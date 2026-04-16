// ---------------------------------------------------------------------------
// IP Name    : tb_int_top
// Author     : Yifeng Wang (yifenwan@phys.ethz.ch)
// Description:
//   Top-level for packet_scheduler/tb_int. Phase 1 walking skeleton:
//     - clk/reset generator
//     - swb_ingress_stub (wraps 4-lane OPQ with run_enable gate)
//     - 4 lane ingress interfaces (opq_ingress_if) tied idle by default
//     - 1 egress interface (opq_egress_if)
//     - 1 CSR interface (opq_csr_if)
//     - 1 run_control_if
//
//   The real FEB datapath (emulator_mutrig, mutrig_frame_deassembly,
//   mts_processor, ring_buffer_cam, feb_frame_assembly) lands in Phase 2
//   under `feb_stub u_feb0/u_feb1`. For Phase 1 we only prove that the
//   OPQ + run-gated stub builds and runs the smoke test cleanly.
// ---------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_int_top;

    // ----- clock / reset ---------------------------------------------------
    logic clk_ref;
    logic rst_n;
    logic rst;  // active-high, fed to VHDL cores
    localparam bit [8:0] RC_STATE_IDLE        = 9'b0_0000_0001;
    localparam bit [8:0] RC_STATE_RUNNING     = 9'b0_0000_1000;
    localparam bit [8:0] RC_STATE_TERMINATING = 9'b0_0001_0000;

    initial begin
        clk_ref = 1'b0;
        forever #4ns clk_ref = ~clk_ref;   // 125 MHz
    end

    initial begin
        rst_n = 1'b0;
        rst   = 1'b1;
        repeat (16) @(posedge clk_ref);
        rst_n = 1'b1;
        rst   = 1'b0;
    end

    // ----- interfaces ------------------------------------------------------
    // Stage C taps: pre-gate FEB tx stream into the SWB stub.
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane0_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane1_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane2_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane3_if (.clk(clk_ref), .rst(rst));
    // Stage D taps: post-gate stream actually presented to OPQ.
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) gate0_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) gate1_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) gate2_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) gate3_if (.clk(clk_ref), .rst(rst));
    opq_egress_if  #(.DATA_W(36))           egress_if(.clk(clk_ref), .rst(rst));
    opq_csr_if     #(.ADDR_W(9))            csr_if   (.clk(clk_ref), .rst(rst));
    emut_avmm_csr_if #(.ADDR_W(4))          emu_csr_if[4] (.clk(clk_ref), .rst(rst));
    run_control_if                          rc_if    (.clk(clk_ref), .rst(rst));

    // Stage A taps (hit_generator FIFO commit per datapath)
    stage_a_if stage_a0_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a1_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a2_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a3_if (.clk(clk_ref), .rst(rst));
    // Intermediate tap: frame_rcv hit_type0 stream before mts.
    hit_type0_if stage_h0_if [4] (.clk(clk_ref), .rst(rst));
    // Intermediate tap: mts hit_type1 stream before rb_cam fanout.
    hit_type1_if stage_h1_if [4] (.clk(clk_ref), .rst(rst));
    // Stage B taps (ring_buffer_cam hit_type2 packets per datapath/slot)
    hit_type2_if stage_b_if [4][4] (.clk(clk_ref), .rst(rst));

    initial begin
        rc_if.run_state  = RC_STATE_IDLE;
        rc_if.run_enable = 1'b0;
        emu_csr_if[0].address   = '0; emu_csr_if[0].read = 1'b0; emu_csr_if[0].write = 1'b0; emu_csr_if[0].writedata = '0;
        emu_csr_if[1].address   = '0; emu_csr_if[1].read = 1'b0; emu_csr_if[1].write = 1'b0; emu_csr_if[1].writedata = '0;
        emu_csr_if[2].address   = '0; emu_csr_if[2].read = 1'b0; emu_csr_if[2].write = 1'b0; emu_csr_if[2].writedata = '0;
        emu_csr_if[3].address   = '0; emu_csr_if[3].read = 1'b0; emu_csr_if[3].write = 1'b0; emu_csr_if[3].writedata = '0;
    end

    // ----- 4 datapath_stubs driving the 4 OPQ lanes -----------------------
    // The OPQ runs in MERGING mode: its page allocator requires every lane to
    // either hold a pending ticket or have asserted alert_eop before it will
    // release a frame. A single active lane never satisfies that condition,
    // so Phase 2 already instantiates 4 full datapath chains. This matches
    // the final 2 FEB × 2 datapath × 4 lane topology from DV_INT_PLAN.md.
`ifdef TB_INT_FAST_RBCAM
    localparam int TB_INT_RBCAM_RING_BUFFER_N_ENTRY = 64;
`else
    localparam int TB_INT_RBCAM_RING_BUFFER_N_ENTRY = 512;
`endif

    logic [35:0] dp_data  [4];
    logic        dp_valid [4];
    logic        dp_sop   [4];
    logic        dp_eop   [4];
    logic        dp_prep_ready [4];
    logic        gate_open;
    logic        gate_open_q;
    logic        swb_gate_mon;
    logic [3:0]  lane_live;
    logic [3:0]  gate_live;

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi++) begin : g_datapath
            datapath_stub #(
                .FEB_ID                    (gi / 2),
                .DATAPATH_ID               (gi % 2),
                .RBCAM_RING_BUFFER_N_ENTRY (TB_INT_RBCAM_RING_BUFFER_N_ENTRY)
            ) u_datapath (
                .i_clk                  (clk_ref),
                .i_rst                  (rst),
                .ctrl_data              (rc_if.run_state),
                .ctrl_valid             (1'b1),
                .emu_csr_address        (emu_csr_if[gi].address),
                .emu_csr_read           (emu_csr_if[gi].read),
                .emu_csr_write          (emu_csr_if[gi].write),
                .emu_csr_writedata      (emu_csr_if[gi].writedata),
                .emu_csr_readdata       (emu_csr_if[gi].readdata),
                .emu_csr_waitrequest    (emu_csr_if[gi].waitrequest),
                .aso_lane_data          (dp_data [gi]),
                .aso_lane_valid         (dp_valid[gi]),
                .aso_lane_startofpacket (dp_sop  [gi]),
                .aso_lane_endofpacket   (dp_eop  [gi]),
                .aso_lane_ready         (1'b1),  // swb_ingress_stub is always ready
                .prep_ready             (dp_prep_ready[gi])
            );
        end
    endgenerate

    // AND-reduce child-IP ctrl-ready across all 4 datapaths and surface it on
    // the run_control_if. PREP uses it as the flush-done condition, while
    // TERMINATING reuses the same aggregate as the per-run drain-complete ack.
    assign rc_if.prep_done = dp_prep_ready[0] & dp_prep_ready[1]
                           & dp_prep_ready[2] & dp_prep_ready[3];
    assign rc_if.term_done = dp_prep_ready[0] & dp_prep_ready[1]
                           & dp_prep_ready[2] & dp_prep_ready[3];

    // Mirror the registered SWB ingress gate locally so the Stage D taps and
    // run audit observe the same one-cycle-delayed gate behavior that OPQ
    // sees, without depending on a mixed-language internal signal tap.
    assign gate_open              = gate_open_q;
    assign lane_live[0]           = (rst === 1'b0) && (dp_valid[0] === 1'b1);
    assign lane_live[1]           = (rst === 1'b0) && (dp_valid[1] === 1'b1);
    assign lane_live[2]           = (rst === 1'b0) && (dp_valid[2] === 1'b1);
    assign lane_live[3]           = (rst === 1'b0) && (dp_valid[3] === 1'b1);
    assign gate_live[0]           = gate_open & lane_live[0];
    assign gate_live[1]           = gate_open & lane_live[1];
    assign gate_live[2]           = gate_open & lane_live[2];
    assign gate_live[3]           = gate_open & lane_live[3];
    assign rc_if.feb_quiet        = ~(lane_live[0] | lane_live[1] | lane_live[2] | lane_live[3]);

    always_ff @(posedge clk_ref) begin
        if (rst)
            gate_open_q <= 1'b0;
        else
            gate_open_q <= rc_if.run_enable;
    end

    generate
        for (genvar hi = 0; hi < 4; hi++) begin : g_stage_h0_tap
            assign stage_h0_if[hi].data          = g_datapath[hi].u_datapath.h0_data;
            assign stage_h0_if[hi].valid         = g_datapath[hi].u_datapath.h0_valid;
            assign stage_h0_if[hi].channel       = g_datapath[hi].u_datapath.h0_channel;
            assign stage_h0_if[hi].startofpacket = g_datapath[hi].u_datapath.h0_sop;
            assign stage_h0_if[hi].endofpacket   = g_datapath[hi].u_datapath.h0_eop;
            assign stage_h0_if[hi].error         = g_datapath[hi].u_datapath.h0_error;
        end
        for (genvar hi = 0; hi < 4; hi++) begin : g_stage_h1_tap
            assign stage_h1_if[hi].data          = g_datapath[hi].u_datapath.h1_data;
            assign stage_h1_if[hi].valid         = g_datapath[hi].u_datapath.h1_valid;
            assign stage_h1_if[hi].ready         = g_datapath[hi].u_datapath.h1_ready;
            assign stage_h1_if[hi].channel       = g_datapath[hi].u_datapath.h1_channel;
            assign stage_h1_if[hi].startofpacket = g_datapath[hi].u_datapath.h1_sop;
            assign stage_h1_if[hi].endofpacket   = g_datapath[hi].u_datapath.h1_eop;
            assign stage_h1_if[hi].empty         = g_datapath[hi].u_datapath.h1_empty;
            assign stage_h1_if[hi].error         = g_datapath[hi].u_datapath.h1_error;
        end
        for (genvar bi = 0; bi < 4; bi++) begin : g_stage_b_tap
            for (genvar bs = 0; bs < 4; bs++) begin : g_stage_b_slot
                assign stage_b_if[bi][bs].data          = g_datapath[bi].u_datapath.h2_data   [bs];
                assign stage_b_if[bi][bs].valid         = g_datapath[bi].u_datapath.h2_valid  [bs];
                assign stage_b_if[bi][bs].ready         = g_datapath[bi].u_datapath.h2_ready  [bs];
                assign stage_b_if[bi][bs].channel       = g_datapath[bi].u_datapath.h2_channel[bs];
                assign stage_b_if[bi][bs].startofpacket = g_datapath[bi].u_datapath.h2_sop    [bs];
                assign stage_b_if[bi][bs].endofpacket   = g_datapath[bi].u_datapath.h2_eop    [bs];
                assign stage_b_if[bi][bs].error         = g_datapath[bi].u_datapath.h2_error  [bs];
            end
        end
    endgenerate

    assign lane0_if.data          = lane_live[0] ? dp_data [0] : '0;
    assign lane0_if.valid         = lane_live[0];
    assign lane0_if.channel       = 2'b00;
    assign lane0_if.startofpacket = lane_live[0] ? dp_sop  [0] : 1'b0;
    assign lane0_if.endofpacket   = lane_live[0] ? dp_eop  [0] : 1'b0;
    assign lane0_if.error         = 3'b000;

    assign lane1_if.data          = lane_live[1] ? dp_data [1] : '0;
    assign lane1_if.valid         = lane_live[1];
    assign lane1_if.channel       = 2'b01;
    assign lane1_if.startofpacket = lane_live[1] ? dp_sop  [1] : 1'b0;
    assign lane1_if.endofpacket   = lane_live[1] ? dp_eop  [1] : 1'b0;
    assign lane1_if.error         = 3'b000;

    assign lane2_if.data          = lane_live[2] ? dp_data [2] : '0;
    assign lane2_if.valid         = lane_live[2];
    assign lane2_if.channel       = 2'b10;
    assign lane2_if.startofpacket = lane_live[2] ? dp_sop  [2] : 1'b0;
    assign lane2_if.endofpacket   = lane_live[2] ? dp_eop  [2] : 1'b0;
    assign lane2_if.error         = 3'b000;

    assign lane3_if.data          = lane_live[3] ? dp_data [3] : '0;
    assign lane3_if.valid         = lane_live[3];
    assign lane3_if.channel       = 2'b11;
    assign lane3_if.startofpacket = lane_live[3] ? dp_sop  [3] : 1'b0;
    assign lane3_if.endofpacket   = lane_live[3] ? dp_eop  [3] : 1'b0;
    assign lane3_if.error         = 3'b000;

    assign gate0_if.data          = gate_live[0] ? lane0_if.data : '0;
    assign gate0_if.valid         = gate_live[0];
    assign gate0_if.channel       = lane0_if.channel;
    assign gate0_if.startofpacket = gate_live[0] ? lane0_if.startofpacket : 1'b0;
    assign gate0_if.endofpacket   = gate_live[0] ? lane0_if.endofpacket   : 1'b0;
    assign gate0_if.error         = lane0_if.error;

    assign gate1_if.data          = gate_live[1] ? lane1_if.data : '0;
    assign gate1_if.valid         = gate_live[1];
    assign gate1_if.channel       = lane1_if.channel;
    assign gate1_if.startofpacket = gate_live[1] ? lane1_if.startofpacket : 1'b0;
    assign gate1_if.endofpacket   = gate_live[1] ? lane1_if.endofpacket   : 1'b0;
    assign gate1_if.error         = lane1_if.error;

    assign gate2_if.data          = gate_live[2] ? lane2_if.data : '0;
    assign gate2_if.valid         = gate_live[2];
    assign gate2_if.channel       = lane2_if.channel;
    assign gate2_if.startofpacket = gate_live[2] ? lane2_if.startofpacket : 1'b0;
    assign gate2_if.endofpacket   = gate_live[2] ? lane2_if.endofpacket   : 1'b0;
    assign gate2_if.error         = lane2_if.error;

    assign gate3_if.data          = gate_live[3] ? lane3_if.data : '0;
    assign gate3_if.valid         = gate_live[3];
    assign gate3_if.channel       = lane3_if.channel;
    assign gate3_if.startofpacket = gate_live[3] ? lane3_if.startofpacket : 1'b0;
    assign gate3_if.endofpacket   = gate_live[3] ? lane3_if.endofpacket   : 1'b0;
    assign gate3_if.error         = lane3_if.error;

    // Stage A drivers — observe the durable L2 enqueue point inside the
    // emulator, not the earlier per-channel source-slot acceptance event.
    // That keeps Stage A aligned with what can actually reach the frame
    // assembler and avoids counting hits that are still upstream of the
    // four L1 FIFOs / shared L2 FIFO boundary.
    assign stage_a0_if.valid   = g_datapath[0].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_valid_c;
    assign stage_a0_if.payload = g_datapath[0].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_word_c;
    assign stage_a0_if.feb_id      = 2'd0;
    assign stage_a0_if.datapath_id = 1'd0;
    assign stage_a0_if.mutrig_ch   = 3'd0;

    assign stage_a1_if.valid   = g_datapath[1].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_valid_c;
    assign stage_a1_if.payload = g_datapath[1].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_word_c;
    assign stage_a1_if.feb_id      = 2'd0;
    assign stage_a1_if.datapath_id = 1'd1;
    assign stage_a1_if.mutrig_ch   = 3'd0;

    assign stage_a2_if.valid   = g_datapath[2].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_valid_c;
    assign stage_a2_if.payload = g_datapath[2].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_word_c;
    assign stage_a2_if.feb_id      = 2'd1;
    assign stage_a2_if.datapath_id = 1'd0;
    assign stage_a2_if.mutrig_ch   = 3'd0;

    assign stage_a3_if.valid   = g_datapath[3].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_valid_c;
    assign stage_a3_if.payload = g_datapath[3].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_word_c;
    assign stage_a3_if.feb_id      = 2'd1;
    assign stage_a3_if.datapath_id = 1'd1;
    assign stage_a3_if.mutrig_ch   = 3'd0;

    assign egress_if.ready = 1'b1;      // always-ready by default

    assign csr_if.address   = '0;
    assign csr_if.read      = 1'b0;
    assign csr_if.write     = 1'b0;
    assign csr_if.writedata = '0;
    assign csr_if.burstcount = 1'b0;

    // rc_if.run_state / run_enable are driven by run_control_driver in
    // tb_int_pkg. They also get deterministic IDLE defaults above so the OPQ
    // never sees X-valued gate control during UVM bring-up.

    // Contract SVA on the framed streams. C observes the pre-gate FEB tx
    // boundary, D observes the run_enable-qualified stream that actually
    // enters OPQ, and E observes accepted OPQ egress beats.
    generate
        for (genvar hi = 0; hi < 4; hi++) begin : g_stage_h0_sva
            tb_int_hit0_contract_sva u_stage_h0_contract_sva (
                .clk  (clk_ref),
                .reset(rst),
                .valid(stage_h0_if[hi].valid),
                .hit_error(stage_h0_if[hi].error[0]),
                .crc_error(stage_h0_if[hi].error[1]),
                .sop  (stage_h0_if[hi].startofpacket),
                .eop  (stage_h0_if[hi].endofpacket)
            );
            tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
                u_stage_h0_run_sva (
                    .clk      (clk_ref),
                    .reset    (rst),
                    .run_state(rc_if.run_state),
                    .valid    (stage_h0_if[hi].valid)
                );
            tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
                u_stage_h1_run_sva (
                    .clk      (clk_ref),
                    .reset    (rst),
                    .run_state(rc_if.run_state),
                    .valid    (stage_h1_if[hi].valid && stage_h1_if[hi].ready)
                );
        end
        for (genvar bi = 0; bi < 4; bi++) begin : g_stage_b_sva_lane
            for (genvar bs = 0; bs < 4; bs++) begin : g_stage_b_sva_slot
                tb_int_hit2_contract_sva u_stage_b_sva (
                    .clk  (clk_ref),
                    .reset(rst),
                    .data (stage_b_if[bi][bs].data),
                    .valid(stage_b_if[bi][bs].valid),
                    .ready(stage_b_if[bi][bs].ready),
                    .sop  (stage_b_if[bi][bs].startofpacket),
                    .eop  (stage_b_if[bi][bs].endofpacket)
                );
                tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
                    u_stage_b_run_sva (
                        .clk      (clk_ref),
                        .reset    (rst),
                        .run_state(rc_if.run_state),
                        .valid    (stage_b_if[bi][bs].valid && stage_b_if[bi][bs].ready)
                    );
            end
        end
    endgenerate
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_c0_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(lane0_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_c1_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(lane1_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_c2_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(lane2_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_c3_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(lane3_if.valid));
    tb_int_frame_contract_sva u_stage_c0_sva (.clk(clk_ref), .reset(rst), .data(lane0_if.data), .valid(lane0_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_c1_sva (.clk(clk_ref), .reset(rst), .data(lane1_if.data), .valid(lane1_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_c2_sva (.clk(clk_ref), .reset(rst), .data(lane2_if.data), .valid(lane2_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_c3_sva (.clk(clk_ref), .reset(rst), .data(lane3_if.data), .valid(lane3_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_d0_sva (.clk(clk_ref), .reset(rst), .data(gate0_if.data), .valid(gate0_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_d1_sva (.clk(clk_ref), .reset(rst), .data(gate1_if.data), .valid(gate1_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_d2_sva (.clk(clk_ref), .reset(rst), .data(gate2_if.data), .valid(gate2_if.valid), .ready(1'b1));
    tb_int_frame_contract_sva u_stage_d3_sva (.clk(clk_ref), .reset(rst), .data(gate3_if.data), .valid(gate3_if.valid), .ready(1'b1));
    tb_int_egress_contract_sva u_stage_e_sva (
        .clk  (clk_ref),
        .reset(rst),
        .data (egress_if.data),
        .valid(egress_if.valid),
        .ready(egress_if.ready),
        .sop  (egress_if.startofpacket),
        .eop  (egress_if.endofpacket)
    );
    tb_int_run_contract_sva u_stage_a0_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(stage_a0_if.valid));
    tb_int_run_contract_sva u_stage_a1_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(stage_a1_if.valid));
    tb_int_run_contract_sva u_stage_a2_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(stage_a2_if.valid));
    tb_int_run_contract_sva u_stage_a3_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(stage_a3_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_d0_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(gate0_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_d1_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(gate1_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_d2_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(gate2_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_d3_run_sva (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(gate3_if.valid));
    tb_int_run_contract_sva #(.ALLOW_TERMINATING(1'b1))
        u_stage_e_run_sva  (.clk(clk_ref), .reset(rst), .run_state(rc_if.run_state), .valid(egress_if.valid && egress_if.ready));
    tb_int_run_enable_contract_sva
        u_swb_gate_contract_sva (
            .clk       (clk_ref),
            .reset     (rst),
            .run_state (rc_if.run_state),
            .run_enable(rc_if.run_enable)
        );

    // ----- DUT instance ----------------------------------------------------
    logic [0:0] v0, v1, v2, v3;
    assign v0 = lane0_if.valid;
    assign v1 = lane1_if.valid;
    assign v2 = lane2_if.valid;
    assign v3 = lane3_if.valid;

    swb_ingress_stub u_swb (
        .d_clk       (clk_ref),
        .d_reset     (rst),
        .run_enable  (rc_if.run_enable),
        .run_gate_mon(run_gate_mon),

        .asi_ingress_0_data          (lane0_if.data),
        .asi_ingress_0_valid         (v0),
        .asi_ingress_0_channel       (lane0_if.channel),
        .asi_ingress_0_startofpacket ({lane0_if.startofpacket}),
        .asi_ingress_0_endofpacket   ({lane0_if.endofpacket}),
        .asi_ingress_0_error         (lane0_if.error),

        .asi_ingress_1_data          (lane1_if.data),
        .asi_ingress_1_valid         (v1),
        .asi_ingress_1_channel       (lane1_if.channel),
        .asi_ingress_1_startofpacket ({lane1_if.startofpacket}),
        .asi_ingress_1_endofpacket   ({lane1_if.endofpacket}),
        .asi_ingress_1_error         (lane1_if.error),

        .asi_ingress_2_data          (lane2_if.data),
        .asi_ingress_2_valid         (v2),
        .asi_ingress_2_channel       (lane2_if.channel),
        .asi_ingress_2_startofpacket ({lane2_if.startofpacket}),
        .asi_ingress_2_endofpacket   ({lane2_if.endofpacket}),
        .asi_ingress_2_error         (lane2_if.error),

        .asi_ingress_3_data          (lane3_if.data),
        .asi_ingress_3_valid         (v3),
        .asi_ingress_3_channel       (lane3_if.channel),
        .asi_ingress_3_startofpacket ({lane3_if.startofpacket}),
        .asi_ingress_3_endofpacket   ({lane3_if.endofpacket}),
        .asi_ingress_3_error         (lane3_if.error),

        .aso_egress_data             (egress_if.data),
        .aso_egress_valid            (egress_if.valid),
        .aso_egress_ready            (egress_if.ready),
        .aso_egress_startofpacket    (egress_if.startofpacket),
        .aso_egress_endofpacket      (egress_if.endofpacket),
        .aso_egress_error            (egress_if.error),

        .avs_csr_address             (csr_if.address),
        .avs_csr_read                (csr_if.read),
        .avs_csr_write               (csr_if.write),
        .avs_csr_writedata           (csr_if.writedata),
        .avs_csr_readdata            (csr_if.readdata),
        .avs_csr_readdatavalid       (csr_if.readdatavalid),
        .avs_csr_waitrequest         (csr_if.waitrequest),
        .avs_csr_burstcount          (csr_if.burstcount)
    );

    // ----- Phase 2 walking-skeleton beat counters --------------------------
    // Count per-lane beats at key stages so the smoke test can prove
    // end-to-end flow before the full Phase 3 stage-A..E scoreboard lands.
    int unsigned cnt_emu_tx [4];
    int unsigned cnt_h0     [4];
    int unsigned cnt_h1     [4];
    int unsigned cnt_lane   [4];
    int unsigned cnt_egress;
    int unsigned cnt_emu_frame_run  [4];
    int unsigned cnt_emu_frame_term [4];
    int unsigned sum_emu_evt_run    [4];
    int unsigned sum_emu_evt_term   [4];
    int unsigned first_emu_evt_term [4];
    int unsigned cnt_emu_evt_latch_mismatch [4];
    int unsigned cnt_emu_frame_latch_zero   [4];
    int unsigned cnt_emu_frame_snap_zero    [4];
    int unsigned last_emu_evt_latch_used    [4];
    int unsigned last_emu_evt_snap          [4];
    int unsigned last_fifo_tail             [4];
    int unsigned cnt_a_since_last_frame     [4];
    int unsigned last_a_window_closed       [4];
    int unsigned max_a_window_closed        [4];
    int unsigned cnt_h0_sop_run     [4];
    int unsigned cnt_h0_sop_term    [4];
    int unsigned cnt_h0_valid_term  [4];
    int unsigned cnt_frcv_enable_term [4];
    int unsigned cnt_frcv_go_term     [4];
    int unsigned cnt_h1_close_marker    [4][4];
    int unsigned cnt_h1_data_after_close[4][4];
    time         t_first_emu_frame_term [4];
    time         t_first_h0_sop_term    [4];
    time         t_first_h1_close       [4][4];
    time         t_first_h1_post_close  [4][4];
    time         t_last_emu_frame_run   [4];
    time         t_last_a_commit        [4];
    bit          seen_emu_frame_term    [4];
    bit          seen_h0_sop_term       [4];
    bit          seen_h1_close          [4][4];
    bit          seen_h1_post_close     [4][4];
    bit          sample_emu_frame_latch_next [4];

    always_ff @(posedge clk_ref) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                cnt_emu_tx[i] <= 0;
                cnt_h0    [i] <= 0;
                cnt_h1    [i] <= 0;
                cnt_lane  [i] <= 0;
            end
            cnt_egress <= 0;
        end else begin
            if (g_datapath[0].u_datapath.emu_tx_valid) cnt_emu_tx[0] <= cnt_emu_tx[0] + 1;
            if (g_datapath[1].u_datapath.emu_tx_valid) cnt_emu_tx[1] <= cnt_emu_tx[1] + 1;
            if (g_datapath[2].u_datapath.emu_tx_valid) cnt_emu_tx[2] <= cnt_emu_tx[2] + 1;
            if (g_datapath[3].u_datapath.emu_tx_valid) cnt_emu_tx[3] <= cnt_emu_tx[3] + 1;

            if (g_datapath[0].u_datapath.h0_valid) cnt_h0[0] <= cnt_h0[0] + 1;
            if (g_datapath[1].u_datapath.h0_valid) cnt_h0[1] <= cnt_h0[1] + 1;
            if (g_datapath[2].u_datapath.h0_valid) cnt_h0[2] <= cnt_h0[2] + 1;
            if (g_datapath[3].u_datapath.h0_valid) cnt_h0[3] <= cnt_h0[3] + 1;

            if (g_datapath[0].u_datapath.h1_valid) cnt_h1[0] <= cnt_h1[0] + 1;
            if (g_datapath[1].u_datapath.h1_valid) cnt_h1[1] <= cnt_h1[1] + 1;
            if (g_datapath[2].u_datapath.h1_valid) cnt_h1[2] <= cnt_h1[2] + 1;
            if (g_datapath[3].u_datapath.h1_valid) cnt_h1[3] <= cnt_h1[3] + 1;

            if (lane_live[0]) cnt_lane[0] <= cnt_lane[0] + 1;
            if (lane_live[1]) cnt_lane[1] <= cnt_lane[1] + 1;
            if (lane_live[2]) cnt_lane[2] <= cnt_lane[2] + 1;
            if (lane_live[3]) cnt_lane[3] <= cnt_lane[3] + 1;

            if (egress_if.valid && egress_if.ready) cnt_egress <= cnt_egress + 1;
        end
    end

    localparam int RC_ENUM_SYNC        = 2;
    localparam int RC_ENUM_RUNNING     = 3;
    localparam int RC_ENUM_TERMINATING = 4;

    generate
        for (genvar ti = 0; ti < 4; ti++) begin : g_term_counters
            always_ff @(posedge clk_ref) begin
                if (rst) begin
                    cnt_emu_frame_run [ti] <= 0;
                    cnt_emu_frame_term[ti] <= 0;
                    sum_emu_evt_run   [ti] <= 0;
                    sum_emu_evt_term  [ti] <= 0;
                    first_emu_evt_term[ti] <= 0;
                    cnt_emu_evt_latch_mismatch[ti] <= 0;
                    cnt_emu_frame_latch_zero  [ti] <= 0;
                    cnt_emu_frame_snap_zero   [ti] <= 0;
                    last_emu_evt_latch_used   [ti] <= 0;
                    last_emu_evt_snap         [ti] <= 0;
                    last_fifo_tail            [ti] <= 0;
                    cnt_a_since_last_frame    [ti] <= 0;
                    last_a_window_closed      [ti] <= 0;
                    max_a_window_closed       [ti] <= 0;
                    cnt_h0_sop_run    [ti] <= 0;
                    cnt_h0_sop_term   [ti] <= 0;
                    cnt_h0_valid_term [ti] <= 0;
                    cnt_frcv_enable_term[ti] <= 0;
                    cnt_frcv_go_term    [ti] <= 0;
                    t_first_emu_frame_term[ti] <= 0;
                    t_first_h0_sop_term   [ti] <= 0;
                    t_last_emu_frame_run  [ti] <= 0;
                    t_last_a_commit       [ti] <= 0;
                    seen_emu_frame_term   [ti] <= 1'b0;
                    seen_h0_sop_term      [ti] <= 1'b0;
                    sample_emu_frame_latch_next[ti] <= 1'b0;
                    for (int slot = 0; slot < 4; slot++) begin
                        cnt_h1_close_marker    [ti][slot] <= 0;
                        cnt_h1_data_after_close[ti][slot] <= 0;
                        t_first_h1_close       [ti][slot] <= 0;
                        t_first_h1_post_close  [ti][slot] <= 0;
                        seen_h1_close          [ti][slot] <= 1'b0;
                        seen_h1_post_close     [ti][slot] <= 1'b0;
                    end
                end else begin
                    bit a_commit;
                    bit running_frame_start;
                    int unsigned h1_slot;
                    a_commit = g_datapath[ti].u_datapath.u_emulator_mutrig.u_hit_gen.l2_push_valid_c;
                    running_frame_start =
                        (g_datapath[ti].u_datapath.u_emulator_mutrig.ctrl_state_q == RC_STATE_RUNNING) &&
                        g_datapath[ti].u_datapath.u_emulator_mutrig.frame_start;
                    last_fifo_tail[ti] <= g_datapath[ti].u_datapath.u_emulator_mutrig.u_hit_gen.fifo_count;

                    if (sample_emu_frame_latch_next[ti]) begin
                        int unsigned evt_used;
                        int unsigned evt_snap;
                        evt_used = g_datapath[ti].u_datapath.u_emulator_mutrig.u_frame_asm.evt_cnt_latch;
                        evt_snap = g_datapath[ti].u_datapath.u_emulator_mutrig.u_hit_gen.event_count;
                        last_emu_evt_latch_used[ti] <= evt_used;
                        last_emu_evt_snap      [ti] <= evt_snap;
                        if (evt_used == 0)
                            cnt_emu_frame_latch_zero[ti] <= cnt_emu_frame_latch_zero[ti] + 1;
                        if (evt_snap == 0)
                            cnt_emu_frame_snap_zero[ti] <= cnt_emu_frame_snap_zero[ti] + 1;
                        if (evt_used != evt_snap)
                            cnt_emu_evt_latch_mismatch[ti] <= cnt_emu_evt_latch_mismatch[ti] + 1;
                        sample_emu_frame_latch_next[ti] <= 1'b0;
                    end

                    if (a_commit) begin
                        t_last_a_commit[ti] <= $time;
                    end

                    if (running_frame_start) begin
                        if (cnt_a_since_last_frame[ti] > max_a_window_closed[ti])
                            max_a_window_closed[ti] <= cnt_a_since_last_frame[ti];
                        last_a_window_closed[ti] <= cnt_a_since_last_frame[ti];
                        cnt_a_since_last_frame[ti] <= a_commit ? 1 : 0;
                        t_last_emu_frame_run[ti] <= $time;
                        sample_emu_frame_latch_next[ti] <= 1'b1;
                    end else if (a_commit) begin
                        cnt_a_since_last_frame[ti] <= cnt_a_since_last_frame[ti] + 1;
                    end

                    if (g_datapath[ti].u_datapath.u_emulator_mutrig.ctrl_state_q == RC_STATE_RUNNING &&
                        g_datapath[ti].u_datapath.u_emulator_mutrig.frame_start) begin
                        cnt_emu_frame_run[ti] <= cnt_emu_frame_run[ti] + 1;
                        sum_emu_evt_run  [ti] <= sum_emu_evt_run  [ti]
                                               + g_datapath[ti].u_datapath.u_emulator_mutrig.event_count;
                    end
                    if (g_datapath[ti].u_datapath.u_emulator_mutrig.ctrl_state_q == RC_STATE_TERMINATING &&
                        g_datapath[ti].u_datapath.u_emulator_mutrig.frame_start) begin
                        cnt_emu_frame_term[ti] <= cnt_emu_frame_term[ti] + 1;
                        sum_emu_evt_term  [ti] <= sum_emu_evt_term  [ti]
                                                + g_datapath[ti].u_datapath.u_emulator_mutrig.event_count;
                        if (!seen_emu_frame_term[ti]) begin
                            seen_emu_frame_term   [ti] <= 1'b1;
                            t_first_emu_frame_term[ti] <= $time;
                            first_emu_evt_term    [ti] <= g_datapath[ti].u_datapath.u_emulator_mutrig.event_count;
                        end
                    end
                    if (int'(g_datapath[ti].u_datapath.u_frame_rcv.run_state_cmd) == RC_ENUM_RUNNING &&
                        g_datapath[ti].u_datapath.h0_valid &&
                        g_datapath[ti].u_datapath.h0_sop) begin
                        cnt_h0_sop_run[ti] <= cnt_h0_sop_run[ti] + 1;
                    end
                    if (int'(g_datapath[ti].u_datapath.u_frame_rcv.run_state_cmd) == RC_ENUM_TERMINATING) begin
                        if (g_datapath[ti].u_datapath.h0_valid)
                            cnt_h0_valid_term[ti] <= cnt_h0_valid_term[ti] + 1;
                        if (g_datapath[ti].u_datapath.h0_valid &&
                            g_datapath[ti].u_datapath.h0_sop) begin
                            cnt_h0_sop_term[ti] <= cnt_h0_sop_term[ti] + 1;
                            if (!seen_h0_sop_term[ti]) begin
                                seen_h0_sop_term   [ti] <= 1'b1;
                                t_first_h0_sop_term[ti] <= $time;
                            end
                        end
                        if (g_datapath[ti].u_datapath.u_frame_rcv.enable == 1'b1)
                            cnt_frcv_enable_term[ti] <= cnt_frcv_enable_term[ti] + 1;
                        if (g_datapath[ti].u_datapath.u_frame_rcv.receiver_go == 1'b1)
                            cnt_frcv_go_term[ti] <= cnt_frcv_go_term[ti] + 1;
                    end

                    if (g_datapath[ti].u_datapath.h1_valid) begin
                        h1_slot = g_datapath[ti].u_datapath.h1_channel[1:0];
                        if (h1_slot < 4) begin
                            if (g_datapath[ti].u_datapath.h1_empty &&
                                g_datapath[ti].u_datapath.h1_eop) begin
                                cnt_h1_close_marker[ti][h1_slot] <= cnt_h1_close_marker[ti][h1_slot] + 1;
                                if (!seen_h1_close[ti][h1_slot]) begin
                                    seen_h1_close   [ti][h1_slot] <= 1'b1;
                                    t_first_h1_close[ti][h1_slot] <= $time;
                                end
                            end else if (!g_datapath[ti].u_datapath.h1_empty &&
                                         seen_h1_close[ti][h1_slot]) begin
                                cnt_h1_data_after_close[ti][h1_slot] <= cnt_h1_data_after_close[ti][h1_slot] + 1;
                                if (!seen_h1_post_close[ti][h1_slot]) begin
                                    seen_h1_post_close    [ti][h1_slot] <= 1'b1;
                                    t_first_h1_post_close[ti][h1_slot] <= $time;
                                end
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    final begin
        $display("[tb_int_top] emu=(%0d,%0d,%0d,%0d) h0=(%0d,%0d,%0d,%0d) h1=(%0d,%0d,%0d,%0d) lane=(%0d,%0d,%0d,%0d) egress=%0d",
                 cnt_emu_tx[0], cnt_emu_tx[1], cnt_emu_tx[2], cnt_emu_tx[3],
                 cnt_h0[0],     cnt_h0[1],     cnt_h0[2],     cnt_h0[3],
                 cnt_h1[0],     cnt_h1[1],     cnt_h1[2],     cnt_h1[3],
                 cnt_lane[0],   cnt_lane[1],   cnt_lane[2],   cnt_lane[3],
                 cnt_egress);
        for (int i = 0; i < 4; i++) begin
            $display("[tb_int_top] A->H0 term dp%0d emu_frame_run=%0d emu_evt_run=%0d emu_frame_term=%0d emu_evt_term=%0d first_emu_evt_term=%0d t_first_emu_term=%0t h0_sop_run=%0d h0_sop_term=%0d t_first_h0_term=%0t h0_valid_term=%0d frcv_enable_term=%0d frcv_go_term=%0d",
                     i,
                     cnt_emu_frame_run[i], sum_emu_evt_run[i],
                     cnt_emu_frame_term[i], sum_emu_evt_term[i], first_emu_evt_term[i], t_first_emu_frame_term[i],
                     cnt_h0_sop_run[i], cnt_h0_sop_term[i], t_first_h0_sop_term[i],
                     cnt_h0_valid_term[i], cnt_frcv_enable_term[i], cnt_frcv_go_term[i]);
            $display("[tb_int_top] A->H0 emu dbg dp%0d last_fs_t=%0t last_a_t=%0t tail_a=%0d last_a_window=%0d max_a_window=%0d evt_latch_used=%0d evt_snap=%0d evt_mismatch=%0d zero_used=%0d zero_snap=%0d fifo_tail=%0d",
                     i,
                     t_last_emu_frame_run[i], t_last_a_commit[i],
                     cnt_a_since_last_frame[i], last_a_window_closed[i], max_a_window_closed[i],
                     last_emu_evt_latch_used[i], last_emu_evt_snap[i],
                     cnt_emu_evt_latch_mismatch[i], cnt_emu_frame_latch_zero[i], cnt_emu_frame_snap_zero[i],
                     last_fifo_tail[i]);
            for (int slot = 0; slot < 4; slot++) begin
                $display("[tb_int_top] H1 close dbg dp%0d slot%0d close_cnt=%0d first_close_t=%0t post_close_data=%0d first_post_t=%0t",
                         i, slot,
                         cnt_h1_close_marker[i][slot], t_first_h1_close[i][slot],
                         cnt_h1_data_after_close[i][slot], t_first_h1_post_close[i][slot]);
            end
            $display("[tb_int_top] H1->B dbg dp0 slot0 push=%0d pop=%0d ow=%0d end_seen=%0b drain_done=%0b deass_used=%0d popcmd_used=%0d term_ready=%0b",
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.debug_msg2.push_cnt,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.debug_msg2.pop_cnt,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.debug_msg2.overwrite_cnt,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.endofrun_seen,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.terminating_drain_done,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.deassembly_fifo_usedw,
                     g_datapath[0].u_datapath.g_rbcam[0].u_rbcam.v2_core.pop_cmd_fifo_usedw,
                     g_datapath[0].u_datapath.rbcam_ctrl_ready[0]);
            $display("[tb_int_top] H1->B dbg dp0 slot1 push=%0d pop=%0d ow=%0d end_seen=%0b drain_done=%0b deass_used=%0d popcmd_used=%0d term_ready=%0b",
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.debug_msg2.push_cnt,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.debug_msg2.pop_cnt,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.debug_msg2.overwrite_cnt,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.endofrun_seen,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.terminating_drain_done,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.deassembly_fifo_usedw,
                     g_datapath[0].u_datapath.g_rbcam[1].u_rbcam.v2_core.pop_cmd_fifo_usedw,
                     g_datapath[0].u_datapath.rbcam_ctrl_ready[1]);
            $display("[tb_int_top] H1->B dbg dp0 slot2 push=%0d pop=%0d ow=%0d end_seen=%0b drain_done=%0b deass_used=%0d popcmd_used=%0d term_ready=%0b",
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.debug_msg2.push_cnt,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.debug_msg2.pop_cnt,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.debug_msg2.overwrite_cnt,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.endofrun_seen,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.terminating_drain_done,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.deassembly_fifo_usedw,
                     g_datapath[0].u_datapath.g_rbcam[2].u_rbcam.v2_core.pop_cmd_fifo_usedw,
                     g_datapath[0].u_datapath.rbcam_ctrl_ready[2]);
            $display("[tb_int_top] H1->B dbg dp0 slot3 push=%0d pop=%0d ow=%0d end_seen=%0b drain_done=%0b deass_used=%0d popcmd_used=%0d term_ready=%0b",
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.debug_msg2.push_cnt,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.debug_msg2.pop_cnt,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.debug_msg2.overwrite_cnt,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.endofrun_seen,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.terminating_drain_done,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.deassembly_fifo_usedw,
                     g_datapath[0].u_datapath.g_rbcam[3].u_rbcam.v2_core.pop_cmd_fifo_usedw,
                     g_datapath[0].u_datapath.rbcam_ctrl_ready[3]);
        end
    end

    // -----------------------------------------------------------------------
    // Run-state edge audit
    //
    // Goal: prove that every datapath module sees the SYNC and RUNNING edges
    // on the same clock cycle, and measure the latency from each edge to the
    // first downstream beat at every connection point in the chain.
    //
    // The 9-bit run_state bus is broadcast by tb_int_top to every datapath_stub
    // with ctrl_valid tied high, so each IP samples the same value on the
    // same clock edge. The internal run_state_cmd register of every IP is
    // therefore expected to transition on the cycle after the broadcast bus
    // transitions, with zero per-IP skew. We capture the event timestamps
    // and report any mismatch.
    // -----------------------------------------------------------------------
    localparam bit [8:0] AUDIT_RC_SYNC    = 9'b0_0000_0100;
    localparam bit [8:0] AUDIT_RC_RUNNING = 9'b0_0000_1000;

    // Broadcast-bus edges (driven by run_control_driver via rc_if.run_state).
    time t_bc_sync    = 0;
    time t_bc_running = 0;
    bit  bc_sync_seen    = 1'b0;
    bit  bc_running_seen = 1'b0;

    always_ff @(posedge clk_ref) begin
        if (!rst) begin
            if (!bc_sync_seen && rc_if.run_state == AUDIT_RC_SYNC) begin
                bc_sync_seen <= 1'b1;
                t_bc_sync    <= $time;
            end
            if (!bc_running_seen && rc_if.run_state == AUDIT_RC_RUNNING) begin
                bc_running_seen <= 1'b1;
                t_bc_running    <= $time;
            end
        end
    end

    // Per-datapath observations: time of the first downstream beat after
    // the broadcast RUNNING edge. Stages probed:
    //   emu_tx  : emulator_mutrig 8b1k tx (frame_rcv ingress)
    //   h0      : frame_rcv hit_type0 (mts_processor ingress)
    //   h1      : mts_processor hit_type1 (rb_cam ingress)
    //   h2[gi]  : rb_cam[gi] hit_type2 (feb_frame_assembly ingress, per slot)
    //   lane    : feb_frame_assembly hit_type3 (OPQ ingress)
    time t_first_emu_tx   [4];
    time t_first_h0       [4];
    time t_first_h1       [4];
    time t_first_h2       [4][4];
    time t_first_lane     [4];
    bit  seen_emu_tx      [4];
    bit  seen_h0          [4];
    bit  seen_h1          [4];
    bit  seen_h2          [4][4];
    bit  seen_lane        [4];

    // Per-IP run-state shadow: reads the internal state register of each IP
    // via hierarchical reference and watches for the cycle on which it
    // transitions to SYNC and to RUNNING. If the broadcast is wired
    // identically, every datapath IP should fire on the same cycle.
    //
    // Probed IPs per datapath:
    //   [0] emulator     : g_datapath[i].u_datapath.u_emulator_mutrig.ctrl_state_q
    //   [1] frame_rcv    : g_datapath[i].u_datapath.u_frame_rcv.run_state_cmd
    //   [2] mts          : g_datapath[i].u_datapath.u_mts.run_state_cmd
    //   [3] rbcam[0..3]  : g_datapath[i].u_datapath.g_rbcam[k].u_rbcam.v2_core.run_state_cmd
    //   [4] ffa datapath : g_datapath[i].u_datapath.u_ffa.d_run_state_cmd
    //   [5] ffa xcvr     : g_datapath[i].u_datapath.u_ffa.x_run_state_cmd
    //   swb gate         : registered ingress gate inside swb_ingress_stub
    //
    // VHDL enum literal positions (from feb_frame_assembly.vhd line 551):
    //   IDLE=0, RUN_PREPARE=1, SYNC=2, RUNNING=3, TERMINATING=4, ...

    time t_emu_sync   [4]; bit f_emu_sync   [4];
    time t_emu_run    [4]; bit f_emu_run    [4];
    time t_frcv_sync  [4]; bit f_frcv_sync  [4];
    time t_frcv_run   [4]; bit f_frcv_run   [4];
    time t_mts_sync   [4]; bit f_mts_sync   [4];
    time t_mts_run    [4]; bit f_mts_run    [4];
    time t_rbcam_sync [4][4]; bit f_rbcam_sync [4][4];
    time t_rbcam_run  [4][4]; bit f_rbcam_run  [4][4];
    time t_ffa_d_sync [4]; bit f_ffa_d_sync [4];
    time t_ffa_d_run  [4]; bit f_ffa_d_run  [4];
    time t_ffa_x_sync [4]; bit f_ffa_x_sync [4];
    time t_ffa_x_run  [4]; bit f_ffa_x_run  [4];
    time t_swb_gate_run; bit f_swb_gate_run;

    // Helper macros for the stage-1 register edge capture. Each IP stores its
    // run_state_cmd as a VHDL enum; the integer position is what we compare.
    `define WATCH_ENUM(NAME, PATH, FLG_S, T_S, FLG_R, T_R)                  \
        if (!FLG_S && int'(PATH) == RC_ENUM_SYNC)    begin FLG_S <= 1'b1; T_S <= $time; end  \
        if (!FLG_R && int'(PATH) == RC_ENUM_RUNNING) begin FLG_R <= 1'b1; T_R <= $time; end

    genvar dpi;
    generate
        for (dpi = 0; dpi < 4; dpi++) begin : g_audit
            always_ff @(posedge clk_ref) begin
                if (!rst && bc_running_seen) begin
                    if (!seen_emu_tx[dpi] && g_datapath[dpi].u_datapath.emu_tx_valid) begin
                        seen_emu_tx[dpi] <= 1'b1;
                        t_first_emu_tx[dpi] <= $time;
                    end
                    if (!seen_h0[dpi] && g_datapath[dpi].u_datapath.h0_valid) begin
                        seen_h0[dpi] <= 1'b1;
                        t_first_h0[dpi] <= $time;
                    end
                    if (!seen_h1[dpi] && g_datapath[dpi].u_datapath.h1_valid) begin
                        seen_h1[dpi] <= 1'b1;
                        t_first_h1[dpi] <= $time;
                    end
                    if (!seen_lane[dpi] && lane_live[dpi]) begin
                        seen_lane[dpi] <= 1'b1;
                        t_first_lane[dpi] <= $time;
                    end
                end
            end
            for (genvar rbi = 0; rbi < 4; rbi++) begin : g_audit_rb
                always_ff @(posedge clk_ref) begin
                    if (!rst && bc_running_seen) begin
                        if (!seen_h2[dpi][rbi] && g_datapath[dpi].u_datapath.h2_valid[rbi]) begin
                            seen_h2[dpi][rbi] <= 1'b1;
                            t_first_h2[dpi][rbi] <= $time;
                        end
                    end
                end
            end
        end
    endgenerate

    // Per-IP run_state_cmd shadow watchers. Hierarchical references into VHDL
    // enum signals are read as their integer position by Questa.
    generate
        for (dpi = 0; dpi < 4; dpi++) begin : g_state_audit
            always_ff @(posedge clk_ref) begin
                if (!rst) begin
                    if (!f_emu_sync[dpi] &&
                        g_datapath[dpi].u_datapath.u_emulator_mutrig.ctrl_state_q == AUDIT_RC_SYNC) begin
                        f_emu_sync[dpi] <= 1'b1;
                        t_emu_sync[dpi] <= $time;
                    end
                    if (!f_emu_run[dpi] &&
                        g_datapath[dpi].u_datapath.u_emulator_mutrig.ctrl_state_q == AUDIT_RC_RUNNING) begin
                        f_emu_run[dpi] <= 1'b1;
                        t_emu_run[dpi] <= $time;
                    end
                    `WATCH_ENUM("frcv",  g_datapath[dpi].u_datapath.u_frame_rcv.run_state_cmd,
                                f_frcv_sync[dpi],  t_frcv_sync[dpi],
                                f_frcv_run[dpi],   t_frcv_run[dpi])
                    `WATCH_ENUM("mts",   g_datapath[dpi].u_datapath.u_mts.run_state_cmd,
                                f_mts_sync[dpi],   t_mts_sync[dpi],
                                f_mts_run[dpi],    t_mts_run[dpi])
                    `WATCH_ENUM("ffa_d", g_datapath[dpi].u_datapath.u_ffa.d_run_state_cmd,
                                f_ffa_d_sync[dpi], t_ffa_d_sync[dpi],
                                f_ffa_d_run[dpi],  t_ffa_d_run[dpi])
                    `WATCH_ENUM("ffa_x", g_datapath[dpi].u_datapath.u_ffa.x_run_state_cmd,
                                f_ffa_x_sync[dpi], t_ffa_x_sync[dpi],
                                f_ffa_x_run[dpi],  t_ffa_x_run[dpi])
                end
            end
            for (genvar rbi = 0; rbi < 4; rbi++) begin : g_state_audit_rb
                always_ff @(posedge clk_ref) begin
                    if (!rst) begin
                        `WATCH_ENUM("rbcam",
                            g_datapath[dpi].u_datapath.g_rbcam[rbi].u_rbcam.v2_core.run_state_cmd,
                            f_rbcam_sync[dpi][rbi], t_rbcam_sync[dpi][rbi],
                            f_rbcam_run[dpi][rbi],  t_rbcam_run[dpi][rbi])
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_ref) begin
        if (!rst && !f_swb_gate_run && gate_open) begin
            f_swb_gate_run <= 1'b1;
            t_swb_gate_run <= $time;
        end
    end

`define CHECK_EDGE_SYNC(LABEL, SEEN, TS, REF_SEEN, REF_TS)                                        \
    if (!(SEEN)) begin                                                                             \
        $error("[run_audit] %s never observed", LABEL);                                            \
    end else if (!(REF_SEEN)) begin                                                                \
        REF_SEEN = 1'b1;                                                                           \
        REF_TS   = TS;                                                                             \
    end else if ((TS) != (REF_TS)) begin                                                           \
        $error("[run_audit] %s skewed: observed=%0t reference=%0t", LABEL, TS, REF_TS);           \
    end


`undef CHECK_EDGE_SYNC

    // ----- UVM start -------------------------------------------------------
    import uvm_pkg::*;
    import tb_int_pkg::*;
    `include "uvm_macros.svh"

    initial begin
        uvm_config_db#(virtual hit_type0_if)::set(null, "uvm_test_top*", "stage_h0_lane0_if", stage_h0_if[0]);
        uvm_config_db#(virtual hit_type0_if)::set(null, "uvm_test_top*", "stage_h0_lane1_if", stage_h0_if[1]);
        uvm_config_db#(virtual hit_type0_if)::set(null, "uvm_test_top*", "stage_h0_lane2_if", stage_h0_if[2]);
        uvm_config_db#(virtual hit_type0_if)::set(null, "uvm_test_top*", "stage_h0_lane3_if", stage_h0_if[3]);
        uvm_config_db#(virtual hit_type1_if)::set(null, "uvm_test_top*", "stage_h1_lane0_if", stage_h1_if[0]);
        uvm_config_db#(virtual hit_type1_if)::set(null, "uvm_test_top*", "stage_h1_lane1_if", stage_h1_if[1]);
        uvm_config_db#(virtual hit_type1_if)::set(null, "uvm_test_top*", "stage_h1_lane2_if", stage_h1_if[2]);
        uvm_config_db#(virtual hit_type1_if)::set(null, "uvm_test_top*", "stage_h1_lane3_if", stage_h1_if[3]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane0_slot0_if", stage_b_if[0][0]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane0_slot1_if", stage_b_if[0][1]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane0_slot2_if", stage_b_if[0][2]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane0_slot3_if", stage_b_if[0][3]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane1_slot0_if", stage_b_if[1][0]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane1_slot1_if", stage_b_if[1][1]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane1_slot2_if", stage_b_if[1][2]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane1_slot3_if", stage_b_if[1][3]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane2_slot0_if", stage_b_if[2][0]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane2_slot1_if", stage_b_if[2][1]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane2_slot2_if", stage_b_if[2][2]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane2_slot3_if", stage_b_if[2][3]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane3_slot0_if", stage_b_if[3][0]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane3_slot1_if", stage_b_if[3][1]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane3_slot2_if", stage_b_if[3][2]);
        uvm_config_db#(virtual hit_type2_if)::set(null, "uvm_test_top*", "stage_b_lane3_slot3_if", stage_b_if[3][3]);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane0_if", lane0_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane1_if", lane1_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane2_if", lane2_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane3_if", lane3_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_c_lane0_if", lane0_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_c_lane1_if", lane1_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_c_lane2_if", lane2_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_c_lane3_if", lane3_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_d_lane0_if", gate0_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_d_lane1_if", gate1_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_d_lane2_if", gate2_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "stage_d_lane3_if", gate3_if);
        uvm_config_db#(virtual opq_egress_if)::set (null, "uvm_test_top*", "egress_if", egress_if);
        uvm_config_db#(virtual opq_csr_if)::set    (null, "uvm_test_top*", "csr_if",    csr_if);
        uvm_config_db#(virtual emut_avmm_csr_if.drv)::set(null, "uvm_test_top*", "emu_csr_lane0_if", emu_csr_if[0]);
        uvm_config_db#(virtual emut_avmm_csr_if.drv)::set(null, "uvm_test_top*", "emu_csr_lane1_if", emu_csr_if[1]);
        uvm_config_db#(virtual emut_avmm_csr_if.drv)::set(null, "uvm_test_top*", "emu_csr_lane2_if", emu_csr_if[2]);
        uvm_config_db#(virtual emut_avmm_csr_if.drv)::set(null, "uvm_test_top*", "emu_csr_lane3_if", emu_csr_if[3]);
        uvm_config_db#(virtual run_control_if)::set(null, "uvm_test_top*", "rc_if",     rc_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a0_if", stage_a0_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a1_if", stage_a1_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a2_if", stage_a2_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a3_if", stage_a3_if);
        run_test();
    end

endmodule

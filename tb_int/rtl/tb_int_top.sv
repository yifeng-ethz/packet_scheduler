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
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane0_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane1_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane2_if (.clk(clk_ref), .rst(rst));
    opq_ingress_if #(.DATA_W(36), .CH_W(2)) lane3_if (.clk(clk_ref), .rst(rst));
    opq_egress_if  #(.DATA_W(36))           egress_if(.clk(clk_ref), .rst(rst));
    opq_csr_if     #(.ADDR_W(9))            csr_if   (.clk(clk_ref), .rst(rst));
    run_control_if                          rc_if    (.clk(clk_ref), .rst(rst));

    // Stage A taps (hit_generator FIFO commit per datapath)
    stage_a_if stage_a0_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a1_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a2_if (.clk(clk_ref), .rst(rst));
    stage_a_if stage_a3_if (.clk(clk_ref), .rst(rst));

    // ----- 4 datapath_stubs driving the 4 OPQ lanes -----------------------
    // The OPQ runs in MERGING mode: its page allocator requires every lane to
    // either hold a pending ticket or have asserted alert_eop before it will
    // release a frame. A single active lane never satisfies that condition,
    // so Phase 2 already instantiates 4 full datapath chains. This matches
    // the final 2 FEB × 2 datapath × 4 lane topology from DV_INT_PLAN.md.
    logic [35:0] dp_data  [4];
    logic        dp_valid [4];
    logic        dp_sop   [4];
    logic        dp_eop   [4];
    logic        dp_prep_ready [4];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi++) begin : g_datapath
            datapath_stub #(
                .FEB_ID      (gi / 2),
                .DATAPATH_ID (gi % 2)
            ) u_datapath (
                .i_clk                  (clk_ref),
                .i_rst                  (rst),
                .ctrl_data              (rc_if.run_state),
                .ctrl_valid             (1'b1),
                .aso_lane_data          (dp_data [gi]),
                .aso_lane_valid         (dp_valid[gi]),
                .aso_lane_startofpacket (dp_sop  [gi]),
                .aso_lane_endofpacket   (dp_eop  [gi]),
                .aso_lane_ready         (1'b1),  // swb_ingress_stub is always ready
                .prep_ready             (dp_prep_ready[gi])
            );
        end
    endgenerate

    // AND-reduce PREP-ready across all 4 datapaths and surface it on the
    // run_control_if so the UVM driver can block in RUN_PREPARE until every
    // child IP of every datapath has acknowledged. ring_buffer_cam dominates
    // (~131072 cycles to walk its CAM/RAM in RUN_PREPARE).
    assign rc_if.prep_done = dp_prep_ready[0] & dp_prep_ready[1]
                           & dp_prep_ready[2] & dp_prep_ready[3];

    assign lane0_if.data          = dp_data [0];
    assign lane0_if.valid         = dp_valid[0];
    assign lane0_if.channel       = 2'b00;
    assign lane0_if.startofpacket = dp_sop  [0];
    assign lane0_if.endofpacket   = dp_eop  [0];
    assign lane0_if.error         = 3'b000;

    assign lane1_if.data          = dp_data [1];
    assign lane1_if.valid         = dp_valid[1];
    assign lane1_if.channel       = 2'b01;
    assign lane1_if.startofpacket = dp_sop  [1];
    assign lane1_if.endofpacket   = dp_eop  [1];
    assign lane1_if.error         = 3'b000;

    assign lane2_if.data          = dp_data [2];
    assign lane2_if.valid         = dp_valid[2];
    assign lane2_if.channel       = 2'b10;
    assign lane2_if.startofpacket = dp_sop  [2];
    assign lane2_if.endofpacket   = dp_eop  [2];
    assign lane2_if.error         = 3'b000;

    assign lane3_if.data          = dp_data [3];
    assign lane3_if.valid         = dp_valid[3];
    assign lane3_if.channel       = 2'b11;
    assign lane3_if.startofpacket = dp_sop  [3];
    assign lane3_if.endofpacket   = dp_eop  [3];
    assign lane3_if.error         = 3'b000;

    // Stage A drivers — reach into hit_generator commit edge for each
    // datapath. The `valid` pulse fires on posedge clk whenever the
    // hit_generator latches a new hit into its FIFO (hit_wr_en is the
    // registered commit strobe, qualified by fifo_full).
    assign stage_a0_if.valid   = g_datapath[0].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_en &&
                                 !g_datapath[0].u_datapath.u_emulator_mutrig.u_hit_gen.fifo_full;
    assign stage_a0_if.payload = g_datapath[0].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_data;
    assign stage_a0_if.feb_id      = 2'd0;
    assign stage_a0_if.datapath_id = 1'd0;
    assign stage_a0_if.mutrig_ch   = 3'd0;

    assign stage_a1_if.valid   = g_datapath[1].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_en &&
                                 !g_datapath[1].u_datapath.u_emulator_mutrig.u_hit_gen.fifo_full;
    assign stage_a1_if.payload = g_datapath[1].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_data;
    assign stage_a1_if.feb_id      = 2'd0;
    assign stage_a1_if.datapath_id = 1'd1;
    assign stage_a1_if.mutrig_ch   = 3'd0;

    assign stage_a2_if.valid   = g_datapath[2].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_en &&
                                 !g_datapath[2].u_datapath.u_emulator_mutrig.u_hit_gen.fifo_full;
    assign stage_a2_if.payload = g_datapath[2].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_data;
    assign stage_a2_if.feb_id      = 2'd1;
    assign stage_a2_if.datapath_id = 1'd0;
    assign stage_a2_if.mutrig_ch   = 3'd0;

    assign stage_a3_if.valid   = g_datapath[3].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_en &&
                                 !g_datapath[3].u_datapath.u_emulator_mutrig.u_hit_gen.fifo_full;
    assign stage_a3_if.payload = g_datapath[3].u_datapath.u_emulator_mutrig.u_hit_gen.hit_wr_data;
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
    // tb_int_pkg. No default assign here — the driver initializes both on
    // its run_phase start.

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

            if (dp_valid[0]) cnt_lane[0] <= cnt_lane[0] + 1;
            if (dp_valid[1]) cnt_lane[1] <= cnt_lane[1] + 1;
            if (dp_valid[2]) cnt_lane[2] <= cnt_lane[2] + 1;
            if (dp_valid[3]) cnt_lane[3] <= cnt_lane[3] + 1;

            if (egress_if.valid && egress_if.ready) cnt_egress <= cnt_egress + 1;
        end
    end

    final begin
        $display("[tb_int_top] emu=(%0d,%0d,%0d,%0d) h0=(%0d,%0d,%0d,%0d) h1=(%0d,%0d,%0d,%0d) lane=(%0d,%0d,%0d,%0d) egress=%0d",
                 cnt_emu_tx[0], cnt_emu_tx[1], cnt_emu_tx[2], cnt_emu_tx[3],
                 cnt_h0[0],     cnt_h0[1],     cnt_h0[2],     cnt_h0[3],
                 cnt_h1[0],     cnt_h1[1],     cnt_h1[2],     cnt_h1[3],
                 cnt_lane[0],   cnt_lane[1],   cnt_lane[2],   cnt_lane[3],
                 cnt_egress);
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

    // Per-IP run_state_cmd shadow: reads the VHDL enum register of each IP
    // via hierarchical reference and watches for the cycle on which it
    // transitions to SYNC and to RUNNING. If the broadcast is wired
    // identically, every IP should fire on the same cycle.
    //
    // Probed IPs per datapath:
    //   [0] frame_rcv    : g_datapath[i].u_datapath.u_frame_rcv.run_state_cmd
    //   [1] mts          : g_datapath[i].u_datapath.u_mts.run_state_cmd
    //   [2] rbcam[0..3]  : g_datapath[i].u_datapath.g_rbcam[k].u_rbcam.v2_core.run_state_cmd
    //   [3] ffa datapath : g_datapath[i].u_datapath.u_ffa.d_run_state_cmd
    //   [4] ffa xcvr     : g_datapath[i].u_datapath.u_ffa.x_run_state_cmd
    //
    // VHDL enum literal positions (from feb_frame_assembly.vhd line 551):
    //   IDLE=0, RUN_PREPARE=1, SYNC=2, RUNNING=3, TERMINATING=4, ...
    localparam int RC_ENUM_SYNC    = 2;
    localparam int RC_ENUM_RUNNING = 3;

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
                    if (!seen_lane[dpi] && dp_valid[dpi]) begin
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

    final begin
        $display("[run_audit] broadcast: t_bc_sync=%0t t_bc_running=%0t",
                 t_bc_sync, t_bc_running);
        for (int i = 0; i < 4; i++) begin
            $display("[run_audit] dp%0d sync : frcv=%0t mts=%0t rbcam=(%0t,%0t,%0t,%0t) ffa_d=%0t ffa_x=%0t",
                     i, t_frcv_sync[i], t_mts_sync[i],
                     t_rbcam_sync[i][0], t_rbcam_sync[i][1],
                     t_rbcam_sync[i][2], t_rbcam_sync[i][3],
                     t_ffa_d_sync[i], t_ffa_x_sync[i]);
            $display("[run_audit] dp%0d run  : frcv=%0t mts=%0t rbcam=(%0t,%0t,%0t,%0t) ffa_d=%0t ffa_x=%0t",
                     i, t_frcv_run[i], t_mts_run[i],
                     t_rbcam_run[i][0], t_rbcam_run[i][1],
                     t_rbcam_run[i][2], t_rbcam_run[i][3],
                     t_ffa_d_run[i], t_ffa_x_run[i]);
            $display("[run_audit] dp%0d first-beat: emu_tx=%0t h0=%0t h1=%0t h2=(%0t,%0t,%0t,%0t) lane=%0t",
                     i, t_first_emu_tx[i], t_first_h0[i], t_first_h1[i],
                     t_first_h2[i][0], t_first_h2[i][1],
                     t_first_h2[i][2], t_first_h2[i][3],
                     t_first_lane[i]);
        end
    end

    // ----- UVM start -------------------------------------------------------
    import uvm_pkg::*;
    import tb_int_pkg::*;
    `include "uvm_macros.svh"

    initial begin
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane0_if", lane0_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane1_if", lane1_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane2_if", lane2_if);
        uvm_config_db#(virtual opq_ingress_if)::set(null, "uvm_test_top*", "lane3_if", lane3_if);
        uvm_config_db#(virtual opq_egress_if)::set (null, "uvm_test_top*", "egress_if", egress_if);
        uvm_config_db#(virtual opq_csr_if)::set    (null, "uvm_test_top*", "csr_if",    csr_if);
        uvm_config_db#(virtual run_control_if)::set(null, "uvm_test_top*", "rc_if",     rc_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a0_if", stage_a0_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a1_if", stage_a1_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a2_if", stage_a2_if);
        uvm_config_db#(virtual stage_a_if)::set   (null, "uvm_test_top*", "stage_a3_if", stage_a3_if);
        run_test();
    end

endmodule

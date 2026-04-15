// ---------------------------------------------------------------------------
// IP Name    : datapath_stub
// Author     : Yifeng Wang (yifenwan@phys.ethz.ch)
// Description:
//   Phase 2 walking skeleton of one FEB datapath side (up or down), wiring
//   the real IP chain:
//
//     emulator_mutrig (1 chip)
//         -> frame_rcv_ip          (mutrig_frame_deassembly)
//         -> mts_processor         (mutrig_timestamp_processor)
//         -> ring_buffer_cam x 4   (one per INTERLEAVING_INDEX 0..3)
//         -> feb_frame_assembly
//         -> aso_hit_type3 (36-bit AvST, one OPQ lane)
//
//   Phase 2 simplification:
//     - 1 emulator_mutrig, not 4. No mux_mutrig2processor: we feed
//       mts_processor directly with the frame_rcv hit_type0 stream and
//       pad the 6-bit channel with the upper 2 mux-sel bits tied to 00.
//     - Single clock domain (i_clk). feb_frame_assembly's xcvr/datapath
//       clocks are both tied to i_clk, same for resets. This matches the
//       Qsys zero-latency pass-through the plan locks for tb_int.
//     - CSR buses of every child IP are tied to their idle state. The
//       emulator_mutrig powers up with csr_enable=1 by default; frame_rcv,
//       mts_processor, ring_buffer_cam and feb_frame_assembly all come out
//       of reset in a pass-through configuration.
//
//   The 9-bit one-hot run control stream is broadcast to every child's
//   asi_ctrl_* sink. All ready outputs are ignored (these IPs hold ctrl
//   ready high when idle and ingest each write cycle).
// ---------------------------------------------------------------------------

`timescale 1ns/1ps

module datapath_stub #(
    parameter int FEB_ID      = 0,
    parameter int DATAPATH_ID = 0
) (
    input  logic        i_clk,
    input  logic        i_rst,

    // 9-bit one-hot run control
    input  logic [8:0]  ctrl_data,
    input  logic        ctrl_valid,

    // Lane output to the OPQ (matches opq_ingress_if, 36-bit)
    output logic [35:0] aso_lane_data,
    output logic        aso_lane_valid,
    output logic        aso_lane_startofpacket,
    output logic        aso_lane_endofpacket,
    input  logic        aso_lane_ready,

    // AND-reduce of every child IP's asi_ctrl_ready. The run-control driver
    // uses this to know when the slowest IP (ring_buffer_cam, ~131k cycles
    // of CAM/RAM flush) has finished its PREPARE phase, and therefore when
    // it is safe to advance to SYNC. Without this gating, SYNC arrives mid-
    // flush and the rb_cam emits no h2 beats until the flush is over,
    // wasting most of the run window.
    output logic        prep_ready
);

    // Zero literals sized to match VHDL sinks (mixed-language width checks)
    logic [31:0] zero32;
    logic [4:0]  zero5;
    logic [3:0]  zero4;
    logic [2:0]  zero3;
    logic [1:0]  zero2;
    assign zero32 = 32'b0;
    assign zero5  = 5'b0;
    assign zero4  = 4'b0;
    assign zero3  = 3'b0;
    assign zero2  = 2'b0;

    // -----------------------------------------------------------------------
    // Per-IP run-control ready bits (collected for prep_ready AND-reduce).
    // -----------------------------------------------------------------------
    logic emu_ctrl_ready;
    logic frcv_ctrl_ready;
    logic mts_ctrl_ready;
    logic rbcam_ctrl_ready [4];
    logic ffa_ctrl_dpath_ready;
    logic ffa_ctrl_xcvr_ready;

    assign prep_ready = emu_ctrl_ready
                      & frcv_ctrl_ready
                      & mts_ctrl_ready
                      & rbcam_ctrl_ready[0] & rbcam_ctrl_ready[1]
                      & rbcam_ctrl_ready[2] & rbcam_ctrl_ready[3]
                      & ffa_ctrl_dpath_ready & ffa_ctrl_xcvr_ready;

    // -----------------------------------------------------------------------
    // emulator_mutrig -> frame_rcv_ip  (8b1k, 9-bit)
    // -----------------------------------------------------------------------
    logic [8:0] emu_tx_data;
    logic       emu_tx_valid;
    logic [3:0] emu_tx_channel;
    logic [2:0] emu_tx_error;

    emulator_mutrig #(
        .FIFO_DEPTH     (64),
        .CSR_ADDR_WIDTH (4)
    ) u_emulator_mutrig (
        .i_clk               (i_clk),
        .i_rst               (i_rst),
        .aso_tx8b1k_data     (emu_tx_data),
        .aso_tx8b1k_valid    (emu_tx_valid),
        .aso_tx8b1k_channel  (emu_tx_channel),
        .aso_tx8b1k_error    (emu_tx_error),
        .asi_ctrl_data       (ctrl_data),
        .asi_ctrl_valid      (ctrl_valid),
        .asi_ctrl_ready      (emu_ctrl_ready),
        .coe_inject_pulse    (1'b0),
        .avs_csr_address     (zero4),
        .avs_csr_read        (1'b0),
        .avs_csr_write       (1'b0),
        .avs_csr_writedata   (zero32),
        .avs_csr_readdata    (/*unused*/),
        .avs_csr_waitrequest (/*unused*/)
    );

    // -----------------------------------------------------------------------
    // frame_rcv_ip  (hit_type0 : 45b, 4-bit channel)
    // -----------------------------------------------------------------------
    logic [3:0]  h0_channel;
    logic        h0_sop;
    logic        h0_eop;
    logic [2:0]  h0_error;
    logic [44:0] h0_data;
    logic        h0_valid;
    logic [41:0] hi_data;
    logic        hi_valid;
    logic [3:0]  hi_channel;

    frame_rcv_ip #(
        .CHANNEL_WIDTH (4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT     (0),
        .DEBUG_LV      (0)
    ) u_frame_rcv (
        .asi_rx8b1k_data            (emu_tx_data),
        .asi_rx8b1k_valid           (emu_tx_valid),
        .asi_rx8b1k_error           (emu_tx_error),
        .asi_rx8b1k_channel         (emu_tx_channel),

        .aso_hit_type0_channel      (h0_channel),
        .aso_hit_type0_startofpacket(h0_sop),
        .aso_hit_type0_endofpacket  (h0_eop),
        .aso_hit_type0_error        (h0_error),
        .aso_hit_type0_data         (h0_data),
        .aso_hit_type0_valid        (h0_valid),

        .aso_headerinfo_data        (hi_data),
        .aso_headerinfo_valid       (hi_valid),
        .aso_headerinfo_channel     (hi_channel),

        .avs_csr_readdata           (/*unused*/),
        .avs_csr_read               (1'b0),
        .avs_csr_address            (zero2),
        .avs_csr_waitrequest        (/*unused*/),
        .avs_csr_write              (1'b0),
        .avs_csr_writedata          (zero32),

        .asi_ctrl_data              (ctrl_data),
        .asi_ctrl_valid             (ctrl_valid),
        .asi_ctrl_ready             (frcv_ctrl_ready),

        .i_rst                      (i_rst),
        .i_clk                      (i_clk)
    );

    // -----------------------------------------------------------------------
    // mts_processor  (hit_type1 : 39b, 4-bit channel)
    //
    // mts_processor expects a 6-bit channel where [5:4] is the mux_sel
    // (which mutrig among the 4). With one mutrig we pad [5:4] = 2'b00.
    // -----------------------------------------------------------------------
    logic [5:0]  h0_channel6;
    assign h0_channel6 = {2'b00, h0_channel};

    logic [3:0]  h1_channel;
    logic        h1_sop;
    logic        h1_eop;
    logic [38:0] h1_data;
    logic        h1_valid;
    logic        h1_ready;
    logic        h1_empty;
    logic        h1_error;

    mts_processor #(
        .FRAME_CORRPT_BIT_LOC (2),
        .CRCERR_BIT_LOC       (1),
        .HITERR_BIT_LOC       (0),
        .BANK                 ("UP"),
        .ENABLED_CHANNEL_HI   (3),
        .ENABLED_CHANNEL_LO   (0),
        .PADDING_EOP_WAIT_CYCLE (512),
        .LPM_DIV_PIPELINE     (4),
        .MUTRIG_BUFFER_EXPECTED_LATENCY_8N (2000),
        .DEBUG                (1)
    ) u_mts (
        .avs_csr_readdata           (/*unused*/),
        .avs_csr_read               (1'b0),
        .avs_csr_address            (zero3),
        .avs_csr_waitrequest        (/*unused*/),
        .avs_csr_write              (1'b0),
        .avs_csr_writedata          (zero32),

        .asi_hit_type0_channel      (h0_channel6),
        .asi_hit_type0_startofpacket(h0_sop),
        .asi_hit_type0_endofpacket  (h0_eop),
        .asi_hit_type0_error        (h0_error),
        .asi_hit_type0_data         (h0_data),
        .asi_hit_type0_valid        (h0_valid),
        .asi_hit_type0_ready        (/*unused*/),

        .aso_hit_type1_channel      (h1_channel),
        .aso_hit_type1_startofpacket(h1_sop),
        .aso_hit_type1_endofpacket  (h1_eop),
        .aso_hit_type1_data         (h1_data),
        .aso_hit_type1_valid        (h1_valid),
        .aso_hit_type1_ready        (h1_ready),
        .aso_hit_type1_empty        (h1_empty),
        .aso_hit_type1_error        (h1_error),

        .asi_ctrl_data              (ctrl_data),
        .asi_ctrl_valid             (ctrl_valid),
        .asi_ctrl_ready             (mts_ctrl_ready),

        .aso_debug_ts_valid         (/*unused*/),
        .aso_debug_ts_data          (/*unused*/),
        .aso_debug_burst_valid      (/*unused*/),
        .aso_debug_burst_data       (/*unused*/),
        .aso_ts_delta_valid         (/*unused*/),
        .aso_ts_delta_data          (/*unused*/),

        .i_rst                      (i_rst),
        .i_clk                      (i_clk)
    );

    // -----------------------------------------------------------------------
    // ring_buffer_cam x 4  (one per INTERLEAVING_INDEX)
    //
    // Each rb_cam sees the same hit_type1 stream and internally keeps only
    // hits whose timestamp slot matches its INTERLEAVING_INDEX modulo
    // INTERLEAVING_FACTOR. Its hit_type2 output then feeds its own lane of
    // feb_frame_assembly.
    // -----------------------------------------------------------------------
    logic [3:0]   h2_channel  [4];
    logic         h2_sop      [4];
    logic         h2_eop      [4];
    logic [35:0]  h2_data     [4];
    logic         h2_valid    [4];
    logic         h2_ready    [4];
    logic         h2_error    [4];
    logic         h1_ready_v  [4];

    assign h1_ready = h1_ready_v[0] & h1_ready_v[1] & h1_ready_v[2] & h1_ready_v[3];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi++) begin : g_rbcam
            ring_buffer_cam #(
                .SEARCH_KEY_WIDTH    (8),
                .RING_BUFFER_N_ENTRY (512),
                .SIDE_DATA_BITS      (31),
                .INTERLEAVING_FACTOR (4),
                .INTERLEAVING_INDEX  (gi),
                .N_PARTITIONS        (4),
                .ENCODER_LEAF_WIDTH  (16),
                .ENCODER_PIPE_STAGES (4),
                .DEBUG               (1)
            ) u_rbcam (
                .avs_csr_readdata           (/*unused*/),
                .avs_csr_read               (1'b0),
                .avs_csr_address            (zero5),
                .avs_csr_waitrequest        (/*unused*/),
                .avs_csr_write              (1'b0),
                .avs_csr_writedata          (zero32),

                .asi_hit_type1_channel      (h1_channel),
                .asi_hit_type1_startofpacket(h1_sop),
                .asi_hit_type1_endofpacket  (h1_eop),
                .asi_hit_type1_data         (h1_data),
                .asi_hit_type1_valid        (h1_valid),
                .asi_hit_type1_ready        (h1_ready_v[gi]),
                .asi_hit_type1_error        (h1_error),

                .aso_hit_type2_channel      (h2_channel[gi]),
                .aso_hit_type2_startofpacket(h2_sop[gi]),
                .aso_hit_type2_endofpacket  (h2_eop[gi]),
                .aso_hit_type2_data         (h2_data[gi]),
                .aso_hit_type2_valid        (h2_valid[gi]),
                .aso_hit_type2_ready        (h2_ready[gi]),
                .aso_hit_type2_error        (h2_error[gi]),

                .i_clk                      (i_clk),
                .i_rst                      (i_rst),

                .asi_ctrl_data              (ctrl_data),
                .asi_ctrl_valid             (ctrl_valid),
                .asi_ctrl_ready             (rbcam_ctrl_ready[gi]),

                .aso_filllevel_data         (/*unused*/),
                .aso_filllevel_valid        (/*unused*/)
            );
        end
    endgenerate

    // -----------------------------------------------------------------------
    // feb_frame_assembly  (single domain: datapath=xcvr=i_clk)
    // -----------------------------------------------------------------------
    feb_frame_assembly #(
        .INTERLEAVING_FACTOR (4),
        .N_SHD               (256),
        .DEBUG               (1)
    ) u_ffa (
        .asi_hit_type2_0_channel      (h2_channel[0]),
        .asi_hit_type2_0_startofpacket(h2_sop[0]),
        .asi_hit_type2_0_endofpacket  (h2_eop[0]),
        .asi_hit_type2_0_data         (h2_data[0]),
        .asi_hit_type2_0_valid        (h2_valid[0]),
        .asi_hit_type2_0_ready        (h2_ready[0]),
        .asi_hit_type2_0_error        (h2_error[0]),

        .asi_hit_type2_1_channel      (h2_channel[1]),
        .asi_hit_type2_1_startofpacket(h2_sop[1]),
        .asi_hit_type2_1_endofpacket  (h2_eop[1]),
        .asi_hit_type2_1_data         (h2_data[1]),
        .asi_hit_type2_1_valid        (h2_valid[1]),
        .asi_hit_type2_1_ready        (h2_ready[1]),
        .asi_hit_type2_1_error        (h2_error[1]),

        .asi_hit_type2_2_channel      (h2_channel[2]),
        .asi_hit_type2_2_startofpacket(h2_sop[2]),
        .asi_hit_type2_2_endofpacket  (h2_eop[2]),
        .asi_hit_type2_2_data         (h2_data[2]),
        .asi_hit_type2_2_valid        (h2_valid[2]),
        .asi_hit_type2_2_ready        (h2_ready[2]),
        .asi_hit_type2_2_error        (h2_error[2]),

        .asi_hit_type2_3_channel      (h2_channel[3]),
        .asi_hit_type2_3_startofpacket(h2_sop[3]),
        .asi_hit_type2_3_endofpacket  (h2_eop[3]),
        .asi_hit_type2_3_data         (h2_data[3]),
        .asi_hit_type2_3_valid        (h2_valid[3]),
        .asi_hit_type2_3_ready        (h2_ready[3]),
        .asi_hit_type2_3_error        (h2_error[3]),

        .aso_hit_type3_startofpacket  (aso_lane_startofpacket),
        .aso_hit_type3_endofpacket    (aso_lane_endofpacket),
        .aso_hit_type3_data           (aso_lane_data),
        .aso_hit_type3_valid          (aso_lane_valid),
        .aso_hit_type3_ready          (aso_lane_ready),

        .asi_ctrl_datapath_data       (ctrl_data),
        .asi_ctrl_datapath_valid      (ctrl_valid),
        .asi_ctrl_datapath_ready      (ffa_ctrl_dpath_ready),
        .asi_ctrl_xcvr_data           (ctrl_data),
        .asi_ctrl_xcvr_valid          (ctrl_valid),
        .asi_ctrl_xcvr_ready          (ffa_ctrl_xcvr_ready),

        .avs_csr_readdata             (/*unused*/),
        .avs_csr_read                 (1'b0),
        .avs_csr_address              (zero4),
        .avs_csr_waitrequest          (/*unused*/),
        .avs_csr_write                (1'b0),
        .avs_csr_writedata            (zero32),

        .aso_debug_ts_data            (/*unused*/),
        .aso_debug_ts_valid           (/*unused*/),
        .aso_debug_burst_valid        (/*unused*/),
        .aso_debug_burst_data         (/*unused*/),
        .aso_ts_delta_valid           (/*unused*/),
        .aso_ts_delta_data            (/*unused*/),
        .aso_debug_filllevel_valid    (/*unused*/),
        .aso_debug_filllevel_data     (/*unused*/),
        .aso_debug_loss8fill_valid    (/*unused*/),
        .aso_debug_loss8fill_data     (/*unused*/),
        .aso_debug_delay8loss_valid   (/*unused*/),
        .aso_debug_delay8loss_data    (/*unused*/),

        .i_clk_xcvr       (i_clk),
        .i_clk_datapath   (i_clk),
        .i_rst_xcvr       (i_rst),
        .i_rst_datapath   (i_rst)
    );

endmodule

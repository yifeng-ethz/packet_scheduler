//------------------------------------------------------------------------------
// opq_native_sv_feature_signoff_top
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.4.0
// Date    : 20260424
// Change  : Keep standalone stimulus reset synchronous so TimeQuest only signs
//           off the OPQ datapath clock
//------------------------------------------------------------------------------

`ifndef OPQ_SYN_N_LANE
`define OPQ_SYN_N_LANE 4
`endif

`ifndef OPQ_SYN_N_SHD
`define OPQ_SYN_N_SHD 128
`endif

`ifndef OPQ_SYN_PAGE_RAM_RD_WIDTH
`define OPQ_SYN_PAGE_RAM_RD_WIDTH 36
`endif

`ifndef OPQ_SYN_TICKET_FIFO_DEPTH
`define OPQ_SYN_TICKET_FIFO_DEPTH 4096
`endif

`ifndef OPQ_SYN_LANE_FIFO_DEPTH
`define OPQ_SYN_LANE_FIFO_DEPTH 2048
`endif

module opq_native_sv_feature_signoff_top (
  input  logic        clk,
  input  logic        reset_n,
  output logic [15:0] activity_o
);
  localparam int unsigned N_LANE = `OPQ_SYN_N_LANE;
  localparam int unsigned N_SHD = `OPQ_SYN_N_SHD;
  localparam int unsigned PAGE_RAM_RD_WIDTH = `OPQ_SYN_PAGE_RAM_RD_WIDTH;
  localparam int unsigned TICKET_FIFO_DEPTH = `OPQ_SYN_TICKET_FIFO_DEPTH;
  localparam int unsigned LANE_FIFO_DEPTH = `OPQ_SYN_LANE_FIFO_DEPTH;
  localparam int unsigned CHANNEL_WIDTH = (N_LANE <= 4) ? 2 : $clog2(N_LANE);
  localparam int unsigned INGRESS_DATA_WIDTH = 32;
  localparam int unsigned INGRESS_DATAK_WIDTH = 4;
  localparam int unsigned EGRESS_SYMBOL_WIDTH = INGRESS_DATA_WIDTH + INGRESS_DATAK_WIDTH;
  localparam int unsigned EGRESS_SYMBOLS_PER_BEAT = PAGE_RAM_RD_WIDTH / EGRESS_SYMBOL_WIDTH;
  localparam int unsigned EGRESS_EMPTY_WIDTH =
    (EGRESS_SYMBOLS_PER_BEAT <= 1) ? 1 : $clog2(EGRESS_SYMBOLS_PER_BEAT);
  localparam int unsigned SIGNATURE_WORDS = 16 + N_LANE;

  localparam logic [2:0] PH_PREAMBLE = 3'd0;
  localparam logic [2:0] PH_HDR1 = 3'd1;
  localparam logic [2:0] PH_HDR2 = 3'd2;
  localparam logic [2:0] PH_HDR3 = 3'd3;
  localparam logic [2:0] PH_HDR4 = 3'd4;
  localparam logic [2:0] PH_SUBHEADER = 3'd5;
  localparam logic [2:0] PH_HIT = 3'd6;
  localparam logic [2:0] PH_TRAILER = 3'd7;

  logic d_reset;
  logic [N_LANE-1:0][EGRESS_SYMBOL_WIDTH-1:0]      asi_ingress_data;
  logic [N_LANE-1:0]                                asi_ingress_valid;
  logic [N_LANE-1:0][CHANNEL_WIDTH-1:0]             asi_ingress_channel;
  logic [N_LANE-1:0]                                asi_ingress_startofpacket;
  logic [N_LANE-1:0]                                asi_ingress_endofpacket;
  logic [N_LANE-1:0][2:0]                           asi_ingress_error;
  logic [PAGE_RAM_RD_WIDTH-1:0]                     aso_egress_data;
  logic                                             aso_egress_valid;
  logic                                             aso_egress_ready;
  logic                                             aso_egress_startofpacket;
  logic                                             aso_egress_endofpacket;
  logic [2:0]                                       aso_egress_error;
  logic [EGRESS_EMPTY_WIDTH-1:0]                    aso_egress_empty;
  logic [N_LANE-1:0][9:0]                           cfg_drr_allowance;
  logic [N_LANE-1:0]                                cfg_drr_allowance_reload;
  logic                                             cfg_reload_pulse;
  logic [31:0]                                      heartbeat;
  logic [31:0]                                      egress_accept_count;
  logic [31:0]                                      egress_checksum;
  logic [31:0]                                      egress_data_fold;
  logic [31:0]                                      observed_word [0:SIGNATURE_WORDS-1];
  (* preserve, noprune *) logic [31:0]              activity_tap_q [0:SIGNATURE_WORDS-1];
  logic [15:0]                                      activity_fold;

  function automatic logic [35:0] make_preamble_word(
    input logic [5:0] dt_type,
    input logic [15:0] feb_id
  );
    begin
      make_preamble_word = {4'b0001, dt_type, 2'b00, feb_id, 8'hBC};
    end
  endfunction

  function automatic logic [35:0] make_header_word(
    input logic [7:0] kind,
    input logic [7:0] lane_id,
    input logic [15:0] pkt_id
  );
    begin
      make_header_word = {4'b0000, kind, lane_id, pkt_id};
    end
  endfunction

  function automatic logic [35:0] make_subheader_word(
    input logic [7:0] shd_ts,
    input logic [7:0] shd_tag,
    input logic [7:0] hit_count
  );
    begin
      make_subheader_word = {4'b0001, shd_ts, shd_tag, hit_count, 8'hF7};
    end
  endfunction

  function automatic logic [35:0] make_hit_word(
    input logic [7:0] lane_id,
    input logic [15:0] pkt_id,
    input logic [7:0] hit_idx
  );
    begin
      make_hit_word = {4'b0000, (8'h40 | lane_id), pkt_id, hit_idx};
    end
  endfunction

  function automatic logic [35:0] make_trailer_word(
    input logic [7:0] lane_id,
    input logic [15:0] pkt_id
  );
    begin
      make_trailer_word = {4'b0001, 8'hA0 | lane_id, pkt_id, 8'h9C};
    end
  endfunction

  assign d_reset = !reset_n;
  assign cfg_drr_allowance_reload = {N_LANE{cfg_reload_pulse}};

  genvar cfg_lane;
  generate
    for (cfg_lane = 0; cfg_lane < N_LANE; cfg_lane = cfg_lane + 1) begin : g_cfg
      localparam logic [CHANNEL_WIDTH-1:0] CHANNEL_ID = cfg_lane[CHANNEL_WIDTH-1:0];

      assign asi_ingress_channel[cfg_lane] = CHANNEL_ID;
      assign asi_ingress_error[cfg_lane] = 3'b000;
      assign cfg_drr_allowance[cfg_lane] = 10'd128;
    end
  endgenerate

  always_comb begin : proc_egress_data_fold
    egress_data_fold = '0;
    for (int b = 0; b < PAGE_RAM_RD_WIDTH; b++) begin
      egress_data_fold[b % 32] = egress_data_fold[b % 32] ^ aso_egress_data[b];
    end
  end

  always_comb begin : proc_observed_word
    for (int w = 0; w < SIGNATURE_WORDS; w++) begin
      observed_word[w] = '0;
    end

    observed_word[0] = heartbeat;
    observed_word[1] = egress_accept_count;
    observed_word[2] = egress_checksum;
    observed_word[3] = egress_data_fold;
    observed_word[4] = {27'd0, aso_egress_error, aso_egress_startofpacket, aso_egress_endofpacket};
    observed_word[5] = {31'd0, aso_egress_valid};
    observed_word[6] = {31'd0, aso_egress_ready};
    observed_word[7] = {{(32-EGRESS_EMPTY_WIDTH){1'b0}}, aso_egress_empty};
    observed_word[8] = 32'(N_LANE);
    observed_word[9] = 32'(N_SHD);
    observed_word[10] = 32'(PAGE_RAM_RD_WIDTH);
    observed_word[11] = 32'(TICKET_FIFO_DEPTH);
    observed_word[12] = 32'(LANE_FIFO_DEPTH);

    for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
      observed_word[16 + lane_idx] = {
        {(29-CHANNEL_WIDTH){1'b0}},
        asi_ingress_valid[lane_idx],
        asi_ingress_startofpacket[lane_idx],
        asi_ingress_endofpacket[lane_idx],
        asi_ingress_channel[lane_idx]
      } ^ {5'd0, asi_ingress_data[lane_idx][26:0]};
    end
  end

  always_comb begin : proc_activity_fold
    activity_fold = '0;
    for (int w = 0; w < SIGNATURE_WORDS; w++) begin
      activity_fold ^= activity_tap_q[w][15:0] ^ activity_tap_q[w][31:16];
    end
  end

  always_ff @(posedge clk) begin : proc_runtime
    if (!reset_n) begin
      heartbeat <= '0;
      cfg_reload_pulse <= 1'b1;
      aso_egress_ready <= 1'b0;
      egress_accept_count <= '0;
      egress_checksum <= '0;
      for (int w = 0; w < SIGNATURE_WORDS; w++) begin
        activity_tap_q[w] <= 32'hACED_0000 ^ 32'(w);
      end
    end else begin
      heartbeat <= heartbeat + 32'd1;
      cfg_reload_pulse <= 1'b0;
      aso_egress_ready <= heartbeat[0] | heartbeat[3] | !heartbeat[5];
      if (aso_egress_valid && aso_egress_ready) begin
        egress_accept_count <= egress_accept_count + 32'd1;
        egress_checksum <= egress_checksum ^ egress_data_fold ^
          {27'd0, aso_egress_error, aso_egress_startofpacket, aso_egress_endofpacket};
      end
      for (int w = 0; w < SIGNATURE_WORDS; w++) begin
        activity_tap_q[w] <= observed_word[w];
      end
    end
  end

  genvar lane;
  generate
    for (lane = 0; lane < N_LANE; lane = lane + 1) begin : g_lane
      localparam logic [7:0] LANE_ID = lane[7:0];

      logic [2:0] lane_phase_q;
      logic [15:0] lane_pkt_id_q;
      logic [7:0] lane_subh_left_q;
      logic [7:0] lane_hits_left_q;
      logic [7:0] lane_shd_ts_q;

      always_ff @(posedge clk) begin : proc_lane_src
        logic [7:0] next_hit_count_v;

        if (!reset_n) begin
          asi_ingress_data[lane] <= '0;
          asi_ingress_valid[lane] <= 1'b0;
          asi_ingress_startofpacket[lane] <= 1'b0;
          asi_ingress_endofpacket[lane] <= 1'b0;
          lane_phase_q <= PH_PREAMBLE;
          lane_pkt_id_q <= {8'h10, LANE_ID};
          lane_subh_left_q <= 8'd2 + LANE_ID[1:0];
          lane_hits_left_q <= 8'd0;
          lane_shd_ts_q <= 8'h20 + LANE_ID;
        end else begin
          next_hit_count_v =
            ((lane_pkt_id_q[1:0] + lane_subh_left_q[1:0] + LANE_ID[1:0]) & 8'h03) + 8'd1;

          asi_ingress_valid[lane] <= 1'b1;
          asi_ingress_startofpacket[lane] <= 1'b0;
          asi_ingress_endofpacket[lane] <= 1'b0;

          case (lane_phase_q)
            PH_PREAMBLE: begin
              asi_ingress_data[lane] <= make_preamble_word(6'h08 + LANE_ID[5:0], 16'h1200 + lane_pkt_id_q);
              asi_ingress_startofpacket[lane] <= 1'b1;
              lane_phase_q <= PH_HDR1;
            end

            PH_HDR1: begin
              asi_ingress_data[lane] <= make_header_word(8'h11, LANE_ID, lane_pkt_id_q);
              lane_phase_q <= PH_HDR2;
            end

            PH_HDR2: begin
              asi_ingress_data[lane] <= make_header_word(8'h22, LANE_ID, lane_pkt_id_q ^ 16'h1357);
              lane_phase_q <= PH_HDR3;
            end

            PH_HDR3: begin
              asi_ingress_data[lane] <= make_header_word(8'h33, LANE_ID, lane_pkt_id_q ^ 16'h2468);
              lane_phase_q <= PH_HDR4;
            end

            PH_HDR4: begin
              asi_ingress_data[lane] <= make_header_word(8'h44, LANE_ID, lane_pkt_id_q ^ 16'h55AA);
              lane_phase_q <= PH_SUBHEADER;
            end

            PH_SUBHEADER: begin
              asi_ingress_data[lane] <= make_subheader_word(lane_shd_ts_q, lane_subh_left_q, next_hit_count_v);
              lane_hits_left_q <= next_hit_count_v;
              lane_shd_ts_q <= lane_shd_ts_q + 8'd1;
              lane_phase_q <= PH_HIT;
            end

            PH_HIT: begin
              asi_ingress_data[lane] <= make_hit_word(LANE_ID, lane_pkt_id_q, lane_hits_left_q);
              if (lane_hits_left_q == 8'd1) begin
                if (lane_subh_left_q == 8'd1) begin
                  lane_phase_q <= PH_TRAILER;
                end else begin
                  lane_subh_left_q <= lane_subh_left_q - 8'd1;
                  lane_phase_q <= PH_SUBHEADER;
                end
              end
              lane_hits_left_q <= lane_hits_left_q - 8'd1;
            end

            default: begin
              asi_ingress_data[lane] <= make_trailer_word(LANE_ID, lane_pkt_id_q);
              asi_ingress_endofpacket[lane] <= 1'b1;
              lane_pkt_id_q <= lane_pkt_id_q + 16'd1;
              lane_subh_left_q <= 8'd1 + lane_pkt_id_q[2:1] + LANE_ID[1:0];
              lane_phase_q <= PH_PREAMBLE;
            end
          endcase
        end
      end
    end
  endgenerate

  ordered_priority_queue_monolithic_sv #(
    .N_LANE(N_LANE),
    .INGRESS_DATA_WIDTH(INGRESS_DATA_WIDTH),
    .INGRESS_DATAK_WIDTH(INGRESS_DATAK_WIDTH),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(65536),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .N_SHD(N_SHD),
    .DEBUG_LV(0)
  ) dut_i (
    .asi_ingress_data(asi_ingress_data),
    .asi_ingress_valid(asi_ingress_valid),
    .asi_ingress_channel(asi_ingress_channel),
    .asi_ingress_startofpacket(asi_ingress_startofpacket),
    .asi_ingress_endofpacket(asi_ingress_endofpacket),
    .asi_ingress_error(asi_ingress_error),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .aso_egress_empty(aso_egress_empty),
    .cfg_drr_allowance_i(cfg_drr_allowance),
    .cfg_drr_allowance_reload_i(cfg_drr_allowance_reload),
    .d_clk(clk),
    .d_reset(d_reset)
  );

  assign activity_o = activity_fold ^ egress_accept_count[15:0] ^ egress_checksum[15:0];
endmodule

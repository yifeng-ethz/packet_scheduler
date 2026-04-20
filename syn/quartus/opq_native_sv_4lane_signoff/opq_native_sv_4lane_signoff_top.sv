module opq_native_sv_4lane_signoff_top (
  input  logic        clk,
  input  logic        reset_n,
  output logic [15:0] activity_o
);
  localparam int unsigned N_LANE = 4;
  localparam int unsigned CHANNEL_WIDTH = 2;
  localparam int unsigned INGRESS_DATA_WIDTH = 32;
  localparam int unsigned INGRESS_DATAK_WIDTH = 4;
  localparam int unsigned PAGE_RAM_RD_WIDTH = 36;
  localparam logic [2:0] PH_PREAMBLE = 3'd0;
  localparam logic [2:0] PH_HDR1 = 3'd1;
  localparam logic [2:0] PH_HDR2 = 3'd2;
  localparam logic [2:0] PH_HDR3 = 3'd3;
  localparam logic [2:0] PH_HDR4 = 3'd4;
  localparam logic [2:0] PH_SUBHEADER = 3'd5;
  localparam logic [2:0] PH_HIT = 3'd6;
  localparam logic [2:0] PH_TRAILER = 3'd7;

  logic d_reset;
  logic [N_LANE-1:0][INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data;
  logic [N_LANE-1:0]                                              asi_ingress_valid;
  logic [N_LANE-1:0][CHANNEL_WIDTH-1:0]                           asi_ingress_channel;
  logic [N_LANE-1:0]                                              asi_ingress_startofpacket;
  logic [N_LANE-1:0]                                              asi_ingress_endofpacket;
  logic [N_LANE-1:0][2:0]                                         asi_ingress_error;
  logic [PAGE_RAM_RD_WIDTH-1:0]                                   aso_egress_data;
  logic                                                           aso_egress_valid;
  logic                                                           aso_egress_ready;
  logic                                                           aso_egress_startofpacket;
  logic                                                           aso_egress_endofpacket;
  logic [2:0]                                                     aso_egress_error;
  logic [N_LANE-1:0][9:0]                                         cfg_drr_allowance;
  logic [N_LANE-1:0]                                              cfg_drr_allowance_reload;
  logic                                                           cfg_reload_pulse;
  logic [31:0]                                                    heartbeat;
  logic [31:0]                                                    egress_accept_count;
  logic [31:0]                                                    egress_checksum;
  localparam int unsigned SIGNATURE_WORDS = 14;
  (* preserve, noprune *) logic [31:0]                            activity_tap_q [0:SIGNATURE_WORDS-1];
  logic [31:0]                                                    observed_word [0:SIGNATURE_WORDS-1];
  logic [15:0]                                                    activity_fold;
  logic [31:0]                                                    synth_observe_global0;
  logic [31:0]                                                    synth_observe_global1;
  logic [31:0]                                                    synth_observe_global2;
  logic [31:0]                                                    synth_observe_global3;
  logic [31:0]                                                    synth_observe_global4;
  logic [31:0]                                                    synth_observe_global5;
  logic [31:0]                                                    synth_observe_global6;
  logic [31:0]                                                    synth_observe_global7;
  logic [31:0]                                                    synth_observe_global8;
  logic [31:0]                                                    synth_observe_global9;
  logic [N_LANE-1:0][31:0]                                        synth_observe_lane;

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

  genvar cfg_lane;
  generate
    for (cfg_lane = 0; cfg_lane < N_LANE; cfg_lane = cfg_lane + 1) begin : g_cfg
      assign asi_ingress_channel[cfg_lane] = cfg_lane[CHANNEL_WIDTH-1:0];
      assign asi_ingress_error[cfg_lane] = 3'b000;
      if (cfg_lane == 0) begin : g_cfg_lane0
        assign cfg_drr_allowance[cfg_lane] = 10'd32;
      end else begin : g_cfg_lane1
        assign cfg_drr_allowance[cfg_lane] = 10'd48;
      end
    end
  endgenerate

  assign cfg_drr_allowance_reload = {N_LANE{cfg_reload_pulse}};

  always_comb begin : proc_observed_word
    for (int w = 0; w < SIGNATURE_WORDS; w++) begin
      observed_word[w] = '0;
    end

    observed_word[0] = synth_observe_global0;
    observed_word[1] = synth_observe_global1;
    observed_word[2] = synth_observe_global2;
    observed_word[3] = synth_observe_global3;
    observed_word[4] = synth_observe_global4;
    observed_word[5] = synth_observe_global5;
    observed_word[6] = synth_observe_global6;
    observed_word[7] = synth_observe_global7;
    observed_word[8] = synth_observe_global8;
    observed_word[9] = synth_observe_global9;

    for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
      observed_word[10 + lane_idx] = synth_observe_lane[lane_idx];
    end
  end

  always_comb begin : proc_activity_fold
    activity_fold = '0;
    for (int w = 0; w < SIGNATURE_WORDS; w++) begin
      activity_fold ^= activity_tap_q[w][15:0] ^ activity_tap_q[w][31:16];
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin : proc_runtime
    if (!reset_n) begin
      heartbeat <= '0;
      cfg_reload_pulse <= 1'b1;
      aso_egress_ready <= 1'b0;
      egress_accept_count <= '0;
      egress_checksum <= '0;
      for (int w = 0; w < SIGNATURE_WORDS; w++) begin
        activity_tap_q[w] <= 32'hACE0_0000 ^ w;
      end
    end else begin
      heartbeat <= heartbeat + 32'd1;
      cfg_reload_pulse <= 1'b0;
      aso_egress_ready <= heartbeat[0] | heartbeat[3] | !heartbeat[5];
      if (aso_egress_valid && aso_egress_ready) begin
        egress_accept_count <= egress_accept_count + 32'd1;
        egress_checksum <= egress_checksum ^ {aso_egress_error, aso_egress_startofpacket,
          aso_egress_endofpacket, aso_egress_data[26:0]};
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

      always_ff @(posedge clk or negedge reset_n) begin : proc_lane_src
        logic [7:0] next_hit_count_v;

        if (!reset_n) begin
          asi_ingress_data[lane] <= '0;
          asi_ingress_valid[lane] <= 1'b0;
          asi_ingress_startofpacket[lane] <= 1'b0;
          asi_ingress_endofpacket[lane] <= 1'b0;
          lane_phase_q <= PH_PREAMBLE;
          lane_pkt_id_q <= {8'h10, LANE_ID};
          lane_subh_left_q <= 8'd2 + LANE_ID;
          lane_hits_left_q <= 8'd0;
          lane_shd_ts_q <= 8'h20 + LANE_ID;
        end else begin
          next_hit_count_v = ((lane_pkt_id_q[1:0] + lane_subh_left_q[1:0] + LANE_ID[1:0]) & 8'h03) + 8'd1;

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
    .TICKET_FIFO_DEPTH(512),
    .PAGE_RAM_DEPTH(65536),
    .N_SHD(256)
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
    .synth_observe_global0_o(synth_observe_global0),
    .synth_observe_global1_o(synth_observe_global1),
    .synth_observe_global2_o(synth_observe_global2),
    .synth_observe_global3_o(synth_observe_global3),
    .synth_observe_global4_o(synth_observe_global4),
    .synth_observe_global5_o(synth_observe_global5),
    .synth_observe_global6_o(synth_observe_global6),
    .synth_observe_global7_o(synth_observe_global7),
    .synth_observe_global8_o(synth_observe_global8),
    .synth_observe_global9_o(synth_observe_global9),
    .synth_observe_lane_o(synth_observe_lane),
    .cfg_drr_allowance_i(cfg_drr_allowance),
    .cfg_drr_allowance_reload_i(cfg_drr_allowance_reload),
    .d_clk(clk),
    .d_reset(d_reset)
  );

  assign activity_o = activity_fold;
endmodule

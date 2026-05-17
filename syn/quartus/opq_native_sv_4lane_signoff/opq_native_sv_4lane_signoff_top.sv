`ifndef OPQ_N_LANE
`define OPQ_N_LANE 4
`endif

`ifndef OPQ_N_SHD
`define OPQ_N_SHD 128
`endif

`ifndef OPQ_TICKET_FIFO_DEPTH
`define OPQ_TICKET_FIFO_DEPTH 1024
`endif

`ifndef OPQ_PAGE_RAM_DEPTH
`define OPQ_PAGE_RAM_DEPTH 65536
`endif

`ifndef OPQ_N_HIT
`define OPQ_N_HIT 2047
`endif

module opq_native_sv_4lane_signoff_top (
  input  logic        clk,
  input  logic        reset_n,
  output logic [15:0] activity_o
);
  localparam int unsigned N_LANE = `OPQ_N_LANE;
  localparam int unsigned N_SHD = `OPQ_N_SHD;
  localparam int unsigned N_HIT = `OPQ_N_HIT;
  localparam int unsigned TICKET_FIFO_DEPTH = `OPQ_TICKET_FIFO_DEPTH;
  localparam int unsigned PAGE_RAM_DEPTH = `OPQ_PAGE_RAM_DEPTH;
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
  logic [8:0]                                                     avs_csr_address;
  logic                                                           avs_csr_read;
  logic                                                           avs_csr_write;
  logic [31:0]                                                    avs_csr_writedata;
  logic [31:0]                                                    avs_csr_readdata;
  logic                                                           avs_csr_readdatavalid;
  logic                                                           avs_csr_waitrequest;
  logic                                                           avs_csr_burstcount;
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

  function automatic logic [8:0] csr_probe_addr(input logic [4:0] probe_idx);
    begin
      unique case (probe_idx)
        5'd0:  csr_probe_addr = 9'h005;
        5'd1:  csr_probe_addr = 9'h140;
        5'd2:  csr_probe_addr = 9'h141;
        5'd3:  csr_probe_addr = 9'h142;
        5'd4:  csr_probe_addr = 9'h143;
        5'd5:  csr_probe_addr = 9'h150;
        5'd6:  csr_probe_addr = 9'h151;
        5'd7:  csr_probe_addr = 9'h152;
        5'd8:  csr_probe_addr = 9'h153;
        5'd9:  csr_probe_addr = 9'h040;
        5'd10: csr_probe_addr = 9'h050;
        5'd11: csr_probe_addr = 9'h060;
        5'd12: csr_probe_addr = 9'h070;
        default: csr_probe_addr = 9'h004;
      endcase
    end
  endfunction

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

    synth_observe_global0 = aso_egress_data[31:0];
    synth_observe_global1 = {
      23'd0,
      avs_csr_waitrequest,
      avs_csr_readdatavalid,
      aso_egress_error,
      aso_egress_endofpacket,
      aso_egress_startofpacket,
      aso_egress_ready,
      aso_egress_valid
    };
    synth_observe_global2 = egress_accept_count;
    synth_observe_global3 = egress_checksum;
    synth_observe_global4 = {23'd0, avs_csr_address};
    synth_observe_global5 = avs_csr_readdata;
    synth_observe_global6 = {31'd0, avs_csr_read};
    synth_observe_global7 = {31'd0, avs_csr_write};
    synth_observe_global8 = avs_csr_writedata;
    synth_observe_global9 = heartbeat;

    for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
      synth_observe_lane[lane_idx] = {
        8'd0,
        asi_ingress_valid[lane_idx],
        asi_ingress_startofpacket[lane_idx],
        asi_ingress_endofpacket[lane_idx],
        asi_ingress_error[lane_idx],
        asi_ingress_data[lane_idx][17:0]
      };
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
      avs_csr_address <= '0;
      avs_csr_read <= 1'b0;
      avs_csr_write <= 1'b0;
      avs_csr_writedata <= '0;
      avs_csr_burstcount <= 1'b0;
      egress_accept_count <= '0;
      egress_checksum <= '0;
      for (int w = 0; w < SIGNATURE_WORDS; w++) begin
        activity_tap_q[w] <= 32'hACE0_0000 ^ w;
      end
    end else begin
      heartbeat <= heartbeat + 32'd1;
      cfg_reload_pulse <= 1'b0;
      aso_egress_ready <= heartbeat[0] | heartbeat[3] | !heartbeat[5];
      avs_csr_address <= csr_probe_addr(heartbeat[4:0]);
      avs_csr_read <= 1'b1;
      avs_csr_write <= 1'b0;
      avs_csr_writedata <= '0;
      avs_csr_burstcount <= 1'b0;
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

  ordered_priority_queue_dut_sv #(
    .N_HIT(N_HIT)
  ) dut_i (
    .asi_ingress_0_data(asi_ingress_data[0]),
    .asi_ingress_0_valid({asi_ingress_valid[0]}),
    .asi_ingress_0_channel(asi_ingress_channel[0]),
    .asi_ingress_0_startofpacket({asi_ingress_startofpacket[0]}),
    .asi_ingress_0_endofpacket({asi_ingress_endofpacket[0]}),
    .asi_ingress_0_error(asi_ingress_error[0]),
    .asi_ingress_1_data(asi_ingress_data[1]),
    .asi_ingress_1_valid({asi_ingress_valid[1]}),
    .asi_ingress_1_channel(asi_ingress_channel[1]),
    .asi_ingress_1_startofpacket({asi_ingress_startofpacket[1]}),
    .asi_ingress_1_endofpacket({asi_ingress_endofpacket[1]}),
    .asi_ingress_1_error(asi_ingress_error[1]),
    .asi_ingress_2_data(asi_ingress_data[2]),
    .asi_ingress_2_valid({asi_ingress_valid[2]}),
    .asi_ingress_2_channel(asi_ingress_channel[2]),
    .asi_ingress_2_startofpacket({asi_ingress_startofpacket[2]}),
    .asi_ingress_2_endofpacket({asi_ingress_endofpacket[2]}),
    .asi_ingress_2_error(asi_ingress_error[2]),
    .asi_ingress_3_data(asi_ingress_data[3]),
    .asi_ingress_3_valid({asi_ingress_valid[3]}),
    .asi_ingress_3_channel(asi_ingress_channel[3]),
    .asi_ingress_3_startofpacket({asi_ingress_startofpacket[3]}),
    .asi_ingress_3_endofpacket({asi_ingress_endofpacket[3]}),
    .asi_ingress_3_error(asi_ingress_error[3]),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .avs_csr_address(avs_csr_address),
    .avs_csr_read(avs_csr_read),
    .avs_csr_write(avs_csr_write),
    .avs_csr_writedata(avs_csr_writedata),
    .avs_csr_readdata(avs_csr_readdata),
    .avs_csr_readdatavalid(avs_csr_readdatavalid),
    .avs_csr_waitrequest(avs_csr_waitrequest),
    .avs_csr_burstcount(avs_csr_burstcount),
    .d_clk(clk),
    .d_reset(d_reset)
  );

  assign activity_o = activity_fold;
endmodule

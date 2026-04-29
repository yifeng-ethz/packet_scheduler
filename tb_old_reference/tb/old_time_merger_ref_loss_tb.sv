//------------------------------------------------------------------------------
// IP Name   : old_time_merger_ref_loss_tb
// Revision  : 0.1 - finite-buffer loss probe for the old time-merger tree
//------------------------------------------------------------------------------

`timescale 1ns/1ps

`ifndef OLD_TM_LANE_COUNT
`define OLD_TM_LANE_COUNT 4
`endif
`ifndef OLD_TM_STAGE_FIFO_DEPTH
`define OLD_TM_STAGE_FIFO_DEPTH 128
`endif

module old_time_merger_ref_loss_tb;
  localparam int LANE_COUNT = `OLD_TM_LANE_COUNT;
  localparam int STAGE_FIFO_DEPTH = `OLD_TM_STAGE_FIFO_DEPTH;
  localparam int DATA_WIDTH = 36;
  localparam int OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES = 4096;
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  sop;
    logic                  eop;
    logic                  is_hit;
  } word_t;

  typedef enum logic [2:0] {
    MON_EXPECT_SOP,
    MON_EXPECT_T0,
    MON_EXPECT_T1,
    MON_EXPECT_D0,
    MON_EXPECT_D1,
    MON_EXPECT_BODY
  } monitor_state_e;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [LANE_COUNT-1:0] lane_valid;
  logic [LANE_COUNT-1:0] lane_sop;
  logic [LANE_COUNT-1:0] lane_eop;
  logic [LANE_COUNT-1:0] lane_mask;
  logic [LANE_COUNT-1:0][DATA_WIDTH-1:0] lane_data;
  logic [LANE_COUNT-1:0] lane_ready;
  logic out_valid;
  logic out_ready;
  logic [DATA_WIDTH-1:0] out_data;
  logic out_sop;
  logic out_eop;
  logic join_wait;
  logic data_merge;
  logic [31:0] debug_join_wait_cycles;
  logic [31:0] debug_role_mismatch_cycles;
  logic [31:0] debug_node_blocked_cycles;
  logic [31:0] debug_fifo_full_stall_cycles;
  logic [31:0] debug_fifo_max_occupancy;
  logic [31:0] header_count;
  logic [31:0] subheader_count;
  logic [31:0] hit_count;

  word_t lane_queue[LANE_COUNT][$];
  monitor_state_e output_monitor_state;
  int unsigned output_header_count;
  int unsigned output_subheader_count;
  int unsigned output_hit_count;
  int unsigned output_trailer_count;
  int unsigned output_d0_subheader_count;
  int unsigned output_d0_hit_count;

  int frame_count;
  int subheaders_per_frame;
  int hits_per_subheader;
  int queue_depth_words;
  int ready_high;
  int ready_low;
  int ready_phase;
  int burstiness_milli;
  int rho_ppm;
  int frame_gap_cycles;
  int drain_cycles;
  bit generation_done;
  bit hits_plusarg_seen;
  int unsigned max_source_queue_words;
  longint unsigned source_dropped_frame_count;
  longint unsigned offered_hit_count;
  longint unsigned accepted_hit_count;
  longint unsigned dropped_hit_count;
  bit trace_txn;

  always #2 clk = ~clk;

  initial begin : proc_global_timeout
    repeat (1000000) @(posedge clk);
    $fatal(1, "old time-merger loss TB timed out for LANE_COUNT=%0d", LANE_COUNT);
  end

  old_time_merger_ref #(
    .LANE_COUNT(LANE_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ROUND_ROBIN(1'b1),
    .STAGE_FIFO_DEPTH(STAGE_FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable_i(1'b1),
    .lane_valid_i(lane_valid),
    .lane_sop_i(lane_sop),
    .lane_eop_i(lane_eop),
    .lane_mask_i(lane_mask),
    .lane_data_i(lane_data),
    .lane_ready_o(lane_ready),
    .out_valid_o(out_valid),
    .out_ready_i(out_ready),
    .out_data_o(out_data),
    .out_sop_o(out_sop),
    .out_eop_o(out_eop),
    .join_wait_o(join_wait),
    .data_merge_o(data_merge),
    .header_count_o(header_count),
    .subheader_count_o(subheader_count),
    .hit_count_o(hit_count),
    .debug_join_wait_cycles_o(debug_join_wait_cycles),
    .debug_role_mismatch_cycles_o(debug_role_mismatch_cycles),
    .debug_node_blocked_cycles_o(debug_node_blocked_cycles),
    .debug_fifo_full_stall_cycles_o(debug_fifo_full_stall_cycles),
    .debug_fifo_max_occupancy_o(debug_fifo_max_occupancy)
  );

  function automatic logic [31:0] make_preamble(logic [5:0] dt_type, logic [15:0] feb_id);
    logic [31:0] word_v;

    word_v = '0;
    word_v[31:26] = dt_type;
    word_v[23:8] = feb_id;
    word_v[7:0] = K285;
    return word_v;
  endfunction

  function automatic logic [35:0] frame_ts_hdr36(logic [47:0] frame_ts);
    return frame_ts[47:12];
  endfunction

  function automatic logic [31:0] make_frame_data_header0(logic [47:0] frame_ts);
    return frame_ts_hdr36(frame_ts)[35:4];
  endfunction

  function automatic logic [31:0] make_frame_data_header1(
    logic [47:0] frame_ts,
    logic [15:0] pkg_cnt
  );
    logic [31:0] word_v;

    word_v = '0;
    word_v[31:16] = frame_ts[15:0];
    word_v[15:0] = pkg_cnt;
    return word_v;
  endfunction

  function automatic logic [31:0] make_frame_debug_header0(
    logic [15:0] subheader_cnt,
    logic [15:0] hit_cnt
  );
    logic [31:0] word_v;

    word_v = '0;
    word_v[30:16] = subheader_cnt[14:0];
    word_v[15:0] = hit_cnt;
    return word_v;
  endfunction

  function automatic logic [31:0] make_frame_debug_header1(logic [30:0] debug_ts);
    logic [31:0] word_v;

    word_v = '0;
    word_v[30:0] = debug_ts;
    return word_v;
  endfunction

  function automatic logic [30:0] default_ingress_debug_ts(logic [47:0] frame_ts);
    logic [31:0] sum_v;

    sum_v = {1'b0, frame_ts[30:0]} + OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES;
    return sum_v[30:0];
  endfunction

  function automatic logic [31:0] make_subheader(logic [7:0] shd_ts, logic [7:0] hit_cnt);
    logic [31:0] word_v;

    word_v = '0;
    word_v[31:24] = shd_ts;
    word_v[15:8] = hit_cnt;
    word_v[7:0] = K237;
    return word_v;
  endfunction

  function automatic logic [31:0] make_trailer();
    logic [31:0] word_v;

    word_v = '0;
    word_v[7:0] = K284;
    return word_v;
  endfunction

  function automatic logic [31:0] make_hit_word(
    input int unsigned lane,
    input int unsigned frame_idx,
    input int unsigned shd,
    input int unsigned hit
  );
    return 32'hD000_0000 ^ (lane * 32'h0100_0000) ^
           (frame_idx * 32'h0001_0000) ^ (shd * 32'h0000_0100) ^
           32'(hit);
  endfunction

  function automatic int unsigned decode_hit_lane(input logic [31:0] payload);
    return int'((payload[31:24] ^ 8'hD0));
  endfunction

  function automatic int unsigned decode_hit_frame(input logic [31:0] payload);
    return int'(payload[23:16]);
  endfunction

  function automatic int unsigned decode_hit_subheader(input logic [31:0] payload);
    return int'(payload[15:8]);
  endfunction

  function automatic int unsigned decode_hit_index(input logic [31:0] payload);
    return int'(payload[7:0]);
  endfunction

  task automatic emit_txn(
    input string event_name,
    input int unsigned lane,
    input int unsigned frame_idx,
    input int unsigned subheader_idx,
    input int unsigned hit_idx,
    input logic [31:0] payload
  );
    if (trace_txn) begin
      $display("OLD_TM_TXN event=%s lane=%0d frame=%0d subheader=%0d hit=%0d bucket=%0d:%0d payload=0x%08x cycle=%0d time=%0t",
               event_name, lane, frame_idx, subheader_idx, hit_idx, frame_idx,
               subheader_idx, payload, int'($time / 4), $time);
    end
  endtask

  task automatic emit_frame_hits(input string event_name, input int unsigned frame_idx);
    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      for (int shd = 0; shd < subheaders_per_frame; shd++) begin
        for (int hit = 0; hit < hits_per_subheader; hit++) begin
          emit_txn(event_name, lane, frame_idx, shd, hit,
                   make_hit_word(lane, frame_idx, shd, hit));
        end
      end
    end
  endtask

  task automatic queue_word(
    input int unsigned lane,
    input logic [31:0] data32,
    input logic [3:0] datak,
    input logic sop,
    input logic eop,
    input logic is_hit
  );
    word_t word_v;

    word_v.data = {datak, data32};
    word_v.sop = sop;
    word_v.eop = eop;
    word_v.is_hit = is_hit;
    lane_queue[lane].push_back(word_v);
  endtask

  task automatic queue_frame(input int unsigned lane, input int unsigned frame_idx);
    logic [47:0] frame_ts;
    logic [15:0] pkg_cnt;
    logic [15:0] subheader_cnt;
    logic [15:0] hit_cnt;

    frame_ts = 48'h0000_0000_1000 + (frame_idx * 48'd2048);
    pkg_cnt = 16'(frame_idx);
    subheader_cnt = 16'(subheaders_per_frame);
    hit_cnt = 16'(subheaders_per_frame * hits_per_subheader);

    queue_word(lane, make_preamble(6'b000001, 16'h0001 + 16'(lane)), 4'b0001, 1'b1, 1'b0, 1'b0);
    queue_word(lane, make_frame_data_header0(frame_ts), 4'b0000, 1'b0, 1'b0, 1'b0);
    queue_word(lane, make_frame_data_header1(frame_ts, pkg_cnt), 4'b0000, 1'b0, 1'b0, 1'b0);
    queue_word(lane, make_frame_debug_header0(subheader_cnt, hit_cnt), 4'b0000, 1'b0, 1'b0, 1'b0);
    queue_word(lane, make_frame_debug_header1(default_ingress_debug_ts(frame_ts)), 4'b0000, 1'b0, 1'b0, 1'b0);
    for (int shd = 0; shd < subheaders_per_frame; shd++) begin
      queue_word(lane, make_subheader(8'(shd), 8'(hits_per_subheader)), 4'b0001, 1'b0, 1'b0, 1'b0);
      for (int hit = 0; hit < hits_per_subheader; hit++) begin
        queue_word(lane, make_hit_word(lane, frame_idx, shd, hit),
                   4'b0000, 1'b0, 1'b0, 1'b1);
      end
    end
    queue_word(lane, make_trailer(), 4'b0001, 1'b0, 1'b1, 1'b0);
  endtask

  function automatic int frame_words();
    return 6 + (subheaders_per_frame * (1 + hits_per_subheader));
  endfunction

  task automatic enqueue_frame_set(input int unsigned frame_idx);
    longint unsigned frame_hits_all_lanes;
    bit can_accept;

    frame_hits_all_lanes = longint'(LANE_COUNT) * longint'(subheaders_per_frame) *
                           longint'(hits_per_subheader);
    offered_hit_count += frame_hits_all_lanes;
    emit_frame_hits("offer", frame_idx);
    can_accept = 1'b1;
    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      if ((lane_queue[lane].size() + frame_words()) > queue_depth_words) begin
        can_accept = 1'b0;
      end
    end

    if (!can_accept) begin
      dropped_hit_count += frame_hits_all_lanes;
      source_dropped_frame_count += 1;
      emit_frame_hits("source_drop", frame_idx);
      return;
    end

    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      queue_frame(lane, frame_idx);
      if (lane_queue[lane].size() > max_source_queue_words) begin
        max_source_queue_words = lane_queue[lane].size();
      end
    end
    accepted_hit_count += frame_hits_all_lanes;
    emit_frame_hits("accept", frame_idx);
  endtask

  function automatic bit queues_empty();
    queues_empty = 1'b1;
    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      if (lane_queue[lane].size() != 0) begin
        queues_empty = 1'b0;
      end
    end
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      output_header_count <= 0;
      output_subheader_count <= 0;
      output_hit_count <= 0;
      output_trailer_count <= 0;
      output_d0_subheader_count <= 0;
      output_d0_hit_count <= 0;
      output_monitor_state <= MON_EXPECT_SOP;
    end else if (out_valid && out_ready) begin
      unique case (output_monitor_state)
        MON_EXPECT_SOP: begin
          if (out_sop) begin
            output_header_count <= output_header_count + 1;
            output_monitor_state <= MON_EXPECT_T0;
          end
        end
        MON_EXPECT_T0: output_monitor_state <= MON_EXPECT_T1;
        MON_EXPECT_T1: output_monitor_state <= MON_EXPECT_D0;
        MON_EXPECT_D0: begin
          output_d0_subheader_count <= output_d0_subheader_count + {1'b0, out_data[30:16]};
          output_d0_hit_count <= output_d0_hit_count + out_data[15:0];
          output_monitor_state <= MON_EXPECT_D1;
        end
        MON_EXPECT_D1: output_monitor_state <= MON_EXPECT_BODY;
        MON_EXPECT_BODY: begin
          if (out_eop) begin
            output_trailer_count <= output_trailer_count + 1;
            output_monitor_state <= MON_EXPECT_SOP;
          end else if ((out_data[35:32] == 4'b0001) && (out_data[7:0] == K237)) begin
            output_subheader_count <= output_subheader_count + 1;
          end else if (out_data[35:32] == 4'b0000) begin
            output_hit_count <= output_hit_count + 1;
            emit_txn("deliver",
                     decode_hit_lane(out_data[31:0]),
                     decode_hit_frame(out_data[31:0]),
                     decode_hit_subheader(out_data[31:0]),
                     decode_hit_index(out_data[31:0]),
                     out_data[31:0]);
          end
        end
        default: output_monitor_state <= MON_EXPECT_SOP;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ready_phase <= 0;
      out_ready <= 1'b0;
    end else if (ready_low == 0) begin
      ready_phase <= 0;
      out_ready <= 1'b1;
    end else begin
      out_ready <= ready_phase < ready_high;
      if (ready_phase == ((ready_high + ready_low) - 1)) begin
        ready_phase <= 0;
      end else begin
        ready_phase <= ready_phase + 1;
      end
    end
  end

  generate
    for (genvar lane_g = 0; lane_g < LANE_COUNT; lane_g++) begin : gen_lane_driver
      always_ff @(posedge clk) begin
        if (!rst_n) begin
          lane_valid[lane_g] <= 1'b0;
          lane_sop[lane_g] <= 1'b0;
          lane_eop[lane_g] <= 1'b0;
          lane_data[lane_g] <= '0;
        end else if (lane_valid[lane_g] && lane_ready[lane_g]) begin
          if ((lane_data[lane_g][35:32] == 4'b0000) &&
              (lane_data[lane_g][31:28] == 4'hD)) begin
            emit_txn("ingress_accept",
                     decode_hit_lane(lane_data[lane_g][31:0]),
                     decode_hit_frame(lane_data[lane_g][31:0]),
                     decode_hit_subheader(lane_data[lane_g][31:0]),
                     decode_hit_index(lane_data[lane_g][31:0]),
                     lane_data[lane_g][31:0]);
          end
          lane_valid[lane_g] <= 1'b0;
          lane_sop[lane_g] <= 1'b0;
          lane_eop[lane_g] <= 1'b0;
          lane_data[lane_g] <= '0;
        end else if (!lane_valid[lane_g] && (lane_queue[lane_g].size() != 0)) begin
          word_t word_v;

          word_v = lane_queue[lane_g].pop_front();
          lane_valid[lane_g] <= 1'b1;
          lane_sop[lane_g] <= word_v.sop;
          lane_eop[lane_g] <= word_v.eop;
          lane_data[lane_g] <= word_v.data;
        end
      end
    end
  endgenerate

  initial begin
    real burstiness;
    real rho_lane;
    real cv_tau;
    real mean_batch;
    real frame_gap_real;
    real loss_probability;
    real source_hit_utilization;
    real source_word_utilization;
    real merged_output_utilization;
    int merged_words_per_frame;

    frame_count = 32;
    subheaders_per_frame = 8;
    hits_per_subheader = 2;
    queue_depth_words = 256;
    ready_high = 1;
    ready_low = 0;
    burstiness_milli = 0;
    rho_ppm = 7500;
    drain_cycles = 4096;
    generation_done = 1'b0;
    max_source_queue_words = 0;
    source_dropped_frame_count = 0;
    offered_hit_count = 0;
    accepted_hit_count = 0;
    dropped_hit_count = 0;
    trace_txn = $test$plusargs("OLD_TM_TRACE_TXN");
    lane_mask = '1;

    void'($value$plusargs("OLD_TM_FRAME_COUNT=%d", frame_count));
    void'($value$plusargs("OLD_TM_SUBHEADERS=%d", subheaders_per_frame));
    hits_plusarg_seen = $value$plusargs("OLD_TM_HITS_PER_SUBHEADER=%d", hits_per_subheader);
    void'($value$plusargs("OLD_TM_QUEUE_DEPTH=%d", queue_depth_words));
    void'($value$plusargs("OLD_TM_READY_HIGH=%d", ready_high));
    void'($value$plusargs("OLD_TM_READY_LOW=%d", ready_low));
    void'($value$plusargs("OLD_TM_BURSTINESS_MILLI=%d", burstiness_milli));
    void'($value$plusargs("OLD_TM_RHO_PPM=%d", rho_ppm));
    void'($value$plusargs("OLD_TM_DRAIN_CYCLES=%d", drain_cycles));

    burstiness = real'(burstiness_milli) / 1000.0;
    if (burstiness > 0.999) begin
      burstiness = 0.999;
    end else if (burstiness < -0.999) begin
      burstiness = -0.999;
    end
    cv_tau = (1.0 + burstiness) / (1.0 - burstiness);
    mean_batch = ((cv_tau * cv_tau) + 1.0) / 2.0;
    if (!hits_plusarg_seen) begin
      hits_per_subheader = $rtoi(mean_batch + 0.5);
      if (hits_per_subheader < 1) begin
        hits_per_subheader = 1;
      end else if (hits_per_subheader > 255) begin
        hits_per_subheader = 255;
      end
    end

    rho_lane = real'(rho_ppm) / 1000000.0;
    if (rho_lane <= 0.0) begin
      rho_lane = 0.001;
    end
    frame_gap_real = real'(subheaders_per_frame * hits_per_subheader) / rho_lane;
    frame_gap_cycles = $rtoi(frame_gap_real + 0.999);
    if (frame_gap_cycles < 1) begin
      frame_gap_cycles = 1;
    end
    merged_words_per_frame =
      6 + subheaders_per_frame + (LANE_COUNT * subheaders_per_frame * hits_per_subheader);
    source_hit_utilization =
      real'(subheaders_per_frame * hits_per_subheader) / real'(frame_gap_cycles);
    source_word_utilization = real'(frame_words()) / real'(frame_gap_cycles);
    merged_output_utilization = real'(merged_words_per_frame) / real'(frame_gap_cycles);

    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    for (int frame = 0; frame < frame_count; frame++) begin
      enqueue_frame_set(frame);
      repeat (frame_gap_cycles) @(posedge clk);
    end
    generation_done = 1'b1;

    wait (queues_empty() && (lane_valid == '0));
    repeat (drain_cycles) @(posedge clk);
    loss_probability = (offered_hit_count == 0) ? 0.0 :
      (real'(dropped_hit_count) / real'(offered_hit_count));

    $display("OLD_TM_LOSS_RESULT implementation=time_merger n_lane=%0d egress_symbols_per_beat=1 burstiness_milli=%0d rho_ppm=%0d ready_high=%0d ready_low=%0d frame_count=%0d subheaders=%0d hits_per_subheader=%0d queue_depth_words=%0d stage_fifo_depth=%0d offered_hit_count=%0d accepted_hit_count=%0d dropped_hit_count=%0d delivered_hit_count=%0d loss_probability=%0.12f",
             LANE_COUNT, burstiness_milli, rho_ppm, ready_high, ready_low, frame_count,
             subheaders_per_frame, hits_per_subheader, queue_depth_words, STAGE_FIFO_DEPTH,
             offered_hit_count, accepted_hit_count, dropped_hit_count, output_hit_count,
             loss_probability);
    $display("OLD_TM_DEBUG_RESULT frame_gap_cycles=%0d hits_per_subheader_per_lane=%0d source_hit_utilization=%0.12f source_word_utilization=%0.12f merged_output_utilization=%0.12f source_dropped_frame_count=%0d max_source_queue_words=%0d debug_join_wait_cycles=%0d debug_role_mismatch_cycles=%0d debug_node_blocked_cycles=%0d debug_fifo_full_stall_cycles=%0d debug_fifo_max_occupancy=%0d",
             frame_gap_cycles, hits_per_subheader, source_hit_utilization,
             source_word_utilization, merged_output_utilization, source_dropped_frame_count,
             max_source_queue_words, debug_join_wait_cycles, debug_role_mismatch_cycles,
             debug_node_blocked_cycles, debug_fifo_full_stall_cycles,
             debug_fifo_max_occupancy);

    if (output_d0_hit_count != output_hit_count) begin
      $fatal(1, "D0 hit count mismatch header_sum=%0d observed=%0d",
             output_d0_hit_count, output_hit_count);
    end
    $finish;
  end
endmodule

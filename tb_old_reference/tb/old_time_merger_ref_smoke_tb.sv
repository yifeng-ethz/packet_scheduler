//------------------------------------------------------------------------------
// IP Name   : old_time_merger_ref_smoke_tb
// Revision  : 0.1 - standalone exact-frame smoke for the old time-merger tree
//------------------------------------------------------------------------------

`timescale 1ns/1ps

`ifndef OLD_TM_LANE_COUNT
`define OLD_TM_LANE_COUNT 4
`endif

module old_time_merger_ref_smoke_tb;
  localparam int LANE_COUNT = `OLD_TM_LANE_COUNT;
  localparam int DATA_WIDTH = 36;
  localparam int OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES = 4096;
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

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
  logic [31:0] header_count;
  logic [31:0] subheader_count;
  logic [31:0] hit_count;
  logic [15:0] output_d0_subheader_count;
  logic [15:0] output_d0_hit_count;
  int unsigned output_header_count;
  int unsigned output_subheader_count;
  int unsigned output_hit_count;
  int unsigned output_trailer_count;

  typedef enum logic [2:0] {
    MON_EXPECT_SOP,
    MON_EXPECT_T0,
    MON_EXPECT_T1,
    MON_EXPECT_D0,
    MON_EXPECT_D1,
    MON_EXPECT_BODY
  } monitor_state_e;

  monitor_state_e output_monitor_state;

  always #2 clk = ~clk;

  initial begin : proc_global_timeout
    repeat (10000) @(posedge clk);
    $fatal(1, "old time-merger smoke timed out for LANE_COUNT=%0d", LANE_COUNT);
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk) begin : proc_trace
    if (rst_n && $test$plusargs("OLD_TM_TRACE")) begin
      if (out_valid && out_ready) begin
        $display("[old_tm_out] t=%0t data=0x%09h datak=0x%1h sop=%0b eop=%0b",
                 $time, out_data, out_data[35:32], out_sop, out_eop);
      end
      if ((lane_valid & ~lane_ready) != '0) begin
        $display("[old_tm_wait] t=%0t valid=0x%0h ready=0x%0h sop=0x%0h eop=0x%0h",
                 $time, lane_valid, lane_ready, lane_sop, lane_eop);
      end
    end
  end
`endif

  old_time_merger_ref #(
    .LANE_COUNT(LANE_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ROUND_ROBIN(1'b1)
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
    .hit_count_o(hit_count)
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

  task automatic drive_word(
    input int unsigned lane,
    input logic [31:0] data32,
    input logic [3:0] datak,
    input logic sop,
    input logic eop
  );
    lane_data[lane] <= {datak, data32};
    lane_sop[lane] <= sop;
    lane_eop[lane] <= eop;
    lane_valid[lane] <= 1'b1;
    do begin
      @(posedge clk);
    end while (!lane_ready[lane]);
    lane_valid[lane] <= 1'b0;
    lane_sop[lane] <= 1'b0;
    lane_eop[lane] <= 1'b0;
    lane_data[lane] <= '0;
    @(posedge clk);
  endtask

  task automatic drive_frame(input int unsigned lane);
    logic [47:0] frame_ts;
    logic [15:0] pkg_cnt;
    logic [15:0] subheader_cnt;
    logic [15:0] hit_cnt;
    logic [31:0] hit0;
    logic [31:0] hit1;

    frame_ts = 48'h0000_0000_1000;
    pkg_cnt = 16'd0;
    subheader_cnt = 16'd1;
    hit_cnt = 16'd2;
    hit0 = 32'hDEAD_BEEF ^ (lane * 32'h1111_0011);
    hit1 = 32'h0BAD_BEEF ^ (lane * 32'h0101_0101);

    drive_word(lane, make_preamble(6'b000001, 16'h0001), 4'b0001, 1'b1, 1'b0);
    drive_word(lane, make_frame_data_header0(frame_ts), 4'b0000, 1'b0, 1'b0);
    drive_word(lane, make_frame_data_header1(frame_ts, pkg_cnt), 4'b0000, 1'b0, 1'b0);
    drive_word(lane, make_frame_debug_header0(subheader_cnt, hit_cnt), 4'b0000, 1'b0, 1'b0);
    drive_word(lane, make_frame_debug_header1(default_ingress_debug_ts(frame_ts)), 4'b0000, 1'b0, 1'b0);
    drive_word(lane, make_subheader(8'h01, 8'd2), 4'b0001, 1'b0, 1'b0);
    drive_word(lane, hit0, 4'b0000, 1'b0, 1'b0);
    drive_word(lane, hit1, 4'b0000, 1'b0, 1'b0);
    drive_word(lane, make_trailer(), 4'b0001, 1'b0, 1'b1);
  endtask

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

        MON_EXPECT_T0: begin
          output_monitor_state <= MON_EXPECT_T1;
        end

        MON_EXPECT_T1: begin
          output_monitor_state <= MON_EXPECT_D0;
        end

        MON_EXPECT_D0: begin
          output_d0_subheader_count <= {1'b0, out_data[30:16]};
          output_d0_hit_count <= out_data[15:0];
          output_monitor_state <= MON_EXPECT_D1;
        end

        MON_EXPECT_D1: begin
          output_monitor_state <= MON_EXPECT_BODY;
        end

        MON_EXPECT_BODY: begin
          if (out_eop) begin
            output_trailer_count <= output_trailer_count + 1;
            output_monitor_state <= MON_EXPECT_SOP;
          end else if ((out_data[35:32] == 4'b0001) && (out_data[7:0] == K237)) begin
            output_subheader_count <= output_subheader_count + 1;
          end else if (out_data[35:32] == 4'b0000) begin
            output_hit_count <= output_hit_count + 1;
          end
        end

        default: begin
          output_monitor_state <= MON_EXPECT_SOP;
        end
      endcase
    end
  end

  initial begin
    lane_valid = '0;
    lane_sop = '0;
    lane_eop = '0;
    lane_data = '0;
    lane_mask = '1;
    out_ready = 1'b1;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      automatic int lane_id = lane;
      fork
        drive_frame(lane_id);
      join_none
    end
    wait fork;

    wait (output_trailer_count != 0);
    repeat (4) @(posedge clk);
    if (output_header_count != 1) begin
      $fatal(1, "expected one merged header, got %0d", output_header_count);
    end
    if (output_subheader_count != 1) begin
      $fatal(1, "expected one merged subheader, got %0d", output_subheader_count);
    end
    if (output_hit_count != (LANE_COUNT * 2)) begin
      $fatal(1, "expected %0d merged hits, got %0d", LANE_COUNT * 2, output_hit_count);
    end
    if (output_d0_subheader_count != output_subheader_count) begin
      $fatal(1, "D0 subheader count mismatch header=%0d observed=%0d",
             output_d0_subheader_count, output_subheader_count);
    end
    if (output_d0_hit_count != output_hit_count) begin
      $fatal(1, "D0 hit count mismatch header=%0d observed=%0d",
             output_d0_hit_count, output_hit_count);
    end
    if (output_trailer_count != 1) begin
      $fatal(1, "expected one merged trailer, got %0d", output_trailer_count);
    end
    $display("OLD_TIME_MERGER_REF_SMOKE PASS headers=%0d subheaders=%0d hits=%0d trailers=%0d",
             output_header_count, output_subheader_count, output_hit_count, output_trailer_count);
    $finish;
  end
endmodule

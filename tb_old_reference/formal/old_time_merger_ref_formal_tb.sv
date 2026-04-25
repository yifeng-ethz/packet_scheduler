//------------------------------------------------------------------------------
// IP Name   : old_time_merger_ref_formal_tb
// Revision  : 0.2 - formal harness for exact OPQ-word parser/tree interface
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module old_time_merger_ref_formal_tb;
  localparam int LANE_COUNT = 4;
  localparam int DATA_WIDTH = 36;

  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  (* gclk *) logic clk;
  logic rst_n;
  logic enable_i;
  logic [LANE_COUNT-1:0] lane_valid_i;
  logic [LANE_COUNT-1:0] lane_sop_i;
  logic [LANE_COUNT-1:0] lane_eop_i;
  logic [LANE_COUNT-1:0] lane_mask_i;
  logic [LANE_COUNT-1:0][DATA_WIDTH-1:0] lane_data_i;
  logic [LANE_COUNT-1:0] lane_ready_o;
  logic out_valid_o;
  logic out_ready_i;
  logic [DATA_WIDTH-1:0] out_data_o;
  logic out_sop_o;
  logic out_eop_o;
  logic join_wait_o;
  logic data_merge_o;
  logic [31:0] header_count_o;
  logic [31:0] subheader_count_o;
  logic [31:0] hit_count_o;

  (* anyseq *) logic [LANE_COUNT-1:0] f_lane_valid;
  (* anyseq *) logic [LANE_COUNT-1:0] f_lane_sop;
  (* anyseq *) logic [LANE_COUNT-1:0] f_lane_eop;
  (* anyseq *) logic [LANE_COUNT-1:0][DATA_WIDTH-1:0] f_lane_data;
  (* anyseq *) logic f_out_ready;
  (* anyseq *) logic f_rst_n;

  logic f_past_valid;
  logic [2:0] f_reset_count;

  initial begin
    f_past_valid = 1'b0;
    f_reset_count = '0;
  end

  old_time_merger_ref #(
    .LANE_COUNT(LANE_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ROUND_ROBIN(1'b1)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable_i(enable_i),
    .lane_valid_i(lane_valid_i),
    .lane_sop_i(lane_sop_i),
    .lane_eop_i(lane_eop_i),
    .lane_mask_i(lane_mask_i),
    .lane_data_i(lane_data_i),
    .lane_ready_o(lane_ready_o),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .out_data_o(out_data_o),
    .out_sop_o(out_sop_o),
    .out_eop_o(out_eop_o),
    .join_wait_o(join_wait_o),
    .data_merge_o(data_merge_o),
    .header_count_o(header_count_o),
    .subheader_count_o(subheader_count_o),
    .hit_count_o(hit_count_o)
  );

  assign lane_valid_i = f_lane_valid;
  assign lane_sop_i = f_lane_sop;
  assign lane_eop_i = f_lane_eop;
  assign lane_data_i = f_lane_data;
  assign out_ready_i = f_out_ready;
  assign rst_n = f_rst_n;
  assign enable_i = 1'b1;
  assign lane_mask_i = '1;

  always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (f_reset_count != 3'd4) begin
      f_reset_count <= f_reset_count + 3'd1;
    end

    if (!f_past_valid || (f_reset_count < 3'd3)) begin
      assume(!rst_n);
    end else begin
      assume(rst_n);
    end

    for (int lane = 0; lane < LANE_COUNT; lane++) begin
      if (lane_sop_i[lane]) begin
        assume(lane_data_i[lane][35:32] == 4'b0001);
        assume(lane_data_i[lane][7:0] == K285);
      end
      if (lane_eop_i[lane]) begin
        assume(lane_data_i[lane][35:32] == 4'b0001);
        assume(lane_data_i[lane][7:0] == K284);
      end
      if ((lane_data_i[lane][35:32] == 4'b0001) &&
          (lane_data_i[lane][7:0] == K237)) begin
        assume(!lane_sop_i[lane]);
      end

      if (f_past_valid && $past(rst_n) &&
          $past(lane_valid_i[lane] && !lane_ready_o[lane])) begin
        assume(lane_valid_i[lane]);
        assume(lane_sop_i[lane] == $past(lane_sop_i[lane]));
        assume(lane_eop_i[lane] == $past(lane_eop_i[lane]));
        assume(lane_data_i[lane] == $past(lane_data_i[lane]));
      end
    end

    if (f_past_valid && rst_n && $past(rst_n) && (f_reset_count == 3'd4)) begin
      if ($past(out_valid_o && !out_ready_i) && !out_ready_i) begin
        assert(out_valid_o);
        assert($stable(out_data_o));
        assert($stable(out_sop_o));
        assert($stable(out_eop_o));
      end

      assert((lane_ready_o & ~lane_mask_i) == '0);

      assert (!(out_valid_o && out_sop_o) ||
              ((out_data_o[35:32] == 4'b0001) && (out_data_o[7:0] == K285)));
      assert (!(out_valid_o && out_eop_o) ||
              ((out_data_o[35:32] == 4'b0001) && (out_data_o[7:0] == K284)));

      cover(out_valid_o && out_ready_i && out_sop_o);
      cover(out_valid_o && out_ready_i && (out_data_o[35:32] == 4'b0000));
      cover(join_wait_o);
    end
  end
endmodule

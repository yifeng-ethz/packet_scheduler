//------------------------------------------------------------------------------
// IP Name   : old_time_merger_ref
// Revision  : 0.2 - parse OPQ frame words and build a cascaded old-merger tree
// Description:
//   Standalone SystemVerilog reference for the historical MuSiP time-merger
//   idea.  The model is not pin-compatible with the old SWB datapath, but it
//   consumes the same 36-bit OPQ/FEB frame words used by the UVM ingress
//   driver and cascades 2-input merger nodes for 4/8/16-lane comparison.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module old_time_merger_ref_node2 #(
  parameter int DATA_WIDTH = 36,
  parameter bit ROUND_ROBIN = 1'b1
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic                       enable_i,

  input  logic [1:0]                 lane_valid_i,
  input  logic [1:0]                 lane_sop_i,
  input  logic [1:0]                 lane_eop_i,
  input  logic [1:0]                 lane_mask_i,
  input  logic [1:0][DATA_WIDTH-1:0] lane_data_i,
  output logic [1:0]                 lane_ready_o,

  output logic                       out_valid_o,
  input  logic                       out_ready_i,
  output logic [DATA_WIDTH-1:0]      out_data_o,
  output logic                       out_sop_o,
  output logic                       out_eop_o,

  output logic                       join_wait_o,
  output logic                       data_merge_o,
  output logic [31:0]                header_count_o,
  output logic [31:0]                subheader_count_o,
  output logic [31:0]                hit_count_o,
  output logic [31:0]                debug_join_wait_cycles_o,
  output logic [31:0]                debug_role_mismatch_cycles_o,
  output logic [31:0]                debug_node_blocked_cycles_o
);

  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  typedef enum logic [2:0] {
    PARSE_SOP,
    PARSE_T0,
    PARSE_T1,
    PARSE_D0,
    PARSE_D1,
    PARSE_BODY
  } parser_state_e;

  typedef enum logic [3:0] {
    ROLE_IDLE,
    ROLE_SOP,
    ROLE_T0,
    ROLE_T1,
    ROLE_D0,
    ROLE_D1,
    ROLE_SUBHEADER,
    ROLE_DATA,
    ROLE_EOP
  } word_role_e;

  parser_state_e lane_parse_q[2];
  word_role_e lane_role_c[2];
  logic [1:0] active_mask_c;
  logic [1:0] plan_ready_c;
  logic plan_valid_c;
  logic plan_sop_c;
  logic plan_eop_c;
  logic can_accept_c;
  logic both_active_c;
  logic one_active_c;
  logic same_role_c;
  logic [DATA_WIDTH-1:0] plan_data_c;
  logic selected_lane_c;
  logic rr_ptr_q;
  logic role_mismatch_stall_c;
  logic node_blocked_c;

  function automatic logic is_preamble(
    input logic [DATA_WIDTH-1:0] data,
    input logic sop
  );
    is_preamble = sop && (data[35:32] == 4'b0001) && (data[7:0] == K285);
  endfunction

  function automatic logic is_subheader(
    input logic [DATA_WIDTH-1:0] data
  );
    is_subheader = (data[35:32] == 4'b0001) && (data[7:0] == K237);
  endfunction

  function automatic logic is_trailer(
    input logic [DATA_WIDTH-1:0] data,
    input logic eop
  );
    is_trailer = eop && (data[35:32] == 4'b0001) && (data[7:0] == K284);
  endfunction

  function automatic word_role_e classify_word(
    input parser_state_e state,
    input logic [DATA_WIDTH-1:0] data,
    input logic sop,
    input logic eop
  );
    unique case (state)
      PARSE_SOP: classify_word = is_preamble(data, sop) ? ROLE_SOP : ROLE_IDLE;
      PARSE_T0: classify_word = ROLE_T0;
      PARSE_T1: classify_word = ROLE_T1;
      PARSE_D0: classify_word = ROLE_D0;
      PARSE_D1: classify_word = ROLE_D1;
      default: begin
        if (is_trailer(data, eop)) begin
          classify_word = ROLE_EOP;
        end else if (is_subheader(data)) begin
          classify_word = ROLE_SUBHEADER;
        end else begin
          classify_word = ROLE_DATA;
        end
      end
    endcase
  endfunction

  function automatic parser_state_e next_parse_state(
    input parser_state_e state,
    input word_role_e role
  );
    unique case (state)
      PARSE_SOP: next_parse_state = (role == ROLE_SOP) ? PARSE_T0 : PARSE_SOP;
      PARSE_T0: next_parse_state = PARSE_T1;
      PARSE_T1: next_parse_state = PARSE_D0;
      PARSE_D0: next_parse_state = PARSE_D1;
      PARSE_D1: next_parse_state = PARSE_BODY;
      default: next_parse_state = (role == ROLE_EOP) ? PARSE_SOP : PARSE_BODY;
    endcase
  endfunction

  function automatic logic [7:0] sat_add8(
    input logic [7:0] a,
    input logic [7:0] b
  );
    logic [8:0] sum_v;

    sum_v = {1'b0, a} + {1'b0, b};
    sat_add8 = sum_v[8] ? 8'hff : sum_v[7:0];
  endfunction

  function automatic logic [15:0] sat_add16(
    input logic [15:0] a,
    input logic [15:0] b
  );
    logic [16:0] sum_v;

    sum_v = {1'b0, a} + {1'b0, b};
    sat_add16 = sum_v[16] ? 16'hffff : sum_v[15:0];
  endfunction

  function automatic logic select_data_lane(
    input logic [DATA_WIDTH-1:0] data0,
    input logic [DATA_WIDTH-1:0] data1,
    input logic rr_ptr
  );
    if (ROUND_ROBIN) begin
      select_data_lane = rr_ptr;
    end else begin
      select_data_lane = data1[3:0] < data0[3:0];
    end
  endfunction

  function automatic logic [DATA_WIDTH-1:0] merged_struct_word(
    input word_role_e role,
    input logic [DATA_WIDTH-1:0] data0,
    input logic [DATA_WIDTH-1:0] data1
  );
    logic [DATA_WIDTH-1:0] word_v;
    logic [14:0] subheader_max_v;

    word_v = data0;
    unique case (role)
      ROLE_D0: begin
        subheader_max_v = (data1[30:16] > data0[30:16]) ? data1[30:16] : data0[30:16];
        word_v[30:16] = subheader_max_v;
        word_v[15:0] = sat_add16(data0[15:0], data1[15:0]);
      end
      ROLE_SUBHEADER: begin
        word_v[15:8] = sat_add8(data0[15:8], data1[15:8]);
      end
      default: begin
        word_v = data0;
      end
    endcase
    merged_struct_word = word_v;
  endfunction

  assign active_mask_c = enable_i ? lane_mask_i : 2'b00;
  assign both_active_c = &active_mask_c;
  assign one_active_c = ^active_mask_c;
  assign can_accept_c = !out_valid_o || out_ready_i;
  assign same_role_c = lane_role_c[0] == lane_role_c[1];

  always_comb begin
    for (int lane = 0; lane < 2; lane++) begin
      lane_role_c[lane] = classify_word(
        lane_parse_q[lane],
        lane_data_i[lane],
        lane_sop_i[lane],
        lane_eop_i[lane]
      );
    end
  end

  always_comb begin
    plan_ready_c = 2'b00;
    plan_valid_c = 1'b0;
    plan_data_c = '0;
    plan_sop_c = 1'b0;
    plan_eop_c = 1'b0;
    selected_lane_c = 1'b0;

    if (enable_i && (active_mask_c != 2'b00)) begin
      if (one_active_c) begin
        selected_lane_c = active_mask_c[1];
        if (lane_valid_i[selected_lane_c]) begin
          plan_valid_c = 1'b1;
          plan_ready_c[selected_lane_c] = 1'b1;
          plan_data_c = lane_data_i[selected_lane_c];
          plan_sop_c =
            (lane_role_c[selected_lane_c] == ROLE_SOP) && lane_sop_i[selected_lane_c];
          plan_eop_c =
            (lane_role_c[selected_lane_c] == ROLE_EOP) && lane_eop_i[selected_lane_c];
        end
      end else if (both_active_c && (&lane_valid_i)) begin
        if (same_role_c && (lane_role_c[0] != ROLE_IDLE)) begin
          if (lane_role_c[0] == ROLE_DATA) begin
            selected_lane_c = select_data_lane(lane_data_i[0], lane_data_i[1], rr_ptr_q);
            plan_valid_c = 1'b1;
            plan_ready_c[selected_lane_c] = 1'b1;
            plan_data_c = lane_data_i[selected_lane_c];
            plan_sop_c = 1'b0;
            plan_eop_c = 1'b0;
          end else begin
            plan_valid_c = 1'b1;
            plan_ready_c = 2'b11;
            plan_data_c = merged_struct_word(lane_role_c[0], lane_data_i[0], lane_data_i[1]);
            plan_sop_c = (lane_role_c[0] == ROLE_SOP) && lane_sop_i[0];
            plan_eop_c = (lane_role_c[0] == ROLE_EOP) && lane_eop_i[0];
          end
        end else if ((lane_role_c[0] == ROLE_DATA) &&
                     ((lane_role_c[1] == ROLE_SUBHEADER) || (lane_role_c[1] == ROLE_EOP))) begin
          plan_valid_c = 1'b1;
          plan_ready_c = 2'b01;
          plan_data_c = lane_data_i[0];
          plan_sop_c = 1'b0;
          plan_eop_c = 1'b0;
        end else if ((lane_role_c[1] == ROLE_DATA) &&
                     ((lane_role_c[0] == ROLE_SUBHEADER) || (lane_role_c[0] == ROLE_EOP))) begin
          plan_valid_c = 1'b1;
          plan_ready_c = 2'b10;
          plan_data_c = lane_data_i[1];
          plan_sop_c = 1'b0;
          plan_eop_c = 1'b0;
        end
      end
    end
  end

  assign lane_ready_o = can_accept_c ? plan_ready_c : 2'b00;
  assign join_wait_o =
    enable_i && both_active_c && !plan_valid_c &&
    ((lane_valid_i & active_mask_c) != active_mask_c);
  assign role_mismatch_stall_c =
    enable_i && both_active_c && (&lane_valid_i) && !plan_valid_c &&
    (lane_role_c[0] != lane_role_c[1]);
  assign node_blocked_c = out_valid_o && !out_ready_i;
  assign data_merge_o =
    (plan_valid_c && ((lane_role_c[0] == ROLE_DATA) || (lane_role_c[1] == ROLE_DATA))) ||
    (out_valid_o && (out_data_o[35:32] == 4'b0000));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid_o <= 1'b0;
      out_data_o <= '0;
      out_sop_o <= 1'b0;
      out_eop_o <= 1'b0;
      rr_ptr_q <= 1'b0;
      header_count_o <= '0;
      subheader_count_o <= '0;
      hit_count_o <= '0;
      debug_join_wait_cycles_o <= '0;
      debug_role_mismatch_cycles_o <= '0;
      debug_node_blocked_cycles_o <= '0;
      for (int lane = 0; lane < 2; lane++) begin
        lane_parse_q[lane] <= PARSE_SOP;
      end
    end else if (!enable_i) begin
      out_valid_o <= 1'b0;
      rr_ptr_q <= 1'b0;
      debug_join_wait_cycles_o <= '0;
      debug_role_mismatch_cycles_o <= '0;
      debug_node_blocked_cycles_o <= '0;
      for (int lane = 0; lane < 2; lane++) begin
        lane_parse_q[lane] <= PARSE_SOP;
      end
    end else begin
      if (can_accept_c) begin
        out_valid_o <= plan_valid_c;
        if (plan_valid_c) begin
          out_data_o <= plan_data_c;
          out_sop_o <= plan_sop_c;
          out_eop_o <= plan_eop_c;

          if (plan_sop_c) begin
            header_count_o <= header_count_o + 32'd1;
          end
          if ((plan_data_c[35:32] == 4'b0001) && (plan_data_c[7:0] == K237)) begin
            subheader_count_o <= subheader_count_o + 32'd1;
          end
          if (plan_data_c[35:32] == 4'b0000) begin
            hit_count_o <= hit_count_o + 32'd1;
          end
        end
      end

      for (int lane = 0; lane < 2; lane++) begin
        if (lane_ready_o[lane] && lane_valid_i[lane]) begin
          lane_parse_q[lane] <= next_parse_state(lane_parse_q[lane], lane_role_c[lane]);
        end
      end

      if (lane_ready_o[selected_lane_c] && lane_valid_i[selected_lane_c] &&
          (lane_role_c[selected_lane_c] == ROLE_DATA) && ROUND_ROBIN) begin
        rr_ptr_q <= ~selected_lane_c;
      end

      if (join_wait_o) begin
        debug_join_wait_cycles_o <= debug_join_wait_cycles_o + 32'd1;
      end
      if (role_mismatch_stall_c) begin
        debug_role_mismatch_cycles_o <= debug_role_mismatch_cycles_o + 32'd1;
      end
      if (node_blocked_c) begin
        debug_node_blocked_cycles_o <= debug_node_blocked_cycles_o + 32'd1;
      end
    end
  end

`ifdef FORMAL
  logic f_past_valid;
  logic [1:0] f_reset_release_q;

  initial begin
    f_past_valid = 1'b0;
    f_reset_release_q = '0;
    out_valid_o = 1'b0;
    out_data_o = '0;
    out_sop_o = 1'b0;
    out_eop_o = 1'b0;
    rr_ptr_q = 1'b0;
    header_count_o = '0;
    subheader_count_o = '0;
    hit_count_o = '0;
    debug_join_wait_cycles_o = '0;
    debug_role_mismatch_cycles_o = '0;
    debug_node_blocked_cycles_o = '0;
    for (int lane = 0; lane < 2; lane++) begin
      lane_parse_q[lane] = PARSE_SOP;
    end
  end

  always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!rst_n) begin
      f_reset_release_q <= '0;
    end else if (f_reset_release_q != 2'd3) begin
      f_reset_release_q <= f_reset_release_q + 1'b1;
    end

    if (f_past_valid && $past(rst_n) && rst_n &&
        (f_reset_release_q == 2'd3) &&
        ($past(f_reset_release_q) == 2'd3)) begin
      if ($past(out_valid_o && !out_ready_i) && !out_ready_i) begin
        assert(out_valid_o);
        assert(out_data_o == $past(out_data_o));
        assert(out_sop_o == $past(out_sop_o));
        assert(out_eop_o == $past(out_eop_o));
      end

      if (!can_accept_c) begin
        assert(lane_ready_o == 2'b00);
      end

      assert((lane_ready_o & ~active_mask_c) == 2'b00);

      for (int lane = 0; lane < 2; lane++) begin
        if (lane_ready_o[lane]) begin
          assert(lane_valid_i[lane]);
        end
      end
    end
  end
`endif

endmodule

module old_time_merger_ref_fifo #(
  parameter int DATA_WIDTH = 38,
  parameter int DEPTH = 128,
  parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  in_valid_i,
  output logic                  in_ready_o,
  input  logic [DATA_WIDTH-1:0] in_data_i,
  output logic                  out_valid_o,
  input  logic                  out_ready_i,
  output logic [DATA_WIDTH-1:0] out_data_o,
  output logic [31:0]           debug_full_stall_cycles_o,
  output logic [31:0]           debug_max_occupancy_o
);
  logic [DATA_WIDTH-1:0] mem_q [DEPTH];
  logic [ADDR_WIDTH-1:0] wr_ptr_q;
  logic [ADDR_WIDTH-1:0] rd_ptr_q;
  logic [ADDR_WIDTH:0]   count_q;
  localparam logic [ADDR_WIDTH:0] DEPTH_COUNT = DEPTH;

  initial begin
    if (DEPTH < 2) begin
      $error("old_time_merger_ref_fifo requires DEPTH >= 2");
    end
    if ((DEPTH & (DEPTH - 1)) != 0) begin
      $error("old_time_merger_ref_fifo requires power-of-two DEPTH, got %0d", DEPTH);
    end
  end

  assign in_ready_o = count_q < DEPTH_COUNT;
  assign out_valid_o = count_q != '0;
  assign out_data_o = mem_q[rd_ptr_q];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q <= '0;
      debug_full_stall_cycles_o <= '0;
      debug_max_occupancy_o <= '0;
    end else begin
      logic do_write_v;
      logic do_read_v;
      logic [ADDR_WIDTH:0] next_count_v;

      do_write_v = in_valid_i && in_ready_o;
      do_read_v = out_valid_o && out_ready_i;
      next_count_v = count_q;

      if (do_write_v) begin
        mem_q[wr_ptr_q] <= in_data_i;
        wr_ptr_q <= wr_ptr_q + 1'b1;
      end
      if (do_read_v) begin
        rd_ptr_q <= rd_ptr_q + 1'b1;
      end

      unique case ({do_write_v, do_read_v})
        2'b10: next_count_v = count_q + 1'b1;
        2'b01: next_count_v = count_q - 1'b1;
        default: begin
        end
      endcase
      count_q <= next_count_v;
      if (next_count_v > debug_max_occupancy_o) begin
        debug_max_occupancy_o <= {{(32-(ADDR_WIDTH+1)){1'b0}}, next_count_v};
      end
      if (in_valid_i && !in_ready_o) begin
        debug_full_stall_cycles_o <= debug_full_stall_cycles_o + 32'd1;
      end
    end
  end

`ifdef FORMAL
  logic fifo_f_past_valid;
  logic [1:0] fifo_f_reset_release_q;

  initial begin
    fifo_f_past_valid = 1'b0;
    fifo_f_reset_release_q = '0;
    wr_ptr_q = '0;
    rd_ptr_q = '0;
    count_q = '0;
    debug_full_stall_cycles_o = '0;
    debug_max_occupancy_o = '0;
  end

  always_ff @(posedge clk) begin
    fifo_f_past_valid <= 1'b1;
    if (!rst_n) begin
      fifo_f_reset_release_q <= '0;
    end else if (fifo_f_reset_release_q != 2'd3) begin
      fifo_f_reset_release_q <= fifo_f_reset_release_q + 1'b1;
    end

    if (fifo_f_past_valid && rst_n && $past(rst_n) &&
        (fifo_f_reset_release_q == 2'd3) &&
        ($past(fifo_f_reset_release_q) == 2'd3)) begin
      assert(count_q <= DEPTH_COUNT);
      if ($past(out_valid_o && !out_ready_i) && !out_ready_i) begin
        assert(out_valid_o);
        assert($stable(out_data_o));
      end
    end
  end
`endif

endmodule

module old_time_merger_ref #(
  parameter int LANE_COUNT = 4,
  parameter int DATA_WIDTH = 36,
  parameter int LANE_ID_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1,
  parameter bit ROUND_ROBIN = 1'b1,
  parameter int STAGE_FIFO_DEPTH = 128
) (
  input  logic                                           clk,
  input  logic                                           rst_n,
  input  logic                                           enable_i,

  input  logic [LANE_COUNT-1:0]                          lane_valid_i,
  input  logic [LANE_COUNT-1:0]                          lane_sop_i,
  input  logic [LANE_COUNT-1:0]                          lane_eop_i,
  input  logic [LANE_COUNT-1:0]                          lane_mask_i,
  input  logic [LANE_COUNT-1:0][DATA_WIDTH-1:0]          lane_data_i,
  output logic [LANE_COUNT-1:0]                          lane_ready_o,

  output logic                                           out_valid_o,
  input  logic                                           out_ready_i,
  output logic [DATA_WIDTH-1:0]                          out_data_o,
  output logic                                           out_sop_o,
  output logic                                           out_eop_o,

  output logic                                           join_wait_o,
  output logic                                           data_merge_o,
  output logic [31:0]                                    header_count_o,
  output logic [31:0]                                    subheader_count_o,
  output logic [31:0]                                    hit_count_o,
  output logic [31:0]                                    debug_join_wait_cycles_o,
  output logic [31:0]                                    debug_role_mismatch_cycles_o,
  output logic [31:0]                                    debug_node_blocked_cycles_o,
  output logic [31:0]                                    debug_fifo_full_stall_cycles_o,
  output logic [31:0]                                    debug_fifo_max_occupancy_o
);

  localparam int STAGE_COUNT = $clog2(LANE_COUNT);
  localparam int PADDED_LANE_COUNT = 1 << STAGE_COUNT;

  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0] stage_valid;
  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0] stage_sop;
  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0] stage_eop;
  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0] stage_mask;
  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0] stage_ready;
  logic [STAGE_COUNT:0][PADDED_LANE_COUNT-1:0][DATA_WIDTH-1:0] stage_data;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_join_wait;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_data_merge;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_header_count;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_subheader_count;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_hit_count;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_debug_join_wait_cycles;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_debug_role_mismatch_cycles;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] node_debug_blocked_cycles;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] fifo_debug_full_stall_cycles;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][31:0] fifo_debug_max_occupancy;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_out_valid;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_out_ready;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_out_sop;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0] node_out_eop;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][DATA_WIDTH-1:0] node_out_data;
  logic [STAGE_COUNT-1:0][PADDED_LANE_COUNT/2-1:0][DATA_WIDTH+1:0] stage_fifo_out_data;

  initial begin
    if (LANE_COUNT < 2) begin
      $error("old_time_merger_ref requires LANE_COUNT >= 2");
    end
    if (LANE_COUNT != PADDED_LANE_COUNT) begin
      $error("old_time_merger_ref requires power-of-two LANE_COUNT, got %0d", LANE_COUNT);
    end
    if (DATA_WIDTH != 36) begin
      $error("old_time_merger_ref currently expects OPQ 36-bit words");
    end
  end

  generate
    for (genvar lane = 0; lane < PADDED_LANE_COUNT; lane++) begin : g_stage0
      if (lane < LANE_COUNT) begin : g_live
        assign stage_valid[0][lane] = lane_valid_i[lane];
        assign stage_sop[0][lane] = lane_sop_i[lane];
        assign stage_eop[0][lane] = lane_eop_i[lane];
        assign stage_mask[0][lane] = lane_mask_i[lane];
        assign stage_data[0][lane] = lane_data_i[lane];
        assign lane_ready_o[lane] = stage_ready[0][lane];
      end else begin : g_pad
        assign stage_valid[0][lane] = 1'b0;
        assign stage_sop[0][lane] = 1'b0;
        assign stage_eop[0][lane] = 1'b0;
        assign stage_mask[0][lane] = 1'b0;
        assign stage_data[0][lane] = '0;
      end
    end

    for (genvar stage = 0; stage < STAGE_COUNT; stage++) begin : g_stage
      localparam int NODE_COUNT = PADDED_LANE_COUNT >> (stage + 1);
      for (genvar node = 0; node < NODE_COUNT; node++) begin : g_node
        old_time_merger_ref_node2 #(
          .DATA_WIDTH(DATA_WIDTH),
          .ROUND_ROBIN(ROUND_ROBIN)
        ) node_i (
          .clk(clk),
          .rst_n(rst_n),
          .enable_i(enable_i),
          .lane_valid_i({
            stage_valid[stage][node * 2 + 1],
            stage_valid[stage][node * 2]
          }),
          .lane_sop_i({
            stage_sop[stage][node * 2 + 1],
            stage_sop[stage][node * 2]
          }),
          .lane_eop_i({
            stage_eop[stage][node * 2 + 1],
            stage_eop[stage][node * 2]
          }),
          .lane_mask_i({
            stage_mask[stage][node * 2 + 1],
            stage_mask[stage][node * 2]
          }),
          .lane_data_i({
            stage_data[stage][node * 2 + 1],
            stage_data[stage][node * 2]
          }),
          .lane_ready_o({
            stage_ready[stage][node * 2 + 1],
            stage_ready[stage][node * 2]
          }),
          .out_valid_o(node_out_valid[stage][node]),
          .out_ready_i(node_out_ready[stage][node]),
          .out_data_o(node_out_data[stage][node]),
          .out_sop_o(node_out_sop[stage][node]),
          .out_eop_o(node_out_eop[stage][node]),
          .join_wait_o(node_join_wait[stage][node]),
          .data_merge_o(node_data_merge[stage][node]),
          .header_count_o(node_header_count[stage][node]),
          .subheader_count_o(node_subheader_count[stage][node]),
          .hit_count_o(node_hit_count[stage][node]),
          .debug_join_wait_cycles_o(node_debug_join_wait_cycles[stage][node]),
          .debug_role_mismatch_cycles_o(node_debug_role_mismatch_cycles[stage][node]),
          .debug_node_blocked_cycles_o(node_debug_blocked_cycles[stage][node])
        );
        old_time_merger_ref_fifo #(
          .DATA_WIDTH(DATA_WIDTH + 2),
          .DEPTH(STAGE_FIFO_DEPTH)
        ) stage_fifo_i (
          .clk(clk),
          .rst_n(rst_n),
          .in_valid_i(node_out_valid[stage][node]),
          .in_ready_o(node_out_ready[stage][node]),
          .in_data_i({
            node_out_sop[stage][node],
            node_out_eop[stage][node],
            node_out_data[stage][node]
          }),
          .out_valid_o(stage_valid[stage + 1][node]),
          .out_ready_i(stage_ready[stage + 1][node]),
          .out_data_o(stage_fifo_out_data[stage][node]),
          .debug_full_stall_cycles_o(fifo_debug_full_stall_cycles[stage][node]),
          .debug_max_occupancy_o(fifo_debug_max_occupancy[stage][node])
        );
        assign {
          stage_sop[stage + 1][node],
          stage_eop[stage + 1][node],
          stage_data[stage + 1][node]
        } = stage_fifo_out_data[stage][node];
        assign stage_mask[stage + 1][node] =
          stage_mask[stage][node * 2] | stage_mask[stage][node * 2 + 1];
      end

      for (genvar pad = NODE_COUNT; pad < PADDED_LANE_COUNT; pad++) begin : g_stage_pad
        assign stage_valid[stage + 1][pad] = 1'b0;
        assign stage_sop[stage + 1][pad] = 1'b0;
        assign stage_eop[stage + 1][pad] = 1'b0;
        assign stage_mask[stage + 1][pad] = 1'b0;
        assign stage_data[stage + 1][pad] = '0;
      end
    end
  endgenerate

  assign stage_ready[STAGE_COUNT][0] = out_ready_i;
  assign out_valid_o = stage_valid[STAGE_COUNT][0];
  assign out_data_o = stage_data[STAGE_COUNT][0];
  assign out_sop_o = stage_sop[STAGE_COUNT][0];
  assign out_eop_o = stage_eop[STAGE_COUNT][0];
  assign join_wait_o = |node_join_wait;
  assign data_merge_o = |node_data_merge;

  always_comb begin
    header_count_o = '0;
    subheader_count_o = '0;
    hit_count_o = '0;
    debug_join_wait_cycles_o = '0;
    debug_role_mismatch_cycles_o = '0;
    debug_node_blocked_cycles_o = '0;
    debug_fifo_full_stall_cycles_o = '0;
    debug_fifo_max_occupancy_o = '0;
    for (int stage = 0; stage < STAGE_COUNT; stage++) begin
      for (int node = 0; node < (PADDED_LANE_COUNT >> (stage + 1)); node++) begin
        header_count_o += node_header_count[stage][node];
        subheader_count_o += node_subheader_count[stage][node];
        hit_count_o += node_hit_count[stage][node];
        debug_join_wait_cycles_o += node_debug_join_wait_cycles[stage][node];
        debug_role_mismatch_cycles_o += node_debug_role_mismatch_cycles[stage][node];
        debug_node_blocked_cycles_o += node_debug_blocked_cycles[stage][node];
        debug_fifo_full_stall_cycles_o += fifo_debug_full_stall_cycles[stage][node];
        if (fifo_debug_max_occupancy[stage][node] > debug_fifo_max_occupancy_o) begin
          debug_fifo_max_occupancy_o = fifo_debug_max_occupancy[stage][node];
        end
      end
    end
  end

`ifdef FORMAL
  always_ff @(posedge clk) begin
    if (rst_n) begin
      assert((lane_ready_o & ~lane_mask_i) == '0);
    end
  end
`endif

endmodule

//------------------------------------------------------------------------------
// IP Name   : tb_top
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.5 - default standalone OPQ UVM signoff to the native monolithic SV DUT
// Description:
//   Top-level OPQ UVM harness wrapper with native monolithic SV as the default signoff target.
//------------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import opq_pkg::*;
  import opq_env_pkg::*;

  logic d_clk = 1'b0;
  logic d_reset = 1'b1;
  time clk_period = 4ns;
  int unsigned clk_period_ns;
`ifdef OPQ_USE_NATIVE_SV
  bit native_trace_boundary;
  bit native_trace_ingress_credit;
  longint unsigned native_trace_after_ps = 0;
  localparam int unsigned TB_LANE_FIFO_ADDR_WIDTH = $clog2(OPQ_LANE_FIFO_DEPTH);
  localparam int unsigned TB_PAGE_RAM_ADDR_WIDTH = $clog2(OPQ_PAGE_RAM_DEPTH);
  localparam int unsigned TB_MAX_PKT_LENGTH = OPQ_N_HIT;
  localparam int unsigned TB_MAX_PKT_LENGTH_BITS =
    (TB_MAX_PKT_LENGTH <= 1) ? 1 : $clog2(TB_MAX_PKT_LENGTH);
  localparam int unsigned TB_HANDLE_SRC_LO = 0;
  localparam int unsigned TB_HANDLE_SRC_HI = TB_LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned TB_HANDLE_DST_LO = TB_LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned TB_HANDLE_DST_HI = TB_LANE_FIFO_ADDR_WIDTH + TB_PAGE_RAM_ADDR_WIDTH - 1;
`endif

  opq_ingress_if ingress_if [OPQ_N_LANE] (d_clk);
  opq_egress_if egress_if (d_clk);
  opq_csr_if csr_if (d_clk);
  opq_drop_if #(OPQ_N_LANE) drop_if (d_clk);

  initial begin
    if ($value$plusargs("TB_CLK_PERIOD_NS=%d", clk_period_ns)) begin
      if (clk_period_ns == 0) begin
        $fatal(1, "TB_CLK_PERIOD_NS must be non-zero");
      end
      clk_period = clk_period_ns * 1ns;
    end

    forever #(clk_period/2) d_clk = ~d_clk;
  end

  initial begin
    repeat (4) @(posedge d_clk);
    d_reset = 1'b0;
  end

  initial begin
`ifdef OPQ_USE_NATIVE_SV
    if (OPQ_N_LANE != 2 && OPQ_N_LANE != 4 && OPQ_N_LANE != 8 && OPQ_N_LANE != 16) begin
      $fatal(1, "Unsupported native OPQ_N_LANE=%0d in packet_scheduler/tb/uvm", OPQ_N_LANE);
    end
    if ((OPQ_PAGE_RAM_RD_WIDTH % OPQ_EGRESS_SYMBOL_WIDTH) != 0) begin
      $fatal(1, "OPQ_PAGE_RAM_RD_WIDTH=%0d is not an integer multiple of symbol width %0d",
        OPQ_PAGE_RAM_RD_WIDTH,
        OPQ_EGRESS_SYMBOL_WIDTH);
    end
    if (OPQ_EGRESS_SYMBOLS_PER_BEAT != (OPQ_PAGE_RAM_RD_WIDTH / OPQ_EGRESS_SYMBOL_WIDTH)) begin
      $fatal(1, "OPQ_EGRESS_SYMBOLS_PER_BEAT=%0d does not match OPQ_PAGE_RAM_RD_WIDTH=%0d",
        OPQ_EGRESS_SYMBOLS_PER_BEAT,
        OPQ_PAGE_RAM_RD_WIDTH);
    end
    if (OPQ_EGRESS_SYMBOLS_PER_BEAT != 1 && OPQ_EGRESS_SYMBOLS_PER_BEAT != 2 &&
        OPQ_EGRESS_SYMBOLS_PER_BEAT != 4 && OPQ_EGRESS_SYMBOLS_PER_BEAT != 8) begin
      $fatal(1, "Unsupported OPQ_EGRESS_SYMBOLS_PER_BEAT=%0d; use 1/2/4/8",
        OPQ_EGRESS_SYMBOLS_PER_BEAT);
    end
    if (OPQ_TICKET_FIFO_DEPTH <= OPQ_N_SHD) begin
      $fatal(1, "OPQ_TICKET_FIFO_DEPTH=%0d must be strictly larger than OPQ_N_SHD=%0d",
        OPQ_TICKET_FIFO_DEPTH,
        OPQ_N_SHD);
    end
`else
    if (OPQ_N_LANE != 2 && OPQ_N_LANE != 4) begin
      $fatal(1, "Unsupported VHDL OPQ_N_LANE=%0d in packet_scheduler/tb/uvm", OPQ_N_LANE);
    end
`endif
  end

`ifdef OPQ_USE_NATIVE_SV
  initial begin
    native_trace_boundary = $test$plusargs("OPQ_NATIVE_TRACE_BOUNDARY");
    native_trace_ingress_credit = $test$plusargs("OPQ_NATIVE_TRACE_INGRESS_CREDIT");
    void'($value$plusargs("OPQ_TRACE_AFTER_PS=%d", native_trace_after_ps));
  end
`endif

  genvar i;
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_if_rst
      assign ingress_if[i].reset = d_reset;
    end
  endgenerate
  assign egress_if.reset = d_reset;
  assign csr_if.reset = d_reset;
  assign drop_if.reset = d_reset;
`ifndef OPQ_USE_NATIVE_SV
  assign egress_if.empty = '0;
`endif

  logic [OPQ_INGRESS_WIDTH-1:0] hit3_symbol_data;
  logic hit3_symbol_valid;
  localparam int unsigned HIT3_UNPACK_FIFO_DEPTH = 32;
  localparam int unsigned HIT3_UNPACK_FIFO_PTR_WIDTH = $clog2(HIT3_UNPACK_FIFO_DEPTH);
  logic [OPQ_INGRESS_WIDTH-1:0] hit3_fifo [HIT3_UNPACK_FIFO_DEPTH];
  logic [HIT3_UNPACK_FIFO_PTR_WIDTH-1:0] hit3_fifo_rptr;
  logic [HIT3_UNPACK_FIFO_PTR_WIDTH-1:0] hit3_fifo_wptr;
  int unsigned hit3_fifo_count;

  function automatic logic [OPQ_INGRESS_WIDTH-1:0] tb_egress_symbol_at(
    input logic [OPQ_PAGE_RAM_RD_WIDTH-1:0] wide_data,
    input int unsigned symbol_idx
  );
    int unsigned lsb;

    lsb = (OPQ_EGRESS_SYMBOLS_PER_BEAT - 1 - symbol_idx) * OPQ_EGRESS_SYMBOL_WIDTH;
    return wide_data[lsb +: OPQ_EGRESS_SYMBOL_WIDTH];
  endfunction

  function automatic int unsigned tb_egress_valid_symbol_count(
    input logic eop,
    input logic [OPQ_EGRESS_EMPTY_WIDTH-1:0] empty
  );
    int unsigned empty_count;

    empty_count = eop ? int'(empty) : 0;
    if (empty_count >= OPQ_EGRESS_SYMBOLS_PER_BEAT) begin
      return 1;
    end
    return OPQ_EGRESS_SYMBOLS_PER_BEAT - empty_count;
  endfunction

  always_ff @(posedge d_clk) begin : proc_hit3_unpack
    int unsigned valid_symbols_v;
    logic [HIT3_UNPACK_FIFO_PTR_WIDTH-1:0] rptr_v;
    logic [HIT3_UNPACK_FIFO_PTR_WIDTH-1:0] wptr_v;
    int unsigned count_v;

    if (d_reset) begin
      hit3_symbol_data <= '0;
      hit3_symbol_valid <= 1'b0;
      hit3_fifo_rptr <= '0;
      hit3_fifo_wptr <= '0;
      hit3_fifo_count <= 0;
    end else begin
      rptr_v = hit3_fifo_rptr;
      wptr_v = hit3_fifo_wptr;
      count_v = hit3_fifo_count;
      hit3_symbol_valid <= 1'b0;

      if (count_v != 0) begin
        hit3_symbol_data <= hit3_fifo[rptr_v];
        hit3_symbol_valid <= 1'b1;
        rptr_v = rptr_v + {{(HIT3_UNPACK_FIFO_PTR_WIDTH-1){1'b0}}, 1'b1};
        count_v = count_v - 1;
      end

      if (egress_if.valid && egress_if.ready) begin
        valid_symbols_v = tb_egress_valid_symbol_count(egress_if.endofpacket, egress_if.empty);
        if ((count_v + valid_symbols_v) > HIT3_UNPACK_FIFO_DEPTH) begin
          $fatal(1, "hit3 unpack FIFO overflow count=%0d enq=%0d", count_v, valid_symbols_v);
        end
        for (int unsigned symbol_idx = 0; symbol_idx < valid_symbols_v; symbol_idx++) begin
          hit3_fifo[wptr_v] <= tb_egress_symbol_at(egress_if.data, symbol_idx);
          wptr_v = wptr_v + {{(HIT3_UNPACK_FIFO_PTR_WIDTH-1){1'b0}}, 1'b1};
          count_v = count_v + 1;
        end
      end

      hit3_fifo_rptr <= rptr_v;
      hit3_fifo_wptr <= wptr_v;
      hit3_fifo_count <= count_v;
    end
  end

`ifndef OPQ_USE_NATIVE_SV
  if (OPQ_N_LANE == 2) begin : gen_drop_tap_2lane
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_lane
      assign drop_if.valid[i] = gen_dut_2lane.dut.u_vhdl.u_impl.dbg_drop_valid[i];
      assign drop_if.hdr_drop_cnt[i] = 16'd0;
      assign drop_if.shd_drop_cnt[i] = drop_if.valid[i] ? 16'd1 : 16'd0;
      assign drop_if.hit_drop_cnt[i] = drop_if.valid[i] ? gen_dut_2lane.dut.u_vhdl.u_impl.dbg_drop_hit_cnt[(i*16) +: 16] : 16'd0;
      assign drop_if.pre_shd_drop_cnt[i] = drop_if.shd_drop_cnt[i];
      assign drop_if.pre_hit_drop_cnt[i] = drop_if.hit_drop_cnt[i];
      assign drop_if.post_hdr_drop_cnt[i] = 16'd0;
      assign drop_if.post_shd_drop_cnt[i] = 16'd0;
      assign drop_if.post_hit_drop_cnt[i] = 16'd0;
      assign drop_if.exact_pre_valid[i] = 1'b0;
      assign drop_if.exact_pre_ts[i] = '0;
      assign drop_if.exact_pre_serial[i] = '0;
      assign drop_if.exact_pre_shd_cnt[i] = '0;
      assign drop_if.exact_pre_hit_cnt[i] = '0;
      assign drop_if.exact_post_valid[i] = 1'b0;
      assign drop_if.exact_post_ts[i] = '0;
      assign drop_if.exact_post_serial[i] = '0;
      assign drop_if.exact_post_shd_cnt[i] = '0;
      assign drop_if.exact_post_hit_cnt[i] = '0;
    end
  end else begin : gen_drop_tap_4lane
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_lane
      assign drop_if.valid[i] = gen_dut_4lane.dut4.u_impl.dbg_drop_valid[i];
      assign drop_if.hdr_drop_cnt[i] = 16'd0;
      assign drop_if.shd_drop_cnt[i] = drop_if.valid[i] ? 16'd1 : 16'd0;
      assign drop_if.hit_drop_cnt[i] = drop_if.valid[i] ? gen_dut_4lane.dut4.u_impl.dbg_drop_hit_cnt[(i*16) +: 16] : 16'd0;
      assign drop_if.pre_shd_drop_cnt[i] = drop_if.shd_drop_cnt[i];
      assign drop_if.pre_hit_drop_cnt[i] = drop_if.hit_drop_cnt[i];
      assign drop_if.post_hdr_drop_cnt[i] = 16'd0;
      assign drop_if.post_shd_drop_cnt[i] = 16'd0;
      assign drop_if.post_hit_drop_cnt[i] = 16'd0;
      assign drop_if.exact_pre_valid[i] = 1'b0;
      assign drop_if.exact_pre_ts[i] = '0;
      assign drop_if.exact_pre_serial[i] = '0;
      assign drop_if.exact_pre_shd_cnt[i] = '0;
      assign drop_if.exact_pre_hit_cnt[i] = '0;
      assign drop_if.exact_post_valid[i] = 1'b0;
      assign drop_if.exact_post_ts[i] = '0;
      assign drop_if.exact_post_serial[i] = '0;
      assign drop_if.exact_post_shd_cnt[i] = '0;
      assign drop_if.exact_post_hit_cnt[i] = '0;
    end
  end
`else
  if (1) begin : gen_drop_tap_native
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_lane_native
      assign drop_if.valid[i] = gen_dut_native.dut.native_drop_evt_valid_dbg[i];
      assign drop_if.hdr_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_hdr_dbg[i];
      assign drop_if.shd_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_shd_dbg[i];
      assign drop_if.hit_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_hit_dbg[i];
      assign drop_if.pre_shd_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_pre_shd_dbg[i];
      assign drop_if.pre_hit_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_pre_hit_dbg[i];
      assign drop_if.post_hdr_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_post_hdr_dbg[i];
      assign drop_if.post_shd_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_post_shd_dbg[i];
      assign drop_if.post_hit_drop_cnt[i] = gen_dut_native.dut.native_drop_evt_post_hit_dbg[i];
      assign drop_if.exact_pre_valid[i] = gen_dut_native.dut.native_exact_pre_valid_dbg[i];
      assign drop_if.exact_pre_ts[i] = gen_dut_native.dut.native_exact_pre_ts_dbg[i];
      assign drop_if.exact_pre_serial[i] = gen_dut_native.dut.native_exact_pre_serial_dbg[i];
      assign drop_if.exact_pre_shd_cnt[i] = gen_dut_native.dut.native_exact_pre_shd_dbg[i];
      assign drop_if.exact_pre_hit_cnt[i] = gen_dut_native.dut.native_exact_pre_hit_dbg[i];
      assign drop_if.exact_post_valid[i] = gen_dut_native.dut.native_exact_post_valid_dbg[i];
      assign drop_if.exact_post_ts[i] = gen_dut_native.dut.native_exact_post_ts_dbg[i];
      assign drop_if.exact_post_serial[i] = gen_dut_native.dut.native_exact_post_serial_dbg[i];
      assign drop_if.exact_post_shd_cnt[i] = gen_dut_native.dut.native_exact_post_shd_dbg[i];
      assign drop_if.exact_post_hit_cnt[i] = gen_dut_native.dut.native_exact_post_hit_dbg[i];
    end
  end
`endif

`ifdef OPQ_USE_NATIVE_SV
  if (OPQ_N_LANE == 2) begin : gen_native_boundary_trace_2lane
    logic [2:0] prev_pa_state;
    logic prev_all_fetch_ready;
    logic prev_any_pending_ticket;
    logic prev_any_pending_curr_sop_ticket;
    logic prev_all_present_tk_sop;
    logic prev_frame_start_waiting_busy_lane;
    logic prev_active_frame_waiting_busy_lane;
    logic [OPQ_N_LANE-1:0] prev_pending_ticket;
    logic [OPQ_N_LANE-1:0] prev_pending_ticket_lane;
    logic [OPQ_N_LANE-1:0] prev_ticket_q_valid;
    logic [OPQ_N_LANE-1:0] prev_tk_sop;
    logic [OPQ_N_LANE-1:0] prev_tk_curr;
    logic [OPQ_N_LANE-1:0] prev_tk_future;
    logic [OPQ_N_LANE-1:0] prev_tk_past;

    always_ff @(posedge d_clk) begin
      if (d_reset) begin
        prev_pa_state <= 3'h7;
        prev_all_fetch_ready <= 1'b0;
        prev_any_pending_ticket <= 1'b0;
        prev_any_pending_curr_sop_ticket <= 1'b0;
        prev_all_present_tk_sop <= 1'b0;
        prev_frame_start_waiting_busy_lane <= 1'b0;
        prev_active_frame_waiting_busy_lane <= 1'b0;
        prev_pending_ticket <= '0;
        prev_pending_ticket_lane <= '0;
        prev_ticket_q_valid <= '0;
        prev_tk_sop <= '0;
        prev_tk_curr <= '0;
        prev_tk_future <= '0;
        prev_tk_past <= '0;
      end
      if (!d_reset && native_trace_boundary &&
          ($rtoi($realtime / 1ps) >= native_trace_after_ps)) begin
        if ((prev_pa_state != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state) ||
            (prev_all_fetch_ready != gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready) ||
            (prev_any_pending_ticket != gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket) ||
            (prev_any_pending_curr_sop_ticket != gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket) ||
            (prev_all_present_tk_sop != gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop) ||
            (prev_frame_start_waiting_busy_lane != gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane) ||
            (prev_active_frame_waiting_busy_lane != gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane) ||
            (prev_pending_ticket != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket) ||
            (prev_pending_ticket_lane != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane) ||
            (prev_ticket_q_valid != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid) ||
            (prev_tk_sop != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop) ||
            (prev_tk_curr != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr) ||
            (prev_tk_future != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future) ||
            (prev_tk_past != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past)) begin
          $display(
            "[opq_pa] t=%0t state=%0d all_fetch=%0b any_pending=%0b any_curr_sop=%0b all_sop=%0b frame_wait=%0b active_wait=%0b frame_lane_active=0x%0h lane_masked=0x%0h lane_skipped=0x%0h ingress_busy=0x%0h pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ticket_wptr=0x%0h/0x%0h ticket_rptr=0x%0h/0x%0h",
            $time,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state,
            gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready,
            gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop,
            gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane,
            gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.frame_lane_active,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.lane_masked,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.lane_skipped,
            gen_dut_native.dut.u_native.ingress_parser_busy_dbg,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past,
            gen_dut_native.dut.u_native.g_ingress_parser[0].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.g_ingress_parser[1].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[0],
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[1]
          );
        end

        prev_pa_state <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state;
        prev_all_fetch_ready <= gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready;
        prev_any_pending_ticket <= gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket;
        prev_any_pending_curr_sop_ticket <=
          gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket;
        prev_all_present_tk_sop <= gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop;
        prev_frame_start_waiting_busy_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane;
        prev_active_frame_waiting_busy_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane;
        prev_pending_ticket <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket;
        prev_pending_ticket_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane;
        prev_ticket_q_valid <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid;
        prev_tk_sop <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop;
        prev_tk_curr <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr;
        prev_tk_future <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future;
        prev_tk_past <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past;

        for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
          if (native_trace_ingress_credit &&
              gen_dut_native.dut.asi_ingress_valid_eff_bus[lane] &&
              gen_dut_native.dut.is_subheader_word(gen_dut_native.dut.asi_ingress_data_bus[lane])) begin
            $display(
              "[opq_ing_credit] t=%0t lane%0d pkg=%0d running_ts=0x%012h data=0x%09h hit_decl=%0d lane_credit=%0d ticket_credit=%0d drop_valid=%0b drop_lane=%0b drop_ticket=%0b",
              $time,
              lane,
              gen_dut_native.dut.native_ingress_pkg_cnt_dbg[lane],
              gen_dut_native.dut.native_ingress_running_ts_dbg[lane],
              gen_dut_native.dut.asi_ingress_data_bus[lane],
              gen_dut_native.dut.asi_ingress_data_bus[lane][15:8],
              gen_dut_native.dut.native_lane_credit_dbg[lane],
              gen_dut_native.dut.native_ticket_credit_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_valid_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_lane_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_ticket_dbg[lane]
            );
          end

          if (gen_dut_native.dut.native_drop_evt_valid_dbg[lane]) begin
            $display(
              "[opq_drop_evt] t=%0t lane%0d credit(lane=%0d ticket=%0d) total(hdr=%0d shd=%0d hit=%0d) pre(shd=%0d hit=%0d) post(hdr=%0d shd=%0d hit=%0d) src(mask=%0b credit=%0b late=%0b handle=%0b) exact_pre(valid=%0b serial=%0d ts=0x%012h shd=%0d hit=%0d) exact_post(valid=%0b serial=%0d ts=0x%012h shd=%0d hit=%0d)",
              $time,
              lane,
              gen_dut_native.dut.native_lane_credit_dbg[lane],
              gen_dut_native.dut.native_ticket_credit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_hdr_dbg[lane],
              gen_dut_native.dut.native_drop_evt_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_hit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_pre_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_pre_hit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_hdr_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_hit_dbg[lane],
              gen_dut_native.dut.csr_lane_mask_effective[lane] &&
                gen_dut_native.dut.asi_ingress_valid_bus[lane] &&
                gen_dut_native.dut.is_subheader_word(gen_dut_native.dut.asi_ingress_data_bus[lane]),
              gen_dut_native.dut.native_ingress_credit_drop_valid_dbg[lane],
              gen_dut_native.dut.native_late_frame_drop_valid_dbg[lane],
              gen_dut_native.dut.native_handle_we_dbg[lane] &&
                gen_dut_native.dut.native_handle_flag_dbg[lane],
              gen_dut_native.dut.native_exact_pre_valid_dbg[lane],
              gen_dut_native.dut.native_exact_pre_serial_dbg[lane],
              gen_dut_native.dut.native_exact_pre_ts_dbg[lane],
              gen_dut_native.dut.native_exact_pre_shd_dbg[lane],
              gen_dut_native.dut.native_exact_pre_hit_dbg[lane],
              gen_dut_native.dut.native_exact_post_valid_dbg[lane],
              gen_dut_native.dut.native_exact_post_serial_dbg[lane],
              gen_dut_native.dut.native_exact_post_ts_dbg[lane],
              gen_dut_native.dut.native_exact_post_shd_dbg[lane],
              gen_dut_native.dut.native_exact_post_hit_dbg[lane]
            );
          end

          if (gen_dut_native.dut.native_handle_we_dbg[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d handle_we flag=%0b src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.native_handle_flag_dbg[lane],
              gen_dut_native.dut.u_native.handle_wdata_dbg[lane][TB_HANDLE_SRC_HI:TB_HANDLE_SRC_LO],
              gen_dut_native.dut.u_native.handle_wdata_dbg[lane][TB_HANDLE_DST_HI:TB_HANDLE_DST_LO],
              gen_dut_native.dut.native_handle_block_len_dbg[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.handle_wptr[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_state[lane] == 3'd1) begin
            $display("[opq_boundary] t=%0t lane%0d mover_prep src=0x%0h dst=0x%0h len=%0d handle_rptr=0x%0h quantum=%0d",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_src[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_dst[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_blk_len[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_rptr[lane],
              gen_dut_native.dut.native_drr_quantum_dbg[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_page_wreq[lane] &&
              gen_dut_native.dut.native_drr_gnt_dbg[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d mover_write word_idx=%0d src=0x%0h dst=0x%0h len=%0d lane_rd=0x%0h lane_q=0x%0h page_addr=0x%0h page_data=0x%0h quantum=%0d",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_word_wr_cnt[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_src[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_dst[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_blk_len[lane],
              gen_dut_native.dut.u_native.lane_fifos_rd_addr[lane],
              gen_dut_native.dut.u_native.lane_fifos_rd_data[lane],
              gen_dut_native.dut.u_native.page_ram_wr_addr_dbg,
              gen_dut_native.dut.u_native.page_ram_wr_data_dbg,
              gen_dut_native.dut.native_drr_quantum_dbg[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_lane_credit_update_valid[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d credit_return amount=%0d handle_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_lane_credit_update[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_rptr[lane]);
          end

          if (gen_dut_native.dut.u_native.page_allocator_i.late_frame_lane_credit_update_valid[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d late_credit_return amount=%0d ticket_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.u_native.page_allocator_i.late_frame_lane_credit_update[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[lane]);
          end
        end
      end
    end
  end else begin : gen_native_boundary_trace_4lane
    logic [2:0] prev_pa_state;
    logic prev_all_fetch_ready;
    logic prev_any_pending_ticket;
    logic prev_any_pending_curr_sop_ticket;
    logic prev_all_present_tk_sop;
    logic prev_frame_start_waiting_busy_lane;
    logic prev_active_frame_waiting_busy_lane;
    logic [OPQ_N_LANE-1:0] prev_pending_ticket;
    logic [OPQ_N_LANE-1:0] prev_pending_ticket_lane;
    logic [OPQ_N_LANE-1:0] prev_ticket_q_valid;
    logic [OPQ_N_LANE-1:0] prev_tk_sop;
    logic [OPQ_N_LANE-1:0] prev_tk_curr;
    logic [OPQ_N_LANE-1:0] prev_tk_future;
    logic [OPQ_N_LANE-1:0] prev_tk_past;

    always_ff @(posedge d_clk) begin
      if (d_reset) begin
        prev_pa_state <= 3'h7;
        prev_all_fetch_ready <= 1'b0;
        prev_any_pending_ticket <= 1'b0;
        prev_any_pending_curr_sop_ticket <= 1'b0;
        prev_all_present_tk_sop <= 1'b0;
        prev_frame_start_waiting_busy_lane <= 1'b0;
        prev_active_frame_waiting_busy_lane <= 1'b0;
        prev_pending_ticket <= '0;
        prev_pending_ticket_lane <= '0;
        prev_ticket_q_valid <= '0;
        prev_tk_sop <= '0;
        prev_tk_curr <= '0;
        prev_tk_future <= '0;
        prev_tk_past <= '0;
      end
      if (!d_reset && native_trace_boundary &&
          ($rtoi($realtime / 1ps) >= native_trace_after_ps)) begin
        if ((prev_pa_state != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state) ||
            (prev_all_fetch_ready != gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready) ||
            (prev_any_pending_ticket != gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket) ||
            (prev_any_pending_curr_sop_ticket != gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket) ||
            (prev_all_present_tk_sop != gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop) ||
            (prev_frame_start_waiting_busy_lane != gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane) ||
            (prev_active_frame_waiting_busy_lane != gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane) ||
            (prev_pending_ticket != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket) ||
            (prev_pending_ticket_lane != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane) ||
            (prev_ticket_q_valid != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid) ||
            (prev_tk_sop != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop) ||
            (prev_tk_curr != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr) ||
            (prev_tk_future != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future) ||
            (prev_tk_past != gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past)) begin
          $display(
            "[opq_pa] t=%0t state=%0d all_fetch=%0b any_pending=%0b any_curr_sop=%0b all_sop=%0b frame_wait=%0b active_wait=%0b frame_lane_active=0x%0h lane_masked=0x%0h lane_skipped=0x%0h ingress_busy=0x%0h pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ticket_wptr=0x%0h/0x%0h/0x%0h/0x%0h ticket_rptr=0x%0h/0x%0h/0x%0h/0x%0h",
            $time,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state,
            gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready,
            gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop,
            gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane,
            gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.frame_lane_active,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.lane_masked,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.lane_skipped,
            gen_dut_native.dut.u_native.ingress_parser_busy_dbg,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past,
            gen_dut_native.dut.u_native.g_ingress_parser[0].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.g_ingress_parser[1].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.g_ingress_parser[2].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.g_ingress_parser[3].ingress_parser_i.ticket_wptr,
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[0],
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[1],
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[2],
            gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[3]
          );
        end

        prev_pa_state <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_state;
        prev_all_fetch_ready <= gen_dut_native.dut.u_native.page_allocator_i.all_lanes_fetch_ready;
        prev_any_pending_ticket <= gen_dut_native.dut.u_native.page_allocator_i.any_pending_ticket;
        prev_any_pending_curr_sop_ticket <=
          gen_dut_native.dut.u_native.page_allocator_i.any_pending_curr_sop_ticket;
        prev_all_present_tk_sop <= gen_dut_native.dut.u_native.page_allocator_i.all_present_tk_sop;
        prev_frame_start_waiting_busy_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.frame_start_waiting_busy_lane;
        prev_active_frame_waiting_busy_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.active_frame_waiting_busy_lane;
        prev_pending_ticket <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket;
        prev_pending_ticket_lane <=
          gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_pending_ticket_lane;
        prev_ticket_q_valid <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_ticket_q_valid;
        prev_tk_sop <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_sop;
        prev_tk_curr <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_curr;
        prev_tk_future <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_future;
        prev_tk_past <= gen_dut_native.dut.u_native.page_allocator_i.page_allocator_is_tk_past;

        for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
          if (native_trace_ingress_credit &&
              gen_dut_native.dut.asi_ingress_valid_eff_bus[lane] &&
              gen_dut_native.dut.is_subheader_word(gen_dut_native.dut.asi_ingress_data_bus[lane])) begin
            $display(
              "[opq_ing_credit] t=%0t lane%0d pkg=%0d running_ts=0x%012h data=0x%09h hit_decl=%0d lane_credit=%0d ticket_credit=%0d drop_valid=%0b drop_lane=%0b drop_ticket=%0b",
              $time,
              lane,
              gen_dut_native.dut.native_ingress_pkg_cnt_dbg[lane],
              gen_dut_native.dut.native_ingress_running_ts_dbg[lane],
              gen_dut_native.dut.asi_ingress_data_bus[lane],
              gen_dut_native.dut.asi_ingress_data_bus[lane][15:8],
              gen_dut_native.dut.native_lane_credit_dbg[lane],
              gen_dut_native.dut.native_ticket_credit_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_valid_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_lane_dbg[lane],
              gen_dut_native.dut.native_ingress_credit_drop_ticket_dbg[lane]
            );
          end

          if (gen_dut_native.dut.native_drop_evt_valid_dbg[lane]) begin
            $display(
              "[opq_drop_evt] t=%0t lane%0d credit(lane=%0d ticket=%0d) total(hdr=%0d shd=%0d hit=%0d) pre(shd=%0d hit=%0d) post(hdr=%0d shd=%0d hit=%0d) src(mask=%0b credit=%0b late=%0b handle=%0b) exact_pre(valid=%0b serial=%0d ts=0x%012h shd=%0d hit=%0d) exact_post(valid=%0b serial=%0d ts=0x%012h shd=%0d hit=%0d)",
              $time,
              lane,
              gen_dut_native.dut.native_lane_credit_dbg[lane],
              gen_dut_native.dut.native_ticket_credit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_hdr_dbg[lane],
              gen_dut_native.dut.native_drop_evt_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_hit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_pre_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_pre_hit_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_hdr_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_shd_dbg[lane],
              gen_dut_native.dut.native_drop_evt_post_hit_dbg[lane],
              gen_dut_native.dut.csr_lane_mask_effective[lane] &&
                gen_dut_native.dut.asi_ingress_valid_bus[lane] &&
                gen_dut_native.dut.is_subheader_word(gen_dut_native.dut.asi_ingress_data_bus[lane]),
              gen_dut_native.dut.native_ingress_credit_drop_valid_dbg[lane],
              gen_dut_native.dut.native_late_frame_drop_valid_dbg[lane],
              gen_dut_native.dut.native_handle_we_dbg[lane] &&
                gen_dut_native.dut.native_handle_flag_dbg[lane],
              gen_dut_native.dut.native_exact_pre_valid_dbg[lane],
              gen_dut_native.dut.native_exact_pre_serial_dbg[lane],
              gen_dut_native.dut.native_exact_pre_ts_dbg[lane],
              gen_dut_native.dut.native_exact_pre_shd_dbg[lane],
              gen_dut_native.dut.native_exact_pre_hit_dbg[lane],
              gen_dut_native.dut.native_exact_post_valid_dbg[lane],
              gen_dut_native.dut.native_exact_post_serial_dbg[lane],
              gen_dut_native.dut.native_exact_post_ts_dbg[lane],
              gen_dut_native.dut.native_exact_post_shd_dbg[lane],
              gen_dut_native.dut.native_exact_post_hit_dbg[lane]
            );
          end

          if (gen_dut_native.dut.native_handle_we_dbg[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d handle_we flag=%0b src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.native_handle_flag_dbg[lane],
              gen_dut_native.dut.u_native.handle_wdata_dbg[lane][TB_HANDLE_SRC_HI:TB_HANDLE_SRC_LO],
              gen_dut_native.dut.u_native.handle_wdata_dbg[lane][TB_HANDLE_DST_HI:TB_HANDLE_DST_LO],
              gen_dut_native.dut.native_handle_block_len_dbg[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.handle_wptr[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_state[lane] == 3'd1) begin
            $display("[opq_boundary] t=%0t lane%0d mover_prep src=0x%0h dst=0x%0h len=%0d handle_rptr=0x%0h quantum=%0d",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_src[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_dst[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_blk_len[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_rptr[lane],
              gen_dut_native.dut.native_drr_quantum_dbg[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_page_wreq[lane] &&
              gen_dut_native.dut.native_drr_gnt_dbg[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d mover_write word_idx=%0d src=0x%0h dst=0x%0h len=%0d lane_rd=0x%0h lane_q=0x%0h page_addr=0x%0h page_data=0x%0h quantum=%0d",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_word_wr_cnt[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_src[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_dst[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_blk_len[lane],
              gen_dut_native.dut.u_native.lane_fifos_rd_addr[lane],
              gen_dut_native.dut.u_native.lane_fifos_rd_data[lane],
              gen_dut_native.dut.u_native.page_ram_wr_addr_dbg,
              gen_dut_native.dut.u_native.page_ram_wr_data_dbg,
              gen_dut_native.dut.native_drr_quantum_dbg[lane]);
          end

          if (gen_dut_native.dut.u_native.block_path_i.block_mover_lane_credit_update_valid[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d credit_return amount=%0d handle_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.u_native.block_path_i.block_mover_lane_credit_update[lane],
              gen_dut_native.dut.u_native.block_path_i.block_mover_handle_rptr[lane]);
          end

          if (gen_dut_native.dut.u_native.page_allocator_i.late_frame_lane_credit_update_valid[lane]) begin
            $display("[opq_boundary] t=%0t lane%0d late_credit_return amount=%0d ticket_rptr=0x%0h",
              $time,
              lane,
              gen_dut_native.dut.u_native.page_allocator_i.late_frame_lane_credit_update[lane],
              gen_dut_native.dut.u_native.page_allocator_i.page_allocator.ticket_rptr[lane]);
          end
        end
      end
    end
  end
`endif

`ifdef OPQ_USE_NATIVE_SV
  logic [OPQ_N_LANE-1:0][35:0] ingress_data_bus;
  logic [OPQ_N_LANE-1:0] ingress_valid_bus;
  logic [OPQ_N_LANE-1:0][OPQ_CHANNEL_WIDTH-1:0] ingress_channel_bus;
  logic [OPQ_N_LANE-1:0] ingress_sop_bus;
  logic [OPQ_N_LANE-1:0] ingress_eop_bus;
  logic [OPQ_N_LANE-1:0][2:0] ingress_error_bus;

  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_native_ingress_bus
      assign ingress_data_bus[i] = ingress_if[i].data;
      assign ingress_valid_bus[i] = ingress_if[i].valid[0];
      assign ingress_channel_bus[i] = ingress_if[i].channel;
      assign ingress_sop_bus[i] = ingress_if[i].startofpacket[0];
      assign ingress_eop_bus[i] = ingress_if[i].endofpacket[0];
      assign ingress_error_bus[i] = ingress_if[i].error;
    end
  endgenerate

  if (1) begin : gen_dut_native
    ordered_priority_queue_dut_array_sv #(
      .OPQ_N_LANE_PARAM(OPQ_N_LANE),
      .OPQ_N_SHD_PARAM(OPQ_N_SHD),
      .OPQ_PAGE_RAM_DEPTH_PARAM(OPQ_PAGE_RAM_DEPTH),
      .OPQ_LANE_FIFO_DEPTH_PARAM(OPQ_LANE_FIFO_DEPTH),
      .OPQ_TICKET_FIFO_DEPTH_PARAM(OPQ_TICKET_FIFO_DEPTH),
      .OPQ_HANDLE_FIFO_DEPTH_PARAM(OPQ_HANDLE_FIFO_DEPTH),
      .CHANNEL_WIDTH_PARAM(OPQ_CHANNEL_WIDTH),
      .PAGE_RAM_RD_WIDTH_PARAM(OPQ_PAGE_RAM_RD_WIDTH)
    ) dut (
      .asi_ingress_data(ingress_data_bus),
      .asi_ingress_valid(ingress_valid_bus),
      .asi_ingress_channel(ingress_channel_bus),
      .asi_ingress_startofpacket(ingress_sop_bus),
      .asi_ingress_endofpacket(ingress_eop_bus),
      .asi_ingress_error(ingress_error_bus),
      .aso_egress_data(egress_if.data),
      .aso_egress_valid(egress_if.valid),
      .aso_egress_ready(egress_if.ready),
      .aso_egress_startofpacket(egress_if.startofpacket),
      .aso_egress_endofpacket(egress_if.endofpacket),
      .aso_egress_error(egress_if.error),
      .aso_egress_empty(egress_if.empty),
      .avs_csr_address(csr_if.address),
      .avs_csr_read(csr_if.read),
      .avs_csr_write(csr_if.write),
      .avs_csr_writedata(csr_if.writedata),
      .avs_csr_readdata(csr_if.readdata),
      .avs_csr_readdatavalid(csr_if.readdatavalid),
      .avs_csr_waitrequest(csr_if.waitrequest),
      .avs_csr_burstcount(csr_if.burstcount),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
  end
`else
  if (OPQ_N_LANE == 2) begin : gen_dut_2lane
    ordered_priority_queue_dut_sv dut (
      .asi_ingress_0_data(ingress_if[0].data),
      .asi_ingress_0_valid(ingress_if[0].valid),
      .asi_ingress_0_channel(ingress_if[0].channel),
      .asi_ingress_0_startofpacket(ingress_if[0].startofpacket),
      .asi_ingress_0_endofpacket(ingress_if[0].endofpacket),
      .asi_ingress_0_error(ingress_if[0].error),
      .asi_ingress_1_data(ingress_if[1].data),
      .asi_ingress_1_valid(ingress_if[1].valid),
      .asi_ingress_1_channel(ingress_if[1].channel),
      .asi_ingress_1_startofpacket(ingress_if[1].startofpacket),
      .asi_ingress_1_endofpacket(ingress_if[1].endofpacket),
      .asi_ingress_1_error(ingress_if[1].error),
      .asi_ingress_2_data('0),
      .asi_ingress_2_valid('0),
      .asi_ingress_2_channel('0),
      .asi_ingress_2_startofpacket('0),
      .asi_ingress_2_endofpacket('0),
      .asi_ingress_2_error('0),
      .asi_ingress_3_data('0),
      .asi_ingress_3_valid('0),
      .asi_ingress_3_channel('0),
      .asi_ingress_3_startofpacket('0),
      .asi_ingress_3_endofpacket('0),
      .asi_ingress_3_error('0),
      .aso_egress_data(egress_if.data),
      .aso_egress_valid(egress_if.valid),
      .aso_egress_ready(egress_if.ready),
      .aso_egress_startofpacket(egress_if.startofpacket),
      .aso_egress_endofpacket(egress_if.endofpacket),
      .aso_egress_error(egress_if.error),
      .avs_csr_address(csr_if.address),
      .avs_csr_read(csr_if.read),
      .avs_csr_write(csr_if.write),
      .avs_csr_writedata(csr_if.writedata),
      .avs_csr_readdata(csr_if.readdata),
      .avs_csr_readdatavalid(csr_if.readdatavalid),
      .avs_csr_waitrequest(csr_if.waitrequest),
      .avs_csr_burstcount(csr_if.burstcount),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
  end else begin : gen_dut_4lane
`ifdef OPQ_USE_NATIVE_SV
    ordered_priority_queue_dut_sv dut4 (
      .asi_ingress_0_data(ingress_if[0].data),
      .asi_ingress_0_valid(ingress_if[0].valid),
      .asi_ingress_0_channel(ingress_if[0].channel),
      .asi_ingress_0_startofpacket(ingress_if[0].startofpacket),
      .asi_ingress_0_endofpacket(ingress_if[0].endofpacket),
      .asi_ingress_0_error(ingress_if[0].error),
      .asi_ingress_1_data(ingress_if[1].data),
      .asi_ingress_1_valid(ingress_if[1].valid),
      .asi_ingress_1_channel(ingress_if[1].channel),
      .asi_ingress_1_startofpacket(ingress_if[1].startofpacket),
      .asi_ingress_1_endofpacket(ingress_if[1].endofpacket),
      .asi_ingress_1_error(ingress_if[1].error),
      .asi_ingress_2_data(ingress_if[2].data),
      .asi_ingress_2_valid(ingress_if[2].valid),
      .asi_ingress_2_channel(ingress_if[2].channel),
      .asi_ingress_2_startofpacket(ingress_if[2].startofpacket),
      .asi_ingress_2_endofpacket(ingress_if[2].endofpacket),
      .asi_ingress_2_error(ingress_if[2].error),
      .asi_ingress_3_data(ingress_if[3].data),
      .asi_ingress_3_valid(ingress_if[3].valid),
      .asi_ingress_3_channel(ingress_if[3].channel),
      .asi_ingress_3_startofpacket(ingress_if[3].startofpacket),
      .asi_ingress_3_endofpacket(ingress_if[3].endofpacket),
      .asi_ingress_3_error(ingress_if[3].error),
      .aso_egress_data(egress_if.data),
      .aso_egress_valid(egress_if.valid),
      .aso_egress_ready(egress_if.ready),
      .aso_egress_startofpacket(egress_if.startofpacket),
      .aso_egress_endofpacket(egress_if.endofpacket),
      .aso_egress_error(egress_if.error),
      .avs_csr_address(csr_if.address),
      .avs_csr_read(csr_if.read),
      .avs_csr_write(csr_if.write),
      .avs_csr_writedata(csr_if.writedata),
      .avs_csr_readdata(csr_if.readdata),
      .avs_csr_readdatavalid(csr_if.readdatavalid),
      .avs_csr_waitrequest(csr_if.waitrequest),
      .avs_csr_burstcount(csr_if.burstcount),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
`else
    ordered_priority_queue_dut4 dut4 (
      .asi_ingress_0_data(ingress_if[0].data),
      .asi_ingress_0_valid(ingress_if[0].valid),
      .asi_ingress_0_channel(ingress_if[0].channel),
      .asi_ingress_0_startofpacket(ingress_if[0].startofpacket),
      .asi_ingress_0_endofpacket(ingress_if[0].endofpacket),
      .asi_ingress_0_error(ingress_if[0].error),
      .asi_ingress_1_data(ingress_if[1].data),
      .asi_ingress_1_valid(ingress_if[1].valid),
      .asi_ingress_1_channel(ingress_if[1].channel),
      .asi_ingress_1_startofpacket(ingress_if[1].startofpacket),
      .asi_ingress_1_endofpacket(ingress_if[1].endofpacket),
      .asi_ingress_1_error(ingress_if[1].error),
      .asi_ingress_2_data(ingress_if[2].data),
      .asi_ingress_2_valid(ingress_if[2].valid),
      .asi_ingress_2_channel(ingress_if[2].channel),
      .asi_ingress_2_startofpacket(ingress_if[2].startofpacket),
      .asi_ingress_2_endofpacket(ingress_if[2].endofpacket),
      .asi_ingress_2_error(ingress_if[2].error),
      .asi_ingress_3_data(ingress_if[3].data),
      .asi_ingress_3_valid(ingress_if[3].valid),
      .asi_ingress_3_channel(ingress_if[3].channel),
      .asi_ingress_3_startofpacket(ingress_if[3].startofpacket),
      .asi_ingress_3_endofpacket(ingress_if[3].endofpacket),
      .asi_ingress_3_error(ingress_if[3].error),
      .aso_egress_data(egress_if.data),
      .aso_egress_valid(egress_if.valid),
      .aso_egress_ready(egress_if.ready),
      .aso_egress_startofpacket(egress_if.startofpacket),
      .aso_egress_endofpacket(egress_if.endofpacket),
      .aso_egress_error(egress_if.error),
      .avs_csr_address(csr_if.address),
      .avs_csr_read(csr_if.read),
      .avs_csr_write(csr_if.write),
      .avs_csr_writedata(csr_if.writedata),
      .avs_csr_readdata(csr_if.readdata),
      .avs_csr_readdatavalid(csr_if.readdatavalid),
      .avs_csr_waitrequest(csr_if.waitrequest),
      .avs_csr_burstcount(csr_if.burstcount),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
`endif
  end

`endif

`ifndef OPQ_DISABLE_TB_SVA
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_ingress_sva
      opq_avst_ingress_sva #(
        .CHANNEL_WIDTH(OPQ_CHANNEL_WIDTH)
      ) ingress_sva (
        .clk(d_clk),
        .reset(d_reset),
        .data(ingress_if[i].data),
        .valid(ingress_if[i].valid),
        .channel(ingress_if[i].channel),
        .startofpacket(ingress_if[i].startofpacket),
        .endofpacket(ingress_if[i].endofpacket),
        .error(ingress_if[i].error)
      );
    end
  endgenerate

  opq_avst_egress_sva #(
    .DATA_WIDTH(OPQ_PAGE_RAM_RD_WIDTH),
    .SYMBOL_WIDTH(OPQ_EGRESS_SYMBOL_WIDTH),
    .SYMBOLS_PER_BEAT(OPQ_EGRESS_SYMBOLS_PER_BEAT),
    .EMPTY_WIDTH(OPQ_EGRESS_EMPTY_WIDTH)
  ) egress_sva (
    .clk(d_clk),
    .reset(d_reset),
    .data(egress_if.data),
    .valid(egress_if.valid),
    .ready(egress_if.ready),
    .startofpacket(egress_if.startofpacket),
    .endofpacket(egress_if.endofpacket),
    .error(egress_if.error),
    .empty(egress_if.empty)
  );

  opq_csr_sva csr_sva (
    .clk(d_clk),
    .reset(d_reset),
    .address(csr_if.address),
    .read(csr_if.read),
    .write(csr_if.write),
    .writedata(csr_if.writedata),
    .burstcount(csr_if.burstcount),
    .waitrequest(csr_if.waitrequest),
    .readdatavalid(csr_if.readdatavalid)
  );

  opq_hit3_contract_sva hit3_contract_sva (
    .clk(d_clk),
    .reset(d_reset),
    .data(hit3_symbol_data),
    .valid(hit3_symbol_valid),
    .ready(1'b1)
  );

`ifndef OPQ_USE_NATIVE_SV
  if (OPQ_N_LANE == 2) begin : gen_drr_sva_2lane
    opq_drr_sva #(
      .N_LANE(OPQ_N_LANE)
    ) drr_sva (
      .clk(d_clk),
      .reset(d_reset),
      .req_raw(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_req),
      .req_eligible(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_req_eligible),
      .gnt(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_gnt),
      .sel_mask(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_sel_mask_dbg),
      .lock_event(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_lock_event),
      .defer_event(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_defer_event),
      .locked(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_locked),
      .pa_write(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_pa_write)
    );
  end else begin : gen_drr_sva_4lane
    opq_drr_sva #(
      .N_LANE(OPQ_N_LANE)
    ) drr_sva (
      .clk(d_clk),
      .reset(d_reset),
      .req_raw(gen_dut_4lane.dut4.u_impl.b2p_arb_req),
      .req_eligible(gen_dut_4lane.dut4.u_impl.b2p_arb_req_eligible),
      .gnt(gen_dut_4lane.dut4.u_impl.b2p_arb_gnt),
      .sel_mask(gen_dut_4lane.dut4.u_impl.b2p_arb_sel_mask_dbg),
      .lock_event(gen_dut_4lane.dut4.u_impl.b2p_arb_lock_event),
      .defer_event(gen_dut_4lane.dut4.u_impl.b2p_arb_defer_event),
      .locked(gen_dut_4lane.dut4.u_impl.b2p_arb_locked),
      .pa_write(gen_dut_4lane.dut4.u_impl.b2p_arb_pa_write)
    );
  end
`endif
`endif

  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_cfg_db
      initial begin
        uvm_config_db#(virtual opq_ingress_if)::set(null, "*", $sformatf("ingress_vif_%0d", i), ingress_if[i]);
      end
    end
  endgenerate

  initial begin
    opq_dut_cfg dut_cfg;

    csr_if.idle();
    dut_cfg = opq_dut_cfg::type_id::create("dut_cfg");
    uvm_config_db#(virtual opq_egress_if)::set(null, "*", "egress_vif", egress_if);
    uvm_config_db#(virtual opq_csr_if)::set(null, "*", "csr_vif", csr_if);
    uvm_config_db#(virtual opq_drop_if #(OPQ_N_LANE))::set(null, "*", "drop_vif", drop_if);
    uvm_config_db#(opq_dut_cfg)::set(null, "*", "dut_cfg", dut_cfg);
    run_test();
  end
endmodule

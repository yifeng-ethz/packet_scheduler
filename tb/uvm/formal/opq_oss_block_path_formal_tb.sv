//------------------------------------------------------------------------------
// IP Name   : opq_oss_block_path_formal_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - OSS Yosys/SBY block-path proof harness
// Description:
//   Yosys/SymbiYosys-friendly harness for the native-SV block mover / DRR
//   arbiter. The proof target is page-writer ownership plus onehot/eligibility
//   invariants on the live arbiter outputs.
//------------------------------------------------------------------------------
module opq_oss_block_path_formal_tb;
  localparam int unsigned N_LANE = 2;
  localparam int unsigned CHANNEL_WIDTH = 2;
  localparam int unsigned LANE_FIFO_DEPTH = 8;
  localparam int unsigned LANE_FIFO_WIDTH = 40;
  localparam int unsigned HANDLE_FIFO_DEPTH = 4;
  localparam int unsigned PAGE_RAM_DEPTH = 16;
  localparam int unsigned N_HIT = 8;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT;
  localparam int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH);
  localparam int unsigned FIFO_RAW_DELAY = 2;
  localparam int unsigned FIFO_RD_DELAY = 1;
  localparam int unsigned PAGE_RAM_DATA_WIDTH = 40;
  localparam int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH);
  localparam int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH);
  localparam int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH);
  localparam int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS;

  (* gclk *) reg gclk;
  reg f_past_valid = 1'b0;
  reg [1:0] f_reset_sr = 2'b11;
  reg [3:0] f_post_reset_sr = 4'b0000;

  wire d_reset = f_reset_sr[1];

  (* anyseq *) reg [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_wptr_i;
  (* anyseq *) reg [N_LANE-1:0]                             handle_we_i;
  (* anyseq *) reg [N_LANE-1:0][HANDLE_LENGTH:0]            handle_fifos_rd_data_i;
  (* anyseq *) reg [N_LANE-1:0][LANE_FIFO_WIDTH-1:0]        lane_fifos_rd_data_i;
  (* anyseq *) reg                                          fetch_ticket_active_i;
  (* anyseq *) reg [N_LANE-1:0]                             tk_future_i;
  (* anyseq *) reg                                          page_allocator_write_head_i;
  (* anyseq *) reg                                          page_allocator_write_tail_i;
  (* anyseq *) reg                                          page_allocator_write_page_i;
  (* anyseq *) reg                                          page_allocator_page_we_i;
  (* anyseq *) reg [PAGE_RAM_ADDR_WIDTH-1:0]                page_allocator_page_waddr_i;
  (* anyseq *) reg [PAGE_RAM_DATA_WIDTH-1:0]                page_allocator_page_wdata_i;
  (* anyseq *) reg [N_LANE-1:0][9:0]                        drr_allowance_i;
  (* anyseq *) reg [N_LANE-1:0]                             drr_allowance_reload_i;

  wire [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]             handle_fifos_rd_addr_o;
  wire [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]               lane_fifos_rd_addr_o;
  wire [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]               lane_credit_update_o;
  wire [N_LANE-1:0]                                         lane_credit_update_valid_o;
  wire                                                      page_ram_we_o;
  wire [PAGE_RAM_ADDR_WIDTH-1:0]                            page_ram_wr_addr_o;
  wire [PAGE_RAM_DATA_WIDTH-1:0]                            page_ram_wr_data_o;
  wire [N_LANE-1:0]                                         req_raw_dbg_oss;
  wire [N_LANE-1:0]                                         req_eligible_dbg_oss;
  wire [N_LANE-1:0]                                         gnt_dbg_oss;
  wire [N_LANE-1:0]                                         sel_mask_dbg_oss;
  wire [N_LANE-1:0]                                         priority_mask_dbg_oss;
  wire [N_LANE-1:0]                                         lock_event_dbg_oss;
  wire [N_LANE-1:0]                                         defer_event_dbg_oss;
  wire [N_LANE-1:0]                                         lock_req_raw_dbg_oss;
  wire [N_LANE-1:0]                                         lock_req_eligible_dbg_oss;
  wire [N_LANE-1:0]                                         defer_req_raw_dbg_oss;
  wire [N_LANE-1:0]                                         defer_req_eligible_dbg_oss;
  wire                                                      locked_dbg_oss;
  wire                                                      page_ram_src_is_pa_dbg_oss;
  wire [N_LANE-1:0]                                         page_ram_src_lane_dbg_oss;
  wire [PAGE_RAM_ADDR_WIDTH-1:0]                            page_ram_src_addr_dbg_oss;
  wire [PAGE_RAM_DATA_WIDTH-1:0]                            page_ram_src_data_dbg_oss;
  wire                                                      page_ram_src_valid_comb_dbg_oss;
  wire                                                      page_ram_src_is_pa_comb_dbg_oss;
  wire [N_LANE-1:0]                                         page_ram_src_lane_comb_dbg_oss;
  wire [PAGE_RAM_ADDR_WIDTH-1:0]                            page_ram_src_addr_comb_dbg_oss;
  wire [PAGE_RAM_DATA_WIDTH-1:0]                            page_ram_src_data_comb_dbg_oss;

  wire pa_write =
    page_allocator_write_head_i ||
    page_allocator_write_tail_i ||
    page_allocator_write_page_i ||
    page_allocator_page_we_i;

  wire pa_direct_write =
    page_allocator_write_head_i ||
    page_allocator_write_tail_i ||
    page_allocator_write_page_i;

  ordered_priority_queue_monolithic_block_path #(
    .N_LANE(N_LANE),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .LANE_FIFO_WIDTH(LANE_FIFO_WIDTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .N_HIT(N_HIT),
    .HIT_SIZE(HIT_SIZE),
    .MAX_PKT_LENGTH(MAX_PKT_LENGTH),
    .MAX_PKT_LENGTH_BITS(MAX_PKT_LENGTH_BITS),
    .FIFO_RAW_DELAY(FIFO_RAW_DELAY),
    .FIFO_RD_DELAY(FIFO_RD_DELAY),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .LANE_FIFO_ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .HANDLE_FIFO_ADDR_WIDTH(HANDLE_FIFO_ADDR_WIDTH),
    .HANDLE_LENGTH(HANDLE_LENGTH)
  ) dut (
    .handle_wptr_i(handle_wptr_i),
    .handle_we_i(handle_we_i),
    .handle_fifos_rd_data_i(handle_fifos_rd_data_i),
    .lane_fifos_rd_data_i(lane_fifos_rd_data_i),
    .fetch_ticket_active_i(fetch_ticket_active_i),
    .tk_future_i(tk_future_i),
    .page_allocator_write_head_i(page_allocator_write_head_i),
    .page_allocator_write_tail_i(page_allocator_write_tail_i),
    .page_allocator_write_page_i(page_allocator_write_page_i),
    .page_allocator_page_we_i(page_allocator_page_we_i),
    .page_allocator_page_waddr_i(page_allocator_page_waddr_i),
    .page_allocator_page_wdata_i(page_allocator_page_wdata_i),
    .drr_allowance_i(drr_allowance_i),
    .drr_allowance_reload_i(drr_allowance_reload_i),
    .handle_fifos_rd_addr_o(handle_fifos_rd_addr_o),
    .lane_fifos_rd_addr_o(lane_fifos_rd_addr_o),
    .lane_credit_update_o(lane_credit_update_o),
    .lane_credit_update_valid_o(lane_credit_update_valid_o),
    .page_ram_we_o(page_ram_we_o),
    .page_ram_wr_addr_o(page_ram_wr_addr_o),
    .page_ram_wr_data_o(page_ram_wr_data_o),
    .req_raw_dbg_oss(req_raw_dbg_oss),
    .req_eligible_dbg_oss(req_eligible_dbg_oss),
    .gnt_dbg_oss(gnt_dbg_oss),
    .sel_mask_dbg_oss(sel_mask_dbg_oss),
    .priority_mask_dbg_oss(priority_mask_dbg_oss),
    .lock_event_dbg_oss(lock_event_dbg_oss),
    .defer_event_dbg_oss(defer_event_dbg_oss),
    .lock_req_raw_dbg_oss(lock_req_raw_dbg_oss),
    .lock_req_eligible_dbg_oss(lock_req_eligible_dbg_oss),
    .defer_req_raw_dbg_oss(defer_req_raw_dbg_oss),
    .defer_req_eligible_dbg_oss(defer_req_eligible_dbg_oss),
    .locked_dbg_oss(locked_dbg_oss),
    .page_ram_src_is_pa_dbg_oss(page_ram_src_is_pa_dbg_oss),
    .page_ram_src_lane_dbg_oss(page_ram_src_lane_dbg_oss),
    .page_ram_src_addr_dbg_oss(page_ram_src_addr_dbg_oss),
    .page_ram_src_data_dbg_oss(page_ram_src_data_dbg_oss),
    .page_ram_src_valid_comb_dbg_oss(page_ram_src_valid_comb_dbg_oss),
    .page_ram_src_is_pa_comb_dbg_oss(page_ram_src_is_pa_comb_dbg_oss),
    .page_ram_src_lane_comb_dbg_oss(page_ram_src_lane_comb_dbg_oss),
    .page_ram_src_addr_comb_dbg_oss(page_ram_src_addr_comb_dbg_oss),
    .page_ram_src_data_comb_dbg_oss(page_ram_src_data_comb_dbg_oss),
    .d_clk(gclk),
    .d_reset(d_reset)
  );

  always @(posedge gclk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(d_reset);
    end
    if (f_reset_sr != 2'b00) begin
      f_reset_sr <= {f_reset_sr[0], 1'b0};
    end
    if (d_reset) begin
      f_post_reset_sr <= 4'b0000;
    end else begin
      f_post_reset_sr <= {f_post_reset_sr[2:0], 1'b1};
    end

    if (d_reset) begin
      assume(!page_ram_we_o);
      assume(page_ram_wr_addr_o == '0);
      assume(page_ram_wr_data_o == '0);
    end else begin
      assume(!(page_allocator_write_head_i && page_allocator_write_tail_i));
      assume(!(page_allocator_write_head_i && page_allocator_write_page_i));
      assume(!(page_allocator_write_tail_i && page_allocator_write_page_i));
      if (!(&f_post_reset_sr)) begin
        assume(!page_ram_we_o);
      end
    end

    if (f_past_valid && (&f_post_reset_sr)) begin
      assert($onehot0(gnt_dbg_oss));
      assert($onehot0(sel_mask_dbg_oss));
      assert($onehot0(lock_event_dbg_oss));

      if (pa_write) begin
        assert(gnt_dbg_oss == '0);
      end
      if (locked_dbg_oss) begin
        assert(sel_mask_dbg_oss != '0);
      end
      if (!locked_dbg_oss && !pa_write && (req_eligible_dbg_oss == '0)) begin
        assert(gnt_dbg_oss == '0);
      end

      if (page_ram_we_o) begin
        assert(page_ram_wr_addr_o == page_ram_src_addr_dbg_oss);
        assert(page_ram_wr_data_o == page_ram_src_data_dbg_oss);
      end

      for (int lane = 0; lane < N_LANE; lane++) begin
        if (!locked_dbg_oss && gnt_dbg_oss[lane] && !pa_write) begin
          assert(req_eligible_dbg_oss[lane] && req_raw_dbg_oss[lane]);
        end
      end
    end

    cover(f_past_valid && (req_raw_dbg_oss != '0));
    cover(f_past_valid && (defer_event_dbg_oss != '0));
    cover(f_past_valid && (lock_event_dbg_oss != '0));
    cover(f_past_valid && page_ram_we_o && !$past(pa_direct_write));
  end
endmodule

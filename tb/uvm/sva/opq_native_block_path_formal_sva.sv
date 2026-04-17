//------------------------------------------------------------------------------
// IP Name   : opq_native_block_path_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - align page-writer ownership invariants to registered page-RAM outputs
// Description:
//   Native-SV formal checker for the block mover / DRR arbiter. These checks
//   prove the page-RAM writer ownership and lane-data forwarding rules from
//   DV_FORMAL plane C/D.
//------------------------------------------------------------------------------
module opq_native_block_path_formal_sva #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH)
) (
  input logic                                      d_clk,
  input logic                                      d_reset,
  input logic                                      page_allocator_write_head_i,
  input logic                                      page_allocator_write_tail_i,
  input logic                                      page_allocator_write_page_i,
  input logic                                      page_allocator_page_we_i,
  input logic [PAGE_RAM_ADDR_WIDTH-1:0]            page_allocator_page_waddr_i,
  input logic [PAGE_RAM_DATA_WIDTH-1:0]            page_allocator_page_wdata_i,
  input logic [N_LANE-1:0][PAGE_RAM_DATA_WIDTH-1:0] lane_fifos_rd_data_i,
  input logic                                      page_ram_we_o,
  input logic [PAGE_RAM_ADDR_WIDTH-1:0]            page_ram_wr_addr_o,
  input logic [PAGE_RAM_DATA_WIDTH-1:0]            page_ram_wr_data_o,
  input logic [N_LANE-1:0]                         req_raw,
  input logic [N_LANE-1:0]                         req_eligible,
  input logic [N_LANE-1:0]                         gnt,
  input logic [N_LANE-1:0]                         sel_mask,
  input logic [N_LANE-1:0]                         lock_event,
  input logic [N_LANE-1:0]                         defer_event,
  input logic                                      locked
);
  logic pa_write;
  logic pa_direct_write;
  logic past_valid;

  assign pa_write = page_allocator_write_page_i ||
    page_allocator_write_head_i ||
    page_allocator_write_tail_i ||
    page_allocator_page_we_i;
  assign pa_direct_write = page_allocator_write_page_i ||
    page_allocator_write_head_i ||
    page_allocator_write_tail_i;

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      past_valid <= 1'b0;
    end else begin
      past_valid <= 1'b1;
    end
  end

  assert property (@(posedge d_clk) disable iff (d_reset) $onehot0(gnt))
    else $error("OPQ_NATIVE_BLOCK_FORMAL grant is not onehot0");

  assert property (@(posedge d_clk) disable iff (d_reset) $onehot0(sel_mask))
    else $error("OPQ_NATIVE_BLOCK_FORMAL sel_mask is not onehot0");

  assert property (@(posedge d_clk) disable iff (d_reset) $onehot0(lock_event))
    else $error("OPQ_NATIVE_BLOCK_FORMAL lock_event is not onehot0");

  assert property (@(posedge d_clk) disable iff (d_reset)
    pa_write |-> (gnt == '0))
    else $error("OPQ_NATIVE_BLOCK_FORMAL page-allocator write did not suppress mover grants");

  assert property (@(posedge d_clk) disable iff (d_reset)
    locked |-> (sel_mask != '0))
    else $error("OPQ_NATIVE_BLOCK_FORMAL locked arbiter lost its owner");

  assert property (@(posedge d_clk) disable iff (d_reset)
    !locked && !pa_write && (req_eligible == '0) |-> (gnt == '0))
    else $error("OPQ_NATIVE_BLOCK_FORMAL arbiter granted without eligible requests");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    page_ram_we_o && $past(pa_direct_write) |-> $past(page_allocator_page_we_i) &&
      (page_ram_wr_addr_o == $past(page_allocator_page_waddr_i)) &&
      (page_ram_wr_data_o == $past(page_allocator_page_wdata_i)))
    else $error("OPQ_NATIVE_BLOCK_FORMAL page-allocator write data/address mismatch");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    page_ram_we_o && !$past(pa_direct_write) |-> $onehot($past(gnt & req_raw)))
    else $error("OPQ_NATIVE_BLOCK_FORMAL page RAM write did not come from exactly one mover writer");

  generate
    genvar lane;
    for (lane = 0; lane < N_LANE; lane++) begin : gen_lane
      assert property (@(posedge d_clk) disable iff (d_reset)
        !locked && gnt[lane] && !pa_write |-> req_eligible[lane] && req_raw[lane])
        else $error("OPQ_NATIVE_BLOCK_FORMAL lane %0d freshly granted without eligibility", lane);

      assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
        $past(gnt[lane] && req_raw[lane] && !pa_write) |->
          page_ram_we_o && (page_ram_wr_data_o == $past(lane_fifos_rd_data_i[lane])))
        else $error("OPQ_NATIVE_BLOCK_FORMAL lane %0d page write data mismatch", lane);

      assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
        defer_event[lane] |-> $past(req_raw[lane] && !req_eligible[lane]))
        else $error("OPQ_NATIVE_BLOCK_FORMAL defer_event on lane %0d without blocked request", lane);

      assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
        lock_event[lane] |-> $past(gnt[lane] && req_raw[lane] && req_eligible[lane]))
        else $error("OPQ_NATIVE_BLOCK_FORMAL lock_event on lane %0d without eligible request", lane);

      cover property (@(posedge d_clk) disable iff (d_reset)
        req_raw[lane] && !req_eligible[lane] ##1 defer_event[lane] ##[1:16]
        req_raw[lane] && req_eligible[lane] ##1 lock_event[lane]);
    end
  endgenerate
endmodule

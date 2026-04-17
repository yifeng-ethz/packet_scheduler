//------------------------------------------------------------------------------
// IP Name   : opq_formal_ftable_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - standalone elaboration top for frame-table formal checkers
// Description:
//   Minimal standalone top that elaborates the translated frame-table tracker
//   and tiled presenter path so their formal checker modules can be compiled
//   and elaborated even before the live signoff top swaps over to them.
//------------------------------------------------------------------------------
module opq_formal_ftable_tb;
  localparam int unsigned N_TILE = 5;
  localparam int unsigned N_WR_SEG = 4;
  localparam int unsigned TILE_FIFO_DEPTH = 32;
  localparam int unsigned PAGE_RAM_DEPTH = 256;
  localparam int unsigned PAGE_RAM_DATA_WIDTH = 40;
  localparam int unsigned TILE_PKT_CNT_WIDTH = 10;
  localparam int unsigned TILE_ID_WIDTH = $clog2(N_TILE);
  localparam int unsigned TILE_FIFO_ADDR_WIDTH = $clog2(TILE_FIFO_DEPTH);
  localparam int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH);

  logic d_clk;
  logic d_reset;

  logic [1:0]                                      update_ftable_valid;
  logic [1:0][TILE_ID_WIDTH-1:0]                   update_ftable_tindex;
  logic [1:0]                                      update_ftable_meta_valid;
  logic [1:0][2*PAGE_RAM_ADDR_WIDTH-1:0]           update_ftable_meta;
  logic [1:0]                                      update_ftable_trltl_valid;
  logic [1:0][TILE_ID_WIDTH-1:0]                   update_ftable_trltl;
  logic [1:0]                                      update_ftable_bdytl_valid;
  logic [1:0][TILE_ID_WIDTH-1:0]                   update_ftable_bdytl;
  logic [1:0]                                      update_ftable_hcmpl;
  logic [1:0]                                      flush_ftable_valid;

  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0]     tile_fifo_rd_addr;
  logic [N_TILE-1:0][2*PAGE_RAM_ADDR_WIDTH-1:0]    tile_fifo_rd_data;
  logic [N_TILE-1:0][PAGE_RAM_DATA_WIDTH-1:0]      page_tile_rd_data;
  logic [N_TILE-1:0][PAGE_RAM_ADDR_WIDTH-1:0]      page_tile_rd_addr;
  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0]     tile_rptr;
  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]       tile_pkt_rcnt;
  logic [TILE_ID_WIDTH-1:0]                        rseg_tile_index;
  logic                                            void_trail_tid;
  logic                                            void_body_tid;
  logic                                            presenter_active;
  logic                                            presenter_warping;
  logic                                            is_rd_tile_in_range;
  logic                                            crossing_tile_valid;
  logic [TILE_ID_WIDTH-1:0]                        crossing_tile;
  logic                                            trailing_active0;
  logic [TILE_ID_WIDTH-1:0]                        trailing_tile_index;
  logic [2:0]                                      presenter_state;
  logic                                            egress_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0]                  egress_data;
  logic                                            egress_startofpacket;
  logic                                            egress_endofpacket;
  logic                                            egress_ready;

  logic [N_TILE-1:0]                               tile_fifo_we;
  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0]     tile_fifo_wr_addr;
  logic [N_TILE-1:0][2*PAGE_RAM_ADDR_WIDTH-1:0]    tile_fifo_wr_data;
  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0]     tile_wptr;
  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]       tile_pkt_wcnt;
  logic [N_TILE-1:0][TILE_ID_WIDTH:0]              trail_tid;
  logic [N_TILE-1:0][TILE_ID_WIDTH:0]              body_tid;

  logic [N_WR_SEG-1:0][TILE_ID_WIDTH-1:0]          wseg_tile_index;
  logic [TILE_ID_WIDTH-1:0]                        leading_wr_tile_index_reg;
  logic                                            mapper_busy;
  logic                                            pa_write_head_start;

  initial begin
    d_clk = 1'b0;
    forever #1 d_clk = ~d_clk;
  end

  initial begin
    d_reset = 1'b1;
    egress_ready = 1'b1;
    update_ftable_valid = '0;
    update_ftable_tindex = '0;
    update_ftable_meta_valid = '0;
    update_ftable_meta = '0;
    update_ftable_trltl_valid = '0;
    update_ftable_trltl = '0;
    update_ftable_bdytl_valid = '0;
    update_ftable_bdytl = '0;
    update_ftable_hcmpl = '0;
    flush_ftable_valid = '0;
    page_tile_rd_data = '0;
    wseg_tile_index = '0;
    leading_wr_tile_index_reg = '0;
    mapper_busy = 1'b0;
    pa_write_head_start = 1'b0;
    #4 d_reset = 1'b0;
  end

  assign tile_fifo_rd_data = tile_fifo_wr_data;

  ordered_priority_queue_monolithic_frame_table_tracker #(
    .N_TILE(N_TILE),
    .TILE_FIFO_DEPTH(TILE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .TILE_PKT_CNT_WIDTH(TILE_PKT_CNT_WIDTH)
  ) tracker_dut (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .i_update_ftable_valid(update_ftable_valid),
    .i_update_ftable_tindex(update_ftable_tindex),
    .i_update_ftable_meta_valid(update_ftable_meta_valid),
    .i_update_ftable_meta(update_ftable_meta),
    .i_update_ftable_trltl_valid(update_ftable_trltl_valid),
    .i_update_ftable_trltl(update_ftable_trltl),
    .i_update_ftable_bdytl_valid(update_ftable_bdytl_valid),
    .i_update_ftable_bdytl(update_ftable_bdytl),
    .i_update_ftable_hcmpl(update_ftable_hcmpl),
    .i_flush_ftable_valid(flush_ftable_valid),
    .i_tile_rptr(tile_rptr),
    .i_tile_pkt_rcnt(tile_pkt_rcnt),
    .i_rseg_tile_index(rseg_tile_index),
    .i_void_trail_tid(void_trail_tid),
    .i_void_body_tid(void_body_tid),
    .o_tile_fifo_we(tile_fifo_we),
    .o_tile_fifo_wr_addr(tile_fifo_wr_addr),
    .o_tile_fifo_wr_data(tile_fifo_wr_data),
    .o_tile_wptr(tile_wptr),
    .o_tile_pkt_wcnt(tile_pkt_wcnt),
    .o_trail_tid(trail_tid),
    .o_body_tid(body_tid)
  );

  ordered_priority_queue_monolithic_frame_table_presenter #(
    .N_TILE(N_TILE),
    .N_WR_SEG(N_WR_SEG),
    .TILE_FIFO_DEPTH(TILE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .TILE_PKT_CNT_WIDTH(TILE_PKT_CNT_WIDTH)
  ) presenter_dut (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .i_wseg_tile_index(wseg_tile_index),
    .i_leading_wr_tile_index_reg(leading_wr_tile_index_reg),
    .i_mapper_busy(mapper_busy),
    .i_pa_write_head_start(pa_write_head_start),
    .i_tile_wptr(tile_wptr),
    .i_tile_pkt_wcnt(tile_pkt_wcnt),
    .i_trail_tid(trail_tid),
    .i_body_tid(body_tid),
    .i_tile_fifo_rd_data(tile_fifo_rd_data),
    .i_page_tile_rd_data(page_tile_rd_data),
    .i_egress_ready(egress_ready),
    .o_tile_fifo_rd_addr(tile_fifo_rd_addr),
    .o_page_tile_rd_addr(page_tile_rd_addr),
    .o_tile_rptr(tile_rptr),
    .o_tile_pkt_rcnt(tile_pkt_rcnt),
    .o_rseg_tile_index(rseg_tile_index),
    .o_void_trail_tid(void_trail_tid),
    .o_void_body_tid(void_body_tid),
    .o_presenter_active(presenter_active),
    .o_presenter_warping(presenter_warping),
    .o_is_rd_tile_in_range(is_rd_tile_in_range),
    .o_crossing_tile_valid(crossing_tile_valid),
    .o_crossing_tile(crossing_tile),
    .o_trailing_active0(trailing_active0),
    .o_trailing_tile_index(trailing_tile_index),
    .o_state(presenter_state),
    .o_egress_valid(egress_valid),
    .o_egress_data(egress_data),
    .o_egress_startofpacket(egress_startofpacket),
    .o_egress_endofpacket(egress_endofpacket)
  );
endmodule

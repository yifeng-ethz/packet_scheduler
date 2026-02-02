interface ftable_if #(
  parameter int N_LANE = 2,
  parameter int HANDLE_PTR_WIDTH = 6,
  parameter int PAGE_RAM_ADDR_W = 9,
  parameter int DATA_W = 40,
  parameter int SHD_CNT_WIDTH = 16,
  parameter int HIT_CNT_WIDTH = 16,
  parameter int N_WR_SEG = 4,
  parameter int TILE_ID_W = 3
) (
  input logic clk
);
  logic rst;

  // Page allocator events + counters.
  logic pa_write_head_start;
  logic [PAGE_RAM_ADDR_W-1:0] pa_frame_start_addr;
  logic [SHD_CNT_WIDTH-1:0] pa_frame_shr_cnt_this;
  logic [HIT_CNT_WIDTH-1:0] pa_frame_hit_cnt_this;

  logic pa_write_tail_done;
  logic pa_write_tail_active;
  logic [PAGE_RAM_ADDR_W-1:0] pa_frame_start_addr_last;
  logic [SHD_CNT_WIDTH-1:0] pa_frame_shr_cnt;
  logic [HIT_CNT_WIDTH-1:0] pa_frame_hit_cnt;
  logic pa_frame_invalid_last;
  logic [N_LANE*HANDLE_PTR_WIDTH-1:0] pa_handle_wptr_flat;

  // Block mover status.
  logic [N_LANE*HANDLE_PTR_WIDTH-1:0] bm_handle_rptr_flat;

  // Page RAM write port.
  logic page_ram_we;
  logic [PAGE_RAM_ADDR_W-1:0] page_ram_wr_addr;
  logic [DATA_W-1:0] page_ram_wr_data;

  // Egress.
  logic egress_ready;
  logic egress_valid;
  logic [DATA_W-1:0] egress_data;
  logic egress_sop;
  logic egress_eop;

  // Status/debug.
  logic wr_blocked_by_rd_lock;
  logic [2:0] mapper_state;
  logic [2:0] presenter_state;
  logic [TILE_ID_W-1:0] rseg_tile_index;
  logic [N_WR_SEG*TILE_ID_W-1:0] wseg_tile_index_flat;

  task automatic drive_idle();
    pa_write_head_start <= 1'b0;
    pa_frame_start_addr <= '0;
    pa_frame_shr_cnt_this <= '0;
    pa_frame_hit_cnt_this <= '0;

    pa_write_tail_done <= 1'b0;
    pa_write_tail_active <= 1'b0;
    pa_frame_start_addr_last <= '0;
    pa_frame_shr_cnt <= '0;
    pa_frame_hit_cnt <= '0;
    pa_frame_invalid_last <= 1'b0;
    pa_handle_wptr_flat <= '0;

    bm_handle_rptr_flat <= '0;

    page_ram_we <= 1'b0;
    page_ram_wr_addr <= '0;
    page_ram_wr_data <= '0;

    egress_ready <= 1'b1;
  endtask

  modport drv (
    input  clk,
    input  rst,
    import drive_idle,
    output pa_write_head_start,
    output pa_frame_start_addr,
    output pa_frame_shr_cnt_this,
    output pa_frame_hit_cnt_this,
    output pa_write_tail_done,
    output pa_write_tail_active,
    output pa_frame_start_addr_last,
    output pa_frame_shr_cnt,
    output pa_frame_hit_cnt,
    output pa_frame_invalid_last,
    output pa_handle_wptr_flat,
    output bm_handle_rptr_flat,
    output page_ram_we,
    output page_ram_wr_addr,
    output page_ram_wr_data,
    input  wr_blocked_by_rd_lock,
    input  mapper_state,
    input  presenter_state,
    input  rseg_tile_index,
    input  wseg_tile_index_flat
  );

  modport mon (
    input clk,
    input rst,
    input pa_write_head_start,
    input pa_frame_start_addr,
    input pa_frame_shr_cnt_this,
    input pa_frame_hit_cnt_this,
    input pa_write_tail_done,
    input pa_write_tail_active,
    input pa_frame_start_addr_last,
    input pa_frame_shr_cnt,
    input pa_frame_hit_cnt,
    input pa_frame_invalid_last,
    input pa_handle_wptr_flat,
    input bm_handle_rptr_flat,
    input page_ram_we,
    input page_ram_wr_addr,
    input page_ram_wr_data,
    input egress_ready,
    input egress_valid,
    input egress_data,
    input egress_sop,
    input egress_eop,
    input wr_blocked_by_rd_lock,
    input mapper_state,
    input presenter_state,
    input rseg_tile_index,
    input wseg_tile_index_flat
  );
endinterface

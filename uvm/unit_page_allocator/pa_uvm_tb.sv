`timescale 1ns/1ps
import uvm_pkg::*;
import pa_pkg::*;

module pa_uvm_tb;
  // Must match pa_pkg localparams (and pa_if defaults).
  localparam int unsigned N_LANE = 4;
  localparam int unsigned N_SHD  = 8;
  localparam int unsigned CHANNEL_WIDTH = 2;

  localparam int unsigned LANE_FIFO_DEPTH   = 32;
  localparam int unsigned TICKET_FIFO_DEPTH = 1024;
  localparam int unsigned HANDLE_FIFO_DEPTH = 1024;
  localparam int unsigned PAGE_RAM_DEPTH    = 262144;

  localparam int unsigned PAGE_RAM_DATA_WIDTH = 40;
  localparam int unsigned HDR_SIZE = 5;
  localparam int unsigned SHD_SIZE = 1;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned TRL_SIZE = 1;
  localparam int unsigned N_HIT    = 255;

  localparam int unsigned FRAME_SERIAL_SIZE   = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE  = 16;
  localparam int unsigned SHD_CNT_WIDTH = 16;
  localparam int unsigned HIT_CNT_WIDTH = 16;

  logic clk = 1'b0;
  always #2 clk = ~clk; // 250 MHz

  // Keep interface un-parameterized so UVM can bind a plain `virtual pa_if`.
  pa_if tb_if (clk);

  initial begin
    tb_if.rst = 1'b1;
    tb_if.drive_defaults();

    uvm_config_db#(virtual pa_if)::set(null, "*", "vif", tb_if);

    fork
      begin
        repeat (50) @(posedge clk);
        tb_if.rst = 1'b0;
      end
    join_none

    if ($test$plusargs("UVM_TESTNAME")) begin
      run_test();
    end else begin
      run_test("pa_test");
    end
  end

  opq_page_allocator_uvm_wrapper #(
    .N_LANE(N_LANE),
    .N_SHD(N_SHD),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .HDR_SIZE(HDR_SIZE),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .TRL_SIZE(TRL_SIZE),
    .N_HIT(N_HIT),
    .FRAME_SERIAL_SIZE(FRAME_SERIAL_SIZE),
    .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
    .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE),
    .SHD_CNT_WIDTH(SHD_CNT_WIDTH),
    .HIT_CNT_WIDTH(HIT_CNT_WIDTH)
  ) dut (
    .i_clk(tb_if.clk),
    .i_rst(tb_if.rst),
    .i_dt_type(tb_if.dt_type),
    .i_feb_id(tb_if.feb_id),
    .i_ticket_wptr_flat(tb_if.ticket_wptr_flat),
    .o_ticket_rd_addr_flat(tb_if.ticket_rd_addr_flat),
    .i_ticket_rd_data_flat(tb_if.ticket_rd_data_flat),
    .o_ticket_credit_update_valid(tb_if.ticket_credit_update_valid),
    .o_ticket_credit_update_flat(tb_if.ticket_credit_update_flat),
    .o_handle_we(tb_if.handle_we),
    .o_handle_wptr_flat(tb_if.handle_wptr_flat),
    .o_handle_wdata_flat(tb_if.handle_wdata_flat),
    .i_handle_rptr_flat(tb_if.handle_rptr_flat),
    .i_mover_busy(tb_if.mover_busy),
    .o_page_we(tb_if.page_we),
    .o_page_waddr(tb_if.page_waddr),
    .o_page_wdata(tb_if.page_wdata),
    .o_pa_write_head_start(tb_if.pa_write_head_start),
    .o_pa_frame_start_addr(tb_if.pa_frame_start_addr),
    .o_pa_frame_shr_cnt_this(tb_if.pa_frame_shr_cnt_this),
    .o_pa_frame_hit_cnt_this(tb_if.pa_frame_hit_cnt_this),
    .o_pa_write_tail_done(tb_if.pa_write_tail_done),
    .o_pa_write_tail_active(tb_if.pa_write_tail_active),
    .o_pa_frame_start_addr_last(tb_if.pa_frame_start_addr_last),
    .o_pa_frame_shr_cnt(tb_if.pa_frame_shr_cnt),
    .o_pa_frame_hit_cnt(tb_if.pa_frame_hit_cnt),
    .o_pa_frame_invalid_last(tb_if.pa_frame_invalid_last),
    .o_pa_handle_wptr_flat(tb_if.pa_handle_wptr_flat),
    .o_quantum_update(tb_if.quantum_update),
    .i_wr_blocked_by_rd_lock(tb_if.wr_blocked_by_rd_lock)
  );
endmodule

`timescale 1ns/1ps
import uvm_pkg::*;
import ftable_pkg::*;

module ftable_uvm_tb;
  // Must match ftable_pkg localparams.
  localparam int N_LANE = 2;
  localparam int N_TILE = 5;
  localparam int N_WR_SEG = 4;

  localparam int TILE_FIFO_DEPTH = 64;
  localparam int PAGE_RAM_DEPTH = 512;
  localparam int DATA_W = 40;

  localparam int SHD_CNT_WIDTH = 16;
  localparam int HIT_CNT_WIDTH = 16;
  localparam int HANDLE_PTR_WIDTH = 6;
  localparam int TILE_PKT_CNT_WIDTH = 10;
  localparam int EGRESS_DELAY = 2;

  localparam int SHD_SIZE = 1;
  localparam int HIT_SIZE = 1;
  localparam int HDR_SIZE = 5;
  localparam int TRL_SIZE = 1;

  localparam int PAGE_RAM_ADDR_W = $clog2(PAGE_RAM_DEPTH);
  localparam int TILE_ID_W = $clog2(N_TILE);

  logic clk = 1'b0;
  always #2 clk = ~clk; // 250 MHz

  // Keep the interface un-parameterized so UVM can bind a plain `virtual ftable_if`.
  // Width parameters must match the DUT instance below (defaults in ftable_if.sv).
  ftable_if tb_if (clk);

  int ready_mode = 1;
  int ready_hi_min = 1;
  int ready_hi_max = 32;
  int ready_lo_min = 1;
  int ready_lo_max = 64;
  int stall_cyc = 0;
  int stall_after_beats = 1;
  int stall_repeat = 0;
  int ready_countdown = 0;
  bit ready_state = 1'b1;
  bit stall_active = 1'b0;
  int stall_countdown = 0;
  int beats_since_sop = 0;
  bit in_pkt = 1'b0;
  bit stall_armed = 1'b1;
  bit stall_fired_pkt = 1'b0;

  initial begin
    void'($value$plusargs("EGRESS_READY_MODE=%d", ready_mode));
    void'($value$plusargs("READY_HI_MIN=%d", ready_hi_min));
    void'($value$plusargs("READY_HI_MAX=%d", ready_hi_max));
    void'($value$plusargs("READY_LO_MIN=%d", ready_lo_min));
    void'($value$plusargs("READY_LO_MAX=%d", ready_lo_max));
    void'($value$plusargs("STALL_CYC=%d", stall_cyc));
    void'($value$plusargs("STALL_AFTER_BEATS=%d", stall_after_beats));
    void'($value$plusargs("STALL_REPEAT=%d", stall_repeat));

    tb_if.rst = 1'b1;
    tb_if.drive_idle();
    tb_if.egress_ready = 1'b0;
    repeat (10) @(posedge clk);
    tb_if.rst = 1'b0;
  end

  // Egress backpressure patterns (configurable via plusargs).
  //   +EGRESS_READY_MODE=0 : always ready
  //   +EGRESS_READY_MODE=1 : light random backpressure (default, ~12.5% low)
  //   +EGRESS_READY_MODE=2 : bursty high/low windows (randomized lengths)
  //   +EGRESS_READY_MODE=3 : deterministic long stall mid-packet
  always @(posedge clk) begin
    if (tb_if.rst) begin
      tb_if.egress_ready <= 1'b0;
      ready_state <= 1'b1;
      ready_countdown <= 0;
      stall_active <= 1'b0;
      stall_countdown <= 0;
      beats_since_sop <= 0;
      in_pkt <= 1'b0;
      stall_armed <= 1'b1;
      stall_fired_pkt <= 1'b0;
    end else begin
      unique case (ready_mode)
        0: tb_if.egress_ready <= 1'b1;
        1: tb_if.egress_ready <= ($urandom_range(0, 7) != 0);
        3: begin
          if (stall_active) begin
            tb_if.egress_ready <= 1'b0;
            if (stall_countdown <= 1) begin
              stall_countdown <= 0;
              stall_active <= 1'b0;
            end else begin
              stall_countdown <= stall_countdown - 1;
            end
          end else begin
            bit next_in_pkt;
            int next_beats;
            next_in_pkt = in_pkt;
            next_beats = beats_since_sop;

            tb_if.egress_ready <= 1'b1;

            if (tb_if.egress_valid && tb_if.egress_ready) begin
              if (tb_if.egress_sop) begin
                next_in_pkt = 1'b1;
                next_beats = 1;
                stall_fired_pkt <= 1'b0;
              end else if (in_pkt) begin
                next_beats = beats_since_sop + 1;
              end
              if (tb_if.egress_eop) begin
                next_in_pkt = 1'b0;
                next_beats = 0;
              end
            end

            if (stall_armed && !stall_fired_pkt && (stall_cyc > 0) && next_in_pkt && (next_beats >= stall_after_beats)) begin
              stall_active <= 1'b1;
              stall_countdown <= stall_cyc;
              tb_if.egress_ready <= 1'b0;
              stall_fired_pkt <= 1'b1;
              if (!stall_repeat) stall_armed <= 1'b0;
            end

            in_pkt <= next_in_pkt;
            beats_since_sop <= next_beats;
          end
        end
        default: begin
          if (ready_countdown <= 0) begin
            ready_state <= ~ready_state;
            if (ready_state) begin
              ready_countdown <= $urandom_range(ready_lo_min, ready_lo_max);
            end else begin
              ready_countdown <= $urandom_range(ready_hi_min, ready_hi_max);
            end
          end else begin
            ready_countdown <= ready_countdown - 1;
          end
          tb_if.egress_ready <= ready_state;
        end
      endcase
    end
  end

  opq_frame_table_uvm_wrapper #(
    .N_LANE(N_LANE),
    .N_TILE(N_TILE),
    .N_WR_SEG(N_WR_SEG),
    .TILE_FIFO_DEPTH(TILE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_DATA_WIDTH(DATA_W),
    .SHD_CNT_WIDTH(SHD_CNT_WIDTH),
    .HIT_CNT_WIDTH(HIT_CNT_WIDTH),
    .HANDLE_PTR_WIDTH(HANDLE_PTR_WIDTH),
    .TILE_PKT_CNT_WIDTH(TILE_PKT_CNT_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .HDR_SIZE(HDR_SIZE),
    .TRL_SIZE(TRL_SIZE)
  ) dut (
    .i_clk(tb_if.clk),
    .i_rst(tb_if.rst),

    .i_pa_write_head_start(tb_if.pa_write_head_start),
    .i_pa_frame_start_addr(tb_if.pa_frame_start_addr),
    .i_pa_frame_shr_cnt_this(tb_if.pa_frame_shr_cnt_this),
    .i_pa_frame_hit_cnt_this(tb_if.pa_frame_hit_cnt_this),

    .i_pa_write_tail_done(tb_if.pa_write_tail_done),
    .i_pa_write_tail_active(tb_if.pa_write_tail_active),
    .i_pa_frame_start_addr_last(tb_if.pa_frame_start_addr_last),
    .i_pa_frame_shr_cnt(tb_if.pa_frame_shr_cnt),
    .i_pa_frame_hit_cnt(tb_if.pa_frame_hit_cnt),
    .i_pa_frame_invalid_last(tb_if.pa_frame_invalid_last),
    .i_pa_handle_wptr_flat(tb_if.pa_handle_wptr_flat),

    .i_bm_handle_rptr_flat(tb_if.bm_handle_rptr_flat),

    .i_page_ram_we(tb_if.page_ram_we),
    .i_page_ram_wr_addr(tb_if.page_ram_wr_addr),
    .i_page_ram_wr_data(tb_if.page_ram_wr_data),

    .i_egress_ready(tb_if.egress_ready),
    .o_egress_valid(tb_if.egress_valid),
    .o_egress_data(tb_if.egress_data),
    .o_egress_startofpacket(tb_if.egress_sop),
    .o_egress_endofpacket(tb_if.egress_eop),

    .o_wr_blocked_by_rd_lock(tb_if.wr_blocked_by_rd_lock),
    .o_mapper_state(tb_if.mapper_state),
    .o_presenter_state(tb_if.presenter_state),
    .o_rseg_tile_index(tb_if.rseg_tile_index),
    .o_wseg_tile_index_flat(tb_if.wseg_tile_index_flat)
  );

  initial begin
    uvm_config_db#(virtual ftable_if)::set(null, "*", "vif", tb_if);
    if ($test$plusargs("UVM_TESTNAME")) begin
      run_test();
    end else begin
      run_test("ftable_test");
    end
  end
endmodule

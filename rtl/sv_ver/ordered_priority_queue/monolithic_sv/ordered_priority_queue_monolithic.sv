//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_sv
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.3.14
// Date    : 20260417
// Change  : Add native DRR configuration hooks so the SV wrapper can expose a VHDL-compatible CSR plane
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_sv #(
  parameter int unsigned N_LANE = 2,
  parameter string MODE = "MERGING",
  parameter bit TRACK_HEADER = 1'b1,
  parameter int unsigned INGRESS_DATA_WIDTH = 32,
  parameter int unsigned INGRESS_DATAK_WIDTH = 4,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned LANE_FIFO_WIDTH = 40,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned FRAME_SERIAL_SIZE = 16,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned DEBUG_LV = 1,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A = 48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B,
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS
) (
  input  logic [N_LANE-1:0][INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data,
  input  logic [N_LANE-1:0]                                              asi_ingress_valid,
  input  logic [N_LANE-1:0][CHANNEL_WIDTH-1:0]                           asi_ingress_channel,
  input  logic [N_LANE-1:0]                                              asi_ingress_startofpacket,
  input  logic [N_LANE-1:0]                                              asi_ingress_endofpacket,
  input  logic [N_LANE-1:0][2:0]                                         asi_ingress_error,
  output logic [PAGE_RAM_RD_WIDTH-1:0]                                   aso_egress_data,
  output logic                                                           aso_egress_valid,
  input  logic                                                           aso_egress_ready,
  output logic                                                           aso_egress_startofpacket,
  output logic                                                           aso_egress_endofpacket,
  output logic [2:0]                                                     aso_egress_error,
  input  logic [N_LANE-1:0][9:0]                                         cfg_drr_allowance_i,
  input  logic [N_LANE-1:0]                                              cfg_drr_allowance_reload_i,
  input  logic                                                           d_clk,
  input  logic                                                           d_reset
);
  // ----------------------------------------------------------------------------
  // Source-level SystemVerilog rewrite in progress.
  // The default/basic data path is now native SV for:
  // - per-lane ingress parser
  // - shared page allocator
  // - handle reader / block mover / B2P arbiter
  // - single-page basic presenter
  //
  // Standalone frame-table tracker/presenter SV translations now exist in this
  // directory, but the top-level shell still uses the basic presenter until the
  // mapper and tiled page-ram hookup are swapped over and regression-backed.
  // ----------------------------------------------------------------------------

  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ingress_ticket_wdata;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ingress_ticket_wptr;
  logic [N_LANE-1:0] ingress_ticket_we;
  logic [N_LANE-1:0][LANE_FIFO_WIDTH-1:0] ingress_lane_wdata;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] ingress_lane_wptr;
  logic [N_LANE-1:0] ingress_lane_we;
  logic [N_LANE-1:0][47:0] ingress_running_ts_dbg;
  logic [N_LANE-1:0][5:0] ingress_dt_type_dbg;
  logic [N_LANE-1:0][15:0] ingress_feb_id_dbg;
  logic [N_LANE-1:0] ingress_alert_eop_dbg;
  logic [N_LANE-1:0] ingress_eop_flush_ack_dbg;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] lane_credit_update;
  logic [N_LANE-1:0] lane_credit_update_valid;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ticket_credit_update;
  logic [N_LANE-1:0] ticket_credit_update_valid;
  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ticket_fifos_rd_data;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifos_rd_addr;
  logic [N_LANE-1:0][LANE_FIFO_WIDTH-1:0] lane_fifos_rd_data;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] lane_fifos_rd_addr;
  logic [N_LANE-1:0][HANDLE_LENGTH:0] handle_fifos_rd_data;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_fifos_rd_addr;
  logic [N_LANE-1:0][HANDLE_LENGTH:0] handle_wdata_dbg;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_waddr_dbg;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_wptr_dbg;
  logic [N_LANE-1:0] handle_we_dbg;
  logic [N_LANE-1:0] tk_future_dbg;
  logic fetch_ticket_active_dbg;
  logic write_head_active_dbg;
  logic write_tail_active_dbg;
  logic write_page_active_dbg;
  logic [2:0] write_meta_flow_dbg;
  logic [2:0] write_meta_flow_d1_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] frame_start_addr_dbg;
  logic [$clog2(N_SHD * N_LANE):0] frame_shr_cnt_this_dbg;
  logic [15:0] frame_hit_cnt_this_dbg;
  logic page_we_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_waddr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_wdata_dbg;
  logic page_ram_we_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_wr_addr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_wr_data_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_rd_addr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data_dbg;
  logic packet_complete_pulse_dbg;
  logic [1:0] packet_complete_presenter_delay_dbg;
  logic packet_complete_presenter_dbg;

  for (genvar m = 0; m < N_LANE; m++) begin : g_storage
    ticket_fifo #(
      .DATA_WIDTH(TICKET_FIFO_DATA_WIDTH),
      .ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH)
    ) ticket_fifo_i (
      .data(ingress_ticket_wdata[m]),
      .read_addr(ticket_fifos_rd_addr[m]),
      .write_addr(ingress_ticket_wptr[m] - 1'b1),
      .we(ingress_ticket_we[m]),
      .clk(d_clk),
      .q(ticket_fifos_rd_data[m])
    );

    lane_fifo #(
      .DATA_WIDTH(LANE_FIFO_WIDTH),
      .ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH)
    ) lane_fifo_i (
      .data(ingress_lane_wdata[m]),
      .read_addr(lane_fifos_rd_addr[m]),
      .write_addr(ingress_lane_wptr[m] - 1'b1),
      .we(ingress_lane_we[m]),
      .clk(d_clk),
      .q(lane_fifos_rd_data[m])
    );

    handle_fifo #(
      .DATA_WIDTH(HANDLE_LENGTH + 1),
      .ADDR_WIDTH(HANDLE_FIFO_ADDR_WIDTH)
    ) handle_fifo_i (
      .data(handle_wdata_dbg[m]),
      .read_addr(handle_fifos_rd_addr[m]),
      .write_addr(handle_waddr_dbg[m]),
      .we(handle_we_dbg[m]),
      .clk(d_clk),
      .q(handle_fifos_rd_data[m])
    );
  end

  for (genvar g = 0; g < N_LANE; g++) begin : g_ingress_parser
    ordered_priority_queue_monolithic_ingress_parser #(
      .INGRESS_DATA_WIDTH(INGRESS_DATA_WIDTH),
      .INGRESS_DATAK_WIDTH(INGRESS_DATAK_WIDTH),
      .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
      .LANE_FIFO_WIDTH(LANE_FIFO_WIDTH),
      .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
      .N_HIT(N_HIT),
      .HIT_SIZE(HIT_SIZE),
      .FRAME_SERIAL_SIZE(FRAME_SERIAL_SIZE),
      .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
      .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE)
    ) ingress_parser_i (
      .asi_ingress_data(asi_ingress_data[g]),
      .asi_ingress_valid(asi_ingress_valid[g]),
      .asi_ingress_startofpacket(asi_ingress_startofpacket[g]),
      .asi_ingress_endofpacket(asi_ingress_endofpacket[g]),
      .asi_ingress_error(asi_ingress_error[g]),
      .lane_credit_update(lane_credit_update[g]),
      .lane_credit_update_valid(lane_credit_update_valid[g]),
      .ticket_credit_update(ticket_credit_update[g]),
      .ticket_credit_update_valid(ticket_credit_update_valid[g]),
      .ticket_wdata(ingress_ticket_wdata[g]),
      .ticket_wptr(ingress_ticket_wptr[g]),
      .ticket_we(ingress_ticket_we[g]),
      .lane_wdata(ingress_lane_wdata[g]),
      .lane_wptr(ingress_lane_wptr[g]),
      .lane_we(ingress_lane_we[g]),
      .running_ts_dbg(ingress_running_ts_dbg[g]),
      .dt_type_dbg(ingress_dt_type_dbg[g]),
      .feb_id_dbg(ingress_feb_id_dbg[g]),
      .alert_eop_state_o(ingress_alert_eop_dbg[g]),
      .eop_flush_ack_i(ingress_eop_flush_ack_dbg[g]),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
  end

  ordered_priority_queue_monolithic_page_allocator #(
    .N_LANE(N_LANE),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .HDR_SIZE(HDR_SIZE),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .TRL_SIZE(TRL_SIZE),
    .FRAME_SERIAL_SIZE(FRAME_SERIAL_SIZE),
    .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
    .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE)
  ) page_allocator_i (
    .ingress_ticket_wptr(ingress_ticket_wptr),
    .ticket_fifos_rd_data_i(ticket_fifos_rd_data),
    .ingress_alert_eop_i(ingress_alert_eop_dbg),
    .dt_type0(ingress_dt_type_dbg[0]),
    .feb_id0(ingress_feb_id_dbg[0]),
    .ingress_running_ts0(ingress_running_ts_dbg[0]),
    .ticket_credit_update_o(ticket_credit_update),
    .ticket_credit_update_valid_o(ticket_credit_update_valid),
    .handle_wdata_o(handle_wdata_dbg),
    .handle_waddr_o(handle_waddr_dbg),
    .handle_we_o(handle_we_dbg),
    .handle_wptr_o(handle_wptr_dbg),
    .eop_flush_ack_o(ingress_eop_flush_ack_dbg),
    .page_we_o(page_we_dbg),
    .page_waddr_o(page_waddr_dbg),
    .page_wdata_o(page_wdata_dbg),
    .ticket_fifos_rd_addr_o(ticket_fifos_rd_addr),
    .tk_future_o(tk_future_dbg),
    .fetch_ticket_active_o(fetch_ticket_active_dbg),
    .write_head_active_o(write_head_active_dbg),
    .write_tail_active_o(write_tail_active_dbg),
    .write_page_active_o(write_page_active_dbg),
    .write_meta_flow_o(write_meta_flow_dbg),
    .write_meta_flow_d1_o(write_meta_flow_d1_dbg),
    .frame_start_addr_o(frame_start_addr_dbg),
    .frame_shr_cnt_this_o(frame_shr_cnt_this_dbg),
    .frame_hit_cnt_this_o(frame_hit_cnt_this_dbg),
    .packet_complete_pulse_o(packet_complete_pulse_dbg),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  ordered_priority_queue_monolithic_block_path #(
    .N_LANE(N_LANE),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .LANE_FIFO_WIDTH(LANE_FIFO_WIDTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .N_HIT(N_HIT),
    .HIT_SIZE(HIT_SIZE)
  ) block_path_i (
    .handle_wptr_i(handle_wptr_dbg),
    .handle_we_i(handle_we_dbg),
    .handle_fifos_rd_data_i(handle_fifos_rd_data),
    .lane_fifos_rd_data_i(lane_fifos_rd_data),
    .fetch_ticket_active_i(fetch_ticket_active_dbg),
    .tk_future_i(tk_future_dbg),
    .page_allocator_write_head_i(write_head_active_dbg),
    .page_allocator_write_tail_i(write_tail_active_dbg),
    .page_allocator_write_page_i(write_page_active_dbg),
    .page_allocator_page_we_i(page_we_dbg),
    .page_allocator_page_waddr_i(page_waddr_dbg),
    .page_allocator_page_wdata_i(page_wdata_dbg),
    .drr_allowance_i(cfg_drr_allowance_i),
    .drr_allowance_reload_i(cfg_drr_allowance_reload_i),
    .handle_fifos_rd_addr_o(handle_fifos_rd_addr),
    .lane_fifos_rd_addr_o(lane_fifos_rd_addr),
    .lane_credit_update_o(lane_credit_update),
    .lane_credit_update_valid_o(lane_credit_update_valid),
    .page_ram_we_o(page_ram_we_dbg),
    .page_ram_wr_addr_o(page_ram_wr_addr_dbg),
    .page_ram_wr_data_o(page_ram_wr_data_dbg),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  page_ram #(
    .DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH)
  ) page_ram_i (
    .data(page_ram_wr_data_dbg),
    .read_addr(page_ram_rd_addr_dbg),
    .write_addr(page_ram_wr_addr_dbg),
    .we(page_ram_we_dbg),
    .clk(d_clk),
    .q(page_ram_rd_data_dbg)
  );

  always_ff @(posedge d_clk) begin : proc_presenter_packet_complete_delay
    if (d_reset) begin
      packet_complete_presenter_delay_dbg <= '0;
    end else begin
      packet_complete_presenter_delay_dbg[0] <= packet_complete_pulse_dbg;
      packet_complete_presenter_delay_dbg[1] <= packet_complete_presenter_delay_dbg[0];
    end
  end

  assign packet_complete_presenter_dbg = packet_complete_presenter_delay_dbg[1];

  always_ff @(posedge d_clk) begin : proc_native_trace
    if ($test$plusargs("OPQ_NATIVE_TRACE_WR") && page_ram_we_dbg) begin
      $display("[opq_native_wr] t=%0t addr=0x%0h data=0x%010h", $time, page_ram_wr_addr_dbg, page_ram_wr_data_dbg);
    end
    if ($test$plusargs("OPQ_NATIVE_TRACE_PKT")) begin
      if (write_head_active_dbg && (write_meta_flow_dbg == 3'd0)) begin
        $display("[opq_native_pkt] t=%0t new_frame addr=0x%0h shd_this=0x%0h hit_this=0x%0h", $time, frame_start_addr_dbg, frame_shr_cnt_this_dbg, frame_hit_cnt_this_dbg);
      end
      if (packet_complete_pulse_dbg) begin
        $display("[opq_native_pkt] t=%0t alloc_complete", $time);
      end
      if (packet_complete_presenter_dbg) begin
        $display("[opq_native_pkt] t=%0t presenter_complete", $time);
      end
    end
  end

  ordered_priority_queue_monolithic_basic_presenter #(
    .N_LANE(N_LANE),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT)
  ) presenter_i (
    .new_frame_valid_i(write_head_active_dbg && (write_meta_flow_dbg == 3'd0)),
    .new_frame_raw_addr_i(frame_start_addr_dbg),
    .frame_shr_cnt_this_i(frame_shr_cnt_this_dbg),
    .frame_hit_cnt_this_i(frame_hit_cnt_this_dbg),
    .packet_complete_i(packet_complete_presenter_dbg),
    .page_ram_rd_addr_o(page_ram_rd_addr_dbg),
    .page_ram_rd_data_i(page_ram_rd_data_dbg),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  initial begin
    assert (PAGE_RAM_ADDR_WIDTH == 16)
      else $warning("PAGE RAM ADDR NON-DEFAULT (16 bits expected)");
    assert ($clog2(N_SHD * N_HIT) + 1 <= 16)
      else $warning("N hits counter will likely overflow the 16-bit frame hit counter");
  end

endmodule

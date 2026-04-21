//------------------------------------------------------------------------------
// IP Name   : opq_formal_ingress_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - standalone elaboration top for ingress-parser formal checks
// Description:
//   Minimal standalone top that elaborates the native-SV ingress parser and
//   its formal checker without pulling in the full multi-lane OPQ top.
//------------------------------------------------------------------------------
module opq_formal_ingress_tb;
  localparam int unsigned INGRESS_DATA_WIDTH = 32;
  localparam int unsigned INGRESS_DATAK_WIDTH = 4;
  localparam int unsigned LANE_FIFO_DEPTH = 16;
  localparam int unsigned LANE_FIFO_WIDTH = 40;
  localparam int unsigned TICKET_FIFO_DEPTH = 16;
  localparam int unsigned N_HIT = 16;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned FRAME_SERIAL_SIZE = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE = 16;
  localparam int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT;
  localparam int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH);
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_A =
    48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + FRAME_SERIAL_SIZE + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 6 + 16 + 48 + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B;
  localparam int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH);
  localparam int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH);

  logic [INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data;
  logic                                              asi_ingress_valid;
  logic                                              asi_ingress_startofpacket;
  logic                                              asi_ingress_endofpacket;
  logic [2:0]                                        asi_ingress_error;
  logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_update;
  logic                                              lane_credit_update_valid;
  logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_update;
  logic                                              ticket_credit_update_valid;
  logic [TICKET_FIFO_DATA_WIDTH-1:0]                 ticket_wdata;
  logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_wptr;
  logic                                              ticket_we;
  logic [LANE_FIFO_WIDTH-1:0]                        lane_wdata;
  logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_wptr;
  logic                                              lane_we;
  logic [47:0]                                       running_ts_dbg;
  logic [47:0]                                       frame_ts_base_dbg;
  logic [5:0]                                        dt_type_dbg;
  logic [15:0]                                       feb_id_dbg;
  logic                                              parser_busy_o;
  logic                                              credit_drop_valid_o;
  logic                                              credit_drop_lane_o;
  logic                                              credit_drop_ticket_o;
  logic [47:0]                                       credit_drop_ts_o;
  logic [15:0]                                       credit_drop_shd_cnt_o;
  logic [15:0]                                       credit_drop_hit_cnt_o;
  logic                                              tail_bypass_valid_o;
  logic                                              tail_bypass_drop_o;
  logic [15:0]                                       tail_bypass_serial_o;
  logic [47:0]                                       tail_bypass_ts_o;
  logic                                              alert_eop_state_o;
  logic                                              eop_flush_ack_i;
  logic                                              d_clk;
  logic                                              d_reset;

  initial begin
    d_clk = 1'b0;
    forever #1 d_clk = ~d_clk;
  end

  initial begin
    d_reset = 1'b1;
    asi_ingress_data = '0;
    asi_ingress_valid = 1'b0;
    asi_ingress_startofpacket = 1'b0;
    asi_ingress_endofpacket = 1'b0;
    asi_ingress_error = '0;
    lane_credit_update = '0;
    lane_credit_update_valid = 1'b0;
    ticket_credit_update = '0;
    ticket_credit_update_valid = 1'b0;
    eop_flush_ack_i = 1'b0;
    #4 d_reset = 1'b0;
  end

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
    .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE),
    .MAX_PKT_LENGTH(MAX_PKT_LENGTH),
    .MAX_PKT_LENGTH_BITS(MAX_PKT_LENGTH_BITS),
    .TICKET_FIFO_DATA_WIDTH_A(TICKET_FIFO_DATA_WIDTH_A),
    .TICKET_FIFO_DATA_WIDTH_B(TICKET_FIFO_DATA_WIDTH_B),
    .TICKET_FIFO_DATA_WIDTH(TICKET_FIFO_DATA_WIDTH),
    .TICKET_FIFO_ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH),
    .LANE_FIFO_ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH)
  ) ingress_parser_dut (
    .asi_ingress_data(asi_ingress_data),
    .asi_ingress_valid(asi_ingress_valid),
    .asi_ingress_startofpacket(asi_ingress_startofpacket),
    .asi_ingress_endofpacket(asi_ingress_endofpacket),
    .asi_ingress_error(asi_ingress_error),
    .lane_credit_update(lane_credit_update),
    .lane_credit_update_valid(lane_credit_update_valid),
    .ticket_credit_update(ticket_credit_update),
    .ticket_credit_update_valid(ticket_credit_update_valid),
    .ticket_wdata(ticket_wdata),
    .ticket_wptr(ticket_wptr),
    .ticket_we(ticket_we),
    .lane_wdata(lane_wdata),
    .lane_wptr(lane_wptr),
    .lane_we(lane_we),
    .running_ts_dbg(running_ts_dbg),
    .frame_ts_base_dbg(frame_ts_base_dbg),
    .dt_type_dbg(dt_type_dbg),
    .feb_id_dbg(feb_id_dbg),
    .parser_busy_o(parser_busy_o),
    .credit_drop_valid_o(credit_drop_valid_o),
    .credit_drop_lane_o(credit_drop_lane_o),
    .credit_drop_ticket_o(credit_drop_ticket_o),
    .credit_drop_ts_o(credit_drop_ts_o),
    .credit_drop_shd_cnt_o(credit_drop_shd_cnt_o),
    .credit_drop_hit_cnt_o(credit_drop_hit_cnt_o),
    .tail_bypass_valid_o(tail_bypass_valid_o),
    .tail_bypass_drop_o(tail_bypass_drop_o),
    .tail_bypass_serial_o(tail_bypass_serial_o),
    .tail_bypass_ts_o(tail_bypass_ts_o),
    .alert_eop_state_o(alert_eop_state_o),
    .eop_flush_ack_i(eop_flush_ack_i),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
endmodule

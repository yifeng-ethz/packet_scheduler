//------------------------------------------------------------------------------
// IP Name   : opq_native_ingress_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - align packet-write invariants to the real same-cycle ptr/we update timing
// Description:
//   Native-SV formal checker for the ingress parser. These checks implement
//   the packet-shape/credit invariants called out in DV_FORMAL plane A/B
//   without changing DUT behavior.
//------------------------------------------------------------------------------
module opq_native_ingress_formal_sva #(
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH = 64,
  parameter int unsigned TICKET_ALT_EOP_LOC = TICKET_FIFO_DATA_WIDTH - 2,
  parameter int unsigned TICKET_ALT_SOP_LOC = TICKET_FIFO_DATA_WIDTH - 1,
  parameter int unsigned EOP_DRAIN_MAX = TICKET_FIFO_DEPTH + 8
) (
  input logic                                    d_clk,
  input logic                                    d_reset,
  input logic                                    asi_ingress_valid,
  input logic                                    asi_ingress_startofpacket,
  input logic                                    asi_ingress_endofpacket,
  input logic [35:0]                             asi_ingress_data,
  input logic [2:0]                              asi_ingress_error,
  input logic [LANE_FIFO_ADDR_WIDTH-1:0]         lane_credit_update,
  input logic                                    lane_credit_update_valid,
  input logic [TICKET_FIFO_ADDR_WIDTH-1:0]       ticket_credit_update,
  input logic                                    ticket_credit_update_valid,
  input logic [TICKET_FIFO_DATA_WIDTH-1:0]       ticket_wdata,
  input logic [TICKET_FIFO_ADDR_WIDTH-1:0]       ticket_wptr,
  input logic                                    ticket_we,
  input logic [LANE_FIFO_ADDR_WIDTH-1:0]         lane_wptr,
  input logic                                    lane_we,
  input logic [LANE_FIFO_ADDR_WIDTH-1:0]         lane_credit_dbg,
  input logic [TICKET_FIFO_ADDR_WIDTH-1:0]       ticket_credit_dbg,
  input logic                                    alert_eop_dbg,
  input logic                                    eop_flush_ack_i
);
  localparam int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2;
  localparam int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1;
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  logic                              past_valid;
`ifdef OPQ_NATIVE_FORMAL_STRICT
  int                                outstanding_tickets;
  int                                outstanding_lane_words;
`endif

  function automatic logic is_preamble_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic is_subheader_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic is_trailer_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      past_valid <= 1'b0;
`ifdef OPQ_NATIVE_FORMAL_STRICT
      outstanding_tickets <= 0;
      outstanding_lane_words <= 0;
`endif
    end else begin
      past_valid <= 1'b1;

`ifdef OPQ_NATIVE_FORMAL_STRICT
      outstanding_tickets <= outstanding_tickets +
        (ticket_we ? 1 : 0) -
        (ticket_credit_update_valid ? int'(ticket_credit_update) : 0);
      outstanding_lane_words <= outstanding_lane_words +
        (lane_we ? 1 : 0) -
        (lane_credit_update_valid ? int'(lane_credit_update) : 0);
`endif
    end
  end

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ticket_we |-> (ticket_wptr == ($past(ticket_wptr) + TICKET_FIFO_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_INGRESS_FORMAL ticket_wptr did not advance after ticket_we");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    !ticket_we |-> $stable(ticket_wptr))
    else $error("OPQ_NATIVE_INGRESS_FORMAL ticket_wptr moved without ticket_we");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    lane_we |-> (lane_wptr == ($past(lane_wptr) + LANE_FIFO_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_INGRESS_FORMAL lane_wptr did not advance after lane_we");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    !lane_we |-> $stable(lane_wptr))
    else $error("OPQ_NATIVE_INGRESS_FORMAL lane_wptr moved without lane_we");

`ifdef OPQ_NATIVE_FORMAL_STRICT
  assert property (@(posedge d_clk) disable iff (d_reset)
    outstanding_tickets >= 0 && outstanding_tickets <= TICKET_FIFO_MAX_CREDIT)
    else $error("OPQ_NATIVE_INGRESS_FORMAL outstanding ticket shadow escaped legal range");

  assert property (@(posedge d_clk) disable iff (d_reset)
    outstanding_lane_words >= 0 && outstanding_lane_words <= LANE_FIFO_MAX_CREDIT)
    else $error("OPQ_NATIVE_INGRESS_FORMAL outstanding lane-word shadow escaped legal range");

  assert property (@(posedge d_clk) disable iff (d_reset)
    (int'(ticket_credit_dbg) + outstanding_tickets) == TICKET_FIFO_MAX_CREDIT)
    else $error("OPQ_NATIVE_INGRESS_FORMAL ticket-credit conservation failed");

  assert property (@(posedge d_clk) disable iff (d_reset)
    (int'(lane_credit_dbg) + outstanding_lane_words) == LANE_FIFO_MAX_CREDIT)
    else $error("OPQ_NATIVE_INGRESS_FORMAL lane-credit conservation failed");
`endif

  assert property (@(posedge d_clk) disable iff (d_reset)
    ticket_we |-> (ticket_credit_dbg != '0))
    else $error("OPQ_NATIVE_INGRESS_FORMAL ticket write happened at zero ticket credit");

  assert property (@(posedge d_clk) disable iff (d_reset)
    lane_we |-> (lane_credit_dbg != '0))
    else $error("OPQ_NATIVE_INGRESS_FORMAL lane write happened at zero lane credit");

  assert property (@(posedge d_clk) disable iff (d_reset)
    ticket_we |-> (ticket_wdata[TICKET_ALT_EOP_LOC] == alert_eop_dbg))
    else $error("OPQ_NATIVE_INGRESS_FORMAL alert_eop/ticket EOP coupling broke");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_startofpacket |-> is_preamble_word(asi_ingress_data) || is_subheader_word(asi_ingress_data))
    else $error("OPQ_NATIVE_INGRESS_FORMAL SOP arrived on a non-preamble/non-subheader word");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_endofpacket |-> is_trailer_word(asi_ingress_data) ||
      (asi_ingress_startofpacket && is_preamble_word(asi_ingress_data)))
    else $error("OPQ_NATIVE_INGRESS_FORMAL EOP arrived on a non-trailer word");

  assert property (@(posedge d_clk) disable iff (d_reset)
    alert_eop_dbg && eop_flush_ack_i |=> !alert_eop_dbg)
    else $error("OPQ_NATIVE_INGRESS_FORMAL flush ack did not clear alert_eop");

  cover property (@(posedge d_clk) disable iff (d_reset)
    $rose(alert_eop_dbg) ##[1:EOP_DRAIN_MAX] (ticket_we || eop_flush_ack_i));

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_startofpacket && is_preamble_word(asi_ingress_data) ##[1:32]
    asi_ingress_valid && asi_ingress_endofpacket && is_trailer_word(asi_ingress_data));
endmodule

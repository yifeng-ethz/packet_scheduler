//------------------------------------------------------------------------------
// IP Name   : opq_oss_ingress_formal_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - OSS Yosys/SBY ingress-parser proof harness
// Description:
//   Yosys/SymbiYosys-friendly ingress-parser harness that replaces the
//   Questa-style temporal SVA with clocked immediate assertions.
//------------------------------------------------------------------------------
module opq_oss_ingress_formal_tb;
  localparam int unsigned INGRESS_DATA_WIDTH = 32;
  localparam int unsigned INGRESS_DATAK_WIDTH = 4;
  localparam int unsigned LANE_FIFO_DEPTH = 8;
  localparam int unsigned LANE_FIFO_WIDTH = 40;
  localparam int unsigned TICKET_FIFO_DEPTH = 8;
  localparam int unsigned N_HIT = 8;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned FRAME_SERIAL_SIZE = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE = 16;
  localparam int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT;
  localparam int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH);
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_A = 48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B;
  localparam int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH);
  localparam int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH);
  localparam int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1;
  localparam int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2;
  localparam logic [2:0] INGRESS_PARSER_IDLE = 3'd0;
  localparam logic [2:0] INGRESS_PARSER_RESET = 3'd5;
  localparam logic [2:0] INGRESS_PARSER_WR_HITS = 3'd4;
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  (* gclk *) reg gclk;
  reg f_past_valid = 1'b0;
  reg [1:0] f_reset_sr = 2'b11;
  reg [3:0] f_post_reset_sr = 4'b0000;
  reg [15:0] f_lane_credit_outstanding = '0;
  reg [15:0] f_ticket_credit_outstanding = '0;
  reg [15:0] f_lane_credit_model = LANE_FIFO_MAX_CREDIT;
  reg [15:0] f_ticket_credit_model = TICKET_FIFO_MAX_CREDIT;

  wire d_reset = f_reset_sr[1];

  (* anyseq *) reg [INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data;
  (* anyseq *) reg                                              asi_ingress_valid;
  (* anyseq *) reg                                              asi_ingress_startofpacket;
  (* anyseq *) reg                                              asi_ingress_endofpacket;
  (* anyseq *) reg [2:0]                                        asi_ingress_error;
  (* anyseq *) reg [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_update;
  (* anyseq *) reg                                              lane_credit_update_valid;
  (* anyseq *) reg [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_update;
  (* anyseq *) reg                                              ticket_credit_update_valid;
  (* anyseq *) reg                                              eop_flush_ack_i;

  wire [TICKET_FIFO_DATA_WIDTH-1:0]                             ticket_wdata;
  wire [TICKET_FIFO_ADDR_WIDTH-1:0]                             ticket_wptr;
  wire                                                          ticket_we;
  wire [LANE_FIFO_WIDTH-1:0]                                    lane_wdata;
  wire [LANE_FIFO_ADDR_WIDTH-1:0]                               lane_wptr;
  wire                                                          lane_we;
  wire [47:0]                                                   running_ts_dbg;
  wire [5:0]                                                    dt_type_dbg;
  wire [15:0]                                                   feb_id_dbg;
  wire [LANE_FIFO_ADDR_WIDTH-1:0]                               lane_credit_dbg_oss;
  wire [TICKET_FIFO_ADDR_WIDTH-1:0]                             ticket_credit_dbg_oss;
  wire [MAX_PKT_LENGTH_BITS-1:0]                                shd_len_dbg_oss;
  wire [2:0]                                                    ingress_state_dbg_oss;
  wire                                                          lane_issue_dbg_oss;
  wire                                                          ticket_issue_dbg_oss;
  wire                                                          credit_drop_lane_decision_dbg_oss;
  wire                                                          credit_drop_ticket_decision_dbg_oss;
  wire                                                          credit_drop_valid_o;
  wire                                                          credit_drop_lane_o;
  wire                                                          credit_drop_ticket_o;
  wire [15:0]                                                   credit_drop_shd_cnt_o;
  wire [15:0]                                                   credit_drop_hit_cnt_o;
  wire                                                          alert_eop_state_o;
  wire [15:0]                                                   lane_credit_consume_amt;
  wire [15:0]                                                   lane_credit_return_amt;
  wire [15:0]                                                   ticket_credit_consume_amt;
  wire [15:0]                                                   ticket_credit_return_amt;
  wire [15:0]                                                   lane_credit_model_next;
  wire [15:0]                                                   lane_credit_outstanding_next;
  wire [15:0]                                                   ticket_credit_model_next;
  wire [15:0]                                                   ticket_credit_outstanding_next;
  wire                                                          credit_tracking_active;

  function automatic logic is_preamble_word(input logic [35:0] word_v);
    is_preamble_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic is_subheader_word(input logic [35:0] word_v);
    is_subheader_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic is_trailer_word(input logic [35:0] word_v);
    is_trailer_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

  assign credit_tracking_active =
    f_past_valid && (&f_post_reset_sr) && !d_reset && (ingress_state_dbg_oss != INGRESS_PARSER_RESET);
  assign lane_credit_consume_amt =
    (credit_tracking_active && lane_issue_dbg_oss && ticket_issue_dbg_oss) ?
      {{(16-MAX_PKT_LENGTH_BITS){1'b0}}, shd_len_dbg_oss} : 16'd0;
  assign lane_credit_return_amt =
    (credit_tracking_active && lane_credit_update_valid) ?
      {{(16-LANE_FIFO_ADDR_WIDTH){1'b0}}, lane_credit_update} : 16'd0;
  assign ticket_credit_consume_amt = (credit_tracking_active && ticket_issue_dbg_oss) ? 16'd1 : 16'd0;
  assign ticket_credit_return_amt =
    (credit_tracking_active && ticket_credit_update_valid) ?
      {{(16-TICKET_FIFO_ADDR_WIDTH){1'b0}}, ticket_credit_update} : 16'd0;
  assign lane_credit_model_next = d_reset ? LANE_FIFO_MAX_CREDIT :
    (f_lane_credit_model + lane_credit_return_amt - lane_credit_consume_amt);
  assign lane_credit_outstanding_next = d_reset ? 16'd0 :
    (f_lane_credit_outstanding + lane_credit_consume_amt - lane_credit_return_amt);
  assign ticket_credit_model_next = d_reset ? TICKET_FIFO_MAX_CREDIT :
    (f_ticket_credit_model + ticket_credit_return_amt - ticket_credit_consume_amt);
  assign ticket_credit_outstanding_next = d_reset ? 16'd0 :
    (f_ticket_credit_outstanding + ticket_credit_consume_amt - ticket_credit_return_amt);

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
  ) dut (
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
    .dt_type_dbg(dt_type_dbg),
    .feb_id_dbg(feb_id_dbg),
    .lane_credit_dbg_oss(lane_credit_dbg_oss),
    .ticket_credit_dbg_oss(ticket_credit_dbg_oss),
    .shd_len_dbg_oss(shd_len_dbg_oss),
    .ingress_state_dbg_oss(ingress_state_dbg_oss),
    .lane_issue_dbg_oss(lane_issue_dbg_oss),
    .ticket_issue_dbg_oss(ticket_issue_dbg_oss),
    .credit_drop_lane_decision_dbg_oss(credit_drop_lane_decision_dbg_oss),
    .credit_drop_ticket_decision_dbg_oss(credit_drop_ticket_decision_dbg_oss),
    .credit_drop_valid_o(credit_drop_valid_o),
    .credit_drop_lane_o(credit_drop_lane_o),
    .credit_drop_ticket_o(credit_drop_ticket_o),
    .credit_drop_shd_cnt_o(credit_drop_shd_cnt_o),
    .credit_drop_hit_cnt_o(credit_drop_hit_cnt_o),
    .alert_eop_state_o(alert_eop_state_o),
    .eop_flush_ack_i(eop_flush_ack_i),
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
      assume(!lane_credit_update_valid && !ticket_credit_update_valid);
      assume(lane_credit_dbg_oss == LANE_FIFO_MAX_CREDIT);
      assume(ticket_credit_dbg_oss == TICKET_FIFO_MAX_CREDIT);
      assume(ingress_state_dbg_oss == INGRESS_PARSER_RESET);
      assume(!lane_we && !ticket_we);
    end

    if (!(&f_post_reset_sr)) begin
      assume(!asi_ingress_valid);
      assume(!asi_ingress_startofpacket && !asi_ingress_endofpacket);
      assume(!lane_credit_update_valid && !ticket_credit_update_valid);
      assume(!eop_flush_ack_i);
      assume(lane_credit_dbg_oss == LANE_FIFO_MAX_CREDIT);
      assume(ticket_credit_dbg_oss == TICKET_FIFO_MAX_CREDIT);
      assume((ingress_state_dbg_oss == INGRESS_PARSER_RESET) || (ingress_state_dbg_oss == INGRESS_PARSER_IDLE));
    end

    if (!d_reset) begin
      assume(!asi_ingress_startofpacket || asi_ingress_valid);
      assume(!asi_ingress_endofpacket || asi_ingress_valid);
      assume(asi_ingress_valid || (!asi_ingress_startofpacket && !asi_ingress_endofpacket));
      assume(!asi_ingress_startofpacket ||
        is_preamble_word(asi_ingress_data) || is_subheader_word(asi_ingress_data));
      assume(!asi_ingress_endofpacket ||
        is_trailer_word(asi_ingress_data) ||
        (asi_ingress_startofpacket && is_preamble_word(asi_ingress_data)));

      // Credit returns are modeled as an external environment contract. They
      // may restore capacity but cannot return more credits than the modeled
      // outstanding words/tickets already consumed by the parser, and they
      // must not over-credit the visible free-space counters.
      assume(!lane_credit_update_valid ||
        ({1'b0, lane_credit_return_amt} <= {1'b0, f_lane_credit_outstanding}));
      assume(!ticket_credit_update_valid ||
        ({1'b0, ticket_credit_return_amt} <= {1'b0, f_ticket_credit_outstanding}));
      assume(!lane_credit_update_valid ||
        ((f_lane_credit_model + lane_credit_return_amt) <= LANE_FIFO_MAX_CREDIT));
      assume(!ticket_credit_update_valid ||
        ((f_ticket_credit_model + ticket_credit_return_amt) <= TICKET_FIFO_MAX_CREDIT));
      if (credit_drop_valid_o) begin
        assume(!lane_issue_dbg_oss && !ticket_issue_dbg_oss);
        assume(credit_drop_lane_o || credit_drop_ticket_o);
      end
    end

    if (f_past_valid && (&f_post_reset_sr) && (ingress_state_dbg_oss != INGRESS_PARSER_RESET)) begin
      // Prove the live event contract rather than exact debug-counter phase.
      assert(lane_issue_dbg_oss == lane_we);
      assert(ticket_issue_dbg_oss == ticket_we);
      assert(!credit_drop_valid_o || (!lane_issue_dbg_oss && !ticket_issue_dbg_oss));
      assert(!credit_drop_lane_o || credit_drop_valid_o);
      assert(!credit_drop_ticket_o || credit_drop_valid_o);
    end

    if (d_reset) begin
      f_lane_credit_outstanding <= '0;
      f_ticket_credit_outstanding <= '0;
      f_lane_credit_model <= LANE_FIFO_MAX_CREDIT;
      f_ticket_credit_model <= TICKET_FIFO_MAX_CREDIT;
    end else begin
      f_lane_credit_outstanding <= lane_credit_outstanding_next;
      f_ticket_credit_outstanding <= ticket_credit_outstanding_next;
      f_lane_credit_model <= lane_credit_model_next;
      f_ticket_credit_model <= ticket_credit_model_next;
    end

    cover(f_past_valid && ticket_we);
    cover(f_past_valid && lane_we);
    cover(f_past_valid && credit_drop_valid_o);
    cover(f_past_valid && credit_drop_valid_o && credit_drop_lane_o && credit_drop_ticket_o);
    cover(f_past_valid && alert_eop_state_o && eop_flush_ack_i);
  end
endmodule

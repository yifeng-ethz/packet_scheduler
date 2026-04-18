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
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  (* gclk *) reg gclk;
  reg f_past_valid = 1'b0;
  reg [1:0] f_reset_sr = 2'b11;
  reg [1:0] f_post_reset_sr = 2'b00;

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

  function automatic logic is_preamble_word(input logic [35:0] word_v);
    is_preamble_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic is_subheader_word(input logic [35:0] word_v);
    is_subheader_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic is_trailer_word(input logic [35:0] word_v);
    is_trailer_word = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

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
      f_post_reset_sr <= 2'b00;
    end else begin
      f_post_reset_sr <= {f_post_reset_sr[0], 1'b1};
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
      // may restore capacity but must not overflow the parser's credit pools.
      assume(!lane_credit_update_valid ||
        ({1'b0, lane_credit_dbg_oss} + {1'b0, lane_credit_update} <=
          LANE_FIFO_MAX_CREDIT));
      assume(!ticket_credit_update_valid ||
        ({1'b0, ticket_credit_dbg_oss} + {1'b0, ticket_credit_update} <=
          TICKET_FIFO_MAX_CREDIT));
    end

    if (f_past_valid && (&f_post_reset_sr)) begin
      assert(lane_credit_dbg_oss <= LANE_FIFO_MAX_CREDIT);
      assert(ticket_credit_dbg_oss <= TICKET_FIFO_MAX_CREDIT);
      if (ticket_we) begin
        assert(ticket_issue_dbg_oss);
      end
      if (lane_we) begin
        assert(lane_issue_dbg_oss);
      end
      if (credit_drop_lane_o) begin
        assert(credit_drop_lane_decision_dbg_oss);
      end
      if (credit_drop_ticket_o) begin
        assert(credit_drop_ticket_decision_dbg_oss);
      end
      if (credit_drop_valid_o) begin
        assert(credit_drop_lane_decision_dbg_oss || credit_drop_ticket_decision_dbg_oss);
      end
    end

    cover(f_past_valid && ticket_we);
    cover(f_past_valid && lane_we);
    cover(f_past_valid && credit_drop_valid_o);
    cover(f_past_valid && credit_drop_valid_o && credit_drop_lane_o && credit_drop_ticket_o);
    cover(f_past_valid && alert_eop_state_o && eop_flush_ack_i);
  end
endmodule

//------------------------------------------------------------------------------
// IP Name   : opq_native_ingress_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.4 - keep the parameter surface aligned with the bound ingress parser
// Description:
//   Native-SV formal checker for the ingress parser. These checks implement
//   the packet-shape/credit invariants called out in DV_FORMAL plane A/B
//   without changing DUT behavior.
//------------------------------------------------------------------------------
module opq_native_ingress_formal_sva #(
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned FRAME_HDR_AUX_WORDS = 4,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH = 64,
  parameter int unsigned MAX_PKT_LENGTH_BITS = 8,
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
  input logic                                    tail_bypass_valid_dbg,
  input logic                                    tail_bypass_drop_dbg,
  input logic                                    alert_eop_dbg,
  input logic                                    eop_flush_ack_i
);
  localparam int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2;
  localparam int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1;
  localparam int unsigned TICKET_BLOCK_LEN_LO = 48 + LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned TICKET_BLOCK_LEN_HI = TICKET_BLOCK_LEN_LO + MAX_PKT_LENGTH_BITS - 1;
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  typedef enum logic [3:0] {
    ING_MON_IDLE,
    ING_MON_HDR0,
    ING_MON_HDR1,
    ING_MON_HDR2,
    ING_MON_HDR3,
    ING_MON_BODY,
    ING_MON_HITS,
    ING_MON_MASK_SUBH,
    ING_MON_MASK_FRAME
  } ingress_mon_state_t;

  logic                              past_valid;
  ingress_mon_state_t                ingress_mon_state;
  logic [7:0]                        ingress_mon_hits_remaining;
  logic [7:0]                        ingress_mon_hits_accepted;
  logic                              ingress_hdr_error_legal_v;
  logic                              ingress_shd_error_legal_v;
  logic                              ingress_hit_error_legal_v;
  logic [MAX_PKT_LENGTH_BITS-1:0]    ingress_mon_hits_accepted_final_v;
  logic                              ingress_clean_hit_d;
  logic                              ingress_hit_error_d;
  logic                              ingress_shd_error_d;
  logic                              ingress_hdr_error_d;
  logic                              ingress_zero_hit_subheader_d;
  logic                              ingress_last_hit_d;
  logic                              ingress_trailer_d;
  logic                              ingress_masked_trailer_d;
  logic [MAX_PKT_LENGTH_BITS-1:0]    ingress_last_hit_accepted_d;
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

  always_comb begin
    ingress_hdr_error_legal_v = 1'b0;
    if (ingress_mon_state == ING_MON_IDLE) begin
      ingress_hdr_error_legal_v = asi_ingress_startofpacket && is_preamble_word(asi_ingress_data);
    end else begin
      ingress_hdr_error_legal_v =
        (ingress_mon_state == ING_MON_HDR0) ||
        (ingress_mon_state == ING_MON_HDR1) ||
        (ingress_mon_state == ING_MON_HDR2) ||
        (ingress_mon_state == ING_MON_HDR3);
    end

    ingress_shd_error_legal_v =
      ((ingress_mon_state == ING_MON_IDLE) ||
       (ingress_mon_state == ING_MON_BODY) ||
       (ingress_mon_state == ING_MON_MASK_SUBH)) &&
      is_subheader_word(asi_ingress_data);

    ingress_hit_error_legal_v = (ingress_mon_state == ING_MON_HITS);
    ingress_mon_hits_accepted_final_v = ingress_mon_hits_accepted[MAX_PKT_LENGTH_BITS-1:0];
    if ((ingress_mon_state == ING_MON_HITS) &&
        asi_ingress_valid &&
        !asi_ingress_error[0]) begin
      ingress_mon_hits_accepted_final_v =
        ingress_mon_hits_accepted_final_v + MAX_PKT_LENGTH_BITS'(1);
    end
  end

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      past_valid <= 1'b0;
      ingress_mon_state <= ING_MON_IDLE;
      ingress_mon_hits_remaining <= '0;
      ingress_mon_hits_accepted <= '0;
      ingress_clean_hit_d <= 1'b0;
      ingress_hit_error_d <= 1'b0;
      ingress_shd_error_d <= 1'b0;
      ingress_hdr_error_d <= 1'b0;
      ingress_zero_hit_subheader_d <= 1'b0;
      ingress_last_hit_d <= 1'b0;
      ingress_trailer_d <= 1'b0;
      ingress_masked_trailer_d <= 1'b0;
      ingress_last_hit_accepted_d <= '0;
`ifdef OPQ_NATIVE_FORMAL_STRICT
      outstanding_tickets <= 0;
      outstanding_lane_words <= 0;
`endif
    end else begin
      past_valid <= 1'b1;

      // Assertions sample in the preponed region, so align beat classification
      // to the DUT's registered write pulses by tracking the previous beat.
      ingress_clean_hit_d <=
        asi_ingress_valid &&
        ingress_hit_error_legal_v &&
        !asi_ingress_error[0];
      ingress_hit_error_d <=
        asi_ingress_valid &&
        ingress_hit_error_legal_v &&
        asi_ingress_error[0];
      ingress_shd_error_d <=
        asi_ingress_valid &&
        ingress_shd_error_legal_v &&
        asi_ingress_error[1];
      ingress_hdr_error_d <=
        asi_ingress_valid &&
        ingress_hdr_error_legal_v &&
        asi_ingress_error[2];
      ingress_zero_hit_subheader_d <=
        asi_ingress_valid &&
        ingress_shd_error_legal_v &&
        !asi_ingress_error[1] &&
        (asi_ingress_data[15:8] == 8'd0);
      ingress_last_hit_d <=
        (ingress_mon_state == ING_MON_HITS) &&
        asi_ingress_valid &&
        (ingress_mon_hits_remaining == 8'd1);
      ingress_trailer_d <=
        asi_ingress_valid &&
        is_trailer_word(asi_ingress_data);
      ingress_masked_trailer_d <=
        asi_ingress_valid &&
        is_trailer_word(asi_ingress_data) &&
        ((ingress_mon_state == ING_MON_MASK_SUBH) ||
         (ingress_mon_state == ING_MON_MASK_FRAME));
      ingress_last_hit_accepted_d <= ingress_mon_hits_accepted_final_v;

`ifdef OPQ_NATIVE_FORMAL_STRICT
      outstanding_tickets <= outstanding_tickets +
        (ticket_we ? 1 : 0) -
        (ticket_credit_update_valid ? int'(ticket_credit_update) : 0);
      outstanding_lane_words <= outstanding_lane_words +
        (lane_we ? 1 : 0) -
        (lane_credit_update_valid ? int'(lane_credit_update) : 0);
`endif

      if (asi_ingress_valid) begin
        unique case (ingress_mon_state)
          ING_MON_IDLE: begin
            if (asi_ingress_startofpacket && is_preamble_word(asi_ingress_data)) begin
              if (asi_ingress_error[2]) begin
                ingress_mon_state <= ING_MON_MASK_FRAME;
              end else begin
                ingress_mon_state <= ING_MON_HDR0;
              end
              ingress_mon_hits_remaining <= '0;
              ingress_mon_hits_accepted <= '0;
            end else if (is_subheader_word(asi_ingress_data)) begin
              if (asi_ingress_error[1]) begin
                ingress_mon_state <= ING_MON_MASK_SUBH;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end else if (asi_ingress_data[15:8] != 8'd0) begin
                ingress_mon_state <= ING_MON_HITS;
                ingress_mon_hits_remaining <= asi_ingress_data[15:8];
                ingress_mon_hits_accepted <= '0;
              end else begin
                ingress_mon_state <= ING_MON_BODY;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end
            end else if (is_trailer_word(asi_ingress_data) && asi_ingress_endofpacket) begin
              ingress_mon_state <= ING_MON_IDLE;
              ingress_mon_hits_remaining <= '0;
              ingress_mon_hits_accepted <= '0;
            end
          end

          ING_MON_HDR0: begin
            if (asi_ingress_error[2]) begin
              ingress_mon_state <= ING_MON_MASK_FRAME;
            end else begin
              ingress_mon_state <= ING_MON_HDR1;
            end
          end

          ING_MON_HDR1: begin
            if (asi_ingress_error[2]) begin
              ingress_mon_state <= ING_MON_MASK_FRAME;
            end else begin
              ingress_mon_state <= ING_MON_HDR2;
            end
          end

          ING_MON_HDR2: begin
            if (asi_ingress_error[2]) begin
              ingress_mon_state <= ING_MON_MASK_FRAME;
            end else begin
              ingress_mon_state <= ING_MON_HDR3;
            end
          end

          ING_MON_HDR3: begin
            if (asi_ingress_error[2]) begin
              ingress_mon_state <= ING_MON_MASK_FRAME;
            end else begin
              ingress_mon_state <= ING_MON_BODY;
            end
          end

          ING_MON_BODY: begin
            if (is_subheader_word(asi_ingress_data)) begin
              if (asi_ingress_error[1]) begin
                ingress_mon_state <= ING_MON_MASK_SUBH;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end else if (asi_ingress_data[15:8] != 8'd0) begin
                ingress_mon_state <= ING_MON_HITS;
                ingress_mon_hits_remaining <= asi_ingress_data[15:8];
                ingress_mon_hits_accepted <= '0;
              end else begin
                ingress_mon_state <= ING_MON_BODY;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end
            end else if (is_trailer_word(asi_ingress_data) && asi_ingress_endofpacket) begin
              ingress_mon_state <= ING_MON_IDLE;
              ingress_mon_hits_remaining <= '0;
              ingress_mon_hits_accepted <= '0;
            end
          end

          ING_MON_HITS: begin
            if (!asi_ingress_error[0]) begin
              ingress_mon_hits_accepted <= ingress_mon_hits_accepted + 8'd1;
            end
            if (ingress_mon_hits_remaining == 8'd1) begin
              ingress_mon_state <= ING_MON_BODY;
              ingress_mon_hits_remaining <= '0;
            end else begin
              ingress_mon_hits_remaining <= ingress_mon_hits_remaining - 8'd1;
            end
          end

          ING_MON_MASK_SUBH: begin
            if (is_trailer_word(asi_ingress_data) && asi_ingress_endofpacket) begin
              ingress_mon_state <= ING_MON_IDLE;
              ingress_mon_hits_remaining <= '0;
              ingress_mon_hits_accepted <= '0;
            end else if (is_subheader_word(asi_ingress_data)) begin
              if (asi_ingress_error[1]) begin
                ingress_mon_state <= ING_MON_MASK_SUBH;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end else if (asi_ingress_data[15:8] != 8'd0) begin
                ingress_mon_state <= ING_MON_HITS;
                ingress_mon_hits_remaining <= asi_ingress_data[15:8];
                ingress_mon_hits_accepted <= '0;
              end else begin
                ingress_mon_state <= ING_MON_BODY;
                ingress_mon_hits_remaining <= '0;
                ingress_mon_hits_accepted <= '0;
              end
            end
          end

          ING_MON_MASK_FRAME: begin
            if (is_trailer_word(asi_ingress_data) && asi_ingress_endofpacket) begin
              ingress_mon_state <= ING_MON_IDLE;
              ingress_mon_hits_remaining <= '0;
              ingress_mon_hits_accepted <= '0;
            end
          end

          default: begin
            ingress_mon_state <= ING_MON_IDLE;
            ingress_mon_hits_remaining <= '0;
            ingress_mon_hits_accepted <= '0;
          end
        endcase
      end
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
    !asi_ingress_valid |-> (asi_ingress_error == '0))
    else $error("OPQ_NATIVE_INGRESS_FORMAL error bits changed without valid");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid |-> $onehot0(asi_ingress_error))
    else $error("OPQ_NATIVE_INGRESS_FORMAL multiple ingress error bits were asserted on one beat");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_error[2] |-> ingress_hdr_error_legal_v)
    else $error("OPQ_NATIVE_INGRESS_FORMAL header error asserted outside preamble/header beats");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_error[1] |-> ingress_shd_error_legal_v)
    else $error("OPQ_NATIVE_INGRESS_FORMAL subheader error asserted outside subheader beats");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_error[0] |-> ingress_hit_error_legal_v)
    else $error("OPQ_NATIVE_INGRESS_FORMAL hit error asserted outside hit beats");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && is_trailer_word(asi_ingress_data) |-> (asi_ingress_error == '0))
    else $error("OPQ_NATIVE_INGRESS_FORMAL trailer carried an illegal ingress error bit");

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

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    lane_we |-> ingress_clean_hit_d)
    else $error("OPQ_NATIVE_INGRESS_FORMAL lane write fired outside a clean hit beat");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_shd_error_d |-> (!lane_we && !ticket_we))
    else $error("OPQ_NATIVE_INGRESS_FORMAL subheader error still produced parser writes");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_hdr_error_d |-> (!lane_we && !ticket_we))
    else $error("OPQ_NATIVE_INGRESS_FORMAL header error still produced parser writes");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_hit_error_d |-> !lane_we)
    else $error("OPQ_NATIVE_INGRESS_FORMAL hit error still wrote a hit word");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_zero_hit_subheader_d |-> (
      ticket_we &&
      !lane_we &&
      (ticket_wdata[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] == '0)))
    else $error("OPQ_NATIVE_INGRESS_FORMAL zero-hit subheader did not emit a zero-length ticket");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_last_hit_d |-> (
      ticket_we &&
      (ticket_wdata[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] == ingress_last_hit_accepted_d)))
    else $error("OPQ_NATIVE_INGRESS_FORMAL final subheader ticket length did not match accepted hits");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_trailer_d |-> tail_bypass_valid_dbg)
    else $error("OPQ_NATIVE_INGRESS_FORMAL trailer beat did not emit a tail-bypass pulse");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    !ingress_trailer_d |-> !tail_bypass_valid_dbg)
    else $error("OPQ_NATIVE_INGRESS_FORMAL tail-bypass pulse escaped a trailer beat");

  assert property (@(posedge d_clk) disable iff (d_reset || !past_valid)
    ingress_trailer_d |-> (tail_bypass_drop_dbg == ingress_masked_trailer_d))
    else $error("OPQ_NATIVE_INGRESS_FORMAL trailer-bypass drop flag did not match the parser mask state");

  cover property (@(posedge d_clk) disable iff (d_reset)
    $rose(alert_eop_dbg) ##[1:EOP_DRAIN_MAX] (ticket_we || eop_flush_ack_i));

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_startofpacket && is_preamble_word(asi_ingress_data) ##[1:32]
    asi_ingress_valid && asi_ingress_endofpacket && is_trailer_word(asi_ingress_data));

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && ingress_hdr_error_legal_v && asi_ingress_error[2]);

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && ingress_shd_error_legal_v && asi_ingress_error[1]);

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && ingress_hit_error_legal_v && asi_ingress_error[0]);

  cover property (@(posedge d_clk) disable iff (d_reset)
    ingress_trailer_d && !ingress_masked_trailer_d && tail_bypass_valid_dbg && !tail_bypass_drop_dbg);

  cover property (@(posedge d_clk) disable iff (d_reset)
    ingress_masked_trailer_d && tail_bypass_valid_dbg && tail_bypass_drop_dbg);
endmodule

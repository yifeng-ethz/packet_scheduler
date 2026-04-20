//------------------------------------------------------------------------------
// IP Name   : opq_native_ingress_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.3 - add header-count-aware ingress frame grammar checks
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
  localparam int unsigned FRAME_HDR_AUX_WORDS_WIDTH =
    (FRAME_HDR_AUX_WORDS <= 1) ? 1 : $clog2(FRAME_HDR_AUX_WORDS + 1);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  logic                              past_valid;
  logic                              frame_open;
  logic [FRAME_HDR_AUX_WORDS_WIDTH-1:0] frame_hdr_aux_words_left;
  logic [FRAME_SUBH_CNT_SIZE-1:0]    expected_frame_subhdr_cnt;
  logic [FRAME_HIT_CNT_SIZE-1:0]     expected_frame_hit_cnt;
  logic [FRAME_SUBH_CNT_SIZE-1:0]    observed_frame_subhdr_cnt;
  logic [FRAME_HIT_CNT_SIZE-1:0]     observed_frame_hit_cnt;
  logic [7:0]                        subheader_hits_left;
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

  function automatic logic is_hit_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0000);
  endfunction

  function automatic logic [FRAME_SUBH_CNT_SIZE-1:0] decode_frame_subhdr_cnt(
    input logic [35:0] word_v
  );
    return FRAME_SUBH_CNT_SIZE'({1'b0, word_v[30:16]});
  endfunction

  function automatic logic [FRAME_HIT_CNT_SIZE-1:0] decode_frame_hit_cnt(
    input logic [35:0] word_v
  );
    return FRAME_HIT_CNT_SIZE'(word_v[15:0]);
  endfunction

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      past_valid <= 1'b0;
      frame_open <= 1'b0;
      frame_hdr_aux_words_left <= '0;
      expected_frame_subhdr_cnt <= '0;
      expected_frame_hit_cnt <= '0;
      observed_frame_subhdr_cnt <= '0;
      observed_frame_hit_cnt <= '0;
      subheader_hits_left <= '0;
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

      if (asi_ingress_valid) begin
        if (!frame_open) begin
          assert (asi_ingress_startofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL frame started without SOP");
          assert (!asi_ingress_endofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL frame collapsed into a single SOP/EOP beat");
          assert (is_preamble_word(asi_ingress_data))
            else $error("OPQ_NATIVE_INGRESS_FORMAL frame started on a non-preamble word");

          frame_open <= 1'b1;
          frame_hdr_aux_words_left <= FRAME_HDR_AUX_WORDS_WIDTH'(FRAME_HDR_AUX_WORDS);
          expected_frame_subhdr_cnt <= '0;
          expected_frame_hit_cnt <= '0;
          observed_frame_subhdr_cnt <= '0;
          observed_frame_hit_cnt <= '0;
          subheader_hits_left <= '0;
        end else if (frame_hdr_aux_words_left != 0) begin
          logic [FRAME_SUBH_CNT_SIZE-1:0] declared_subhdr_cnt_v;
          logic [FRAME_HIT_CNT_SIZE-1:0] declared_hit_cnt_v;

          assert (!asi_ingress_startofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL SOP reasserted inside a frame header");
          assert (!asi_ingress_endofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL EOP arrived before the frame trailer");
          assert (!is_preamble_word(asi_ingress_data) &&
            !is_subheader_word(asi_ingress_data) &&
            !is_trailer_word(asi_ingress_data))
            else $error("OPQ_NATIVE_INGRESS_FORMAL marker word arrived inside the frame header payload");

          if (frame_hdr_aux_words_left == FRAME_HDR_AUX_WORDS_WIDTH'(2)) begin
            declared_subhdr_cnt_v = decode_frame_subhdr_cnt(asi_ingress_data);
            declared_hit_cnt_v = decode_frame_hit_cnt(asi_ingress_data);

            assert (asi_ingress_data[31] == 1'b0)
              else $error("OPQ_NATIVE_INGRESS_FORMAL reserved frame count bit[31] was set");
            assert (declared_subhdr_cnt_v <= FRAME_SUBH_CNT_SIZE'(N_SHD))
              else $error("OPQ_NATIVE_INGRESS_FORMAL frame header sub-header count exceeded N_SHD");
            assert (declared_hit_cnt_v <= FRAME_HIT_CNT_SIZE'(N_SHD * N_HIT))
              else $error("OPQ_NATIVE_INGRESS_FORMAL frame header hit count exceeded N_SHD*N_HIT");

            expected_frame_subhdr_cnt <= declared_subhdr_cnt_v;
            expected_frame_hit_cnt <= declared_hit_cnt_v;
          end

          frame_hdr_aux_words_left <= frame_hdr_aux_words_left - FRAME_HDR_AUX_WORDS_WIDTH'(1);
        end else if (is_trailer_word(asi_ingress_data)) begin
          assert (!asi_ingress_startofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL trailer illegally asserted SOP");
          assert (asi_ingress_endofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL trailer arrived without EOP");
          assert (subheader_hits_left == 0)
            else $error("OPQ_NATIVE_INGRESS_FORMAL trailer arrived while hit payloads were still pending");
          assert (observed_frame_subhdr_cnt == expected_frame_subhdr_cnt)
            else $error("OPQ_NATIVE_INGRESS_FORMAL trailer sub-header count mismatch");
          assert (observed_frame_hit_cnt == expected_frame_hit_cnt)
            else $error("OPQ_NATIVE_INGRESS_FORMAL trailer hit count mismatch");

          frame_open <= 1'b0;
          frame_hdr_aux_words_left <= '0;
          subheader_hits_left <= '0;
        end else if (is_subheader_word(asi_ingress_data)) begin
          assert (!asi_ingress_startofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL sub-header illegally asserted SOP");
          assert (!asi_ingress_endofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL sub-header illegally asserted EOP");
          assert (subheader_hits_left == 0)
            else $error("OPQ_NATIVE_INGRESS_FORMAL sub-header arrived before the previous payload drained");
          assert (observed_frame_subhdr_cnt < expected_frame_subhdr_cnt)
            else $error("OPQ_NATIVE_INGRESS_FORMAL sub-header count exceeded the frame header declaration");
          assert (asi_ingress_data[15:8] <= 8'(N_HIT))
            else $error("OPQ_NATIVE_INGRESS_FORMAL sub-header hit count exceeded N_HIT");

          observed_frame_subhdr_cnt <= observed_frame_subhdr_cnt + FRAME_SUBH_CNT_SIZE'(1);
          subheader_hits_left <= asi_ingress_data[15:8];
        end else begin
          assert (!asi_ingress_startofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL hit payload illegally asserted SOP");
          assert (!asi_ingress_endofpacket)
            else $error("OPQ_NATIVE_INGRESS_FORMAL hit payload illegally asserted EOP");
          assert (is_hit_word(asi_ingress_data))
            else $error("OPQ_NATIVE_INGRESS_FORMAL body beat was neither sub-header, hit, nor trailer");
          assert (subheader_hits_left != 0)
            else $error("OPQ_NATIVE_INGRESS_FORMAL hit payload arrived without a pending sub-header");
          assert (observed_frame_hit_cnt < expected_frame_hit_cnt)
            else $error("OPQ_NATIVE_INGRESS_FORMAL hit count exceeded the frame header declaration");

          observed_frame_hit_cnt <= observed_frame_hit_cnt + FRAME_HIT_CNT_SIZE'(1);
          subheader_hits_left <= subheader_hits_left - 8'd1;
        end
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
    asi_ingress_valid && asi_ingress_startofpacket |-> is_preamble_word(asi_ingress_data))
    else $error("OPQ_NATIVE_INGRESS_FORMAL SOP arrived on a non-preamble word");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_endofpacket |-> is_trailer_word(asi_ingress_data))
    else $error("OPQ_NATIVE_INGRESS_FORMAL EOP arrived on a non-trailer word");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && is_preamble_word(asi_ingress_data) |-> asi_ingress_startofpacket)
    else $error("OPQ_NATIVE_INGRESS_FORMAL preamble arrived without SOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && is_trailer_word(asi_ingress_data) |-> asi_ingress_endofpacket)
    else $error("OPQ_NATIVE_INGRESS_FORMAL trailer arrived without EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    alert_eop_dbg && eop_flush_ack_i |=> !alert_eop_dbg)
    else $error("OPQ_NATIVE_INGRESS_FORMAL flush ack did not clear alert_eop");

  cover property (@(posedge d_clk) disable iff (d_reset)
    $rose(alert_eop_dbg) ##[1:EOP_DRAIN_MAX] (ticket_we || eop_flush_ack_i));

  cover property (@(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid && asi_ingress_startofpacket && is_preamble_word(asi_ingress_data) ##1
    asi_ingress_valid ##1
    asi_ingress_valid ##1
    asi_ingress_valid ##1
    asi_ingress_valid && is_subheader_word(asi_ingress_data) ##[0:16]
    asi_ingress_valid && is_hit_word(asi_ingress_data) ##[1:32]
    asi_ingress_valid && asi_ingress_endofpacket && is_trailer_word(asi_ingress_data));
endmodule

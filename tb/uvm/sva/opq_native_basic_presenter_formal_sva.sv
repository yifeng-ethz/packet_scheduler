//------------------------------------------------------------------------------
// IP Name   : opq_native_basic_presenter_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - formal-oriented basic-presenter packet boundary invariants
// Description:
//   Native-SV formal checker for the live basic presenter. This is the active
//   native-SV signoff egress path today, so these checks are prioritized ahead
//   of the standalone tiled presenter.
//------------------------------------------------------------------------------
module opq_native_basic_presenter_formal_sva #(
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned META_ADDR_WIDTH = 9,
  parameter int unsigned EGRESS_DELAY = 3
) (
  input logic                                 d_clk,
  input logic                                 d_reset,
  input logic                                 packet_complete_i,
  input logic                                 new_frame_valid_i,
  input logic [PAGE_RAM_ADDR_WIDTH-1:0]       page_ram_rd_addr_o,
  input logic [PAGE_RAM_DATA_WIDTH-1:0]       page_ram_rd_data_i,
  input logic [PAGE_RAM_RD_WIDTH-1:0]         aso_egress_data,
  input logic                                 aso_egress_valid,
  input logic                                 aso_egress_ready,
  input logic                                 aso_egress_startofpacket,
  input logic                                 aso_egress_endofpacket,
  input logic [2:0]                           aso_egress_error,
  input logic [2:0]                           presenter_state,
  input logic [META_ADDR_WIDTH-1:0]           meta_wptr,
  input logic [META_ADDR_WIDTH-1:0]           meta_rptr,
  input logic [META_ADDR_WIDTH-1:0]           meta_pkt_wcnt,
  input logic [META_ADDR_WIDTH-1:0]           meta_pkt_rcnt,
  input logic [PAGE_RAM_ADDR_WIDTH-1:0]       page_ram_rptr,
  input logic [EGRESS_DELAY:0]                output_data_valid,
  input logic [PAGE_RAM_DATA_WIDTH-1:0]       output_data,
  input logic [PAGE_RAM_ADDR_WIDTH-1:0]       pkt_rd_word_cnt,
  input logic                                 retire_pending
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [2:0] FTABLE_PRESENTER_IDLE = 3'd0;
  localparam logic [2:0] FTABLE_PRESENTER_WAIT_FOR_COMPLETE = 3'd1;
  localparam logic [2:0] FTABLE_PRESENTER_PRESENTING = 3'd2;
  localparam logic [2:0] FTABLE_PRESENTER_RESET = 3'd3;

  logic packet_open;

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      packet_open <= 1'b0;
    end else if (aso_egress_valid && aso_egress_ready) begin
      if (aso_egress_startofpacket) begin
        packet_open <= 1'b1;
      end
      if (aso_egress_endofpacket) begin
        packet_open <= 1'b0;
      end
    end
  end

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && !aso_egress_ready |=> aso_egress_valid &&
      $stable({aso_egress_data, aso_egress_startofpacket, aso_egress_endofpacket, aso_egress_error}))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL egress beat changed under backpressure");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && !aso_egress_ready |=>
      $stable(page_ram_rptr) && $stable(meta_rptr) && $stable(meta_pkt_rcnt) &&
      $stable(pkt_rd_word_cnt) && $stable(output_data_valid) && $stable(output_data))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL internal presenter pointers moved under backpressure");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_startofpacket |->
      (aso_egress_data[35:32] == 4'b0001) && (aso_egress_data[7:0] == K285))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL SOP beat is not a preamble");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_endofpacket |->
      (aso_egress_data[35:32] == 4'b0001) && (aso_egress_data[7:0] == K284))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL EOP beat is not a trailer");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid |-> !(aso_egress_startofpacket && aso_egress_endofpacket))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL single-beat collapse detected");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_ready && aso_egress_startofpacket |-> !packet_open)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL second SOP arrived before EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_ready && aso_egress_endofpacket |-> packet_open)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL EOP arrived without an open packet");

  assert property (@(posedge d_clk) disable iff (d_reset)
    retire_pending && aso_egress_valid && aso_egress_ready |=> (presenter_state == FTABLE_PRESENTER_IDLE) &&
      (meta_rptr == ($past(meta_rptr) + META_ADDR_WIDTH'(1))) &&
      (meta_pkt_rcnt == ($past(meta_pkt_rcnt) + META_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer retire did not advance meta pointers exactly once");

  assert property (@(posedge d_clk) disable iff (d_reset)
    packet_complete_i |=> (meta_pkt_wcnt == ($past(meta_pkt_wcnt) + META_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL packet_complete did not advance meta_pkt_wcnt");

  assert property (@(posedge d_clk) disable iff (d_reset)
    new_frame_valid_i |=> (meta_wptr == ($past(meta_wptr) + META_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL new_frame_valid did not advance meta_wptr");

  assert property (@(posedge d_clk) d_reset |=> !aso_egress_valid &&
    (presenter_state == FTABLE_PRESENTER_RESET))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL reset did not force the presenter quiescent");

  cover property (@(posedge d_clk) disable iff (d_reset)
    new_frame_valid_i ##[1:32] packet_complete_i ##[1:64]
    aso_egress_valid && aso_egress_startofpacket && aso_egress_ready ##[1:64]
    aso_egress_valid && !aso_egress_ready ##1
    aso_egress_valid && aso_egress_ready ##[1:64]
    aso_egress_valid && aso_egress_endofpacket && aso_egress_ready);
endmodule

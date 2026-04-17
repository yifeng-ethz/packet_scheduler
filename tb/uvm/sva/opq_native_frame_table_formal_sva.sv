//------------------------------------------------------------------------------
// IP Name   : opq_native_frame_table_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - formal-oriented frame-table tracker/presenter invariants
// Description:
//   Native-SV formal checkers for the standalone frame-table tracker and tiled
//   presenter translations. These modules are not yet on the live signoff
//   path, but the local invariants from DV_FORMAL are implemented now so the
//   later swap-over has packet/flush checks ready.
//------------------------------------------------------------------------------
module opq_native_frame_table_tracker_formal_sva #(
  parameter int unsigned N_TILE = 5,
  parameter int unsigned TILE_FIFO_DEPTH = 512,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned TILE_PKT_CNT_WIDTH = 10
) (
  input logic                                                 d_clk,
  input logic                                                 d_reset,
  input logic [1:0]                                           i_update_ftable_valid,
  input logic [1:0][$clog2(N_TILE)-1:0]                       i_update_ftable_tindex,
  input logic [1:0]                                           i_flush_ftable_valid,
  input logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       i_tile_rptr,
  input logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            i_tile_pkt_rcnt,
  input logic [N_TILE-1:0]                                    o_tile_fifo_we,
  input logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_wptr,
  input logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            o_tile_pkt_wcnt,
  input logic [N_TILE-1:0][$clog2(N_TILE):0]                  o_trail_tid,
  input logic [N_TILE-1:0][$clog2(N_TILE):0]                  o_body_tid
);
  generate
    genvar lane;
    for (lane = 0; lane < 2; lane++) begin : gen_flush_port
      assert property (@(posedge d_clk) disable iff (d_reset)
        i_flush_ftable_valid[lane] |=>
          (o_tile_wptr[i_update_ftable_tindex[lane]] == $past(i_tile_rptr[i_update_ftable_tindex[lane]])) &&
          (o_tile_pkt_wcnt[i_update_ftable_tindex[lane]] == $past(i_tile_pkt_rcnt[i_update_ftable_tindex[lane]])))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL flush did not reset tile write state on port %0d", lane);

      assert property (@(posedge d_clk) disable iff (d_reset)
        i_flush_ftable_valid[lane] |=>
          (o_trail_tid[i_update_ftable_tindex[lane]] == '0) &&
          (o_body_tid[i_update_ftable_tindex[lane]] == '0))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL flush did not clear TID ownership on port %0d", lane);

      assert property (@(posedge d_clk) disable iff (d_reset)
        i_update_ftable_valid[lane] && i_flush_ftable_valid[lane] |=>
          (o_tile_wptr[i_update_ftable_tindex[lane]] == $past(i_tile_rptr[i_update_ftable_tindex[lane]])))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL flush did not win over update on port %0d", lane);
    end

    for (lane = 0; lane < N_TILE; lane++) begin : gen_tile
      assert property (@(posedge d_clk) disable iff (d_reset)
        o_tile_fifo_we[lane] &&
        !(i_flush_ftable_valid[0] && (i_update_ftable_tindex[0] == lane)) &&
        !(i_flush_ftable_valid[1] && (i_update_ftable_tindex[1] == lane))
        |=> (o_tile_wptr[lane] == ($past(o_tile_wptr[lane]) + $clog2(TILE_FIFO_DEPTH)'(1))))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL tile %0d write pointer did not advance on write", lane);

      assert property (@(posedge d_clk) disable iff (d_reset)
        !o_tile_fifo_we[lane] &&
        !(i_flush_ftable_valid[0] && (i_update_ftable_tindex[0] == lane)) &&
        !(i_flush_ftable_valid[1] && (i_update_ftable_tindex[1] == lane))
        |=>
          $stable(o_tile_wptr[lane]))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL tile %0d write pointer moved without a write or flush", lane);

      assert property (@(posedge d_clk) disable iff (d_reset)
        $onehot0({o_trail_tid[lane][$clog2(N_TILE)], o_body_tid[lane][$clog2(N_TILE)]}))
        else $error("OPQ_NATIVE_FTABLE_TRACKER_FORMAL tile %0d TID ownership is not onehot0", lane);
    end
  endgenerate
endmodule

module opq_native_frame_table_presenter_formal_sva #(
  parameter int unsigned N_TILE = 5,
  parameter int unsigned TILE_FIFO_DEPTH = 512,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned TILE_PKT_CNT_WIDTH = 10,
  parameter int unsigned EGRESS_DELAY = 2
) (
  input logic                                                 d_clk,
  input logic                                                 d_reset,
  input logic                                                 i_egress_ready,
  input logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_rptr,
  input logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            o_tile_pkt_rcnt,
  input logic [$clog2(N_TILE)-1:0]                            o_rseg_tile_index,
  input logic                                                 o_egress_valid,
  input logic [PAGE_RAM_DATA_WIDTH-1:0]                       o_egress_data,
  input logic                                                 o_egress_startofpacket,
  input logic                                                 o_egress_endofpacket,
  input logic [2:0]                                           o_state,
  input logic [N_TILE-1:0][$clog2(PAGE_RAM_DEPTH)-1:0]        page_ram_rptr,
  input logic [$clog2(PAGE_RAM_DEPTH)-1:0]                    pkt_rd_word_cnt
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [2:0] PRESENTER_RESETTING = 3'd6;
  logic packet_open;

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      packet_open <= 1'b0;
    end else if (o_egress_valid && i_egress_ready) begin
      if (o_egress_startofpacket) begin
        packet_open <= 1'b1;
      end
      if (o_egress_endofpacket) begin
        packet_open <= 1'b0;
      end
    end
  end

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && !i_egress_ready |=> o_egress_valid &&
      $stable({o_egress_data, o_egress_startofpacket, o_egress_endofpacket}))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL egress beat changed under backpressure");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && !i_egress_ready |=>
      $stable(page_ram_rptr) && $stable(o_tile_rptr) &&
      $stable(o_tile_pkt_rcnt) && $stable(pkt_rd_word_cnt))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL read-side pointers moved under backpressure");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && o_egress_startofpacket |->
      (o_egress_data[35:32] == 4'b0001) && (o_egress_data[7:0] == K285))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL SOP beat is not a preamble");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && o_egress_endofpacket |->
      (o_egress_data[35:32] == 4'b0001) && (o_egress_data[7:0] == K284))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL EOP beat is not a trailer");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid |-> !(o_egress_startofpacket && o_egress_endofpacket))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL single-beat collapse detected");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && i_egress_ready && o_egress_startofpacket |-> !packet_open)
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL second SOP arrived before EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && i_egress_ready && o_egress_endofpacket |-> packet_open)
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL EOP arrived without an open packet");

  assert property (@(posedge d_clk) d_reset |=> !o_egress_valid &&
    (o_state == PRESENTER_RESETTING))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL reset did not force the presenter quiescent");

  cover property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && o_egress_startofpacket && i_egress_ready ##[1:32]
    o_egress_valid && !i_egress_ready ##1
    o_egress_valid && i_egress_ready ##[1:64]
    o_egress_valid && o_egress_endofpacket && i_egress_ready);
endmodule

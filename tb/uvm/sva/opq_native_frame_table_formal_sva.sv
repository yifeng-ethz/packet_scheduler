//------------------------------------------------------------------------------
// IP Name   : opq_native_frame_table_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - add count-aware packet grammar checks to the tiled presenter
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
  localparam logic [7:0] K237 = 8'hF7;
  localparam int unsigned FRAME_HDR_AUX_WORDS = 4;
  localparam int unsigned FRAME_HDR_AUX_WORDS_WIDTH =
    (FRAME_HDR_AUX_WORDS <= 1) ? 1 : $clog2(FRAME_HDR_AUX_WORDS + 1);
  localparam logic [2:0] PRESENTER_RESETTING = 3'd6;
  logic                              frame_open;
  logic [7:0]                        hit_words_left;
  logic [FRAME_HDR_AUX_WORDS_WIDTH-1:0] frame_hdr_aux_words_left;
  logic                              saw_nonempty_subhdr;
  logic [31:0]                       frame_ts_hi32;
  logic [15:0]                       frame_ts_lo16;
  logic [15:0]                       expected_frame_subhdr_cnt;
  logic [15:0]                       expected_frame_hit_cnt;
  logic [15:0]                       emitted_frame_subhdr_cnt;
  logic [15:0]                       emitted_frame_hit_cnt;
  logic [35:0]                       subheader_ts_hi;
  logic [7:0]                        last_subhdr_byte;
  logic                              last_subhdr_valid;
  logic [47:0]                       last_subhdr_abs_ts;
  logic [47:0]                       last_nonempty_subhdr_abs_ts;
  logic [15:0]                       current_frame_pkg_cnt;
  logic [15:0]                       last_closed_frame_pkg_cnt;
  logic                              last_closed_frame_valid;
  logic [47:0]                       last_closed_frame_ts;

  function automatic logic pkt_is_preamble(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic pkt_is_frame_trl(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

  function automatic logic pkt_is_subhdr(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic pkt_is_hit(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return (word_v[35:32] == 4'b0000);
  endfunction

  function automatic logic [15:0] decode_frame_subhdr_cnt(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return 16'({1'b0, word_v[30:16]});
  endfunction

  function automatic logic [15:0] decode_frame_hit_cnt(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    return 16'(word_v[15:0]);
  endfunction

  function automatic logic [35:0] extend_subheader_ts_hi(
    input logic [35:0] curr_hi,
    input logic        last_valid,
    input logic [7:0]  last_byte,
    input logic [7:0]  curr_byte
  );
    logic [35:0] hi_v;
    begin
      hi_v = curr_hi;
      if (last_valid && (curr_byte < last_byte)) begin
        hi_v = hi_v + 36'd1;
      end
      return hi_v;
    end
  endfunction

  function automatic logic [47:0] make_subheader_abs_ts(
    input logic [35:0] ts_hi,
    input logic [7:0]  shd_byte
  );
    return {ts_hi, shd_byte, 4'h0};
  endfunction

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      frame_open <= 1'b0;
      hit_words_left <= '0;
      frame_hdr_aux_words_left <= '0;
      saw_nonempty_subhdr <= 1'b0;
      frame_ts_hi32 <= '0;
      frame_ts_lo16 <= '0;
      expected_frame_subhdr_cnt <= '0;
      expected_frame_hit_cnt <= '0;
      emitted_frame_subhdr_cnt <= '0;
      emitted_frame_hit_cnt <= '0;
      subheader_ts_hi <= '0;
      last_subhdr_byte <= '0;
      last_subhdr_valid <= 1'b0;
      last_subhdr_abs_ts <= '0;
      last_nonempty_subhdr_abs_ts <= '0;
      current_frame_pkg_cnt <= '0;
      last_closed_frame_pkg_cnt <= '0;
      last_closed_frame_valid <= 1'b0;
      last_closed_frame_ts <= '0;
    end else if (o_egress_valid && i_egress_ready) begin
      if (!frame_open) begin
        assert (o_egress_startofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL frame started without SOP");
        assert (!o_egress_endofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL frame collapsed into a single SOP/EOP beat");
        assert (pkt_is_preamble(o_egress_data))
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL frame started on a non-preamble word");

        frame_open <= 1'b1;
        frame_hdr_aux_words_left <= FRAME_HDR_AUX_WORDS_WIDTH'(FRAME_HDR_AUX_WORDS);
        hit_words_left <= '0;
        saw_nonempty_subhdr <= 1'b0;
        frame_ts_hi32 <= '0;
        frame_ts_lo16 <= '0;
        expected_frame_subhdr_cnt <= '0;
        expected_frame_hit_cnt <= '0;
        emitted_frame_subhdr_cnt <= '0;
        emitted_frame_hit_cnt <= '0;
        subheader_ts_hi <= '0;
        last_subhdr_byte <= '0;
        last_subhdr_valid <= 1'b0;
        last_subhdr_abs_ts <= '0;
        last_nonempty_subhdr_abs_ts <= '0;
        current_frame_pkg_cnt <= '0;
      end else if (frame_hdr_aux_words_left != 0) begin
        logic [15:0] declared_subhdr_cnt_v;
        logic [15:0] declared_hit_cnt_v;

        assert (!o_egress_startofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL SOP reasserted inside a frame header");
        assert (!o_egress_endofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL EOP arrived before the frame trailer");
        assert (!pkt_is_preamble(o_egress_data) &&
          !pkt_is_subhdr(o_egress_data) &&
          !pkt_is_frame_trl(o_egress_data))
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL marker word arrived inside the frame header payload");

        case (frame_hdr_aux_words_left)
          FRAME_HDR_AUX_WORDS_WIDTH'(4): frame_ts_hi32 <= o_egress_data[31:0];
          FRAME_HDR_AUX_WORDS_WIDTH'(3): begin
            frame_ts_lo16 <= o_egress_data[31:16];
            subheader_ts_hi <= {frame_ts_hi32, o_egress_data[31:28]};
            current_frame_pkg_cnt <= o_egress_data[15:0];
            if (last_closed_frame_valid) begin
              assert (o_egress_data[15:0] > last_closed_frame_pkg_cnt)
                else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL frame pkg_cnt did not increase");
              assert ({frame_ts_hi32, o_egress_data[31:16]} > last_closed_frame_ts)
                else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL frame timestamp did not increase");
            end
          end
          FRAME_HDR_AUX_WORDS_WIDTH'(2): begin
            declared_subhdr_cnt_v = decode_frame_subhdr_cnt(o_egress_data);
            declared_hit_cnt_v = decode_frame_hit_cnt(o_egress_data);

            assert (o_egress_data[31] == 1'b0)
              else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL reserved frame count bit[31] was set");
            expected_frame_subhdr_cnt <= declared_subhdr_cnt_v;
            expected_frame_hit_cnt <= declared_hit_cnt_v;
          end
          default: begin
          end
        endcase
        frame_hdr_aux_words_left <= frame_hdr_aux_words_left - FRAME_HDR_AUX_WORDS_WIDTH'(1);
      end else if (pkt_is_frame_trl(o_egress_data)) begin
        assert (!o_egress_startofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer illegally asserted SOP");
        assert (o_egress_endofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer arrived without EOP");
        assert (hit_words_left == 0)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer arrived with hit words still pending");
        assert (emitted_frame_subhdr_cnt == expected_frame_subhdr_cnt)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer sub-header count mismatch");
        assert (emitted_frame_hit_cnt == expected_frame_hit_cnt)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer hit count mismatch");

        frame_open <= 1'b0;
        last_closed_frame_pkg_cnt <= current_frame_pkg_cnt;
        last_closed_frame_ts <= {frame_ts_hi32, frame_ts_lo16};
        last_closed_frame_valid <= 1'b1;
      end else if (pkt_is_subhdr(o_egress_data)) begin
        logic [35:0] subheader_ts_hi_v;
        logic [47:0] subheader_abs_ts_v;

        assert (!o_egress_startofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL sub-header illegally asserted SOP");
        assert (!o_egress_endofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL sub-header illegally asserted EOP");
        assert (hit_words_left == 0)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL sub-header arrived before the previous payload drained");
        assert (emitted_frame_subhdr_cnt < expected_frame_subhdr_cnt)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL sub-header count exceeded the frame header declaration");

        subheader_ts_hi_v = extend_subheader_ts_hi(
          subheader_ts_hi,
          last_subhdr_valid,
          last_subhdr_byte,
          o_egress_data[31:24]
        );
        subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, o_egress_data[31:24]);

        if (last_subhdr_valid) begin
          assert (subheader_abs_ts_v > last_subhdr_abs_ts)
            else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL sub-header absolute ts did not increase");
        end

        subheader_ts_hi <= subheader_ts_hi_v;
        last_subhdr_byte <= o_egress_data[31:24];
        last_subhdr_valid <= 1'b1;
        last_subhdr_abs_ts <= subheader_abs_ts_v;
        emitted_frame_subhdr_cnt <= emitted_frame_subhdr_cnt + 16'd1;

        if (o_egress_data[15:8] != 8'h00) begin
          if (saw_nonempty_subhdr) begin
            assert (subheader_abs_ts_v > last_nonempty_subhdr_abs_ts)
              else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL non-empty sub-header absolute ts did not increase");
          end
          saw_nonempty_subhdr <= 1'b1;
          last_nonempty_subhdr_abs_ts <= subheader_abs_ts_v;
          hit_words_left <= o_egress_data[15:8];
        end
      end else begin
        assert (!o_egress_startofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL hit payload illegally asserted SOP");
        assert (!o_egress_endofpacket)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL hit payload illegally asserted EOP");
        assert (pkt_is_hit(o_egress_data))
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL body beat was neither sub-header, hit, nor trailer");
        assert (hit_words_left != 0)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL hit payload arrived without a pending sub-header");
        assert (emitted_frame_hit_cnt < expected_frame_hit_cnt)
          else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL hit count exceeded the frame header declaration");

        hit_words_left <= hit_words_left - 8'd1;
        emitted_frame_hit_cnt <= emitted_frame_hit_cnt + 16'd1;
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
      pkt_is_preamble(o_egress_data))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL SOP beat is not a preamble");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && o_egress_endofpacket |->
      pkt_is_frame_trl(o_egress_data))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL EOP beat is not a trailer");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && pkt_is_preamble(o_egress_data) |-> o_egress_startofpacket)
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL preamble arrived without SOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && pkt_is_frame_trl(o_egress_data) |-> o_egress_endofpacket)
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL trailer arrived without EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid |-> !(o_egress_startofpacket && o_egress_endofpacket))
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL single-beat collapse detected");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && i_egress_ready && o_egress_startofpacket |-> !frame_open)
    else $error("OPQ_NATIVE_FTABLE_PRESENTER_FORMAL second SOP arrived before EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    o_egress_valid && i_egress_ready && o_egress_endofpacket |-> frame_open)
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

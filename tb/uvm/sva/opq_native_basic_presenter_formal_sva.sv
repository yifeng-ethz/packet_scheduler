//------------------------------------------------------------------------------
// IP Name   : opq_native_basic_presenter_formal_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.3 - allow same-timestamp emitted frames while catching regressions
// Description:
//   Native-SV formal checker for the live basic presenter. This is the active
//   native-SV signoff egress path today, so these checks are prioritized ahead
//   of the standalone tiled presenter.
//------------------------------------------------------------------------------
module opq_native_basic_presenter_formal_sva #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
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
  localparam logic [7:0] K237 = 8'hF7;
  localparam int unsigned FRAME_HDR_AUX_WORDS = 4;
  localparam int unsigned FRAME_HDR_AUX_WORDS_WIDTH =
    (FRAME_HDR_AUX_WORDS <= 1) ? 1 : $clog2(FRAME_HDR_AUX_WORDS + 1);
  localparam logic [2:0] FTABLE_PRESENTER_IDLE = 3'd0;
  localparam logic [2:0] FTABLE_PRESENTER_WAIT_FOR_COMPLETE = 3'd1;
  localparam logic [2:0] FTABLE_PRESENTER_PRESENTING = 3'd2;
  localparam logic [2:0] FTABLE_PRESENTER_RESET = 3'd3;

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

  function automatic logic pkt_is_preamble(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic pkt_is_frame_trl(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

  function automatic logic pkt_is_subhdr(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic pkt_is_hit(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0000);
  endfunction

  function automatic logic [15:0] decode_frame_subhdr_cnt(input logic [35:0] word_v);
    return 16'({1'b0, word_v[30:16]});
  endfunction

  function automatic logic [15:0] decode_frame_hit_cnt(input logic [35:0] word_v);
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
    end else if (aso_egress_valid && aso_egress_ready) begin
      if (!frame_open) begin
        assert (aso_egress_startofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame started without SOP");
        assert (!aso_egress_endofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame collapsed into a single SOP/EOP beat");
        assert (pkt_is_preamble(aso_egress_data))
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame started on a non-preamble word");

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

        assert (!aso_egress_startofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL SOP reasserted inside a frame header");
        assert (!aso_egress_endofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL EOP arrived before the frame trailer");
        assert (!pkt_is_preamble(aso_egress_data) &&
          !pkt_is_subhdr(aso_egress_data) &&
          !pkt_is_frame_trl(aso_egress_data))
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL marker word arrived inside the frame header payload");

        case (frame_hdr_aux_words_left)
          FRAME_HDR_AUX_WORDS_WIDTH'(4): frame_ts_hi32 <= aso_egress_data[31:0];
          FRAME_HDR_AUX_WORDS_WIDTH'(3): begin
            frame_ts_lo16 <= aso_egress_data[31:16];
            subheader_ts_hi <= {frame_ts_hi32, aso_egress_data[31:28]};
            current_frame_pkg_cnt <= aso_egress_data[15:0];
            if (last_closed_frame_valid) begin
              assert (aso_egress_data[15:0] > last_closed_frame_pkg_cnt)
                else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame pkg_cnt did not increase");
              assert ({frame_ts_hi32, aso_egress_data[31:16]} >= last_closed_frame_ts)
                else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame timestamp regressed");
            end
          end
          FRAME_HDR_AUX_WORDS_WIDTH'(2): begin
            declared_subhdr_cnt_v = decode_frame_subhdr_cnt(aso_egress_data);
            declared_hit_cnt_v = decode_frame_hit_cnt(aso_egress_data);

            assert (aso_egress_data[31] == 1'b0)
              else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL reserved frame count bit[31] was set");
            assert (declared_subhdr_cnt_v <= 16'(N_SHD * N_LANE))
              else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame sub-header count exceeded the configured maximum");
            assert (declared_hit_cnt_v <= 16'(N_SHD * N_HIT))
              else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL frame hit count exceeded the configured maximum");

            expected_frame_subhdr_cnt <= declared_subhdr_cnt_v;
            expected_frame_hit_cnt <= declared_hit_cnt_v;
          end
          default: begin
          end
        endcase
        frame_hdr_aux_words_left <= frame_hdr_aux_words_left - FRAME_HDR_AUX_WORDS_WIDTH'(1);
      end else if (pkt_is_frame_trl(aso_egress_data)) begin
        assert (!aso_egress_startofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer illegally asserted SOP");
        assert (aso_egress_endofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer arrived without EOP");
        assert (hit_words_left == 0)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer arrived with hit words still pending");
        assert (emitted_frame_subhdr_cnt == expected_frame_subhdr_cnt)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer sub-header count mismatch");
        assert (emitted_frame_hit_cnt == expected_frame_hit_cnt)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer hit count mismatch");

        frame_open <= 1'b0;
        last_closed_frame_pkg_cnt <= current_frame_pkg_cnt;
        last_closed_frame_ts <= {frame_ts_hi32, frame_ts_lo16};
        last_closed_frame_valid <= 1'b1;
      end else if (pkt_is_subhdr(aso_egress_data)) begin
        logic [35:0] subheader_ts_hi_v;
        logic [47:0] subheader_abs_ts_v;

        assert (!aso_egress_startofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header illegally asserted SOP");
        assert (!aso_egress_endofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header illegally asserted EOP");
        assert (hit_words_left == 0)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header arrived before the previous payload drained");
        assert (emitted_frame_subhdr_cnt < expected_frame_subhdr_cnt)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header count exceeded the frame header declaration");
        assert (aso_egress_data[15:8] <= 8'(N_HIT))
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header hit count exceeded N_HIT");

        subheader_ts_hi_v = extend_subheader_ts_hi(
          subheader_ts_hi,
          last_subhdr_valid,
          last_subhdr_byte,
          aso_egress_data[31:24]
        );
        subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, aso_egress_data[31:24]);

        if (last_subhdr_valid) begin
          assert (subheader_abs_ts_v > last_subhdr_abs_ts)
            else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL sub-header absolute ts did not increase");
        end

        subheader_ts_hi <= subheader_ts_hi_v;
        last_subhdr_byte <= aso_egress_data[31:24];
        last_subhdr_valid <= 1'b1;
        last_subhdr_abs_ts <= subheader_abs_ts_v;
        emitted_frame_subhdr_cnt <= emitted_frame_subhdr_cnt + 16'd1;

        if (aso_egress_data[15:8] != 8'h00) begin
          if (saw_nonempty_subhdr) begin
            assert (subheader_abs_ts_v > last_nonempty_subhdr_abs_ts)
              else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL non-empty sub-header absolute ts did not increase");
          end
          saw_nonempty_subhdr <= 1'b1;
          last_nonempty_subhdr_abs_ts <= subheader_abs_ts_v;
          hit_words_left <= aso_egress_data[15:8];
        end
      end else begin
        assert (!aso_egress_startofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL hit payload illegally asserted SOP");
        assert (!aso_egress_endofpacket)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL hit payload illegally asserted EOP");
        assert (pkt_is_hit(aso_egress_data))
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL body beat was neither sub-header, hit, nor trailer");
        assert (hit_words_left != 0)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL hit payload arrived without a pending sub-header");
        assert (emitted_frame_hit_cnt < expected_frame_hit_cnt)
          else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL hit count exceeded the frame header declaration");

        hit_words_left <= hit_words_left - 8'd1;
        emitted_frame_hit_cnt <= emitted_frame_hit_cnt + 16'd1;
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
      pkt_is_preamble(aso_egress_data))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL SOP beat is not a preamble");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_endofpacket |->
      pkt_is_frame_trl(aso_egress_data))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL EOP beat is not a trailer");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && pkt_is_preamble(aso_egress_data) |-> aso_egress_startofpacket)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL preamble arrived without SOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && pkt_is_frame_trl(aso_egress_data) |-> aso_egress_endofpacket)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer arrived without EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid |-> !(aso_egress_startofpacket && aso_egress_endofpacket))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL single-beat collapse detected");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_ready && aso_egress_startofpacket |-> !frame_open)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL second SOP arrived before EOP");

  assert property (@(posedge d_clk) disable iff (d_reset)
    aso_egress_valid && aso_egress_ready && aso_egress_endofpacket |-> frame_open)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL EOP arrived without an open packet");

  assert property (@(posedge d_clk) disable iff (d_reset)
    retire_pending && aso_egress_valid && aso_egress_ready |=> (presenter_state == FTABLE_PRESENTER_IDLE) &&
      (meta_rptr == ($past(meta_rptr) + META_ADDR_WIDTH'(1))) &&
      (meta_pkt_rcnt == ($past(meta_pkt_rcnt) + META_ADDR_WIDTH'(1))))
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL trailer retire did not advance meta pointers exactly once");

  assert property (@(posedge d_clk) disable iff (d_reset)
    retire_pending && aso_egress_valid |-> aso_egress_endofpacket)
    else $error("OPQ_NATIVE_BASIC_PRESENTER_FORMAL retire_pending exposed a non-trailer beat");

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

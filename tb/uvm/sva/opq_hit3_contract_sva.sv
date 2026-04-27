//------------------------------------------------------------------------------
// IP Name   : opq_hit3_contract_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.6 - track 16-bit subheader hit counts
// Description:
//   Checks the active egress frame/subheader/hit contract used by the UVM
//   scoreboard: an implicit 5-word frame header, then K237 subheaders, hit
//   payloads, and a K284 trailer. Absolute subheader ordering is reconstructed
//   from the full frame timestamp and extended across subheader-byte wrap.
//------------------------------------------------------------------------------
module opq_hit3_contract_sva (
  input logic clk,
  input logic reset,
  input logic [35:0] data,
  input logic valid,
  input logic ready
);
  localparam int unsigned FRAME_HDR_AUX_WORDS = 4;

  logic frame_open;
  logic [15:0] hit_words_left;
  logic [2:0] frame_hdr_aux_words_left;
  logic saw_nonempty_subhdr;
  logic [31:0] frame_ts_hi32;
  logic [15:0] frame_ts_lo16;
  logic [15:0] expected_frame_subhdr_cnt;
  logic [15:0] expected_frame_hit_cnt;
  logic [15:0] emitted_frame_subhdr_cnt;
  logic [15:0] emitted_frame_hit_cnt;
  logic [35:0] subheader_ts_hi;
  logic [7:0] last_subhdr_byte;
  logic last_subhdr_valid;
  logic [47:0] last_subhdr_abs_ts;
  logic [47:0] last_nonempty_subhdr_abs_ts;
  logic [15:0] current_frame_pkg_cnt;
  logic [15:0] last_closed_frame_pkg_cnt;
  logic last_closed_frame_valid;
  logic [47:0] last_closed_frame_ts;

  function automatic logic pkt_is_frame_trl(input logic [35:0] word);
    return (word[35:32] == 4'b0001) && (word[7:0] == 8'h9C);
  endfunction

  function automatic logic pkt_is_subhdr(input logic [35:0] word);
    return (word[35:32] == 4'b0001) && (word[7:0] == 8'hF7);
  endfunction

  function automatic logic pkt_is_hit(input logic [35:0] word);
    return (word[35:32] == 4'b0000);
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

  always_ff @(posedge clk) begin
    if (reset) begin
      frame_open                  <= 1'b0;
      hit_words_left              <= '0;
      frame_hdr_aux_words_left    <= '0;
      saw_nonempty_subhdr         <= 1'b0;
      frame_ts_hi32               <= '0;
      frame_ts_lo16               <= '0;
      expected_frame_subhdr_cnt   <= '0;
      expected_frame_hit_cnt      <= '0;
      emitted_frame_subhdr_cnt    <= '0;
      emitted_frame_hit_cnt       <= '0;
      subheader_ts_hi             <= '0;
      last_subhdr_byte            <= '0;
      last_subhdr_valid           <= 1'b0;
      last_subhdr_abs_ts          <= '0;
      last_nonempty_subhdr_abs_ts <= '0;
      current_frame_pkg_cnt       <= '0;
      last_closed_frame_pkg_cnt   <= '0;
      last_closed_frame_valid     <= 1'b0;
      last_closed_frame_ts        <= '0;
    end else if (valid && ready) begin
      if (!frame_open) begin
        frame_open                  <= 1'b1;
        frame_hdr_aux_words_left    <= FRAME_HDR_AUX_WORDS[2:0];
        hit_words_left              <= '0;
        saw_nonempty_subhdr         <= 1'b0;
        frame_ts_hi32               <= '0;
        frame_ts_lo16               <= '0;
        expected_frame_subhdr_cnt   <= '0;
        expected_frame_hit_cnt      <= '0;
        emitted_frame_subhdr_cnt    <= '0;
        emitted_frame_hit_cnt       <= '0;
        subheader_ts_hi             <= '0;
        last_subhdr_byte            <= '0;
        last_subhdr_valid           <= 1'b0;
        last_subhdr_abs_ts          <= '0;
        last_nonempty_subhdr_abs_ts <= '0;
        current_frame_pkg_cnt       <= '0;
      end else if (frame_hdr_aux_words_left != 0) begin
        case (frame_hdr_aux_words_left)
          3'd4: frame_ts_hi32 <= data[31:0];
          3'd3: begin
            frame_ts_lo16   <= data[31:16];
            subheader_ts_hi <= {frame_ts_hi32, data[31:28]};
            current_frame_pkg_cnt <= data[15:0];
            if (last_closed_frame_valid) begin
              // Whole frames can be legally dropped before they ever reach
              // egress, so emitted pkg_cnt must be strictly increasing, not
              // necessarily contiguous.
              assert (data[15:0] > last_closed_frame_pkg_cnt)
                else $error("[opq_hit3_contract] frame pkg_cnt did not increase: prev=%0d new=%0d",
                  last_closed_frame_pkg_cnt, data[15:0]);
              // Multiple emitted frames can legally carry the same frame
              // timestamp when continuous aggregate traffic is split across
              // egress frames. The global order contract is nondecreasing.
              assert ({frame_ts_hi32, data[31:16]} >= last_closed_frame_ts)
                else $error("[opq_hit3_contract] frame timestamp regressed: prev=0x%012h new=0x%012h",
                  last_closed_frame_ts, {frame_ts_hi32, data[31:16]});
            end
          end
          3'd2: begin
            expected_frame_subhdr_cnt <= {1'b0, data[30:16]};
            expected_frame_hit_cnt    <= data[15:0];
          end
          default: begin
          end
        endcase
        frame_hdr_aux_words_left <= frame_hdr_aux_words_left - 1'b1;
      end else if (pkt_is_frame_trl(data)) begin
        assert (hit_words_left == 0)
          else $error("[opq_hit3_contract] frame trailer arrived with %0d hit words still pending", hit_words_left);
        assert (emitted_frame_subhdr_cnt == expected_frame_subhdr_cnt)
          else $error("[opq_hit3_contract] frame trailer sub-header count mismatch: expected=%0d actual=%0d",
            expected_frame_subhdr_cnt, emitted_frame_subhdr_cnt);
        assert (emitted_frame_hit_cnt == expected_frame_hit_cnt)
          else $error("[opq_hit3_contract] frame trailer hit count mismatch: expected=%0d actual=%0d",
            expected_frame_hit_cnt, emitted_frame_hit_cnt);
        frame_open <= 1'b0;
        last_closed_frame_pkg_cnt <= current_frame_pkg_cnt;
        last_closed_frame_ts      <= {frame_ts_hi32, frame_ts_lo16};
        last_closed_frame_valid   <= 1'b1;
      end else if (pkt_is_subhdr(data)) begin
        logic [35:0] subheader_ts_hi_v;
        logic [47:0] subheader_abs_ts_v;

        assert (hit_words_left == 0)
          else $error("[opq_hit3_contract] sub-header arrived before the previous sub-header drained");
        assert (emitted_frame_subhdr_cnt < expected_frame_subhdr_cnt)
          else $error("[opq_hit3_contract] sub-header count exceeded header promise: expected=%0d actual=%0d",
            expected_frame_subhdr_cnt, emitted_frame_subhdr_cnt + 16'd1);

        subheader_ts_hi_v = extend_subheader_ts_hi(
          subheader_ts_hi,
          last_subhdr_valid,
          last_subhdr_byte,
          data[31:24]
        );
        subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, data[31:24]);

        if (last_subhdr_valid) begin
          assert (subheader_abs_ts_v > last_subhdr_abs_ts)
            else $error("[opq_hit3_contract] sub-header absolute ts did not increase: prev=0x%012h new=0x%012h",
              last_subhdr_abs_ts, subheader_abs_ts_v);
        end

        subheader_ts_hi   <= subheader_ts_hi_v;
        last_subhdr_byte  <= data[31:24];
        last_subhdr_valid <= 1'b1;
        last_subhdr_abs_ts <= subheader_abs_ts_v;
        emitted_frame_subhdr_cnt <= emitted_frame_subhdr_cnt + 16'd1;

        if (data[23:8] != 16'h0000) begin
          if (saw_nonempty_subhdr) begin
            assert (subheader_abs_ts_v > last_nonempty_subhdr_abs_ts)
              else $error("[opq_hit3_contract] non-empty sub-header absolute ts did not increase: prev=0x%012h new=0x%012h",
                last_nonempty_subhdr_abs_ts, subheader_abs_ts_v);
          end
          saw_nonempty_subhdr         <= 1'b1;
          last_nonempty_subhdr_abs_ts <= subheader_abs_ts_v;
          hit_words_left              <= data[23:8];
        end
      end else if (pkt_is_hit(data)) begin
        assert (hit_words_left != 0)
          else $error("[opq_hit3_contract] hit word arrived without a pending non-empty sub-header");
        assert (emitted_frame_hit_cnt < expected_frame_hit_cnt)
          else $error("[opq_hit3_contract] hit count exceeded header promise: expected=%0d actual=%0d",
            expected_frame_hit_cnt, emitted_frame_hit_cnt + 16'd1);
        if (hit_words_left != 0) begin
          hit_words_left <= hit_words_left - 16'd1;
        end
        emitted_frame_hit_cnt <= emitted_frame_hit_cnt + 16'd1;
      end
    end
  end

  final begin
    if (hit_words_left != 0) begin
      $error("[opq_hit3_contract] simulation ended with %0d hit words still pending under the active sub-header",
        hit_words_left);
    end
    if (frame_open) begin
      $error("[opq_hit3_contract] simulation ended with an open frame");
    end
    if (!frame_open) begin
      if (emitted_frame_subhdr_cnt != expected_frame_subhdr_cnt) begin
        $error("[opq_hit3_contract] simulation ended with closed frame sub-header mismatch: expected=%0d actual=%0d",
          expected_frame_subhdr_cnt, emitted_frame_subhdr_cnt);
      end
      if (emitted_frame_hit_cnt != expected_frame_hit_cnt) begin
        $error("[opq_hit3_contract] simulation ended with closed frame hit mismatch: expected=%0d actual=%0d",
          expected_frame_hit_cnt, emitted_frame_hit_cnt);
      end
    end
  end
endmodule

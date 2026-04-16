//------------------------------------------------------------------------------
// IP Name   : tb_int_frame_contract_sva
// Description:
//   Passive framed-stream contract checker for tb_int stages C/D/E. Mirrors
//   the active OPQ harness contract: implicit frame start on the first
//   accepted beat, then 4 header words, K237 subheaders, hit payloads, and a
//   K284 trailer. Absolute subheader timestamp is reconstructed across the
//   subheader-byte wrap.
//------------------------------------------------------------------------------
module tb_int_frame_contract_sva #(
  parameter int MAX_ERROR_REPORTS = 16
) (
  input logic clk,
  input logic reset,
  input logic [35:0] data,
  input logic valid,
  input logic ready
);
  localparam int unsigned FRAME_HDR_AUX_WORDS = 4;

  logic frame_open;
  logic [7:0] hit_words_left;
  logic [2:0] frame_hdr_aux_words_left;
  logic saw_nonempty_subhdr;
  logic [31:0] frame_ts_hi32;
  logic [15:0] frame_ts_lo16;
  logic [35:0] subheader_ts_hi;
  logic [7:0] last_subhdr_byte;
  logic last_subhdr_valid;
  logic [47:0] last_nonempty_subhdr_abs_ts;
  int unsigned contract_err_count;
  bit          contract_err_saturated;

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

  task automatic report_contract_error(input string msg);
    begin
      contract_err_count = contract_err_count + 1;
      if (contract_err_count <= MAX_ERROR_REPORTS) begin
        $error("[tb_int_frame_contract] %s", msg);
      end else if (!contract_err_saturated) begin
        contract_err_saturated = 1'b1;
        $error("[tb_int_frame_contract] report limit reached, suppressing further messages");
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (reset) begin
      frame_open                  <= 1'b0;
      hit_words_left              <= '0;
      frame_hdr_aux_words_left    <= '0;
      saw_nonempty_subhdr         <= 1'b0;
      frame_ts_hi32               <= '0;
      frame_ts_lo16               <= '0;
      subheader_ts_hi             <= '0;
      last_subhdr_byte            <= '0;
      last_subhdr_valid           <= 1'b0;
      last_nonempty_subhdr_abs_ts <= '0;
      contract_err_count          <= 0;
      contract_err_saturated      <= 1'b0;
    end else if (valid && ready) begin
      if (!frame_open) begin
        frame_open                  <= 1'b1;
        frame_hdr_aux_words_left    <= FRAME_HDR_AUX_WORDS[2:0];
        hit_words_left              <= '0;
        saw_nonempty_subhdr         <= 1'b0;
        frame_ts_hi32               <= '0;
        frame_ts_lo16               <= '0;
        subheader_ts_hi             <= '0;
        last_subhdr_byte            <= '0;
        last_subhdr_valid           <= 1'b0;
        last_nonempty_subhdr_abs_ts <= '0;
      end else if (frame_hdr_aux_words_left != 0) begin
        case (frame_hdr_aux_words_left)
          3'd4: frame_ts_hi32 <= data[31:0];
          3'd3: begin
            frame_ts_lo16   <= data[31:16];
            subheader_ts_hi <= {frame_ts_hi32, data[31:28]};
          end
          default: begin
          end
        endcase
        frame_hdr_aux_words_left <= frame_hdr_aux_words_left - 1'b1;
      end else if (pkt_is_frame_trl(data)) begin
        if (hit_words_left != 0) begin
          report_contract_error($sformatf(
            "frame trailer arrived with %0d hit words still pending",
            hit_words_left));
        end
        frame_open <= 1'b0;
      end else if (pkt_is_subhdr(data)) begin
        logic [35:0] subheader_ts_hi_v;
        logic [47:0] subheader_abs_ts_v;

        if (hit_words_left != 0) begin
          report_contract_error("sub-header arrived before the previous sub-header drained");
        end

        subheader_ts_hi_v = extend_subheader_ts_hi(
          subheader_ts_hi,
          last_subhdr_valid,
          last_subhdr_byte,
          data[31:24]
        );
        subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, data[31:24]);

        subheader_ts_hi   <= subheader_ts_hi_v;
        last_subhdr_byte  <= data[31:24];
        last_subhdr_valid <= 1'b1;

        if (data[15:8] != 8'h00) begin
          if (saw_nonempty_subhdr) begin
            if (!(subheader_abs_ts_v > last_nonempty_subhdr_abs_ts)) begin
              report_contract_error($sformatf(
                "non-empty sub-header absolute ts did not increase: prev=0x%012h new=0x%012h",
                last_nonempty_subhdr_abs_ts, subheader_abs_ts_v));
            end
          end
          saw_nonempty_subhdr         <= 1'b1;
          last_nonempty_subhdr_abs_ts <= subheader_abs_ts_v;
          hit_words_left              <= data[15:8];
        end
      end else if (pkt_is_hit(data)) begin
        if (hit_words_left == 0) begin
          report_contract_error("hit word arrived without a pending non-empty sub-header");
        end
        if (hit_words_left != 0) begin
          hit_words_left <= hit_words_left - 1'b1;
        end
      end
    end
  end

  final begin
    if (contract_err_count > MAX_ERROR_REPORTS) begin
      $display("[tb_int_frame_contract] suppressed %0d additional errors",
        contract_err_count - MAX_ERROR_REPORTS);
    end
    if (hit_words_left != 0) begin
      $error("[tb_int_frame_contract] simulation ended with %0d hit words still pending under the active sub-header",
        hit_words_left);
    end
    if (frame_open) begin
      $error("[tb_int_frame_contract] simulation ended with an open frame");
    end
  end
endmodule

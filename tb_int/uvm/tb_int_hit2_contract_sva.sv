//------------------------------------------------------------------------------
// IP Name   : tb_int_hit2_contract_sva
// Description:
//   Passive contract checker for the ring_buffer_cam hit_type2 stream.
//   Each accepted packet is a single subheader packet: one K237 subheader beat
//   marked by SOP, followed by the declared number of hit beats, with EOP on
//   the last hit or on the subheader itself for an empty packet.
//------------------------------------------------------------------------------
module tb_int_hit2_contract_sva #(
  parameter int MAX_ERROR_REPORTS = 16
) (
  input logic clk,
  input logic reset,
  input logic [35:0] data,
  input logic valid,
  input logic ready,
  input logic sop,
  input logic eop
);
  localparam logic [7:0] K237 = 8'hF7;

  logic        packet_open;
  logic [7:0]  hit_words_left;
  logic        saw_nonempty_subhdr;
  logic [35:0] subheader_ts_hi;
  logic [7:0]  last_subhdr_byte;
  logic        last_subhdr_valid;
  logic [47:0] last_nonempty_subhdr_abs_ts;

  int unsigned contract_err_count;
  bit          contract_err_saturated;

  function automatic logic pkt_is_subhdr(input logic [35:0] word);
    return (word[35:32] == 4'b0001) && (word[7:0] == K237);
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
        $error("[tb_int_hit2_contract] %s", msg);
      end else if (!contract_err_saturated) begin
        contract_err_saturated = 1'b1;
        $error("[tb_int_hit2_contract] report limit reached, suppressing further messages");
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (reset) begin
      packet_open               <= 1'b0;
      hit_words_left            <= '0;
      saw_nonempty_subhdr       <= 1'b0;
      subheader_ts_hi           <= '0;
      last_subhdr_byte          <= '0;
      last_subhdr_valid         <= 1'b0;
      last_nonempty_subhdr_abs_ts <= '0;
      contract_err_count        <= 0;
      contract_err_saturated    <= 1'b0;
    end else if (valid && ready) begin
      logic [35:0] subheader_ts_hi_v;
      logic [47:0] subheader_abs_ts_v;
      logic [7:0]  hit_words_left_next;

      if (sop) begin
        if (packet_open) begin
          report_contract_error("new subheader packet started before the previous packet closed");
        end
        if (!pkt_is_subhdr(data)) begin
          report_contract_error("SOP asserted on a non-subheader beat");
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
          if (saw_nonempty_subhdr && !(subheader_abs_ts_v > last_nonempty_subhdr_abs_ts)) begin
            report_contract_error($sformatf(
              "non-empty subheader absolute ts did not increase: prev=0x%012h new=0x%012h",
              last_nonempty_subhdr_abs_ts, subheader_abs_ts_v));
          end
          saw_nonempty_subhdr       <= 1'b1;
          last_nonempty_subhdr_abs_ts <= subheader_abs_ts_v;
        end

        hit_words_left_next = data[15:8];
        if (eop) begin
          if (hit_words_left_next != 0) begin
            report_contract_error($sformatf(
              "subheader packet ended on SOP with %0d hits still declared",
              hit_words_left_next));
          end
          packet_open    <= 1'b0;
          hit_words_left <= '0;
        end else begin
          packet_open    <= 1'b1;
          hit_words_left <= hit_words_left_next;
        end
      end else begin
        hit_words_left_next = hit_words_left;

        if (!packet_open) begin
          report_contract_error("beat arrived outside an open hit_type2 packet");
        end
        if (pkt_is_subhdr(data)) begin
          report_contract_error("subheader beat arrived without SOP");
        end
        if (!pkt_is_hit(data)) begin
          report_contract_error("non-hit beat arrived inside a hit_type2 packet");
        end

        if (hit_words_left == 0) begin
          report_contract_error("hit beat arrived without a pending hit count");
        end else begin
          hit_words_left_next = hit_words_left - 1'b1;
        end

        if (eop) begin
          if (hit_words_left_next != 0) begin
            report_contract_error($sformatf(
              "EOP asserted with %0d hit beats still pending in the packet",
              hit_words_left_next));
          end
          packet_open    <= 1'b0;
          hit_words_left <= '0;
        end else begin
          if (hit_words_left_next == 0) begin
            report_contract_error("packet consumed the declared hit count without asserting EOP");
          end
          packet_open    <= packet_open;
          hit_words_left <= hit_words_left_next;
        end
      end
    end
  end

  final begin
    if (contract_err_count > MAX_ERROR_REPORTS) begin
      $display("[tb_int_hit2_contract] suppressed %0d additional errors",
               contract_err_count - MAX_ERROR_REPORTS);
    end
    if (hit_words_left != 0) begin
      $error("[tb_int_hit2_contract] simulation ended with %0d hit beats still pending in the open packet",
        hit_words_left);
    end
    if (packet_open) begin
      $error("[tb_int_hit2_contract] simulation ended with an open hit_type2 packet");
    end
  end
endmodule

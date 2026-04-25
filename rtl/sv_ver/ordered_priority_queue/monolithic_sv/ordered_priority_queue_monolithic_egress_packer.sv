//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_egress_packer
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.4.0
// Date    : 20260424
// Change  : Pack the native 36-bit OPQ symbol stream into 1/2/4/8-symbol
//           Avalon-ST egress beats with a packet-tail empty sideband
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_egress_packer #(
  parameter int unsigned SYMBOL_WIDTH = 36,
  parameter int unsigned OUT_WIDTH = 36,
  parameter int unsigned SYMBOLS_PER_BEAT = OUT_WIDTH / SYMBOL_WIDTH,
  parameter int unsigned EMPTY_WIDTH = (SYMBOLS_PER_BEAT <= 1) ? 1 : $clog2(SYMBOLS_PER_BEAT),
  parameter int unsigned COUNT_WIDTH = $clog2(SYMBOLS_PER_BEAT + 1)
) (
  input  logic [SYMBOL_WIDTH-1:0]      symbol_data_i,
  input  logic                         symbol_valid_i,
  output logic                         symbol_ready_o,
  input  logic                         symbol_startofpacket_i,
  input  logic                         symbol_endofpacket_i,
  input  logic [2:0]                   symbol_error_i,
  output logic [OUT_WIDTH-1:0]         aso_egress_data,
  output logic                         aso_egress_valid,
  input  logic                         aso_egress_ready,
  output logic                         aso_egress_startofpacket,
  output logic                         aso_egress_endofpacket,
  output logic [2:0]                   aso_egress_error,
  output logic [EMPTY_WIDTH-1:0]       aso_egress_empty,
  input  logic                         d_clk,
  input  logic                         d_reset
);
  localparam logic [COUNT_WIDTH-1:0] SYMBOLS_PER_BEAT_COUNT = SYMBOLS_PER_BEAT;
  localparam logic [EMPTY_WIDTH-1:0] SYMBOLS_PER_BEAT_EMPTY = SYMBOLS_PER_BEAT;

  initial begin
    assert (SYMBOL_WIDTH > 0)
      else $fatal(1, "OPQ egress packer SYMBOL_WIDTH must be non-zero");
    assert (OUT_WIDTH >= SYMBOL_WIDTH)
      else $fatal(1, "OPQ egress packer OUT_WIDTH must be at least SYMBOL_WIDTH");
    assert ((OUT_WIDTH % SYMBOL_WIDTH) == 0)
      else $fatal(1, "OPQ egress packer OUT_WIDTH must be an integer symbol multiple");
    assert (SYMBOLS_PER_BEAT == (OUT_WIDTH / SYMBOL_WIDTH))
      else $fatal(1, "OPQ egress packer SYMBOLS_PER_BEAT does not match OUT_WIDTH/SYMBOL_WIDTH");
    assert ((SYMBOLS_PER_BEAT == 1) || (SYMBOLS_PER_BEAT == 2) ||
            (SYMBOLS_PER_BEAT == 4) || (SYMBOLS_PER_BEAT == 8))
      else $fatal(1, "OPQ egress packer supports 1/2/4/8 symbols per egress beat");
  end

  generate
    if (SYMBOLS_PER_BEAT == 1) begin : g_passthrough
      assign symbol_ready_o = aso_egress_ready;
      assign aso_egress_data = symbol_data_i;
      assign aso_egress_valid = symbol_valid_i;
      assign aso_egress_startofpacket = symbol_startofpacket_i;
      assign aso_egress_endofpacket = symbol_endofpacket_i;
      assign aso_egress_error = symbol_error_i;
      assign aso_egress_empty = '0;
    end else begin : g_pack
      logic [OUT_WIDTH-1:0] buf_data_q;
      logic [COUNT_WIDTH-1:0] buf_count_q;
      logic buf_sop_q;
      logic [2:0] buf_error_q;

      logic [OUT_WIDTH-1:0] out_data_q;
      logic out_valid_q;
      logic out_sop_q;
      logic out_eop_q;
      logic [2:0] out_error_q;
      logic [EMPTY_WIDTH-1:0] out_empty_q;

      assign symbol_ready_o = !out_valid_q || aso_egress_ready;
      assign aso_egress_data = out_data_q;
      assign aso_egress_valid = out_valid_q;
      assign aso_egress_startofpacket = out_sop_q;
      assign aso_egress_endofpacket = out_eop_q;
      assign aso_egress_error = out_error_q;
      assign aso_egress_empty = out_empty_q;

      always_ff @(posedge d_clk) begin : proc_pack
        logic [OUT_WIDTH-1:0] data_v;
        logic [COUNT_WIDTH-1:0] count_v;
        logic sop_v;
        logic [2:0] error_v;
        int unsigned write_lsb_v;

        if (d_reset) begin
          buf_data_q <= '0;
          buf_count_q <= '0;
          buf_sop_q <= 1'b0;
          buf_error_q <= '0;
          out_data_q <= '0;
          out_valid_q <= 1'b0;
          out_sop_q <= 1'b0;
          out_eop_q <= 1'b0;
          out_error_q <= '0;
          out_empty_q <= '0;
        end else begin
          if (out_valid_q && aso_egress_ready) begin
            out_valid_q <= 1'b0;
            out_sop_q <= 1'b0;
            out_eop_q <= 1'b0;
            out_error_q <= '0;
            out_empty_q <= '0;
          end

          if (symbol_valid_i && symbol_ready_o) begin
            data_v = buf_data_q;
            count_v = buf_count_q + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
            sop_v = (buf_count_q == '0) ? symbol_startofpacket_i : buf_sop_q;
            error_v = buf_error_q | symbol_error_i;
            write_lsb_v = (SYMBOLS_PER_BEAT - 1 - int'(buf_count_q)) * SYMBOL_WIDTH;
            data_v[write_lsb_v +: SYMBOL_WIDTH] = symbol_data_i;

            if ((count_v == SYMBOLS_PER_BEAT_COUNT) || symbol_endofpacket_i) begin
              out_data_q <= data_v;
              out_valid_q <= 1'b1;
              out_sop_q <= sop_v;
              out_eop_q <= symbol_endofpacket_i;
              out_error_q <= error_v;
              if (symbol_endofpacket_i) begin
                out_empty_q <= SYMBOLS_PER_BEAT_EMPTY - count_v[EMPTY_WIDTH-1:0];
              end else begin
                out_empty_q <= '0;
              end
              buf_data_q <= '0;
              buf_count_q <= '0;
              buf_sop_q <= 1'b0;
              buf_error_q <= '0;
            end else begin
              buf_data_q <= data_v;
              buf_count_q <= count_v;
              buf_sop_q <= sop_v;
              buf_error_q <= error_v;
            end
          end
        end
      end
    end
  endgenerate
endmodule

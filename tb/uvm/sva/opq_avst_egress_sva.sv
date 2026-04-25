module opq_avst_egress_sva #(
  parameter int unsigned DATA_WIDTH = 36,
  parameter int unsigned SYMBOL_WIDTH = 36,
  parameter int unsigned SYMBOLS_PER_BEAT = DATA_WIDTH / SYMBOL_WIDTH,
  parameter int unsigned EMPTY_WIDTH = (SYMBOLS_PER_BEAT <= 1) ? 1 : $clog2(SYMBOLS_PER_BEAT)
) (
  input logic clk,
  input logic reset,
  input logic [DATA_WIDTH-1:0] data,
  input logic valid,
  input logic ready,
  input logic startofpacket,
  input logic endofpacket,
  input logic [2:0] error,
  input logic [EMPTY_WIDTH-1:0] empty
);
  logic packet_open;
  logic [SYMBOL_WIDTH-1:0] first_symbol;
  logic [SYMBOL_WIDTH-1:0] eop_symbol;

  function automatic logic [SYMBOL_WIDTH-1:0] symbol_at(
    input logic [DATA_WIDTH-1:0] beat_data,
    input int unsigned symbol_idx
  );
    int unsigned lsb;

    lsb = (SYMBOLS_PER_BEAT - 1 - symbol_idx) * SYMBOL_WIDTH;
    return beat_data[lsb +: SYMBOL_WIDTH];
  endfunction

  function automatic int unsigned last_valid_symbol(input logic [EMPTY_WIDTH-1:0] empty_count);
    int unsigned empty_v;

    empty_v = int'(empty_count);
    if (empty_v >= SYMBOLS_PER_BEAT) begin
      return 0;
    end
    return SYMBOLS_PER_BEAT - 1 - empty_v;
  endfunction

  always_comb begin
    first_symbol = symbol_at(data, 0);
    eop_symbol = symbol_at(data, last_valid_symbol(empty));
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      packet_open <= 1'b0;
    end else if (valid && ready) begin
      if (startofpacket) begin
        packet_open <= 1'b1;
      end
      if (endofpacket) begin
        packet_open <= 1'b0;
      end
    end
  end

  property p_hold_under_backpressure;
    @(posedge clk) disable iff (reset)
      valid && !ready |=> valid && $stable({data, startofpacket, endofpacket, error, empty});
  endproperty

  property p_sideband_requires_valid;
    @(posedge clk) disable iff (reset)
      (startofpacket || endofpacket) |-> valid;
  endproperty

  property p_empty_requires_eop;
    @(posedge clk) disable iff (reset)
      (empty != '0) |-> (valid && endofpacket);
  endproperty

  property p_empty_in_range;
    @(posedge clk) disable iff (reset)
      valid && endofpacket |-> (int'(empty) < SYMBOLS_PER_BEAT);
  endproperty

  property p_startofpacket_has_preamble;
    @(posedge clk) disable iff (reset)
      valid && startofpacket |-> (first_symbol[35:32] == 4'b0001) &&
                                  (first_symbol[7:0] == 8'hBC);
  endproperty

  property p_endofpacket_has_trailer;
    @(posedge clk) disable iff (reset)
      valid && endofpacket |->
        (eop_symbol[35:32] == 4'b0001) &&
        (eop_symbol[7:0] == 8'h9C);
  endproperty

  property p_no_single_beat_header_trailer_collapse;
    @(posedge clk) disable iff (reset)
      valid |-> !(startofpacket && endofpacket);
  endproperty

  assert property (p_hold_under_backpressure);
  assert property (p_sideband_requires_valid);
  assert property (p_empty_requires_eop);
  assert property (p_empty_in_range);
  assert property (p_startofpacket_has_preamble);
  assert property (p_endofpacket_has_trailer);

  generate
    if (SYMBOLS_PER_BEAT == 1) begin : gen_single_symbol_sva
      assert property (p_no_single_beat_header_trailer_collapse);
    end
  endgenerate
endmodule

module opq_avst_egress_sva (
  input logic clk,
  input logic reset,
  input logic [35:0] data,
  input logic valid,
  input logic ready,
  input logic startofpacket,
  input logic endofpacket,
  input logic [2:0] error
);
  logic packet_open;

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
      valid && !ready |=> valid && $stable({data, startofpacket, endofpacket, error});
  endproperty

  property p_sideband_requires_valid;
    @(posedge clk) disable iff (reset)
      (startofpacket || endofpacket) |-> valid;
  endproperty

  property p_startofpacket_has_preamble;
    @(posedge clk) disable iff (reset)
      valid && startofpacket |-> (data[35:32] == 4'b0001) && (data[7:0] == 8'hBC);
  endproperty

  property p_endofpacket_has_trailer;
    @(posedge clk) disable iff (reset)
      valid && endofpacket |-> (data[35:32] == 4'b0001) && (data[7:0] == 8'h9C);
  endproperty

  property p_no_single_beat_header_trailer_collapse;
    @(posedge clk) disable iff (reset)
      valid |-> !(startofpacket && endofpacket);
  endproperty

  assert property (p_hold_under_backpressure);
  assert property (p_sideband_requires_valid);
  assert property (p_startofpacket_has_preamble);
  assert property (p_endofpacket_has_trailer);
  assert property (p_no_single_beat_header_trailer_collapse);
endmodule

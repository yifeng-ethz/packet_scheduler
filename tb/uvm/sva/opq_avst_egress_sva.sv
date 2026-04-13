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
  property p_hold_under_backpressure;
    @(posedge clk) disable iff (reset)
      valid && !ready |=> valid && $stable({data, startofpacket, endofpacket, error});
  endproperty

  property p_sideband_requires_valid;
    @(posedge clk) disable iff (reset)
      (startofpacket || endofpacket) |-> valid;
  endproperty

  assert property (p_hold_under_backpressure);
  assert property (p_sideband_requires_valid);
endmodule

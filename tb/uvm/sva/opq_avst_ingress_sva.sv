module opq_avst_ingress_sva (
  input logic clk,
  input logic reset,
  input logic [35:0] data,
  input logic [0:0] valid,
  input logic [1:0] channel,
  input logic [0:0] startofpacket,
  input logic [0:0] endofpacket,
  input logic [2:0] error
);
  property p_sideband_requires_valid;
    @(posedge clk) disable iff (reset)
      (startofpacket[0] || endofpacket[0]) |-> valid[0];
  endproperty

  property p_preamble_has_sop;
    @(posedge clk) disable iff (reset)
      valid[0] && (data[35:32] == 4'b0001) && (data[7:0] == 8'hBC) |-> startofpacket[0];
  endproperty

  property p_hit_payload_not_k;
    @(posedge clk) disable iff (reset)
      valid[0] && (data[7:0] != 8'hBC) && (data[7:0] != 8'h9C) && (data[7:0] != 8'hF7) && !startofpacket[0]
        |-> (data[35:32] == 4'b0000);
  endproperty

  assert property (p_sideband_requires_valid);
  assert property (p_preamble_has_sop);
  assert property (p_hit_payload_not_k);
endmodule

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
  logic packet_open;
  logic packet_error_tainted;

  always_ff @(posedge clk) begin
    if (reset) begin
      packet_open <= 1'b0;
      packet_error_tainted <= 1'b0;
    end else if (valid[0]) begin
      if (startofpacket[0]) begin
        packet_open <= 1'b1;
        if (!packet_open || packet_error_tainted || endofpacket[0]) begin
          packet_error_tainted <= (error != '0);
        end
      end
      if (packet_open && (error != '0)) begin
        packet_error_tainted <= 1'b1;
      end
      if (endofpacket[0]) begin
        packet_open <= 1'b0;
        packet_error_tainted <= 1'b0;
      end
    end
  end

  property p_sideband_requires_valid;
    @(posedge clk) disable iff (reset)
      (startofpacket[0] || endofpacket[0]) |-> valid[0];
  endproperty

  property p_startofpacket_has_preamble;
    @(posedge clk) disable iff (reset)
      valid[0] && startofpacket[0] |-> (data[35:32] == 4'b0001) &&
        ((data[7:0] == 8'hBC) || (data[7:0] == 8'hF7));
  endproperty

  property p_preamble_has_sop;
    @(posedge clk) disable iff (reset)
      valid[0] && (data[35:32] == 4'b0001) && (data[7:0] == 8'hBC) |-> startofpacket[0];
  endproperty

  property p_no_nested_startofpacket;
    @(posedge clk) disable iff (reset)
      valid[0] && startofpacket[0] |-> (!packet_open || packet_error_tainted);
  endproperty

  property p_endofpacket_requires_open_packet;
    @(posedge clk) disable iff (reset)
      valid[0] && endofpacket[0] |-> (packet_open || startofpacket[0]
        || ((data[35:32] == 4'b0001) && (data[7:0] == 8'h9C)));
  endproperty

  property p_hit_payload_not_k;
    @(posedge clk) disable iff (reset)
      valid[0] && (data[7:0] != 8'hBC) && (data[7:0] != 8'h9C) && (data[7:0] != 8'hF7) && !startofpacket[0]
        |-> (data[35:32] == 4'b0000);
  endproperty

  assert property (p_sideband_requires_valid);
  assert property (p_startofpacket_has_preamble);
  assert property (p_preamble_has_sop);
  assert property (p_no_nested_startofpacket);
  assert property (p_endofpacket_requires_open_packet);
  assert property (p_hit_payload_not_k);
endmodule

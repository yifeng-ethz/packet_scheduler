module opq_csr_sva (
  input logic        clk,
  input logic        reset,
  input logic [8:0]  address,
  input logic        read,
  input logic        write,
  input logic [31:0] writedata,
  input logic        burstcount,
  input logic        waitrequest,
  input logic        readdatavalid
);
  property p_single_access_kind;
    @(posedge clk) disable iff (reset)
      !(read && write);
  endproperty

  property p_request_stable_under_waitrequest;
    @(posedge clk) disable iff (reset)
      (waitrequest && (read || write))
        |=> $stable({address, writedata, burstcount});
  endproperty

  property p_single_beat_access;
    @(posedge clk) disable iff (reset)
      (read || write) |-> burstcount;
  endproperty

  property p_readdatavalid_without_waitrequest;
    @(posedge clk) disable iff (reset)
      readdatavalid |-> !waitrequest;
  endproperty

  property p_read_has_readdatavalid;
    @(posedge clk) disable iff (reset)
      (read && !waitrequest) |=> readdatavalid;
  endproperty

  assert property (p_single_access_kind);
  assert property (p_request_stable_under_waitrequest);
  assert property (p_single_beat_access);
  assert property (p_readdatavalid_without_waitrequest);
  assert property (p_read_has_readdatavalid);
endmodule

interface opq_ingress_if(input logic clk);
  logic reset;
  logic [35:0] data;
  logic [0:0] valid;
  logic [1:0] channel;
  logic [0:0] startofpacket;
  logic [0:0] endofpacket;
  logic [2:0] error;

  clocking drv_cb @(posedge clk);
    output data, valid, channel, startofpacket, endofpacket, error;
  endclocking

  clocking mon_cb @(posedge clk);
    input reset, data, valid, channel, startofpacket, endofpacket, error;
  endclocking
endinterface

interface opq_egress_if(input logic clk);
  logic reset;
  logic [35:0] data;
  logic valid;
  logic ready;
  logic startofpacket;
  logic endofpacket;
  logic [2:0] error;

  clocking drv_cb @(posedge clk);
    output ready;
    input reset, data, valid, startofpacket, endofpacket, error;
  endclocking

  clocking mon_cb @(posedge clk);
    input reset, data, valid, ready, startofpacket, endofpacket, error;
  endclocking
endinterface

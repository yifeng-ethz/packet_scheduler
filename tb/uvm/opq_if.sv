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

interface opq_csr_if(input logic clk);
  logic reset;
  logic [8:0] address;
  logic read;
  logic write;
  logic [31:0] writedata;
  logic [31:0] readdata;
  logic readdatavalid;
  logic waitrequest;
  logic burstcount;

  clocking drv_cb @(posedge clk);
    output address, read, write, writedata, burstcount;
    input reset, readdata, readdatavalid, waitrequest;
  endclocking

  clocking mon_cb @(posedge clk);
    input reset, address, read, write, writedata, readdata, readdatavalid, waitrequest, burstcount;
  endclocking

  task automatic idle();
    drv_cb.address <= '0;
    drv_cb.read <= 1'b0;
    drv_cb.write <= 1'b0;
    drv_cb.writedata <= '0;
    drv_cb.burstcount <= 1'b0;
  endtask

  task automatic wait_reset_release();
    while (reset) begin
      idle();
      @(drv_cb);
    end
  endtask

  task automatic write32(input logic [8:0] addr, input logic [31:0] data);
    int timeout_cycles;
    wait_reset_release();
    drv_cb.address <= addr;
    drv_cb.writedata <= data;
    drv_cb.burstcount <= 1'b1;
    drv_cb.read <= 1'b0;
    drv_cb.write <= 1'b1;
    timeout_cycles = 0;
    do begin
      @(drv_cb);
      timeout_cycles++;
      if (timeout_cycles > 32) begin
        $fatal(1, "OPQ_CSR_IF CSR write timeout addr=0x%03h", addr);
      end
    end while (drv_cb.waitrequest);
    idle();
  endtask

  task automatic read32(input logic [8:0] addr, output logic [31:0] data);
    int timeout_cycles;
    wait_reset_release();
    drv_cb.address <= addr;
    drv_cb.writedata <= '0;
    drv_cb.burstcount <= 1'b1;
    drv_cb.write <= 1'b0;
    drv_cb.read <= 1'b1;
    timeout_cycles = 0;
    do begin
      @(drv_cb);
      timeout_cycles++;
      if (timeout_cycles > 32) begin
        $fatal(1, "OPQ_CSR_IF CSR read accept timeout addr=0x%03h", addr);
      end
    end while (drv_cb.waitrequest);
    timeout_cycles = 0;
    while (readdatavalid !== 1'b1) begin
      @(drv_cb);
      timeout_cycles++;
      if (timeout_cycles > 32) begin
        $fatal(1, "OPQ_CSR_IF CSR read data timeout addr=0x%03h", addr);
      end
    end
    data = readdata;
    idle();
  endtask
endinterface

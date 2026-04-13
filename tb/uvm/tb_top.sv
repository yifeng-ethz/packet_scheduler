`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import opq_pkg::*;
  import opq_env_pkg::*;

  localparam time CLK_PERIOD = 4ns;

  logic d_clk = 1'b0;
  logic d_reset = 1'b1;

  opq_ingress_if ingress_if [OPQ_N_LANE] (d_clk);
  opq_egress_if egress_if (d_clk);

  always #(CLK_PERIOD/2) d_clk = ~d_clk;

  initial begin
    repeat (4) @(posedge d_clk);
    d_reset = 1'b0;
  end

  genvar i;
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_if_rst
      assign ingress_if[i].reset = d_reset;
    end
  endgenerate
  assign egress_if.reset = d_reset;

  ordered_priority_queue_dut_sv dut (
    .asi_ingress_0_data(ingress_if[0].data),
    .asi_ingress_0_valid(ingress_if[0].valid),
    .asi_ingress_0_channel(ingress_if[0].channel),
    .asi_ingress_0_startofpacket(ingress_if[0].startofpacket),
    .asi_ingress_0_endofpacket(ingress_if[0].endofpacket),
    .asi_ingress_0_error(ingress_if[0].error),
    .asi_ingress_1_data(ingress_if[1].data),
    .asi_ingress_1_valid(ingress_if[1].valid),
    .asi_ingress_1_channel(ingress_if[1].channel),
    .asi_ingress_1_startofpacket(ingress_if[1].startofpacket),
    .asi_ingress_1_endofpacket(ingress_if[1].endofpacket),
    .asi_ingress_1_error(ingress_if[1].error),
    .aso_egress_data(egress_if.data),
    .aso_egress_valid(egress_if.valid),
    .aso_egress_ready(egress_if.ready),
    .aso_egress_startofpacket(egress_if.startofpacket),
    .aso_egress_endofpacket(egress_if.endofpacket),
    .aso_egress_error(egress_if.error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_ingress_sva
      opq_avst_ingress_sva ingress_sva (
        .clk(d_clk),
        .reset(d_reset),
        .data(ingress_if[i].data),
        .valid(ingress_if[i].valid),
        .channel(ingress_if[i].channel),
        .startofpacket(ingress_if[i].startofpacket),
        .endofpacket(ingress_if[i].endofpacket),
        .error(ingress_if[i].error)
      );
    end
  endgenerate

  opq_avst_egress_sva egress_sva (
    .clk(d_clk),
    .reset(d_reset),
    .data(egress_if.data),
    .valid(egress_if.valid),
    .ready(egress_if.ready),
    .startofpacket(egress_if.startofpacket),
    .endofpacket(egress_if.endofpacket),
    .error(egress_if.error)
  );

  initial begin
    uvm_config_db#(virtual opq_ingress_if)::set(null, "*", "ingress_vif_0", ingress_if[0]);
    uvm_config_db#(virtual opq_ingress_if)::set(null, "*", "ingress_vif_1", ingress_if[1]);
    uvm_config_db#(virtual opq_egress_if)::set(null, "*", "egress_vif", egress_if);
    run_test();
  end
endmodule

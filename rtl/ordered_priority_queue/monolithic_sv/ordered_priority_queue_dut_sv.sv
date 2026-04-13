module ordered_priority_queue_dut_sv (
  input  logic [35:0] asi_ingress_0_data,
  input  logic [0:0]  asi_ingress_0_valid,
  input  logic [1:0]  asi_ingress_0_channel,
  input  logic [0:0]  asi_ingress_0_startofpacket,
  input  logic [0:0]  asi_ingress_0_endofpacket,
  input  logic [2:0]  asi_ingress_0_error,
  input  logic [35:0] asi_ingress_1_data,
  input  logic [0:0]  asi_ingress_1_valid,
  input  logic [1:0]  asi_ingress_1_channel,
  input  logic [0:0]  asi_ingress_1_startofpacket,
  input  logic [0:0]  asi_ingress_1_endofpacket,
  input  logic [2:0]  asi_ingress_1_error,
  output logic [35:0] aso_egress_data,
  output logic        aso_egress_valid,
  input  logic        aso_egress_ready,
  output logic        aso_egress_startofpacket,
  output logic        aso_egress_endofpacket,
  output logic [2:0]  aso_egress_error,
  input  logic        d_clk,
  input  logic        d_reset
);
`ifdef OPQ_USE_NATIVE_SV
  logic [1:0][35:0] asi_ingress_data_bus;
  logic [1:0]       asi_ingress_valid_bus;
  logic [1:0][1:0]  asi_ingress_channel_bus;
  logic [1:0]       asi_ingress_startofpacket_bus;
  logic [1:0]       asi_ingress_endofpacket_bus;
  logic [1:0][2:0]  asi_ingress_error_bus;

  assign asi_ingress_data_bus[0] = asi_ingress_0_data;
  assign asi_ingress_data_bus[1] = asi_ingress_1_data;
  assign asi_ingress_valid_bus[0] = asi_ingress_0_valid[0];
  assign asi_ingress_valid_bus[1] = asi_ingress_1_valid[0];
  assign asi_ingress_channel_bus[0] = asi_ingress_0_channel;
  assign asi_ingress_channel_bus[1] = asi_ingress_1_channel;
  assign asi_ingress_startofpacket_bus[0] = asi_ingress_0_startofpacket[0];
  assign asi_ingress_startofpacket_bus[1] = asi_ingress_1_startofpacket[0];
  assign asi_ingress_endofpacket_bus[0] = asi_ingress_0_endofpacket[0];
  assign asi_ingress_endofpacket_bus[1] = asi_ingress_1_endofpacket[0];
  assign asi_ingress_error_bus[0] = asi_ingress_0_error;
  assign asi_ingress_error_bus[1] = asi_ingress_1_error;

  ordered_priority_queue_monolithic_sv u_native (
    .asi_ingress_data(asi_ingress_data_bus),
    .asi_ingress_valid(asi_ingress_valid_bus),
    .asi_ingress_channel(asi_ingress_channel_bus),
    .asi_ingress_startofpacket(asi_ingress_startofpacket_bus),
    .asi_ingress_endofpacket(asi_ingress_endofpacket_bus),
    .asi_ingress_error(asi_ingress_error_bus),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
`else
  ordered_priority_queue_dut u_vhdl (
    .asi_ingress_0_data(asi_ingress_0_data),
    .asi_ingress_0_valid(asi_ingress_0_valid),
    .asi_ingress_0_channel(asi_ingress_0_channel),
    .asi_ingress_0_startofpacket(asi_ingress_0_startofpacket),
    .asi_ingress_0_endofpacket(asi_ingress_0_endofpacket),
    .asi_ingress_0_error(asi_ingress_0_error),
    .asi_ingress_1_data(asi_ingress_1_data),
    .asi_ingress_1_valid(asi_ingress_1_valid),
    .asi_ingress_1_channel(asi_ingress_1_channel),
    .asi_ingress_1_startofpacket(asi_ingress_1_startofpacket),
    .asi_ingress_1_endofpacket(asi_ingress_1_endofpacket),
    .asi_ingress_1_error(asi_ingress_1_error),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
`endif
endmodule

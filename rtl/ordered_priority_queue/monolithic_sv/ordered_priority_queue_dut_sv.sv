//------------------------------------------------------------------------------
// ordered_priority_queue_dut_sv
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.3.11
// Date    : 20260417
// Change  : Extend the native SV DUT wrapper so the FEB-contract UVM harness can drive 2-lane or 4-lane mode
//------------------------------------------------------------------------------

`ifndef OPQ_N_SHD
`define OPQ_N_SHD 256
`endif

`ifndef OPQ_N_LANE
`define OPQ_N_LANE 2
`endif

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
  input  logic [35:0] asi_ingress_2_data,
  input  logic [0:0]  asi_ingress_2_valid,
  input  logic [1:0]  asi_ingress_2_channel,
  input  logic [0:0]  asi_ingress_2_startofpacket,
  input  logic [0:0]  asi_ingress_2_endofpacket,
  input  logic [2:0]  asi_ingress_2_error,
  input  logic [35:0] asi_ingress_3_data,
  input  logic [0:0]  asi_ingress_3_valid,
  input  logic [1:0]  asi_ingress_3_channel,
  input  logic [0:0]  asi_ingress_3_startofpacket,
  input  logic [0:0]  asi_ingress_3_endofpacket,
  input  logic [2:0]  asi_ingress_3_error,
  output logic [35:0] aso_egress_data,
  output logic        aso_egress_valid,
  input  logic        aso_egress_ready,
  output logic        aso_egress_startofpacket,
  output logic        aso_egress_endofpacket,
  output logic [2:0]  aso_egress_error,
  input  logic [8:0]  avs_csr_address,
  input  logic        avs_csr_read,
  input  logic        avs_csr_write,
  input  logic [31:0] avs_csr_writedata,
  output logic [31:0] avs_csr_readdata,
  output logic        avs_csr_readdatavalid,
  output logic        avs_csr_waitrequest,
  input  logic        avs_csr_burstcount,
  input  logic        d_clk,
  input  logic        d_reset
);
`ifdef OPQ_USE_NATIVE_SV
  logic [3:0][35:0] asi_ingress_data_bus;
  logic [3:0]       asi_ingress_valid_bus;
  logic [3:0][1:0]  asi_ingress_channel_bus;
  logic [3:0]       asi_ingress_startofpacket_bus;
  logic [3:0]       asi_ingress_endofpacket_bus;
  logic [3:0][2:0]  asi_ingress_error_bus;

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
  assign asi_ingress_data_bus[2] = asi_ingress_2_data;
  assign asi_ingress_data_bus[3] = asi_ingress_3_data;
  assign asi_ingress_valid_bus[2] = asi_ingress_2_valid[0];
  assign asi_ingress_valid_bus[3] = asi_ingress_3_valid[0];
  assign asi_ingress_channel_bus[2] = asi_ingress_2_channel;
  assign asi_ingress_channel_bus[3] = asi_ingress_3_channel;
  assign asi_ingress_startofpacket_bus[2] = asi_ingress_2_startofpacket[0];
  assign asi_ingress_startofpacket_bus[3] = asi_ingress_3_startofpacket[0];
  assign asi_ingress_endofpacket_bus[2] = asi_ingress_2_endofpacket[0];
  assign asi_ingress_endofpacket_bus[3] = asi_ingress_3_endofpacket[0];
  assign asi_ingress_error_bus[2] = asi_ingress_2_error;
  assign asi_ingress_error_bus[3] = asi_ingress_3_error;

  ordered_priority_queue_monolithic_sv #(
    .N_LANE(`OPQ_N_LANE),
    .N_SHD(`OPQ_N_SHD)
  ) u_native (
    .asi_ingress_data(asi_ingress_data_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_valid(asi_ingress_valid_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_channel(asi_ingress_channel_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_startofpacket(asi_ingress_startofpacket_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_endofpacket(asi_ingress_endofpacket_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_error(asi_ingress_error_bus[`OPQ_N_LANE-1:0]),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  always_comb begin
    avs_csr_readdata = '0;
    avs_csr_readdatavalid = avs_csr_read;
    avs_csr_waitrequest = 1'b0;
  end
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
    .avs_csr_address(avs_csr_address),
    .avs_csr_read(avs_csr_read),
    .avs_csr_write(avs_csr_write),
    .avs_csr_writedata(avs_csr_writedata),
    .avs_csr_readdata(avs_csr_readdata),
    .avs_csr_readdatavalid(avs_csr_readdatavalid),
    .avs_csr_waitrequest(avs_csr_waitrequest),
    .avs_csr_burstcount(avs_csr_burstcount),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
`endif
endmodule

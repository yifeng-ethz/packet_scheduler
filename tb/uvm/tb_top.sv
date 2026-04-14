//------------------------------------------------------------------------------
// IP Name   : tb_top
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.3 - add DRR arbiter SVA for the VHDL monolithic DUT path
// Description:
//   Top-level mixed-language OPQ UVM harness wrapper.
//------------------------------------------------------------------------------
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
  opq_csr_if csr_if (d_clk);
  opq_drop_if #(OPQ_N_LANE) drop_if (d_clk);

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
  assign csr_if.reset = d_reset;
  assign drop_if.reset = d_reset;

`ifndef OPQ_USE_NATIVE_SV
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_tap
      assign drop_if.valid[i] = dut.u_vhdl.u_impl.dbg_drop_valid[i];
      assign drop_if.shd_drop_cnt[i] = drop_if.valid[i] ? 16'd1 : 16'd0;
      assign drop_if.hit_drop_cnt[i] = drop_if.valid[i] ? dut.u_vhdl.u_impl.dbg_drop_hit_cnt[(i*16) +: 16] : 16'd0;
    end
  endgenerate
`else
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_tap_stub
      assign drop_if.valid[i] = 1'b0;
      assign drop_if.shd_drop_cnt[i] = '0;
      assign drop_if.hit_drop_cnt[i] = '0;
    end
  endgenerate
`endif

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
    .avs_csr_address(csr_if.address),
    .avs_csr_read(csr_if.read),
    .avs_csr_write(csr_if.write),
    .avs_csr_writedata(csr_if.writedata),
    .avs_csr_readdata(csr_if.readdata),
    .avs_csr_readdatavalid(csr_if.readdatavalid),
    .avs_csr_waitrequest(csr_if.waitrequest),
    .avs_csr_burstcount(csr_if.burstcount),
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

  opq_csr_sva csr_sva (
    .clk(d_clk),
    .reset(d_reset),
    .address(csr_if.address),
    .read(csr_if.read),
    .write(csr_if.write),
    .writedata(csr_if.writedata),
    .burstcount(csr_if.burstcount),
    .waitrequest(csr_if.waitrequest),
    .readdatavalid(csr_if.readdatavalid)
  );

  opq_hit3_contract_sva hit3_contract_sva (
    .clk(d_clk),
    .reset(d_reset),
    .data(egress_if.data),
    .valid(egress_if.valid),
    .ready(egress_if.ready)
  );

`ifndef OPQ_USE_NATIVE_SV
  opq_drr_sva #(
    .N_LANE(OPQ_N_LANE)
  ) drr_sva (
    .clk(d_clk),
    .reset(d_reset),
    .req_raw(dut.u_vhdl.u_impl.b2p_arb_req),
    .req_eligible(dut.u_vhdl.u_impl.b2p_arb_req_eligible),
    .gnt(dut.u_vhdl.u_impl.b2p_arb_gnt),
    .sel_mask(dut.u_vhdl.u_impl.b2p_arb_sel_mask_dbg),
    .lock_event(dut.u_vhdl.u_impl.b2p_arb_lock_event),
    .defer_event(dut.u_vhdl.u_impl.b2p_arb_defer_event),
    .locked(dut.u_vhdl.u_impl.b2p_arb_locked),
    .pa_write(dut.u_vhdl.u_impl.b2p_arb_pa_write)
  );
`endif

  initial begin
    opq_dut_cfg dut_cfg;

    csr_if.idle();
    dut_cfg = opq_dut_cfg::type_id::create("dut_cfg");
    uvm_config_db#(virtual opq_ingress_if)::set(null, "*", "ingress_vif_0", ingress_if[0]);
    uvm_config_db#(virtual opq_ingress_if)::set(null, "*", "ingress_vif_1", ingress_if[1]);
    uvm_config_db#(virtual opq_egress_if)::set(null, "*", "egress_vif", egress_if);
    uvm_config_db#(virtual opq_csr_if)::set(null, "*", "csr_vif", csr_if);
    uvm_config_db#(virtual opq_drop_if #(OPQ_N_LANE))::set(null, "*", "drop_vif", drop_if);
    uvm_config_db#(opq_dut_cfg)::set(null, "*", "dut_cfg", dut_cfg);
    run_test();
  end
endmodule

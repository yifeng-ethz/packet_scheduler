//------------------------------------------------------------------------------
// IP Name   : tb_top
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.5 - default standalone OPQ UVM signoff to the native monolithic SV DUT
// Description:
//   Top-level OPQ UVM harness wrapper with native monolithic SV as the default signoff target.
//------------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import opq_pkg::*;
  import opq_env_pkg::*;

  logic d_clk = 1'b0;
  logic d_reset = 1'b1;
  time clk_period = 4ns;
  int unsigned clk_period_ns;

  opq_ingress_if ingress_if [OPQ_N_LANE] (d_clk);
  opq_egress_if egress_if (d_clk);
  opq_csr_if csr_if (d_clk);
  opq_drop_if #(OPQ_N_LANE) drop_if (d_clk);

  initial begin
    if ($value$plusargs("TB_CLK_PERIOD_NS=%d", clk_period_ns)) begin
      if (clk_period_ns == 0) begin
        $fatal(1, "TB_CLK_PERIOD_NS must be non-zero");
      end
      clk_period = clk_period_ns * 1ns;
    end

    forever #(clk_period/2) d_clk = ~d_clk;
  end

  initial begin
    repeat (4) @(posedge d_clk);
    d_reset = 1'b0;
  end

  initial begin
    if (OPQ_N_LANE != 2 && OPQ_N_LANE != 4) begin
      $fatal(1, "Unsupported OPQ_N_LANE=%0d in packet_scheduler/tb/uvm", OPQ_N_LANE);
    end
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
  if (OPQ_N_LANE == 2) begin : gen_drop_tap_2lane
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_lane
      assign drop_if.valid[i] = gen_dut_2lane.dut.u_vhdl.u_impl.dbg_drop_valid[i];
      assign drop_if.shd_drop_cnt[i] = drop_if.valid[i] ? 16'd1 : 16'd0;
      assign drop_if.hit_drop_cnt[i] = drop_if.valid[i] ? gen_dut_2lane.dut.u_vhdl.u_impl.dbg_drop_hit_cnt[(i*16) +: 16] : 16'd0;
    end
  end else begin : gen_drop_tap_4lane
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_lane
      assign drop_if.valid[i] = gen_dut_4lane.dut4.u_impl.dbg_drop_valid[i];
      assign drop_if.shd_drop_cnt[i] = drop_if.valid[i] ? 16'd1 : 16'd0;
      assign drop_if.hit_drop_cnt[i] = drop_if.valid[i] ? gen_dut_4lane.dut4.u_impl.dbg_drop_hit_cnt[(i*16) +: 16] : 16'd0;
    end
  end
`else
  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_drop_tap_stub
      assign drop_if.valid[i] = 1'b0;
      assign drop_if.shd_drop_cnt[i] = '0;
      assign drop_if.hit_drop_cnt[i] = '0;
    end
  endgenerate
`endif

  if (OPQ_N_LANE == 2) begin : gen_dut_2lane
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
      .asi_ingress_2_data('0),
      .asi_ingress_2_valid('0),
      .asi_ingress_2_channel('0),
      .asi_ingress_2_startofpacket('0),
      .asi_ingress_2_endofpacket('0),
      .asi_ingress_2_error('0),
      .asi_ingress_3_data('0),
      .asi_ingress_3_valid('0),
      .asi_ingress_3_channel('0),
      .asi_ingress_3_startofpacket('0),
      .asi_ingress_3_endofpacket('0),
      .asi_ingress_3_error('0),
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
  end else begin : gen_dut_4lane
`ifdef OPQ_USE_NATIVE_SV
    ordered_priority_queue_dut_sv dut4 (
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
      .asi_ingress_2_data(ingress_if[2].data),
      .asi_ingress_2_valid(ingress_if[2].valid),
      .asi_ingress_2_channel(ingress_if[2].channel),
      .asi_ingress_2_startofpacket(ingress_if[2].startofpacket),
      .asi_ingress_2_endofpacket(ingress_if[2].endofpacket),
      .asi_ingress_2_error(ingress_if[2].error),
      .asi_ingress_3_data(ingress_if[3].data),
      .asi_ingress_3_valid(ingress_if[3].valid),
      .asi_ingress_3_channel(ingress_if[3].channel),
      .asi_ingress_3_startofpacket(ingress_if[3].startofpacket),
      .asi_ingress_3_endofpacket(ingress_if[3].endofpacket),
      .asi_ingress_3_error(ingress_if[3].error),
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
`else
    ordered_priority_queue_dut4 dut4 (
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
      .asi_ingress_2_data(ingress_if[2].data),
      .asi_ingress_2_valid(ingress_if[2].valid),
      .asi_ingress_2_channel(ingress_if[2].channel),
      .asi_ingress_2_startofpacket(ingress_if[2].startofpacket),
      .asi_ingress_2_endofpacket(ingress_if[2].endofpacket),
      .asi_ingress_2_error(ingress_if[2].error),
      .asi_ingress_3_data(ingress_if[3].data),
      .asi_ingress_3_valid(ingress_if[3].valid),
      .asi_ingress_3_channel(ingress_if[3].channel),
      .asi_ingress_3_startofpacket(ingress_if[3].startofpacket),
      .asi_ingress_3_endofpacket(ingress_if[3].endofpacket),
      .asi_ingress_3_error(ingress_if[3].error),
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
`endif
  end

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
  if (OPQ_N_LANE == 2) begin : gen_drr_sva_2lane
    opq_drr_sva #(
      .N_LANE(OPQ_N_LANE)
    ) drr_sva (
      .clk(d_clk),
      .reset(d_reset),
      .req_raw(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_req),
      .req_eligible(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_req_eligible),
      .gnt(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_gnt),
      .sel_mask(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_sel_mask_dbg),
      .lock_event(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_lock_event),
      .defer_event(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_defer_event),
      .locked(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_locked),
      .pa_write(gen_dut_2lane.dut.u_vhdl.u_impl.b2p_arb_pa_write)
    );
  end else begin : gen_drr_sva_4lane
    opq_drr_sva #(
      .N_LANE(OPQ_N_LANE)
    ) drr_sva (
      .clk(d_clk),
      .reset(d_reset),
      .req_raw(gen_dut_4lane.dut4.u_impl.b2p_arb_req),
      .req_eligible(gen_dut_4lane.dut4.u_impl.b2p_arb_req_eligible),
      .gnt(gen_dut_4lane.dut4.u_impl.b2p_arb_gnt),
      .sel_mask(gen_dut_4lane.dut4.u_impl.b2p_arb_sel_mask_dbg),
      .lock_event(gen_dut_4lane.dut4.u_impl.b2p_arb_lock_event),
      .defer_event(gen_dut_4lane.dut4.u_impl.b2p_arb_defer_event),
      .locked(gen_dut_4lane.dut4.u_impl.b2p_arb_locked),
      .pa_write(gen_dut_4lane.dut4.u_impl.b2p_arb_pa_write)
    );
  end
`endif

  generate
    for (i = 0; i < OPQ_N_LANE; i++) begin : gen_cfg_db
      initial begin
        uvm_config_db#(virtual opq_ingress_if)::set(null, "*", $sformatf("ingress_vif_%0d", i), ingress_if[i]);
      end
    end
  endgenerate

  initial begin
    opq_dut_cfg dut_cfg;

    csr_if.idle();
    dut_cfg = opq_dut_cfg::type_id::create("dut_cfg");
    uvm_config_db#(virtual opq_egress_if)::set(null, "*", "egress_vif", egress_if);
    uvm_config_db#(virtual opq_csr_if)::set(null, "*", "csr_vif", csr_if);
    uvm_config_db#(virtual opq_drop_if #(OPQ_N_LANE))::set(null, "*", "drop_vif", drop_if);
    uvm_config_db#(opq_dut_cfg)::set(null, "*", "dut_cfg", dut_cfg);
    run_test();
  end
endmodule

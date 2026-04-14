class opq_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(opq_virtual_sequencer)

  opq_ingress_sequencer ingress_seqr[OPQ_N_LANE];
  opq_egress_sequencer egress_seqr;

  function new(string name = "opq_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class opq_env extends uvm_env;
  `uvm_component_utils(opq_env)

  virtual opq_ingress_if ingress_vif[OPQ_N_LANE];
  virtual opq_egress_if egress_vif;
  virtual opq_drop_if #(OPQ_N_LANE) drop_vif;

  opq_ingress_agent ingress_agent[OPQ_N_LANE];
  opq_egress_agent egress_agent;
  opq_drop_monitor drop_monitor;
  opq_scoreboard scoreboard;
  opq_coverage coverage;
  opq_virtual_sequencer vseqr;

  function new(string name = "opq_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      if (!uvm_config_db#(virtual opq_ingress_if)::get(this, "", $sformatf("ingress_vif_%0d", i), ingress_vif[i])) begin
        `uvm_fatal(get_type_name(), $sformatf("Missing ingress_vif_%0d", i))
      end
    end
    if (!uvm_config_db#(virtual opq_egress_if)::get(this, "", "egress_vif", egress_vif)) begin
      `uvm_fatal(get_type_name(), "Missing egress_vif")
    end
    if (!uvm_config_db#(virtual opq_drop_if #(OPQ_N_LANE))::get(this, "", "drop_vif", drop_vif)) begin
      `uvm_fatal(get_type_name(), "Missing drop_vif")
    end

    vseqr = opq_virtual_sequencer::type_id::create("vseqr", this);
    scoreboard = opq_scoreboard::type_id::create("scoreboard", this);
    coverage = opq_coverage::type_id::create("coverage", this);
    drop_monitor = opq_drop_monitor::type_id::create("drop_monitor", this);

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      ingress_agent[i] = opq_ingress_agent::type_id::create($sformatf("ingress_agent_%0d", i), this);
      ingress_agent[i].vif = ingress_vif[i];
      ingress_agent[i].lane_id = i;
      ingress_agent[i].is_active = UVM_ACTIVE;
    end

    egress_agent = opq_egress_agent::type_id::create("egress_agent", this);
    egress_agent.vif = egress_vif;
    egress_agent.is_active = UVM_ACTIVE;
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    for (int i = 0; i < OPQ_N_LANE; i++) begin
      ingress_agent[i].drv.frame_ap.connect(scoreboard.frame_imp);
      ingress_agent[i].drv.frame_ap.connect(coverage.frame_imp);
      ingress_agent[i].mon.ap.connect(scoreboard.ingress_imp);
      ingress_agent[i].mon.ap.connect(coverage.ingress_imp);
      vseqr.ingress_seqr[i] = ingress_agent[i].seqr;
    end
    egress_agent.mon.ap.connect(scoreboard.egress_imp);
    egress_agent.mon.ap.connect(coverage.egress_imp);
    egress_agent.drv.bp_ap.connect(coverage.bp_imp);
    drop_monitor.ap.connect(scoreboard.drop_imp);
    vseqr.egress_seqr = egress_agent.seqr;
  endfunction
endclass

class opq_base_test extends uvm_test;
  `uvm_component_utils(opq_base_test)

  opq_env env;
  opq_scoreboard_cfg sb_cfg;

  function new(string name = "opq_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = opq_scoreboard_cfg::type_id::create("sb_cfg");
    return cfg;
  endfunction

  function void build_phase(uvm_phase phase);
    sb_cfg = create_scoreboard_cfg();
    uvm_config_db#(opq_scoreboard_cfg)::set(this, "env.scoreboard", "cfg", sb_cfg);
    super.build_phase(phase);
    env = opq_env::type_id::create("env", this);
  endfunction

  virtual task run_main_sequence();
  endtask

  virtual function time dwell_time();
    return 300us;
  endfunction

  task run_phase(uvm_phase phase);
    time holdoff;

    phase.raise_objection(this);
    run_main_sequence();
    holdoff = dwell_time();
    #(holdoff);
    phase.drop_objection(this);
  endtask
endclass

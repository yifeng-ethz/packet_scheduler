class opq_basic_smoke_test extends opq_base_test;
  `uvm_component_utils(opq_basic_smoke_test)

  function new(string name = "opq_basic_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence seq;
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

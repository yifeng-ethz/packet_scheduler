class opq_basic_smoke_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_smoke_test)

  function new(string name = "opq_basic_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_ts_boundary_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_ts_boundary_test)

  function new(string name = "opq_basic_ts_boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_boundary_ts_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_boundary_ts_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_subheader_shape_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_subheader_shape_test)

  function new(string name = "opq_basic_subheader_shape_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_subheader_shape_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_subheader_shape_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_feb_packet_contract_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_feb_packet_contract_test)

  function new(string name = "opq_basic_feb_packet_contract_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_basic_feb_packet_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_basic_feb_packet_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_rn001_board_shape_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_rn001_board_shape_test)

  function new(string name = "opq_basic_rn001_board_shape_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 2ms;
  endfunction

  virtual task run_main_sequence();
    opq_rn001_board_shape_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_rn001_board_shape_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_rn001_lane2_only_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_rn001_lane2_only_test)

  function new(string name = "opq_basic_rn001_lane2_only_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 2ms;
  endfunction

  virtual task run_main_sequence();
    opq_rn001_board_shape_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_rn001_board_shape_virtual_sequence::type_id::create("seq");
    seq.active_lane = 2;
    seq.single_lane_only = 1'b1;
    seq.start(env.vseqr);
  endtask
endclass

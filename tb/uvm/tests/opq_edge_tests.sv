class opq_edge_placeholder_test extends opq_base_test;
  `uvm_component_utils(opq_edge_placeholder_test)

  function new(string name = "opq_edge_placeholder_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 1us;
  endfunction

  virtual task run_main_sequence();
    `uvm_info(get_type_name(), "Edge-case harness placeholder compiled and ready for case expansion.", UVM_LOW)
  endtask
endclass

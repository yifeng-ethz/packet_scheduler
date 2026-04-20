class opq_prof_stress_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_stress_test)

  function new(string name = "opq_prof_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 700us;
  endfunction

  virtual task run_main_sequence();
    opq_soak_virtual_sequence seq;
    csr_clear_counters();
    fork
      begin
        seq = opq_soak_virtual_sequence::type_id::create("seq");
        seq.frame_count = 6;
        seq.start(env.vseqr);
      end
      begin
        #10us;
        poll_lane_credits(16, 8us);
      end
    join
  endtask
endclass

class opq_prof_long_soak_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_long_soak_test)

  function new(string name = "opq_prof_long_soak_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 1800us;
  endfunction

  virtual task run_main_sequence();
    opq_soak_virtual_sequence seq;
    csr_clear_counters();
    fork
      begin
        seq = opq_soak_virtual_sequence::type_id::create("seq");
        seq.frame_count = 24;
        seq.start(env.vseqr);
      end
      begin
        #20us;
        poll_lane_credits(32, 12us);
      end
    join
  endtask
endclass

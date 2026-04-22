class opq_edge_backpressure_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_backpressure_test)

  function new(string name = "opq_edge_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 500us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.trigger_mode = BP_TRIGGER_FIRST_VALID;
    bp_item.high_cycles = 6;
    bp_item.low_cycles = 4;
    bp_item.repeat_count = 24;
    bp_seq.items.push_back(bp_item);
    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #12us;
        poll_lane_credits(10, 8us);
      end
    join
  endtask
endclass

class opq_edge_always_ready_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_always_ready_test)

  function new(string name = "opq_edge_always_ready_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_ALWAYS_READY;
    bp_item.high_cycles = 32;
    bp_item.low_cycles = 4;
    bp_item.repeat_count = 1;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #10us;
        poll_lane_credits(8, 8us);
      end
    join
  endtask
endclass

class opq_edge_ready_medium_profile_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_ready_medium_profile_test)

  function new(string name = "opq_edge_ready_medium_profile_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 32;
    bp_item.low_cycles = 8;
    bp_item.repeat_count = 12;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #10us;
        poll_lane_credits(8, 8us);
      end
    join
  endtask
endclass

class opq_edge_burst_restart_profile_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_burst_restart_profile_test)

  function new(string name = "opq_edge_burst_restart_profile_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 700us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 4;
    bp_item.low_cycles = 12;
    bp_item.repeat_count = 24;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #14us;
        poll_lane_credits(14, 8us);
      end
    join
  endtask
endclass

class opq_edge_stuck_low_backpressure_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_stuck_low_backpressure_test)

  function new(string name = "opq_edge_stuck_low_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 550us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_ALWAYS_STALL;
    bp_item.trigger_mode = BP_TRIGGER_FIRST_VALID;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 2048;
    bp_item.repeat_count = 1;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #1500ns;
        poll_lane_credits(20, 500ns);
      end
    join
  endtask
endclass

class opq_edge_toggle_backpressure_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_toggle_backpressure_test)

  function new(string name = "opq_edge_toggle_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 600us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 1;
    bp_item.repeat_count = 24;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #12us;
        poll_lane_credits(12, 8us);
      end
    join
  endtask
endclass

class opq_edge_long_toggle_backpressure_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_long_toggle_backpressure_test)

  function new(string name = "opq_edge_long_toggle_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 1;
    bp_item.repeat_count = 96;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #12us;
        poll_lane_credits(24, 10us);
      end
    join
  endtask
endclass

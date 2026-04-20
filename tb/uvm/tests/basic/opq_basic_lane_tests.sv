class opq_basic_single_active_lane_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_single_active_lane_test)

  function new(string name = "opq_basic_single_active_lane_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 350us;
  endfunction

  virtual task run_main_sequence();
    opq_single_lane_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    seq.active_lane = 0;
    seq.frame_count = 4;
    seq.subheaders_per_frame = 4;
    seq.hit_count = 4;
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_single_active_lane_lane1_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_single_active_lane_lane1_test)

  function new(string name = "opq_basic_single_active_lane_lane1_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 400us;
  endfunction

  virtual task run_main_sequence();
    opq_single_lane_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    seq.active_lane = 1;
    seq.frame_count = 6;
    seq.subheaders_per_frame = 6;
    seq.hit_count = 3;
    seq.start(env.vseqr);
  endtask
endclass

class opq_basic_single_active_lane_dense_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_basic_single_active_lane_dense_test)

  function new(string name = "opq_basic_single_active_lane_dense_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 500us;
  endfunction

  virtual task run_main_sequence();
    opq_single_lane_virtual_sequence seq;
    int unsigned subheaders_per_frame;

    csr_clear_counters();
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    subheaders_per_frame = (OPQ_N_SHD >= 16) ? 16 : OPQ_N_SHD;
    if (subheaders_per_frame < 4) begin
      subheaders_per_frame = 4;
    end
    seq.active_lane = 0;
    seq.frame_count = 6;
    seq.subheaders_per_frame = subheaders_per_frame;
    seq.hit_count = 4;
    seq.start(env.vseqr);
  endtask
endclass

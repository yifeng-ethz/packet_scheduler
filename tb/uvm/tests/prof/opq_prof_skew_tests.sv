class opq_prof_lane_skew_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_lane_skew_test)

  function new(string name = "opq_prof_lane_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 650us;
  endfunction

  virtual task run_main_sequence();
    opq_stress_virtual_sequence seq;

    csr_clear_counters();
    fork
      begin
        seq = opq_stress_virtual_sequence::type_id::create("seq");
        seq.frame_count = 8;
        seq.subheaders_per_frame = 6;
        seq.hit_count = 2;
        seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
        seq.lane1_extra_gap_cycles = 32;
        seq.start(env.vseqr);
      end
      begin
        #10us;
        poll_lane_credits(16, 8us);
      end
    join
  endtask
endclass

class opq_prof_heavy_lane_skew_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_heavy_lane_skew_test)

  function new(string name = "opq_prof_heavy_lane_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_stress_virtual_sequence seq;

    csr_clear_counters();
    fork
      begin
        seq = opq_stress_virtual_sequence::type_id::create("seq");
        seq.frame_count = 10;
        seq.subheaders_per_frame = 6;
        seq.hit_count = 2;
        seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
        seq.lane1_extra_gap_cycles = 64;
        seq.start(env.vseqr);
      end
      begin
        #12us;
        poll_lane_credits(20, 10us);
      end
    join
  endtask
endclass

class opq_prof_whole_frame_skew_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_whole_frame_skew_test)

  function new(string name = "opq_prof_whole_frame_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_whole_frame_skew_virtual_sequence seq;

    csr_clear_counters();
    fork
      begin
        seq = opq_whole_frame_skew_virtual_sequence::type_id::create("seq");
        seq.frame_count = 24;
        seq.hit_period = 4;
        seq.hit_count_when_active = 2;
        seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
        seq.start(env.vseqr);
      end
      begin
        #10us;
        poll_lane_credits(24, 10us);
      end
    join
  endtask
endclass

class opq_prof_deep_whole_frame_skew_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_prof_deep_whole_frame_skew_test)

  function new(string name = "opq_prof_deep_whole_frame_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 1300us;
  endfunction

  virtual task run_main_sequence();
    opq_whole_frame_skew_virtual_sequence seq;
    int unsigned subheaders_per_frame;

    csr_clear_counters();
    fork
      begin
        seq = opq_whole_frame_skew_virtual_sequence::type_id::create("seq");
        seq.frame_count = 28;
        subheaders_per_frame = (OPQ_N_SHD >= 128) ? 128 : OPQ_N_SHD;
        if (subheaders_per_frame < 32) begin
          subheaders_per_frame = 32;
        end
        seq.subheaders_per_frame = subheaders_per_frame;
        seq.hit_period = 3;
        seq.hit_count_when_active = 2;
        seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
        seq.start(env.vseqr);
      end
      begin
        #14us;
        poll_lane_credits(28, 10us);
      end
    join
  endtask
endclass

class opq_prof_missing_empty_frame_test extends opq_base_test;
  `uvm_component_utils(opq_prof_missing_empty_frame_test)

  function new(string name = "opq_prof_missing_empty_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = (OPQ_N_LANE >= 4);
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_missing_empty_frame_virtual_sequence seq;

    csr_clear_counters();
    fork
      begin
        seq = opq_missing_empty_frame_virtual_sequence::type_id::create("seq");
        seq.start(env.vseqr);
      end
      begin
        #10us;
        poll_lane_credits(24, 10us);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b0);
      sample_lane_drr_snapshot(lane, -1, 1'b0, 1'b0);
    end
    sample_frame_table_drop_snapshot();
    check_frame_table_counts();
  endtask
endclass

class opq_prof_asymmetric_missing_empty_frame_test extends opq_base_test;
  `uvm_component_utils(opq_prof_asymmetric_missing_empty_frame_test)

  function new(string name = "opq_prof_asymmetric_missing_empty_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = (OPQ_N_LANE >= 4);
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 1100us;
  endfunction

  virtual task run_main_sequence();
    opq_missing_empty_frame_virtual_sequence seq;

    csr_clear_counters();
    fork
      begin
        seq = opq_missing_empty_frame_virtual_sequence::type_id::create("seq");
        seq.lane_frame_count[0] = 4;
        if (OPQ_N_LANE >= 2) begin
          seq.lane_frame_count[1] = 10;
          seq.lane_extra_gap_cycles[1] = 64;
        end
        seq.hit_period = 3;
        seq.hit_count_when_active = 2;
        seq.start(env.vseqr);
      end
      begin
        #12us;
        poll_lane_credits(28, 10us);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b0);
      sample_lane_drr_snapshot(lane, -1, 1'b0, 1'b0);
    end
    sample_frame_table_drop_snapshot();
    check_frame_table_counts();
  endtask
endclass

class opq_prof_stress_test extends opq_base_test;
  `uvm_component_utils(opq_prof_stress_test)

  function new(string name = "opq_prof_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
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

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
  endtask
endclass

class opq_prof_lane_skew_test extends opq_base_test;
  `uvm_component_utils(opq_prof_lane_skew_test)

  function new(string name = "opq_prof_lane_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
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

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
  endtask
endclass

class opq_prof_whole_frame_skew_test extends opq_base_test;
  `uvm_component_utils(opq_prof_whole_frame_skew_test)

  function new(string name = "opq_prof_whole_frame_skew_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
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

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
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

class opq_prof_long_soak_test extends opq_base_test;
  `uvm_component_utils(opq_prof_long_soak_test)

  function new(string name = "opq_prof_long_soak_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
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

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
  endtask
endclass

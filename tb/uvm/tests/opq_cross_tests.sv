//------------------------------------------------------------------------------
// IP Name   : opq_cross_tests
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - align DRR checks to block-level defer semantics and add bursty CRV
// Description:
//   Cross-bucket tests for backpressure, credit, and DRR scheduler interactions.
//------------------------------------------------------------------------------
class opq_cross_bp_credit_test extends opq_base_test;
  `uvm_component_utils(opq_cross_bp_credit_test)

  function new(string name = "opq_cross_bp_credit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_soak_virtual_sequence seq;

    csr_clear_counters();
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 8;
    bp_item.low_cycles = 8;
    bp_item.repeat_count = 40;
    bp_seq.items.push_back(bp_item);

    fork
      begin
        seq = opq_soak_virtual_sequence::type_id::create("seq");
        seq.frame_count = 6;
        seq.start(env.vseqr);
      end
      begin
        #2us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #12us;
        poll_lane_credits(20, 8us);
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

class opq_cross_drr_allowance_test extends opq_base_test;
  `uvm_component_utils(opq_cross_drr_allowance_test)

  function new(string name = "opq_cross_drr_allowance_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_drr_saturation_virtual_sequence seq;

    csr_clear_counters();
    csr_write_lane_drr_allowance(0, 4);
    csr_write_lane_drr_allowance(1, 32);
    seq = opq_drr_saturation_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    int unsigned lane0_allowance;
    int unsigned lane0_quantum;
    int unsigned lane0_grant_cnt;
    int unsigned lane0_beat_cnt;
    int unsigned lane0_defer_cnt;
    int unsigned lane1_allowance;
    int unsigned lane1_quantum;
    int unsigned lane1_grant_cnt;
    int unsigned lane1_beat_cnt;
    int unsigned lane1_defer_cnt;

    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_drop_accounting_and_credit(lane, 1'b0);
    end
    check_frame_table_counts();

    read_lane_drr_snapshot(0, lane0_allowance, lane0_quantum, lane0_grant_cnt, lane0_beat_cnt, lane0_defer_cnt);
    read_lane_drr_snapshot(1, lane1_allowance, lane1_quantum, lane1_grant_cnt, lane1_beat_cnt, lane1_defer_cnt);
    sample_lane_drr_snapshot(0, 4, 1'b1, 1'b1);
    sample_lane_drr_snapshot(1, 32, 1'b1, 1'b0);

    if (lane0_beat_cnt != env.scoreboard.get_accepted_lane_hit_cnt(0)) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane0 DRR beat count mismatch expected=%0d actual=%0d",
        env.scoreboard.get_accepted_lane_hit_cnt(0), lane0_beat_cnt
      ))
    end
    if (lane1_beat_cnt != env.scoreboard.get_accepted_lane_hit_cnt(1)) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane1 DRR beat count mismatch expected=%0d actual=%0d",
        env.scoreboard.get_accepted_lane_hit_cnt(1), lane1_beat_cnt
      ))
    end
    if (lane0_defer_cnt <= lane1_defer_cnt) begin
      `uvm_error(get_type_name(), $sformatf(
        "Expected lane0 defer count to exceed lane1 under tighter DRR allowance, lane0=%0d lane1=%0d",
        lane0_defer_cnt, lane1_defer_cnt
      ))
    end
    if ((lane0_grant_cnt == 0) || (lane1_grant_cnt == 0)) begin
      `uvm_error(get_type_name(), $sformatf(
        "Expected both lanes to receive non-zero DRR grant counts, lane0=%0d lane1=%0d",
        lane0_grant_cnt, lane1_grant_cnt
      ))
    end
  endtask
endclass

class opq_cross_drr_idle_lane_test extends opq_base_test;
  `uvm_component_utils(opq_cross_drr_idle_lane_test)

  function new(string name = "opq_cross_drr_idle_lane_test", uvm_component parent = null);
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
    opq_single_lane_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    seq.active_lane = 0;
    seq.frame_count = 4;
    seq.subheaders_per_frame = 8;
    seq.hit_count = 8;
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    int unsigned allowance_word;
    int unsigned quantum_word;
    int unsigned grant_cnt_word;
    int unsigned beat_cnt_word;
    int unsigned defer_cnt_word;

    super.run_post_sequence_checks();
    check_lane_no_drop_and_credit(0, 1'b0);
    check_lane_no_drop_and_credit(1, 1'b0);
    check_frame_table_counts();

    sample_lane_drr_snapshot(0, OPQ_DRR_DEFAULT_ALLOWANCE, 1'b1, 1'b0);
    read_lane_drr_snapshot(1, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);
    env.coverage.sample_drr_snapshot(1, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);

    if (allowance_word !== OPQ_DRR_DEFAULT_ALLOWANCE) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane allowance mismatch expected=%0d actual=%0d",
        OPQ_DRR_DEFAULT_ALLOWANCE, allowance_word
      ))
    end
    if (grant_cnt_word !== 0 || beat_cnt_word !== 0 || defer_cnt_word !== 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane should not accumulate DRR service counters grant=%0d beat=%0d defer=%0d",
        grant_cnt_word, beat_cnt_word, defer_cnt_word
      ))
    end
    if (quantum_word !== OPQ_DRR_DEFAULT_ALLOWANCE) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane live quantum mismatch expected=%0d actual=%0d",
        OPQ_DRR_DEFAULT_ALLOWANCE, quantum_word
      ))
    end
  endtask
endclass

class opq_cross_drr_zero_allowance_test extends opq_base_test;
  `uvm_component_utils(opq_cross_drr_zero_allowance_test)

  function new(string name = "opq_cross_drr_zero_allowance_test", uvm_component parent = null);
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
    opq_single_lane_virtual_sequence seq;

    csr_clear_counters();
    csr_write_lane_drr_allowance(0, 0);
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    seq.active_lane = 1;
    seq.frame_count = 4;
    seq.subheaders_per_frame = 8;
    seq.hit_count = 8;
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    int unsigned allowance_word;
    int unsigned quantum_word;
    int unsigned grant_cnt_word;
    int unsigned beat_cnt_word;
    int unsigned defer_cnt_word;

    super.run_post_sequence_checks();
    check_lane_no_drop_and_credit(0, 1'b0);
    check_lane_no_drop_and_credit(1, 1'b0);
    check_frame_table_counts();

    read_lane_drr_snapshot(0, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);
    env.coverage.sample_drr_snapshot(0, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);
    if (allowance_word !== 0 || quantum_word !== 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Zero-allowance lane should report allowance=0 quantum=0, actual allowance=%0d quantum=%0d",
        allowance_word, quantum_word
      ))
    end
    if (grant_cnt_word !== 0 || beat_cnt_word !== 0 || defer_cnt_word !== 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Zero-allowance idle lane should not accumulate DRR counters grant=%0d beat=%0d defer=%0d",
        grant_cnt_word, beat_cnt_word, defer_cnt_word
      ))
    end

    sample_lane_drr_snapshot(1, OPQ_DRR_DEFAULT_ALLOWANCE, 1'b1, 1'b0);
  endtask
endclass

class opq_cross_drr_short_allowance_test extends opq_base_test;
  `uvm_component_utils(opq_cross_drr_short_allowance_test)

  function new(string name = "opq_cross_drr_short_allowance_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 900us;
  endfunction

  virtual task run_main_sequence();
    opq_drr_saturation_virtual_sequence seq;

    csr_clear_counters();
    csr_write_lane_drr_allowance(0, 8);
    csr_write_lane_drr_allowance(1, 16);
    seq = opq_drr_saturation_virtual_sequence::type_id::create("seq");
    seq.frame_count = 3;
    seq.subheaders_per_frame = 6;
    seq.hit_count_per_subheader = 24;
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    int unsigned lane0_allowance;
    int unsigned lane0_quantum;
    int unsigned lane0_grant_cnt;
    int unsigned lane0_beat_cnt;
    int unsigned lane0_defer_cnt;
    int unsigned lane1_allowance;
    int unsigned lane1_quantum;
    int unsigned lane1_grant_cnt;
    int unsigned lane1_beat_cnt;
    int unsigned lane1_defer_cnt;

    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_drop_accounting_and_credit(lane, 1'b0);
    end
    check_frame_table_counts();

    read_lane_drr_snapshot(0, lane0_allowance, lane0_quantum, lane0_grant_cnt, lane0_beat_cnt, lane0_defer_cnt);
    read_lane_drr_snapshot(1, lane1_allowance, lane1_quantum, lane1_grant_cnt, lane1_beat_cnt, lane1_defer_cnt);
    env.coverage.sample_drr_snapshot(0, lane0_allowance, lane0_quantum, lane0_grant_cnt, lane0_beat_cnt, lane0_defer_cnt);
    env.coverage.sample_drr_snapshot(1, lane1_allowance, lane1_quantum, lane1_grant_cnt, lane1_beat_cnt, lane1_defer_cnt);

    if (lane0_allowance !== 8 || lane1_allowance !== 16) begin
      `uvm_error(get_type_name(), $sformatf(
        "Short-allowance CSR mismatch lane0=%0d lane1=%0d",
        lane0_allowance, lane1_allowance
      ))
    end
    if ((lane0_grant_cnt == 0) || (lane0_beat_cnt == 0) ||
        (lane1_grant_cnt == 0) || (lane1_beat_cnt == 0)) begin
      `uvm_error(get_type_name(), $sformatf(
        "Expected both short-allowance lanes to receive service lane0 grant=%0d beat=%0d lane1 grant=%0d beat=%0d",
        lane0_grant_cnt, lane0_beat_cnt, lane1_grant_cnt, lane1_beat_cnt
      ))
    end
    if ((lane0_defer_cnt == 0) && (lane1_defer_cnt == 0)) begin
      `uvm_error(get_type_name(), "Expected at least one short-allowance lane to observe DRR defer activity")
    end
  endtask
endclass

class opq_cross_idle_lane_backpressure_test extends opq_base_test;
  `uvm_component_utils(opq_cross_idle_lane_backpressure_test)

  function new(string name = "opq_cross_idle_lane_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 1100us;
  endfunction

  virtual task run_main_sequence();
    opq_single_lane_virtual_sequence seq;
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;

    csr_clear_counters();
    seq = opq_single_lane_virtual_sequence::type_id::create("seq");
    seq.active_lane = 0;
    seq.frame_count = 6;
    seq.subheaders_per_frame = 8;
    seq.hit_count = 8;

    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 8;
    bp_item.low_cycles = 8;
    bp_item.repeat_count = 40;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #2us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #14us;
        poll_lane_credits(24, 8us);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    int unsigned allowance_word;
    int unsigned quantum_word;
    int unsigned grant_cnt_word;
    int unsigned beat_cnt_word;
    int unsigned defer_cnt_word;

    super.run_post_sequence_checks();
    check_lane_no_drop_and_credit(0, 1'b0);
    check_lane_no_drop_and_credit(1, 1'b0);
    check_frame_table_counts();

    sample_lane_drr_snapshot(0, OPQ_DRR_DEFAULT_ALLOWANCE, 1'b1, 1'b0);
    read_lane_drr_snapshot(1, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);
    env.coverage.sample_drr_snapshot(1, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);

    if (allowance_word !== OPQ_DRR_DEFAULT_ALLOWANCE) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane allowance mismatch under backpressure expected=%0d actual=%0d",
        OPQ_DRR_DEFAULT_ALLOWANCE, allowance_word
      ))
    end
    if (grant_cnt_word !== 0 || beat_cnt_word !== 0 || defer_cnt_word !== 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane should not accumulate DRR counters under backpressure grant=%0d beat=%0d defer=%0d",
        grant_cnt_word, beat_cnt_word, defer_cnt_word
      ))
    end
    if (quantum_word !== OPQ_DRR_DEFAULT_ALLOWANCE) begin
      `uvm_error(get_type_name(), $sformatf(
        "Idle lane live quantum mismatch under backpressure expected=%0d actual=%0d",
        OPQ_DRR_DEFAULT_ALLOWANCE, quantum_word
      ))
    end
  endtask
endclass

class opq_cross_drr_bursty_random_test extends opq_base_test;
  `uvm_component_utils(opq_cross_drr_bursty_random_test)

  int unsigned hot_lane;
  int unsigned lane_allowance_cfg[OPQ_N_LANE];

  function new(string name = "opq_cross_drr_bursty_random_test", uvm_component parent = null);
    super.new(name, parent);
    hot_lane = 0;
    foreach (lane_allowance_cfg[i]) begin
      lane_allowance_cfg[i] = OPQ_DRR_DEFAULT_ALLOWANCE;
    end
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 1200us;
  endfunction

  virtual function void configure_bursty_sequence(opq_drr_bursty_random_virtual_sequence seq);
    if (!seq.randomize()) begin
      `uvm_fatal(get_type_name(), "Failed to randomize bursty DRR stress sequence")
    end
  endfunction

  virtual function void configure_bursty_allowance(
    output int unsigned hot_allowance,
    output int unsigned cold_allowance
  );
    if (!std::randomize(hot_allowance, cold_allowance) with {
      hot_allowance inside {[1:8]};
      cold_allowance inside {[16:64]};
      hot_allowance < cold_allowance;
    }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize DRR allowance pair")
    end
  endfunction

  virtual task run_main_sequence();
    opq_drr_bursty_random_virtual_sequence seq;
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    int unsigned hot_allowance;
    int unsigned cold_allowance;

    seq = opq_drr_bursty_random_virtual_sequence::type_id::create("seq");
    configure_bursty_sequence(seq);
    configure_bursty_allowance(hot_allowance, cold_allowance);

    hot_lane = seq.hot_lane;
    lane_allowance_cfg[0] = (hot_lane == 0) ? hot_allowance : cold_allowance;
    lane_allowance_cfg[1] = (hot_lane == 1) ? hot_allowance : cold_allowance;

    csr_clear_counters();
    csr_write_lane_drr_allowance(0, lane_allowance_cfg[0]);
    csr_write_lane_drr_allowance(1, lane_allowance_cfg[1]);

    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 6;
    bp_item.low_cycles = 4;
    bp_item.repeat_count = 48;
    bp_seq.items.push_back(bp_item);

    `uvm_info(get_type_name(), $sformatf(
      "DRR bursty CRV config: hot_lane=%0d lane0_allowance=%0d lane1_allowance=%0d frame_count=%0d subheaders=%0d hot_hits=%0d cold_hits=%0d hot_gap=%0d cold_gap=%0d",
      hot_lane,
      lane_allowance_cfg[0],
      lane_allowance_cfg[1],
      seq.frame_count,
      seq.subheaders_per_frame,
      seq.hot_hits_per_subheader,
      seq.cold_hits_per_subheader,
      seq.hot_gap_cycles,
      seq.cold_gap_cycles
    ), UVM_LOW)

    fork
      begin
        seq.start(env.vseqr);
      end
      begin
        #2us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    int unsigned allowance_word;
    int unsigned quantum_word;
    int unsigned grant_cnt_word;
    int unsigned beat_cnt_word;
    int unsigned defer_cnt_word;
    int unsigned cold_lane;

    super.run_post_sequence_checks();
    cold_lane = (hot_lane == 0) ? 1 : 0;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_drop_accounting_and_credit(lane, 1'b0);
      read_lane_drr_snapshot(
        lane,
        allowance_word,
        quantum_word,
        grant_cnt_word,
        beat_cnt_word,
        defer_cnt_word
      );
      sample_lane_drr_snapshot(lane, lane_allowance_cfg[lane], 1'b1, lane == hot_lane);

      if (beat_cnt_word != env.scoreboard.get_accepted_lane_hit_cnt(lane)) begin
        `uvm_error(get_type_name(), $sformatf(
          "lane%0d DRR beat count mismatch expected=%0d actual=%0d",
          lane,
          env.scoreboard.get_accepted_lane_hit_cnt(lane),
          beat_cnt_word
        ))
      end
    end

    check_frame_table_counts();

    read_lane_drr_snapshot(
      hot_lane,
      allowance_word,
      quantum_word,
      grant_cnt_word,
      beat_cnt_word,
      defer_cnt_word
    );
    if (defer_cnt_word == 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Expected hot lane %0d to accumulate non-zero DRR defer count",
        hot_lane
      ))
    end

    read_lane_drr_snapshot(
      cold_lane,
      allowance_word,
      quantum_word,
      grant_cnt_word,
      beat_cnt_word,
      defer_cnt_word
    );
    if (allowance_word != lane_allowance_cfg[cold_lane]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Cold lane %0d DRR allowance mismatch expected=%0d actual=%0d",
        cold_lane, lane_allowance_cfg[cold_lane], allowance_word
      ))
    end
  endtask
endclass

class opq_cross_drr_bursty_repro_test extends opq_cross_drr_bursty_random_test;
  `uvm_component_utils(opq_cross_drr_bursty_repro_test)

  function new(string name = "opq_cross_drr_bursty_repro_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void configure_bursty_sequence(opq_drr_bursty_random_virtual_sequence seq);
    seq.hot_lane = 0;
    seq.frame_count = 8;
    seq.subheaders_per_frame = 11;
    seq.hot_hits_per_subheader = 46;
    seq.cold_hits_per_subheader = 4;
    seq.hot_gap_cycles = 8;
    seq.cold_gap_cycles = 4032;
  endfunction

  virtual function void configure_bursty_allowance(
    output int unsigned hot_allowance,
    output int unsigned cold_allowance
  );
    hot_allowance = 1;
    cold_allowance = 46;
  endfunction
endclass

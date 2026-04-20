class opq_frame_signoff_base_test extends opq_base_test;
  `uvm_component_utils(opq_frame_signoff_base_test)

  localparam int unsigned TB_REF_CLK_PERIOD_NS = 4;
  localparam int unsigned CREDIT_RESTORE_TIMEOUT_CYCLES = 125_000;
  localparam int unsigned CREDIT_RESTORE_POLL_CYCLES = 125;
  localparam int unsigned INTER_CASE_GAP_CYCLES = 500;
  localparam int unsigned BP_START_DELAY_CYCLES = 250;
  localparam int unsigned MASKED_DROP_HOLDOFF_CYCLES = 1_250;
  localparam int unsigned SIGNOFF_DWELL_CYCLES = 625_000;

  bit [15:0] no_restart_next_pkg_cnt_base[OPQ_N_LANE];
  bit [47:0] no_restart_next_frame_ts_base;

  function new(string name = "opq_frame_signoff_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  function automatic int unsigned tb_clk_period_ns();
    int unsigned clk_period_ns;

    if (!$value$plusargs("TB_CLK_PERIOD_NS=%d", clk_period_ns) || (clk_period_ns == 0)) begin
      clk_period_ns = TB_REF_CLK_PERIOD_NS;
    end
    return clk_period_ns;
  endfunction

  function automatic time tb_clk_period();
    return tb_clk_period_ns() * 1ns;
  endfunction

  function automatic time cycles_to_time(longint unsigned cycle_count);
    return cycle_count * tb_clk_period();
  endfunction

  function automatic int unsigned duration_ns_to_cycles(longint unsigned duration_ns);
    longint unsigned clk_period_ns;

    clk_period_ns = tb_clk_period_ns();
    if (duration_ns == 0) begin
      return 0;
    end
    return int'((duration_ns + clk_period_ns - 1) / clk_period_ns);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(SIGNOFF_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(CREDIT_RESTORE_TIMEOUT_CYCLES);
  endfunction

  virtual function time credit_restore_poll();
    return cycles_to_time(CREDIT_RESTORE_POLL_CYCLES);
  endfunction

  virtual function time inter_case_gap_time();
    return cycles_to_time(INTER_CASE_GAP_CYCLES);
  endfunction

  virtual function time bp_start_delay_time();
    return cycles_to_time(BP_START_DELAY_CYCLES);
  endfunction

  virtual function time masked_drop_holdoff_time();
    return cycles_to_time(MASKED_DROP_HOLDOFF_CYCLES);
  endfunction

  task automatic reset_no_restart_identity();
    no_restart_next_frame_ts_base = '0;
    foreach (no_restart_next_pkg_cnt_base[lane]) begin
      no_restart_next_pkg_cnt_base[lane] = '0;
    end
  endtask

  task automatic configure_no_restart_sequence(opq_virtual_sequence_base seq);
    seq.configure_continuous_frame(no_restart_next_pkg_cnt_base, no_restart_next_frame_ts_base);
    `uvm_info(get_type_name(), $sformatf(
      "No-restart identity for %s: frame_ts_base=0x%012h lane0_pkg_base=%0d lane1_pkg_base=%0d",
      seq.get_name(),
      no_restart_next_frame_ts_base,
      no_restart_next_pkg_cnt_base[0],
      (OPQ_N_LANE > 1) ? no_restart_next_pkg_cnt_base[1] : '0
    ), UVM_LOW)
  endtask

  task automatic advance_no_restart_sequence(opq_virtual_sequence_base seq);
    bit [47:0] frame_duration_cycles;
    int unsigned frame_slots_emitted;
    bit emits_egress_frames;

    frame_duration_cycles = 48'(OPQ_N_SHD * 16);
    frame_slots_emitted = seq.get_continuous_frame_slots_emitted();
    emits_egress_frames = seq.continuous_frame_emits_egress_frames();
    if (emits_egress_frames) begin
      foreach (no_restart_next_pkg_cnt_base[lane]) begin
        no_restart_next_pkg_cnt_base[lane] = seq.get_next_pkg_cnt_base(lane);
      end
      no_restart_next_frame_ts_base = no_restart_next_frame_ts_base +
        (frame_duration_cycles * frame_slots_emitted);
    end
  endtask

  task automatic run_vseq(opq_virtual_sequence_base seq, time inter_case_gap = 0);
    time gap_t;

    gap_t = (inter_case_gap == 0) ? inter_case_gap_time() : inter_case_gap;
    configure_no_restart_sequence(seq);
    `uvm_info(get_type_name(), $sformatf("Starting no-restart case %s", seq.get_name()), UVM_LOW)
    seq.start(env.vseqr);
    wait_for_ingress_idle(
      $sformatf("%s_ingress_idle", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    advance_no_restart_sequence(seq);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    #(gap_t);
  endtask

  task automatic run_basic_with_bp(
    opq_bp_mode_e mode,
    int unsigned high_cycles,
    int unsigned low_cycles,
    int unsigned repeat_count
  );
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_basic_virtual_sequence seq;

    seq = opq_basic_virtual_sequence::type_id::create($sformatf("basic_seq_%0t", $time));
    bp_seq = opq_bp_sequence::type_id::create($sformatf("bp_seq_%0t", $time));
    bp_item = opq_bp_item::type_id::create($sformatf("bp_item_%0t", $time));
    bp_item.mode = mode;
    bp_item.high_cycles = high_cycles;
    bp_item.low_cycles = low_cycles;
    bp_item.repeat_count = repeat_count;
    bp_seq.items.push_back(bp_item);

    configure_no_restart_sequence(seq);
    fork
      seq.start(env.vseqr);
      begin
        #(bp_start_delay_time());
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    wait_for_ingress_idle(
      $sformatf("%s_ingress_idle", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    advance_no_restart_sequence(seq);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    #(inter_case_gap_time());
  endtask

  task automatic run_masked_drop_case(uvm_object_wrapper seq_type);
    opq_virtual_sequence_base seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    $cast(seq, seq_type.create_object($sformatf("masked_seq_%0t", $time)));
    configure_no_restart_sequence(seq);
    `uvm_info(get_type_name(), $sformatf("Starting no-restart case %s", seq.get_name()), UVM_LOW)
    seq.start(env.vseqr);
    advance_no_restart_sequence(seq);
    #(masked_drop_holdoff_time());
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    #(inter_case_gap_time());
  endtask

  task automatic run_masked_drop_recovery_case(string step_name = "masked_recovery");
    opq_masked_drop_virtual_sequence masked_seq;
    opq_basic_virtual_sequence recovery_seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    masked_seq = opq_masked_drop_virtual_sequence::type_id::create({step_name, "_masked_seq"});
    recovery_seq = opq_basic_virtual_sequence::type_id::create({step_name, "_recovery_seq"});
    configure_no_restart_sequence(masked_seq);
    `uvm_info(get_type_name(), $sformatf("Starting no-restart case %s", masked_seq.get_name()), UVM_LOW)
    masked_seq.start(env.vseqr);
    advance_no_restart_sequence(masked_seq);
    #(masked_drop_holdoff_time());
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", masked_seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    run_vseq(recovery_seq);
  endtask

  task automatic run_cross_idle_lane_bp_case(
    string seq_name,
    int unsigned active_lane,
    int unsigned frame_count,
    int unsigned subheaders_per_frame,
    int unsigned hit_count,
    int unsigned high_cycles = 8,
    int unsigned low_cycles = 8,
    int unsigned repeat_count = 40
  );
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_single_lane_virtual_sequence single_lane_seq;

    bp_seq = opq_bp_sequence::type_id::create({seq_name, "_bp_seq"});
    bp_item = opq_bp_item::type_id::create({seq_name, "_bp_item"});
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = high_cycles;
    bp_item.low_cycles = low_cycles;
    bp_item.repeat_count = repeat_count;
    bp_seq.items.push_back(bp_item);

    single_lane_seq = opq_single_lane_virtual_sequence::type_id::create(seq_name);
    single_lane_seq.active_lane = active_lane;
    single_lane_seq.frame_count = frame_count;
    single_lane_seq.subheaders_per_frame = subheaders_per_frame;
    single_lane_seq.hit_count = hit_count;
    configure_no_restart_sequence(single_lane_seq);
    fork
      single_lane_seq.start(env.vseqr);
      begin
        #(inter_case_gap_time());
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    advance_no_restart_sequence(single_lane_seq);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", single_lane_seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    #(inter_case_gap_time());
  endtask

  task automatic run_cross_drr_bp_case(
    string seq_name,
    int unsigned frame_count,
    int unsigned subheaders_per_frame,
    int unsigned hit_count_per_subheader,
    int unsigned high_cycles = 8,
    int unsigned low_cycles = 8,
    int unsigned repeat_count = 32,
    int unsigned lane0_allowance = 8,
    int unsigned lane1_allowance = 16
  );
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_drr_saturation_virtual_sequence drr_seq;

    bp_seq = opq_bp_sequence::type_id::create({seq_name, "_bp_seq"});
    bp_item = opq_bp_item::type_id::create({seq_name, "_bp_item"});
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = high_cycles;
    bp_item.low_cycles = low_cycles;
    bp_item.repeat_count = repeat_count;
    bp_seq.items.push_back(bp_item);

    drr_seq = opq_drr_saturation_virtual_sequence::type_id::create(seq_name);
    drr_seq.frame_count = frame_count;
    drr_seq.subheaders_per_frame = subheaders_per_frame;
    drr_seq.hit_count_per_subheader = hit_count_per_subheader;

    csr_write_lane_drr_allowance(0, lane0_allowance);
    csr_write_lane_drr_allowance(1, lane1_allowance);
    configure_no_restart_sequence(drr_seq);
    fork
      drr_seq.start(env.vseqr);
      begin
        #(inter_case_gap_time());
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    wait_for_ingress_idle(
      $sformatf("%s_ingress_idle", drr_seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    advance_no_restart_sequence(drr_seq);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", drr_seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    csr_write_lane_drr_allowance(0, OPQ_DRR_DEFAULT_ALLOWANCE);
    csr_write_lane_drr_allowance(1, OPQ_DRR_DEFAULT_ALLOWANCE);
    #(inter_case_gap_time());
  endtask

  task automatic run_basic_bucket();
    opq_basic_virtual_sequence basic_seq;
    opq_boundary_ts_virtual_sequence ts_seq;
    opq_basic_feb_packet_virtual_sequence feb_seq;
    opq_subheader_shape_virtual_sequence shd_seq;
    opq_single_lane_virtual_sequence single_lane_seq;

    basic_seq = opq_basic_virtual_sequence::type_id::create("basic_seq");
    ts_seq = opq_boundary_ts_virtual_sequence::type_id::create("ts_seq");
    feb_seq = opq_basic_feb_packet_virtual_sequence::type_id::create("feb_seq");
    shd_seq = opq_subheader_shape_virtual_sequence::type_id::create("shd_seq");
    single_lane_seq = opq_single_lane_virtual_sequence::type_id::create("single_lane_seq");
    single_lane_seq.active_lane = 0;
    single_lane_seq.frame_count = 4;
    single_lane_seq.subheaders_per_frame = 4;
    single_lane_seq.hit_count = 4;

    run_vseq(basic_seq);
    run_vseq(ts_seq);
    run_vseq(feb_seq);
    run_vseq(shd_seq);
    run_vseq(single_lane_seq);
  endtask

  task automatic run_edge_bucket();
    opq_max_hits_virtual_sequence max_hits_seq;

    run_basic_with_bp(BP_PERIODIC_STALL, 6, 4, 24);
    run_basic_with_bp(BP_ALWAYS_READY, 32, 4, 1);
    run_basic_with_bp(BP_PERIODIC_STALL, 32, 8, 12);
    run_basic_with_bp(BP_PERIODIC_STALL, 4, 12, 24);
    run_basic_with_bp(BP_ALWAYS_STALL, 1, 2048, 1);

    max_hits_seq = opq_max_hits_virtual_sequence::type_id::create("max_hits_seq");
    run_vseq(max_hits_seq);

    run_basic_with_bp(BP_PERIODIC_STALL, 1, 1, 24);
  endtask

  task automatic run_prof_bucket();
    opq_soak_virtual_sequence soak_seq;
    opq_stress_virtual_sequence stress_seq;
    opq_whole_frame_skew_virtual_sequence whole_frame_seq;
    opq_missing_empty_frame_virtual_sequence sparse_seq;
    opq_soak_virtual_sequence long_soak_seq;

    soak_seq = opq_soak_virtual_sequence::type_id::create("soak_seq");
    soak_seq.frame_count = 6;
    run_vseq(soak_seq);

    stress_seq = opq_stress_virtual_sequence::type_id::create("stress_seq");
    stress_seq.frame_count = 8;
    stress_seq.subheaders_per_frame = 6;
    stress_seq.hit_count = 2;
    stress_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    stress_seq.lane1_extra_gap_cycles = 32;
    run_vseq(stress_seq);

    whole_frame_seq = opq_whole_frame_skew_virtual_sequence::type_id::create("whole_frame_seq");
    whole_frame_seq.frame_count = 24;
    whole_frame_seq.hit_period = 4;
    whole_frame_seq.hit_count_when_active = 2;
    whole_frame_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(whole_frame_seq);

    sparse_seq = opq_missing_empty_frame_virtual_sequence::type_id::create("sparse_seq");
    run_vseq(sparse_seq);

    long_soak_seq = opq_soak_virtual_sequence::type_id::create("long_soak_seq");
    long_soak_seq.frame_count = 24;
    run_vseq(long_soak_seq);
  endtask

  task automatic run_error_bucket();
    opq_subheader_error_recovery_virtual_sequence shd_recovery_seq;

    run_masked_drop_case(opq_masked_drop_virtual_sequence::get_type());
    run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());
    run_masked_drop_case(opq_burst_masked_drop_virtual_sequence::get_type());
    run_masked_drop_recovery_case("masked_recovery");

    shd_recovery_seq = opq_subheader_error_recovery_virtual_sequence::type_id::create("shd_recovery_seq");
    run_vseq(shd_recovery_seq);
  endtask

  task automatic run_cross_bucket();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_soak_virtual_sequence soak_seq;
    opq_drr_saturation_virtual_sequence drr_seq;
    opq_single_lane_virtual_sequence single_lane_seq;

    bp_seq = opq_bp_sequence::type_id::create("bp_credit_bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_credit_bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 8;
    bp_item.low_cycles = 8;
    bp_item.repeat_count = 40;
    bp_seq.items.push_back(bp_item);
    soak_seq = opq_soak_virtual_sequence::type_id::create("bp_credit_seq");
    soak_seq.frame_count = 6;
    configure_no_restart_sequence(soak_seq);
    fork
      soak_seq.start(env.vseqr);
      begin
        #(inter_case_gap_time());
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    advance_no_restart_sequence(soak_seq);
    wait_for_credit_restore(
      "bp_credit_seq_credit_restore",
      credit_restore_timeout(),
      credit_restore_poll()
    );
    #(inter_case_gap_time());

    csr_write_lane_drr_allowance(0, 4);
    csr_write_lane_drr_allowance(1, 32);
    drr_seq = opq_drr_saturation_virtual_sequence::type_id::create("drr_allow_seq");
    run_vseq(drr_seq);

    single_lane_seq = opq_single_lane_virtual_sequence::type_id::create("idle_lane_seq");
    single_lane_seq.active_lane = 0;
    single_lane_seq.frame_count = 4;
    single_lane_seq.subheaders_per_frame = 8;
    single_lane_seq.hit_count = 8;
    run_vseq(single_lane_seq);

    csr_write_lane_drr_allowance(0, 0);
    csr_write_lane_drr_allowance(1, OPQ_DRR_DEFAULT_ALLOWANCE);
    single_lane_seq = opq_single_lane_virtual_sequence::type_id::create("zero_allow_seq");
    single_lane_seq.active_lane = 1;
    single_lane_seq.frame_count = 4;
    single_lane_seq.subheaders_per_frame = 8;
    single_lane_seq.hit_count = 8;
    run_vseq(single_lane_seq);

    csr_write_lane_drr_allowance(0, 8);
    csr_write_lane_drr_allowance(1, 16);
    drr_seq = opq_drr_saturation_virtual_sequence::type_id::create("drr_short_seq");
    drr_seq.frame_count = 3;
    drr_seq.subheaders_per_frame = 6;
    drr_seq.hit_count_per_subheader = 24;
    run_vseq(drr_seq);

    run_cross_idle_lane_bp_case("idle_lane_bp_case_seq", 0, 6, 8, 8);

    csr_write_lane_drr_allowance(0, OPQ_DRR_DEFAULT_ALLOWANCE);
    csr_write_lane_drr_allowance(1, OPQ_DRR_DEFAULT_ALLOWANCE);
  endtask

  task automatic run_promoted_default_build_matrix();
    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    run_basic_bucket();
    run_edge_bucket();
    run_prof_bucket();
    run_error_bucket();
    run_cross_bucket();
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_drop_accounting_and_credit(lane);
      sample_lane_drr_snapshot(lane, -1, 1'b0, 1'b0);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
  endtask
endclass

class opq_bucket_frame_native_sv_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_bucket_frame_native_sv_test)

  function new(string name = "opq_bucket_frame_native_sv_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    run_promoted_default_build_matrix();
  endtask
endclass

class opq_all_buckets_frame_native_sv_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_all_buckets_frame_native_sv_test)

  function new(string name = "opq_all_buckets_frame_native_sv_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(750_000);
  endfunction

  virtual task run_main_sequence();
    opq_whole_frame_skew_virtual_sequence extra_prof_seq;
    opq_subheader_error_recovery_virtual_sequence extra_err_seq;

    run_promoted_default_build_matrix();

    extra_prof_seq = opq_whole_frame_skew_virtual_sequence::type_id::create("extra_prof_seq");
    extra_prof_seq.frame_count = 12;
    extra_prof_seq.hit_period = 3;
    extra_prof_seq.hit_count_when_active = 2;
    extra_prof_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(extra_prof_seq);

    extra_err_seq = opq_subheader_error_recovery_virtual_sequence::type_id::create("extra_err_seq");
    run_vseq(extra_err_seq);
  endtask
endclass

class opq_cross_mixed_bucket_random_soak_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_mixed_bucket_random_soak_test)

  localparam int unsigned MIXED_SOAK_DWELL_CYCLES = 1_250_000;
  localparam int unsigned MIXED_SOAK_TIMEOUT_CYCLES = 1_250_000;
  localparam int unsigned MIXED_BUCKET_COUNT = 5;
  localparam int unsigned MIXED_ERROR_CASE_COUNT = 4;

  int unsigned soak_iterations;
  int unsigned bucket_visit_count[MIXED_BUCKET_COUNT];
  int unsigned error_case_visit_count[MIXED_ERROR_CASE_COUNT];

  function new(string name = "opq_cross_mixed_bucket_random_soak_test", uvm_component parent = null);
    int unsigned soak_iterations_plusarg;

    super.new(name, parent);
    soak_iterations = 128;
    if ($value$plusargs("OPQ_MIXED_SOAK_STEPS=%d", soak_iterations_plusarg) &&
        (soak_iterations_plusarg > 0)) begin
      soak_iterations = soak_iterations_plusarg;
    end
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(MIXED_SOAK_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(MIXED_SOAK_TIMEOUT_CYCLES);
  endfunction

  function automatic string mixed_bucket_name(int unsigned bucket_idx);
    case (bucket_idx)
      0: return "BASIC";
      1: return "EDGE";
      2: return "PROF";
      3: return "ERROR";
      4: return "CROSS";
      default: return "UNKNOWN";
    endcase
  endfunction

  task automatic run_random_basic_step(int unsigned step_idx);
    int unsigned choice;
    int unsigned active_lane_local;
    int unsigned frame_count_local;
    opq_virtual_sequence_base seq;
    opq_single_lane_virtual_sequence single_lane_seq;

    if (!std::randomize(choice) with { choice inside {[0:1]}; }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize mixed BASIC choice")
    end

    case (choice)
      0: begin
        seq = opq_basic_virtual_sequence::type_id::create($sformatf("mixed_basic_%0d", step_idx));
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed BASIC step %0d case=basic", step_idx),
          UVM_LOW
        )
        run_vseq(seq);
      end
      1: begin
        single_lane_seq =
          opq_single_lane_virtual_sequence::type_id::create($sformatf("mixed_single_lane_%0d", step_idx));
        if (!std::randomize(active_lane_local, frame_count_local) with {
          active_lane_local < OPQ_N_LANE;
          frame_count_local inside {[3:6]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed BASIC single-lane settings")
        end
        single_lane_seq.active_lane = active_lane_local;
        single_lane_seq.frame_count = frame_count_local;
        single_lane_seq.subheaders_per_frame = 4;
        single_lane_seq.hit_count = 4;
        `uvm_info(
          get_type_name(),
          $sformatf(
            "Mixed BASIC step %0d case=single_lane active_lane=%0d frame_count=%0d subheaders=%0d hits=%0d",
            step_idx,
            active_lane_local,
            frame_count_local,
            single_lane_seq.subheaders_per_frame,
            single_lane_seq.hit_count
          ),
          UVM_LOW
        )
        run_vseq(single_lane_seq);
      end
    endcase
  endtask

  task automatic run_random_edge_step(int unsigned step_idx);
    int unsigned choice;
    opq_bp_mode_e bp_mode;
    int unsigned high_cycles;
    int unsigned low_cycles;
    int unsigned repeat_count;
    opq_virtual_sequence_base seq;

    if (!std::randomize(choice) with { choice inside {[0:1]}; }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize mixed EDGE choice")
    end

    case (choice)
      0: begin
        if (!std::randomize(bp_mode, high_cycles, low_cycles, repeat_count) with {
          bp_mode == BP_PERIODIC_STALL;
          high_cycles inside {4, 6, 8, 16, 32};
          low_cycles inside {1, 4, 8, 12, 16};
          repeat_count inside {[12:32]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed EDGE backpressure profile")
        end
        `uvm_info(
          get_type_name(),
          $sformatf(
            "Mixed EDGE step %0d case=basic_bp mode=%0d high=%0d low=%0d repeat=%0d",
            step_idx,
            bp_mode,
            high_cycles,
            low_cycles,
            repeat_count
          ),
          UVM_LOW
        )
        run_basic_with_bp(bp_mode, high_cycles, low_cycles, repeat_count);
      end
      1: begin
        seq = opq_max_hits_virtual_sequence::type_id::create($sformatf("mixed_max_hits_%0d", step_idx));
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed EDGE step %0d case=max_hits", step_idx),
          UVM_LOW
        )
        run_vseq(seq);
      end
    endcase
  endtask

  task automatic run_random_prof_step(int unsigned step_idx);
    int unsigned choice;
    int unsigned soak_frame_count_local;
    int unsigned skew_frame_count_local;
    int unsigned skew_hit_period_local;
    opq_virtual_sequence_base seq;
    opq_soak_virtual_sequence soak_seq;
    opq_whole_frame_skew_virtual_sequence skew_seq;

    if (!std::randomize(choice) with { choice inside {[0:2]}; }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize mixed PROF choice")
    end

    case (choice)
      0: begin
        soak_seq = opq_soak_virtual_sequence::type_id::create($sformatf("mixed_soak_%0d", step_idx));
        if (!std::randomize(soak_frame_count_local) with { soak_frame_count_local inside {[8:20]}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed PROF soak frame count")
        end
        soak_seq.frame_count = soak_frame_count_local;
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed PROF step %0d case=soak frame_count=%0d", step_idx, soak_frame_count_local),
          UVM_LOW
        )
        run_vseq(soak_seq);
      end
      1: begin
        skew_seq =
          opq_whole_frame_skew_virtual_sequence::type_id::create($sformatf("mixed_whole_skew_%0d", step_idx));
        if (!std::randomize(skew_frame_count_local, skew_hit_period_local) with {
          skew_frame_count_local inside {[8:20]};
          skew_hit_period_local inside {[2:5]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed PROF whole-frame skew settings")
        end
        skew_seq.frame_count = skew_frame_count_local;
        skew_seq.hit_period = skew_hit_period_local;
        skew_seq.hit_count_when_active = 2;
        skew_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
        `uvm_info(
          get_type_name(),
          $sformatf(
            "Mixed PROF step %0d case=whole_skew frame_count=%0d hit_period=%0d active_hits=%0d",
            step_idx,
            skew_frame_count_local,
            skew_hit_period_local,
            skew_seq.hit_count_when_active
          ),
          UVM_LOW
        )
        run_vseq(skew_seq);
      end
      2: begin
        seq = opq_missing_empty_frame_virtual_sequence::type_id::create($sformatf("mixed_sparse_%0d", step_idx));
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed PROF step %0d case=sparse_missing_empty", step_idx),
          UVM_LOW
        )
        run_vseq(seq);
      end
    endcase
  endtask

  task automatic run_random_error_step(int unsigned step_idx);
    int unsigned choice;
    int unsigned unseen_error_cases[$];

    for (int unsigned idx = 0; idx < MIXED_ERROR_CASE_COUNT; idx++) begin
      if (error_case_visit_count[idx] == 0) begin
        unseen_error_cases.push_back(idx);
      end
    end

    if (unseen_error_cases.size() != 0) begin
      int unsigned unseen_idx;
      if (!std::randomize(unseen_idx) with { unseen_idx < unseen_error_cases.size(); }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize unseen mixed ERROR choice")
      end
      choice = unseen_error_cases[unseen_idx];
    end else begin
      if (!std::randomize(choice) with { choice < MIXED_ERROR_CASE_COUNT; }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize mixed ERROR choice")
      end
    end

    error_case_visit_count[choice]++;

    case (choice)
      0: begin
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed ERROR step %0d case=masked_drop", step_idx),
          UVM_LOW
        )
        run_masked_drop_case(opq_masked_drop_virtual_sequence::get_type());
      end
      1: begin
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed ERROR step %0d case=single_hit_masked_drop", step_idx),
          UVM_LOW
        )
        run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());
      end
      2: begin
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed ERROR step %0d case=masked_drop_recovery", step_idx),
          UVM_LOW
        )
        run_masked_drop_recovery_case($sformatf("mixed_masked_recovery_%0d", step_idx));
      end
      3: begin
        opq_subheader_error_recovery_virtual_sequence shd_recovery_seq;

        shd_recovery_seq =
          opq_subheader_error_recovery_virtual_sequence::type_id::create(
            $sformatf("mixed_subheader_recovery_%0d", step_idx)
          );
        `uvm_info(
          get_type_name(),
          $sformatf("Mixed ERROR step %0d case=subheader_error_recovery", step_idx),
          UVM_LOW
        )
        run_vseq(shd_recovery_seq);
      end
    endcase
  endtask

  task automatic run_random_cross_step(int unsigned step_idx);
    int unsigned choice;
    int unsigned high_cycles;
    int unsigned low_cycles;
    int unsigned repeat_count;
    int unsigned drr_frame_count_local;
    int unsigned drr_subheaders_local;
    int unsigned drr_hits_local;
    opq_drr_saturation_virtual_sequence drr_seq;

    if (!std::randomize(choice) with { choice inside {[0:1]}; }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize mixed CROSS choice")
    end

    case (choice)
      0: begin
        drr_seq = opq_drr_saturation_virtual_sequence::type_id::create($sformatf("mixed_drr_%0d", step_idx));
        if (!std::randomize(high_cycles, low_cycles, repeat_count) with {
          high_cycles inside {4, 8, 12};
          low_cycles inside {4, 8, 12};
          repeat_count inside {[16:48]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed CROSS DRR backpressure settings")
        end
        if (!std::randomize(drr_frame_count_local, drr_subheaders_local, drr_hits_local) with {
          drr_frame_count_local inside {[3:5]};
          drr_subheaders_local inside {[4:8]};
          drr_hits_local inside {[8:20]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize mixed CROSS DRR saturation settings")
        end
        drr_seq.frame_count = drr_frame_count_local;
        drr_seq.subheaders_per_frame = drr_subheaders_local;
        drr_seq.hit_count_per_subheader = drr_hits_local;
        `uvm_info(
          get_type_name(),
          $sformatf(
            "Mixed CROSS step %0d case=drr_bp frames=%0d subheaders=%0d hits=%0d high=%0d low=%0d repeat=%0d allowance0=%0d allowance1=%0d",
            step_idx,
            drr_frame_count_local,
            drr_subheaders_local,
            drr_hits_local,
            high_cycles,
            low_cycles,
            repeat_count,
            8,
            16
          ),
          UVM_LOW
        )
        csr_write_lane_drr_allowance(0, 8);
        csr_write_lane_drr_allowance(1, 16);
        configure_no_restart_sequence(drr_seq);
        fork
          drr_seq.start(env.vseqr);
          begin
            opq_bp_sequence bp_seq;
            opq_bp_item bp_item;
            bp_seq = opq_bp_sequence::type_id::create($sformatf("mixed_drr_bp_%0d", step_idx));
            bp_item = opq_bp_item::type_id::create($sformatf("mixed_drr_bp_item_%0d", step_idx));
            bp_item.mode = BP_PERIODIC_STALL;
            bp_item.high_cycles = high_cycles;
            bp_item.low_cycles = low_cycles;
            bp_item.repeat_count = repeat_count;
            bp_seq.items.push_back(bp_item);
            #(inter_case_gap_time());
            bp_seq.start(env.vseqr.egress_seqr);
          end
        join
        advance_no_restart_sequence(drr_seq);
        wait_for_credit_restore(
          $sformatf("%s_credit_restore", drr_seq.get_name()),
          credit_restore_timeout(),
          credit_restore_poll()
        );
        csr_write_lane_drr_allowance(0, OPQ_DRR_DEFAULT_ALLOWANCE);
        csr_write_lane_drr_allowance(1, OPQ_DRR_DEFAULT_ALLOWANCE);
        #(inter_case_gap_time());
      end
      1: begin
        `uvm_info(
          get_type_name(),
          $sformatf(
            "Mixed CROSS step %0d case=idle_lane_bp active_lane=%0d frames=%0d subheaders=%0d hits=%0d high=%0d low=%0d repeat=%0d",
            step_idx,
            0,
            6,
            8,
            8,
            8,
            8,
            32
          ),
          UVM_LOW
        )
        run_cross_idle_lane_bp_case($sformatf("mixed_idle_lane_bp_%0d", step_idx), 0, 6, 8, 8, 8, 8, 32);
      end
    endcase
  endtask

  task automatic run_random_mixed_step(int unsigned step_idx);
    int unsigned bucket_idx;
    int unsigned unseen_buckets[$];

    for (int unsigned idx = 0; idx < MIXED_BUCKET_COUNT; idx++) begin
      if (bucket_visit_count[idx] == 0) begin
        unseen_buckets.push_back(idx);
      end
    end

    if (unseen_buckets.size() != 0) begin
      int unsigned unseen_idx;
      if (!std::randomize(unseen_idx) with { unseen_idx < unseen_buckets.size(); }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize unseen mixed-soak bucket index")
      end
      bucket_idx = unseen_buckets[unseen_idx];
    end else begin
      if (!std::randomize(bucket_idx) with { bucket_idx < MIXED_BUCKET_COUNT; }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize mixed-soak bucket index")
      end
    end

    bucket_visit_count[bucket_idx]++;
    `uvm_info(
      get_type_name(),
      $sformatf(
        "Mixed-soak step %0d selected bucket %s visit=%0d",
        step_idx,
        mixed_bucket_name(bucket_idx),
        bucket_visit_count[bucket_idx]
      ),
      UVM_LOW
    )

    case (bucket_idx)
      0: run_random_basic_step(step_idx);
      1: run_random_edge_step(step_idx);
      2: run_random_prof_step(step_idx);
      3: run_random_error_step(step_idx);
      4: run_random_cross_step(step_idx);
      default: `uvm_fatal(get_type_name(), "Invalid mixed-soak bucket selection")
    endcase
  endtask

  virtual task run_main_sequence();
    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    foreach (bucket_visit_count[idx]) begin
      bucket_visit_count[idx] = 0;
    end
    foreach (error_case_visit_count[idx]) begin
      error_case_visit_count[idx] = 0;
    end

    for (int unsigned step_idx = 0; step_idx < soak_iterations; step_idx++) begin
      run_random_mixed_step(step_idx);
    end

    foreach (bucket_visit_count[idx]) begin
      if (bucket_visit_count[idx] == 0) begin
        `uvm_error(
          get_type_name(),
          $sformatf("Mixed-bucket soak never visited bucket %s", mixed_bucket_name(idx))
        )
      end
    end
    foreach (error_case_visit_count[idx]) begin
      if (error_case_visit_count[idx] == 0) begin
        `uvm_error(
          get_type_name(),
          $sformatf("Mixed ERROR soak never visited error subcase %0d", idx)
        )
      end
    end
  endtask
endclass

class opq_cross_mixed_bucket_long_simtime_soak_test extends opq_cross_mixed_bucket_random_soak_test;
  `uvm_component_utils(opq_cross_mixed_bucket_long_simtime_soak_test)

  function new(string name = "opq_cross_mixed_bucket_long_simtime_soak_test", uvm_component parent = null);
    int unsigned soak_iterations_plusarg;

    super.new(name, parent);
    soak_iterations = 256;
    if ($value$plusargs("OPQ_MIXED_SOAK_STEPS=%d", soak_iterations_plusarg) &&
        (soak_iterations_plusarg > 0)) begin
      soak_iterations = soak_iterations_plusarg;
    end
  endfunction
endclass

class opq_cross_mixed_bucket_seconds_soak_test extends opq_cross_mixed_bucket_random_soak_test;
  `uvm_component_utils(opq_cross_mixed_bucket_seconds_soak_test)

  localparam int unsigned SECONDS_SOAK_DWELL_CYCLES = 2_500_000;
  localparam int unsigned SECONDS_SOAK_TIMEOUT_CYCLES = 2_500_000;

  function new(string name = "opq_cross_mixed_bucket_seconds_soak_test", uvm_component parent = null);
    int unsigned soak_iterations_plusarg;

    super.new(name, parent);
    soak_iterations = 512;
    if ($value$plusargs("OPQ_MIXED_SOAK_STEPS=%d", soak_iterations_plusarg) &&
        (soak_iterations_plusarg > 0)) begin
      soak_iterations = soak_iterations_plusarg;
    end
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(SECONDS_SOAK_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(SECONDS_SOAK_TIMEOUT_CYCLES);
  endfunction
endclass

class opq_cross_random_ready_overflow_seconds_soak_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_random_ready_overflow_seconds_soak_test)

  localparam int unsigned OVERFLOW_SOAK_DWELL_CYCLES = 2_500_000;
  localparam int unsigned OVERFLOW_SOAK_TIMEOUT_CYCLES = 2_500_000;

  int unsigned soak_iterations;
  int unsigned bp_segment_count;
  int unsigned overflow_steps_with_ft_drop;
  int unsigned short_bp_segments_seen;
  int unsigned ms_like_bp_segments_seen;
  bit require_ft_drop;
  bit [31:0] last_ft_drop_hdr_total;
  bit [31:0] last_ft_drop_shd_total;
  bit [31:0] last_ft_drop_hit_total;

  function new(string name = "opq_cross_random_ready_overflow_seconds_soak_test", uvm_component parent = null);
    int unsigned soak_iterations_plusarg;
    int unsigned bp_segment_plusarg;
    int unsigned require_ft_drop_plusarg;

    super.new(name, parent);
    soak_iterations = 12;
    bp_segment_count = 48;
    require_ft_drop = 1'b1;
    if ($value$plusargs("OPQ_OVERFLOW_SOAK_STEPS=%d", soak_iterations_plusarg) &&
        (soak_iterations_plusarg > 0)) begin
      soak_iterations = soak_iterations_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_BP_SEGMENTS=%d", bp_segment_plusarg) &&
        (bp_segment_plusarg > 0)) begin
      bp_segment_count = bp_segment_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_REQUIRE_FT_DROP=%d", require_ft_drop_plusarg)) begin
      require_ft_drop = (require_ft_drop_plusarg != 0);
    end
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;

    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.min_sop_count = 1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(OVERFLOW_SOAK_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(OVERFLOW_SOAK_TIMEOUT_CYCLES);
  endfunction

  virtual function int unsigned default_min_hit_percent();
    return 1;
  endfunction

  virtual function int unsigned default_max_hit_percent();
    return 80;
  endfunction

  virtual function int unsigned default_hot_lane_min_hit_percent();
    return 60;
  endfunction

  virtual function int unsigned default_hot_lane_count_min();
    return 1;
  endfunction

  virtual function int unsigned default_hot_lane_count_max();
    return (OPQ_N_LANE >= 2) ? 2 : 1;
  endfunction

  virtual function string soak_label();
    return "overflow";
  endfunction

  virtual function time target_run_time();
    return 0;
  endfunction

  task automatic append_bp_item(
    ref opq_bp_sequence bp_seq,
    input string item_name,
    input opq_bp_mode_e mode,
    input int unsigned high_cycles,
    input int unsigned low_cycles,
    input int unsigned repeat_count
  );
    opq_bp_item bp_item;

    bp_item = opq_bp_item::type_id::create(item_name);
    bp_item.mode = mode;
    bp_item.high_cycles = high_cycles;
    bp_item.low_cycles = low_cycles;
    bp_item.repeat_count = repeat_count;
    bp_seq.items.push_back(bp_item);
  endtask

  task automatic append_bp_item_ns(
    ref opq_bp_sequence bp_seq,
    input string item_name,
    input opq_bp_mode_e mode,
    input longint unsigned high_ns,
    input longint unsigned low_ns,
    input int unsigned repeat_count
  );
    append_bp_item(
      bp_seq,
      item_name,
      mode,
      duration_ns_to_cycles(high_ns),
      duration_ns_to_cycles(low_ns),
      repeat_count
    );
  endtask

  task automatic build_random_ready_gate_sequence(ref opq_bp_sequence bp_seq, int unsigned step_idx);
    int unsigned seg_idx;

    seg_idx = 0;

    if (bp_segment_count > 0) begin
      int unsigned high_cycles;
      int unsigned low_cycles;
      int unsigned repeat_count;

      if (!std::randomize(high_cycles, low_cycles, repeat_count) with {
        high_cycles inside {1, 2, 4, 8};
        low_cycles inside {1, 2, 4, 8};
        repeat_count inside {[8:32]};
      }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize mandatory short periodic stall segment")
      end
      append_bp_item(
        bp_seq,
        $sformatf("bp_periodic_short_forced_%0d", step_idx),
        BP_PERIODIC_STALL,
        high_cycles,
        low_cycles,
        repeat_count
      );
      short_bp_segments_seen++;
      seg_idx++;
    end

    if (bp_segment_count > 1) begin
      longint unsigned high_ns;
      longint unsigned low_ns;

      if (!std::randomize(high_ns, low_ns) with {
        high_ns inside {10_000, 50_000, 100_000, 250_000};
        low_ns inside {250_000, 500_000, 1_000_000, 2_000_000};
      }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize mandatory ms-like backpressure segment")
      end
      append_bp_item_ns(
        bp_seq,
        $sformatf("bp_periodic_ms_forced_%0d", step_idx),
        BP_PERIODIC_STALL,
        high_ns,
        low_ns,
        1
      );
      ms_like_bp_segments_seen++;
      seg_idx++;
    end

    for (; seg_idx < bp_segment_count; seg_idx++) begin
      int unsigned pattern_pick;

      if (!std::randomize(pattern_pick) with { pattern_pick inside {[0:99]}; }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize overflow backpressure pattern")
      end

      if (pattern_pick < 18) begin
        int unsigned ready_cycles;
        if (!std::randomize(ready_cycles) with { ready_cycles inside {1, 2, 4, 8, 16, 32}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize short ready segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_ready_short_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_READY,
          ready_cycles,
          1,
          1
        );
      end else if (pattern_pick < 35) begin
        int unsigned high_cycles;
        int unsigned low_cycles;
        int unsigned repeat_count;
        if (!std::randomize(high_cycles, low_cycles, repeat_count) with {
          high_cycles inside {1, 2, 4, 8};
          low_cycles inside {1, 2, 4, 8};
          repeat_count inside {[8:32]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize short periodic stall segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_periodic_short_%0d_%0d", step_idx, seg_idx),
          BP_PERIODIC_STALL,
          high_cycles,
          low_cycles,
          repeat_count
        );
        short_bp_segments_seen++;
      end else if (pattern_pick < 52) begin
        int unsigned high_cycles;
        int unsigned low_cycles;
        int unsigned repeat_count;
        if (!std::randomize(high_cycles, low_cycles, repeat_count) with {
          high_cycles inside {4, 8, 16, 32};
          low_cycles inside {16, 32, 64, 128};
          repeat_count inside {[4:16]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize medium periodic stall segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_periodic_medium_%0d_%0d", step_idx, seg_idx),
          BP_PERIODIC_STALL,
          high_cycles,
          low_cycles,
          repeat_count
        );
      end else if (pattern_pick < 62) begin
        int unsigned low_cycles;
        if (!std::randomize(low_cycles) with { low_cycles inside {1, 2, 4, 8, 16, 32}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize short stall segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_stall_short_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_STALL,
          1,
          low_cycles,
          1
        );
        short_bp_segments_seen++;
      end else if (pattern_pick < 72) begin
        int unsigned low_cycles;
        if (!std::randomize(low_cycles) with { low_cycles inside {128, 256, 512, 1024}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize long stall segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_stall_long_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_STALL,
          1,
          low_cycles,
          1
        );
      end else if (pattern_pick < 80) begin
        int unsigned ready_cycles;
        if (!std::randomize(ready_cycles) with { ready_cycles inside {64, 128, 256, 512}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize long ready segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_ready_long_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_READY,
          ready_cycles,
          1,
          1
        );
      end else if (pattern_pick < 88) begin
        int unsigned high_cycles;
        int unsigned low_cycles;
        int unsigned repeat_count;
        if (!std::randomize(high_cycles, low_cycles, repeat_count) with {
          high_cycles inside {8, 16, 32, 64};
          low_cycles inside {256, 512, 1024, 2048};
          repeat_count inside {[2:8]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize extended periodic stall segment")
        end
        append_bp_item(
          bp_seq,
          $sformatf("bp_periodic_long_%0d_%0d", step_idx, seg_idx),
          BP_PERIODIC_STALL,
          high_cycles,
          low_cycles,
          repeat_count
        );
      end else if (pattern_pick < 95) begin
        longint unsigned low_ns;
        if (!std::randomize(low_ns) with { low_ns inside {1_000, 10_000, 100_000}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize microsecond-scale stall segment")
        end
        append_bp_item_ns(
          bp_seq,
          $sformatf("bp_stall_us_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_STALL,
          1,
          low_ns,
          1
        );
      end else if (pattern_pick < 98) begin
        longint unsigned low_ns;
        if (!std::randomize(low_ns) with {
          low_ns inside {250_000, 500_000, 1_000_000, 2_000_000};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize ms-like stall segment")
        end
        append_bp_item_ns(
          bp_seq,
          $sformatf("bp_stall_ms_%0d_%0d", step_idx, seg_idx),
          BP_ALWAYS_STALL,
          1,
          low_ns,
          1
        );
        ms_like_bp_segments_seen++;
      end else begin
        longint unsigned high_ns;
        longint unsigned low_ns;
        int unsigned repeat_count;
        if (!std::randomize(high_ns, low_ns, repeat_count) with {
          high_ns inside {250, 1_000, 10_000, 50_000};
          low_ns inside {50_000, 100_000, 250_000, 500_000};
          repeat_count inside {[1:4]};
        }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize ms-like periodic stall segment")
        end
        append_bp_item_ns(
          bp_seq,
          $sformatf("bp_periodic_ms_%0d_%0d", step_idx, seg_idx),
          BP_PERIODIC_STALL,
          high_ns,
          low_ns,
          repeat_count
        );
        ms_like_bp_segments_seen++;
      end
    end
  endtask

  task automatic sample_frame_table_drop_totals(
    output bit [31:0] ft_drop_hdr_word,
    output bit [31:0] ft_drop_shd_word,
    output bit [31:0] ft_drop_hit_word
  );
    csr_read32(OPQ_CSR_WORD_FT_DROP_HDR, ft_drop_hdr_word);
    csr_read32(OPQ_CSR_WORD_FT_DROP_SHD, ft_drop_shd_word);
    csr_read32(OPQ_CSR_WORD_FT_DROP_HIT, ft_drop_hit_word);
    env.coverage.sample_drop_snapshot(
      opq_coverage::DROP_DOMAIN_FTABLE,
      -1,
      ft_drop_hdr_word,
      ft_drop_shd_word,
      ft_drop_hit_word
    );
  endtask

  task automatic update_ftable_drop_progress(int unsigned step_idx);
    bit [31:0] ft_drop_hdr_word;
    bit [31:0] ft_drop_shd_word;
    bit [31:0] ft_drop_hit_word;

    sample_frame_table_drop_totals(ft_drop_hdr_word, ft_drop_shd_word, ft_drop_hit_word);
    if ((ft_drop_hdr_word > last_ft_drop_hdr_total) ||
        (ft_drop_shd_word > last_ft_drop_shd_total) ||
        (ft_drop_hit_word > last_ft_drop_hit_total)) begin
      overflow_steps_with_ft_drop++;
    end
    last_ft_drop_hdr_total = ft_drop_hdr_word;
    last_ft_drop_shd_total = ft_drop_shd_word;
    last_ft_drop_hit_total = ft_drop_hit_word;

    `uvm_info(
      get_type_name(),
      $sformatf(
        "%s soak step %0d cumulative ft_drop_hdr=%0d ft_drop_shd=%0d ft_drop_hit=%0d steps_with_ft_drop=%0d",
        soak_label(),
        step_idx,
        ft_drop_hdr_word,
        ft_drop_shd_word,
        ft_drop_hit_word,
        overflow_steps_with_ft_drop
      ),
      UVM_LOW
    )
  endtask

  task automatic run_random_ready_overflow_step(int unsigned step_idx);
    opq_variable_saturation_overflow_virtual_sequence seq;
    opq_bp_sequence bp_seq;
    int unsigned frame_count_local;
    int unsigned inter_frame_gap_cycles_local;
    int unsigned subheaders_per_frame_plusarg;
    int unsigned frame_count_plusarg;
    int unsigned gap_cycles_plusarg;
    int unsigned hot_lane_count_plusarg;
    int unsigned min_hit_percent_plusarg;
    int unsigned max_hit_percent_plusarg;
    int unsigned hot_lane_min_hit_percent_plusarg;

    seq = opq_variable_saturation_overflow_virtual_sequence::type_id::create($sformatf("overflow_seq_%0d", step_idx));
    bp_seq = opq_bp_sequence::type_id::create($sformatf("overflow_bp_seq_%0d", step_idx));

    if (!std::randomize(frame_count_local, inter_frame_gap_cycles_local) with {
      frame_count_local inside {[2:4]};
      inter_frame_gap_cycles_local inside {0, 1, 2, 4};
    }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize overflow step density")
    end

    seq.frame_count = frame_count_local;
    seq.subheaders_per_frame = (OPQ_N_SHD >= 128) ? 128 : OPQ_N_SHD;
    seq.min_hit_percent = default_min_hit_percent();
    seq.max_hit_percent = default_max_hit_percent();
    seq.hot_lane_min_hit_percent = default_hot_lane_min_hit_percent();
    seq.hot_lane_count_min = default_hot_lane_count_min();
    seq.hot_lane_count_max = default_hot_lane_count_max();
    seq.inter_frame_gap_cycles = inter_frame_gap_cycles_local;
    if ($value$plusargs("OPQ_OVERFLOW_SUBHEADERS_PER_FRAME=%d", subheaders_per_frame_plusarg) &&
        (subheaders_per_frame_plusarg > 0) &&
        (subheaders_per_frame_plusarg <= OPQ_N_SHD)) begin
      seq.subheaders_per_frame = subheaders_per_frame_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_FRAMES_PER_STEP=%d", frame_count_plusarg) &&
        (frame_count_plusarg > 0)) begin
      seq.frame_count = frame_count_plusarg;
      frame_count_local = frame_count_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_GAP_CYCLES=%d", gap_cycles_plusarg)) begin
      seq.inter_frame_gap_cycles = gap_cycles_plusarg;
      inter_frame_gap_cycles_local = gap_cycles_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_HOT_LANES=%d", hot_lane_count_plusarg) &&
        (hot_lane_count_plusarg > 0) &&
        (hot_lane_count_plusarg <= OPQ_N_LANE)) begin
      seq.hot_lane_count_min = hot_lane_count_plusarg;
      seq.hot_lane_count_max = hot_lane_count_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_MIN_HIT_PERCENT=%d", min_hit_percent_plusarg) &&
        (min_hit_percent_plusarg <= 100)) begin
      seq.min_hit_percent = min_hit_percent_plusarg;
    end
    if ((seq.max_hit_percent < seq.min_hit_percent) ||
        (seq.hot_lane_min_hit_percent < seq.min_hit_percent)) begin
      `uvm_fatal(get_type_name(), $sformatf(
        "Invalid saturation defaults min=%0d max=%0d hot_min=%0d",
        seq.min_hit_percent,
        seq.max_hit_percent,
        seq.hot_lane_min_hit_percent
      ))
    end
    if ($value$plusargs("OPQ_OVERFLOW_MAX_HIT_PERCENT=%d", max_hit_percent_plusarg) &&
        (max_hit_percent_plusarg >= seq.min_hit_percent) &&
        (max_hit_percent_plusarg <= 100)) begin
      seq.max_hit_percent = max_hit_percent_plusarg;
    end
    if ($value$plusargs("OPQ_OVERFLOW_HOT_MIN_HIT_PERCENT=%d", hot_lane_min_hit_percent_plusarg) &&
        (hot_lane_min_hit_percent_plusarg >= seq.min_hit_percent) &&
        (hot_lane_min_hit_percent_plusarg <= seq.max_hit_percent)) begin
      seq.hot_lane_min_hit_percent = hot_lane_min_hit_percent_plusarg;
    end
    if ((seq.max_hit_percent < seq.min_hit_percent) ||
        (seq.hot_lane_min_hit_percent < seq.min_hit_percent) ||
        (seq.hot_lane_count_max < seq.hot_lane_count_min)) begin
      `uvm_fatal(get_type_name(), $sformatf(
        "Invalid saturation config min=%0d max=%0d hot_min=%0d hot_lanes=[%0d:%0d]",
        seq.min_hit_percent,
        seq.max_hit_percent,
        seq.hot_lane_min_hit_percent,
        seq.hot_lane_count_min,
        seq.hot_lane_count_max
      ))
    end
    build_random_ready_gate_sequence(bp_seq, step_idx);

    `uvm_info(
      get_type_name(),
      $sformatf(
        "%s soak step %0d frames=%0d subheaders=%0d gap_cycles=%0d bp_segments=%0d hit_percent=[%0d:%0d] hot_min=%0d hot_lanes=[%0d:%0d] time=%0t",
        soak_label(),
        step_idx,
        frame_count_local,
        seq.subheaders_per_frame,
        inter_frame_gap_cycles_local,
        bp_segment_count,
        seq.min_hit_percent,
        seq.max_hit_percent,
        seq.hot_lane_min_hit_percent,
        seq.hot_lane_count_min,
        seq.hot_lane_count_max,
        $time
      ),
      UVM_LOW
    )

    configure_no_restart_sequence(seq);
    fork
      seq.start(env.vseqr);
      begin
        #(cycles_to_time(4));
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    advance_no_restart_sequence(seq);
    wait_for_credit_restore(
      $sformatf("%s_credit_restore", seq.get_name()),
      credit_restore_timeout(),
      credit_restore_poll()
    );
    update_ftable_drop_progress(step_idx);
    report_frame_table_accounting_checkpoint($sformatf("%s_step_%0d", soak_label(), step_idx), 1'b1);
    report_lane_hit_accounting_checkpoint($sformatf("%s_step_%0d", soak_label(), step_idx), 1'b1);
    #(inter_case_gap_time());
  endtask

  virtual task run_main_sequence();
    time target_t;
    int unsigned step_idx;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    overflow_steps_with_ft_drop = 0;
    short_bp_segments_seen = 0;
    ms_like_bp_segments_seen = 0;
    last_ft_drop_hdr_total = '0;
    last_ft_drop_shd_total = '0;
    last_ft_drop_hit_total = '0;
    target_t = target_run_time();
    step_idx = 0;

    do begin
      run_random_ready_overflow_step(step_idx);
      step_idx++;
    end while ((step_idx < soak_iterations) || ((target_t != 0) && ($time < target_t)));
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] ft_wr_hdr_word;
    bit [31:0] ft_wr_shd_word;
    bit [31:0] ft_wr_hit_word;
    bit [31:0] ft_rd_hdr_word;
    bit [31:0] ft_rd_shd_word;
    bit [31:0] ft_rd_hit_word;
    bit [31:0] ft_drop_hdr_word;
    bit [31:0] ft_drop_shd_word;
    bit [31:0] ft_drop_hit_word;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
      sample_lane_drr_snapshot(lane, -1, 1'b0, 1'b0);
    end

    csr_read32(OPQ_CSR_WORD_FT_WR_HDR, ft_wr_hdr_word);
    csr_read32(OPQ_CSR_WORD_FT_WR_SHD, ft_wr_shd_word);
    csr_read32(OPQ_CSR_WORD_FT_WR_HIT, ft_wr_hit_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_HDR, ft_rd_hdr_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_SHD, ft_rd_shd_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_HIT, ft_rd_hit_word);
    sample_frame_table_drop_totals(ft_drop_hdr_word, ft_drop_shd_word, ft_drop_hit_word);

    if (ft_rd_hdr_word !== env.scoreboard.get_actual_egress_hdr_cnt()[31:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_rd_hdr mismatch expected=%0d actual=%0d",
        env.scoreboard.get_actual_egress_hdr_cnt(),
        ft_rd_hdr_word
      ))
    end
    if (ft_rd_shd_word !== env.scoreboard.get_actual_egress_shd_cnt()[31:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_rd_shd mismatch expected=%0d actual=%0d",
        env.scoreboard.get_actual_egress_shd_cnt(),
        ft_rd_shd_word
      ))
    end
    if (ft_rd_hit_word !== env.scoreboard.get_actual_egress_hit_cnt()[31:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_rd_hit mismatch expected=%0d actual=%0d",
        env.scoreboard.get_actual_egress_hit_cnt(),
        ft_rd_hit_word
      ))
    end
    if (ft_wr_hdr_word !== (ft_rd_hdr_word + ft_drop_hdr_word)) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_wr_hdr accounting mismatch wr=%0d rd=%0d drop=%0d",
        ft_wr_hdr_word,
        ft_rd_hdr_word,
        ft_drop_hdr_word
      ))
    end
    if (ft_wr_shd_word !== (ft_rd_shd_word + ft_drop_shd_word)) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_wr_shd accounting mismatch wr=%0d rd=%0d drop=%0d",
        ft_wr_shd_word,
        ft_rd_shd_word,
        ft_drop_shd_word
      ))
    end
    if (ft_wr_hit_word !== (ft_rd_hit_word + ft_drop_hit_word)) begin
      `uvm_error(get_type_name(), $sformatf(
        "ft_wr_hit accounting mismatch wr=%0d rd=%0d drop=%0d",
        ft_wr_hit_word,
        ft_rd_hit_word,
        ft_drop_hit_word
      ))
    end
    if (require_ft_drop) begin
      if ((ft_drop_hdr_word == 0) && (ft_drop_shd_word == 0) && (ft_drop_hit_word == 0)) begin
        `uvm_error(get_type_name(), "Expected non-zero frame-table drop counters during random-ready overflow soak")
      end
      if (overflow_steps_with_ft_drop == 0) begin
        `uvm_error(get_type_name(), "Random-ready overflow soak never advanced the frame-table drop counters")
      end
    end else begin
      `uvm_info(
        get_type_name(),
        $sformatf(
          "%s soak completed in shape-check mode: ft_drop_hdr=%0d ft_drop_shd=%0d ft_drop_hit=%0d steps_with_ft_drop=%0d",
          soak_label(),
          ft_drop_hdr_word,
          ft_drop_shd_word,
          ft_drop_hit_word,
          overflow_steps_with_ft_drop
        ),
        UVM_LOW
      )
    end
    if ((bp_segment_count > 0) && (short_bp_segments_seen == 0)) begin
      `uvm_error(get_type_name(), "Random-ready overflow soak never exercised a short-cycle backpressure segment")
    end
    if ((bp_segment_count > 1) && (ms_like_bp_segments_seen == 0)) begin
      `uvm_error(get_type_name(), "Random-ready overflow soak never exercised an ms-like backpressure segment")
    end
    report_frame_table_accounting_checkpoint({soak_label(), "_final"}, 1'b1);
    report_lane_hit_accounting_checkpoint({soak_label(), "_final"}, 1'b1);
  endtask
endclass

class opq_cross_random_ready_overflow_long_simtime_soak_test extends opq_cross_random_ready_overflow_seconds_soak_test;
  `uvm_component_utils(opq_cross_random_ready_overflow_long_simtime_soak_test)

  function new(string name = "opq_cross_random_ready_overflow_long_simtime_soak_test", uvm_component parent = null);
    super.new(name, parent);
    if (!$test$plusargs("OPQ_OVERFLOW_SOAK_STEPS")) begin
      soak_iterations = 16;
    end
    if (!$test$plusargs("OPQ_OVERFLOW_BP_SEGMENTS")) begin
      bp_segment_count = 64;
    end
  endfunction
endclass

class opq_cross_random_ready_overflow_extensive_soak_test extends opq_cross_random_ready_overflow_seconds_soak_test;
  `uvm_component_utils(opq_cross_random_ready_overflow_extensive_soak_test)

  function new(string name = "opq_cross_random_ready_overflow_extensive_soak_test", uvm_component parent = null);
    super.new(name, parent);
    if (!$test$plusargs("OPQ_OVERFLOW_SOAK_STEPS")) begin
      soak_iterations = 8;
    end
    if (!$test$plusargs("OPQ_OVERFLOW_BP_SEGMENTS")) begin
      bp_segment_count = 24;
    end
  endfunction
endclass

class opq_cross_random_ready_half_saturation_1s_simtime_test extends opq_cross_random_ready_overflow_seconds_soak_test;
  `uvm_component_utils(opq_cross_random_ready_half_saturation_1s_simtime_test)

  function new(string name = "opq_cross_random_ready_half_saturation_1s_simtime_test", uvm_component parent = null);
    super.new(name, parent);
    require_ft_drop = 1'b0;
    if (!$test$plusargs("OPQ_OVERFLOW_SOAK_STEPS")) begin
      soak_iterations = 8;
    end
    if (!$test$plusargs("OPQ_OVERFLOW_BP_SEGMENTS")) begin
      bp_segment_count = 32;
    end
  endfunction

  virtual function int unsigned default_min_hit_percent();
    return 0;
  endfunction

  virtual function int unsigned default_max_hit_percent();
    return 50;
  endfunction

  virtual function int unsigned default_hot_lane_min_hit_percent();
    return 25;
  endfunction

  virtual function int unsigned default_hot_lane_count_min();
    return 0;
  endfunction

  virtual function string soak_label();
    return "half_sat";
  endfunction

  virtual function time target_run_time();
    return 1s;
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(4096);
  endfunction
endclass

class opq_cross_drr_then_idle_lane_bp_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_drr_then_idle_lane_bp_repro_test)

  function new(string name = "opq_cross_drr_then_idle_lane_bp_repro_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_main_sequence();
    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    run_cross_drr_bp_case("repro_drr", 5, 7, 16, 8, 8, 32, 8, 16);
    run_cross_idle_lane_bp_case("repro_idle_lane_bp", 0, 6, 8, 8, 8, 8, 32);
  endtask
endclass

class opq_cross_hit3_lead_in_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_hit3_lead_in_repro_test)

  localparam int unsigned REPRO_DWELL_CYCLES = 2_500_000;
  localparam int unsigned REPRO_TIMEOUT_CYCLES = 2_500_000;

  function new(string name = "opq_cross_hit3_lead_in_repro_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(REPRO_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(REPRO_TIMEOUT_CYCLES);
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence basic_seq;
    opq_whole_frame_skew_virtual_sequence skew_seq;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);

    skew_seq = opq_whole_frame_skew_virtual_sequence::type_id::create("repro_whole_skew");
    skew_seq.frame_count = 17;
    skew_seq.hit_period = 2;
    skew_seq.hit_count_when_active = 2;
    skew_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(skew_seq);

    run_cross_idle_lane_bp_case("repro_idle_lane_bp_186", 0, 6, 8, 8, 8, 8, 32);

    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_187");
    run_vseq(basic_seq);

    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_188");
    run_vseq(basic_seq);

    run_cross_drr_bp_case("repro_drr_189", 5, 7, 16, 8, 8, 32, 8, 16);
    run_cross_idle_lane_bp_case("repro_idle_lane_bp_190", 0, 6, 8, 8, 8, 8, 32);
  endtask
endclass

class opq_cross_hit3_exact_183_190_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_hit3_exact_183_190_repro_test)

  localparam int unsigned REPRO_DWELL_CYCLES = 2_500_000;
  localparam int unsigned REPRO_TIMEOUT_CYCLES = 2_500_000;

  function new(string name = "opq_cross_hit3_exact_183_190_repro_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(REPRO_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(REPRO_TIMEOUT_CYCLES);
  endfunction

  virtual task run_main_sequence();
    opq_whole_frame_skew_virtual_sequence skew_seq;
    opq_basic_virtual_sequence basic_187_seq;
    opq_basic_virtual_sequence basic_188_seq;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);

    // Exact failing lead-in from the logged seconds-soak repro window.
    run_basic_with_bp(BP_PERIODIC_STALL, 4, 8, 17);
    run_cross_drr_bp_case("repro_drr_184", 3, 7, 13, 4, 12, 44, 8, 16);

    skew_seq =
      opq_whole_frame_skew_virtual_sequence::type_id::create("repro_whole_skew_185");
    skew_seq.frame_count = 17;
    skew_seq.hit_period = 2;
    skew_seq.hit_count_when_active = 2;
    skew_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(skew_seq);

    run_cross_idle_lane_bp_case("repro_idle_lane_bp_186", 0, 6, 8, 8, 8, 8, 32);

    basic_187_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_187");
    run_vseq(basic_187_seq);

    basic_188_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_188");
    run_vseq(basic_188_seq);

    run_cross_drr_bp_case("repro_drr_189", 5, 7, 16, 4, 4, 41, 8, 16);
    run_cross_idle_lane_bp_case("repro_idle_lane_bp_190", 0, 6, 8, 8, 8, 8, 32);
  endtask
endclass

class opq_cross_masked_drop_exact_102_117_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_masked_drop_exact_102_117_repro_test)

  localparam int unsigned REPRO_DWELL_CYCLES = 1_000_000;
  localparam int unsigned REPRO_TIMEOUT_CYCLES = 1_000_000;

  function new(
    string name = "opq_cross_masked_drop_exact_102_117_repro_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(REPRO_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(REPRO_TIMEOUT_CYCLES);
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence basic_seq;
    opq_missing_empty_frame_virtual_sequence sparse_seq;
    opq_max_hits_virtual_sequence max_hits_seq;
    opq_single_lane_virtual_sequence single_lane_seq;
    opq_whole_frame_skew_virtual_sequence skew_seq;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);

    // Exact mixed-soak failing window from steps 102..117.
    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_102");
    run_vseq(basic_seq);

    run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());

    sparse_seq =
      opq_missing_empty_frame_virtual_sequence::type_id::create("repro_sparse_104");
    run_vseq(sparse_seq);

    max_hits_seq = opq_max_hits_virtual_sequence::type_id::create("repro_max_hits_105");
    run_vseq(max_hits_seq);

    run_basic_with_bp(BP_PERIODIC_STALL, 4, 12, 12);
    run_basic_with_bp(BP_PERIODIC_STALL, 16, 16, 13);

    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_108");
    run_vseq(basic_seq);

    run_basic_with_bp(BP_PERIODIC_STALL, 4, 4, 25);

    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_110");
    run_vseq(basic_seq);

    single_lane_seq =
      opq_single_lane_virtual_sequence::type_id::create("repro_single_lane_111");
    single_lane_seq.active_lane = 0;
    single_lane_seq.frame_count = 6;
    single_lane_seq.subheaders_per_frame = 4;
    single_lane_seq.hit_count = 4;
    run_vseq(single_lane_seq);

    single_lane_seq =
      opq_single_lane_virtual_sequence::type_id::create("repro_single_lane_112");
    single_lane_seq.active_lane = 1;
    single_lane_seq.frame_count = 5;
    single_lane_seq.subheaders_per_frame = 4;
    single_lane_seq.hit_count = 4;
    run_vseq(single_lane_seq);

    run_cross_idle_lane_bp_case("repro_idle_lane_bp_113", 0, 6, 8, 8, 8, 8, 32);

    skew_seq =
      opq_whole_frame_skew_virtual_sequence::type_id::create("repro_whole_skew_114");
    skew_seq.frame_count = 9;
    skew_seq.hit_period = 2;
    skew_seq.hit_count_when_active = 2;
    skew_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(skew_seq);

    skew_seq =
      opq_whole_frame_skew_virtual_sequence::type_id::create("repro_whole_skew_115");
    skew_seq.frame_count = 8;
    skew_seq.hit_period = 3;
    skew_seq.hit_count_when_active = 2;
    skew_seq.inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    run_vseq(skew_seq);

    run_masked_drop_recovery_case("repro_masked_recovery_116");
    run_masked_drop_recovery_case("repro_masked_recovery_117");
  endtask
endclass

class opq_cross_single_hit_masked_then_sparse_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_single_hit_masked_then_sparse_repro_test)

  localparam int unsigned REPRO_TIMEOUT_CYCLES = 1_000_000;

  function new(
    string name = "opq_cross_single_hit_masked_then_sparse_repro_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(REPRO_TIMEOUT_CYCLES);
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence basic_seq;
    opq_missing_empty_frame_virtual_sequence sparse_seq;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);

    basic_seq = opq_basic_virtual_sequence::type_id::create("repro_basic_lead_in");
    run_vseq(basic_seq);

    run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());

    sparse_seq =
      opq_missing_empty_frame_virtual_sequence::type_id::create("repro_sparse_followup");
    run_vseq(sparse_seq);
  endtask
endclass

class opq_cross_sparse_single_lane_drr_credit_restore_repro_test extends opq_frame_signoff_base_test;
  `uvm_component_utils(opq_cross_sparse_single_lane_drr_credit_restore_repro_test)

  localparam int unsigned REPRO_DWELL_CYCLES = 500_000;
  localparam int unsigned REPRO_TIMEOUT_CYCLES = 500_000;

  function new(
    string name = "opq_cross_sparse_single_lane_drr_credit_restore_repro_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return cycles_to_time(REPRO_DWELL_CYCLES);
  endfunction

  virtual function time credit_restore_timeout();
    return cycles_to_time(REPRO_TIMEOUT_CYCLES);
  endfunction

  virtual task run_main_sequence();
    opq_missing_empty_frame_virtual_sequence sparse_seq;
    opq_single_lane_virtual_sequence single_lane_seq;

    reset_no_restart_identity();
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);

    sparse_seq = opq_missing_empty_frame_virtual_sequence::type_id::create("repro_sparse_0");
    run_vseq(sparse_seq);
    report_lane_hit_accounting_checkpoint("after_sparse_0", 1'b1);

    single_lane_seq =
      opq_single_lane_virtual_sequence::type_id::create("repro_single_lane_1");
    single_lane_seq.active_lane = 0;
    single_lane_seq.frame_count = 5;
    single_lane_seq.subheaders_per_frame = 4;
    single_lane_seq.hit_count = 4;
    run_vseq(single_lane_seq);
    report_lane_hit_accounting_checkpoint("after_single_lane_1", 1'b0);

    run_cross_drr_bp_case("repro_drr_2", 3, 6, 9, 8, 4, 45, 8, 16);
    report_lane_hit_accounting_checkpoint("after_drr_2", 1'b0);
  endtask
endclass

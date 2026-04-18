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

  function automatic time tb_clk_period();
    int unsigned clk_period_ns;

    if (!$value$plusargs("TB_CLK_PERIOD_NS=%d", clk_period_ns) || (clk_period_ns == 0)) begin
      clk_period_ns = TB_REF_CLK_PERIOD_NS;
    end
    return clk_period_ns * 1ns;
  endfunction

  function automatic time cycles_to_time(longint unsigned cycle_count);
    return cycle_count * tb_clk_period();
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

    frame_duration_cycles = 48'(OPQ_N_SHD * 16);
    frame_slots_emitted = seq.get_continuous_frame_slots_emitted();
    foreach (no_restart_next_pkg_cnt_base[lane]) begin
      no_restart_next_pkg_cnt_base[lane] = seq.get_next_pkg_cnt_base(lane);
    end
    if (seq.continuous_frame_emits_egress_frames()) begin
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

  int unsigned soak_iterations;
  int unsigned bucket_visit_count[MIXED_BUCKET_COUNT];

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
        run_basic_with_bp(bp_mode, high_cycles, low_cycles, repeat_count);
      end
      1: begin
        seq = opq_max_hits_virtual_sequence::type_id::create($sformatf("mixed_max_hits_%0d", step_idx));
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
        run_vseq(skew_seq);
      end
      2: begin
        seq = opq_missing_empty_frame_virtual_sequence::type_id::create($sformatf("mixed_sparse_%0d", step_idx));
        run_vseq(seq);
      end
    endcase
  endtask

  task automatic run_random_error_step(int unsigned step_idx);
    int unsigned choice;

    if (!std::randomize(choice) with { choice inside {[0:2]}; }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize mixed ERROR choice")
    end

    case (choice)
      0: begin
        run_masked_drop_case(opq_masked_drop_virtual_sequence::get_type());
      end
      1: begin
        run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());
      end
      2: begin
        run_masked_drop_recovery_case($sformatf("mixed_masked_recovery_%0d", step_idx));
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

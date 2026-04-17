class opq_frame_signoff_base_test extends opq_base_test;
  `uvm_component_utils(opq_frame_signoff_base_test)

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

  virtual function time dwell_time();
    return 2500us;
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

  task automatic run_vseq(opq_virtual_sequence_base seq, time inter_case_gap = 2us);
    configure_no_restart_sequence(seq);
    `uvm_info(get_type_name(), $sformatf("Starting no-restart case %s", seq.get_name()), UVM_LOW)
    seq.start(env.vseqr);
    advance_no_restart_sequence(seq);
    wait_for_credit_restore($sformatf("%s_credit_restore", seq.get_name()));
    #(inter_case_gap);
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
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    advance_no_restart_sequence(seq);
    wait_for_credit_restore($sformatf("%s_credit_restore", seq.get_name()));
    #2us;
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
    #5us;
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    wait_for_credit_restore($sformatf("%s_credit_restore", seq.get_name()));
    #2us;
  endtask

  task automatic run_basic_bucket();
    opq_basic_virtual_sequence basic_seq;
    opq_boundary_ts_virtual_sequence ts_seq;
    opq_basic_feb_packet_virtual_sequence feb_seq;
    opq_subheader_shape_virtual_sequence shd_seq;

    basic_seq = opq_basic_virtual_sequence::type_id::create("basic_seq");
    ts_seq = opq_boundary_ts_virtual_sequence::type_id::create("ts_seq");
    feb_seq = opq_basic_feb_packet_virtual_sequence::type_id::create("feb_seq");
    shd_seq = opq_subheader_shape_virtual_sequence::type_id::create("shd_seq");

    run_vseq(basic_seq);
    run_vseq(ts_seq);
    run_vseq(feb_seq);
    run_vseq(shd_seq);
  endtask

  task automatic run_edge_bucket();
    opq_max_hits_virtual_sequence max_hits_seq;

    run_basic_with_bp(BP_PERIODIC_STALL, 6, 4, 24);
    run_basic_with_bp(BP_ALWAYS_READY, 32, 4, 1);
    run_basic_with_bp(BP_ALWAYS_READY, 32, 8, 1);
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
  endtask

  task automatic run_error_bucket();
    opq_masked_drop_virtual_sequence masked_seq;
    opq_basic_virtual_sequence recovery_seq;
    opq_subheader_error_recovery_virtual_sequence shd_recovery_seq;
    bit [31:0] mask_word;

    run_masked_drop_case(opq_masked_drop_virtual_sequence::get_type());
    run_masked_drop_case(opq_single_hit_masked_drop_virtual_sequence::get_type());
    run_masked_drop_case(opq_burst_masked_drop_virtual_sequence::get_type());

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    masked_seq = opq_masked_drop_virtual_sequence::type_id::create("masked_seq");
    recovery_seq = opq_basic_virtual_sequence::type_id::create("recovery_seq");
    configure_no_restart_sequence(masked_seq);
    `uvm_info(get_type_name(), $sformatf("Starting no-restart case %s", masked_seq.get_name()), UVM_LOW)
    masked_seq.start(env.vseqr);
    advance_no_restart_sequence(masked_seq);
    #5us;
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    wait_for_credit_restore($sformatf("%s_credit_restore", masked_seq.get_name()));
    run_vseq(recovery_seq);

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
        #2us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
    join
    advance_no_restart_sequence(soak_seq);
    wait_for_credit_restore("bp_credit_seq_credit_restore");
    #2us;

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
    return 3000us;
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

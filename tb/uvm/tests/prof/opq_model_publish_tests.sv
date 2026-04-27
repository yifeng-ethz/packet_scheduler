class opq_model_publish_loss_sweep_test extends opq_base_test;
  `uvm_component_utils(opq_model_publish_loss_sweep_test)

  string model_case;
  int unsigned model_profile;
  int unsigned model_frame_count;
  int unsigned model_subheaders_per_frame;
  int unsigned model_hit_period;
  int unsigned model_hit_count;
  int unsigned model_inter_gap_cycles;
  int unsigned model_ready_high;
  int unsigned model_ready_low;
  int unsigned model_ready_repeat;
  int unsigned model_rho_ppm;
  int signed   model_burstiness_milli;
  int unsigned model_ready_duty_ppm;
  int unsigned model_dwell_us;
  int unsigned model_drain_timeout_us;
  int unsigned model_require_drain;
  int unsigned model_credit_samples;
  int unsigned model_credit_interval_us;

  function new(string name = "opq_model_publish_loss_sweep_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.allow_drop_accounting = 1'b1;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  function void read_model_plusargs();
    int signed burstiness_arg;

    model_case = "RTL-LS-002";
    void'($value$plusargs("OPQ_MODEL_CASE=%s", model_case));

    model_profile = 0;
    model_frame_count = 24;
    model_subheaders_per_frame = 32;
    model_hit_period = 4;
    model_hit_count = 2;
    model_inter_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    model_ready_high = 0;
    model_ready_low = 0;
    model_ready_repeat = 0;
    model_rho_ppm = 7500;
    model_burstiness_milli = 0;
    model_ready_duty_ppm = 1000000;
    model_dwell_us = 900;
    model_drain_timeout_us = 900;
    model_require_drain = 0;
    model_credit_samples = 12;
    model_credit_interval_us = 10;

    void'($value$plusargs("OPQ_MODEL_PROFILE=%d", model_profile));
    void'($value$plusargs("OPQ_MODEL_FRAME_COUNT=%d", model_frame_count));
    void'($value$plusargs("OPQ_MODEL_SUBHEADERS=%d", model_subheaders_per_frame));
    void'($value$plusargs("OPQ_MODEL_HIT_PERIOD=%d", model_hit_period));
    void'($value$plusargs("OPQ_MODEL_HIT_COUNT=%d", model_hit_count));
    void'($value$plusargs("OPQ_MODEL_INTER_GAP=%d", model_inter_gap_cycles));
    void'($value$plusargs("OPQ_MODEL_READY_HIGH=%d", model_ready_high));
    void'($value$plusargs("OPQ_MODEL_READY_LOW=%d", model_ready_low));
    void'($value$plusargs("OPQ_MODEL_READY_REPEAT=%d", model_ready_repeat));
    void'($value$plusargs("OPQ_MODEL_RHO_PPM=%d", model_rho_ppm));
    if ($value$plusargs("OPQ_MODEL_BURSTINESS_MILLI=%d", burstiness_arg)) begin
      model_burstiness_milli = burstiness_arg;
    end
    void'($value$plusargs("OPQ_MODEL_READY_DUTY_PPM=%d", model_ready_duty_ppm));
    void'($value$plusargs("OPQ_MODEL_DWELL_US=%d", model_dwell_us));
    void'($value$plusargs("OPQ_MODEL_DRAIN_TIMEOUT_US=%d", model_drain_timeout_us));
    void'($value$plusargs("OPQ_MODEL_REQUIRE_DRAIN=%d", model_require_drain));
    void'($value$plusargs("OPQ_MODEL_CREDIT_SAMPLES=%d", model_credit_samples));
    void'($value$plusargs("OPQ_MODEL_CREDIT_INTERVAL_US=%d", model_credit_interval_us));

    if (model_subheaders_per_frame == 0) begin
      model_subheaders_per_frame = 1;
    end
    if (model_subheaders_per_frame > OPQ_N_SHD) begin
      model_subheaders_per_frame = OPQ_N_SHD;
    end
    if (model_hit_count > OPQ_N_HIT) begin
      model_hit_count = OPQ_N_HIT;
    end
    if (model_ready_repeat == 0 && model_ready_low != 0) begin
      model_ready_repeat = model_frame_count + 8;
    end
    if ((model_ready_high + model_ready_low) != 0) begin
      model_ready_duty_ppm = (model_ready_high * 1000000) / (model_ready_high + model_ready_low);
    end
  endfunction

  virtual function time dwell_time();
    read_model_plusargs();
    return model_dwell_us * 1us;
  endfunction

  task automatic run_model_backpressure();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;

    if (model_ready_low == 0) begin
      return;
    end

    bp_seq = opq_bp_sequence::type_id::create("model_publish_bp_seq");
    bp_item = opq_bp_item::type_id::create("model_publish_bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = model_ready_high;
    bp_item.low_cycles = model_ready_low;
    bp_item.repeat_count = model_ready_repeat;
    bp_seq.items.push_back(bp_item);
    bp_seq.start(env.vseqr.egress_seqr);
  endtask

  virtual task run_main_sequence();
    opq_whole_frame_skew_virtual_sequence whole_seq;
    opq_drr_saturation_virtual_sequence drr_seq;
    opq_variable_saturation_overflow_virtual_sequence sat_seq;

    read_model_plusargs();
    csr_clear_counters();

    `uvm_info(get_type_name(), $sformatf(
      "MODEL_PUBLISH_CONFIG case=%s profile=%0d n_lane=%0d n_shd=%0d egress_symbols_per_beat=%0d frame_count=%0d subheaders_per_frame=%0d hit_period=%0d hit_count=%0d ready_duty_ppm=%0d rho_ppm=%0d burstiness_milli=%0d",
      model_case,
      model_profile,
      OPQ_N_LANE,
      OPQ_N_SHD,
      OPQ_EGRESS_SYMBOLS_PER_BEAT,
      model_frame_count,
      model_subheaders_per_frame,
      model_hit_period,
      model_hit_count,
      model_ready_duty_ppm,
      model_rho_ppm,
      model_burstiness_milli
    ), UVM_LOW)

    fork
      begin
        case (model_profile)
          1: begin
            drr_seq = opq_drr_saturation_virtual_sequence::type_id::create("model_publish_drr_seq");
            drr_seq.frame_count = model_frame_count;
            drr_seq.subheaders_per_frame = model_subheaders_per_frame;
            drr_seq.hit_count_per_subheader = model_hit_count;
            drr_seq.start(env.vseqr);
          end
          2: begin
            sat_seq = opq_variable_saturation_overflow_virtual_sequence::type_id::create("model_publish_sat_seq");
            sat_seq.frame_count = model_frame_count;
            sat_seq.subheaders_per_frame = model_subheaders_per_frame;
            sat_seq.min_hit_percent = (model_hit_count < 1) ? 1 : model_hit_count;
            sat_seq.max_hit_percent = (model_hit_count < 1) ? 1 : model_hit_count;
            sat_seq.hot_lane_min_hit_percent = (model_hit_count < 1) ? 1 : model_hit_count;
            sat_seq.hot_lane_count_min = 1;
            sat_seq.hot_lane_count_max = (OPQ_N_LANE >= 2) ? 2 : 1;
            sat_seq.inter_frame_gap_cycles = model_inter_gap_cycles;
            sat_seq.start(env.vseqr);
          end
          default: begin
            whole_seq = opq_whole_frame_skew_virtual_sequence::type_id::create("model_publish_whole_seq");
            whole_seq.frame_count = model_frame_count;
            whole_seq.subheaders_per_frame = model_subheaders_per_frame;
            whole_seq.hit_period = model_hit_period;
            whole_seq.hit_count_when_active = model_hit_count;
            whole_seq.inter_frame_gap_cycles = model_inter_gap_cycles;
            whole_seq.start(env.vseqr);
          end
        endcase
      end
      begin
        #1us;
        run_model_backpressure();
      end
      begin
        #10us;
        poll_lane_credits(model_credit_samples, model_credit_interval_us * 1us);
      end
    join
  endtask

  task automatic emit_model_publish_result();
    int unsigned total_expected;
    int unsigned total_accepted;
    int unsigned total_dropped;
    int unsigned total_delivered;
    int unsigned total_unexplained;
    int unsigned total_loss_ppm;
    bit [31:0] ft_wr_hit_word;
    bit [31:0] ft_rd_hit_word;
    bit [31:0] ft_drop_hit_word;

    total_expected = 0;
    total_accepted = 0;
    total_dropped = 0;
    total_delivered = 0;
    total_unexplained = 0;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int unsigned expected_hits;
      int unsigned accepted_hits;
      int unsigned dropped_hits;
      int unsigned delivered_hits;
      int unsigned unexplained_hits;
      int unsigned loss_ppm;
      int unsigned allowance_word;
      int unsigned quantum_word;
      int unsigned grant_cnt_word;
      int unsigned beat_cnt_word;
      int unsigned defer_cnt_word;

      expected_hits = env.scoreboard.get_expected_lane_hit_cnt(lane);
      accepted_hits = env.scoreboard.get_accepted_lane_hit_cnt(lane);
      dropped_hits = env.scoreboard.get_dropped_lane_hit_cnt(lane);
      delivered_hits = env.scoreboard.get_actual_lane_hit_cnt(lane);
      unexplained_hits = env.scoreboard.get_unexplained_lane_hit_cnt(lane);
      loss_ppm = (expected_hits == 0) ? 0 : ((dropped_hits * 1000000) / expected_hits);
      read_lane_drr_snapshot(lane, allowance_word, quantum_word, grant_cnt_word, beat_cnt_word, defer_cnt_word);

      total_expected += expected_hits;
      total_accepted += accepted_hits;
      total_dropped += dropped_hits;
      total_delivered += delivered_hits;
      total_unexplained += unexplained_hits;

      `uvm_info(get_type_name(), $sformatf(
        "MODEL_PUBLISH_RESULT case=%s profile=%0d lane=%0d n_lane=%0d n_shd=%0d egress_symbols_per_beat=%0d ready_duty_ppm=%0d rho_ppm=%0d burstiness_milli=%0d frame_count=%0d subheaders_per_frame=%0d hit_period=%0d hit_count=%0d expected_hits=%0d accepted_hits=%0d dropped_hits=%0d delivered_hits=%0d unexplained_hits=%0d loss_ppm=%0d drr_allowance=%0d drr_quantum=%0d drr_grants=%0d drr_beats=%0d drr_defers=%0d",
        model_case,
        model_profile,
        lane,
        OPQ_N_LANE,
        OPQ_N_SHD,
        OPQ_EGRESS_SYMBOLS_PER_BEAT,
        model_ready_duty_ppm,
        model_rho_ppm,
        model_burstiness_milli,
        model_frame_count,
        model_subheaders_per_frame,
        model_hit_period,
        model_hit_count,
        expected_hits,
        accepted_hits,
        dropped_hits,
        delivered_hits,
        unexplained_hits,
        loss_ppm,
        allowance_word,
        quantum_word,
        grant_cnt_word,
        beat_cnt_word,
        defer_cnt_word
      ), UVM_LOW)
    end

    total_loss_ppm = (total_expected == 0) ? 0 : ((total_dropped * 1000000) / total_expected);
    csr_read32(OPQ_CSR_WORD_FT_WR_HIT, ft_wr_hit_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_HIT, ft_rd_hit_word);
    csr_read32(OPQ_CSR_WORD_FT_DROP_HIT, ft_drop_hit_word);

    `uvm_info(get_type_name(), $sformatf(
      "MODEL_PUBLISH_AGG case=%s profile=%0d n_lane=%0d n_shd=%0d egress_symbols_per_beat=%0d ready_duty_ppm=%0d rho_ppm=%0d burstiness_milli=%0d expected_hits=%0d accepted_hits=%0d dropped_hits=%0d delivered_hits=%0d unexplained_hits=%0d loss_ppm=%0d ft_wr_hit=%0d ft_rd_hit=%0d ft_drop_hit=%0d",
      model_case,
      model_profile,
      OPQ_N_LANE,
      OPQ_N_SHD,
      OPQ_EGRESS_SYMBOLS_PER_BEAT,
      model_ready_duty_ppm,
      model_rho_ppm,
      model_burstiness_milli,
      total_expected,
      total_accepted,
      total_dropped,
      total_delivered,
      total_unexplained,
      total_loss_ppm,
      ft_wr_hit_word,
      ft_rd_hit_word,
      ft_drop_hit_word
    ), UVM_LOW)
  endtask

  virtual task run_post_sequence_checks();
    read_model_plusargs();
    super.run_post_sequence_checks();

    if (model_require_drain != 0) begin
      wait_for_credit_restore("model_publish_drain", model_drain_timeout_us * 1us, 500ns);
    end else begin
      wait_for_ingress_idle("model_publish_ingress_idle", model_drain_timeout_us * 1us, 500ns);
    end

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, model_require_drain != 0);
      sample_lane_drr_snapshot(lane, -1, 1'b0, 1'b0);
    end
    sample_frame_table_drop_snapshot();
    report_frame_table_accounting_checkpoint("model_publish_final", model_require_drain != 0);
    report_lane_hit_accounting_checkpoint("model_publish_final", model_require_drain != 0);
    report_core_principle_checkpoint("model_publish_final", model_require_drain != 0, model_require_drain != 0);
    emit_model_publish_result();
  endtask
endclass

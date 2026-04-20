class opq_error_lane_mask_test extends opq_base_test;
  `uvm_component_utils(opq_error_lane_mask_test)

  function new(string name = "opq_error_lane_mask_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 80us;
  endfunction

  virtual task run_main_sequence();
    opq_masked_drop_virtual_sequence seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    seq = opq_masked_drop_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] lane_mask_word;

    super.run_post_sequence_checks();
    lane_mask_word = '0;
    lane_mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    expect_csr_value("lane_mask", OPQ_CSR_WORD_LANE_MASK, lane_mask_word);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      expect_csr_value($sformatf("lane%0d_wr_hdr", lane), lane_base + 9'h000, 0);
      expect_csr_value($sformatf("lane%0d_wr_shd", lane), lane_base + 9'h001, 0);
      expect_csr_value($sformatf("lane%0d_wr_hit", lane), lane_base + 9'h002, 0);
      expect_csr_value($sformatf("lane%0d_rd_hdr", lane), lane_base + 9'h003, 0);
      expect_csr_value($sformatf("lane%0d_rd_shd", lane), lane_base + 9'h004, 0);
      expect_csr_value($sformatf("lane%0d_rd_hit", lane), lane_base + 9'h005, 0);
      expect_csr_value($sformatf("lane%0d_drop_hdr", lane), lane_base + 9'h006,
        env.scoreboard.get_expected_lane_hdr_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_shd", lane), lane_base + 9'h007,
        env.scoreboard.get_expected_lane_shd_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_hit", lane), lane_base + 9'h008,
        env.scoreboard.get_expected_lane_hit_cnt(lane));
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
    end
    expect_csr_value("ft_wr_hdr", OPQ_CSR_WORD_FT_WR_HDR, 0);
    expect_csr_value("ft_wr_shd", OPQ_CSR_WORD_FT_WR_SHD, 0);
    expect_csr_value("ft_wr_hit", OPQ_CSR_WORD_FT_WR_HIT, 0);
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
    sample_frame_table_drop_snapshot();
  endtask
endclass

class opq_error_lane_mask_single_hit_test extends opq_base_test;
  `uvm_component_utils(opq_error_lane_mask_single_hit_test)

  function new(string name = "opq_error_lane_mask_single_hit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 80us;
  endfunction

  virtual task run_main_sequence();
    opq_single_hit_masked_drop_virtual_sequence seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    seq = opq_single_hit_masked_drop_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] lane_mask_word;

    super.run_post_sequence_checks();
    lane_mask_word = '0;
    lane_mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    expect_csr_value("lane_mask", OPQ_CSR_WORD_LANE_MASK, lane_mask_word);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      expect_csr_value($sformatf("lane%0d_wr_hdr", lane), lane_base + 9'h000, 0);
      expect_csr_value($sformatf("lane%0d_wr_shd", lane), lane_base + 9'h001, 0);
      expect_csr_value($sformatf("lane%0d_wr_hit", lane), lane_base + 9'h002, 0);
      expect_csr_value($sformatf("lane%0d_rd_hdr", lane), lane_base + 9'h003, 0);
      expect_csr_value($sformatf("lane%0d_rd_shd", lane), lane_base + 9'h004, 0);
      expect_csr_value($sformatf("lane%0d_rd_hit", lane), lane_base + 9'h005, 0);
      expect_csr_value($sformatf("lane%0d_drop_hdr", lane), lane_base + 9'h006,
        env.scoreboard.get_expected_lane_hdr_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_shd", lane), lane_base + 9'h007,
        env.scoreboard.get_expected_lane_shd_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_hit", lane), lane_base + 9'h008,
        env.scoreboard.get_expected_lane_hit_cnt(lane));
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
    end
    sample_frame_table_drop_snapshot();
  endtask
endclass

class opq_error_lane_mask_burst_test extends opq_base_test;
  `uvm_component_utils(opq_error_lane_mask_burst_test)

  function new(string name = "opq_error_lane_mask_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 180us;
  endfunction

  virtual task run_main_sequence();
    opq_burst_masked_drop_virtual_sequence seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    seq = opq_burst_masked_drop_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] lane_mask_word;

    super.run_post_sequence_checks();
    lane_mask_word = '0;
    lane_mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};
    expect_csr_value("lane_mask", OPQ_CSR_WORD_LANE_MASK, lane_mask_word);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      expect_csr_value($sformatf("lane%0d_wr_hdr", lane), lane_base + 9'h000, 0);
      expect_csr_value($sformatf("lane%0d_wr_shd", lane), lane_base + 9'h001, 0);
      expect_csr_value($sformatf("lane%0d_wr_hit", lane), lane_base + 9'h002, 0);
      expect_csr_value($sformatf("lane%0d_rd_hdr", lane), lane_base + 9'h003, 0);
      expect_csr_value($sformatf("lane%0d_rd_shd", lane), lane_base + 9'h004, 0);
      expect_csr_value($sformatf("lane%0d_rd_hit", lane), lane_base + 9'h005, 0);
      expect_csr_value($sformatf("lane%0d_drop_hdr", lane), lane_base + 9'h006,
        env.scoreboard.get_expected_lane_hdr_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_shd", lane), lane_base + 9'h007,
        env.scoreboard.get_expected_lane_shd_cnt(lane));
      expect_csr_value($sformatf("lane%0d_drop_hit", lane), lane_base + 9'h008,
        env.scoreboard.get_expected_lane_hit_cnt(lane));
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
    end
    sample_frame_table_drop_snapshot();
  endtask
endclass

class opq_error_ftable_overflow_test extends opq_base_test;
  `uvm_component_utils(opq_error_ftable_overflow_test)

  function new(string name = "opq_error_ftable_overflow_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 420us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_soak_virtual_sequence seq;

    csr_clear_counters();
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_ALWAYS_STALL;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 55_000;
    bp_item.repeat_count = 1;
    bp_seq.items.push_back(bp_item);

    fork
      begin
        seq = opq_soak_virtual_sequence::type_id::create("seq");
        seq.frame_count = 32;
        seq.start(env.vseqr);
      end
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #20us;
        poll_lane_credits(20, 40us);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] ft_drop_hdr_word;
    bit [31:0] ft_drop_shd_word;
    bit [31:0] ft_drop_hit_word;

    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
    end

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

    if ((ft_drop_hdr_word == 0) && (ft_drop_shd_word == 0) && (ft_drop_hit_word == 0)) begin
      `uvm_error(get_type_name(), "Expected non-zero frame-table drop counters during forced egress stall overflow run")
    end
    report_frame_table_accounting_checkpoint("forced_overflow_final", 1'b1);
    report_lane_hit_accounting_checkpoint("forced_overflow_final", 1'b1);
    report_core_principle_checkpoint("forced_overflow_final", 1'b1, 1'b1);
  endtask
endclass

class opq_error_counter_clear_test extends opq_base_test;
  `uvm_component_utils(opq_error_counter_clear_test)

  function new(string name = "opq_error_counter_clear_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 40us;
  endfunction

  virtual task run_main_sequence();
    opq_masked_drop_virtual_sequence seq;
    bit [31:0] mask_word;
    bit [31:0] hdr_drop_word;
    bit [31:0] shd_drop_word;
    bit [31:0] hit_drop_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};

    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    seq = opq_masked_drop_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
    #5us;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;

      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      csr_read32(lane_base + 9'h006, hdr_drop_word);
      csr_read32(lane_base + 9'h007, shd_drop_word);
      csr_read32(lane_base + 9'h008, hit_drop_word);
      if ((hdr_drop_word == 0) && (shd_drop_word == 0) && (hit_drop_word == 0)) begin
        `uvm_error(get_type_name(), $sformatf(
          "Expected non-zero lane drop counters before clear on lane %0d",
          lane
        ))
      end
    end

    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    expect_csr_value("lane_mask", OPQ_CSR_WORD_LANE_MASK, 0);
    expect_csr_value("ft_wr_hdr", OPQ_CSR_WORD_FT_WR_HDR, 0);
    expect_csr_value("ft_wr_shd", OPQ_CSR_WORD_FT_WR_SHD, 0);
    expect_csr_value("ft_wr_hit", OPQ_CSR_WORD_FT_WR_HIT, 0);
    expect_csr_value("ft_rd_hdr", OPQ_CSR_WORD_FT_RD_HDR, 0);
    expect_csr_value("ft_rd_shd", OPQ_CSR_WORD_FT_RD_SHD, 0);
    expect_csr_value("ft_rd_hit", OPQ_CSR_WORD_FT_RD_HIT, 0);
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;

      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      expect_csr_value($sformatf("lane%0d_wr_hdr", lane), lane_base + 9'h000, 0);
      expect_csr_value($sformatf("lane%0d_wr_shd", lane), lane_base + 9'h001, 0);
      expect_csr_value($sformatf("lane%0d_wr_hit", lane), lane_base + 9'h002, 0);
      expect_csr_value($sformatf("lane%0d_rd_hdr", lane), lane_base + 9'h003, 0);
      expect_csr_value($sformatf("lane%0d_rd_shd", lane), lane_base + 9'h004, 0);
      expect_csr_value($sformatf("lane%0d_rd_hit", lane), lane_base + 9'h005, 0);
      expect_csr_value($sformatf("lane%0d_drop_hdr", lane), lane_base + 9'h006, 0);
      expect_csr_value($sformatf("lane%0d_drop_shd", lane), lane_base + 9'h007, 0);
      expect_csr_value($sformatf("lane%0d_drop_hit", lane), lane_base + 9'h008, 0);
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b1);
    end
    sample_frame_table_drop_snapshot();
  endtask
endclass

class opq_error_lane_mask_recovery_test extends opq_base_test;
  `uvm_component_utils(opq_error_lane_mask_recovery_test)

  function new(string name = "opq_error_lane_mask_recovery_test", uvm_component parent = null);
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
    return 350us;
  endfunction

  virtual task run_main_sequence();
    opq_masked_drop_virtual_sequence masked_seq;
    opq_basic_virtual_sequence recovery_seq;
    bit [31:0] mask_word;

    mask_word = '0;
    mask_word[OPQ_N_LANE-1:0] = {OPQ_N_LANE{1'b1}};

    csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_LANE_MASK, mask_word);
    masked_seq = opq_masked_drop_virtual_sequence::type_id::create("masked_seq");
    recovery_seq = opq_basic_virtual_sequence::type_id::create("recovery_seq");

    masked_seq.start(env.vseqr);
    #5us;
    csr_write32(OPQ_CSR_WORD_LANE_MASK, 32'h0000_0000);
    recovery_seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    expect_csr_value("lane_mask", OPQ_CSR_WORD_LANE_MASK, 0);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_drop_accounting_and_credit(lane);
      sample_lane_drr_snapshot(lane, OPQ_DRR_DEFAULT_ALLOWANCE, 1'b0, 1'b0);
    end
    check_frame_table_counts();
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
  endtask
endclass

class opq_error_header_mask_recovery_test extends opq_base_test;
  `uvm_component_utils(opq_error_header_mask_recovery_test)

  function new(string name = "opq_error_header_mask_recovery_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.allow_unmatched_ingress_preamble = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 120us;
  endfunction

  virtual task run_main_sequence();
    opq_header_error_recovery_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_header_error_recovery_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
  endtask
endclass

class opq_error_header_word_mask_recovery_test extends opq_base_test;
  `uvm_component_utils(opq_error_header_word_mask_recovery_test)

  function new(string name = "opq_error_header_word_mask_recovery_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.allow_unmatched_ingress_preamble = 1'b0;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 180us;
  endfunction

  virtual task run_main_sequence();
    opq_header_word_error_recovery_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_header_word_error_recovery_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
  endtask
endclass

class opq_error_subheader_mask_recovery_test extends opq_base_test;
  `uvm_component_utils(opq_error_subheader_mask_recovery_test)

  function new(string name = "opq_error_subheader_mask_recovery_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 140us;
  endfunction

  virtual task run_main_sequence();
    opq_subheader_error_recovery_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_subheader_error_recovery_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
  endtask
endclass

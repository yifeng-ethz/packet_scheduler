//------------------------------------------------------------------------------
// IP Name   : opq_base_test
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - add DRR defer helpers for block-level scheduler checks
// Description:
//   Shared UVM base test with CSR helpers and scoreboard/counter checks.
//------------------------------------------------------------------------------
class opq_base_test extends uvm_test;
  `uvm_component_utils(opq_base_test)

  opq_env env;
  opq_scoreboard_cfg sb_cfg;
  opq_dut_cfg dut_cfg;
  virtual opq_csr_if csr_vif;

  function new(string name = "opq_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = opq_scoreboard_cfg::type_id::create("sb_cfg");
    return cfg;
  endfunction

  function void build_phase(uvm_phase phase);
    sb_cfg = create_scoreboard_cfg();
    uvm_config_db#(opq_scoreboard_cfg)::set(this, "env.scoreboard", "cfg", sb_cfg);
    if (!uvm_config_db#(opq_dut_cfg)::get(this, "", "dut_cfg", dut_cfg)) begin
      dut_cfg = opq_dut_cfg::type_id::create("dut_cfg");
      uvm_config_db#(opq_dut_cfg)::set(this, "*", "dut_cfg", dut_cfg);
    end
    super.build_phase(phase);
    if (!uvm_config_db#(virtual opq_csr_if)::get(this, "", "csr_vif", csr_vif)) begin
      `uvm_fatal(get_type_name(), "Missing csr_vif")
    end
    env = opq_env::type_id::create("env", this);
  endfunction

  virtual task run_main_sequence();
  endtask

  virtual task run_post_sequence_checks();
  endtask

  virtual function time dwell_time();
    return 300us;
  endfunction

  task automatic csr_write32(bit [8:0] addr, bit [31:0] data);
    logic [31:0] dummy_data;
    csr_vif.write32(addr, data);
    env.coverage.sample_csr_access(1'b1, addr);
    dummy_data = '0;
  endtask

  task automatic csr_read32(bit [8:0] addr, output bit [31:0] data);
    logic [31:0] data_v;
    csr_vif.read32(addr, data_v);
    data = data_v;
    env.coverage.sample_csr_access(1'b0, addr);
  endtask

  task automatic csr_peek32(bit [8:0] addr, output bit [31:0] data);
    logic [31:0] data_v;
    csr_vif.read32(addr, data_v);
    data = data_v;
  endtask

  task automatic csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_CTRL, 32'h0000_0001);
  endtask

  task automatic csr_write_lane_drr_allowance(int lane_id, int unsigned allowance);
    bit [8:0] lane_base;
    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    csr_write32(lane_base + OPQ_CSR_LANE_WORD_DRR_ALLOWANCE, allowance[31:0]);
  endtask

  task automatic expect_csr_value(string what, bit [8:0] addr, int unsigned expected);
    bit [31:0] actual;
    csr_read32(addr, actual);
    if (actual !== expected[31:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR mismatch %s addr=0x%03h expected=0x%08h actual=0x%08h",
        what, addr, expected, actual
      ))
    end
  endtask

  task automatic expect_csr_nonzero(string what, bit [8:0] addr);
    bit [31:0] actual;
    csr_read32(addr, actual);
    if (actual == 32'h0000_0000) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR unexpectedly zero %s addr=0x%03h",
        what, addr
      ))
    end
  endtask

  task automatic check_csr_header_and_caps();
    bit [31:0] uid_word;
    bit [31:0] meta_word;
    bit [31:0] lane_mask_word;
    bit [31:0] status_word;
    bit [31:0] cap_word;

    csr_read32(OPQ_CSR_WORD_UID, uid_word);
    csr_read32(OPQ_CSR_WORD_META, meta_word);
    csr_read32(OPQ_CSR_WORD_LANE_MASK, lane_mask_word);
    csr_read32(OPQ_CSR_WORD_STATUS, status_word);
    csr_read32(OPQ_CSR_WORD_CAP, cap_word);

    if (uid_word !== 32'h4F50_514D) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR UID mismatch expected=0x4F50514D actual=0x%08h",
        uid_word
      ))
    end
    if (meta_word == 32'h0000_0000) begin
      `uvm_error(get_type_name(), "CSR META version page returned zero")
    end
    if (lane_mask_word !== 32'h0000_0000) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR lane mask should reset to zero, actual=0x%08h",
        lane_mask_word
      ))
    end
    if (status_word[OPQ_N_LANE-1:0] !== '0) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR status lane mask reset mismatch actual=0x%08h",
        status_word
      ))
    end
    if (cap_word[4:0] !== 5'h1F) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR capability feature bits mismatch actual=0x%08h",
        cap_word
      ))
    end
    if (cap_word[15:8] !== OPQ_CSR_LANE_REGION_STRIDE[7:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR capability lane stride mismatch expected=0x%02h actual=0x%02h",
        OPQ_CSR_LANE_REGION_STRIDE[7:0], cap_word[15:8]
      ))
    end
    if (cap_word[23:16] !== OPQ_CSR_LANE_REGION_BASE[7:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR capability lane base mismatch expected=0x%02h actual=0x%02h",
        OPQ_CSR_LANE_REGION_BASE[7:0], cap_word[23:16]
      ))
    end
    if (cap_word[31:24] !== OPQ_N_LANE[7:0]) begin
      `uvm_error(get_type_name(), $sformatf(
        "CSR capability lane count mismatch expected=%0d actual=%0d",
        OPQ_N_LANE, cap_word[31:24]
      ))
    end
  endtask

  task automatic check_lane_no_drop_and_credit(int lane_id, bit sample_default_drr = 1'b1);
    bit [8:0] lane_base;
    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    expect_csr_value($sformatf("lane%0d_wr_hdr", lane_id), lane_base + 9'h000,
      env.scoreboard.get_expected_lane_hdr_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_wr_shd", lane_id), lane_base + 9'h001,
      env.scoreboard.get_expected_lane_shd_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_wr_hit", lane_id), lane_base + 9'h002,
      env.scoreboard.get_expected_lane_hit_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_hdr", lane_id), lane_base + 9'h003,
      env.scoreboard.get_expected_lane_hdr_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_shd", lane_id), lane_base + 9'h004,
      env.scoreboard.get_expected_lane_shd_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_hit", lane_id), lane_base + 9'h005,
      env.scoreboard.get_expected_lane_hit_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_drop_hdr", lane_id), lane_base + 9'h006, 0);
    expect_csr_value($sformatf("lane%0d_drop_shd", lane_id), lane_base + 9'h007, 0);
    expect_csr_value($sformatf("lane%0d_drop_hit", lane_id), lane_base + 9'h008, 0);
    sample_lane_drop_snapshot(lane_id);
    sample_lane_credit_snapshot(lane_id, 1'b1);
    if (sample_default_drr) begin
      sample_lane_drr_snapshot(lane_id, OPQ_DRR_DEFAULT_ALLOWANCE, 1'b0, 1'b0);
    end
  endtask

  task automatic check_lane_drop_accounting_and_credit(int lane_id, bit require_full_credit = 1'b1);
    bit [8:0] lane_base;
    bit [31:0] drop_hdr_word;
    bit [31:0] drop_shd_word;
    bit [31:0] drop_hit_word;
    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    csr_read32(lane_base + 9'h006, drop_hdr_word);
    csr_read32(lane_base + 9'h007, drop_shd_word);
    csr_read32(lane_base + 9'h008, drop_hit_word);
    env.scoreboard.verify_lane_drop_totals(lane_id, drop_hdr_word, drop_shd_word, drop_hit_word);
    expect_csr_value($sformatf("lane%0d_wr_hdr", lane_id), lane_base + 9'h000,
      env.scoreboard.get_ingress_visible_lane_hdr_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_wr_shd", lane_id), lane_base + 9'h001,
      env.scoreboard.get_ingress_visible_lane_shd_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_wr_hit", lane_id), lane_base + 9'h002,
      env.scoreboard.get_ingress_visible_lane_hit_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_hdr", lane_id), lane_base + 9'h003,
      env.scoreboard.get_ingress_visible_lane_hdr_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_shd", lane_id), lane_base + 9'h004,
      env.scoreboard.get_ingress_visible_lane_shd_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_rd_hit", lane_id), lane_base + 9'h005,
      env.scoreboard.get_ingress_visible_lane_hit_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_drop_hdr", lane_id), lane_base + 9'h006,
      env.scoreboard.get_dropped_lane_hdr_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_drop_shd", lane_id), lane_base + 9'h007,
      env.scoreboard.get_dropped_lane_shd_cnt(lane_id));
    expect_csr_value($sformatf("lane%0d_drop_hit", lane_id), lane_base + 9'h008,
      env.scoreboard.get_dropped_lane_hit_cnt(lane_id));
    sample_lane_drop_snapshot(lane_id);
    sample_lane_credit_snapshot(lane_id, require_full_credit);
  endtask

  task automatic check_frame_table_counts();
    expect_csr_value("ft_rd_shd", OPQ_CSR_WORD_FT_RD_SHD, env.scoreboard.get_actual_egress_shd_cnt());
    expect_csr_value("ft_rd_hit", OPQ_CSR_WORD_FT_RD_HIT, env.scoreboard.get_actual_egress_hit_cnt());
    expect_csr_value("ft_drop_hdr", OPQ_CSR_WORD_FT_DROP_HDR, 0);
    expect_csr_value("ft_drop_shd", OPQ_CSR_WORD_FT_DROP_SHD, 0);
    expect_csr_value("ft_drop_hit", OPQ_CSR_WORD_FT_DROP_HIT, 0);
    sample_frame_table_drop_snapshot();
  endtask

  task automatic sample_lane_credit_snapshot(int lane_id, bit require_full);
    bit [8:0] lane_base;
    bit [31:0] lane_credit_word;
    bit [31:0] ticket_credit_word;

    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    csr_read32(lane_base + 9'h009, lane_credit_word);
    csr_read32(lane_base + 9'h00A, ticket_credit_word);

    if (lane_credit_word > OPQ_LANE_FIFO_MAX_CREDIT) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane%0d lane_credit overflow observed: %0d > %0d",
        lane_id, lane_credit_word, OPQ_LANE_FIFO_MAX_CREDIT
      ))
    end
    if (ticket_credit_word > OPQ_TICKET_FIFO_MAX_CREDIT) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane%0d ticket_credit overflow observed: %0d > %0d",
        lane_id, ticket_credit_word, OPQ_TICKET_FIFO_MAX_CREDIT
      ))
    end
    if (require_full) begin
      if (lane_credit_word !== OPQ_LANE_FIFO_MAX_CREDIT) begin
        `uvm_error(get_type_name(), $sformatf(
          "lane%0d lane_credit did not fully restore: expected=%0d actual=%0d",
          lane_id, OPQ_LANE_FIFO_MAX_CREDIT, lane_credit_word
        ))
      end
      if (ticket_credit_word !== OPQ_TICKET_FIFO_MAX_CREDIT) begin
        `uvm_error(get_type_name(), $sformatf(
          "lane%0d ticket_credit did not fully restore: expected=%0d actual=%0d",
          lane_id, OPQ_TICKET_FIFO_MAX_CREDIT, ticket_credit_word
        ))
      end
    end

    env.coverage.sample_credit_snapshot(lane_id, lane_credit_word, ticket_credit_word);
  endtask

  task automatic sample_lane_drop_snapshot(int lane_id);
    bit [8:0] lane_base;
    bit [31:0] hdr_drop_word;
    bit [31:0] shd_drop_word;
    bit [31:0] hit_drop_word;

    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    csr_read32(lane_base + 9'h006, hdr_drop_word);
    csr_read32(lane_base + 9'h007, shd_drop_word);
    csr_read32(lane_base + 9'h008, hit_drop_word);
    env.coverage.sample_drop_snapshot(
      opq_coverage::DROP_DOMAIN_LANE,
      lane_id,
      hdr_drop_word,
      shd_drop_word,
      hit_drop_word
    );
  endtask

  task automatic report_lane_hit_accounting_checkpoint(
    string label,
    bit require_drained = 1'b0
  );
    int unsigned total_accepted;
    int unsigned total_dropped;
    int unsigned total_delivered;
    int unsigned total_unexplained;

    total_accepted = 0;
    total_dropped = 0;
    total_delivered = 0;
    total_unexplained = 0;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      bit [31:0] drop_shd_word;
      bit [31:0] drop_hit_word;
      int unsigned expected_hits;
      int unsigned accepted_hits;
      int unsigned dropped_hits;
      int unsigned delivered_hits;
      int unsigned unexplained_hits;
      int unsigned loss_pct_x100;

      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      csr_read32(lane_base + 9'h007, drop_shd_word);
      csr_read32(lane_base + 9'h008, drop_hit_word);
      env.scoreboard.verify_lane_drop_totals(
        lane,
        env.scoreboard.get_dropped_lane_hdr_cnt(lane),
        drop_shd_word,
        drop_hit_word
      );

      expected_hits = env.scoreboard.get_expected_lane_hit_cnt(lane);
      accepted_hits = env.scoreboard.get_accepted_lane_hit_cnt(lane);
      dropped_hits = env.scoreboard.get_dropped_lane_hit_cnt(lane);
      delivered_hits = env.scoreboard.get_actual_lane_hit_cnt(lane);
      unexplained_hits = env.scoreboard.get_unexplained_lane_hit_cnt(lane);
      if (expected_hits == 0) begin
        loss_pct_x100 = 0;
      end else begin
        loss_pct_x100 = (dropped_hits * 10000) / expected_hits;
      end

      total_accepted += accepted_hits;
      total_dropped += dropped_hits;
      total_delivered += delivered_hits;
      total_unexplained += unexplained_hits;

      `uvm_info(get_type_name(), $sformatf(
        "%s lane%0d hit_ledger expected=%0d accepted=%0d dropped=%0d delivered=%0d unexplained=%0d drop_pct=%0d.%02d",
        label,
        lane,
        expected_hits,
        accepted_hits,
        dropped_hits,
        delivered_hits,
        unexplained_hits,
        loss_pct_x100 / 100,
        loss_pct_x100 % 100
      ), UVM_LOW)

      if (expected_hits != (dropped_hits + delivered_hits + unexplained_hits)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s lane%0d hit accounting mismatch expected=%0d accepted=%0d dropped=%0d delivered=%0d unexplained=%0d",
          label,
          lane,
          expected_hits,
          accepted_hits,
          dropped_hits,
          delivered_hits,
          unexplained_hits
        ))
      end
      if (accepted_hits != (delivered_hits + unexplained_hits)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s lane%0d accepted-hit mismatch accepted=%0d delivered=%0d unexplained=%0d",
          label,
          lane,
          accepted_hits,
          delivered_hits,
          unexplained_hits
        ))
      end
      if (require_drained && (unexplained_hits != 0)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s lane%0d expected drained hit ledger but still has %0d unexplained hits",
          label,
          lane,
          unexplained_hits
        ))
        env.scoreboard.dump_lane_unexplained_hits(lane, 24);
      end
    end

    `uvm_info(get_type_name(), $sformatf(
      "%s aggregate_hit_ledger accepted=%0d dropped=%0d delivered=%0d unexplained=%0d",
      label,
      total_accepted,
      total_dropped,
      total_delivered,
      total_unexplained
    ), UVM_LOW)
  endtask

  task automatic report_frame_table_accounting_checkpoint(
    string label,
    bit require_accounting_match = 1'b1
  );
    bit [31:0] ft_wr_hdr_word;
    bit [31:0] ft_wr_shd_word;
    bit [31:0] ft_wr_hit_word;
    bit [31:0] ft_rd_hdr_word;
    bit [31:0] ft_rd_shd_word;
    bit [31:0] ft_rd_hit_word;
    bit [31:0] ft_drop_hdr_word;
    bit [31:0] ft_drop_shd_word;
    bit [31:0] ft_drop_hit_word;

    csr_read32(OPQ_CSR_WORD_FT_WR_HDR, ft_wr_hdr_word);
    csr_read32(OPQ_CSR_WORD_FT_WR_SHD, ft_wr_shd_word);
    csr_read32(OPQ_CSR_WORD_FT_WR_HIT, ft_wr_hit_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_HDR, ft_rd_hdr_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_SHD, ft_rd_shd_word);
    csr_read32(OPQ_CSR_WORD_FT_RD_HIT, ft_rd_hit_word);
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

    `uvm_info(get_type_name(), $sformatf(
      "%s frame_table_ledger wr_hdr=%0d rd_hdr=%0d drop_hdr=%0d wr_shd=%0d rd_shd=%0d drop_shd=%0d wr_hit=%0d rd_hit=%0d drop_hit=%0d",
      label,
      ft_wr_hdr_word,
      ft_rd_hdr_word,
      ft_drop_hdr_word,
      ft_wr_shd_word,
      ft_rd_shd_word,
      ft_drop_shd_word,
      ft_wr_hit_word,
      ft_rd_hit_word,
      ft_drop_hit_word
    ), UVM_LOW)

    if (require_accounting_match) begin
      if (ft_wr_hdr_word !== (ft_rd_hdr_word + ft_drop_hdr_word)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s ft_wr_hdr accounting mismatch wr=%0d rd=%0d drop=%0d",
          label,
          ft_wr_hdr_word,
          ft_rd_hdr_word,
          ft_drop_hdr_word
        ))
      end
      if (ft_wr_shd_word !== (ft_rd_shd_word + ft_drop_shd_word)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s ft_wr_shd accounting mismatch wr=%0d rd=%0d drop=%0d",
          label,
          ft_wr_shd_word,
          ft_rd_shd_word,
          ft_drop_shd_word
        ))
      end
      if (ft_wr_hit_word !== (ft_rd_hit_word + ft_drop_hit_word)) begin
        `uvm_error(get_type_name(), $sformatf(
          "%s ft_wr_hit accounting mismatch wr=%0d rd=%0d drop=%0d",
          label,
          ft_wr_hit_word,
          ft_rd_hit_word,
          ft_drop_hit_word
        ))
      end
    end
  endtask

  task automatic report_core_principle_checkpoint(
    string label,
    bit require_drained = 1'b0,
    bit require_ft_match = 1'b1
  );
    bit hit_conservation_ok;
    bit accepted_delivery_ok;
    bit drained_ok;
    bit ft_ownership_ok;
    string first_break;

    hit_conservation_ok = 1'b1;
    accepted_delivery_ok = 1'b1;
    drained_ok = 1'b1;
    ft_ownership_ok = 1'b1;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      bit [31:0] drop_shd_word;
      bit [31:0] drop_hit_word;
      int unsigned expected_hits;
      int unsigned accepted_hits;
      int unsigned dropped_hits;
      int unsigned delivered_hits;
      int unsigned unexplained_hits;

      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      csr_read32(lane_base + 9'h007, drop_shd_word);
      csr_read32(lane_base + 9'h008, drop_hit_word);

      expected_hits = env.scoreboard.get_expected_lane_hit_cnt(lane);
      accepted_hits = env.scoreboard.get_accepted_lane_hit_cnt(lane);
      dropped_hits = drop_hit_word;
      delivered_hits = env.scoreboard.get_actual_lane_hit_cnt(lane);
      unexplained_hits = env.scoreboard.get_unexplained_lane_hit_cnt(lane);

      if (expected_hits != (dropped_hits + delivered_hits + unexplained_hits)) begin
        hit_conservation_ok = 1'b0;
      end
      if (accepted_hits != (delivered_hits + unexplained_hits)) begin
        accepted_delivery_ok = 1'b0;
      end
      if (require_drained && (unexplained_hits != 0)) begin
        drained_ok = 1'b0;
      end
    end

    if (require_ft_match) begin
      bit [31:0] ft_wr_hdr_word;
      bit [31:0] ft_wr_shd_word;
      bit [31:0] ft_wr_hit_word;
      bit [31:0] ft_rd_hdr_word;
      bit [31:0] ft_rd_shd_word;
      bit [31:0] ft_rd_hit_word;
      bit [31:0] ft_drop_hdr_word;
      bit [31:0] ft_drop_shd_word;
      bit [31:0] ft_drop_hit_word;

      csr_read32(OPQ_CSR_WORD_FT_WR_HDR, ft_wr_hdr_word);
      csr_read32(OPQ_CSR_WORD_FT_WR_SHD, ft_wr_shd_word);
      csr_read32(OPQ_CSR_WORD_FT_WR_HIT, ft_wr_hit_word);
      csr_read32(OPQ_CSR_WORD_FT_RD_HDR, ft_rd_hdr_word);
      csr_read32(OPQ_CSR_WORD_FT_RD_SHD, ft_rd_shd_word);
      csr_read32(OPQ_CSR_WORD_FT_RD_HIT, ft_rd_hit_word);
      csr_read32(OPQ_CSR_WORD_FT_DROP_HDR, ft_drop_hdr_word);
      csr_read32(OPQ_CSR_WORD_FT_DROP_SHD, ft_drop_shd_word);
      csr_read32(OPQ_CSR_WORD_FT_DROP_HIT, ft_drop_hit_word);

      if ((ft_wr_hdr_word !== (ft_rd_hdr_word + ft_drop_hdr_word)) ||
          (ft_wr_shd_word !== (ft_rd_shd_word + ft_drop_shd_word)) ||
          (ft_wr_hit_word !== (ft_rd_hit_word + ft_drop_hit_word))) begin
        ft_ownership_ok = 1'b0;
      end
    end

    if (!ft_ownership_ok) begin
      first_break = "frame_table_ownership";
    end else if (!hit_conservation_ok) begin
      first_break = "hit_conservation";
    end else if (!accepted_delivery_ok) begin
      first_break = "accepted_delivery";
    end else if (!drained_ok) begin
      first_break = "drain_not_closed";
    end else begin
      first_break = "clean";
    end

    `uvm_info(get_type_name(), $sformatf(
      "%s core_principles first_break=%s ft_ownership=%s hit_conservation=%s accepted_delivery=%s drained=%s",
      label,
      first_break,
      ft_ownership_ok ? "ok" : "bad",
      hit_conservation_ok ? "ok" : "bad",
      accepted_delivery_ok ? "ok" : "bad",
      drained_ok ? "ok" : "bad"
    ), UVM_LOW)
  endtask

  task automatic read_lane_drr_snapshot(
    int lane_id,
    output int unsigned allowance_word,
    output int unsigned quantum_word,
    output int unsigned grant_cnt_word,
    output int unsigned beat_cnt_word,
    output int unsigned defer_cnt_word
  );
    bit [8:0] lane_base;
    bit [31:0] allowance_word_raw;
    bit [31:0] quantum_word_raw;
    bit [31:0] grant_cnt_word_raw;
    bit [31:0] beat_cnt_word_raw;
    bit [31:0] defer_cnt_word_raw;

    lane_base = OPQ_CSR_LANE_REGION_BASE + lane_id * OPQ_CSR_LANE_REGION_STRIDE;
    csr_read32(lane_base + OPQ_CSR_LANE_WORD_DRR_ALLOWANCE, allowance_word_raw);
    csr_read32(lane_base + OPQ_CSR_LANE_WORD_DRR_QUANTUM, quantum_word_raw);
    csr_read32(lane_base + OPQ_CSR_LANE_WORD_DRR_GRANT_CNT, grant_cnt_word_raw);
    csr_read32(lane_base + OPQ_CSR_LANE_WORD_DRR_BEAT_CNT, beat_cnt_word_raw);
    csr_read32(lane_base + OPQ_CSR_LANE_WORD_DRR_DEFER_CNT, defer_cnt_word_raw);

    allowance_word = allowance_word_raw;
    quantum_word = quantum_word_raw;
    grant_cnt_word = grant_cnt_word_raw;
    beat_cnt_word = beat_cnt_word_raw;
    defer_cnt_word = defer_cnt_word_raw;
  endtask

  task automatic sample_lane_drr_snapshot(
    int lane_id,
    int expected_allowance = -1,
    bit require_nonzero_service = 1'b0,
    bit require_nonzero_defer = 1'b0
  );
    int unsigned allowance_word;
    int unsigned quantum_word;
    int unsigned grant_cnt_word;
    int unsigned beat_cnt_word;
    int unsigned defer_cnt_word;

    read_lane_drr_snapshot(
      lane_id,
      allowance_word,
      quantum_word,
      grant_cnt_word,
      beat_cnt_word,
      defer_cnt_word
    );

    if ((expected_allowance >= 0) && (allowance_word !== expected_allowance[31:0])) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane%0d DRR allowance mismatch expected=%0d actual=%0d",
        lane_id, expected_allowance, allowance_word
      ))
    end
    if (require_nonzero_service) begin
      if ((grant_cnt_word == 0) || (beat_cnt_word == 0)) begin
        `uvm_error(get_type_name(), $sformatf(
          "lane%0d expected non-zero DRR service counters, grant=%0d beat=%0d",
          lane_id, grant_cnt_word, beat_cnt_word
        ))
      end
    end
    if (require_nonzero_defer && (defer_cnt_word == 0)) begin
      `uvm_error(get_type_name(), $sformatf(
        "lane%0d expected non-zero DRR defer counter",
        lane_id
      ))
    end

    env.coverage.sample_drr_snapshot(
      lane_id,
      allowance_word,
      quantum_word,
      grant_cnt_word,
      beat_cnt_word,
      defer_cnt_word
    );
  endtask

  task automatic sample_frame_table_drop_snapshot();
    bit [31:0] hdr_drop_word;
    bit [31:0] shd_drop_word;
    bit [31:0] hit_drop_word;

    csr_read32(OPQ_CSR_WORD_FT_DROP_HDR, hdr_drop_word);
    csr_read32(OPQ_CSR_WORD_FT_DROP_SHD, shd_drop_word);
    csr_read32(OPQ_CSR_WORD_FT_DROP_HIT, hit_drop_word);
    env.coverage.sample_drop_snapshot(
      opq_coverage::DROP_DOMAIN_FTABLE,
      -1,
      hdr_drop_word,
      shd_drop_word,
      hit_drop_word
    );
  endtask

  task automatic poll_lane_credits(int sample_count, time interval_t);
    for (int sample_idx = 0; sample_idx < sample_count; sample_idx++) begin
      #(interval_t);
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        sample_lane_credit_snapshot(lane, 1'b0);
      end
    end
  endtask

  task automatic dump_lane_credit_snapshot(string tag = "credit_snapshot");
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [8:0] lane_base;
      bit [31:0] lane_credit_word;
      bit [31:0] ticket_credit_word;

      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      csr_peek32(lane_base + 9'h009, lane_credit_word);
      csr_peek32(lane_base + 9'h00A, ticket_credit_word);
      `uvm_info(get_type_name(), $sformatf(
        "%s lane%0d lane_credit=%0d/%0d ticket_credit=%0d/%0d",
        tag,
        lane,
        lane_credit_word,
        OPQ_LANE_FIFO_MAX_CREDIT,
        ticket_credit_word,
        OPQ_TICKET_FIFO_MAX_CREDIT
      ), UVM_LOW)
    end
  endtask

  task automatic dump_dut_status_snapshot(string tag = "dut_status");
    bit [31:0] status_word;

    csr_peek32(OPQ_CSR_WORD_STATUS, status_word);
    `uvm_info(get_type_name(), $sformatf(
      "%s lane_mask=0x%0h page_allocator_active=%0b arbiter_active=%0b egress_valid=%0b lane_mask_effective=%0b n_lane=%0d",
      tag,
      status_word[OPQ_N_LANE-1:0],
      status_word[16],
      status_word[17],
      status_word[18],
      status_word[19],
      status_word[23:20]
    ), UVM_LOW)
  endtask

  task automatic wait_for_credit_restore(
    string tag = "drain",
    time timeout_t = 500us,
    time poll_t = 500ns
  );
    bit drained;
    bit dut_idle;
    bit egress_idle;
    int stable_samples;
    time deadline;

    deadline = $time + timeout_t;
    stable_samples = 0;

    while ($time < deadline) begin
      drained = 1'b1;
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        bit [8:0] lane_base;
        bit [31:0] lane_credit_word;
        bit [31:0] ticket_credit_word;

        lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
        csr_peek32(lane_base + 9'h009, lane_credit_word);
        csr_peek32(lane_base + 9'h00A, ticket_credit_word);
        if ((lane_credit_word != OPQ_LANE_FIFO_MAX_CREDIT) ||
            (ticket_credit_word != OPQ_TICKET_FIFO_MAX_CREDIT)) begin
          drained = 1'b0;
          break;
        end
      end

      if (drained) begin
        bit [31:0] status_word;

        csr_peek32(OPQ_CSR_WORD_STATUS, status_word);
        // Continuous-frame signoff needs the page allocator and effective lane
        // mask to settle between composed cases; the exported arbiter-active
        // bit remains asserted in some fully drained idle states.
        dut_idle = (status_word[16] == 1'b0) &&
                   (status_word[19] == 1'b0);
        egress_idle = (status_word[18] == 1'b0) &&
                      (env.egress_vif.valid !== 1'b1);
        if (dut_idle && egress_idle) begin
          stable_samples++;
        end else begin
          stable_samples = 0;
        end
        if (stable_samples >= 2) begin
          return;
        end
      end else begin
        stable_samples = 0;
      end

      #(poll_t);
    end

    `uvm_error(get_type_name(), $sformatf(
      "%s timed out waiting for lane/ticket credit restore after %0t",
      tag, timeout_t
    ))
    dump_lane_credit_snapshot({tag, "_timeout"});
    dump_dut_status_snapshot({tag, "_timeout"});
    poll_lane_credits(4, 500ns);
    report_lane_hit_accounting_checkpoint({tag, "_timeout"}, 1'b0);
    report_core_principle_checkpoint({tag, "_timeout"}, 1'b0, 1'b1);
  endtask

  task automatic wait_for_ingress_idle(
    string tag = "ingress_idle",
    time timeout_t = 500us,
    time poll_t = 500ns
  );
    bit ingress_idle;
    int stable_samples;
    time deadline;

    deadline = $time + timeout_t;
    stable_samples = 0;

    while ($time < deadline) begin
      ingress_idle = 1'b1;
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        if (!env.ingress_agent[lane].drv.is_idle() ||
            env.ingress_agent[lane].seqr.has_do_available()) begin
          ingress_idle = 1'b0;
          break;
        end
      end

      if (ingress_idle) begin
        stable_samples++;
        if (stable_samples >= 2) begin
          return;
        end
      end else begin
        stable_samples = 0;
      end

      #(poll_t);
    end

    `uvm_error(get_type_name(), $sformatf(
      "%s timed out waiting for ingress drivers to go idle after %0t",
      tag, timeout_t
    ))
  endtask

  task run_phase(uvm_phase phase);
    time holdoff;

    phase.raise_objection(this);
    check_csr_header_and_caps();
    run_main_sequence();
    holdoff = dwell_time();
    #(holdoff);
    run_post_sequence_checks();
    phase.drop_objection(this);
  endtask
endclass

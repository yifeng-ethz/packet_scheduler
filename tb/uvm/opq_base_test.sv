//------------------------------------------------------------------------------
// IP Name   : opq_base_test
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - active base test for OPQ UVM harness
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

  task automatic csr_clear_counters();
    csr_write32(OPQ_CSR_WORD_CTRL, 32'h0000_0001);
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
    if (cap_word[3:0] !== 4'hF) begin
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

  task automatic check_lane_no_drop_and_credit(int lane_id);
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

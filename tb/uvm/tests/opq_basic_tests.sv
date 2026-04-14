class opq_basic_smoke_test extends opq_base_test;
  `uvm_component_utils(opq_basic_smoke_test)

  function new(string name = "opq_basic_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
  endfunction

  virtual task run_main_sequence();
    opq_basic_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_basic_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
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

class opq_basic_ts_boundary_test extends opq_base_test;
  `uvm_component_utils(opq_basic_ts_boundary_test)

  function new(string name = "opq_basic_ts_boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
  endfunction

  virtual task run_main_sequence();
    opq_boundary_ts_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_boundary_ts_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
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

class opq_basic_subheader_shape_test extends opq_base_test;
  `uvm_component_utils(opq_basic_subheader_shape_test)

  function new(string name = "opq_basic_subheader_shape_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    return cfg;
  endfunction

  virtual task run_main_sequence();
    opq_subheader_shape_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_subheader_shape_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
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

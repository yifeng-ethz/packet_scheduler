class opq_cross_bp_credit_test extends opq_base_test;
  `uvm_component_utils(opq_cross_bp_credit_test)

  function new(string name = "opq_cross_bp_credit_test", uvm_component parent = null);
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

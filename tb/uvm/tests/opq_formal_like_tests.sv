//------------------------------------------------------------------------------
// IP Name   : opq_formal_like_tests
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.4 - keep stable wrapper-facing fallback test names for a later qverify backend swap
// Description:
//   Directed long-running stress tests that exercise the same packet-shape
//   contracts as the dedicated formal SVA when a real proof backend is not
//   available on the host.
//------------------------------------------------------------------------------
// These thin subclasses are the stable wrapper-facing entry points for the
// current simulation-backed fallback. A later qverify/znformal flow can reuse
// the same names while swapping in proof-oriented harness internals.
class opq_formal_like_ingress_recovery_stress_test extends opq_error_subheader_mask_recovery_test;
  `uvm_component_utils(opq_formal_like_ingress_recovery_stress_test)

  function new(string name = "opq_formal_like_ingress_recovery_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class opq_formal_like_mover_drr_credit_stress_test extends opq_cross_drr_allowance_test;
  `uvm_component_utils(opq_formal_like_mover_drr_credit_stress_test)

  function new(string name = "opq_formal_like_mover_drr_credit_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class opq_formal_like_egress_flush_backpressure_stress_test extends opq_base_test;
  `uvm_component_utils(opq_formal_like_egress_flush_backpressure_stress_test)

  function new(string name = "opq_formal_like_egress_flush_backpressure_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b0;
    cfg.allow_drop_accounting = 1'b1;
    cfg.require_egress_preamble = 1'b0;
    cfg.min_sop_count = 0;
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

    seq = opq_soak_virtual_sequence::type_id::create("seq");
    seq.frame_count = 40;

    bp_seq = opq_bp_sequence::type_id::create("bp_seq");

    bp_item = opq_bp_item::type_id::create("bp_item_periodic");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 6;
    bp_item.low_cycles = 6;
    bp_item.repeat_count = 40;
    bp_seq.items.push_back(bp_item);

    bp_item = opq_bp_item::type_id::create("bp_item_flush_window");
    bp_item.mode = BP_ALWAYS_STALL;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 16_384;
    bp_item.repeat_count = 1;
    bp_seq.items.push_back(bp_item);

    bp_item = opq_bp_item::type_id::create("bp_item_toggle_tail");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 1;
    bp_item.low_cycles = 1;
    bp_item.repeat_count = 32;
    bp_seq.items.push_back(bp_item);

    fork
      begin
        seq.start(env.vseqr);
      end
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #2us;
        poll_lane_credits(40, 2us);
      end
    join
  endtask

  virtual task run_post_sequence_checks();
    bit [31:0] ft_drop_hdr_word;
    bit [31:0] ft_drop_shd_word;
    bit [31:0] ft_drop_hit_word;
    int unsigned total_ft_drop;

    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      sample_lane_drop_snapshot(lane);
      sample_lane_credit_snapshot(lane, 1'b0);
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

    total_ft_drop = ft_drop_hdr_word + ft_drop_shd_word + ft_drop_hit_word;
    if (total_ft_drop == 0) begin
      `uvm_error(get_type_name(),
        "Expected frame-table drop or flush activity during formal-like egress stress, but all FT drop counters stayed zero")
    end
  endtask
endclass

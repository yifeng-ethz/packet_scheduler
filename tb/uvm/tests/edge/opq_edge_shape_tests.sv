class opq_edge_max_hits_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_max_hits_test)

  function new(string name = "opq_edge_max_hits_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 250us;
  endfunction

  virtual task run_main_sequence();
    opq_max_hits_virtual_sequence seq;
    csr_clear_counters();
    seq = opq_max_hits_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask
endclass

class opq_edge_max_hits_backpressure_test extends opq_no_drop_test_base;
  `uvm_component_utils(opq_edge_max_hits_backpressure_test)

  function new(string name = "opq_edge_max_hits_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function time dwell_time();
    return 700us;
  endfunction

  virtual task run_main_sequence();
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;
    opq_max_hits_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_max_hits_virtual_sequence::type_id::create("seq");
    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = 6;
    bp_item.low_cycles = 4;
    bp_item.repeat_count = 20;
    bp_seq.items.push_back(bp_item);

    fork
      seq.start(env.vseqr);
      begin
        #1us;
        bp_seq.start(env.vseqr.egress_seqr);
      end
      begin
        #12us;
        poll_lane_credits(16, 8us);
      end
    join
  endtask
endclass

class opq_edge_overlimit_one_loss_test extends opq_base_test;
  `uvm_component_utils(opq_edge_overlimit_one_loss_test)

  function new(string name = "opq_edge_overlimit_one_loss_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.allow_drop_accounting = 1'b1;
    return cfg;
  endfunction

  virtual function time dwell_time();
    return 350us;
  endfunction

  virtual task run_main_sequence();
    opq_overlimit_one_loss_virtual_sequence seq;

    csr_clear_counters();
    seq = opq_overlimit_one_loss_virtual_sequence::type_id::create("seq");
    seq.start(env.vseqr);
  endtask

  virtual task run_post_sequence_checks();
    bit [8:0] lane_base;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
      if (lane == 0) begin
        check_lane_drop_accounting_and_credit(lane);
        expect_csr_value($sformatf("lane%0d_limit_drop_shd", lane), lane_base + 9'h007, 0);
        expect_csr_value($sformatf("lane%0d_limit_drop_hit", lane), lane_base + 9'h008, 1);
      end else begin
        check_lane_no_drop_and_credit(lane);
      end
    end
    check_frame_table_counts();
  endtask
endclass

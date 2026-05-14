class opq_no_drop_test_base extends opq_base_test;
  function new(string name = "opq_no_drop_test_base", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function opq_scoreboard_cfg create_scoreboard_cfg();
    opq_scoreboard_cfg cfg;
    cfg = super.create_scoreboard_cfg();
    cfg.check_hit_integrity = 1'b1;
    cfg.strict_packet_format = 1'b1;
    cfg.require_egress_preamble = 1'b1;
    return cfg;
  endfunction

  virtual task run_post_sequence_checks();
    super.run_post_sequence_checks();
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      check_lane_no_drop_and_credit(lane);
    end
    check_frame_table_counts();
  endtask
endclass

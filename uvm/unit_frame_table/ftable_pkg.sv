package ftable_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Must match the DUT instance in ftable_uvm_tb.sv.
  localparam int unsigned N_LANE = 2;
  localparam int unsigned PAGE_RAM_DEPTH = 512;
  localparam int unsigned DATA_W = 40;

  localparam int unsigned HDR_SIZE = 5;
  localparam int unsigned SHD_SIZE = 1;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned TRL_SIZE = 1;

  function automatic int unsigned calc_total_words(int unsigned shr_cnt, int unsigned hit_cnt);
    return HDR_SIZE + (shr_cnt * SHD_SIZE) + (hit_cnt * HIT_SIZE) + TRL_SIZE;
  endfunction

  localparam bit [7:0] K285 = 8'hBC;
  localparam bit [7:0] K284 = 8'h9C;

  function automatic bit [DATA_W-1:0] make_word(int unsigned pkt_id, int unsigned word_idx, int unsigned total_words);
    bit [DATA_W-1:0] w;
    w = '0;
    // Match the split presenter: SOP/EOP are derived from K285/K284 markers.
    // [35:32] byte_is_k (0001) + [7:0] K-code.
    w[39:36] = 4'hA;
    w[31:16] = pkt_id[15:0];
    if (word_idx == 0) begin
      w[35:32] = 4'b0001;
      w[15:8]  = word_idx[7:0];
      w[7:0]   = K285;
    end else if ((total_words > 0) && (word_idx == (total_words - 1))) begin
      w[35:32] = 4'b0001;
      w[15:8]  = word_idx[7:0];
      w[7:0]   = K284;
    end else begin
      w[35:32] = 4'b0000;
      w[15:0]  = word_idx[15:0];
    end
    return w;
  endfunction

  function automatic int unsigned parse_pkt_id(bit [DATA_W-1:0] w);
    return int'(w[31:16]);
  endfunction

  class ftable_pkt extends uvm_sequence_item;
    rand int unsigned pkt_id;
    rand int unsigned start_addr;
    rand int unsigned shr_cnt;
    rand int unsigned hit_cnt;
    rand bit force_invalid;
    rand bit is_dummy;
    rand int unsigned idle_cycles;

    constraint c_defaults {
      is_dummy inside {0, 1};
      force_invalid inside {0, 1};
      idle_cycles inside {[0:8]};
      shr_cnt inside {[0:32]};
      hit_cnt inside {[0:255]};
      start_addr < PAGE_RAM_DEPTH;
    }

    `uvm_object_utils_begin(ftable_pkt)
      `uvm_field_int(pkt_id, UVM_DEFAULT)
      `uvm_field_int(start_addr, UVM_DEFAULT)
      `uvm_field_int(shr_cnt, UVM_DEFAULT)
      `uvm_field_int(hit_cnt, UVM_DEFAULT)
      `uvm_field_int(force_invalid, UVM_DEFAULT)
      `uvm_field_int(is_dummy, UVM_DEFAULT)
      `uvm_field_int(idle_cycles, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "ftable_pkt");
      super.new(name);
    endfunction
  endclass

  class ftable_obs_pkt extends uvm_sequence_item;
    int unsigned pkt_id;
    bit [DATA_W-1:0] words[$];

    `uvm_object_utils(ftable_obs_pkt)
    function new(string name = "ftable_obs_pkt");
      super.new(name);
    endfunction
  endclass

  class ftable_sequencer extends uvm_sequencer #(ftable_pkt);
    `uvm_component_utils(ftable_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class ftable_driver extends uvm_driver #(ftable_pkt);
    `uvm_component_utils(ftable_driver)
    virtual ftable_if vif;
    uvm_analysis_port #(ftable_pkt) exp_ap;

    ftable_pkt prev_pkt;
    bit prev_valid;
    bit prev_blocked;
    bit pktdbg_en;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      exp_ap = new("exp_ap", this);
      prev_pkt = null;
      prev_valid = 1'b0;
      prev_blocked = 1'b0;
      pktdbg_en = 1'b0;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ftable_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ftable_driver: virtual interface not set")
      end
      begin
        int tmp;
        if ($value$plusargs("PKTDBG=%d", tmp)) pktdbg_en = (tmp != 0);
      end
    endfunction

    task automatic wait_cycles(int unsigned n);
      repeat (n) @(posedge vif.clk);
    endtask

    task automatic wait_mapper_idle(int unsigned timeout_cyc = 2000);
      int unsigned waited = 0;
      while (vif.rst || (vif.mapper_state !== 3'b000)) begin
        @(posedge vif.clk);
        if (!vif.rst) begin
          waited++;
          if (waited > timeout_cyc) begin
            `uvm_fatal("MAPTIMEOUT", $sformatf("Mapper did not return IDLE within %0d cycles (state=%b)",
              timeout_cyc, vif.mapper_state))
          end
        end else begin
          waited = 0;
        end
      end
    endtask

    task automatic drive_head_start(ftable_pkt p);
      // Let implicit truncation handle sizing (older ModelSim SV parsers can be picky about slicing expressions).
      vif.pa_frame_start_addr <= p.start_addr;
      vif.pa_frame_shr_cnt_this <= (p.shr_cnt * N_LANE);
      vif.pa_frame_hit_cnt_this <= p.hit_cnt;
      vif.pa_write_head_start <= 1'b1;
      @(posedge vif.clk);
      vif.pa_write_head_start <= 1'b0;
    endtask

    task automatic drive_tail_done(ftable_pkt p, bit blocked);
      bit drop_pkt;
      drop_pkt = p.force_invalid || blocked;

      vif.pa_frame_start_addr_last <= p.start_addr;
      vif.pa_frame_shr_cnt <= p.shr_cnt;
      vif.pa_frame_hit_cnt <= p.hit_cnt;
      vif.pa_frame_invalid_last <= drop_pkt;
      vif.pa_write_tail_active <= 1'b0;

      vif.pa_write_tail_done <= 1'b1;
      @(posedge vif.clk);
      vif.pa_write_tail_done <= 1'b0;

      if (!drop_pkt) begin
        ftable_pkt exp;
        exp = ftable_pkt::type_id::create("exp");
        exp.copy(p);
        if (pktdbg_en && ((exp.pkt_id == 61) || (exp.pkt_id == 74) || (exp.pkt_id == 128) || (exp.pkt_id == 139))) begin
          int unsigned tw;
          tw = calc_total_words(exp.shr_cnt, exp.hit_cnt);
          `uvm_info("PKTDBG", $sformatf("EXPECT pkt_id=%0d start_addr=%0d shr_cnt=%0d hit_cnt=%0d total_words=%0d",
            exp.pkt_id, exp.start_addr, exp.shr_cnt, exp.hit_cnt, tw), UVM_LOW)
        end
        exp_ap.write(exp);
      end else begin
        `uvm_info("DROP", $sformatf("Dropped pkt_id=%0d (force_invalid=%0b blocked=%0b)",
          p.pkt_id, p.force_invalid, blocked), UVM_LOW)
      end
    endtask

    task automatic write_packet_words(ftable_pkt p, output bit blocked_seen);
      int unsigned total_words;
      blocked_seen = 1'b0;
      total_words = calc_total_words(p.shr_cnt, p.hit_cnt);

      for (int unsigned idx = 0; idx < total_words; idx++) begin
        int unsigned addr;
        addr = (p.start_addr + idx) % PAGE_RAM_DEPTH;
        vif.page_ram_we <= 1'b1;
        vif.page_ram_wr_addr <= addr;
        vif.page_ram_wr_data <= make_word(p.pkt_id, idx, total_words);

        if (vif.wr_blocked_by_rd_lock) blocked_seen = 1'b1;
        @(posedge vif.clk);
      end
      vif.page_ram_we <= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
      ftable_pkt req;
      wait (vif.rst == 1'b0);
      vif.drive_idle();
      wait_mapper_idle();

      forever begin
        seq_item_port.get_next_item(req);

        // Head-start always issues (even for the final dummy flush item).
        drive_head_start(req);

        // Allow the mapper to complete its update for the new head.
        wait_mapper_idle();
        wait_cycles(1);

        // Finalize the previous packet only after the next head-start has advanced the mapper pipe.
        if (prev_valid) begin
          wait_mapper_idle();
          drive_tail_done(prev_pkt, prev_blocked);
          prev_valid = 1'b0;
          prev_blocked = 1'b0;
          wait_mapper_idle();
        end

        if (!req.is_dummy) begin
          bit blocked;
          if (pktdbg_en && ((req.pkt_id == 61) || (req.pkt_id == 74) || (req.pkt_id == 128) || (req.pkt_id == 139))) begin
            int unsigned tw;
            tw = calc_total_words(req.shr_cnt, req.hit_cnt);
            `uvm_info("PKTDBG", $sformatf("WRITE pkt_id=%0d start_addr=%0d shr_cnt=%0d hit_cnt=%0d total_words=%0d",
              req.pkt_id, req.start_addr, req.shr_cnt, req.hit_cnt, tw), UVM_LOW)
          end
          write_packet_words(req, blocked);

          prev_pkt = req;
          prev_valid = 1'b1;
          prev_blocked = blocked;
          wait_cycles(req.idle_cycles);
        end else begin
          // Dummy flush item does not create a new pending packet.
          wait_cycles(req.idle_cycles);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass

  class ftable_egress_monitor extends uvm_component;
    `uvm_component_utils(ftable_egress_monitor)
    virtual ftable_if vif;
    uvm_analysis_port #(ftable_obs_pkt) ap;

    bit in_pkt;
    bit [DATA_W-1:0] cur_words[$];

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
      in_pkt = 1'b0;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ftable_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ftable_egress_monitor: virtual interface not set")
      end
    endfunction

    task run_phase(uvm_phase phase);
      wait (vif.rst == 1'b0);
      forever begin
        @(posedge vif.clk);
        if (vif.rst) begin
          in_pkt = 1'b0;
          cur_words.delete();
          continue;
        end

        if (vif.egress_valid && vif.egress_ready) begin
          if (vif.egress_sop) begin
            if (in_pkt) `uvm_error("EGRESS", "SOP while already in packet")
            in_pkt = 1'b1;
            cur_words.delete();
          end

          if (!in_pkt) `uvm_error("EGRESS", "Data beat without SOP context")
          cur_words.push_back(vif.egress_data);

          if (vif.egress_eop) begin
            ftable_obs_pkt obs;
            obs = ftable_obs_pkt::type_id::create("obs", this);
            obs.words = cur_words;
            if (cur_words.size() > 0) obs.pkt_id = parse_pkt_id(cur_words[0]);
            ap.write(obs);
            in_pkt = 1'b0;
            cur_words.delete();
          end
        end
      end
    endtask
  endclass

  class ftable_scoreboard extends uvm_component;
    `uvm_component_utils(ftable_scoreboard)

    uvm_tlm_analysis_fifo #(ftable_pkt) exp_fifo;
    uvm_tlm_analysis_fifo #(ftable_obs_pkt) obs_fifo;

    bit allow_skip;
    int unsigned allow_skip_max;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      exp_fifo = new("exp_fifo", this);
      obs_fifo = new("obs_fifo", this);
      allow_skip = 1'b0;
      allow_skip_max = 32;
      begin
        int tmp;
        if ($value$plusargs("ALLOW_SKIP=%d", tmp)) allow_skip = (tmp != 0);
      end
      void'($value$plusargs("ALLOW_SKIP_MAX=%d", allow_skip_max));
    endfunction

    task automatic compare_pkt(ftable_pkt exp, ftable_obs_pkt obs);
      int unsigned exp_words;
      exp_words = calc_total_words(exp.shr_cnt, exp.hit_cnt);
      if (obs.words.size() != exp_words) begin
        int unsigned cmp_words;
        int unsigned first_bad;
        bit [DATA_W-1:0] last_w;
        int unsigned last_word_idx;
        int unsigned last_pkt_id;
        bit [DATA_W-1:0] bad_w;
        int unsigned bad_pkt_id;

        cmp_words = (obs.words.size() < exp_words) ? obs.words.size() : exp_words;
        first_bad = cmp_words;
        for (int unsigned i = 0; i < cmp_words; i++) begin
          bit [DATA_W-1:0] exp_w;
          exp_w = make_word(exp.pkt_id, i, exp_words);
          if (obs.words[i] !== exp_w) begin
            first_bad = i;
            break;
          end
        end

        last_w = (obs.words.size() > 0) ? obs.words[obs.words.size() - 1] : '0;
        last_word_idx = last_w[15:8];
        last_pkt_id = int'(last_w[31:16]);

        bad_w = (first_bad < obs.words.size()) ? obs.words[first_bad] : '0;
        bad_pkt_id = int'(bad_w[31:16]);

        `uvm_error("MISMATCH", $sformatf(
          "Len mismatch exp_pkt_id=%0d obs_pkt_id=%0d exp=%0d got=%0d first_bad_idx=%0d bad_pkt_id=%0d obs_last_pkt_id=%0d obs_last_idx=%0d obs_last_k=0x%0h",
          exp.pkt_id, obs.pkt_id, exp_words, obs.words.size(), first_bad, bad_pkt_id, last_pkt_id, last_word_idx, last_w[7:0]))
        return;
      end
      if (obs.pkt_id != exp.pkt_id) begin
        `uvm_error("MISMATCH", $sformatf("ID mismatch exp=%0d got=%0d", exp.pkt_id, obs.pkt_id))
        return;
      end
      for (int unsigned i = 0; i < exp_words; i++) begin
        bit [DATA_W-1:0] exp_w;
        exp_w = make_word(exp.pkt_id, i, exp_words);
        if (obs.words[i] !== exp_w) begin
          `uvm_error("MISMATCH", $sformatf("Word mismatch pkt_id=%0d idx=%0d exp=0x%0h got=0x%0h",
            exp.pkt_id, i, exp_w, obs.words[i]))
          return;
        end
      end
    endtask

    task run_phase(uvm_phase phase);
      ftable_obs_pkt obs;
      ftable_pkt exp;
      ftable_pkt exp_q[$];
      int match_idx;
      int unsigned fetched;

      forever begin
        obs_fifo.get(obs);

        // Ensure at least one expected packet is buffered.
        if (exp_q.size() == 0) begin
          exp_fifo.get(exp);
          exp_q.push_back(exp);
        end

        if (!allow_skip) begin
          exp = exp_q.pop_front();
          compare_pkt(exp, obs);
          continue;
        end

        // Allow drops/overwrites: search buffered expected queue, extending from fifo as needed.
        match_idx = -1;
        fetched = 0;
        while (match_idx < 0) begin
          for (int i = 0; i < exp_q.size(); i++) begin
            if (exp_q[i].pkt_id == obs.pkt_id) begin
              match_idx = i;
              break;
            end
          end
          if (match_idx >= 0) break;

          if (fetched >= allow_skip_max) begin
            `uvm_error("SKIP", $sformatf("No match for observed pkt_id=%0d within ALLOW_SKIP_MAX=%0d",
              obs.pkt_id, allow_skip_max))
            break;
          end
          exp_fifo.get(exp);
          exp_q.push_back(exp);
          fetched++;
        end

        if (match_idx >= 0) begin
          for (int i = 0; i < match_idx; i++) begin
            `uvm_info("SKIP", $sformatf("Skipping expected pkt_id=%0d (assumed dropped/overwritten)", exp_q[0].pkt_id), UVM_LOW)
            void'(exp_q.pop_front());
          end
          exp = exp_q.pop_front();
          compare_pkt(exp, obs);
        end
      end
    endtask
  endclass

  class ftable_env extends uvm_env;
    `uvm_component_utils(ftable_env)
    ftable_sequencer seqr;
    ftable_driver drv;
    ftable_egress_monitor mon;
    ftable_scoreboard scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr = ftable_sequencer::type_id::create("seqr", this);
      drv = ftable_driver::type_id::create("drv", this);
      mon = ftable_egress_monitor::type_id::create("mon", this);
      scb = ftable_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
      drv.exp_ap.connect(scb.exp_fifo.analysis_export);
      mon.ap.connect(scb.obs_fifo.analysis_export);
    endfunction
  endclass

  class ftable_rand_seq extends uvm_sequence #(ftable_pkt);
    `uvm_object_utils(ftable_rand_seq)

    int unsigned n_frames;
    int unsigned max_hits;
    int unsigned max_shds;
    int unsigned min_gap;
    int unsigned max_gap;
    int unsigned invalid_pct;

    function new(string name = "ftable_rand_seq");
      super.new(name);
    endfunction

    task body();
      int unsigned addr_ptr;
      n_frames = 200;
      max_hits = 64;
      max_shds = 16;
      min_gap = 0;
      max_gap = 4;
      invalid_pct = 0;

      void'($value$plusargs("N_FRAMES=%d", n_frames));
      void'($value$plusargs("MAX_HITS=%d", max_hits));
      void'($value$plusargs("MAX_SHDS=%d", max_shds));
      void'($value$plusargs("MIN_GAP=%d", min_gap));
      void'($value$plusargs("MAX_GAP=%d", max_gap));
      void'($value$plusargs("INVALID_PCT=%d", invalid_pct));

      addr_ptr = 0;
      for (int unsigned i = 0; i < n_frames; i++) begin
        ftable_pkt req;
        int unsigned hit_cnt;
        int unsigned shr_cnt;
        int unsigned len;
        int unsigned gap;
        bit invalid;

        hit_cnt = $urandom_range(0, max_hits);
        shr_cnt = $urandom_range(0, max_shds);
        len = calc_total_words(shr_cnt, hit_cnt);
        gap = (max_gap >= min_gap) ? $urandom_range(min_gap, max_gap) : 0;
        invalid = (invalid_pct != 0) && ($urandom_range(0, 99) < invalid_pct);

        req = ftable_pkt::type_id::create($sformatf("pkt_%0d", i));
        req.pkt_id = i + 1;
        req.start_addr = addr_ptr % PAGE_RAM_DEPTH;
        req.shr_cnt = shr_cnt;
        req.hit_cnt = hit_cnt;
        req.force_invalid = invalid;
        req.is_dummy = 1'b0;
        req.idle_cycles = gap;

        start_item(req);
        finish_item(req);

        addr_ptr = (addr_ptr + len) % PAGE_RAM_DEPTH;
      end

      // Dummy head-start to flush the final tail-done.
      begin
        ftable_pkt dummy;
        dummy = ftable_pkt::type_id::create("dummy_flush");
        dummy.pkt_id = 32'hdead_beef;
        dummy.start_addr = addr_ptr % PAGE_RAM_DEPTH;
        dummy.shr_cnt = 0;
        dummy.hit_cnt = 0;
        dummy.force_invalid = 1'b1;
        dummy.is_dummy = 1'b1;
        dummy.idle_cycles = 0;
        start_item(dummy);
        finish_item(dummy);
      end
    endtask
  endclass

  class ftable_test extends uvm_test;
    `uvm_component_utils(ftable_test)
    ftable_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = ftable_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      ftable_rand_seq seq;
      phase.raise_objection(this);
      seq = ftable_rand_seq::type_id::create("seq");
      seq.start(env.seqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage

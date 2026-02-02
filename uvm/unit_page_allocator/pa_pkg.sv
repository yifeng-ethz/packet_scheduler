package pa_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Must match the DUT instance in pa_uvm_tb.sv (and pa_if defaults).
  localparam int unsigned N_LANE = 4;
  localparam int unsigned N_SHD  = 8;
  localparam int unsigned CHANNEL_WIDTH = 2;

  localparam int unsigned LANE_FIFO_DEPTH   = 32;
  localparam int unsigned TICKET_FIFO_DEPTH = 1024;
  localparam int unsigned HANDLE_FIFO_DEPTH = 1024;
  localparam int unsigned PAGE_RAM_DEPTH    = 262144;

  localparam int unsigned DATA_W = 40;
  localparam int unsigned HDR_SIZE = 5;
  localparam int unsigned SHD_SIZE = 1;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned TRL_SIZE = 1;
  localparam int unsigned N_HIT    = 255;

  localparam int unsigned FRAME_SERIAL_SIZE   = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE  = 16;

  localparam int unsigned SHD_CNT_WIDTH = 16;
  localparam int unsigned HIT_CNT_WIDTH = 16;

  localparam int unsigned SUBFRAME_DURATION_CYCLES = 16;
  localparam int unsigned FRAME_DURATION_CYCLES    = N_SHD * SUBFRAME_DURATION_CYCLES;

  localparam int unsigned LANE_FIFO_ADDR_W    = $clog2(LANE_FIFO_DEPTH);
  localparam int unsigned PAGE_ADDR_W         = $clog2(PAGE_RAM_DEPTH);
  localparam int unsigned TICKET_ADDR_W       = $clog2(TICKET_FIFO_DEPTH);
  localparam int unsigned HANDLE_ADDR_W       = $clog2(HANDLE_FIFO_DEPTH);
  localparam int unsigned MAX_PKT_LENGTH_BITS = $clog2(HIT_SIZE * N_HIT);

  localparam int unsigned TICKET_W_A = 48 + LANE_FIFO_ADDR_W + MAX_PKT_LENGTH_BITS + 2;
  localparam int unsigned TICKET_W_B = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2;
  localparam int unsigned TICKET_W   = (TICKET_W_A > TICKET_W_B) ? TICKET_W_A : TICKET_W_B;

  localparam int unsigned HANDLE_W = LANE_FIFO_ADDR_W + PAGE_ADDR_W + MAX_PKT_LENGTH_BITS + 1;

  localparam int unsigned TICKET_ALT_EOP_LOC = TICKET_W - 2;
  localparam int unsigned TICKET_ALT_SOP_LOC = TICKET_W - 1;

  localparam int unsigned TICKET_SERIAL_LO = 0;
  localparam int unsigned TICKET_SERIAL_HI = FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_N_SUBH_LO = FRAME_SERIAL_SIZE;
  localparam int unsigned TICKET_N_SUBH_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  localparam int unsigned TICKET_N_HIT_LO  = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  localparam int unsigned TICKET_N_HIT_HI  = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;

  localparam int unsigned TICKET_TS_LO = 0;
  localparam int unsigned TICKET_TS_HI = 47;
  localparam int unsigned TICKET_LANE_RD_OFST_LO = 48;
  localparam int unsigned TICKET_LANE_RD_OFST_HI = 48 + LANE_FIFO_ADDR_W - 1;
  localparam int unsigned TICKET_BLOCK_LEN_LO    = 48 + LANE_FIFO_ADDR_W;
  localparam int unsigned TICKET_BLOCK_LEN_HI    = 48 + LANE_FIFO_ADDR_W + MAX_PKT_LENGTH_BITS - 1;

  localparam int unsigned HANDLE_SRC_LO = 0;
  localparam int unsigned HANDLE_SRC_HI = LANE_FIFO_ADDR_W - 1;
  localparam int unsigned HANDLE_DST_LO = LANE_FIFO_ADDR_W;
  localparam int unsigned HANDLE_DST_HI = LANE_FIFO_ADDR_W + PAGE_ADDR_W - 1;
  localparam int unsigned HANDLE_LEN_LO = LANE_FIFO_ADDR_W + PAGE_ADDR_W;
  localparam int unsigned HANDLE_LEN_HI = LANE_FIFO_ADDR_W + PAGE_ADDR_W + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned HANDLE_FLAG_BIT = HANDLE_W - 1;

  localparam bit [7:0] K285 = 8'hBC;
  localparam bit [7:0] K284 = 8'h9C;
  localparam bit [7:0] K237 = 8'hF7;

  typedef struct packed {
    int unsigned addr;
    bit [DATA_W-1:0] data;
  } page_exp_t;

  typedef struct packed {
    int unsigned start_addr;
    int unsigned shr_cnt_this;
    int unsigned hit_cnt_this;
    int unsigned serial;
  } head_exp_t;

  typedef struct packed {
    int unsigned start_addr_last;
    int unsigned shr_cnt;
    int unsigned hit_cnt;
    bit invalid_last;
  } tail_exp_t;

  function automatic logic [TICKET_W-1:0] pack_sop_ticket(
    int unsigned serial,
    int unsigned n_subh,
    int unsigned n_hit,
    bit alert_eop
  );
    logic [TICKET_W-1:0] t;
    t = '0;
    t[TICKET_SERIAL_HI:TICKET_SERIAL_LO] = serial[FRAME_SERIAL_SIZE-1:0];
    t[TICKET_N_SUBH_HI:TICKET_N_SUBH_LO] = n_subh[FRAME_SUBH_CNT_SIZE-1:0];
    t[TICKET_N_HIT_HI:TICKET_N_HIT_LO] = n_hit[FRAME_HIT_CNT_SIZE-1:0];
    t[TICKET_ALT_EOP_LOC] = alert_eop;
    t[TICKET_ALT_SOP_LOC] = 1'b1;
    return t;
  endfunction

  function automatic logic [TICKET_W-1:0] pack_shd_ticket(
    longint unsigned ticket_ts,
    int unsigned lane_rd_ofst,
    int unsigned block_len
  );
    logic [TICKET_W-1:0] t;
    t = '0;
    t[TICKET_TS_HI:TICKET_TS_LO] = ticket_ts[47:0];
    t[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO] = lane_rd_ofst[LANE_FIFO_ADDR_W-1:0];
    t[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] = block_len[MAX_PKT_LENGTH_BITS-1:0];
    t[TICKET_ALT_EOP_LOC] = 1'b0;
    t[TICKET_ALT_SOP_LOC] = 1'b0;
    return t;
  endfunction

  function automatic logic [HANDLE_W-1:0] pack_handle(
    bit flag,
    int unsigned src,
    int unsigned dst,
    int unsigned len
  );
    logic [HANDLE_W-1:0] h;
    h = '0;
    h[HANDLE_FLAG_BIT] = flag;
    h[HANDLE_SRC_HI:HANDLE_SRC_LO] = src[LANE_FIFO_ADDR_W-1:0];
    h[HANDLE_DST_HI:HANDLE_DST_LO] = dst[PAGE_ADDR_W-1:0];
    h[HANDLE_LEN_HI:HANDLE_LEN_LO] = len[MAX_PKT_LENGTH_BITS-1:0];
    return h;
  endfunction

  function automatic bit [DATA_W-1:0] make_word0(bit [5:0] dt_type, bit [15:0] feb_id);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0001;
    w[31:26] = dt_type;
    w[23:8]  = feb_id;
    w[7:0]   = K285;
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_word1(longint unsigned frame_ts);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0000;
    w[31:0]  = frame_ts[47:16];
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_word2(longint unsigned frame_ts, int unsigned serial);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32]  = 4'b0000;
    w[31:16]  = frame_ts[15:0];
    w[15:0]   = serial[15:0];
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_word3(int unsigned shr_decl, int unsigned hit_cnt);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0000;
    w[31:16] = shr_decl[15:0];
    w[15:0]  = hit_cnt[15:0];
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_word4(longint unsigned running_ts);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0000;
    w[30:0]  = running_ts[30:0];
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_shd_word(longint unsigned running_ts, int unsigned hit_cnt_u16);
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0001;
    w[31:24] = running_ts[11:4];
    w[23:8]  = hit_cnt_u16[15:0];
    w[7:0]   = K237;
    return w;
  endfunction

  function automatic bit [DATA_W-1:0] make_trl_word();
    bit [DATA_W-1:0] w;
    w = '0;
    w[35:32] = 4'b0001;
    w[7:0]   = K284;
    return w;
  endfunction

  function automatic longint unsigned calc_frame_ts(int unsigned serial);
    longint unsigned s_odd;
    s_odd = (((serial >> 1) << 1) + 1);
    return s_odd * FRAME_DURATION_CYCLES;
  endfunction

  function automatic int unsigned xorshift32(ref int unsigned state);
    state ^= (state << 13);
    state ^= (state >> 17);
    state ^= (state << 5);
    return state;
  endfunction

  function automatic int unsigned rand_range(ref int unsigned state, int unsigned max_incl);
    int unsigned v;
    if (max_incl == 0) return 0;
    v = xorshift32(state);
    return v % (max_incl + 1);
  endfunction

  class pa_scoreboard extends uvm_component;
    `uvm_component_utils(pa_scoreboard)

    virtual pa_if vif;

    page_exp_t exp_page_q[$];
    head_exp_t exp_head_q[$];
    tail_exp_t exp_tail_q[$];
    logic [HANDLE_W-1:0] exp_handle_q [N_LANE][$];

    bit done;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      done = 1'b0;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual pa_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "pa_scoreboard: virtual interface not set")
      end
    endfunction

    function void clear_expected();
      exp_page_q.delete();
      exp_head_q.delete();
      exp_tail_q.delete();
      for (int unsigned i = 0; i < N_LANE; i++) exp_handle_q[i].delete();
      done = 1'b0;
    endfunction

    function void push_page(int unsigned addr, bit [DATA_W-1:0] data);
      page_exp_t e;
      e.addr = addr;
      e.data = data;
      exp_page_q.push_back(e);
    endfunction

    function void push_head(int unsigned start_addr, int unsigned shr_cnt_this, int unsigned hit_cnt_this, int unsigned serial);
      head_exp_t h;
      h.start_addr = start_addr;
      h.shr_cnt_this = shr_cnt_this;
      h.hit_cnt_this = hit_cnt_this;
      h.serial = serial;
      exp_head_q.push_back(h);
    endfunction

    function void push_tail(int unsigned start_addr_last, int unsigned shr_cnt, int unsigned hit_cnt, bit invalid_last);
      tail_exp_t t;
      t.start_addr_last = start_addr_last;
      t.shr_cnt = shr_cnt;
      t.hit_cnt = hit_cnt;
      t.invalid_last = invalid_last;
      exp_tail_q.push_back(t);
    endfunction

    function void push_handle(int unsigned lane, logic [HANDLE_W-1:0] h);
      exp_handle_q[lane].push_back(h);
    endfunction

    function automatic bit all_handles_done();
      for (int unsigned i = 0; i < N_LANE; i++) begin
        if (exp_handle_q[i].size() != 0) return 1'b0;
      end
      return 1'b1;
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned quiet;
      quiet = 0;

      wait (vif.rst == 1'b0);
      forever begin
        @(posedge vif.clk);
        if (vif.rst) begin
          quiet = 0;
          continue;
        end

        // Head-start meta check.
        if (vif.pa_write_head_start) begin
          if (exp_head_q.size() == 0) begin
            `uvm_error("UNEXP", "Unexpected pa_write_head_start")
          end else begin
            head_exp_t exp;
            exp = exp_head_q.pop_front();
            if (vif.pa_frame_start_addr !== exp.start_addr[PAGE_ADDR_W-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Head start_addr mismatch exp=%0d got=%0d",
                exp.start_addr, vif.pa_frame_start_addr))
            end
            if (vif.pa_frame_shr_cnt_this !== exp.shr_cnt_this[SHD_CNT_WIDTH-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Head shr_cnt_this mismatch exp=%0d got=%0d",
                exp.shr_cnt_this, vif.pa_frame_shr_cnt_this))
            end
            if (vif.pa_frame_hit_cnt_this !== exp.hit_cnt_this[HIT_CNT_WIDTH-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Head hit_cnt_this mismatch exp=%0d got=%0d",
                exp.hit_cnt_this, vif.pa_frame_hit_cnt_this))
            end
          end
        end

        // Tail-done meta check.
        if (vif.pa_write_tail_done) begin
          if (exp_tail_q.size() == 0) begin
            `uvm_error("UNEXP", "Unexpected pa_write_tail_done")
          end else begin
            tail_exp_t exp;
            exp = exp_tail_q.pop_front();
            if (vif.pa_frame_start_addr_last !== exp.start_addr_last[PAGE_ADDR_W-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Tail start_addr_last mismatch exp=%0d got=%0d",
                exp.start_addr_last, vif.pa_frame_start_addr_last))
            end
            if (vif.pa_frame_shr_cnt !== exp.shr_cnt[SHD_CNT_WIDTH-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Tail shr_cnt mismatch exp=%0d got=%0d",
                exp.shr_cnt, vif.pa_frame_shr_cnt))
            end
            if (vif.pa_frame_hit_cnt !== exp.hit_cnt[HIT_CNT_WIDTH-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Tail hit_cnt mismatch exp=%0d got=%0d",
                exp.hit_cnt, vif.pa_frame_hit_cnt))
            end
            if (vif.pa_frame_invalid_last !== exp.invalid_last) begin
              `uvm_error("MISMATCH", $sformatf("Tail invalid_last mismatch exp=%0b got=%0b",
                exp.invalid_last, vif.pa_frame_invalid_last))
            end
          end
        end

        // Page write compare.
        if (vif.page_we) begin
          if (exp_page_q.size() == 0) begin
            `uvm_error("UNEXP", $sformatf("Unexpected page write addr=%0d data=0x%0h", vif.page_waddr, vif.page_wdata))
          end else begin
            page_exp_t exp;
            exp = exp_page_q.pop_front();
            if (vif.page_waddr !== exp.addr[PAGE_ADDR_W-1:0]) begin
              `uvm_error("MISMATCH", $sformatf("Page addr mismatch exp=%0d got=%0d", exp.addr, vif.page_waddr))
            end
            if (vif.page_wdata !== exp.data) begin
              `uvm_error("MISMATCH", $sformatf("Page data mismatch addr=%0d exp=0x%0h got=0x%0h",
                exp.addr, exp.data, vif.page_wdata))
            end
          end
        end

        // Handle compare.
        for (int unsigned lane = 0; lane < N_LANE; lane++) begin
          if (vif.handle_we[lane]) begin
            logic [HANDLE_W-1:0] got;
            got = vif.handle_wdata_flat[lane*HANDLE_W +: HANDLE_W];
            if (exp_handle_q[lane].size() == 0) begin
              `uvm_error("UNEXP", $sformatf("Unexpected handle lane=%0d wdata=0x%0h", lane, got))
            end else begin
              logic [HANDLE_W-1:0] exp;
              exp = exp_handle_q[lane].pop_front();
              if (got !== exp) begin
                `uvm_error("MISMATCH", $sformatf("Handle mismatch lane=%0d exp=0x%0h got=0x%0h", lane, exp, got))
              end
            end
          end
        end

        if ((exp_page_q.size() == 0) && (exp_head_q.size() == 0) && (exp_tail_q.size() == 0) && all_handles_done()) begin
          quiet++;
          if (quiet > 32) begin
            done = 1'b1;
            `uvm_info("DONE", "All expected events observed", UVM_LOW)
            break;
          end
        end else begin
          quiet = 0;
        end
      end
    endtask
  endclass

  class pa_test extends uvm_test;
    `uvm_component_utils(pa_test)
    virtual pa_if vif;
    pa_scoreboard scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual pa_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "pa_test: virtual interface not set")
      end
      scb = pa_scoreboard::type_id::create("scb", this);
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned n_frames;
      int unsigned max_hits;
      int unsigned seed;
      int unsigned rng_state;
      bit [5:0] dt_type;
      bit [15:0] feb_id;

      n_frames = 20;
      max_hits = 255;
      seed = 1;
      dt_type = 6'h01;
      feb_id = 16'h1234;

      void'($value$plusargs("N_FRAMES=%d", n_frames));
      void'($value$plusargs("MAX_HITS=%d", max_hits));
      void'($value$plusargs("SEED=%d", seed));

      phase.raise_objection(this);

      rng_state = seed;
      if (max_hits > N_HIT) begin
        `uvm_warning("CFG", $sformatf("Clamping MAX_HITS=%0d to N_HIT=%0d", max_hits, N_HIT))
        max_hits = N_HIT;
      end

      // Configure static inputs.
      vif.dt_type <= dt_type;
      vif.feb_id <= feb_id;

      // Hold until reset deasserts, but preload tickets while reset is asserted.
      wait (vif.rst == 1'b1);

      scb.clear_expected();

      // Build ticket streams + expected events.
      begin
        int unsigned ticket_idx;
        longint unsigned page_ptr;
        int unsigned prev_frame_start;
        int unsigned prev_frame_hits;
        int unsigned prev_frame_shr_cnt;
        int unsigned lane_src_ofst [N_LANE];

        ticket_idx = 0;
        page_ptr = 0;
        prev_frame_start = 0;
        prev_frame_hits = 0;
        prev_frame_shr_cnt = 0;
        for (int unsigned lane = 0; lane < N_LANE; lane++) lane_src_ofst[lane] = 0;

        if ((n_frames * (1 + N_SHD)) >= TICKET_FIFO_DEPTH) begin
          `uvm_fatal("CFG", $sformatf("N_FRAMES*(1+N_SHD)=%0d exceeds TICKET_FIFO_DEPTH=%0d",
            (n_frames * (1 + N_SHD)), TICKET_FIFO_DEPTH))
        end

        for (int unsigned f = 0; f < n_frames; f++) begin
          int unsigned serial;
          bit alert_eop;
          int unsigned frame_start;
          longint unsigned frame_ts;
          longint unsigned running_ts;
          int unsigned frame_hits;
          int unsigned lane_hits [N_LANE];
          int unsigned len_mtx [N_SHD][N_LANE];
          int unsigned src_mtx [N_SHD][N_LANE];

          serial = f;
          alert_eop = (f != 0);

          // Generate per-subheader/per-lane lengths.
          for (int unsigned lane = 0; lane < N_LANE; lane++) lane_hits[lane] = 0;
          for (int unsigned s = 0; s < N_SHD; s++) begin
            for (int unsigned lane = 0; lane < N_LANE; lane++) begin
              len_mtx[s][lane] = rand_range(rng_state, max_hits);
              lane_hits[lane] += len_mtx[s][lane];
            end
          end

          frame_hits = 0;
          for (int unsigned lane = 0; lane < N_LANE; lane++) frame_hits += lane_hits[lane];

          // Compute src offsets for each subheader ticket/handle, and advance the per-lane running offsets.
          for (int unsigned lane = 0; lane < N_LANE; lane++) begin
            int unsigned src;
            src = lane_src_ofst[lane];
            for (int unsigned s = 0; s < N_SHD; s++) begin
              src_mtx[s][lane] = src;
              src += len_mtx[s][lane];
            end
            lane_src_ofst[lane] = src;
          end

          // New frame allocation start.
          frame_start = int'(page_ptr) + (alert_eop ? TRL_SIZE : 0);
          frame_ts = calc_frame_ts(serial);

          // Expected head-start metadata: shr_cnt_this is lane-summed.
          scb.push_head(frame_start, N_LANE * N_SHD, frame_hits, serial);

          // Header words 0..2 for this frame.
          scb.push_page(frame_start + 0, make_word0(dt_type, feb_id));
          scb.push_page(frame_start + 1, make_word1(frame_ts));
          scb.push_page(frame_start + 2, make_word2(frame_ts, serial));

          // Tail/trailer for previous frame, emitted on SOP of this frame.
          if (alert_eop) begin
            longint unsigned boundary_ts;
            boundary_ts = longint'(serial) * FRAME_DURATION_CYCLES;
            scb.push_tail(prev_frame_start, prev_frame_shr_cnt, prev_frame_hits, 1'b0);
            scb.push_page(prev_frame_start + 3, make_word3(prev_frame_shr_cnt / N_LANE, prev_frame_hits));
            scb.push_page(prev_frame_start + 4, make_word4(boundary_ts));
            scb.push_page(frame_start - 1, make_trl_word());
          end

          // Body starts right after the header.
          page_ptr = longint'(frame_start + HDR_SIZE);

          // Subheaders: generate per-lane hit lengths and expected handles.
          running_ts = longint'(serial) * FRAME_DURATION_CYCLES;
          for (int unsigned s = 0; s < N_SHD; s++) begin
            int unsigned sub_total;
            longint unsigned dst;

            sub_total = 0;
            for (int unsigned lane = 0; lane < N_LANE; lane++) sub_total += len_mtx[s][lane];

            // Emit handles with proper per-lane dst offsets, matching the RTL's ALLOC_PAGE loop.
            dst = page_ptr + SHD_SIZE;
            for (int unsigned lane = 0; lane < N_LANE; lane++) begin
              logic [HANDLE_W-1:0] h;
              int unsigned len;
              len = len_mtx[s][lane];

              if (len != 0) begin
                h = pack_handle(1'b0, src_mtx[s][lane], int'(dst), len);
                scb.push_handle(lane, h);
                dst += len;
              end
            end

            scb.push_page(int'(page_ptr), make_shd_word(running_ts, sub_total));
            page_ptr = page_ptr + SHD_SIZE + sub_total;
            running_ts += SUBFRAME_DURATION_CYCLES;
          end

          // SOP ticket fields: n_subh is global (replicated across lanes), n_hit is per-lane; summed by RTL.
          for (int unsigned lane = 0; lane < N_LANE; lane++) begin
            vif.set_ticket(lane, ticket_idx, pack_sop_ticket(serial, N_SHD, lane_hits[lane], alert_eop));
          end

          // Subheader tickets.
          for (int unsigned s = 0; s < N_SHD; s++) begin
            longint unsigned tk_ts;
            tk_ts = longint'(serial) * FRAME_DURATION_CYCLES + longint'(s) * SUBFRAME_DURATION_CYCLES;
            for (int unsigned lane = 0; lane < N_LANE; lane++) begin
              vif.set_ticket(lane, ticket_idx + 1 + s, pack_shd_ticket(tk_ts, src_mtx[s][lane], len_mtx[s][lane]));
            end
          end

          ticket_idx += 1 + N_SHD;

          // Stash for next frame's tail.
          prev_frame_start = frame_start;
          prev_frame_hits = frame_hits;
          prev_frame_shr_cnt = N_LANE * N_SHD;
        end

        // Publish write pointers.
        for (int unsigned lane = 0; lane < N_LANE; lane++) begin
          vif.set_ticket_wptr(lane, ticket_idx);
        end
      end

      // Wait for the scoreboard to observe all expected events.
      wait (scb.done);
      phase.drop_objection(this);
    endtask
  endclass
endpackage

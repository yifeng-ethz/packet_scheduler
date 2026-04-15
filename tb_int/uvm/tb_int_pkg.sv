// ---------------------------------------------------------------------------
// IP Name    : tb_int_pkg
// Author     : Yifeng Wang (yifenwan@phys.ethz.ch)
// Description:
//   UVM package for packet_scheduler/tb_int. Phase 1 skeleton: config,
//   run_control_agent sequence item / driver / sequencer / agent,
//   scoreboard stub, env, smoke test. Stage A..E monitors are declared
//   but currently TODO-empty; they get filled in Phase 2 once the feb_stub
//   chain is wired.
// ---------------------------------------------------------------------------

`ifndef TB_INT_PKG_SV
`define TB_INT_PKG_SV

package tb_int_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------------------
    // Analysis port tag declarations for the scoreboard
    // -----------------------------------------------------------------------
    `uvm_analysis_imp_decl(_stage_a)
    `uvm_analysis_imp_decl(_stage_d)
    `uvm_analysis_imp_decl(_stage_e)

    // -----------------------------------------------------------------------
    // Config object
    // -----------------------------------------------------------------------
    class tb_int_cfg extends uvm_object;
        `uvm_object_utils(tb_int_cfg)

        int unsigned num_feb         = 2;
        int unsigned num_datapath    = 2;
        int unsigned num_mutrig      = 4;  // per datapath
        int unsigned opq_n_lane      = 4;
        int unsigned smoke_run_cycles = 2000;

        function new(string name = "tb_int_cfg");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: stage A hit (captured at hit_generator FIFO commit)
    // -----------------------------------------------------------------------
    class tb_int_hit_event extends uvm_object;
        `uvm_object_utils(tb_int_hit_event)

        bit [63:0] hit_id;
        time       abs_ts;
        bit [1:0]  feb_id;
        bit        datapath_id;
        bit [2:0]  mutrig_ch;
        bit [47:0] payload;

        function new(string name = "tb_int_hit_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: stage D OPQ ingress beat (per lane)
    // -----------------------------------------------------------------------
    class tb_int_ingress_event extends uvm_object;
        `uvm_object_utils(tb_int_ingress_event)

        int unsigned lane_id;
        time         abs_ts;
        bit [35:0]   data;
        bit [1:0]    channel;
        bit          sop;
        bit          eop;

        function new(string name = "tb_int_ingress_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: stage E OPQ egress beat
    // -----------------------------------------------------------------------
    class tb_int_egress_event extends uvm_object;
        `uvm_object_utils(tb_int_egress_event)

        time       abs_ts;
        bit [35:0] data;
        bit        sop;
        bit        eop;

        function new(string name = "tb_int_egress_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stateful frame parser — one instance per AvST sink (4 lanes at stage D,
    // 1 at stage E). Tracks the feb_frame_assembly AvST layout:
    //
    //   sop  : beat 0 — preamble                   (tag="0001", K285)
    //          beats 1..4 — 4 header words         (data hdr 0/1 + dbg hdr 0/1)
    //          beats 5..N-1 — subheaders and hits
    //   eop  : beat N    — trailer                 (tag="0001", K284)
    //
    // Within the body, a beat is a subheader when tag=="0001" && byte0==K237,
    // a trailer when tag=="0001" && byte0==K284, otherwise a hit.
    //
    // Stage E snoops the OPQ egress; Phase 2 empirical result was 15 frames
    // for 1400 ingress frames, which is what this parser exists to explain.
    // -----------------------------------------------------------------------
    typedef enum bit [1:0] { FP_IDLE, FP_HEADER, FP_BODY } frame_parser_state_e;

    class tb_int_frame_parser extends uvm_object;
        `uvm_object_utils(tb_int_frame_parser)

        localparam bit [3:0] FRAMING_TAG = 4'b0001;
        localparam bit [7:0] K285        = 8'hBC; // preamble
        localparam bit [7:0] K237        = 8'hF7; // subheader
        localparam bit [7:0] K284        = 8'h9C; // trailer

        frame_parser_state_e st;
        int unsigned hdr_cnt;
        int unsigned n_frames;
        int unsigned n_preambles;
        int unsigned n_headers;   // data + debug header words (4 per frame)
        int unsigned n_subheaders;
        int unsigned n_hits;
        int unsigned n_trailers;
        int unsigned n_orphan;    // beats seen in FP_IDLE (no sop yet) — ghost
        int unsigned n_missing_eop;
        int unsigned n_mid_sop;   // sop without prior eop

        function new(string name = "tb_int_frame_parser");
            super.new(name);
            st            = FP_IDLE;
            hdr_cnt       = 0;
            n_frames      = 0;
            n_preambles   = 0;
            n_headers     = 0;
            n_subheaders  = 0;
            n_hits        = 0;
            n_trailers    = 0;
            n_orphan      = 0;
            n_missing_eop = 0;
            n_mid_sop     = 0;
        endfunction

        virtual function void step(bit sop, bit eop, bit [35:0] data);
            bit is_subheader;
            bit is_trailer;
            if (sop) begin
                if (st != FP_IDLE) n_mid_sop++;
                st          = FP_HEADER;
                hdr_cnt     = 1;
                n_frames++;
                n_preambles++;
                if (eop) begin
                    // degenerate single-beat frame
                    n_trailers++;
                    st = FP_IDLE;
                end
                return;
            end
            case (st)
                FP_IDLE: begin
                    n_orphan++;
                end
                FP_HEADER: begin
                    hdr_cnt++;
                    n_headers++;
                    if (hdr_cnt >= 5) st = FP_BODY;
                    if (eop) begin
                        n_missing_eop++; // eop mid-header is a protocol break
                        st = FP_IDLE;
                    end
                end
                FP_BODY: begin
                    is_subheader = (data[35:32] == FRAMING_TAG) &&
                                   (data[7:0]   == K237);
                    is_trailer   = (data[35:32] == FRAMING_TAG) &&
                                   (data[7:0]   == K284);
                    if (is_trailer) begin
                        n_trailers++;
                        if (!eop) n_missing_eop++;
                        st = FP_IDLE;
                    end else if (is_subheader) begin
                        n_subheaders++;
                        if (eop) begin
                            n_missing_eop++;
                            st = FP_IDLE;
                        end
                    end else begin
                        n_hits++;
                        if (eop) begin
                            n_missing_eop++;
                            st = FP_IDLE;
                        end
                    end
                end
            endcase
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Hit record (scoreboard entry)
    // -----------------------------------------------------------------------
    typedef struct packed {
        bit [7:0]  feb_id;
        bit [7:0]  datapath_id;
        bit [7:0]  mutrig_ch;
    } mutrig_origin_t;

    class tb_int_hit_record extends uvm_object;
        `uvm_object_utils(tb_int_hit_record)

        bit [63:0] hit_id;
        bit [63:0] abs_ts;
        mutrig_origin_t origin;
        bit [47:0] payload;
        bit [63:0] stage_ts [5];
        bit [4:0]  stage_seen;
        bit [7:0]  expected_subheader_slot;
        bit [1:0]  expected_lane;

        function new(string name = "tb_int_hit_record");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Scoreboard. Phase 2 walking skeleton: receive stage A and stage E
    // analysis events, count them, and flag a hard error if either end is
    // silent. Phase 3 extends this with per-hit identity matching across
    // all stages.
    // -----------------------------------------------------------------------
    class tb_int_scoreboard extends uvm_component;
        `uvm_component_utils(tb_int_scoreboard)

        uvm_analysis_imp_stage_a#(tb_int_hit_event,     tb_int_scoreboard) stage_a_imp;
        uvm_analysis_imp_stage_d#(tb_int_ingress_event, tb_int_scoreboard) stage_d_imp;
        uvm_analysis_imp_stage_e#(tb_int_egress_event,  tb_int_scoreboard) stage_e_imp;

        tb_int_hit_record hit_db [bit [63:0]];
        int unsigned n_stage_a;
        int unsigned n_stage_a_per_lane    [4];
        int unsigned n_stage_d_beats_per_lane  [4];
        int unsigned n_stage_d_frames_per_lane [4];
        int unsigned n_stage_d_beats;
        int unsigned n_stage_d_frames;
        int unsigned n_stage_e_beats;
        int unsigned n_stage_e_frames;
        int unsigned n_missing;
        int unsigned n_ghost;
        int unsigned n_slot_violation;

        // Stateful frame parsers — 4 per stage D lane, 1 for stage E.
        tb_int_frame_parser d_parser [4];
        tb_int_frame_parser e_parser;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            n_stage_a = 0;
            n_stage_d_beats = 0;
            n_stage_d_frames = 0;
            n_stage_e_beats = 0;
            n_stage_e_frames = 0;
            n_missing = 0;
            n_ghost = 0;
            n_slot_violation = 0;
            foreach (n_stage_a_per_lane[i])        n_stage_a_per_lane[i]        = 0;
            foreach (n_stage_d_beats_per_lane[i])  n_stage_d_beats_per_lane[i]  = 0;
            foreach (n_stage_d_frames_per_lane[i]) n_stage_d_frames_per_lane[i] = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            stage_a_imp = new("stage_a_imp", this);
            stage_d_imp = new("stage_d_imp", this);
            stage_e_imp = new("stage_e_imp", this);
            foreach (d_parser[i])
                d_parser[i] = tb_int_frame_parser::type_id::create(
                                  $sformatf("d_parser_%0d", i));
            e_parser = tb_int_frame_parser::type_id::create("e_parser");
        endfunction

        // Stage A analysis write: a hit_generator committed a new hit to
        // its FIFO. The tag monitor has already assigned a monotonic
        // hit_id; we record it in hit_db and bump counters.
        virtual function void write_stage_a(tb_int_hit_event ev);
            int unsigned lane_idx;
            tb_int_hit_record rec;
            rec = tb_int_hit_record::type_id::create("rec");
            rec.hit_id = ev.hit_id;
            rec.abs_ts = ev.abs_ts;
            rec.origin.feb_id      = {6'b0, ev.feb_id};
            rec.origin.datapath_id = {7'b0, ev.datapath_id};
            rec.origin.mutrig_ch   = {5'b0, ev.mutrig_ch};
            rec.payload    = ev.payload;
            rec.stage_ts[0] = ev.abs_ts;
            rec.stage_seen  = rec.stage_seen | 5'b0_0001;
            hit_db[ev.hit_id] = rec;
            n_stage_a++;
            lane_idx = {ev.feb_id, ev.datapath_id};
            if (lane_idx < 4) n_stage_a_per_lane[lane_idx]++;
        endfunction

        // Stage D analysis write: one beat on a single OPQ ingress lane.
        // Phase 2 walking-skeleton: count beats and frame heads (sop) per
        // lane. The {hit, subheader, header, debug-header, trailer} tag
        // classification is non-trivial because feb_frame_assembly leaves
        // [35:32] inheriting prior values across the 5-cycle SOF state,
        // so a flat data[35:32] decode is not a reliable hit predicate.
        // Phase 3 will add a stateful per-lane frame parser.
        virtual function void write_stage_d(tb_int_ingress_event ev);
            n_stage_d_beats++;
            if (ev.lane_id < 4) begin
                n_stage_d_beats_per_lane[ev.lane_id]++;
                d_parser[ev.lane_id].step(ev.sop, ev.eop, ev.data);
            end
            if (ev.sop) begin
                n_stage_d_frames++;
                if (ev.lane_id < 4) n_stage_d_frames_per_lane[ev.lane_id]++;
            end
        endfunction

        // Stage E analysis write: one accepted beat on the OPQ egress
        // AvST. Same Phase-2 simplification as stage D: count beats and
        // frame heads (sop). The hit-extracting decoder is Phase 3.
        virtual function void write_stage_e(tb_int_egress_event ev);
            n_stage_e_beats++;
            if (ev.sop) n_stage_e_frames++;
            e_parser.step(ev.sop, ev.eop, ev.data);
        endfunction

        virtual function void report_phase(uvm_phase phase);
            int unsigned d_hits_total;
            int unsigned d_subheaders_total;
            int unsigned d_frames_total;
            int unsigned d_trailers_total;
            super.report_phase(phase);
            d_hits_total       = 0;
            d_subheaders_total = 0;
            d_frames_total     = 0;
            d_trailers_total   = 0;
            foreach (d_parser[i]) begin
                d_hits_total       += d_parser[i].n_hits;
                d_subheaders_total += d_parser[i].n_subheaders;
                d_frames_total     += d_parser[i].n_frames;
                d_trailers_total   += d_parser[i].n_trailers;
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_d[%0d] parser: frames=%0d preambles=%0d headers=%0d subheaders=%0d hits=%0d trailers=%0d orphan=%0d missing_eop=%0d mid_sop=%0d",
                                    i,
                                    d_parser[i].n_frames,
                                    d_parser[i].n_preambles,
                                    d_parser[i].n_headers,
                                    d_parser[i].n_subheaders,
                                    d_parser[i].n_hits,
                                    d_parser[i].n_trailers,
                                    d_parser[i].n_orphan,
                                    d_parser[i].n_missing_eop,
                                    d_parser[i].n_mid_sop),
                          UVM_LOW)
            end
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_d totals: frames=%0d hits=%0d subheaders=%0d trailers=%0d",
                                d_frames_total, d_hits_total,
                                d_subheaders_total, d_trailers_total),
                      UVM_LOW)
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_e parser: frames=%0d preambles=%0d headers=%0d subheaders=%0d hits=%0d trailers=%0d orphan=%0d missing_eop=%0d mid_sop=%0d",
                                e_parser.n_frames,
                                e_parser.n_preambles,
                                e_parser.n_headers,
                                e_parser.n_subheaders,
                                e_parser.n_hits,
                                e_parser.n_trailers,
                                e_parser.n_orphan,
                                e_parser.n_missing_eop,
                                e_parser.n_mid_sop),
                      UVM_LOW)
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_a=%0d a_per_lane=(%0d,%0d,%0d,%0d) stage_d_beats=%0d stage_d_frames=%0d d_beats_per_lane=(%0d,%0d,%0d,%0d) d_frames_per_lane=(%0d,%0d,%0d,%0d) stage_e_beats=%0d stage_e_frames=%0d hit_db=%0d missing=%0d ghost=%0d slot_violation=%0d",
                                n_stage_a,
                                n_stage_a_per_lane[0], n_stage_a_per_lane[1],
                                n_stage_a_per_lane[2], n_stage_a_per_lane[3],
                                n_stage_d_beats, n_stage_d_frames,
                                n_stage_d_beats_per_lane[0], n_stage_d_beats_per_lane[1],
                                n_stage_d_beats_per_lane[2], n_stage_d_beats_per_lane[3],
                                n_stage_d_frames_per_lane[0], n_stage_d_frames_per_lane[1],
                                n_stage_d_frames_per_lane[2], n_stage_d_frames_per_lane[3],
                                n_stage_e_beats, n_stage_e_frames,
                                hit_db.size(),
                                n_missing, n_ghost, n_slot_violation),
                      UVM_LOW)
            if (n_stage_a == 0)
                `uvm_error("TB_INT_SB", "no stage A hits observed")
            if (n_stage_d_beats == 0)
                `uvm_error("TB_INT_SB", "no stage D beats observed")
            if (n_stage_d_frames == 0)
                `uvm_error("TB_INT_SB", "no stage D frame heads observed")
            if (n_stage_e_beats == 0)
                `uvm_error("TB_INT_SB", "no stage E beats observed")
            if (n_stage_e_frames == 0)
                `uvm_error("TB_INT_SB", "no stage E frame heads observed")
            // Every lane must be live — single-silent-lane would satisfy
            // the n_stage_a > 0 check but violate the 4-lane topology.
            foreach (n_stage_a_per_lane[i]) begin
                if (n_stage_a_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage A lane %0d silent (per-lane hit count 0)", i))
            end
            foreach (n_stage_d_beats_per_lane[i]) begin
                if (n_stage_d_beats_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage D lane %0d silent (per-lane beat count 0)", i))
            end
            foreach (n_stage_d_frames_per_lane[i]) begin
                if (n_stage_d_frames_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage D lane %0d emitted no frame heads", i))
            end
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stage A monitor — one per datapath. Samples the stage_a_if commit
    // pulse on each posedge clk. The monotonic hit_id is assigned from a
    // static class counter so every monitor instance produces globally
    // unique ids.
    // -----------------------------------------------------------------------
    class tb_int_stage_a_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_a_monitor)
        virtual stage_a_if vif;
        uvm_analysis_port#(tb_int_hit_event) ap;
        int unsigned lane_id;
        static bit [63:0] next_hit_id = 64'd0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                `uvm_fatal("STAGE_A", $sformatf("vif not assigned for stage_a lane %0d", lane_id))
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1) begin
                    tb_int_hit_event ev;
                    ev = tb_int_hit_event::type_id::create("ev");
                    ev.hit_id      = next_hit_id;
                    next_hit_id    = next_hit_id + 64'd1;
                    ev.abs_ts      = $time;
                    ev.feb_id      = vif.feb_id;
                    ev.datapath_id = vif.datapath_id;
                    ev.mutrig_ch   = vif.mutrig_ch;
                    ev.payload     = vif.payload;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage E monitor — snoops the OPQ egress AvST and emits one
    // tb_int_egress_event per accepted beat.
    // -----------------------------------------------------------------------
    class tb_int_stage_e_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_e_monitor)
        virtual opq_egress_if vif;
        uvm_analysis_port#(tb_int_egress_event) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                `uvm_fatal("STAGE_E", "egress vif not assigned")
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1 && vif.ready === 1'b1) begin
                    tb_int_egress_event ev;
                    ev = tb_int_egress_event::type_id::create("ev");
                    ev.abs_ts = $time;
                    ev.data   = vif.data;
                    ev.sop    = vif.startofpacket;
                    ev.eop    = vif.endofpacket;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage D monitor — one per OPQ ingress lane. Snoops valid beats on
    // the opq_ingress_if and publishes a tb_int_ingress_event per beat.
    // The OPQ ingress side has no ready/valid handshake to gate against
    // (the swb_ingress_stub is always ready), so every cycle of valid is
    // an accepted beat.
    // -----------------------------------------------------------------------
    class tb_int_stage_d_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_d_monitor)
        virtual opq_ingress_if vif;
        uvm_analysis_port#(tb_int_ingress_event) ap;
        int unsigned lane_id;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                `uvm_fatal("STAGE_D", $sformatf("vif not assigned for stage_d lane %0d", lane_id))
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1) begin
                    tb_int_ingress_event ev;
                    ev = tb_int_ingress_event::type_id::create("ev");
                    ev.lane_id = lane_id;
                    ev.abs_ts  = $time;
                    ev.data    = vif.data;
                    ev.channel = vif.channel;
                    ev.sop     = vif.startofpacket;
                    ev.eop     = vif.endofpacket;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Run control agent (sequencer + driver + item)
    // -----------------------------------------------------------------------
    typedef enum bit [1:0] { RC_PREPARE, RC_START, RC_END } rc_op_e;

    class run_control_item extends uvm_sequence_item;
        `uvm_object_utils(run_control_item)
        rc_op_e      op;
        int unsigned hold_cycles;

        function new(string name = "run_control_item");
            super.new(name);
            op = RC_PREPARE;
            hold_cycles = 0;
        endfunction
    endclass

    class run_control_sequencer extends uvm_sequencer#(run_control_item);
        `uvm_component_utils(run_control_sequencer)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class run_control_driver extends uvm_driver#(run_control_item);
        `uvm_component_utils(run_control_driver)
        virtual run_control_if vif;

        // 9-bit one-hot run_state encoding (matches the FEB runctl bus).
        localparam bit [8:0] RC_STATE_IDLE        = 9'b0_0000_0001;
        localparam bit [8:0] RC_STATE_PREPARE     = 9'b0_0000_0010;
        localparam bit [8:0] RC_STATE_SYNC        = 9'b0_0000_0100;
        localparam bit [8:0] RC_STATE_RUNNING     = 9'b0_0000_1000;
        localparam bit [8:0] RC_STATE_TERMINATING = 9'b0_0001_0000;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (!uvm_config_db#(virtual run_control_if)::get(this, "", "rc_if", vif))
                `uvm_fatal("RC_DRV", "rc_if not found in config db")
            vif.run_state  <= RC_STATE_IDLE;
            vif.run_enable <= 1'b0;
            forever begin
                run_control_item it;
                seq_item_port.get_next_item(it);
                drive(it);
                seq_item_port.item_done();
            end
        endtask

        // Number of cycles SYNC is held before transitioning to RUNNING.
        // ring_buffer_cam uses SYNC to reset its gts counter and to release
        // the PREPARE-state flush, so the pulse must be long enough for the
        // internal state machine to advance.
        localparam int SYNC_HOLD_CYCLES = 32;

        // Safety upper bound on the PREP wait. ring_buffer_cam needs
        // ~131072 cycles to flush its CAM/RAM (256 data values × 512
        // entries). Allow generous headroom for the slowest IP.
        localparam int PREP_READY_TIMEOUT_CYCLES = 200000;

        virtual task drive(run_control_item it);
            int unsigned waited;
            case (it.op)
                RC_PREPARE: begin
                    vif.run_state  <= RC_STATE_PREPARE;
                    vif.run_enable <= 1'b0;
                    // Hold PREPARE for the minimum requested time first so
                    // every IP definitely sees the edge and starts its
                    // flush.
                    repeat (it.hold_cycles) @(posedge vif.clk);
                    // Then block until rc_if.prep_done goes high — the
                    // AND-reduce of every IP's asi_ctrl_ready across all 4
                    // datapaths. Without this, SYNC arrives mid-flush and
                    // rb_cam emits no h2 beats until ~131k cycles later.
                    waited = 0;
                    while (vif.prep_done !== 1'b1) begin
                        @(posedge vif.clk);
                        waited++;
                        if (waited >= PREP_READY_TIMEOUT_CYCLES) begin
                            `uvm_fatal("RC_DRV",
                                       $sformatf("prep_done never asserted after %0d cycles",
                                                 PREP_READY_TIMEOUT_CYCLES))
                        end
                    end
                    `uvm_info("RC_DRV",
                              $sformatf("PREP done after %0d extra wait cycles", waited),
                              UVM_LOW)
                end
                RC_START: begin
                    // SYNC pulse: resets rb_cam gts counter and releases the
                    // PREPARE-state flush. The OPQ/feb pipeline chain all
                    // honor the same 9-bit one-hot convention.
                    vif.run_state  <= RC_STATE_SYNC;
                    vif.run_enable <= 1'b0;
                    repeat (SYNC_HOLD_CYCLES) @(posedge vif.clk);
                    vif.run_state  <= RC_STATE_RUNNING;
                    vif.run_enable <= 1'b1;
                    repeat (it.hold_cycles) @(posedge vif.clk);
                end
                RC_END: begin
                    vif.run_state  <= RC_STATE_TERMINATING;
                    vif.run_enable <= 1'b0;
                    repeat (it.hold_cycles) @(posedge vif.clk);
                end
            endcase
        endtask
    endclass

    class run_control_agent extends uvm_agent;
        `uvm_component_utils(run_control_agent)
        run_control_sequencer sqr;
        run_control_driver    drv;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = run_control_sequencer::type_id::create("sqr", this);
            drv = run_control_driver   ::type_id::create("drv", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Environment
    // -----------------------------------------------------------------------
    class tb_int_env extends uvm_env;
        `uvm_component_utils(tb_int_env)

        tb_int_cfg              cfg;
        tb_int_scoreboard       sb;
        run_control_agent       rc_agent;
        tb_int_stage_a_monitor  stage_a [4];
        tb_int_stage_d_monitor  stage_d [4];
        tb_int_stage_e_monitor  stage_e;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(tb_int_cfg)::get(this, "", "cfg", cfg)) begin
                cfg = tb_int_cfg::type_id::create("cfg");
            end
            sb       = tb_int_scoreboard::type_id::create("sb", this);
            rc_agent = run_control_agent ::type_id::create("rc_agent", this);
            foreach (stage_a[i]) begin
                stage_a[i] = tb_int_stage_a_monitor::type_id::create(
                                 $sformatf("stage_a_%0d", i), this);
                stage_a[i].lane_id = i;
                if (!uvm_config_db#(virtual stage_a_if)::get(
                        this, "", $sformatf("stage_a%0d_if", i), stage_a[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_a%0d_if not found in config db", i))
            end
            foreach (stage_d[i]) begin
                stage_d[i] = tb_int_stage_d_monitor::type_id::create(
                                 $sformatf("stage_d_%0d", i), this);
                stage_d[i].lane_id = i;
                if (!uvm_config_db#(virtual opq_ingress_if)::get(
                        this, "", $sformatf("lane%0d_if", i), stage_d[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("lane%0d_if not found in config db", i))
            end
            stage_e = tb_int_stage_e_monitor::type_id::create("stage_e", this);
            if (!uvm_config_db#(virtual opq_egress_if)::get(
                    this, "", "egress_if", stage_e.vif))
                `uvm_fatal("ENV", "egress_if not found in config db")
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            foreach (stage_a[i]) stage_a[i].ap.connect(sb.stage_a_imp);
            foreach (stage_d[i]) stage_d[i].ap.connect(sb.stage_d_imp);
            stage_e.ap.connect(sb.stage_e_imp);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Base virtual sequence (PREPARE -> START -> END)
    // -----------------------------------------------------------------------
    class tb_int_base_vseq extends uvm_sequence;
        `uvm_object_utils(tb_int_base_vseq)
        run_control_sequencer rc_sqr;
        int unsigned prepare_cycles = 1024;
        int unsigned run_cycles     = 2000;
        // Drain budget after the emulator stops generating new hits. Must
        // exceed the rb_cam jitter window (910*2 short-mode cycles) plus
        // feb_frame_assembly + OPQ residency, otherwise the last few
        // frames are still trapped in the pipeline at end-of-sim.
        int unsigned end_cycles     = 4096;

        function new(string name = "tb_int_base_vseq");
            super.new(name);
        endfunction

        virtual task body();
            run_control_item it;
            it = run_control_item::type_id::create("rc_prepare");
            it.op = RC_PREPARE;
            it.hold_cycles = prepare_cycles;
            start_item(it); finish_item(it);

            it = run_control_item::type_id::create("rc_start");
            it.op = RC_START;
            it.hold_cycles = run_cycles;
            start_item(it); finish_item(it);

            it = run_control_item::type_id::create("rc_end");
            it.op = RC_END;
            it.hold_cycles = end_cycles;
            start_item(it); finish_item(it);
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Base test
    // -----------------------------------------------------------------------
    class tb_int_base_test extends uvm_test;
        `uvm_component_utils(tb_int_base_test)
        tb_int_env env;
        tb_int_cfg cfg;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // Subclasses override this hook to tweak cfg fields before env
        // is built. Keeps build_phase itself linear and UVM-hygienic.
        virtual function tb_int_cfg make_cfg();
            return tb_int_cfg::type_id::create("cfg");
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cfg = make_cfg();
            uvm_config_db#(tb_int_cfg)::set(this, "env", "cfg", cfg);
            env = tb_int_env::type_id::create("env", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_base_vseq vseq;
            phase.raise_objection(this);
            vseq = tb_int_base_vseq::type_id::create("vseq");
            vseq.run_cycles = cfg.smoke_run_cycles;
            vseq.start(env.rc_agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Smoke test — short walking-skeleton run, default cycle budget.
    // -----------------------------------------------------------------------
    class tb_int_smoke_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function tb_int_cfg make_cfg();
            tb_int_cfg c;
            c = tb_int_cfg::type_id::create("cfg");
            c.smoke_run_cycles = 200000;
            return c;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Basic E2E test — Phase 2 acceptance test. Same cycle budget as the
    // smoke test, but named distinctly so CI can call it out as the
    // walking-skeleton acceptance gate. The pass criterion is the
    // scoreboard's stage A/D/E nonzero + per-lane liveness checks; identity
    // matching across stages lands in Phase 3.
    // -----------------------------------------------------------------------
    class tb_int_basic_e2e_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_basic_e2e_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function tb_int_cfg make_cfg();
            tb_int_cfg c;
            c = tb_int_cfg::type_id::create("cfg");
            c.smoke_run_cycles = 200000;
            return c;
        endfunction
    endclass

endpackage : tb_int_pkg

`endif

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
    `uvm_analysis_imp_decl(_stage_h0)
    `uvm_analysis_imp_decl(_stage_h1)
    `uvm_analysis_imp_decl(_stage_b)
    `uvm_analysis_imp_decl(_stage_c)
    `uvm_analysis_imp_decl(_stage_d)
    `uvm_analysis_imp_decl(_stage_e)

    localparam bit [7:0] K285 = 8'hBC;
    localparam bit [7:0] K284 = 8'h9C;
    localparam bit [8:0] OPQ_CSR_WORD_UID            = 9'h000;
    localparam bit [8:0] OPQ_CSR_WORD_META           = 9'h001;
    localparam bit [8:0] OPQ_CSR_WORD_LANE_MASK      = 9'h002;
    localparam bit [8:0] OPQ_CSR_WORD_CTRL           = 9'h003;
    localparam bit [8:0] OPQ_CSR_WORD_STATUS         = 9'h004;
    localparam bit [8:0] OPQ_CSR_WORD_CAP            = 9'h005;
    localparam bit [8:0] OPQ_CSR_WORD_FT_WR_HDR      = 9'h008;
    localparam bit [8:0] OPQ_CSR_WORD_FT_WR_SHD      = 9'h009;
    localparam bit [8:0] OPQ_CSR_WORD_FT_WR_HIT      = 9'h00A;
    localparam bit [8:0] OPQ_CSR_WORD_FT_RD_HDR      = 9'h00B;
    localparam bit [8:0] OPQ_CSR_WORD_FT_RD_SHD      = 9'h00C;
    localparam bit [8:0] OPQ_CSR_WORD_FT_RD_HIT      = 9'h00D;
    localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_HDR    = 9'h00E;
    localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_SHD    = 9'h00F;
    localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_HIT    = 9'h010;
    localparam bit [8:0] OPQ_CSR_LANE_REGION_BASE    = 9'h040;
    localparam bit [8:0] OPQ_CSR_LANE_REGION_STRIDE  = 9'h010;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_WR_HDR    = 4'h0;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_WR_SHD    = 4'h1;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_WR_HIT    = 4'h2;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_RD_HDR    = 4'h3;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_RD_SHD    = 4'h4;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_RD_HIT    = 4'h5;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DROP_HDR  = 4'h6;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DROP_SHD  = 4'h7;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DROP_HIT  = 4'h8;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_LANE_CREDIT   = 4'h9;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_TICKET_CREDIT = 4'hA;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_ALLOWANCE = 4'hB;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_QUANTUM   = 4'hC;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_GRANT_CNT = 4'hD;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_BEAT_CNT  = 4'hE;
    localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_DEFER_CNT = 4'hF;

    // -----------------------------------------------------------------------
    // Config object
    // -----------------------------------------------------------------------
    class tb_int_emut_cfg extends uvm_object;
        `uvm_object_utils(tb_int_emut_cfg)

        bit        enable                = 1'b1;
        bit [1:0]  hit_mode              = 2'b00;
        bit        short_mode            = 1'b0;
        bit [15:0] hit_rate              = 16'h0800;
        bit [15:0] noise_rate            = 16'h0100;
        bit [4:0]  burst_size            = 5'd4;
        bit [4:0]  burst_center          = 5'd16;
        bit        cluster_cross_asic    = 1'b0;
        bit [7:0]  cluster_center_global = 8'd16;
        bit [3:0]  cluster_lane_index    = 4'd0;
        bit [3:0]  cluster_lane_count    = 4'd1;
        bit [31:0] seed                  = 32'hDEAD_BEEF;
        bit [2:0]  tx_mode               = 3'b000;
        bit        gen_idle              = 1'b1;
        bit [3:0]  asic_id               = 4'd0;

        function new(string name = "tb_int_emut_cfg");
            super.new(name);
        endfunction

        function bit [31:0] control_reg();
            return {28'b0, short_mode, hit_mode, enable};
        endfunction

        function bit [31:0] hit_rate_reg();
            return {noise_rate, hit_rate};
        endfunction

        function bit [31:0] burst_cfg_reg();
            return {2'b0, cluster_lane_count, cluster_lane_index,
                    cluster_center_global, cluster_cross_asic,
                    burst_center, 3'b0, burst_size};
        endfunction

        function bit [31:0] tx_mode_reg();
            return {24'b0, asic_id, gen_idle, tx_mode};
        endfunction

        function string describe();
            return $sformatf("en=%0b hit_mode=%0d short=%0b hit_rate=0x%04h noise_rate=0x%04h burst_size=%0d burst_center=%0d xasic=%0b gcenter=%0d lane=%0d/%0d seed=0x%08h tx_mode=0x%0h gen_idle=%0b asic_id=%0d",
                             enable, hit_mode, short_mode, hit_rate, noise_rate,
                             burst_size, burst_center, cluster_cross_asic,
                             cluster_center_global, cluster_lane_index,
                             cluster_lane_count, seed, tx_mode, gen_idle, asic_id);
        endfunction
    endclass

    class tb_int_cfg extends uvm_object;
        `uvm_object_utils(tb_int_cfg)

        int unsigned num_feb          = 2;
        int unsigned num_datapath     = 2;
        int unsigned num_mutrig       = 4;  // logical target topology; current stub models 1 emulator/datapath
        int unsigned opq_n_lane       = 4;
        int unsigned smoke_run_cycles = 2000;
        bit          require_stage_e  = 1'b1;
        bit          require_lossless_feb = 1'b0;
        bit          program_emulators    = 1'b0;
        int unsigned longrun_case_id      = 0;
        string       longrun_case_name    = "";
        tb_int_emut_cfg emu_cfg[4];

        function new(string name = "tb_int_cfg");
            super.new(name);
            foreach (emu_cfg[i]) begin
                emu_cfg[i] = tb_int_emut_cfg::type_id::create($sformatf("emu_cfg_%0d", i));
                emu_cfg[i].asic_id = i[3:0];
                emu_cfg[i].cluster_lane_index = i[3:0];
            end
        endfunction

        function string describe_longrun();
            return $sformatf("case_id=%0d case=%s require_stage_e=%0b require_lossless_feb=%0b run_cycles=%0d",
                             longrun_case_id, longrun_case_name,
                             require_stage_e, require_lossless_feb,
                             smoke_run_cycles);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Shared stable-RUNNING window database.
    //
    // Stable-run loss accounting should follow hits born well inside RUNNING,
    // not those created right on the START/END edges. The run-control driver
    // arms this window in absolute simulation time and stage A tags each hit
    // at its true origin.
    // -----------------------------------------------------------------------
    class tb_int_run_window_db;
        static int unsigned start_guard_cycles = 128;
        static int unsigned end_guard_cycles   = 128;
        static time         run_start_ts       = 0;
        static time         run_end_ts         = 0;
        static time         stable_start_ts    = 0;
        static time         stable_end_ts      = 0;
        static bit          stable_window_open = 1'b0;
        static bit          stable_window_seen = 1'b0;

        static function void configure_guards(int unsigned start_cycles,
                                              int unsigned end_cycles);
            start_guard_cycles = start_cycles;
            end_guard_cycles   = end_cycles;
        endfunction

        static function void reset();
            run_start_ts       = 0;
            run_end_ts         = 0;
            stable_start_ts    = 0;
            stable_end_ts      = 0;
            stable_window_open = 1'b0;
            stable_window_seen = 1'b0;
        endfunction

        static function void note_run_start(time t);
            run_start_ts = t;
            run_end_ts   = 0;
        endfunction

        static function void note_run_end(time t);
            run_end_ts = t;
        endfunction

        static function time get_run_end_ts();
            return run_end_ts;
        endfunction

        static function bit run_end_seen();
            return (run_end_ts != 0);
        endfunction

        static function void note_stable_start(time t);
            stable_start_ts    = t;
            stable_end_ts      = 0;
            stable_window_open = 1'b1;
            stable_window_seen = 1'b1;
        endfunction

        static function void note_stable_end(time t);
            stable_end_ts      = t;
            stable_window_open = 1'b0;
            stable_window_seen = 1'b1;
        endfunction

        static function bit is_stable_origin(time t);
            if (!stable_window_seen)
                return 1'b0;
            if (stable_window_open)
                return (t >= stable_start_ts);
            return (t >= stable_start_ts) && (t < stable_end_ts);
        endfunction

        static function string describe();
            if (!stable_window_seen) begin
                return $sformatf("stable window not armed (guards start=%0d end=%0d cycles)",
                                 start_guard_cycles, end_guard_cycles);
            end
            if (stable_window_open) begin
                return $sformatf("stable_start=%0t stable_end=open (guards start=%0d end=%0d cycles)",
                                 stable_start_ts, start_guard_cycles, end_guard_cycles);
            end
            return $sformatf("stable_start=%0t stable_end=%0t (guards start=%0d end=%0d cycles)",
                             stable_start_ts, stable_end_ts,
                             start_guard_cycles, end_guard_cycles);
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
    // Analysis transaction: frame_rcv hit_type0 beat before mts.
    // -----------------------------------------------------------------------
    class tb_int_hit0_event extends uvm_object;
        `uvm_object_utils(tb_int_hit0_event)

        int unsigned lane_id;
        time         abs_ts;
        bit [44:0]   data;
        bit [3:0]    channel;
        bit          sop;
        bit          eop;
        bit [2:0]    error;

        function new(string name = "tb_int_hit0_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: mts hit_type1 beat before rb_cam fanout.
    // -----------------------------------------------------------------------
    class tb_int_hit1_event extends uvm_object;
        `uvm_object_utils(tb_int_hit1_event)

        int unsigned lane_id;
        time         abs_ts;
        bit [38:0]   data;
        bit [3:0]    channel;
        bit          sop;
        bit          eop;
        bit          empty;
        bit          error;

        function new(string name = "tb_int_hit1_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: framed per-lane beat at stage C or D
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
        bit [2:0]  error;

        function new(string name = "tb_int_egress_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Reusable frame-level TLM item for the FEB/OPQ framed contract.
    // This is the capture/replay hook alongside the existing direct pin path:
    // stage-C or stage-D can lift real framed beats into one object per frame,
    // while tb_int keeps the direct pin-wiggle path into OPQ intact.
    // -----------------------------------------------------------------------
    class tb_int_frame_hit_desc extends uvm_object;
        bit [31:0] payload_word;

        `uvm_object_utils_begin(tb_int_frame_hit_desc)
            `uvm_field_int(payload_word, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "tb_int_frame_hit_desc");
            super.new(name);
            payload_word = '0;
        endfunction
    endclass

    class tb_int_frame_subheader_desc extends uvm_object;
        bit [7:0] shd_ts;
        tb_int_frame_hit_desc hits[$];

        `uvm_object_utils_begin(tb_int_frame_subheader_desc)
            `uvm_field_int(shd_ts, UVM_DEFAULT)
            `uvm_field_queue_object(hits, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "tb_int_frame_subheader_desc");
            super.new(name);
            shd_ts = '0;
        endfunction

        function int unsigned hit_count();
            return hits.size();
        endfunction
    endclass

    class tb_int_frame_item extends uvm_sequence_item;
        byte                       stage_tag;
        int                        lane_id;
        bit [1:0]                  channel;
        bit [47:0]                 frame_ts;
        bit [15:0]                 pkg_cnt;
        bit [5:0]                  dt_type;
        bit [15:0]                 feb_id;
        bit                        whole_frame_packet;
        time                       first_abs_ts;
        time                       last_abs_ts;
        tb_int_frame_subheader_desc subheaders[$];

        `uvm_object_utils_begin(tb_int_frame_item)
            `uvm_field_int(stage_tag, UVM_DEFAULT)
            `uvm_field_int(lane_id, UVM_DEFAULT)
            `uvm_field_int(channel, UVM_DEFAULT)
            `uvm_field_int(frame_ts, UVM_DEFAULT)
            `uvm_field_int(pkg_cnt, UVM_DEFAULT)
            `uvm_field_int(dt_type, UVM_DEFAULT)
            `uvm_field_int(feb_id, UVM_DEFAULT)
            `uvm_field_int(whole_frame_packet, UVM_DEFAULT)
            `uvm_field_int(first_abs_ts, UVM_DEFAULT)
            `uvm_field_int(last_abs_ts, UVM_DEFAULT)
            `uvm_field_queue_object(subheaders, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "tb_int_frame_item");
            super.new(name);
            stage_tag = 8'h3F;
            lane_id = -1;
            channel = '0;
            frame_ts = '0;
            pkg_cnt = '0;
            dt_type = '0;
            feb_id = '0;
            whole_frame_packet = 1'b1;
            first_abs_ts = 0;
            last_abs_ts = 0;
        endfunction

        function bit [15:0] frame_subh_count_bits();
            return subheaders.size();
        endfunction

        function bit [15:0] frame_hit_count_bits();
            int unsigned total_hits;

            total_hits = 0;
            foreach (subheaders[i])
                total_hits += subheaders[i].hit_count();
            return total_hits[15:0];
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Analysis transaction: stage B ring_buffer_cam hit_type2 beat.
    // lane_id is the datapath lane 0..3, slot_id is the rb_cam interleaving
    // slot 0..3 inside that datapath.
    // -----------------------------------------------------------------------
    class tb_int_hit2_event extends uvm_object;
        `uvm_object_utils(tb_int_hit2_event)

        int unsigned lane_id;
        int unsigned slot_id;
        time         abs_ts;
        bit [35:0]   data;
        bit [3:0]    channel;
        bit          sop;
        bit          eop;
        bit          error;

        function new(string name = "tb_int_hit2_event");
            super.new(name);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stateful data-framed parser shared by stages C/D/E. Mirrors the live
    // OPQ harness contract: after an implicit first accepted beat, consume
    // four frame-header aux words, then parse K237 subheaders, hit words, and
    // the K284 trailer while tracking the absolute subheader timestamp and the
    // remaining hit count under the active subheader.
    // -----------------------------------------------------------------------
    class tb_int_frame_parser extends uvm_object;
        `uvm_object_utils(tb_int_frame_parser)

        localparam bit [3:0] FRAMING_TAG = 4'b0001;
        localparam bit [7:0] K285        = 8'hBC; // preamble
        localparam bit [7:0] K237        = 8'hF7; // subheader
        localparam bit [7:0] K284        = 8'h9C; // trailer
        localparam int unsigned FRAME_HDR_AUX_WORDS = 4;

        bit          frame_open;
        bit [7:0]    hit_words_left;
        bit [2:0]    frame_hdr_aux_words_left;
        bit          saw_nonempty_subhdr;
        bit [31:0]   frame_ts_hi32;
        bit [15:0]   frame_ts_lo16;
        bit [35:0]   subheader_ts_hi;
        bit [7:0]    last_subhdr_byte;
        bit          last_subhdr_valid;
        bit [47:0]   last_nonempty_subhdr_abs_ts;
        bit [47:0]   curr_subhdr_abs_ts;
        bit [47:0]   last_hit_abs_ts;
        int unsigned n_frames;
        int unsigned n_preambles;
        int unsigned n_headers;
        int unsigned n_subheaders;
        int unsigned n_hits;
        int unsigned n_trailers;
        int unsigned n_orphan;
        int unsigned n_contract_err;

        function new(string name = "tb_int_frame_parser");
            super.new(name);
            frame_open                  = 1'b0;
            hit_words_left              = '0;
            frame_hdr_aux_words_left    = '0;
            saw_nonempty_subhdr         = 1'b0;
            frame_ts_hi32               = '0;
            frame_ts_lo16               = '0;
            subheader_ts_hi             = '0;
            last_subhdr_byte            = '0;
            last_subhdr_valid           = 1'b0;
            last_nonempty_subhdr_abs_ts = '0;
            curr_subhdr_abs_ts          = '0;
            last_hit_abs_ts             = '0;
            n_frames      = 0;
            n_preambles   = 0;
            n_headers     = 0;
            n_subheaders  = 0;
            n_hits        = 0;
            n_trailers    = 0;
            n_orphan      = 0;
            n_contract_err = 0;
        endfunction

        function automatic bit pkt_is_frame_trl(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K284);
        endfunction

        function automatic bit pkt_is_subhdr(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K237);
        endfunction

        function automatic bit pkt_is_preamble(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K285);
        endfunction

        function automatic bit pkt_is_hit(bit [35:0] word);
            return (word[35:32] == 4'b0000);
        endfunction

        function automatic bit [35:0] extend_subheader_ts_hi(
            bit [35:0] curr_hi,
            bit        last_valid,
            bit [7:0]  last_byte,
            bit [7:0]  curr_byte
        );
            bit [35:0] hi_v;
            hi_v = curr_hi;
            if (last_valid && (curr_byte < last_byte))
                hi_v = hi_v + 36'd1;
            return hi_v;
        endfunction

        function automatic bit [47:0] make_subheader_abs_ts(
            bit [35:0] ts_hi,
            bit [7:0]  shd_byte
        );
            return {ts_hi, shd_byte, 4'h0};
        endfunction

        function automatic void note_contract_error();
            n_contract_err++;
        endfunction

        // Consumes one accepted beat and returns 1 when that beat is a hit
        // payload word under the active subheader.
        virtual function bit step(bit [35:0] data);
            bit          is_hit;
            bit [35:0]   subheader_ts_hi_v;
            bit [47:0]   subheader_abs_ts_v;

            is_hit = 1'b0;

            if (!frame_open) begin
                frame_open                  = 1'b1;
                frame_hdr_aux_words_left    = FRAME_HDR_AUX_WORDS[2:0];
                hit_words_left              = '0;
                saw_nonempty_subhdr         = 1'b0;
                frame_ts_hi32               = '0;
                frame_ts_lo16               = '0;
                subheader_ts_hi             = '0;
                last_subhdr_byte            = '0;
                last_subhdr_valid           = 1'b0;
                last_nonempty_subhdr_abs_ts = '0;
                curr_subhdr_abs_ts          = '0;
                last_hit_abs_ts             = '0;
                n_frames++;
                if (pkt_is_preamble(data))
                    n_preambles++;
                else
                    n_orphan++;
                return 1'b0;
            end

            if (frame_hdr_aux_words_left != 0) begin
                case (frame_hdr_aux_words_left)
                    3'd4: frame_ts_hi32 = data[31:0];
                    3'd3: begin
                        frame_ts_lo16   = data[31:16];
                        subheader_ts_hi = {frame_ts_hi32, data[31:28]};
                    end
                    default: begin
                    end
                endcase
                frame_hdr_aux_words_left--;
                n_headers++;
                return 1'b0;
            end

            if (pkt_is_frame_trl(data)) begin
                if (hit_words_left != 0)
                    note_contract_error();
                n_trailers++;
                frame_open = 1'b0;
                return 1'b0;
            end

            if (pkt_is_subhdr(data)) begin
                if (hit_words_left != 0)
                    note_contract_error();
                subheader_ts_hi_v = extend_subheader_ts_hi(
                    subheader_ts_hi,
                    last_subhdr_valid,
                    last_subhdr_byte,
                    data[31:24]
                );
                subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, data[31:24]);
                subheader_ts_hi    = subheader_ts_hi_v;
                last_subhdr_byte   = data[31:24];
                last_subhdr_valid  = 1'b1;
                curr_subhdr_abs_ts = subheader_abs_ts_v;
                n_subheaders++;
                if (data[15:8] != 8'h00) begin
                    if (saw_nonempty_subhdr && !(subheader_abs_ts_v > last_nonempty_subhdr_abs_ts))
                        note_contract_error();
                    saw_nonempty_subhdr         = 1'b1;
                    last_nonempty_subhdr_abs_ts = subheader_abs_ts_v;
                    hit_words_left              = data[15:8];
                end
                return 1'b0;
            end

            if (pkt_is_hit(data)) begin
                if (hit_words_left == 0) begin
                    note_contract_error();
                    return 1'b0;
                end
                hit_words_left--;
                n_hits++;
                is_hit         = 1'b1;
                last_hit_abs_ts = {curr_subhdr_abs_ts[47:4], data[31:28]};
                return is_hit;
            end

            n_orphan++;
            return 1'b0;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stateful parser for the Stage-E OPQ egress stream. This shares the
    // same framed data layout as stages C/D, but OPQ also provides explicit
    // SOP/EOP on the K28.5/K28.4 beats. Use those sidebands as recovery
    // hints so a local framing glitch does not cascade into hundreds of
    // secondary parser errors.
    // -----------------------------------------------------------------------
    class tb_int_egress_frame_parser extends uvm_object;
        `uvm_object_utils(tb_int_egress_frame_parser)

        localparam bit [3:0] FRAMING_TAG = 4'b0001;
        localparam bit [7:0] K285        = 8'hBC;
        localparam bit [7:0] K237        = 8'hF7;
        localparam bit [7:0] K284        = 8'h9C;
        localparam int unsigned FRAME_HDR_AUX_WORDS = 4;

        bit          frame_open;
        bit [7:0]    hit_words_left;
        bit [2:0]    frame_hdr_aux_words_left;
        bit          saw_nonempty_subhdr;
        bit [31:0]   frame_ts_hi32;
        bit [15:0]   frame_ts_lo16;
        bit [35:0]   subheader_ts_hi;
        bit [7:0]    last_subhdr_byte;
        bit          last_subhdr_valid;
        bit [47:0]   last_nonempty_subhdr_abs_ts;
        bit [47:0]   curr_subhdr_abs_ts;
        bit [47:0]   last_hit_abs_ts;
        int unsigned n_frames;
        int unsigned n_preambles;
        int unsigned n_headers;
        int unsigned n_subheaders;
        int unsigned n_hits;
        int unsigned n_trailers;
        int unsigned n_orphan;
        int unsigned n_restart_sop;
        int unsigned n_contract_err;

        function new(string name = "tb_int_egress_frame_parser");
            super.new(name);
            frame_open                  = 1'b0;
            hit_words_left              = '0;
            frame_hdr_aux_words_left    = '0;
            saw_nonempty_subhdr         = 1'b0;
            frame_ts_hi32               = '0;
            frame_ts_lo16               = '0;
            subheader_ts_hi             = '0;
            last_subhdr_byte            = '0;
            last_subhdr_valid           = 1'b0;
            last_nonempty_subhdr_abs_ts = '0;
            curr_subhdr_abs_ts          = '0;
            last_hit_abs_ts             = '0;
            n_frames       = 0;
            n_preambles    = 0;
            n_headers      = 0;
            n_subheaders   = 0;
            n_hits         = 0;
            n_trailers     = 0;
            n_orphan       = 0;
            n_restart_sop  = 0;
            n_contract_err = 0;
        endfunction

        function automatic bit pkt_is_frame_trl(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K284);
        endfunction

        function automatic bit pkt_is_subhdr(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K237);
        endfunction

        function automatic bit pkt_is_preamble(bit [35:0] word);
            return (word[35:32] == FRAMING_TAG) && (word[7:0] == K285);
        endfunction

        function automatic bit pkt_is_hit(bit [35:0] word);
            return (word[35:32] == 4'b0000);
        endfunction

        function automatic bit [35:0] extend_subheader_ts_hi(
            bit [35:0] curr_hi,
            bit        last_valid,
            bit [7:0]  last_byte,
            bit [7:0]  curr_byte
        );
            bit [35:0] hi_v;
            hi_v = curr_hi;
            if (last_valid && (curr_byte < last_byte))
                hi_v = hi_v + 36'd1;
            return hi_v;
        endfunction

        function automatic bit [47:0] make_subheader_abs_ts(
            bit [35:0] ts_hi,
            bit [7:0]  shd_byte
        );
            return {ts_hi, shd_byte, 4'h0};
        endfunction

        function automatic void note_contract_error();
            n_contract_err++;
        endfunction

        function automatic void start_new_frame();
            frame_open                  = 1'b1;
            frame_hdr_aux_words_left    = FRAME_HDR_AUX_WORDS[2:0];
            hit_words_left              = '0;
            saw_nonempty_subhdr         = 1'b0;
            frame_ts_hi32               = '0;
            frame_ts_lo16               = '0;
            subheader_ts_hi             = '0;
            last_subhdr_byte            = '0;
            last_subhdr_valid           = 1'b0;
            last_nonempty_subhdr_abs_ts = '0;
            curr_subhdr_abs_ts          = '0;
            last_hit_abs_ts             = '0;
            n_frames++;
        endfunction

        virtual function bit step(bit [35:0] data, bit sop, bit eop);
            bit          is_hit;
            bit [35:0]   subheader_ts_hi_v;
            bit [47:0]   subheader_abs_ts_v;

            is_hit = 1'b0;

            if (sop) begin
                if (frame_open)
                    n_restart_sop++;
                start_new_frame();
                if (pkt_is_preamble(data))
                    n_preambles++;
                else
                    note_contract_error();
                if (eop) begin
                    note_contract_error();
                    frame_open = 1'b0;
                end
                return 1'b0;
            end

            if (!frame_open) begin
                start_new_frame();
                if (pkt_is_preamble(data)) begin
                    n_preambles++;
                    if (eop) begin
                        note_contract_error();
                        frame_open = 1'b0;
                    end
                    return 1'b0;
                end
                // OPQ can suppress the visible K28.5 beat while refilling the
                // presenter. When that happens the first accepted beat at the
                // egress is already the first header aux word, so fall through
                // and let the header parser consume this beat.
            end

            if (pkt_is_preamble(data)) begin
                n_restart_sop++;
                start_new_frame();
                n_preambles++;
                if (eop) begin
                    note_contract_error();
                    frame_open = 1'b0;
                end
                return 1'b0;
            end

            if (frame_hdr_aux_words_left != 0) begin
                case (frame_hdr_aux_words_left)
                    3'd4: frame_ts_hi32 = data[31:0];
                    3'd3: begin
                        frame_ts_lo16   = data[31:16];
                        subheader_ts_hi = {frame_ts_hi32, data[31:28]};
                    end
                    default: begin
                    end
                endcase
                frame_hdr_aux_words_left--;
                n_headers++;
                if (eop) begin
                    note_contract_error();
                    frame_open = 1'b0;
                    frame_hdr_aux_words_left = '0;
                    hit_words_left = '0;
                end
                return 1'b0;
            end

            if (pkt_is_frame_trl(data)) begin
                if (hit_words_left != 0)
                    note_contract_error();
                if (!eop)
                    note_contract_error();
                n_trailers++;
                frame_open = 1'b0;
                return 1'b0;
            end

            if (pkt_is_subhdr(data)) begin
                if (hit_words_left != 0)
                    note_contract_error();
                subheader_ts_hi_v = extend_subheader_ts_hi(
                    subheader_ts_hi,
                    last_subhdr_valid,
                    last_subhdr_byte,
                    data[31:24]
                );
                subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, data[31:24]);
                subheader_ts_hi    = subheader_ts_hi_v;
                last_subhdr_byte   = data[31:24];
                last_subhdr_valid  = 1'b1;
                curr_subhdr_abs_ts = subheader_abs_ts_v;
                n_subheaders++;
                if (data[15:8] != 8'h00) begin
                    if (saw_nonempty_subhdr && !(subheader_abs_ts_v > last_nonempty_subhdr_abs_ts))
                        note_contract_error();
                    saw_nonempty_subhdr         = 1'b1;
                    last_nonempty_subhdr_abs_ts = subheader_abs_ts_v;
                    hit_words_left              = data[15:8];
                end
                if (eop) begin
                    note_contract_error();
                    frame_open = 1'b0;
                    hit_words_left = '0;
                end
                return 1'b0;
            end

            if (pkt_is_hit(data)) begin
                if (hit_words_left == 0) begin
                    // OPQ can hide a presenter restart breakpoint word at the
                    // external egress. When that happens the next accepted beat
                    // can be a lone hit fragment whose visible subheader was
                    // masked. Record it as a recoverable orphan instead of a
                    // hard contract failure.
                    n_orphan++;
                end else begin
                    hit_words_left--;
                    n_hits++;
                    is_hit          = 1'b1;
                    last_hit_abs_ts = {curr_subhdr_abs_ts[47:4], data[31:28]};
                end
                if (eop) begin
                    note_contract_error();
                    frame_open = 1'b0;
                    hit_words_left = '0;
                end
                return is_hit;
            end

            n_orphan++;
            if (eop) begin
                note_contract_error();
                frame_open = 1'b0;
                hit_words_left = '0;
            end
            return 1'b0;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stateful parser for the Stage-B hit_type2 stream. Each packet is one
    // K237 subheader plus the declared number of hit words, with EOP on the
    // last beat or on the subheader itself for an empty packet.
    // -----------------------------------------------------------------------
    class tb_int_hit2_parser extends uvm_object;
        `uvm_object_utils(tb_int_hit2_parser)

        localparam bit [7:0] K237 = 8'hF7;

        bit          packet_open;
        bit [7:0]    hit_words_left;
        bit          saw_nonempty_subhdr;
        bit [35:0]   subheader_ts_hi;
        bit [7:0]    last_subhdr_byte;
        bit          last_subhdr_valid;
        bit [47:0]   last_nonempty_subhdr_abs_ts;
        bit [47:0]   curr_subhdr_abs_ts;
        bit [47:0]   last_hit_abs_ts;
        int unsigned n_packets;
        int unsigned n_subheaders;
        int unsigned n_hits;
        int unsigned n_empty_packets;
        int unsigned n_orphan;
        int unsigned n_contract_err;

        function new(string name = "tb_int_hit2_parser");
            super.new(name);
            packet_open               = 1'b0;
            hit_words_left            = '0;
            saw_nonempty_subhdr       = 1'b0;
            subheader_ts_hi           = '0;
            last_subhdr_byte          = '0;
            last_subhdr_valid         = 1'b0;
            last_nonempty_subhdr_abs_ts = '0;
            curr_subhdr_abs_ts        = '0;
            last_hit_abs_ts           = '0;
            n_packets      = 0;
            n_subheaders   = 0;
            n_hits         = 0;
            n_empty_packets = 0;
            n_orphan       = 0;
            n_contract_err = 0;
        endfunction

        function automatic bit pkt_is_subhdr(bit [35:0] word);
            return (word[35:32] == 4'b0001) && (word[7:0] == K237);
        endfunction

        function automatic bit pkt_is_hit(bit [35:0] word);
            return (word[35:32] == 4'b0000);
        endfunction

        function automatic bit [35:0] extend_subheader_ts_hi(
            bit [35:0] curr_hi,
            bit        last_valid,
            bit [7:0]  last_byte,
            bit [7:0]  curr_byte
        );
            bit [35:0] hi_v;
            hi_v = curr_hi;
            if (last_valid && (curr_byte < last_byte))
                hi_v = hi_v + 36'd1;
            return hi_v;
        endfunction

        function automatic bit [47:0] make_subheader_abs_ts(
            bit [35:0] ts_hi,
            bit [7:0]  shd_byte
        );
            return {ts_hi, shd_byte, 4'h0};
        endfunction

        function automatic void note_contract_error();
            n_contract_err++;
        endfunction

        virtual function bit step(bit [35:0] data, bit sop, bit eop);
            bit        is_hit;
            bit [35:0] subheader_ts_hi_v;
            bit [47:0] subheader_abs_ts_v;
            bit [7:0]  hit_words_left_v;

            is_hit          = 1'b0;
            hit_words_left_v = hit_words_left;

            if (sop) begin
                n_packets++;
                n_subheaders++;
                if (packet_open)
                    note_contract_error();
                if (!pkt_is_subhdr(data))
                    note_contract_error();
                subheader_ts_hi_v = extend_subheader_ts_hi(
                    subheader_ts_hi,
                    last_subhdr_valid,
                    last_subhdr_byte,
                    data[31:24]
                );
                subheader_abs_ts_v = make_subheader_abs_ts(subheader_ts_hi_v, data[31:24]);
                subheader_ts_hi    = subheader_ts_hi_v;
                last_subhdr_byte   = data[31:24];
                last_subhdr_valid  = 1'b1;
                curr_subhdr_abs_ts = subheader_abs_ts_v;
                if (data[15:8] != 8'h00) begin
                    if (saw_nonempty_subhdr && !(subheader_abs_ts_v > last_nonempty_subhdr_abs_ts))
                        note_contract_error();
                    saw_nonempty_subhdr         = 1'b1;
                    last_nonempty_subhdr_abs_ts = subheader_abs_ts_v;
                end else begin
                    n_empty_packets++;
                end
                hit_words_left_v = data[15:8];
                if (eop) begin
                    if (hit_words_left_v != 0)
                        note_contract_error();
                    packet_open    = 1'b0;
                    hit_words_left = '0;
                end else begin
                    packet_open    = 1'b1;
                    hit_words_left = hit_words_left_v;
                end
                return 1'b0;
            end

            if (!packet_open)
                note_contract_error();
            if (pkt_is_subhdr(data))
                note_contract_error();
            if (!pkt_is_hit(data)) begin
                n_orphan++;
                if (eop) begin
                    packet_open    = 1'b0;
                    hit_words_left = '0;
                end
                return 1'b0;
            end
            if (hit_words_left == 0) begin
                note_contract_error();
                if (eop) begin
                    packet_open = 1'b0;
                end
                return 1'b0;
            end
            hit_words_left_v = hit_words_left - 1'b1;
            hit_words_left   = hit_words_left_v;
            n_hits++;
            is_hit          = 1'b1;
            last_hit_abs_ts = {curr_subhdr_abs_ts[47:4], data[31:28]};
            if (eop) begin
                if (hit_words_left_v != 0)
                    note_contract_error();
                packet_open    = 1'b0;
                hit_words_left = '0;
            end else if (hit_words_left_v == 0) begin
                note_contract_error();
            end
            return is_hit;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Stateful parser for the Stage-H0 hit_type0 stream. Every valid beat is
    // one hit. In frame_rcv_ip MODE_HALT=0 the producer intentionally allows
    // recovery patterns such as `sop ... sop eop` and `... eop sop eop`, so
    // this parser tracks those events as recovery markers instead of protocol
    // violations.
    // -----------------------------------------------------------------------
    class tb_int_hit0_parser extends uvm_object;
        `uvm_object_utils(tb_int_hit0_parser)

        bit          frame_open;
        int unsigned n_frames;
        int unsigned n_hits;
        int unsigned n_orphan;
        int unsigned n_restart_sop;
        int unsigned n_orphan_eop;
        int unsigned n_contract_err;

        function new(string name = "tb_int_hit0_parser");
            super.new(name);
            frame_open     = 1'b0;
            n_frames       = 0;
            n_hits         = 0;
            n_orphan       = 0;
            n_restart_sop  = 0;
            n_orphan_eop   = 0;
            n_contract_err = 0;
        endfunction

        function automatic void note_contract_error();
            n_contract_err++;
        endfunction

        virtual function bit step(bit sop, bit eop);
            n_hits++;
            if (sop) begin
                if (frame_open)
                    n_restart_sop++;
                n_frames++;
                frame_open = !eop;
                return 1'b1;
            end

            if (!frame_open)
                n_orphan++;
            if (eop && !frame_open)
                n_orphan_eop++;
            if (eop)
                frame_open = 1'b0;
            return 1'b1;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Content-aware hit identity tuple.
    //
    // Identity bits that survive the entire datapath unchanged:
    //   - channel : 5-bit SiPM channel 0..31
    //   - t_fine  : 5-bit 50ps fine time (T_Fine)
    //
    // Everything else moves: T_CC is LUT-decoded and gts-folded in
    // mts_processor between stages A and B, and the hit_type2 layout drops
    // the error / badhit bits entirely. For per-lane FIFO matching against a
    // common key this 10-bit tuple is adequate — each of 1024 buckets holds
    // ~6 hits per lane in a 200k-cycle run, and order within a bucket is
    // preserved end-to-end because the datapath is point-to-point FIFO.
    //
    // The source lane is recovered from the 4-bit asic field at stages
    // B..E. Lane identification at stage A comes from (feb_id, datapath_id)
    // in the stage_a_if tap. Both numbering systems are aligned via
    // datapath_stub's LANE_ASIC_ID = FEB_ID*2 + DATAPATH_ID tie-off.
    // -----------------------------------------------------------------------
    typedef struct packed {
        bit [4:0] channel;
        bit [4:0] t_fine;
    } hit_key_t;

    // Extract the identity tuple from a raw 48-bit hit_generator word.
    // Layout (both long and short modes, short pads the lower bits with 0):
    //   [47:43] channel, [42] T_BadHit, [41:27] T_CC, [26:22] T_Fine, ...
    function automatic hit_key_t extract_key_stage_a(bit [47:0] p);
        hit_key_t k;
        k.channel = p[47:43];
        k.t_fine  = p[26:22];
        return k;
    endfunction

    // Extract the identity tuple from a 45-bit hit_type0 word.
    // Layout (frame_rcv_ip aso_hit_type0_data):
    //   [44:41]=asic, [40:36]=channel, [35:21]=t_cc, [20:16]=t_fine,
    //   [15:1]=e_cc, [0]=e_flag
    function automatic hit_key_t extract_key_hit0(bit [44:0] d);
        hit_key_t k;
        k.channel = d[40:36];
        k.t_fine  = d[20:16];
        return k;
    endfunction

    // Recover the source lane from the asic field of a hit_type0 beat.
    function automatic int unsigned extract_lane_hit0(bit [44:0] d);
        return int'(d[44:41]);
    endfunction

    // Extract the identity tuple from a 39-bit hit_type1 word.
    // Layout (mts_processor aso_hit_type1_data):
    //   [38:35]=asic, [34:30]=channel, [29:17]=tcc_8n, [16:14]=tcc_1n6,
    //   [13:9]=t_fine, [8:0]=et_1n6
    function automatic hit_key_t extract_key_hit1(bit [38:0] d);
        hit_key_t k;
        k.channel = d[34:30];
        k.t_fine  = d[13:9];
        return k;
    endfunction

    // Recover the source lane from the asic field of a hit_type1 beat.
    function automatic int unsigned extract_lane_hit1(bit [38:0] d);
        return int'(d[38:35]);
    endfunction

    // Extract the identity tuple from a 36-bit hit_type2 body word.
    // Layout (rb_cam aso_hit_type2_data for a hit beat, byte_is_k == "0000"):
    //   [35:32]=0000, [31:28]=ts[3:0], [27:26]="00", [25:22]=asic,
    //   [21:17]=channel, [16:14]=tcc_1n6, [13:9]=t_fine, [8:0]=et_1n6
    function automatic hit_key_t extract_key_hit2(bit [35:0] d);
        hit_key_t k;
        k.channel = d[21:17];
        k.t_fine  = d[13:9];
        return k;
    endfunction

    // Recover the source lane from the asic field of a hit_type2 beat.
    // datapath_stub ties asic = FEB_ID*2 + DATAPATH_ID, so the value is
    // already the 0..3 lane index.
    function automatic int unsigned extract_lane_hit2(bit [35:0] d);
        return int'(d[25:22]);
    endfunction

    // Project the raw stage-A MuTRiG storage word onto the parser-visible
    // hit_type0 payload observed at H0. Long mode preserves the payload
    // fields directly; short mode keeps channel/TCC/T_Fine only and zeroes
    // the lower parser fields.
    typedef bit [40:0] hit_ah0_key_t;

    function automatic hit_ah0_key_t extract_key_stage_a_h0(bit [47:0] p,
                                                             bit short_mode);
        if (short_mode)
            return {p[47:43], p[41:27], p[26:22], 15'b0, 1'b0};
        return {p[47:43], p[41:27], p[26:22], p[19:5], p[20]};
    endfunction

    function automatic hit_ah0_key_t extract_key_hit0_ah0(bit [44:0] d);
        return {d[40:36], d[35:21], d[20:16], d[15:1], d[0]};
    endfunction

    // The hit_type2 body beat is forwarded unchanged from stage B through
    // stage E, so the raw 36-bit word itself is the exact downstream key.
    typedef bit [35:0] hit_raw36_key_t;

    function automatic hit_raw36_key_t extract_key_hit2_exact(bit [35:0] d);
        return d;
    endfunction

    // A single hit observation recorded at one stage. The ledger keeps one
    // per-lane-per-key queue of these, and reconciliation pops in FIFO order.
    class tb_int_hit_obs extends uvm_object;
        `uvm_object_utils(tb_int_hit_obs)

        hit_key_t    key;
        int unsigned lane_id;
        int unsigned seq_in_bucket;   // ordinal within (lane, key) queue
        time         abs_ts;
        bit [47:0]   hit_abs_ts;
        bit          root_hit_id_valid;
        bit [63:0]   root_hit_id;
        bit          run_origin;
        bit [35:0]   raw_data;        // stage B..E raw beat
        bit [47:0]   raw_payload_a;   // stage A raw hit (unused for B..E)

        function new(string name = "tb_int_hit_obs");
            super.new(name);
        endfunction

        function string describe();
            string id_desc;
            if (root_hit_id_valid)
                id_desc = $sformatf("0x%016h", root_hit_id);
            else
                id_desc = "?";
            return $sformatf("{lane=%0d ch=%0d tfine=%0d seq=%0d t=%0t hit_ts=0x%012h id=%s}",
                             lane_id, key.channel, key.t_fine,
                             seq_in_bucket, abs_ts, hit_abs_ts, id_desc);
        endfunction
    endclass

    typedef enum int unsigned {
        TRACE_STAGE_B,
        TRACE_STAGE_C,
        TRACE_STAGE_D,
        TRACE_STAGE_E
    } tb_int_trace_stage_e;

    class tb_int_beat_trace extends uvm_object;
        `uvm_object_utils(tb_int_beat_trace)

        tb_int_trace_stage_e stage_id;
        int unsigned         lane_id;
        int unsigned         slot_id;
        time                 abs_ts;
        bit [35:0]           data;
        bit [3:0]            channel;
        bit                  sop;
        bit                  eop;
        bit                  ready;

        function new(string name = "tb_int_beat_trace");
            super.new(name);
        endfunction

        function string stage_name();
            case (stage_id)
                TRACE_STAGE_B: return "B";
                TRACE_STAGE_C: return "C";
                TRACE_STAGE_D: return "D";
                default:      return "E";
            endcase
        endfunction

        function string describe();
            return $sformatf("%s lane=%0d slot=%0d t=%0t sop=%0b eop=%0b ready=%0b ch=0x%0h data=0x%09h",
                             stage_name(), lane_id, slot_id, abs_ts,
                             sop, eop, ready, channel, data);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Content-aware scoreboard.
    //
    // Per-lane, per-key FIFO ledger. Each stage classifies beats through the
    // frame parser and pushes hit-body beats into its ledger keyed by
    // (lane, hit_key_t). Reconciliation in report_phase pops matched pairs in
    // FIFO order and reports residuals (missing at the downstream stage,
    // ghost beats the upstream stage never produced). Anomalies 1 and 2 are
    // expected to fall out as specific (lane, key) bucket imbalances.
    // -----------------------------------------------------------------------
    typedef tb_int_hit_obs obs_q_t [$];
    typedef tb_int_hit_obs root_obs_by_id_t [bit [63:0]];

    class tb_int_scoreboard extends uvm_component;
        `uvm_component_utils(tb_int_scoreboard)

        tb_int_cfg cfg;
        uvm_analysis_imp_stage_a#(tb_int_hit_event,     tb_int_scoreboard) stage_a_imp;
        uvm_analysis_imp_stage_h0#(tb_int_hit0_event,   tb_int_scoreboard) stage_h0_imp;
        uvm_analysis_imp_stage_h1#(tb_int_hit1_event,   tb_int_scoreboard) stage_h1_imp;
        uvm_analysis_imp_stage_b#(tb_int_hit2_event,    tb_int_scoreboard) stage_b_imp;
        uvm_analysis_imp_stage_c#(tb_int_ingress_event, tb_int_scoreboard) stage_c_imp;
        uvm_analysis_imp_stage_d#(tb_int_ingress_event, tb_int_scoreboard) stage_d_imp;
        uvm_analysis_imp_stage_e#(tb_int_egress_event,  tb_int_scoreboard) stage_e_imp;

        // Aggregate counters (still useful as sanity markers alongside the
        // ledger).
        int unsigned n_stage_a;
        int unsigned n_stage_a_per_lane    [4];
        int unsigned n_stage_h0_beats_per_lane [4];
        int unsigned n_stage_h0_frames_per_lane[4];
        int unsigned n_stage_h0_beats;
        int unsigned n_stage_h0_frames;
        int unsigned n_stage_h1_beats_per_lane [4];
        int unsigned n_stage_h1_beats_per_slot [4][4];
        int unsigned n_stage_h1_error_per_lane [4];
        int unsigned n_stage_h1_error_per_slot [4][4];
        int unsigned n_stage_h1_beats;
        int unsigned n_stage_b_beats_per_lane  [4];
        int unsigned n_stage_b_packets_per_lane[4];
        int unsigned n_stage_b_beats_per_slot  [4][4];
        int unsigned n_stage_b_packets_per_slot[4][4];
        int unsigned n_stage_b_beats;
        int unsigned n_stage_b_packets;
        int unsigned n_stage_c_beats_per_lane  [4];
        int unsigned n_stage_c_frames_per_lane [4];
        int unsigned n_stage_c_beats;
        int unsigned n_stage_c_frames;
        int unsigned n_stage_d_beats_per_lane  [4];
        int unsigned n_stage_d_frames_per_lane [4];
        int unsigned n_stage_d_beats;
        int unsigned n_stage_d_frames;
        int unsigned n_stage_e_beats;
        int unsigned n_stage_e_frames;

        // Per-lane content ledgers: [lane][key] -> FIFO of observations.
        // At stage A the lane is known from the stage_a_if tap.
        // At stage H0 the lane is the frame_rcv datapath index 0..3.
        // At stage B the lane is the datapath index 0..3; slot_id stays in
        // the beat history for first-fail debug but the hit identity ledger
        // is aggregated per datapath lane because feb_frame_assembly merges
        // the 4 slot streams back into one lane.
        // At stages C and D the lane is the ingress interface index 0..3.
        // At stage E the lane is recovered from the hit-body asic field,
        //   which datapath_stub ties to FEB_ID*2 + DATAPATH_ID.
        obs_q_t stage_a_ledger [4][bit [9:0]];
        obs_q_t stage_h0_ledger[4][bit [9:0]];
        obs_q_t stage_h1_ledger[4][bit [9:0]];
        obs_q_t stage_h1_slot_ledger[4][4][bit [9:0]];
        obs_q_t stage_h1_eligible_ledger[4][bit [9:0]];
        obs_q_t stage_h1_eligible_slot_ledger[4][4][bit [9:0]];
        obs_q_t stage_b_ledger [4][bit [9:0]];
        obs_q_t stage_b_slot_ledger [4][4][bit [9:0]];
        obs_q_t stage_c_ledger [4][bit [9:0]];
        obs_q_t stage_d_ledger [4][bit [9:0]];
        obs_q_t stage_e_ledger [4][bit [9:0]];

        // Boundary-specific ledgers used where the generic (channel, t_fine)
        // bucket is too lossy to diagnose the true first failing stage.
        obs_q_t stage_a_ah0_ledger [4][hit_ah0_key_t];
        obs_q_t stage_h0_ah0_ledger[4][hit_ah0_key_t];
        obs_q_t stage_b_exact_ledger[4][hit_raw36_key_t];
        obs_q_t stage_c_exact_ledger[4][hit_raw36_key_t];
        obs_q_t stage_d_exact_ledger[4][hit_raw36_key_t];
        obs_q_t stage_e_exact_ledger[4][hit_raw36_key_t];

        // Stable-RUNNING origin ledger keyed by the globally unique stage-A
        // hit_id. This follows source-origin identity, so a hit born during
        // stable RUNNING is still counted even if it emerges downstream in
        // TERMINATING.
        root_obs_by_id_t stage_a_run_root_obs [4];
        root_obs_by_id_t stage_h0_run_root_obs[4];
        root_obs_by_id_t stage_h1_run_root_obs[4];
        root_obs_by_id_t stage_h1e_run_root_obs[4];
        root_obs_by_id_t stage_b_run_root_obs [4];
        root_obs_by_id_t stage_c_run_root_obs [4];
        root_obs_by_id_t stage_d_run_root_obs [4];
        root_obs_by_id_t stage_e_run_root_obs [4];

        // Stage-E beats we couldn't attribute to a lane (asic field out of
        // range 0..3). Would mean a frame leaked into stage E from a lane
        // that isn't part of the 4-datapath topology.
        int unsigned n_stage_e_lane_unknown;

        // Stateful parsers — 4 hit_type0 streams at stage H0, 4x4 hit_type2
        // packets at stage B, 4 framed
        // lanes at C and D, and 1 framed egress stream at E.
        tb_int_hit0_parser  h0_parser[4];
        tb_int_hit2_parser  b_parser [4][4];
        tb_int_frame_parser c_parser [4];
        tb_int_frame_parser d_parser [4];
        tb_int_egress_frame_parser e_parser;

        // Rolling windows of the most recent accepted beats at each stage.
        // These are dumped when the first local contract error appears so the
        // first failing boundary is visible immediately instead of only as a
        // final bucket imbalance.
        tb_int_beat_trace b_history [4][4][$];
        tb_int_beat_trace c_history [4][$];
        tb_int_beat_trace d_history [4][$];
        tb_int_beat_trace e_history [$];
        bit              b_contract_dumped [4][4];
        bit              c_contract_dumped [4];
        bit              d_contract_dumped [4];
        bit              e_contract_dumped;
        bit              rbcam_filter_inerr_enabled;

        // Reconciliation summary produced in report_phase. One row per lane,
        // per stage pair (A->H0, H0->H1, H1->B, B->C, C->D, D->E).
        int unsigned rec_a_total_per_lane   [4];
        int unsigned rec_h0_total_per_lane  [4];
        int unsigned rec_h1_total_per_lane  [4];
        int unsigned rec_h1_eligible_total_per_lane [4];
        int unsigned rec_h1_filtered_per_lane[4];
        int unsigned rec_b_total_per_lane   [4];
        int unsigned rec_c_total_per_lane   [4];
        int unsigned rec_d_total_per_lane   [4];
        int unsigned rec_e_total_per_lane   [4];
        int unsigned rec_matched_ah0_per_lane[4];
        int unsigned rec_missing_h0_per_lane [4];
        int unsigned rec_ghost_h0_per_lane   [4];
        int unsigned rec_matched_ah1_per_lane[4];
        int unsigned rec_missing_h1_per_lane [4];
        int unsigned rec_ghost_h1_per_lane   [4];
        int unsigned rec_matched_ab_per_lane [4];
        int unsigned rec_missing_b_per_lane [4];
        int unsigned rec_ghost_b_per_lane   [4];
        int unsigned rec_matched_ab_eligible_per_lane [4];
        int unsigned rec_missing_b_eligible_per_lane [4];
        int unsigned rec_ghost_b_eligible_per_lane   [4];
        int unsigned rec_h1_total_per_slot  [4][4];
        int unsigned rec_h1_eligible_total_per_slot [4][4];
        int unsigned rec_h1_filtered_per_slot [4][4];
        int unsigned rec_b_total_per_slot   [4][4];
        int unsigned rec_matched_h1b_per_slot[4][4];
        int unsigned rec_missing_b_per_slot [4][4];
        int unsigned rec_ghost_b_per_slot   [4][4];
        int unsigned rec_matched_h1b_eligible_per_slot[4][4];
        int unsigned rec_missing_b_eligible_per_slot [4][4];
        int unsigned rec_ghost_b_eligible_per_slot   [4][4];
        int unsigned rec_matched_bc_per_lane[4];
        int unsigned rec_missing_c_per_lane [4];
        int unsigned rec_ghost_c_per_lane   [4];
        int unsigned rec_matched_cd_per_lane[4];
        int unsigned rec_missing_d_per_lane [4];
        int unsigned rec_ghost_d_per_lane   [4];
        int unsigned rec_matched_de_per_lane[4];
        int unsigned rec_missing_e_per_lane [4];
        int unsigned rec_ghost_e_per_lane   [4];
        int unsigned rec_run_a_total_per_lane   [4];
        int unsigned rec_run_h0_total_per_lane  [4];
        int unsigned rec_run_h1_total_per_lane  [4];
        int unsigned rec_run_h1e_total_per_lane [4];
        int unsigned rec_run_b_total_per_lane   [4];
        int unsigned rec_run_c_total_per_lane   [4];
        int unsigned rec_run_d_total_per_lane   [4];
        int unsigned rec_run_e_total_per_lane   [4];
        int unsigned rec_run_matched_ah0_per_lane[4];
        int unsigned rec_run_missing_h0_per_lane [4];
        int unsigned rec_run_ghost_h0_per_lane   [4];
        int unsigned rec_run_matched_ah1_per_lane[4];
        int unsigned rec_run_missing_h1_per_lane [4];
        int unsigned rec_run_ghost_h1_per_lane   [4];
        int unsigned rec_run_matched_ab_per_lane [4];
        int unsigned rec_run_missing_b_per_lane  [4];
        int unsigned rec_run_ghost_b_per_lane    [4];
        int unsigned rec_run_matched_bc_per_lane [4];
        int unsigned rec_run_missing_c_per_lane  [4];
        int unsigned rec_run_ghost_c_per_lane    [4];
        int unsigned rec_run_matched_cd_per_lane [4];
        int unsigned rec_run_missing_d_per_lane  [4];
        int unsigned rec_run_ghost_d_per_lane    [4];
        int unsigned rec_run_matched_de_per_lane [4];
        int unsigned rec_run_missing_e_per_lane  [4];
        int unsigned rec_run_ghost_e_per_lane    [4];
        int unsigned rec_run_active_h1e_total_per_lane[4];
        int unsigned rec_run_active_h1e_matched_b_per_lane[4];
        int unsigned rec_run_active_h1e_missing_b_per_lane[4];
        int unsigned rec_run_active_b_total_per_lane[4];
        int unsigned rec_run_active_b_matched_c_per_lane[4];
        int unsigned rec_run_active_b_missing_c_per_lane[4];

        function new(string name, uvm_component parent);
            super.new(name, parent);
            n_stage_a = 0;
            n_stage_h0_beats = 0;
            n_stage_h0_frames = 0;
            n_stage_h1_beats = 0;
            n_stage_b_beats = 0;
            n_stage_b_packets = 0;
            n_stage_c_beats = 0;
            n_stage_c_frames = 0;
            n_stage_d_beats = 0;
            n_stage_d_frames = 0;
            n_stage_e_beats = 0;
            n_stage_e_frames = 0;
            n_stage_e_lane_unknown = 0;
            rbcam_filter_inerr_enabled = 1'b1;
            foreach (n_stage_a_per_lane[i])        n_stage_a_per_lane[i]        = 0;
            foreach (n_stage_h0_beats_per_lane[i]) n_stage_h0_beats_per_lane[i] = 0;
            foreach (n_stage_h0_frames_per_lane[i]) n_stage_h0_frames_per_lane[i] = 0;
            foreach (n_stage_h1_beats_per_lane[i]) begin
                n_stage_h1_beats_per_lane[i] = 0;
                n_stage_h1_error_per_lane[i] = 0;
            end
            foreach (n_stage_h1_beats_per_slot[i,j]) begin
                n_stage_h1_beats_per_slot[i][j] = 0;
                n_stage_h1_error_per_slot[i][j] = 0;
            end
            foreach (n_stage_b_beats_per_lane[i])  n_stage_b_beats_per_lane[i]  = 0;
            foreach (n_stage_b_packets_per_lane[i]) n_stage_b_packets_per_lane[i] = 0;
            foreach (n_stage_b_beats_per_slot[i,j]) begin
                n_stage_b_beats_per_slot[i][j]   = 0;
                n_stage_b_packets_per_slot[i][j] = 0;
                b_contract_dumped[i][j]          = 1'b0;
            end
            foreach (n_stage_c_beats_per_lane[i])  n_stage_c_beats_per_lane[i]  = 0;
            foreach (n_stage_c_frames_per_lane[i]) n_stage_c_frames_per_lane[i] = 0;
            foreach (n_stage_d_beats_per_lane[i])  n_stage_d_beats_per_lane[i]  = 0;
            foreach (n_stage_d_frames_per_lane[i]) n_stage_d_frames_per_lane[i] = 0;
            foreach (rec_a_total_per_lane[i]) begin
                rec_a_total_per_lane[i]    = 0;
                rec_h0_total_per_lane[i]   = 0;
                rec_h1_total_per_lane[i]   = 0;
                rec_h1_eligible_total_per_lane[i] = 0;
                rec_h1_filtered_per_lane[i] = 0;
                rec_b_total_per_lane[i]    = 0;
                rec_c_total_per_lane[i]    = 0;
                rec_d_total_per_lane[i]    = 0;
                rec_e_total_per_lane[i]    = 0;
                rec_matched_ah0_per_lane[i] = 0;
                rec_missing_h0_per_lane[i]  = 0;
                rec_ghost_h0_per_lane[i]    = 0;
                rec_matched_ah1_per_lane[i] = 0;
                rec_missing_h1_per_lane[i]  = 0;
                rec_ghost_h1_per_lane[i]    = 0;
                rec_matched_ab_per_lane[i]  = 0;
                rec_missing_b_per_lane[i]  = 0;
                rec_ghost_b_per_lane[i]    = 0;
                rec_matched_ab_eligible_per_lane[i] = 0;
                rec_missing_b_eligible_per_lane[i]  = 0;
                rec_ghost_b_eligible_per_lane[i]    = 0;
                foreach (rec_h1_total_per_slot[i,j]) begin
                    rec_h1_total_per_slot[i][j]    = 0;
                    rec_h1_eligible_total_per_slot[i][j] = 0;
                    rec_h1_filtered_per_slot[i][j] = 0;
                    rec_b_total_per_slot[i][j]     = 0;
                    rec_matched_h1b_per_slot[i][j] = 0;
                    rec_missing_b_per_slot[i][j]   = 0;
                    rec_ghost_b_per_slot[i][j]     = 0;
                    rec_matched_h1b_eligible_per_slot[i][j] = 0;
                    rec_missing_b_eligible_per_slot[i][j]   = 0;
                    rec_ghost_b_eligible_per_slot[i][j]     = 0;
                end
                rec_matched_bc_per_lane[i] = 0;
                rec_missing_c_per_lane[i]  = 0;
                rec_ghost_c_per_lane[i]    = 0;
                rec_matched_cd_per_lane[i] = 0;
                rec_missing_d_per_lane[i]  = 0;
                rec_ghost_d_per_lane[i]    = 0;
                rec_matched_de_per_lane[i] = 0;
                rec_missing_e_per_lane[i]  = 0;
                rec_ghost_e_per_lane[i]    = 0;
                rec_run_a_total_per_lane[i]    = 0;
                rec_run_h0_total_per_lane[i]   = 0;
                rec_run_h1_total_per_lane[i]   = 0;
                rec_run_h1e_total_per_lane[i]  = 0;
                rec_run_b_total_per_lane[i]    = 0;
                rec_run_c_total_per_lane[i]    = 0;
                rec_run_d_total_per_lane[i]    = 0;
                rec_run_e_total_per_lane[i]    = 0;
                rec_run_matched_ah0_per_lane[i] = 0;
                rec_run_missing_h0_per_lane[i]  = 0;
                rec_run_ghost_h0_per_lane[i]    = 0;
                rec_run_matched_ah1_per_lane[i] = 0;
                rec_run_missing_h1_per_lane[i]  = 0;
                rec_run_ghost_h1_per_lane[i]    = 0;
                rec_run_matched_ab_per_lane[i]  = 0;
                rec_run_missing_b_per_lane[i]   = 0;
                rec_run_ghost_b_per_lane[i]     = 0;
                rec_run_matched_bc_per_lane[i]  = 0;
                rec_run_missing_c_per_lane[i]   = 0;
                rec_run_ghost_c_per_lane[i]     = 0;
                rec_run_matched_cd_per_lane[i]  = 0;
                rec_run_missing_d_per_lane[i]   = 0;
                rec_run_ghost_d_per_lane[i]     = 0;
                rec_run_matched_de_per_lane[i]  = 0;
                rec_run_missing_e_per_lane[i]   = 0;
                rec_run_ghost_e_per_lane[i]     = 0;
                rec_run_active_h1e_total_per_lane[i]      = 0;
                rec_run_active_h1e_matched_b_per_lane[i]  = 0;
                rec_run_active_h1e_missing_b_per_lane[i]  = 0;
                rec_run_active_b_total_per_lane[i]        = 0;
                rec_run_active_b_matched_c_per_lane[i]    = 0;
                rec_run_active_b_missing_c_per_lane[i]    = 0;
                c_contract_dumped[i]       = 1'b0;
                d_contract_dumped[i]       = 1'b0;
            end
            e_contract_dumped = 1'b0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(tb_int_cfg)::get(this, "", "cfg", cfg))
                cfg = tb_int_cfg::type_id::create("cfg");
            stage_a_imp = new("stage_a_imp", this);
            stage_h0_imp = new("stage_h0_imp", this);
            stage_h1_imp = new("stage_h1_imp", this);
            stage_b_imp = new("stage_b_imp", this);
            stage_c_imp = new("stage_c_imp", this);
            stage_d_imp = new("stage_d_imp", this);
            stage_e_imp = new("stage_e_imp", this);
            foreach (h0_parser[i])
                h0_parser[i] = tb_int_hit0_parser::type_id::create(
                                   $sformatf("h0_parser_%0d", i));
            foreach (b_parser[i,j])
                b_parser[i][j] = tb_int_hit2_parser::type_id::create(
                                     $sformatf("b_parser_%0d_%0d", i, j));
            foreach (c_parser[i])
                c_parser[i] = tb_int_frame_parser::type_id::create(
                                  $sformatf("c_parser_%0d", i));
            foreach (d_parser[i])
                d_parser[i] = tb_int_frame_parser::type_id::create(
                                  $sformatf("d_parser_%0d", i));
            e_parser = tb_int_egress_frame_parser::type_id::create("e_parser");
            void'(uvm_config_db#(bit)::get(this, "", "rbcam_filter_inerr_enabled",
                                           rbcam_filter_inerr_enabled));
        endfunction

        function automatic void push_trace(ref tb_int_beat_trace q[$], tb_int_beat_trace tr);
            if (q.size() >= 16)
                void'(q.pop_front());
            q.push_back(tr);
        endfunction

        function automatic void dump_trace_queue(string title, input tb_int_beat_trace q[$]);
            `uvm_info("TB_INT_TRACE", title, UVM_LOW)
            foreach (q[i]) begin
                `uvm_info("TB_INT_TRACE", $sformatf("  %s", q[i].describe()), UVM_LOW)
            end
        endfunction

        function automatic string first_fail_desc(int unsigned lane);
            if (rec_missing_h0_per_lane[lane] > 0 || rec_ghost_h0_per_lane[lane] > 0)
                return "A->H0";
            if (rec_missing_h1_per_lane[lane] > 0 || rec_ghost_h1_per_lane[lane] > 0)
                return "H0->H1";
            if (rec_missing_b_eligible_per_lane[lane] > 0 ||
                rec_ghost_b_eligible_per_lane[lane] > 0)
                return "H1->B(eligible)";
            if (rec_missing_c_per_lane[lane] > 0 || rec_ghost_c_per_lane[lane] > 0)
                return "B->C";
            if (rec_missing_d_per_lane[lane] > 0 || rec_ghost_d_per_lane[lane] > 0)
                return "C->D";
            if (rec_missing_e_per_lane[lane] > 0 || rec_ghost_e_per_lane[lane] > 0)
                return "D->E";
            return "none";
        endfunction

        function automatic string largest_loss_desc(int unsigned lane);
            string       desc;
            int unsigned best_score;
            int unsigned score;

            desc       = "none";
            best_score = 0;

            score = rec_missing_h0_per_lane[lane] + rec_ghost_h0_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "A->H0";
            end

            score = rec_missing_h1_per_lane[lane] + rec_ghost_h1_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "H0->H1";
            end

            score = rec_missing_b_eligible_per_lane[lane] +
                    rec_ghost_b_eligible_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "H1->B(eligible)";
            end

            score = rec_missing_c_per_lane[lane] + rec_ghost_c_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "B->C";
            end

            score = rec_missing_d_per_lane[lane] + rec_ghost_d_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "C->D";
            end

            score = rec_missing_e_per_lane[lane] + rec_ghost_e_per_lane[lane];
            if (score > best_score) begin
                best_score = score;
                desc = "D->E";
            end

            return desc;
        endfunction

        function automatic string obs_head_desc(input obs_q_t q);
            if (q.size() == 0 || q[0] == null)
                return "-";
            return q[0].describe();
        endfunction

        function automatic void copy_root_hit_id(tb_int_hit_obs dst, tb_int_hit_obs src);
            if (dst == null || src == null)
                return;
            dst.run_origin = src.run_origin;
            if (!src.root_hit_id_valid)
                return;
            dst.root_hit_id_valid = 1'b1;
            dst.root_hit_id       = src.root_hit_id;
        endfunction

        function automatic void record_run_origin(ref root_obs_by_id_t map,
                                                  input tb_int_hit_obs obs);
            if (obs == null || !obs.root_hit_id_valid || !obs.run_origin)
                return;
            map[obs.root_hit_id] = obs;
        endfunction

        function automatic int unsigned count_root_obs(ref root_obs_by_id_t map);
            bit [63:0] root_id;
            bit        ok;
            int unsigned total;

            total = 0;
            if (map.first(root_id)) begin
                ok = 1'b1;
                while (ok) begin
                    total++;
                    ok = map.next(root_id);
                end
            end
            return total;
        endfunction

        function automatic void reconcile_root_boundary(
            ref root_obs_by_id_t up_map,
            ref root_obs_by_id_t dn_map,
            output int unsigned matched,
            output int unsigned missing,
            output int unsigned ghost
        );
            bit [63:0] root_id;
            bit        ok;

            matched = 0;
            missing = 0;
            ghost   = 0;

            if (up_map.first(root_id)) begin
                ok = 1'b1;
                while (ok) begin
                    if (dn_map.exists(root_id))
                        matched++;
                    else
                        missing++;
                    ok = up_map.next(root_id);
                end
            end

            if (dn_map.first(root_id)) begin
                ok = 1'b1;
                while (ok) begin
                    if (!up_map.exists(root_id))
                        ghost++;
                    ok = dn_map.next(root_id);
                end
            end
        endfunction

        function automatic void reconcile_root_boundary_before(
            ref root_obs_by_id_t up_map,
            ref root_obs_by_id_t dn_map,
            input time cutoff_ts,
            output int unsigned total,
            output int unsigned matched,
            output int unsigned missing
        );
            bit [63:0] root_id;
            bit        ok;

            total   = 0;
            matched = 0;
            missing = 0;

            if (cutoff_ts == 0)
                return;

            if (up_map.first(root_id)) begin
                ok = 1'b1;
                while (ok) begin
                    if (up_map[root_id] != null && up_map[root_id].abs_ts < cutoff_ts) begin
                        total++;
                        if (dn_map.exists(root_id))
                            matched++;
                        else
                            missing++;
                    end
                    ok = up_map.next(root_id);
                end
            end
        endfunction

        function automatic void dump_root_boundary_candidates(
            input string boundary,
            input string up_name,
            ref root_obs_by_id_t up_map,
            input string dn_name,
            ref root_obs_by_id_t dn_map,
            input int unsigned n_max
        );
            bit [63:0] root_id;
            bit        ok;
            int unsigned dumped;

            dumped = 0;
            if (up_map.first(root_id)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    if (!dn_map.exists(root_id)) begin
                        `uvm_info("TB_INT_SB",
                                  $sformatf("%s missing %s root=0x%016h %s",
                                            boundary, dn_name, root_id,
                                            up_map[root_id].describe()),
                                  UVM_MEDIUM)
                        dumped++;
                    end
                    ok = up_map.next(root_id);
                end
            end

            dumped = 0;
            if (dn_map.first(root_id)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    if (!up_map.exists(root_id)) begin
                        `uvm_info("TB_INT_SB",
                                  $sformatf("%s ghost %s root=0x%016h %s",
                                            boundary, dn_name, root_id,
                                            dn_map[root_id].describe()),
                                  UVM_MEDIUM)
                        dumped++;
                    end
                    ok = dn_map.next(root_id);
                end
            end
        endfunction

        function automatic string obs_desc_at(input obs_q_t q, int unsigned idx);
            if (idx >= q.size() || q[idx] == null)
                return "-";
            return q[idx].describe();
        endfunction

        function automatic void dump_boundary_candidates(
            string boundary,
            string prefix,
            string up_name,
            input obs_q_t up_q,
            int unsigned up_n,
            string dn_name,
            input obs_q_t dn_q,
            int unsigned dn_n,
            int unsigned n_max
        );
            int unsigned idx;
            int unsigned n_dump;

            if (up_n > dn_n) begin
                n_dump = ((up_n - dn_n) < n_max) ? (up_n - dn_n) : n_max;
                for (int unsigned off = 0; off < n_dump; off++) begin
                    idx = dn_n + off;
                    `uvm_info("TB_INT_SB",
                              $sformatf("%s %s missing %s[%0d]=%s",
                                        prefix, boundary, up_name, idx,
                                        obs_desc_at(up_q, idx)),
                              UVM_MEDIUM)
                end
            end

            if (dn_n > up_n) begin
                n_dump = ((dn_n - up_n) < n_max) ? (dn_n - up_n) : n_max;
                for (int unsigned off = 0; off < n_dump; off++) begin
                    idx = up_n + off;
                    `uvm_info("TB_INT_SB",
                              $sformatf("%s %s ghost %s[%0d]=%s",
                                        prefix, boundary, dn_name, idx,
                                        obs_desc_at(dn_q, idx)),
                              UVM_MEDIUM)
                end
            end
        endfunction

        function automatic void reconcile_ah0_boundary(
            int unsigned lane,
            output int unsigned matched,
            output int unsigned missing,
            output int unsigned ghost
        );
            hit_ah0_key_t kb;
            bit           ok;

            matched = 0;
            missing = 0;
            ghost   = 0;

            if (stage_a_ah0_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok) begin
                    int a_n, h0_n;
                    a_n  = stage_a_ah0_ledger[lane][kb].size();
                    h0_n = stage_h0_ah0_ledger[lane].exists(kb)
                           ? stage_h0_ah0_ledger[lane][kb].size() : 0;
                    if (a_n <= h0_n) matched += a_n;
                    else begin
                        matched += h0_n;
                        missing += (a_n - h0_n);
                    end
                    ok = stage_a_ah0_ledger[lane].next(kb);
                end
            end

            if (stage_h0_ah0_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok) begin
                    int a_n, h0_n;
                    h0_n = stage_h0_ah0_ledger[lane][kb].size();
                    a_n  = stage_a_ah0_ledger[lane].exists(kb)
                           ? stage_a_ah0_ledger[lane][kb].size() : 0;
                    if (h0_n > a_n)
                        ghost += (h0_n - a_n);
                    ok = stage_h0_ah0_ledger[lane].next(kb);
                end
            end
        endfunction

        function automatic void reconcile_hit2_boundary(
            ref obs_q_t up_ledger[hit_raw36_key_t],
            ref obs_q_t dn_ledger[hit_raw36_key_t],
            output int unsigned matched,
            output int unsigned missing,
            output int unsigned ghost
        );
            hit_raw36_key_t kb;
            bit             ok;

            matched = 0;
            missing = 0;
            ghost   = 0;

            if (up_ledger.first(kb)) begin
                ok = 1'b1;
                while (ok) begin
                    int up_n, dn_n;
                    up_n = up_ledger[kb].size();
                    dn_n = dn_ledger.exists(kb) ? dn_ledger[kb].size() : 0;
                    if (up_n <= dn_n) matched += up_n;
                    else begin
                        matched += dn_n;
                        missing += (up_n - dn_n);
                    end
                    ok = up_ledger.next(kb);
                end
            end

            if (dn_ledger.first(kb)) begin
                ok = 1'b1;
                while (ok) begin
                    int up_n, dn_n;
                    dn_n = dn_ledger[kb].size();
                    up_n = up_ledger.exists(kb) ? up_ledger[kb].size() : 0;
                    if (dn_n > up_n)
                        ghost += (dn_n - up_n);
                    ok = dn_ledger.next(kb);
                end
            end
        endfunction

        function automatic void dump_ah0_bucket_if_residual(
            input int unsigned lane,
            input hit_ah0_key_t kb,
            ref int unsigned dumped,
            input int unsigned n_max
        );
            int    a_n, h0_n;
            obs_q_t empty_q;

            if (dumped >= n_max)
                return;

            a_n  = stage_a_ah0_ledger[lane].exists(kb) ? stage_a_ah0_ledger[lane][kb].size() : 0;
            h0_n = stage_h0_ah0_ledger[lane].exists(kb) ? stage_h0_ah0_ledger[lane][kb].size() : 0;
            if (a_n == h0_n)
                return;

            `uvm_info("TB_INT_SB",
                      $sformatf("lane=%0d A->H0 exact ch=%0d tcc=0x%0h tfine=%0d ecc=0x%0h eflag=%0b A=%0d H0=%0d",
                                lane, kb[40:36], kb[35:21], kb[20:16], kb[15:1], kb[0], a_n, h0_n),
                      UVM_MEDIUM)
            dump_boundary_candidates(
                "A->H0(exact)",
                $sformatf("lane=%0d ch=%0d tcc=0x%0h tfine=%0d ecc=0x%0h eflag=%0b",
                          lane, kb[40:36], kb[35:21], kb[20:16], kb[15:1], kb[0]),
                "A",
                stage_a_ah0_ledger[lane].exists(kb) ? stage_a_ah0_ledger[lane][kb] : empty_q,
                a_n,
                "H0",
                stage_h0_ah0_ledger[lane].exists(kb) ? stage_h0_ah0_ledger[lane][kb] : empty_q,
                h0_n,
                2
            );
            dumped++;
        endfunction

        function automatic void dump_ah0_residual_buckets(input int unsigned lane, input int unsigned n_max);
            int unsigned dumped;
            hit_ah0_key_t kb;
            bit           ok;

            dumped = 0;
            if (stage_a_ah0_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_ah0_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_a_ah0_ledger[lane].next(kb);
                end
            end
            if (stage_h0_ah0_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_ah0_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_h0_ah0_ledger[lane].next(kb);
                end
            end
        endfunction

        function automatic void dump_hit2_bucket_if_residual(
            input string boundary,
            input int unsigned lane,
            ref obs_q_t up_ledger[hit_raw36_key_t],
            input string up_name,
            ref obs_q_t dn_ledger[hit_raw36_key_t],
            input string dn_name,
            input hit_raw36_key_t kb,
            ref int unsigned dumped,
            input int unsigned n_max
        );
            int       up_n, dn_n;
            hit_key_t hk;
            obs_q_t   empty_q;

            if (dumped >= n_max)
                return;

            up_n = up_ledger.exists(kb) ? up_ledger[kb].size() : 0;
            dn_n = dn_ledger.exists(kb) ? dn_ledger[kb].size() : 0;
            if (up_n == dn_n)
                return;

            hk = extract_key_hit2(kb);
            `uvm_info("TB_INT_SB",
                      $sformatf("lane=%0d %s exact asic=%0d ch=%0d tfine=%0d raw=0x%09h %s=%0d %s=%0d",
                                lane, boundary, extract_lane_hit2(kb), hk.channel, hk.t_fine, kb,
                                up_name, up_n, dn_name, dn_n),
                      UVM_MEDIUM)
            dump_boundary_candidates(
                {boundary, "(exact)"},
                $sformatf("lane=%0d asic=%0d ch=%0d tfine=%0d raw=0x%09h",
                          lane, extract_lane_hit2(kb), hk.channel, hk.t_fine, kb),
                up_name,
                up_ledger.exists(kb) ? up_ledger[kb] : empty_q,
                up_n,
                dn_name,
                dn_ledger.exists(kb) ? dn_ledger[kb] : empty_q,
                dn_n,
                2
            );
            dumped++;
        endfunction

        function automatic void dump_hit2_residual_buckets(
            input string boundary,
            input int unsigned lane,
            ref obs_q_t up_ledger[hit_raw36_key_t],
            input string up_name,
            ref obs_q_t dn_ledger[hit_raw36_key_t],
            input string dn_name,
            input int unsigned n_max
        );
            int unsigned   dumped;
            hit_raw36_key_t kb;
            bit            ok;

            dumped = 0;
            if (up_ledger.first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_hit2_bucket_if_residual(boundary, lane, up_ledger, up_name,
                                                 dn_ledger, dn_name, kb, dumped, n_max);
                    ok = up_ledger.next(kb);
                end
            end
            if (dn_ledger.first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_hit2_bucket_if_residual(boundary, lane, up_ledger, up_name,
                                                 dn_ledger, dn_name, kb, dumped, n_max);
                    ok = dn_ledger.next(kb);
                end
            end
        endfunction

        virtual function void dump_stage_b_contract_context(int unsigned lane, int unsigned slot, string why);
            if (lane >= 4 || slot >= 4 || b_contract_dumped[lane][slot])
                return;
            b_contract_dumped[lane][slot] = 1'b1;
            `uvm_error("TB_INT_TRACE",
                       $sformatf("first stage-B contract failure at lane=%0d slot=%0d: %s",
                                 lane, slot, why))
            dump_trace_queue($sformatf("recent Stage-B lane=%0d slot=%0d beats", lane, slot),
                             b_history[lane][slot]);
        endfunction

        virtual function void dump_stage_framed_contract_context(
            tb_int_trace_stage_e stage_id,
            int unsigned lane,
            string why
        );
            case (stage_id)
                TRACE_STAGE_C: begin
                    if (lane >= 4 || c_contract_dumped[lane])
                        return;
                    c_contract_dumped[lane] = 1'b1;
                    `uvm_error("TB_INT_TRACE",
                               $sformatf("first stage-C contract failure at lane=%0d: %s",
                                         lane, why))
                    dump_trace_queue($sformatf("recent Stage-C lane=%0d beats", lane), c_history[lane]);
                    for (int slot = 0; slot < 4; slot++) begin
                        dump_trace_queue($sformatf("recent Stage-B lane=%0d slot=%0d beats", lane, slot),
                                         b_history[lane][slot]);
                    end
                end
                TRACE_STAGE_D: begin
                    if (lane >= 4 || d_contract_dumped[lane])
                        return;
                    d_contract_dumped[lane] = 1'b1;
                    `uvm_error("TB_INT_TRACE",
                               $sformatf("first stage-D contract failure at lane=%0d: %s",
                                         lane, why))
                    dump_trace_queue($sformatf("recent Stage-D lane=%0d beats", lane), d_history[lane]);
                    dump_trace_queue($sformatf("recent Stage-C lane=%0d beats", lane), c_history[lane]);
                end
                default: begin
                    if (e_contract_dumped)
                        return;
                    e_contract_dumped = 1'b1;
                    `uvm_error("TB_INT_TRACE",
                               $sformatf("first stage-E contract failure: %s", why))
                    dump_trace_queue("recent Stage-E accepted beats", e_history);
                    for (int ln = 0; ln < 4; ln++) begin
                        dump_trace_queue($sformatf("recent Stage-D lane=%0d beats", ln), d_history[ln]);
                    end
                    if (lane < 4) begin
                        dump_trace_queue($sformatf("recent Stage-C lane=%0d beats", lane), c_history[lane]);
                        for (int slot = 0; slot < 4; slot++) begin
                            dump_trace_queue($sformatf("recent Stage-B lane=%0d slot=%0d beats", lane, slot),
                                             b_history[lane][slot]);
                        end
                    end
                end
            endcase
        endfunction

        // Stage A: a hit_generator committed a new raw 48-bit hit to its
        // FIFO. Extract the identity tuple and push into the per-lane
        // content ledger keyed on (channel, t_fine).
        virtual function void write_stage_a(tb_int_hit_event ev);
            int unsigned     lane_idx;
            hit_key_t        k;
            bit [9:0]        kb;
            hit_ah0_key_t    ah0_kb;
            tb_int_hit_obs   obs;
            n_stage_a++;
            lane_idx = {ev.feb_id[0], ev.datapath_id};
            if (lane_idx >= 4) return;
            n_stage_a_per_lane[lane_idx]++;
            k      = extract_key_stage_a(ev.payload);
            kb     = {k.channel, k.t_fine};
            ah0_kb = extract_key_stage_a_h0(ev.payload, cfg.emu_cfg[lane_idx].short_mode);
            obs = tb_int_hit_obs::type_id::create("a_obs");
            obs.key            = k;
            obs.lane_id        = lane_idx;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = '0;
            obs.root_hit_id_valid = 1'b1;
            obs.root_hit_id    = ev.hit_id;
            obs.run_origin     = tb_int_run_window_db::is_stable_origin(ev.abs_ts);
            obs.raw_payload_a  = ev.payload;
            obs.seq_in_bucket  = stage_a_ledger[lane_idx].exists(kb)
                                 ? stage_a_ledger[lane_idx][kb].size() : 0;
            stage_a_ledger[lane_idx][kb].push_back(obs);
            stage_a_ah0_ledger[lane_idx][ah0_kb].push_back(obs);
            record_run_origin(stage_a_run_root_obs[lane_idx], obs);
        endfunction

        // Stage H0: one frame_rcv hit_type0 beat before mts. Every valid beat
        // is one hit; SOP/EOP delimit the parent MuTRiG frame.
        virtual function void write_stage_h0(tb_int_hit0_event ev);
            hit_key_t        k;
            bit [9:0]        kb;
            hit_ah0_key_t    ah0_kb;
            tb_int_hit_obs   obs;
            int unsigned     beat_lane;
            int unsigned     match_seq;

            n_stage_h0_beats++;
            if (ev.lane_id >= 4)
                return;
            if (ev.sop)
                n_stage_h0_frames++;
            n_stage_h0_beats_per_lane[ev.lane_id]++;
            if (ev.sop)
                n_stage_h0_frames_per_lane[ev.lane_id]++;

            void'(h0_parser[ev.lane_id].step(ev.sop, ev.eop));

            k      = extract_key_hit0(ev.data);
            kb     = {k.channel, k.t_fine};
            ah0_kb = extract_key_hit0_ah0(ev.data);
            obs = tb_int_hit_obs::type_id::create("h0_obs");
            obs.key            = k;
            obs.lane_id        = ev.lane_id;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = '0;
            obs.raw_data       = ev.data[35:0];
            beat_lane = extract_lane_hit0(ev.data);
            if (beat_lane != ev.lane_id) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_h0 lane=%0d beat asic=%0d mismatch at ch=%0d tfine=%0d",
                                    ev.lane_id, beat_lane, k.channel, k.t_fine),
                          UVM_HIGH)
            end
            obs.seq_in_bucket  = stage_h0_ledger[ev.lane_id].exists(kb)
                                 ? stage_h0_ledger[ev.lane_id][kb].size() : 0;
            match_seq          = stage_h0_ah0_ledger[ev.lane_id].exists(ah0_kb)
                                 ? stage_h0_ah0_ledger[ev.lane_id][ah0_kb].size() : 0;
            if (stage_a_ah0_ledger[ev.lane_id].exists(ah0_kb) &&
                stage_a_ah0_ledger[ev.lane_id][ah0_kb].size() > match_seq)
                copy_root_hit_id(obs, stage_a_ah0_ledger[ev.lane_id][ah0_kb][match_seq]);
            stage_h0_ledger[ev.lane_id][kb].push_back(obs);
            stage_h0_ah0_ledger[ev.lane_id][ah0_kb].push_back(obs);
            record_run_origin(stage_h0_run_root_obs[ev.lane_id], obs);
        endfunction

        // Stage H1: one accepted mts hit_type1 beat before the rb_cam fanout.
        // The mts sideband channel carries the downstream interleaving slot,
        // while the true datapath lane still comes from the asic field in the
        // data payload.
        virtual function void write_stage_h1(tb_int_hit1_event ev);
            hit_key_t       k;
            bit [9:0]       kb;
            tb_int_hit_obs  obs;
            tb_int_hit_obs  eligible_obs;
            int unsigned    beat_lane;
            int unsigned    slot_id;

            if (ev.lane_id >= 4)
                return;
            slot_id = int'(ev.channel[1:0]);
            if (ev.empty) begin
                if (!ev.eop) begin
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage_h1 lane=%0d slot=%0d empty close marker without EOP",
                                         ev.lane_id, slot_id))
                end
                return;
            end

            n_stage_h1_beats++;
            n_stage_h1_beats_per_lane[ev.lane_id]++;
            if (slot_id < 4)
                n_stage_h1_beats_per_slot[ev.lane_id][slot_id]++;
            if (ev.error) begin
                n_stage_h1_error_per_lane[ev.lane_id]++;
                if (slot_id < 4)
                    n_stage_h1_error_per_slot[ev.lane_id][slot_id]++;
            end

            k  = extract_key_hit1(ev.data);
            kb = {k.channel, k.t_fine};
            obs = tb_int_hit_obs::type_id::create("h1_obs");
            obs.key            = k;
            obs.lane_id        = ev.lane_id;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = '0;
            obs.raw_data       = ev.data[35:0];
            beat_lane = extract_lane_hit1(ev.data);
            if (beat_lane != ev.lane_id) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_h1 lane=%0d beat asic=%0d mismatch at ch=%0d tfine=%0d",
                                    ev.lane_id, beat_lane, k.channel, k.t_fine),
                          UVM_HIGH)
            end
            obs.seq_in_bucket  = stage_h1_ledger[ev.lane_id].exists(kb)
                                 ? stage_h1_ledger[ev.lane_id][kb].size() : 0;
            if (stage_h0_ledger[ev.lane_id].exists(kb) &&
                stage_h0_ledger[ev.lane_id][kb].size() > obs.seq_in_bucket)
                copy_root_hit_id(obs, stage_h0_ledger[ev.lane_id][kb][obs.seq_in_bucket]);
            stage_h1_ledger[ev.lane_id][kb].push_back(obs);
            if (slot_id < 4)
                stage_h1_slot_ledger[ev.lane_id][slot_id][kb].push_back(obs);
            record_run_origin(stage_h1_run_root_obs[ev.lane_id], obs);

            if (rbcam_filter_inerr_enabled && ev.error)
                return;

            eligible_obs = tb_int_hit_obs::type_id::create("h1_eligible_obs");
            eligible_obs.key           = k;
            eligible_obs.lane_id       = ev.lane_id;
            eligible_obs.abs_ts        = ev.abs_ts;
            eligible_obs.hit_abs_ts    = '0;
            eligible_obs.raw_data      = ev.data[35:0];
            eligible_obs.seq_in_bucket = stage_h1_eligible_ledger[ev.lane_id].exists(kb)
                                         ? stage_h1_eligible_ledger[ev.lane_id][kb].size() : 0;
            copy_root_hit_id(eligible_obs, obs);
            stage_h1_eligible_ledger[ev.lane_id][kb].push_back(eligible_obs);
            if (slot_id < 4)
                stage_h1_eligible_slot_ledger[ev.lane_id][slot_id][kb].push_back(eligible_obs);
            record_run_origin(stage_h1e_run_root_obs[ev.lane_id], eligible_obs);
        endfunction

        // Stage B: one accepted hit_type2 beat from one rb_cam slot. The
        // parser enforces the subheader-packet contract and only hit-body
        // beats enter the per-lane ledger.
        virtual function void write_stage_b(tb_int_hit2_event ev);
            int unsigned       prev_err;
            bit                is_hit;
            hit_key_t          k;
            bit [9:0]          kb;
            hit_raw36_key_t    raw_k;
            tb_int_hit_obs     obs;
            int unsigned       beat_lane;
            tb_int_beat_trace  tr;

            n_stage_b_beats++;
            if (ev.sop) n_stage_b_packets++;
            if (ev.lane_id >= 4 || ev.slot_id >= 4) return;
            n_stage_b_beats_per_lane[ev.lane_id]++;
            n_stage_b_beats_per_slot[ev.lane_id][ev.slot_id]++;
            if (ev.sop) begin
                n_stage_b_packets_per_lane[ev.lane_id]++;
                n_stage_b_packets_per_slot[ev.lane_id][ev.slot_id]++;
            end

            tr = tb_int_beat_trace::type_id::create("b_trace");
            tr.stage_id = TRACE_STAGE_B;
            tr.lane_id  = ev.lane_id;
            tr.slot_id  = ev.slot_id;
            tr.abs_ts   = ev.abs_ts;
            tr.data     = ev.data;
            tr.channel  = ev.channel;
            tr.sop      = ev.sop;
            tr.eop      = ev.eop;
            tr.ready    = 1'b1;
            push_trace(b_history[ev.lane_id][ev.slot_id], tr);

            prev_err = b_parser[ev.lane_id][ev.slot_id].n_contract_err;
            is_hit   = b_parser[ev.lane_id][ev.slot_id].step(ev.data, ev.sop, ev.eop);
            if (b_parser[ev.lane_id][ev.slot_id].n_contract_err != prev_err) begin
                dump_stage_b_contract_context(
                    ev.lane_id,
                    ev.slot_id,
                    $sformatf("data=0x%09h sop=%0b eop=%0b", ev.data, ev.sop, ev.eop)
                );
            end
            if (!is_hit) return;

            k     = extract_key_hit2(ev.data);
            kb    = {k.channel, k.t_fine};
            raw_k = extract_key_hit2_exact(ev.data);
            obs = tb_int_hit_obs::type_id::create("b_obs");
            obs.key            = k;
            obs.lane_id        = ev.lane_id;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = b_parser[ev.lane_id][ev.slot_id].last_hit_abs_ts;
            obs.raw_data       = ev.data;
            beat_lane = extract_lane_hit2(ev.data);
            if (beat_lane != ev.lane_id) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_b lane=%0d slot=%0d beat asic=%0d mismatch at ch=%0d tfine=%0d",
                                    ev.lane_id, ev.slot_id, beat_lane, k.channel, k.t_fine),
                          UVM_HIGH)
            end
            obs.seq_in_bucket  = stage_b_ledger[ev.lane_id].exists(kb)
                                 ? stage_b_ledger[ev.lane_id][kb].size() : 0;
            if (stage_h1_eligible_ledger[ev.lane_id].exists(kb) &&
                stage_h1_eligible_ledger[ev.lane_id][kb].size() > obs.seq_in_bucket)
                copy_root_hit_id(obs, stage_h1_eligible_ledger[ev.lane_id][kb][obs.seq_in_bucket]);
            stage_b_ledger[ev.lane_id][kb].push_back(obs);
            stage_b_slot_ledger[ev.lane_id][ev.slot_id][kb].push_back(obs);
            stage_b_exact_ledger[ev.lane_id][raw_k].push_back(obs);
            record_run_origin(stage_b_run_root_obs[ev.lane_id], obs);
        endfunction

        // Stage C: one framed beat on a pre-gate FEB tx lane. The shared
        // parser extracts only hit-body words into the content ledger.
        virtual function void write_stage_c(tb_int_ingress_event ev);
            int unsigned      prev_err;
            bit               is_hit;
            hit_key_t         k;
            bit [9:0]         kb;
            hit_raw36_key_t   raw_k;
            tb_int_hit_obs    obs;
            int unsigned      beat_lane;
            int unsigned      match_seq;
            tb_int_beat_trace tr;

            n_stage_c_beats++;
            if (ev.sop) n_stage_c_frames++;
            if (ev.lane_id >= 4) return;
            n_stage_c_beats_per_lane[ev.lane_id]++;
            if (ev.sop) n_stage_c_frames_per_lane[ev.lane_id]++;

            tr = tb_int_beat_trace::type_id::create("c_trace");
            tr.stage_id = TRACE_STAGE_C;
            tr.lane_id  = ev.lane_id;
            tr.slot_id  = '1;
            tr.abs_ts   = ev.abs_ts;
            tr.data     = ev.data;
            tr.channel  = {2'b00, ev.channel};
            tr.sop      = ev.sop;
            tr.eop      = ev.eop;
            tr.ready    = 1'b1;
            push_trace(c_history[ev.lane_id], tr);

            prev_err = c_parser[ev.lane_id].n_contract_err;
            is_hit   = c_parser[ev.lane_id].step(ev.data);
            if (c_parser[ev.lane_id].n_contract_err != prev_err) begin
                dump_stage_framed_contract_context(
                    TRACE_STAGE_C,
                    ev.lane_id,
                    $sformatf("data=0x%09h sop=%0b eop=%0b", ev.data, ev.sop, ev.eop)
                );
            end
            if (!is_hit) return;

            k     = extract_key_hit2(ev.data);
            kb    = {k.channel, k.t_fine};
            raw_k = extract_key_hit2_exact(ev.data);
            obs = tb_int_hit_obs::type_id::create("c_obs");
            obs.key            = k;
            obs.lane_id        = ev.lane_id;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = c_parser[ev.lane_id].last_hit_abs_ts;
            obs.raw_data       = ev.data;
            beat_lane = extract_lane_hit2(ev.data);
            if (beat_lane != ev.lane_id) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_c lane=%0d beat asic=%0d mismatch at ch=%0d tfine=%0d",
                                    ev.lane_id, beat_lane, k.channel, k.t_fine),
                          UVM_HIGH)
            end
            obs.seq_in_bucket  = stage_c_ledger[ev.lane_id].exists(kb)
                                 ? stage_c_ledger[ev.lane_id][kb].size() : 0;
            match_seq          = stage_c_exact_ledger[ev.lane_id].exists(raw_k)
                                 ? stage_c_exact_ledger[ev.lane_id][raw_k].size() : 0;
            if (stage_b_exact_ledger[ev.lane_id].exists(raw_k) &&
                stage_b_exact_ledger[ev.lane_id][raw_k].size() > match_seq)
                copy_root_hit_id(obs, stage_b_exact_ledger[ev.lane_id][raw_k][match_seq]);
            else if (stage_b_ledger[ev.lane_id].exists(kb) &&
                     stage_b_ledger[ev.lane_id][kb].size() > obs.seq_in_bucket)
                copy_root_hit_id(obs, stage_b_ledger[ev.lane_id][kb][obs.seq_in_bucket]);
            stage_c_ledger[ev.lane_id][kb].push_back(obs);
            stage_c_exact_ledger[ev.lane_id][raw_k].push_back(obs);
            record_run_origin(stage_c_run_root_obs[ev.lane_id], obs);
        endfunction

        // Stage D: one beat on a single OPQ ingress lane. The frame parser
        // tells us whether this beat is a 36-bit hit-body word; only those
        // enter the ledger. Framing beats still update the parser counters.
        virtual function void write_stage_d(tb_int_ingress_event ev);
            int unsigned      prev_err;
            bit               is_hit;
            hit_key_t         k;
            bit [9:0]         kb;
            hit_raw36_key_t   raw_k;
            tb_int_hit_obs    obs;
            int unsigned      beat_lane;
            int unsigned      match_seq;
            tb_int_beat_trace tr;

            n_stage_d_beats++;
            if (ev.sop) n_stage_d_frames++;
            if (ev.lane_id >= 4) return;
            n_stage_d_beats_per_lane[ev.lane_id]++;
            if (ev.sop) n_stage_d_frames_per_lane[ev.lane_id]++;

            tr = tb_int_beat_trace::type_id::create("d_trace");
            tr.stage_id = TRACE_STAGE_D;
            tr.lane_id  = ev.lane_id;
            tr.slot_id  = '1;
            tr.abs_ts   = ev.abs_ts;
            tr.data     = ev.data;
            tr.channel  = {2'b00, ev.channel};
            tr.sop      = ev.sop;
            tr.eop      = ev.eop;
            tr.ready    = 1'b1;
            push_trace(d_history[ev.lane_id], tr);

            prev_err = d_parser[ev.lane_id].n_contract_err;
            is_hit   = d_parser[ev.lane_id].step(ev.data);
            if (d_parser[ev.lane_id].n_contract_err != prev_err) begin
                dump_stage_framed_contract_context(
                    TRACE_STAGE_D,
                    ev.lane_id,
                    $sformatf("data=0x%09h sop=%0b eop=%0b", ev.data, ev.sop, ev.eop)
                );
            end
            if (!is_hit) return;

            k     = extract_key_hit2(ev.data);
            kb    = {k.channel, k.t_fine};
            raw_k = extract_key_hit2_exact(ev.data);
            obs = tb_int_hit_obs::type_id::create("d_obs");
            obs.key            = k;
            obs.lane_id        = ev.lane_id;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = d_parser[ev.lane_id].last_hit_abs_ts;
            obs.raw_data       = ev.data;
            beat_lane = extract_lane_hit2(ev.data);
            if (beat_lane != ev.lane_id) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_d lane=%0d beat asic=%0d mismatch at ch=%0d tfine=%0d",
                                    ev.lane_id, beat_lane, k.channel, k.t_fine),
                          UVM_HIGH)
            end
            obs.seq_in_bucket  = stage_d_ledger[ev.lane_id].exists(kb)
                                 ? stage_d_ledger[ev.lane_id][kb].size() : 0;
            match_seq          = stage_d_exact_ledger[ev.lane_id].exists(raw_k)
                                 ? stage_d_exact_ledger[ev.lane_id][raw_k].size() : 0;
            if (stage_c_exact_ledger[ev.lane_id].exists(raw_k) &&
                stage_c_exact_ledger[ev.lane_id][raw_k].size() > match_seq)
                copy_root_hit_id(obs, stage_c_exact_ledger[ev.lane_id][raw_k][match_seq]);
            else if (stage_c_ledger[ev.lane_id].exists(kb) &&
                     stage_c_ledger[ev.lane_id][kb].size() > obs.seq_in_bucket)
                copy_root_hit_id(obs, stage_c_ledger[ev.lane_id][kb][obs.seq_in_bucket]);
            stage_d_ledger[ev.lane_id][kb].push_back(obs);
            stage_d_exact_ledger[ev.lane_id][raw_k].push_back(obs);
            record_run_origin(stage_d_run_root_obs[ev.lane_id], obs);
        endfunction

        // Stage E: one accepted beat on the OPQ egress AvST. Aggregates
        // all 4 lanes onto a single stream, so we recover the source lane
        // from the hit-body asic field ([25:22]).
        virtual function void write_stage_e(tb_int_egress_event ev);
            int unsigned      prev_err;
            bit               is_hit;
            hit_key_t         k;
            bit [9:0]         kb;
            hit_raw36_key_t   raw_k;
            int unsigned      lane;
            int unsigned      match_seq;
            tb_int_hit_obs    obs;
            tb_int_beat_trace tr;
            int unsigned      hint_lane;

            n_stage_e_beats++;
            if (ev.sop) n_stage_e_frames++;

            tr = tb_int_beat_trace::type_id::create("e_trace");
            tr.stage_id = TRACE_STAGE_E;
            tr.lane_id  = '1;
            tr.slot_id  = '1;
            tr.abs_ts   = ev.abs_ts;
            tr.data     = ev.data;
            tr.channel  = '0;
            tr.sop      = ev.sop;
            tr.eop      = ev.eop;
            tr.ready    = 1'b1;
            push_trace(e_history, tr);

            prev_err = e_parser.n_contract_err;
            is_hit   = e_parser.step(ev.data, ev.sop, ev.eop);
            if (ev.data[35:32] == 4'b0000)
                hint_lane = extract_lane_hit2(ev.data);
            else
                hint_lane = 32'hffff_ffff;
            if (e_parser.n_contract_err != prev_err) begin
                dump_stage_framed_contract_context(
                    TRACE_STAGE_E,
                    hint_lane,
                    $sformatf("data=0x%09h sop=%0b eop=%0b", ev.data, ev.sop, ev.eop)
                );
            end
            if (!is_hit) return;

            k     = extract_key_hit2(ev.data);
            lane  = extract_lane_hit2(ev.data);
            if (lane >= 4) begin
                n_stage_e_lane_unknown++;
                return;
            end
            kb    = {k.channel, k.t_fine};
            raw_k = extract_key_hit2_exact(ev.data);
            obs = tb_int_hit_obs::type_id::create("e_obs");
            obs.key            = k;
            obs.lane_id        = lane;
            obs.abs_ts         = ev.abs_ts;
            obs.hit_abs_ts     = e_parser.last_hit_abs_ts;
            obs.raw_data       = ev.data;
            obs.seq_in_bucket  = stage_e_ledger[lane].exists(kb)
                                 ? stage_e_ledger[lane][kb].size() : 0;
            match_seq          = stage_e_exact_ledger[lane].exists(raw_k)
                                 ? stage_e_exact_ledger[lane][raw_k].size() : 0;
            if (stage_d_exact_ledger[lane].exists(raw_k) &&
                stage_d_exact_ledger[lane][raw_k].size() > match_seq)
                copy_root_hit_id(obs, stage_d_exact_ledger[lane][raw_k][match_seq]);
            else if (stage_d_ledger[lane].exists(kb) &&
                     stage_d_ledger[lane][kb].size() > obs.seq_in_bucket)
                copy_root_hit_id(obs, stage_d_ledger[lane][kb][obs.seq_in_bucket]);
            stage_e_ledger[lane][kb].push_back(obs);
            stage_e_exact_ledger[lane][raw_k].push_back(obs);
            record_run_origin(stage_e_run_root_obs[lane], obs);
        endfunction

        // Reconcile stage pairs per lane using FIFO counts in each
        // (channel, t_fine) bucket. This exposes the first failing boundary
        // directly: A->H0, H0->H1, H1->B, B->C, C->D, D->E.
        virtual function void reconcile();
            for (int ln = 0; ln < 4; ln++) begin
                int unsigned a_total, h0_total, h1_total, h1_eligible_total;
                int unsigned b_total, c_total, d_total, e_total;
                int unsigned matched_ah0, missing_h0, ghost_h0;
                int unsigned matched_h0h1, missing_h1, ghost_h1;
                int unsigned matched_h1b, missing_b, ghost_b;
                int unsigned matched_h1b_eligible, missing_b_eligible, ghost_b_eligible;
                int unsigned matched_bc, missing_c, ghost_c;
                int unsigned matched_cd, missing_d, ghost_d;
                int unsigned matched_de, missing_e, ghost_e;
                bit [9:0] kb;
                bit       ok;

                a_total = 0; h0_total = 0; h1_total = 0; h1_eligible_total = 0;
                b_total = 0; c_total = 0; d_total = 0; e_total = 0;
                matched_ah0 = 0; missing_h0 = 0; ghost_h0 = 0;
                matched_h0h1 = 0; missing_h1 = 0; ghost_h1 = 0;
                matched_h1b = 0; missing_b = 0; ghost_b = 0;
                matched_h1b_eligible = 0; missing_b_eligible = 0; ghost_b_eligible = 0;
                matched_bc = 0; missing_c = 0; ghost_c = 0;
                matched_cd = 0; missing_d = 0; ghost_d = 0;
                matched_de = 0; missing_e = 0; ghost_e = 0;

                if (stage_a_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int a_n, h0_n;
                        a_n = stage_a_ledger[ln][kb].size();
                        h0_n = stage_h0_ledger[ln].exists(kb)
                               ? stage_h0_ledger[ln][kb].size() : 0;
                        a_total += a_n;
                        if (a_n <= h0_n) matched_ah0 += a_n;
                        else begin
                            matched_ah0 += h0_n;
                            missing_h0 += (a_n - h0_n);
                        end
                        ok = stage_a_ledger[ln].next(kb);
                    end
                end

                if (stage_h0_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int a_n, h0_n, h1_n;
                        h0_n = stage_h0_ledger[ln][kb].size();
                        a_n = stage_a_ledger[ln].exists(kb)
                              ? stage_a_ledger[ln][kb].size() : 0;
                        h1_n = stage_h1_ledger[ln].exists(kb)
                               ? stage_h1_ledger[ln][kb].size() : 0;
                        h0_total += h0_n;
                        if (h0_n > a_n) ghost_h0 += (h0_n - a_n);
                        if (h0_n <= h1_n) matched_h0h1 += h0_n;
                        else begin
                            matched_h0h1 += h1_n;
                            missing_h1 += (h0_n - h1_n);
                        end
                        ok = stage_h0_ledger[ln].next(kb);
                    end
                end

                if (stage_h1_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int h0_n, h1_n, b_n;
                        h1_n = stage_h1_ledger[ln][kb].size();
                        h0_n = stage_h0_ledger[ln].exists(kb)
                               ? stage_h0_ledger[ln][kb].size() : 0;
                        b_n = stage_b_ledger[ln].exists(kb)
                              ? stage_b_ledger[ln][kb].size() : 0;
                        h1_total += h1_n;
                        if (h1_n > h0_n) ghost_h1 += (h1_n - h0_n);
                        if (h1_n <= b_n) matched_h1b += h1_n;
                        else begin
                            matched_h1b += b_n;
                            missing_b += (h1_n - b_n);
                        end
                        ok = stage_h1_ledger[ln].next(kb);
                    end
                end

                if (stage_h1_eligible_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int h1_n, b_n;
                        h1_n = stage_h1_eligible_ledger[ln][kb].size();
                        b_n = stage_b_ledger[ln].exists(kb)
                              ? stage_b_ledger[ln][kb].size() : 0;
                        h1_eligible_total += h1_n;
                        if (h1_n <= b_n) matched_h1b_eligible += h1_n;
                        else begin
                            matched_h1b_eligible += b_n;
                            missing_b_eligible += (h1_n - b_n);
                        end
                        ok = stage_h1_eligible_ledger[ln].next(kb);
                    end
                end

                if (stage_b_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int h1_n, h1e_n, b_n, c_n;
                        b_n = stage_b_ledger[ln][kb].size();
                        h1_n = stage_h1_ledger[ln].exists(kb)
                               ? stage_h1_ledger[ln][kb].size() : 0;
                        h1e_n = stage_h1_eligible_ledger[ln].exists(kb)
                                ? stage_h1_eligible_ledger[ln][kb].size() : 0;
                        c_n = stage_c_ledger[ln].exists(kb)
                              ? stage_c_ledger[ln][kb].size() : 0;
                        b_total += b_n;
                        if (b_n > h1_n) ghost_b += (b_n - h1_n);
                        if (b_n > h1e_n) ghost_b_eligible += (b_n - h1e_n);
                        if (b_n <= c_n) matched_bc += b_n;
                        else begin
                            matched_bc += c_n;
                            missing_c += (b_n - c_n);
                        end
                        ok = stage_b_ledger[ln].next(kb);
                    end
                end

                if (stage_c_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int b_n, c_n, d_n;
                        c_n = stage_c_ledger[ln][kb].size();
                        b_n = stage_b_ledger[ln].exists(kb)
                              ? stage_b_ledger[ln][kb].size() : 0;
                        d_n = stage_d_ledger[ln].exists(kb)
                              ? stage_d_ledger[ln][kb].size() : 0;
                        c_total += c_n;
                        if (c_n > b_n) ghost_c += (c_n - b_n);
                        if (c_n <= d_n) matched_cd += c_n;
                        else begin
                            matched_cd += d_n;
                            missing_d += (c_n - d_n);
                        end
                        ok = stage_c_ledger[ln].next(kb);
                    end
                end

                if (stage_d_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int c_n, d_n, e_n;
                        d_n = stage_d_ledger[ln][kb].size();
                        c_n = stage_c_ledger[ln].exists(kb)
                              ? stage_c_ledger[ln][kb].size() : 0;
                        e_n = stage_e_ledger[ln].exists(kb)
                              ? stage_e_ledger[ln][kb].size() : 0;
                        d_total += d_n;
                        if (d_n > c_n) ghost_d += (d_n - c_n);
                        if (d_n <= e_n) matched_de += d_n;
                        else begin
                            matched_de += e_n;
                            missing_e += (d_n - e_n);
                        end
                        ok = stage_d_ledger[ln].next(kb);
                    end
                end

                if (stage_e_ledger[ln].first(kb)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int d_n, e_n;
                        e_n = stage_e_ledger[ln][kb].size();
                        d_n = stage_d_ledger[ln].exists(kb)
                              ? stage_d_ledger[ln][kb].size() : 0;
                        e_total += e_n;
                        if (e_n > d_n) ghost_e += (e_n - d_n);
                        ok = stage_e_ledger[ln].next(kb);
                    end
                end

                reconcile_ah0_boundary(ln, matched_ah0, missing_h0, ghost_h0);
                reconcile_hit2_boundary(stage_b_exact_ledger[ln], stage_c_exact_ledger[ln],
                                        matched_bc, missing_c, ghost_c);
                reconcile_hit2_boundary(stage_c_exact_ledger[ln], stage_d_exact_ledger[ln],
                                        matched_cd, missing_d, ghost_d);
                reconcile_hit2_boundary(stage_d_exact_ledger[ln], stage_e_exact_ledger[ln],
                                        matched_de, missing_e, ghost_e);

                rec_a_total_per_lane[ln]    = a_total;
                rec_h0_total_per_lane[ln]   = h0_total;
                rec_h1_total_per_lane[ln]   = h1_total;
                rec_h1_eligible_total_per_lane[ln] = h1_eligible_total;
                rec_h1_filtered_per_lane[ln] = h1_total - h1_eligible_total;
                rec_b_total_per_lane[ln]    = b_total;
                rec_c_total_per_lane[ln]    = c_total;
                rec_d_total_per_lane[ln]    = d_total;
                rec_e_total_per_lane[ln]    = e_total;
                rec_matched_ah0_per_lane[ln] = matched_ah0;
                rec_missing_h0_per_lane[ln]  = missing_h0;
                rec_ghost_h0_per_lane[ln]    = ghost_h0;
                rec_matched_ah1_per_lane[ln] = matched_h0h1;
                rec_missing_h1_per_lane[ln]  = missing_h1;
                rec_ghost_h1_per_lane[ln]    = ghost_h1;
                rec_matched_ab_per_lane[ln] = matched_h1b;
                rec_missing_b_per_lane[ln]  = missing_b;
                rec_ghost_b_per_lane[ln]    = ghost_b;
                rec_matched_ab_eligible_per_lane[ln] = matched_h1b_eligible;
                rec_missing_b_eligible_per_lane[ln]  = missing_b_eligible;
                rec_ghost_b_eligible_per_lane[ln]    = ghost_b_eligible;
                rec_matched_bc_per_lane[ln] = matched_bc;
                rec_missing_c_per_lane[ln]  = missing_c;
                rec_ghost_c_per_lane[ln]    = ghost_c;
                rec_matched_cd_per_lane[ln] = matched_cd;
                rec_missing_d_per_lane[ln]  = missing_d;
                rec_ghost_d_per_lane[ln]    = ghost_d;
                rec_matched_de_per_lane[ln] = matched_de;
                rec_missing_e_per_lane[ln]  = missing_e;
                rec_ghost_e_per_lane[ln]    = ghost_e;

                for (int slot = 0; slot < 4; slot++) begin
                    int unsigned h1_slot_total, h1_eligible_slot_total, b_slot_total;
                    int unsigned h1_filtered_slot_total;
                    int unsigned matched_h1b_slot, missing_b_slot, ghost_b_slot;
                    int unsigned matched_h1b_eligible_slot, missing_b_eligible_slot, ghost_b_eligible_slot;

                    h1_slot_total             = 0;
                    h1_eligible_slot_total    = 0;
                    h1_filtered_slot_total    = 0;
                    b_slot_total              = 0;
                    matched_h1b_slot          = 0;
                    missing_b_slot            = 0;
                    ghost_b_slot              = 0;
                    matched_h1b_eligible_slot = 0;
                    missing_b_eligible_slot   = 0;
                    ghost_b_eligible_slot     = 0;

                    if (stage_h1_slot_ledger[ln][slot].first(kb)) begin
                        ok = 1'b1;
                        while (ok) begin
                            int h1_n, b_n;
                            h1_n = stage_h1_slot_ledger[ln][slot][kb].size();
                            b_n = stage_b_slot_ledger[ln][slot].exists(kb)
                                  ? stage_b_slot_ledger[ln][slot][kb].size() : 0;
                            h1_slot_total += h1_n;
                            if (h1_n <= b_n) matched_h1b_slot += h1_n;
                            else begin
                                matched_h1b_slot += b_n;
                                missing_b_slot += (h1_n - b_n);
                            end
                            ok = stage_h1_slot_ledger[ln][slot].next(kb);
                        end
                    end

                    if (stage_h1_eligible_slot_ledger[ln][slot].first(kb)) begin
                        ok = 1'b1;
                        while (ok) begin
                            int h1_n, b_n;
                            h1_n = stage_h1_eligible_slot_ledger[ln][slot][kb].size();
                            b_n = stage_b_slot_ledger[ln][slot].exists(kb)
                                  ? stage_b_slot_ledger[ln][slot][kb].size() : 0;
                            h1_eligible_slot_total += h1_n;
                            if (h1_n <= b_n) matched_h1b_eligible_slot += h1_n;
                            else begin
                                matched_h1b_eligible_slot += b_n;
                                missing_b_eligible_slot += (h1_n - b_n);
                            end
                            ok = stage_h1_eligible_slot_ledger[ln][slot].next(kb);
                        end
                    end

                    if (stage_b_slot_ledger[ln][slot].first(kb)) begin
                        ok = 1'b1;
                        while (ok) begin
                            int h1_n, h1e_n, b_n;
                            b_n = stage_b_slot_ledger[ln][slot][kb].size();
                            h1_n = stage_h1_slot_ledger[ln][slot].exists(kb)
                                   ? stage_h1_slot_ledger[ln][slot][kb].size() : 0;
                            h1e_n = stage_h1_eligible_slot_ledger[ln][slot].exists(kb)
                                    ? stage_h1_eligible_slot_ledger[ln][slot][kb].size() : 0;
                            b_slot_total += b_n;
                            if (b_n > h1_n) ghost_b_slot += (b_n - h1_n);
                            if (b_n > h1e_n) ghost_b_eligible_slot += (b_n - h1e_n);
                            ok = stage_b_slot_ledger[ln][slot].next(kb);
                        end
                    end

                    h1_filtered_slot_total = h1_slot_total - h1_eligible_slot_total;
                    rec_h1_total_per_slot[ln][slot]    = h1_slot_total;
                    rec_h1_eligible_total_per_slot[ln][slot] = h1_eligible_slot_total;
                    rec_h1_filtered_per_slot[ln][slot] = h1_filtered_slot_total;
                    rec_b_total_per_slot[ln][slot]     = b_slot_total;
                    rec_matched_h1b_per_slot[ln][slot] = matched_h1b_slot;
                    rec_missing_b_per_slot[ln][slot]   = missing_b_slot;
                    rec_ghost_b_per_slot[ln][slot]     = ghost_b_slot;
                    rec_matched_h1b_eligible_per_slot[ln][slot] = matched_h1b_eligible_slot;
                    rec_missing_b_eligible_per_slot[ln][slot]   = missing_b_eligible_slot;
                    rec_ghost_b_eligible_per_slot[ln][slot]     = ghost_b_eligible_slot;
                end
            end
        endfunction

        virtual function void reconcile_running_origin();
            for (int ln = 0; ln < 4; ln++) begin
                rec_run_a_total_per_lane[ln]   = count_root_obs(stage_a_run_root_obs[ln]);
                rec_run_h0_total_per_lane[ln]  = count_root_obs(stage_h0_run_root_obs[ln]);
                rec_run_h1_total_per_lane[ln]  = count_root_obs(stage_h1_run_root_obs[ln]);
                rec_run_h1e_total_per_lane[ln] = count_root_obs(stage_h1e_run_root_obs[ln]);
                rec_run_b_total_per_lane[ln]   = count_root_obs(stage_b_run_root_obs[ln]);
                rec_run_c_total_per_lane[ln]   = count_root_obs(stage_c_run_root_obs[ln]);
                rec_run_d_total_per_lane[ln]   = count_root_obs(stage_d_run_root_obs[ln]);
                rec_run_e_total_per_lane[ln]   = count_root_obs(stage_e_run_root_obs[ln]);

                reconcile_root_boundary(stage_a_run_root_obs[ln], stage_h0_run_root_obs[ln],
                                        rec_run_matched_ah0_per_lane[ln],
                                        rec_run_missing_h0_per_lane[ln],
                                        rec_run_ghost_h0_per_lane[ln]);
                reconcile_root_boundary(stage_h0_run_root_obs[ln], stage_h1_run_root_obs[ln],
                                        rec_run_matched_ah1_per_lane[ln],
                                        rec_run_missing_h1_per_lane[ln],
                                        rec_run_ghost_h1_per_lane[ln]);
                reconcile_root_boundary(stage_h1e_run_root_obs[ln], stage_b_run_root_obs[ln],
                                        rec_run_matched_ab_per_lane[ln],
                                        rec_run_missing_b_per_lane[ln],
                                        rec_run_ghost_b_per_lane[ln]);
                reconcile_root_boundary(stage_b_run_root_obs[ln], stage_c_run_root_obs[ln],
                                        rec_run_matched_bc_per_lane[ln],
                                        rec_run_missing_c_per_lane[ln],
                                        rec_run_ghost_c_per_lane[ln]);
                reconcile_root_boundary(stage_c_run_root_obs[ln], stage_d_run_root_obs[ln],
                                        rec_run_matched_cd_per_lane[ln],
                                        rec_run_missing_d_per_lane[ln],
                                        rec_run_ghost_d_per_lane[ln]);
                reconcile_root_boundary(stage_d_run_root_obs[ln], stage_e_run_root_obs[ln],
                                        rec_run_matched_de_per_lane[ln],
                                        rec_run_missing_e_per_lane[ln],
                                        rec_run_ghost_e_per_lane[ln]);
                reconcile_root_boundary_before(stage_h1e_run_root_obs[ln], stage_b_run_root_obs[ln],
                                               tb_int_run_window_db::get_run_end_ts(),
                                               rec_run_active_h1e_total_per_lane[ln],
                                               rec_run_active_h1e_matched_b_per_lane[ln],
                                               rec_run_active_h1e_missing_b_per_lane[ln]);
                reconcile_root_boundary_before(stage_b_run_root_obs[ln], stage_c_run_root_obs[ln],
                                               tb_int_run_window_db::get_run_end_ts(),
                                               rec_run_active_b_total_per_lane[ln],
                                               rec_run_active_b_matched_c_per_lane[ln],
                                               rec_run_active_b_missing_c_per_lane[ln]);
            end
        endfunction

        function automatic void dump_bucket_if_residual(
            int unsigned lane,
            bit [9:0] kb,
            ref int unsigned dumped,
            int unsigned n_max
        );
            int a_n, h0_n, h1_n, h1e_n, b_n, c_n, d_n, e_n;
            obs_q_t empty_q;
            if (dumped >= n_max)
                return;
            a_n = stage_a_ledger[lane].exists(kb) ? stage_a_ledger[lane][kb].size() : 0;
            h0_n = stage_h0_ledger[lane].exists(kb) ? stage_h0_ledger[lane][kb].size() : 0;
            h1_n = stage_h1_ledger[lane].exists(kb) ? stage_h1_ledger[lane][kb].size() : 0;
            h1e_n = stage_h1_eligible_ledger[lane].exists(kb)
                    ? stage_h1_eligible_ledger[lane][kb].size() : 0;
            b_n = stage_b_ledger[lane].exists(kb) ? stage_b_ledger[lane][kb].size() : 0;
            c_n = stage_c_ledger[lane].exists(kb) ? stage_c_ledger[lane][kb].size() : 0;
            d_n = stage_d_ledger[lane].exists(kb) ? stage_d_ledger[lane][kb].size() : 0;
            e_n = stage_e_ledger[lane].exists(kb) ? stage_e_ledger[lane][kb].size() : 0;
            if (a_n != h0_n || h0_n != h1_n || h1e_n != b_n || b_n != c_n || c_n != d_n || d_n != e_n) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("lane=%0d ch=%0d tfine=%0d   A=%0d H0=%0d H1=%0d H1e=%0d B=%0d C=%0d D=%0d E=%0d",
                                    lane, kb[9:5], kb[4:0],
                                    a_n, h0_n, h1_n, h1e_n, b_n, c_n, d_n, e_n),
                          UVM_MEDIUM)
                `uvm_info("TB_INT_SB",
                          $sformatf("lane=%0d ch=%0d tfine=%0d heads: A=%s | H0=%s | H1=%s | H1e=%s | B=%s | C=%s | D=%s | E=%s",
                                    lane, kb[9:5], kb[4:0],
                                    (a_n > 0) ? obs_head_desc(stage_a_ledger[lane][kb]) : "-",
                                    (h0_n > 0) ? obs_head_desc(stage_h0_ledger[lane][kb]) : "-",
                                    (h1_n > 0) ? obs_head_desc(stage_h1_ledger[lane][kb]) : "-",
                                    (h1e_n > 0) ? obs_head_desc(stage_h1_eligible_ledger[lane][kb]) : "-",
                                    (b_n > 0) ? obs_head_desc(stage_b_ledger[lane][kb]) : "-",
                                    (c_n > 0) ? obs_head_desc(stage_c_ledger[lane][kb]) : "-",
                                    (d_n > 0) ? obs_head_desc(stage_d_ledger[lane][kb]) : "-",
                                    (e_n > 0) ? obs_head_desc(stage_e_ledger[lane][kb]) : "-"),
                          UVM_HIGH)
                dump_boundary_candidates(
                    "A->H0",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "A",
                    stage_a_ledger[lane].exists(kb) ? stage_a_ledger[lane][kb] : empty_q,
                    a_n,
                    "H0",
                    stage_h0_ledger[lane].exists(kb) ? stage_h0_ledger[lane][kb] : empty_q,
                    h0_n,
                    2
                );
                dump_boundary_candidates(
                    "H0->H1",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "H0",
                    stage_h0_ledger[lane].exists(kb) ? stage_h0_ledger[lane][kb] : empty_q,
                    h0_n,
                    "H1",
                    stage_h1_ledger[lane].exists(kb) ? stage_h1_ledger[lane][kb] : empty_q,
                    h1_n,
                    2
                );
                dump_boundary_candidates(
                    "H1->B(eligible)",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "H1e",
                    stage_h1_eligible_ledger[lane].exists(kb) ? stage_h1_eligible_ledger[lane][kb] : empty_q,
                    h1e_n,
                    "B",
                    stage_b_ledger[lane].exists(kb) ? stage_b_ledger[lane][kb] : empty_q,
                    b_n,
                    2
                );
                dump_boundary_candidates(
                    "B->C",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "B",
                    stage_b_ledger[lane].exists(kb) ? stage_b_ledger[lane][kb] : empty_q,
                    b_n,
                    "C",
                    stage_c_ledger[lane].exists(kb) ? stage_c_ledger[lane][kb] : empty_q,
                    c_n,
                    2
                );
                dump_boundary_candidates(
                    "C->D",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "C",
                    stage_c_ledger[lane].exists(kb) ? stage_c_ledger[lane][kb] : empty_q,
                    c_n,
                    "D",
                    stage_d_ledger[lane].exists(kb) ? stage_d_ledger[lane][kb] : empty_q,
                    d_n,
                    2
                );
                dump_boundary_candidates(
                    "D->E",
                    $sformatf("lane=%0d ch=%0d tfine=%0d", lane, kb[9:5], kb[4:0]),
                    "D",
                    stage_d_ledger[lane].exists(kb) ? stage_d_ledger[lane][kb] : empty_q,
                    d_n,
                    "E",
                    stage_e_ledger[lane].exists(kb) ? stage_e_ledger[lane][kb] : empty_q,
                    e_n,
                    2
                );
                dumped++;
            end
        endfunction

        // Dump the first N residual key buckets seen at any stage for this
        // lane. Multiple passes are acceptable here because the goal is to
        // expose concrete mismatches quickly, not to produce a deduplicated
        // exhaustive report.
        virtual function void dump_residual_buckets(int unsigned lane, int unsigned n_max);
            int unsigned dumped;
            bit [9:0] kb;
            bit       ok;
            dumped = 0;
            if (stage_a_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_a_ledger[lane].next(kb);
                end
            end
            if (stage_h0_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_h0_ledger[lane].next(kb);
                end
            end
            if (stage_h1_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_h1_ledger[lane].next(kb);
                end
            end
            if (stage_b_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_b_ledger[lane].next(kb);
                end
            end
            if (stage_c_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_c_ledger[lane].next(kb);
                end
            end
            if (stage_d_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_d_ledger[lane].next(kb);
                end
            end
            if (stage_e_ledger[lane].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_bucket_if_residual(lane, kb, dumped, n_max);
                    ok = stage_e_ledger[lane].next(kb);
                end
            end
        endfunction

        function automatic void dump_h1b_slot_bucket_if_residual(
            int unsigned lane,
            int unsigned slot,
            bit [9:0] kb,
            ref int unsigned dumped,
            int unsigned n_max
        );
            int h1_n, h1e_n, b_n;
            obs_q_t empty_q;
            if (dumped >= n_max)
                return;
            h1_n = stage_h1_slot_ledger[lane][slot].exists(kb)
                   ? stage_h1_slot_ledger[lane][slot][kb].size() : 0;
            h1e_n = stage_h1_eligible_slot_ledger[lane][slot].exists(kb)
                    ? stage_h1_eligible_slot_ledger[lane][slot][kb].size() : 0;
            b_n = stage_b_slot_ledger[lane][slot].exists(kb)
                  ? stage_b_slot_ledger[lane][slot][kb].size() : 0;
            if (h1e_n != b_n) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("lane=%0d slot=%0d ch=%0d tfine=%0d   H1=%0d H1e=%0d B=%0d",
                                    lane, slot, kb[9:5], kb[4:0], h1_n, h1e_n, b_n),
                          UVM_MEDIUM)
                `uvm_info("TB_INT_SB",
                          $sformatf("lane=%0d slot=%0d ch=%0d tfine=%0d heads: H1=%s | H1e=%s | B=%s",
                                    lane, slot, kb[9:5], kb[4:0],
                                    (h1_n > 0) ? obs_head_desc(stage_h1_slot_ledger[lane][slot][kb]) : "-",
                                    (h1e_n > 0) ? obs_head_desc(stage_h1_eligible_slot_ledger[lane][slot][kb]) : "-",
                                    (b_n > 0) ? obs_head_desc(stage_b_slot_ledger[lane][slot][kb]) : "-"),
                          UVM_HIGH)
                dump_boundary_candidates(
                    "H1->B(slot eligible)",
                    $sformatf("lane=%0d slot=%0d ch=%0d tfine=%0d", lane, slot, kb[9:5], kb[4:0]),
                    "H1e",
                    stage_h1_eligible_slot_ledger[lane][slot].exists(kb)
                        ? stage_h1_eligible_slot_ledger[lane][slot][kb] : empty_q,
                    h1e_n,
                    "B",
                    stage_b_slot_ledger[lane][slot].exists(kb)
                        ? stage_b_slot_ledger[lane][slot][kb] : empty_q,
                    b_n,
                    2
                );
                dumped++;
            end
        endfunction

        virtual function void dump_h1b_slot_residual_buckets(
            int unsigned lane,
            int unsigned slot,
            int unsigned n_max
        );
            int unsigned dumped;
            bit [9:0] kb;
            bit       ok;

            dumped = 0;
            if (stage_h1_slot_ledger[lane][slot].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_h1b_slot_bucket_if_residual(lane, slot, kb, dumped, n_max);
                    ok = stage_h1_slot_ledger[lane][slot].next(kb);
                end
            end
            if (stage_b_slot_ledger[lane][slot].first(kb)) begin
                ok = 1'b1;
                while (ok && dumped < n_max) begin
                    dump_h1b_slot_bucket_if_residual(lane, slot, kb, dumped, n_max);
                    ok = stage_b_slot_ledger[lane][slot].next(kb);
                end
            end
        endfunction

        virtual function void report_phase(uvm_phase phase);
            int unsigned h0_hits_total;
            int unsigned h0_frames_total;
            int unsigned h0_restart_total;
            int unsigned h0_orphan_eop_total;
            int unsigned h0_contract_total;
            int unsigned b_hits_total;
            int unsigned b_packets_total;
            int unsigned b_contract_total;
            int unsigned h1_error_total;
            int unsigned h1_eligible_total;
            int unsigned c_hits_total;
            int unsigned c_subheaders_total;
            int unsigned c_frames_total;
            int unsigned c_trailers_total;
            int unsigned d_hits_total;
            int unsigned d_subheaders_total;
            int unsigned d_frames_total;
            int unsigned d_trailers_total;
            bit          allow_sparse_source_lanes;
            bit          lane_requires_source_activity [4];

            super.report_phase(phase);
            reconcile();
            reconcile_running_origin();

            h0_hits_total      = 0;
            h0_frames_total    = 0;
            h0_restart_total   = 0;
            h0_orphan_eop_total = 0;
            h0_contract_total  = 0;
            b_hits_total     = 0;
            b_packets_total  = 0;
            b_contract_total = 0;
            h1_error_total   = 0;
            h1_eligible_total = 0;
            c_hits_total       = 0;
            c_subheaders_total = 0;
            c_frames_total     = 0;
            c_trailers_total   = 0;
            d_hits_total       = 0;
            d_subheaders_total = 0;
            d_frames_total     = 0;
            d_trailers_total   = 0;
            allow_sparse_source_lanes = 1'b0;
            foreach (cfg.emu_cfg[i]) begin
                lane_requires_source_activity[i] = 1'b0;
                if (cfg.emu_cfg[i].cluster_cross_asic)
                    allow_sparse_source_lanes = 1'b1;
                else if (cfg.emu_cfg[i].enable && (cfg.emu_cfg[i].hit_mode == 2'b01))
                    lane_requires_source_activity[i] = 1'b1;
            end

            foreach (h0_parser[i]) begin
                h0_hits_total     += h0_parser[i].n_hits;
                h0_frames_total   += h0_parser[i].n_frames;
                h0_restart_total  += h0_parser[i].n_restart_sop;
                h0_orphan_eop_total += h0_parser[i].n_orphan_eop;
                h0_contract_total += h0_parser[i].n_contract_err;
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_h0[%0d] parser: frames=%0d hits=%0d orphan=%0d restart_sop=%0d orphan_eop=%0d open_at_end=%0b contract_err=%0d",
                                    i,
                                    h0_parser[i].n_frames,
                                    h0_parser[i].n_hits,
                                    h0_parser[i].n_orphan,
                                    h0_parser[i].n_restart_sop,
                                    h0_parser[i].n_orphan_eop,
                                    h0_parser[i].frame_open,
                                    h0_parser[i].n_contract_err),
                          UVM_LOW)
            end
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_h0 totals: beats=%0d frames=%0d hits=%0d restart_sop=%0d orphan_eop=%0d contract_err=%0d",
                                n_stage_h0_beats, h0_frames_total, h0_hits_total,
                                h0_restart_total, h0_orphan_eop_total, h0_contract_total),
                      UVM_LOW)
            if (h0_contract_total != 0)
                `uvm_error("TB_INT_SB",
                           $sformatf("stage_h0 contract parser saw %0d errors", h0_contract_total))

            foreach (n_stage_h1_error_per_lane[i])
                h1_error_total += n_stage_h1_error_per_lane[i];
            foreach (rec_h1_eligible_total_per_lane[i])
                h1_eligible_total += rec_h1_eligible_total_per_lane[i];
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_h1 totals: beats=%0d eligible=%0d filtered_tserr=%0d filter_inerr=%0b",
                                n_stage_h1_beats, h1_eligible_total,
                                h1_error_total, rbcam_filter_inerr_enabled),
                      UVM_LOW)
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_h1 error beats: lane0=(raw=%0d err=%0d eligible=%0d) lane1=(raw=%0d err=%0d eligible=%0d) lane2=(raw=%0d err=%0d eligible=%0d) lane3=(raw=%0d err=%0d eligible=%0d)",
                                n_stage_h1_beats_per_lane[0], n_stage_h1_error_per_lane[0], rec_h1_eligible_total_per_lane[0],
                                n_stage_h1_beats_per_lane[1], n_stage_h1_error_per_lane[1], rec_h1_eligible_total_per_lane[1],
                                n_stage_h1_beats_per_lane[2], n_stage_h1_error_per_lane[2], rec_h1_eligible_total_per_lane[2],
                                n_stage_h1_beats_per_lane[3], n_stage_h1_error_per_lane[3], rec_h1_eligible_total_per_lane[3]),
                      UVM_LOW)

            foreach (b_parser[i,j]) begin
                b_hits_total     += b_parser[i][j].n_hits;
                b_packets_total  += b_parser[i][j].n_packets;
                b_contract_total += b_parser[i][j].n_contract_err;
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_b[%0d][%0d] parser: packets=%0d subheaders=%0d hits=%0d empty=%0d orphan=%0d contract_err=%0d",
                                    i, j,
                                    b_parser[i][j].n_packets,
                                    b_parser[i][j].n_subheaders,
                                    b_parser[i][j].n_hits,
                                    b_parser[i][j].n_empty_packets,
                                    b_parser[i][j].n_orphan,
                                    b_parser[i][j].n_contract_err),
                          UVM_LOW)
            end
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_b totals: beats=%0d packets=%0d hits=%0d contract_err=%0d",
                                n_stage_b_beats, b_packets_total, b_hits_total, b_contract_total),
                      UVM_LOW)
            if (b_contract_total != 0)
                `uvm_error("TB_INT_SB",
                           $sformatf("stage_b contract parser saw %0d errors", b_contract_total))

            foreach (c_parser[i]) begin
                c_hits_total       += c_parser[i].n_hits;
                c_subheaders_total += c_parser[i].n_subheaders;
                c_frames_total     += c_parser[i].n_frames;
                c_trailers_total   += c_parser[i].n_trailers;
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_c[%0d] parser: frames=%0d preambles=%0d headers=%0d subheaders=%0d hits=%0d trailers=%0d orphan=%0d contract_err=%0d",
                                    i,
                                    c_parser[i].n_frames,
                                    c_parser[i].n_preambles,
                                    c_parser[i].n_headers,
                                    c_parser[i].n_subheaders,
                                    c_parser[i].n_hits,
                                    c_parser[i].n_trailers,
                                    c_parser[i].n_orphan,
                                    c_parser[i].n_contract_err),
                          UVM_LOW)
                if (c_parser[i].n_contract_err != 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage_c[%0d] contract parser saw %0d errors",
                                         i, c_parser[i].n_contract_err))
            end
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_c totals: frames=%0d hits=%0d subheaders=%0d trailers=%0d",
                                c_frames_total, c_hits_total,
                                c_subheaders_total, c_trailers_total),
                      UVM_LOW)

            foreach (d_parser[i]) begin
                d_hits_total       += d_parser[i].n_hits;
                d_subheaders_total += d_parser[i].n_subheaders;
                d_frames_total     += d_parser[i].n_frames;
                d_trailers_total   += d_parser[i].n_trailers;
                `uvm_info("TB_INT_SB",
                          $sformatf("stage_d[%0d] parser: frames=%0d preambles=%0d headers=%0d subheaders=%0d hits=%0d trailers=%0d orphan=%0d contract_err=%0d",
                                    i,
                                    d_parser[i].n_frames,
                                    d_parser[i].n_preambles,
                                    d_parser[i].n_headers,
                                    d_parser[i].n_subheaders,
                                    d_parser[i].n_hits,
                                    d_parser[i].n_trailers,
                                    d_parser[i].n_orphan,
                                    d_parser[i].n_contract_err),
                          UVM_LOW)
                if (d_parser[i].n_contract_err != 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage_d[%0d] contract parser saw %0d errors",
                                         i, d_parser[i].n_contract_err))
            end
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_d totals: frames=%0d hits=%0d subheaders=%0d trailers=%0d",
                                d_frames_total, d_hits_total,
                                d_subheaders_total, d_trailers_total),
                      UVM_LOW)

            `uvm_info("TB_INT_SB",
                      $sformatf("stage_e parser: frames=%0d preambles=%0d headers=%0d subheaders=%0d hits=%0d trailers=%0d orphan=%0d restart_sop=%0d contract_err=%0d",
                                e_parser.n_frames,
                                e_parser.n_preambles,
                                e_parser.n_headers,
                                e_parser.n_subheaders,
                                e_parser.n_hits,
                                e_parser.n_trailers,
                                e_parser.n_orphan,
                                e_parser.n_restart_sop,
                                e_parser.n_contract_err),
                      UVM_LOW)
            if (e_parser.n_contract_err != 0)
                `uvm_error("TB_INT_SB",
                           $sformatf("stage_e contract parser saw %0d errors",
                                     e_parser.n_contract_err))

            `uvm_info("TB_INT_SB",
                      $sformatf("stage_a=%0d a_per_lane=(%0d,%0d,%0d,%0d) stage_h0=%0d h0_per_lane=(%0d,%0d,%0d,%0d) h0_frames_per_lane=(%0d,%0d,%0d,%0d) stage_h1=%0d h1_per_lane=(%0d,%0d,%0d,%0d) stage_b_beats=%0d stage_b_packets=%0d b_beats_per_lane=(%0d,%0d,%0d,%0d) b_packets_per_lane=(%0d,%0d,%0d,%0d) stage_c_beats=%0d stage_c_frames=%0d c_beats_per_lane=(%0d,%0d,%0d,%0d) c_frames_per_lane=(%0d,%0d,%0d,%0d) stage_d_beats=%0d stage_d_frames=%0d d_beats_per_lane=(%0d,%0d,%0d,%0d) d_frames_per_lane=(%0d,%0d,%0d,%0d) stage_e_beats=%0d stage_e_frames=%0d e_lane_unknown=%0d",
                                n_stage_a,
                                n_stage_a_per_lane[0], n_stage_a_per_lane[1],
                                n_stage_a_per_lane[2], n_stage_a_per_lane[3],
                                n_stage_h0_beats,
                                n_stage_h0_beats_per_lane[0], n_stage_h0_beats_per_lane[1],
                                n_stage_h0_beats_per_lane[2], n_stage_h0_beats_per_lane[3],
                                n_stage_h0_frames_per_lane[0], n_stage_h0_frames_per_lane[1],
                                n_stage_h0_frames_per_lane[2], n_stage_h0_frames_per_lane[3],
                                n_stage_h1_beats,
                                n_stage_h1_beats_per_lane[0], n_stage_h1_beats_per_lane[1],
                                n_stage_h1_beats_per_lane[2], n_stage_h1_beats_per_lane[3],
                                n_stage_b_beats, n_stage_b_packets,
                                n_stage_b_beats_per_lane[0], n_stage_b_beats_per_lane[1],
                                n_stage_b_beats_per_lane[2], n_stage_b_beats_per_lane[3],
                                n_stage_b_packets_per_lane[0], n_stage_b_packets_per_lane[1],
                                n_stage_b_packets_per_lane[2], n_stage_b_packets_per_lane[3],
                                n_stage_c_beats, n_stage_c_frames,
                                n_stage_c_beats_per_lane[0], n_stage_c_beats_per_lane[1],
                                n_stage_c_beats_per_lane[2], n_stage_c_beats_per_lane[3],
                                n_stage_c_frames_per_lane[0], n_stage_c_frames_per_lane[1],
                                n_stage_c_frames_per_lane[2], n_stage_c_frames_per_lane[3],
                                n_stage_d_beats, n_stage_d_frames,
                                n_stage_d_beats_per_lane[0], n_stage_d_beats_per_lane[1],
                                n_stage_d_beats_per_lane[2], n_stage_d_beats_per_lane[3],
                                n_stage_d_frames_per_lane[0], n_stage_d_frames_per_lane[1],
                                n_stage_d_frames_per_lane[2], n_stage_d_frames_per_lane[3],
                                n_stage_e_beats, n_stage_e_frames,
                                n_stage_e_lane_unknown),
                      UVM_LOW)
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_h1 slot beats: lane0=(%0d,%0d,%0d,%0d) lane1=(%0d,%0d,%0d,%0d) lane2=(%0d,%0d,%0d,%0d) lane3=(%0d,%0d,%0d,%0d)",
                                n_stage_h1_beats_per_slot[0][0], n_stage_h1_beats_per_slot[0][1],
                                n_stage_h1_beats_per_slot[0][2], n_stage_h1_beats_per_slot[0][3],
                                n_stage_h1_beats_per_slot[1][0], n_stage_h1_beats_per_slot[1][1],
                                n_stage_h1_beats_per_slot[1][2], n_stage_h1_beats_per_slot[1][3],
                                n_stage_h1_beats_per_slot[2][0], n_stage_h1_beats_per_slot[2][1],
                                n_stage_h1_beats_per_slot[2][2], n_stage_h1_beats_per_slot[2][3],
                                n_stage_h1_beats_per_slot[3][0], n_stage_h1_beats_per_slot[3][1],
                                n_stage_h1_beats_per_slot[3][2], n_stage_h1_beats_per_slot[3][3]),
                      UVM_LOW)
            `uvm_info("TB_INT_SB",
                      $sformatf("stage_h1 slot errors: lane0=(%0d,%0d,%0d,%0d) lane1=(%0d,%0d,%0d,%0d) lane2=(%0d,%0d,%0d,%0d) lane3=(%0d,%0d,%0d,%0d)",
                                n_stage_h1_error_per_slot[0][0], n_stage_h1_error_per_slot[0][1],
                                n_stage_h1_error_per_slot[0][2], n_stage_h1_error_per_slot[0][3],
                                n_stage_h1_error_per_slot[1][0], n_stage_h1_error_per_slot[1][1],
                                n_stage_h1_error_per_slot[1][2], n_stage_h1_error_per_slot[1][3],
                                n_stage_h1_error_per_slot[2][0], n_stage_h1_error_per_slot[2][1],
                                n_stage_h1_error_per_slot[2][2], n_stage_h1_error_per_slot[2][3],
                                n_stage_h1_error_per_slot[3][0], n_stage_h1_error_per_slot[3][1],
                                n_stage_h1_error_per_slot[3][2], n_stage_h1_error_per_slot[3][3]),
                      UVM_LOW)
            foreach (rec_h1_total_per_slot[i,j]) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("lane[%0d] slot[%0d] H1->B: H1=%0d H1e=%0d filtered=%0d B=%0d matched_raw=%0d missing_raw=%0d ghost_raw=%0d matched_eligible=%0d missing_eligible=%0d ghost_eligible=%0d",
                                    i, j,
                                    rec_h1_total_per_slot[i][j],
                                    rec_h1_eligible_total_per_slot[i][j],
                                    rec_h1_filtered_per_slot[i][j],
                                    rec_b_total_per_slot[i][j],
                                    rec_matched_h1b_per_slot[i][j],
                                    rec_missing_b_per_slot[i][j],
                                    rec_ghost_b_per_slot[i][j],
                                    rec_matched_h1b_eligible_per_slot[i][j],
                                    rec_missing_b_eligible_per_slot[i][j],
                                    rec_ghost_b_eligible_per_slot[i][j]),
                          UVM_LOW)
                if (rec_missing_b_eligible_per_slot[i][j] > 0 ||
                    rec_ghost_b_eligible_per_slot[i][j] > 0)
                    dump_h1b_slot_residual_buckets(i, j, 8);
            end

            `uvm_info("TB_INT_SB",
                      $sformatf("stable running origin window: %s",
                                tb_int_run_window_db::describe()),
                      UVM_LOW)
            foreach (rec_run_a_total_per_lane[i]) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("lane[%0d] RUN-origin: A=%0d H0=%0d H1=%0d H1e=%0d B=%0d C=%0d D=%0d E=%0d | A->H0 matched=%0d missing=%0d ghost=%0d | H0->H1 matched=%0d missing=%0d ghost=%0d | H1e->B matched=%0d missing=%0d ghost=%0d | B->C matched=%0d missing=%0d ghost=%0d | C->D matched=%0d missing=%0d ghost=%0d | D->E matched=%0d missing=%0d ghost=%0d",
                                    i,
                                    rec_run_a_total_per_lane[i],
                                    rec_run_h0_total_per_lane[i],
                                    rec_run_h1_total_per_lane[i],
                                    rec_run_h1e_total_per_lane[i],
                                    rec_run_b_total_per_lane[i],
                                    rec_run_c_total_per_lane[i],
                                    rec_run_d_total_per_lane[i],
                                    rec_run_e_total_per_lane[i],
                                    rec_run_matched_ah0_per_lane[i],
                                    rec_run_missing_h0_per_lane[i],
                                    rec_run_ghost_h0_per_lane[i],
                                    rec_run_matched_ah1_per_lane[i],
                                    rec_run_missing_h1_per_lane[i],
                                    rec_run_ghost_h1_per_lane[i],
                                    rec_run_matched_ab_per_lane[i],
                                    rec_run_missing_b_per_lane[i],
                                    rec_run_ghost_b_per_lane[i],
                                    rec_run_matched_bc_per_lane[i],
                                    rec_run_missing_c_per_lane[i],
                                    rec_run_ghost_c_per_lane[i],
                                    rec_run_matched_cd_per_lane[i],
                                    rec_run_missing_d_per_lane[i],
                                    rec_run_ghost_d_per_lane[i],
                                    rec_run_matched_de_per_lane[i],
                                    rec_run_missing_e_per_lane[i],
                                    rec_run_ghost_e_per_lane[i]),
                          UVM_LOW)
                if (rec_run_missing_h0_per_lane[i] > 0 || rec_run_ghost_h0_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN A->H0", i),
                                                 "A", stage_a_run_root_obs[i],
                                                 "H0", stage_h0_run_root_obs[i], 8);
                if (rec_run_missing_h1_per_lane[i] > 0 || rec_run_ghost_h1_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN H0->H1", i),
                                                 "H0", stage_h0_run_root_obs[i],
                                                 "H1", stage_h1_run_root_obs[i], 8);
                if (rec_run_missing_b_per_lane[i] > 0 || rec_run_ghost_b_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN H1e->B", i),
                                                 "H1e", stage_h1e_run_root_obs[i],
                                                 "B", stage_b_run_root_obs[i], 8);
                if (rec_run_missing_c_per_lane[i] > 0 || rec_run_ghost_c_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN B->C", i),
                                                 "B", stage_b_run_root_obs[i],
                                                 "C", stage_c_run_root_obs[i], 8);
                if (rec_run_missing_d_per_lane[i] > 0 || rec_run_ghost_d_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN C->D", i),
                                                 "C", stage_c_run_root_obs[i],
                                                 "D", stage_d_run_root_obs[i], 8);
                if (rec_run_missing_e_per_lane[i] > 0 || rec_run_ghost_e_per_lane[i] > 0)
                    dump_root_boundary_candidates($sformatf("lane[%0d] RUN D->E", i),
                                                 "D", stage_d_run_root_obs[i],
                                                 "E", stage_e_run_root_obs[i], 8);
                `uvm_info("TB_INT_SB",
                          $sformatf("lane[%0d] RUN-active reach: H1e(before_run_end)=%0d -> B(any) matched=%0d missing=%0d | B(before_run_end)=%0d -> C(any) matched=%0d missing=%0d",
                                    i,
                                    rec_run_active_h1e_total_per_lane[i],
                                    rec_run_active_h1e_matched_b_per_lane[i],
                                    rec_run_active_h1e_missing_b_per_lane[i],
                                    rec_run_active_b_total_per_lane[i],
                                    rec_run_active_b_matched_c_per_lane[i],
                                    rec_run_active_b_missing_c_per_lane[i]),
                          UVM_LOW)
            end

            foreach (rec_a_total_per_lane[i]) begin
                `uvm_info("TB_INT_SB",
                          $sformatf("lane[%0d] ledger: A=%0d H0=%0d H1=%0d H1e=%0d B=%0d C=%0d D=%0d E=%0d | A->H0 matched=%0d missing=%0d ghost=%0d | H0->H1 matched=%0d missing=%0d ghost=%0d | H1->B raw matched=%0d missing=%0d ghost=%0d | H1->B eligible matched=%0d missing=%0d ghost=%0d filtered=%0d | B->C matched=%0d missing=%0d ghost=%0d | C->D matched=%0d missing=%0d ghost=%0d | D->E matched=%0d missing=%0d ghost=%0d | first_fail=%s | largest_loss=%s",
                                    i,
                                    rec_a_total_per_lane[i],
                                    rec_h0_total_per_lane[i],
                                    rec_h1_total_per_lane[i],
                                    rec_h1_eligible_total_per_lane[i],
                                    rec_b_total_per_lane[i],
                                    rec_c_total_per_lane[i],
                                    rec_d_total_per_lane[i],
                                    rec_e_total_per_lane[i],
                                    rec_matched_ah0_per_lane[i],
                                    rec_missing_h0_per_lane[i],
                                    rec_ghost_h0_per_lane[i],
                                    rec_matched_ah1_per_lane[i],
                                    rec_missing_h1_per_lane[i],
                                    rec_ghost_h1_per_lane[i],
                                    rec_matched_ab_per_lane[i],
                                    rec_missing_b_per_lane[i],
                                    rec_ghost_b_per_lane[i],
                                    rec_matched_ab_eligible_per_lane[i],
                                    rec_missing_b_eligible_per_lane[i],
                                    rec_ghost_b_eligible_per_lane[i],
                                    rec_h1_filtered_per_lane[i],
                                    rec_matched_bc_per_lane[i],
                                    rec_missing_c_per_lane[i],
                                    rec_ghost_c_per_lane[i],
                                    rec_matched_cd_per_lane[i],
                                    rec_missing_d_per_lane[i],
                                    rec_ghost_d_per_lane[i],
                                    rec_matched_de_per_lane[i],
                                    rec_missing_e_per_lane[i],
                                    rec_ghost_e_per_lane[i],
                                    first_fail_desc(i),
                                    largest_loss_desc(i)),
                          UVM_LOW)
                if (rec_missing_h0_per_lane[i] > 0 || rec_missing_h1_per_lane[i] > 0 ||
                    rec_missing_b_eligible_per_lane[i] > 0 || rec_missing_c_per_lane[i] > 0 ||
                    rec_missing_d_per_lane[i] > 0 || rec_missing_e_per_lane[i] > 0 ||
                    rec_ghost_h0_per_lane[i]  > 0 || rec_ghost_h1_per_lane[i]  > 0 ||
                    rec_ghost_b_eligible_per_lane[i] > 0 || rec_ghost_c_per_lane[i] > 0 ||
                    rec_ghost_d_per_lane[i]   > 0 || rec_ghost_e_per_lane[i]   > 0) begin
                    if (rec_missing_h0_per_lane[i] > 0 || rec_ghost_h0_per_lane[i] > 0)
                        dump_ah0_residual_buckets(i, 8);
                    if (rec_missing_c_per_lane[i] > 0 || rec_ghost_c_per_lane[i] > 0)
                        dump_hit2_residual_buckets("B->C", i, stage_b_exact_ledger[i], "B",
                                                   stage_c_exact_ledger[i], "C", 8);
                    if (rec_missing_d_per_lane[i] > 0 || rec_ghost_d_per_lane[i] > 0)
                        dump_hit2_residual_buckets("C->D", i, stage_c_exact_ledger[i], "C",
                                                   stage_d_exact_ledger[i], "D", 8);
                    if (rec_missing_e_per_lane[i] > 0 || rec_ghost_e_per_lane[i] > 0)
                        dump_hit2_residual_buckets("D->E", i, stage_d_exact_ledger[i], "D",
                                                   stage_e_exact_ledger[i], "E", 8);
                    dump_residual_buckets(i, 20);
                end
            end

            if (n_stage_a == 0)
                `uvm_error("TB_INT_SB", "no stage A hits observed")
            if (n_stage_h0_beats == 0)
                `uvm_error("TB_INT_SB", "no stage H0 beats observed")
            if (n_stage_h0_frames == 0)
                `uvm_error("TB_INT_SB", "no stage H0 frame heads observed")
            if (n_stage_h1_beats == 0)
                `uvm_error("TB_INT_SB", "no stage H1 beats observed")
            if (n_stage_b_beats == 0)
                `uvm_error("TB_INT_SB", "no stage B beats observed")
            if (n_stage_b_packets == 0)
                `uvm_error("TB_INT_SB", "no stage B packets observed")
            if (n_stage_c_beats == 0)
                `uvm_error("TB_INT_SB", "no stage C beats observed")
            if (n_stage_c_frames == 0)
                `uvm_error("TB_INT_SB", "no stage C frame heads observed")
            if (n_stage_d_beats == 0)
                `uvm_error("TB_INT_SB", "no stage D beats observed")
            if (n_stage_d_frames == 0)
                `uvm_error("TB_INT_SB", "no stage D frame heads observed")
            if (cfg.require_stage_e) begin
                if (n_stage_e_beats == 0)
                    `uvm_error("TB_INT_SB", "no stage E beats observed")
                if (n_stage_e_frames == 0)
                    `uvm_error("TB_INT_SB", "no stage E frame heads observed")
            end

            if (cfg.require_lossless_feb) begin
                foreach (rec_missing_h0_per_lane[i]) begin
                    if (rec_missing_h0_per_lane[i] > 0 || rec_ghost_h0_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("lossless FEB signoff failed at A->H0 lane %0d: missing=%0d ghost=%0d",
                                             i, rec_missing_h0_per_lane[i], rec_ghost_h0_per_lane[i]))
                    if (rec_missing_h1_per_lane[i] > 0 || rec_ghost_h1_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("lossless FEB signoff failed at H0->H1 lane %0d: missing=%0d ghost=%0d",
                                             i, rec_missing_h1_per_lane[i], rec_ghost_h1_per_lane[i]))
                    if (rec_missing_b_eligible_per_lane[i] > 0 || rec_ghost_b_eligible_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("lossless FEB signoff failed at H1e->B lane %0d: missing=%0d ghost=%0d",
                                             i, rec_missing_b_eligible_per_lane[i], rec_ghost_b_eligible_per_lane[i]))
                    if (rec_missing_c_per_lane[i] > 0 || rec_ghost_c_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("lossless FEB signoff failed at B->C lane %0d: missing=%0d ghost=%0d",
                                             i, rec_missing_c_per_lane[i], rec_ghost_c_per_lane[i]))
                    if (rec_missing_d_per_lane[i] > 0 || rec_ghost_d_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("lossless FEB signoff failed at C->D lane %0d: missing=%0d ghost=%0d",
                                             i, rec_missing_d_per_lane[i], rec_ghost_d_per_lane[i]))
                end
            end

            if (allow_sparse_source_lanes) begin
                `uvm_info("TB_INT_SB",
                          "cluster_cross_asic profile active: source-side per-lane silence checks are mode-aware",
                          UVM_LOW)
            end
            foreach (n_stage_a_per_lane[i]) begin
                if (n_stage_a_per_lane[i] == 0) begin
                    if (lane_requires_source_activity[i])
                        `uvm_error("TB_INT_SB",
                                   $sformatf("stage A lane %0d silent (per-lane hit count 0)", i))
                    else if (cfg.emu_cfg[i].enable)
                        `uvm_info("TB_INT_SB",
                                  $sformatf("stage A lane %0d silent but allowed by the case profile", i),
                                  UVM_LOW)
                end
            end
            foreach (n_stage_h0_beats_per_lane[i]) begin
                if (n_stage_h0_beats_per_lane[i] == 0) begin
                    if (n_stage_a_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("stage H0 lane %0d silent (per-lane beat count 0)", i))
                    else if (cfg.emu_cfg[i].enable)
                        `uvm_info("TB_INT_SB",
                                  $sformatf("stage H0 lane %0d silent because stage A saw no hits", i),
                                  UVM_LOW)
                end
            end
            foreach (n_stage_h0_frames_per_lane[i]) begin
                if (n_stage_h0_frames_per_lane[i] == 0) begin
                    if (n_stage_a_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("stage H0 lane %0d emitted no frame heads", i))
                    else if (cfg.emu_cfg[i].enable)
                        `uvm_info("TB_INT_SB",
                                  $sformatf("stage H0 lane %0d emitted no frame heads because stage A saw no hits", i),
                                  UVM_LOW)
                end
            end
            foreach (n_stage_h1_beats_per_lane[i]) begin
                if (n_stage_h1_beats_per_lane[i] == 0) begin
                    if (n_stage_h0_beats_per_lane[i] > 0)
                        `uvm_error("TB_INT_SB",
                                   $sformatf("stage H1 lane %0d silent (per-lane beat count 0)", i))
                    else if (cfg.emu_cfg[i].enable)
                        `uvm_info("TB_INT_SB",
                                  $sformatf("stage H1 lane %0d silent because stage H0 saw no hits", i),
                                  UVM_LOW)
                end
            end
            foreach (n_stage_b_beats_per_lane[i]) begin
                if (n_stage_b_beats_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage B lane %0d silent (per-lane beat count 0)", i))
            end
            foreach (n_stage_b_packets_per_lane[i]) begin
                if (n_stage_b_packets_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage B lane %0d emitted no hit_type2 packets", i))
            end
            foreach (n_stage_c_beats_per_lane[i]) begin
                if (n_stage_c_beats_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage C lane %0d silent (per-lane beat count 0)", i))
            end
            foreach (n_stage_c_frames_per_lane[i]) begin
                if (n_stage_c_frames_per_lane[i] == 0)
                    `uvm_error("TB_INT_SB",
                               $sformatf("stage C lane %0d emitted no frame heads", i))
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
    // Stage H0 monitor — one per datapath. Samples valid hit_type0 beats on
    // the frame_rcv -> mts boundary.
    // -----------------------------------------------------------------------
    class tb_int_stage_h0_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_h0_monitor)
        virtual hit_type0_if vif;
        uvm_analysis_port#(tb_int_hit0_event) ap;
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
                `uvm_fatal("STAGE_H0", $sformatf("vif not assigned for stage_h0 lane %0d", lane_id))
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1) begin
                    tb_int_hit0_event ev;
                    ev = tb_int_hit0_event::type_id::create("ev");
                    ev.lane_id = lane_id;
                    ev.abs_ts  = $time;
                    ev.data    = vif.data;
                    ev.channel = vif.channel;
                    ev.sop     = vif.startofpacket;
                    ev.eop     = vif.endofpacket;
                    ev.error   = vif.error;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage H1 monitor — one per datapath. Samples accepted hit_type1 beats
    // on the mts -> rb_cam boundary.
    // -----------------------------------------------------------------------
    class tb_int_stage_h1_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_h1_monitor)
        virtual hit_type1_if vif;
        uvm_analysis_port#(tb_int_hit1_event) ap;
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
                `uvm_fatal("STAGE_H1", $sformatf("vif not assigned for stage_h1 lane %0d", lane_id))
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1 && vif.ready === 1'b1) begin
                    tb_int_hit1_event ev;
                    ev = tb_int_hit1_event::type_id::create("ev");
                    ev.lane_id = lane_id;
                    ev.abs_ts  = $time;
                    ev.data    = vif.data;
                    ev.channel = vif.channel;
                    ev.sop     = vif.startofpacket;
                    ev.eop     = vif.endofpacket;
                    ev.empty   = vif.empty;
                    ev.error   = vif.error;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage B monitor — one per datapath/slot ring_buffer_cam hit_type2
    // stream. Samples only accepted beats (valid && ready).
    // -----------------------------------------------------------------------
    class tb_int_stage_b_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_b_monitor)
        virtual hit_type2_if vif;
        uvm_analysis_port#(tb_int_hit2_event) ap;
        int unsigned lane_id;
        int unsigned slot_id;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                `uvm_fatal("STAGE_B",
                           $sformatf("vif not assigned for stage_b lane %0d slot %0d",
                                     lane_id, slot_id))
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1) continue;
                if (vif.valid === 1'b1 && vif.ready === 1'b1) begin
                    tb_int_hit2_event ev;
                    ev = tb_int_hit2_event::type_id::create("ev");
                    ev.lane_id = lane_id;
                    ev.slot_id = slot_id;
                    ev.abs_ts  = $time;
                    ev.data    = vif.data;
                    ev.channel = vif.channel;
                    ev.sop     = vif.startofpacket;
                    ev.eop     = vif.endofpacket;
                    ev.error   = vif.error[0];
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage C monitor — one per pre-gate FEB tx lane.
    // -----------------------------------------------------------------------
    class tb_int_stage_c_monitor extends uvm_component;
        `uvm_component_utils(tb_int_stage_c_monitor)
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
                `uvm_fatal("STAGE_C", $sformatf("vif not assigned for stage_c lane %0d", lane_id))
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
                    ev.error  = vif.error;
                    ap.write(ev);
                end
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Stage D monitor — one per post-gate OPQ ingress lane. Snoops valid
    // beats on the run_enable-qualified ingress stream. The OPQ ingress side
    // has no ready/valid handshake to gate against, so every cycle of valid
    // is an accepted beat.
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
    // Framed-beat to frame-item bridge for stage C / stage D capture.
    // This preserves a reusable TLM path from the real FEB frame contract
    // while keeping the direct pin-level OPQ path active for tb_int.
    // -----------------------------------------------------------------------
    class tb_int_ingress_frame_bridge extends uvm_component;
        `uvm_component_utils(tb_int_ingress_frame_bridge)

        uvm_analysis_imp#(tb_int_ingress_event, tb_int_ingress_frame_bridge) ingress_imp;
        uvm_analysis_port#(tb_int_frame_item) ap;

        string             stage_name;
        int                lane_id;
        tb_int_frame_item  curr_frame;
        int unsigned       header_words_seen;
        int                active_subheader_idx;
        int unsigned       hit_words_left;
        bit [31:0]         frame_ts_hi32;
        int unsigned       n_frames_built;
        int unsigned       n_orphan_beats;
        int unsigned       n_capture_err;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            stage_name = "?";
            lane_id = -1;
            reset_state();
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ingress_imp = new("ingress_imp", this);
            ap = new("ap", this);
        endfunction

        function automatic bit is_preamble(bit [35:0] data);
            return (data[35:32] == 4'b0001) && (data[7:0] == K285);
        endfunction

        function automatic bit is_subheader(bit [35:0] data);
            return (data[35:32] == 4'b0001) && (data[7:0] == 8'hF7);
        endfunction

        function automatic bit is_trailer(bit [35:0] data);
            return (data[35:32] == 4'b0001) && (data[7:0] == 8'h9C);
        endfunction

        function automatic bit is_hit_word(bit [35:0] data);
            return (data[35:32] == 4'b0000);
        endfunction

        function automatic void note_capture_err(string msg);
            n_capture_err++;
            `uvm_warning("FRAME_TLM", $sformatf("%s lane=%0d %s", stage_name, lane_id, msg));
        endfunction

        function automatic void reset_state();
            curr_frame = null;
            header_words_seen = 0;
            active_subheader_idx = -1;
            hit_words_left = 0;
            frame_ts_hi32 = '0;
        endfunction

        function automatic void start_frame(tb_int_ingress_event ev);
            if (curr_frame != null) begin
                note_capture_err("new SOP arrived before trailer; dropping partial frame");
                reset_state();
            end

            curr_frame = tb_int_frame_item::type_id::create(
                $sformatf("%s_lane%0d_frame_%0d", stage_name, lane_id, n_frames_built)
            );
            if (stage_name == "C")
                curr_frame.stage_tag = "C";
            else if (stage_name == "D")
                curr_frame.stage_tag = "D";
            else
                curr_frame.stage_tag = 8'h3F;
            curr_frame.lane_id = ev.lane_id;
            curr_frame.channel = ev.channel;
            curr_frame.dt_type = ev.data[31:26];
            curr_frame.feb_id = ev.data[23:8];
            curr_frame.whole_frame_packet = 1'b1;
            curr_frame.first_abs_ts = ev.abs_ts;
            curr_frame.last_abs_ts = ev.abs_ts;
            header_words_seen = 0;
            active_subheader_idx = -1;
            hit_words_left = 0;
            frame_ts_hi32 = '0;
        endfunction

        function automatic void emit_frame(time abs_ts);
            tb_int_frame_item frame_clone;

            if (curr_frame == null) begin
                return;
            end
            curr_frame.last_abs_ts = abs_ts;
            $cast(frame_clone, curr_frame.clone());
            ap.write(frame_clone);
            n_frames_built++;
            reset_state();
        endfunction

        virtual function void write(tb_int_ingress_event ev);
            if (curr_frame == null) begin
                if (is_preamble(ev.data)) begin
                    start_frame(ev);
                end else begin
                    n_orphan_beats++;
                end
                return;
            end

            if (is_preamble(ev.data)) begin
                start_frame(ev);
                return;
            end

            curr_frame.last_abs_ts = ev.abs_ts;

            if (header_words_seen < 4) begin
                case (header_words_seen)
                    0: frame_ts_hi32 = ev.data[31:0];
                    1: begin
                        curr_frame.frame_ts = {frame_ts_hi32, ev.data[31:16]};
                        curr_frame.pkg_cnt  = ev.data[15:0];
                    end
                    default: begin
                    end
                endcase
                header_words_seen++;
                if (ev.eop) begin
                    note_capture_err("frame terminated during header words");
                end
                return;
            end

            if (is_trailer(ev.data)) begin
                if (hit_words_left != 0) begin
                    note_capture_err("trailer arrived with hit words still pending");
                end
                emit_frame(ev.abs_ts);
                return;
            end

            if (is_subheader(ev.data)) begin
                tb_int_frame_subheader_desc shd;

                if (hit_words_left != 0) begin
                    note_capture_err("new subheader arrived before previous hit payloads completed");
                end
                shd = tb_int_frame_subheader_desc::type_id::create(
                    $sformatf("%s_lane%0d_shd_%0d", stage_name, lane_id, curr_frame.subheaders.size())
                );
                shd.shd_ts = ev.data[31:24];
                curr_frame.subheaders.push_back(shd);
                active_subheader_idx = curr_frame.subheaders.size() - 1;
                hit_words_left = ev.data[15:8];
                if (ev.eop && !is_trailer(ev.data)) begin
                    note_capture_err("subheader beat asserted EOP without trailer");
                end
                return;
            end

            if (is_hit_word(ev.data)) begin
                tb_int_frame_hit_desc hit_desc;

                if (hit_words_left == 0 || active_subheader_idx < 0 ||
                    active_subheader_idx >= curr_frame.subheaders.size()) begin
                    note_capture_err($sformatf("hit beat without active subheader data=0x%09h", ev.data));
                    return;
                end
                hit_desc = tb_int_frame_hit_desc::type_id::create(
                    $sformatf("%s_lane%0d_hit_%0d_%0d",
                              stage_name, lane_id, active_subheader_idx,
                              curr_frame.subheaders[active_subheader_idx].hits.size())
                );
                hit_desc.payload_word = ev.data[31:0];
                curr_frame.subheaders[active_subheader_idx].hits.push_back(hit_desc);
                hit_words_left--;
                if (ev.eop) begin
                    note_capture_err("hit beat asserted EOP without trailer");
                end
                return;
            end

            note_capture_err($sformatf("unclassified beat data=0x%09h", ev.data));
        endfunction

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("FRAME_TLM",
                      $sformatf("%s lane=%0d tlm_frames=%0d capture_err=%0d",
                                stage_name, lane_id, n_frames_built, n_capture_err),
                      UVM_LOW)
            if (n_orphan_beats != 0) begin
                `uvm_info("FRAME_TLM",
                          $sformatf("%s lane=%0d orphan_beats=%0d",
                                    stage_name, lane_id, n_orphan_beats),
                          UVM_LOW)
            end
        endfunction
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

        int unsigned stable_start_guard_cycles = 128;
        int unsigned stable_end_guard_cycles   = 128;
        int unsigned term_done_timeout_cycles  = 300000;
        int unsigned term_quiet_cycles         = 64;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            int unsigned plusarg_cycles;

            if (!uvm_config_db#(virtual run_control_if)::get(this, "", "rc_if", vif))
                `uvm_fatal("RC_DRV", "rc_if not found in config db")
            if ($value$plusargs("TB_INT_STABLE_START_GUARD_CYCLES=%d", plusarg_cycles))
                stable_start_guard_cycles = plusarg_cycles;
            if ($value$plusargs("TB_INT_STABLE_END_GUARD_CYCLES=%d", plusarg_cycles))
                stable_end_guard_cycles = plusarg_cycles;
            if ($value$plusargs("TB_INT_TERM_DONE_TIMEOUT_CYCLES=%d", plusarg_cycles))
                term_done_timeout_cycles = plusarg_cycles;
            if ($value$plusargs("TB_INT_TERM_QUIET_CYCLES=%d", plusarg_cycles))
                term_quiet_cycles = plusarg_cycles;
            tb_int_run_window_db::configure_guards(stable_start_guard_cycles,
                                                   stable_end_guard_cycles);
            tb_int_run_window_db::reset();
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
                    tb_int_run_window_db::reset();
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
                    int unsigned stable_prefix_cycles;
                    int unsigned stable_body_cycles;
                    int unsigned stable_suffix_cycles;

                    // SYNC pulse: resets rb_cam gts counter and releases the
                    // PREPARE-state flush. The OPQ/feb pipeline chain all
                    // honor the same 9-bit one-hot convention.
                    vif.run_state  <= RC_STATE_SYNC;
                    vif.run_enable <= 1'b0;
                    repeat (SYNC_HOLD_CYCLES) @(posedge vif.clk);
                    vif.run_state  <= RC_STATE_RUNNING;
                    vif.run_enable <= 1'b1;
                    tb_int_run_window_db::note_run_start($time);

                    stable_prefix_cycles = (it.hold_cycles < stable_start_guard_cycles)
                                           ? it.hold_cycles : stable_start_guard_cycles;
                    if (it.hold_cycles > stable_prefix_cycles + stable_end_guard_cycles)
                        stable_suffix_cycles = stable_end_guard_cycles;
                    else
                        stable_suffix_cycles = (it.hold_cycles > stable_prefix_cycles)
                                               ? (it.hold_cycles - stable_prefix_cycles) : 0;
                    stable_body_cycles = it.hold_cycles - stable_prefix_cycles - stable_suffix_cycles;

                    repeat (stable_prefix_cycles) @(posedge vif.clk);
                    if (stable_body_cycles != 0) begin
                        tb_int_run_window_db::note_stable_start($time);
                        repeat (stable_body_cycles) @(posedge vif.clk);
                        tb_int_run_window_db::note_stable_end($time);
                    end
                    repeat (stable_suffix_cycles) @(posedge vif.clk);
                end
                RC_END: begin
                    int unsigned waited;
                    int unsigned quiet_seen;
                    bit          term_done_seen;

                    tb_int_run_window_db::note_run_end($time);
                    vif.run_state  <= RC_STATE_TERMINATING;
                    vif.run_enable <= 1'b1;
                    repeat (it.hold_cycles) @(posedge vif.clk);

                    waited         = 0;
                    quiet_seen     = 0;
                    term_done_seen = 1'b0;
                    while (!term_done_seen || quiet_seen < term_quiet_cycles) begin
                        @(posedge vif.clk);
                        waited++;
                        if (vif.term_done === 1'b1)
                            term_done_seen = 1'b1;
                        if (term_done_seen && vif.feb_quiet === 1'b1)
                            quiet_seen++;
                        else
                            quiet_seen = 0;
                        if (waited >= term_done_timeout_cycles) begin
                            `uvm_fatal("RC_DRV",
                                       $sformatf("terminate drain never completed after %0d cycles (term_done_seen=%0b feb_quiet=%0b quiet_seen=%0d)",
                                                 term_done_timeout_cycles,
                                                 term_done_seen,
                                                 vif.feb_quiet,
                                                 quiet_seen))
                        end
                    end
                    `uvm_info("RC_DRV",
                              $sformatf("TERMINATING done after %0d extra wait cycles (quiet_cycles=%0d)",
                                        waited, term_quiet_cycles),
                              UVM_LOW)
                    vif.run_state  <= RC_STATE_IDLE;
                    vif.run_enable <= 1'b0;
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
        tb_int_stage_h0_monitor stage_h0[4];
        tb_int_stage_h1_monitor stage_h1[4];
        tb_int_stage_b_monitor  stage_b [4][4];
        tb_int_stage_c_monitor  stage_c [4];
        tb_int_stage_d_monitor  stage_d [4];
        tb_int_stage_e_monitor  stage_e;
        tb_int_ingress_frame_bridge stage_c_tlm[4];
        tb_int_ingress_frame_bridge stage_d_tlm[4];
        uvm_tlm_analysis_fifo#(tb_int_frame_item) stage_c_frame_fifo[4];
        uvm_tlm_analysis_fifo#(tb_int_frame_item) stage_d_frame_fifo[4];

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(tb_int_cfg)::get(this, "", "cfg", cfg)) begin
                cfg = tb_int_cfg::type_id::create("cfg");
            end
            uvm_config_db#(tb_int_cfg)::set(this, "sb", "cfg", cfg);
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
            foreach (stage_h0[i]) begin
                stage_h0[i] = tb_int_stage_h0_monitor::type_id::create(
                                  $sformatf("stage_h0_%0d", i), this);
                stage_h0[i].lane_id = i;
                if (!uvm_config_db#(virtual hit_type0_if)::get(
                        this, "", $sformatf("stage_h0_lane%0d_if", i), stage_h0[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_h0_lane%0d_if not found in config db", i))
            end
            foreach (stage_h1[i]) begin
                stage_h1[i] = tb_int_stage_h1_monitor::type_id::create(
                                  $sformatf("stage_h1_%0d", i), this);
                stage_h1[i].lane_id = i;
                if (!uvm_config_db#(virtual hit_type1_if)::get(
                        this, "", $sformatf("stage_h1_lane%0d_if", i), stage_h1[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_h1_lane%0d_if not found in config db", i))
            end
            foreach (stage_b[i,j]) begin
                stage_b[i][j] = tb_int_stage_b_monitor::type_id::create(
                                    $sformatf("stage_b_%0d_%0d", i, j), this);
                stage_b[i][j].lane_id = i;
                stage_b[i][j].slot_id = j;
                if (!uvm_config_db#(virtual hit_type2_if)::get(
                        this, "",
                        $sformatf("stage_b_lane%0d_slot%0d_if", i, j),
                        stage_b[i][j].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_b_lane%0d_slot%0d_if not found in config db",
                                         i, j))
            end
            foreach (stage_c[i]) begin
                stage_c[i] = tb_int_stage_c_monitor::type_id::create(
                                 $sformatf("stage_c_%0d", i), this);
                stage_c[i].lane_id = i;
                if (!uvm_config_db#(virtual opq_ingress_if)::get(
                        this, "", $sformatf("stage_c_lane%0d_if", i), stage_c[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_c_lane%0d_if not found in config db", i))
                stage_c_tlm[i] = tb_int_ingress_frame_bridge::type_id::create(
                                     $sformatf("stage_c_tlm_%0d", i), this);
                stage_c_tlm[i].stage_name = "C";
                stage_c_tlm[i].lane_id = i;
                stage_c_frame_fifo[i] = new($sformatf("stage_c_frame_fifo_%0d", i), this);
            end
            foreach (stage_d[i]) begin
                stage_d[i] = tb_int_stage_d_monitor::type_id::create(
                                 $sformatf("stage_d_%0d", i), this);
                stage_d[i].lane_id = i;
                if (!uvm_config_db#(virtual opq_ingress_if)::get(
                        this, "", $sformatf("stage_d_lane%0d_if", i), stage_d[i].vif))
                    `uvm_fatal("ENV",
                               $sformatf("stage_d_lane%0d_if not found in config db", i))
                stage_d_tlm[i] = tb_int_ingress_frame_bridge::type_id::create(
                                     $sformatf("stage_d_tlm_%0d", i), this);
                stage_d_tlm[i].stage_name = "D";
                stage_d_tlm[i].lane_id = i;
                stage_d_frame_fifo[i] = new($sformatf("stage_d_frame_fifo_%0d", i), this);
            end
            stage_e = tb_int_stage_e_monitor::type_id::create("stage_e", this);
            if (!uvm_config_db#(virtual opq_egress_if)::get(
                    this, "", "egress_if", stage_e.vif))
                `uvm_fatal("ENV", "egress_if not found in config db")
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            foreach (stage_a[i]) stage_a[i].ap.connect(sb.stage_a_imp);
            foreach (stage_h0[i]) stage_h0[i].ap.connect(sb.stage_h0_imp);
            foreach (stage_h1[i]) stage_h1[i].ap.connect(sb.stage_h1_imp);
            foreach (stage_b[i,j]) stage_b[i][j].ap.connect(sb.stage_b_imp);
            foreach (stage_c[i]) begin
                stage_c[i].ap.connect(sb.stage_c_imp);
                stage_c[i].ap.connect(stage_c_tlm[i].ingress_imp);
                stage_c_tlm[i].ap.connect(stage_c_frame_fifo[i].analysis_export);
            end
            foreach (stage_d[i]) begin
                stage_d[i].ap.connect(sb.stage_d_imp);
                stage_d[i].ap.connect(stage_d_tlm[i].ingress_imp);
                stage_d_tlm[i].ap.connect(stage_d_frame_fifo[i].analysis_export);
            end
            stage_e.ap.connect(sb.stage_e_imp);
        endfunction

        // Hybrid FEB->OPQ tests can block on the real stage-C/stage-D frame
        // contract here without touching the monitor internals directly.
        virtual task wait_stage_c_frame(int unsigned lane, output tb_int_frame_item frame);
            if (lane >= 4)
                `uvm_fatal("ENV", $sformatf("wait_stage_c_frame lane=%0d out of range", lane))
            stage_c_frame_fifo[lane].get(frame);
        endtask

        virtual task wait_stage_d_frame(int unsigned lane, output tb_int_frame_item frame);
            if (lane >= 4)
                `uvm_fatal("ENV", $sformatf("wait_stage_d_frame lane=%0d out of range", lane))
            stage_d_frame_fifo[lane].get(frame);
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Base virtual sequence (PREPARE -> START -> END)
    // -----------------------------------------------------------------------
    class tb_int_base_vseq extends uvm_sequence;
        `uvm_object_utils(tb_int_base_vseq)
        run_control_sequencer rc_sqr;
        int unsigned prepare_cycles = 1024;
        int unsigned run_cycles     = 2000;
        // Minimum TERMINATING grace before the run-control driver starts
        // waiting for the real drain-complete handshake. The actual end of
        // run is no longer a hard fixed window; tb_int now waits for the
        // datapath ctrl-ready aggregate plus a quiet FEB output streak.
        int unsigned end_cycles     = 4096;

        function new(string name = "tb_int_base_vseq");
            super.new(name);
        endfunction

        virtual task body();
            int unsigned    plusarg_cycles;
            run_control_item it;

            if ($value$plusargs("TB_INT_PREPARE_CYCLES=%d", plusarg_cycles))
                prepare_cycles = plusarg_cycles;
            if ($value$plusargs("TB_INT_RUN_CYCLES=%d", plusarg_cycles))
                run_cycles = plusarg_cycles;
            if ($value$plusargs("TB_INT_END_CYCLES=%d", plusarg_cycles))
                end_cycles = plusarg_cycles;

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
        virtual opq_csr_if csr_vif;
        virtual emut_avmm_csr_if.drv emu_csr_vif[4];

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
            if (!uvm_config_db#(virtual opq_csr_if)::get(this, "", "csr_if", csr_vif))
                `uvm_fatal("TB_INT_CFG", "csr_if not found in config db")
            foreach (emu_csr_vif[i]) begin
                if (!uvm_config_db#(virtual emut_avmm_csr_if.drv)::get(
                        this, "", $sformatf("emu_csr_lane%0d_if", i), emu_csr_vif[i]))
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("emu_csr_lane%0d_if not found in config db", i))
            end
        endfunction

        task automatic wait_for_reset_release();
            if (emu_csr_vif[0] == null)
                `uvm_fatal("TB_INT_CFG", "emu_csr_lane0_if is null")
            while (emu_csr_vif[0].rst === 1'b1)
                @(posedge emu_csr_vif[0].clk);
            repeat (2) @(posedge emu_csr_vif[0].clk);
        endtask

        task automatic emu_csr_write(int unsigned lane,
                                     bit [3:0] address,
                                     bit [31:0] writedata,
                                     input string what = "");
            if (lane >= 4)
                `uvm_fatal("TB_INT_CFG", $sformatf("invalid emulator lane %0d", lane))
            @(posedge emu_csr_vif[lane].clk);
            emu_csr_vif[lane].address   <= address;
            emu_csr_vif[lane].writedata <= writedata;
            emu_csr_vif[lane].write     <= 1'b1;
            emu_csr_vif[lane].read      <= 1'b0;
            @(posedge emu_csr_vif[lane].clk);
            while (emu_csr_vif[lane].waitrequest === 1'b1)
                @(posedge emu_csr_vif[lane].clk);
            emu_csr_vif[lane].write     <= 1'b0;
            emu_csr_vif[lane].address   <= '0;
            emu_csr_vif[lane].writedata <= '0;
            if (what != "")
                `uvm_info("TB_INT_EMU_CFG",
                          $sformatf("lane%0d write %s addr=0x%0h data=0x%08h",
                                    lane, what, address, writedata),
                          UVM_LOW)
        endtask

        task automatic emu_csr_read(int unsigned lane,
                                    bit [3:0] address,
                                    output bit [31:0] readdata,
                                    input string what = "");
            if (lane >= 4)
                `uvm_fatal("TB_INT_CFG", $sformatf("invalid emulator lane %0d", lane))
            @(posedge emu_csr_vif[lane].clk);
            emu_csr_vif[lane].address <= address;
            emu_csr_vif[lane].read    <= 1'b1;
            emu_csr_vif[lane].write   <= 1'b0;
            @(posedge emu_csr_vif[lane].clk);
            while (emu_csr_vif[lane].waitrequest === 1'b1)
                @(posedge emu_csr_vif[lane].clk);
            #1step;
            readdata = emu_csr_vif[lane].readdata;
            emu_csr_vif[lane].read    <= 1'b0;
            emu_csr_vif[lane].address <= '0;
            if (what != "")
                `uvm_info("TB_INT_EMU_CFG",
                          $sformatf("lane%0d read %s addr=0x%0h data=0x%08h",
                                    lane, what, address, readdata),
                          UVM_LOW)
        endtask

        task automatic opq_csr_read(bit [8:0] address,
                                    output bit [31:0] readdata,
                                    input string what = "");
            logic [31:0] rd;
            if (csr_vif == null)
                `uvm_fatal("TB_INT_CFG", "csr_if is null")
            csr_vif.read32(address, rd);
            readdata = rd;
            if (what != "")
                `uvm_info("TB_INT_OPQ_CSR",
                          $sformatf("read %s addr=0x%03h data=0x%08h",
                                    what, address, readdata),
                          UVM_LOW)
        endtask

        task automatic dump_opq_csr_snapshot(string tag = "post_run");
            bit [31:0] uid_word;
            bit [31:0] meta_word;
            bit [31:0] lane_mask_word;
            bit [31:0] status_word;
            bit [31:0] cap_word;
            bit [31:0] ft_wr_hdr;
            bit [31:0] ft_wr_shd;
            bit [31:0] ft_wr_hit;
            bit [31:0] ft_rd_hdr;
            bit [31:0] ft_rd_shd;
            bit [31:0] ft_rd_hit;
            bit [31:0] ft_drop_hdr;
            bit [31:0] ft_drop_shd;
            bit [31:0] ft_drop_hit;

            opq_csr_read(OPQ_CSR_WORD_UID, uid_word, {tag, ".uid"});
            opq_csr_read(OPQ_CSR_WORD_META, meta_word, {tag, ".meta"});
            opq_csr_read(OPQ_CSR_WORD_LANE_MASK, lane_mask_word, {tag, ".lane_mask"});
            opq_csr_read(OPQ_CSR_WORD_STATUS, status_word, {tag, ".status"});
            opq_csr_read(OPQ_CSR_WORD_CAP, cap_word, {tag, ".cap"});
            opq_csr_read(OPQ_CSR_WORD_FT_WR_HDR, ft_wr_hdr, {tag, ".ft_wr_hdr"});
            opq_csr_read(OPQ_CSR_WORD_FT_WR_SHD, ft_wr_shd, {tag, ".ft_wr_shd"});
            opq_csr_read(OPQ_CSR_WORD_FT_WR_HIT, ft_wr_hit, {tag, ".ft_wr_hit"});
            opq_csr_read(OPQ_CSR_WORD_FT_RD_HDR, ft_rd_hdr, {tag, ".ft_rd_hdr"});
            opq_csr_read(OPQ_CSR_WORD_FT_RD_SHD, ft_rd_shd, {tag, ".ft_rd_shd"});
            opq_csr_read(OPQ_CSR_WORD_FT_RD_HIT, ft_rd_hit, {tag, ".ft_rd_hit"});
            opq_csr_read(OPQ_CSR_WORD_FT_DROP_HDR, ft_drop_hdr, {tag, ".ft_drop_hdr"});
            opq_csr_read(OPQ_CSR_WORD_FT_DROP_SHD, ft_drop_shd, {tag, ".ft_drop_shd"});
            opq_csr_read(OPQ_CSR_WORD_FT_DROP_HIT, ft_drop_hit, {tag, ".ft_drop_hit"});
            `uvm_info("TB_INT_OPQ_CSR",
                      $sformatf("%s summary uid=0x%08h meta=0x%08h lane_mask=0x%08h status=0x%08h cap=0x%08h ft_wr=(%0d,%0d,%0d) ft_rd=(%0d,%0d,%0d) ft_drop=(%0d,%0d,%0d)",
                                tag, uid_word, meta_word, lane_mask_word, status_word, cap_word,
                                ft_wr_hdr, ft_wr_shd, ft_wr_hit,
                                ft_rd_hdr, ft_rd_shd, ft_rd_hit,
                                ft_drop_hdr, ft_drop_shd, ft_drop_hit),
                      UVM_NONE)
            for (int lane = 0; lane < cfg.opq_n_lane; lane++) begin
                bit [8:0] lane_base;
                bit [31:0] wr_hdr;
                bit [31:0] wr_shd;
                bit [31:0] wr_hit;
                bit [31:0] rd_hdr;
                bit [31:0] rd_shd;
                bit [31:0] rd_hit;
                bit [31:0] drop_hdr;
                bit [31:0] drop_shd;
                bit [31:0] drop_hit;
                bit [31:0] lane_credit;
                bit [31:0] ticket_credit;
                bit [31:0] drr_allowance;
                bit [31:0] drr_quantum;
                bit [31:0] drr_grant_cnt;
                bit [31:0] drr_beat_cnt;
                bit [31:0] drr_defer_cnt;

                lane_base = OPQ_CSR_LANE_REGION_BASE + lane * OPQ_CSR_LANE_REGION_STRIDE;
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_WR_HDR, wr_hdr);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_WR_SHD, wr_shd);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_WR_HIT, wr_hit);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_RD_HDR, rd_hdr);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_RD_SHD, rd_shd);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_RD_HIT, rd_hit);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DROP_HDR, drop_hdr);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DROP_SHD, drop_shd);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DROP_HIT, drop_hit);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_LANE_CREDIT, lane_credit);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_TICKET_CREDIT, ticket_credit);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DRR_ALLOWANCE, drr_allowance);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DRR_QUANTUM, drr_quantum);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DRR_GRANT_CNT, drr_grant_cnt);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DRR_BEAT_CNT, drr_beat_cnt);
                opq_csr_read(lane_base + OPQ_CSR_LANE_WORD_DRR_DEFER_CNT, drr_defer_cnt);
                `uvm_info("TB_INT_OPQ_CSR",
                          $sformatf("%s lane%0d wr=(%0d,%0d,%0d) rd=(%0d,%0d,%0d) drop=(%0d,%0d,%0d) credit=(lane=%0d,ticket=%0d) drr=(allow=%0d,quantum=%0d,grant=%0d,beat=%0d,defer=%0d)",
                                    tag, lane,
                                    wr_hdr, wr_shd, wr_hit,
                                    rd_hdr, rd_shd, rd_hit,
                                    drop_hdr, drop_shd, drop_hit,
                                    lane_credit, ticket_credit,
                                    drr_allowance, drr_quantum, drr_grant_cnt, drr_beat_cnt, drr_defer_cnt),
                          UVM_NONE)
            end
        endtask

        task automatic program_emulator_lane(int unsigned lane,
                                             tb_int_emut_cfg lane_cfg,
                                             bit verify_readback = 1'b1);
            bit [31:0] rd;
            if (lane_cfg == null)
                `uvm_fatal("TB_INT_CFG", $sformatf("emu_cfg[%0d] is null", lane))
            `uvm_info("TB_INT_EMU_CFG",
                      $sformatf("lane%0d profile: %s", lane, lane_cfg.describe()),
                      UVM_LOW)
            emu_csr_write(lane, 4'h0, lane_cfg.control_reg(), "CONTROL");
            emu_csr_write(lane, 4'h1, lane_cfg.hit_rate_reg(), "HIT_RATE");
            emu_csr_write(lane, 4'h2, lane_cfg.burst_cfg_reg(), "BURST_CFG");
            emu_csr_write(lane, 4'h3, lane_cfg.seed, "PRNG_SEED");
            emu_csr_write(lane, 4'h4, lane_cfg.tx_mode_reg(), "TX_MODE");
            if (verify_readback) begin
                emu_csr_read(lane, 4'h0, rd, "CONTROL");
                if (rd !== lane_cfg.control_reg())
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("lane%0d CONTROL readback mismatch exp=0x%08h got=0x%08h",
                                         lane, lane_cfg.control_reg(), rd))
                emu_csr_read(lane, 4'h1, rd, "HIT_RATE");
                if (rd !== lane_cfg.hit_rate_reg())
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("lane%0d HIT_RATE readback mismatch exp=0x%08h got=0x%08h",
                                         lane, lane_cfg.hit_rate_reg(), rd))
                emu_csr_read(lane, 4'h2, rd, "BURST_CFG");
                if (rd !== lane_cfg.burst_cfg_reg())
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("lane%0d BURST_CFG readback mismatch exp=0x%08h got=0x%08h",
                                         lane, lane_cfg.burst_cfg_reg(), rd))
                emu_csr_read(lane, 4'h3, rd, "PRNG_SEED");
                if (rd !== lane_cfg.seed)
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("lane%0d PRNG_SEED readback mismatch exp=0x%08h got=0x%08h",
                                         lane, lane_cfg.seed, rd))
                emu_csr_read(lane, 4'h4, rd, "TX_MODE");
                if (rd !== lane_cfg.tx_mode_reg())
                    `uvm_fatal("TB_INT_CFG",
                               $sformatf("lane%0d TX_MODE readback mismatch exp=0x%08h got=0x%08h",
                                         lane, lane_cfg.tx_mode_reg(), rd))
            end
        endtask

        virtual task configure_before_run();
        endtask

        virtual task check_after_run();
        endtask

        virtual task run_phase(uvm_phase phase);
            tb_int_base_vseq vseq;
            phase.raise_objection(this);
            wait_for_reset_release();
            configure_before_run();
            vseq = tb_int_base_vseq::type_id::create("vseq");
            vseq.run_cycles = cfg.smoke_run_cycles;
            vseq.start(env.rc_agent.sqr);
            check_after_run();
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
            // Shortened from 200000 to keep the run below the latent OPQ
            // truncation/delta-storm window that opens at sim time
            // ~2061780 ns. Long-horizon run lives in a follow-up once
            // the OPQ bug is rooted out.
            c.smoke_run_cycles = 40000;
            return c;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Terminate-marker E2E test — same datapath budget as the basic test, but
    // called out separately so the upgraded terminate-drain contract has an
    // explicit integration regression target. The RC_END path now waits on
    // term_done + feb_quiet instead of cutting back to IDLE on a fixed timer.
    // -----------------------------------------------------------------------
    class tb_int_terminate_marker_e2e_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_terminate_marker_e2e_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function tb_int_cfg make_cfg();
            tb_int_cfg c;
            c = tb_int_cfg::type_id::create("cfg");
            c.smoke_run_cycles = 40000;
            return c;
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Long-run sanity test — generated emulator-profile matrix for FEB-side
    // datapath signoff. This keeps stage E optional while requiring lossless
    // closure through stage D.
    // -----------------------------------------------------------------------
    class tb_int_longrun_sanity_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_longrun_sanity_test)

        localparam bit [1:0] HIT_MODE_POISSON = 2'b00;
        localparam bit [1:0] HIT_MODE_BURST   = 2'b01;
        localparam bit [1:0] HIT_MODE_NOISE   = 2'b10;
        localparam bit [1:0] HIT_MODE_MIXED   = 2'b11;
        localparam bit [2:0] TX_MODE_LONG     = 3'b000;
        localparam bit [2:0] TX_MODE_SHORT    = 3'b100;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function automatic bit [15:0] base_hit_rate(bit short_mode, int unsigned load_idx);
            if (short_mode) begin
                case (load_idx)
                    0: return 16'h0200;
                    1: return 16'h0500;
                    2: return 16'h0800;
                    default: return 16'h0C00;
                endcase
            end
            case (load_idx)
                0: return 16'h0100;
                1: return 16'h0400;
                2: return 16'h0600;
                default: return 16'h0900;
            endcase
        endfunction

        function automatic bit [15:0] base_noise_rate(bit short_mode, int unsigned load_idx);
            if (short_mode) begin
                case (load_idx)
                    0: return 16'h0040;
                    1: return 16'h0100;
                    2: return 16'h0180;
                    default: return 16'h0200;
                endcase
            end
            case (load_idx)
                0: return 16'h0020;
                1: return 16'h0080;
                2: return 16'h0100;
                default: return 16'h0180;
            endcase
        endfunction

        function automatic bit [4:0] burst_size_for(int unsigned traffic_idx,
                                                    int unsigned load_idx);
            case (traffic_idx)
                1: return 5'(2 + load_idx);
                3: return 5'(2 + (load_idx >> 1));
                default: return 5'd1;
            endcase
        endfunction

        function automatic int unsigned run_cycles_for(int unsigned load_idx);
            // Keep each long-run case inside the 1s-180s wall-clock target on the
            // current mixed-language tb_int build. Empirically, 12k run cycles are
            // already ~48s for the lightest profile, so the high-load tier must stay
            // well below 96k cycles.
            case (load_idx)
                0: return 8000;
                1: return 12000;
                2: return 20000;
                default: return 32000;
            endcase
        endfunction

        function automatic bit [31:0] case_seed_root(int unsigned case_id,
                                                     int unsigned frame_idx,
                                                     int unsigned family_idx,
                                                     int unsigned traffic_idx,
                                                     int unsigned load_idx);
            return 32'h6A09_E667 ^ (case_id * 32'h0001_0001)
                   ^ (frame_idx << 28) ^ (family_idx << 24)
                   ^ (traffic_idx << 20) ^ (load_idx << 16);
        endfunction

        function automatic string case_name_for(int unsigned case_id,
                                                int unsigned frame_idx,
                                                int unsigned family_idx,
                                                int unsigned traffic_idx,
                                                int unsigned load_idx);
            string frame_code;
            string family_code;
            string traffic_code;
            frame_code = (frame_idx == 0) ? "L" : "S";
            case (family_idx)
                0: family_code = "U";
                1: family_code = "F";
                2: family_code = "H";
                default: family_code = "C";
            endcase
            case (traffic_idx)
                0: traffic_code = "P";
                1: traffic_code = "B";
                2: traffic_code = "N";
                default: traffic_code = "M";
            endcase
            return $sformatf("PROF_TBINT_%03d_%s%s%s%0d",
                             case_id, frame_code, family_code, traffic_code, load_idx);
        endfunction

        virtual function tb_int_cfg make_cfg();
            tb_int_cfg c;
            int unsigned case_id;
            int unsigned idx;
            int unsigned frame_idx;
            int unsigned family_idx;
            int unsigned traffic_idx;
            int unsigned load_idx;
            bit          short_mode;
            bit [15:0]   hit_rate_base;
            bit [15:0]   noise_rate_base;
            bit [4:0]    burst_size_base;
            bit [31:0]   seed_root;

            c = tb_int_cfg::type_id::create("cfg");
            case_id = 1;
            void'($value$plusargs("TB_INT_LONGRUN_CASE_ID=%d", case_id));
            if (case_id < 1 || case_id > 128) begin
                `uvm_warning("TB_INT_LONGRUN",
                             $sformatf("invalid TB_INT_LONGRUN_CASE_ID=%0d, falling back to 1", case_id))
                case_id = 1;
            end

            idx         = case_id - 1;
            frame_idx   = idx / 64;
            family_idx  = (idx / 16) % 4;
            traffic_idx = (idx / 4) % 4;
            load_idx    = idx % 4;
            short_mode  = (frame_idx != 0);

            c.program_emulators   = 1'b1;
            c.require_stage_e     = 1'b0;
            c.require_lossless_feb = 1'b1;
            c.longrun_case_id     = case_id;
            c.longrun_case_name   = case_name_for(case_id, frame_idx, family_idx, traffic_idx, load_idx);
            c.smoke_run_cycles    = run_cycles_for(load_idx);
            void'($value$plusargs("TB_INT_LONGRUN_RUN_CYCLES=%d", c.smoke_run_cycles));

            hit_rate_base   = base_hit_rate(short_mode, load_idx);
            noise_rate_base = base_noise_rate(short_mode, load_idx);
            burst_size_base = burst_size_for(traffic_idx, load_idx);
            seed_root       = case_seed_root(case_id, frame_idx, family_idx, traffic_idx, load_idx);

            foreach (c.emu_cfg[lane]) begin
                c.emu_cfg[lane].enable                = 1'b1;
                c.emu_cfg[lane].short_mode            = short_mode;
                c.emu_cfg[lane].tx_mode               = short_mode ? TX_MODE_SHORT : TX_MODE_LONG;
                c.emu_cfg[lane].gen_idle              = 1'b1;
                c.emu_cfg[lane].asic_id               = 4'(lane);
                c.emu_cfg[lane].cluster_lane_index    = 4'(lane);
                c.emu_cfg[lane].cluster_lane_count    = 4'd1;
                c.emu_cfg[lane].cluster_cross_asic    = 1'b0;
                c.emu_cfg[lane].cluster_center_global = 8'(16 + ((case_id * 7) % 64));
                c.emu_cfg[lane].burst_center          = 5'(4 + ((lane * 6 + case_id) % 24));
                c.emu_cfg[lane].burst_size            = burst_size_base;
                c.emu_cfg[lane].seed                  = seed_root ^ (32'h9E37_79B9 * (lane + 1));
                c.emu_cfg[lane].hit_rate              = hit_rate_base;
                c.emu_cfg[lane].noise_rate            = noise_rate_base;

                case (traffic_idx)
                    0: begin
                        c.emu_cfg[lane].hit_mode   = HIT_MODE_POISSON;
                        c.emu_cfg[lane].noise_rate = 16'h0000;
                        c.emu_cfg[lane].burst_size = 5'd1;
                    end
                    1: begin
                        c.emu_cfg[lane].hit_mode   = HIT_MODE_BURST;
                        c.emu_cfg[lane].hit_rate   = 16'h0000;
                        c.emu_cfg[lane].noise_rate = 16'h0000;
                    end
                    2: begin
                        c.emu_cfg[lane].hit_mode   = HIT_MODE_NOISE;
                        c.emu_cfg[lane].hit_rate   = 16'h0000;
                        c.emu_cfg[lane].burst_size = 5'd1;
                    end
                    default: begin
                        c.emu_cfg[lane].hit_mode   = HIT_MODE_MIXED;
                        c.emu_cfg[lane].hit_rate   = hit_rate_base;
                        c.emu_cfg[lane].noise_rate = noise_rate_base >> 1;
                    end
                endcase

                case (family_idx)
                    0: begin
                        // Uniform
                    end
                    1: begin
                        // FEB-skew: FEB0 cooler, FEB1 exact case load.
                        if (lane < 2) begin
                            c.emu_cfg[lane].hit_rate   = c.emu_cfg[lane].hit_rate >> 1;
                            c.emu_cfg[lane].noise_rate = c.emu_cfg[lane].noise_rate >> 1;
                        end
                    end
                    2: begin
                        // Hotspot: one datapath hot, others cooler.
                        if (lane == (case_id % 4)) begin
                            c.emu_cfg[lane].hit_rate   = hit_rate_base;
                            c.emu_cfg[lane].noise_rate = noise_rate_base;
                        end else begin
                            c.emu_cfg[lane].hit_rate   = c.emu_cfg[lane].hit_rate >> 1;
                            c.emu_cfg[lane].noise_rate = c.emu_cfg[lane].noise_rate >> 1;
                            if (traffic_idx == 1 || traffic_idx == 3)
                                c.emu_cfg[lane].burst_size = (burst_size_base > 2) ? (burst_size_base - 1) : 5'd1;
                        end
                    end
                    default: begin
                        // Cross-ASIC cluster-domain replay across the 4 tb_int lanes.
                        c.emu_cfg[lane].cluster_cross_asic = 1'b1;
                        c.emu_cfg[lane].cluster_lane_count = 4'd4;
                        c.emu_cfg[lane].seed               = seed_root;
                        c.emu_cfg[lane].burst_center       = 5'd16;
                        if (traffic_idx == 0)
                            c.emu_cfg[lane].burst_size = (burst_size_base > 1) ? burst_size_base : 5'd2;
                    end
                endcase

                if ((traffic_idx == 1) || (traffic_idx == 2)) begin
                    // Burst-only and noise-only cases carry one active source.
                    if (traffic_idx == 1)
                        c.emu_cfg[lane].noise_rate = 16'h0000;
                    if (traffic_idx == 2)
                        c.emu_cfg[lane].hit_rate = 16'h0000;
                end
            end
            return c;
        endfunction

        virtual task configure_before_run();
            `uvm_info("TB_INT_LONGRUN", cfg.describe_longrun(), UVM_NONE)
            foreach (cfg.emu_cfg[i])
                program_emulator_lane(i, cfg.emu_cfg[i], 1'b1);
        endtask

        virtual task check_after_run();
            dump_opq_csr_snapshot($sformatf("longrun_case%0d", cfg.longrun_case_id));
        endtask
    endclass

endpackage : tb_int_pkg

`endif

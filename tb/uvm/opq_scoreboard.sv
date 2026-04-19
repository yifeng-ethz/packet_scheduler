//------------------------------------------------------------------------------
// IP Name   : opq_scoreboard
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - add full absolute hit timestamp reconstruction
// Revision  : 0.2 - consume explicit full frame ts[15:0] from header word 2
// Revision  : 0.3 - reconstruct hits from frame ts[47:12] + absolute subheader ts[11:4]
// Description:
//   Scoreboard for ingress-to-egress hit integrity and CSR-visible packet counts.
//------------------------------------------------------------------------------
class opq_scoreboard extends uvm_component;
  `uvm_component_utils(opq_scoreboard)

  typedef struct {
    bit [63:0] hit_id;
    bit [47:0] hit_ts;
    bit [31:0] hit_word;
    int        lane_id;
    bit [7:0]  shd_ts;
  } opq_hit_trace_t;

  typedef struct {
    bit [47:0] frame_ts_full;
    bit [15:0] pkg_cnt;
    bit [15:0] subh_cnt;
    bit [15:0] hit_cnt;
    bit [31:0] data_header0;
    bit [31:0] data_header1;
    bit [31:0] debug_header0;
    bit [31:0] debug_header1;
  } opq_frame_meta_t;

  uvm_analysis_imp_frame #(opq_frame_item, opq_scoreboard) frame_imp;
  uvm_analysis_imp_ingress #(opq_beat_item, opq_scoreboard) ingress_imp;
  uvm_analysis_imp_egress #(opq_beat_item, opq_scoreboard) egress_imp;
  uvm_analysis_imp_drop #(opq_drop_item, opq_scoreboard) drop_imp;
  opq_scoreboard_cfg cfg;

  bit [47:0] ingress_frame_ts     [OPQ_N_LANE];
  bit [47:0] ingress_current_ts   [OPQ_N_LANE];
  bit [7:0]  ingress_current_shd  [OPQ_N_LANE];
  int        ingress_header_idx   [OPQ_N_LANE];
  int        ingress_hits_pending [OPQ_N_LANE];
  bit        ingress_ignore_hits_pending [OPQ_N_LANE];
  bit        ingress_have_frame_meta [OPQ_N_LANE];
  opq_frame_meta_t ingress_frame_meta [OPQ_N_LANE];

  bit        egress_in_packet;
  bit [47:0] egress_frame_ts;
  bit [47:0] egress_current_ts;
  bit [7:0]  egress_current_shd;
  int        egress_header_idx;
  int        egress_hits_pending;

  bit        egress_preamble_seen;
  int unsigned sop_count;
  int unsigned expected_lane_hdr_cnt[OPQ_N_LANE];
  int unsigned expected_lane_shd_cnt[OPQ_N_LANE];
  int unsigned expected_lane_hit_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_hdr_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_shd_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_hit_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_pre_shd_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_pre_hit_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_post_hdr_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_post_shd_cnt[OPQ_N_LANE];
  int unsigned dropped_lane_post_hit_cnt[OPQ_N_LANE];
  int unsigned actual_lane_hit_cnt[OPQ_N_LANE];
  int unsigned actual_egress_hdr_cnt;
  int unsigned actual_egress_shd_cnt;
  int unsigned actual_egress_hit_cnt;

  opq_hit_trace_t pending_ingress_hits[OPQ_N_LANE][$];
  opq_frame_meta_t pending_ingress_frames[OPQ_N_LANE][$];
  opq_hit_trace_t lane_accounting_hits[OPQ_N_LANE][$];
  opq_hit_trace_t expected_hits[$];
  opq_hit_trace_t actual_hits[$];
  bit dropped_hit_id[string];
  bit dropped_hit_sig[string];

  function new(string name = "opq_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    frame_imp = new("frame_imp", this);
    ingress_imp = new("ingress_imp", this);
    egress_imp = new("egress_imp", this);
    drop_imp = new("drop_imp", this);
  endfunction

  function automatic void reset_ingress_lane(int lane_id);
    ingress_frame_ts[lane_id] = '0;
    ingress_current_ts[lane_id] = '0;
    ingress_current_shd[lane_id] = '0;
    ingress_header_idx[lane_id] = -1;
    ingress_hits_pending[lane_id] = 0;
    ingress_ignore_hits_pending[lane_id] = 1'b0;
    ingress_have_frame_meta[lane_id] = 1'b0;
    ingress_frame_meta[lane_id] = '{default: '0};
  endfunction

  function automatic int unsigned accepted_frame_subh_count(opq_frame_item frame);
    int unsigned total_subh;

    total_subh = 0;
    foreach (frame.subheaders[i]) begin
      if (frame.subheaders[i].error_bits == '0) begin
        total_subh++;
      end
    end
    return total_subh;
  endfunction

  function automatic int unsigned accepted_frame_hit_count(opq_frame_item frame);
    int unsigned total_hits;

    total_hits = 0;
    foreach (frame.subheaders[i]) begin
      if (frame.subheaders[i].error_bits != '0) begin
        continue;
      end
      foreach (frame.subheaders[i].hits[j]) begin
        if (frame.subheaders[i].hits[j].error_bits == '0) begin
          total_hits++;
        end
      end
    end
    return total_hits;
  endfunction

  function automatic void reset_egress_state();
    egress_in_packet = 1'b0;
    egress_frame_ts = '0;
    egress_current_ts = '0;
    egress_current_shd = '0;
    egress_header_idx = -1;
    egress_hits_pending = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(opq_scoreboard_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = opq_scoreboard_cfg::type_id::create("cfg");
    end

    foreach (ingress_header_idx[i]) begin
      reset_ingress_lane(i);
    end
    reset_egress_state();
    egress_preamble_seen = 1'b0;
    sop_count = 0;
    foreach (expected_lane_hdr_cnt[i]) begin
      expected_lane_hdr_cnt[i] = 0;
      expected_lane_shd_cnt[i] = 0;
      expected_lane_hit_cnt[i] = 0;
      dropped_lane_hdr_cnt[i] = 0;
      dropped_lane_shd_cnt[i] = 0;
      dropped_lane_hit_cnt[i] = 0;
      dropped_lane_pre_shd_cnt[i] = 0;
      dropped_lane_pre_hit_cnt[i] = 0;
      dropped_lane_post_hdr_cnt[i] = 0;
      dropped_lane_post_shd_cnt[i] = 0;
      dropped_lane_post_hit_cnt[i] = 0;
      actual_lane_hit_cnt[i] = 0;
    end
    actual_egress_hdr_cnt = 0;
    actual_egress_shd_cnt = 0;
    actual_egress_hit_cnt = 0;
  endfunction

  function automatic string hit_key(bit [47:0] hit_ts, bit [31:0] hit_word);
    return $sformatf("%012h_%08h", hit_ts, hit_word);
  endfunction

  function automatic string hit_id_key(bit [63:0] hit_id);
    return $sformatf("%016h", hit_id);
  endfunction

  function automatic string hit_sig_key(int lane_id, bit [47:0] hit_ts, bit [31:0] hit_word);
    return $sformatf("%0d_%012h_%08h", lane_id, hit_ts, hit_word);
  endfunction

  function automatic bit [47:0] make_abs_hit_ts(bit [47:0] frame_ts, bit [7:0] shd_ts);
    return {frame_ts[47:12], shd_ts, 4'b0000};
  endfunction

  function automatic bit [47:0] make_egress_hit_ts(bit [47:0] frame_ts, bit [7:0] shd_ts_abs_low8);
    return {frame_ts[47:12], shd_ts_abs_low8, 4'b0000};
  endfunction

  function automatic void push_actual_hit(bit [31:0] hit_word);
    opq_hit_trace_t trace;

    trace.hit_id = '0;
    trace.hit_ts = egress_current_ts;
    trace.hit_word = hit_word;
    trace.lane_id = -1;
    trace.shd_ts = egress_current_shd;
    actual_hits.push_back(trace);
  endfunction

  function automatic int retire_actual_from_lane_accounting(bit [47:0] hit_ts, bit [31:0] hit_word);
    string key;

    key = hit_key(hit_ts, hit_word);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      for (int idx = 0; idx < lane_accounting_hits[lane].size(); idx++) begin
        if (hit_key(lane_accounting_hits[lane][idx].hit_ts, lane_accounting_hits[lane][idx].hit_word) == key) begin
          lane_accounting_hits[lane].delete(idx);
          return lane;
        end
      end
    end
    return -1;
  endfunction

  function automatic void retire_lane_accounting_trace(
    int         lane_id,
    bit [47:0]  hit_ts,
    bit [31:0]  hit_word
  );
    string key;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return;
    end

    key = hit_key(hit_ts, hit_word);
    for (int idx = 0; idx < lane_accounting_hits[lane_id].size(); idx++) begin
      if (hit_key(lane_accounting_hits[lane_id][idx].hit_ts, lane_accounting_hits[lane_id][idx].hit_word) == key) begin
        lane_accounting_hits[lane_id].delete(idx);
        break;
      end
    end
  endfunction

  function void write_frame(opq_frame_item frame);
    opq_frame_meta_t meta;
    opq_hit_trace_t trace;
    int unsigned accepted_subh_cnt;
    int unsigned accepted_hit_cnt;

    if (frame.lane_id < 0 || frame.lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Frame contract arrived with invalid lane_id=%0d", frame.lane_id))
      return;
    end

    meta.frame_ts_full = frame.frame_ts;
    meta.pkg_cnt = frame.pkg_cnt;
    meta.subh_cnt = frame.frame_subh_count_bits();
    meta.hit_cnt = frame.frame_hit_count_bits();
    meta.data_header0 = make_frame_data_header0(frame.frame_ts);
    meta.data_header1 = make_frame_data_header1(frame.frame_ts, frame.pkg_cnt);
    meta.debug_header0 = make_frame_debug_header0(frame.frame_subh_count_bits(), frame.frame_hit_count_bits());
    meta.debug_header1 = make_frame_debug_header1(frame.frame_ts);
    pending_ingress_frames[frame.lane_id].push_back(meta);

    accepted_subh_cnt = accepted_frame_subh_count(frame);
    accepted_hit_cnt = accepted_frame_hit_count(frame);
    expected_lane_hdr_cnt[frame.lane_id]++;
    expected_lane_shd_cnt[frame.lane_id] += accepted_subh_cnt;
    expected_lane_hit_cnt[frame.lane_id] += accepted_hit_cnt;

    foreach (frame.subheaders[i]) begin
      foreach (frame.subheaders[i].hits[j]) begin
        trace.hit_id = frame.subheaders[i].hits[j].debug_hit_id;
        trace.hit_ts = make_abs_hit_ts(frame.frame_ts, frame.subheaders[i].shd_ts);
        trace.hit_word = frame.subheaders[i].hits[j].payload_word;
        trace.lane_id = frame.lane_id;
        trace.shd_ts = frame.subheaders[i].shd_ts;
        pending_ingress_hits[frame.lane_id].push_back(trace);
        if (cfg.allow_drop_accounting &&
            frame.subheaders[i].error_bits == '0 &&
            frame.subheaders[i].hits[j].error_bits == '0) begin
          lane_accounting_hits[frame.lane_id].push_back(trace);
        end
      end
    end
  endfunction

  function void write_ingress(opq_beat_item beat);
    bit [3:0] datak;
    bit [31:0] data32;
    int lane_id;

    lane_id = beat.lane_id;
    datak = beat.data[35:32];
    data32 = beat.data[31:0];

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Ingress beat arrived with invalid lane_id=%0d", lane_id))
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K285 && beat.sop) begin
      if (pending_ingress_frames[lane_id].size() == 0) begin
        if (!cfg.allow_unmatched_ingress_preamble) begin
          `uvm_error(get_type_name(), $sformatf(
            "Ingress lane %0d observed frame preamble without queued frame metadata",
            lane_id
          ))
        end
        ingress_have_frame_meta[lane_id] = 1'b0;
      end else begin
        ingress_frame_meta[lane_id] = pending_ingress_frames[lane_id].pop_front();
        ingress_have_frame_meta[lane_id] = 1'b1;
        ingress_frame_ts[lane_id] = ingress_frame_meta[lane_id].frame_ts_full;
      end
      ingress_header_idx[lane_id] = 0;
      ingress_hits_pending[lane_id] = 0;
      ingress_ignore_hits_pending[lane_id] = 1'b0;
      return;
    end

    if (ingress_header_idx[lane_id] >= 0) begin
      case (ingress_header_idx[lane_id])
        0: begin
          if (cfg.check_feb_contract && ingress_have_frame_meta[lane_id] &&
              data32 != ingress_frame_meta[lane_id].data_header0) begin
            `uvm_error(get_type_name(), $sformatf(
              "Ingress lane %0d data_header0 mismatch expected=0x%08h got=0x%08h",
              lane_id, ingress_frame_meta[lane_id].data_header0, data32
            ))
          end
        end
        1: begin
          if (cfg.check_feb_contract && ingress_have_frame_meta[lane_id] &&
              data32 != ingress_frame_meta[lane_id].data_header1) begin
            `uvm_error(get_type_name(), $sformatf(
              "Ingress lane %0d data_header1 mismatch expected=0x%08h got=0x%08h",
              lane_id, ingress_frame_meta[lane_id].data_header1, data32
            ))
          end
        end
        2: begin
          if (cfg.check_feb_contract && ingress_have_frame_meta[lane_id] &&
              data32 != ingress_frame_meta[lane_id].debug_header0) begin
            `uvm_error(get_type_name(), $sformatf(
              "Ingress lane %0d debug_header0 mismatch expected=0x%08h got=0x%08h",
              lane_id, ingress_frame_meta[lane_id].debug_header0, data32
            ))
          end
        end
        3: begin
          if (cfg.check_feb_contract && ingress_have_frame_meta[lane_id] &&
              data32 != ingress_frame_meta[lane_id].debug_header1) begin
            `uvm_error(get_type_name(), $sformatf(
              "Ingress lane %0d debug_header1 mismatch expected=0x%08h got=0x%08h",
              lane_id, ingress_frame_meta[lane_id].debug_header1, data32
            ))
          end
        end
        default: begin
        end
      endcase

      if (ingress_header_idx[lane_id] == 3) begin
        ingress_header_idx[lane_id] = -1;
        ingress_have_frame_meta[lane_id] = 1'b0;
      end else begin
        ingress_header_idx[lane_id]++;
      end
      return;
    end

    if (ingress_hits_pending[lane_id] > 0) begin
      if (datak != 4'b0000) begin
        `uvm_error(get_type_name(), $sformatf(
          "Ingress lane %0d expected hit payload, got datak=0x%1h data=0x%08h",
          lane_id, datak, data32
        ))
      end else begin
        opq_hit_trace_t trace;
        bit drop_hit_from_integrity;

        drop_hit_from_integrity = ingress_ignore_hits_pending[lane_id] || beat.error[0];
        if (pending_ingress_hits[lane_id].size() == 0) begin
          `uvm_error(get_type_name(), $sformatf(
            "Ingress lane %0d observed hit ts=0x%012h word=0x%08h without queued debug HIT_ID",
            lane_id, ingress_current_ts[lane_id], data32
          ))
          trace.hit_id = '0;
          trace.hit_ts = ingress_current_ts[lane_id];
          trace.hit_word = data32;
          trace.lane_id = lane_id;
          trace.shd_ts = ingress_current_shd[lane_id];
        end else begin
          trace = pending_ingress_hits[lane_id].pop_front();
          if (!drop_hit_from_integrity &&
              (trace.hit_word != data32 ||
               trace.hit_ts != ingress_current_ts[lane_id] ||
               trace.shd_ts != ingress_current_shd[lane_id])) begin
            `uvm_error(get_type_name(), $sformatf(
              "Ingress contract mismatch hit_id=0x%016h lane=%0d exp_ts=0x%012h got_ts=0x%012h exp_word=0x%08h got_word=0x%08h exp_shd=0x%02h got_shd=0x%02h",
              trace.hit_id, lane_id, trace.hit_ts, ingress_current_ts[lane_id],
              trace.hit_word, data32, trace.shd_ts, ingress_current_shd[lane_id]
            ))
          end
          trace.hit_ts = ingress_current_ts[lane_id];
          trace.hit_word = data32;
          trace.shd_ts = ingress_current_shd[lane_id];
        end
        if (!drop_hit_from_integrity) begin
          expected_hits.push_back(trace);
        end else if (cfg.allow_drop_accounting) begin
          retire_lane_accounting_trace(lane_id, trace.hit_ts, trace.hit_word);
        end
      end
      ingress_hits_pending[lane_id]--;
      if (ingress_hits_pending[lane_id] == 0) begin
        ingress_ignore_hits_pending[lane_id] = 1'b0;
      end
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K237) begin
      ingress_current_shd[lane_id] = data32[31:24];
      ingress_current_ts[lane_id] = make_abs_hit_ts(ingress_frame_ts[lane_id], data32[31:24]);
      ingress_hits_pending[lane_id] = data32[15:8];
      ingress_ignore_hits_pending[lane_id] = beat.error[1];
    end
  endfunction

  function void write_egress(opq_beat_item beat);
    bit [3:0] datak;
    bit [31:0] data32;
    int matched_lane;

    datak = beat.data[35:32];
    data32 = beat.data[31:0];

    if (beat.sop) begin
      sop_count++;
    end

    if (!egress_in_packet) begin
      egress_in_packet = 1'b1;
      egress_header_idx = 0;
      egress_hits_pending = 0;
    end

    if (egress_header_idx >= 0) begin
      case (egress_header_idx)
        0: begin
          if (datak == 4'b0001 && data32[7:0] == K285) begin
            egress_preamble_seen = 1'b1;
            actual_egress_hdr_cnt++;
          end
        end
        1: egress_frame_ts[47:16] = data32;
        2: egress_frame_ts[15:0] = data32[31:16];
        default: begin
        end
      endcase

      if (egress_header_idx == 4) begin
        egress_header_idx = -1;
      end else begin
        egress_header_idx++;
      end
      return;
    end

    if (egress_hits_pending > 0) begin
      if (datak != 4'b0000) begin
        `uvm_error(get_type_name(), $sformatf(
          "Egress expected hit payload, got datak=0x%1h data=0x%08h",
          datak, data32
        ))
      end else begin
        push_actual_hit(data32);
        matched_lane = retire_actual_from_lane_accounting(egress_current_ts, data32);
        if ((matched_lane >= 0) && (matched_lane < OPQ_N_LANE)) begin
          actual_lane_hit_cnt[matched_lane]++;
        end
        actual_egress_hit_cnt++;
      end
      egress_hits_pending--;
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K237) begin
      egress_current_shd = data32[31:24];
      egress_current_ts = make_egress_hit_ts(egress_frame_ts, data32[31:24]);
      egress_hits_pending = data32[15:8];
      actual_egress_shd_cnt++;
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K284) begin
      reset_egress_state();
      return;
    end
  endfunction

  function void write_drop(opq_drop_item item);
    int unsigned exact_post_shd_delta;
    int unsigned exact_post_hit_delta;
    int unsigned residual_shd_delta;
    int unsigned residual_hit_delta;

    if (item.lane_id < 0 || item.lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Drop item arrived with invalid lane_id=%0d", item.lane_id))
      return;
    end

    exact_post_shd_delta = 0;
    exact_post_hit_delta = 0;
    if (item.exact_post_valid) begin
      exact_post_shd_delta = item.exact_post_shd_cnt;
      exact_post_hit_delta = item.exact_post_hit_cnt;
      if ((exact_post_shd_delta > item.post_shd_drop_cnt) ||
          (exact_post_hit_delta > item.post_hit_drop_cnt) ||
          (exact_post_shd_delta > item.shd_drop_cnt) ||
          (exact_post_hit_delta > item.hit_drop_cnt)) begin
        `uvm_error(get_type_name(), $sformatf(
          "Exact post-drop detail exceeded event totals lane=%0d exact_shd=%0d exact_hit=%0d total_shd=%0d total_hit=%0d post_shd=%0d post_hit=%0d",
          item.lane_id,
          exact_post_shd_delta,
          exact_post_hit_delta,
          item.shd_drop_cnt,
          item.hit_drop_cnt,
          item.post_shd_drop_cnt,
          item.post_hit_drop_cnt
        ))
        exact_post_shd_delta = 0;
        exact_post_hit_delta = 0;
      end
    end

    residual_shd_delta = item.shd_drop_cnt - exact_post_shd_delta;
    residual_hit_delta = item.hit_drop_cnt - exact_post_hit_delta;

    dropped_lane_hdr_cnt[item.lane_id] += item.hdr_drop_cnt;
    dropped_lane_pre_shd_cnt[item.lane_id] += item.pre_shd_drop_cnt;
    dropped_lane_pre_hit_cnt[item.lane_id] += item.pre_hit_drop_cnt;
    dropped_lane_post_hdr_cnt[item.lane_id] += item.post_hdr_drop_cnt;
    dropped_lane_post_shd_cnt[item.lane_id] += item.post_shd_drop_cnt;
    dropped_lane_post_hit_cnt[item.lane_id] += item.post_hit_drop_cnt;
    if (exact_post_hit_delta != 0) begin
      apply_exact_drop_delta(
        item.lane_id,
        item.exact_post_ts,
        exact_post_shd_delta,
        exact_post_hit_delta,
        "monitor_exact_post"
      );
    end
    apply_drop_delta(item.lane_id, residual_shd_delta, residual_hit_delta, "monitor");
  endfunction

  function void verify_lane_drop_totals(
    int lane_id,
    int unsigned hdr_drop_total,
    int unsigned shd_drop_total,
    int unsigned hit_drop_total
  );
    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Drop total check arrived with invalid lane_id=%0d", lane_id))
      return;
    end

    if (hdr_drop_total != dropped_lane_hdr_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Drop hdr total mismatch lane=%0d expected=%0d actual=%0d",
        lane_id,
        dropped_lane_hdr_cnt[lane_id],
        hdr_drop_total
      ))
    end
    if (shd_drop_total != dropped_lane_shd_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Drop shd total mismatch lane=%0d expected=%0d actual=%0d",
        lane_id,
        dropped_lane_shd_cnt[lane_id],
        shd_drop_total
      ))
    end
    if (hit_drop_total != dropped_lane_hit_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Drop hit total mismatch lane=%0d expected=%0d actual=%0d",
        lane_id,
        dropped_lane_hit_cnt[lane_id],
        hit_drop_total
      ))
    end
  endfunction

  function void apply_drop_delta(
    int lane_id,
    int unsigned shd_drop_delta,
    int unsigned hit_drop_delta,
    string source
  );
    opq_hit_trace_t trace;
    int unsigned hit_cnt;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Drop accounting arrived with invalid lane_id=%0d from %s", lane_id, source))
      return;
    end

    dropped_lane_shd_cnt[lane_id] += shd_drop_delta;
    dropped_lane_hit_cnt[lane_id] += hit_drop_delta;

    if (dropped_lane_shd_cnt[lane_id] > expected_lane_shd_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Dropped subheader count exceeded expected traffic lane=%0d dropped=%0d expected=%0d source=%s",
        lane_id,
        dropped_lane_shd_cnt[lane_id],
        expected_lane_shd_cnt[lane_id],
        source
      ))
    end
    if (dropped_lane_hit_cnt[lane_id] > expected_lane_hit_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Dropped hit count exceeded expected traffic lane=%0d dropped=%0d expected=%0d source=%s",
        lane_id,
        dropped_lane_hit_cnt[lane_id],
        expected_lane_hit_cnt[lane_id],
        source
      ))
    end

    if (!cfg.allow_drop_accounting) begin
      return;
    end

    hit_cnt = hit_drop_delta;
    while (hit_cnt > 0) begin
      if (lane_accounting_hits[lane_id].size() == 0) begin
        `uvm_error(get_type_name(), $sformatf(
          "Drop accounting underrun lane=%0d shd_drop=%0d hit_drop=%0d source=%s",
          lane_id, shd_drop_delta, hit_drop_delta, source
        ))
        break;
      end
      trace = lane_accounting_hits[lane_id].pop_front();
      dropped_hit_id[hit_id_key(trace.hit_id)] = 1'b1;
      dropped_hit_sig[hit_sig_key(trace.lane_id, trace.hit_ts, trace.hit_word)] = 1'b1;
      hit_cnt--;
    end
  endfunction

  function void apply_exact_drop_delta(
    int         lane_id,
    bit [47:0]  hit_ts,
    int unsigned shd_drop_delta,
    int unsigned hit_drop_delta,
    string      source
  );
    opq_hit_trace_t trace;
    int unsigned hit_cnt;
    int idx;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Exact drop accounting arrived with invalid lane_id=%0d from %s", lane_id, source))
      return;
    end

    dropped_lane_shd_cnt[lane_id] += shd_drop_delta;
    dropped_lane_hit_cnt[lane_id] += hit_drop_delta;

    if (dropped_lane_shd_cnt[lane_id] > expected_lane_shd_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Exact dropped subheader count exceeded expected traffic lane=%0d dropped=%0d expected=%0d source=%s",
        lane_id,
        dropped_lane_shd_cnt[lane_id],
        expected_lane_shd_cnt[lane_id],
        source
      ))
    end
    if (dropped_lane_hit_cnt[lane_id] > expected_lane_hit_cnt[lane_id]) begin
      `uvm_error(get_type_name(), $sformatf(
        "Exact dropped hit count exceeded expected traffic lane=%0d dropped=%0d expected=%0d source=%s",
        lane_id,
        dropped_lane_hit_cnt[lane_id],
        expected_lane_hit_cnt[lane_id],
        source
      ))
    end

    if (!cfg.allow_drop_accounting) begin
      return;
    end

    hit_cnt = hit_drop_delta;
    idx = 0;
    while ((idx < lane_accounting_hits[lane_id].size()) && (hit_cnt > 0)) begin
      if (lane_accounting_hits[lane_id][idx].hit_ts == hit_ts) begin
        trace = lane_accounting_hits[lane_id][idx];
        lane_accounting_hits[lane_id].delete(idx);
        dropped_hit_id[hit_id_key(trace.hit_id)] = 1'b1;
        dropped_hit_sig[hit_sig_key(trace.lane_id, trace.hit_ts, trace.hit_word)] = 1'b1;
        hit_cnt--;
      end else begin
        idx++;
      end
    end

    if (hit_cnt != 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Exact drop accounting mismatch lane=%0d ts=0x%012h expected_hits=%0d missing_hits=%0d source=%s",
        lane_id, hit_ts, hit_drop_delta, hit_cnt, source
      ))
    end
  endfunction

  function void apply_lane_drop_totals(
    int lane_id,
    int unsigned shd_drop_total,
    int unsigned hit_drop_total
  );
    int unsigned shd_drop_delta;
    int unsigned hit_drop_delta;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Drop total sync arrived with invalid lane_id=%0d", lane_id))
      return;
    end

    if ((shd_drop_total < dropped_lane_shd_cnt[lane_id]) ||
        (hit_drop_total < dropped_lane_hit_cnt[lane_id])) begin
      `uvm_error(get_type_name(), $sformatf(
        "Drop total sync regressed lane=%0d shd_total=%0d hit_total=%0d current_shd=%0d current_hit=%0d",
        lane_id,
        shd_drop_total,
        hit_drop_total,
        dropped_lane_shd_cnt[lane_id],
        dropped_lane_hit_cnt[lane_id]
      ))
      return;
    end

    shd_drop_delta = shd_drop_total - dropped_lane_shd_cnt[lane_id];
    hit_drop_delta = hit_drop_total - dropped_lane_hit_cnt[lane_id];
    apply_drop_delta(lane_id, shd_drop_delta, hit_drop_delta, "csr_total");
  endfunction

  function void check_phase(uvm_phase phase);
    int actual_key_count[string];
    string key;
    string drop_key;
    int compare_expected_hits;
    int missing_hits;
    int ghost_hits;

    super.check_phase(phase);

    if (cfg.require_egress_preamble && !egress_preamble_seen) begin
      `uvm_error(get_type_name(), "No egress preamble (K285) observed")
    end
    if (sop_count < cfg.min_sop_count) begin
      `uvm_error(get_type_name(), $sformatf(
        "Expected at least %0d egress SOP beats, saw %0d",
        cfg.min_sop_count, sop_count
      ))
    end
    if (!cfg.check_hit_integrity) begin
      return;
    end

    foreach (pending_ingress_hits[i]) begin
      if (pending_ingress_hits[i].size() != 0) begin
        `uvm_error(get_type_name(), $sformatf(
          "Lane %0d still has %0d queued debug HIT_ID entries that never reached ingress",
          i, pending_ingress_hits[i].size()
        ))
      end
      if (pending_ingress_frames[i].size() != 0) begin
        `uvm_error(get_type_name(), $sformatf(
          "Lane %0d still has %0d queued frame metadata entries that never reached ingress",
          i, pending_ingress_frames[i].size()
        ))
      end
    end

    foreach (actual_hits[i]) begin
      key = hit_key(actual_hits[i].hit_ts, actual_hits[i].hit_word);
      if (!actual_key_count.exists(key)) begin
        actual_key_count[key] = 0;
      end
      actual_key_count[key]++;
    end

    missing_hits = 0;
    compare_expected_hits = 0;
    foreach (expected_hits[i]) begin
      drop_key = hit_id_key(expected_hits[i].hit_id);
      if (cfg.allow_drop_accounting &&
          (dropped_hit_id.exists(drop_key) ||
           dropped_hit_sig.exists(hit_sig_key(
             expected_hits[i].lane_id,
             expected_hits[i].hit_ts,
             expected_hits[i].hit_word
           )))) begin
        continue;
      end
      compare_expected_hits++;
      key = hit_key(expected_hits[i].hit_ts, expected_hits[i].hit_word);
      if (actual_key_count.exists(key) && actual_key_count[key] > 0) begin
        actual_key_count[key]--;
      end else begin
        missing_hits++;
        `uvm_error(get_type_name(), $sformatf(
          "Missing hit_id=0x%016h lane=%0d ts=0x%012h shd_ts=0x%02h word=0x%08h",
          expected_hits[i].hit_id,
          expected_hits[i].lane_id,
          expected_hits[i].hit_ts,
          expected_hits[i].shd_ts,
          expected_hits[i].hit_word
        ))
      end
    end

    ghost_hits = 0;
    foreach (actual_hits[i]) begin
      key = hit_key(actual_hits[i].hit_ts, actual_hits[i].hit_word);
      if (actual_key_count.exists(key) && actual_key_count[key] > 0) begin
        ghost_hits++;
        actual_key_count[key]--;
        `uvm_error(get_type_name(), $sformatf(
          "Ghost hit ts=0x%012h shd_ts=0x%02h word=0x%08h",
          actual_hits[i].hit_ts,
          actual_hits[i].shd_ts,
          actual_hits[i].hit_word
        ))
      end
    end

    `uvm_info(get_type_name(), $sformatf(
      "Hit integrity summary: expected=%0d actual=%0d missing=%0d ghost=%0d",
      compare_expected_hits, actual_hits.size(), missing_hits, ghost_hits
    ), UVM_LOW)
    foreach (expected_lane_hit_cnt[i]) begin
      `uvm_info(get_type_name(), $sformatf(
        "lane%0d hit ledger: accepted=%0d dropped=%0d pre_drop=%0d post_drop=%0d delivered=%0d unexplained=%0d",
        i,
        get_accepted_lane_hit_cnt(i),
        get_dropped_lane_hit_cnt(i),
        get_pre_dropped_lane_hit_cnt(i),
        get_post_dropped_lane_hit_cnt(i),
        get_actual_lane_hit_cnt(i),
        get_unexplained_lane_hit_cnt(i)
      ), UVM_LOW)
    end
  endfunction

  function automatic int unsigned get_expected_lane_hdr_cnt(int lane_id);
    return expected_lane_hdr_cnt[lane_id];
  endfunction

  function automatic int unsigned get_expected_lane_shd_cnt(int lane_id);
    return expected_lane_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_expected_lane_hit_cnt(int lane_id);
    return expected_lane_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_dropped_lane_shd_cnt(int lane_id);
    return dropped_lane_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_dropped_lane_hit_cnt(int lane_id);
    return dropped_lane_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_dropped_lane_hdr_cnt(int lane_id);
    return dropped_lane_hdr_cnt[lane_id];
  endfunction

  function automatic int unsigned get_pre_dropped_lane_shd_cnt(int lane_id);
    return dropped_lane_pre_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_pre_dropped_lane_hit_cnt(int lane_id);
    return dropped_lane_pre_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_post_dropped_lane_hdr_cnt(int lane_id);
    return dropped_lane_post_hdr_cnt[lane_id];
  endfunction

  function automatic int unsigned get_post_dropped_lane_shd_cnt(int lane_id);
    return dropped_lane_post_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_post_dropped_lane_hit_cnt(int lane_id);
    return dropped_lane_post_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_accepted_lane_shd_cnt(int lane_id);
    if (dropped_lane_shd_cnt[lane_id] > expected_lane_shd_cnt[lane_id]) begin
      return 0;
    end
    return expected_lane_shd_cnt[lane_id] - dropped_lane_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_accepted_lane_hit_cnt(int lane_id);
    if (dropped_lane_hit_cnt[lane_id] > expected_lane_hit_cnt[lane_id]) begin
      return 0;
    end
    return expected_lane_hit_cnt[lane_id] - dropped_lane_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_ingress_visible_lane_hdr_cnt(int lane_id);
    return expected_lane_hdr_cnt[lane_id];
  endfunction

  function automatic int unsigned get_ingress_visible_lane_shd_cnt(int lane_id);
    if (dropped_lane_pre_shd_cnt[lane_id] > expected_lane_shd_cnt[lane_id]) begin
      return 0;
    end
    return expected_lane_shd_cnt[lane_id] - dropped_lane_pre_shd_cnt[lane_id];
  endfunction

  function automatic int unsigned get_ingress_visible_lane_hit_cnt(int lane_id);
    if (dropped_lane_pre_hit_cnt[lane_id] > expected_lane_hit_cnt[lane_id]) begin
      return 0;
    end
    return expected_lane_hit_cnt[lane_id] - dropped_lane_pre_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_actual_lane_hit_cnt(int lane_id);
    return actual_lane_hit_cnt[lane_id];
  endfunction

  function automatic int unsigned get_unexplained_lane_hit_cnt(int lane_id);
    return lane_accounting_hits[lane_id].size();
  endfunction

  function automatic int unsigned get_actual_egress_hdr_cnt();
    return actual_egress_hdr_cnt;
  endfunction

  function automatic int unsigned get_actual_egress_shd_cnt();
    return actual_egress_shd_cnt;
  endfunction

  function automatic int unsigned get_actual_egress_hit_cnt();
    return actual_egress_hit_cnt;
  endfunction
endclass

//------------------------------------------------------------------------------
// IP Name   : opq_scoreboard
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - add full absolute hit timestamp reconstruction
// Revision  : 0.2 - consume explicit full frame ts[15:0] from header word 2
// Revision  : 0.3 - reconstruct hits from frame ts[47:12] + absolute subheader ts[11:4]
// Revision  : 0.4 - mirror parser subheader wrap extension for hit/drop timestamps
// Revision  : 0.5 - disambiguate exact drop accounting with frame pkg_cnt/serial
// Revision  : 0.6 - allow unique ts/word lane-accounting fallback when merged no-restart egress reserializes packet ids
// Revision  : 0.7 - keep canonical hit timestamps for delivery matching and parser timestamps for exact-drop bookkeeping
// Revision  : 0.8 - trace canonical-domain residency proxy separately from ingress debug timestamp semantics
// Description:
//   Scoreboard for ingress-to-egress hit integrity and CSR-visible packet counts.
//------------------------------------------------------------------------------
class opq_scoreboard extends uvm_component;
  `uvm_component_utils(opq_scoreboard)

  typedef struct {
    bit [63:0] hit_id;
    bit [15:0] pkg_cnt;
    bit [47:0] hit_ts;
    bit [47:0] accounting_hit_ts;
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

  typedef struct {
    bit [15:0]   pkg_cnt;
    bit [47:0]   hit_ts;
    int unsigned shd_drop_delta;
    int unsigned hit_drop_delta;
  } opq_pending_exact_drop_t;

  typedef struct {
    bit [47:0] frame_ts_full;
    bit [15:0] pkg_cnt;
    bit [30:0] proxy_ingress_ts;
    bit [30:0] ingress_debug_ts;
  } opq_stay_frame_t;

  uvm_analysis_imp_frame #(opq_frame_item, opq_scoreboard) frame_imp;
  uvm_analysis_imp_ingress #(opq_beat_item, opq_scoreboard) ingress_imp;
  uvm_analysis_imp_egress #(opq_beat_item, opq_scoreboard) egress_imp;
  uvm_analysis_imp_drop #(opq_drop_item, opq_scoreboard) drop_imp;
  opq_scoreboard_cfg cfg;

  bit [47:0] ingress_frame_ts     [OPQ_N_LANE];
  bit [47:0] ingress_current_ts   [OPQ_N_LANE];
  bit [47:0] ingress_accounting_ts[OPQ_N_LANE];
  bit [7:0]  ingress_current_shd  [OPQ_N_LANE];
  bit [15:0] ingress_frame_subh_cnt[OPQ_N_LANE];
  bit [15:0] ingress_frame_hit_cnt[OPQ_N_LANE];
  bit [15:0] ingress_current_pkg_cnt[OPQ_N_LANE];
  bit        ingress_subheaders_seen [OPQ_N_LANE];
  int        ingress_header_idx   [OPQ_N_LANE];
  int        ingress_hits_pending [OPQ_N_LANE];
  bit        ingress_ignore_hits_pending [OPQ_N_LANE];
  bit        ingress_have_frame_meta [OPQ_N_LANE];
  int unsigned ingress_observed_subh_cnt[OPQ_N_LANE];
  int unsigned ingress_observed_hit_cnt [OPQ_N_LANE];
  opq_frame_meta_t ingress_frame_meta [OPQ_N_LANE];

  bit        egress_in_packet;
  bit [47:0] egress_frame_ts;
  bit [15:0] egress_pkg_cnt;
  bit [30:0] egress_debug_ts;
  bit [47:0] egress_current_ts;
  bit [7:0]  egress_current_shd;
  bit        egress_subheaders_seen;
  int        egress_header_idx;
  int        egress_hits_pending;
  bit        enable_stay_time_trace;
  bit        enable_txn_trace;

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
  opq_stay_frame_t pending_stay_frames[OPQ_N_LANE][$];
  opq_hit_trace_t lane_accounting_hits[OPQ_N_LANE][$];
  opq_pending_exact_drop_t pending_exact_drops[OPQ_N_LANE][$];
  opq_hit_trace_t expected_hits[$];
  opq_hit_trace_t actual_hits[$];
  bit dropped_hit_id[string];
  bit dropped_hit_sig[string];
  int unsigned stay_sample_count[OPQ_N_LANE];

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
    ingress_accounting_ts[lane_id] = '0;
    ingress_current_shd[lane_id] = '0;
    ingress_frame_subh_cnt[lane_id] = '0;
    ingress_frame_hit_cnt[lane_id] = '0;
    ingress_current_pkg_cnt[lane_id] = '0;
    ingress_subheaders_seen[lane_id] = 1'b0;
    ingress_header_idx[lane_id] = -1;
    ingress_hits_pending[lane_id] = 0;
    ingress_ignore_hits_pending[lane_id] = 1'b0;
    ingress_have_frame_meta[lane_id] = 1'b0;
    ingress_observed_subh_cnt[lane_id] = 0;
    ingress_observed_hit_cnt[lane_id] = 0;
    ingress_frame_meta[lane_id] = '{default: '0};
  endfunction

  function automatic void strict_packet_error(
    string       what,
    opq_beat_item beat
  );
    if (!cfg.strict_packet_format) begin
      return;
    end
    `uvm_error(get_type_name(), $sformatf(
      "%s data=0x%09h datak=0x%1h sop=%0b eop=%0b err=0x%0h",
      what, beat.data, beat.data[35:32], beat.sop, beat.eop, beat.error
    ))
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
    egress_pkg_cnt = '0;
    egress_debug_ts = '0;
    egress_current_ts = '0;
    egress_current_shd = '0;
    egress_subheaders_seen = 1'b0;
    egress_header_idx = -1;
    egress_hits_pending = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(opq_scoreboard_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = opq_scoreboard_cfg::type_id::create("cfg");
    end
    enable_stay_time_trace = $test$plusargs("OPQ_STAY_TRACE");
    enable_txn_trace = $test$plusargs("OPQ_TRACE_TXN");

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
      stay_sample_count[i] = 0;
    end
    actual_egress_hdr_cnt = 0;
    actual_egress_shd_cnt = 0;
    actual_egress_hit_cnt = 0;
  endfunction

  function automatic string hit_key(bit [15:0] pkg_cnt, bit [47:0] hit_ts, bit [31:0] hit_word);
    return $sformatf("%04h_%012h_%08h", pkg_cnt, hit_ts, hit_word);
  endfunction

  function automatic string hit_id_key(bit [63:0] hit_id);
    return $sformatf("%016h", hit_id);
  endfunction

  function automatic string hit_sig_key(
    int        lane_id,
    bit [15:0] pkg_cnt,
    bit [47:0] hit_ts,
    bit [31:0] hit_word
  );
    return $sformatf("%0d_%04h_%012h_%08h", lane_id, pkg_cnt, hit_ts, hit_word);
  endfunction

  function automatic void emit_txn_trace(string event_name, opq_hit_trace_t trace);
    if (!enable_txn_trace) begin
      return;
    end
    $display("OPQ_TXN event=%s lane=%0d hit_id=0x%016h pkg_cnt=%0d bucket=%0d:0x%02h hit_ts=0x%012h accounting_ts=0x%012h word=0x%08h cycle=%0d time=%0t",
      event_name,
      trace.lane_id,
      trace.hit_id,
      trace.pkg_cnt,
      trace.pkg_cnt,
      trace.shd_ts,
      trace.hit_ts,
      trace.accounting_hit_ts,
      trace.hit_word,
      int'($time / 4),
      $time
    );
  endfunction

  function automatic bit [47:0] make_abs_hit_ts(bit [47:0] frame_ts, bit [7:0] shd_ts);
    return {frame_ts[47:12], shd_ts, 4'b0000};
  endfunction

  function automatic bit [47:0] extend_subheader_ts(
    bit [47:0] last_running_ts,
    bit        seen_prior_subheader,
    bit [7:0]  curr_subheader_byte
  );
    bit [47:0] ts_v;

    ts_v = {last_running_ts[47:12], curr_subheader_byte, 4'b0000};
    if (seen_prior_subheader && (curr_subheader_byte < last_running_ts[11:4])) begin
      ts_v[47:12] = last_running_ts[47:12] + 36'd1;
    end
    return ts_v;
  endfunction

  function automatic bit [47:0] extend_parser_running_ts(
    bit [47:0]   last_running_ts,
    bit [15:0]   frame_subheader_count,
    bit [7:0]    curr_subheader_byte
  );
    bit [47:0] ts_v;

    ts_v = {last_running_ts[47:12], curr_subheader_byte, 4'b0000};
    if ((frame_subheader_count != '0) && (curr_subheader_byte < last_running_ts[11:4])) begin
      ts_v[47:12] = last_running_ts[47:12] + 36'd1;
    end
    return ts_v;
  endfunction

  function automatic void push_actual_hit(bit [31:0] hit_word);
    opq_hit_trace_t trace;

    trace.hit_id = '0;
    trace.pkg_cnt = egress_pkg_cnt;
    trace.hit_ts = egress_current_ts;
    trace.accounting_hit_ts = '0;
    trace.hit_word = hit_word;
    trace.lane_id = -1;
    trace.shd_ts = egress_current_shd;
    actual_hits.push_back(trace);
  endfunction

  function automatic int retire_actual_from_lane_accounting(
    bit [15:0] pkg_cnt,
    bit [47:0] hit_ts,
    bit [31:0] hit_word
  );
    string key;
    int fallback_lane;
    int fallback_idx;
    int fallback_match_cnt;

    key = hit_key(pkg_cnt, hit_ts, hit_word);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      for (int idx = 0; idx < lane_accounting_hits[lane].size(); idx++) begin
        if (hit_key(
          lane_accounting_hits[lane][idx].pkg_cnt,
          lane_accounting_hits[lane][idx].hit_ts,
          lane_accounting_hits[lane][idx].hit_word
        ) == key) begin
          lane_accounting_hits[lane].delete(idx);
          return lane;
        end
      end
    end

    // In merged no-restart traffic the egress packet serial can legally
    // reflect the merged frame header rather than the original lane-local
    // packet index. When the payload word and reconstructed hit timestamp are
    // still unique, retire that one lane-local accounting entry instead of
    // leaving a false unexplained residue.
    fallback_lane = -1;
    fallback_idx = -1;
    fallback_match_cnt = 0;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      for (int idx = 0; idx < lane_accounting_hits[lane].size(); idx++) begin
        if ((lane_accounting_hits[lane][idx].hit_ts == hit_ts) &&
            (lane_accounting_hits[lane][idx].hit_word == hit_word)) begin
          fallback_lane = lane;
          fallback_idx = idx;
          fallback_match_cnt++;
        end
      end
    end
    if ((fallback_match_cnt == 1) && (fallback_lane >= 0)) begin
      lane_accounting_hits[fallback_lane].delete(fallback_idx);
      return fallback_lane;
    end
    return -1;
  endfunction

  function automatic void retire_lane_accounting_trace(
    int         lane_id,
    bit [15:0]  pkg_cnt,
    bit [47:0]  hit_ts,
    bit [31:0]  hit_word
  );
    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return;
    end

    for (int idx = 0; idx < lane_accounting_hits[lane_id].size(); idx++) begin
      if ((lane_accounting_hits[lane_id][idx].pkg_cnt == pkg_cnt) &&
          (lane_accounting_hits[lane_id][idx].accounting_hit_ts == hit_ts) &&
          (lane_accounting_hits[lane_id][idx].hit_word == hit_word)) begin
        lane_accounting_hits[lane_id].delete(idx);
        break;
      end
    end
  endfunction

  function automatic int unsigned count_lane_hits_at_exact_id(
    int        lane_id,
    bit [15:0] pkg_cnt,
    bit [47:0] hit_ts
  );
    int unsigned match_cnt;

    match_cnt = 0;
    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return 0;
    end
    for (int idx = 0; idx < lane_accounting_hits[lane_id].size(); idx++) begin
      if ((lane_accounting_hits[lane_id][idx].pkg_cnt == pkg_cnt) &&
          (lane_accounting_hits[lane_id][idx].accounting_hit_ts == hit_ts)) begin
        match_cnt++;
      end
    end
    return match_cnt;
  endfunction

  function automatic void emit_stay_sample(
    int        lane_id,
    bit [47:0] frame_ts_full,
    bit [30:0] proxy_ingress_ts_v,
    bit [30:0] ingress_debug_ts_v,
    bit [30:0] egress_debug_ts_v
  );
    int signed proxy_cycles_v;
    int signed debug_delta_v;
    int unsigned sample_idx_v;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return;
    end
    proxy_cycles_v = $signed({1'b0, egress_debug_ts_v}) - $signed({1'b0, proxy_ingress_ts_v});
    debug_delta_v = $signed({1'b0, egress_debug_ts_v}) - $signed({1'b0, ingress_debug_ts_v});
    if (proxy_cycles_v < 0) begin
      `uvm_warning(get_type_name(), $sformatf(
        "OPQ residency proxy underflow lane=%0d frame_ts=0x%012h proxy_ingress_ts=0x%08h ingress_debug_ts=0x%08h egress_debug_ts=0x%08h",
        lane_id,
        frame_ts_full,
        proxy_ingress_ts_v,
        ingress_debug_ts_v,
        egress_debug_ts_v
      ))
      return;
    end

    sample_idx_v = stay_sample_count[lane_id];
    stay_sample_count[lane_id] = stay_sample_count[lane_id] + 1;
    `uvm_info(get_type_name(), $sformatf(
      "OPQ_RESIDENCY_PROXY_SAMPLE lane=%0d sample_idx=%0d frame_ts=0x%012h proxy_ingress_ts=0x%08h ingress_debug_ts=0x%08h egress_debug_ts=0x%08h proxy_cycles=%0d debug_delta_cycles=%0d",
      lane_id,
      sample_idx_v,
      frame_ts_full,
      proxy_ingress_ts_v,
      ingress_debug_ts_v,
      egress_debug_ts_v,
      proxy_cycles_v,
      debug_delta_v
    ), UVM_LOW)
  endfunction

  function automatic void retire_stay_frames(
    bit [47:0] frame_ts_full,
    bit [30:0] egress_debug_ts_v
  );
    int matched_cnt;

    if (!enable_stay_time_trace) begin
      return;
    end

    matched_cnt = 0;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int idx;

      idx = 0;
      while (idx < pending_stay_frames[lane].size()) begin
        if (pending_stay_frames[lane][idx].frame_ts_full == frame_ts_full) begin
          emit_stay_sample(
            lane,
            pending_stay_frames[lane][idx].frame_ts_full,
            pending_stay_frames[lane][idx].proxy_ingress_ts,
            pending_stay_frames[lane][idx].ingress_debug_ts,
            egress_debug_ts_v
          );
          pending_stay_frames[lane].delete(idx);
          matched_cnt++;
        end else begin
          idx++;
        end
      end
    end

    if (matched_cnt == 0) begin
      `uvm_warning(get_type_name(), $sformatf(
        "OPQ stay trace saw egress frame_ts=0x%012h debug_ts=0x%08h without queued ingress stay metadata",
        frame_ts_full,
        egress_debug_ts_v
      ))
    end
  endfunction

  function void write_frame(opq_frame_item frame);
    opq_frame_meta_t meta;
    opq_stay_frame_t stay_meta;
    opq_hit_trace_t trace;
    opq_hit_trace_t accounting_trace;
    int unsigned accepted_subh_cnt;
    int unsigned accepted_hit_cnt;
    bit [47:0] frame_running_ts;
    bit [47:0] accounting_running_ts;
    bit        frame_subheaders_seen;

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
    meta.debug_header1 = make_frame_debug_header1(frame.ingress_debug_ts);
    pending_ingress_frames[frame.lane_id].push_back(meta);
    if (enable_stay_time_trace) begin
      stay_meta.frame_ts_full = frame.frame_ts;
      stay_meta.pkg_cnt = frame.pkg_cnt;
      stay_meta.proxy_ingress_ts = frame.frame_ts[30:0];
      stay_meta.ingress_debug_ts = frame.ingress_debug_ts;
      pending_stay_frames[frame.lane_id].push_back(stay_meta);
    end

    accepted_subh_cnt = accepted_frame_subh_count(frame);
    accepted_hit_cnt = accepted_frame_hit_count(frame);
    expected_lane_hdr_cnt[frame.lane_id]++;
    expected_lane_shd_cnt[frame.lane_id] += accepted_subh_cnt;
    expected_lane_hit_cnt[frame.lane_id] += accepted_hit_cnt;

    frame_running_ts = frame.frame_ts;
    accounting_running_ts = frame.frame_ts;
    frame_subheaders_seen = 1'b0;
    foreach (frame.subheaders[i]) begin
      frame_running_ts = extend_subheader_ts(
        frame_running_ts,
        frame_subheaders_seen,
        frame.subheaders[i].shd_ts
      );
      accounting_running_ts = extend_parser_running_ts(
        accounting_running_ts,
        meta.subh_cnt,
        frame.subheaders[i].shd_ts
      );
      frame_subheaders_seen = 1'b1;
      foreach (frame.subheaders[i].hits[j]) begin
        trace.hit_id = frame.subheaders[i].hits[j].debug_hit_id;
        trace.pkg_cnt = frame.pkg_cnt;
        trace.hit_ts = frame_running_ts;
        trace.accounting_hit_ts = accounting_running_ts;
        trace.hit_word = frame.subheaders[i].hits[j].payload_word;
        trace.lane_id = frame.lane_id;
        trace.shd_ts = frame.subheaders[i].shd_ts;
        emit_txn_trace("offer", trace);
        pending_ingress_hits[frame.lane_id].push_back(trace);
        if (cfg.allow_drop_accounting &&
            frame.subheaders[i].error_bits == '0 &&
            frame.subheaders[i].hits[j].error_bits == '0) begin
          accounting_trace = trace;
          lane_accounting_hits[frame.lane_id].push_back(accounting_trace);
          emit_txn_trace("expected", trace);
        end
      end
    end

    resolve_pending_exact_drops(frame.lane_id);
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
        ingress_frame_ts[lane_id] = '0;
        ingress_frame_subh_cnt[lane_id] = '0;
        ingress_frame_hit_cnt[lane_id] = '0;
        ingress_current_pkg_cnt[lane_id] = '0;
      end else begin
        ingress_frame_meta[lane_id] = pending_ingress_frames[lane_id].pop_front();
        ingress_have_frame_meta[lane_id] = 1'b1;
        ingress_frame_ts[lane_id] = ingress_frame_meta[lane_id].frame_ts_full;
        ingress_frame_subh_cnt[lane_id] = ingress_frame_meta[lane_id].subh_cnt;
        ingress_frame_hit_cnt[lane_id] = ingress_frame_meta[lane_id].hit_cnt;
        ingress_current_pkg_cnt[lane_id] = ingress_frame_meta[lane_id].pkg_cnt;
      end
      if (cfg.strict_packet_format && beat.eop) begin
        strict_packet_error($sformatf("Ingress lane %0d preamble asserted eop", lane_id), beat);
      end
      ingress_header_idx[lane_id] = 0;
      ingress_hits_pending[lane_id] = 0;
      ingress_ignore_hits_pending[lane_id] = 1'b0;
      ingress_current_ts[lane_id] = ingress_frame_ts[lane_id];
      ingress_accounting_ts[lane_id] = ingress_frame_ts[lane_id];
      ingress_subheaders_seen[lane_id] = 1'b0;
      ingress_observed_subh_cnt[lane_id] = 0;
      ingress_observed_hit_cnt[lane_id] = 0;
      return;
    end

    if (ingress_header_idx[lane_id] >= 0) begin
      if (cfg.strict_packet_format) begin
        if (datak != 4'b0000) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d header word %0d carried datak",
            lane_id, ingress_header_idx[lane_id]
          ), beat);
        end
        if (beat.sop) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d header word %0d asserted sop",
            lane_id, ingress_header_idx[lane_id]
          ), beat);
        end
        if (beat.eop) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d header word %0d asserted eop",
            lane_id, ingress_header_idx[lane_id]
          ), beat);
        end
      end
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
          trace.pkg_cnt = ingress_current_pkg_cnt[lane_id];
          trace.hit_ts = ingress_current_ts[lane_id];
          trace.accounting_hit_ts = ingress_accounting_ts[lane_id];
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
          trace.accounting_hit_ts = ingress_accounting_ts[lane_id];
          trace.hit_word = data32;
          trace.shd_ts = ingress_current_shd[lane_id];
        end
        if (!drop_hit_from_integrity) begin
          expected_hits.push_back(trace);
          emit_txn_trace("ingress_accept", trace);
        end else if (cfg.allow_drop_accounting) begin
          retire_lane_accounting_trace(
            lane_id,
            trace.pkg_cnt,
            ingress_accounting_ts[lane_id],
            trace.hit_word
          );
        end
        ingress_observed_hit_cnt[lane_id]++;
      end
      ingress_hits_pending[lane_id]--;
      if (ingress_hits_pending[lane_id] == 0) begin
        ingress_ignore_hits_pending[lane_id] = 1'b0;
      end
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K237) begin
      if (cfg.strict_packet_format) begin
        if (beat.sop) begin
          strict_packet_error($sformatf("Ingress lane %0d subheader asserted sop", lane_id), beat);
        end
        if (beat.eop) begin
          strict_packet_error($sformatf("Ingress lane %0d subheader asserted eop", lane_id), beat);
        end
        if (ingress_have_frame_meta[lane_id] &&
            (ingress_observed_subh_cnt[lane_id] >= ingress_frame_subh_cnt[lane_id])) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d observed too many subheaders observed=%0d declared=%0d",
            lane_id, ingress_observed_subh_cnt[lane_id] + 1, ingress_frame_subh_cnt[lane_id]
          ), beat);
        end
      end
      ingress_current_shd[lane_id] = data32[31:24];
      ingress_current_ts[lane_id] = extend_subheader_ts(
        ingress_current_ts[lane_id],
        ingress_subheaders_seen[lane_id],
        data32[31:24]
      );
      ingress_accounting_ts[lane_id] = extend_parser_running_ts(
        ingress_accounting_ts[lane_id],
        ingress_frame_subh_cnt[lane_id],
        data32[31:24]
      );
      ingress_subheaders_seen[lane_id] = 1'b1;
      ingress_hits_pending[lane_id] = data32[23:8];
      ingress_ignore_hits_pending[lane_id] = beat.error[1];
      ingress_observed_subh_cnt[lane_id]++;
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K284) begin
      if (cfg.strict_packet_format) begin
        if (beat.sop) begin
          strict_packet_error($sformatf("Ingress lane %0d trailer asserted sop", lane_id), beat);
        end
        if (!beat.eop) begin
          strict_packet_error($sformatf("Ingress lane %0d trailer missing eop", lane_id), beat);
        end
        if (ingress_have_frame_meta[lane_id] &&
            (ingress_observed_subh_cnt[lane_id] != ingress_frame_subh_cnt[lane_id])) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d subheader count mismatch declared=%0d observed=%0d",
            lane_id, ingress_frame_subh_cnt[lane_id], ingress_observed_subh_cnt[lane_id]
          ), beat);
        end
        if (ingress_have_frame_meta[lane_id] &&
            (ingress_observed_hit_cnt[lane_id] != ingress_frame_hit_cnt[lane_id])) begin
          strict_packet_error($sformatf(
            "Ingress lane %0d hit count mismatch declared=%0d observed=%0d",
            lane_id, ingress_frame_hit_cnt[lane_id], ingress_observed_hit_cnt[lane_id]
          ), beat);
        end
      end
      reset_ingress_lane(lane_id);
      return;
    end

    if (cfg.strict_packet_format) begin
      strict_packet_error($sformatf("Ingress lane %0d unexpected in-frame word", lane_id), beat);
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
      if (cfg.strict_packet_format) begin
        if (egress_header_idx == 0) begin
          if (!beat.sop) begin
            strict_packet_error("Egress preamble missing sop", beat);
          end
          if (beat.eop) begin
            strict_packet_error("Egress preamble asserted eop", beat);
          end
          if (!((datak == 4'b0001) && (data32[7:0] == K285))) begin
            strict_packet_error("Egress header word 0 is not K28.5 preamble", beat);
          end
        end else begin
          if (datak != 4'b0000) begin
            strict_packet_error($sformatf("Egress header word %0d carried datak", egress_header_idx), beat);
          end
          if (beat.sop) begin
            strict_packet_error($sformatf("Egress header word %0d asserted sop", egress_header_idx), beat);
          end
          if (beat.eop) begin
            strict_packet_error($sformatf("Egress header word %0d asserted eop", egress_header_idx), beat);
          end
        end
      end
      case (egress_header_idx)
        0: begin
          if (datak == 4'b0001 && data32[7:0] == K285) begin
            egress_preamble_seen = 1'b1;
            actual_egress_hdr_cnt++;
          end
        end
        1: egress_frame_ts[47:16] = data32;
        2: begin
          egress_frame_ts[15:0] = data32[31:16];
          egress_pkg_cnt = data32[15:0];
        end
        4: begin
          egress_debug_ts = data32[30:0];
          retire_stay_frames(egress_frame_ts, egress_debug_ts);
        end
        default: begin
        end
      endcase

      if (egress_header_idx == 4) begin
        egress_header_idx = -1;
        egress_current_ts = egress_frame_ts;
        egress_subheaders_seen = 1'b0;
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
        matched_lane = retire_actual_from_lane_accounting(egress_pkg_cnt, egress_current_ts, data32);
        if (enable_txn_trace) begin
          opq_hit_trace_t actual_trace;

          actual_trace.hit_id = '0;
          actual_trace.pkg_cnt = egress_pkg_cnt;
          actual_trace.hit_ts = egress_current_ts;
          actual_trace.accounting_hit_ts = '0;
          actual_trace.hit_word = data32;
          actual_trace.lane_id = matched_lane;
          actual_trace.shd_ts = egress_current_shd;
          emit_txn_trace("deliver", actual_trace);
        end
        if ((matched_lane >= 0) && (matched_lane < OPQ_N_LANE)) begin
          actual_lane_hit_cnt[matched_lane]++;
        end
        actual_egress_hit_cnt++;
      end
      if (cfg.strict_packet_format) begin
        if (beat.sop) begin
          strict_packet_error("Egress hit asserted sop", beat);
        end
        if (beat.eop) begin
          strict_packet_error("Egress hit asserted eop before trailer", beat);
        end
      end
      egress_hits_pending--;
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K237) begin
      if (cfg.strict_packet_format) begin
        if (beat.sop) begin
          strict_packet_error("Egress subheader asserted sop", beat);
        end
        if (beat.eop) begin
          strict_packet_error("Egress subheader asserted eop", beat);
        end
      end
      egress_current_shd = data32[31:24];
      egress_current_ts = extend_subheader_ts(
        egress_current_ts,
        egress_subheaders_seen,
        data32[31:24]
      );
      egress_subheaders_seen = 1'b1;
      egress_hits_pending = data32[23:8];
      actual_egress_shd_cnt++;
      return;
    end

    if (datak == 4'b0001 && data32[7:0] == K284) begin
      if (cfg.strict_packet_format) begin
        if (beat.sop) begin
          strict_packet_error("Egress trailer asserted sop", beat);
        end
        if (!beat.eop) begin
          strict_packet_error("Egress trailer missing eop", beat);
        end
      end
      reset_egress_state();
      return;
    end

    if (cfg.strict_packet_format) begin
      strict_packet_error("Egress unexpected in-frame word", beat);
    end
  endfunction

  function void write_drop(opq_drop_item item);
    int unsigned exact_pre_shd_delta;
    int unsigned exact_pre_hit_delta;
    int unsigned exact_post_shd_delta;
    int unsigned exact_post_hit_delta;
    int unsigned residual_shd_delta;
    int unsigned residual_hit_delta;

    if (item.lane_id < 0 || item.lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Drop item arrived with invalid lane_id=%0d", item.lane_id))
      return;
    end

    exact_pre_shd_delta = 0;
    exact_pre_hit_delta = 0;
    exact_post_shd_delta = 0;
    exact_post_hit_delta = 0;
    if (item.exact_pre_valid) begin
      exact_pre_shd_delta = item.exact_pre_shd_cnt;
      exact_pre_hit_delta = item.exact_pre_hit_cnt;
      if ((exact_pre_shd_delta > item.pre_shd_drop_cnt) ||
          (exact_pre_hit_delta > item.pre_hit_drop_cnt) ||
          (exact_pre_shd_delta > item.shd_drop_cnt) ||
          (exact_pre_hit_delta > item.hit_drop_cnt)) begin
        `uvm_error(get_type_name(), $sformatf(
          "Exact pre-drop detail exceeded event totals lane=%0d exact_shd=%0d exact_hit=%0d total_shd=%0d total_hit=%0d pre_shd=%0d pre_hit=%0d",
          item.lane_id,
          exact_pre_shd_delta,
          exact_pre_hit_delta,
          item.shd_drop_cnt,
          item.hit_drop_cnt,
          item.pre_shd_drop_cnt,
          item.pre_hit_drop_cnt
        ))
        exact_pre_shd_delta = 0;
        exact_pre_hit_delta = 0;
      end
    end
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

    dropped_lane_hdr_cnt[item.lane_id] += item.hdr_drop_cnt;
    dropped_lane_pre_shd_cnt[item.lane_id] += item.pre_shd_drop_cnt;
    dropped_lane_pre_hit_cnt[item.lane_id] += item.pre_hit_drop_cnt;
    dropped_lane_post_hdr_cnt[item.lane_id] += item.post_hdr_drop_cnt;
    dropped_lane_post_shd_cnt[item.lane_id] += item.post_shd_drop_cnt;
    dropped_lane_post_hit_cnt[item.lane_id] += item.post_hit_drop_cnt;
    account_drop_totals(item.lane_id, item.shd_drop_cnt, item.hit_drop_cnt, "monitor");
    if (exact_pre_hit_delta != 0) begin
      queue_or_apply_exact_drop(
        item.lane_id,
        item.exact_pre_serial,
        item.exact_pre_ts,
        exact_pre_shd_delta,
        exact_pre_hit_delta,
        "monitor_exact_pre"
      );
    end
    if (exact_post_hit_delta != 0) begin
      queue_or_apply_exact_drop(
        item.lane_id,
        item.exact_post_serial,
        item.exact_post_ts,
        exact_post_shd_delta,
        exact_post_hit_delta,
        "monitor_exact_post"
      );
    end
    residual_shd_delta = item.shd_drop_cnt - exact_pre_shd_delta - exact_post_shd_delta;
    residual_hit_delta = item.hit_drop_cnt - exact_pre_hit_delta - exact_post_hit_delta;
    apply_drop_delta(item.lane_id, residual_shd_delta, residual_hit_delta, "monitor");
    resolve_pending_exact_drops(item.lane_id);
  endfunction

  function automatic void account_drop_totals(
    int lane_id,
    int unsigned shd_drop_delta,
    int unsigned hit_drop_delta,
    string source
  );
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
      dropped_hit_sig[hit_sig_key(trace.lane_id, trace.pkg_cnt, trace.hit_ts, trace.hit_word)] = 1'b1;
      emit_txn_trace("controlled_drop", trace);
      hit_cnt--;
    end
  endfunction

  function bit apply_exact_drop_delta(
    int         lane_id,
    bit [15:0]  pkg_cnt,
    bit [47:0]  hit_ts,
    int unsigned shd_drop_delta,
    int unsigned hit_drop_delta,
    string      source,
    bit         report_unavailable = 1'b1
  );
    opq_hit_trace_t trace;
    int unsigned hit_cnt;
    int unsigned exact_hit_cnt;
    int unsigned aggregate_hit_cnt;
    int unsigned match_cnt;
    int idx;
    bit [47:0] front_ts;
    bit [47:0] back_ts;
    bit [15:0] front_pkg_cnt;
    bit [15:0] back_pkg_cnt;
    bit future_exact_v;
    bit duplicate_single_v;
    string partial_source;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf("Exact drop accounting arrived with invalid lane_id=%0d from %s", lane_id, source))
      return 1'b0;
    end

    if (!cfg.allow_drop_accounting) begin
      return 1'b1;
    end

    front_ts = '0;
    back_ts = '0;
    front_pkg_cnt = '0;
    back_pkg_cnt = '0;
    if (lane_accounting_hits[lane_id].size() != 0) begin
      front_pkg_cnt = lane_accounting_hits[lane_id][0].pkg_cnt;
      front_ts = lane_accounting_hits[lane_id][0].accounting_hit_ts;
      back_pkg_cnt = lane_accounting_hits[lane_id][lane_accounting_hits[lane_id].size()-1].pkg_cnt;
      back_ts = lane_accounting_hits[lane_id][lane_accounting_hits[lane_id].size()-1].accounting_hit_ts;
    end
    match_cnt = count_lane_hits_at_exact_id(lane_id, pkg_cnt, hit_ts);
    duplicate_single_v =
      (shd_drop_delta == 1) &&
      (hit_drop_delta != 0) &&
      (match_cnt == 0) &&
      ((lane_accounting_hits[lane_id].size() == 0) ||
       (pkg_cnt < front_pkg_cnt) ||
       ((pkg_cnt == front_pkg_cnt) && (hit_ts < front_ts)));
    if (duplicate_single_v) begin
      if (report_unavailable) begin
        `uvm_warning(get_type_name(), $sformatf(
          "Exact drop detail already accounted lane=%0d pkg_cnt=%0d ts=0x%012h expected_hits=%0d available_hits_at_id=%0d queue_depth=%0d front_pkg=%0d front_ts=0x%012h back_pkg=%0d back_ts=0x%012h source=%s; suppressing duplicate single-subheader drop",
          lane_id,
          pkg_cnt,
          hit_ts,
          hit_drop_delta,
          match_cnt,
          lane_accounting_hits[lane_id].size(),
          front_pkg_cnt,
          front_ts,
          back_pkg_cnt,
          back_ts,
          source
        ))
      end
      return 1'b1;
    end

    future_exact_v =
      (lane_accounting_hits[lane_id].size() == 0) ||
      (pkg_cnt > back_pkg_cnt) ||
      ((pkg_cnt == back_pkg_cnt) && (hit_ts > back_ts));
    if ((match_cnt < hit_drop_delta) && future_exact_v) begin
      if (report_unavailable) begin
        `uvm_warning(get_type_name(), $sformatf(
          "Exact drop detail unavailable lane=%0d pkg_cnt=%0d ts=0x%012h expected_hits=%0d available_hits_at_id=%0d queue_depth=%0d front_pkg=%0d front_ts=0x%012h back_pkg=%0d back_ts=0x%012h source=%s; deferring exact drop resolution",
          lane_id,
          pkg_cnt,
          hit_ts,
          hit_drop_delta,
          match_cnt,
          lane_accounting_hits[lane_id].size(),
          front_pkg_cnt,
          front_ts,
          back_pkg_cnt,
          back_ts,
          source
        ))
      end
      return 1'b0;
    end

    exact_hit_cnt = (match_cnt < hit_drop_delta) ? match_cnt : hit_drop_delta;
    aggregate_hit_cnt = hit_drop_delta - exact_hit_cnt;
    hit_cnt = exact_hit_cnt;
    idx = 0;
    while ((idx < lane_accounting_hits[lane_id].size()) && (hit_cnt > 0)) begin
      if ((lane_accounting_hits[lane_id][idx].pkg_cnt == pkg_cnt) &&
          (lane_accounting_hits[lane_id][idx].accounting_hit_ts == hit_ts)) begin
        trace = lane_accounting_hits[lane_id][idx];
        lane_accounting_hits[lane_id].delete(idx);
        dropped_hit_id[hit_id_key(trace.hit_id)] = 1'b1;
        dropped_hit_sig[hit_sig_key(trace.lane_id, trace.pkg_cnt, trace.hit_ts, trace.hit_word)] = 1'b1;
        emit_txn_trace("controlled_drop", trace);
        hit_cnt--;
      end else begin
        idx++;
      end
    end

    if (hit_cnt != 0) begin
      `uvm_error(get_type_name(), $sformatf(
        "Exact drop accounting internal mismatch lane=%0d pkg_cnt=%0d ts=0x%012h expected_hits=%0d missing_hits=%0d source=%s",
        lane_id,
        pkg_cnt,
        hit_ts,
        exact_hit_cnt,
        hit_cnt,
        source
      ))
      return 1'b0;
    end

    if (aggregate_hit_cnt != 0) begin
      partial_source = $sformatf("%s_partial", source);
      if (report_unavailable) begin
        `uvm_warning(get_type_name(), $sformatf(
          "Exact drop detail partial lane=%0d pkg_cnt=%0d ts=0x%012h expected_hits=%0d exact_hits=%0d aggregate_hits=%0d queue_depth=%0d front_pkg=%0d front_ts=0x%012h back_pkg=%0d back_ts=0x%012h source=%s",
          lane_id,
          pkg_cnt,
          hit_ts,
          hit_drop_delta,
          exact_hit_cnt,
          aggregate_hit_cnt,
          lane_accounting_hits[lane_id].size(),
          front_pkg_cnt,
          front_ts,
          back_pkg_cnt,
          back_ts,
          source
        ))
      end
      apply_drop_delta(lane_id, 0, aggregate_hit_cnt, partial_source);
    end
    return 1'b1;
  endfunction

  function automatic void queue_or_apply_exact_drop(
    int lane_id,
    bit [15:0] pkg_cnt,
    bit [47:0] hit_ts,
    int unsigned shd_drop_delta,
    int unsigned hit_drop_delta,
    string source
  );
    opq_pending_exact_drop_t pending;

    if (apply_exact_drop_delta(
      lane_id,
      pkg_cnt,
      hit_ts,
      shd_drop_delta,
      hit_drop_delta,
      source,
      1'b1
    )) begin
      return;
    end

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return;
    end

    pending.pkg_cnt = pkg_cnt;
    pending.hit_ts = hit_ts;
    pending.shd_drop_delta = shd_drop_delta;
    pending.hit_drop_delta = hit_drop_delta;
    pending_exact_drops[lane_id].push_back(pending);
  endfunction

  function automatic void resolve_pending_exact_drops(int lane_id);
    int idx;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      return;
    end

    idx = 0;
    while (idx < pending_exact_drops[lane_id].size()) begin
      if (apply_exact_drop_delta(
        lane_id,
        pending_exact_drops[lane_id][idx].pkg_cnt,
        pending_exact_drops[lane_id][idx].hit_ts,
        pending_exact_drops[lane_id][idx].shd_drop_delta,
        pending_exact_drops[lane_id][idx].hit_drop_delta,
        "pending_exact",
        1'b0
      )) begin
        pending_exact_drops[lane_id].delete(idx);
      end else begin
        idx++;
      end
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
    if (cfg.strict_packet_format && egress_in_packet) begin
      `uvm_error(get_type_name(), $sformatf(
        "Egress packet did not terminate cleanly header_idx=%0d hits_pending=%0d",
        egress_header_idx, egress_hits_pending
      ))
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
      if (enable_stay_time_trace && (pending_stay_frames[i].size() != 0)) begin
        `uvm_warning(get_type_name(), $sformatf(
          "Lane %0d still has %0d queued stay-trace frames without an egress match",
          i, pending_stay_frames[i].size()
        ))
      end
      resolve_pending_exact_drops(i);
      if (pending_exact_drops[i].size() != 0) begin
        `uvm_error(get_type_name(), $sformatf(
          "Lane %0d still has %0d deferred exact-drop events unresolved at end of test",
          i, pending_exact_drops[i].size()
        ))
      end
    end

    foreach (actual_hits[i]) begin
      key = hit_key(actual_hits[i].pkg_cnt, actual_hits[i].hit_ts, actual_hits[i].hit_word);
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
             expected_hits[i].pkg_cnt,
             expected_hits[i].hit_ts,
             expected_hits[i].hit_word
           )))) begin
        continue;
      end
      compare_expected_hits++;
      key = hit_key(expected_hits[i].pkg_cnt, expected_hits[i].hit_ts, expected_hits[i].hit_word);
      if (actual_key_count.exists(key) && actual_key_count[key] > 0) begin
        actual_key_count[key]--;
      end else begin
        missing_hits++;
        `uvm_error(get_type_name(), $sformatf(
          "Missing hit_id=0x%016h lane=%0d pkg_cnt=%0d ts=0x%012h shd_ts=0x%02h word=0x%08h",
          expected_hits[i].hit_id,
          expected_hits[i].lane_id,
          expected_hits[i].pkg_cnt,
          expected_hits[i].hit_ts,
          expected_hits[i].shd_ts,
          expected_hits[i].hit_word
        ))
      end
    end

    ghost_hits = 0;
    foreach (actual_hits[i]) begin
      key = hit_key(actual_hits[i].pkg_cnt, actual_hits[i].hit_ts, actual_hits[i].hit_word);
      if (actual_key_count.exists(key) && actual_key_count[key] > 0) begin
        ghost_hits++;
        actual_key_count[key]--;
        `uvm_error(get_type_name(), $sformatf(
          "Ghost hit pkg_cnt=%0d ts=0x%012h shd_ts=0x%02h word=0x%08h",
          actual_hits[i].pkg_cnt,
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
      if (enable_stay_time_trace) begin
        `uvm_info(get_type_name(), $sformatf(
          "OPQ_RESIDENCY_PROXY_SUMMARY lane=%0d samples=%0d unmatched=%0d",
          i,
          stay_sample_count[i],
          pending_stay_frames[i].size()
        ), UVM_LOW)
      end
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
    int unsigned pre_dropped_hdr_cnt;

    if (dropped_lane_post_hdr_cnt[lane_id] > dropped_lane_hdr_cnt[lane_id]) begin
      pre_dropped_hdr_cnt = 0;
    end else begin
      pre_dropped_hdr_cnt = dropped_lane_hdr_cnt[lane_id] - dropped_lane_post_hdr_cnt[lane_id];
    end

    if (pre_dropped_hdr_cnt > expected_lane_hdr_cnt[lane_id]) begin
      return 0;
    end
    return expected_lane_hdr_cnt[lane_id] - pre_dropped_hdr_cnt;
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

  function void dump_lane_unexplained_hits(int lane_id, int unsigned max_entries = 16);
    int unsigned shown;
    int unsigned ts_run_count;
    bit [47:0] current_ts;
    bit        current_ts_valid;

    if (lane_id < 0 || lane_id >= OPQ_N_LANE) begin
      `uvm_error(get_type_name(), $sformatf(
        "Unexplained hit dump requested with invalid lane_id=%0d",
        lane_id
      ))
      return;
    end

    $display("[opq_unexplained] lane%0d queue_depth=%0d",
      lane_id,
      lane_accounting_hits[lane_id].size()
    );

    shown = 0;
    current_ts = '0;
    ts_run_count = 0;
    current_ts_valid = 1'b0;
    for (int idx = 0; idx < lane_accounting_hits[lane_id].size(); idx++) begin
      if (!current_ts_valid) begin
        current_ts = lane_accounting_hits[lane_id][idx].hit_ts;
        ts_run_count = 1;
        current_ts_valid = 1'b1;
      end else if (lane_accounting_hits[lane_id][idx].hit_ts == current_ts) begin
        ts_run_count++;
      end else begin
        $display("[opq_unexplained] lane%0d ts=0x%012h count=%0d",
          lane_id,
          current_ts,
          ts_run_count
        );
        current_ts = lane_accounting_hits[lane_id][idx].hit_ts;
        ts_run_count = 1;
      end

      if (shown < max_entries) begin
        $display("[opq_unexplained] lane%0d idx=%0d hit_id=0x%016h ts=0x%012h acct_ts=0x%012h shd_ts=0x%02h word=0x%08h",
          lane_id,
          shown,
          lane_accounting_hits[lane_id][idx].hit_id,
          lane_accounting_hits[lane_id][idx].hit_ts,
          lane_accounting_hits[lane_id][idx].accounting_hit_ts,
          lane_accounting_hits[lane_id][idx].shd_ts,
          lane_accounting_hits[lane_id][idx].hit_word
        );
        shown++;
      end
    end

    if (current_ts_valid) begin
      $display("[opq_unexplained] lane%0d ts=0x%012h count=%0d",
        lane_id,
        current_ts,
        ts_run_count
      );
    end
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

//------------------------------------------------------------------------------
// IP Name   : opq_basic_seq
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.4 - carry virtual FEB ingress-debug timing through absolute lane skew
// Description:
//   UVM virtual sequences for the active OPQ regression buckets.
//------------------------------------------------------------------------------
class opq_lane_frame_sequence extends uvm_sequence #(opq_frame_item);
  `uvm_object_utils(opq_lane_frame_sequence)

  opq_frame_item frames[$];

  function new(string name = "opq_lane_frame_sequence");
    super.new(name);
  endfunction

  task body();
    foreach (frames[i]) begin
      start_item(frames[i]);
      finish_item(frames[i]);
    end
  endtask
endclass

class opq_bp_sequence extends uvm_sequence #(opq_bp_item);
  `uvm_object_utils(opq_bp_sequence)

  opq_bp_item items[$];

  function new(string name = "opq_bp_sequence");
    super.new(name);
  endfunction

  task body();
    foreach (items[i]) begin
      start_item(items[i]);
      finish_item(items[i]);
    end
  endtask
endclass

class opq_virtual_sequence_base extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(opq_virtual_sequence_base)
  `uvm_declare_p_sequencer(opq_virtual_sequencer)

  static bit [63:0] next_debug_hit_id = 64'd1;

  bit continuous_frame_mode;
  bit [15:0] continuous_pkg_cnt_base[OPQ_N_LANE];
  bit [15:0] continuous_next_pkg_cnt_base[OPQ_N_LANE];
  bit [47:0] continuous_frame_ts_base;
  bit        continuous_lane_seen[OPQ_N_LANE];
  int unsigned continuous_frame_slots_emitted;

  function new(string name = "opq_virtual_sequence_base");
    super.new(name);
    reset_continuous_frame_context();
  endfunction

  function void reset_continuous_frame_context();
    continuous_frame_mode = 1'b0;
    continuous_frame_ts_base = '0;
    continuous_frame_slots_emitted = 0;
    foreach (continuous_pkg_cnt_base[i]) begin
      continuous_pkg_cnt_base[i] = '0;
      continuous_next_pkg_cnt_base[i] = '0;
      continuous_lane_seen[i] = 1'b0;
    end
  endfunction

  function void configure_continuous_frame(
    input bit [15:0] pkg_cnt_base[OPQ_N_LANE],
    input bit [47:0] frame_ts_base
  );
    reset_continuous_frame_context();
    continuous_frame_mode = 1'b1;
    continuous_frame_ts_base = frame_ts_base;
    foreach (continuous_pkg_cnt_base[i]) begin
      continuous_pkg_cnt_base[i] = pkg_cnt_base[i];
      continuous_next_pkg_cnt_base[i] = pkg_cnt_base[i];
    end
  endfunction

  function automatic bit [15:0] get_next_pkg_cnt_base(int lane_id);
    return continuous_next_pkg_cnt_base[lane_id];
  endfunction

  function automatic int unsigned get_continuous_frame_slots_emitted();
    return continuous_frame_slots_emitted;
  endfunction

  virtual function bit continuous_frame_emits_egress_frames();
    return 1'b1;
  endfunction

  function automatic opq_frame_item finalize_frame_item(
    opq_frame_item tr,
    bit [15:0] local_pkg_cnt
  );
    int lane_id;
    bit [7:0] shd_ts_offset;

    lane_id = tr.lane_id;
    if (continuous_frame_mode) begin
      tr.frame_ts = tr.frame_ts + continuous_frame_ts_base;
      tr.pkg_cnt = tr.pkg_cnt + continuous_pkg_cnt_base[lane_id];
      shd_ts_offset = continuous_frame_ts_base[11:4];
      foreach (tr.subheaders[i]) begin
        tr.subheaders[i].shd_ts = tr.subheaders[i].shd_ts + shd_ts_offset;
      end
      if ((int'(local_pkg_cnt) + 1) > continuous_frame_slots_emitted) begin
        continuous_frame_slots_emitted = int'(local_pkg_cnt) + 1;
      end
      continuous_lane_seen[lane_id] = 1'b1;
      continuous_next_pkg_cnt_base[lane_id] = tr.pkg_cnt + 16'd1;
    end
    tr.ingress_debug_ts = default_ingress_debug_ts(tr.frame_ts);
    return tr;
  endfunction

  function automatic bit [7:0] abs_shd_ts(bit [47:0] frame_ts, int unsigned shd_slot_offset);
    bit [7:0] shd_slot_offset_v;

    shd_slot_offset_v = shd_slot_offset[7:0];
    return frame_ts[11:4] + shd_slot_offset_v;
  endfunction

  function automatic opq_frame_item build_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    int unsigned subheader_count,
    int unsigned shd_ts_base,
    int unsigned pre_gap_cycles,
    bit [31:0] hit0,
    bit [31:0] hit1,
    int unsigned hit_count
  );
    opq_frame_item tr;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    for (int i = 0; i < subheader_count; i++) begin
      opq_subheader_desc shd;
      shd = opq_subheader_desc::type_id::create($sformatf("%s_shd_%0d", name, i));
      shd.shd_ts = (shd_ts_base + i) % 256;
      if (i == 0 && hit_count > 0) begin
        opq_hit_desc hit_desc0;
        hit_desc0 = opq_hit_desc::type_id::create($sformatf("%s_hit_%0d_0", name, i));
        hit_desc0.payload_word = hit0;
        hit_desc0.debug_hit_id = next_debug_hit_id;
        next_debug_hit_id++;
        shd.hits.push_back(hit_desc0);
        if (hit_count > 1) begin
          opq_hit_desc hit_desc1;
          hit_desc1 = opq_hit_desc::type_id::create($sformatf("%s_hit_%0d_1", name, i));
          hit_desc1.payload_word = hit1;
          hit_desc1.debug_hit_id = next_debug_hit_id;
          next_debug_hit_id++;
          shd.hits.push_back(hit_desc1);
        end
      end
      tr.subheaders.push_back(shd);
    end

    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  function automatic opq_frame_item build_single_subheader_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    bit [7:0] shd_ts,
    int unsigned pre_gap_cycles,
    bit [31:0] hit_words[$]
  );
    opq_frame_item tr;
    opq_subheader_desc shd;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    shd = opq_subheader_desc::type_id::create({name, "_shd0"});
    shd.shd_ts = shd_ts;
    foreach (hit_words[i]) begin
      opq_hit_desc hit_desc;
      hit_desc = opq_hit_desc::type_id::create($sformatf("%s_hit_%0d", name, i));
      hit_desc.payload_word = hit_words[i];
      hit_desc.debug_hit_id = next_debug_hit_id;
      next_debug_hit_id++;
      shd.hits.push_back(hit_desc);
    end
    tr.subheaders.push_back(shd);
    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  function automatic opq_frame_item build_sparse_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    int unsigned pre_gap_cycles,
    bit [7:0] shd_ts_words[$],
    bit [31:0] hit_words[$]
  );
    opq_frame_item tr;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    if (shd_ts_words.size() != hit_words.size()) begin
      `uvm_fatal(get_type_name(), $sformatf(
        "build_sparse_frame size mismatch shd_ts=%0d hit_words=%0d for %s",
        shd_ts_words.size(), hit_words.size(), name
      ))
    end

    foreach (shd_ts_words[i]) begin
      opq_subheader_desc shd;
      opq_hit_desc hit_desc;

      shd = opq_subheader_desc::type_id::create($sformatf("%s_sparse_shd_%0d", name, i));
      shd.shd_ts = shd_ts_words[i];
      hit_desc = opq_hit_desc::type_id::create($sformatf("%s_sparse_hit_%0d", name, i));
      hit_desc.payload_word = hit_words[i];
      hit_desc.debug_hit_id = next_debug_hit_id;
      next_debug_hit_id++;
      shd.hits.push_back(hit_desc);
      tr.subheaders.push_back(shd);
    end

    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  function automatic opq_frame_item build_dense_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    int unsigned subheader_count,
    int unsigned shd_ts_base,
    int unsigned pre_gap_cycles,
    int unsigned hit_count_per_subheader,
    bit [31:0] payload_seed
  );
    opq_frame_item tr;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    for (int shd_idx = 0; shd_idx < subheader_count; shd_idx++) begin
      opq_subheader_desc shd;

      shd = opq_subheader_desc::type_id::create($sformatf("%s_dense_shd_%0d", name, shd_idx));
      shd.shd_ts = (shd_ts_base + shd_idx) % 256;
      for (int hit_idx = 0; hit_idx < hit_count_per_subheader; hit_idx++) begin
        opq_hit_desc hit_desc;

        hit_desc = opq_hit_desc::type_id::create($sformatf("%s_dense_hit_%0d_%0d", name, shd_idx, hit_idx));
        hit_desc.payload_word = payload_seed
          + (shd_idx << 8)
          + hit_idx
          + (lane_id << 24);
        hit_desc.debug_hit_id = next_debug_hit_id;
        next_debug_hit_id++;
        shd.hits.push_back(hit_desc);
      end
      tr.subheaders.push_back(shd);
    end

    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  function automatic opq_frame_item build_timestamp_hit_count_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    int unsigned shd_ts_base,
    int unsigned pre_gap_cycles,
    input int unsigned hit_counts[$],
    bit [31:0] payload_seed
  );
    opq_frame_item tr;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    foreach (hit_counts[shd_idx]) begin
      opq_subheader_desc shd;
      int unsigned capped_hit_count;

      shd = opq_subheader_desc::type_id::create($sformatf("%s_ts_shd_%0d", name, shd_idx));
      shd.shd_ts = (shd_ts_base + shd_idx) % 256;
      capped_hit_count = (hit_counts[shd_idx] > OPQ_N_HIT) ? OPQ_N_HIT : hit_counts[shd_idx];
      for (int unsigned hit_idx = 0; hit_idx < capped_hit_count; hit_idx++) begin
        opq_hit_desc hit_desc;

        hit_desc = opq_hit_desc::type_id::create($sformatf("%s_ts_hit_%0d_%0d", name, shd_idx, hit_idx));
        hit_desc.payload_word = payload_seed
          + (shd_idx << 12)
          + hit_idx
          + (lane_id << 24);
        hit_desc.debug_hit_id = next_debug_hit_id;
        next_debug_hit_id++;
        shd.hits.push_back(hit_desc);
      end
      tr.subheaders.push_back(shd);
    end

    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  function automatic bit [63:0] decode_slot_offset_cycles(
    opq_frame_item tr,
    int unsigned slot_idx,
    int unsigned slot_gap_cycles
  );
    bit [63:0] slot_offset_cycles;

    slot_offset_cycles = tr.pre_gap_cycles;
    if (slot_idx != 0) begin
      if (tr.pre_gap_cycles > slot_gap_cycles) begin
        slot_offset_cycles = tr.pre_gap_cycles - slot_gap_cycles;
      end else begin
        slot_offset_cycles = '0;
      end
    end
    return slot_offset_cycles;
  endfunction

  function automatic bit [63:0] get_absolute_launch_origin_cycle();
    bit [63:0] launch_origin_cycle;
    bit [63:0] live_cycle_origin;

    launch_origin_cycle = OPQ_POST_RESET_SETTLE_CYCLES + OPQ_ABSOLUTE_LAUNCH_GUARD_CYCLES;
    if ((p_sequencer != null) && (p_sequencer.ingress_vif[0] != null)) begin
      live_cycle_origin = '0;
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        if ((p_sequencer.ingress_vif[lane] != null) &&
            (p_sequencer.ingress_vif[lane].cycle_count > live_cycle_origin)) begin
          live_cycle_origin = p_sequencer.ingress_vif[lane].cycle_count;
        end
      end
      launch_origin_cycle = live_cycle_origin + OPQ_ABSOLUTE_LAUNCH_GUARD_CYCLES;
    end
    return launch_origin_cycle;
  endfunction

  task automatic apply_absolute_frame_period_schedule(
    ref opq_frame_item lane_frames[OPQ_N_LANE][$],
    input int unsigned frame_period_cycles
  );
    int unsigned max_slot_count;
    bit [63:0] launch_origin_cycle;

    if (frame_period_cycles == 0) begin
      frame_period_cycles = OPQ_FRAME_DURATION_SWB_CYCLES;
    end

    max_slot_count = 0;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      if (lane_frames[lane].size() > max_slot_count) begin
        max_slot_count = lane_frames[lane].size();
      end
    end

    launch_origin_cycle = get_absolute_launch_origin_cycle();
    for (int unsigned slot_idx = 0; slot_idx < max_slot_count; slot_idx++) begin
      bit [63:0] slot_base_cycle;

      slot_base_cycle = launch_origin_cycle + (64'(slot_idx) * 64'(frame_period_cycles));
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        if (slot_idx < lane_frames[lane].size()) begin
          bit [63:0] frame_words_v;

          frame_words_v = lane_frames[lane][slot_idx].frame_word_count();
          if (frame_words_v > 64'(frame_period_cycles)) begin
            `uvm_warning(get_type_name(), $sformatf(
              "lane %0d frame slot %0d word_count=%0d exceeds physical frame_period_cycles=%0d",
              lane,
              slot_idx,
              frame_words_v,
              frame_period_cycles
            ))
          end
          lane_frames[lane][slot_idx].use_absolute_launch = 1'b1;
          lane_frames[lane][slot_idx].launch_cycle = slot_base_cycle;
          lane_frames[lane][slot_idx].frame_slot_id = slot_idx;
          lane_frames[lane][slot_idx].ingress_debug_ts =
            default_ingress_debug_ts(lane_frames[lane][slot_idx].frame_ts);
        end
      end
    end
  endtask

  task automatic apply_absolute_frame_slot_schedule(
    ref opq_frame_item lane_frames[OPQ_N_LANE][$],
    input int unsigned slot_gap_cycles
  );
    int unsigned max_slot_count;
    bit [63:0] slot_base_cycle;

    max_slot_count = 0;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      if (lane_frames[lane].size() > max_slot_count) begin
        max_slot_count = lane_frames[lane].size();
      end
    end

    slot_base_cycle = get_absolute_launch_origin_cycle();
    for (int unsigned slot_idx = 0; slot_idx < max_slot_count; slot_idx++) begin
      bit slot_has_frame;
      bit [63:0] next_slot_base_cycle;

      slot_has_frame = 1'b0;
      next_slot_base_cycle = slot_base_cycle;
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        if (slot_idx < lane_frames[lane].size()) begin
          bit [63:0] launch_cycle_v;
          bit [63:0] slot_offset_cycles;
          bit [63:0] slot_end_cycle;

          slot_has_frame = 1'b1;
          slot_offset_cycles = decode_slot_offset_cycles(
            lane_frames[lane][slot_idx],
            slot_idx,
            slot_gap_cycles
          );
          launch_cycle_v = slot_base_cycle + slot_offset_cycles;
          slot_end_cycle = launch_cycle_v + lane_frames[lane][slot_idx].frame_word_count();

          lane_frames[lane][slot_idx].use_absolute_launch = 1'b1;
          lane_frames[lane][slot_idx].launch_cycle = launch_cycle_v;
          lane_frames[lane][slot_idx].frame_slot_id = slot_idx;
          lane_frames[lane][slot_idx].ingress_debug_ts = add_debug_ts_offset(
            default_ingress_debug_ts(lane_frames[lane][slot_idx].frame_ts),
            slot_offset_cycles
          );
          if (slot_end_cycle > next_slot_base_cycle) begin
            next_slot_base_cycle = slot_end_cycle;
          end
        end
      end
      if (slot_has_frame) begin
        slot_base_cycle = next_slot_base_cycle + slot_gap_cycles;
      end
    end
  endtask

  task automatic start_lane_frames(ref opq_frame_item lane0_frames[$], ref opq_frame_item lane1_frames[$]);
    opq_frame_item lane_frames[OPQ_N_LANE][$];

    foreach (lane0_frames[i]) lane_frames[0].push_back(lane0_frames[i]);
    foreach (lane1_frames[i]) lane_frames[1].push_back(lane1_frames[i]);
    start_lane_frame_matrix(lane_frames);
  endtask

  task automatic start_lane_frame_matrix(ref opq_frame_item lane_frames[OPQ_N_LANE][$]);
    opq_lane_frame_sequence lane_seq[OPQ_N_LANE];

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      lane_seq[i] = opq_lane_frame_sequence::type_id::create($sformatf("lane_seq_%0d", i));
      for (int j = 0; j < lane_frames[i].size(); j++) begin
        lane_seq[i].frames.push_back(lane_frames[i][j]);
      end
    end

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      automatic int lane = i;
      fork
        lane_seq[lane].start(p_sequencer.ingress_seqr[lane]);
      join_none
    end
    wait fork;
  endtask

  task automatic start_periodic_backpressure(int high_cycles, int low_cycles, int repeat_count);
    opq_bp_sequence bp_seq;
    opq_bp_item bp_item;

    bp_seq = opq_bp_sequence::type_id::create("bp_seq");
    bp_item = opq_bp_item::type_id::create("bp_item");
    bp_item.mode = BP_PERIODIC_STALL;
    bp_item.high_cycles = high_cycles;
    bp_item.low_cycles = low_cycles;
    bp_item.repeat_count = repeat_count;
    bp_seq.items.push_back(bp_item);
    bp_seq.start(p_sequencer.egress_seqr);
  endtask
endclass

class opq_basic_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_basic_virtual_sequence)

  function new(string name = "opq_basic_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;
    int unsigned smoke_subheaders_per_frame;

    ts_step = OPQ_N_SHD * 16;
    // BASIC smoke is a functional no-drop lane-scale check.  Dense full-frame
    // traffic belongs in the loss/profile bucket, not in this direct smoke.
    smoke_subheaders_per_frame = 1;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] first_seed;
      bit [31:0] second_seed;

      first_seed = 32'hDEAD_BEEF ^ (lane * 32'h1111_0011);
      second_seed = 32'h0BAD_BEEF ^ (lane * 32'h0101_0101);

      lane_frames[lane].push_back(build_frame(
        $sformatf("lane%0d_pkt0", lane), lane, ts_step, 16'd0,
        smoke_subheaders_per_frame, 1, 0,
        first_seed, second_seed, 2
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_basic_feb_packet_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_basic_feb_packet_virtual_sequence)

  function new(string name = "opq_basic_feb_packet_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;
    int unsigned contract_subheaders_per_frame;

    ts_step = OPQ_N_SHD * 16;
    contract_subheaders_per_frame = 1;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] first_seed;
      bit [31:0] second_seed;
      int unsigned feb_id;

      first_seed = 32'hDEADBEEF ^ (lane * 32'h11110011);
      second_seed = 32'h0BADBEEF ^ (lane * 32'h01010101);
      feb_id = (lane < 2) ? 16'h0001 : 16'h0002;

      lane_frames[lane].push_back(build_frame(
        $sformatf("lane%0d_feb_pkt0", lane), lane, ts_step, 16'd0,
        contract_subheaders_per_frame, 1, 0, first_seed, second_seed, 2
      ));

      for (int idx = 0; idx < lane_frames[lane].size(); idx++) begin
        lane_frames[lane][idx].whole_frame_packet = 1'b1;
        lane_frames[lane][idx].feb_id = feb_id[15:0];
      end
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_rn001_board_shape_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_rn001_board_shape_virtual_sequence)

  int unsigned frame_count;
  int unsigned hit_count_per_subheader;
  int unsigned inter_frame_gap_cycles;

  function new(string name = "opq_rn001_board_shape_virtual_sequence");
    super.new(name);
    frame_count = 4;
    hit_count_per_subheader = 1;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    void'($value$plusargs("OPQ_RN001_FRAME_COUNT=%d", frame_count));
    void'($value$plusargs("OPQ_RN001_HITS_PER_SUBHEADER=%d", hit_count_per_subheader));
    if (frame_count == 0) begin
      `uvm_fatal(get_type_name(), "OPQ_RN001_FRAME_COUNT must be non-zero")
    end
    if (hit_count_per_subheader > OPQ_N_HIT) begin
      `uvm_fatal(get_type_name(), $sformatf(
        "OPQ_RN001_HITS_PER_SUBHEADER=%0d exceeds OPQ_N_HIT=%0d",
        hit_count_per_subheader, OPQ_N_HIT
      ))
    end

    ts_step = OPQ_FRAME_DURATION_TS_TICKS;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int unsigned feb_id;

      feb_id = (lane < 2) ? 16'h0001 : 16'h0002;
      for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
        opq_frame_item tr;
        int unsigned pre_gap_cycles;
        int unsigned shd_ts_base;
        bit [31:0] payload_seed;

        pre_gap_cycles = (frame_idx == 0) ? 0 : inter_frame_gap_cycles;
        shd_ts_base = frame_idx * OPQ_N_SHD;
        payload_seed = 32'h5200_0000 + (lane << 24) + frame_idx;
        tr = build_dense_frame(
          $sformatf("lane%0d_rn001_shape_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          OPQ_N_SHD,
          shd_ts_base,
          pre_gap_cycles,
          hit_count_per_subheader,
          payload_seed
        );
        tr.whole_frame_packet = 1'b1;
        tr.feb_id = feb_id[15:0];
        lane_frames[lane].push_back(tr);
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_whole_frame_skew_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_whole_frame_skew_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned hit_period;
  int unsigned hit_count_when_active;
  int unsigned inter_frame_gap_cycles;
  int unsigned lane_extra_gap_cycles[OPQ_N_LANE];

  function new(string name = "opq_whole_frame_skew_virtual_sequence");
    super.new(name);
    frame_count = 12;
    subheaders_per_frame = OPQ_N_SHD;
    hit_period = 4;
    hit_count_when_active = 2;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      lane_extra_gap_cycles[lane] = lane * 32;
    end
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int unsigned feb_id;
      feb_id = (lane < 2) ? 16'h0001 : 16'h0002;
      for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
        int unsigned pre_gap_cycles;
        int unsigned frame_hit_count;
        bit [31:0] first_seed;
        bit [31:0] second_seed;

        pre_gap_cycles = (frame_idx == 0) ? lane_extra_gap_cycles[lane]
                                          : inter_frame_gap_cycles + lane_extra_gap_cycles[lane];
        frame_hit_count = (((frame_idx + lane) % hit_period) == 0) ? hit_count_when_active : 0;
        first_seed = 32'h5000_0000 + (lane * 32'h0100_0000) + frame_idx;
        second_seed = 32'h6000_0000 + (lane * 32'h0100_0000) + frame_idx;

        lane_frames[lane].push_back(build_frame(
          $sformatf("lane%0d_whole_frame_%0d", lane, frame_idx), lane,
          ts_step * frame_idx, frame_idx[15:0], subheaders_per_frame,
          (frame_idx + lane + 1) % OPQ_N_SHD, pre_gap_cycles,
          first_seed, second_seed, frame_hit_count
        ));
        lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
        lane_frames[lane][lane_frames[lane].size()-1].feb_id = feb_id[15:0];
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_timestamp_burst_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_timestamp_burst_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned inter_frame_gap_cycles;
  int unsigned total_rho_ppm;
  int unsigned noise_rho_ppm;
  int unsigned cluster_rho_ppm;
  int unsigned cluster_size_min;
  int unsigned cluster_size_max;
  int signed   burstiness_milli;
  int unsigned rng_seed;

  function new(string name = "opq_timestamp_burst_virtual_sequence");
    super.new(name);
    frame_count = 16;
    subheaders_per_frame = OPQ_N_SHD;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    total_rho_ppm = 600000;
    noise_rho_ppm = 100000;
    cluster_rho_ppm = 500000;
    cluster_size_min = 4;
    cluster_size_max = 8;
    burstiness_milli = 403;
    rng_seed = 32'h5C1F_0001;
  endfunction

  function automatic bit [31:0] next_rng(ref bit [31:0] state);
    state = (state * 32'd1664525) + 32'd1013904223;
    return state;
  endfunction

  function automatic real uniform_open01(ref bit [31:0] state);
    return (real'(next_rng(state)) + 1.0) / 4294967297.0;
  endfunction

  function automatic int unsigned sample_poisson_ppm(
    int unsigned rate_ppm,
    ref bit [31:0] state
  );
    int unsigned count;
    real lambda;
    real limit_p;
    real product_p;

    if (rate_ppm == 0) begin
      return 0;
    end

    lambda = real'(rate_ppm) / 1000000.0;
    limit_p = $exp(-lambda);
    product_p = 1.0;
    count = 0;
    do begin
      count++;
      product_p *= uniform_open01(state);
    end while (product_p > limit_p);
    return count - 1;
  endfunction

  function automatic int unsigned sample_periodic_ppm(
    int unsigned rate_ppm,
    ref int unsigned accum_ppm
  );
    longint unsigned next_accum;

    if (rate_ppm == 0) begin
      return 0;
    end
    next_accum = longint'(accum_ppm) + longint'(rate_ppm);
    accum_ppm = int'(next_accum % 1000000);
    return int'(next_accum / 1000000);
  endfunction

  function automatic int unsigned sample_cluster_size(ref bit [31:0] state);
    int unsigned span;

    if (cluster_size_max <= cluster_size_min) begin
      return cluster_size_min;
    end
    span = cluster_size_max - cluster_size_min + 1;
    return cluster_size_min + (next_rng(state) % span);
  endfunction

  function automatic real burstiness_to_mean_batch();
    real b;
    real cv;

    b = burstiness_milli / 1000.0;
    if (b < 0.0) begin
      return 1.0;
    end
    if (b > 0.999) begin
      b = 0.999;
    end
    cv = (1.0 + b) / (1.0 - b);
    return 0.5 * ((cv * cv) + 1.0);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [31:0] lane_rng[OPQ_N_LANE];
    bit [47:0] ts_step;
    int unsigned frame_period_cycles;
    int unsigned active_noise_rho_ppm;
    int unsigned active_cluster_rho_ppm;
    int unsigned active_periodic_rho_ppm;
    int unsigned active_cluster_event_ppm;
    int unsigned active_cluster_min;
    int unsigned active_cluster_max;
    int unsigned lane_noise_hits[OPQ_N_LANE];
    int unsigned lane_cluster_hits[OPQ_N_LANE];
    int unsigned lane_cluster_events[OPQ_N_LANE];
    int unsigned lane_periodic_accum_ppm[OPQ_N_LANE];

    if (subheaders_per_frame == 0) begin
      subheaders_per_frame = 1;
    end
    if (subheaders_per_frame > OPQ_N_SHD) begin
      subheaders_per_frame = OPQ_N_SHD;
    end
    if (cluster_size_min == 0) begin
      cluster_size_min = 1;
    end
    if (cluster_size_max < cluster_size_min) begin
      cluster_size_max = cluster_size_min;
    end

    active_noise_rho_ppm = noise_rho_ppm;
    active_cluster_rho_ppm = cluster_rho_ppm;
    active_periodic_rho_ppm = 0;
    active_cluster_min = cluster_size_min;
    active_cluster_max = cluster_size_max;
    if ((active_noise_rho_ppm == 0) && (active_cluster_rho_ppm == 0)) begin
      if (burstiness_milli <= 0) begin
        active_noise_rho_ppm = total_rho_ppm;
      end else begin
        real mean_batch;
        int unsigned rounded_batch;

        mean_batch = burstiness_to_mean_batch();
        rounded_batch = int'($rtoi(mean_batch + 0.5));
        if (rounded_batch < 1) begin
          rounded_batch = 1;
        end
        active_cluster_min = rounded_batch;
        active_cluster_max = rounded_batch;
        active_cluster_rho_ppm = total_rho_ppm;
      end
    end
    if ((burstiness_milli < 0) && (active_cluster_rho_ppm == 0)) begin
      int unsigned periodic_milli;
      longint unsigned periodic_rho_wide;

      periodic_milli = int'(-burstiness_milli);
      if (periodic_milli > 1000) begin
        periodic_milli = 1000;
      end
      periodic_rho_wide = (longint'(active_noise_rho_ppm) * longint'(periodic_milli)) / 1000;
      active_periodic_rho_ppm = int'(periodic_rho_wide);
      active_noise_rho_ppm -= active_periodic_rho_ppm;
    end

    begin
      real cluster_mean;
      cluster_mean = 0.5 * real'(active_cluster_min + active_cluster_max);
      if ((active_cluster_rho_ppm != 0) && (cluster_mean > 0.0)) begin
        active_cluster_event_ppm = int'($rtoi((active_cluster_rho_ppm / cluster_mean) + 0.5));
      end else begin
        active_cluster_event_ppm = 0;
      end
    end

    ts_step = OPQ_FRAME_DURATION_TS_TICKS;
    frame_period_cycles = (inter_frame_gap_cycles == 0)
      ? OPQ_FRAME_DURATION_SWB_CYCLES
      : inter_frame_gap_cycles;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      lane_rng[lane] = rng_seed ^ (32'h9E37_79B9 * (lane + 1));
      lane_noise_hits[lane] = 0;
      lane_cluster_hits[lane] = 0;
      lane_cluster_events[lane] = 0;
      lane_periodic_accum_ppm[lane] = (active_periodic_rho_ppm == 0)
        ? 0
        : int'(next_rng(lane_rng[lane]) % 1000000);
    end

    `uvm_info(get_type_name(), $sformatf(
      "TIMESTAMP_BURST_CONFIG n_lane=%0d frame_count=%0d subheaders_per_frame=%0d total_rho_ppm=%0d noise_rho_ppm=%0d periodic_rho_ppm=%0d cluster_rho_ppm=%0d cluster_event_ppm=%0d cluster_size_min=%0d cluster_size_max=%0d burstiness_milli=%0d independent_lanes=1 seed=%0d frame_ts_step_ticks=%0d frame_launch_period_cycles=%0d feb_header_latency_cycles=%0d",
      OPQ_N_LANE,
      frame_count,
      subheaders_per_frame,
      total_rho_ppm,
      active_noise_rho_ppm,
      active_periodic_rho_ppm,
      active_cluster_rho_ppm,
      active_cluster_event_ppm,
      active_cluster_min,
      active_cluster_max,
      burstiness_milli,
      rng_seed,
      OPQ_FRAME_DURATION_TS_TICKS,
      frame_period_cycles,
      OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES
    ), UVM_LOW)

    for (int unsigned frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        int unsigned hit_counts[$];
        int unsigned pre_gap_cycles;
        bit [31:0] payload_seed;

        for (int unsigned shd_idx = 0; shd_idx < subheaders_per_frame; shd_idx++) begin
          int unsigned noise_hits;
          int unsigned periodic_hits;
          int unsigned cluster_events;
          int unsigned total_hits;

          periodic_hits = sample_periodic_ppm(active_periodic_rho_ppm, lane_periodic_accum_ppm[lane]);
          noise_hits = periodic_hits + sample_poisson_ppm(active_noise_rho_ppm, lane_rng[lane]);
          cluster_events = sample_poisson_ppm(active_cluster_event_ppm, lane_rng[lane]);
          total_hits = noise_hits;
          lane_noise_hits[lane] += noise_hits;
          lane_cluster_events[lane] += cluster_events;
          for (int unsigned event_idx = 0; event_idx < cluster_events; event_idx++) begin
            int unsigned cluster_hits;

            cluster_hits = sample_cluster_size(lane_rng[lane]);
            total_hits += cluster_hits;
            lane_cluster_hits[lane] += cluster_hits;
          end
          hit_counts.push_back(total_hits);
        end

        pre_gap_cycles = 0;
        payload_seed = 32'hA000_0000 + (lane << 24) + (frame_idx << 8);
        lane_frames[lane].push_back(build_timestamp_hit_count_frame(
          $sformatf("lane%0d_timestamp_burst_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          0,
          pre_gap_cycles,
          hit_counts,
          payload_seed
        ));
        lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
        lane_frames[lane][lane_frames[lane].size()-1].feb_id = (lane < 2) ? 16'h0001 : 16'h0002;
      end
    end

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      `uvm_info(get_type_name(), $sformatf(
        "TIMESTAMP_BURST_COUNTS lane=%0d noise_hits=%0d cluster_hits=%0d cluster_events=%0d total_hits=%0d",
        lane,
        lane_noise_hits[lane],
        lane_cluster_hits[lane],
        lane_cluster_events[lane],
        lane_noise_hits[lane] + lane_cluster_hits[lane]
      ), UVM_LOW)
    end

    apply_absolute_frame_period_schedule(lane_frames, frame_period_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_per_lane_skew_sweep_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_per_lane_skew_sweep_virtual_sequence)

  int unsigned frame_count_per_phase;
  int unsigned subheaders_per_frame;
  int unsigned hit_period;
  int unsigned hit_count_when_active;
  int unsigned inter_frame_gap_cycles;
  int unsigned sweep_phase_count;
  int unsigned max_extra_gap_cycles;

  function new(string name = "opq_per_lane_skew_sweep_virtual_sequence");
    super.new(name);
    frame_count_per_phase = 6;
    subheaders_per_frame = OPQ_N_SHD;
    hit_period = 4;
    hit_count_when_active = 2;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    sweep_phase_count = 4;
    max_extra_gap_cycles = (OPQ_N_SHD * 16) / 2;
  endfunction

  function automatic int unsigned lane_gap_cycles(
    int lane,
    int unsigned phase_idx
  );
    int unsigned phase_gap_cycles;

    if ((OPQ_N_LANE <= 1) || (phase_idx == 0) || (max_extra_gap_cycles == 0)) begin
      return 0;
    end
    if (sweep_phase_count == 0) begin
      phase_gap_cycles = max_extra_gap_cycles;
    end else begin
      phase_gap_cycles = (max_extra_gap_cycles * phase_idx) / sweep_phase_count;
    end
    return (phase_gap_cycles * lane) / (OPQ_N_LANE - 1);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;
    int unsigned phase_count;
    int unsigned global_frame_idx;

    ts_step = OPQ_N_SHD * 16;
    phase_count = sweep_phase_count + 1;
    global_frame_idx = 0;

    for (int unsigned phase_idx = 0; phase_idx < phase_count; phase_idx++) begin
      for (int unsigned frame_idx = 0; frame_idx < frame_count_per_phase; frame_idx++) begin
        for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
          int unsigned pre_gap_cycles;
          int unsigned frame_hit_count;
          int unsigned lane_extra_gap_cycles;
          int unsigned shd_ts_base;
          bit [31:0] first_seed;
          bit [31:0] second_seed;
          int unsigned feb_id;

          lane_extra_gap_cycles = lane_gap_cycles(lane, phase_idx);
          pre_gap_cycles = (global_frame_idx == 0) ? lane_extra_gap_cycles
                                                   : inter_frame_gap_cycles + lane_extra_gap_cycles;
          if (hit_period == 0) begin
            frame_hit_count = hit_count_when_active;
          end else begin
            frame_hit_count = (((global_frame_idx + lane) % hit_period) == 0)
                            ? hit_count_when_active : 0;
          end
          shd_ts_base = (global_frame_idx + lane + 1) % OPQ_N_SHD;
          first_seed = 32'h5300_0000 + (lane * 32'h0100_0000) + (phase_idx << 8) + frame_idx;
          second_seed = 32'h6300_0000 + (lane * 32'h0100_0000) + (phase_idx << 8) + frame_idx;
          feb_id = (lane < 2) ? 16'h0001 : 16'h0002;

          lane_frames[lane].push_back(build_frame(
            $sformatf("lane%0d_phase%0d_skew_%0d", lane, phase_idx, frame_idx),
            lane,
            ts_step * global_frame_idx,
            global_frame_idx[15:0],
            subheaders_per_frame,
            shd_ts_base,
            pre_gap_cycles,
            first_seed,
            second_seed,
            frame_hit_count
          ));
          lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
          lane_frames[lane][lane_frames[lane].size()-1].feb_id = feb_id[15:0];
        end
        global_frame_idx++;
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_missing_empty_frame_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_missing_empty_frame_virtual_sequence)

  int unsigned lane_frame_count[OPQ_N_LANE];
  int unsigned subheaders_per_frame;
  int unsigned hit_period;
  int unsigned hit_count_when_active;
  int unsigned inter_frame_gap_cycles;
  int unsigned lane_extra_gap_cycles[OPQ_N_LANE];

  function new(string name = "opq_missing_empty_frame_virtual_sequence");
    super.new(name);
    subheaders_per_frame = OPQ_N_SHD;
    hit_period = 4;
    hit_count_when_active = 2;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      lane_frame_count[lane] = 2;
      lane_extra_gap_cycles[lane] = lane * 32;
    end
    if (OPQ_N_LANE >= 4) begin
      lane_frame_count[0] = 2;
      lane_frame_count[1] = 6;
      lane_frame_count[2] = 2;
      lane_frame_count[3] = 4;
    end
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int unsigned feb_id;
      feb_id = (lane < 2) ? 16'h0001 : 16'h0002;
      for (int frame_idx = 0; frame_idx < lane_frame_count[lane]; frame_idx++) begin
        int unsigned pre_gap_cycles;
        int unsigned frame_hit_count;
        bit [31:0] first_seed;
        bit [31:0] second_seed;

        pre_gap_cycles = (frame_idx == 0) ? lane_extra_gap_cycles[lane]
                                          : inter_frame_gap_cycles + lane_extra_gap_cycles[lane];
        frame_hit_count = (((frame_idx + lane) % hit_period) == 0) ? hit_count_when_active : 0;
        first_seed = 32'h7100_0000 + (lane * 32'h0100_0000) + frame_idx;
        second_seed = 32'h7200_0000 + (lane * 32'h0100_0000) + frame_idx;

        lane_frames[lane].push_back(build_frame(
          $sformatf("lane%0d_missing_idle_%0d", lane, frame_idx), lane,
          ts_step * frame_idx, frame_idx[15:0], subheaders_per_frame,
          (frame_idx + lane + 1) % OPQ_N_SHD, pre_gap_cycles,
          first_seed, second_seed, frame_hit_count
        ));
        lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
        lane_frames[lane][lane_frames[lane].size()-1].feb_id = feb_id[15:0];
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_stress_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_stress_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned hit_count;
  int unsigned inter_frame_gap_cycles;
  int unsigned lane1_extra_gap_cycles;

  function new(string name = "opq_stress_virtual_sequence");
    super.new(name);
    frame_count = 6;
    subheaders_per_frame = 4;
    hit_count = 2;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    lane1_extra_gap_cycles = 32;
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned gap0;
      int unsigned gap1;
      gap0 = (frame_idx == 0) ? 0 : inter_frame_gap_cycles;
      gap1 = (frame_idx == 0) ? 0 : inter_frame_gap_cycles + lane1_extra_gap_cycles;

      lane0_frames.push_back(build_frame(
        $sformatf("lane0_stress_%0d", frame_idx),
        0,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        (frame_idx + 1) % 256,
        gap0,
        32'h1000_0000 + frame_idx,
        32'h2000_0000 + frame_idx,
        hit_count
      ));
      lane1_frames.push_back(build_frame(
        $sformatf("lane1_stress_%0d", frame_idx),
        1,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        (frame_idx + 1) % 256,
        gap1,
        32'h3000_0000 + frame_idx,
        32'h4000_0000 + frame_idx,
        hit_count
      ));
    end

    foreach (lane0_frames[i]) lane_frames[0].push_back(lane0_frames[i]);
    foreach (lane1_frames[i]) lane_frames[1].push_back(lane1_frames[i]);
    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    lane0_frames.delete();
    lane1_frames.delete();
    for (int i = 0; i < lane_frames[0].size(); i++) lane0_frames.push_back(lane_frames[0][i]);
    for (int i = 0; i < lane_frames[1].size(); i++) lane1_frames.push_back(lane_frames[1][i]);
    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_subheader_shape_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_subheader_shape_virtual_sequence)

  function new(string name = "opq_subheader_shape_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] pair_hits[$];
    bit [31:0] burst_hits[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    pair_hits = {32'h7F10_0001, 32'h7F10_0002};
    burst_hits.delete();
    for (int hit_idx = 0; hit_idx < 32; hit_idx++) begin
      burst_hits.push_back(32'h7F20_0000 + hit_idx);
    end

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_pair_ts7f", 0, 48'd0, 16'd0, 8'h7F, 0, pair_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_burst_ts7f", 1, 48'd0, 16'd0, 8'h7F, 0, burst_hits
    ));

    pair_hits = {32'h8010_0001, 32'h8010_0002};
    burst_hits.delete();
    for (int hit_idx = 0; hit_idx < 32; hit_idx++) begin
      burst_hits.push_back(32'h8020_0000 + hit_idx);
    end

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_pair_ts80", 0, ts_step, 16'd1, 8'h80, OPQ_MIN_SOP_GAP_CYCLES, pair_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_burst_ts80", 1, ts_step, 16'd1, 8'h80, OPQ_MIN_SOP_GAP_CYCLES, burst_hits
    ));

    pair_hits = {32'hFE10_0001, 32'hFE10_0002};
    burst_hits.delete();
    for (int hit_idx = 0; hit_idx < 32; hit_idx++) begin
      burst_hits.push_back(32'hFE20_0000 + hit_idx);
    end

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_pair_tsfe", 0, ts_step * 2, 16'd2, 8'hFE, OPQ_MIN_SOP_GAP_CYCLES, pair_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_burst_tsfe", 1, ts_step * 2, 16'd2, 8'hFE, OPQ_MIN_SOP_GAP_CYCLES, burst_hits
    ));

    pair_hits = {32'hFF10_0001, 32'hFF10_0002};
    burst_hits.delete();
    for (int hit_idx = 0; hit_idx < 32; hit_idx++) begin
      burst_hits.push_back(32'hFF20_0000 + hit_idx);
    end

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_pair_tsff", 0, ts_step * 3, 16'd3, 8'hFF, OPQ_MIN_SOP_GAP_CYCLES, pair_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_burst_tsff", 1, ts_step * 3, 16'd3, 8'hFF, OPQ_MIN_SOP_GAP_CYCLES, burst_hits
    ));

    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_single_lane_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_single_lane_virtual_sequence)

  int unsigned active_lane;
  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned hit_count;
  int unsigned inter_frame_gap_cycles;
  bit          drive_idle_frame_cadence;

  function new(string name = "opq_single_lane_virtual_sequence");
    super.new(name);
    active_lane = 0;
    frame_count = 4;
    subheaders_per_frame = 8;
    hit_count = 8;
    inter_frame_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES;
    drive_idle_frame_cadence = 1'b1;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    if (active_lane >= OPQ_N_LANE) begin
      `uvm_fatal(get_type_name(), $sformatf(
        "opq_single_lane_virtual_sequence active_lane=%0d out of range",
        active_lane
      ))
    end

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      opq_frame_item tr;
      int unsigned pre_gap_cycles;
      int unsigned shd_ts_base;

      pre_gap_cycles = (frame_idx == 0) ? 0 : inter_frame_gap_cycles;
      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;
      tr = build_dense_frame(
        $sformatf("lane%0d_single_%0d", active_lane, frame_idx),
        active_lane,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        shd_ts_base,
        pre_gap_cycles,
        hit_count,
        32'h7800_0000 + (active_lane << 20) + frame_idx
      );
      lane_frames[active_lane].push_back(tr);

      if (drive_idle_frame_cadence) begin
        for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
          opq_frame_item idle_tr;

          if (lane == active_lane) begin
            continue;
          end
          idle_tr = build_frame(
            $sformatf("lane%0d_idle_%0d", lane, frame_idx),
            lane,
            ts_step * frame_idx,
            frame_idx[15:0],
            subheaders_per_frame,
            shd_ts_base,
            pre_gap_cycles,
            '0,
            '0,
            0
          );
          lane_frames[lane].push_back(idle_tr);
        end
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_masked_drop_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_masked_drop_virtual_sequence)

  function new(string name = "opq_masked_drop_virtual_sequence");
    super.new(name);
  endfunction

  virtual function bit continuous_frame_emits_egress_frames();
    // Lane-masked frames still consume composed ingress identity in
    // no-restart tests; otherwise the next legal frame reuses the same
    // pkg_cnt/frame_ts window and aliases drop accounting.
    return 1'b1;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];

      lane_hits = {
        32'hA000_0002 + (lane * 32'h0100_0000),
        32'hA000_0001 + (lane * 32'h0100_0000)
      };
      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_masked", lane),
        lane,
        48'd0,
        16'd0,
        8'h01,
        0,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_single_hit_masked_drop_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_single_hit_masked_drop_virtual_sequence)

  function new(string name = "opq_single_hit_masked_drop_virtual_sequence");
    super.new(name);
  endfunction

  virtual function bit continuous_frame_emits_egress_frames();
    return 1'b1;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];

      lane_hits = {
        32'hA100_0001 + (lane * 32'h0100_0000)
      };
      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_masked_single", lane),
        lane,
        48'd0,
        16'd0,
        8'h01,
        0,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_single_subheader_empty_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_single_subheader_empty_virtual_sequence)

  function new(string name = "opq_single_subheader_empty_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [31:0] empty_hits[$];

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_single_empty", lane),
        lane,
        48'd0,
        16'd0,
        8'h01,
        0,
        empty_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_burst_masked_drop_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_burst_masked_drop_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned hit_count_per_subheader;

  function new(string name = "opq_burst_masked_drop_virtual_sequence");
    super.new(name);
    frame_count = 3;
    subheaders_per_frame = 4;
    hit_count_per_subheader = 8;
  endfunction

  virtual function bit continuous_frame_emits_egress_frames();
    return 1'b1;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
        int unsigned pre_gap_cycles;
        int unsigned shd_ts_base;
        bit [31:0] seed_base;

        pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
        shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;
        seed_base = 32'h7A00_0000 + (lane * 32'h0100_0000) + frame_idx;

        lane_frames[lane].push_back(build_dense_frame(
          $sformatf("lane%0d_masked_burst_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          subheaders_per_frame,
          shd_ts_base,
          pre_gap_cycles,
          hit_count_per_subheader,
          seed_base
        ));
      end
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_header_error_recovery_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_header_error_recovery_virtual_sequence)

  function new(string name = "opq_header_error_recovery_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];
      opq_frame_item bad_frame;

      lane_hits = {
        32'h7C00_0001 + (lane * 32'h0001_0000),
        32'h7C00_0002 + (lane * 32'h0001_0000)
      };

      bad_frame = build_frame($sformatf("lane%0d_hdr_err", lane), lane, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
      bad_frame.preamble_error_bits = 3'b100;
      bad_frame.omit_trailer = 1'b1;
      bad_frame.suppress_scoreboard_frame = 1'b1;
      lane_frames[lane].push_back(bad_frame);

      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_hdr_recovery", lane),
        lane,
        ts_step,
        16'd1,
        8'h01,
        0,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_header_word_error_recovery_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_header_word_error_recovery_virtual_sequence)

  function new(string name = "opq_header_word_error_recovery_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];
      opq_frame_item bad_frame;

      lane_hits = {
        32'h7C10_0001 + (lane * 32'h0001_0000),
        32'h7C10_0002 + (lane * 32'h0001_0000)
      };

      bad_frame = build_frame($sformatf("lane%0d_hdr_word_err", lane), lane, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
      bad_frame.data_header1_error_bits = 3'b100;
      lane_frames[lane].push_back(bad_frame);

      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_hdr_word_recovery", lane),
        lane,
        ts_step,
        16'd1,
        8'h01,
        OPQ_MIN_SOP_GAP_CYCLES,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_subheader_error_recovery_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_subheader_error_recovery_virtual_sequence)

  function new(string name = "opq_subheader_error_recovery_virtual_sequence");
    super.new(name);
  endfunction

  function automatic opq_frame_item build_subheader_error_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    int unsigned pre_gap_cycles
  );
    opq_frame_item tr;
    opq_subheader_desc bad_shd;
    opq_subheader_desc good_shd;
    opq_hit_desc bad_hit;

    tr = opq_frame_item::type_id::create(name);
    tr.lane_id = lane_id;
    tr.channel = lane_to_channel(lane_id);
    tr.frame_ts = frame_ts;
    tr.pkg_cnt = pkg_cnt;
    tr.pre_gap_cycles = pre_gap_cycles;

    bad_shd = opq_subheader_desc::type_id::create({name, "_bad_shd"});
    bad_shd.shd_ts = 8'h01;
    bad_shd.error_bits = 3'b010;
    bad_hit = opq_hit_desc::type_id::create({name, "_bad_shd_hit0"});
    bad_hit.payload_word = 32'h7E80_0000 + lane_id;
    bad_hit.debug_hit_id = next_debug_hit_id;
    next_debug_hit_id++;
    bad_shd.hits.push_back(bad_hit);
    tr.subheaders.push_back(bad_shd);

    good_shd = opq_subheader_desc::type_id::create({name, "_good_shd"});
    good_shd.shd_ts = 8'h02;
    tr.subheaders.push_back(good_shd);

    return finalize_frame_item(tr, pkg_cnt);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];

      lane_hits = {32'h7E00_0001 + (lane * 32'h0001_0000)};
      lane_frames[lane].push_back(build_subheader_error_frame(
        $sformatf("lane%0d_shd_err", lane),
        lane,
        48'd0,
        16'd0,
        0
      ));

      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_shd_recovery", lane),
        lane,
        ts_step,
        16'd1,
        8'h03,
        OPQ_MIN_SOP_GAP_CYCLES,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_hit_error_recovery_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_hit_error_recovery_virtual_sequence)

  function new(string name = "opq_hit_error_recovery_virtual_sequence");
    super.new(name);
  endfunction

  function automatic opq_frame_item build_hit_error_frame(
    string name,
    int lane_id,
    bit [47:0] frame_ts,
    bit [15:0] pkg_cnt,
    bit [7:0] shd_ts,
    int unsigned pre_gap_cycles,
    bit mask_last_hit
  );
    opq_frame_item tr;
    bit [31:0] hit_words[$];
    int hit_idx;

    hit_words = {
      32'h7A00_1000 + lane_id,
      32'h7A00_2000 + lane_id
    };
    tr = build_single_subheader_frame(
      name,
      lane_id,
      frame_ts,
      pkg_cnt,
      shd_ts,
      pre_gap_cycles,
      hit_words
    );
    if (mask_last_hit) begin
      hit_idx = tr.subheaders[0].hits.size() - 1;
    end else begin
      hit_idx = 0;
    end
    tr.subheaders[0].hits[hit_idx].error_bits = 3'b001;
    return tr;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] lane_hits[$];

      lane_hits = {
        32'h7A10_0001 + (lane * 32'h0001_0000),
        32'h7A10_0002 + (lane * 32'h0001_0000)
      };

      lane_frames[lane].push_back(build_hit_error_frame(
        $sformatf("lane%0d_hit_err_%s", lane, lane[0] ? "last" : "first"),
        lane,
        48'd0,
        16'd0,
        8'h01,
        0,
        lane[0]
      ));

      lane_frames[lane].push_back(build_single_subheader_frame(
        $sformatf("lane%0d_hit_recovery", lane),
        lane,
        ts_step,
        16'd1,
        8'h03,
        OPQ_MIN_SOP_GAP_CYCLES,
        lane_hits
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_soak_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_soak_virtual_sequence)

  int unsigned frame_count;

  function new(string name = "opq_soak_virtual_sequence");
    super.new(name);
    frame_count = 6;
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned subheader_count;
      int unsigned shd_ts_base;
      int unsigned pre_gap_cycles;
      bit [31:0] lane0_hit0;
      bit [31:0] lane0_hit1;
      bit [31:0] lane1_hit0;
      bit [31:0] lane1_hit1;
      int unsigned hit_count;

      subheader_count = (frame_idx == 0) ? (OPQ_N_SHD - 1) : OPQ_N_SHD;
      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;
      pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
      hit_count = ((frame_idx % 3) == 0) ? 2 : 0;
      lane0_hit0 = 32'h1000_0000 + frame_idx;
      lane0_hit1 = 32'h2000_0000 + frame_idx;
      lane1_hit0 = 32'h3000_0000 + frame_idx;
      lane1_hit1 = 32'h4000_0000 + frame_idx;

      lane0_frames.push_back(build_frame(
        $sformatf("lane0_soak_%0d", frame_idx),
        0,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheader_count,
        shd_ts_base,
        pre_gap_cycles,
        lane0_hit0,
        lane0_hit1,
        hit_count
      ));
      lane1_frames.push_back(build_frame(
        $sformatf("lane1_soak_%0d", frame_idx),
        1,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheader_count,
        shd_ts_base,
        pre_gap_cycles,
        lane1_hit0,
        lane1_hit1,
        hit_count
      ));
      lane0_frames[lane0_frames.size()-1].whole_frame_packet = 1'b1;
      lane1_frames[lane1_frames.size()-1].whole_frame_packet = 1'b1;
      lane0_frames[lane0_frames.size()-1].feb_id = 16'h0001;
      lane1_frames[lane1_frames.size()-1].feb_id = 16'h0001;
    end

    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_drr_saturation_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_drr_saturation_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned hit_count_per_subheader;

  function new(string name = "opq_drr_saturation_virtual_sequence");
    super.new(name);
    frame_count = 4;
    subheaders_per_frame = 8;
    hit_count_per_subheader = 32;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned pre_gap_cycles;
      int unsigned shd_ts_base;

      pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;

      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        lane_frames[lane].push_back(build_dense_frame(
          $sformatf("lane%0d_drr_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          subheaders_per_frame,
          shd_ts_base,
          pre_gap_cycles,
          hit_count_per_subheader,
          32'h7600_0000 + (lane * 32'h0010_0000) + frame_idx
        ));
        lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
        lane_frames[lane][lane_frames[lane].size()-1].feb_id = 16'h0001;
      end
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_drr_bursty_random_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_drr_bursty_random_virtual_sequence)

  rand int unsigned hot_lane;
  rand int unsigned frame_count;
  rand int unsigned subheaders_per_frame;
  rand int unsigned hot_hits_per_subheader;
  rand int unsigned cold_hits_per_subheader;
  rand int unsigned hot_gap_cycles;
  rand int unsigned cold_gap_cycles;

  constraint c_hot_lane { hot_lane < OPQ_N_LANE; }
  constraint c_frame_count { frame_count inside {[4:8]}; }
  constraint c_subheaders { subheaders_per_frame inside {[8:16]}; }
  constraint c_hot_hits { hot_hits_per_subheader inside {[24:48]}; }
  constraint c_cold_hits { cold_hits_per_subheader inside {[1:8]}; }
  constraint c_gap_hot { hot_gap_cycles inside {0, 8, 16}; }
  constraint c_gap_cold {
    cold_gap_cycles inside {
      OPQ_MIN_SOP_GAP_CYCLES,
      OPQ_MIN_SOP_GAP_CYCLES + 32,
      OPQ_MIN_SOP_GAP_CYCLES + 128
    };
  }

  function new(string name = "opq_drr_bursty_random_virtual_sequence");
    super.new(name);
    hot_lane = 0;
    frame_count = 6;
    subheaders_per_frame = 8;
    hot_hits_per_subheader = 32;
    cold_hits_per_subheader = 4;
    hot_gap_cycles = 0;
    cold_gap_cycles = OPQ_MIN_SOP_GAP_CYCLES + 32;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned shd_ts_base;
      int unsigned lane_gap_cycles;
      int unsigned lane_hits_per_subheader;

      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;

      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        lane_gap_cycles = (frame_idx == 0) ? 0 : ((hot_lane == lane) ? hot_gap_cycles : cold_gap_cycles);
        lane_hits_per_subheader = (hot_lane == lane) ? hot_hits_per_subheader : cold_hits_per_subheader;

        lane_frames[lane].push_back(build_dense_frame(
          $sformatf("lane%0d_drr_rand_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          subheaders_per_frame,
          shd_ts_base,
          lane_gap_cycles,
          lane_hits_per_subheader,
          32'h7600_8000 + (lane * 32'h0010_0000) + frame_idx
        ));
      end
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_boundary_ts_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_boundary_ts_virtual_sequence)

  function new(string name = "opq_boundary_ts_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [7:0] lane0_shd_ts[$];
    bit [7:0] lane1_shd_ts[$];
    bit [31:0] lane0_hit_words[$];
    bit [31:0] lane1_hit_words[$];
    bit [47:0] ts_step;
    int unsigned shd_mid;
    int unsigned shd_late;
    int unsigned shd_last;

    ts_step = OPQ_N_SHD * 16;
    shd_last = OPQ_N_SHD - 1;
    shd_mid = shd_last / 2;
    shd_late = (OPQ_N_SHD + shd_last) / 2;

    lane0_shd_ts = {8'(0), 8'(shd_mid)};
    lane0_hit_words = {32'h7000_0000, 32'h7000_0000 + 32'(shd_mid)};
    lane1_shd_ts = {8'h01};
    lane1_hit_words = {32'h7100_0001};
    lane0_frames.push_back(build_sparse_frame("lane0_ts_early", 0, 48'd0, 16'd0, 0, lane0_shd_ts, lane0_hit_words));
    lane1_frames.push_back(build_sparse_frame("lane1_ts_early", 1, 48'd0, 16'd0, 0, lane1_shd_ts, lane1_hit_words));

    lane0_shd_ts = {8'(shd_late), 8'(shd_last - 1)};
    lane0_hit_words = {
      32'h7000_0000 + 32'(shd_late),
      32'h7000_0000 + 32'(shd_last - 1)
    };
    lane1_shd_ts = {8'(shd_last)};
    lane1_hit_words = {32'h7100_0000 + 32'(shd_last)};
    lane0_frames.push_back(build_sparse_frame("lane0_ts_late", 0, ts_step, 16'd1, OPQ_MIN_SOP_GAP_CYCLES, lane0_shd_ts, lane0_hit_words));
    lane1_frames.push_back(build_sparse_frame("lane1_ts_late", 1, ts_step, 16'd1, OPQ_MIN_SOP_GAP_CYCLES, lane1_shd_ts, lane1_hit_words));

    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_max_hits_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_max_hits_virtual_sequence)

  function new(string name = "opq_max_hits_virtual_sequence");
    super.new(name);
  endfunction

  function automatic int unsigned distributed_lane_hits(
    int lane,
    int unsigned total_hits
  );
    int unsigned base_hits;
    int unsigned remainder_hits;

    base_hits = total_hits / OPQ_N_LANE;
    remainder_hits = total_hits % OPQ_N_LANE;
    return base_hits + ((int'(lane) < int'(remainder_hits)) ? 1 : 0);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;
    int unsigned warmup_hit_total;
    int unsigned max_hit_total;

    ts_step = OPQ_N_SHD * 16;
    max_hit_total = OPQ_N_HIT;
    if ((16 * OPQ_N_LANE) <= OPQ_N_HIT) begin
      warmup_hit_total = 16 * OPQ_N_LANE;
    end else begin
      warmup_hit_total = (OPQ_N_HIT + 1) / 2;
    end

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      int unsigned warmup_lane_hits;
      int unsigned max_lane_hits;

      warmup_lane_hits = distributed_lane_hits(lane, warmup_hit_total);
      max_lane_hits = distributed_lane_hits(lane, max_hit_total);

      lane_frames[lane].push_back(build_dense_frame(
        $sformatf("lane%0d_hit16", lane),
        lane,
        48'd0,
        16'd0,
        1,
        8'h01,
        0,
        warmup_lane_hits,
        32'h7200_0000 + (lane * 32'h0010_0000)
      ));

      lane_frames[lane].push_back(build_dense_frame(
        $sformatf("lane%0d_hit%0d", lane, max_lane_hits),
        lane,
        ts_step,
        16'd1,
        1,
        abs_shd_ts(ts_step, 2),
        OPQ_MIN_SOP_GAP_CYCLES,
        max_lane_hits,
        32'h7400_0000 + (lane * 32'h0010_0000)
      ));
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_overlimit_one_loss_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_overlimit_one_loss_virtual_sequence)

  function new(string name = "opq_overlimit_one_loss_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];

    lane_frames[0].push_back(build_dense_frame(
      "lane0_hit_limit_plus_one",
      0,
      48'd0,
      16'd0,
      1,
      8'h01,
      OPQ_MIN_SOP_GAP_CYCLES,
      OPQ_N_HIT + 1,
      32'h7600_0000
    ));

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_ftable_overflow_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_ftable_overflow_virtual_sequence)

  int unsigned frame_count;
  int unsigned hit_count_per_subheader;

  function new(string name = "opq_ftable_overflow_virtual_sequence");
    super.new(name);
    frame_count = 6;
    hit_count_per_subheader = OPQ_N_HIT;
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned pre_gap_cycles;
      int unsigned shd_ts_base;

      pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
      shd_ts_base = (frame_idx == 0) ? 0 : frame_idx * OPQ_N_SHD;

      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        lane_frames[lane].push_back(build_dense_frame(
          $sformatf("lane%0d_overflow_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          OPQ_N_SHD,
          shd_ts_base,
          pre_gap_cycles,
          hit_count_per_subheader,
          32'h5000_0000 + (lane * 32'h0010_0000) + frame_idx
        ));
      end
    end

    start_lane_frame_matrix(lane_frames);
  endtask
endclass

class opq_variable_saturation_overflow_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_variable_saturation_overflow_virtual_sequence)

  int unsigned frame_count;
  int unsigned subheaders_per_frame;
  int unsigned min_hit_percent;
  int unsigned max_hit_percent;
  int unsigned hot_lane_min_hit_percent;
  int unsigned hot_lane_count_min;
  int unsigned hot_lane_count_max;
  int unsigned inter_frame_gap_cycles;

  function new(string name = "opq_variable_saturation_overflow_virtual_sequence");
    super.new(name);
    frame_count = 6;
    subheaders_per_frame = (OPQ_N_SHD >= 128) ? 128 : OPQ_N_SHD;
    min_hit_percent = 1;
    max_hit_percent = 80;
    hot_lane_min_hit_percent = 60;
    hot_lane_count_min = 1;
    hot_lane_count_max = (OPQ_N_LANE >= 2) ? 2 : 1;
    inter_frame_gap_cycles = (OPQ_MIN_SOP_GAP_CYCLES >= 8) ? (OPQ_MIN_SOP_GAP_CYCLES / 8) : 1;
  endfunction

  function automatic int unsigned percent_to_hit_count_per_subheader(int unsigned hit_percent);
    int unsigned hit_count;

    if (hit_percent == 0) begin
      return 0;
    end
    hit_count = ((OPQ_N_HIT * hit_percent) + 99) / 100;
    if (hit_count == 0) begin
      hit_count = 1;
    end
    if (hit_count > OPQ_N_HIT) begin
      hit_count = OPQ_N_HIT;
    end
    return hit_count;
  endfunction

  function automatic int unsigned gap_cycles_from_profile(int unsigned gap_profile);
    case (gap_profile)
      0: return 0;
      1: return 4;
      2: return 32;
      3: return 256;
      4: return 2_048;
      5: return 16_384;
      default: return OPQ_MIN_SOP_GAP_CYCLES;
    endcase
  endfunction

  task body();
    opq_frame_item lane_frames[OPQ_N_LANE][$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned hot_lane_start;
      int unsigned hot_lane_span;

      if (!std::randomize(hot_lane_start, hot_lane_span) with {
        hot_lane_start < OPQ_N_LANE;
        hot_lane_span inside {[hot_lane_count_min:hot_lane_count_max]};
        hot_lane_span <= OPQ_N_LANE;
      }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize hot-lane overflow window")
      end
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        int unsigned gap_profile;
        int unsigned hit_percent;
        int unsigned hit_count_per_subheader;
        int unsigned lane_extra_gap_cycles;
        int unsigned pre_gap_cycles;
        int unsigned shd_ts_base;
        bit hot_lane_selected;
        bit [31:0] payload_seed;

        hot_lane_selected = (((lane + OPQ_N_LANE - hot_lane_start) % OPQ_N_LANE) < hot_lane_span);

        if (hot_lane_selected) begin
          if (!std::randomize(hit_percent) with {
            hit_percent inside {[hot_lane_min_hit_percent:max_hit_percent]};
          }) begin
            `uvm_fatal(get_type_name(), "Failed to randomize hot-lane saturation")
          end
        end else begin
          if (!std::randomize(hit_percent) with {
            hit_percent inside {[min_hit_percent:max_hit_percent]};
          }) begin
            `uvm_fatal(get_type_name(), "Failed to randomize lane saturation")
          end
        end
        if (!std::randomize(gap_profile) with { gap_profile inside {[0:5]}; }) begin
          `uvm_fatal(get_type_name(), "Failed to randomize lane skew profile")
        end

        hit_count_per_subheader = percent_to_hit_count_per_subheader(hit_percent);
        lane_extra_gap_cycles = gap_cycles_from_profile(gap_profile);
        pre_gap_cycles = (frame_idx == 0) ? lane_extra_gap_cycles
                                          : inter_frame_gap_cycles + lane_extra_gap_cycles;
        shd_ts_base = (frame_idx == 0) ? ((lane + 1) % OPQ_N_SHD)
                                       : ((frame_idx * OPQ_N_SHD) + lane) % OPQ_N_SHD;
        payload_seed = 32'h8800_0000 + (lane << 20) + (frame_idx << 8) + hit_percent;

        lane_frames[lane].push_back(build_dense_frame(
          $sformatf("lane%0d_sat_%0d", lane, frame_idx),
          lane,
          ts_step * frame_idx,
          frame_idx[15:0],
          subheaders_per_frame,
          shd_ts_base,
          pre_gap_cycles,
          hit_count_per_subheader,
          payload_seed
        ));
        lane_frames[lane][lane_frames[lane].size()-1].whole_frame_packet = 1'b1;
        lane_frames[lane][lane_frames[lane].size()-1].feb_id = (lane < 2) ? 16'h0001 : 16'h0002;
      end
    end

    apply_absolute_frame_slot_schedule(lane_frames, inter_frame_gap_cycles);
    start_lane_frame_matrix(lane_frames);
  endtask
endclass

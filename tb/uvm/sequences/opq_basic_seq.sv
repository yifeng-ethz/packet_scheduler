//------------------------------------------------------------------------------
// IP Name   : opq_basic_seq
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.3 - keep inactive DRR lanes on realistic empty-frame cadence
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
    tr.channel = lane_id[1:0];
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
    tr.channel = lane_id[1:0];
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
    tr.channel = lane_id[1:0];
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
    tr.channel = lane_id[1:0];
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
      foreach (lane_frames[i][j]) begin
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;
    int unsigned smoke_subheaders_per_frame;

    ts_step = OPQ_N_SHD * 16;
    // Keep the BASIC smoke in a no-drop regime even when OPQ_N_SHD scales up.
    smoke_subheaders_per_frame = (OPQ_N_SHD >= 128) ? 128 : OPQ_N_SHD;
    if (smoke_subheaders_per_frame < 2) begin
      smoke_subheaders_per_frame = 2;
    end

    lane0_frames.push_back(build_frame(
      "lane0_pkt0", 0, 48'd0, 16'd0, smoke_subheaders_per_frame - 1, 1, 0,
      32'hDEADBEEF, 32'h0BADBEEF, 2
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt0", 1, 48'd0, 16'd0, smoke_subheaders_per_frame - 1, 1, 0,
      32'hCAFEBABE, 32'h0BADCAFE, 2
    ));

    lane0_frames.push_back(build_frame(
      "lane0_pkt1", 0, ts_step, 16'd1, smoke_subheaders_per_frame, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt1", 1, ts_step, 16'd1, smoke_subheaders_per_frame, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    lane0_frames.push_back(build_frame(
      "lane0_pkt2", 0, ts_step + ts_step, 16'd2, smoke_subheaders_per_frame, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt2", 1, ts_step + ts_step, 16'd2, smoke_subheaders_per_frame, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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

    ts_step = OPQ_N_SHD * 16;

    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      bit [31:0] first_seed;
      bit [31:0] second_seed;
      int unsigned feb_id;

      first_seed = 32'hDEADBEEF ^ (lane * 32'h11110011);
      second_seed = 32'h0BADBEEF ^ (lane * 32'h01010101);
      feb_id = (lane < 2) ? 16'h0001 : 16'h0002;

      lane_frames[lane].push_back(build_frame(
        $sformatf("lane%0d_feb_pkt0", lane), lane, 48'd0, 16'd0,
        OPQ_N_SHD - 1, 1, 0, first_seed, second_seed, 2
      ));
      lane_frames[lane].push_back(build_frame(
        $sformatf("lane%0d_feb_pkt1", lane), lane, ts_step, 16'd1,
        OPQ_N_SHD, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
        '0, '0, 0
      ));
      lane_frames[lane].push_back(build_frame(
        $sformatf("lane%0d_feb_pkt2", lane), lane, ts_step + ts_step, 16'd2,
        OPQ_N_SHD, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
        '0, '0, 0
      ));

      foreach (lane_frames[lane][idx]) begin
        lane_frames[lane][idx].whole_frame_packet = 1'b1;
        lane_frames[lane][idx].feb_id = feb_id[15:0];
      end
    end

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
    foreach (lane_frames[0][i]) lane0_frames.push_back(lane_frames[0][i]);
    foreach (lane_frames[1][i]) lane1_frames.push_back(lane_frames[1][i]);
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] lane0_hits[$];
    bit [31:0] lane1_hits[$];
    bit [47:0] ts_step;
    opq_frame_item bad_frame;

    ts_step = OPQ_N_SHD * 16;
    lane0_hits = {32'h7C00_0001, 32'h7C00_0002};
    lane1_hits = {32'h7D00_0001, 32'h7D00_0002};

    bad_frame = build_frame("lane0_hdr_err", 0, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
    bad_frame.preamble_error_bits = 3'b100;
    bad_frame.omit_trailer = 1'b1;
    bad_frame.suppress_scoreboard_frame = 1'b1;
    lane0_frames.push_back(bad_frame);

    bad_frame = build_frame("lane1_hdr_err", 1, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
    bad_frame.preamble_error_bits = 3'b100;
    bad_frame.omit_trailer = 1'b1;
    bad_frame.suppress_scoreboard_frame = 1'b1;
    lane1_frames.push_back(bad_frame);

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_hdr_recovery", 0, ts_step, 16'd1, 8'h01, 0, lane0_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_hdr_recovery", 1, ts_step, 16'd1, 8'h01, 0, lane1_hits
    ));

    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_header_word_error_recovery_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_header_word_error_recovery_virtual_sequence)

  function new(string name = "opq_header_word_error_recovery_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] lane0_hits[$];
    bit [31:0] lane1_hits[$];
    bit [47:0] ts_step;
    opq_frame_item bad_frame;

    ts_step = OPQ_N_SHD * 16;
    lane0_hits = {32'h7C10_0001, 32'h7C10_0002};
    lane1_hits = {32'h7D10_0001, 32'h7D10_0002};

    bad_frame = build_frame("lane0_hdr_word_err", 0, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
    bad_frame.data_header1_error_bits = 3'b100;
    lane0_frames.push_back(bad_frame);

    bad_frame = build_frame("lane1_hdr_word_err", 1, 48'd0, 16'd0, 0, 0, 0, '0, '0, 0);
    bad_frame.data_header1_error_bits = 3'b100;
    lane1_frames.push_back(bad_frame);

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_hdr_word_recovery", 0, ts_step, 16'd1, 8'h01, OPQ_MIN_SOP_GAP_CYCLES, lane0_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_hdr_word_recovery", 1, ts_step, 16'd1, 8'h01, OPQ_MIN_SOP_GAP_CYCLES, lane1_hits
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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
    tr.channel = lane_id[1:0];
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] lane0_hits[$];
    bit [31:0] lane1_hits[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    lane0_hits = {32'h7E00_0001};
    lane1_hits = {32'h7F00_0001};

    lane0_frames.push_back(build_subheader_error_frame("lane0_shd_err", 0, 48'd0, 16'd0, 0));
    lane1_frames.push_back(build_subheader_error_frame("lane1_shd_err", 1, 48'd0, 16'd0, 0));

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_shd_recovery", 0, ts_step, 16'd1, 8'h03, OPQ_MIN_SOP_GAP_CYCLES, lane0_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_shd_recovery", 1, ts_step, 16'd1, 8'h03, OPQ_MIN_SOP_GAP_CYCLES, lane1_hits
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] lane0_hits[$];
    bit [31:0] lane1_hits[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;
    lane0_hits = {32'h7A10_0001, 32'h7A10_0002};
    lane1_hits = {32'h7B10_0001, 32'h7B10_0002};

    lane0_frames.push_back(build_hit_error_frame(
      "lane0_hit_err_first",
      0,
      48'd0,
      16'd0,
      8'h01,
      0,
      1'b0
    ));
    lane1_frames.push_back(build_hit_error_frame(
      "lane1_hit_err_last",
      1,
      48'd0,
      16'd0,
      8'h01,
      0,
      1'b1
    ));

    lane0_frames.push_back(build_single_subheader_frame(
      "lane0_hit_recovery",
      0,
      ts_step,
      16'd1,
      8'h03,
      OPQ_MIN_SOP_GAP_CYCLES,
      lane0_hits
    ));
    lane1_frames.push_back(build_single_subheader_frame(
      "lane1_hit_recovery",
      1,
      ts_step,
      16'd1,
      8'h03,
      OPQ_MIN_SOP_GAP_CYCLES,
      lane1_hits
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned pre_gap_cycles;
      int unsigned shd_ts_base;

      pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;

      lane0_frames.push_back(build_dense_frame(
        $sformatf("lane0_drr_%0d", frame_idx),
        0,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        shd_ts_base,
        pre_gap_cycles,
        hit_count_per_subheader,
        32'h7600_0000 + frame_idx
      ));
      lane1_frames.push_back(build_dense_frame(
        $sformatf("lane1_drr_%0d", frame_idx),
        1,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        shd_ts_base,
        pre_gap_cycles,
        hit_count_per_subheader,
        32'h7700_0000 + frame_idx
      ));
      lane0_frames[lane0_frames.size()-1].whole_frame_packet = 1'b1;
      lane1_frames[lane1_frames.size()-1].whole_frame_packet = 1'b1;
      lane0_frames[lane0_frames.size()-1].feb_id = 16'h0001;
      lane1_frames[lane1_frames.size()-1].feb_id = 16'h0001;
    end

    start_lane_frames(lane0_frames, lane1_frames);
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned shd_ts_base;
      int unsigned lane0_gap_cycles;
      int unsigned lane1_gap_cycles;
      int unsigned lane0_hits_per_subheader;
      int unsigned lane1_hits_per_subheader;

      shd_ts_base = (frame_idx == 0) ? 1 : frame_idx * OPQ_N_SHD;
      lane0_gap_cycles = (frame_idx == 0) ? 0 : ((hot_lane == 0) ? hot_gap_cycles : cold_gap_cycles);
      lane1_gap_cycles = (frame_idx == 0) ? 0 : ((hot_lane == 1) ? hot_gap_cycles : cold_gap_cycles);
      lane0_hits_per_subheader = (hot_lane == 0) ? hot_hits_per_subheader : cold_hits_per_subheader;
      lane1_hits_per_subheader = (hot_lane == 1) ? hot_hits_per_subheader : cold_hits_per_subheader;

      lane0_frames.push_back(build_dense_frame(
        $sformatf("lane0_drr_rand_%0d", frame_idx),
        0,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        shd_ts_base,
        lane0_gap_cycles,
        lane0_hits_per_subheader,
        32'h7600_8000 + frame_idx
      ));
      lane1_frames.push_back(build_dense_frame(
        $sformatf("lane1_drr_rand_%0d", frame_idx),
        1,
        ts_step * frame_idx,
        frame_idx[15:0],
        subheaders_per_frame,
        shd_ts_base,
        lane1_gap_cycles,
        lane1_hits_per_subheader,
        32'h7700_8000 + frame_idx
      ));
    end

    start_lane_frames(lane0_frames, lane1_frames);
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

    ts_step = OPQ_N_SHD * 16;

    lane0_shd_ts = {8'h00, 8'h7F};
    lane0_hit_words = {32'h7000_0000, 32'h7000_007F};
    lane1_shd_ts = {8'h01};
    lane1_hit_words = {32'h7100_0001};
    lane0_frames.push_back(build_sparse_frame("lane0_ts_early", 0, 48'd0, 16'd0, 0, lane0_shd_ts, lane0_hit_words));
    lane1_frames.push_back(build_sparse_frame("lane1_ts_early", 1, 48'd0, 16'd0, 0, lane1_shd_ts, lane1_hit_words));

    lane0_shd_ts = {8'h80, 8'hFE};
    lane0_hit_words = {32'h7000_0080, 32'h7000_00FE};
    lane1_shd_ts = {8'hFF};
    lane1_hit_words = {32'h7100_00FF};
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

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    lane0_frames.push_back(build_dense_frame(
      "lane0_hit16",
      0,
      48'd0,
      16'd0,
      1,
      8'h01,
      0,
      16,
      32'h7200_0000
    ));
    lane1_frames.push_back(build_dense_frame(
      "lane1_hit16",
      1,
      48'd0,
      16'd0,
      1,
      8'h01,
      0,
      16,
      32'h7300_0000
    ));

    lane0_frames.push_back(build_dense_frame(
      "lane0_hit32",
      0,
      ts_step,
      16'd1,
      1,
      abs_shd_ts(ts_step, 2),
      OPQ_MIN_SOP_GAP_CYCLES,
      32,
      32'h7400_0000
    ));
    lane1_frames.push_back(build_dense_frame(
      "lane1_hit32",
      1,
      ts_step,
      16'd1,
      1,
      abs_shd_ts(ts_step, 2),
      OPQ_MIN_SOP_GAP_CYCLES,
      32,
      32'h7500_0000
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      int unsigned pre_gap_cycles;
      int unsigned shd_ts_base;

      pre_gap_cycles = (frame_idx == 0) ? 0 : OPQ_MIN_SOP_GAP_CYCLES;
      shd_ts_base = (frame_idx == 0) ? 0 : frame_idx * OPQ_N_SHD;

      lane0_frames.push_back(build_dense_frame(
        $sformatf("lane0_overflow_%0d", frame_idx),
        0,
        ts_step * frame_idx,
        frame_idx[15:0],
        OPQ_N_SHD,
        shd_ts_base,
        pre_gap_cycles,
        hit_count_per_subheader,
        32'h5000_0000 + frame_idx
      ));
      lane1_frames.push_back(build_dense_frame(
        $sformatf("lane1_overflow_%0d", frame_idx),
        1,
        ts_step * frame_idx,
        frame_idx[15:0],
        OPQ_N_SHD,
        shd_ts_base,
        pre_gap_cycles,
        hit_count_per_subheader,
        32'h6000_0000 + frame_idx
      ));
    end

    start_lane_frames(lane0_frames, lane1_frames);
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

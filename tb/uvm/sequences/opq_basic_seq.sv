//------------------------------------------------------------------------------
// IP Name   : opq_basic_seq
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - derive absolute subheader timestamps from frame_ts for parameterized sequences
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

  function new(string name = "opq_virtual_sequence_base");
    super.new(name);
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

    return tr;
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
    return tr;
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

    return tr;
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

    return tr;
  endfunction

  task automatic start_lane_frames(ref opq_frame_item lane0_frames[$], ref opq_frame_item lane1_frames[$]);
    opq_lane_frame_sequence lane_seq[OPQ_N_LANE];

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      lane_seq[i] = opq_lane_frame_sequence::type_id::create($sformatf("lane_seq_%0d", i));
    end
    foreach (lane0_frames[i]) lane_seq[0].frames.push_back(lane0_frames[i]);
    foreach (lane1_frames[i]) lane_seq[1].frames.push_back(lane1_frames[i]);

    fork
      lane_seq[0].start(p_sequencer.ingress_seqr[0]);
      lane_seq[1].start(p_sequencer.ingress_seqr[1]);
    join
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

    ts_step = OPQ_N_SHD * 16;

    lane0_frames.push_back(build_frame(
      "lane0_pkt0", 0, 48'd0, 16'd0, OPQ_N_SHD - 1, 1, 0,
      32'hDEADBEEF, 32'h0BADBEEF, 2
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt0", 1, 48'd0, 16'd0, OPQ_N_SHD - 1, 1, 0,
      32'hCAFEBABE, 32'h0BADCAFE, 2
    ));

    lane0_frames.push_back(build_frame(
      "lane0_pkt1", 0, ts_step, 16'd1, OPQ_N_SHD, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt1", 1, ts_step, 16'd1, OPQ_N_SHD, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    lane0_frames.push_back(build_frame(
      "lane0_pkt2", 0, ts_step + ts_step, 16'd2, OPQ_N_SHD, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane1_frames.push_back(build_frame(
      "lane1_pkt2", 1, ts_step + ts_step, 16'd2, OPQ_N_SHD, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    start_lane_frames(lane0_frames, lane1_frames);
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

    start_lane_frames(lane0_frames, lane1_frames);
  endtask
endclass

class opq_masked_drop_virtual_sequence extends opq_virtual_sequence_base;
  `uvm_object_utils(opq_masked_drop_virtual_sequence)

  function new(string name = "opq_masked_drop_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    opq_frame_item lane0_frames[$];
    opq_frame_item lane1_frames[$];
    bit [31:0] lane0_hits[$];
    bit [31:0] lane1_hits[$];

    lane0_hits = {32'hAAAA_0001, 32'hAAAA_0002};
    lane1_hits = {32'hBBBB_0001, 32'hBBBB_0002};

    lane0_frames.push_back(build_single_subheader_frame("lane0_masked", 0, 48'd0, 16'd0, 8'h01, 0, lane0_hits));
    lane1_frames.push_back(build_single_subheader_frame("lane1_masked", 1, 48'd0, 16'd0, 8'h01, 0, lane1_hits));
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

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

class opq_basic_virtual_sequence extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(opq_basic_virtual_sequence)
  `uvm_declare_p_sequencer(opq_virtual_sequencer)

  static bit [63:0] next_debug_hit_id = 64'd1;

  function new(string name = "opq_basic_virtual_sequence");
    super.new(name);
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

  task body();
    opq_lane_frame_sequence lane_seq[OPQ_N_LANE];
    bit [47:0] ts_step;

    ts_step = OPQ_N_SHD * 16;

    for (int i = 0; i < OPQ_N_LANE; i++) begin
      lane_seq[i] = opq_lane_frame_sequence::type_id::create($sformatf("lane_seq_%0d", i));
    end

    lane_seq[0].frames.push_back(build_frame(
      "lane0_pkt0", 0, 48'd0, 16'd0, OPQ_N_SHD - 1, 1, 0,
      32'hDEADBEEF, 32'h0BADBEEF, 2
    ));
    lane_seq[1].frames.push_back(build_frame(
      "lane1_pkt0", 1, 48'd0, 16'd0, OPQ_N_SHD - 1, 1, 0,
      32'hCAFEBABE, 32'h0BADCAFE, 2
    ));

    lane_seq[0].frames.push_back(build_frame(
      "lane0_pkt1", 0, ts_step, 16'd1, OPQ_N_SHD, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane_seq[1].frames.push_back(build_frame(
      "lane1_pkt1", 1, ts_step, 16'd1, OPQ_N_SHD, OPQ_N_SHD, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    lane_seq[0].frames.push_back(build_frame(
      "lane0_pkt2", 0, ts_step + ts_step, 16'd2, OPQ_N_SHD, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));
    lane_seq[1].frames.push_back(build_frame(
      "lane1_pkt2", 1, ts_step + ts_step, 16'd2, OPQ_N_SHD, OPQ_N_SHD * 2, OPQ_MIN_SOP_GAP_CYCLES,
      '0, '0, 0
    ));

    fork
      lane_seq[0].start(p_sequencer.ingress_seqr[0]);
      lane_seq[1].start(p_sequencer.ingress_seqr[1]);
    join
  endtask
endclass

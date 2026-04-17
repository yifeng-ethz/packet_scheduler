//------------------------------------------------------------------------------
// IP Name   : opq_ingress_agent
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - drive frame words through shared packet-format helpers
// Description:
//   Ingress sequencer/driver/monitor for the active OPQ UVM harness.
//------------------------------------------------------------------------------
class opq_ingress_sequencer extends uvm_sequencer #(opq_frame_item);
  `uvm_component_utils(opq_ingress_sequencer)

  function new(string name = "opq_ingress_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class opq_ingress_driver extends uvm_driver #(opq_frame_item);
  `uvm_component_utils(opq_ingress_driver)

  virtual opq_ingress_if vif;
  int lane_id;
  uvm_analysis_port #(opq_frame_item) frame_ap;

  function new(string name = "opq_ingress_driver", uvm_component parent = null);
    super.new(name, parent);
    frame_ap = new("frame_ap", this);
  endfunction

  task automatic clear_bus();
    vif.drv_cb.data <= '0;
    vif.drv_cb.valid <= '0;
    vif.drv_cb.channel <= '0;
    vif.drv_cb.startofpacket <= '0;
    vif.drv_cb.endofpacket <= '0;
    vif.drv_cb.error <= '0;
  endtask

  task automatic wait_cycles(int unsigned cycles);
    repeat (cycles) @(vif.drv_cb);
  endtask

  task automatic wait_reset_release();
    while (vif.reset) begin
      clear_bus();
      @(vif.drv_cb);
    end
    wait_cycles(OPQ_POST_RESET_SETTLE_CYCLES);
  endtask

  task automatic drive_word(
    bit [31:0] data32,
    bit [3:0] datak,
    bit sop,
    bit eop,
    bit [2:0] err_bits,
    bit [1:0] channel
  );
    vif.drv_cb.data <= {datak, data32};
    vif.drv_cb.valid <= '1;
    vif.drv_cb.channel <= channel;
    vif.drv_cb.startofpacket <= sop;
    vif.drv_cb.endofpacket <= eop;
    vif.drv_cb.error <= err_bits;
    @(vif.drv_cb);
    clear_bus();
  endtask

  task automatic drive_frame(opq_frame_item tr);
    wait_reset_release();
    wait_cycles(tr.pre_gap_cycles);

    drive_word(make_preamble(tr.dt_type, tr.feb_id), 4'b0001, 1'b1, 1'b0, tr.preamble_error_bits, tr.channel);
    drive_word(make_frame_data_header0(tr.frame_ts), 4'b0000, 1'b0, 1'b0, tr.data_header0_error_bits, tr.channel);
    drive_word(make_frame_data_header1(tr.frame_ts, tr.pkg_cnt), 4'b0000, 1'b0, 1'b0, tr.data_header1_error_bits, tr.channel);
    drive_word(make_frame_debug_header0(tr.frame_subh_count_bits(), tr.frame_hit_count_bits()),
      4'b0000, 1'b0, 1'b0, tr.debug_header0_error_bits, tr.channel);
    drive_word(make_frame_debug_header1(tr.frame_ts), 4'b0000, 1'b0, 1'b0, tr.debug_header1_error_bits, tr.channel);

    foreach (tr.subheaders[i]) begin
      bit [7:0] hit_cnt;
      hit_cnt = tr.subheaders[i].hit_count();
      drive_word(make_subheader(tr.subheaders[i].shd_ts, hit_cnt), 4'b0001,
        tr.whole_frame_packet ? 1'b0 : 1'b1,
        (tr.whole_frame_packet ? 1'b0 : (hit_cnt == 0)),
        tr.subheaders[i].error_bits, tr.channel);
      foreach (tr.subheaders[i].hits[j]) begin
        drive_word(tr.subheaders[i].hits[j].payload_word, 4'b0000, 1'b0,
          (tr.whole_frame_packet ? 1'b0 : (j == tr.subheaders[i].hits.size() - 1)),
          tr.subheaders[i].hits[j].error_bits, tr.channel);
      end
    end

    if (!tr.omit_trailer) begin
      drive_word(make_trailer(), 4'b0001, 1'b0, 1'b1, 3'b000, tr.channel);
    end
  endtask

  task run_phase(uvm_phase phase);
    opq_frame_item tr;
    opq_frame_item tr_clone;

    clear_bus();
    forever begin
      seq_item_port.get_next_item(tr);
      $cast(tr_clone, tr.clone());
      if (!tr.suppress_scoreboard_frame) begin
        frame_ap.write(tr_clone);
      end
      `uvm_info(get_type_name(), $sformatf("Driving lane %0d frame pkg_cnt=%0d subh=%0d hits=%0d",
        lane_id, tr.pkg_cnt, tr.frame_subh_count_bits(), tr.frame_hit_count_bits()), UVM_MEDIUM)
      drive_frame(tr);
      seq_item_port.item_done();
    end
  endtask
endclass

class opq_ingress_monitor extends uvm_component;
  `uvm_component_utils(opq_ingress_monitor)

  virtual opq_ingress_if vif;
  int lane_id;
  uvm_analysis_port #(opq_beat_item) ap;
  uvm_analysis_port #(opq_frame_item) frame_ap;
  int unsigned beat_count;
  opq_frame_item curr_frame;
  int unsigned header_words_seen;
  int active_subheader_idx;
  int unsigned hit_words_left;
  int unsigned n_frames_captured;
  int unsigned n_frame_capture_err;
  int unsigned n_orphan_beats;

  function new(string name = "opq_ingress_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
    frame_ap = new("frame_ap", this);
    reset_frame_state();
  endfunction

  function automatic void reset_frame_state();
    curr_frame = null;
    header_words_seen = 0;
    active_subheader_idx = -1;
    hit_words_left = 0;
  endfunction

  function automatic bit is_preamble(opq_beat_item beat);
    return (beat.data[35:32] == 4'b0001) && beat.sop && (beat.data[7:0] == K285);
  endfunction

  function automatic bit is_subheader(opq_beat_item beat);
    return (beat.data[35:32] == 4'b0001) && (beat.data[7:0] == K237);
  endfunction

  function automatic bit is_trailer(opq_beat_item beat);
    return (beat.data[35:32] == 4'b0001) && beat.eop && (beat.data[7:0] == K284);
  endfunction

  function automatic bit is_hit_word(opq_beat_item beat);
    return (beat.data[35:32] == 4'b0000);
  endfunction

  function automatic void note_frame_capture_err(string msg);
    n_frame_capture_err++;
    `uvm_warning(get_type_name(), $sformatf("lane%0d frame-capture %s", lane_id, msg))
  endfunction

  function automatic void start_frame(opq_beat_item beat);
    if (curr_frame != null) begin
      note_frame_capture_err("saw a new preamble before trailer; dropping partial frame");
      reset_frame_state();
    end

    curr_frame = opq_frame_item::type_id::create($sformatf("lane%0d_frame_%0d", lane_id, n_frames_captured));
    curr_frame.lane_id = lane_id;
    curr_frame.channel = lane_id[1:0];
    curr_frame.dt_type = beat.data[31:26];
    curr_frame.feb_id = beat.data[23:8];
    curr_frame.whole_frame_packet = 1'b1;
    header_words_seen = 0;
    active_subheader_idx = -1;
    hit_words_left = 0;
  endfunction

  function automatic void emit_frame();
    opq_frame_item frame_clone;

    if (curr_frame == null) begin
      return;
    end
    $cast(frame_clone, curr_frame.clone());
    frame_ap.write(frame_clone);
    n_frames_captured++;
    reset_frame_state();
  endfunction

  function automatic void consume_frame_beat(opq_beat_item beat);
    if (curr_frame == null) begin
      if (is_preamble(beat)) begin
        start_frame(beat);
      end else begin
        n_orphan_beats++;
      end
      return;
    end

    if (is_preamble(beat)) begin
      start_frame(beat);
      return;
    end

    if (header_words_seen < OPQ_FRAME_HDR_AUX_WORDS) begin
      case (header_words_seen)
        0: curr_frame.frame_ts[47:16] = beat.data[31:0];
        1: begin
          curr_frame.frame_ts[15:0] = beat.data[31:16];
          curr_frame.pkg_cnt = beat.data[15:0];
        end
        default: begin
        end
      endcase
      header_words_seen++;
      if (beat.eop) begin
        note_frame_capture_err("frame terminated during header words");
      end
      return;
    end

    if (is_trailer(beat)) begin
      if (hit_words_left != 0) begin
        note_frame_capture_err("trailer arrived while hit payloads were still pending");
      end
      emit_frame();
      return;
    end

    if (is_subheader(beat)) begin
      opq_subheader_desc shd;

      if (hit_words_left != 0) begin
        note_frame_capture_err("new subheader arrived before the previous payload completed");
      end
      shd = opq_subheader_desc::type_id::create(
        $sformatf("lane%0d_shd_%0d", lane_id, curr_frame.subheaders.size())
      );
      shd.shd_ts = beat.data[31:24];
      curr_frame.subheaders.push_back(shd);
      active_subheader_idx = curr_frame.subheaders.size() - 1;
      hit_words_left = beat.data[15:8];
      if (beat.eop) begin
        note_frame_capture_err("subheader asserted eop before trailer");
      end
      return;
    end

    if (is_hit_word(beat)) begin
      opq_hit_desc hit_desc;

      if (hit_words_left == 0 || active_subheader_idx < 0 ||
          active_subheader_idx >= curr_frame.subheaders.size()) begin
        note_frame_capture_err($sformatf("hit beat without active subheader data=0x%09h", beat.data));
        return;
      end
      hit_desc = opq_hit_desc::type_id::create(
        $sformatf("lane%0d_hit_%0d_%0d",
                  lane_id, active_subheader_idx,
                  curr_frame.subheaders[active_subheader_idx].hits.size())
      );
      hit_desc.payload_word = beat.data[31:0];
      curr_frame.subheaders[active_subheader_idx].hits.push_back(hit_desc);
      hit_words_left--;
      if (beat.eop) begin
        note_frame_capture_err("hit beat asserted eop before trailer");
      end
      return;
    end

    n_orphan_beats++;
  endfunction

  task run_phase(uvm_phase phase);
    opq_beat_item beat;

    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.reset && vif.mon_cb.valid[0]) begin
        beat = opq_beat_item::type_id::create("beat");
        beat.lane_id = lane_id;
        beat.data = vif.mon_cb.data;
        beat.sop = vif.mon_cb.startofpacket[0];
        beat.eop = vif.mon_cb.endofpacket[0];
        beat.error = vif.mon_cb.error;
        if (beat_count < 16) begin
          `uvm_info(get_type_name(), $sformatf(
            "lane%0d ingress[%0d] data=0x%09h datak=0x%1h sop=%0b eop=%0b err=0x%0h",
            lane_id, beat_count, beat.data, beat.data[35:32], beat.sop, beat.eop, beat.error
          ), UVM_LOW)
        end
        beat_count++;
        ap.write(beat);
        consume_frame_beat(beat);
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf(
      "lane%0d monitored_frames=%0d orphan_beats=%0d capture_err=%0d",
      lane_id, n_frames_captured, n_orphan_beats, n_frame_capture_err
    ), UVM_LOW)
  endfunction
endclass

class opq_ingress_agent extends uvm_agent;
  `uvm_component_utils(opq_ingress_agent)

  virtual opq_ingress_if vif;
  int lane_id;
  opq_ingress_sequencer seqr;
  opq_ingress_driver drv;
  opq_ingress_monitor mon;

  function new(string name = "opq_ingress_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = opq_ingress_monitor::type_id::create("mon", this);
    mon.vif = vif;
    mon.lane_id = lane_id;
    if (is_active == UVM_ACTIVE) begin
      seqr = opq_ingress_sequencer::type_id::create("seqr", this);
      drv = opq_ingress_driver::type_id::create("drv", this);
      drv.vif = vif;
      drv.lane_id = lane_id;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass

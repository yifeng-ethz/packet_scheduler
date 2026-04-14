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

    drive_word(make_preamble(tr.dt_type, tr.feb_id), 4'b0001, 1'b1, 1'b0, 3'b000, tr.channel);
    drive_word(make_frame_data_header0(tr.frame_ts), 4'b0000, 1'b0, 1'b0, 3'b000, tr.channel);
    drive_word(make_frame_data_header1(tr.frame_ts, tr.pkg_cnt), 4'b0000, 1'b0, 1'b0, 3'b000, tr.channel);
    drive_word(make_frame_debug_header0(tr.frame_subh_count_bits(), tr.frame_hit_count_bits()),
      4'b0000, 1'b0, 1'b0, 3'b000, tr.channel);
    drive_word(make_frame_debug_header1(tr.frame_ts), 4'b0000, 1'b0, 1'b1, 3'b000, tr.channel);

    foreach (tr.subheaders[i]) begin
      bit [7:0] hit_cnt;
      hit_cnt = tr.subheaders[i].hit_count();
      drive_word(make_subheader(tr.subheaders[i].shd_ts, hit_cnt), 4'b0001, 1'b1, (hit_cnt == 0), 3'b000, tr.channel);
      foreach (tr.subheaders[i].hits[j]) begin
        drive_word(tr.subheaders[i].hits[j].payload_word, 4'b0000, 1'b0,
          (j == tr.subheaders[i].hits.size() - 1), 3'b000, tr.channel);
      end
    end

    drive_word(make_trailer(), 4'b0001, 1'b0, 1'b1, 3'b000, tr.channel);
  endtask

  task run_phase(uvm_phase phase);
    opq_frame_item tr;
    opq_frame_item tr_clone;

    clear_bus();
    forever begin
      seq_item_port.get_next_item(tr);
      $cast(tr_clone, tr.clone());
      frame_ap.write(tr_clone);
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
  int unsigned beat_count;

  function new(string name = "opq_ingress_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
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
      end
    end
  endtask
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

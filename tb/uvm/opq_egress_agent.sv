class opq_egress_sequencer extends uvm_sequencer #(opq_bp_item);
  `uvm_component_utils(opq_egress_sequencer)

  function new(string name = "opq_egress_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class opq_egress_driver extends uvm_driver #(opq_bp_item);
  `uvm_component_utils(opq_egress_driver)

  virtual opq_egress_if vif;
  uvm_analysis_port #(opq_bp_item) bp_ap;

  function new(string name = "opq_egress_driver", uvm_component parent = null);
    super.new(name, parent);
    bp_ap = new("bp_ap", this);
  endfunction

  task automatic wait_cycles(int unsigned cycles, bit ready_value);
    repeat (cycles) begin
      vif.drv_cb.ready <= ready_value;
      @(vif.drv_cb);
    end
  endtask

  task automatic apply_item(opq_bp_item item);
    int unsigned repeats;
    int unsigned high_cycles;
    int unsigned low_cycles;

    repeats = (item.repeat_count == 0) ? 1 : item.repeat_count;
    high_cycles = (item.high_cycles == 0) ? 1 : item.high_cycles;
    low_cycles = (item.low_cycles == 0) ? 1 : item.low_cycles;

    case (item.mode)
      BP_ALWAYS_READY: wait_cycles(high_cycles * repeats, 1'b1);
      BP_ALWAYS_STALL: wait_cycles(low_cycles * repeats, 1'b0);
      BP_PERIODIC_STALL: begin
        repeat (repeats) begin
          wait_cycles(high_cycles, 1'b1);
          wait_cycles(low_cycles, 1'b0);
        end
      end
      default: wait_cycles(1, 1'b1);
    endcase
  endtask

  task run_phase(uvm_phase phase);
    opq_bp_item item;
    bit was_in_reset;
    int unsigned settle_cycles;

    vif.drv_cb.ready <= 1'b0;
    was_in_reset = 1'b1;
    settle_cycles = 0;
    forever begin
      @(vif.drv_cb);
      if (vif.drv_cb.reset) begin
        vif.drv_cb.ready <= 1'b0;
        was_in_reset = 1'b1;
        settle_cycles = 0;
      end else begin
        if (was_in_reset) begin
          if (settle_cycles < OPQ_POST_RESET_SETTLE_CYCLES) begin
            vif.drv_cb.ready <= 1'b0;
            settle_cycles++;
            continue;
          end
          was_in_reset = 1'b0;
        end
        item = null;
        seq_item_port.try_next_item(item);
        if (item != null) begin
          opq_bp_item item_clone;
          $cast(item_clone, item.clone());
          bp_ap.write(item_clone);
          apply_item(item);
          vif.drv_cb.ready <= 1'b1;
          seq_item_port.item_done();
        end else begin
          vif.drv_cb.ready <= 1'b1;
        end
      end
    end
  endtask
endclass

class opq_egress_monitor extends uvm_component;
  `uvm_component_utils(opq_egress_monitor)

  virtual opq_egress_if vif;
  uvm_analysis_port #(opq_beat_item) ap;
  int unsigned beat_count;

  function new(string name = "opq_egress_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    opq_beat_item beat;
    bit trace_all_beats;
    longint unsigned trace_after_ps;
    bit trace_after_ps_valid;

    trace_all_beats = $test$plusargs("OPQ_TRACE_EGRESS_ALL");
    trace_after_ps = 0;
    trace_after_ps_valid = $value$plusargs("OPQ_TRACE_AFTER_PS=%d", trace_after_ps);
    if (trace_after_ps_valid) begin
      trace_all_beats = 1'b1;
    end

    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.reset && vif.mon_cb.valid && vif.mon_cb.ready) begin
        beat = opq_beat_item::type_id::create("beat");
        beat.lane_id = -1;
        beat.data = vif.mon_cb.data;
        beat.sop = vif.mon_cb.startofpacket;
        beat.eop = vif.mon_cb.endofpacket;
        beat.error = vif.mon_cb.error;
        if (((trace_all_beats && ($time >= trace_after_ps)) || (beat_count < 64))) begin
          `uvm_info(get_type_name(), $sformatf(
            "egress[%0d] data=0x%09h datak=0x%1h sop=%0b eop=%0b err=0x%0h",
            beat_count, beat.data, beat.data[35:32], beat.sop, beat.eop, beat.error
          ), UVM_LOW)
        end
        beat_count++;
        ap.write(beat);
      end
    end
  endtask
endclass

class opq_egress_agent extends uvm_agent;
  `uvm_component_utils(opq_egress_agent)

  virtual opq_egress_if vif;
  opq_egress_sequencer seqr;
  opq_egress_driver drv;
  opq_egress_monitor mon;

  function new(string name = "opq_egress_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = opq_egress_monitor::type_id::create("mon", this);
    mon.vif = vif;
    if (is_active == UVM_ACTIVE) begin
      seqr = opq_egress_sequencer::type_id::create("seqr", this);
      drv = opq_egress_driver::type_id::create("drv", this);
      drv.vif = vif;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass

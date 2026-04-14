//------------------------------------------------------------------------------
// IP Name   : opq_drop_monitor
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - observe lane-local dropped subheaders for drop-aware scoring
// Description:
//   UVM monitor for internal OPQ drop events exported through a lightweight
//   debug interface in the mixed-language harness.
//------------------------------------------------------------------------------
class opq_drop_monitor extends uvm_component;
  `uvm_component_utils(opq_drop_monitor)

  virtual opq_drop_if #(OPQ_N_LANE) vif;
  uvm_analysis_port #(opq_drop_item) ap;
  int unsigned observed_drop_evt_cnt[OPQ_N_LANE];
  int unsigned observed_drop_hit_cnt[OPQ_N_LANE];

  function new(string name = "opq_drop_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual opq_drop_if #(OPQ_N_LANE))::get(this, "", "drop_vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing drop_vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    opq_drop_item item;

    forever begin
      @(negedge vif.clk);
      if (vif.reset) begin
        continue;
      end
      for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
        if (vif.valid[lane] === 1'b1) begin
          item = opq_drop_item::type_id::create($sformatf("drop_lane%0d", lane), this);
          item.lane_id = lane;
          item.shd_drop_cnt = vif.shd_drop_cnt[lane];
          item.hit_drop_cnt = vif.hit_drop_cnt[lane];
          observed_drop_evt_cnt[lane]++;
          observed_drop_hit_cnt[lane] += item.hit_drop_cnt;
          ap.write(item);
        end
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    for (int lane = 0; lane < OPQ_N_LANE; lane++) begin
      `uvm_info(get_type_name(), $sformatf(
        "lane%0d observed drop events=%0d dropped_hits=%0d",
        lane,
        observed_drop_evt_cnt[lane],
        observed_drop_hit_cnt[lane]
      ), UVM_LOW)
    end
  endfunction
endclass

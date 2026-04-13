class opq_coverage extends uvm_component;
  `uvm_component_utils(opq_coverage)

  uvm_analysis_imp_ingress #(opq_beat_item, opq_coverage) ingress_imp;
  uvm_analysis_imp_egress #(opq_beat_item, opq_coverage) egress_imp;

  covergroup cg_cfg with function sample(int n_lane, int rd_width, int n_shd);
    coverpoint n_lane { bins default_lane = {2}; }
    coverpoint rd_width { bins width36 = {36}; }
    coverpoint n_shd { bins subheader256 = {256}; }
  endgroup

  covergroup cg_ingress with function sample(int lane, bit is_k, bit sop, bit eop, bit [7:0] low_byte);
    coverpoint lane { bins lane0 = {0}; bins lane1 = {1}; }
    coverpoint is_k { bins control = {1}; bins payload = {0}; }
    coverpoint sop { bins seen[] = {0,1}; }
    coverpoint eop { bins seen[] = {0,1}; }
    coverpoint low_byte {
      bins preamble = {K285};
      bins subheader = {K237};
      bins trailer = {K284};
      bins other = default;
    }
  endgroup

  covergroup cg_egress with function sample(bit is_preamble, bit is_hit, bit sop, bit eop, bit [7:0] low_byte);
    coverpoint is_preamble { bins no = {0}; bins yes = {1}; }
    coverpoint is_hit { bins no = {0}; bins yes = {1}; }
    coverpoint sop { bins seen[] = {0,1}; }
    coverpoint eop { bins seen[] = {0,1}; }
    coverpoint low_byte {
      bins preamble = {K285};
      bins subheader = {K237};
      bins trailer = {K284};
      bins other = default;
    }
  endgroup

  function new(string name = "opq_coverage", uvm_component parent = null);
    super.new(name, parent);
    ingress_imp = new("ingress_imp", this);
    egress_imp = new("egress_imp", this);
    cg_cfg = new();
    cg_ingress = new();
    cg_egress = new();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    cg_cfg.sample(OPQ_N_LANE, OPQ_PAGE_RAM_RD_WIDTH, OPQ_N_SHD);
  endfunction

  function void write_ingress(opq_beat_item beat);
    cg_ingress.sample(beat.lane_id, beat.data[35:32] == 4'b0001, beat.sop, beat.eop, beat.data[7:0]);
  endfunction

  function void write_egress(opq_beat_item beat);
    bit is_preamble;
    bit is_hit;
    is_preamble = (beat.data[35:32] == 4'b0001) && (beat.data[7:0] == K285);
    is_hit = (beat.data[35:32] == 4'b0000);
    cg_egress.sample(is_preamble, is_hit, beat.sop, beat.eop, beat.data[7:0]);
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Coverage cfg=%.2f ingress=%.2f egress=%.2f",
      cg_cfg.get_inst_coverage(), cg_ingress.get_inst_coverage(), cg_egress.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

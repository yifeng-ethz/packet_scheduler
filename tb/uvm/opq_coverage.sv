//------------------------------------------------------------------------------
// IP Name   : opq_coverage
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.5 - ignore impossible CSR/config crosses and clarify exact-512 ticket bin
// Description:
//   Functional coverage model for the active OPQ UVM harness.
//------------------------------------------------------------------------------
class opq_coverage extends uvm_component;
  `uvm_component_utils(opq_coverage)

  localparam int CSR_REGION_IDENTITY = 0;
  localparam int CSR_REGION_CONTROL  = 1;
  localparam int CSR_REGION_FTABLE   = 2;
  localparam int CSR_REGION_LANE_CNT = 3;
  localparam int CSR_REGION_CREDIT   = 4;
  localparam int CSR_REGION_DRR      = 5;
  localparam int DROP_DOMAIN_LANE    = 0;
  localparam int DROP_DOMAIN_FTABLE  = 1;

  uvm_analysis_imp_frame #(opq_frame_item, opq_coverage) frame_imp;
  uvm_analysis_imp_ingress #(opq_beat_item, opq_coverage) ingress_imp;
  uvm_analysis_imp_egress #(opq_beat_item, opq_coverage) egress_imp;
  uvm_analysis_imp_bp #(opq_bp_item, opq_coverage) bp_imp;
  opq_dut_cfg cfg;

  covergroup cg_cfg with function sample(int n_lane, int rd_width, int n_shd, int page_depth, int ticket_depth);
    coverpoint n_lane {
      bins active_cfg = {OPQ_N_LANE};
    }
    coverpoint rd_width {
      bins active_cfg = {OPQ_PAGE_RAM_RD_WIDTH};
    }
    coverpoint n_shd {
      bins shd128 = {128};
      bins shd256 = {256};
      bins shd512 = {512};
    }
    coverpoint page_depth {
      bins reduced_overflow = {[256:1024]};
      bins default_cfg = {65536};
    }
    coverpoint ticket_depth {
      bins default_cfg = {256};
      bins exact512 = {512};
      bins extended_cfg = {[513:2048]};
    }
    cross n_shd, ticket_depth {
      ignore_bins illegal_nshd512_exact =
        binsof(n_shd) intersect {512} &&
        binsof(ticket_depth) intersect {512};
    }
    cross n_shd, page_depth;
  endgroup

  covergroup cg_frame with function sample(int lane, int subh_cnt, int hit_cnt, int pre_gap, bit [7:0] first_shd_ts);
    coverpoint lane { bins lane0 = {0}; bins lane1 = {1}; }
    coverpoint subh_cnt {
      bins one = {1};
      bins few = {[2:4]};
      bins almost_full = {OPQ_N_SHD - 1};
      bins max = {OPQ_N_SHD};
    }
    coverpoint hit_cnt {
      bins zero = {0};
      bins one = {1};
      bins pair = {2};
      bins burst = {16, 32};
    }
    coverpoint pre_gap {
      bins none = {0};
      bins frame_gap = {OPQ_MIN_SOP_GAP_CYCLES};
      bins skew_gap = {OPQ_MIN_SOP_GAP_CYCLES + 32};
    }
    coverpoint first_shd_ts {
      bins ts0 = {8'h00};
      bins ts1 = {8'h01};
      bins ts80 = {8'h80};
      bins tsff = {8'hFF};
    }
  endgroup

  covergroup cg_subheader with function sample(int hit_cnt, bit [7:0] shd_ts);
    coverpoint hit_cnt {
      bins zero = {0};
      bins one = {1};
      bins pair = {2};
      bins burst = {16, 32};
    }
    coverpoint shd_ts {
      bins ts0 = {8'h00};
      bins ts1 = {8'h01};
      bins ts7f = {8'h7F};
      bins ts80 = {8'h80};
      bins tsfe = {8'hFE};
      bins tsff = {8'hFF};
      bins other = default;
    }
    cross hit_cnt, shd_ts;
  endgroup

  covergroup cg_bp with function sample(int mode_i, int high_cycles, int low_cycles, int repeat_count);
    coverpoint mode_i {
      bins mode_ready = {int'(BP_ALWAYS_READY)};
      bins mode_stall = {int'(BP_PERIODIC_STALL)};
      bins mode_stuck_low = {int'(BP_ALWAYS_STALL)};
    }
    coverpoint high_cycles {
      bins hi_one = {1};
      bins hi_periodic = {6, 8};
      bins hi_ready = {32};
    }
    coverpoint low_cycles {
      bins lo_one = {1};
      bins lo_short = {4};
      bins lo_medium = {8};
      bins lo_deep_stall = {[1024:65535]};
    }
    coverpoint repeat_count {
      bins rep_one = {1};
      bins rep_pair = {2};
      bins rep_periodic = {24};
      bins rep_many = {40};
    }
    cross mode_i, low_cycles;
  endgroup

  covergroup cg_csr with function sample(bit is_write, int region, int lane, int word_idx);
    coverpoint is_write {
      bins read = {0};
      bins write = {1};
    }
    coverpoint region {
      bins identity = {CSR_REGION_IDENTITY};
      bins control = {CSR_REGION_CONTROL};
      bins ftable = {CSR_REGION_FTABLE};
      bins lane_cnt = {CSR_REGION_LANE_CNT};
      bins credit = {CSR_REGION_CREDIT};
      bins drr = {CSR_REGION_DRR};
    }
    coverpoint lane {
      bins none = {-1};
      bins lane0 = {0};
      bins lane1 = {1};
      illegal_bins other = default;
    }
    coverpoint word_idx {
      bins meta_words[] = {[0:5]};
      bins ft_words[] = {[0:8]};
      bins lane_words[] = {[0:8]};
      bins credit_words[] = {[9:10]};
      bins drr_words[] = {[11:15]};
    }
    cross is_write, region;
    cross is_write, region {
      ignore_bins read_only_region_writes =
        binsof(is_write.write) &&
        (binsof(region.identity) ||
         binsof(region.ftable) ||
         binsof(region.lane_cnt) ||
         binsof(region.credit));
    }
    cross region, lane {
      ignore_bins non_lane_regions =
        (binsof(region.identity) ||
         binsof(region.control) ||
         binsof(region.ftable)) &&
        (binsof(lane.lane0) || binsof(lane.lane1));
      ignore_bins lane_regions_none =
        (binsof(region.lane_cnt) ||
         binsof(region.credit) ||
         binsof(region.drr)) &&
        binsof(lane.none);
    }
  endgroup

  covergroup cg_credit with function sample(int lane, int lane_credit, int ticket_credit);
    coverpoint lane {
      bins lane0 = {0};
      bins lane1 = {1};
    }
    coverpoint lane_credit {
      bins tight = {[0:32]};
      bins active = {[33:OPQ_LANE_FIFO_MAX_CREDIT-1]};
      bins full = {OPQ_LANE_FIFO_MAX_CREDIT};
    }
    coverpoint ticket_credit {
      bins tight = {[0:4]};
      bins active = {[5:OPQ_TICKET_FIFO_MAX_CREDIT-1]};
      bins full = {OPQ_TICKET_FIFO_MAX_CREDIT};
    }
    cross lane, lane_credit;
    cross lane, ticket_credit;
  endgroup

  covergroup cg_drop with function sample(int domain, int lane, int hdr_cnt, int shd_cnt, int hit_cnt);
    coverpoint domain {
      bins lane_domain = {DROP_DOMAIN_LANE};
      bins ftable_domain = {DROP_DOMAIN_FTABLE};
    }
    coverpoint lane {
      bins none = {-1};
      bins lane0 = {0};
      bins lane1 = {1};
    }
    coverpoint hdr_cnt {
      bins zero = {0};
      bins one = {1};
      bins many = {[2:1024]};
    }
    coverpoint shd_cnt {
      bins zero = {0};
      bins one = {1};
      bins few = {[2:16]};
      bins many = {[17:4096]};
    }
    coverpoint hit_cnt {
      bins zero = {0};
      bins one = {1};
      bins few = {[2:16]};
      bins many = {[17:65535]};
    }
    cross domain, hdr_cnt, shd_cnt;
  endgroup

  covergroup cg_drr with function sample(int lane, int allowance, int live_quantum, int grant_cnt, int beat_cnt, int defer_cnt);
    coverpoint lane {
      bins lane0 = {0};
      bins lane1 = {1};
    }
    coverpoint allowance {
      bins zero = {0};
      bins tiny = {[1:4]};
      bins short = {[5:31]};
      bins default_cfg = {OPQ_DRR_DEFAULT_ALLOWANCE};
      bins long = {[32:4095]};
    }
    coverpoint live_quantum {
      bins zero = {0};
      bins tiny = {[1:4]};
      bins short = {[5:31]};
      bins default_cfg = {OPQ_DRR_DEFAULT_ALLOWANCE};
      bins long = {[32:4095]};
    }
    coverpoint grant_cnt {
      bins zero = {0};
      bins some = {[1:15]};
      bins many = {[16:65535]};
    }
    coverpoint beat_cnt {
      bins zero = {0};
      bins some = {[1:31]};
      bins many = {[32:65535]};
    }
    coverpoint defer_cnt {
      bins zero = {0};
      bins some = {[1:15]};
      bins many = {[16:65535]};
    }
    defer_seen: coverpoint int'(defer_cnt > 0) {
      bins no = {0};
      bins yes = {1};
    }
    cross lane, allowance;
    cross lane, defer_cnt;
    cross lane, allowance, defer_seen;
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
    frame_imp = new("frame_imp", this);
    ingress_imp = new("ingress_imp", this);
    egress_imp = new("egress_imp", this);
    bp_imp = new("bp_imp", this);
    cg_cfg = new();
    cg_frame = new();
    cg_subheader = new();
    cg_bp = new();
    cg_csr = new();
    cg_credit = new();
    cg_drop = new();
    cg_drr = new();
    cg_ingress = new();
    cg_egress = new();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if (!uvm_config_db#(opq_dut_cfg)::get(this, "", "dut_cfg", cfg)) begin
      cfg = opq_dut_cfg::type_id::create("dut_cfg");
    end
    cg_cfg.sample(cfg.n_lane, OPQ_PAGE_RAM_RD_WIDTH, cfg.n_shd, cfg.page_ram_depth, cfg.ticket_fifo_depth);
  endfunction

  function void write_frame(opq_frame_item frame);
    bit [7:0] first_shd_ts;

    first_shd_ts = (frame.subheaders.size() == 0) ? 8'h00 : frame.subheaders[0].shd_ts;
    cg_frame.sample(frame.lane_id, frame.subheaders.size(), frame.frame_hit_count_bits(), frame.pre_gap_cycles, first_shd_ts);
    foreach (frame.subheaders[i]) begin
      cg_subheader.sample(frame.subheaders[i].hit_count(), frame.subheaders[i].shd_ts);
    end
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

  function void write_bp(opq_bp_item item);
    cg_bp.sample(int'(item.mode), item.high_cycles, item.low_cycles, item.repeat_count);
  endfunction

  function automatic void sample_csr_access(bit is_write, bit [8:0] addr);
    int region;
    int lane;
    int word_idx;

    region = CSR_REGION_CONTROL;
    lane = -1;
    word_idx = int'(addr);

    if (addr <= OPQ_CSR_WORD_CAP) begin
      if (addr <= OPQ_CSR_WORD_META) begin
        region = CSR_REGION_IDENTITY;
      end else begin
        region = CSR_REGION_CONTROL;
      end
      word_idx = int'(addr);
    end else if ((addr >= OPQ_CSR_WORD_FT_WR_HDR) && (addr <= OPQ_CSR_WORD_FT_DROP_HIT)) begin
      region = CSR_REGION_FTABLE;
      word_idx = int'(addr - OPQ_CSR_WORD_FT_WR_HDR);
    end else if (addr >= OPQ_CSR_LANE_REGION_BASE) begin
      lane = int'((addr - OPQ_CSR_LANE_REGION_BASE) / OPQ_CSR_LANE_REGION_STRIDE);
      word_idx = int'((addr - OPQ_CSR_LANE_REGION_BASE) % OPQ_CSR_LANE_REGION_STRIDE);
      if (word_idx >= 11) begin
        region = CSR_REGION_DRR;
      end else if (word_idx >= 9) begin
        region = CSR_REGION_CREDIT;
      end else begin
        region = CSR_REGION_LANE_CNT;
      end
    end

    cg_csr.sample(is_write, region, lane, word_idx);
  endfunction

  function void sample_credit_snapshot(int lane, int lane_credit, int ticket_credit);
    cg_credit.sample(lane, lane_credit, ticket_credit);
  endfunction

  function void sample_drop_snapshot(int domain, int lane, int hdr_cnt, int shd_cnt, int hit_cnt);
    cg_drop.sample(domain, lane, hdr_cnt, shd_cnt, hit_cnt);
  endfunction

  function void sample_drr_snapshot(int lane, int allowance, int live_quantum, int grant_cnt, int beat_cnt, int defer_cnt);
    cg_drr.sample(lane, allowance, live_quantum, grant_cnt, beat_cnt, defer_cnt);
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Coverage cfg=%.2f frame=%.2f subh=%.2f bp=%.2f csr=%.2f credit=%.2f drop=%.2f drr=%.2f ingress=%.2f egress=%.2f",
      cg_cfg.get_inst_coverage(),
      cg_frame.get_inst_coverage(),
      cg_subheader.get_inst_coverage(),
      cg_bp.get_inst_coverage(),
      cg_csr.get_inst_coverage(),
      cg_credit.get_inst_coverage(),
      cg_drop.get_inst_coverage(),
      cg_drr.get_inst_coverage(),
      cg_ingress.get_inst_coverage(),
      cg_egress.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

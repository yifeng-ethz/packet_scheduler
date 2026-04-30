//------------------------------------------------------------------------------
// IP Name   : opq_pkg
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.3 - model ingress debug timestamps as virtual FEB dispatch time
// Description:
//   Shared UVM types, helpers, and packet-format builders for the OPQ harness.
//------------------------------------------------------------------------------
package opq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_ingress)
  `uvm_analysis_imp_decl(_egress)
  `uvm_analysis_imp_decl(_frame)
  `uvm_analysis_imp_decl(_bp)
  `uvm_analysis_imp_decl(_drop)

`ifndef OPQ_PAGE_RAM_DEPTH
`define OPQ_PAGE_RAM_DEPTH 65536
`endif
`ifndef OPQ_N_SHD
`define OPQ_N_SHD 256
`endif
`ifndef OPQ_TICKET_FIFO_DEPTH
`define OPQ_TICKET_FIFO_DEPTH 8192
`endif
`ifndef OPQ_N_LANE
`define OPQ_N_LANE 2
`endif
`ifndef OPQ_LANE_FIFO_DEPTH
`define OPQ_LANE_FIFO_DEPTH 8192
`endif

`ifndef OPQ_HANDLE_FIFO_DEPTH
`define OPQ_HANDLE_FIFO_DEPTH 64
`endif
`ifndef OPQ_CHANNEL_WIDTH
`define OPQ_CHANNEL_WIDTH 2
`endif
`ifndef OPQ_PAGE_RAM_RD_WIDTH
`define OPQ_PAGE_RAM_RD_WIDTH 36
`endif
`ifndef OPQ_EGRESS_SYMBOLS_PER_BEAT
`define OPQ_EGRESS_SYMBOLS_PER_BEAT 1
`endif
`ifndef OPQ_EGRESS_EMPTY_WIDTH
`define OPQ_EGRESS_EMPTY_WIDTH 1
`endif
`ifndef OPQ_N_HIT
`define OPQ_N_HIT 255
`endif

  localparam int OPQ_N_LANE = `OPQ_N_LANE;
  localparam int OPQ_INGRESS_WIDTH = 36;
  localparam int OPQ_CHANNEL_WIDTH = `OPQ_CHANNEL_WIDTH;
  localparam int OPQ_PAGE_RAM_RD_WIDTH = `OPQ_PAGE_RAM_RD_WIDTH;
  localparam int OPQ_EGRESS_SYMBOL_WIDTH = OPQ_INGRESS_WIDTH;
  localparam int OPQ_EGRESS_SYMBOLS_PER_BEAT = `OPQ_EGRESS_SYMBOLS_PER_BEAT;
  localparam int OPQ_EGRESS_EMPTY_WIDTH = `OPQ_EGRESS_EMPTY_WIDTH;
  localparam int OPQ_PAGE_RAM_DEPTH = `OPQ_PAGE_RAM_DEPTH;
  localparam int OPQ_LANE_FIFO_DEPTH = `OPQ_LANE_FIFO_DEPTH;
  localparam int OPQ_TICKET_FIFO_DEPTH = `OPQ_TICKET_FIFO_DEPTH;
  localparam int OPQ_HANDLE_FIFO_DEPTH = `OPQ_HANDLE_FIFO_DEPTH;
  localparam int OPQ_LANE_FIFO_MAX_CREDIT = OPQ_LANE_FIFO_DEPTH - 2;
  localparam int OPQ_TICKET_FIFO_MAX_CREDIT = OPQ_TICKET_FIFO_DEPTH - 1;
  localparam int OPQ_HANDLE_FIFO_MAX_CREDIT = OPQ_HANDLE_FIFO_DEPTH - 2;
  localparam int OPQ_N_SHD = `OPQ_N_SHD;
  localparam int OPQ_N_HIT = `OPQ_N_HIT;
  localparam int OPQ_DRR_DEFAULT_ALLOWANCE = 256;
  localparam int OPQ_TIMESTAMP_TICK_NS = 8;
  localparam int OPQ_UVM_CLK_PERIOD_NS = 4;
  localparam int OPQ_SUBHEADER_DURATION_TS_TICKS = 16;
  localparam int OPQ_FRAME_DURATION_TS_TICKS = OPQ_N_SHD * OPQ_SUBHEADER_DURATION_TS_TICKS;
  localparam int OPQ_FRAME_DURATION_SWB_CYCLES =
    (OPQ_FRAME_DURATION_TS_TICKS * OPQ_TIMESTAMP_TICK_NS) / OPQ_UVM_CLK_PERIOD_NS;
  localparam int OPQ_MIN_SOP_GAP_CYCLES = OPQ_FRAME_DURATION_SWB_CYCLES;
  localparam int OPQ_POST_RESET_SETTLE_CYCLES = 4;
  localparam int OPQ_ABSOLUTE_LAUNCH_GUARD_CYCLES = 64;
  localparam int OPQ_FRAME_HDR_AUX_WORDS = 4;
  localparam int OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES = 4096;

  localparam bit [7:0] K285 = 8'hBC;
  localparam bit [7:0] K284 = 8'h9C;
  localparam bit [7:0] K237 = 8'hF7;
  localparam bit [8:0] OPQ_CSR_WORD_UID = 9'h000;
  localparam bit [8:0] OPQ_CSR_WORD_META = 9'h001;
  localparam bit [8:0] OPQ_CSR_WORD_LANE_MASK = 9'h002;
  localparam bit [8:0] OPQ_CSR_WORD_CTRL = 9'h003;
  localparam bit [8:0] OPQ_CSR_WORD_STATUS = 9'h004;
  localparam bit [8:0] OPQ_CSR_WORD_CAP = 9'h005;
  localparam bit [8:0] OPQ_CSR_WORD_FT_WR_HDR = 9'h008;
  localparam bit [8:0] OPQ_CSR_WORD_FT_WR_SHD = 9'h009;
  localparam bit [8:0] OPQ_CSR_WORD_FT_WR_HIT = 9'h00A;
  localparam bit [8:0] OPQ_CSR_WORD_FT_RD_HDR = 9'h00B;
  localparam bit [8:0] OPQ_CSR_WORD_FT_RD_SHD = 9'h00C;
  localparam bit [8:0] OPQ_CSR_WORD_FT_RD_HIT = 9'h00D;
  localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_HDR = 9'h00E;
  localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_SHD = 9'h00F;
  localparam bit [8:0] OPQ_CSR_WORD_FT_DROP_HIT = 9'h010;
  localparam bit [8:0] OPQ_CSR_LANE_REGION_BASE = 9'h040;
  localparam bit [8:0] OPQ_CSR_LANE_REGION_STRIDE = 9'h010;
  localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_ALLOWANCE = 4'hB;
  localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_QUANTUM = 4'hC;
  localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_GRANT_CNT = 4'hD;
  localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_BEAT_CNT = 4'hE;
  localparam bit [3:0] OPQ_CSR_LANE_WORD_DRR_DEFER_CNT = 4'hF;

  typedef enum int {
    BP_ALWAYS_READY,
    BP_PERIODIC_STALL,
    BP_ALWAYS_STALL
  } opq_bp_mode_e;

  typedef enum int {
    BP_TRIGGER_IMMEDIATE,
    BP_TRIGGER_FIRST_VALID,
    BP_TRIGGER_FIRST_SOP
  } opq_bp_trigger_e;

  function automatic bit [31:0] make_preamble(bit [5:0] dt_type, bit [15:0] feb_id);
    bit [31:0] data32;
    data32 = '0;
    data32[31:26] = dt_type;
    data32[23:8] = feb_id;
    data32[7:0] = K285;
    return data32;
  endfunction

  function automatic bit [31:0] make_subheader(bit [7:0] shd_ts, bit [15:0] hit_cnt);
    bit [31:0] data32;
    data32 = '0;
    data32[31:24] = shd_ts;
    data32[23:8] = hit_cnt;
    data32[7:0] = K237;
    return data32;
  endfunction

  function automatic bit [35:0] frame_ts_hdr36(bit [47:0] frame_ts);
    return frame_ts[47:12];
  endfunction

  function automatic bit [31:0] make_frame_data_header0(bit [47:0] frame_ts);
    return frame_ts_hdr36(frame_ts)[35:4];
  endfunction

  function automatic bit [31:0] make_frame_data_header1(bit [47:0] frame_ts, bit [15:0] pkg_cnt);
    bit [31:0] data32;
    data32 = '0;
    data32[31:16] = frame_ts[15:0];
    data32[15:0] = pkg_cnt;
    return data32;
  endfunction

  function automatic bit [31:0] make_frame_debug_header0(bit [15:0] subheader_cnt, bit [15:0] hit_cnt);
    bit [31:0] data32;
    data32 = '0;
    data32[30:16] = subheader_cnt[14:0];
    data32[15:0] = hit_cnt;
    return data32;
  endfunction

  function automatic bit [31:0] make_frame_debug_header1(bit [30:0] debug_ts);
    bit [31:0] data32;
    data32 = '0;
    data32[30:0] = debug_ts;
    return data32;
  endfunction

  function automatic bit [30:0] add_debug_ts_offset(
    bit [30:0] base_ts,
    bit [63:0] extra_cycles
  );
    bit [31:0] sum_v;

    sum_v = {1'b0, base_ts} + {1'b0, extra_cycles[30:0]};
    return sum_v[30:0];
  endfunction

  function automatic bit [30:0] default_ingress_debug_ts(bit [47:0] frame_ts);
    return add_debug_ts_offset(frame_ts[30:0], OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES);
  endfunction

  function automatic bit [OPQ_CHANNEL_WIDTH-1:0] lane_to_channel(int unsigned lane_id);
    return lane_id[OPQ_CHANNEL_WIDTH-1:0];
  endfunction

  function automatic bit [31:0] make_trailer();
    bit [31:0] data32;
    data32 = '0;
    data32[7:0] = K284;
    return data32;
  endfunction

  class opq_hit_desc extends uvm_object;
    rand bit [31:0] payload_word;
    bit [63:0] debug_hit_id;
    bit [2:0]  error_bits;

    `uvm_object_utils_begin(opq_hit_desc)
      `uvm_field_int(payload_word, UVM_DEFAULT)
      `uvm_field_int(debug_hit_id, UVM_DEFAULT)
      `uvm_field_int(error_bits, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_hit_desc");
      super.new(name);
      payload_word = '0;
      debug_hit_id = '0;
      error_bits = '0;
    endfunction
  endclass

  class opq_subheader_desc extends uvm_object;
    rand bit [7:0] shd_ts;
    rand opq_hit_desc hits[$];
    bit [2:0] error_bits;

    `uvm_object_utils_begin(opq_subheader_desc)
      `uvm_field_int(shd_ts, UVM_DEFAULT)
      `uvm_field_int(error_bits, UVM_DEFAULT)
      `uvm_field_queue_object(hits, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_subheader_desc");
      super.new(name);
      error_bits = '0;
    endfunction

    function int unsigned hit_count();
      return hits.size();
    endfunction
  endclass

  class opq_frame_item extends uvm_sequence_item;
    rand int unsigned lane_id;
    rand bit [OPQ_CHANNEL_WIDTH-1:0] channel;
    rand bit [47:0] frame_ts;
    rand bit [15:0] pkg_cnt;
    rand bit [5:0] dt_type;
    rand bit [15:0] feb_id;
    rand int unsigned pre_gap_cycles;
    bit [30:0] ingress_debug_ts;
    bit use_absolute_launch;
    bit [63:0] launch_cycle;
    int unsigned frame_slot_id;
    bit [2:0] preamble_error_bits;
    bit [2:0] data_header0_error_bits;
    bit [2:0] data_header1_error_bits;
    bit [2:0] debug_header0_error_bits;
    bit [2:0] debug_header1_error_bits;
    bit whole_frame_packet;
    bit omit_trailer;
    bit suppress_scoreboard_frame;
    opq_subheader_desc subheaders[$];

    constraint c_lane_range { lane_id < OPQ_N_LANE; }
    constraint c_channel_match { channel == lane_to_channel(lane_id); }

    `uvm_object_utils_begin(opq_frame_item)
      `uvm_field_int(lane_id, UVM_DEFAULT)
      `uvm_field_int(channel, UVM_DEFAULT)
      `uvm_field_int(frame_ts, UVM_DEFAULT)
      `uvm_field_int(pkg_cnt, UVM_DEFAULT)
      `uvm_field_int(dt_type, UVM_DEFAULT)
      `uvm_field_int(feb_id, UVM_DEFAULT)
      `uvm_field_int(pre_gap_cycles, UVM_DEFAULT)
      `uvm_field_int(ingress_debug_ts, UVM_DEFAULT)
      `uvm_field_int(use_absolute_launch, UVM_DEFAULT)
      `uvm_field_int(launch_cycle, UVM_DEFAULT)
      `uvm_field_int(frame_slot_id, UVM_DEFAULT)
      `uvm_field_int(preamble_error_bits, UVM_DEFAULT)
      `uvm_field_int(data_header0_error_bits, UVM_DEFAULT)
      `uvm_field_int(data_header1_error_bits, UVM_DEFAULT)
      `uvm_field_int(debug_header0_error_bits, UVM_DEFAULT)
      `uvm_field_int(debug_header1_error_bits, UVM_DEFAULT)
      `uvm_field_int(whole_frame_packet, UVM_DEFAULT)
      `uvm_field_int(omit_trailer, UVM_DEFAULT)
      `uvm_field_int(suppress_scoreboard_frame, UVM_DEFAULT)
      `uvm_field_queue_object(subheaders, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_frame_item");
      super.new(name);
      dt_type = 6'b000001;
      feb_id = 16'h0001;
      pre_gap_cycles = 0;
      ingress_debug_ts = '0;
      use_absolute_launch = 1'b0;
      launch_cycle = '0;
      frame_slot_id = '0;
      preamble_error_bits = '0;
      data_header0_error_bits = '0;
      data_header1_error_bits = '0;
      debug_header0_error_bits = '0;
      debug_header1_error_bits = '0;
      whole_frame_packet = 1'b1;
      omit_trailer = 1'b0;
      suppress_scoreboard_frame = 1'b0;
    endfunction

    function bit [15:0] frame_subh_count_bits();
      return subheaders.size();
    endfunction

    function bit [15:0] frame_hit_count_bits();
      int unsigned total_hits;
      total_hits = 0;
      foreach (subheaders[i]) begin
        total_hits += subheaders[i].hit_count();
      end
      return total_hits;
    endfunction

    function int unsigned frame_word_count();
      int unsigned total_words;

      total_words = 5;
      total_words += subheaders.size();
      total_words += frame_hit_count_bits();
      if (!omit_trailer) begin
        total_words++;
      end
      return total_words;
    endfunction
  endclass

  class opq_bp_item extends uvm_sequence_item;
    rand opq_bp_mode_e mode;
    rand opq_bp_trigger_e trigger_mode;
    rand int unsigned high_cycles;
    rand int unsigned low_cycles;
    rand int unsigned repeat_count;

    `uvm_object_utils_begin(opq_bp_item)
      `uvm_field_enum(opq_bp_mode_e, mode, UVM_DEFAULT)
      `uvm_field_enum(opq_bp_trigger_e, trigger_mode, UVM_DEFAULT)
      `uvm_field_int(high_cycles, UVM_DEFAULT)
      `uvm_field_int(low_cycles, UVM_DEFAULT)
      `uvm_field_int(repeat_count, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_bp_item");
      super.new(name);
      mode = BP_ALWAYS_READY;
      trigger_mode = BP_TRIGGER_IMMEDIATE;
      high_cycles = 1;
      low_cycles = 1;
      repeat_count = 1;
    endfunction
  endclass

  class opq_beat_item extends uvm_sequence_item;
    int lane_id;
    bit [35:0] data;
    bit sop;
    bit eop;
    bit [2:0] error;

    `uvm_object_utils_begin(opq_beat_item)
      `uvm_field_int(lane_id, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(sop, UVM_DEFAULT)
      `uvm_field_int(eop, UVM_DEFAULT)
      `uvm_field_int(error, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_beat_item");
      super.new(name);
      lane_id = -1;
      data = '0;
      sop = 0;
      eop = 0;
      error = '0;
    endfunction
  endclass

  class opq_drop_item extends uvm_sequence_item;
    int lane_id;
    int unsigned hdr_drop_cnt;
    int unsigned shd_drop_cnt;
    int unsigned hit_drop_cnt;
    int unsigned pre_shd_drop_cnt;
    int unsigned pre_hit_drop_cnt;
    int unsigned post_hdr_drop_cnt;
    int unsigned post_shd_drop_cnt;
    int unsigned post_hit_drop_cnt;
    bit          exact_pre_valid;
    bit [47:0]   exact_pre_ts;
    bit [15:0]   exact_pre_serial;
    int unsigned exact_pre_shd_cnt;
    int unsigned exact_pre_hit_cnt;
    bit          exact_post_valid;
    bit [47:0]   exact_post_ts;
    bit [15:0]   exact_post_serial;
    int unsigned exact_post_shd_cnt;
    int unsigned exact_post_hit_cnt;

    `uvm_object_utils_begin(opq_drop_item)
      `uvm_field_int(lane_id, UVM_DEFAULT)
      `uvm_field_int(hdr_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(shd_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(hit_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(pre_shd_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(pre_hit_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(post_hdr_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(post_shd_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(post_hit_drop_cnt, UVM_DEFAULT)
      `uvm_field_int(exact_pre_valid, UVM_DEFAULT)
      `uvm_field_int(exact_pre_ts, UVM_DEFAULT)
      `uvm_field_int(exact_pre_serial, UVM_DEFAULT)
      `uvm_field_int(exact_pre_shd_cnt, UVM_DEFAULT)
      `uvm_field_int(exact_pre_hit_cnt, UVM_DEFAULT)
      `uvm_field_int(exact_post_valid, UVM_DEFAULT)
      `uvm_field_int(exact_post_ts, UVM_DEFAULT)
      `uvm_field_int(exact_post_serial, UVM_DEFAULT)
      `uvm_field_int(exact_post_shd_cnt, UVM_DEFAULT)
      `uvm_field_int(exact_post_hit_cnt, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_drop_item");
      super.new(name);
      lane_id = -1;
      hdr_drop_cnt = 0;
      shd_drop_cnt = 0;
      hit_drop_cnt = 0;
      pre_shd_drop_cnt = 0;
      pre_hit_drop_cnt = 0;
      post_hdr_drop_cnt = 0;
      post_shd_drop_cnt = 0;
      post_hit_drop_cnt = 0;
      exact_pre_valid = 1'b0;
      exact_pre_ts = '0;
      exact_pre_serial = '0;
      exact_pre_shd_cnt = 0;
      exact_pre_hit_cnt = 0;
      exact_post_valid = 1'b0;
      exact_post_ts = '0;
      exact_post_serial = '0;
      exact_post_shd_cnt = 0;
      exact_post_hit_cnt = 0;
    endfunction
  endclass

  class opq_dut_cfg extends uvm_object;
    int unsigned n_lane;
    int unsigned page_ram_depth;
    int unsigned ticket_fifo_depth;
    int unsigned n_shd;
    int unsigned n_hit;

    `uvm_object_utils_begin(opq_dut_cfg)
      `uvm_field_int(n_lane, UVM_DEFAULT)
      `uvm_field_int(page_ram_depth, UVM_DEFAULT)
      `uvm_field_int(ticket_fifo_depth, UVM_DEFAULT)
      `uvm_field_int(n_shd, UVM_DEFAULT)
      `uvm_field_int(n_hit, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_dut_cfg");
      super.new(name);
      n_lane = OPQ_N_LANE;
      page_ram_depth = OPQ_PAGE_RAM_DEPTH;
      ticket_fifo_depth = OPQ_TICKET_FIFO_DEPTH;
      n_shd = OPQ_N_SHD;
      n_hit = OPQ_N_HIT;
    endfunction
  endclass

  class opq_scoreboard_cfg extends uvm_object;
    bit check_hit_integrity;
    bit check_feb_contract;
    bit require_egress_preamble;
    bit allow_drop_accounting;
    bit allow_unmatched_ingress_preamble;
    int unsigned min_sop_count;

    `uvm_object_utils_begin(opq_scoreboard_cfg)
      `uvm_field_int(check_hit_integrity, UVM_DEFAULT)
      `uvm_field_int(check_feb_contract, UVM_DEFAULT)
      `uvm_field_int(require_egress_preamble, UVM_DEFAULT)
      `uvm_field_int(allow_drop_accounting, UVM_DEFAULT)
      `uvm_field_int(allow_unmatched_ingress_preamble, UVM_DEFAULT)
      `uvm_field_int(min_sop_count, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_scoreboard_cfg");
      super.new(name);
      check_hit_integrity = 1'b1;
      check_feb_contract = 1'b1;
      require_egress_preamble = 1'b0;
      allow_drop_accounting = 1'b0;
      allow_unmatched_ingress_preamble = 1'b0;
      min_sop_count = 0;
    endfunction
  endclass
endpackage

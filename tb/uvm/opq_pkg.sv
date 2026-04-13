package opq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_ingress)
  `uvm_analysis_imp_decl(_egress)
  `uvm_analysis_imp_decl(_frame)

  localparam int OPQ_N_LANE = 2;
  localparam int OPQ_INGRESS_WIDTH = 36;
  localparam int OPQ_CHANNEL_WIDTH = 2;
  localparam int OPQ_PAGE_RAM_RD_WIDTH = 36;
  localparam int OPQ_N_SHD = 128;
  localparam int OPQ_N_HIT = 255;
  localparam int OPQ_MIN_SOP_GAP_CYCLES = 4000;
  localparam int OPQ_POST_RESET_SETTLE_CYCLES = 4;

  localparam bit [7:0] K285 = 8'hBC;
  localparam bit [7:0] K284 = 8'h9C;
  localparam bit [7:0] K237 = 8'hF7;

  typedef enum int {
    BP_ALWAYS_READY,
    BP_PERIODIC_STALL
  } opq_bp_mode_e;

  function automatic bit [31:0] make_preamble(bit [5:0] dt_type, bit [15:0] feb_id);
    bit [31:0] data32;
    data32 = '0;
    data32[31:26] = dt_type;
    data32[23:8] = feb_id;
    data32[7:0] = K285;
    return data32;
  endfunction

  function automatic bit [31:0] make_subheader(bit [7:0] shd_ts, bit [7:0] hit_cnt);
    bit [31:0] data32;
    data32 = '0;
    data32[31:24] = shd_ts;
    data32[15:8] = hit_cnt;
    data32[7:0] = K237;
    return data32;
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

    `uvm_object_utils_begin(opq_hit_desc)
      `uvm_field_int(payload_word, UVM_DEFAULT)
      `uvm_field_int(debug_hit_id, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_hit_desc");
      super.new(name);
      payload_word = '0;
      debug_hit_id = '0;
    endfunction
  endclass

  class opq_subheader_desc extends uvm_object;
    rand bit [7:0] shd_ts;
    rand opq_hit_desc hits[$];

    `uvm_object_utils_begin(opq_subheader_desc)
      `uvm_field_int(shd_ts, UVM_DEFAULT)
      `uvm_field_queue_object(hits, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_subheader_desc");
      super.new(name);
    endfunction

    function int unsigned hit_count();
      return hits.size();
    endfunction
  endclass

  class opq_frame_item extends uvm_sequence_item;
    rand int unsigned lane_id;
    rand bit [1:0] channel;
    rand bit [47:0] frame_ts;
    rand bit [15:0] pkg_cnt;
    rand bit [5:0] dt_type;
    rand bit [15:0] feb_id;
    rand int unsigned pre_gap_cycles;
    opq_subheader_desc subheaders[$];

    constraint c_lane_range { lane_id < OPQ_N_LANE; }
    constraint c_channel_match { channel == lane_id[1:0]; }

    `uvm_object_utils_begin(opq_frame_item)
      `uvm_field_int(lane_id, UVM_DEFAULT)
      `uvm_field_int(channel, UVM_DEFAULT)
      `uvm_field_int(frame_ts, UVM_DEFAULT)
      `uvm_field_int(pkg_cnt, UVM_DEFAULT)
      `uvm_field_int(dt_type, UVM_DEFAULT)
      `uvm_field_int(feb_id, UVM_DEFAULT)
      `uvm_field_int(pre_gap_cycles, UVM_DEFAULT)
      `uvm_field_queue_object(subheaders, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_frame_item");
      super.new(name);
      dt_type = 6'b000001;
      feb_id = 16'h0001;
      pre_gap_cycles = 0;
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
  endclass

  class opq_bp_item extends uvm_sequence_item;
    rand opq_bp_mode_e mode;
    rand int unsigned high_cycles;
    rand int unsigned low_cycles;
    rand int unsigned repeat_count;

    `uvm_object_utils_begin(opq_bp_item)
      `uvm_field_enum(opq_bp_mode_e, mode, UVM_DEFAULT)
      `uvm_field_int(high_cycles, UVM_DEFAULT)
      `uvm_field_int(low_cycles, UVM_DEFAULT)
      `uvm_field_int(repeat_count, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_bp_item");
      super.new(name);
      mode = BP_ALWAYS_READY;
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

  class opq_scoreboard_cfg extends uvm_object;
    bit check_hit_integrity;
    bit require_egress_preamble;
    int unsigned min_sop_count;

    `uvm_object_utils_begin(opq_scoreboard_cfg)
      `uvm_field_int(check_hit_integrity, UVM_DEFAULT)
      `uvm_field_int(require_egress_preamble, UVM_DEFAULT)
      `uvm_field_int(min_sop_count, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "opq_scoreboard_cfg");
      super.new(name);
      check_hit_integrity = 1'b1;
      require_egress_preamble = 1'b0;
      min_sop_count = 0;
    endfunction
  endclass
endpackage

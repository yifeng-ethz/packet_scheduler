//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_page_allocator
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.3.58
// Date    : 20260421
// Change  : Reactivate late current-frame SOP joins so inactive lanes cannot age same-frame body tickets into late drops
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_page_allocator #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned FRAME_SERIAL_SIZE = 16,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A =
    48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + FRAME_SERIAL_SIZE + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 6 + 16 + 48 + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B,
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH),
  parameter int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS,
  parameter int unsigned FIFO_RAW_DELAY = 2,
  parameter int unsigned FRAME_DURATION_CYCLES = N_SHD * 16,
  parameter int unsigned FRAME_JOIN_WAIT_CYCLES = 64,
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned ALLOC_PAGE_FLOW_WIDTH = (N_LANE <= 1) ? 1 : $clog2(N_LANE),
  parameter int unsigned WRITE_META_FLOW_WIDTH = 3,
  parameter int unsigned PAGE_LENGTH_WIDTH = MAX_PKT_LENGTH_BITS + CHANNEL_WIDTH
) (
  input  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ingress_ticket_wptr,
  input  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0]     ticket_fifos_rd_data_i,
  input  logic [N_LANE-1:0][5:0]                            ingress_dt_type_i,
  input  logic [N_LANE-1:0][15:0]                           ingress_feb_id_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_frame_ts_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_running_ts_i,
  input  logic [N_LANE-1:0]                                 ingress_parser_busy_i,
  input  logic [N_LANE-1:0]                                 ingress_tail_bypass_valid_i,
  input  logic [N_LANE-1:0]                                 ingress_tail_bypass_drop_i,
  input  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0]          ingress_tail_bypass_serial_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_tail_bypass_ts_i,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_credit_update_o,
  output logic [N_LANE-1:0]                                 ticket_credit_update_valid_o,
  output logic [N_LANE-1:0][HANDLE_LENGTH:0]                handle_wdata_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_waddr_o,
  output logic [N_LANE-1:0]                                 handle_we_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_wptr_o,
  output logic [N_LANE-1:0]                                 eop_flush_ack_o,
  output logic [N_LANE-1:0]                                 late_frame_drop_valid_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_hdr_cnt_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_shd_cnt_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_hit_cnt_o,
  output logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0]          late_frame_drop_serial_o,
  output logic [N_LANE-1:0][47:0]                           late_frame_drop_ts_o,
  output logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]       late_frame_lane_credit_update_o,
  output logic [N_LANE-1:0]                                 late_frame_lane_credit_update_valid_o,
  output logic                                              page_we_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    page_waddr_o,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                    page_wdata_o,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_fifos_rd_addr_o,
  output logic [N_LANE-1:0]                                 tk_future_o,
  output logic                                              fetch_ticket_active_o,
  output logic                                              alloc_page_active_o,
  output logic                                              write_head_active_o,
  output logic                                              write_tail_active_o,
  output logic                                              write_page_active_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_d1_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    frame_start_addr_o,
  output logic [MAX_SHR_CNT_BITS-1:0]                       frame_shr_cnt_this_o,
  output logic [MAX_HIT_CNT_BITS-1:0]                       frame_hit_cnt_this_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]           frame_lane_shd_cnt_this_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]           frame_lane_hit_cnt_this_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    packet_complete_frame_start_addr_o,
  output logic [MAX_SHR_CNT_BITS-1:0]                       packet_complete_shr_cnt_o,
  output logic [MAX_HIT_CNT_BITS-1:0]                       packet_complete_hit_cnt_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]           packet_complete_lane_shd_cnt_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]           packet_complete_lane_hit_cnt_o,
  output logic                                              packet_complete_pulse_o,
  input  logic                                              resident_backpressure_hold_i,
  input  logic                                              d_clk,
  input  logic                                              d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  localparam int unsigned HANDLE_SRC_LO = 0;
  localparam int unsigned HANDLE_SRC_HI = LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_DST_LO = LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned HANDLE_DST_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_LEN_LO = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH;
  localparam int unsigned HANDLE_LEN_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned TICKET_TS_LO = 0;
  localparam int unsigned TICKET_TS_HI = 47;
  localparam int unsigned TICKET_LANE_RD_OFST_LO = 48;
  localparam int unsigned TICKET_LANE_RD_OFST_HI = 48 + LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned TICKET_BLOCK_LEN_LO = 48 + LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned TICKET_BLOCK_LEN_HI = 48 + LANE_FIFO_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned TICKET_BODY_SERIAL_LO = TICKET_BLOCK_LEN_HI + 1;
  localparam int unsigned TICKET_BODY_SERIAL_HI = TICKET_BODY_SERIAL_LO + FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_SERIAL_LO = 0;
  localparam int unsigned TICKET_SERIAL_HI = FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_N_SUBH_LO = FRAME_SERIAL_SIZE;
  localparam int unsigned TICKET_N_SUBH_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  localparam int unsigned TICKET_N_HIT_LO = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  localparam int unsigned TICKET_N_HIT_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;
  localparam int unsigned TICKET_DT_TYPE_LO = TICKET_N_HIT_HI + 1;
  localparam int unsigned TICKET_DT_TYPE_HI = TICKET_DT_TYPE_LO + 6 - 1;
  localparam int unsigned TICKET_FEB_ID_LO = TICKET_DT_TYPE_HI + 1;
  localparam int unsigned TICKET_FEB_ID_HI = TICKET_FEB_ID_LO + 16 - 1;
  localparam int unsigned TICKET_FRAME_TS_LO = TICKET_FEB_ID_HI + 1;
  localparam int unsigned TICKET_FRAME_TS_HI = TICKET_FRAME_TS_LO + 48 - 1;
  localparam int unsigned TICKET_ALT_EOP_LOC = TICKET_FIFO_DATA_WIDTH - 2;
  localparam int unsigned TICKET_ALT_SOP_LOC = TICKET_FIFO_DATA_WIDTH - 1;
  localparam logic [ALLOC_PAGE_FLOW_WIDTH-1:0] ALLOC_PAGE_FLOW_LAST = N_LANE - 1;

  typedef logic [LANE_FIFO_ADDR_WIDTH-1:0] lane_fifo_addr_t;
  typedef logic [TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifo_addr_t;
  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [HANDLE_FIFO_ADDR_WIDTH-1:0] handle_fifo_addr_t;
  typedef logic [MAX_PKT_LENGTH_BITS-1:0] pkt_length_t;
  typedef logic [MAX_SHR_CNT_BITS-1:0] frame_shr_cnt_t;
  typedef logic [MAX_HIT_CNT_BITS-1:0] frame_hit_cnt_t;
  typedef logic [PAGE_LENGTH_WIDTH-1:0] page_length_t;

  typedef struct packed {
    logic [47:0]           ticket_ts;
    lane_fifo_addr_t       lane_fifo_rd_offset;
    pkt_length_t           block_length;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial;
    logic                  alert_eop;
    logic                  alert_sop;
  } ticket_t;

  localparam ticket_t TICKET_DEFAULT = '{
    ticket_ts: '0,
    lane_fifo_rd_offset: '0,
    block_length: '0,
    frame_serial: '0,
    alert_eop: 1'b0,
    alert_sop: 1'b0
  };

`ifndef SYNTHESIS
  bit opq_trace_boundary_en;
  time opq_trace_after_ps;
  logic formal_past_valid;

  initial begin
    opq_trace_boundary_en = $test$plusargs("OPQ_NATIVE_TRACE_BOUNDARY");
    opq_trace_after_ps = 0;
    void'($value$plusargs("OPQ_TRACE_AFTER_PS=%d", opq_trace_after_ps));
  end

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      formal_past_valid <= 1'b0;
    end else begin
      formal_past_valid <= 1'b1;
    end
  end
`endif

  typedef enum logic [3:0] {
    PAGE_ALLOCATOR_IDLE,
    PAGE_ALLOCATOR_FETCH_TICKET,
    PAGE_ALLOCATOR_CLASSIFY_TICKET,
    PAGE_ALLOCATOR_ACCUM_TICKET,
    PAGE_ALLOCATOR_SUMMARIZE_TICKET,
    PAGE_ALLOCATOR_DECIDE_TICKET,
    PAGE_ALLOCATOR_APPLY_TICKET,
    PAGE_ALLOCATOR_WRITE_HEAD,
    PAGE_ALLOCATOR_WRITE_TAIL,
    PAGE_ALLOCATOR_ALLOC_PAGE,
    PAGE_ALLOCATOR_FINALIZE_PAGE,
    PAGE_ALLOCATOR_WRITE_PAGE,
    PAGE_ALLOCATOR_RESET
  } page_allocator_state_t;

  typedef ticket_fifo_addr_t ticket_credit_update_t [N_LANE];
  typedef logic [N_LANE-1:0] handle_wflag_t;
  typedef handle_fifo_addr_t handle_wptr_t [N_LANE];
  typedef ticket_t tickets_t [N_LANE];
  typedef ticket_fifo_addr_t ticket_rptr_t [N_LANE];
  typedef logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ticket_raws_t;
  localparam int unsigned FRAME_JOIN_WAIT_WIDTH =
    (FRAME_JOIN_WAIT_CYCLES > 0) ? $clog2(FRAME_JOIN_WAIT_CYCLES + 1) : 1;
  typedef logic [FRAME_JOIN_WAIT_WIDTH-1:0] frame_join_wait_t;
  typedef enum logic [1:0] {
    FETCH_LANE_HOLD,
    FETCH_LANE_ADVANCE_ONLY,
    FETCH_LANE_LOAD,
    FETCH_LANE_LATE_DROP
  } fetch_lane_action_t;
  typedef fetch_lane_action_t fetch_lane_actions_t [N_LANE];
  localparam int unsigned FUTURE_FRAME_PAIR_COUNT = (N_LANE + 1) / 2;
  localparam int unsigned FUTURE_FRAME_LANE_WIDTH = (N_LANE <= 1) ? 1 : $clog2(N_LANE);

  typedef struct packed {
    logic                        valid;
    logic [FRAME_SERIAL_SIZE-1:0] serial;
    logic [FUTURE_FRAME_LANE_WIDTH-1:0] lane;
  } future_frame_candidate_t;

  function automatic future_frame_candidate_t choose_earlier_future_frame(
    input future_frame_candidate_t lhs,
    input future_frame_candidate_t rhs
  );
    future_frame_candidate_t result;

    if (!lhs.valid) begin
      result = rhs;
    end else if (!rhs.valid) begin
      result = lhs;
    end else if (rhs.serial < lhs.serial) begin
      result = rhs;
    end else begin
      result = lhs;
    end

    return result;
  endfunction

  function automatic logic serial_reached_or_passed(
    input logic [FRAME_SERIAL_SIZE-1:0] observed_serial,
    input logic [FRAME_SERIAL_SIZE-1:0] target_serial
  );
    logic [FRAME_SERIAL_SIZE-1:0] serial_delta;
    begin
      serial_delta = observed_serial - target_serial;
      serial_reached_or_passed = !serial_delta[FRAME_SERIAL_SIZE-1];
    end
  endfunction

`ifndef SYNTHESIS
  function automatic logic [FRAME_SERIAL_SIZE-1:0] tail_target_serial_from_raw(
    input logic [TICKET_FIFO_DATA_WIDTH-1:0] ticket_raw_v
  );
    begin
      if (ticket_raw_v[TICKET_ALT_SOP_LOC]) begin
        tail_target_serial_from_raw = ticket_raw_v[TICKET_SERIAL_HI:TICKET_SERIAL_LO];
      end else begin
        tail_target_serial_from_raw = ticket_raw_v[TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO];
      end
    end
  endfunction

  function automatic ticket_fifo_addr_t tail_status_slot(
    input logic [FRAME_SERIAL_SIZE-1:0] serial_v
  );
    begin
      tail_status_slot = ticket_fifo_addr_t'(serial_v);
    end
  endfunction
`endif

  typedef struct {
    ticket_rptr_t          ticket_rptr;
    ticket_credit_update_t ticket_credit_update;
    logic [N_LANE-1:0]     ticket_credit_update_valid;
    logic [N_LANE-1:0]     handle_we;
    handle_wflag_t         handle_wflag;
    handle_wptr_t          handle_wptr;
    logic                  page_we;
    logic [PAGE_RAM_DATA_WIDTH-1:0] page_wdata;
    page_ram_addr_t        page_waddr;
    page_ram_addr_t        frame_start_addr;
    page_ram_addr_t        frame_start_addr_last;
    logic [35:0]           frame_cnt;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial_this;
    frame_shr_cnt_t        frame_shr_cnt;
    frame_shr_cnt_t        frame_shr_cnt_this;
    frame_shr_cnt_t        frame_lane_shd_cnt [N_LANE];
    frame_shr_cnt_t        frame_lane_shd_cnt_this [N_LANE];
    frame_hit_cnt_t        frame_hit_cnt;
    frame_hit_cnt_t        frame_hit_cnt_this;
    frame_hit_cnt_t        frame_lane_hit_cnt [N_LANE];
    frame_hit_cnt_t        frame_lane_hit_cnt_this [N_LANE];
    logic [47:0]           frame_ts;
    logic [47:0]           running_ts;
    logic [N_LANE-1:0]     frame_lane_active;
    logic [N_LANE-1:0]     frame_lane_tail_seen;
    logic [N_LANE-1:0]     ingress_tail_seen_valid;
    logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] ingress_tail_serial_seen;
    logic [N_LANE-1:0]     ingress_tail_drop_seen;
    logic [N_LANE-1:0][47:0] ingress_tail_ts_seen;
    frame_join_wait_t      frame_join_wait;
    logic [N_LANE-1:0]     lane_masked;
    logic [N_LANE-1:0]     lane_skipped;
    logic                  subheader_has_accepted_lane;
    tickets_t              ticket;
    page_ram_addr_t        page_start_addr;
    page_length_t          page_length;
    logic [ALLOC_PAGE_FLOW_WIDTH-1:0] alloc_page_flow;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow_d1;
    logic                  write_trailer;
    logic                  tail_only_flush;
    logic                  reset_done;
  } page_allocator_reg_t;

  localparam page_allocator_reg_t PAGE_ALLOCATOR_REG_RESET = '{
    ticket_rptr: '{default:'0},
    ticket_credit_update: '{default:'0},
    ticket_credit_update_valid: '0,
    handle_we: '0,
    handle_wflag: '0,
    handle_wptr: '{default:'0},
    page_we: 1'b0,
    page_wdata: '0,
    page_waddr: '0,
    frame_start_addr: '0,
    frame_start_addr_last: '0,
    frame_cnt: '0,
    frame_serial: '0,
    frame_serial_this: '0,
    frame_shr_cnt: '0,
    frame_shr_cnt_this: '0,
    frame_lane_shd_cnt: '{default:'0},
    frame_lane_shd_cnt_this: '{default:'0},
    frame_hit_cnt: '0,
    frame_hit_cnt_this: '0,
    frame_lane_hit_cnt: '{default:'0},
    frame_lane_hit_cnt_this: '{default:'0},
    frame_ts: '0,
    running_ts: '0,
    frame_lane_active: '0,
    frame_lane_tail_seen: '0,
    ingress_tail_seen_valid: '0,
    ingress_tail_serial_seen: '0,
    ingress_tail_drop_seen: '0,
    ingress_tail_ts_seen: '0,
    frame_join_wait: '0,
    lane_masked: '0,
    lane_skipped: '0,
    subheader_has_accepted_lane: 1'b0,
    ticket: '{default:TICKET_DEFAULT},
    page_start_addr: '0,
    page_length: '0,
    alloc_page_flow: '0,
    write_meta_flow: '0,
    write_meta_flow_d1: '0,
    write_trailer: 1'b0,
    tail_only_flush: 1'b0,
    reset_done: 1'b0
  };

  typedef ticket_t page_allocator_if_read_ticket_ticket_t [N_LANE];

  typedef struct packed {
    logic [FRAME_SERIAL_SIZE-1:0] serial;
    frame_shr_cnt_t               n_subh;
    frame_hit_cnt_t               n_hit;
  } page_allocator_if_read_ticket_ticket_sop_t;

  page_allocator_state_t page_allocator_state;
  page_allocator_reg_t page_allocator;
  logic [N_LANE-1:0][FIFO_RAW_DELAY:1] page_allocator_is_pending_ticket_d;
  ticket_rptr_t page_allocator_ticket_rptr_d;
  (* preserve *) logic [N_LANE-1:0] fetch_pending_q;
  (* preserve *) tickets_t fetch_ticket_q;
  (* preserve *) ticket_raws_t fetch_ticket_raw_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_sop_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_curr_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_future_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_past_q;
  logic [N_LANE-1:0] fetch_lane_masked_q;
  logic [N_LANE-1:0] fetch_lane_credit_valid_q;
  logic [N_LANE-1:0] fetch_lane_reactivate_q;
  fetch_lane_actions_t fetch_lane_action_q;
  logic fetch_all_present_tk_sop_q;
  logic fetch_any_pending_sop_q;
  logic fetch_any_pending_curr_sop_q;
  logic fetch_future_frame_seen_q;
  logic fetch_start_new_frame_q;
  logic fetch_rebase_future_frame_q;
  logic fetch_join_absorb_only_q;
  logic [N_LANE-1:0] fetch_lanes_with_curr_sop_q;
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] fetch_curr_sop_n_subh_q;
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] fetch_curr_sop_n_hit_q;
  logic fetch_header_lane_valid_q;
  logic [FUTURE_FRAME_LANE_WIDTH-1:0] fetch_header_lane_q;
  logic [5:0] fetch_default_header_dt_type_q;
  logic [15:0] fetch_default_header_feb_id_q;
  logic [47:0] fetch_default_header_frame_ts_q;
  logic [47:0] fetch_default_header_running_ts_q;
  logic [5:0] fetch_header_dt_type_q;
  logic [15:0] fetch_header_feb_id_q;
  logic [47:0] fetch_header_frame_ts_q;
  logic [47:0] fetch_header_running_ts_q;
  logic [FRAME_SERIAL_SIZE-1:0] fetch_sop_serial_q;
  frame_shr_cnt_t fetch_sop_n_subh_q;
  frame_hit_cnt_t fetch_sop_n_hit_q;
  logic [FRAME_SERIAL_SIZE-1:0] fetch_future_frame_serial_q;
  logic [FUTURE_FRAME_LANE_WIDTH-1:0] fetch_future_frame_lane_q;
  logic [47:0] fetch_future_frame_ts_q;
  logic [N_LANE-1:0] fetch_tail_ready_q;
  logic [N_LANE-1:0] fetch_tail_dropped_q;
  logic [N_LANE-1:0][TICKET_FIFO_DEPTH-1:0] ingress_tail_status_valid_q;
  logic [N_LANE-1:0][TICKET_FIFO_DEPTH-1:0] ingress_tail_status_drop_q;
  logic [N_LANE-1:0][TICKET_FIFO_DEPTH-1:0][FRAME_SERIAL_SIZE-1:0] ingress_tail_status_serial_q;
  logic [N_LANE-1:0] page_allocator_is_pending_ticket;
  logic [N_LANE-1:0] page_allocator_is_pending_ticket_lane;
  logic [N_LANE-1:0] page_allocator_ticket_q_valid;
  logic [N_LANE-1:0] page_allocator_is_tk_sop;
  logic [N_LANE-1:0] page_allocator_is_tk_curr;
  logic [N_LANE-1:0] page_allocator_is_tk_future;
  logic [N_LANE-1:0] page_allocator_is_tk_past;
  logic [FRAME_SERIAL_SIZE-1:0] page_allocator_ticket_serial_ref;
  page_allocator_if_read_ticket_ticket_t page_allocator_if_read_ticket_ticket;
  page_allocator_if_read_ticket_ticket_sop_t page_allocator_if_read_ticket_ticket_sop;
  logic [N_LANE-1:0][PAGE_RAM_ADDR_WIDTH-1:0] page_allocator_if_alloc_blk_start;
  logic [N_LANE-1:0][HANDLE_LENGTH-1:0] page_allocator_if_write_handle_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_shr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_hdr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_trl_data;
  logic all_lanes_fetch_ready;
  logic all_present_tk_sop;
  logic any_pending_ticket;
  logic any_pending_curr_sop_ticket;
  logic any_pending_ticket_lane;
  logic any_pending_sop_ticket;
  logic frame_start_waiting_busy_lane;
  logic active_frame_waiting_busy_lane;
  logic active_frame_pending_nonfuture_ticket;
  logic frame_join_hold;
  logic all_active_lanes_tail_ready;
  logic [N_LANE-1:0] lanes_with_sop_ticket;
  logic [N_LANE-1:0] lanes_with_curr_sop_ticket;
  logic [5:0] header_dt_type;
  logic [15:0] header_feb_id;
  logic [47:0] header_frame_ts;
  logic [47:0] header_running_ts;
  logic packet_complete_pulse;
  logic [N_LANE-1:0] eop_flush_ack;
  logic [N_LANE-1:0] late_frame_drop_valid;
  logic [N_LANE-1:0][15:0] late_frame_drop_hdr_cnt;
  logic [N_LANE-1:0][15:0] late_frame_drop_shd_cnt;
  logic [N_LANE-1:0][15:0] late_frame_drop_hit_cnt;
  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] late_frame_drop_serial;
  logic [N_LANE-1:0][47:0] late_frame_drop_ts;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] late_frame_lane_credit_update;
  logic [N_LANE-1:0] late_frame_lane_credit_update_valid;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_complete_frame_start_addr;
  frame_shr_cnt_t packet_complete_shr_cnt;
  frame_hit_cnt_t packet_complete_hit_cnt;
  frame_shr_cnt_t packet_complete_lane_shd_cnt [N_LANE];
  frame_hit_cnt_t packet_complete_lane_hit_cnt [N_LANE];

  always_comb begin : proc_page_allocator_comb
    int unsigned total_subh_v;
    int unsigned total_hit_v;
    page_ram_addr_t alloc_offset_v;
    bit header_lane_selected_v;
    bit lane_tail_ready_v;
    total_subh_v = 0;
    total_hit_v = 0;
    all_lanes_fetch_ready = 1'b1;
    all_present_tk_sop = 1'b1;
    any_pending_ticket = 1'b0;
    any_pending_curr_sop_ticket = 1'b0;
    any_pending_ticket_lane = 1'b0;
    any_pending_sop_ticket = 1'b0;
    frame_start_waiting_busy_lane = 1'b0;
    active_frame_waiting_busy_lane = 1'b0;
    active_frame_pending_nonfuture_ticket = 1'b0;
    frame_join_hold = 1'b0;
    page_allocator_ticket_serial_ref = page_allocator.frame_serial;
    all_active_lanes_tail_ready = 1'b1;
    lanes_with_sop_ticket = '0;
    lanes_with_curr_sop_ticket = '0;
    header_dt_type = ingress_dt_type_i[0];
    header_feb_id = ingress_feb_id_i[0];
    header_frame_ts = ingress_frame_ts_i[0];
    header_running_ts = ingress_frame_ts_i[0];
    header_lane_selected_v = 1'b0;
    page_allocator_if_read_ticket_ticket_sop = '0;
    page_allocator_if_write_page_shr_data = '0;
    page_allocator_if_write_page_hdr_data = '0;
    page_allocator_if_write_page_trl_data = '0;
    page_allocator_is_tk_sop = '0;
    page_allocator_is_tk_curr = '0;
    page_allocator_is_tk_future = '0;
    page_allocator_is_tk_past = '0;
    page_allocator_is_pending_ticket_lane = '0;
    ticket_fifos_rd_addr_o = '0;
    handle_we_o = '0;
    alloc_offset_v = page_ram_addr_t'(SHD_SIZE);
    handle_wdata_o = '0;
    handle_waddr_o = '0;

    page_allocator_if_write_page_shr_data[35:32] = 4'b0001;
    page_allocator_if_write_page_shr_data[31:24] = page_allocator.running_ts[11:4];
    page_allocator_if_write_page_shr_data[23:16] = 8'd0;
    page_allocator_if_write_page_shr_data[15:8] = page_allocator.page_length[7:0];
    page_allocator_if_write_page_shr_data[7:0] = K237;

    if (page_allocator.frame_lane_active != '0) begin
      page_allocator_ticket_serial_ref = page_allocator.frame_serial_this;
    end

    page_allocator_if_write_page_trl_data[35:32] = 4'b0001;
    page_allocator_if_write_page_trl_data[7:0] = K284;

    unique case (page_allocator.write_meta_flow)
      3'd0: begin
        page_allocator_if_write_page_hdr_data[35:32] = 4'b0001;
        page_allocator_if_write_page_hdr_data[31:26] = header_dt_type;
        page_allocator_if_write_page_hdr_data[23:8] = header_feb_id;
        page_allocator_if_write_page_hdr_data[7:0] = K285;
      end
      3'd1: begin
        page_allocator_if_write_page_hdr_data[31:0] = page_allocator.frame_ts[47:16];
      end
      3'd2: begin
        page_allocator_if_write_page_hdr_data[31:16] = page_allocator.frame_ts[15:0];
        page_allocator_if_write_page_hdr_data[15:0] = page_allocator.frame_serial_this;
      end
      3'd3: begin
        page_allocator_if_write_page_hdr_data[16+MAX_SHR_CNT_BITS-1:16] = page_allocator.frame_shr_cnt;
        page_allocator_if_write_page_hdr_data[MAX_HIT_CNT_BITS-1:0] = page_allocator.frame_hit_cnt;
      end
      3'd4: begin
        page_allocator_if_write_page_hdr_data[30:0] = page_allocator.running_ts[30:0];
      end
      3'd5: begin
        page_allocator_if_write_page_hdr_data = page_allocator_if_write_page_trl_data;
      end
      default: begin
      end
    endcase

    for (int i = 0; i < N_LANE; i++) begin
      ticket_credit_update_o[i] = page_allocator.ticket_credit_update[i];
      ticket_credit_update_valid_o[i] = page_allocator.ticket_credit_update_valid[i];
      handle_wptr_o[i] = page_allocator.handle_wptr[i];
      eop_flush_ack_o[i] = eop_flush_ack[i];
      late_frame_drop_valid_o[i] = late_frame_drop_valid[i];
      late_frame_drop_hdr_cnt_o[i] = late_frame_drop_hdr_cnt[i];
      late_frame_drop_shd_cnt_o[i] = late_frame_drop_shd_cnt[i];
      late_frame_drop_hit_cnt_o[i] = late_frame_drop_hit_cnt[i];
      late_frame_drop_serial_o[i] = late_frame_drop_serial[i];
      late_frame_drop_ts_o[i] = late_frame_drop_ts[i];
      late_frame_lane_credit_update_o[i] = late_frame_lane_credit_update[i];
      late_frame_lane_credit_update_valid_o[i] = late_frame_lane_credit_update_valid[i];

      page_allocator_if_alloc_blk_start[i] = page_allocator.page_start_addr + alloc_offset_v;
      if (!page_allocator.lane_masked[i] && !page_allocator.lane_skipped[i]) begin
        alloc_offset_v = alloc_offset_v + page_ram_addr_t'(page_allocator.ticket[i].block_length);
      end
      page_allocator_if_write_handle_data[i][HANDLE_SRC_HI:HANDLE_SRC_LO] = page_allocator.ticket[i].lane_fifo_rd_offset;
      page_allocator_if_write_handle_data[i][HANDLE_DST_HI:HANDLE_DST_LO] = page_allocator_if_alloc_blk_start[i];
      page_allocator_if_write_handle_data[i][HANDLE_LEN_HI:HANDLE_LEN_LO] = page_allocator.ticket[i].block_length;

      page_allocator_is_pending_ticket[i] = (ingress_ticket_wptr[i] != page_allocator.ticket_rptr[i]);
      any_pending_ticket |= page_allocator_is_pending_ticket[i];

      page_allocator_if_read_ticket_ticket[i].ticket_ts = ticket_fifos_rd_data_i[i][TICKET_TS_HI:TICKET_TS_LO];
      page_allocator_if_read_ticket_ticket[i].lane_fifo_rd_offset =
        ticket_fifos_rd_data_i[i][TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO];
      page_allocator_if_read_ticket_ticket[i].block_length =
        ticket_fifos_rd_data_i[i][TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO];
      if (ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC]) begin
        page_allocator_if_read_ticket_ticket[i].frame_serial =
          ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
      end else begin
        page_allocator_if_read_ticket_ticket[i].frame_serial =
          ticket_fifos_rd_data_i[i][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO];
      end
      page_allocator_if_read_ticket_ticket[i].alert_eop = ticket_fifos_rd_data_i[i][TICKET_ALT_EOP_LOC];
      page_allocator_if_read_ticket_ticket[i].alert_sop = ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC];

      if (page_allocator_is_pending_ticket[i] && ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC]) begin
        page_allocator_is_tk_sop[i] = 1'b1;
        lanes_with_sop_ticket[i] = 1'b1;
        any_pending_sop_ticket = 1'b1;
        if (ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] ==
            page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_curr[i] = 1'b1;
          lanes_with_curr_sop_ticket[i] = 1'b1;
          any_pending_curr_sop_ticket = 1'b1;
          total_subh_v += int'(ticket_fifos_rd_data_i[i][TICKET_N_SUBH_HI:TICKET_N_SUBH_LO]);
          total_hit_v += int'(ticket_fifos_rd_data_i[i][TICKET_N_HIT_HI:TICKET_N_HIT_LO]);
          if (!header_lane_selected_v) begin
            header_dt_type = ticket_fifos_rd_data_i[i][TICKET_DT_TYPE_HI:TICKET_DT_TYPE_LO];
            header_feb_id = ticket_fifos_rd_data_i[i][TICKET_FEB_ID_HI:TICKET_FEB_ID_LO];
            header_frame_ts = ticket_fifos_rd_data_i[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
            header_running_ts = ticket_fifos_rd_data_i[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
            page_allocator_if_read_ticket_ticket_sop.serial =
              ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
            header_lane_selected_v = 1'b1;
          end
        end
      end

      if (!page_allocator_is_pending_ticket[i]) begin
        page_allocator_is_tk_future[i] = 1'b0;
        page_allocator_is_tk_past[i] = 1'b0;
      end else if (page_allocator_is_tk_sop[i]) begin
        if (ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] > page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end
        if (ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] < page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end
      end else begin
        if (page_allocator_if_read_ticket_ticket[i].frame_serial > page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end else if (page_allocator_if_read_ticket_ticket[i].frame_serial < page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end else begin
          if (ticket_fifos_rd_data_i[i][47:0] > page_allocator.running_ts) begin
            page_allocator_is_tk_future[i] = 1'b1;
          end
          if (ticket_fifos_rd_data_i[i][47:0] < page_allocator.running_ts) begin
            page_allocator_is_tk_past[i] = 1'b1;
          end
        end
      end

      page_allocator_is_pending_ticket_lane[i] = &page_allocator_is_pending_ticket_d[i];
      page_allocator_ticket_q_valid[i] = (page_allocator_ticket_rptr_d[i] == page_allocator.ticket_rptr[i]);
      any_pending_ticket_lane |= page_allocator_is_pending_ticket_lane[i];
      lane_tail_ready_v = page_allocator.frame_lane_tail_seen[i];
      if (page_allocator.ingress_tail_seen_valid[i] &&
          serial_reached_or_passed(
            page_allocator.ingress_tail_serial_seen[i],
            page_allocator.frame_serial_this
          )) begin
        lane_tail_ready_v = 1'b1;
      end
      if (!page_allocator_is_pending_ticket[i] && ingress_parser_busy_i[i]) begin
        frame_start_waiting_busy_lane = 1'b1;
      end
      if (page_allocator.frame_lane_active[i] &&
          !lane_tail_ready_v &&
          !page_allocator_is_pending_ticket[i] &&
          ingress_parser_busy_i[i]) begin
        active_frame_waiting_busy_lane = 1'b1;
      end
      if (page_allocator.frame_lane_active[i] &&
          page_allocator_is_pending_ticket[i]) begin
        // Future SOP tickets can belong to the next frame and should not block
        // retirement of the current one. Any unread non-SOP ticket still
        // belongs to the active frame, even if its timestamp is still ahead of
        // running_ts, so keep the frame alive until those subheaders are
        // drained.
        if (!page_allocator_is_tk_sop[i] ||
            !(page_allocator_is_pending_ticket_lane[i] &&
              page_allocator_ticket_q_valid[i] &&
              page_allocator_is_tk_future[i])) begin
          active_frame_pending_nonfuture_ticket = 1'b1;
        end
      end
      if ((page_allocator.frame_lane_active != '0) &&
          !page_allocator.frame_lane_active[i] &&
          page_allocator_is_pending_ticket[i] &&
          !page_allocator_is_tk_sop[i] &&
          (page_allocator_if_read_ticket_ticket[i].frame_serial ==
            page_allocator.frame_serial_this)) begin
        // A skewed whole-frame lane can surface its first body ticket after
        // another lane has already opened the frame. Keep that current-frame
        // ownership alive instead of retiring the frame and late-dropping the
        // straggling body ticket one cycle later.
        active_frame_pending_nonfuture_ticket = 1'b1;
      end
      if ((page_allocator.frame_lane_active != '0) &&
          !page_allocator.frame_lane_active[i] &&
          page_allocator_is_pending_ticket[i] &&
          page_allocator_is_tk_sop[i] &&
          page_allocator_is_tk_curr[i]) begin
        // An inactive lane can still surface the current-frame SOP after the
        // frame has already been opened by another lane. Keep the frame live
        // until that SOP is absorbed and the lane is reactivated, otherwise
        // the following body ticket ages into the late-drop path.
        active_frame_pending_nonfuture_ticket = 1'b1;
      end
      if ((page_allocator.frame_lane_active != '0) &&
          !page_allocator.frame_lane_active[i] &&
          !page_allocator_is_pending_ticket[i] &&
          ingress_parser_busy_i[i] &&
          (ingress_frame_ts_i[i] == page_allocator.frame_ts)) begin
        // A lane can still be parsing the current frame after another lane has
        // already opened it. Keep the frame alive until that parser either
        // surfaces its ticket or drains to idle; otherwise the late body
        // ticket can be reclassified against the next frame and dropped.
        active_frame_pending_nonfuture_ticket = 1'b1;
      end
      if (page_allocator_is_pending_ticket[i] && !page_allocator_is_pending_ticket_lane[i]) begin
        all_lanes_fetch_ready = 1'b0;
      end
      if (page_allocator_is_pending_ticket[i] && !page_allocator_ticket_q_valid[i]) begin
        all_lanes_fetch_ready = 1'b0;
      end
      if (page_allocator_is_pending_ticket[i] && !page_allocator_is_tk_sop[i]) begin
        all_present_tk_sop = 1'b0;
      end
      if (page_allocator.frame_lane_active[i] &&
          !(lane_tail_ready_v &&
            (!page_allocator_is_pending_ticket[i] || page_allocator_is_tk_future[i]))) begin
        all_active_lanes_tail_ready = 1'b0;
      end

      handle_we_o[i] = page_allocator.handle_we[i];
      handle_wdata_o[i] = {page_allocator.handle_wflag[i], page_allocator_if_write_handle_data[i]};
      handle_waddr_o[i] = page_allocator.handle_wptr[i] - handle_fifo_addr_t'(1);
      ticket_fifos_rd_addr_o[i] = page_allocator.ticket_rptr[i];
      tk_future_o[i] = page_allocator_is_tk_future[i];
    end

    if ((page_allocator.frame_join_wait != '0) &&
        (page_allocator.frame_lane_active != '0) &&
        !any_pending_sop_ticket) begin
      frame_join_hold = 1'b1;
    end

    page_allocator_if_read_ticket_ticket_sop.n_subh = frame_shr_cnt_t'(total_subh_v);
    page_allocator_if_read_ticket_ticket_sop.n_hit = frame_hit_cnt_t'(total_hit_v);

    page_we_o = page_allocator.page_we;
    page_waddr_o = page_allocator.page_waddr;
    fetch_ticket_active_o =
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_CLASSIFY_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_ACCUM_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_SUMMARIZE_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET);
    alloc_page_active_o = (page_allocator_state == PAGE_ALLOCATOR_ALLOC_PAGE);
    write_head_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_HEAD);
    write_tail_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_TAIL);
    write_page_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE);
    write_meta_flow_o = page_allocator.write_meta_flow;
    write_meta_flow_d1_o = page_allocator.write_meta_flow_d1;
    frame_start_addr_o = page_allocator.frame_start_addr;
    frame_shr_cnt_this_o = page_allocator.frame_shr_cnt_this;
    frame_hit_cnt_this_o = page_allocator.frame_hit_cnt_this;
    for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
      frame_lane_shd_cnt_this_o[lane_idx] = page_allocator.frame_lane_shd_cnt_this[lane_idx];
      frame_lane_hit_cnt_this_o[lane_idx] = page_allocator.frame_lane_hit_cnt_this[lane_idx];
      packet_complete_lane_shd_cnt_o[lane_idx] = packet_complete_lane_shd_cnt[lane_idx];
      packet_complete_lane_hit_cnt_o[lane_idx] = packet_complete_lane_hit_cnt[lane_idx];
    end
    packet_complete_frame_start_addr_o = packet_complete_frame_start_addr;
    packet_complete_shr_cnt_o = packet_complete_shr_cnt;
    packet_complete_hit_cnt_o = packet_complete_hit_cnt;
    packet_complete_pulse_o = packet_complete_pulse;
    unique case (page_allocator_state)
      PAGE_ALLOCATOR_WRITE_PAGE: page_wdata_o = page_allocator_if_write_page_shr_data;
      PAGE_ALLOCATOR_WRITE_HEAD,
      PAGE_ALLOCATOR_WRITE_TAIL: page_wdata_o = page_allocator_if_write_page_hdr_data;
      default: page_wdata_o = '0;
    endcase
  end

  always_ff @(posedge d_clk) begin : proc_page_allocator
    for (int i = 0; i < N_LANE; i++) begin
      page_allocator.ticket_credit_update_valid[i] <= 1'b0;
      page_allocator.handle_we[i] <= 1'b0;
      page_allocator.handle_wflag[i] <= 1'b0;
    end
    page_allocator.page_we <= 1'b0;
    packet_complete_pulse <= 1'b0;
    packet_complete_frame_start_addr <= packet_complete_frame_start_addr;
    packet_complete_shr_cnt <= packet_complete_shr_cnt;
    packet_complete_hit_cnt <= packet_complete_hit_cnt;
    packet_complete_lane_shd_cnt <= packet_complete_lane_shd_cnt;
    packet_complete_lane_hit_cnt <= packet_complete_lane_hit_cnt;
    eop_flush_ack <= '0;
    late_frame_drop_valid <= '0;
    late_frame_drop_hdr_cnt <= '{default:'0};
    late_frame_drop_shd_cnt <= '{default:'0};
    late_frame_drop_hit_cnt <= '{default:'0};
    late_frame_drop_serial <= '{default:'0};
    late_frame_drop_ts <= '{default:'0};
    late_frame_lane_credit_update <= '{default:'0};
    late_frame_lane_credit_update_valid <= '0;

    for (int i = 0; i < N_LANE; i++) begin
      if (ingress_tail_bypass_valid_i[i]) begin
        ticket_fifo_addr_t tail_status_slot_v;

        tail_status_slot_v = ticket_fifo_addr_t'(ingress_tail_bypass_serial_i[i]);
        page_allocator.ingress_tail_seen_valid[i] <= 1'b1;
        page_allocator.ingress_tail_serial_seen[i] <= ingress_tail_bypass_serial_i[i];
        page_allocator.ingress_tail_drop_seen[i] <= ingress_tail_bypass_drop_i[i];
        page_allocator.ingress_tail_ts_seen[i] <= ingress_tail_bypass_ts_i[i];
        ingress_tail_status_valid_q[i][tail_status_slot_v] <= 1'b1;
        ingress_tail_status_drop_q[i][tail_status_slot_v] <= ingress_tail_bypass_drop_i[i];
        ingress_tail_status_serial_q[i][tail_status_slot_v] <= ingress_tail_bypass_serial_i[i];
      end
      if (page_allocator.frame_lane_active[i] &&
          ((ingress_tail_bypass_valid_i[i] &&
            serial_reached_or_passed(
              ingress_tail_bypass_serial_i[i],
              page_allocator.frame_serial_this
            )) ||
           (page_allocator.ingress_tail_seen_valid[i] &&
            serial_reached_or_passed(
              page_allocator.ingress_tail_serial_seen[i],
              page_allocator.frame_serial_this
            )))) begin
        page_allocator.frame_lane_tail_seen[i] <= 1'b1;
      end
    end

    unique case (page_allocator_state)
      PAGE_ALLOCATOR_IDLE: begin
        if ((page_allocator.frame_lane_active != '0) &&
            all_active_lanes_tail_ready &&
            !active_frame_pending_nonfuture_ticket &&
            (page_allocator.frame_cnt != '0)) begin
`ifndef SYNTHESIS
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display(
                "[opq_pa_decision] t=%0t idle_to_write_tail running_ts=0x%0h frame_lane_active=0x%0h page_len=%0d frame_shd=%0d frame_hit=%0d pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ingress_busy=0x%0h",
                $time,
                page_allocator.running_ts,
                page_allocator.frame_lane_active,
                page_allocator.page_length,
                page_allocator.frame_shr_cnt,
                page_allocator.frame_hit_cnt,
                page_allocator_is_pending_ticket,
                page_allocator_is_pending_ticket_lane,
                page_allocator_ticket_q_valid,
                page_allocator_is_tk_sop,
                page_allocator_is_tk_curr,
                page_allocator_is_tk_future,
                page_allocator_is_tk_past,
                ingress_parser_busy_i
              );
            end
`endif
          eop_flush_ack <= '1;
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr + page_ram_addr_t'(3);
          page_allocator.frame_start_addr_last <= page_allocator.frame_start_addr;
          page_allocator.frame_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
          page_allocator.write_meta_flow <= WRITE_META_FLOW_WIDTH'(3);
          page_allocator.write_trailer <= 1'b1;
          page_allocator.tail_only_flush <= 1'b1;
          page_allocator.frame_lane_active <= '0;
          page_allocator.frame_lane_tail_seen <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_WRITE_TAIL;
        end else if (all_lanes_fetch_ready &&
                     any_pending_ticket &&
                     !active_frame_waiting_busy_lane &&
                     !frame_join_hold &&
                     !(all_present_tk_sop &&
                       any_pending_curr_sop_ticket &&
                       frame_start_waiting_busy_lane)) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t idle_to_fetch running_ts=0x%0h frame_lane_active=0x%0h pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ingress_busy=0x%0h",
              $time,
              page_allocator.running_ts,
              page_allocator.frame_lane_active,
              page_allocator_is_pending_ticket,
              page_allocator_is_pending_ticket_lane,
              page_allocator_ticket_q_valid,
              page_allocator_is_tk_sop,
              page_allocator_is_tk_curr,
              page_allocator_is_tk_future,
              page_allocator_is_tk_past,
              ingress_parser_busy_i
            );
          end
`endif
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end
        end

      PAGE_ALLOCATOR_FETCH_TICKET: begin
        if (!all_lanes_fetch_ready) begin
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end else begin
          for (int i = 0; i < N_LANE; i++) begin
            logic [FRAME_SERIAL_SIZE-1:0] tail_target_serial_v;
            logic tail_ready_now_v;
            logic tail_drop_now_v;
            logic live_tail_matches_v;
            logic seen_tail_matches_v;
            logic shadow_tail_exact_v;
            ticket_fifo_addr_t tail_status_slot_v;

            fetch_pending_q[i] <= page_allocator_is_pending_ticket[i];
            fetch_ticket_q[i] <= page_allocator_if_read_ticket_ticket[i];
            fetch_ticket_raw_q[i] <= ticket_fifos_rd_data_i[i];
            if (ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC]) begin
              tail_target_serial_v = ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
            end else begin
              tail_target_serial_v = page_allocator_if_read_ticket_ticket[i].frame_serial;
            end
            live_tail_matches_v =
              ingress_tail_bypass_valid_i[i] &&
              serial_reached_or_passed(
                ingress_tail_bypass_serial_i[i],
                tail_target_serial_v
              );
            seen_tail_matches_v =
              page_allocator.ingress_tail_seen_valid[i] &&
              serial_reached_or_passed(
                page_allocator.ingress_tail_serial_seen[i],
                tail_target_serial_v
              );
            tail_status_slot_v = ticket_fifo_addr_t'(tail_target_serial_v);
            shadow_tail_exact_v =
              ingress_tail_status_valid_q[i][tail_status_slot_v] &&
              (ingress_tail_status_serial_q[i][tail_status_slot_v] == tail_target_serial_v);
            tail_ready_now_v = live_tail_matches_v || seen_tail_matches_v;
            tail_drop_now_v = 1'b0;
            if (ingress_tail_bypass_valid_i[i] &&
                (ingress_tail_bypass_serial_i[i] == tail_target_serial_v)) begin
              tail_drop_now_v = ingress_tail_bypass_drop_i[i];
            end else if (shadow_tail_exact_v) begin
              tail_drop_now_v = ingress_tail_status_drop_q[i][tail_status_slot_v];
            end
            fetch_tail_ready_q[i] <= tail_ready_now_v;
            fetch_tail_dropped_q[i] <= tail_drop_now_v;
          end
          // Fallback header fields are only used when no current-frame SOP lane
          // is selected. Seed them from stable parser inputs here and let the
          // registered winning header lane override them in SUMMARIZE_TICKET.
          fetch_default_header_dt_type_q <= ingress_dt_type_i[0];
          fetch_default_header_feb_id_q <= ingress_feb_id_i[0];
          fetch_default_header_frame_ts_q <= ingress_frame_ts_i[0];
          fetch_default_header_running_ts_q <= ingress_frame_ts_i[0];
          page_allocator_state <= PAGE_ALLOCATOR_CLASSIFY_TICKET;
        end
        end

      PAGE_ALLOCATOR_CLASSIFY_TICKET: begin
        logic [N_LANE-1:0] tk_sop_v;
        logic [N_LANE-1:0] tk_curr_v;
        logic [N_LANE-1:0] tk_curr_sop_usable_v;
        logic [N_LANE-1:0] tk_future_v;
        logic [N_LANE-1:0] tk_past_v;
        logic [N_LANE-1:0] lanes_with_curr_sop_v;
        logic header_lane_selected_v;
        logic [FUTURE_FRAME_LANE_WIDTH-1:0] header_lane_v;
        logic all_present_tk_sop_v;
        logic any_pending_sop_v;
        logic any_pending_curr_sop_v;
        logic [FRAME_SERIAL_SIZE-1:0] header_serial_v;
        logic [FRAME_SERIAL_SIZE-1:0] ticket_serial_ref_v;

        tk_sop_v = '0;
        tk_curr_v = '0;
        tk_curr_sop_usable_v = '0;
        tk_future_v = '0;
        tk_past_v = '0;
        lanes_with_curr_sop_v = '0;
        header_lane_selected_v = 1'b0;
        header_lane_v = '0;
        all_present_tk_sop_v = 1'b1;
        any_pending_sop_v = 1'b0;
        any_pending_curr_sop_v = 1'b0;
        header_serial_v = '0;
        ticket_serial_ref_v = page_allocator.frame_serial;

        if (page_allocator.frame_lane_active != '0) begin
          ticket_serial_ref_v = page_allocator.frame_serial_this;
        end

        for (int i = 0; i < N_LANE; i++) begin
          if (fetch_pending_q[i] && fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
            tk_sop_v[i] = 1'b1;
            any_pending_sop_v = 1'b1;
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] ==
                ticket_serial_ref_v) begin
              tk_curr_v[i] = 1'b1;
              if (!fetch_tail_dropped_q[i]) begin
                tk_curr_sop_usable_v[i] = 1'b1;
                lanes_with_curr_sop_v[i] = 1'b1;
                any_pending_curr_sop_v = 1'b1;
                if (!header_lane_selected_v) begin
                  header_lane_v = FUTURE_FRAME_LANE_WIDTH'(i);
                  header_serial_v = fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
                  header_lane_selected_v = 1'b1;
                end
              end
            end
          end

          if (!fetch_pending_q[i]) begin
            tk_future_v[i] = 1'b0;
            tk_past_v[i] = 1'b0;
          end else if (tk_sop_v[i]) begin
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] > ticket_serial_ref_v) begin
              tk_future_v[i] = 1'b1;
            end
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] < ticket_serial_ref_v) begin
              tk_past_v[i] = 1'b1;
            end
          end else begin
            if (fetch_ticket_q[i].frame_serial > ticket_serial_ref_v) begin
              tk_future_v[i] = 1'b1;
            end else if (fetch_ticket_q[i].frame_serial < ticket_serial_ref_v) begin
              tk_past_v[i] = 1'b1;
            end else begin
              if (fetch_ticket_q[i].ticket_ts > page_allocator.running_ts) begin
                tk_future_v[i] = 1'b1;
              end
              if (fetch_ticket_q[i].ticket_ts < page_allocator.running_ts) begin
                tk_past_v[i] = 1'b1;
              end
            end
          end

          if (fetch_pending_q[i] && !tk_sop_v[i]) begin
            all_present_tk_sop_v = 1'b0;
          end

          if (tk_curr_sop_usable_v[i]) begin
            fetch_curr_sop_n_subh_q[i] <=
              frame_shr_cnt_t'(fetch_ticket_raw_q[i][TICKET_N_SUBH_HI:TICKET_N_SUBH_LO]);
            fetch_curr_sop_n_hit_q[i] <=
              frame_hit_cnt_t'(fetch_ticket_raw_q[i][TICKET_N_HIT_HI:TICKET_N_HIT_LO]);
          end else begin
            fetch_curr_sop_n_subh_q[i] <= '0;
            fetch_curr_sop_n_hit_q[i] <= '0;
          end
        end

        fetch_tk_sop_q <= tk_sop_v;
        fetch_tk_curr_q <= tk_curr_v;
        fetch_tk_future_q <= tk_future_v;
        fetch_tk_past_q <= tk_past_v;
        fetch_all_present_tk_sop_q <= all_present_tk_sop_v;
        fetch_any_pending_sop_q <= any_pending_sop_v;
        fetch_any_pending_curr_sop_q <= any_pending_curr_sop_v;
        fetch_lanes_with_curr_sop_q <= lanes_with_curr_sop_v;
        fetch_header_lane_valid_q <= header_lane_selected_v;
        fetch_header_lane_q <= header_lane_v;
        fetch_sop_serial_q <= header_serial_v;
        page_allocator_state <= PAGE_ALLOCATOR_ACCUM_TICKET;
        end

      PAGE_ALLOCATOR_ACCUM_TICKET: begin
        int unsigned total_subh_v;
        int unsigned total_hit_v;
        int unsigned pair_subh_v [FUTURE_FRAME_PAIR_COUNT];
        int unsigned pair_hit_v [FUTURE_FRAME_PAIR_COUNT];

        total_subh_v = 0;
        total_hit_v = 0;

        for (int i = 0; i < FUTURE_FRAME_PAIR_COUNT; i++) begin
          pair_subh_v[i] = 0;
          pair_hit_v[i] = 0;
          if ((2 * i) < N_LANE) begin
            pair_subh_v[i] += int'(fetch_curr_sop_n_subh_q[2 * i]);
            pair_hit_v[i] += int'(fetch_curr_sop_n_hit_q[2 * i]);
          end
          if ((2 * i + 1) < N_LANE) begin
            pair_subh_v[i] += int'(fetch_curr_sop_n_subh_q[2 * i + 1]);
            pair_hit_v[i] += int'(fetch_curr_sop_n_hit_q[2 * i + 1]);
          end
          total_subh_v += pair_subh_v[i];
          total_hit_v += pair_hit_v[i];
        end

        fetch_sop_n_subh_q <= frame_shr_cnt_t'(total_subh_v);
        fetch_sop_n_hit_q <= frame_hit_cnt_t'(total_hit_v);
        page_allocator_state <= PAGE_ALLOCATOR_SUMMARIZE_TICKET;
        end

      PAGE_ALLOCATOR_SUMMARIZE_TICKET: begin
        logic future_frame_seen_v;
        logic [FRAME_SERIAL_SIZE-1:0] future_frame_serial_v;
        logic [5:0] header_dt_type_v;
        logic [15:0] header_feb_id_v;
        logic [47:0] header_frame_ts_v;
        logic [47:0] header_running_ts_v;
        future_frame_candidate_t future_candidates_v [N_LANE];
        future_frame_candidate_t future_pairs_v [FUTURE_FRAME_PAIR_COUNT];
        future_frame_candidate_t future_best_v;

        future_frame_seen_v = 1'b0;
        future_frame_serial_v = page_allocator.frame_serial;
        header_dt_type_v = fetch_default_header_dt_type_q;
        header_feb_id_v = fetch_default_header_feb_id_q;
        header_frame_ts_v = fetch_default_header_frame_ts_q;
        header_running_ts_v = fetch_default_header_running_ts_q;
        future_best_v = '{
          valid: 1'b0,
          serial: page_allocator.frame_serial,
          lane: '0
        };

        if (fetch_header_lane_valid_q) begin
          header_dt_type_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_DT_TYPE_HI:TICKET_DT_TYPE_LO];
          header_feb_id_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FEB_ID_HI:TICKET_FEB_ID_LO];
          header_frame_ts_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
          header_running_ts_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
        end

        for (int i = 0; i < N_LANE; i++) begin
          future_candidates_v[i] = '{
            valid: fetch_pending_q[i] && fetch_tk_sop_q[i] && !fetch_tk_past_q[i],
            serial: fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO],
            lane: FUTURE_FRAME_LANE_WIDTH'(i)
          };
        end

        for (int i = 0; i < FUTURE_FRAME_PAIR_COUNT; i++) begin
          if ((2 * i + 1) < N_LANE) begin
            future_pairs_v[i] = choose_earlier_future_frame(
              future_candidates_v[2 * i],
              future_candidates_v[2 * i + 1]
            );
          end else begin
            future_pairs_v[i] = future_candidates_v[2 * i];
          end
        end

        for (int i = 0; i < FUTURE_FRAME_PAIR_COUNT; i++) begin
          future_best_v = choose_earlier_future_frame(future_best_v, future_pairs_v[i]);
        end

        future_frame_seen_v = future_best_v.valid;
        future_frame_serial_v = future_best_v.serial;
        fetch_header_dt_type_q <= header_dt_type_v;
        fetch_header_feb_id_q <= header_feb_id_v;
        fetch_header_frame_ts_q <= header_frame_ts_v;
        fetch_header_running_ts_q <= header_running_ts_v;
        fetch_future_frame_seen_q <= future_frame_seen_v;
        fetch_future_frame_serial_q <= future_frame_serial_v;
        fetch_future_frame_lane_q <= future_best_v.lane;
        fetch_join_absorb_only_q <=
          (page_allocator.frame_join_wait != '0) &&
          (page_allocator.frame_lane_active != '0) &&
          fetch_any_pending_sop_q;
        fetch_start_new_frame_q <=
          (page_allocator.frame_lane_active == '0) &&
          fetch_all_present_tk_sop_q &&
          fetch_any_pending_curr_sop_q;
        page_allocator_state <= PAGE_ALLOCATOR_DECIDE_TICKET;
        end

      PAGE_ALLOCATOR_DECIDE_TICKET: begin
        logic [N_LANE-1:0] lane_masked_v;
        logic [N_LANE-1:0] lane_credit_valid_v;
        logic [N_LANE-1:0] lane_reactivate_v;
        logic [47:0] future_frame_ts_v;
        logic rebase_future_frame_v;
        fetch_lane_actions_t lane_action_v;

        lane_masked_v = '0;
        lane_credit_valid_v = '0;
        lane_reactivate_v = '0;
        future_frame_ts_v = page_allocator.frame_ts;
        if (fetch_future_frame_seen_q) begin
          future_frame_ts_v =
            fetch_ticket_raw_q[fetch_future_frame_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
        end
        rebase_future_frame_v =
          (page_allocator.frame_lane_active == '0) &&
          fetch_all_present_tk_sop_q &&
          fetch_any_pending_sop_q &&
          !fetch_any_pending_curr_sop_q &&
          fetch_future_frame_seen_q &&
          (fetch_future_frame_serial_q > page_allocator.frame_serial) &&
          (future_frame_ts_v > page_allocator.frame_ts);
        fetch_future_frame_ts_q <= future_frame_ts_v;
        fetch_rebase_future_frame_q <= rebase_future_frame_v;

        for (int i = 0; i < N_LANE; i++) begin
          lane_action_v[i] = FETCH_LANE_HOLD;
          if (!fetch_pending_q[i]) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_tk_curr_q[i] &&
                       fetch_tk_sop_q[i] &&
                       fetch_tail_dropped_q[i]) begin
            lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b1;
          end else if (fetch_join_absorb_only_q) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
            if ((page_allocator.frame_lane_active != '0) &&
                !page_allocator.frame_lane_active[i] &&
                fetch_tk_sop_q[i] &&
                fetch_tk_curr_q[i]) begin
              // During the join window, absorb a late current-frame SOP from
              // an inactive lane and mark that lane active before its body
              // ticket appears on the next fetch.
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = !fetch_tail_dropped_q[i];
            end else if (fetch_tk_sop_q[i] &&
                         fetch_tk_past_q[i] &&
                         (fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO] +
                           48'(FRAME_DURATION_CYCLES) == page_allocator.frame_ts)) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = 1'b1;
            end
          end else if (rebase_future_frame_v) begin
            lane_masked_v[i] = 1'b0;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_start_new_frame_q) begin
            if (fetch_tk_curr_q[i]) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_masked_v[i] = 1'b0;
              lane_credit_valid_v[i] = 1'b1;
            end else if (fetch_tk_future_q[i]) begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end else if (fetch_tk_past_q[i]) begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end else begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end
          end else if ((page_allocator.frame_lane_active != '0) &&
                       !page_allocator.frame_lane_active[i] &&
                       fetch_tk_curr_q[i] &&
                       fetch_tk_sop_q[i] &&
                       !fetch_tail_dropped_q[i]) begin
            // Outside the explicit join window, a late current-frame SOP still
            // belongs to the active frame. Consume it and reactivate the lane
            // so its body ticket stays on the live-frame path.
            lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b1;
            lane_reactivate_v[i] = 1'b1;
          end else if (fetch_tk_future_q[i]) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_tk_past_q[i]) begin
            if ((page_allocator.frame_lane_active != '0) &&
                fetch_tk_sop_q[i] &&
                (fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO] +
                  48'(FRAME_DURATION_CYCLES) == page_allocator.frame_ts)) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = 1'b1;
            end else begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end
          end else if ((page_allocator.frame_lane_active == '0) && !fetch_tk_sop_q[i]) begin
            // A frame cannot start from body traffic alone. Keep current non-SOP
            // tickets parked until a matching SOP claims the frame, or let them
            // age into the late-drop path once they fall behind running_ts.
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else begin
            lane_action_v[i] = FETCH_LANE_LOAD;
            lane_masked_v[i] = 1'b0;
            lane_credit_valid_v[i] = 1'b1;
          end
        end

        for (int i = 0; i < N_LANE; i++) begin
          fetch_lane_masked_q[i] <= lane_masked_v[i];
          fetch_lane_credit_valid_q[i] <= lane_credit_valid_v[i];
          fetch_lane_reactivate_q[i] <= lane_reactivate_v[i];
          fetch_lane_action_q[i] <= lane_action_v[i];
        end
        page_allocator_state <= PAGE_ALLOCATOR_APPLY_TICKET;
        end

      PAGE_ALLOCATOR_APPLY_TICKET: begin
        page_allocator.lane_masked <= '0;
        page_allocator.lane_skipped <= '0;
        page_allocator.subheader_has_accepted_lane <= 1'b0;
        page_allocator.page_length <= '0;

        if (fetch_join_absorb_only_q) begin
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fetch_lane_credit_valid_q[i];
            page_allocator.lane_masked[i] <= 1'b1;
            if (fetch_lane_action_q[i] == FETCH_LANE_ADVANCE_ONLY) begin
              page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              if (fetch_lane_reactivate_q[i]) begin
                page_allocator.frame_lane_active[i] <= 1'b1;
              end
            end else begin
              page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
            end
          end

          page_allocator.alloc_page_flow <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else if (fetch_rebase_future_frame_q) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t fetch_rebase_future_frame old_serial=0x%0h new_serial=0x%0h old_frame_ts=0x%0h new_frame_ts=0x%0h pending=0x%0h",
              $time,
              page_allocator.frame_serial,
              fetch_future_frame_serial_q,
              page_allocator.frame_ts,
              fetch_future_frame_ts_q,
              fetch_pending_q
            );
          end
`endif
          page_allocator.frame_serial <= fetch_future_frame_serial_q;
          page_allocator.alloc_page_flow <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else begin
          if (fetch_start_new_frame_q) begin
            page_allocator.frame_shr_cnt_this <= fetch_sop_n_subh_q;
            page_allocator.frame_hit_cnt_this <= fetch_sop_n_hit_q;
            page_allocator.frame_serial_this <= fetch_sop_serial_q;
            page_allocator.frame_serial <= page_allocator.frame_serial + 1'b1;
          end

          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fetch_lane_credit_valid_q[i];
            page_allocator.lane_masked[i] <= fetch_lane_masked_q[i];

            unique case (fetch_lane_action_q[i])
              FETCH_LANE_HOLD: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
              FETCH_LANE_ADVANCE_ONLY: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
                if (fetch_lane_reactivate_q[i]) begin
                  page_allocator.frame_lane_active[i] <= 1'b1;
                  page_allocator.frame_lane_tail_seen[i] <= fetch_tail_ready_q[i];
                end
              end
              FETCH_LANE_LOAD: begin
                page_allocator.ticket[i] <= fetch_ticket_q[i];
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
                if (page_allocator.frame_lane_active[i]) begin
                  page_allocator.frame_lane_tail_seen[i] <= fetch_tail_ready_q[i];
                end
              end
              FETCH_LANE_LATE_DROP: begin
                late_frame_drop_valid[i] <= 1'b1;
                if (fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
                  late_frame_drop_hdr_cnt[i] <= 16'd1;
                  late_frame_drop_shd_cnt[i] <= '0;
                  late_frame_drop_hit_cnt[i] <= '0;
                  late_frame_drop_serial[i] <= fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
                  late_frame_drop_ts[i] <= fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
                end else begin
                  late_frame_drop_hdr_cnt[i] <= '0;
                  late_frame_drop_shd_cnt[i] <= 16'd1;
                  late_frame_drop_hit_cnt[i] <=
                    {{(16-MAX_PKT_LENGTH_BITS){1'b0}}, fetch_ticket_q[i].block_length};
                  late_frame_drop_serial[i] <= fetch_ticket_q[i].frame_serial;
                  late_frame_drop_ts[i] <= fetch_ticket_q[i].ticket_ts;
                end
                late_frame_lane_credit_update[i] <= fetch_ticket_q[i].block_length;
                late_frame_lane_credit_update_valid[i] <= 1'b1;
                page_allocator.ticket[i] <= TICKET_DEFAULT;
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              end
              default: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
            endcase
          end

          page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
          page_allocator.alloc_page_flow <= '0;

          if (fetch_start_new_frame_q) begin
`ifndef SYNTHESIS
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display(
                "[opq_pa_decision] t=%0t fetch_to_write_head header_ts=0x%0h frame_serial_this=0x%0h n_subh=%0d n_hit=%0d lanes_curr_sop=0x%0h tail_ready=0x%0h tail_dropped=0x%0h ingress_busy=0x%0h",
                $time,
                fetch_header_frame_ts_q,
                fetch_sop_serial_q,
                fetch_sop_n_subh_q,
                fetch_sop_n_hit_q,
                fetch_lanes_with_curr_sop_q,
                fetch_tail_ready_q,
                fetch_tail_dropped_q,
                ingress_parser_busy_i
              );
            end
`endif
            page_allocator.frame_shr_cnt <= '0;
            page_allocator.frame_hit_cnt <= '0;
            page_allocator.page_we <= 1'b1;
            if (&(fetch_lanes_with_curr_sop_q & fetch_tail_ready_q)) begin
              page_allocator.page_waddr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
              page_allocator.frame_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
              page_allocator.frame_start_addr_last <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
            end else begin
              page_allocator.page_waddr <= page_allocator.page_start_addr;
              page_allocator.frame_start_addr <= page_allocator.page_start_addr;
              page_allocator.frame_start_addr_last <= page_allocator.page_start_addr;
            end
            page_allocator.frame_ts <= fetch_header_frame_ts_q;
            // Seed each frame from its first subheader slot, not from a live
            // parser-running timestamp that may already have advanced past
            // unread tickets by the time the allocator opens the frame.
            page_allocator.running_ts <= fetch_header_running_ts_q;
            // Only fast-close frames that are already completely empty. Frames
            // with zero hits can still carry real empty subheaders that must
            // be emitted through the normal page path.
            page_allocator.write_trailer <=
              &(fetch_lanes_with_curr_sop_q & fetch_tail_ready_q) &&
              (fetch_sop_n_subh_q == '0) &&
              (fetch_sop_n_hit_q == '0);
            page_allocator.tail_only_flush <= 1'b0;
            page_allocator.frame_lane_active <= fetch_lanes_with_curr_sop_q;
            page_allocator.frame_lane_tail_seen <= fetch_lanes_with_curr_sop_q & fetch_tail_ready_q;
            page_allocator_state <= PAGE_ALLOCATOR_WRITE_HEAD;
            page_allocator.write_meta_flow <= '0;
          end
        end
        end

      PAGE_ALLOCATOR_WRITE_HEAD: begin
        if (int'(page_allocator.write_meta_flow) < 2) begin
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr + page_ram_addr_t'(page_allocator.write_meta_flow) +
            page_ram_addr_t'(1);
        end else begin
          if (page_allocator.write_trailer) begin
            page_allocator.page_we <= 1'b1;
            page_allocator.page_waddr <= page_allocator.frame_start_addr_last +
              page_ram_addr_t'(page_allocator.write_meta_flow) + page_ram_addr_t'(1);
            page_allocator_state <= PAGE_ALLOCATOR_WRITE_TAIL;
          end else begin
            page_allocator.page_we <= 1'b0;
            page_allocator.page_start_addr <= page_allocator.frame_start_addr + page_ram_addr_t'(HDR_SIZE);
            page_allocator.frame_cnt <= page_allocator.frame_cnt + 1'b1;
            page_allocator.frame_ts <= page_allocator.frame_ts + 48'(FRAME_DURATION_CYCLES);
            if ((page_allocator.frame_lane_active != '0) &&
                (page_allocator.frame_lane_active != '1)) begin
              page_allocator.frame_join_wait <= frame_join_wait_t'(FRAME_JOIN_WAIT_CYCLES);
            end else begin
              page_allocator.frame_join_wait <= '0;
            end
            page_allocator_state <= PAGE_ALLOCATOR_IDLE;
          end
        end
        page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
        end

      PAGE_ALLOCATOR_WRITE_TAIL: begin
        if (int'(page_allocator.write_meta_flow) < 4) begin
          page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr_last +
            page_ram_addr_t'(page_allocator.write_meta_flow) + page_ram_addr_t'(1);
        end else if (int'(page_allocator.write_meta_flow) < 5) begin
          page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr - page_ram_addr_t'(1);
        end else begin
          page_allocator.write_meta_flow <= '0;
          page_allocator.write_trailer <= 1'b0;
          page_allocator.frame_shr_cnt_this <= page_allocator.frame_shr_cnt;
          page_allocator.frame_hit_cnt_this <= page_allocator.frame_hit_cnt;
          page_allocator.frame_lane_shd_cnt_this <= page_allocator.frame_lane_shd_cnt;
          page_allocator.frame_lane_hit_cnt_this <= page_allocator.frame_lane_hit_cnt;
          packet_complete_frame_start_addr <= page_allocator.frame_start_addr_last;
          packet_complete_shr_cnt <= page_allocator.frame_shr_cnt;
          packet_complete_hit_cnt <= page_allocator.frame_hit_cnt;
          packet_complete_lane_shd_cnt <= page_allocator.frame_lane_shd_cnt;
          packet_complete_lane_hit_cnt <= page_allocator.frame_lane_hit_cnt;
          packet_complete_pulse <= 1'b1;
          if (page_allocator.tail_only_flush) begin
            page_allocator.page_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
            page_allocator.tail_only_flush <= 1'b0;
          end else begin
            // A zero-hit SOP+EOP frame reaches WRITE_TAIL directly from WRITE_HEAD.
            // Retire that frame here because it skipped the normal active-frame
            // completion path in IDLE.
            page_allocator.frame_cnt <= page_allocator.frame_cnt + 1'b1;
            page_allocator.frame_lane_active <= '0;
            page_allocator.frame_lane_tail_seen <= '0;
            page_allocator.page_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(HDR_SIZE + TRL_SIZE);
            page_allocator.frame_ts <= page_allocator.frame_ts + 48'(FRAME_DURATION_CYCLES);
          end
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
          page_allocator.frame_join_wait <= '0;
          page_allocator.frame_shr_cnt <= '0;
          page_allocator.frame_hit_cnt <= '0;
          page_allocator.frame_lane_shd_cnt <= '{default:'0};
          page_allocator.frame_lane_hit_cnt <= '{default:'0};
        end
        end

      PAGE_ALLOCATOR_ALLOC_PAGE: begin
        int unsigned lane_sel_v;
        logic lane_accept_v;
        logic lane_skip_v;
        logic subheader_has_accepted_lane_v;
        logic lane_masked_v;
        logic lane_skipped_v;
        ticket_t ticket_v;
        page_length_t page_length_v;
        frame_shr_cnt_t frame_shr_cnt_v;
        frame_hit_cnt_t frame_hit_cnt_v;
        frame_shr_cnt_t frame_lane_shd_cnt_v [N_LANE];
        frame_hit_cnt_t frame_lane_hit_cnt_v [N_LANE];

        lane_sel_v = int'(page_allocator.alloc_page_flow);
        lane_accept_v = 1'b0;
        lane_skip_v = 1'b0;
        subheader_has_accepted_lane_v = page_allocator.subheader_has_accepted_lane;
        lane_masked_v = page_allocator.lane_masked[lane_sel_v];
        lane_skipped_v = page_allocator.lane_skipped[lane_sel_v];
        ticket_v = page_allocator.ticket[lane_sel_v];
        page_length_v = page_allocator.page_length;
        frame_shr_cnt_v = page_allocator.frame_shr_cnt;
        frame_hit_cnt_v = page_allocator.frame_hit_cnt;
        for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
          frame_lane_shd_cnt_v[lane_idx] = page_allocator.frame_lane_shd_cnt[lane_idx];
          frame_lane_hit_cnt_v[lane_idx] = page_allocator.frame_lane_hit_cnt[lane_idx];
        end

        if (page_allocator.alloc_page_flow == ALLOC_PAGE_FLOW_LAST) begin
          page_allocator.alloc_page_flow <= '0;
        end else begin
          page_allocator.alloc_page_flow <= page_allocator.alloc_page_flow + 1'b1;
        end

        if (!lane_skipped_v && !lane_masked_v &&
            (ticket_v.block_length != '0) &&
            ((frame_hit_cnt_v + frame_hit_cnt_t'(ticket_v.block_length)) <= frame_hit_cnt_t'(N_HIT))) begin
          lane_accept_v = 1'b1;
          if (!subheader_has_accepted_lane_v) begin
            subheader_has_accepted_lane_v = 1'b1;
            frame_shr_cnt_v = frame_shr_cnt_v + 1'b1;
          end
          frame_hit_cnt_v = frame_hit_cnt_v + frame_hit_cnt_t'(ticket_v.block_length);
          frame_lane_shd_cnt_v[lane_sel_v] = frame_lane_shd_cnt_v[lane_sel_v] + frame_shr_cnt_t'(1);
          frame_lane_hit_cnt_v[lane_sel_v] =
            frame_lane_hit_cnt_v[lane_sel_v] + frame_hit_cnt_t'(ticket_v.block_length);
        end else if (!lane_skipped_v && !lane_masked_v &&
                     (ticket_v.block_length != '0)) begin
          lane_skip_v = 1'b1;
          page_allocator.lane_skipped[lane_sel_v] <= 1'b1;
        end

        if (ticket_v.block_length == '0) begin
          page_allocator.handle_we[lane_sel_v] <= 1'b0;
        end else if (lane_skipped_v || lane_skip_v) begin
          page_allocator.handle_we[lane_sel_v] <= 1'b1;
          page_allocator.handle_wflag[lane_sel_v] <= 1'b1;
          page_allocator.handle_wptr[lane_sel_v] <=
            page_allocator.handle_wptr[lane_sel_v] + handle_fifo_addr_t'(1);
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display("[opq_boundary] t=%0t lane%0d handle_skip ts=0x%0h src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h",
              $time,
              lane_sel_v,
              ticket_v.ticket_ts,
              ticket_v.lane_fifo_rd_offset,
              page_allocator_if_alloc_blk_start[lane_sel_v],
              ticket_v.block_length,
              page_allocator.handle_wptr[lane_sel_v] + handle_fifo_addr_t'(1),
              page_allocator.ticket_rptr[lane_sel_v]);
          end
`endif
        end else if (lane_masked_v) begin
          page_allocator.handle_we[lane_sel_v] <= 1'b0;
        end else if (lane_accept_v) begin
          page_allocator.handle_we[lane_sel_v] <= 1'b1;
          page_allocator.handle_wptr[lane_sel_v] <=
            page_allocator.handle_wptr[lane_sel_v] + handle_fifo_addr_t'(1);
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display("[opq_boundary] t=%0t lane%0d handle_accept ts=0x%0h src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h page_len_next=%0d",
              $time,
              lane_sel_v,
              ticket_v.ticket_ts,
              ticket_v.lane_fifo_rd_offset,
              page_allocator_if_alloc_blk_start[lane_sel_v],
              ticket_v.block_length,
              page_allocator.handle_wptr[lane_sel_v] + handle_fifo_addr_t'(1),
              page_allocator.ticket_rptr[lane_sel_v],
              page_length_v + page_length_t'(ticket_v.block_length));
          end
`endif
          page_length_v = page_length_v + page_length_t'(ticket_v.block_length);
        end else begin
          page_allocator.handle_we[lane_sel_v] <= 1'b0;
        end

        page_allocator.subheader_has_accepted_lane <= subheader_has_accepted_lane_v;
        page_allocator.page_length <= page_length_v;
        page_allocator.frame_shr_cnt <= frame_shr_cnt_v;
        page_allocator.frame_hit_cnt <= frame_hit_cnt_v;
        for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
          page_allocator.frame_lane_shd_cnt[lane_idx] <= frame_lane_shd_cnt_v[lane_idx];
          page_allocator.frame_lane_hit_cnt[lane_idx] <= frame_lane_hit_cnt_v[lane_idx];
        end

        if (page_allocator.alloc_page_flow == ALLOC_PAGE_FLOW_LAST) begin
          page_allocator.alloc_page_flow <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_FINALIZE_PAGE;
        end
        end

      PAGE_ALLOCATOR_FINALIZE_PAGE: begin
        page_allocator.alloc_page_flow <= '0;
        if (&page_allocator.lane_masked || !page_allocator.subheader_has_accepted_lane) begin
          page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else begin
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.page_start_addr;
          page_allocator_state <= PAGE_ALLOCATOR_WRITE_PAGE;
        end
        end

      PAGE_ALLOCATOR_WRITE_PAGE: begin
        page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
        page_allocator.page_start_addr <= page_allocator.page_waddr +
          page_ram_addr_t'(page_allocator.page_length) + page_ram_addr_t'(SHD_SIZE);
        page_allocator.frame_join_wait <= '0;
        page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end

      PAGE_ALLOCATOR_RESET: begin
        if (!page_allocator.reset_done) begin
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(TICKET_FIFO_MAX_CREDIT);
            page_allocator.ticket_credit_update_valid[i] <= 1'b1;
          end
          page_allocator.reset_done <= 1'b1;
        end else if (!d_reset) begin
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end
        end

      default: begin
      end
    endcase

    page_allocator.write_meta_flow_d1 <= page_allocator.write_meta_flow;

    if ((page_allocator.frame_join_wait != '0) &&
        (page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
        (page_allocator.frame_lane_active != '0)) begin
      page_allocator.frame_join_wait <= page_allocator.frame_join_wait - frame_join_wait_t'(1);
    end

    for (int i = 0; i < N_LANE; i++) begin
      if (d_reset) begin
        page_allocator_is_pending_ticket_d[i] <= '0;
        page_allocator_ticket_rptr_d[i] <= '0;
      end else begin
        page_allocator_ticket_rptr_d[i] <= page_allocator.ticket_rptr[i];
        for (int j = 1; j <= FIFO_RAW_DELAY; j++) begin
          if (j == 1) begin
            page_allocator_is_pending_ticket_d[i][j] <= page_allocator_is_pending_ticket[i];
          end else begin
            page_allocator_is_pending_ticket_d[i][j] <= page_allocator_is_pending_ticket_d[i][j-1];
          end
        end
      end
    end

    if (d_reset) begin
      page_allocator <= PAGE_ALLOCATOR_REG_RESET;
      page_allocator.reset_done <= 1'b0;
      page_allocator_state <= PAGE_ALLOCATOR_RESET;
      fetch_pending_q <= '0;
      fetch_ticket_q <= '{default:TICKET_DEFAULT};
      fetch_ticket_raw_q <= '0;
      fetch_lane_masked_q <= '0;
      fetch_lane_credit_valid_q <= '0;
      fetch_lane_reactivate_q <= '0;
      fetch_all_present_tk_sop_q <= 1'b0;
      fetch_any_pending_sop_q <= 1'b0;
      fetch_any_pending_curr_sop_q <= 1'b0;
      fetch_future_frame_seen_q <= 1'b0;
      fetch_start_new_frame_q <= 1'b0;
      fetch_rebase_future_frame_q <= 1'b0;
      fetch_join_absorb_only_q <= 1'b0;
      fetch_lanes_with_curr_sop_q <= '0;
      fetch_curr_sop_n_subh_q <= '0;
      fetch_curr_sop_n_hit_q <= '0;
      fetch_header_lane_valid_q <= 1'b0;
      fetch_header_lane_q <= '0;
      fetch_default_header_dt_type_q <= '0;
      fetch_default_header_feb_id_q <= '0;
      fetch_default_header_frame_ts_q <= '0;
      fetch_default_header_running_ts_q <= '0;
      fetch_header_dt_type_q <= '0;
      fetch_header_feb_id_q <= '0;
      fetch_header_frame_ts_q <= '0;
      fetch_header_running_ts_q <= '0;
      fetch_sop_serial_q <= '0;
      fetch_sop_n_subh_q <= '0;
      fetch_sop_n_hit_q <= '0;
      fetch_future_frame_serial_q <= '0;
      fetch_future_frame_lane_q <= '0;
      fetch_future_frame_ts_q <= '0;
      fetch_tail_ready_q <= '0;
      fetch_tail_dropped_q <= '0;
      ingress_tail_status_valid_q <= '0;
      ingress_tail_status_drop_q <= '0;
      ingress_tail_status_serial_q <= '0;
      for (int i = 0; i < N_LANE; i++) begin
        fetch_lane_action_q[i] <= FETCH_LANE_HOLD;
      end
      packet_complete_frame_start_addr <= '0;
      packet_complete_shr_cnt <= '0;
      packet_complete_hit_cnt <= '0;
      packet_complete_lane_shd_cnt <= '{default:'0};
      packet_complete_lane_hit_cnt <= '{default:'0};
    end
  end

  property p_page_allocator_reset_enters_reset;
    @(posedge d_clk) d_reset |=> (page_allocator_state == PAGE_ALLOCATOR_RESET);
  endproperty
  ap_page_allocator_reset_enters_reset: assert property (p_page_allocator_reset_enters_reset);

  property p_page_allocator_idle_fetch_requires_all_lanes;
    @(posedge d_clk) disable iff (d_reset)
      ((page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
       !((page_allocator.frame_lane_active != '0) &&
         all_active_lanes_tail_ready &&
         !active_frame_pending_nonfuture_ticket &&
         (page_allocator.frame_cnt != '0)) &&
       all_lanes_fetch_ready &&
       any_pending_ticket &&
       !active_frame_waiting_busy_lane &&
       !frame_join_hold &&
       !(all_present_tk_sop &&
         any_pending_curr_sop_ticket &&
         frame_start_waiting_busy_lane))
      |=> (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET);
  endproperty
  ap_page_allocator_idle_fetch_requires_all_lanes: assert property (p_page_allocator_idle_fetch_requires_all_lanes);

  property p_page_allocator_write_page_returns_idle;
    @(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE)
      |=> (page_allocator_state == PAGE_ALLOCATOR_IDLE);
  endproperty
  ap_page_allocator_write_page_returns_idle: assert property (p_page_allocator_write_page_returns_idle);

`ifndef SYNTHESIS
  for (genvar g = 0; g < N_LANE; g++) begin : gen_tail_bypass_formal
    property p_tail_bypass_captures_shadow;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past(ingress_tail_bypass_valid_i[g])
        |->
        page_allocator.ingress_tail_seen_valid[g] &&
        (page_allocator.ingress_tail_serial_seen[g] == $past(ingress_tail_bypass_serial_i[g])) &&
        (page_allocator.ingress_tail_drop_seen[g] == $past(ingress_tail_bypass_drop_i[g])) &&
        (page_allocator.ingress_tail_ts_seen[g] == $past(ingress_tail_bypass_ts_i[g])) &&
        ingress_tail_status_valid_q[g][tail_status_slot($past(ingress_tail_bypass_serial_i[g]))] &&
        (ingress_tail_status_drop_q[g][tail_status_slot($past(ingress_tail_bypass_serial_i[g]))] ==
          $past(ingress_tail_bypass_drop_i[g])) &&
        (ingress_tail_status_serial_q[g][tail_status_slot($past(ingress_tail_bypass_serial_i[g]))] ==
          $past(ingress_tail_bypass_serial_i[g]));
    endproperty
    ap_tail_bypass_captures_shadow: assert property (p_tail_bypass_captures_shadow)
      else $error("OPQ_PAGE_ALLOCATOR tail bypass did not persist into the per-serial shadow state");

    property p_fetch_tail_ready_accepts_live_bypass;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
              all_lanes_fetch_ready &&
                ingress_tail_bypass_valid_i[g] &&
              serial_reached_or_passed(
                ingress_tail_bypass_serial_i[g],
                tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])
              ))
        |-> fetch_tail_ready_q[g];
    endproperty
    ap_fetch_tail_ready_accepts_live_bypass: assert property (p_fetch_tail_ready_accepts_live_bypass)
      else $error("OPQ_PAGE_ALLOCATOR live ingress tail bypass did not mark the target packet tail-ready");

    property p_fetch_tail_drop_uses_live_exact_bypass;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
              all_lanes_fetch_ready &&
              ingress_tail_bypass_valid_i[g] &&
              (ingress_tail_bypass_serial_i[g] ==
                tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])))
        |-> fetch_tail_ready_q[g] &&
            (fetch_tail_dropped_q[g] == $past(ingress_tail_bypass_drop_i[g]));
    endproperty
    ap_fetch_tail_drop_uses_live_exact_bypass: assert property (p_fetch_tail_drop_uses_live_exact_bypass)
      else $error("OPQ_PAGE_ALLOCATOR exact live bypass serial did not drive fetch_tail_dropped_q");

    property p_fetch_tail_drop_uses_shadow_exact_bypass;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
              all_lanes_fetch_ready &&
              !(ingress_tail_bypass_valid_i[g] &&
                (ingress_tail_bypass_serial_i[g] ==
                  tail_target_serial_from_raw(ticket_fifos_rd_data_i[g]))) &&
              ingress_tail_status_valid_q[g][tail_status_slot(
                tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])
              )] &&
              (ingress_tail_status_serial_q[g][tail_status_slot(
                tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])
              )] == tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])))
        |-> fetch_tail_ready_q[g] &&
            (fetch_tail_dropped_q[g] ==
              $past(ingress_tail_status_drop_q[g][tail_status_slot(
                tail_target_serial_from_raw(ticket_fifos_rd_data_i[g])
              )]));
    endproperty
    ap_fetch_tail_drop_uses_shadow_exact_bypass: assert property (p_fetch_tail_drop_uses_shadow_exact_bypass)
      else $error("OPQ_PAGE_ALLOCATOR shadowed bypass state did not drive fetch_tail_dropped_q for an earlier packet");

    property p_late_drop_serial_matches_ticket;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET) &&
              (fetch_lane_action_q[g] == FETCH_LANE_LATE_DROP))
        |-> late_frame_drop_valid[g] &&
            (late_frame_drop_serial[g] ==
              ($past(fetch_ticket_raw_q[g][TICKET_ALT_SOP_LOC]) ?
                $past(fetch_ticket_raw_q[g][TICKET_SERIAL_HI:TICKET_SERIAL_LO]) :
                $past(fetch_ticket_q[g].frame_serial)));
    endproperty
    ap_late_drop_serial_matches_ticket: assert property (p_late_drop_serial_matches_ticket)
      else $error("OPQ_PAGE_ALLOCATOR late-drop serial did not match the dropped ticket identity");

`ifdef OPQ_NATIVE_FORMAL_STRICT
    property p_busy_parser_same_frame_keeps_frame_live;
      @(posedge d_clk) disable iff (d_reset)
        (page_allocator.frame_lane_active != '0) &&
        !page_allocator.frame_lane_active[g] &&
        !page_allocator_is_pending_ticket[g] &&
        ingress_parser_busy_i[g] &&
        (ingress_frame_ts_i[g] == page_allocator.frame_ts)
        |->
        active_frame_pending_nonfuture_ticket;
    endproperty
    ap_busy_parser_same_frame_keeps_frame_live: assert property (p_busy_parser_same_frame_keeps_frame_live)
      else $error("OPQ_PAGE_ALLOCATOR retired a live frame while an inactive lane parser was still busy on that same frame timestamp");

    property p_active_frame_body_serial_is_not_past;
      @(posedge d_clk) disable iff (d_reset)
        (page_allocator.frame_lane_active != '0) &&
        page_allocator_is_pending_ticket[g] &&
        !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
        (ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO] == page_allocator.running_ts) &&
        (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] ==
          page_allocator.frame_serial_this)
        |->
        !page_allocator_is_tk_past[g];
    endproperty
    ap_active_frame_body_serial_is_not_past: assert property (p_active_frame_body_serial_is_not_past)
      else $error("OPQ_PAGE_ALLOCATOR active-frame body ticket fell into the past path despite matching the live frame serial");

    property p_fetch_active_frame_body_serial_is_not_past;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
              all_lanes_fetch_ready &&
              (page_allocator.frame_lane_active != '0) &&
              page_allocator_is_pending_ticket[g] &&
              !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
              (ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO] == page_allocator.running_ts) &&
              (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] ==
                page_allocator.frame_serial_this))
        |->
        fetch_pending_q[g] &&
        ($past(ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO]) ==
          $past(page_allocator.frame_serial_this)) &&
        ($past(ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO]) ==
          $past(page_allocator.running_ts)) &&
        !fetch_tk_past_q[g];
    endproperty
    ap_fetch_active_frame_body_serial_is_not_past: assert property (p_fetch_active_frame_body_serial_is_not_past)
      else $error("OPQ_PAGE_ALLOCATOR registered fetch path marked an active-frame body ticket as past");

    property p_fetch_current_join_sop_reactivates_inactive_lane;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) &&
              (page_allocator.frame_lane_active != '0) &&
              !page_allocator.frame_lane_active[g] &&
              fetch_pending_q[g] &&
              fetch_tk_curr_q[g] &&
              fetch_tk_sop_q[g] &&
              !fetch_tail_dropped_q[g])
        |->
        (fetch_lane_action_q[g] == FETCH_LANE_ADVANCE_ONLY) &&
        fetch_lane_credit_valid_q[g] &&
        fetch_lane_reactivate_q[g];
    endproperty
    ap_fetch_current_join_sop_reactivates_inactive_lane: assert property (p_fetch_current_join_sop_reactivates_inactive_lane)
      else $error("OPQ_PAGE_ALLOCATOR failed to absorb a late current-frame SOP and reactivate its inactive lane");

    property p_apply_reactivate_marks_lane_active;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET) &&
              (fetch_lane_action_q[g] == FETCH_LANE_ADVANCE_ONLY) &&
              fetch_lane_reactivate_q[g])
        |->
        page_allocator.frame_lane_active[g];
    endproperty
    ap_apply_reactivate_marks_lane_active: assert property (p_apply_reactivate_marks_lane_active)
      else $error("OPQ_PAGE_ALLOCATOR consumed a join SOP but failed to mark the lane active");

    cp_tail_bypass_shadow_drop_window: cover property (@(posedge d_clk) disable iff (d_reset)
      ingress_tail_bypass_valid_i[g] && ingress_tail_bypass_drop_i[g]
      ##1 page_allocator.ingress_tail_seen_valid[g]
      ##[1:16] ((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) && all_lanes_fetch_ready)
      ##1 fetch_tail_dropped_q[g]);

    cp_active_frame_body_serial_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      page_allocator_is_pending_ticket[g] &&
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
      all_lanes_fetch_ready &&
      !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
      (ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO] == page_allocator.running_ts) &&
      (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] ==
        page_allocator.frame_serial_this)
      ##1 fetch_pending_q[g] && !fetch_tk_past_q[g]);

    cp_current_join_sop_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      !page_allocator.frame_lane_active[g] &&
      page_allocator_is_pending_ticket[g] &&
      page_allocator_is_tk_sop[g] &&
      page_allocator_is_tk_curr[g]
      ##[1:4] ((page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) &&
               fetch_pending_q[g] &&
               fetch_tk_sop_q[g] &&
               fetch_tk_curr_q[g] &&
               !fetch_tail_dropped_q[g])
      ##1 fetch_lane_reactivate_q[g]);

    cp_busy_parser_same_frame_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      !page_allocator.frame_lane_active[g] &&
      !page_allocator_is_pending_ticket[g] &&
      ingress_parser_busy_i[g] &&
      (ingress_frame_ts_i[g] == page_allocator.frame_ts)
      ##1 active_frame_pending_nonfuture_ticket);
`endif

    cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
      all_lanes_fetch_ready &&
      !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
      (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] !=
        page_allocator_ticket_serial_ref)
      ##1 fetch_pending_q[g]);
  end
`endif

endmodule

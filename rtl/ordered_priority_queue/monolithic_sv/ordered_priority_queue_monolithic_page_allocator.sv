//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_page_allocator
// Version : 26.0.0
// Date    : 20260413
// Change  : Extract monolithic page allocator from VHDL into standalone SV
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_page_allocator #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned N_SHD = 128,
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
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A = 48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2,
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
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned ALLOC_PAGE_FLOW_WIDTH = (N_LANE <= 1) ? 1 : $clog2(N_LANE),
  parameter int unsigned WRITE_META_FLOW_WIDTH = 3,
  parameter int unsigned PAGE_LENGTH_WIDTH = MAX_PKT_LENGTH_BITS + CHANNEL_WIDTH
) (
  input  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ingress_ticket_wptr,
  input  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0]     ticket_fifos_rd_data_i,
  input  logic [5:0]                                        dt_type0,
  input  logic [15:0]                                       feb_id0,
  input  logic [47:0]                                       ingress_running_ts0,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_credit_update_o,
  output logic [N_LANE-1:0]                                 ticket_credit_update_valid_o,
  output logic [N_LANE-1:0][HANDLE_LENGTH:0]                handle_wdata_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_waddr_o,
  output logic [N_LANE-1:0]                                 handle_we_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_wptr_o,
  output logic                                              page_we_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    page_waddr_o,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                    page_wdata_o,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_fifos_rd_addr_o,
  output logic [N_LANE-1:0]                                 tk_future_o,
  output logic                                              fetch_ticket_active_o,
  output logic                                              write_head_active_o,
  output logic                                              write_tail_active_o,
  output logic                                              write_page_active_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_d1_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    frame_start_addr_o,
  output logic [MAX_SHR_CNT_BITS-1:0]                       frame_shr_cnt_this_o,
  output logic [MAX_HIT_CNT_BITS-1:0]                       frame_hit_cnt_this_o,
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
  localparam int unsigned TICKET_SERIAL_LO = 0;
  localparam int unsigned TICKET_SERIAL_HI = FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_N_SUBH_LO = FRAME_SERIAL_SIZE;
  localparam int unsigned TICKET_N_SUBH_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  localparam int unsigned TICKET_N_HIT_LO = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  localparam int unsigned TICKET_N_HIT_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;
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
    logic                  alert_eop;
    logic                  alert_sop;
  } ticket_t;

  localparam ticket_t TICKET_DEFAULT = '{
    ticket_ts: '0,
    lane_fifo_rd_offset: '0,
    block_length: '0,
    alert_eop: 1'b0,
    alert_sop: 1'b0
  };

  typedef enum logic [2:0] {
    PAGE_ALLOCATOR_IDLE,
    PAGE_ALLOCATOR_FETCH_TICKET,
    PAGE_ALLOCATOR_WRITE_HEAD,
    PAGE_ALLOCATOR_WRITE_TAIL,
    PAGE_ALLOCATOR_ALLOC_PAGE,
    PAGE_ALLOCATOR_WRITE_PAGE,
    PAGE_ALLOCATOR_RESET
  } page_allocator_state_t;

  typedef ticket_fifo_addr_t ticket_credit_update_t [N_LANE];
  typedef logic [N_LANE-1:0] handle_wflag_t;
  typedef handle_fifo_addr_t handle_wptr_t [N_LANE];
  typedef ticket_t tickets_t [N_LANE];
  typedef ticket_fifo_addr_t ticket_rptr_t [N_LANE];

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
    frame_hit_cnt_t        frame_hit_cnt;
    frame_hit_cnt_t        frame_hit_cnt_this;
    logic [47:0]           frame_ts;
    logic [47:0]           running_ts;
    logic [N_LANE-1:0]     lane_masked;
    logic [N_LANE-1:0]     lane_skipped;
    tickets_t              ticket;
    page_ram_addr_t        page_start_addr;
    page_length_t          page_length;
    logic [ALLOC_PAGE_FLOW_WIDTH-1:0] alloc_page_flow;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow_d1;
    logic                  write_trailer;
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
    frame_hit_cnt: '0,
    frame_hit_cnt_this: '0,
    frame_ts: '0,
    running_ts: '0,
    lane_masked: '0,
    lane_skipped: '0,
    ticket: '{default:TICKET_DEFAULT},
    page_start_addr: '0,
    page_length: '0,
    alloc_page_flow: '0,
    write_meta_flow: '0,
    write_meta_flow_d1: '0,
    write_trailer: 1'b0,
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
  logic [N_LANE-1:0] page_allocator_is_pending_ticket;
  logic [N_LANE-1:0] page_allocator_is_pending_ticket_lane;
  logic [N_LANE-1:0] page_allocator_is_tk_sop;
  logic [N_LANE-1:0] page_allocator_is_tk_future;
  logic [N_LANE-1:0] page_allocator_is_tk_past;
  page_allocator_if_read_ticket_ticket_t page_allocator_if_read_ticket_ticket;
  page_allocator_if_read_ticket_ticket_sop_t page_allocator_if_read_ticket_ticket_sop;
  logic [N_LANE-1:0][PAGE_RAM_ADDR_WIDTH-1:0] page_allocator_if_alloc_blk_start;
  logic [N_LANE-1:0][HANDLE_LENGTH-1:0] page_allocator_if_write_handle_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_shr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_hdr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_trl_data;

  always_comb begin : proc_page_allocator_comb
    int unsigned total_subh_v;
    int unsigned total_hit_v;

    total_subh_v = 0;
    total_hit_v = 0;
    page_allocator_if_read_ticket_ticket_sop = '0;
    page_allocator_if_write_page_shr_data = '0;
    page_allocator_if_write_page_hdr_data = '0;
    page_allocator_if_write_page_trl_data = '0;
    page_allocator_is_tk_sop = '0;
    page_allocator_is_tk_future = '0;
    page_allocator_is_tk_past = '0;
    page_allocator_is_pending_ticket_lane = '0;
    ticket_fifos_rd_addr_o = '0;
    handle_we_o = '0;
    handle_wdata_o = '0;
    handle_waddr_o = '0;

    page_allocator_if_write_page_shr_data[35:32] = 4'b0001;
    page_allocator_if_write_page_shr_data[31:24] = page_allocator.running_ts[11:4];
    page_allocator_if_write_page_shr_data[23:8] = 16'(page_allocator.page_length);
    page_allocator_if_write_page_shr_data[7:0] = K237;

    unique case (page_allocator.write_meta_flow)
      3'd0: begin
        page_allocator_if_write_page_hdr_data[35:32] = 4'b0001;
        page_allocator_if_write_page_hdr_data[31:26] = dt_type0;
        page_allocator_if_write_page_hdr_data[23:8] = feb_id0;
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
        page_allocator_if_write_page_hdr_data[30:0] = ingress_running_ts0[30:0];
      end
      3'd5: begin
        page_allocator_if_write_page_hdr_data = page_allocator_if_write_page_trl_data;
      end
      default: begin
      end
    endcase

    page_allocator_if_write_page_trl_data[35:32] = 4'b0001;
    page_allocator_if_write_page_trl_data[7:0] = K284;

    for (int i = 0; i < N_LANE; i++) begin
      ticket_credit_update_o[i] = page_allocator.ticket_credit_update[i];
      ticket_credit_update_valid_o[i] = page_allocator.ticket_credit_update_valid[i];
      handle_wptr_o[i] = page_allocator.handle_wptr[i];

      if (i > 0) begin
        page_allocator_if_alloc_blk_start[i] =
          page_allocator.page_start_addr + page_ram_addr_t'(page_allocator.ticket[i-1].block_length) +
          page_ram_addr_t'(SHD_SIZE);
      end else begin
        page_allocator_if_alloc_blk_start[i] = page_allocator.page_start_addr + page_ram_addr_t'(SHD_SIZE);
      end
      page_allocator_if_write_handle_data[i][HANDLE_SRC_HI:HANDLE_SRC_LO] = page_allocator.ticket[i].lane_fifo_rd_offset;
      page_allocator_if_write_handle_data[i][HANDLE_DST_HI:HANDLE_DST_LO] = page_allocator_if_alloc_blk_start[i];
      page_allocator_if_write_handle_data[i][HANDLE_LEN_HI:HANDLE_LEN_LO] = page_allocator.ticket[i].block_length;

      page_allocator_is_pending_ticket[i] = (ingress_ticket_wptr[i] != page_allocator.ticket_rptr[i]);

      page_allocator_if_read_ticket_ticket[i].ticket_ts = ticket_fifos_rd_data_i[i][TICKET_TS_HI:TICKET_TS_LO];
      page_allocator_if_read_ticket_ticket[i].lane_fifo_rd_offset =
        ticket_fifos_rd_data_i[i][TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO];
      page_allocator_if_read_ticket_ticket[i].block_length =
        ticket_fifos_rd_data_i[i][TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO];
      page_allocator_if_read_ticket_ticket[i].alert_eop = ticket_fifos_rd_data_i[i][TICKET_ALT_EOP_LOC];
      page_allocator_if_read_ticket_ticket[i].alert_sop = ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC];

      total_subh_v += int'(ticket_fifos_rd_data_i[i][TICKET_N_SUBH_HI:TICKET_N_SUBH_LO]);
      total_hit_v += int'(ticket_fifos_rd_data_i[i][TICKET_N_HIT_HI:TICKET_N_HIT_LO]);

      if (ticket_fifos_rd_data_i[i][TICKET_ALT_SOP_LOC]) begin
        page_allocator_is_tk_sop[i] = 1'b1;
      end

      if (page_allocator_is_tk_sop[i]) begin
        if (ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] >= (page_allocator.frame_serial + 1'b1)) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end
        if (ticket_fifos_rd_data_i[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] < page_allocator.frame_serial) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end
      end else begin
        if (ticket_fifos_rd_data_i[i][47:0] > page_allocator.running_ts) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end
        if (ticket_fifos_rd_data_i[i][47:0] < page_allocator.running_ts) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end
      end

      page_allocator_is_pending_ticket_lane[i] = &page_allocator_is_pending_ticket_d[i];

      handle_we_o[i] = page_allocator.handle_we[i];
      handle_wdata_o[i] = {page_allocator.handle_wflag[i], page_allocator_if_write_handle_data[i]};
      handle_waddr_o[i] = page_allocator.handle_wptr[i] - handle_fifo_addr_t'(1);
      ticket_fifos_rd_addr_o[i] = page_allocator.ticket_rptr[i];
      tk_future_o[i] = page_allocator_is_tk_future[i];
    end

    page_allocator_if_read_ticket_ticket_sop.serial = ticket_fifos_rd_data_i[0][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
    page_allocator_if_read_ticket_ticket_sop.n_subh = frame_shr_cnt_t'(total_subh_v);
    page_allocator_if_read_ticket_ticket_sop.n_hit = frame_hit_cnt_t'(total_hit_v);

    page_we_o = page_allocator.page_we;
    page_waddr_o = page_allocator.page_waddr;
    fetch_ticket_active_o = (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET);
    write_head_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_HEAD);
    write_tail_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_TAIL);
    write_page_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE);
    write_meta_flow_o = page_allocator.write_meta_flow;
    write_meta_flow_d1_o = page_allocator.write_meta_flow_d1;
    frame_start_addr_o = page_allocator.frame_start_addr;
    frame_shr_cnt_this_o = page_allocator.frame_shr_cnt_this;
    frame_hit_cnt_this_o = page_allocator.frame_hit_cnt_this;
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

    unique case (page_allocator_state)
      PAGE_ALLOCATOR_IDLE: begin
        if ((&page_allocator_is_pending_ticket_lane) && (&page_allocator_is_pending_ticket)) begin
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end
      end

      PAGE_ALLOCATOR_FETCH_TICKET: begin
        page_allocator.lane_masked <= '0;
        page_allocator.lane_skipped <= '0;
        page_allocator.page_length <= '0;

        for (int i = 0; i < N_LANE; i++) begin
          page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
          page_allocator.ticket_credit_update_valid[i] <= 1'b1;

          if (&page_allocator_is_tk_sop) begin
            page_allocator.frame_shr_cnt_this <= page_allocator_if_read_ticket_ticket_sop.n_subh;
            page_allocator.frame_hit_cnt_this <= page_allocator_if_read_ticket_ticket_sop.n_hit;
            page_allocator.frame_serial_this <= page_allocator_if_read_ticket_ticket_sop.serial;
            page_allocator.frame_serial <= page_allocator.frame_serial + 1'b1;
            page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
          end else if (page_allocator_is_tk_future[i]) begin
            page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
            page_allocator.lane_masked[i] <= 1'b1;
            page_allocator.ticket_credit_update_valid[i] <= 1'b0;
          end else if (page_allocator_is_tk_past[i]) begin
            page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
            page_allocator.lane_skipped[i] <= 1'b1;
          end else begin
            page_allocator.ticket[i] <= page_allocator_if_read_ticket_ticket[i];
            page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
          end
        end

        page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
        page_allocator.alloc_page_flow <= '0;

        for (int i = 0; i < N_LANE; i++) begin
          if (&page_allocator_is_tk_sop) begin
            page_allocator.page_we <= 1'b1;
            if (page_allocator_if_read_ticket_ticket[i].alert_eop) begin
              page_allocator.page_waddr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
              page_allocator.frame_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
            end else begin
              page_allocator.page_waddr <= page_allocator.page_start_addr;
              page_allocator.frame_start_addr <= page_allocator.page_start_addr;
            end
            page_allocator.frame_start_addr_last <= page_allocator.frame_start_addr;
            page_allocator.running_ts <= page_allocator.frame_ts;
            page_allocator.write_trailer <= page_allocator_if_read_ticket_ticket[i].alert_eop;
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
          page_allocator.page_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(HDR_SIZE + TRL_SIZE);
          page_allocator.frame_ts <= page_allocator.frame_ts + 48'(FRAME_DURATION_CYCLES);
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
          page_allocator.frame_shr_cnt <= '0;
          page_allocator.frame_hit_cnt <= '0;
        end
      end

      PAGE_ALLOCATOR_ALLOC_PAGE: begin
        if (page_allocator.alloc_page_flow == ALLOC_PAGE_FLOW_LAST) begin
          page_allocator.alloc_page_flow <= '0;
        end else begin
          page_allocator.alloc_page_flow <= page_allocator.alloc_page_flow + 1'b1;
        end

        for (int i = 0; i < N_LANE; i++) begin
          if (int'(page_allocator.alloc_page_flow) == i) begin
            if (!page_allocator.lane_skipped[i] && !page_allocator.lane_masked[i]) begin
              page_allocator.frame_shr_cnt <= page_allocator.frame_shr_cnt + 1'b1;
              page_allocator.frame_hit_cnt <= page_allocator.frame_hit_cnt +
                frame_hit_cnt_t'(page_allocator.ticket[i].block_length);
            end

            if (page_allocator.ticket[i].block_length == '0) begin
              page_allocator.handle_we[i] <= 1'b0;
            end else if (page_allocator.lane_skipped[i]) begin
              page_allocator.handle_we[i] <= 1'b1;
              page_allocator.handle_wflag[i] <= 1'b1;
              page_allocator.handle_wptr[i] <= page_allocator.handle_wptr[i] + handle_fifo_addr_t'(1);
            end else if (page_allocator.lane_masked[i]) begin
              page_allocator.handle_we[i] <= 1'b0;
            end else begin
              page_allocator.handle_we[i] <= 1'b1;
              page_allocator.handle_wptr[i] <= page_allocator.handle_wptr[i] + handle_fifo_addr_t'(1);
              page_allocator.page_length <= page_allocator.page_length + page_length_t'(page_allocator.ticket[i].block_length);
            end
          end
        end

        if (page_allocator.alloc_page_flow == ALLOC_PAGE_FLOW_LAST) begin
          if (&page_allocator.lane_masked) begin
            page_allocator_state <= PAGE_ALLOCATOR_IDLE;
            page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
          end else begin
            page_allocator_state <= PAGE_ALLOCATOR_WRITE_PAGE;
            page_allocator.page_we <= 1'b1;
            page_allocator.page_waddr <= page_allocator.page_start_addr;
          end
          page_allocator.alloc_page_flow <= '0;
        end
      end

      PAGE_ALLOCATOR_WRITE_PAGE: begin
        page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
        page_allocator.page_start_addr <= page_allocator.page_waddr +
          page_ram_addr_t'(page_allocator.page_length) + page_ram_addr_t'(SHD_SIZE);
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

    for (int i = 0; i < N_LANE; i++) begin
      if (d_reset) begin
        page_allocator_is_pending_ticket_d[i] <= '0;
      end else begin
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
    end
  end

  property p_page_allocator_reset_enters_reset;
    @(posedge d_clk) d_reset |=> (page_allocator_state == PAGE_ALLOCATOR_RESET);
  endproperty
  ap_page_allocator_reset_enters_reset: assert property (p_page_allocator_reset_enters_reset);

  property p_page_allocator_idle_fetch_requires_all_lanes;
    @(posedge d_clk) disable iff (d_reset)
      ((page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
       (&page_allocator_is_pending_ticket_lane) &&
       (&page_allocator_is_pending_ticket))
      |=> (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET);
  endproperty
  ap_page_allocator_idle_fetch_requires_all_lanes: assert property (p_page_allocator_idle_fetch_requires_all_lanes);

  property p_page_allocator_write_page_returns_idle;
    @(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE)
      |=> (page_allocator_state == PAGE_ALLOCATOR_IDLE);
  endproperty
  ap_page_allocator_write_page_returns_idle: assert property (p_page_allocator_write_page_returns_idle);

endmodule

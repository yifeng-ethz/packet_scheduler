interface pa_if (
  input logic clk
);
  // Keep defaults aligned with `pa_pkg.sv` and `pa_uvm_tb.sv` so UVM can use `virtual pa_if`.
  localparam int unsigned N_LANE = 4;
  localparam int unsigned N_SHD  = 8;
  localparam int unsigned CHANNEL_WIDTH = 2;

  localparam int unsigned LANE_FIFO_DEPTH   = 32;
  localparam int unsigned TICKET_FIFO_DEPTH = 1024;
  localparam int unsigned HANDLE_FIFO_DEPTH = 1024;
  localparam int unsigned PAGE_RAM_DEPTH    = 262144;

  localparam int unsigned PAGE_RAM_DATA_WIDTH = 40;
  localparam int unsigned HDR_SIZE = 5;
  localparam int unsigned SHD_SIZE = 1;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned TRL_SIZE = 1;
  localparam int unsigned N_HIT    = 255;

  localparam int unsigned FRAME_SERIAL_SIZE   = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE  = 16;

  localparam int unsigned SHD_CNT_WIDTH = 16;
  localparam int unsigned HIT_CNT_WIDTH = 16;

  localparam int unsigned LANE_FIFO_ADDR_W   = $clog2(LANE_FIFO_DEPTH);
  localparam int unsigned TICKET_ADDR_W      = $clog2(TICKET_FIFO_DEPTH);
  localparam int unsigned HANDLE_ADDR_W      = $clog2(HANDLE_FIFO_DEPTH);
  localparam int unsigned PAGE_ADDR_W        = $clog2(PAGE_RAM_DEPTH);
  localparam int unsigned MAX_PKT_LENGTH_BITS = $clog2(HIT_SIZE * N_HIT);

  localparam int unsigned TICKET_W_A = 48 + LANE_FIFO_ADDR_W + MAX_PKT_LENGTH_BITS + 2;
  localparam int unsigned TICKET_W_B = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2;
  localparam int unsigned TICKET_W   = (TICKET_W_A > TICKET_W_B) ? TICKET_W_A : TICKET_W_B;

  localparam int unsigned HANDLE_W = LANE_FIFO_ADDR_W + PAGE_ADDR_W + MAX_PKT_LENGTH_BITS + 1;

  logic rst;

  // DUT inputs.
  logic [5:0]  dt_type;
  logic [15:0] feb_id;

  logic [N_LANE*TICKET_ADDR_W-1:0] ticket_wptr_flat;
  logic [N_LANE*TICKET_W-1:0]      ticket_rd_data_flat;
  logic [N_LANE*HANDLE_ADDR_W-1:0] handle_rptr_flat;
  logic [N_LANE-1:0]              mover_busy;
  logic                           wr_blocked_by_rd_lock;

  // DUT outputs.
  logic [N_LANE*TICKET_ADDR_W-1:0] ticket_rd_addr_flat;
  logic [N_LANE-1:0]              ticket_credit_update_valid;
  logic [N_LANE*TICKET_ADDR_W-1:0] ticket_credit_update_flat;

  logic [N_LANE-1:0]              handle_we;
  logic [N_LANE*HANDLE_ADDR_W-1:0] handle_wptr_flat;
  logic [N_LANE*HANDLE_W-1:0]      handle_wdata_flat;

  logic page_we;
  logic [PAGE_ADDR_W-1:0] page_waddr;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_wdata;

  logic pa_write_head_start;
  logic [PAGE_ADDR_W-1:0] pa_frame_start_addr;
  logic [SHD_CNT_WIDTH-1:0] pa_frame_shr_cnt_this;
  logic [HIT_CNT_WIDTH-1:0] pa_frame_hit_cnt_this;

  logic pa_write_tail_done;
  logic pa_write_tail_active;
  logic [PAGE_ADDR_W-1:0] pa_frame_start_addr_last;
  logic [SHD_CNT_WIDTH-1:0] pa_frame_shr_cnt;
  logic [HIT_CNT_WIDTH-1:0] pa_frame_hit_cnt;
  logic pa_frame_invalid_last;
  logic [N_LANE*HANDLE_ADDR_W-1:0] pa_handle_wptr_flat;

  logic [N_LANE-1:0] quantum_update;

  // In-test ticket "memories" providing show-ahead read data.
  logic [TICKET_W-1:0] ticket_mem [N_LANE][TICKET_FIFO_DEPTH];
  logic [TICKET_ADDR_W-1:0] ticket_wptr_lane [N_LANE];

  function automatic int unsigned get_ticket_raddr(int unsigned lane);
    logic [TICKET_ADDR_W-1:0] addr_bits;
    addr_bits = ticket_rd_addr_flat[lane*TICKET_ADDR_W +: TICKET_ADDR_W];
    if ($isunknown(addr_bits)) return 0;
    return int'(addr_bits);
  endfunction

  // Drive show-ahead FIFO data from the interface-local ticket memories.
  always_comb begin
    ticket_wptr_flat = '0;
    ticket_rd_data_flat = '0;
    for (int unsigned i = 0; i < N_LANE; i++) begin
      ticket_wptr_flat[i*TICKET_ADDR_W +: TICKET_ADDR_W] = ticket_wptr_lane[i];
      ticket_rd_data_flat[i*TICKET_W +: TICKET_W] = ticket_mem[i][get_ticket_raddr(i)];
    end
  end

  // Default: model drained movers/handles to avoid SOP stalling.
  always_comb begin
    handle_rptr_flat = handle_wptr_flat;
    mover_busy = '0;
    wr_blocked_by_rd_lock = 1'b0;
  end

  task automatic drive_defaults();
    dt_type = 6'h01;
    feb_id = 16'h1234;
    for (int unsigned i = 0; i < N_LANE; i++) begin
      ticket_wptr_lane[i] = '0;
    end
  endtask

  task automatic set_ticket(input int unsigned lane, input int unsigned addr, input logic [TICKET_W-1:0] data);
    ticket_mem[lane][addr] = data;
  endtask

  task automatic set_ticket_wptr(input int unsigned lane, input int unsigned wptr);
    ticket_wptr_lane[lane] = wptr[TICKET_ADDR_W-1:0];
  endtask

endinterface

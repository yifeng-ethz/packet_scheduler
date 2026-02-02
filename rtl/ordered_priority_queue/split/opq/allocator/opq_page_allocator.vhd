-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_page_allocator
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Consumes per-lane tickets, allocates page RAM space for subheaders+hits, writes header/
--                      tail/trailer words, and emits per-lane mover handles. Provides conservative drop-on-
--                      contention behavior when write is blocked by presenter read-lock.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.and_reduce;
use ieee.std_logic_misc.or_reduce;

use work.opq_util_pkg.all;

-- Page allocator (split from ordered_priority_queue):
--   - Consumes per-lane tickets (show-ahead FIFO read via i_ticket_rd_data)
--   - Allocates page-RAM regions for the next subheader + hits
--   - Writes:
--       * frame header words 0..2 on SOP
--       * per-subheader marker word (K237) with hit count
--       * frame tail words 3..4 and trailer (K284) when the next SOP arrives (if enabled)
--   - Emits per-lane block-mover handles {src,dst,len}+flag
--
-- This module targets the MERGING mode behavior in the monolithic RTL.
entity opq_page_allocator is
  generic (
    MODE : string := "MERGING";

    N_LANE              : positive := 2;
    N_SHD               : positive := 128;
    CHANNEL_WIDTH       : positive := 2;

    LANE_FIFO_DEPTH     : positive := 1024;
    TICKET_FIFO_DEPTH   : positive := 256;
    HANDLE_FIFO_DEPTH   : positive := 64;

    PAGE_RAM_DEPTH      : positive := 65536;
    PAGE_RAM_DATA_WIDTH : positive := 40;

    HDR_SIZE            : positive := 5;
    SHD_SIZE            : positive := 1;
    HIT_SIZE            : positive := 1;
    TRL_SIZE            : positive := 1;

    N_HIT               : positive := 255;

    FRAME_SERIAL_SIZE   : positive := 16;
    FRAME_SUBH_CNT_SIZE : positive := 16;
    FRAME_HIT_CNT_SIZE  : positive := 16;

    SHD_CNT_WIDTH       : positive := 16;
    HIT_CNT_WIDTH       : positive := 16;

    -- Must match ingress parser / ticket FIFO width.
    --
    -- NOTE: Quartus' VHDL front-end is picky about user-defined function calls
    --       in generic default expressions, so the default here is a safe
    --       constant and opq_top always overrides it.
    TICKET_FIFO_DATA_WIDTH : positive := 96
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Header info (used to assemble header word0).
    i_dt_type : in std_logic_vector(5 downto 0);
    i_feb_id  : in std_logic_vector(15 downto 0);

    -- Ticket FIFO (show-ahead read).
    i_ticket_wptr    : in  unsigned_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);
    o_ticket_rd_addr : out slv_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);
    i_ticket_rd_data : in  slv_array_t(0 to N_LANE-1)(TICKET_FIFO_DATA_WIDTH-1 downto 0);

    -- Credit return to ingress parser.
    o_ticket_credit_update_valid : out std_logic_vector(N_LANE-1 downto 0);
    o_ticket_credit_update       : out unsigned_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);

    -- Handle FIFO write port (flag + handle fields).
    o_handle_we      : out std_logic_vector(N_LANE-1 downto 0);
    o_handle_wptr    : out unsigned_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);
    o_handle_wdata   : out slv_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH) + clog2(PAGE_RAM_DEPTH) + clog2(HIT_SIZE*N_HIT) downto 0);
    o_handle_wr_addr : out slv_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);

    -- Block mover progress (for frame-boundary safety).
    i_handle_rptr : in unsigned_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);
    i_mover_busy  : in std_logic_vector(N_LANE-1 downto 0) := (others => '0');

    -- Single write port into the page RAM (priority over movers handled externally).
    o_alloc_page_we    : out std_logic;
    o_alloc_page_waddr : out std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_alloc_page_wdata : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- Frame-table mapper interface.
    o_pa_write_head_start      : out std_logic;
    o_pa_frame_start_addr      : out unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_pa_frame_shr_cnt_this    : out unsigned(SHD_CNT_WIDTH-1 downto 0);
    o_pa_frame_hit_cnt_this    : out unsigned(HIT_CNT_WIDTH-1 downto 0);

    o_pa_write_tail_done       : out std_logic;
    o_pa_write_tail_active     : out std_logic;
    o_pa_frame_start_addr_last : out unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_pa_frame_shr_cnt         : out unsigned(SHD_CNT_WIDTH-1 downto 0);
    o_pa_frame_hit_cnt         : out unsigned(HIT_CNT_WIDTH-1 downto 0);
    o_pa_frame_invalid_last    : out std_logic;
    o_pa_handle_wptr           : out unsigned_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);

    -- Quantum update tick (typically when a lane provides a timely ticket).
    o_quantum_update : out std_logic_vector(N_LANE-1 downto 0);

    -- Read-lock feedback (from frame-table complex): marks frame invalid (drop) instead of corrupting output.
    i_wr_blocked_by_rd_lock : in std_logic := '0'
  );
end entity opq_page_allocator;

architecture rtl of opq_page_allocator is
  constant K285 : std_logic_vector(7 downto 0) := x"BC";
  constant K284 : std_logic_vector(7 downto 0) := x"9C";
  constant K237 : std_logic_vector(7 downto 0) := x"F7";

  constant FIFO_RAW_DELAY : natural := 2;
  constant SUBFRAME_DURATION_CYCLES : natural := 16;
  constant FRAME_DURATION_CYCLES : natural := N_SHD * SUBFRAME_DURATION_CYCLES;
  constant FRAME_DURATION_SHIFT : natural := clog2(FRAME_DURATION_CYCLES);
  constant FRAME_DURATION_IS_POW2_C : boolean := is_pow2(positive'(FRAME_DURATION_CYCLES));

  constant LANE_FIFO_ADDR_W   : natural := clog2(LANE_FIFO_DEPTH);
  constant TICKET_FIFO_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);
  constant HANDLE_FIFO_ADDR_W : natural := clog2(HANDLE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_W    : natural := clog2(PAGE_RAM_DEPTH);

  constant MAX_PKT_LENGTH_BITS : natural := clog2(HIT_SIZE*N_HIT);

  -- Handle encoding (must match opq_block_mover).
  constant HANDLE_LENGTH : natural := LANE_FIFO_ADDR_W + PAGE_RAM_ADDR_W + MAX_PKT_LENGTH_BITS;
  constant HANDLE_SRC_LO : natural := 0;
  constant HANDLE_SRC_HI : natural := LANE_FIFO_ADDR_W-1;
  constant HANDLE_DST_LO : natural := LANE_FIFO_ADDR_W;
  constant HANDLE_DST_HI : natural := LANE_FIFO_ADDR_W + PAGE_RAM_ADDR_W-1;
  constant HANDLE_LEN_LO : natural := LANE_FIFO_ADDR_W + PAGE_RAM_ADDR_W;
  constant HANDLE_LEN_HI : natural := LANE_FIFO_ADDR_W + PAGE_RAM_ADDR_W + MAX_PKT_LENGTH_BITS-1;

  -- Ticket format (must match ingress parser).
  constant TICKET_LENGTH          : natural := TICKET_FIFO_DATA_WIDTH;
  constant TICKET_TS_LO           : natural := 0;
  constant TICKET_TS_HI           : natural := 47;
  constant TICKET_LANE_RD_OFST_LO : natural := 48;
  constant TICKET_LANE_RD_OFST_HI : natural := 48 + LANE_FIFO_ADDR_W - 1;
  constant TICKET_BLOCK_LEN_LO    : natural := 48 + LANE_FIFO_ADDR_W;
  constant TICKET_BLOCK_LEN_HI    : natural := 48 + LANE_FIFO_ADDR_W + MAX_PKT_LENGTH_BITS - 1;

  constant TICKET_SERIAL_LO : natural := 0;
  constant TICKET_SERIAL_HI : natural := FRAME_SERIAL_SIZE-1;
  constant TICKET_N_SUBH_LO : natural := FRAME_SERIAL_SIZE;
  constant TICKET_N_SUBH_HI : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  constant TICKET_N_HIT_LO  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  constant TICKET_N_HIT_HI  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;

  constant TICKET_ALT_EOP_LOC : natural := TICKET_LENGTH - 2;
  constant TICKET_ALT_SOP_LOC : natural := TICKET_LENGTH - 1;

  subtype ticket_ptr_t is unsigned(TICKET_FIFO_ADDR_W-1 downto 0);
  subtype handle_ptr_t is unsigned(HANDLE_FIFO_ADDR_W-1 downto 0);
  subtype page_addr_t  is unsigned(PAGE_RAM_ADDR_W-1 downto 0);

  type ticket_t is record
    ticket_ts           : unsigned(47 downto 0);
    lane_fifo_rd_offset : std_logic_vector(LANE_FIFO_ADDR_W-1 downto 0);
    block_length        : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
    alert_eop           : std_logic;
    alert_sop           : std_logic;
  end record;
  constant TICKET_DEFAULT : ticket_t := (
    ticket_ts => (others => '0'),
    lane_fifo_rd_offset => (others => '0'),
    block_length => (others => '0'),
    alert_eop => '0',
    alert_sop => '0'
  );

  type tickets_t is array (0 to N_LANE-1) of ticket_t;

  type sop_ticket_t is record
    serial : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
    n_subh : unsigned(SHD_CNT_WIDTH-1 downto 0);
    n_hit  : unsigned(HIT_CNT_WIDTH-1 downto 0);
  end record;

  type state_t is (IDLE, FETCH_TICKET, WRITE_HEAD, WRITE_TAIL, ALLOC_PAGE, WRITE_PAGE, RESET);

  type pending_ds_t is array (0 to N_LANE-1) of std_logic_vector(1 to FIFO_RAW_DELAY);

  type reg_t is record
    -- ticket
    ticket_rptr                : unsigned_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);
    ticket_credit_update       : unsigned_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);
    ticket_credit_update_valid : std_logic_vector(N_LANE-1 downto 0);

    -- handle
    handle_we    : std_logic_vector(N_LANE-1 downto 0);
    handle_wptr  : unsigned_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);
    handle_wdata : slv_array_t(0 to N_LANE-1)(HANDLE_LENGTH downto 0);

    -- page write
    page_we    : std_logic;
    page_waddr : std_logic_vector(PAGE_RAM_ADDR_W-1 downto 0);

    -- frame meta
    frame_start_addr      : page_addr_t;
    frame_start_addr_last : page_addr_t;
    frame_serial          : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
    frame_serial_this     : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
    frame_shr_cnt_this    : unsigned(SHD_CNT_WIDTH-1 downto 0);
    frame_hit_cnt_this    : unsigned(HIT_CNT_WIDTH-1 downto 0);
    frame_shr_cnt         : unsigned(SHD_CNT_WIDTH-1 downto 0);
    frame_hit_cnt         : unsigned(HIT_CNT_WIDTH-1 downto 0);
    frame_ts              : unsigned(47 downto 0);
    running_ts            : unsigned(47 downto 0);
    frame_invalid         : std_logic;
    frame_invalid_last    : std_logic;

    -- current subheader allocation
    lane_masked  : std_logic_vector(N_LANE-1 downto 0);
    lane_skipped : std_logic_vector(N_LANE-1 downto 0);
    ticket       : tickets_t;
    page_start_addr : page_addr_t;
    page_length     : unsigned(MAX_PKT_LENGTH_BITS+CHANNEL_WIDTH-1 downto 0);
    alloc_page_flow : natural range 0 to N_LANE-1;

    -- header/tail flow
    write_meta_flow : natural range 0 to 5;
    write_trailer   : std_logic;

    reset_done : std_logic;
  end record;

  constant REG_RESET : reg_t := (
    ticket_rptr => (others => (others => '0')),
    ticket_credit_update => (others => (others => '0')),
    ticket_credit_update_valid => (others => '0'),
    handle_we => (others => '0'),
    handle_wptr => (others => (others => '0')),
    handle_wdata => (others => (others => '0')),
    page_we => '0',
    page_waddr => (others => '0'),
    frame_start_addr => (others => '0'),
    frame_start_addr_last => (others => '0'),
    frame_serial => (others => '0'),
    frame_serial_this => (others => '0'),
    frame_shr_cnt_this => (others => '0'),
    frame_hit_cnt_this => (others => '0'),
    frame_shr_cnt => (others => '0'),
    frame_hit_cnt => (others => '0'),
    frame_ts => (others => '0'),
    running_ts => (others => '0'),
    frame_invalid => '0',
    frame_invalid_last => '0',
    lane_masked => (others => '0'),
    lane_skipped => (others => '0'),
    ticket => (others => TICKET_DEFAULT),
    page_start_addr => (others => '0'),
    page_length => (others => '0'),
    alloc_page_flow => 0,
    write_meta_flow => 0,
    write_trailer => '0',
    reset_done => '0'
  );

  signal state : state_t := RESET;
  signal r     : reg_t := REG_RESET;

  signal pending_ticket      : std_logic_vector(N_LANE-1 downto 0);
  signal pending_ticket_d    : pending_ds_t := (others => (others => '0'));
  signal pending_ticket_lane : std_logic_vector(N_LANE-1 downto 0);

  signal tk_decoded   : tickets_t;
  signal tk_sop       : sop_ticket_t;
  signal is_tk_sop    : std_logic_vector(N_LANE-1 downto 0);
  signal is_tk_future : std_logic_vector(N_LANE-1 downto 0);
  signal is_tk_past   : std_logic_vector(N_LANE-1 downto 0);

  signal alloc_page_wdata_hdr : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal alloc_page_wdata_shd : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal alloc_page_wdata_trl : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

  signal alloc_page_wdata : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
begin
  -- The timestamp model assumes FRAME_DURATION_CYCLES is a power-of-two (N_SHD is constrained in _hw.tcl).
  assert FRAME_DURATION_IS_POW2_C
    report "OPQ: FRAME_DURATION_CYCLES (N_SHD*SUBFRAME_DURATION_CYCLES) must be a power-of-two"
    severity failure;

  -- Outputs.
  gen_ticket_rd_addr : for i in 0 to N_LANE-1 generate
    o_ticket_rd_addr(i) <= std_logic_vector(r.ticket_rptr(i));
  end generate;

  o_ticket_credit_update_valid <= r.ticket_credit_update_valid;
  o_ticket_credit_update       <= r.ticket_credit_update;

  o_handle_we <= r.handle_we;
  o_handle_wptr <= r.handle_wptr;
  o_pa_handle_wptr <= r.handle_wptr;

  gen_handle_out : for i in 0 to N_LANE-1 generate
    o_handle_wdata(i) <= r.handle_wdata(i);
    o_handle_wr_addr(i) <= std_logic_vector(r.handle_wptr(i) - 1);
  end generate;

  o_alloc_page_we    <= r.page_we when (state = WRITE_PAGE) or (state = WRITE_HEAD) or (state = WRITE_TAIL) else '0';
  o_alloc_page_waddr <= r.page_waddr;
  o_alloc_page_wdata <= alloc_page_wdata;

  o_pa_frame_start_addr      <= r.frame_start_addr;
  o_pa_frame_shr_cnt_this    <= r.frame_shr_cnt_this;
  o_pa_frame_hit_cnt_this    <= r.frame_hit_cnt_this;
  o_pa_frame_start_addr_last <= r.frame_start_addr_last;
  o_pa_frame_shr_cnt         <= r.frame_shr_cnt;
  o_pa_frame_hit_cnt         <= r.frame_hit_cnt;
  -- Important: `i_wr_blocked_by_rd_lock` can assert in the same cycle as `o_pa_write_tail_done`
  -- (last meta word write blocked). Make the invalid flag visible immediately so the mapper
  -- never enqueues meta for a partially written frame.
  o_pa_frame_invalid_last    <= r.frame_invalid_last or i_wr_blocked_by_rd_lock;

  o_pa_write_head_start <= '1' when (state = WRITE_HEAD) and (r.write_meta_flow = 0) else '0';
  o_pa_write_tail_done  <= '1' when (state = WRITE_TAIL) and (r.write_meta_flow = 3) else '0';
  o_pa_write_tail_active <= '1' when state = WRITE_TAIL else '0';

  -- Default quantum update: asserted when a lane provides a timely ticket (not future) in FETCH_TICKET.
  gen_quantum : for i in 0 to N_LANE-1 generate
    o_quantum_update(i) <= '1' when (state = FETCH_TICKET) and (is_tk_future(i) = '0') else '0';
  end generate;

  -- Pending ticket detection.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            PAGE_ALLOCATOR.PENDING_COMB
  -- @brief           Detect non-empty ticket FIFO per lane (show-ahead: wptr != rptr)
  -- @input           i_ticket_wptr, r.ticket_rptr
  -- @output          pending_ticket
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_pending : process (all) is
  begin
    for i in 0 to N_LANE-1 loop
      if i_ticket_wptr(i) /= r.ticket_rptr(i) then
        pending_ticket(i) <= '1';
      else
        pending_ticket(i) <= '0';
      end if;
    end loop;
  end process;

  -- Decode tickets at the current read pointers (show-ahead).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            PAGE_ALLOCATOR.DECODE_COMB
  -- @brief           Decode show-ahead tickets and compute aggregate SOP counters (subheader/hit totals)
  -- @input           i_ticket_rd_data
  -- @output          tk_decoded, is_tk_sop, tk_sop
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_decode : process (all) is
    variable total_subh_v : unsigned(SHD_CNT_WIDTH-1 downto 0);
    variable total_hit_v  : unsigned(HIT_CNT_WIDTH-1 downto 0);
    variable serial_v     : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
  begin
    total_subh_v := (others => '0');
    total_hit_v  := (others => '0');
    serial_v     := (others => '0');

    for i in 0 to N_LANE-1 loop
      tk_decoded(i).ticket_ts           <= unsigned(i_ticket_rd_data(i)(TICKET_TS_HI downto TICKET_TS_LO));
      tk_decoded(i).lane_fifo_rd_offset <= i_ticket_rd_data(i)(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO);
      tk_decoded(i).block_length        <= unsigned(i_ticket_rd_data(i)(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO));
      tk_decoded(i).alert_eop           <= i_ticket_rd_data(i)(TICKET_ALT_EOP_LOC);
      tk_decoded(i).alert_sop           <= i_ticket_rd_data(i)(TICKET_ALT_SOP_LOC);

      is_tk_sop(i) <= i_ticket_rd_data(i)(TICKET_ALT_SOP_LOC);

      total_subh_v := total_subh_v + resize(unsigned(i_ticket_rd_data(i)(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO)), SHD_CNT_WIDTH);
      total_hit_v  := total_hit_v + resize(unsigned(i_ticket_rd_data(i)(TICKET_N_HIT_HI downto TICKET_N_HIT_LO)), HIT_CNT_WIDTH);
    end loop;

    serial_v := unsigned(i_ticket_rd_data(0)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO));
    tk_sop.serial <= serial_v;
    tk_sop.n_subh <= total_subh_v;
    tk_sop.n_hit  <= total_hit_v;

    -- Timeliness classification (mirrors monolithic).
    for i in 0 to N_LANE-1 loop
      if is_tk_sop(i) = '1' then
        if unsigned(i_ticket_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) >= (r.frame_serial + 1) then
          is_tk_future(i) <= '1';
        else
          is_tk_future(i) <= '0';
        end if;
      elsif (unsigned(i_ticket_rd_data(i)(47 downto 0)) > (r.running_ts + to_unsigned(16, r.running_ts'length))) then
        is_tk_future(i) <= '1';
      else
        is_tk_future(i) <= '0';
      end if;

      if is_tk_sop(i) = '1' then
        if unsigned(i_ticket_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) < r.frame_serial then
          is_tk_past(i) <= '1';
        else
          is_tk_past(i) <= '0';
        end if;
      elsif (unsigned(i_ticket_rd_data(i)(47 downto 0)) + to_unsigned(16, r.running_ts'length) < r.running_ts) then
        is_tk_past(i) <= '1';
      else
        is_tk_past(i) <= '0';
      end if;
    end loop;
  end process;

  -- Assemble allocator page write data (header/subheader/trailer), combinational.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            PAGE_ALLOCATOR.PAGE_WDATA_COMB
  -- @brief           Assemble allocator page RAM write data for header/subheader/trailer words
  -- @input           state, r.write_meta_flow, r.running_ts, r.frame_ts, r.frame_serial_this, i_dt_type/i_feb_id
  -- @output          alloc_page_wdata (and *_hdr/*_shd/*_trl)
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_page_wdata : process (all) is
    variable hdr : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    variable shd : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    variable trl : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    variable shr_decl : unsigned(SHD_CNT_WIDTH-1 downto 0);
  begin
    hdr := (others => '0');
    shd := (others => '0');
    trl := (others => '0');

    -- Subheader marker word.
    shd(35 downto 32) := "0001";
    shd(31 downto 24) := std_logic_vector(r.running_ts(11 downto 4));
    -- Subheader hit count is 8-bit in the OPQ wire format.
    -- When N_LANE>2, the merged hit count can exceed 255 if not trimmed, which corrupts framing.
    -- Enforce an 8-bit field here; upstream logic must also ensure r.page_length never exceeds N_HIT.
    shd(23 downto 16) := (others => '0');
    shd(15 downto 8)  := std_logic_vector(resize(r.page_length, 8));
    shd(7 downto 0) := K237;

    -- Trailer marker word.
    trl(35 downto 32) := "0001";
    trl(31 downto 8) := (others => '0');
    trl(7 downto 0) := K284;

    -- Header words (write_meta_flow selects word index).
    case r.write_meta_flow is
      when 0 =>
        hdr(35 downto 32) := "0001";
        hdr(31 downto 26) := i_dt_type;
        hdr(23 downto 8)  := i_feb_id;
        hdr(7 downto 0)   := K285;
      when 1 =>
        hdr(35 downto 32) := "0000";
        hdr(31 downto 0)  := std_logic_vector(r.frame_ts(47 downto 16));
      when 2 =>
        hdr(35 downto 32) := "0000";
        hdr(31 downto 16) := std_logic_vector(r.frame_ts(15 downto 0));
        hdr(15 downto 0)  := std_logic_vector(r.frame_serial_this);
      when 3 =>
        hdr(35 downto 32) := "0000";
        -- Declared subheader count is per merged frame (not summed across lanes).
        -- Use the SOP-declared count (sum across lanes) to avoid undercounting when lanes are skipped.
        shr_decl := r.frame_shr_cnt_this / to_unsigned(N_LANE, r.frame_shr_cnt_this'length);
        hdr(16 + SHD_CNT_WIDTH-1 downto 16) := std_logic_vector(shr_decl);
        hdr(HIT_CNT_WIDTH-1 downto 0) := std_logic_vector(r.frame_hit_cnt);
      when 4 =>
        hdr(35 downto 32) := "0000";
        hdr(30 downto 0) := std_logic_vector(r.running_ts(30 downto 0));
      when 5 =>
        hdr := trl;
      when others =>
        hdr := (others => '0');
    end case;

    alloc_page_wdata_hdr <= hdr;
    alloc_page_wdata_shd <= shd;
    alloc_page_wdata_trl <= trl;

    if state = WRITE_PAGE then
      alloc_page_wdata <= shd;
    elsif (state = WRITE_HEAD) or (state = WRITE_TAIL) then
      alloc_page_wdata <= hdr;
    else
      alloc_page_wdata <= (others => '0');
    end if;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            PAGE_ALLOCATOR.REG
  -- @brief           Main allocator state machine: pop tickets, allocate pages, and emit mover handles
  -- @input           pending_ticket/is_tk_future/is_tk_past, decoded tickets, i_wr_blocked_by_rd_lock
  -- @output          o_alloc_page_*, o_handle_*, o_ticket_credit_update_*, frame-table mapper event outputs
  -- @description     In contention (write blocked by presenter read-lock), may mark frame invalid and
  --                  proceed to maintain a consistent egress stream (dropping is preferred over corruption).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_page_allocator : process (i_clk) is
    variable any_mover_busy_v : boolean;
    variable lane_sel : natural range 0 to N_LANE-1;
    variable dst_base : unsigned(PAGE_RAM_ADDR_W-1 downto 0);
    variable handle_v : std_logic_vector(HANDLE_LENGTH downto 0);
    variable prev_frame_invalid_v : std_logic;
    variable serial_mid_v : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
  begin
    if rising_edge(i_clk) then
      -- defaults (one-cycle pulses)
      r.ticket_credit_update_valid <= (others => '0');
      r.handle_we <= (others => '0');
      r.page_we <= '0';

      -- pending-ticket delay chain
      for i in 0 to N_LANE-1 loop
        for j in 1 to FIFO_RAW_DELAY loop
          if j = 1 then
            pending_ticket_d(i)(j) <= pending_ticket(i);
          else
            pending_ticket_d(i)(j) <= pending_ticket_d(i)(j-1);
          end if;
        end loop;
      end loop;

      -- stable pending flag per lane
      for i in 0 to N_LANE-1 loop
        pending_ticket_lane(i) <= and_reduce(pending_ticket_d(i));
      end loop;

      case state is
        when IDLE =>
          if (and_reduce(pending_ticket_lane) = '1') and (and_reduce(pending_ticket) = '1') then
            any_mover_busy_v := false;
            for j in 0 to N_LANE-1 loop
              if (i_mover_busy(j) = '1') then
                any_mover_busy_v := true;
              end if;
              if (r.handle_wptr(j) /= i_handle_rptr(j)) then
                any_mover_busy_v := true;
              end if;
            end loop;

            if (and_reduce(is_tk_sop) = '1') and any_mover_busy_v then
              -- stall until movers drain
            else
              state <= FETCH_TICKET;
            end if;
          end if;

        when FETCH_TICKET =>
          -- If the previous frame did not fully materialize (drop/overflow), prefer to drop it as a whole
          -- rather than presenting a partial/corrupted frame on egress.
          prev_frame_invalid_v := r.frame_invalid;
          if and_reduce(is_tk_sop) = '1' then
            if (r.frame_shr_cnt /= r.frame_shr_cnt_this) or (r.frame_hit_cnt /= r.frame_hit_cnt_this) then
              prev_frame_invalid_v := '1';
            end if;
          end if;

          r.lane_masked <= (others => '0');
          r.lane_skipped <= (others => '0');
          r.page_length <= (others => '0');

          for i in 0 to N_LANE-1 loop
            -- Return 1 ticket credit by default (ack read).
            r.ticket_credit_update(i) <= to_unsigned(1, TICKET_FIFO_ADDR_W);
            r.ticket_credit_update_valid(i) <= '1';

            if and_reduce(is_tk_sop) = '1' then
              -- SOP tickets (frame boundary).
              r.frame_shr_cnt_this <= tk_sop.n_subh;
              r.frame_hit_cnt_this <= tk_sop.n_hit;
              r.frame_serial_this  <= tk_sop.serial;
              r.frame_serial       <= r.frame_serial + 1;
              r.frame_invalid_last <= prev_frame_invalid_v;
              r.frame_invalid      <= '0';
              r.ticket_rptr(i)     <= r.ticket_rptr(i) + 1;
            elsif is_tk_future(i) = '1' then
              -- Stall this lane (don't consume ticket).
              r.ticket_rptr(i) <= r.ticket_rptr(i);
              r.lane_masked(i) <= '1';
              r.ticket_credit_update_valid(i) <= '0';
            elsif is_tk_past(i) = '1' then
              -- Drop this ticket but generate a skip handle later to return lane credit.
              r.ticket(i) <= tk_decoded(i);
              r.ticket_rptr(i) <= r.ticket_rptr(i) + 1;
              r.lane_skipped(i) <= '1';
            else
              r.ticket(i) <= tk_decoded(i);
              r.ticket_rptr(i) <= r.ticket_rptr(i) + 1;
            end if;
          end loop;

          state <= ALLOC_PAGE;
          r.alloc_page_flow <= 0;

          -- SOP: kick header write pipeline (and possibly previous tail).
          if and_reduce(is_tk_sop) = '1' then
            r.page_we <= '1';
            if tk_decoded(0).alert_eop = '1' then
              r.page_waddr <= std_logic_vector(r.page_start_addr + to_unsigned(TRL_SIZE, r.page_start_addr'length));
              r.frame_start_addr <= r.page_start_addr + to_unsigned(TRL_SIZE, r.page_start_addr'length);
            else
              r.page_waddr <= std_logic_vector(r.page_start_addr);
              r.frame_start_addr <= r.page_start_addr;
            end if;
            r.frame_start_addr_last <= r.frame_start_addr;

            -- running_ts = serial * FRAME_DURATION_CYCLES (avoid integer math)
            r.running_ts <= shift_left(resize(tk_sop.serial, r.running_ts'length), FRAME_DURATION_SHIFT);
            -- frame_ts = (2*floor(serial/2) + 1) * FRAME_DURATION_CYCLES (midpoint timestamp, matches monolithic)
            serial_mid_v := tk_sop.serial;
            serial_mid_v(0) := '0';
            serial_mid_v := serial_mid_v + 1;
            r.frame_ts <= shift_left(resize(serial_mid_v, r.frame_ts'length), FRAME_DURATION_SHIFT);

            r.write_trailer <= tk_decoded(0).alert_eop;
            state <= WRITE_HEAD;
            r.write_meta_flow <= 0;
          end if;

        when WRITE_HEAD =>
          if r.write_meta_flow < 2 then
            r.page_we <= '1';
            r.page_waddr <= std_logic_vector(r.frame_start_addr + to_unsigned(r.write_meta_flow + 1, r.frame_start_addr'length));
          else
            if r.write_trailer = '1' then
              r.page_we <= '1';
              r.page_waddr <= std_logic_vector(r.frame_start_addr_last + to_unsigned(r.write_meta_flow + 1, r.frame_start_addr_last'length));
              state <= WRITE_TAIL;
            else
              r.page_we <= '0';
              r.page_start_addr <= r.frame_start_addr + to_unsigned(HDR_SIZE, r.frame_start_addr'length);
              r.frame_ts <= r.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, r.frame_ts'length);
              state <= IDLE;
            end if;
          end if;
          r.write_meta_flow <= r.write_meta_flow + 1;

        when WRITE_TAIL =>
          if r.write_meta_flow < 4 then
            r.write_meta_flow <= r.write_meta_flow + 1;
            r.page_we <= '1';
            r.page_waddr <= std_logic_vector(r.frame_start_addr_last + to_unsigned(r.write_meta_flow + 1, r.frame_start_addr_last'length));
          elsif r.write_meta_flow < 5 then
            r.write_meta_flow <= r.write_meta_flow + 1;
            r.page_we <= '1';
            r.page_waddr <= std_logic_vector(r.frame_start_addr - 1);
          else
            r.write_meta_flow <= 0;
            r.write_trailer <= '0';
            r.page_start_addr <= r.page_start_addr + to_unsigned(HDR_SIZE + TRL_SIZE, r.page_start_addr'length);
            r.frame_ts <= r.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, r.frame_ts'length);
            state <= IDLE;
            r.frame_shr_cnt <= (others => '0');
            r.frame_hit_cnt <= (others => '0');
          end if;

        when ALLOC_PAGE =>
          -- Allocate per-lane blocks in serial (one lane per cycle).
          lane_sel := r.alloc_page_flow;

          -- Default: advance to next lane.
          if r.alloc_page_flow < N_LANE-1 then
            r.alloc_page_flow <= r.alloc_page_flow + 1;
          end if;

          -- Track accepted subheaders across lanes (used for completeness checking).
          if (r.lane_skipped(lane_sel) = '0') and (r.lane_masked(lane_sel) = '0') then
            r.frame_shr_cnt <= r.frame_shr_cnt + 1;
          end if;

          -- Handle write.
          handle_v := (others => '0');
          dst_base := r.page_start_addr + to_unsigned(SHD_SIZE, r.page_start_addr'length) + resize(r.page_length, r.page_start_addr'length);
          handle_v(HANDLE_LENGTH) := '0';
          handle_v(HANDLE_SRC_HI downto HANDLE_SRC_LO) := r.ticket(lane_sel).lane_fifo_rd_offset;
          handle_v(HANDLE_DST_HI downto HANDLE_DST_LO) := std_logic_vector(dst_base);
          handle_v(HANDLE_LEN_HI downto HANDLE_LEN_LO) := std_logic_vector(r.ticket(lane_sel).block_length);

          if r.ticket(lane_sel).block_length = 0 then
            -- no-op
          elsif r.lane_skipped(lane_sel) = '1' then
            r.handle_we(lane_sel) <= '1';
            handle_v(HANDLE_LENGTH) := '1';
            r.handle_wdata(lane_sel) <= handle_v;
            r.handle_wptr(lane_sel) <= r.handle_wptr(lane_sel) + 1;
          elsif r.lane_masked(lane_sel) = '1' then
            -- no handle
          else
            -- Prevent merged subheader hit-count overflow (8-bit field on the wire).
            -- Policy: when sum would exceed N_HIT, drop this lane's block (skip handle) and mark frame invalid.
            if (r.page_length + resize(r.ticket(lane_sel).block_length, r.page_length'length)) > to_unsigned(N_HIT, r.page_length'length) then
              r.handle_we(lane_sel) <= '1';
              handle_v(HANDLE_LENGTH) := '1';
              r.handle_wdata(lane_sel) <= handle_v;
              r.handle_wptr(lane_sel) <= r.handle_wptr(lane_sel) + 1;
              r.frame_invalid <= '1';
            else
              r.handle_we(lane_sel) <= '1';
              r.handle_wdata(lane_sel) <= handle_v;
              r.handle_wptr(lane_sel) <= r.handle_wptr(lane_sel) + 1;
              r.page_length <= r.page_length + resize(r.ticket(lane_sel).block_length, r.page_length'length);
              r.frame_hit_cnt <= r.frame_hit_cnt + resize(r.ticket(lane_sel).block_length, r.frame_hit_cnt'length);
            end if;
          end if;

          -- Exit after last lane.
          if r.alloc_page_flow = N_LANE-1 then
            r.alloc_page_flow <= 0;
            if and_reduce(r.lane_masked) = '1' then
              state <= IDLE;
              r.running_ts(47 downto 4) <= r.running_ts(47 downto 4) + 1;
              r.frame_invalid <= '1';
            else
              state <= WRITE_PAGE;
              r.page_we <= '1';
              r.page_waddr <= std_logic_vector(r.page_start_addr);
            end if;
          end if;

        when WRITE_PAGE =>
          r.running_ts(47 downto 4) <= r.running_ts(47 downto 4) + 1;
          r.page_start_addr <= unsigned(r.page_waddr) + resize(r.page_length, r.page_start_addr'length) + to_unsigned(SHD_SIZE, r.page_start_addr'length);
          r.page_length <= (others => '0');
          state <= IDLE;

        when RESET =>
          if r.reset_done = '0' then
            for i in 0 to N_LANE-1 loop
              r.ticket_credit_update(i) <= to_unsigned(TICKET_FIFO_DEPTH-1, r.ticket_credit_update(i)'length);
              r.ticket_credit_update_valid(i) <= '1';
            end loop;
            r.reset_done <= '1';
          else
            if i_rst = '0' then
              state <= IDLE;
            end if;
          end if;

        when others =>
          null;
      end case;

      -- Never allow writer to corrupt a locked tile: mark frame invalid (drop).
      if (i_rst = '0') and (i_wr_blocked_by_rd_lock = '1') then
        -- Conservative rule: any blocked write means we cannot guarantee packet integrity.
        -- Mark both the current frame and the previous frame invalid so the mapper can flush/drop
        -- whole frames rather than presenting partial/corrupted packets.
        r.frame_invalid_last <= '1';
        r.frame_invalid      <= '1';
      end if;

      -- Sync reset.
      if i_rst = '1' then
        state <= RESET;
        if state /= RESET then
          r <= REG_RESET;
          r.reset_done <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture rtl;

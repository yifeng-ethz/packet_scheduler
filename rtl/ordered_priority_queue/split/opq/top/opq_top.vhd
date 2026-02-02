-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_top
-- Author:              Yifeng Wang (original OPQ) / split+integration by Codex
-- Revision:            0.1 - split top-level integration of OPQ pipeline
-- Description:         Top-level integration of split OPQ modules:
--                        ingress_parser -> lane/ticket FIFOs -> page_allocator -> handle FIFOs -> block movers
--                        allocator+movers -> b2p_arbiter -> frame_table (tiled page RAM + presenter)
--                        frame_table status -> rd_debug_if (read-only Avalon-MM)
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

entity opq_top is
  generic (
    N_LANE : positive := 2;
    N_TILE : positive := 5;
    N_WR_SEG : positive := 4;

    N_SHD : positive := 8;
    CHANNEL_WIDTH : positive := 2;

    INGRESS_DATA_WIDTH  : positive := 32;
    INGRESS_DATAK_WIDTH : positive := 4;

    LANE_FIFO_DEPTH   : positive := 1024;
    LANE_FIFO_WIDTH   : positive := 40;
    TICKET_FIFO_DEPTH : positive := 256;
    HANDLE_FIFO_DEPTH : positive := 64;

    PAGE_RAM_DEPTH      : positive := 65536;
    PAGE_RAM_DATA_WIDTH : positive := 40;

    HDR_SIZE : positive := 5;
    SHD_SIZE : positive := 1;
    HIT_SIZE : positive := 1;
    TRL_SIZE : positive := 1;

    N_HIT : positive := 255;

    FRAME_SERIAL_SIZE   : positive := 16;
    FRAME_SUBH_CNT_SIZE : positive := 16;
    FRAME_HIT_CNT_SIZE  : positive := 16;

    SHD_CNT_WIDTH : positive := 16;
    HIT_CNT_WIDTH : positive := 16;

    TILE_FIFO_DEPTH    : positive := 512;
    TILE_PKT_CNT_WIDTH : positive := 10;
    EGRESS_DELAY       : natural := 2;

    QUANTUM_PER_SUBFRAME : natural := 256;
    QUANTUM_WIDTH        : positive := 10;

    AVS_ADDR_WIDTH : positive := 8;

    -- Debug: 0=off, 1=basic, 2=verbose (simulation diagnostics only).
    DEBUG_LV       : natural := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Avalon-ST like ingress (per lane).
    i_ingress_data          : in  slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    i_ingress_valid         : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_channel       : in  slv_array_t(0 to N_LANE-1)(CHANNEL_WIDTH-1 downto 0);
    i_ingress_startofpacket : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_endofpacket   : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_error         : in  slv_array_t(0 to N_LANE-1)(2 downto 0);

    -- Egress (single stream).
    i_egress_ready         : in  std_logic;
    o_egress_valid         : out std_logic;
    o_egress_data          : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    o_egress_startofpacket : out std_logic;
    o_egress_endofpacket   : out std_logic;

    -- Read-only debug Avalon-MM (WIP map).
    i_avs_address       : in  std_logic_vector(AVS_ADDR_WIDTH-1 downto 0) := (others => '0');
    i_avs_read          : in  std_logic := '0';
    o_avs_readdata      : out std_logic_vector(31 downto 0);
    o_avs_waitrequest   : out std_logic;
    o_avs_readdatavalid : out std_logic;

    -- Extra debug visibility.
    o_trim_drop_active     : out std_logic_vector(N_LANE-1 downto 0);
    o_wr_blocked_by_rd_lock : out std_logic
  );
end entity opq_top;

architecture rtl of opq_top is
  constant LANE_FIFO_ADDR_W   : natural := clog2(LANE_FIFO_DEPTH);
  constant TICKET_FIFO_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);
  constant HANDLE_FIFO_ADDR_W : natural := clog2(HANDLE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_W    : natural := clog2(PAGE_RAM_DEPTH);
  constant WORD_WR_CNT_WIDTH  : natural := clog2(HIT_SIZE*N_HIT);
  constant HANDLE_DATA_WIDTH  : natural := clog2(LANE_FIFO_DEPTH) + clog2(PAGE_RAM_DEPTH) + clog2(HIT_SIZE*N_HIT) + 1;

  constant TICKET_FIFO_DATA_WIDTH : natural := imax(
    48 + clog2(LANE_FIFO_DEPTH) + clog2(HIT_SIZE*N_HIT) + 2,
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2
  );

  -- FIFO signals.
  signal lane_we      : std_logic_vector(N_LANE-1 downto 0);
  signal lane_wptr    : unsigned_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_W-1 downto 0);
  signal lane_wdata   : slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);
  signal lane_wr_addr : slv_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_W-1 downto 0);

  signal ticket_we      : std_logic_vector(N_LANE-1 downto 0);
  signal ticket_wptr    : unsigned_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);
  signal ticket_wdata   : slv_array_t(0 to N_LANE-1)(TICKET_FIFO_DATA_WIDTH-1 downto 0);
  signal ticket_wr_addr : slv_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);

  signal ticket_rd_addr : slv_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);
  signal ticket_rd_data : slv_array_t(0 to N_LANE-1)(TICKET_FIFO_DATA_WIDTH-1 downto 0);

  signal handle_we      : std_logic_vector(N_LANE-1 downto 0);
  signal handle_wptr    : unsigned_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);
  signal handle_wdata   : slv_array_t(0 to N_LANE-1)(HANDLE_DATA_WIDTH-1 downto 0);
  signal handle_wr_addr : slv_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);

  signal handle_rd_addr : slv_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);
  signal handle_rd_data : slv_array_t(0 to N_LANE-1)(HANDLE_DATA_WIDTH-1 downto 0);

  signal lane_rd_addr : slv_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_W-1 downto 0);
  signal lane_rd_data : slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);

  -- Credits.
  signal lane_credit_update_valid   : std_logic_vector(N_LANE-1 downto 0);
  signal lane_credit_update         : unsigned_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_W-1 downto 0);
  signal ticket_credit_update_valid : std_logic_vector(N_LANE-1 downto 0);
  signal ticket_credit_update       : unsigned_array_t(0 to N_LANE-1)(TICKET_FIFO_ADDR_W-1 downto 0);

  -- Page allocator -> frame table.
  signal pa_write_head_start      : std_logic;
  signal pa_frame_start_addr      : unsigned(PAGE_RAM_ADDR_W-1 downto 0);
  signal pa_frame_shr_cnt_this    : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt_this    : unsigned(HIT_CNT_WIDTH-1 downto 0);

  signal pa_write_tail_done       : std_logic;
  signal pa_write_tail_active     : std_logic;
  signal pa_frame_start_addr_last : unsigned(PAGE_RAM_ADDR_W-1 downto 0);
  signal pa_frame_shr_cnt         : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt         : unsigned(HIT_CNT_WIDTH-1 downto 0);
  signal pa_frame_invalid_last    : std_logic;
  signal pa_handle_wptr           : unsigned_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);

  -- Page allocator -> arbiter.
  signal alloc_page_we    : std_logic;
  signal alloc_page_waddr : std_logic_vector(PAGE_RAM_ADDR_W-1 downto 0);
  signal alloc_page_wdata : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

  -- Block mover -> arbiter.
  signal bm_page_wreq   : std_logic_vector(N_LANE-1 downto 0);
  signal bm_page_wptr   : unsigned_array_t(0 to N_LANE-1)(PAGE_RAM_ADDR_W-1 downto 0);
  signal bm_word_wr_cnt : unsigned_array_t(0 to N_LANE-1)(WORD_WR_CNT_WIDTH-1 downto 0);
  signal bm_handle_pending : std_logic_vector(N_LANE-1 downto 0);
  signal bm_handle_rptr    : unsigned_array_t(0 to N_LANE-1)(HANDLE_FIFO_ADDR_W-1 downto 0);

  -- Arbiter.
  signal b2p_arb_gnt    : std_logic_vector(N_LANE-1 downto 0);
  signal page_ram_we    : std_logic;
  signal page_ram_addr  : std_logic_vector(PAGE_RAM_ADDR_W-1 downto 0);
  signal page_ram_wdata : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal quantum_update : std_logic_vector(N_LANE-1 downto 0);

  -- Frame table status for debug.
  constant TILE_ID_W : natural := clog2(N_TILE);
  signal mapper_state    : std_logic_vector(2 downto 0);
  signal presenter_state : std_logic_vector(2 downto 0);
  signal rseg_tile_index : unsigned(TILE_ID_W-1 downto 0);
  signal wseg_tile_index : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_W-1 downto 0);
  signal tile_wptr       : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
  signal tile_rptr       : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
  signal tile_pkt_wcnt   : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
  signal tile_pkt_rcnt   : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);

  -- Header fields for allocator output.
  signal dt_type : std_logic_vector(5 downto 0) := (others => '0');
  signal feb_id  : std_logic_vector(15 downto 0) := (others => '0');

  signal trim_drop_active_s : std_logic_vector(N_LANE-1 downto 0);
  signal wr_blocked_by_rd_lock_s : std_logic;
begin
  o_trim_drop_active <= trim_drop_active_s;
  o_wr_blocked_by_rd_lock <= wr_blocked_by_rd_lock_s;

  -- Lane FIFO is a ring buffer; pointer truncation assumes power-of-two depth.
  assert is_pow2(LANE_FIFO_DEPTH)
    report "OPQ: LANE_FIFO_DEPTH must be a power-of-two"
    severity failure;

  -- Latch dt_type/feb_id from lane0 preamble (for allocator header word0).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            OPQ_TOP.HDR_LATCH
  -- @brief           Latch dt_type/feb_id from lane0 K28.5 preamble for header word0 assembly
  -- @input           i_ingress_data/valid/startofpacket (lane0)
  -- @output          dt_type, feb_id
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_hdr_latch : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if (i_ingress_valid(0) = '1') and (i_ingress_startofpacket(0) = '1') then
        if (i_ingress_data(0)(35 downto 32) = "0001") and (i_ingress_data(0)(7 downto 0) = x"BC") then
          dt_type <= i_ingress_data(0)(31 downto 26);
          feb_id  <= i_ingress_data(0)(23 downto 8);
        end if;
      end if;
      if i_rst = '1' then
        dt_type <= (others => '0');
        feb_id  <= (others => '0');
      end if;
    end if;
  end process;

  u_ingress : entity work.opq_ingress_parser
    generic map (
      N_LANE => N_LANE,
      INGRESS_DATA_WIDTH => INGRESS_DATA_WIDTH,
      INGRESS_DATAK_WIDTH => INGRESS_DATAK_WIDTH,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
      TICKET_FIFO_DEPTH => TICKET_FIFO_DEPTH,
      HIT_SIZE => HIT_SIZE,
      N_HIT => N_HIT,
      FRAME_SERIAL_SIZE => FRAME_SERIAL_SIZE,
      FRAME_SUBH_CNT_SIZE => FRAME_SUBH_CNT_SIZE,
      FRAME_HIT_CNT_SIZE => FRAME_HIT_CNT_SIZE,
      TICKET_FIFO_DATA_WIDTH => TICKET_FIFO_DATA_WIDTH
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_ingress_data => i_ingress_data,
      i_ingress_valid => i_ingress_valid,
      i_ingress_channel => i_ingress_channel,
      i_ingress_startofpacket => i_ingress_startofpacket,
      i_ingress_endofpacket => i_ingress_endofpacket,
      i_ingress_error => i_ingress_error,

      i_lane_credit_update_valid => lane_credit_update_valid,
      i_lane_credit_update => lane_credit_update,
      i_ticket_credit_update_valid => ticket_credit_update_valid,
      i_ticket_credit_update => ticket_credit_update,

      o_lane_we => lane_we,
      o_lane_wptr => lane_wptr,
      o_lane_wdata => lane_wdata,
      o_lane_wr_addr => lane_wr_addr,

      o_ticket_we => ticket_we,
      o_ticket_wptr => ticket_wptr,
      o_ticket_wdata => ticket_wdata,
      o_ticket_wr_addr => ticket_wr_addr,

      o_trim_drop_active => trim_drop_active_s
    );

  -- Lane FIFOs (one per lane).
  gen_lane_fifo : for i in 0 to N_LANE-1 generate
    u_lane_fifo : entity work.opq_sync_ram
      generic map (
        DATA_WIDTH => LANE_FIFO_WIDTH,
        ADDR_WIDTH => LANE_FIFO_ADDR_W
      )
      port map (
        data       => lane_wdata(i),
        read_addr  => lane_rd_addr(i),
        write_addr => lane_wr_addr(i),
        we         => lane_we(i),
        clk        => i_clk,
        q          => lane_rd_data(i)
      );
  end generate;

  -- Ticket FIFOs (one per lane, show-ahead read for allocator).
  gen_ticket_fifo : for i in 0 to N_LANE-1 generate
    u_ticket_fifo : entity work.opq_sync_ram
      generic map (
        DATA_WIDTH => TICKET_FIFO_DATA_WIDTH,
        ADDR_WIDTH => TICKET_FIFO_ADDR_W
      )
      port map (
        data       => ticket_wdata(i),
        read_addr  => ticket_rd_addr(i),
        write_addr => ticket_wr_addr(i),
        we         => ticket_we(i),
        clk        => i_clk,
        q          => ticket_rd_data(i)
      );
  end generate;

  -- Handle FIFOs (one per lane, written by allocator, read by movers).
  gen_handle_fifo : for i in 0 to N_LANE-1 generate
    u_handle_fifo : entity work.opq_sync_ram
      generic map (
        DATA_WIDTH => HANDLE_DATA_WIDTH,
        ADDR_WIDTH => HANDLE_FIFO_ADDR_W
      )
      port map (
        data       => handle_wdata(i),
        read_addr  => handle_rd_addr(i),
        write_addr => handle_wr_addr(i),
        we         => handle_we(i),
        clk        => i_clk,
        q          => handle_rd_data(i)
      );
  end generate;

  u_page_alloc : entity work.opq_page_allocator
    generic map (
      MODE => "MERGING",
      N_LANE => N_LANE,
      N_SHD => N_SHD,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      TICKET_FIFO_DEPTH => TICKET_FIFO_DEPTH,
      HANDLE_FIFO_DEPTH => HANDLE_FIFO_DEPTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      HDR_SIZE => HDR_SIZE,
      SHD_SIZE => SHD_SIZE,
      HIT_SIZE => HIT_SIZE,
      TRL_SIZE => TRL_SIZE,
      N_HIT => N_HIT,
      FRAME_SERIAL_SIZE => FRAME_SERIAL_SIZE,
      FRAME_SUBH_CNT_SIZE => FRAME_SUBH_CNT_SIZE,
      FRAME_HIT_CNT_SIZE => FRAME_HIT_CNT_SIZE,
      SHD_CNT_WIDTH => SHD_CNT_WIDTH,
      HIT_CNT_WIDTH => HIT_CNT_WIDTH,
      TICKET_FIFO_DATA_WIDTH => TICKET_FIFO_DATA_WIDTH
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_dt_type => dt_type,
      i_feb_id => feb_id,

      i_ticket_wptr => ticket_wptr,
      o_ticket_rd_addr => ticket_rd_addr,
      i_ticket_rd_data => ticket_rd_data,

      o_ticket_credit_update_valid => ticket_credit_update_valid,
      o_ticket_credit_update => ticket_credit_update,

      o_handle_we => handle_we,
      o_handle_wptr => handle_wptr,
      o_handle_wdata => handle_wdata,
      o_handle_wr_addr => handle_wr_addr,

      i_handle_rptr => bm_handle_rptr,
      i_mover_busy => bm_handle_pending,

      o_alloc_page_we => alloc_page_we,
      o_alloc_page_waddr => alloc_page_waddr,
      o_alloc_page_wdata => alloc_page_wdata,

      o_pa_write_head_start => pa_write_head_start,
      o_pa_frame_start_addr => pa_frame_start_addr,
      o_pa_frame_shr_cnt_this => pa_frame_shr_cnt_this,
      o_pa_frame_hit_cnt_this => pa_frame_hit_cnt_this,

      o_pa_write_tail_done => pa_write_tail_done,
      o_pa_write_tail_active => pa_write_tail_active,
      o_pa_frame_start_addr_last => pa_frame_start_addr_last,
      o_pa_frame_shr_cnt => pa_frame_shr_cnt,
      o_pa_frame_hit_cnt => pa_frame_hit_cnt,
      o_pa_frame_invalid_last => pa_frame_invalid_last,
      o_pa_handle_wptr => pa_handle_wptr,

      o_quantum_update => quantum_update,
      i_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock_s
    );

  u_block_mover : entity work.opq_block_mover
    generic map (
      N_LANE => N_LANE,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
      HANDLE_FIFO_DEPTH => HANDLE_FIFO_DEPTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      HIT_SIZE => HIT_SIZE,
      N_HIT => N_HIT
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_handle_fifos_rd_data => handle_rd_data,
      i_handle_wptr => handle_wptr,
      i_handle_we => handle_we,
      o_handle_fifos_rd_addr => handle_rd_addr,

      i_lane_fifos_rd_data => lane_rd_data,
      o_lane_fifos_rd_addr => lane_rd_addr,

      i_b2p_arb_gnt => b2p_arb_gnt,

      o_page_wreq => bm_page_wreq,
      o_page_wptr => bm_page_wptr,
      o_word_wr_cnt => bm_word_wr_cnt,

      o_lane_credit_update_valid => lane_credit_update_valid,
      o_lane_credit_update => lane_credit_update,

      o_handle_pending => bm_handle_pending
    );

  u_b2p_arb : entity work.opq_b2p_arbiter
    generic map (
      N_LANE => N_LANE,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      WORD_WR_CNT_WIDTH => WORD_WR_CNT_WIDTH,
      QUANTUM_PER_SUBFRAME => QUANTUM_PER_SUBFRAME,
      QUANTUM_WIDTH => QUANTUM_WIDTH
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_bm_page_wreq => bm_page_wreq,
      i_bm_page_wptr => bm_page_wptr,
      i_bm_word_wr_cnt => bm_word_wr_cnt,
      i_bm_lane_rd_data => lane_rd_data,

      i_alloc_page_we => alloc_page_we,
      i_alloc_page_waddr => alloc_page_waddr,
      i_alloc_page_wdata => alloc_page_wdata,

      i_quantum_update => quantum_update,

      o_b2p_arb_gnt => b2p_arb_gnt,
      o_page_ram_we => page_ram_we,
      o_page_ram_wr_addr => page_ram_addr,
      o_page_ram_wr_data => page_ram_wdata
    );

  u_ftable : entity work.opq_frame_table
    generic map (
      N_LANE => N_LANE,
      N_TILE => N_TILE,
      N_WR_SEG => N_WR_SEG,
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      SHD_CNT_WIDTH => SHD_CNT_WIDTH,
      HIT_CNT_WIDTH => HIT_CNT_WIDTH,
      HANDLE_PTR_WIDTH => HANDLE_FIFO_ADDR_W,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH,
      EGRESS_DELAY => EGRESS_DELAY,
      SHD_SIZE => SHD_SIZE,
      HIT_SIZE => HIT_SIZE,
      HDR_SIZE => HDR_SIZE,
      TRL_SIZE => TRL_SIZE,
      DEBUG_LV => DEBUG_LV
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_pa_write_head_start => pa_write_head_start,
      i_pa_frame_start_addr => pa_frame_start_addr,
      i_pa_frame_shr_cnt_this => pa_frame_shr_cnt_this,
      i_pa_frame_hit_cnt_this => pa_frame_hit_cnt_this,

      i_pa_write_tail_done => pa_write_tail_done,
      i_pa_write_tail_active => pa_write_tail_active,
      i_pa_frame_start_addr_last => pa_frame_start_addr_last,
      i_pa_frame_shr_cnt => pa_frame_shr_cnt,
      i_pa_frame_hit_cnt => pa_frame_hit_cnt,
      i_pa_frame_invalid_last => pa_frame_invalid_last,
      i_pa_handle_wptr => pa_handle_wptr,

      i_bm_handle_rptr => bm_handle_rptr,

      i_page_ram_we => page_ram_we,
      i_page_ram_wr_addr => unsigned(page_ram_addr),
      i_page_ram_wr_data => page_ram_wdata,

      i_egress_ready => i_egress_ready,
      o_egress_valid => o_egress_valid,
      o_egress_data => o_egress_data,
      o_egress_startofpacket => o_egress_startofpacket,
      o_egress_endofpacket => o_egress_endofpacket,

      o_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock_s,
      o_mapper_state => mapper_state,
      o_presenter_state => presenter_state,
      o_rseg_tile_index => rseg_tile_index,
      o_wseg_tile_index => wseg_tile_index,
      o_tile_wptr => tile_wptr,
      o_tile_rptr => tile_rptr,
      o_tile_pkt_wcnt => tile_pkt_wcnt,
      o_tile_pkt_rcnt => tile_pkt_rcnt
    );

  u_dbg : entity work.opq_rd_debug_if
    generic map (
      AVS_ADDR_WIDTH => AVS_ADDR_WIDTH,
      N_TILE => N_TILE,
      N_WR_SEG => N_WR_SEG,
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_avs_address => i_avs_address,
      i_avs_read => i_avs_read,
      o_avs_readdata => o_avs_readdata,
      o_avs_waitrequest => o_avs_waitrequest,
      o_avs_readdatavalid => o_avs_readdatavalid,

      i_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock_s,
      i_mapper_state => mapper_state,
      i_presenter_state => presenter_state,
      i_rseg_tile_index => rseg_tile_index,
      i_wseg_tile_index => wseg_tile_index,
      i_tile_wptr => tile_wptr,
      i_tile_rptr => tile_rptr,
      i_tile_pkt_wcnt => tile_pkt_wcnt,
      i_tile_pkt_rcnt => tile_pkt_rcnt
    );

  -- Convert handle read pointers to unsigned arrays (used by allocator/frame-table for stalling/finalize).
  gen_handle_rptr : for i in 0 to N_LANE-1 generate
    bm_handle_rptr(i) <= unsigned(handle_rd_addr(i));
  end generate;
end architecture rtl;

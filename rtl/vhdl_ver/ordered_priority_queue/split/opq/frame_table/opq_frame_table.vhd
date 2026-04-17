-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_frame_table
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Frame-table complex binding mapper + tracker + presenter around the tiled page RAMs.
--                      Responsible for mapping packet allocations to tiles and presenting complete packets.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

entity opq_frame_table is
  generic (
    N_LANE            : positive := 2;
    N_TILE            : positive := 5;
    N_WR_SEG          : positive := 4;

    TILE_FIFO_DEPTH   : positive := 512;
    PAGE_RAM_DEPTH    : positive := 65536;
    PAGE_RAM_DATA_WIDTH : positive := 40;

    SHD_CNT_WIDTH     : positive := 16;
    HIT_CNT_WIDTH     : positive := 16;
    HANDLE_PTR_WIDTH  : positive := 6;
    TILE_PKT_CNT_WIDTH : positive := 10;
    EGRESS_DELAY      : natural := 2;

    SHD_SIZE          : natural := 8;
    HIT_SIZE          : natural := 1;
    HDR_SIZE          : natural := 5;
    TRL_SIZE          : natural := 1;

    -- Debug: 0=off, 1=basic, 2=verbose (simulation diagnostics only).
    DEBUG_LV          : natural := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Page allocator events + counters (minimal subset needed by mapper).
    i_pa_write_head_start      : in  std_logic;
    i_pa_frame_start_addr      : in  unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt_this    : in  unsigned(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt_this    : in  unsigned(HIT_CNT_WIDTH-1 downto 0);

    i_pa_write_tail_done       : in  std_logic;
    i_pa_write_tail_active     : in  std_logic;
    i_pa_frame_start_addr_last : in  unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt         : in  unsigned(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt         : in  unsigned(HIT_CNT_WIDTH-1 downto 0);
    i_pa_frame_invalid_last    : in  std_logic;
    i_pa_handle_wptr           : in  unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);

    -- Block mover status (used to delay finalize until movers drained).
    i_bm_handle_rptr           : in  unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);

    -- Page RAM write stream into the tiled page memories (single write port).
    i_page_ram_we              : in  std_logic;
    i_page_ram_wr_addr         : in  unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_page_ram_wr_data         : in  std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- Egress.
    i_egress_ready             : in  std_logic;
    o_egress_valid             : out std_logic;
    o_egress_data              : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    o_egress_startofpacket     : out std_logic;
    o_egress_endofpacket       : out std_logic;

    -- Status/debug.
    o_wr_blocked_by_rd_lock    : out std_logic;
    o_mapper_state             : out std_logic_vector(2 downto 0);
    o_presenter_state          : out std_logic_vector(2 downto 0);
    o_rseg_tile_index          : out unsigned(clog2(N_TILE)-1 downto 0);
    o_wseg_tile_index          : out unsigned_array_t(0 to N_WR_SEG-1)(clog2(N_TILE)-1 downto 0);
    o_tile_wptr                : out unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_tile_rptr                : out unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_tile_pkt_wcnt            : out unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    o_tile_pkt_rcnt            : out unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0)
  );
end entity opq_frame_table;

architecture rtl of opq_frame_table is
  constant PAGE_RAM_ADDR_W  : natural := clog2(PAGE_RAM_DEPTH);
  constant TILE_ID_W        : natural := clog2(N_TILE);
  constant TILE_FIFO_ADDR_W : natural := clog2(TILE_FIFO_DEPTH);
  constant TILE_FIFO_DATA_W : natural := 2 * PAGE_RAM_ADDR_W;

  -- Mapper outputs.
  signal mapper_update_valid       : std_logic_vector(1 downto 0);
  signal mapper_update_tindex      : unsigned_array_t(0 to 1)(TILE_ID_W-1 downto 0);
  signal mapper_update_meta_valid  : std_logic_vector(1 downto 0);
  signal mapper_update_meta        : slv_array_t(0 to 1)(2*PAGE_RAM_ADDR_W-1 downto 0);
  signal mapper_update_trltl_valid : std_logic_vector(1 downto 0);
  signal mapper_update_trltl       : unsigned_array_t(0 to 1)(TILE_ID_W-1 downto 0);
  signal mapper_update_bdytl_valid : std_logic_vector(1 downto 0);
  signal mapper_update_bdytl       : unsigned_array_t(0 to 1)(TILE_ID_W-1 downto 0);
  signal mapper_update_hcmpl       : std_logic_vector(1 downto 0);
  signal mapper_flush_valid        : std_logic_vector(1 downto 0);

  signal wseg_tile_index     : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_W-1 downto 0);
  signal leading_wr_tile_reg : unsigned(TILE_ID_W-1 downto 0);
  signal expand_wr_tile_reg  : unsigned(TILE_ID_W-1 downto 0);
  signal writing_tile_index  : unsigned(TILE_ID_W-1 downto 0);
  signal mapper_state_code   : std_logic_vector(2 downto 0);

  -- Tracker outputs.
  signal tile_fifo_we      : std_logic_vector(N_TILE-1 downto 0);
  signal tile_fifo_wr_addr : slv_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0);
  signal tile_fifo_wr_data : slv_array_t(0 to N_TILE-1)(TILE_FIFO_DATA_W-1 downto 0);
  signal tile_wptr         : unsigned_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0);
  signal tile_pkt_wcnt     : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
  signal trail_tid         : unsigned_array_t(0 to N_TILE-1)(TILE_ID_W downto 0);
  signal body_tid          : unsigned_array_t(0 to N_TILE-1)(TILE_ID_W downto 0);

  -- Tile FIFO memory interface.
  signal tile_fifo_rd_addr : slv_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0);
  signal tile_fifo_rd_data : slv_array_t(0 to N_TILE-1)(TILE_FIFO_DATA_W-1 downto 0);

  -- Page tile RAM interface.
  signal page_tile_rd_addr : slv_array_t(0 to N_TILE-1)(PAGE_RAM_ADDR_W-1 downto 0);
  signal page_tile_rd_data : slv_array_t(0 to N_TILE-1)(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal page_tile_we      : std_logic_vector(N_TILE-1 downto 0);
  signal page_tile_wr_addr : std_logic_vector(PAGE_RAM_ADDR_W-1 downto 0);

  -- Presenter outputs/feedback.
  signal tile_rptr       : unsigned_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0);
  signal tile_pkt_rcnt   : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
  signal rseg_tile_index : unsigned(TILE_ID_W-1 downto 0);
  signal void_trail_tid  : std_logic;
  signal void_body_tid   : std_logic;
  signal presenter_active : std_logic;
  signal presenter_warping : std_logic;
  signal is_rd_tile_in_range : std_logic;
  signal crossing_tile_valid : std_logic;
  signal crossing_tile       : unsigned(TILE_ID_W-1 downto 0);
  signal trailing_active0    : std_logic;
  signal trailing_tile_index : unsigned(TILE_ID_W-1 downto 0);
  signal presenter_state_code : std_logic_vector(2 downto 0);

  signal wr_blocked_by_rd_lock : std_logic;
  signal mapper_busy : std_logic;

  -- Simulation-only diagnostics for write-vs-read lock contention.
  -- synthesis translate_off
  signal wr_blocked_q   : std_logic := '0';
  signal wr_blocked_cnt : natural := 0;
  -- synthesis translate_on
begin
  o_wr_blocked_by_rd_lock <= wr_blocked_by_rd_lock;
  o_mapper_state <= mapper_state_code;
  o_presenter_state <= presenter_state_code;
  o_rseg_tile_index <= rseg_tile_index;
  o_wseg_tile_index <= wseg_tile_index;
  o_tile_wptr <= tile_wptr;
  o_tile_rptr <= tile_rptr;
  o_tile_pkt_wcnt <= tile_pkt_wcnt;
  o_tile_pkt_rcnt <= tile_pkt_rcnt;

  -- Mapper "busy" heuristics (used to freeze presenter warps during tile updates).
  mapper_busy <= '0' when mapper_state_code = "000" else '1';

  u_mapper : entity work.opq_frame_table_mapper
    generic map (
      N_LANE           => N_LANE,
      N_TILE           => N_TILE,
      N_WR_SEG         => N_WR_SEG,
      PAGE_RAM_DEPTH   => PAGE_RAM_DEPTH,
      SHD_CNT_WIDTH    => SHD_CNT_WIDTH,
      HIT_CNT_WIDTH    => HIT_CNT_WIDTH,
      HANDLE_PTR_WIDTH => HANDLE_PTR_WIDTH,
      SHD_SIZE         => SHD_SIZE,
      HIT_SIZE         => HIT_SIZE,
      HDR_SIZE         => HDR_SIZE,
      TRL_SIZE         => TRL_SIZE,
      DEBUG_LV         => DEBUG_LV
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_pa_write_head_start    => i_pa_write_head_start,
      i_pa_frame_start_addr    => i_pa_frame_start_addr,
      i_pa_frame_shr_cnt_this  => i_pa_frame_shr_cnt_this,
      i_pa_frame_hit_cnt_this  => i_pa_frame_hit_cnt_this,

      i_pa_write_tail_done      => i_pa_write_tail_done,
      i_pa_write_tail_active    => i_pa_write_tail_active,
      i_pa_frame_start_addr_last => i_pa_frame_start_addr_last,
      i_pa_frame_shr_cnt        => i_pa_frame_shr_cnt,
      i_pa_frame_hit_cnt        => i_pa_frame_hit_cnt,
      i_pa_frame_invalid_last   => i_pa_frame_invalid_last,
      i_pa_handle_wptr          => i_pa_handle_wptr,

      i_bm_handle_rptr          => i_bm_handle_rptr,

      i_presenter_active        => presenter_active,
      i_presenter_warping       => presenter_warping,
      i_presenter_rseg_tile_index => rseg_tile_index,
      i_presenter_crossing_tile_valid => crossing_tile_valid,
      i_presenter_crossing_tile => crossing_tile,
      i_presenter_rd_tile_in_range => is_rd_tile_in_range,

      i_page_ram_we             => i_page_ram_we,
      i_page_ram_wr_addr        => i_page_ram_wr_addr,

      o_update_ftable_valid     => mapper_update_valid,
      o_update_ftable_tindex    => mapper_update_tindex,
      o_update_ftable_meta_valid => mapper_update_meta_valid,
      o_update_ftable_meta      => mapper_update_meta,
      o_update_ftable_trltl_valid => mapper_update_trltl_valid,
      o_update_ftable_trltl     => mapper_update_trltl,
      o_update_ftable_bdytl_valid => mapper_update_bdytl_valid,
      o_update_ftable_bdytl     => mapper_update_bdytl,
      o_update_ftable_hcmpl     => mapper_update_hcmpl,
      o_flush_ftable_valid      => mapper_flush_valid,

      o_wseg_tile_index         => wseg_tile_index,
      o_leading_wr_tile_index_reg => leading_wr_tile_reg,
      o_expand_wr_tile_index_reg  => expand_wr_tile_reg,
      o_writing_tile_index      => writing_tile_index,
      o_state                   => mapper_state_code
    );

  u_tracker : entity work.opq_frame_table_tracker
    generic map (
      N_TILE           => N_TILE,
      TILE_FIFO_DEPTH  => TILE_FIFO_DEPTH,
      PAGE_RAM_DEPTH   => PAGE_RAM_DEPTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_update_ftable_valid      => mapper_update_valid,
      i_update_ftable_tindex     => mapper_update_tindex,
      i_update_ftable_meta_valid => mapper_update_meta_valid,
      i_update_ftable_meta       => mapper_update_meta,
      i_update_ftable_trltl_valid => mapper_update_trltl_valid,
      i_update_ftable_trltl      => mapper_update_trltl,
      i_update_ftable_bdytl_valid => mapper_update_bdytl_valid,
      i_update_ftable_bdytl      => mapper_update_bdytl,
      i_update_ftable_hcmpl      => mapper_update_hcmpl,
      i_flush_ftable_valid       => mapper_flush_valid,

      i_tile_rptr       => tile_rptr,
      i_tile_pkt_rcnt   => tile_pkt_rcnt,
      i_rseg_tile_index => rseg_tile_index,
      i_void_trail_tid  => void_trail_tid,
      i_void_body_tid   => void_body_tid,

      o_tile_fifo_we      => tile_fifo_we,
      o_tile_fifo_wr_addr => tile_fifo_wr_addr,
      o_tile_fifo_wr_data => tile_fifo_wr_data,

      o_tile_wptr       => tile_wptr,
      o_tile_pkt_wcnt   => tile_pkt_wcnt,
      o_trail_tid       => trail_tid,
      o_body_tid        => body_tid
    );

  u_presenter : entity work.opq_frame_table_presenter
    generic map (
      N_TILE            => N_TILE,
      N_WR_SEG          => N_WR_SEG,
      TILE_FIFO_DEPTH   => TILE_FIFO_DEPTH,
      PAGE_RAM_DEPTH    => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH,
      EGRESS_DELAY      => EGRESS_DELAY,
      DEBUG_LV          => DEBUG_LV
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_wseg_tile_index          => wseg_tile_index,
      i_leading_wr_tile_index_reg => leading_wr_tile_reg,
      i_mapper_busy              => mapper_busy,
      i_pa_write_head_start      => i_pa_write_head_start,

      i_tile_wptr      => tile_wptr,
      i_tile_pkt_wcnt  => tile_pkt_wcnt,
      i_trail_tid      => trail_tid,
      i_body_tid       => body_tid,
      i_tile_fifo_rd_data => tile_fifo_rd_data,

      i_page_tile_rd_data => page_tile_rd_data,
      i_egress_ready      => i_egress_ready,

      o_tile_fifo_rd_addr => tile_fifo_rd_addr,
      o_page_tile_rd_addr => page_tile_rd_addr,

      o_tile_rptr       => tile_rptr,
      o_tile_pkt_rcnt   => tile_pkt_rcnt,
      o_rseg_tile_index => rseg_tile_index,
      o_void_trail_tid  => void_trail_tid,
      o_void_body_tid   => void_body_tid,

      o_presenter_active    => presenter_active,
      o_presenter_warping   => presenter_warping,
      o_is_rd_tile_in_range => is_rd_tile_in_range,
      o_crossing_tile_valid => crossing_tile_valid,
      o_crossing_tile       => crossing_tile,
      o_trailing_active0    => trailing_active0,
      o_trailing_tile_index => trailing_tile_index,
      o_state               => presenter_state_code,

      o_egress_valid        => o_egress_valid,
      o_egress_data         => o_egress_data,
      o_egress_startofpacket => o_egress_startofpacket,
      o_egress_endofpacket   => o_egress_endofpacket
    );

  -- ───────────────────────────────────────────────────────────────
  -- Tile FIFO memories (one per tile).
  -- ───────────────────────────────────────────────────────────────
  gen_tile_fifo : for i in 0 to N_TILE-1 generate
    u_tile_fifo : entity work.opq_sync_ram
      generic map (
        DATA_WIDTH => TILE_FIFO_DATA_W,
        ADDR_WIDTH => TILE_FIFO_ADDR_W
      )
      port map (
        data       => tile_fifo_wr_data(i),
        read_addr  => tile_fifo_rd_addr(i),
        write_addr => tile_fifo_wr_addr(i),
        we         => tile_fifo_we(i),
        clk        => i_clk,
        q          => tile_fifo_rd_data(i)
      );
  end generate;

  -- ───────────────────────────────────────────────────────────────
  -- Page tile memories (one per tile), with write-side guarding.
  -- ───────────────────────────────────────────────────────────────
  -- Block writes into tiles locked by the presenter (any active read-side state).
  -- - Always lock the current rseg tile.
  -- - If a packet spans two tiles, lock the spill tail tile as soon as it is known (crossing_tile_valid),
  --   and keep it locked while reading the trailing segment (trailing_active0).
  -- - When a write is blocked, the page allocator is notified (i_wr_blocked_by_rd_lock) and will mark
  --   the affected frame(s) invalid so the mapper/presenter drops whole frames (drop is preferred over
  --   presenting broken packets).
  wr_blocked_by_rd_lock <= '1' when
    (i_page_ram_we = '1')
    and (presenter_active = '1')
    and (
      (writing_tile_index = rseg_tile_index)
      or ((crossing_tile_valid = '1') and (writing_tile_index = crossing_tile))
      or ((trailing_active0 = '1') and (writing_tile_index = trailing_tile_index))
    ) else '0';

  page_tile_wr_addr <= std_logic_vector(i_page_ram_wr_addr);
  gen_page_tile_we : for i in 0 to N_TILE-1 generate
    page_tile_we(i) <= '1' when (i_page_ram_we = '1')
                            and (writing_tile_index = to_unsigned(i, TILE_ID_W))
                            and (wr_blocked_by_rd_lock = '0')
                       else '0';

    u_page_tile : entity work.opq_sync_ram
      generic map (
        DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
        ADDR_WIDTH => PAGE_RAM_ADDR_W
      )
      port map (
        data       => i_page_ram_wr_data,
        read_addr  => page_tile_rd_addr(i),
        write_addr => page_tile_wr_addr,
        we         => page_tile_we(i),
        clk        => i_clk,
        q          => page_tile_rd_data(i)
      );
  end generate;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE.WR_LOCK_DBG
  -- @brief           Simulation-only tap for write blocks due to presenter tile locks
  -- @input           wr_blocked_by_rd_lock, writing_tile_index, rseg/crossing/trailing context
  -- @output          report note (DEBUG_LV>=2) on rising edge of lock block
  -- @description     This hook is intentionally rate-limited and edge-triggered to avoid log floods.
  --                  It is useful to confirm the “never write to read-locked tiles” rule and to
  --                  correlate whole-frame drops back to the first cycle of contention.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- synthesis translate_off
  proc_wr_lock_dbg : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        wr_blocked_q   <= '0';
        wr_blocked_cnt <= 0;
      else
        if (wr_blocked_by_rd_lock = '1') and (wr_blocked_q = '0') then
          wr_blocked_cnt <= wr_blocked_cnt + 1;
          if (DEBUG_LV >= 2) and (wr_blocked_cnt < 50) then
            report "FTABLE: WR blocked by RD lock"
                   & " t=" & time'image(now)
                   & " wr_tile=" & integer'image(to_integer(writing_tile_index))
                   & " rseg=" & integer'image(to_integer(rseg_tile_index))
                   & " cross_v=" & std_logic'image(crossing_tile_valid)
                   & " cross=" & integer'image(to_integer(crossing_tile))
                   & " trl_v=" & std_logic'image(trailing_active0)
                   & " trl_tile=" & integer'image(to_integer(trailing_tile_index))
                   & " addr=" & integer'image(to_integer(i_page_ram_wr_addr))
                   severity note;
          end if;
        end if;
        wr_blocked_q <= wr_blocked_by_rd_lock;
      end if;
    end if;
  end process;
  -- synthesis translate_on
end architecture rtl;

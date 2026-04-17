-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_frame_table_tracker
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Tracks packet locations and completion status by writing per-tile FIFO metadata and
--                      maintaining per-tile spill linkage/lock bits for safe overwrite + presentation.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.or_reduce;

use work.opq_util_pkg.all;

entity opq_frame_table_tracker is
  generic (
    N_TILE           : positive := 5;
    TILE_FIFO_DEPTH  : positive := 512;
    PAGE_RAM_DEPTH   : positive := 65536;
    TILE_PKT_CNT_WIDTH : positive := 10
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Commands from mapper (pulse signals; typically asserted for 1 cycle).
    i_update_ftable_valid      : in  std_logic_vector(1 downto 0);
    i_update_ftable_tindex     : in  unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    i_update_ftable_meta_valid : in  std_logic_vector(1 downto 0);
    i_update_ftable_meta       : in  slv_array_t(0 to 1)(2*clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_update_ftable_trltl_valid : in std_logic_vector(1 downto 0);
    i_update_ftable_trltl      : in  unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    i_update_ftable_bdytl_valid : in std_logic_vector(1 downto 0);
    i_update_ftable_bdytl      : in  unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    i_update_ftable_hcmpl      : in  std_logic_vector(1 downto 0);
    i_flush_ftable_valid       : in  std_logic_vector(1 downto 0);

    -- Presenter feedback (used for safe flush + reg voiding).
    i_tile_rptr       : in  unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    i_tile_pkt_rcnt   : in  unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    i_rseg_tile_index : in  unsigned(clog2(N_TILE)-1 downto 0);
    i_void_trail_tid  : in  std_logic;
    i_void_body_tid   : in  std_logic;

    -- Outputs to external tile FIFO RAMs.
    o_tile_fifo_we      : out std_logic_vector(N_TILE-1 downto 0);
    o_tile_fifo_wr_addr : out slv_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_tile_fifo_wr_data : out slv_array_t(0 to N_TILE-1)(2*clog2(PAGE_RAM_DEPTH)-1 downto 0);

    -- Status/regs for presenter.
    o_tile_wptr       : out unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_tile_pkt_wcnt   : out unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    o_trail_tid       : out unsigned_array_t(0 to N_TILE-1)(clog2(N_TILE) downto 0); -- msb valid
    o_body_tid        : out unsigned_array_t(0 to N_TILE-1)(clog2(N_TILE) downto 0)  -- msb lock/valid
  );
end entity opq_frame_table_tracker;

architecture rtl of opq_frame_table_tracker is
  constant TILE_ID_WIDTH      : natural := clog2(N_TILE);
  constant TILE_FIFO_ADDR_W   : natural := clog2(TILE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_W    : natural := clog2(PAGE_RAM_DEPTH);
  constant TILE_FIFO_DATA_W   : natural := 2 * PAGE_RAM_ADDR_W;

  type tracker_state_t is (IDLE, RECORD_TILE, RESET);
  signal state : tracker_state_t := RESET;

  -- Tile FIFO meta pointers + completed-packet counters.
  signal tile_wptr     : unsigned_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0) := (others => (others => '0'));
  signal tile_pkt_wcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => '0'));

  -- Spill linkage regs (per tile).
  signal trail_tid : unsigned_array_t(0 to N_TILE-1)(TILE_ID_WIDTH downto 0) := (others => (others => '0'));
  signal body_tid  : unsigned_array_t(0 to N_TILE-1)(TILE_ID_WIDTH downto 0) := (others => (others => '0'));

  -- Latched mapper commands (executed in RECORD_TILE).
  signal upd_valid      : std_logic_vector(1 downto 0) := (others => '0');
  signal upd_tindex     : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal upd_meta_valid : std_logic_vector(1 downto 0) := (others => '0');
  signal upd_meta       : slv_array_t(0 to 1)(TILE_FIFO_DATA_W-1 downto 0) := (others => (others => '0'));
  signal upd_trltl_valid : std_logic_vector(1 downto 0) := (others => '0');
  signal upd_trltl      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal upd_bdytl_valid : std_logic_vector(1 downto 0) := (others => '0');
  signal upd_bdytl      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal upd_hcmpl      : std_logic_vector(1 downto 0) := (others => '0');
begin
  o_tile_wptr     <= tile_wptr;
  o_tile_pkt_wcnt <= tile_pkt_wcnt;
  o_trail_tid     <= trail_tid;
  o_body_tid      <= body_tid;

  -- Tile FIFO write interface (combinational, driven while RECORD_TILE is active).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_TRACKER.TILE_FIFO_WR_COMB
  -- @brief           Drive per-tile FIFO write enables/addr/data based on latched mapper commands
  -- @input           state, upd_meta_valid/upd_tindex/upd_meta, tile_wptr
  -- @output          o_tile_fifo_we/o_tile_fifo_wr_addr/o_tile_fifo_wr_data
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_tile_fifo_wr_comb : process (all) is
    variable we_v      : std_logic_vector(N_TILE-1 downto 0);
    variable wr_addr_v : slv_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0);
    variable wr_data_v : slv_array_t(0 to N_TILE-1)(TILE_FIFO_DATA_W-1 downto 0);
    variable tile_i    : natural range 0 to N_TILE-1;
  begin
    we_v := (others => '0');
    wr_addr_v := (others => (others => '0'));
    wr_data_v := (others => (others => '0'));

    if state = RECORD_TILE then
      for a in 0 to 1 loop
        tile_i := to_integer(upd_tindex(a));
        if upd_meta_valid(a) = '1' then
          we_v(tile_i) := '1';
          wr_addr_v(tile_i) := std_logic_vector(tile_wptr(tile_i));
          wr_data_v(tile_i) := upd_meta(a);
        end if;
      end loop;
    end if;

    o_tile_fifo_we      <= we_v;
    o_tile_fifo_wr_addr <= wr_addr_v;
    o_tile_fifo_wr_data <= wr_data_v;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_TRACKER.REG
  -- @brief           Consume mapper update/flush pulses and update per-tile meta pointers and spill linkage
  -- @input           i_update_ftable_*, i_flush_ftable_valid, presenter voids and rseg index
  -- @output          tile_wptr/tile_pkt_wcnt, trail_tid/body_tid
  -- @description     Flush is the “sacrifice” mechanism: it resets `tile_wptr` to the presenter’s
  --                  `tile_rptr` and aligns packet counters to `tile_pkt_rcnt`, effectively dropping
  --                  any queued (unread) meta before the mapper reuses that tile for new writes.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_tracker : process (i_clk) is
    variable tile_i : natural range 0 to N_TILE-1;
  begin
    if rising_edge(i_clk) then
      -- Priority 0: flush (drop queued packets in a tile before overwrite).
      if or_reduce(i_flush_ftable_valid) = '1' then
        for a in 0 to 1 loop
          if i_flush_ftable_valid(a) = '1' then
            tile_i := to_integer(i_update_ftable_tindex(a));
            trail_tid(tile_i) <= (others => '0');
            body_tid(tile_i)  <= (others => '0');
            tile_wptr(tile_i) <= i_tile_rptr(tile_i);
            tile_pkt_wcnt(tile_i) <= i_tile_pkt_rcnt(tile_i);
          end if;
        end loop;
      end if;

      case state is
        when IDLE =>
          if or_reduce(i_update_ftable_valid) = '1' then
            upd_valid       <= i_update_ftable_valid;
            upd_tindex      <= i_update_ftable_tindex;
            upd_meta_valid  <= i_update_ftable_meta_valid;
            upd_meta        <= i_update_ftable_meta;
            upd_trltl_valid <= i_update_ftable_trltl_valid;
            upd_trltl       <= i_update_ftable_trltl;
            upd_bdytl_valid <= i_update_ftable_bdytl_valid;
            upd_bdytl       <= i_update_ftable_bdytl;
            upd_hcmpl       <= i_update_ftable_hcmpl;
            state <= RECORD_TILE;
          elsif or_reduce(upd_valid) = '1' then
            -- Handle a pending latched command (should be rare, but matches the monolithic behavior).
            state <= RECORD_TILE;
          end if;

        when RECORD_TILE =>
          for a in 0 to 1 loop
            tile_i := to_integer(upd_tindex(a));

            if upd_meta_valid(a) = '1' then
              tile_wptr(tile_i) <= tile_wptr(tile_i) + 1;
            end if;

            if upd_trltl_valid(a) = '1' then
              trail_tid(tile_i) <= '1' & upd_trltl(a);
            end if;

            if upd_bdytl_valid(a) = '1' then
              body_tid(tile_i)(TILE_ID_WIDTH-1 downto 0) <= upd_bdytl(a);
              -- Leave msb (lock/valid) untouched; default is '0' (unlocked).
            end if;

            if upd_hcmpl(a) = '1' then
              tile_pkt_wcnt(tile_i) <= tile_pkt_wcnt(tile_i) + 1;
            end if;
          end loop;

          upd_valid       <= (others => '0');
          upd_meta_valid  <= (others => '0');
          upd_trltl_valid <= (others => '0');
          upd_bdytl_valid <= (others => '0');
          upd_hcmpl       <= (others => '0');
          state <= IDLE;

        when RESET =>
          tile_wptr     <= (others => (others => '0'));
          tile_pkt_wcnt <= (others => (others => '0'));
          trail_tid     <= (others => (others => '0'));
          body_tid      <= (others => (others => '0'));
          upd_valid     <= (others => '0');
          upd_meta_valid <= (others => '0');
          upd_trltl_valid <= (others => '0');
          upd_bdytl_valid <= (others => '0');
          upd_hcmpl <= (others => '0');
          state <= IDLE;

        when others =>
          null;
      end case;

      -- Presenter-driven voids.
      if i_void_body_tid = '1' then
        tile_i := to_integer(i_rseg_tile_index);
        body_tid(tile_i)(body_tid(tile_i)'high) <= '0';
      end if;
      if i_void_trail_tid = '1' then
        tile_i := to_integer(i_rseg_tile_index);
        trail_tid(tile_i)(trail_tid(tile_i)'high) <= '0';
      end if;

      if i_rst = '1' then
        state <= RESET;
      end if;
    end if;
  end process;
end architecture rtl;

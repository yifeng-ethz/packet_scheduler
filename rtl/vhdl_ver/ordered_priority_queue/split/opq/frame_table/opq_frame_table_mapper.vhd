-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_frame_table_mapper
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Maps allocator progress into frame-table (tile FIFO) meta updates and manages the
--                      write-segment (wseg) -> tile mapping, including spill/overwrite handling.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

entity opq_frame_table_mapper is
  generic (
    N_LANE          : positive := 2;
    N_TILE          : positive := 5;
    N_WR_SEG        : positive := 4;

    PAGE_RAM_DEPTH  : positive := 65536;
    SHD_CNT_WIDTH   : positive := 16;
    HIT_CNT_WIDTH   : positive := 16;
    HANDLE_PTR_WIDTH : positive := 6;

    -- Word-counting sizes for frame-span estimation.
    SHD_SIZE        : natural := 8;
    HIT_SIZE        : natural := 1;
    HDR_SIZE        : natural := 5;
    TRL_SIZE        : natural := 1;

    -- Debug: 0=off, 1=basic, 2=verbose (simulation diagnostics only).
    DEBUG_LV        : natural := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Page allocator (events + counters).
    i_pa_write_head_start     : in  std_logic; -- (WRITE_HEAD, meta_flow=0)
    i_pa_frame_start_addr     : in  unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt_this   : in  unsigned(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt_this   : in  unsigned(HIT_CNT_WIDTH-1 downto 0);

    i_pa_write_tail_done      : in  std_logic; -- (WRITE_TAIL, meta_flow=3)
    i_pa_write_tail_active    : in  std_logic; -- page allocator in WRITE_TAIL
    i_pa_frame_start_addr_last : in unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt        : in  unsigned(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt        : in  unsigned(HIT_CNT_WIDTH-1 downto 0);
    i_pa_frame_invalid_last   : in  std_logic;
    i_pa_handle_wptr          : in  unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);

    -- Block mover status.
    i_bm_handle_rptr          : in  unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);

    -- Presenter status (locks/warps).
    i_presenter_active        : in  std_logic;
    i_presenter_warping       : in  std_logic;
    i_presenter_rseg_tile_index : in unsigned(clog2(N_TILE)-1 downto 0);
    i_presenter_crossing_tile_valid : in std_logic;
    i_presenter_crossing_tile : in  unsigned(clog2(N_TILE)-1 downto 0);
    i_presenter_rd_tile_in_range : in std_logic;

    -- Page RAM write address (used only to decide spill tile vs head tile).
    i_page_ram_we             : in  std_logic;
    i_page_ram_wr_addr        : in  unsigned(clog2(PAGE_RAM_DEPTH)-1 downto 0);

    -- Outputs to tile FIFO tracker.
    o_update_ftable_valid     : out std_logic_vector(1 downto 0);
    o_update_ftable_tindex    : out unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    o_update_ftable_meta_valid : out std_logic_vector(1 downto 0);
    o_update_ftable_meta      : out slv_array_t(0 to 1)(2*clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_update_ftable_trltl_valid : out std_logic_vector(1 downto 0);
    o_update_ftable_trltl     : out unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    o_update_ftable_bdytl_valid : out std_logic_vector(1 downto 0);
    o_update_ftable_bdytl     : out unsigned_array_t(0 to 1)(clog2(N_TILE)-1 downto 0);
    o_update_ftable_hcmpl     : out std_logic_vector(1 downto 0);
    o_flush_ftable_valid      : out std_logic_vector(1 downto 0);

    -- Current mapping (for top-level routing).
    o_wseg_tile_index         : out unsigned_array_t(0 to N_WR_SEG-1)(clog2(N_TILE)-1 downto 0);
    o_leading_wr_tile_index_reg : out unsigned(clog2(N_TILE)-1 downto 0);
    o_expand_wr_tile_index_reg  : out unsigned(clog2(N_TILE)-1 downto 0);
    o_writing_tile_index      : out unsigned(clog2(N_TILE)-1 downto 0);

    -- Debug/visibility.
    o_state                   : out std_logic_vector(2 downto 0)
  );
end entity opq_frame_table_mapper;

architecture rtl of opq_frame_table_mapper is
  constant PAGE_RAM_ADDR_WIDTH : natural := clog2(PAGE_RAM_DEPTH);
  constant TILE_ID_WIDTH       : natural := clog2(N_TILE);

  subtype page_addr_t is unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
  subtype tile_id_t  is unsigned(TILE_ID_WIDTH-1 downto 0);

  type ftable_mapper_state_t is (IDLE, PREP_UPDATE, UPDATE_FRAME_TABLE, MODIFY_FRAME_TABLE, RESET);
  signal state : ftable_mapper_state_t := RESET;

  -- Core registers (mirrors the monolithic mapper).
  signal new_frame_raw_addr   : page_addr_t := (others => '0');
  signal frame_shr_cnt        : unsigned(SHD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal frame_hit_cnt        : unsigned(HIT_CNT_WIDTH-1 downto 0) := (others => '0');

  signal wseg                 : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal wseg_last_tile_pipe  : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal last_pkt_expand_tile_pipe : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal last_pkt_spill_pipe       : std_logic_vector(0 to 1) := (others => '0');

  signal leading_wseg_reg     : natural range 0 to N_WR_SEG-1 := 0;
  signal update_ftable_spill_reg : std_logic := '0';
  signal update_ftable_fspan_reg : page_addr_t := (others => '0');
  signal leading_wr_tile_index_reg : tile_id_t := (others => '0');
  signal expand_wr_tile_index_reg  : tile_id_t := (others => '0');
  signal expand_wr_tile_index_reg0 : natural range 0 to N_TILE-1 := 0;

  signal rd_tile_in_wr_seg    : natural range 0 to N_WR_SEG-1 := 0;

  -- Pending pkt finalize (after tail + movers drain).
  signal pending_pkt_valid    : std_logic := '0';
  signal pending_pkt_tindex   : tile_id_t := (others => '0');
  signal pending_pkt_meta     : std_logic_vector(2*PAGE_RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal pending_pkt_drop     : std_logic := '0';
  signal pending_pkt_handle_wptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0) := (others => (others => '0'));

  -- The page RAM write port is registered by the B2P arbiter (1-cycle latency). Some allocator
  -- qualifiers (WRITE_TAIL active) must be delayed to line up with `i_page_ram_we/i_page_ram_wr_addr`
  -- to correctly route previous-frame tail/trailer words.
  signal pa_write_tail_active_q     : std_logic := '0';
  signal pa_frame_start_addr_q      : page_addr_t := (others => '0');
  signal pa_frame_start_addr_last_q : page_addr_t := (others => '0');

  -- Comb outputs.
  signal update_ftable_fspan    : page_addr_t;
  signal update_ftable_spill    : std_logic;
  signal update_ftable_trail_span : page_addr_t;
  signal leading_wr_seg_index_c : natural range 0 to N_WR_SEG-1;
  signal leading_wr_tile_index_c : tile_id_t;
  signal expand_wr_tile_index_0  : natural range 0 to N_TILE-1;
  signal expand_wr_tile_index_c  : tile_id_t;
  signal writing_tile_index_c    : tile_id_t;

  -- Outputs (registered ones).
  signal update_ftable_valid_r      : std_logic_vector(1 downto 0) := (others => '0');
  signal update_ftable_tindex_r     : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal update_ftable_meta_valid_r : std_logic_vector(1 downto 0) := (others => '0');
  signal update_ftable_meta_r       : slv_array_t(0 to 1)(2*PAGE_RAM_ADDR_WIDTH-1 downto 0) := (others => (others => '0'));
  signal update_ftable_trltl_valid_r : std_logic_vector(1 downto 0) := (others => '0');
  signal update_ftable_trltl_r      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal update_ftable_bdytl_valid_r : std_logic_vector(1 downto 0) := (others => '0');
  signal update_ftable_bdytl_r      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0) := (others => (others => '0'));
  signal update_ftable_hcmpl_r      : std_logic_vector(1 downto 0) := (others => '0');
  signal flush_ftable_valid_r       : std_logic_vector(1 downto 0) := (others => '0');
begin
  -- Outputs.
  o_update_ftable_valid      <= update_ftable_valid_r;
  o_update_ftable_tindex     <= update_ftable_tindex_r;
  o_update_ftable_meta_valid <= update_ftable_meta_valid_r;
  o_update_ftable_meta       <= update_ftable_meta_r;
  o_update_ftable_trltl_valid <= update_ftable_trltl_valid_r;
  o_update_ftable_trltl      <= update_ftable_trltl_r;
  o_update_ftable_bdytl_valid <= update_ftable_bdytl_valid_r;
  o_update_ftable_bdytl      <= update_ftable_bdytl_r;
  o_update_ftable_hcmpl      <= update_ftable_hcmpl_r;
  o_flush_ftable_valid       <= flush_ftable_valid_r;

  o_wseg_tile_index          <= wseg;
  o_leading_wr_tile_index_reg <= leading_wr_tile_index_reg;
  o_expand_wr_tile_index_reg  <= expand_wr_tile_index_reg;
  o_writing_tile_index       <= writing_tile_index_c;

  -- Debug: state encoding.
  with state select o_state <=
    "000" when IDLE,
    "001" when PREP_UPDATE,
    "010" when UPDATE_FRAME_TABLE,
    "011" when MODIFY_FRAME_TABLE,
    "100" when RESET,
    "111" when others;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_MAPPER.REG
  -- @brief           Mapper state machine: compute wseg->tile mapping and emit tracker update/flush pulses
  -- @input           allocator events/counters, presenter lock/warp context, i_page_ram_wr_addr
  -- @output          o_update_ftable_*, o_flush_ftable_valid, o_wseg_tile_index, o_writing_tile_index
  -- @description     Ensures overwrites do not corrupt a tile currently being read by the presenter. When
  --                  contention is detected, packets may be sacrificed (dropped/overwritten) to guarantee
  --                  egress packet integrity (no broken/merged packets).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_frame_table_mapper : process (i_clk) is
    variable next_wr_tile_i : natural range 0 to N_TILE-1;
    variable movers_done_v  : boolean;
  begin
    if rising_edge(i_clk) then
      -- defaults (one-cycle pulses)
      update_ftable_valid_r       <= (others => '0');
      update_ftable_meta_valid_r  <= (others => '0');
      update_ftable_trltl_valid_r <= (others => '0');
      update_ftable_bdytl_valid_r <= (others => '0');
      flush_ftable_valid_r        <= (others => '0');
      update_ftable_hcmpl_r       <= (others => '0');

      -- Align allocator qualifiers with the registered page RAM write port.
      pa_write_tail_active_q     <= i_pa_write_tail_active;
      pa_frame_start_addr_q      <= i_pa_frame_start_addr;
      pa_frame_start_addr_last_q <= i_pa_frame_start_addr_last;

      case state is
        when IDLE =>
          if i_pa_write_head_start = '1' then
            new_frame_raw_addr <= i_pa_frame_start_addr;
            frame_shr_cnt <= i_pa_frame_shr_cnt_this / to_unsigned(N_LANE, frame_shr_cnt'length);
            frame_hit_cnt <= i_pa_frame_hit_cnt_this;
            state <= PREP_UPDATE;
            expand_wr_tile_index_reg0 <= expand_wr_tile_index_0;
          elsif pending_pkt_valid = '1' then
            -- Finalize a completed frame when movers drained and the allocator is done with WRITE_TAIL.
            -- NOTE: This is intentionally handled in IDLE so mapper head updates (i_pa_write_head_start)
            -- are never blocked by a slow mover/finalize path (prevents mis-mapping under high load).
            movers_done_v := true;
            for i in 0 to N_LANE-1 loop
              if i_bm_handle_rptr(i) /= pending_pkt_handle_wptr(i) then
                movers_done_v := false;
              end if;
            end loop;

            if (i_pa_write_tail_active = '0') and movers_done_v then
              if (pending_pkt_drop = '1') or (i_pa_frame_invalid_last = '1') then
                -- Drop: do not enqueue meta for the packet. The split mapper only enqueues meta at
                -- tail-done, so a dropped packet has no new FIFO entry to remove. Flushing here can
                -- race the presenter (tile_wptr reset while reading) and lead to meta replay.
                null;
              else
                -- Normal: enqueue meta for the completed frame.
                update_ftable_valid_r(0)      <= '1';
                update_ftable_tindex_r(0)     <= pending_pkt_tindex;
                update_ftable_meta_valid_r(0) <= '1';
                update_ftable_meta_r(0)       <= pending_pkt_meta;
                update_ftable_hcmpl_r(0)      <= '1';
              end if;

              pending_pkt_valid <= '0';
              pending_pkt_drop  <= '0';

              -- If the read side is actively holding the current write tile, advance the write window
              -- to the next available tile (sacrificing unread contents via flush).
              if (i_presenter_active = '1') and (i_presenter_rseg_tile_index = leading_wr_tile_index_c) then
                next_wr_tile_i := (to_integer(leading_wr_tile_index_c) + 1) mod N_TILE;
                if next_wr_tile_i = to_integer(i_presenter_rseg_tile_index) then
                  next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                end if;
                if i_presenter_crossing_tile_valid = '1' then
                  if next_wr_tile_i = to_integer(i_presenter_crossing_tile) then
                    next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                  end if;
                end if;

                -- synthesis translate_off
                if DEBUG_LV >= 2 then
                  report "FTABLE_MAPPER: rd holds wr tile -> advance wr window"
                         & " lead=" & integer'image(to_integer(leading_wr_tile_index_c))
                         & " rseg=" & integer'image(to_integer(i_presenter_rseg_tile_index))
                         & " cross_v=" & std_logic'image(i_presenter_crossing_tile_valid)
                         & " cross=" & integer'image(to_integer(i_presenter_crossing_tile))
                         & " next=" & integer'image(next_wr_tile_i)
                         severity note;
                end if;
                -- synthesis translate_on

                flush_ftable_valid_r(1)   <= '1';
                update_ftable_tindex_r(1) <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);

                for i in 0 to N_WR_SEG-2 loop
                  wseg(i) <= wseg(i+1);
                end loop;
                wseg(N_WR_SEG-1) <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);
              end if;
            end if;

          elsif i_pa_write_tail_done = '1' then
            -- Latch the completion info; it will be committed once movers drained.
            if pending_pkt_valid = '0' then
              pending_pkt_valid <= '1';
              pending_pkt_tindex <= wseg_last_tile_pipe(1);
              pending_pkt_meta <= std_logic_vector(resize(
                                 resize(i_pa_frame_shr_cnt * to_unsigned(SHD_SIZE, i_pa_frame_shr_cnt'length), PAGE_RAM_ADDR_WIDTH)
                               + resize(i_pa_frame_hit_cnt * to_unsigned(HIT_SIZE, i_pa_frame_hit_cnt'length), PAGE_RAM_ADDR_WIDTH)
                               + to_unsigned(HDR_SIZE + TRL_SIZE, PAGE_RAM_ADDR_WIDTH),
                                 PAGE_RAM_ADDR_WIDTH
                               )) & std_logic_vector(i_pa_frame_start_addr_last);
              pending_pkt_drop <= i_pa_frame_invalid_last;
              pending_pkt_handle_wptr <= i_pa_handle_wptr;
            end if;
          end if;

        when PREP_UPDATE =>
          if i_presenter_warping = '0' then
            state <= UPDATE_FRAME_TABLE;
          end if;
          update_ftable_spill_reg <= update_ftable_spill;
          leading_wseg_reg <= leading_wr_seg_index_c;
          leading_wr_tile_index_reg <= leading_wr_tile_index_c;
          expand_wr_tile_index_reg <= expand_wr_tile_index_c;
          update_ftable_fspan_reg <= update_ftable_fspan;

        when UPDATE_FRAME_TABLE =>
          if update_ftable_spill_reg = '1' then
            -- a) spill/overflow frame: may touch two tiles.
            if leading_wseg_reg < N_WR_SEG-1 then
              -- still space in the WR head: expand remaining segments onto the expanding tile.
              for i in 0 to N_WR_SEG-1 loop
                if i > leading_wseg_reg then
                  wseg(i) <= expand_wr_tile_index_reg;
                end if;
              end loop;
            else
              -- WR segs fully expanded: scroll (and optionally shrink-scroll when rd locks two tiles).
              if i_presenter_crossing_tile_valid = '1' then
                for i in 0 to N_WR_SEG-3 loop
                  wseg(i) <= wseg(i+1);
                end loop;
                for i in N_WR_SEG-2 to N_WR_SEG-1 loop
                  wseg(i) <= wseg(0);
                end loop;
              else
                for i in 0 to N_WR_SEG-2 loop
                  wseg(i) <= wseg(i+1);
                end loop;
                wseg(N_WR_SEG-1) <= expand_wr_tile_index_reg;
              end if;
            end if;

            -- Two update commands: head tile and spill tile.
            update_ftable_valid_r       <= "11";
            update_ftable_tindex_r(0)   <= leading_wr_tile_index_reg;
            update_ftable_trltl_valid_r(0) <= '1';
            update_ftable_trltl_r(0)    <= expand_wr_tile_index_reg;

            update_ftable_tindex_r(1)   <= expand_wr_tile_index_reg;
            update_ftable_bdytl_valid_r(1) <= '1';
            update_ftable_bdytl_r(1)    <= leading_wr_tile_index_reg;
            flush_ftable_valid_r(1)     <= '1';
          end if;

          -- Record the tile of this packet (used when tail later finalizes).
          wseg_last_tile_pipe(0) <= leading_wr_tile_index_reg;
          wseg_last_tile_pipe(1) <= wseg_last_tile_pipe(0);
          last_pkt_expand_tile_pipe(0) <= expand_wr_tile_index_reg;
          last_pkt_expand_tile_pipe(1) <= last_pkt_expand_tile_pipe(0);
          last_pkt_spill_pipe(0) <= update_ftable_spill_reg;
          last_pkt_spill_pipe(1) <= last_pkt_spill_pipe(0);
          state <= IDLE;

        when MODIFY_FRAME_TABLE =>
          if pending_pkt_valid = '1' then
            movers_done_v := true;
            for i in 0 to N_LANE-1 loop
              if i_bm_handle_rptr(i) /= pending_pkt_handle_wptr(i) then
                movers_done_v := false;
              end if;
            end loop;

            if (i_pa_write_tail_active = '0') and movers_done_v then
              state <= IDLE;
              if (pending_pkt_drop = '1') or (i_pa_frame_invalid_last = '1') then
                -- Drop: do not enqueue meta for the packet. Avoid flushing to prevent rseg races.
                null;
              else
                -- Normal: enqueue meta for the completed frame.
                update_ftable_valid_r(0)      <= '1';
                update_ftable_tindex_r(0)     <= pending_pkt_tindex;
                update_ftable_meta_valid_r(0) <= '1';
                update_ftable_meta_r(0)       <= pending_pkt_meta;
                update_ftable_hcmpl_r(0)      <= '1';
              end if;

              pending_pkt_valid <= '0';
              pending_pkt_drop  <= '0';

              -- If the read side is actively holding the current write tile, advance the write window
              -- to the next available tile (sacrificing unread contents via flush).
              if (i_presenter_active = '1') and (i_presenter_rseg_tile_index = leading_wr_tile_index_c) then
                next_wr_tile_i := (to_integer(leading_wr_tile_index_c) + 1) mod N_TILE;
                if next_wr_tile_i = to_integer(i_presenter_rseg_tile_index) then
                  next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                end if;
                if i_presenter_crossing_tile_valid = '1' then
                  if next_wr_tile_i = to_integer(i_presenter_crossing_tile) then
                    next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                  end if;
                end if;

                -- synthesis translate_off
                if DEBUG_LV >= 2 then
                  report "FTABLE_MAPPER: (MODIFY) rd holds wr tile -> advance wr window"
                         & " lead=" & integer'image(to_integer(leading_wr_tile_index_c))
                         & " rseg=" & integer'image(to_integer(i_presenter_rseg_tile_index))
                         & " cross_v=" & std_logic'image(i_presenter_crossing_tile_valid)
                         & " cross=" & integer'image(to_integer(i_presenter_crossing_tile))
                         & " next=" & integer'image(next_wr_tile_i)
                         severity note;
                end if;
                -- synthesis translate_on

                flush_ftable_valid_r(1)   <= '1';
                update_ftable_tindex_r(1) <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);

                for i in 0 to N_WR_SEG-2 loop
                  wseg(i) <= wseg(i+1);
                end loop;
                wseg(N_WR_SEG-1) <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);
              end if;
            end if;
          else
            state <= IDLE;
          end if;

        when RESET =>
          -- Initialize write segments away from read segment (rseg=0).
          for i in 0 to N_WR_SEG-1 loop
            wseg(i) <= to_unsigned((i + 1) mod N_TILE, TILE_ID_WIDTH);
          end loop;
          wseg_last_tile_pipe <= (others => (others => '0'));
          last_pkt_expand_tile_pipe <= (others => (others => '0'));
          last_pkt_spill_pipe       <= (others => '0');

          leading_wseg_reg <= 0;
          new_frame_raw_addr <= (others => '0');
          frame_shr_cnt <= (others => '0');
          frame_hit_cnt <= (others => '0');

          leading_wr_tile_index_reg <= to_unsigned(N_TILE-1, TILE_ID_WIDTH);
          expand_wr_tile_index_reg <= (others => '0');
          expand_wr_tile_index_reg0 <= 0;
          update_ftable_fspan_reg <= (others => '0');
          update_ftable_spill_reg <= '0';

          pending_pkt_valid <= '0';
          pending_pkt_tindex <= (others => '0');
          pending_pkt_meta <= (others => '0');
          pending_pkt_drop <= '0';
          pending_pkt_handle_wptr <= (others => (others => '0'));

          state <= IDLE;

        when others =>
          null;
      end case;

      -- Read-side warp can shrink the write window.
      if i_presenter_warping = '1' then
        if i_presenter_rd_tile_in_range = '1' then
          if rd_tile_in_wr_seg > 0 then
            for i in 0 to N_WR_SEG-2 loop
              wseg(i) <= wseg(i+1);
            end loop;
          end if;
        end if;
      end if;

      if i_rst = '1' then
        pa_write_tail_active_q     <= '0';
        pa_frame_start_addr_q      <= (others => '0');
        pa_frame_start_addr_last_q <= (others => '0');
        state <= RESET;
      end if;
    end if;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_MAPPER.COMB
  -- @brief           Comb computations for spill detection, expected next tile, and read-lock blocking
  -- @input           new_frame_raw_addr, frame_shr_cnt, frame_hit_cnt, i_presenter_*, wseg
  -- @output          update_ftable_* comb terms and tile index helpers
  -- @description     This logic mirrors the monolithic “wseg/tile window” behavior:
  --                  - leading WR tile is the newest/active segment (last change in `wseg`)
  --                  - expand tile is (leading+1) mod N_TILE, with skip over the read-locked tile(s)
  --                    (rseg + spill crossing tile)
  --                  Note: seeing the window advance to tile 0 is normal wrap-around when
  --                  leading tile is N_TILE-1.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_frame_table_mapper_comb : process (all) is
    variable leading_wr_seg_index_v      : natural range 0 to N_WR_SEG-1;
    variable leading_wr_tile_index_v     : natural range 0 to N_TILE-1;
    variable leading_wr_tile_index_c_v  : tile_id_t;
    variable expected_new_wr_tile_index  : natural range 0 to N_TILE-1;
    variable expected_new_wr_tile_index_rd : natural range 0 to N_TILE-1;
    variable rd_tile_in_wr_seg_v         : natural range 0 to N_WR_SEG-1;
    variable fspan_v                     : page_addr_t;
    variable prev_tail_w3_addr           : page_addr_t;
    variable prev_tail_w4_addr           : page_addr_t;
    variable prev_trailer_addr           : page_addr_t;
    variable is_prev_meta_write_v        : boolean;
    variable prev_write_tile_index_v     : tile_id_t;
    variable curr_raw_addr_v             : page_addr_t;
    variable curr_leading_tile_v         : tile_id_t;
    variable curr_expand_tile_v          : tile_id_t;
    variable expand_wr_tile_index_c_v    : tile_id_t;
    variable span_sum_v                  : unsigned(PAGE_RAM_ADDR_WIDTH downto 0);
  begin
    -- Frame span estimation (in page words).
    fspan_v := resize(
                resize(frame_shr_cnt * to_unsigned(SHD_SIZE, frame_shr_cnt'length), PAGE_RAM_ADDR_WIDTH)
              + resize(frame_hit_cnt * to_unsigned(HIT_SIZE, frame_hit_cnt'length), PAGE_RAM_ADDR_WIDTH)
              + to_unsigned(HDR_SIZE + TRL_SIZE, PAGE_RAM_ADDR_WIDTH),
              PAGE_RAM_ADDR_WIDTH
            );
    update_ftable_fspan <= fspan_v;

    span_sum_v := resize(new_frame_raw_addr, span_sum_v'length) + resize(fspan_v, span_sum_v'length);
    if (span_sum_v > to_unsigned(PAGE_RAM_DEPTH, span_sum_v'length)) then
      update_ftable_spill <= '1';
      update_ftable_trail_span <= resize(span_sum_v - to_unsigned(PAGE_RAM_DEPTH, span_sum_v'length), PAGE_RAM_ADDR_WIDTH);
    else
      update_ftable_spill <= '0';
      update_ftable_trail_span <= (others => '0');
    end if;

    -- Leading WR segment = last position where the tile changes (newest/active).
    leading_wr_seg_index_v := 0;
    for i in 0 to N_WR_SEG-2 loop
      if wseg(i+1) /= wseg(i) then
        leading_wr_seg_index_v := i + 1;
      end if;
    end loop;
    leading_wr_seg_index_c <= leading_wr_seg_index_v;

    leading_wr_tile_index_c_v := wseg(leading_wr_seg_index_v);
    leading_wr_tile_index_c <= leading_wr_tile_index_c_v;
    leading_wr_tile_index_v := to_integer(wseg(leading_wr_seg_index_v));

    expected_new_wr_tile_index := (leading_wr_tile_index_v + 1) mod N_TILE;
    expand_wr_tile_index_0 <= expected_new_wr_tile_index;

    -- Expand tile index: skip read-locked tile(s) using the pipelined expected index.
    expected_new_wr_tile_index_rd := expand_wr_tile_index_reg0;
    if (state = IDLE) and (i_pa_write_head_start = '1') then
      -- During the WRITE_HEAD start cycle, expand_wr_tile_index_reg0 has not been updated yet.
      -- Use the combinational expected tile directly.
      expected_new_wr_tile_index_rd := expected_new_wr_tile_index;
    end if;
    if expected_new_wr_tile_index_rd = to_integer(i_presenter_rseg_tile_index) then
      expected_new_wr_tile_index_rd := (expected_new_wr_tile_index_rd + 1) mod N_TILE;
    end if;
    if i_presenter_crossing_tile_valid = '1' then
      if expected_new_wr_tile_index_rd = to_integer(i_presenter_crossing_tile) then
        expected_new_wr_tile_index_rd := (expected_new_wr_tile_index_rd + 1) mod N_TILE;
      end if;
    end if;
    expand_wr_tile_index_c_v := to_unsigned(expected_new_wr_tile_index_rd, TILE_ID_WIDTH);
    expand_wr_tile_index_c <= expand_wr_tile_index_c_v;

    -- Read tile position within WR segs.
    rd_tile_in_wr_seg_v := 0;
    for i in N_WR_SEG-1 downto 0 loop
      if wseg(i) = i_presenter_rseg_tile_index then
        rd_tile_in_wr_seg_v := i;
      end if;
    end loop;
    rd_tile_in_wr_seg <= rd_tile_in_wr_seg_v;

    -- Current write tile selection for page RAM writes.
    prev_tail_w3_addr := resize(pa_frame_start_addr_last_q + to_unsigned(3, pa_frame_start_addr_last_q'length), PAGE_RAM_ADDR_WIDTH);
    prev_tail_w4_addr := resize(pa_frame_start_addr_last_q + to_unsigned(4, pa_frame_start_addr_last_q'length), PAGE_RAM_ADDR_WIDTH);
    prev_trailer_addr := resize(pa_frame_start_addr_q - to_unsigned(1, pa_frame_start_addr_q'length), PAGE_RAM_ADDR_WIDTH);

    -- Guard the "previous meta write" special-case so it only applies during the allocator WRITE_TAIL
    -- stage. Without this, normal payload writes that happen to hit these addresses (e.g. early packets
    -- at address 0..4 in simplified/UVM models) would be misrouted into the previous-packet tile.
    is_prev_meta_write_v := (i_page_ram_we = '1')
                            and (pa_write_tail_active_q = '1')
                            and ((i_page_ram_wr_addr = prev_tail_w3_addr)
                                 or (i_page_ram_wr_addr = prev_tail_w4_addr)
                                 or (i_page_ram_wr_addr = prev_trailer_addr));

    -- Previous-frame meta writes (tail/trailer) must use the previous packet's spill mapping, not the
    -- current packet's spill mapping (mirrors monolithic last_pkt_dbg_tile_index behavior).
    if last_pkt_spill_pipe(1) = '1' then
      if i_page_ram_wr_addr >= i_pa_frame_start_addr_last then
        prev_write_tile_index_v := wseg_last_tile_pipe(1);
      else
        prev_write_tile_index_v := last_pkt_expand_tile_pipe(1);
      end if;
    else
      prev_write_tile_index_v := wseg_last_tile_pipe(1);
    end if;

    if is_prev_meta_write_v then
      writing_tile_index_c <= prev_write_tile_index_v;
    else
      -- Current-frame writes: select between leading/expand tiles based on address wrap relative to the
      -- current frame start address. Use combinational tile indices during PREP_UPDATE to avoid the
      -- 1-cycle register lag (matches monolithic PREP_UPDATE glitch avoidance).
      if (state = PREP_UPDATE) or ((state = IDLE) and (i_pa_write_head_start = '1')) then
        curr_raw_addr_v := new_frame_raw_addr;
        if (state = IDLE) and (i_pa_write_head_start = '1') then
          curr_raw_addr_v := i_pa_frame_start_addr;
        end if;
        curr_leading_tile_v := leading_wr_tile_index_c_v;
        curr_expand_tile_v  := expand_wr_tile_index_c_v;
      else
        curr_raw_addr_v := new_frame_raw_addr;
        curr_leading_tile_v := leading_wr_tile_index_reg;
        curr_expand_tile_v  := expand_wr_tile_index_reg;
      end if;

      if i_page_ram_wr_addr >= curr_raw_addr_v then
        writing_tile_index_c <= curr_leading_tile_v;
      else
        writing_tile_index_c <= curr_expand_tile_v;
      end if;
    end if;
  end process;
end architecture rtl;

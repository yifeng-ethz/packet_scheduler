-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_frame_table_presenter
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Presenter that reads tile FIFO meta + tiled page RAM to emit complete packets on the
--                      egress stream. Provides read-lock/warp status for safe overwrite handling.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

entity opq_frame_table_presenter is
  generic (
    N_TILE            : positive := 5;
    N_WR_SEG          : positive := 4;
    TILE_FIFO_DEPTH   : positive := 512;
    PAGE_RAM_DEPTH    : positive := 65536;
    PAGE_RAM_DATA_WIDTH : positive := 40;
    TILE_PKT_CNT_WIDTH : positive := 10;
    EGRESS_DELAY      : natural := 2;

    -- Debug: 0=off, 1=basic, 2=verbose (simulation diagnostics only).
    DEBUG_LV          : natural := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Mapper context (warp + spill avoidance).
    i_wseg_tile_index           : in  unsigned_array_t(0 to N_WR_SEG-1)(clog2(N_TILE)-1 downto 0);
    i_leading_wr_tile_index_reg : in  unsigned(clog2(N_TILE)-1 downto 0);
    i_mapper_busy               : in  std_logic;
    i_pa_write_head_start       : in  std_logic;

    -- Tracker-provided counters + spill links.
    i_tile_wptr     : in  unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    i_tile_pkt_wcnt : in  unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    i_trail_tid     : in  unsigned_array_t(0 to N_TILE-1)(clog2(N_TILE) downto 0); -- msb valid
    i_body_tid      : in  unsigned_array_t(0 to N_TILE-1)(clog2(N_TILE) downto 0); -- msb lock/valid

    -- Tile FIFO read data (meta = {length, header_addr}).
    i_tile_fifo_rd_data : in  slv_array_t(0 to N_TILE-1)(2*clog2(PAGE_RAM_DEPTH)-1 downto 0);

    -- Page tile read data (one per tile).
    i_page_tile_rd_data : in  slv_array_t(0 to N_TILE-1)(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- Egress handshake.
    i_egress_ready : in  std_logic;

    -- RAM read addresses.
    o_tile_fifo_rd_addr : out slv_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_page_tile_rd_addr : out slv_array_t(0 to N_TILE-1)(clog2(PAGE_RAM_DEPTH)-1 downto 0);

    -- Presenter-maintained pointers/counters (fed back into tracker).
    o_tile_rptr       : out unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    o_tile_pkt_rcnt   : out unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    o_rseg_tile_index : out unsigned(clog2(N_TILE)-1 downto 0);
    o_void_trail_tid  : out std_logic;
    o_void_body_tid   : out std_logic;

    -- Status to mapper/top.
    o_presenter_active     : out std_logic;
    o_presenter_warping    : out std_logic;
    o_is_rd_tile_in_range  : out std_logic;
    o_crossing_tile_valid  : out std_logic;
    o_crossing_tile        : out unsigned(clog2(N_TILE)-1 downto 0);
    o_trailing_active0     : out std_logic;
    o_trailing_tile_index  : out unsigned(clog2(N_TILE)-1 downto 0);
    o_state                : out std_logic_vector(2 downto 0);

    -- Egress data stream.
    o_egress_valid         : out std_logic;
    o_egress_data          : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    o_egress_startofpacket : out std_logic;
    o_egress_endofpacket   : out std_logic
  );
end entity opq_frame_table_presenter;

architecture rtl of opq_frame_table_presenter is
  constant TILE_ID_W        : natural := clog2(N_TILE);
  constant TILE_FIFO_ADDR_W : natural := clog2(TILE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_W  : natural := clog2(PAGE_RAM_DEPTH);

  constant K285 : std_logic_vector(7 downto 0) := "10111100"; -- 0xBC
  constant K284 : std_logic_vector(7 downto 0) := "10011100"; -- 0x9C

  type presenter_state_t is (
    IDLE,
    WAIT_FOR_COMPLETE,
    VERIFY,
    PRESENTING,
    RESTART, -- unused (kept for state-code compatibility)
    WARPING,
    RESET
  );

  signal state : presenter_state_t := RESET;

  -- Tile FIFO meta pointers + completed-packet counters.
  signal tile_rptr     : unsigned_array_t(0 to N_TILE-1)(TILE_FIFO_ADDR_W-1 downto 0) := (others => (others => '0'));
  signal tile_pkt_rcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => '0'));

  -- Read-segment tile index.
  signal rseg_tile_index : unsigned(TILE_ID_W-1 downto 0) := (others => '0');

  -- Page RAM read pointers per tile (only one tile advances at a time).
  signal page_ram_rptr : unsigned_array_t(0 to N_TILE-1)(PAGE_RAM_ADDR_W-1 downto 0) := (others => (others => '0'));

  -- Latched meta of the current head packet (from tile FIFO).
  signal leading_header_addr : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');
  signal packet_length       : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');

  -- Spill tracking.
  signal crossing_tile_valid : std_logic := '0';
  signal crossing_tile       : unsigned(TILE_ID_W-1 downto 0) := (others => '0');
  signal trailing_active     : std_logic_vector(EGRESS_DELAY downto 0) := (others => '0');
  signal trailing_tile_index : unsigned(TILE_ID_W-1 downto 0) := (others => '0');

  -- Output pipeline (valid only; data is held in `output_data`).
  signal output_data_valid : std_logic_vector(EGRESS_DELAY downto 0) := (others => '0');
  signal output_data       : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');
  signal pkt_rd_word_cnt   : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');

  -- Registered view of page RAM data (held stable under backpressure).
  signal page_tile_rd_data_reg : slv_array_t(0 to N_TILE-1)(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => (others => '0'));

  -- Backpressure skid capture (one extra stage to preserve the RAM q word across long stalls).
  signal page_tile_rd_data_skid : slv_array_t(0 to N_TILE-1)(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => (others => '0'));
  signal page_tile_skid_valid   : std_logic := '0';


  -- Combinational helpers.
  signal is_new_pkt_head     : std_logic;
  signal is_new_pkt_complete : std_logic;
  signal is_rd_tile_in_range : std_logic;
  signal in_range_warp_rd_tile : unsigned(TILE_ID_W-1 downto 0);
  signal is_pkt_spilling     : std_logic;
  signal output_is_trailer   : std_logic;
  signal page_ram_rd_data    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

  signal void_trail_tid : std_logic := '0';
  signal void_body_tid  : std_logic := '0';

begin
  -- Outputs.
  o_tile_rptr <= tile_rptr;
  o_tile_pkt_rcnt <= tile_pkt_rcnt;
  o_rseg_tile_index <= rseg_tile_index;
  o_void_trail_tid <= void_trail_tid;
  o_void_body_tid <= void_body_tid;
  o_crossing_tile_valid <= crossing_tile_valid;
  o_crossing_tile <= crossing_tile;
  o_trailing_active0 <= trailing_active(0);
  o_trailing_tile_index <= trailing_tile_index;

  o_presenter_warping <= '1' when state = WARPING else '0';
  -- Read-lock indicator:
  -- Assert only when the presenter is actively consuming page RAM (PRESENTING/RESTART), plus the
  -- cycle(s) where a head packet is already complete and we are about to enter PRESENTING. This
  -- avoids blocking writes while we are still waiting for the write side to finish the packet.
  o_presenter_active <= '1' when (state = PRESENTING)
                             or (state = RESTART)
                             or ((state = WAIT_FOR_COMPLETE) and (is_new_pkt_complete = '1'))
                        else '0';
  o_is_rd_tile_in_range <= is_rd_tile_in_range;

  -- State encoding (keep "011" PRESENTING and "100" RESTART for top-level lock guards).
  with state select o_state <=
    "000" when IDLE,
    "001" when WAIT_FOR_COMPLETE,
    "010" when VERIFY,
    "011" when PRESENTING,
    "100" when RESTART,
    "101" when WARPING,
    "110" when RESET,
    "111" when others;

  -- Egress valid mirrors the monolithic OPQ: a pure function of the internal pipeline.
  -- (Non-presenting states keep `output_data_valid` cleared or hold under backpressure.)
  o_egress_valid <= output_data_valid(EGRESS_DELAY);
  o_egress_data  <= output_data;
  o_egress_startofpacket <= '1' when (o_egress_valid = '1')
                                  and (output_data(35 downto 32) = "0001")
                                  and (output_data(7 downto 0) = K285)
                           else '0';
  o_egress_endofpacket <= '1' when (o_egress_valid = '1')
                                and (output_data(35 downto 32) = "0001")
                                and (output_data(7 downto 0) = K284)
                         else '0';

  output_is_trailer <= o_egress_endofpacket;

  -- Tile FIFO read addresses are simply the presenter-maintained rptrs.
  gen_tile_fifo_rd_addr : for i in 0 to N_TILE-1 generate
    o_tile_fifo_rd_addr(i) <= std_logic_vector(tile_rptr(i));
  end generate;

  -- Drive page RAM read addresses from per-tile rptrs.
  gen_page_tile_rd_addr : for i in 0 to N_TILE-1 generate
    o_page_tile_rd_addr(i) <= std_logic_vector(page_ram_rptr(i));
  end generate;

  -- Select page RAM read data (normal rseg vs. trailing spill tile), aligned with the egress tap.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_PRESENTER.PAGE_RD_COMB
  -- @brief           Select active tile page data (normal rseg vs trailing spill), aligned with egress tap
  -- @input           rseg_tile_index, trailing_active/trailing_tile_index, page_tile_rd_data_reg
  -- @output          page_ram_rd_data
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_page_ram_rd_data : process (all) is
    variable sel_idx : natural range 0 to N_TILE-1;
  begin
    if trailing_active(EGRESS_DELAY) = '1' then
      sel_idx := to_integer(trailing_tile_index);
    else
      sel_idx := to_integer(rseg_tile_index);
    end if;
    page_ram_rd_data <= page_tile_rd_data_reg(sel_idx);
  end process;

  -- Combinational status flags (mirrors the monolithic design).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_PRESENTER.FLAGS_COMB
  -- @brief           Derive packet availability flags and warp/range helpers for the presenter+mapper
  -- @input           i_tile_wptr/i_tile_pkt_wcnt, tile_rptr/tile_pkt_rcnt, i_wseg_tile_index, rseg_tile_index
  -- @output          is_new_pkt_head/is_new_pkt_complete, is_rd_tile_in_range, in_range_warp_rd_tile
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_flags : process (all) is
    variable rseg_i : natural range 0 to N_TILE-1;
    variable warp_seg : natural range 0 to N_WR_SEG-1;
  begin
    rseg_i := to_integer(rseg_tile_index);

    -- New meta head present?
    if i_tile_wptr(rseg_i) /= tile_rptr(rseg_i) then
      is_new_pkt_head <= '1';
    else
      is_new_pkt_head <= '0';
    end if;

    -- Completed packet available?
    if i_tile_pkt_wcnt(rseg_i) /= tile_pkt_rcnt(rseg_i) then
      is_new_pkt_complete <= '1';
    else
      is_new_pkt_complete <= '0';
    end if;

    -- Is the current rseg tile within the write window segments?
    is_rd_tile_in_range <= '0';
    for s in 0 to N_WR_SEG-1 loop
      if i_wseg_tile_index(s) = rseg_tile_index then
        is_rd_tile_in_range <= '1';
      end if;
    end loop;

    -- If in range, warp to the next WR seg tile (matches monolithic "in-range warp" helper).
    warp_seg := 0;
    for s in N_WR_SEG-2 downto 0 loop
      if rseg_tile_index = i_wseg_tile_index(s) then
        warp_seg := s + 1;
      end if;
    end loop;
    in_range_warp_rd_tile <= i_wseg_tile_index(warp_seg);

    -- Spilling if header+length crosses the page boundary.
    if (to_integer(leading_header_addr) + to_integer(packet_length) >= PAGE_RAM_DEPTH) then
      is_pkt_spilling <= '1';
    else
      is_pkt_spilling <= '0';
    end if;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            FTABLE_PRESENTER.REG
  -- @brief           Presenter state machine: fetch meta, verify complete, and stream packet words to egress
  -- @input           is_new_pkt_head/is_new_pkt_complete, i_egress_ready, i_mapper_busy, i_pa_write_head_start
  -- @output          o_egress_*, tile_rptr/tile_pkt_rcnt, read-lock/warp indicators, o_void_* tid pulses
  -- @description     Holds output data stable under backpressure and only presents complete packets. Under
  --                  contention, may warp/void spill linkage to preserve packet integrity.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_presenter : process (i_clk) is
    variable any_tile_has_head : boolean;
    variable rseg_i            : natural range 0 to N_TILE-1;
    variable cross_i           : natural range 0 to N_TILE-1;
  begin
    if rising_edge(i_clk) then
      -- defaults (one-cycle pulses)
      void_trail_tid <= '0';
      void_body_tid  <= '0';

      -- Track whether any tile has queued meta (guards empty warps).
      any_tile_has_head := false;
      for t in 0 to N_TILE-1 loop
        if i_tile_wptr(t) /= tile_rptr(t) then
          any_tile_has_head := true;
        end if;
      end loop;

      rseg_i := to_integer(rseg_tile_index);

      -- NOTE: `i_tile_fifo_rd_data` comes from synchronous RAM and is already registered. To avoid
      -- using stale meta when `tile_rptr` advances, only latch `leading_header_addr/packet_length`
      -- at the moment we start presenting a packet (WAIT_FOR_COMPLETE -> PRESENTING/VERIFY).

      case state is
        when IDLE =>
          output_data_valid <= (others => '0');
          trailing_active(0) <= '0';
          crossing_tile_valid <= '0';

          if is_new_pkt_head = '1' then
            state <= WAIT_FOR_COMPLETE;
          elsif rseg_tile_index = i_leading_wr_tile_index_reg then
            -- Wait on the active write tile.
            null;
          else
            -- Warp only if there is work elsewhere, and this tile is empty.
            if any_tile_has_head and (is_new_pkt_head = '0') then
              if (i_mapper_busy = '0') and (i_pa_write_head_start = '0') then
                -- Free up the current rseg tile to become a write tile.
                tile_rptr(rseg_i)     <= i_tile_wptr(rseg_i);
                tile_pkt_rcnt(rseg_i) <= (others => '0');

                if is_rd_tile_in_range = '1' then
                  rseg_tile_index <= in_range_warp_rd_tile;
                else
                  rseg_tile_index <= i_wseg_tile_index(0);
                end if;
                state <= WARPING;
              end if;
            end if;
          end if;

        when WARPING =>
          state <= IDLE;

        when WAIT_FOR_COMPLETE =>
          if is_new_pkt_head = '0' then
            state <= IDLE;
          elsif is_new_pkt_complete = '1' then
            -- Latch the packet meta for the current head entry.
            leading_header_addr <= unsigned(i_tile_fifo_rd_data(rseg_i)(PAGE_RAM_ADDR_W-1 downto 0));
            packet_length       <= unsigned(i_tile_fifo_rd_data(rseg_i)(2*PAGE_RAM_ADDR_W-1 downto PAGE_RAM_ADDR_W));

            -- synthesis translate_off
            if DEBUG_LV >= 2 then
              report "FTABLE_PRESENTER: start packet"
                     & " t=" & time'image(now)
                     & " rseg=" & integer'image(to_integer(rseg_tile_index))
                     & " hdr_addr=" & integer'image(to_integer(unsigned(i_tile_fifo_rd_data(rseg_i)(PAGE_RAM_ADDR_W-1 downto 0))))
                     & " len=" & integer'image(to_integer(unsigned(i_tile_fifo_rd_data(rseg_i)(2*PAGE_RAM_ADDR_W-1 downto PAGE_RAM_ADDR_W))))
                     & " wptr=" & integer'image(to_integer(i_tile_wptr(rseg_i)))
                     & " rptr=" & integer'image(to_integer(tile_rptr(rseg_i)))
                     & " wcnt=" & integer'image(to_integer(i_tile_pkt_wcnt(rseg_i)))
                     & " rcnt=" & integer'image(to_integer(tile_pkt_rcnt(rseg_i)))
                     severity note;
            end if;
            -- synthesis translate_on

            -- Start presenting the packet (write side must respect rd locks; do not
            -- drop solely because this tile is also the leading write tile).
            page_ram_rptr(rseg_i) <= unsigned(i_tile_fifo_rd_data(rseg_i)(PAGE_RAM_ADDR_W-1 downto 0));
            pkt_rd_word_cnt       <= (others => '0');
            output_data_valid     <= (others => '0');
            trailing_active       <= (others => '0');
            crossing_tile_valid   <= '0';

            if (to_integer(unsigned(i_tile_fifo_rd_data(rseg_i)(PAGE_RAM_ADDR_W-1 downto 0)))
                + to_integer(unsigned(i_tile_fifo_rd_data(rseg_i)(2*PAGE_RAM_ADDR_W-1 downto PAGE_RAM_ADDR_W)))
                >= PAGE_RAM_DEPTH) then
              crossing_tile <= i_trail_tid(rseg_i)(TILE_ID_W-1 downto 0);
              state <= VERIFY;
            else
              state <= PRESENTING;
            end if;
          end if;

        when VERIFY =>
          -- Verify spill link. If broken, drop the head packet.
          cross_i := to_integer(crossing_tile);
          if i_body_tid(cross_i)(TILE_ID_W-1 downto 0) = rseg_tile_index then
            crossing_tile_valid <= '1';
            state <= PRESENTING;
          else
            -- synthesis translate_off
            if DEBUG_LV >= 2 then
              report "FTABLE_PRESENTER: spill link verify FAIL -> drop head"
                     & " t=" & time'image(now)
                     & " rseg=" & integer'image(to_integer(rseg_tile_index))
                     & " cross=" & integer'image(to_integer(crossing_tile))
                     & " body_tid[cross]=" & integer'image(to_integer(i_body_tid(cross_i)(TILE_ID_W-1 downto 0)))
                     severity note;
            end if;
            -- synthesis translate_on

            tile_pkt_rcnt(rseg_i) <= tile_pkt_rcnt(rseg_i) + 1;
            tile_rptr(rseg_i)     <= tile_rptr(rseg_i) + 1;
            crossing_tile_valid   <= '0';
            state <= IDLE;
          end if;

        when PRESENTING =>
          -- While the downstream is stalling a valid tap beat, do not restart/rollback; instead freeze the
          -- pipeline and capture the unfreezable RAM-q stage once (skid) so the next beat is not lost.
          if (output_data_valid(EGRESS_DELAY) = '1') and (i_egress_ready = '0') then
            if page_tile_skid_valid = '0' then
              page_tile_rd_data_skid <= i_page_tile_rd_data;
              page_tile_skid_valid   <= '1';
            end if;
          else
            -- Advance the internal pipeline (fill when tap not valid, or stream when ready=1).
            output_data_valid(0) <= '1';
            for d in 0 to EGRESS_DELAY-1 loop
              output_data_valid(d+1) <= output_data_valid(d);
            end loop;
            output_data <= page_ram_rd_data;

            -- Word count at egress tap (accepted beats).
            if (output_data_valid(EGRESS_DELAY) = '1') and (i_egress_ready = '1') then
              pkt_rd_word_cnt <= pkt_rd_word_cnt + 1;
            end if;

            -- Read pointer maintenance: advance the active read pointer while we are advancing the pipe.
            -- Important: the page RAM rptr runs ahead of the egress tap by the internal pipeline depth,
            -- so the end-of-page spill switch must be scheduled based on the read pointer (not only on
            -- accepted beats), otherwise small head spans (start near PAGE_RAM_DEPTH-1) can miss the switch.
            if trailing_active(0) = '1' then
              page_ram_rptr(to_integer(trailing_tile_index)) <= page_ram_rptr(to_integer(trailing_tile_index)) + 1;
            else
              if (is_pkt_spilling = '1') and (to_integer(page_ram_rptr(rseg_i)) = PAGE_RAM_DEPTH-1) then
                trailing_active(0)  <= '1';
                trailing_tile_index <= crossing_tile;
                page_ram_rptr(rseg_i) <= (others => '0');
                page_ram_rptr(to_integer(crossing_tile)) <= (others => '0');
              else
                page_ram_rptr(rseg_i) <= page_ram_rptr(rseg_i) + 1;
              end if;
            end if;
          end if;

          -- Packet completion (trailer) and spill switch happen only on accepted beats.
          if (output_data_valid(EGRESS_DELAY) = '1') and (i_egress_ready = '1') then
            if output_is_trailer = '1' then
              state <= IDLE;
              output_data_valid <= (others => '0');

              if trailing_active(0) = '1' then
                trailing_active(0)    <= '0';
                void_body_tid         <= '1';
                crossing_tile_valid   <= '0';
              end if;

              -- If the mapper/tracker flushed this tile while the packet was in-flight,
              -- `i_tile_wptr` may have been reset to our current `tile_rptr`. In that case,
              -- do not increment again (would create a wrap mismatch and re-play stale meta).
                if i_tile_wptr(rseg_i) /= tile_rptr(rseg_i) then
                  tile_pkt_rcnt(rseg_i) <= tile_pkt_rcnt(rseg_i) + 1;
                  tile_rptr(rseg_i)     <= tile_rptr(rseg_i) + 1;
                end if;
            end if;
          end if;

        when RESTART =>
          -- Unused in the split presenter: backpressure is handled by freezing the pipeline in PRESENTING.
          state <= PRESENTING;

        when RESET =>
          state <= IDLE;
          tile_rptr          <= (others => (others => '0'));
          tile_pkt_rcnt      <= (others => (others => '0'));
          rseg_tile_index    <= (others => '0');
          page_ram_rptr      <= (others => (others => '0'));
          leading_header_addr <= (others => '0');
          packet_length      <= (others => '0');
          crossing_tile_valid <= '0';
          crossing_tile      <= (others => '0');
          trailing_active    <= (others => '0');
          trailing_tile_index <= (others => '0');
          output_data_valid  <= (others => '0');
          output_data        <= (others => '0');
          pkt_rd_word_cnt    <= (others => '0');
          page_tile_rd_data_reg <= (others => (others => '0'));
          page_tile_rd_data_skid <= (others => (others => '0'));
          page_tile_skid_valid    <= '0';

        when others =>
          null;
      end case;

      -- Keep the page RAM read-data pipeline aligned with egress backpressure.
      -- If a valid word is stalled at the egress (valid=1, ready=0), hold this stage too,
      -- otherwise the registered RAM output would overwrite in-flight words and cause duplicates.
      if (i_egress_ready = '1') or (output_data_valid(EGRESS_DELAY) = '0') then
        if page_tile_skid_valid = '1' then
          page_tile_rd_data_reg <= page_tile_rd_data_skid;
          page_tile_skid_valid  <= '0';
        else
          page_tile_rd_data_reg <= i_page_tile_rd_data;
        end if;
      end if;

      -- Keep trailing_active aligned with the output pipeline under backpressure.
      if (i_egress_ready = '1') or (output_data_valid(EGRESS_DELAY) = '0') then
        for d in 0 to EGRESS_DELAY-1 loop
          trailing_active(d+1) <= trailing_active(d);
        end loop;
      end if;

      if i_rst = '1' then
        state <= RESET;
      end if;
    end if;
  end process;
end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_frame_table is
end entity tb_opq_frame_table;

architecture tb of tb_opq_frame_table is
  constant N_LANE : positive := 2;
  constant N_TILE : positive := 5;
  constant N_WR_SEG : positive := 4;

  constant TILE_FIFO_DEPTH : positive := 8;
  constant PAGE_RAM_DEPTH  : positive := 32;
  constant PAGE_RAM_DATA_WIDTH : positive := 40;

  constant SHD_CNT_WIDTH : positive := 8;
  constant HIT_CNT_WIDTH : positive := 8;
  constant HANDLE_PTR_WIDTH : positive := 4;
  constant TILE_PKT_CNT_WIDTH : positive := 8;
  constant EGRESS_DELAY : natural := 2;

  constant SHD_SIZE : natural := 1;
  constant HIT_SIZE : natural := 1;
  constant HDR_SIZE : natural := 1;
  constant TRL_SIZE : natural := 1;

  constant PAGE_RAM_ADDR_W : natural := clog2(PAGE_RAM_DEPTH);

  constant CLK_PERIOD : time := 10 ns;

  constant K285 : std_logic_vector(7 downto 0) := "10111100"; -- 0xBC
  constant K284 : std_logic_vector(7 downto 0) := "10011100"; -- 0x9C
  constant DBG  : boolean := true;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- Page allocator interface (to frame_table).
  signal pa_write_head_start      : std_logic := '0';
  signal pa_frame_start_addr      : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');
  signal pa_frame_shr_cnt_this    : unsigned(SHD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_hit_cnt_this    : unsigned(HIT_CNT_WIDTH-1 downto 0) := (others => '0');

  signal pa_write_tail_done       : std_logic := '0';
  signal pa_write_tail_active     : std_logic := '0';
  signal pa_frame_start_addr_last : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');
  signal pa_frame_shr_cnt         : unsigned(SHD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_hit_cnt         : unsigned(HIT_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_invalid_last    : std_logic := '0';
  signal pa_handle_wptr           : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0) := (others => (others => '0'));

  signal bm_handle_rptr           : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0) := (others => (others => '0'));

  -- Page RAM write port.
  signal page_ram_we      : std_logic := '0';
  signal page_ram_wr_addr : unsigned(PAGE_RAM_ADDR_W-1 downto 0) := (others => '0');
  signal page_ram_wr_data : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');

  -- Egress.
  signal egress_ready : std_logic := '1';
  signal egress_valid : std_logic;
  signal egress_data  : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal egress_sop   : std_logic;
  signal egress_eop   : std_logic;

  -- Status/debug.
  signal wr_blocked_by_rd_lock : std_logic;
  signal mapper_state   : std_logic_vector(2 downto 0);
  signal presenter_state: std_logic_vector(2 downto 0);
  signal rseg_tile_index : unsigned(clog2(N_TILE)-1 downto 0);
  signal wseg_tile_index : unsigned_array_t(0 to N_WR_SEG-1)(clog2(N_TILE)-1 downto 0);
  signal tile_wptr : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
  signal tile_rptr : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
  signal tile_pkt_wcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
  signal tile_pkt_rcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);

  function mk_hdr(id : natural) return std_logic_vector is
    variable d : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(7 downto 0)   := K285;
    d(31 downto 8)  := std_logic_vector(to_unsigned(id, 24));
    return d;
  end function;

  function mk_hit(id : natural; idx : natural) return std_logic_vector is
    variable d : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    d(39 downto 32) := x"aa";
    d(31 downto 16) := std_logic_vector(to_unsigned(id, 16));
    d(15 downto 0)  := std_logic_vector(to_unsigned(idx, 16));
    return d;
  end function;

  function mk_trl(id : natural) return std_logic_vector is
    variable d : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(7 downto 0)   := K284;
    d(31 downto 8)  := std_logic_vector(to_unsigned(id, 24));
    return d;
  end function;

  procedure wait_cycles(n : natural) is
  begin
    for i in 0 to n-1 loop
      wait until rising_edge(clk);
    end loop;
  end procedure;

  procedure wait_word(expected : std_logic_vector; timeout_cycles : natural := 500) is
    variable seen : boolean := false;
  begin
    for i in 0 to timeout_cycles-1 loop
      wait until rising_edge(clk);
      if (egress_valid = '1') and (egress_ready = '1') then
        assert egress_data = expected
          report "egress word mismatch" severity failure;
        seen := true;
        exit;
      end if;
    end loop;
    assert seen report "timeout waiting for egress word" severity failure;
  end procedure;
begin
  clk <= not clk after CLK_PERIOD / 2;

  monitor : process
    variable last_mapper_state    : std_logic_vector(2 downto 0) := (others => 'U');
    variable last_presenter_state : std_logic_vector(2 downto 0) := (others => 'U');
    variable last_rseg            : unsigned(rseg_tile_index'range) := (others => 'U');
    variable last_tile_wptr       : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0) := (others => (others => 'U'));
    variable last_tile_rptr       : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0) := (others => (others => 'U'));
    variable last_tile_pkt_wcnt   : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => 'U'));
    variable last_tile_pkt_rcnt   : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => 'U'));
  begin
    wait until rising_edge(clk);
    loop
      wait until rising_edge(clk);

      if DBG then
        if mapper_state /= last_mapper_state then
          report "mapper_state=" & to_hstring(mapper_state) severity note;
          last_mapper_state := mapper_state;
        end if;
        if presenter_state /= last_presenter_state then
          report "presenter_state=" & to_hstring(presenter_state) &
                 " rseg=" & integer'image(to_integer(rseg_tile_index)) severity note;
          last_presenter_state := presenter_state;
        end if;
        if rseg_tile_index /= last_rseg then
          report "rseg_tile_index=" & integer'image(to_integer(rseg_tile_index)) severity note;
          last_rseg := rseg_tile_index;
        end if;

        for t in 0 to N_TILE-1 loop
          if tile_wptr(t) /= last_tile_wptr(t) then
            report "tile_wptr(" & integer'image(t) & ")=" &
                   integer'image(to_integer(tile_wptr(t))) severity note;
            last_tile_wptr(t) := tile_wptr(t);
          end if;
          if tile_rptr(t) /= last_tile_rptr(t) then
            report "tile_rptr(" & integer'image(t) & ")=" &
                   integer'image(to_integer(tile_rptr(t))) severity note;
            last_tile_rptr(t) := tile_rptr(t);
          end if;
          if tile_pkt_wcnt(t) /= last_tile_pkt_wcnt(t) then
            report "tile_pkt_wcnt(" & integer'image(t) & ")=" &
                   integer'image(to_integer(tile_pkt_wcnt(t))) severity note;
            last_tile_pkt_wcnt(t) := tile_pkt_wcnt(t);
          end if;
          if tile_pkt_rcnt(t) /= last_tile_pkt_rcnt(t) then
            report "tile_pkt_rcnt(" & integer'image(t) & ")=" &
                   integer'image(to_integer(tile_pkt_rcnt(t))) severity note;
            last_tile_pkt_rcnt(t) := tile_pkt_rcnt(t);
          end if;
        end loop;

        if (egress_valid = '1') and (egress_ready = '1') then
          report "egress word=" & to_hstring(egress_data) &
                 " sop=" & std_logic'image(egress_sop) &
                 " eop=" & std_logic'image(egress_eop) severity note;
        end if;
      end if;
    end loop;
  end process;

  dut : entity work.opq_frame_table
    generic map (
      N_LANE => N_LANE,
      N_TILE => N_TILE,
      N_WR_SEG => N_WR_SEG,
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      SHD_CNT_WIDTH => SHD_CNT_WIDTH,
      HIT_CNT_WIDTH => HIT_CNT_WIDTH,
      HANDLE_PTR_WIDTH => HANDLE_PTR_WIDTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH,
      EGRESS_DELAY => EGRESS_DELAY,
      SHD_SIZE => SHD_SIZE,
      HIT_SIZE => HIT_SIZE,
      HDR_SIZE => HDR_SIZE,
      TRL_SIZE => TRL_SIZE
    )
    port map (
      i_clk => clk,
      i_rst => rst,

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
      i_page_ram_wr_addr => page_ram_wr_addr,
      i_page_ram_wr_data => page_ram_wr_data,

      i_egress_ready => egress_ready,
      o_egress_valid => egress_valid,
      o_egress_data  => egress_data,
      o_egress_startofpacket => egress_sop,
      o_egress_endofpacket   => egress_eop,

      o_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock,
      o_mapper_state => mapper_state,
      o_presenter_state => presenter_state,
      o_rseg_tile_index => rseg_tile_index,
      o_wseg_tile_index => wseg_tile_index,
      o_tile_wptr => tile_wptr,
      o_tile_rptr => tile_rptr,
      o_tile_pkt_wcnt => tile_pkt_wcnt,
      o_tile_pkt_rcnt => tile_pkt_rcnt
    );

  stim : process is
    variable id0 : natural := 1;
    variable id1 : natural := 2;
    variable blocked_seen : boolean;
    variable found : boolean;
  begin
    egress_ready <= '1';
    page_ram_we <= '0';

    rst <= '1';
    wait_cycles(5);
    rst <= '0';

    -- ─────────────────────────────────────────────
    -- Test 1: basic packet (non-spill), made presentable by
    -- forcing a WR window scroll (spill) and then starting one
    -- additional frame so the presenter no longer considers the
    -- packet's tile as the "active write tile".
    -- ─────────────────────────────────────────────
    -- Frame0 head start (non-spill, will be written into the reset leading tile).
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(0, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(2, HIT_CNT_WIDTH);
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    -- Give mapper time to latch/update.
    wait_cycles(3);

    -- Write packet words (hdr + 2 hits + trailer) at addresses 0..3.
    page_ram_we <= '1';
    page_ram_wr_addr <= to_unsigned(0, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hdr(id0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(1, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(2, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 1);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(3, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_trl(id0);
    wait until rising_edge(clk);
    page_ram_we <= '0';

    -- Frame1 head start: force a spill so the mapper scrolls the WR window.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(31, PAGE_RAM_ADDR_W); -- hdr+trl => 2 words, spills by 1
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    -- Allow UPDATE_FRAME_TABLE to execute.
    wait_cycles(4);

    -- Tail done for Frame0 (finalize meta).
    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_frame_start_addr_last <= to_unsigned(0, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= to_unsigned(2, HIT_CNT_WIDTH);
    pa_frame_invalid_last    <= '0';
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';

    -- Frame2 head start: advances the mapper regs so the presenter won't drop
    -- packets that live in the previous leading tile.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(8, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(4);

    -- Expect exact output sequence.
    wait_word(mk_hdr(id0));
    wait_word(mk_hit(id0, 0));
    wait_word(mk_hit(id0, 1));
    wait_word(mk_trl(id0));

    -- ─────────────────────────────────────────────
    -- Test 2: spill across page boundary (two tiles)
    -- ─────────────────────────────────────────────
    id0 := 3;
    id1 := 4;

    -- Frame2 head start near end => wrap.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(30, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(3, HIT_CNT_WIDTH); -- hdr+3hit+trl => 5 words, spills at addr 30
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(3);

    -- Write hdr @30, hit0 @31, hit1 @0, hit2 @1, trl @2
    page_ram_we <= '1';
    page_ram_wr_addr <= to_unsigned(30, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hdr(id0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(31, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(0, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 1);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(1, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 2);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(2, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_trl(id0);
    wait until rising_edge(clk);
    page_ram_we <= '0';

    -- Dummy next frame to advance pipe.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(12, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(2);

    -- Tail done for Frame2.
    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_frame_start_addr_last <= to_unsigned(30, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= to_unsigned(3, HIT_CNT_WIDTH);
    pa_frame_invalid_last    <= '0';
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';

    wait_word(mk_hdr(id0));
    wait_word(mk_hit(id0, 0));
    wait_word(mk_hit(id0, 1));
    wait_word(mk_hit(id0, 2));
    wait_word(mk_trl(id0));

    -- ─────────────────────────────────────────────
    -- Test 3: backpressure restart mid-packet
    -- ─────────────────────────────────────────────
    id0 := 5;

    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(4, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(4, HIT_CNT_WIDTH); -- hdr+4hit+trl => 6 words
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(3);

    page_ram_we <= '1';
    page_ram_wr_addr <= to_unsigned(4, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hdr(id0);
    wait until rising_edge(clk);
    for h in 0 to 3 loop
      page_ram_wr_addr <= to_unsigned(5 + h, PAGE_RAM_ADDR_W);
      page_ram_wr_data <= mk_hit(id0, h);
      wait until rising_edge(clk);
    end loop;
    page_ram_wr_addr <= to_unsigned(9, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_trl(id0);
    wait until rising_edge(clk);
    page_ram_we <= '0';

    -- Dummy next frame to advance pipe.
    wait until rising_edge(clk);
    pa_write_head_start <= '1';
    pa_frame_start_addr <= to_unsigned(20, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(2);

    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_frame_start_addr_last <= to_unsigned(4, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= to_unsigned(4, HIT_CNT_WIDTH);
    pa_frame_invalid_last    <= '0';
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';

    -- Consume first two words, then stall, then resume.
    wait_word(mk_hdr(id0));
    wait_word(mk_hit(id0, 0));

    egress_ready <= '0';
    wait_cycles(8);
    egress_ready <= '1';

    wait_word(mk_hit(id0, 1));
    wait_word(mk_hit(id0, 2));
    wait_word(mk_hit(id0, 3));
    wait_word(mk_trl(id0));

    -- ─────────────────────────────────────────────
    -- Test 4: long stall + write into rd-locked tile
    -- Expect: no broken output; the new packet is dropped (invalid) and the in-flight
    -- packet remains intact.
    -- ─────────────────────────────────────────────
    id0 := 10;
    id1 := 11;

    -- Reset the frame-table complex (RAM contents persist, pointers/counters reset).
    rst <= '1';
    wait_cycles(5);
    rst <= '0';

    -- Hold egress stalled so the presenter locks the tile while presenting.
    egress_ready <= '0';

    -- Packet A (id0): non-spill, 4 words @12..15 (hdr+2hit+trl).
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(12, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(2, HIT_CNT_WIDTH);
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(3);

    page_ram_we <= '1';
    page_ram_wr_addr <= to_unsigned(12, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hdr(id0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(13, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 0);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(14, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id0, 1);
    wait until rising_edge(clk);
    page_ram_wr_addr <= to_unsigned(15, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_trl(id0);
    wait until rising_edge(clk);
    page_ram_we <= '0';

    -- Dummy next frame to advance the mapper's wseg_last_tile pipe so the tail-done
    -- update targets the correct tile.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(0, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(4);

    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_frame_start_addr_last <= to_unsigned(12, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= to_unsigned(2, HIT_CNT_WIDTH);
    pa_frame_invalid_last    <= '0';
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';

    -- Wait for presenter to warp to the leading write tile and start presenting.
    found := false;
    for i in 0 to 500 loop
      wait until rising_edge(clk);
      if ((presenter_state = "011") or (presenter_state = "100"))
        and (rseg_tile_index = to_unsigned(4, rseg_tile_index'length)) then
        found := true;
        exit;
      end if;
    end loop;
    assert found report "timeout waiting for presenter to lock tile4" severity failure;

    -- Packet B (id1): write while locked. Mark invalid if write is blocked.
    blocked_seen := false;

    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(16, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(1, HIT_CNT_WIDTH); -- hdr+hit+trl => 3 words
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    wait_cycles(2);

    page_ram_we <= '1';
    page_ram_wr_addr <= to_unsigned(16, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hdr(id1);
    wait until rising_edge(clk);
    if wr_blocked_by_rd_lock = '1' then
      blocked_seen := true;
    end if;
    page_ram_wr_addr <= to_unsigned(17, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_hit(id1, 0);
    wait until rising_edge(clk);
    if wr_blocked_by_rd_lock = '1' then
      blocked_seen := true;
    end if;
    page_ram_wr_addr <= to_unsigned(18, PAGE_RAM_ADDR_W);
    page_ram_wr_data <= mk_trl(id1);
    wait until rising_edge(clk);
    if wr_blocked_by_rd_lock = '1' then
      blocked_seen := true;
    end if;
    page_ram_we <= '0';

    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_frame_start_addr_last <= to_unsigned(16, PAGE_RAM_ADDR_W);
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= to_unsigned(1, HIT_CNT_WIDTH);
    if blocked_seen then
      pa_frame_invalid_last <= '1';
    else
      pa_frame_invalid_last <= '0';
    end if;
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';
    pa_frame_invalid_last <= '0';

    -- Resume egress and confirm we get a full, unbroken Packet A and no Packet B header.
    egress_ready <= '1';

    wait_word(mk_hdr(id0));
    wait_word(mk_hit(id0, 0));
    wait_word(mk_hit(id0, 1));
    wait_word(mk_trl(id0));

    for i in 0 to 200 loop
      wait until rising_edge(clk);
      assert not ((egress_valid = '1') and (egress_ready = '1'))
        report "unexpected extra packet output after Test4" severity failure;
    end loop;

    finish;
  end process;
end architecture tb;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_b2p_arbiter is
end entity tb_opq_b2p_arbiter;

architecture tb of tb_opq_b2p_arbiter is
  constant N_LANE              : positive := 2;
  constant LANE_FIFO_WIDTH     : positive := 8;
  constant PAGE_RAM_DEPTH      : positive := 16;
  constant PAGE_RAM_DATA_WIDTH : positive := 8;
  constant WORD_WR_CNT_WIDTH   : positive := 4;
  constant QUANTUM_PER_SUBFRAME : natural := 2;
  constant QUANTUM_WIDTH        : positive := 4;

  constant ALL_ONES  : std_logic_vector(N_LANE-1 downto 0) := (others => '1');
  constant ALL_ZEROS : std_logic_vector(N_LANE-1 downto 0) := (others => '0');

  constant CLK_PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal bm_page_wreq    : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal bm_page_wptr    : unsigned_array_t(0 to N_LANE-1)(clog2(PAGE_RAM_DEPTH)-1 downto 0);
  signal bm_word_wr_cnt  : unsigned_array_t(0 to N_LANE-1)(WORD_WR_CNT_WIDTH-1 downto 0);
  signal bm_lane_rd_data : slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);

  signal alloc_page_we    : std_logic := '0';
  signal alloc_page_waddr : std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0) := (others => '0');
  signal alloc_page_wdata : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0) := (others => '0');

  signal quantum_update : std_logic_vector(N_LANE-1 downto 0) := (others => '0');

  signal gnt      : std_logic_vector(N_LANE-1 downto 0);
  signal page_we  : std_logic;
  signal page_addr : std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
  signal page_data : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.opq_b2p_arbiter
    generic map (
      N_LANE               => N_LANE,
      LANE_FIFO_WIDTH      => LANE_FIFO_WIDTH,
      PAGE_RAM_DEPTH       => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH  => PAGE_RAM_DATA_WIDTH,
      WORD_WR_CNT_WIDTH    => WORD_WR_CNT_WIDTH,
      QUANTUM_PER_SUBFRAME => QUANTUM_PER_SUBFRAME,
      QUANTUM_WIDTH        => QUANTUM_WIDTH
    )
    port map (
      i_clk  => clk,
      i_rst  => rst,

      i_bm_page_wreq    => bm_page_wreq,
      i_bm_page_wptr    => bm_page_wptr,
      i_bm_word_wr_cnt  => bm_word_wr_cnt,
      i_bm_lane_rd_data => bm_lane_rd_data,

      i_alloc_page_we    => alloc_page_we,
      i_alloc_page_waddr => alloc_page_waddr,
      i_alloc_page_wdata => alloc_page_wdata,

      i_quantum_update => quantum_update,

      o_b2p_arb_gnt      => gnt,
      o_page_ram_we      => page_we,
      o_page_ram_wr_addr => page_addr,
      o_page_ram_wr_data => page_data
    );

  stim : process is
  begin
    for i in 0 to N_LANE-1 loop
      bm_page_wptr(i) <= (others => '0');
      bm_word_wr_cnt(i) <= (others => '0');
      bm_lane_rd_data(i) <= (others => '0');
    end loop;

    rst <= '1';
    wait for 5 * CLK_PERIOD;
    rst <= '0';

    wait until rising_edge(clk);
    bm_page_wreq <= (others => '1');
    bm_page_wptr(0) <= to_unsigned(1, bm_page_wptr(0)'length);
    bm_page_wptr(1) <= to_unsigned(8, bm_page_wptr(1)'length);
    bm_lane_rd_data(0) <= x"a0";
    bm_lane_rd_data(1) <= x"b0";

    -- Let the DRR/quantum behavior run for a bit.
    wait for 16 * CLK_PERIOD;

    -- Allocator preemption should override grants and force the page RAM write mux.
    wait until rising_edge(clk);
    alloc_page_we    <= '1';
    alloc_page_waddr <= std_logic_vector(to_unsigned(3, alloc_page_waddr'length));
    alloc_page_wdata <= x"5a";

    wait until rising_edge(clk);
    alloc_page_we <= '0';

    wait for 8 * CLK_PERIOD;

    finish;
  end process;

  checker : process is
    variable started         : boolean := false;
    variable skip_checks_cnt : natural := 0;
    variable last_gnt        : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    variable consec_grants   : natural := 0;
    variable saw_lane0       : boolean := false;
    variable saw_lane1       : boolean := false;
    variable obs_cycles      : natural := 0;
    variable have_expected : boolean := false;

    variable exp_we_next   : std_logic := '0';
    variable exp_addr_next : std_logic_vector(page_addr'range) := (others => '0');
    variable exp_data_next : std_logic_vector(page_data'range) := (others => '0');
  begin
    wait until rising_edge(clk);
    loop
      wait until rising_edge(clk);
      -- allow comb outputs to settle post-edge (ModelSim can require multiple deltas)
      wait for 1 ns;

      if rst = '1' then
        started := false;
        skip_checks_cnt := 0;
        last_gnt := (others => '0');
        consec_grants := 0;
        saw_lane0 := false;
        saw_lane1 := false;
        obs_cycles := 0;
        have_expected := false;
        exp_we_next := '0';
        exp_addr_next := (others => '0');
        exp_data_next := (others => '0');
        next;
      end if;

      if have_expected and started and (skip_checks_cnt = 0) then
        assert page_we = exp_we_next
          report "page_we mismatch" severity failure;
        assert page_addr = exp_addr_next
          report "page_addr mismatch" severity failure;
        assert page_data = exp_data_next
          report "page_data mismatch" severity failure;
      end if;

      if (not started) and (bm_page_wreq = ALL_ONES) then
        started := true;
        skip_checks_cnt := 2; -- allow pipeline fill / first registered write
        last_gnt := (others => '0');
        consec_grants := 0;
        saw_lane0 := false;
        saw_lane1 := false;
        obs_cycles := 0;
        have_expected := false;
      end if;

      if started and (alloc_page_we = '0') then
        if skip_checks_cnt > 0 then
          skip_checks_cnt := skip_checks_cnt - 1;
        else
          -- For this unit TB (N_LANE=2): expect a onehot grant whenever req is present.
          assert (gnt = "01") or (gnt = "10")
            report "expected onehot grant when bm_page_wreq is asserted" severity failure;

          if gnt = last_gnt then
            consec_grants := consec_grants + 1;
          else
            last_gnt := gnt;
            consec_grants := 1;
          end if;

          assert consec_grants <= QUANTUM_PER_SUBFRAME
            report "quantum violation: too many consecutive grants to same lane" severity failure;

          if gnt(0) = '1' then
            saw_lane0 := true;
          end if;
          if gnt(1) = '1' then
            saw_lane1 := true;
          end if;

          obs_cycles := obs_cycles + 1;
          if obs_cycles = 16 then
            assert saw_lane0 and saw_lane1
              report "expected both lanes to be granted under continuous request" severity failure;
          end if;
        end if;
      end if;

      if alloc_page_we = '1' then
        assert gnt = ALL_ZEROS
          report "allocator preemption expects gnt=0" severity failure;
      end if;

      -- Compute expected registered page RAM output for next cycle.
      exp_we_next := '0';
      exp_addr_next := (others => '0');
      exp_data_next := (others => '0');

      if alloc_page_we = '1' then
        exp_we_next := '1';
        exp_addr_next := alloc_page_waddr;
        exp_data_next := alloc_page_wdata;
      else
        for i in 0 to N_LANE-1 loop
          if (gnt(i) = '1') and (bm_page_wreq(i) = '1') then
            exp_we_next := '1';
            exp_addr_next := std_logic_vector(bm_page_wptr(i) + resize(bm_word_wr_cnt(i), bm_page_wptr(i)'length));
            exp_data_next := bm_lane_rd_data(i)(PAGE_RAM_DATA_WIDTH-1 downto 0);
          end if;
        end loop;
      end if;

      have_expected := true;
    end loop;
  end process;
end architecture tb;

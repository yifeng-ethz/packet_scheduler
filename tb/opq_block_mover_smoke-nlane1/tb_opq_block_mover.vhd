library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_block_mover is
end entity tb_opq_block_mover;

architecture tb of tb_opq_block_mover is
  constant N_LANE            : positive := 1;
  constant LANE_FIFO_DEPTH   : positive := 16;
  constant LANE_FIFO_WIDTH   : positive := 8;
  constant HANDLE_FIFO_DEPTH : positive := 4;
  constant PAGE_RAM_DEPTH    : positive := 16;
  constant HIT_SIZE          : positive := 1;
  constant N_HIT             : positive := 8;
  constant FIFO_RAW_DELAY    : positive := 1;
  constant FIFO_RD_DELAY     : positive := 1;

  constant CLK_PERIOD : time := 10 ns;

  constant LANE_FIFO_ADDR_WIDTH   : natural := clog2(LANE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_WIDTH    : natural := clog2(PAGE_RAM_DEPTH);
  constant MAX_PKT_LENGTH_BITS    : natural := clog2(HIT_SIZE * N_HIT);
  constant HANDLE_ADDR_WIDTH      : natural := clog2(HANDLE_FIFO_DEPTH);
  constant HANDLE_DATA_WIDTH      : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS + 1;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal handle_fifos_rd_data : slv_array_t(0 to N_LANE-1)(HANDLE_DATA_WIDTH-1 downto 0) := (others => (others => '0'));
  signal handle_wptr          : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_WIDTH-1 downto 0) := (others => (others => '0'));
  signal handle_we            : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal handle_fifos_rd_addr : slv_array_t(0 to N_LANE-1)(HANDLE_ADDR_WIDTH-1 downto 0);

  signal lane_fifos_rd_data : slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0) := (others => (others => '0'));
  signal lane_fifos_rd_addr : slv_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_WIDTH-1 downto 0);

  signal b2p_arb_gnt : std_logic_vector(N_LANE-1 downto 0) := (others => '1');

  signal page_wreq   : std_logic_vector(N_LANE-1 downto 0);
  signal page_wptr   : unsigned_array_t(0 to N_LANE-1)(PAGE_RAM_ADDR_WIDTH-1 downto 0);
  signal word_wr_cnt : unsigned_array_t(0 to N_LANE-1)(MAX_PKT_LENGTH_BITS-1 downto 0);

  signal lane_credit_update_valid : std_logic_vector(N_LANE-1 downto 0);
  signal lane_credit_update       : unsigned_array_t(0 to N_LANE-1)(LANE_FIFO_ADDR_WIDTH-1 downto 0);

  signal handle_pending : std_logic_vector(N_LANE-1 downto 0);

  type handle_mem_t is array (0 to HANDLE_FIFO_DEPTH-1) of std_logic_vector(HANDLE_DATA_WIDTH-1 downto 0);
  signal handle_mem : handle_mem_t := (others => (others => '0'));

  function pack_handle(
    src     : natural;
    dst     : natural;
    blk_len : natural;
    flag    : std_logic
  ) return std_logic_vector is
    variable v : std_logic_vector(HANDLE_DATA_WIDTH-1 downto 0);
  begin
    v := (others => '0');
    v(LANE_FIFO_ADDR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(src, LANE_FIFO_ADDR_WIDTH));
    v(LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH-1 downto LANE_FIFO_ADDR_WIDTH) := std_logic_vector(to_unsigned(dst, PAGE_RAM_ADDR_WIDTH));
    v(LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS-1 downto LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH) :=
      std_logic_vector(to_unsigned(blk_len, MAX_PKT_LENGTH_BITS));
    v(LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS) := flag;
    return v;
  end function;

  function is_01(s : std_logic_vector) return boolean is
  begin
    for i in s'range loop
      if (s(i) /= '0') and (s(i) /= '1') then
        return false;
      end if;
    end loop;
    return true;
  end function;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.opq_block_mover
    generic map (
      N_LANE            => N_LANE,
      LANE_FIFO_DEPTH   => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH   => LANE_FIFO_WIDTH,
      HANDLE_FIFO_DEPTH => HANDLE_FIFO_DEPTH,
      PAGE_RAM_DEPTH    => PAGE_RAM_DEPTH,
      HIT_SIZE          => HIT_SIZE,
      N_HIT             => N_HIT,
      FIFO_RAW_DELAY    => FIFO_RAW_DELAY,
      FIFO_RD_DELAY     => FIFO_RD_DELAY
    )
    port map (
      i_clk => clk,
      i_rst => rst,

      i_handle_fifos_rd_data => handle_fifos_rd_data,
      i_handle_wptr          => handle_wptr,
      i_handle_we            => handle_we,
      o_handle_fifos_rd_addr => handle_fifos_rd_addr,

      i_lane_fifos_rd_data => lane_fifos_rd_data,
      o_lane_fifos_rd_addr => lane_fifos_rd_addr,

      i_b2p_arb_gnt => b2p_arb_gnt,

      o_page_wreq   => page_wreq,
      o_page_wptr   => page_wptr,
      o_word_wr_cnt => word_wr_cnt,

      o_lane_credit_update_valid => lane_credit_update_valid,
      o_lane_credit_update       => lane_credit_update,

      o_handle_pending => handle_pending
    );

  -- Simple combinational model: handle FIFO read data follows read address.
  proc_handle_mem : process (all) is
    variable addr_i : natural := 0;
  begin
    if is_01(handle_fifos_rd_addr(0)) then
      addr_i := to_integer(unsigned(handle_fifos_rd_addr(0)));
    end if;
    handle_fifos_rd_data(0) <= handle_mem(addr_i);
  end process;

  stim : process is
    variable cycles_handle0_wreq : natural := 0;
    variable saw_wreq_on_handle1 : boolean := false;
    variable saw_credit_len3     : boolean := false;
    variable saw_credit_len2     : boolean := false;
    variable done_v              : boolean := false;
  begin
    -- Two handles:
    --  0) normal write (blk_len=3)
    --  1) abort (flag=1), should not write but still return credit.
    handle_mem(0) <= pack_handle(src => 0,  dst => 4, blk_len => 3, flag => '0');
    handle_mem(1) <= pack_handle(src => 8,  dst => 12, blk_len => 2, flag => '1');
    handle_wptr(0) <= to_unsigned(2, HANDLE_ADDR_WIDTH);

    rst <= '1';
    wait for 5 * CLK_PERIOD;
    rst <= '0';

    -- Run until both handles drain (or timeout).
    for cyc in 0 to 200 loop
      wait until rising_edge(clk);
      wait for 0 ns;

      if page_wreq(0) = '1' then
        if unsigned(handle_fifos_rd_addr(0)) = 0 then
          cycles_handle0_wreq := cycles_handle0_wreq + 1;
          assert page_wptr(0) = to_unsigned(4, PAGE_RAM_ADDR_WIDTH)
            report "handle0 page_wptr mismatch" severity failure;
        elsif unsigned(handle_fifos_rd_addr(0)) = 1 then
          saw_wreq_on_handle1 := true;
        end if;
      end if;

      if lane_credit_update_valid(0) = '1' then
        if lane_credit_update(0) = to_unsigned(3, LANE_FIFO_ADDR_WIDTH) then
          saw_credit_len3 := true;
        elsif lane_credit_update(0) = to_unsigned(2, LANE_FIFO_ADDR_WIDTH) then
          saw_credit_len2 := true;
        end if;
      end if;

      if (unsigned(handle_fifos_rd_addr(0)) = 2) and (handle_pending(0) = '0') then
        done_v := true;
        exit;
      end if;
    end loop;

    assert done_v
      report "timeout waiting for handles to drain" severity failure;

    assert cycles_handle0_wreq = 3
      report "expected 3 writes for handle0, got " & integer'image(cycles_handle0_wreq) severity failure;
    assert not saw_wreq_on_handle1
      report "unexpected page_wreq on abort handle1" severity failure;
    assert saw_credit_len3
      report "missing credit return for handle0 (blk_len=3)" severity failure;
    assert saw_credit_len2
      report "missing credit return for handle1 (blk_len=2)" severity failure;
    assert unsigned(handle_fifos_rd_addr(0)) = 2
      report "expected handle_rptr to advance to 2" severity failure;
    assert handle_pending(0) = '0'
      report "expected no pending handles at end" severity failure;

    finish;
  end process;
end architecture tb;

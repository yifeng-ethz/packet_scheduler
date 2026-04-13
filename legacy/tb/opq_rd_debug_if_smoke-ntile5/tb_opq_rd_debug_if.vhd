library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_rd_debug_if is
end entity tb_opq_rd_debug_if;

architecture tb of tb_opq_rd_debug_if is
  constant AVS_ADDR_WIDTH : positive := 8;
  constant N_TILE         : positive := 5;
  constant N_WR_SEG       : positive := 4;
  constant TILE_FIFO_DEPTH : positive := 512;
  constant TILE_PKT_CNT_WIDTH : positive := 10;

  constant TILE_ID_W : natural := clog2(N_TILE);
  constant CLK_PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal avs_address       : std_logic_vector(AVS_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal avs_read          : std_logic := '0';
  signal avs_readdata      : std_logic_vector(31 downto 0);
  signal avs_waitrequest   : std_logic;
  signal avs_readdatavalid : std_logic;

  signal wr_blocked : std_logic := '0';
  signal mapper_state : std_logic_vector(2 downto 0) := (others => '0');
  signal presenter_state : std_logic_vector(2 downto 0) := (others => '0');
  signal rseg_tile : unsigned(TILE_ID_W-1 downto 0) := (others => '0');
  signal wseg_tile : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_W-1 downto 0) := (others => (others => '0'));
  signal tile_wptr : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0) := (others => (others => '0'));
  signal tile_rptr : unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0) := (others => (others => '0'));
  signal tile_wcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => '0'));
  signal tile_rcnt : unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0) := (others => (others => '0'));

  procedure do_read(
    signal p_address       : out std_logic_vector(AVS_ADDR_WIDTH-1 downto 0);
    signal p_read          : out std_logic;
    signal p_clk           : in  std_logic;
    signal p_waitrequest   : in  std_logic;
    signal p_readdatavalid : in  std_logic;
    signal p_readdata      : in  std_logic_vector(31 downto 0);
    addr : natural;
    exp  : std_logic_vector(31 downto 0)
  ) is
  begin
    p_address <= std_logic_vector(to_unsigned(addr, AVS_ADDR_WIDTH));
    p_read <= '1';
    wait until rising_edge(p_clk);
    p_read <= '0';
    wait for 1 ps;
    assert p_waitrequest = '0' report "waitrequest must be 0" severity failure;
    assert p_readdatavalid = '1' report "readdatavalid missing" severity failure;
    assert p_readdata = exp report "readdata mismatch" severity failure;
    wait until rising_edge(p_clk);
    wait for 1 ps;
    assert p_readdatavalid = '0' report "readdatavalid must clear" severity failure;
  end procedure;
begin
  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.opq_rd_debug_if
    generic map (
      AVS_ADDR_WIDTH => AVS_ADDR_WIDTH,
      N_TILE => N_TILE,
      N_WR_SEG => N_WR_SEG,
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH
    )
    port map (
      i_clk => clk,
      i_rst => rst,

      i_avs_address => avs_address,
      i_avs_read => avs_read,
      o_avs_readdata => avs_readdata,
      o_avs_waitrequest => avs_waitrequest,
      o_avs_readdatavalid => avs_readdatavalid,

      i_wr_blocked_by_rd_lock => wr_blocked,
      i_mapper_state => mapper_state,
      i_presenter_state => presenter_state,
      i_rseg_tile_index => rseg_tile,
      i_wseg_tile_index => wseg_tile,
      i_tile_wptr => tile_wptr,
      i_tile_rptr => tile_rptr,
      i_tile_pkt_wcnt => tile_wcnt,
      i_tile_pkt_rcnt => tile_rcnt
    );

  stim : process is
    variable exp_status : std_logic_vector(31 downto 0);
  begin
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    -- Populate debug sources with non-zero values.
    wr_blocked <= '1';
    mapper_state <= "101";
    presenter_state <= "011";
    rseg_tile <= to_unsigned(2, rseg_tile'length);
    for s in 0 to N_WR_SEG-1 loop
      wseg_tile(s) <= to_unsigned(s, wseg_tile(s)'length);
    end loop;
    for t in 0 to N_TILE-1 loop
      tile_wptr(t) <= to_unsigned(10 + t, tile_wptr(t)'length);
      tile_rptr(t) <= to_unsigned(3 + t, tile_rptr(t)'length);
      tile_wcnt(t) <= to_unsigned(20 + t, tile_wcnt(t)'length);
      tile_rcnt(t) <= to_unsigned(15 + t, tile_rcnt(t)'length);
    end loop;

    wait until rising_edge(clk);

    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 0, x"4F505130");

    exp_status := (others => '0');
    exp_status(0) := '1';
    exp_status(3 downto 1) := "101";
    exp_status(6 downto 4) := "011";
    exp_status(15 downto 8) := std_logic_vector(to_unsigned(2, 8));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 2, exp_status);

    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 3, std_logic_vector(resize(rseg_tile, 32)));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 4, std_logic_vector(resize(wseg_tile(0), 32)));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 5, std_logic_vector(resize(wseg_tile(1), 32)));

    -- Tile 2 window.
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 16 + 2*4 + 0, std_logic_vector(resize(tile_wptr(2), 32)));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 16 + 2*4 + 1, std_logic_vector(resize(tile_rptr(2), 32)));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 16 + 2*4 + 2, std_logic_vector(resize(tile_wcnt(2), 32)));
    do_read(avs_address, avs_read, clk, avs_waitrequest, avs_readdatavalid, avs_readdata, 16 + 2*4 + 3, std_logic_vector(resize(tile_rcnt(2), 32)));

    report "tb_opq_rd_debug_if: PASS" severity note;
    finish;
  end process;
end architecture tb;

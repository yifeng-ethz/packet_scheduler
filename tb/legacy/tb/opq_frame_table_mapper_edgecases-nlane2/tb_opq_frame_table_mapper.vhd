library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_frame_table_mapper is
end entity tb_opq_frame_table_mapper;

architecture tb of tb_opq_frame_table_mapper is
  constant N_LANE : positive := 2;
  constant N_TILE : positive := 5;
  constant N_WR_SEG : positive := 4;

  constant PAGE_RAM_DEPTH : positive := 16;
  constant SHD_CNT_WIDTH  : positive := 8;
  constant HIT_CNT_WIDTH  : positive := 8;
  constant HANDLE_PTR_WIDTH : positive := 3;

  constant SHD_SIZE : natural := 1;
  constant HIT_SIZE : natural := 1;
  constant HDR_SIZE : natural := 1;
  constant TRL_SIZE : natural := 1;

  constant PAGE_RAM_ADDR_WIDTH : natural := clog2(PAGE_RAM_DEPTH);
  constant TILE_ID_WIDTH       : natural := clog2(N_TILE);

  constant CLK_PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- Inputs.
  signal pa_write_head_start      : std_logic := '0';
  signal pa_frame_start_addr      : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_shr_cnt_this    : unsigned(SHD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_hit_cnt_this    : unsigned(HIT_CNT_WIDTH-1 downto 0) := (others => '0');

  signal pa_write_tail_done       : std_logic := '0';
  signal pa_write_tail_active     : std_logic := '0';
  signal pa_frame_start_addr_last : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_shr_cnt         : unsigned(SHD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_hit_cnt         : unsigned(HIT_CNT_WIDTH-1 downto 0) := (others => '0');
  signal pa_frame_invalid_last    : std_logic := '0';
  signal pa_handle_wptr           : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0) := (others => (others => '0'));

  signal bm_handle_rptr           : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0) := (others => (others => '0'));

  signal presenter_active         : std_logic := '0';
  signal presenter_warping        : std_logic := '0';
  signal presenter_rseg_tile      : unsigned(TILE_ID_WIDTH-1 downto 0) := (others => '0');
  signal presenter_cross_valid    : std_logic := '0';
  signal presenter_cross_tile     : unsigned(TILE_ID_WIDTH-1 downto 0) := (others => '0');
  signal presenter_rd_in_range    : std_logic := '0';

  signal page_ram_we              : std_logic := '0';
  signal page_ram_wr_addr         : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0) := (others => '0');

  -- Outputs.
  signal update_ftable_valid      : std_logic_vector(1 downto 0);
  signal update_ftable_tindex     : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0);
  signal update_ftable_meta_valid : std_logic_vector(1 downto 0);
  signal update_ftable_meta       : slv_array_t(0 to 1)(2*PAGE_RAM_ADDR_WIDTH-1 downto 0);
  signal update_ftable_trltl_valid : std_logic_vector(1 downto 0);
  signal update_ftable_trltl      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0);
  signal update_ftable_bdytl_valid : std_logic_vector(1 downto 0);
  signal update_ftable_bdytl      : unsigned_array_t(0 to 1)(TILE_ID_WIDTH-1 downto 0);
  signal update_ftable_hcmpl      : std_logic_vector(1 downto 0);
  signal flush_ftable_valid       : std_logic_vector(1 downto 0);

  signal wseg_tile_index          : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_WIDTH-1 downto 0);
  signal leading_wr_tile_reg      : unsigned(TILE_ID_WIDTH-1 downto 0);
  signal expand_wr_tile_reg       : unsigned(TILE_ID_WIDTH-1 downto 0);
  signal writing_tile             : unsigned(TILE_ID_WIDTH-1 downto 0);

  signal state_code               : std_logic_vector(2 downto 0);
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.opq_frame_table_mapper
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
      TRL_SIZE         => TRL_SIZE
    )
    port map (
      i_clk => clk,
      i_rst => rst,

      i_pa_write_head_start    => pa_write_head_start,
      i_pa_frame_start_addr    => pa_frame_start_addr,
      i_pa_frame_shr_cnt_this  => pa_frame_shr_cnt_this,
      i_pa_frame_hit_cnt_this  => pa_frame_hit_cnt_this,

      i_pa_write_tail_done      => pa_write_tail_done,
      i_pa_write_tail_active    => pa_write_tail_active,
      i_pa_frame_start_addr_last => pa_frame_start_addr_last,
      i_pa_frame_shr_cnt        => pa_frame_shr_cnt,
      i_pa_frame_hit_cnt        => pa_frame_hit_cnt,
      i_pa_frame_invalid_last   => pa_frame_invalid_last,
      i_pa_handle_wptr          => pa_handle_wptr,

      i_bm_handle_rptr          => bm_handle_rptr,

      i_presenter_active        => presenter_active,
      i_presenter_warping       => presenter_warping,
      i_presenter_rseg_tile_index => presenter_rseg_tile,
      i_presenter_crossing_tile_valid => presenter_cross_valid,
      i_presenter_crossing_tile => presenter_cross_tile,
      i_presenter_rd_tile_in_range => presenter_rd_in_range,

      i_page_ram_we             => page_ram_we,
      i_page_ram_wr_addr        => page_ram_wr_addr,

      o_update_ftable_valid     => update_ftable_valid,
      o_update_ftable_tindex    => update_ftable_tindex,
      o_update_ftable_meta_valid => update_ftable_meta_valid,
      o_update_ftable_meta      => update_ftable_meta,
      o_update_ftable_trltl_valid => update_ftable_trltl_valid,
      o_update_ftable_trltl     => update_ftable_trltl,
      o_update_ftable_bdytl_valid => update_ftable_bdytl_valid,
      o_update_ftable_bdytl     => update_ftable_bdytl,
      o_update_ftable_hcmpl     => update_ftable_hcmpl,
      o_flush_ftable_valid      => flush_ftable_valid,

      o_wseg_tile_index         => wseg_tile_index,
      o_leading_wr_tile_index_reg => leading_wr_tile_reg,
      o_expand_wr_tile_index_reg  => expand_wr_tile_reg,
      o_writing_tile_index      => writing_tile,
      o_state                   => state_code
    );

  stim : process is
  begin
    -- Keep presenter on tile 0 (locked) so mapper must skip tile 0 for the expanding tile.
    presenter_rseg_tile   <= (others => '0');
    presenter_cross_valid <= '0';
    presenter_cross_tile  <= (others => '0');
    presenter_active      <= '0';
    presenter_warping     <= '0';
    presenter_rd_in_range <= '0';

    rst <= '1';
    wait for 5 * CLK_PERIOD;
    rst <= '0';

    -- Post-reset sanity.
    wait until rising_edge(clk);
    wait for 1 ns;
    assert wseg_tile_index(0) = to_unsigned(1, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(1) = to_unsigned(2, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(2) = to_unsigned(3, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(3) = to_unsigned(4, TILE_ID_WIDTH) severity failure;
    assert leading_wr_tile_reg = to_unsigned(4, TILE_ID_WIDTH) severity failure;

    -- Frame0: non-spill, just to push pipe0.
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= (others => '0');
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= (others => '0');
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    -- Wait a couple cycles for state to settle.
    wait for 5 * CLK_PERIOD;

    -- Frame1: spill (start near end). Should expand to tile 1 (skip read-locked tile 0).
    wait until rising_edge(clk);
    pa_write_head_start   <= '1';
    pa_frame_start_addr   <= to_unsigned(14, PAGE_RAM_ADDR_WIDTH);
    pa_frame_shr_cnt_this <= (others => '0');
    pa_frame_hit_cnt_this <= to_unsigned(1, HIT_CNT_WIDTH);
    wait until rising_edge(clk);
    pa_write_head_start <= '0';

    -- Allow UPDATE_FRAME_TABLE to execute.
    wait for 5 * CLK_PERIOD;

    -- After spill scroll: [1,2,3,4] -> [2,3,4,1]
    wait until rising_edge(clk);
    wait for 1 ns;
    assert wseg_tile_index(0) = to_unsigned(2, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(1) = to_unsigned(3, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(2) = to_unsigned(4, TILE_ID_WIDTH) severity failure;
    assert wseg_tile_index(3) = to_unsigned(1, TILE_ID_WIDTH) severity failure;

    -- Tail done for frame0 (meta should target tile 4 after pipe1).
    wait until rising_edge(clk);
    pa_write_tail_done       <= '1';
    pa_write_tail_active     <= '0';
    pa_frame_start_addr_last <= (others => '0');
    pa_frame_shr_cnt         <= (others => '0');
    pa_frame_hit_cnt         <= (others => '0');
    pa_frame_invalid_last    <= '0';
    wait until rising_edge(clk);
    pa_write_tail_done <= '0';

    wait for 10 * CLK_PERIOD;
    finish;
  end process;

  checker : process is
    variable saw_spill_update : boolean := false;
    variable saw_meta_update  : boolean := false;
    constant EXP_META_FRAME0  : std_logic_vector(2*PAGE_RAM_ADDR_WIDTH-1 downto 0) :=
      std_logic_vector(to_unsigned(HDR_SIZE + TRL_SIZE, PAGE_RAM_ADDR_WIDTH)) &
      std_logic_vector(to_unsigned(0, PAGE_RAM_ADDR_WIDTH));
  begin
    wait until rising_edge(clk);
    loop
      wait until rising_edge(clk);
      wait for 1 ns;

      if rst = '1' then
        saw_spill_update := false;
        saw_meta_update := false;
        next;
      end if;

      if update_ftable_valid = "11" then
        saw_spill_update := true;
        assert update_ftable_tindex(0) = to_unsigned(4, TILE_ID_WIDTH)
          report "spill: expected head tile 4" severity failure;
        assert update_ftable_tindex(1) = to_unsigned(1, TILE_ID_WIDTH)
          report "spill: expected expand tile 1 (skip rseg=0)" severity failure;
        assert update_ftable_trltl_valid(0) = '1' severity failure;
        assert update_ftable_trltl(0) = to_unsigned(1, TILE_ID_WIDTH) severity failure;
        assert update_ftable_bdytl_valid(1) = '1' severity failure;
        assert update_ftable_bdytl(1) = to_unsigned(4, TILE_ID_WIDTH) severity failure;
        assert flush_ftable_valid(1) = '1' severity failure;
      end if;

      if (update_ftable_valid = "01") and (update_ftable_meta_valid(0) = '1') then
        saw_meta_update := true;
        assert update_ftable_tindex(0) = to_unsigned(4, TILE_ID_WIDTH)
          report "meta: expected tile 4 (frame0)" severity failure;
        assert update_ftable_meta(0) = EXP_META_FRAME0
          report "meta payload mismatch" severity failure;
        assert update_ftable_hcmpl(0) = '1' severity failure;
      end if;

      if saw_spill_update and saw_meta_update then
        -- let stim finish
        null;
      end if;
    end loop;
  end process;
end architecture tb;


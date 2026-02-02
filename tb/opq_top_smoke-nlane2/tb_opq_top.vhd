library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_top is
end entity tb_opq_top;

architecture tb of tb_opq_top is
  constant N_LANE : positive := 2;
  constant N_TILE : positive := 5;
  constant N_WR_SEG : positive := 4;
  constant N_SHD : positive := 2;
  constant CHANNEL_WIDTH : positive := 1; -- log2(N_LANE)

  constant INGRESS_DATA_WIDTH  : positive := 32;
  constant INGRESS_DATAK_WIDTH : positive := 4;

  constant LANE_FIFO_DEPTH   : positive := 64;
  constant LANE_FIFO_WIDTH   : positive := 40;
  constant TICKET_FIFO_DEPTH : positive := 64;
  constant HANDLE_FIFO_DEPTH : positive := 64;

  constant PAGE_RAM_DEPTH      : positive := 512;
  constant PAGE_RAM_DATA_WIDTH : positive := 40;

  constant HDR_SIZE : positive := 5;
  constant SHD_SIZE : positive := 1;
  constant HIT_SIZE : positive := 1;
  constant TRL_SIZE : positive := 1;
  constant N_HIT    : positive := 255;

  constant FRAME_SERIAL_SIZE   : positive := 16;
  constant FRAME_SUBH_CNT_SIZE : positive := 16;
  constant FRAME_HIT_CNT_SIZE  : positive := 16;
  constant SHD_CNT_WIDTH : positive := 16;
  constant HIT_CNT_WIDTH : positive := 16;

  constant TILE_FIFO_DEPTH    : positive := 64;
  constant TILE_PKT_CNT_WIDTH : positive := 10;
  constant EGRESS_DELAY       : natural := 2;

  constant CLK_PERIOD : time := 4 ns;

  constant K285 : std_logic_vector(7 downto 0) := x"BC";
  constant K284 : std_logic_vector(7 downto 0) := x"9C";
  constant K237 : std_logic_vector(7 downto 0) := x"F7";

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal ingress_data : slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => (others => '0'));
  signal ingress_valid : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_channel : slv_array_t(0 to N_LANE-1)(CHANNEL_WIDTH-1 downto 0) := (others => (others => '0'));
  signal ingress_sop : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_eop : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_err : slv_array_t(0 to N_LANE-1)(2 downto 0) := (others => (others => '0'));

  signal egress_ready : std_logic := '1';
  signal egress_valid : std_logic;
  signal egress_data  : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
  signal egress_sop   : std_logic;
  signal egress_eop   : std_logic;

  signal trim_drop_active : std_logic_vector(N_LANE-1 downto 0);
  signal wr_blocked_by_rd_lock : std_logic;

  function mk_preamble(dt_type : std_logic_vector(5 downto 0); feb_id : std_logic_vector(15 downto 0)) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(31 downto 26) := dt_type;
    d(23 downto 8) := feb_id;
    d(7 downto 0) := K285;
    return d;
  end function;

  function mk_trailer return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(7 downto 0) := K284;
    return d;
  end function;

  function mk_subheader(shd_ts : natural; hit_cnt : natural) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(31 downto 24) := std_logic_vector(to_unsigned(shd_ts, 8));
    d(15 downto 8) := std_logic_vector(to_unsigned(hit_cnt, 8));
    d(7 downto 0) := K237;
    return d;
  end function;

  function mk_word32(w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0000";
    d(31 downto 0) := w;
    return d;
  end function;

  function mk_hit(payload : natural) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0000";
    d(31 downto 0) := std_logic_vector(to_unsigned(payload, 32));
    return d;
  end function;

  procedure drive_all_lanes(
    signal data_s  : out slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    signal valid_s : out std_logic_vector(N_LANE-1 downto 0);
    signal sop_s   : out std_logic_vector(N_LANE-1 downto 0);
    signal eop_s   : out std_logic_vector(N_LANE-1 downto 0);
    d0 : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    d1 : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    v  : std_logic;
    sop : std_logic;
    eop : std_logic
  ) is
  begin
    data_s(0) <= d0;
    data_s(1) <= d1;
    valid_s <= (others => v);
    sop_s <= (others => sop);
    eop_s <= (others => eop);
  end procedure;

begin
  clk <= not clk after CLK_PERIOD/2;

  -- Use stable channel IDs.
  ingress_channel(0) <= (others => '0');
  ingress_channel(1) <= (others => '1');

  dut : entity work.opq_top
    generic map (
      N_LANE => N_LANE,
      N_TILE => N_TILE,
      N_WR_SEG => N_WR_SEG,
      N_SHD => N_SHD,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      INGRESS_DATA_WIDTH => INGRESS_DATA_WIDTH,
      INGRESS_DATAK_WIDTH => INGRESS_DATAK_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
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
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH,
      EGRESS_DELAY => EGRESS_DELAY
    )
    port map (
      i_clk => clk,
      i_rst => rst,

      i_ingress_data => ingress_data,
      i_ingress_valid => ingress_valid,
      i_ingress_channel => ingress_channel,
      i_ingress_startofpacket => ingress_sop,
      i_ingress_endofpacket => ingress_eop,
      i_ingress_error => ingress_err,

      i_egress_ready => egress_ready,
      o_egress_valid => egress_valid,
      o_egress_data => egress_data,
      o_egress_startofpacket => egress_sop,
      o_egress_endofpacket => egress_eop,

      i_avs_address => (others => '0'),
      i_avs_read => '0',
      o_avs_readdata => open,
      o_avs_waitrequest => open,
      o_avs_readdatavalid => open,

      o_trim_drop_active => trim_drop_active,
      o_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock
    );

  stim : process is
    constant dt_type_c : std_logic_vector(5 downto 0) := "000001";
    constant feb_id_c  : std_logic_vector(15 downto 0) := x"1234";
    constant hit_per_shd : natural := 2;
    constant hits_per_lane_per_frame : natural := N_SHD * hit_per_shd;
    constant exp_words : natural := HDR_SIZE + N_SHD*(SHD_SIZE + N_LANE*hit_per_shd) + TRL_SIZE;

    variable in_pkt : boolean := false;
    variable word_idx : natural := 0;
    variable got_pkt : boolean := false;
    variable k237_seen : natural := 0;
  begin
    rst <= '1';
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, (others => '0'), (others => '0'), '0', '0', '0');
    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;
    rst <= '0';
    -- Allow one clean cycle for all DUT sub-state-machines to leave RESET.
    wait until rising_edge(clk);

    -- Frame 0 header (SOP ticket generation).
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_preamble(dt_type_c, feb_id_c), mk_preamble(dt_type_c, feb_id_c), '1', '1', '0');
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- header0 ts[47:16]
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- header1 ts[15:0]=0, serial=0 (packed into low 16 via parser)
    ingress_data(0)(15 downto 0) <= x"0000";
    ingress_data(1)(15 downto 0) <= x"0000";
    ingress_data(0)(31 downto 16) <= x"0000";
    ingress_data(1)(31 downto 16) <= x"0000";
    wait until rising_edge(clk);
    drive_all_lanes(
      ingress_data, ingress_valid, ingress_sop, ingress_eop,
      mk_word32(std_logic_vector(to_unsigned(N_SHD, 16)) & std_logic_vector(to_unsigned(hits_per_lane_per_frame, 16))),
      mk_word32(std_logic_vector(to_unsigned(N_SHD, 16)) & std_logic_vector(to_unsigned(hits_per_lane_per_frame, 16))),
      '1', '0', '0'
    ); -- debug0 {n_subh, n_hit_lane}
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- debug1
    wait until rising_edge(clk);
    ingress_valid <= (others => '0');

    -- Frame 0 subheaders: use absolute shd_ts = serial*N_SHD + s.
    for s in 0 to N_SHD-1 loop
      -- subheader marker
      drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_subheader(s, hit_per_shd), mk_subheader(s, hit_per_shd), '1', '1', '0');
      wait until rising_edge(clk);
      ingress_sop <= (others => '0');
      -- hits (2 words, same count per lane to keep ticket writes aligned)
      for h in 0 to hit_per_shd-1 loop
        drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_hit(16#1000# + s*16 + h), mk_hit(16#2000# + s*16 + h), '1', '0', '0');
        if h = hit_per_shd-1 then
          ingress_eop <= (others => '1');
        end if;
        wait until rising_edge(clk);
        ingress_eop <= (others => '0');
      end loop;
      ingress_valid <= (others => '0');
      wait until rising_edge(clk);
    end loop;

    -- Trailer marker ends the frame.
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_trailer, mk_trailer, '1', '1', '1');
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, (others => '0'), (others => '0'), '0', '0', '0');

    -- Frame 1 header only (flushes frame 0 tail/trailer).
    for i in 0 to 10 loop
      wait until rising_edge(clk);
    end loop;

    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_preamble(dt_type_c, feb_id_c), mk_preamble(dt_type_c, feb_id_c), '1', '1', '0');
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- header0
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- header1
    ingress_data(0)(15 downto 0) <= x"0001";
    ingress_data(1)(15 downto 0) <= x"0001";
    ingress_data(0)(31 downto 16) <= x"0000";
    ingress_data(1)(31 downto 16) <= x"0000";
    wait until rising_edge(clk);
    drive_all_lanes(
      ingress_data, ingress_valid, ingress_sop, ingress_eop,
      mk_word32(std_logic_vector(to_unsigned(N_SHD, 16)) & std_logic_vector(to_unsigned(hits_per_lane_per_frame, 16))),
      mk_word32(std_logic_vector(to_unsigned(N_SHD, 16)) & std_logic_vector(to_unsigned(hits_per_lane_per_frame, 16))),
      '1', '0', '0'
    ); -- debug0
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, mk_word32(x"00000000"), mk_word32(x"00000000"), '1', '0', '0'); -- debug1
    wait until rising_edge(clk);
    drive_all_lanes(ingress_data, ingress_valid, ingress_sop, ingress_eop, (others => '0'), (others => '0'), '0', '0', '0');

    -- Observe the first egress packet (frame 0).
    for cyc in 0 to 4000 loop
      wait until rising_edge(clk);

      if (egress_valid = '1') and (egress_ready = '1') then
        if egress_sop = '1' then
          in_pkt := true;
          word_idx := 0;
          k237_seen := 0;
        end if;

        if in_pkt then
          if word_idx = 0 then
            assert egress_data(35 downto 32) = "0001" report "Egress word0 not K-word" severity failure;
            assert egress_data(7 downto 0) = K285 report "Egress word0 not K285" severity failure;
            assert egress_data(31 downto 26) = dt_type_c report "Egress dt_type mismatch" severity failure;
            assert egress_data(23 downto 8) = feb_id_c report "Egress feb_id mismatch" severity failure;
          end if;

          if (egress_data(35 downto 32) = "0001") and (egress_data(7 downto 0) = K237) then
            k237_seen := k237_seen + 1;
          end if;

          if egress_eop = '1' then
            assert egress_data(35 downto 32) = "0001" report "Egress last word not K-word" severity failure;
            assert egress_data(7 downto 0) = K284 report "Egress last word not K284" severity failure;
            assert word_idx + 1 = exp_words report "Unexpected egress packet length" severity failure;
            assert k237_seen = N_SHD report "Unexpected number of K237 subheaders in egress" severity failure;
            got_pkt := true;
            exit;
          end if;

          word_idx := word_idx + 1;
        end if;
      end if;
    end loop;

    assert got_pkt report "Did not observe a complete egress packet" severity failure;

    report "tb_opq_top: PASS" severity note;
    finish;
  end process;
end architecture tb;

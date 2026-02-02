library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_ingress_parser is
end entity tb_opq_ingress_parser;

architecture tb of tb_opq_ingress_parser is
  constant N_LANE : positive := 1;
  constant INGRESS_DATA_WIDTH  : positive := 32;
  constant INGRESS_DATAK_WIDTH : positive := 4;
  constant CHANNEL_WIDTH : positive := 2;

  constant LANE_FIFO_DEPTH : positive := 32;
  constant LANE_FIFO_WIDTH : positive := 40;
  constant TICKET_FIFO_DEPTH : positive := 16;

  constant HIT_SIZE : positive := 1;
  constant N_HIT    : positive := 4;
  constant MAX_PKT_LENGTH_BITS : natural := clog2(HIT_SIZE*N_HIT);
  constant N_HIT_SAT : natural := imin(N_HIT, 2**MAX_PKT_LENGTH_BITS - 1);

  constant FRAME_SERIAL_SIZE   : positive := 16;
  constant FRAME_SUBH_CNT_SIZE : positive := 16;
  constant FRAME_HIT_CNT_SIZE  : positive := 16;

  constant TICKET_FIFO_DATA_WIDTH : natural := imax(
    48 + clog2(LANE_FIFO_DEPTH) + clog2(HIT_SIZE*N_HIT) + 2,
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2
  );

  constant LANE_ADDR_W  : natural := clog2(LANE_FIFO_DEPTH);
  constant TICKET_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);

  constant CLK_PERIOD : time := 10 ns;

  constant K237 : std_logic_vector(7 downto 0) := x"F7";
  constant K285 : std_logic_vector(7 downto 0) := x"BC";
  constant K284 : std_logic_vector(7 downto 0) := x"9C";

  constant TICKET_ALT_EOP_LOC : natural := TICKET_FIFO_DATA_WIDTH - 2;
  constant TICKET_ALT_SOP_LOC : natural := TICKET_FIFO_DATA_WIDTH - 1;
  constant TICKET_SERIAL_LO : natural := 0;
  constant TICKET_SERIAL_HI : natural := FRAME_SERIAL_SIZE-1;
  constant TICKET_N_SUBH_LO : natural := FRAME_SERIAL_SIZE;
  constant TICKET_N_SUBH_HI : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  constant TICKET_N_HIT_LO  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  constant TICKET_N_HIT_HI  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;
  constant TICKET_BLOCK_LEN_LO : natural := 48 + LANE_ADDR_W;
  constant TICKET_BLOCK_LEN_HI : natural := 48 + LANE_ADDR_W + MAX_PKT_LENGTH_BITS - 1;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal ingress_data : slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => (others => '0'));
  signal ingress_valid : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_channel : slv_array_t(0 to N_LANE-1)(CHANNEL_WIDTH-1 downto 0) := (others => (others => '0'));
  signal ingress_sop : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_eop : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ingress_err : slv_array_t(0 to N_LANE-1)(2 downto 0) := (others => (others => '0'));

  signal lane_credit_update_valid : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal lane_credit_update : unsigned_array_t(0 to N_LANE-1)(LANE_ADDR_W-1 downto 0) := (others => (others => '0'));
  signal ticket_credit_update_valid : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
  signal ticket_credit_update : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0) := (others => (others => '0'));

  signal lane_we : std_logic_vector(N_LANE-1 downto 0);
  signal lane_wptr : unsigned_array_t(0 to N_LANE-1)(LANE_ADDR_W-1 downto 0);
  signal lane_wdata : slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);
  signal lane_wr_addr : slv_array_t(0 to N_LANE-1)(LANE_ADDR_W-1 downto 0);

  signal ticket_we : std_logic_vector(N_LANE-1 downto 0);
  signal ticket_wptr : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);
  signal ticket_wdata : slv_array_t(0 to N_LANE-1)(TICKET_FIFO_DATA_WIDTH-1 downto 0);
  signal ticket_wr_addr : slv_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);

  signal trim_drop : std_logic_vector(N_LANE-1 downto 0);

  signal lane_writes_s  : natural := 0;
  signal ticket_writes_s : natural := 0;
  signal sop_ticket_writes_s : natural := 0;
  signal subh_ticket_writes_s : natural := 0;

  function mk_preamble return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(7 downto 0) := K285;
    return d;
  end function;

  function mk_word32(w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0000";
    d(31 downto 0) := w;
    return d;
  end function;

  function mk_subheader(hit_cnt : natural) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(35 downto 32) := "0001";
    d(7 downto 0) := K237;
    d(15 downto 8) := std_logic_vector(to_unsigned(hit_cnt, 8));
    return d;
  end function;

  function mk_hit(word : natural) return std_logic_vector is
    variable d : std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0) := (others => '0');
  begin
    d(31 downto 0) := std_logic_vector(to_unsigned(word, 32));
    d(35 downto 32) := "0000";
    return d;
  end function;

begin
  clk <= not clk after CLK_PERIOD/2;

  monitor : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        lane_writes_s  <= 0;
        ticket_writes_s <= 0;
        sop_ticket_writes_s <= 0;
        subh_ticket_writes_s <= 0;
      else
        if lane_we(0) = '1' then
          lane_writes_s <= lane_writes_s + 1;
        end if;
        if ticket_we(0) = '1' then
          ticket_writes_s <= ticket_writes_s + 1;
          if ticket_wdata(0)(TICKET_ALT_SOP_LOC) = '1' then
            sop_ticket_writes_s <= sop_ticket_writes_s + 1;
            assert lane_we(0) = '0' report "SOP ticket write must not coincide with lane FIFO hit write" severity failure;
            assert ticket_wdata(0)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO) = x"1234"
              report "SOP ticket serial mismatch" severity failure;
            assert unsigned(ticket_wdata(0)(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO)) = to_unsigned(1, FRAME_SUBH_CNT_SIZE)
              report "SOP ticket n_subh mismatch" severity failure;
            assert unsigned(ticket_wdata(0)(TICKET_N_HIT_HI downto TICKET_N_HIT_LO)) = to_unsigned(6, FRAME_HIT_CNT_SIZE)
              report "SOP ticket n_hit mismatch" severity failure;
            assert ticket_wdata(0)(TICKET_ALT_EOP_LOC) = '0'
              report "Unexpected ALT_EOP in SOP ticket" severity failure;
          else
            subh_ticket_writes_s <= subh_ticket_writes_s + 1;
            assert lane_we(0) = '1' report "Subheader ticket must coincide with last kept hit write" severity failure;
            assert lane_wdata(0)(36) = '1' report "lane FIFO EOP delimiter (bit36) not set on last kept hit" severity failure;
            assert unsigned(ticket_wdata(0)(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO)) = to_unsigned(N_HIT_SAT, MAX_PKT_LENGTH_BITS)
              report "Subheader ticket block_length mismatch" severity failure;
          end if;
        end if;
      end if;
    end if;
  end process;

  dut : entity work.opq_ingress_parser
    generic map (
      N_LANE => N_LANE,
      INGRESS_DATA_WIDTH => INGRESS_DATA_WIDTH,
      INGRESS_DATAK_WIDTH => INGRESS_DATAK_WIDTH,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
      TICKET_FIFO_DEPTH => TICKET_FIFO_DEPTH,
      HIT_SIZE => HIT_SIZE,
      N_HIT => N_HIT,
      FRAME_SERIAL_SIZE => FRAME_SERIAL_SIZE,
      FRAME_SUBH_CNT_SIZE => FRAME_SUBH_CNT_SIZE,
      FRAME_HIT_CNT_SIZE => FRAME_HIT_CNT_SIZE,
      TICKET_FIFO_DATA_WIDTH => TICKET_FIFO_DATA_WIDTH
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

      i_lane_credit_update_valid => lane_credit_update_valid,
      i_lane_credit_update => lane_credit_update,
      i_ticket_credit_update_valid => ticket_credit_update_valid,
      i_ticket_credit_update => ticket_credit_update,

      o_lane_we => lane_we,
      o_lane_wptr => lane_wptr,
      o_lane_wdata => lane_wdata,
      o_lane_wr_addr => lane_wr_addr,

      o_ticket_we => ticket_we,
      o_ticket_wptr => ticket_wptr,
      o_ticket_wdata => ticket_wdata,
      o_ticket_wr_addr => ticket_wr_addr,

      o_trim_drop_active => trim_drop
    );

  stim : process is
  begin
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    -- One clean cycle after reset deassertion.
    wait until rising_edge(clk);

    -- Preamble + 4-word header parse to generate SOP ticket.
    ingress_valid(0) <= '1';
    ingress_sop(0) <= '1';
    ingress_eop(0) <= '0';
    ingress_data(0) <= mk_preamble;
    wait until rising_edge(clk);
    ingress_sop(0) <= '0';

    -- header0: ts[47:16]
    ingress_data(0) <= mk_word32(x"00000000");
    wait until rising_edge(clk);

    -- header1: ts[15:0] + serial (low 16)
    ingress_data(0) <= mk_word32(x"00001234"); -- ts_lo=0x0000, serial=0x1234
    wait until rising_edge(clk);

    -- debug0: n_subh + n_hit
    ingress_data(0) <= mk_word32(x"00010006"); -- n_subh=1, n_hit=6
    wait until rising_edge(clk);

    -- debug1: unused
    ingress_data(0) <= mk_word32(x"00000000");
    wait until rising_edge(clk);

    -- Subheader declaring 6 hits; expect trimming down to N_HIT_SAT.
    ingress_data(0) <= mk_subheader(6);
    ingress_sop(0) <= '1';
    wait until rising_edge(clk);
    ingress_sop(0) <= '0';

    -- 6 hit words; only N_HIT_SAT should be written to lane FIFO.
    for i in 0 to 5 loop
      ingress_data(0) <= mk_hit(i);
      ingress_valid(0) <= '1';
      ingress_eop(0) <= '0';
      if i = 5 then
        ingress_eop(0) <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    ingress_valid(0) <= '0';
    ingress_eop(0) <= '0';
    ingress_data(0) <= (others => '0');

    -- Optional trailer marker (should attach ALT_EOP to the *next* SOP ticket).
    ingress_valid(0) <= '1';
    ingress_sop(0) <= '1';
    ingress_eop(0) <= '1';
    ingress_data(0)(35 downto 32) <= "0001";
    ingress_data(0)(7 downto 0) <= K284;
    wait until rising_edge(clk);
    ingress_valid(0) <= '0';
    ingress_sop(0) <= '0';
    ingress_eop(0) <= '0';

    -- Let the DUT drain.
    for i in 0 to 20 loop
      wait until rising_edge(clk);
    end loop;

    assert lane_writes_s = N_HIT_SAT report "Expected trimmed lane writes = N_HIT_SAT" severity failure;
    assert ticket_writes_s = 2 report "Expected SOP ticket + one subheader ticket" severity failure;
    assert sop_ticket_writes_s = 1 report "Expected exactly one SOP ticket write" severity failure;
    assert subh_ticket_writes_s = 1 report "Expected exactly one subheader ticket write" severity failure;

    report "tb_opq_ingress_parser: PASS" severity note;
    finish;
  end process;
end architecture tb;

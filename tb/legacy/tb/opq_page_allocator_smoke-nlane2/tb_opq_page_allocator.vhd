library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

library std;
use std.env.all;

entity tb_opq_page_allocator is
end entity tb_opq_page_allocator;

architecture tb of tb_opq_page_allocator is
  constant N_LANE : positive := 2;
  constant N_SHD  : positive := 4;
  constant CHANNEL_WIDTH : positive := 1; -- log2(N_LANE)

  constant LANE_FIFO_DEPTH   : positive := 32;
  constant TICKET_FIFO_DEPTH : positive := 16;
  constant HANDLE_FIFO_DEPTH : positive := 16;
  constant PAGE_RAM_DEPTH    : positive := 256;
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

  constant LANE_ADDR_W   : natural := clog2(LANE_FIFO_DEPTH);
  constant TICKET_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);
  constant HANDLE_ADDR_W : natural := clog2(HANDLE_FIFO_DEPTH);
  constant PAGE_ADDR_W   : natural := clog2(PAGE_RAM_DEPTH);
  constant MAX_PKT_LENGTH_BITS : natural := clog2(HIT_SIZE*N_HIT);
  constant HANDLE_LENGTH : natural := LANE_ADDR_W + PAGE_ADDR_W + MAX_PKT_LENGTH_BITS;
  constant HANDLE_DST_LO : natural := LANE_ADDR_W;
  constant HANDLE_DST_HI : natural := LANE_ADDR_W + PAGE_ADDR_W - 1;

  constant TICKET_W : natural := imax(
    48 + clog2(LANE_FIFO_DEPTH) + clog2(HIT_SIZE*N_HIT) + 2,
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2
  );

  constant TICKET_LENGTH : natural := TICKET_W;
  constant TICKET_TS_LO  : natural := 0;
  constant TICKET_TS_HI  : natural := 47;
  constant TICKET_LANE_RD_OFST_LO : natural := 48;
  constant TICKET_LANE_RD_OFST_HI : natural := 48 + LANE_ADDR_W - 1;
  constant TICKET_BLOCK_LEN_LO : natural := 48 + LANE_ADDR_W;
  constant TICKET_BLOCK_LEN_HI : natural := 48 + LANE_ADDR_W + MAX_PKT_LENGTH_BITS - 1;

  constant TICKET_SERIAL_LO : natural := 0;
  constant TICKET_SERIAL_HI : natural := FRAME_SERIAL_SIZE-1;
  constant TICKET_N_SUBH_LO : natural := FRAME_SERIAL_SIZE;
  constant TICKET_N_SUBH_HI : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  constant TICKET_N_HIT_LO  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  constant TICKET_N_HIT_HI  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;

  constant TICKET_ALT_EOP_LOC : natural := TICKET_LENGTH - 2;
  constant TICKET_ALT_SOP_LOC : natural := TICKET_LENGTH - 1;

  constant K285 : std_logic_vector(7 downto 0) := x"BC";
  constant K284 : std_logic_vector(7 downto 0) := x"9C";
  constant K237 : std_logic_vector(7 downto 0) := x"F7";

  constant CLK_PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal dt_type : std_logic_vector(5 downto 0) := "101010";
  signal feb_id  : std_logic_vector(15 downto 0) := x"1234";

  signal ticket_wptr : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0) := (others => (others => '0'));
  signal ticket_rd_addr : slv_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);
  signal ticket_rd_data : slv_array_t(0 to N_LANE-1)(TICKET_W-1 downto 0);

  signal ticket_credit_update_valid : std_logic_vector(N_LANE-1 downto 0);
  signal ticket_credit_update : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);

  signal handle_we : std_logic_vector(N_LANE-1 downto 0);
  signal handle_wptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);
  signal handle_wdata : slv_array_t(0 to N_LANE-1)(HANDLE_LENGTH downto 0);
  signal handle_wr_addr : slv_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);

  signal handle_rptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);

  signal page_we : std_logic;
  signal page_waddr : std_logic_vector(PAGE_ADDR_W-1 downto 0);
  signal page_wdata : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

  signal pa_write_head_start : std_logic;
  signal pa_frame_start_addr : unsigned(PAGE_ADDR_W-1 downto 0);
  signal pa_frame_shr_cnt_this : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt_this : unsigned(HIT_CNT_WIDTH-1 downto 0);

  signal pa_write_tail_done : std_logic;
  signal pa_write_tail_active : std_logic;
  signal pa_frame_start_addr_last : unsigned(PAGE_ADDR_W-1 downto 0);
  signal pa_frame_shr_cnt : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt : unsigned(HIT_CNT_WIDTH-1 downto 0);
  signal pa_frame_invalid_last : std_logic;
  signal pa_handle_wptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);

  signal quantum_update : std_logic_vector(N_LANE-1 downto 0);

  type ticket_mem_t is array (0 to TICKET_FIFO_DEPTH-1) of std_logic_vector(TICKET_W-1 downto 0);
  signal ticket_mem0 : ticket_mem_t := (others => (others => '0'));
  signal ticket_mem1 : ticket_mem_t := (others => (others => '0'));

  function mk_sop_ticket(
    serial : natural;
    n_subh : natural;
    n_hit  : natural;
    alert_eop : std_logic
  ) return std_logic_vector is
    variable d : std_logic_vector(TICKET_W-1 downto 0) := (others => '0');
  begin
    d(TICKET_SERIAL_HI downto TICKET_SERIAL_LO) := std_logic_vector(to_unsigned(serial, FRAME_SERIAL_SIZE));
    d(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO) := std_logic_vector(to_unsigned(n_subh, FRAME_SUBH_CNT_SIZE));
    d(TICKET_N_HIT_HI downto TICKET_N_HIT_LO) := std_logic_vector(to_unsigned(n_hit, FRAME_HIT_CNT_SIZE));
    d(TICKET_ALT_SOP_LOC) := '1';
    d(TICKET_ALT_EOP_LOC) := alert_eop;
    return d;
  end function;

  function mk_shd_ticket(
    ts : natural;
    lane_ofst : natural;
    blk_len : natural
  ) return std_logic_vector is
    variable d : std_logic_vector(TICKET_W-1 downto 0) := (others => '0');
  begin
    d(TICKET_TS_HI downto TICKET_TS_LO) := std_logic_vector(to_unsigned(ts, 48));
    d(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO) := std_logic_vector(to_unsigned(lane_ofst, LANE_ADDR_W));
    d(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO) := std_logic_vector(to_unsigned(blk_len, MAX_PKT_LENGTH_BITS));
    d(TICKET_ALT_SOP_LOC) := '0';
    d(TICKET_ALT_EOP_LOC) := '0';
    return d;
  end function;
begin
  clk <= not clk after CLK_PERIOD/2;

  -- Show-ahead ticket memories.
  proc_ticket_mem : process (all) is
    variable a0 : natural;
    variable a1 : natural;
  begin
    a0 := to_integer(unsigned(ticket_rd_addr(0)));
    a1 := to_integer(unsigned(ticket_rd_addr(1)));
    ticket_rd_data(0) <= ticket_mem0(a0);
    ticket_rd_data(1) <= ticket_mem1(a1);
  end process;

  -- Simulate movers draining handles immediately.
  handle_rptr <= handle_wptr;

  dut : entity work.opq_page_allocator
    generic map (
      MODE => "MERGING",
      N_LANE => N_LANE,
      N_SHD => N_SHD,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
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
      TICKET_FIFO_DATA_WIDTH => TICKET_W
    )
    port map (
      i_clk => clk,
      i_rst => rst,
      i_dt_type => dt_type,
      i_feb_id => feb_id,

      i_ticket_wptr => ticket_wptr,
      o_ticket_rd_addr => ticket_rd_addr,
      i_ticket_rd_data => ticket_rd_data,

      o_ticket_credit_update_valid => ticket_credit_update_valid,
      o_ticket_credit_update => ticket_credit_update,

      o_handle_we => handle_we,
      o_handle_wptr => handle_wptr,
      o_handle_wdata => handle_wdata,
      o_handle_wr_addr => handle_wr_addr,

      i_handle_rptr => handle_rptr,
      i_mover_busy => (others => '0'),

      o_alloc_page_we => page_we,
      o_alloc_page_waddr => page_waddr,
      o_alloc_page_wdata => page_wdata,

      o_pa_write_head_start => pa_write_head_start,
      o_pa_frame_start_addr => pa_frame_start_addr,
      o_pa_frame_shr_cnt_this => pa_frame_shr_cnt_this,
      o_pa_frame_hit_cnt_this => pa_frame_hit_cnt_this,
      o_pa_write_tail_done => pa_write_tail_done,
      o_pa_write_tail_active => pa_write_tail_active,
      o_pa_frame_start_addr_last => pa_frame_start_addr_last,
      o_pa_frame_shr_cnt => pa_frame_shr_cnt,
      o_pa_frame_hit_cnt => pa_frame_hit_cnt,
      o_pa_frame_invalid_last => pa_frame_invalid_last,
      o_pa_handle_wptr => pa_handle_wptr,
      o_quantum_update => quantum_update,
      i_wr_blocked_by_rd_lock => '0'
    );

  monitor : process (clk) is
    variable handle_cnt : natural := 0;
    variable shd_seen : boolean := false;
    variable trl_seen : boolean := false;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        handle_cnt := 0;
        shd_seen := false;
        trl_seen := false;
      else
        for i in 0 to N_LANE-1 loop
          if handle_we(i) = '1' then
            if handle_cnt = 0 then
              assert unsigned(handle_wdata(i)(HANDLE_DST_HI downto HANDLE_DST_LO)) = to_unsigned(6, PAGE_ADDR_W)
                report "lane0 dst mismatch for first subheader" severity failure;
            elsif handle_cnt = 1 then
              assert unsigned(handle_wdata(i)(HANDLE_DST_HI downto HANDLE_DST_LO)) = to_unsigned(9, PAGE_ADDR_W)
                report "lane1 dst mismatch for first subheader" severity failure;
            end if;
            handle_cnt := handle_cnt + 1;
          end if;
        end loop;

        if page_we = '1' then
          if (page_wdata(35 downto 32) = "0001") and (page_wdata(7 downto 0) = K237) then
            shd_seen := true;
            assert unsigned(page_waddr) = to_unsigned(5, PAGE_ADDR_W) report "subheader addr mismatch" severity failure;
          end if;
          if (page_wdata(35 downto 32) = "0001") and (page_wdata(7 downto 0) = K284) then
            trl_seen := true;
            assert unsigned(page_waddr) = to_unsigned(11, PAGE_ADDR_W) report "trailer addr mismatch" severity failure;
          end if;
        end if;

        if trl_seen and shd_seen then
          report "tb_opq_page_allocator: PASS" severity note;
          finish;
        end if;
      end if;
    end if;
  end process;

  stim : process is
  begin
    -- Preload tickets: [SOP0, SHD0, SOP1, SHD1]
    ticket_mem0(0) <= mk_sop_ticket(0, N_SHD*N_LANE, 0, '0');
    ticket_mem1(0) <= mk_sop_ticket(0, N_SHD*N_LANE, 0, '0');

    -- Subheader 0 (ts=0): lane0 has 3 hits, lane1 has 2 hits.
    ticket_mem0(1) <= mk_shd_ticket(0, 0, 3);
    ticket_mem1(1) <= mk_shd_ticket(0, 0, 2);

    -- SOP1 triggers writing previous tail/trailer.
    ticket_mem0(2) <= mk_sop_ticket(1, N_SHD*N_LANE, 0, '1');
    ticket_mem1(2) <= mk_sop_ticket(1, N_SHD*N_LANE, 0, '1');

    -- Subheader 1 (ts=64): keep it small.
    ticket_mem0(3) <= mk_shd_ticket(64, 0, 1);
    ticket_mem1(3) <= mk_shd_ticket(64, 0, 1);

    ticket_wptr(0) <= to_unsigned(4, TICKET_ADDR_W);
    ticket_wptr(1) <= to_unsigned(4, TICKET_ADDR_W);

    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    -- Let it run.
    for i in 0 to 500 loop
      wait until rising_edge(clk);
    end loop;
    assert false report "timeout" severity failure;
  end process;
end architecture tb;


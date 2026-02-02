-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_page_allocator_uvm_wrapper
-- Author:              Codex (UVM wrapper for OPQ split)
-- Revision:            0.1 - mixed-language UVM support
-- Description:         Flattened VHDL wrapper around `work.opq_page_allocator` for SystemVerilog/UVM tests.
--                      Converts array ports to packed vectors for easier SV connectivity.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

-- VHDL wrapper to flatten array ports for SV/UVM.
entity opq_page_allocator_uvm_wrapper is
  generic (
    N_LANE : positive := 2;
    N_SHD  : positive := 8;
    CHANNEL_WIDTH : positive := 1;

    LANE_FIFO_DEPTH   : positive := 32;
    TICKET_FIFO_DEPTH : positive := 512;
    HANDLE_FIFO_DEPTH : positive := 512;
    PAGE_RAM_DEPTH    : positive := 1024;

    PAGE_RAM_DATA_WIDTH : positive := 40;
    HDR_SIZE : positive := 5;
    SHD_SIZE : positive := 1;
    HIT_SIZE : positive := 1;
    TRL_SIZE : positive := 1;
    N_HIT    : positive := 255;

    FRAME_SERIAL_SIZE   : positive := 16;
    FRAME_SUBH_CNT_SIZE : positive := 16;
    FRAME_HIT_CNT_SIZE  : positive := 16;

    SHD_CNT_WIDTH : positive := 16;
    HIT_CNT_WIDTH : positive := 16
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    i_dt_type : in std_logic_vector(5 downto 0);
    i_feb_id  : in std_logic_vector(15 downto 0);

    i_ticket_wptr_flat    : in  std_logic_vector(N_LANE*clog2(TICKET_FIFO_DEPTH)-1 downto 0);
    o_ticket_rd_addr_flat : out std_logic_vector(N_LANE*clog2(TICKET_FIFO_DEPTH)-1 downto 0);
    i_ticket_rd_data_flat : in  std_logic_vector(N_LANE*imax(
      48 + clog2(LANE_FIFO_DEPTH) + clog2(HIT_SIZE*N_HIT) + 2,
      FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2
    )-1 downto 0);

    o_ticket_credit_update_valid : out std_logic_vector(N_LANE-1 downto 0);
    o_ticket_credit_update_flat  : out std_logic_vector(N_LANE*clog2(TICKET_FIFO_DEPTH)-1 downto 0);

    o_handle_we      : out std_logic_vector(N_LANE-1 downto 0);
    o_handle_wptr_flat : out std_logic_vector(N_LANE*clog2(HANDLE_FIFO_DEPTH)-1 downto 0);
    o_handle_wdata_flat : out std_logic_vector(N_LANE*(clog2(LANE_FIFO_DEPTH) + clog2(PAGE_RAM_DEPTH) + clog2(HIT_SIZE*N_HIT) + 1)-1 downto 0);

    i_handle_rptr_flat : in std_logic_vector(N_LANE*clog2(HANDLE_FIFO_DEPTH)-1 downto 0);
    i_mover_busy       : in std_logic_vector(N_LANE-1 downto 0);

    o_page_we    : out std_logic;
    o_page_waddr : out std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_page_wdata : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    o_pa_write_head_start      : out std_logic;
    o_pa_frame_start_addr      : out std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_pa_frame_shr_cnt_this    : out std_logic_vector(SHD_CNT_WIDTH-1 downto 0);
    o_pa_frame_hit_cnt_this    : out std_logic_vector(HIT_CNT_WIDTH-1 downto 0);

    o_pa_write_tail_done       : out std_logic;
    o_pa_write_tail_active     : out std_logic;
    o_pa_frame_start_addr_last : out std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_pa_frame_shr_cnt         : out std_logic_vector(SHD_CNT_WIDTH-1 downto 0);
    o_pa_frame_hit_cnt         : out std_logic_vector(HIT_CNT_WIDTH-1 downto 0);
    o_pa_frame_invalid_last    : out std_logic;
    o_pa_handle_wptr_flat      : out std_logic_vector(N_LANE*clog2(HANDLE_FIFO_DEPTH)-1 downto 0);

    o_quantum_update : out std_logic_vector(N_LANE-1 downto 0);

    i_wr_blocked_by_rd_lock : in std_logic
  );
end entity opq_page_allocator_uvm_wrapper;

architecture rtl of opq_page_allocator_uvm_wrapper is
  constant TICKET_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);
  constant HANDLE_ADDR_W : natural := clog2(HANDLE_FIFO_DEPTH);
  constant PAGE_ADDR_W   : natural := clog2(PAGE_RAM_DEPTH);
  constant TICKET_W : natural := imax(
    48 + clog2(LANE_FIFO_DEPTH) + clog2(HIT_SIZE*N_HIT) + 2,
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2
  );
  constant HANDLE_W : natural := clog2(LANE_FIFO_DEPTH) + clog2(PAGE_RAM_DEPTH) + clog2(HIT_SIZE*N_HIT) + 1;

  signal ticket_wptr : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);
  signal ticket_rd_addr : slv_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);
  signal ticket_rd_data : slv_array_t(0 to N_LANE-1)(TICKET_W-1 downto 0);

  signal ticket_credit_update : unsigned_array_t(0 to N_LANE-1)(TICKET_ADDR_W-1 downto 0);

  signal handle_wptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);
  signal handle_wdata : slv_array_t(0 to N_LANE-1)(HANDLE_W-1 downto 0);
  signal handle_wr_addr : slv_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);
  signal handle_rptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_ADDR_W-1 downto 0);

  signal pa_frame_start_addr      : unsigned(PAGE_ADDR_W-1 downto 0);
  signal pa_frame_start_addr_last : unsigned(PAGE_ADDR_W-1 downto 0);
  signal pa_frame_shr_cnt_this    : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt_this    : unsigned(HIT_CNT_WIDTH-1 downto 0);
  signal pa_frame_shr_cnt         : unsigned(SHD_CNT_WIDTH-1 downto 0);
  signal pa_frame_hit_cnt         : unsigned(HIT_CNT_WIDTH-1 downto 0);
begin
  -- Unpack ticket_wptr/rd_data.
  gen_unpack : for i in 0 to N_LANE-1 generate
    ticket_wptr(i) <= unsigned(i_ticket_wptr_flat((i+1)*TICKET_ADDR_W-1 downto i*TICKET_ADDR_W));
    ticket_rd_data(i) <= i_ticket_rd_data_flat((i+1)*TICKET_W-1 downto i*TICKET_W);
    handle_rptr(i) <= unsigned(i_handle_rptr_flat((i+1)*HANDLE_ADDR_W-1 downto i*HANDLE_ADDR_W));

    o_ticket_rd_addr_flat((i+1)*TICKET_ADDR_W-1 downto i*TICKET_ADDR_W) <= ticket_rd_addr(i);
    o_ticket_credit_update_flat((i+1)*TICKET_ADDR_W-1 downto i*TICKET_ADDR_W) <= std_logic_vector(ticket_credit_update(i));
    o_handle_wptr_flat((i+1)*HANDLE_ADDR_W-1 downto i*HANDLE_ADDR_W) <= std_logic_vector(handle_wptr(i));
    o_pa_handle_wptr_flat((i+1)*HANDLE_ADDR_W-1 downto i*HANDLE_ADDR_W) <= std_logic_vector(handle_wptr(i));
    o_handle_wdata_flat((i+1)*HANDLE_W-1 downto i*HANDLE_W) <= handle_wdata(i);
  end generate;

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
      i_clk => i_clk,
      i_rst => i_rst,

      i_dt_type => i_dt_type,
      i_feb_id => i_feb_id,

      i_ticket_wptr => ticket_wptr,
      o_ticket_rd_addr => ticket_rd_addr,
      i_ticket_rd_data => ticket_rd_data,

      o_ticket_credit_update_valid => o_ticket_credit_update_valid,
      o_ticket_credit_update => ticket_credit_update,

      o_handle_we => o_handle_we,
      o_handle_wptr => handle_wptr,
      o_handle_wdata => handle_wdata,
      o_handle_wr_addr => handle_wr_addr,

      i_handle_rptr => handle_rptr,
      i_mover_busy => i_mover_busy,

      o_alloc_page_we => o_page_we,
      o_alloc_page_waddr => o_page_waddr,
      o_alloc_page_wdata => o_page_wdata,

      o_pa_write_head_start => o_pa_write_head_start,
      o_pa_frame_start_addr => pa_frame_start_addr,
      o_pa_frame_shr_cnt_this => pa_frame_shr_cnt_this,
      o_pa_frame_hit_cnt_this => pa_frame_hit_cnt_this,

      o_pa_write_tail_done => o_pa_write_tail_done,
      o_pa_write_tail_active => o_pa_write_tail_active,
      o_pa_frame_start_addr_last => pa_frame_start_addr_last,
      o_pa_frame_shr_cnt => pa_frame_shr_cnt,
      o_pa_frame_hit_cnt => pa_frame_hit_cnt,
      o_pa_frame_invalid_last => o_pa_frame_invalid_last,
      o_pa_handle_wptr => open,

      o_quantum_update => o_quantum_update,
      i_wr_blocked_by_rd_lock => i_wr_blocked_by_rd_lock
    );

  o_pa_frame_start_addr <= std_logic_vector(pa_frame_start_addr);
  o_pa_frame_start_addr_last <= std_logic_vector(pa_frame_start_addr_last);
  o_pa_frame_shr_cnt_this <= std_logic_vector(pa_frame_shr_cnt_this);
  o_pa_frame_hit_cnt_this <= std_logic_vector(pa_frame_hit_cnt_this);
  o_pa_frame_shr_cnt <= std_logic_vector(pa_frame_shr_cnt);
  o_pa_frame_hit_cnt <= std_logic_vector(pa_frame_hit_cnt);
end architecture rtl;

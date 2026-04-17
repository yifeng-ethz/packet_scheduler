-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_frame_table_uvm_wrapper
-- Author:              Codex (UVM wrapper for OPQ split)
-- Revision:            0.1 - mixed-language UVM support
-- Description:         Flattened VHDL wrapper around `work.opq_frame_table` for SystemVerilog/UVM tests.
--                      Converts array ports to packed vectors for easy DPI/VPI access.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

-- Flattened wrapper for mixed-language (SV/UVM) testing.
entity opq_frame_table_uvm_wrapper is
  generic (
    N_LANE            : positive := 2;
    N_TILE            : positive := 5;
    N_WR_SEG          : positive := 4;

    TILE_FIFO_DEPTH   : positive := 8;
    PAGE_RAM_DEPTH    : positive := 256;
    PAGE_RAM_DATA_WIDTH : positive := 40;

    SHD_CNT_WIDTH     : positive := 8;
    HIT_CNT_WIDTH     : positive := 8;
    HANDLE_PTR_WIDTH  : positive := 4;
    TILE_PKT_CNT_WIDTH : positive := 8;
    EGRESS_DELAY      : natural := 2;

    SHD_SIZE          : natural := 1;
    HIT_SIZE          : natural := 1;
    HDR_SIZE          : natural := 1;
    TRL_SIZE          : natural := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Page allocator events + counters.
    i_pa_write_head_start      : in  std_logic;
    i_pa_frame_start_addr      : in  std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt_this    : in  std_logic_vector(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt_this    : in  std_logic_vector(HIT_CNT_WIDTH-1 downto 0);

    i_pa_write_tail_done       : in  std_logic;
    i_pa_write_tail_active     : in  std_logic;
    i_pa_frame_start_addr_last : in  std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_pa_frame_shr_cnt         : in  std_logic_vector(SHD_CNT_WIDTH-1 downto 0);
    i_pa_frame_hit_cnt         : in  std_logic_vector(HIT_CNT_WIDTH-1 downto 0);
    i_pa_frame_invalid_last    : in  std_logic;
    i_pa_handle_wptr_flat      : in  std_logic_vector(N_LANE*HANDLE_PTR_WIDTH-1 downto 0);

    -- Block mover status.
    i_bm_handle_rptr_flat      : in  std_logic_vector(N_LANE*HANDLE_PTR_WIDTH-1 downto 0);

    -- Page RAM write port.
    i_page_ram_we              : in  std_logic;
    i_page_ram_wr_addr         : in  std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_page_ram_wr_data         : in  std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- Egress.
    i_egress_ready             : in  std_logic;
    o_egress_valid             : out std_logic;
    o_egress_data              : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    o_egress_startofpacket     : out std_logic;
    o_egress_endofpacket       : out std_logic;

    -- Status/debug (flattened).
    o_wr_blocked_by_rd_lock    : out std_logic;
    o_mapper_state             : out std_logic_vector(2 downto 0);
    o_presenter_state          : out std_logic_vector(2 downto 0);
    o_rseg_tile_index          : out std_logic_vector(clog2(N_TILE)-1 downto 0);
    o_wseg_tile_index_flat     : out std_logic_vector(N_WR_SEG*clog2(N_TILE)-1 downto 0)
  );
end entity opq_frame_table_uvm_wrapper;

architecture rtl of opq_frame_table_uvm_wrapper is
  constant TILE_ID_W : natural := clog2(N_TILE);

  signal pa_handle_wptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);
  signal bm_handle_rptr : unsigned_array_t(0 to N_LANE-1)(HANDLE_PTR_WIDTH-1 downto 0);

  signal wseg_tile_index : unsigned_array_t(0 to N_WR_SEG-1)(TILE_ID_W-1 downto 0);
  signal rseg_tile_index : unsigned(TILE_ID_W-1 downto 0);
begin
  gen_unpack : for i in 0 to N_LANE-1 generate
    pa_handle_wptr(i) <= unsigned(i_pa_handle_wptr_flat((i+1)*HANDLE_PTR_WIDTH-1 downto i*HANDLE_PTR_WIDTH));
    bm_handle_rptr(i) <= unsigned(i_bm_handle_rptr_flat((i+1)*HANDLE_PTR_WIDTH-1 downto i*HANDLE_PTR_WIDTH));
  end generate;

  o_rseg_tile_index <= std_logic_vector(rseg_tile_index);
  gen_wseg_flat : for i in 0 to N_WR_SEG-1 generate
    o_wseg_tile_index_flat((i+1)*TILE_ID_W-1 downto i*TILE_ID_W) <= std_logic_vector(wseg_tile_index(i));
  end generate;

  u_ftable : entity work.opq_frame_table
    generic map (
      N_LANE           => N_LANE,
      N_TILE           => N_TILE,
      N_WR_SEG         => N_WR_SEG,
      TILE_FIFO_DEPTH  => TILE_FIFO_DEPTH,
      PAGE_RAM_DEPTH   => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH,
      SHD_CNT_WIDTH    => SHD_CNT_WIDTH,
      HIT_CNT_WIDTH    => HIT_CNT_WIDTH,
      HANDLE_PTR_WIDTH => HANDLE_PTR_WIDTH,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH,
      EGRESS_DELAY     => EGRESS_DELAY,
      SHD_SIZE         => SHD_SIZE,
      HIT_SIZE         => HIT_SIZE,
      HDR_SIZE         => HDR_SIZE,
      TRL_SIZE         => TRL_SIZE
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_pa_write_head_start   => i_pa_write_head_start,
      i_pa_frame_start_addr   => unsigned(i_pa_frame_start_addr),
      i_pa_frame_shr_cnt_this => unsigned(i_pa_frame_shr_cnt_this),
      i_pa_frame_hit_cnt_this => unsigned(i_pa_frame_hit_cnt_this),

      i_pa_write_tail_done       => i_pa_write_tail_done,
      i_pa_write_tail_active     => i_pa_write_tail_active,
      i_pa_frame_start_addr_last => unsigned(i_pa_frame_start_addr_last),
      i_pa_frame_shr_cnt         => unsigned(i_pa_frame_shr_cnt),
      i_pa_frame_hit_cnt         => unsigned(i_pa_frame_hit_cnt),
      i_pa_frame_invalid_last    => i_pa_frame_invalid_last,
      i_pa_handle_wptr           => pa_handle_wptr,

      i_bm_handle_rptr           => bm_handle_rptr,

      i_page_ram_we              => i_page_ram_we,
      i_page_ram_wr_addr         => unsigned(i_page_ram_wr_addr),
      i_page_ram_wr_data         => i_page_ram_wr_data,

      i_egress_ready             => i_egress_ready,
      o_egress_valid             => o_egress_valid,
      o_egress_data              => o_egress_data,
      o_egress_startofpacket     => o_egress_startofpacket,
      o_egress_endofpacket       => o_egress_endofpacket,

      o_wr_blocked_by_rd_lock    => o_wr_blocked_by_rd_lock,
      o_mapper_state             => o_mapper_state,
      o_presenter_state          => o_presenter_state,
      o_rseg_tile_index          => rseg_tile_index,
      o_wseg_tile_index          => wseg_tile_index,
      o_tile_wptr                => open,
      o_tile_rptr                => open,
      o_tile_pkt_wcnt            => open,
      o_tile_pkt_rcnt            => open
    );
end architecture rtl;

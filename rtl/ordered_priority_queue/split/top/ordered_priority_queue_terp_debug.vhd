-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             ordered_priority_queue_terp_debug (split wrapper)
-- Author:              Yifeng Wang (original OPQ) / split wrapper by Codex
-- Revision:            0.1 - split wrapper for VHDL-only sims
-- Description:         Fixed 2-lane wrapper exposing the monolithic OPQ interface and instantiating the
--                      split implementation (`work.opq_top`). Used by legacy VHDL TBs.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

-- Split OPQ drop-in replacement for the TERP-preprocessed monolithic RTL.
-- Intended use:
--   - Compile this file instead of `packet_scheduler/tb/ordered_priority_queue/ordered_priority_queue.vhd`
--   - Keep using `packet_scheduler/tb/ordered_priority_queue/ordered_priority_queue_wrapper.vhd` unchanged.
--
-- Notes:
--   - This wrapper currently targets the 2-lane UVM/tb interface (asi_ingress_0/1_*).
--   - Egress data width adapts by truncating the internal 40-bit word to PAGE_RAM_RD_WIDTH.
entity ordered_priority_queue_terp_debug is
  generic (
    -- IP basic
    N_LANE              : natural := 2;
    MODE                : string := "MERGING";
    TRACK_HEADER        : boolean := true;
    -- ingress format
    INGRESS_DATA_WIDTH  : natural := 32;
    INGRESS_DATAK_WIDTH : natural := 4;
    CHANNEL_WIDTH       : natural := 2;
    -- IP advance
    LANE_FIFO_DEPTH     : natural := 1024;
    LANE_FIFO_WIDTH     : natural := 40;
    TICKET_FIFO_DEPTH   : natural := 256;
    HANDLE_FIFO_DEPTH   : natural := 64;
    PAGE_RAM_DEPTH      : natural := 65536;
    PAGE_RAM_RD_WIDTH   : natural := 36;
    -- packet format
    N_SHD               : natural := 128;
    N_HIT               : natural := 255;
    HDR_SIZE            : natural := 5;
    SHD_SIZE            : natural := 1;
    HIT_SIZE            : natural := 1;
    TRL_SIZE            : natural := 1;
    FRAME_SERIAL_SIZE   : natural := 16;
    FRAME_SUBH_CNT_SIZE : natural := 16;
    FRAME_HIT_CNT_SIZE  : natural := 16;
    -- debug configuration
    DEBUG_LV            : natural := 1
  );
  port (
    -- Ingress Queue Interface(s)
    asi_ingress_0_data          : in  std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    asi_ingress_0_valid         : in  std_logic_vector(0 downto 0);
    asi_ingress_0_channel       : in  std_logic_vector(CHANNEL_WIDTH-1 downto 0);
    asi_ingress_0_startofpacket : in  std_logic_vector(0 downto 0);
    asi_ingress_0_endofpacket   : in  std_logic_vector(0 downto 0);
    asi_ingress_0_error         : in  std_logic_vector(2 downto 0);
    asi_ingress_1_data          : in  std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    asi_ingress_1_valid         : in  std_logic_vector(0 downto 0);
    asi_ingress_1_channel       : in  std_logic_vector(CHANNEL_WIDTH-1 downto 0);
    asi_ingress_1_startofpacket : in  std_logic_vector(0 downto 0);
    asi_ingress_1_endofpacket   : in  std_logic_vector(0 downto 0);
    asi_ingress_1_error         : in  std_logic_vector(2 downto 0);

    -- Egress Queue Interface
    aso_egress_data          : out std_logic_vector(PAGE_RAM_RD_WIDTH-1 downto 0);
    aso_egress_valid         : out std_logic;
    aso_egress_ready         : in  std_logic;
    aso_egress_startofpacket : out std_logic;
    aso_egress_endofpacket   : out std_logic;
    aso_egress_error         : out std_logic_vector(2 downto 0);

    -- CLK / RST
    d_clk   : in std_logic;
    d_reset : in std_logic
  );
end entity ordered_priority_queue_terp_debug;

architecture rtl of ordered_priority_queue_terp_debug is
  constant N_TILE_C    : positive := 5;
  constant N_WR_SEG_C  : positive := 4;
  constant TILE_FIFO_DEPTH_C : positive := 512;
  constant TILE_PKT_CNT_WIDTH_C : positive := 10;
  constant EGRESS_DELAY_C : natural := 2;
  constant PAGE_RAM_DATA_WIDTH_C : positive := 40;

  signal ingress_data_s          : slv_array_t(0 to 1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
  signal ingress_valid_s         : std_logic_vector(1 downto 0);
  signal ingress_channel_s       : slv_array_t(0 to 1)(CHANNEL_WIDTH-1 downto 0);
  signal ingress_startofpacket_s : std_logic_vector(1 downto 0);
  signal ingress_endofpacket_s   : std_logic_vector(1 downto 0);
  signal ingress_error_s         : slv_array_t(0 to 1)(2 downto 0);

  signal egress_data_s : std_logic_vector(PAGE_RAM_DATA_WIDTH_C-1 downto 0);
  signal trim_drop_active_s : std_logic_vector(1 downto 0);
  signal wr_blocked_by_rd_lock_s : std_logic;
begin
  assert N_LANE = 2
    report "ordered_priority_queue_terp_debug(split): only N_LANE=2 is supported by this wrapper"
    severity failure;

  ingress_data_s(0) <= asi_ingress_0_data;
  ingress_data_s(1) <= asi_ingress_1_data;
  ingress_valid_s(0) <= asi_ingress_0_valid(0);
  ingress_valid_s(1) <= asi_ingress_1_valid(0);
  ingress_channel_s(0) <= asi_ingress_0_channel;
  ingress_channel_s(1) <= asi_ingress_1_channel;
  ingress_startofpacket_s(0) <= asi_ingress_0_startofpacket(0);
  ingress_startofpacket_s(1) <= asi_ingress_1_startofpacket(0);
  ingress_endofpacket_s(0) <= asi_ingress_0_endofpacket(0);
  ingress_endofpacket_s(1) <= asi_ingress_1_endofpacket(0);
  ingress_error_s(0) <= asi_ingress_0_error;
  ingress_error_s(1) <= asi_ingress_1_error;

  u_split : entity work.opq_top
    generic map (
      N_LANE => 2,
      N_TILE => N_TILE_C,
      N_WR_SEG => N_WR_SEG_C,
      N_SHD => N_SHD,
      CHANNEL_WIDTH => CHANNEL_WIDTH,
      INGRESS_DATA_WIDTH => INGRESS_DATA_WIDTH,
      INGRESS_DATAK_WIDTH => INGRESS_DATAK_WIDTH,
      LANE_FIFO_DEPTH => LANE_FIFO_DEPTH,
      LANE_FIFO_WIDTH => LANE_FIFO_WIDTH,
      TICKET_FIFO_DEPTH => TICKET_FIFO_DEPTH,
      HANDLE_FIFO_DEPTH => HANDLE_FIFO_DEPTH,
      PAGE_RAM_DEPTH => PAGE_RAM_DEPTH,
      PAGE_RAM_DATA_WIDTH => PAGE_RAM_DATA_WIDTH_C,
      HDR_SIZE => HDR_SIZE,
      SHD_SIZE => SHD_SIZE,
      HIT_SIZE => HIT_SIZE,
      TRL_SIZE => TRL_SIZE,
      N_HIT => N_HIT,
      FRAME_SERIAL_SIZE => FRAME_SERIAL_SIZE,
      FRAME_SUBH_CNT_SIZE => FRAME_SUBH_CNT_SIZE,
      FRAME_HIT_CNT_SIZE => FRAME_HIT_CNT_SIZE,
      SHD_CNT_WIDTH => FRAME_SUBH_CNT_SIZE,
      HIT_CNT_WIDTH => FRAME_HIT_CNT_SIZE,
      TILE_FIFO_DEPTH => TILE_FIFO_DEPTH_C,
      TILE_PKT_CNT_WIDTH => TILE_PKT_CNT_WIDTH_C,
      EGRESS_DELAY => EGRESS_DELAY_C,
      DEBUG_LV => DEBUG_LV
    )
    port map (
      i_clk => d_clk,
      i_rst => d_reset,

      i_ingress_data => ingress_data_s,
      i_ingress_valid => ingress_valid_s,
      i_ingress_channel => ingress_channel_s,
      i_ingress_startofpacket => ingress_startofpacket_s,
      i_ingress_endofpacket => ingress_endofpacket_s,
      i_ingress_error => ingress_error_s,

      i_egress_ready => aso_egress_ready,
      o_egress_valid => aso_egress_valid,
      o_egress_data => egress_data_s,
      o_egress_startofpacket => aso_egress_startofpacket,
      o_egress_endofpacket => aso_egress_endofpacket,

      i_avs_address => (others => '0'),
      i_avs_read => '0',
      o_avs_readdata => open,
      o_avs_waitrequest => open,
      o_avs_readdatavalid => open,

      o_trim_drop_active => trim_drop_active_s,
      o_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock_s
    );

  -- Egress data width adaptation (monolithic interface is typically 36b).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            OPQ_TERP_DEBUG.EGRESS_ADAPT
  -- @brief           Width adaptation between split internal word (40b) and wrapper egress width
  -- @input           egress_data_s
  -- @output          aso_egress_data
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_egress_data : process (all) is
  begin
    -- `resize` truncates MSBs when shrinking and zero-extends when widening.
    aso_egress_data <= std_logic_vector(resize(unsigned(egress_data_s), PAGE_RAM_RD_WIDTH));
  end process;

  -- TODO: propagate error semantics (hit/shd/hdr) through the split pipeline.
  aso_egress_error <= (others => '0');

  -- MODE/TRACK_HEADER/DEBUG_LV are currently ignored by the split implementation.
  -- (MODE is internally MERGING; DEBUG taps live in the monolithic debug RTL.)
  assert MODE = "MERGING"
    report "ordered_priority_queue_terp_debug(split): only MODE=""MERGING"" is implemented in opq_split currently"
    severity warning;
  assert TRACK_HEADER
    report "ordered_priority_queue_terp_debug(split): TRACK_HEADER=false not implemented (ignored)"
    severity warning;
end architecture rtl;

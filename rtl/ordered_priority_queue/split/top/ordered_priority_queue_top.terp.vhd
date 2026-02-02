-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             ordered_priority_queue (split wrapper)
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch) / split wrapper by Codex
-- Revision:            0.1 - TERP wrapper for split OPQ (generated via `altera_terp`)
-- Description:         TERP template that exposes the monolithic OPQ Avalon-ST interface (per-lane ports)
--                      and instantiates the split implementation (`work.opq_top`).
--
--                      Intended use:
--                        - Run `packet_scheduler/rtl/ordered_priority_queue/split/top/update_preprocessed.sh` to generate
--                          `ordered_priority_queue_top.vhd` with a stable entity name.
--                        - Compile the generated VHDL as a drop-in replacement for the monolithic OPQ RTL
--                          in simulation (and later in Quartus integration).
--
-- TERP parameters (set by `altera_terp`):
--   - n_lane             : number of ingress lanes (generates ports `asi_ingress_<i>_*`)
--   - egress_empty_width : optional `aso_egress_empty` width (kept for compatibility; driven to 0)
--   - output_name        : VHDL entity name to generate
--
-- Notes:
--   - This wrapper is intended to be drop-in compatible with the monolithic
--     `packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd` interface.
--   - MODE/TRACK_HEADER/DEBUG_LV generics are retained for compatibility; split currently implements
--     MERGING only and does not propagate egress_error yet.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

entity ${output_name} is
    generic (
        -- IP basic
        N_LANE                  : natural := $n_lane; -- number of ingress lanes, e.g., 4 for x4
        MODE                    : string := "MERGING"; -- {MULTIPLEXING MERGING}
        TRACK_HEADER            : boolean := true;
        -- ingress format
        INGRESS_DATA_WIDTH      : natural := 32;
        INGRESS_DATAK_WIDTH     : natural := 4;
        CHANNEL_WIDTH           : natural := 2;
        -- IP advance
        LANE_FIFO_DEPTH         : natural := 1024;
        LANE_FIFO_WIDTH         : natural := 40;
        TICKET_FIFO_DEPTH       : natural := 256;
        HANDLE_FIFO_DEPTH       : natural := 64;
        PAGE_RAM_DEPTH          : natural := 65536;
        PAGE_RAM_RD_WIDTH       : natural := 36;
        -- packet format
        N_SHD                   : natural := 128;
        N_HIT                   : natural := 255;
        HDR_SIZE                : natural := 5;
        SHD_SIZE                : natural := 1;
        HIT_SIZE                : natural := 1;
        TRL_SIZE                : natural := 1;
        FRAME_SERIAL_SIZE       : natural := 16;
        FRAME_SUBH_CNT_SIZE     : natural := 16;
        FRAME_HIT_CNT_SIZE      : natural := 16;
        -- debug configuration
        DEBUG_LV               : natural := 1
    );
    port (
        -- +----------------------------+
        -- | Ingress Queue Interface(s) |
        -- +----------------------------+
        @@ for {set i 0} {$i < $n_lane} {incr i} {
        asi_ingress_${i}_data            : in  std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
        asi_ingress_${i}_valid           : in  std_logic_vector(0 downto 0);
        asi_ingress_${i}_channel         : in  std_logic_vector(CHANNEL_WIDTH-1 downto 0);
        asi_ingress_${i}_startofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_${i}_endofpacket     : in  std_logic_vector(0 downto 0);
        asi_ingress_${i}_error           : in  std_logic_vector(2 downto 0);
        @@ }

        -- +------------------------+
        -- | Egress Queue Interface |
        -- +------------------------+
        aso_egress_data             : out std_logic_vector(PAGE_RAM_RD_WIDTH-1 downto 0);
        aso_egress_valid            : out std_logic;
        aso_egress_ready            : in  std_logic;
        aso_egress_startofpacket    : out std_logic;
        aso_egress_endofpacket      : out std_logic;
        aso_egress_error            : out std_logic_vector(2 downto 0);
        @@ if {$egress_empty_width > 0} {
        aso_egress_empty            : out std_logic_vector($egress_empty_width-1 downto 0);
        @@ } elseif {$egress_empty_width == 1} {
        aso_egress_empty            : out std_logic_vector(0 downto 0);
        @@ }

        -- +---------------------+
        -- | CLK / RST Interface |
        -- +---------------------+
        d_clk                    : in std_logic;
        d_reset                  : in std_logic
    );
end entity ${output_name};


architecture rtl of ${output_name} is
    -- Keep the same internal constants as the monolithic v25.0 wrapper.
    constant N_TILE_C               : positive := 5;
    constant N_WR_SEG_C             : positive := 4;
    constant TILE_FIFO_DEPTH_C      : positive := 512;
    constant TILE_PKT_CNT_WIDTH_C   : positive := 10;
    constant EGRESS_DELAY_C         : natural  := 2;

    -- Map scalar per-lane ports into VHDL-2008 arrays (used by `opq_top`).
    signal ingress_data_s          : slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    signal ingress_valid_s         : std_logic_vector(N_LANE-1 downto 0);
    signal ingress_channel_s       : slv_array_t(0 to N_LANE-1)(CHANNEL_WIDTH-1 downto 0);
    signal ingress_startofpacket_s : std_logic_vector(N_LANE-1 downto 0);
    signal ingress_endofpacket_s   : std_logic_vector(N_LANE-1 downto 0);
    signal ingress_error_s         : slv_array_t(0 to N_LANE-1)(2 downto 0);

    signal egress_data_s           : std_logic_vector(LANE_FIFO_WIDTH-1 downto 0);

    signal trim_drop_active_s      : std_logic_vector(N_LANE-1 downto 0);
    signal wr_blocked_by_rd_lock_s : std_logic;
begin
    -- Tie ingress ports into arrays.
    @@ for {set i 0} {$i < $n_lane} {incr i} {
    ingress_data_s(${i})            <= asi_ingress_${i}_data;
    ingress_valid_s(${i})           <= asi_ingress_${i}_valid(0);
    ingress_channel_s(${i})         <= asi_ingress_${i}_channel;
    ingress_startofpacket_s(${i})   <= asi_ingress_${i}_startofpacket(0);
    ingress_endofpacket_s(${i})     <= asi_ingress_${i}_endofpacket(0);
    ingress_error_s(${i})           <= asi_ingress_${i}_error;
    @@ }

    u_split : entity work.opq_top
        generic map (
            N_LANE                => N_LANE,
            N_TILE                => N_TILE_C,
            N_WR_SEG              => N_WR_SEG_C,
            N_SHD                 => N_SHD,
            CHANNEL_WIDTH         => CHANNEL_WIDTH,
            INGRESS_DATA_WIDTH    => INGRESS_DATA_WIDTH,
            INGRESS_DATAK_WIDTH   => INGRESS_DATAK_WIDTH,
            LANE_FIFO_DEPTH       => LANE_FIFO_DEPTH,
            LANE_FIFO_WIDTH       => LANE_FIFO_WIDTH,
            TICKET_FIFO_DEPTH     => TICKET_FIFO_DEPTH,
            HANDLE_FIFO_DEPTH     => HANDLE_FIFO_DEPTH,
            PAGE_RAM_DEPTH        => PAGE_RAM_DEPTH,
            PAGE_RAM_DATA_WIDTH   => LANE_FIFO_WIDTH,
            HDR_SIZE              => HDR_SIZE,
            SHD_SIZE              => SHD_SIZE,
            HIT_SIZE              => HIT_SIZE,
            TRL_SIZE              => TRL_SIZE,
            N_HIT                 => N_HIT,
            FRAME_SERIAL_SIZE     => FRAME_SERIAL_SIZE,
            FRAME_SUBH_CNT_SIZE   => FRAME_SUBH_CNT_SIZE,
            FRAME_HIT_CNT_SIZE    => FRAME_HIT_CNT_SIZE,
            SHD_CNT_WIDTH         => FRAME_SUBH_CNT_SIZE,
            HIT_CNT_WIDTH         => FRAME_HIT_CNT_SIZE,
            TILE_FIFO_DEPTH       => TILE_FIFO_DEPTH_C,
            TILE_PKT_CNT_WIDTH    => TILE_PKT_CNT_WIDTH_C,
            EGRESS_DELAY          => EGRESS_DELAY_C,
            DEBUG_LV              => DEBUG_LV
        )
        port map (
            i_clk                 => d_clk,
            i_rst                 => d_reset,

            i_ingress_data        => ingress_data_s,
            i_ingress_valid       => ingress_valid_s,
            i_ingress_channel     => ingress_channel_s,
            i_ingress_startofpacket => ingress_startofpacket_s,
            i_ingress_endofpacket => ingress_endofpacket_s,
            i_ingress_error       => ingress_error_s,

            i_egress_ready        => aso_egress_ready,
            o_egress_valid        => aso_egress_valid,
            o_egress_data         => egress_data_s,
            o_egress_startofpacket => aso_egress_startofpacket,
            o_egress_endofpacket  => aso_egress_endofpacket,

            i_avs_address         => (others => '0'),
            i_avs_read            => '0',
            o_avs_readdata        => open,
            o_avs_waitrequest     => open,
            o_avs_readdatavalid   => open,

            o_trim_drop_active    => trim_drop_active_s,
            o_wr_blocked_by_rd_lock => wr_blocked_by_rd_lock_s
        );

    -- Egress data width adaptation (monolithic interface is typically 36b).
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            OPQ_TERP_WRAPPER.EGRESS_ADAPT
    -- @brief           Width adaptation between split internal word and wrapper egress bus width
    -- @input           egress_data_s
    -- @output          aso_egress_data
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_egress_data : process (all) is
    begin
        -- Width adaptation without out-of-range slices (safe for any PAGE_RAM_RD_WIDTH vs LANE_FIFO_WIDTH).
        -- `resize` truncates MSBs when shrinking and zero-extends MSBs when widening.
        aso_egress_data <= std_logic_vector(resize(unsigned(egress_data_s), PAGE_RAM_RD_WIDTH));
    end process;

    -- TODO: propagate error semantics through the split pipeline.
    aso_egress_error <= (others => '0');

    @@ if {$egress_empty_width > 0} {
    aso_egress_empty <= (others => '0');
    @@ } elseif {$egress_empty_width == 1} {
    aso_egress_empty <= (others => '0');
    @@ }

    -- MODE/TRACK_HEADER are currently ignored by the split implementation.
    assert MODE = "MERGING"
        report "${output_name}(split): only MODE=""MERGING"" is implemented currently"
        severity warning;
    assert TRACK_HEADER
        report "${output_name}(split): TRACK_HEADER=false not implemented (ignored)"
        severity warning;
end architecture rtl;

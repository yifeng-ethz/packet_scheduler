-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             intf_adapter
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            1.0
-- Date:                July 23, 2025 (file created)
-- Description:         Adapter between mu3e custom signal bundle and standard NoC interface (AXI4, Avalon Streaming)
--
--                      - data structure is defined as:
--                          Name (abbr.)            :  unit size (fixed)    Usage
--                          --------------------------------------------------------------------------------------
--                          data                       32 bits              a word of data (byte 3 downto 0)
--                          datak                      4 bits               byte is k (byte 3 downto 0)
--                          idle                       1 bit                0=valid
--                          sop                        1 bit                1=premable 1st word
--                          dthr                       1 bit                not used
--                          sbhdr                      1 bit                not used
--                          eop                        1 bit                1=trailer
--                          err                        1 bit                not used
--                          t0                         1 bit                not used
--                          t1                         1 bit                not used
--                          d0                         1 bit                not used
--                          d1                         1 bit                not used

-- ------------------------------------------------------------------------------------------------------------
-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================
-- general
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
-- altera-specific
library altera_mf;
use altera_mf.all;
-- get params from hls* macro


entity ${output_name} is
    generic (
        -- IP basic
        N_LANE                  : natural := 2;-- number of ingress lanes, e.g., 4 for x4 lanes will induce 4 interfaces
        -- Interface format
        INGRESS_FORMAT          : string := "Mu3e"; -- {Mu3e Avalon AXI4}
        EGRESS_FORMAT           : string := "Avalon"; -- {Mu3e Avalon AXI4}
        -- Mu3e signal format
        MU3E_SIG_WIDTH          : natural := 39; -- mu3e bundle signal width, little endian as the sequence below
        MU3E_USE_DATA           : boolean := True; -- use data signal, ex {data[31:0]}
        MU3E_USE_DATAK          : boolean := True; -- use datak signal, ex {data[35:32]}
        MU3E_USE_IDLE           : boolean := True; -- use idle signal
        MU3E_USE_SOP            : boolean := True; -- use sop signal
        MU3E_USE_DTHR           : boolean := False; -- use dthr signal
        MU3E_USE_SBHDR          : boolean := False; -- use sbhdr signal
        MU3E_USE_EOP            : boolean := True; -- use eop signal
        MU3E_USE_ERR            : boolean := False; -- use err signal
        MU3E_USE_T0             : boolean := False; -- use t0 signal
        MU3E_USE_T1             : boolean := False; -- use t1 signal
        MU3E_USE_D0             : boolean := False; -- use d0 signal
        MU3E_USE_D1             : boolean := False; -- use d1 signal
        -- Avalon Streaming format
        AVS_DATA_WIDTH          : natural := 36; -- avalon streaming signal width
        AVS_CHANNEL_WIDTH       : natural := 2; -- avalon streaming channel width
        AVS_ERROR_WIDTH         : natural := 3; -- avalon streaming error width
        AVS_USE_DATA            : boolean := True; -- use data signal
        AVS_USE_VALID           : boolean := True; -- use valid signal
        AVS_USE_SOP             : boolean := True; -- use start of packet signal
        AVS_USE_EOP             : boolean := True; -- use end of packet signal
        AVS_USE_ERR             : boolean := False; -- use error signal
        AVS_USE_CHANNEL         : boolean := True; -- use channel signal
        -- debug configuration
        DEBUG_LV                : natural := 1 -- debug level, e.g., 0 for no debug, 1 for basic debug
    );
    port (
        -- +----------------------+
        -- | Ingress Interface(s) |
        -- +----------------------+
        @@ for {set i 0} {$i < $n_lane} {incr i} {
            @@ if {[string equal -nocase $ingress_format "Avalon"]} {
                @@ if {$avs_use_data} {
        asi_ingress_${i}_data            : in  std_logic_vector(AVS_DATA_WIDTH-1 downto 0); -- [35:32] : byte_is_k - "0001" = sub-header, "0000" = hit
                @@ }
                @@ if {$avs_use_valid} {
        asi_ingress_${i}_valid           : in  std_logic_vector(0 downto 0); -- non-backlog, will drop packet inside if full
                @@ }
                @@ if {$avs_use_channel} {
        asi_ingress_${i}_channel         : in  std_logic_vector(AVS_CHANNEL_WIDTH-1 downto 0); -- indicates the logical channel, fixed during run time
                @@ }
                @@ if {$avs_use_sop} {
        asi_ingress_${i}_startofpacket   : in  std_logic_vector(0 downto 0); -- start of subheader or header
                @@ }
                @@ if {$avs_use_eop} {
        asi_ingress_${i}_endofpacket     : in  std_logic_vector(0 downto 0); -- end of subheader (last hit) or header
                @@ }
                @@ if {$avs_use_err} {
        asi_ingress_${i}_error           : in  std_logic_vector(AVS_ERROR_WIDTH-1 downto 0); -- errorDescriptor = {hit_err shd_err hdr_err}. will block the remaining data until eop and revoke the current packet
                @@ }
            @@ } elseif {[string equal -nocase $ingress_format "AXI4"]} {
            -- TODO AXI4 interface
            @@ } else {
        cds_ingress_${i}_data            : in  std_logic_vector(MU3E_SIG_WIDTH-1 downto 0); -- mu3e bundle signal
            @@ }
        @@ }

        -- +---------------------+
        -- | Egress Interface(s) |
        -- +---------------------+
        @@ for {set i 0} {$i < $n_lane} {incr i} {
            @@ if {[string equal -nocase $egress_format "Avalon"]} {
                @@ if {$avs_use_data} {
        aso_egress_${i}_data             : out std_logic_vector(AVS_DATA_WIDTH-1 downto 0); -- [35:32] : byte_is_k - "0001" = sub-header, "0000" = hit
                @@ }
                @@ if {$avs_use_valid} {
        aso_egress_${i}_valid            : out std_logic_vector(0 downto 0); -- non-backlog, will drop packet inside if full
                @@ }
                @@ if {$avs_use_channel} {
        aso_egress_${i}_channel          : out std_logic_vector(AVS_CHANNEL_WIDTH-1 downto 0); -- indicates the logical channel, fixed during run time
                @@ }
                @@ if {$avs_use_sop} {
        aso_egress_${i}_startofpacket    : out std_logic_vector(0 downto 0); -- start of subheader or header
                @@ }
                @@ if {$avs_use_eop} {
        aso_egress_${i}_endofpacket      : out std_logic_vector(0 downto 0); -- end of subheader (last hit) or header
                @@ }
                @@ if {$avs_use_err} {
        aso_egress_${i}_error            : out std_logic_vector(AVS_ERROR_WIDTH-1 downto 0); -- errorDescriptor = {hit_err shd_err hdr_err}. will block the remaining data until eop and revoke the current packet
                @@ }
            @@ } elseif {[string equal -nocase $egress_format "AXI4"]} {
        -- TODO AXI4 interface
            @@ } else {
        cdm_egress_${i}_data              : out  std_logic_vector(MU3E_SIG_WIDTH-1 downto 0); -- mu3e bundle signal
            @@ }
        @@ }


        -- +---------------------+
        -- | CLK / RST Interface |
        -- +---------------------+
        data_clk                  : in std_logic; -- data path clock
        data_reset                : in std_logic -- data path reset
    );
end entity ${output_name};

architecture rtl of ${output_name} is
    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  COMMON
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- universal 8b10b
	constant K285					: std_logic_vector(7 downto 0) := "10111100"; -- 16#BC# -- byte 0 marks header begins
	constant K284					: std_logic_vector(7 downto 0) := "10011100"; -- 16#9C# -- byte 0 marks trailer ends
	constant K237					: std_logic_vector(7 downto 0) := "11110111"; -- 16#F7# -- byte 0 marks subheader begins

    -- direct io signals
    signal d_clk					: std_logic;
    signal d_rst					: std_logic;

    -- format location
    constant MU3E_DATA_LO           : natural := 0;
    constant MU3E_DATA_HI           : natural := 31;
    constant MU3E_DATAK_LO          : natural := 32;
    constant MU3E_DATAK_HI          : natural := 35;
    constant MU3E_IDLE_LO           : natural := 36;
    constant MU3E_IDLE_HI           : natural := 36;
    constant MU3E_SOP_LO            : natural := 37;
    constant MU3E_SOP_HI            : natural := 37;
    constant MU3E_EOP_LO            : natural := 38;
    constant MU3E_EOP_HI            : natural := 38;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- INGRESS MAPPER
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    type ingress_mapper_t is record
        data            : std_logic_vector(MU3E_DATA_HI-MU3E_DATA_LO downto 0);
        datak           : std_logic_vector(MU3E_DATAK_HI-MU3E_DATAK_LO downto 0);
        valid           : std_logic_vector(MU3E_IDLE_HI-MU3E_IDLE_LO downto 0);
        sop             : std_logic_vector(MU3E_SOP_HI-MU3E_SOP_LO downto 0);
        eop             : std_logic_vector(MU3E_EOP_HI-MU3E_EOP_LO downto 0);
    end record;
    type ingress_mappers_t is array (0 to N_LANE-1) of ingress_mapper_t;
    signal ingress_mapper           : ingress_mappers_t;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- EGRESS MAPPER
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    signal egress_mapper           : ingress_mappers_t;


begin
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- io mapping
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    d_clk       <= data_clk;
    d_rst       <= data_reset;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            INGRESS MAPPER
    -- @brief           Register and map raw MU3E lane words into internal per-lane record fields.
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_ingress_mapper : process (d_clk)
    begin
        if rising_edge(d_clk) then
            @@ for {set i 0} {$i < $n_lane} {incr i} {
                ingress_mapper($i).data      <= cds_ingress_${i}_data(MU3E_DATA_HI downto MU3E_DATA_LO);
                ingress_mapper($i).datak     <= cds_ingress_${i}_data(MU3E_DATAK_HI downto MU3E_DATAK_LO);
                ingress_mapper($i).valid     <= cds_ingress_${i}_data(MU3E_IDLE_HI downto MU3E_IDLE_LO);
                ingress_mapper($i).sop       <= cds_ingress_${i}_data(MU3E_SOP_HI downto MU3E_SOP_LO);
                ingress_mapper($i).eop       <= cds_ingress_${i}_data(MU3E_EOP_HI downto MU3E_EOP_LO);
            @@ }

            if d_rst then

            end if;
        end if;
    end process;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            EGRESS MAPPER
    -- @brief           Map internal per-lane record fields back onto the enabled Avalon-ST outputs.
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_egress_mapper : process (d_clk)
    begin
        if rising_edge(d_clk) then
            for i in 0 to N_LANE-1 loop
                egress_mapper(i).data      <= ingress_mapper(i).data;
                egress_mapper(i).datak     <= ingress_mapper(i).datak;
                egress_mapper(i).valid     <= ingress_mapper(i).valid;
                egress_mapper(i).sop       <= ingress_mapper(i).sop;
                egress_mapper(i).eop       <= ingress_mapper(i).eop;
            end loop;

            if d_rst then

            end if;
        end if;
    end process;

    proc_egress_mapper_comb : process (all)
    begin

        @@ for {set i 0} {$i < $n_lane} {incr i} {
            @@ if {$avs_use_data} {
        aso_egress_${i}_data             <= egress_mapper(${i}).datak & egress_mapper(${i}).data;
            @@ }
            @@ if {$avs_use_valid} {
        aso_egress_${i}_valid            <= egress_mapper(${i}).valid;
            @@ }
            @@ if {$avs_use_channel} {
        aso_egress_${i}_channel          <= std_logic_vector(to_unsigned(${i},AVS_CHANNEL_WIDTH));
            @@ }
            @@ if {$avs_use_sop} {
        aso_egress_${i}_startofpacket    <= egress_mapper($i).sop;
            @@ }
            @@ if {$avs_use_eop} {
        aso_egress_${i}_endofpacket      <= egress_mapper($i).eop;
            @@ }
            @@ if {$avs_use_err} {
        aso_egress_${i}_error            <= (others => '0');
            @@ }
        @@ }

    end process;






end architecture rtl;

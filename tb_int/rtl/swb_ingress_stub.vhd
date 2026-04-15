-- ---------------------------------------------------------------------------
-- IP Name    : swb_ingress_stub
-- Author     : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Description:
--   Minimal SWB ingress stub for packet_scheduler/tb_int. Exposes 4 raw
--   36-bit AvST ingress ports (one per FEB link) and wires them straight
--   into ordered_priority_queue_dut4 with N_LANE=4. The ingress valid of
--   every lane is gated by run_enable so the run-control agent can drop
--   all ingress in one cycle.
--
--   This stub replaces the SWB xcvr + datapath subsystem on the switching
--   board side. The xcvr is not simulated; the FEB tx AvST beats drive
--   the OPQ ingress AvST beats in the same clock domain with zero
--   latency.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity swb_ingress_stub is
    port (
        -- clock / reset (single domain)
        d_clk       : in  std_logic;
        d_reset     : in  std_logic;

        -- run gate from the run_control_agent (PCIe side)
        run_enable  : in  std_logic;

        -- lane 0 ingress (feb0 / up)
        asi_ingress_0_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_0_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_0_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_0_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_0_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_0_error         : in  std_logic_vector(2 downto 0);

        -- lane 1 ingress (feb0 / dn)
        asi_ingress_1_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_1_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_1_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_1_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_1_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_1_error         : in  std_logic_vector(2 downto 0);

        -- lane 2 ingress (feb1 / up)
        asi_ingress_2_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_2_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_2_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_2_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_2_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_2_error         : in  std_logic_vector(2 downto 0);

        -- lane 3 ingress (feb1 / dn)
        asi_ingress_3_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_3_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_3_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_3_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_3_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_3_error         : in  std_logic_vector(2 downto 0);

        -- egress
        aso_egress_data             : out std_logic_vector(35 downto 0);
        aso_egress_valid            : out std_logic;
        aso_egress_ready            : in  std_logic;
        aso_egress_startofpacket    : out std_logic;
        aso_egress_endofpacket      : out std_logic;
        aso_egress_error            : out std_logic_vector(2 downto 0);

        -- OPQ CSR (flat passthrough)
        avs_csr_address             : in  std_logic_vector(8 downto 0);
        avs_csr_read                : in  std_logic;
        avs_csr_write               : in  std_logic;
        avs_csr_writedata           : in  std_logic_vector(31 downto 0);
        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_readdatavalid       : out std_logic;
        avs_csr_waitrequest         : out std_logic;
        avs_csr_burstcount          : in  std_logic
    );
end entity swb_ingress_stub;

architecture rtl of swb_ingress_stub is
    signal gate : std_logic_vector(0 downto 0);
    signal v0, v1, v2, v3 : std_logic_vector(0 downto 0);
begin
    gate(0) <= run_enable;
    v0 <= asi_ingress_0_valid and gate;
    v1 <= asi_ingress_1_valid and gate;
    v2 <= asi_ingress_2_valid and gate;
    v3 <= asi_ingress_3_valid and gate;

    u_opq : entity work.ordered_priority_queue_dut4
        port map (
            asi_ingress_0_data          => asi_ingress_0_data,
            asi_ingress_0_valid         => v0,
            asi_ingress_0_channel       => asi_ingress_0_channel,
            asi_ingress_0_startofpacket => asi_ingress_0_startofpacket,
            asi_ingress_0_endofpacket   => asi_ingress_0_endofpacket,
            asi_ingress_0_error         => asi_ingress_0_error,
            asi_ingress_1_data          => asi_ingress_1_data,
            asi_ingress_1_valid         => v1,
            asi_ingress_1_channel       => asi_ingress_1_channel,
            asi_ingress_1_startofpacket => asi_ingress_1_startofpacket,
            asi_ingress_1_endofpacket   => asi_ingress_1_endofpacket,
            asi_ingress_1_error         => asi_ingress_1_error,
            asi_ingress_2_data          => asi_ingress_2_data,
            asi_ingress_2_valid         => v2,
            asi_ingress_2_channel       => asi_ingress_2_channel,
            asi_ingress_2_startofpacket => asi_ingress_2_startofpacket,
            asi_ingress_2_endofpacket   => asi_ingress_2_endofpacket,
            asi_ingress_2_error         => asi_ingress_2_error,
            asi_ingress_3_data          => asi_ingress_3_data,
            asi_ingress_3_valid         => v3,
            asi_ingress_3_channel       => asi_ingress_3_channel,
            asi_ingress_3_startofpacket => asi_ingress_3_startofpacket,
            asi_ingress_3_endofpacket   => asi_ingress_3_endofpacket,
            asi_ingress_3_error         => asi_ingress_3_error,
            aso_egress_data             => aso_egress_data,
            aso_egress_valid            => aso_egress_valid,
            aso_egress_ready            => aso_egress_ready,
            aso_egress_startofpacket    => aso_egress_startofpacket,
            aso_egress_endofpacket      => aso_egress_endofpacket,
            aso_egress_error            => aso_egress_error,
            avs_csr_address             => avs_csr_address,
            avs_csr_read                => avs_csr_read,
            avs_csr_write               => avs_csr_write,
            avs_csr_writedata           => avs_csr_writedata,
            avs_csr_readdata            => avs_csr_readdata,
            avs_csr_readdatavalid       => avs_csr_readdatavalid,
            avs_csr_waitrequest         => avs_csr_waitrequest,
            avs_csr_burstcount          => avs_csr_burstcount,
            d_clk                       => d_clk,
            d_reset                     => d_reset
        );
end architecture rtl;

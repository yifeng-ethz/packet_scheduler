library ieee;
use ieee.std_logic_1164.all;

entity ordered_priority_queue is
    generic (
        DEBUG_LV               : natural := 1
    );
    port (
        asi_ingress_0_data            : in  std_logic_vector(35 downto 0);
        asi_ingress_0_valid           : in  std_logic_vector(0 downto 0);
        asi_ingress_0_channel         : in  std_logic_vector(1 downto 0);
        asi_ingress_0_startofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_0_endofpacket     : in  std_logic_vector(0 downto 0);
        asi_ingress_0_error           : in  std_logic_vector(2 downto 0);
        asi_ingress_1_data            : in  std_logic_vector(35 downto 0);
        asi_ingress_1_valid           : in  std_logic_vector(0 downto 0);
        asi_ingress_1_channel         : in  std_logic_vector(1 downto 0);
        asi_ingress_1_startofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_1_endofpacket     : in  std_logic_vector(0 downto 0);
        asi_ingress_1_error           : in  std_logic_vector(2 downto 0);

        aso_egress_data               : out std_logic_vector(35 downto 0);
        aso_egress_valid              : out std_logic;
        aso_egress_ready              : in  std_logic;
        aso_egress_startofpacket      : out std_logic;
        aso_egress_endofpacket        : out std_logic;
        aso_egress_error              : out std_logic_vector(2 downto 0);

        d_clk                         : in  std_logic;
        d_reset                       : in  std_logic
    );
end entity ordered_priority_queue;

architecture rtl of ordered_priority_queue is
begin
    u_impl : entity work.debug_queue_system_ordered_priority_queue_250722_624ymiy
        generic map (
            DEBUG_LV               => DEBUG_LV
        )
        port map (
            asi_ingress_0_data          => asi_ingress_0_data,
            asi_ingress_0_valid         => asi_ingress_0_valid,
            asi_ingress_0_channel       => asi_ingress_0_channel,
            asi_ingress_0_startofpacket => asi_ingress_0_startofpacket,
            asi_ingress_0_endofpacket   => asi_ingress_0_endofpacket,
            asi_ingress_0_error         => asi_ingress_0_error,
            asi_ingress_1_data          => asi_ingress_1_data,
            asi_ingress_1_valid         => asi_ingress_1_valid,
            asi_ingress_1_channel       => asi_ingress_1_channel,
            asi_ingress_1_startofpacket => asi_ingress_1_startofpacket,
            asi_ingress_1_endofpacket   => asi_ingress_1_endofpacket,
            asi_ingress_1_error         => asi_ingress_1_error,

            aso_egress_data             => aso_egress_data,
            aso_egress_valid            => aso_egress_valid,
            aso_egress_ready            => aso_egress_ready,
            aso_egress_startofpacket    => aso_egress_startofpacket,
            aso_egress_endofpacket      => aso_egress_endofpacket,
            aso_egress_error            => aso_egress_error,

            d_clk                       => d_clk,
            d_reset                     => d_reset
        );
end architecture rtl;

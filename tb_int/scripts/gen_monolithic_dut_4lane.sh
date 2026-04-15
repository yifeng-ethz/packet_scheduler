#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : gen_monolithic_dut_4lane
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Description:
#   Generate the monolithic OPQ implementation with N_LANE=4 for the
#   packet_scheduler integration testbench (tb_int). The impl is produced
#   from the same altera_terp template used by tb/, but with n_lane=4.
#   The thin wrapper with hardcoded 4-lane AvST ingress ports is written
#   directly (no terp) and lives alongside the impl in OUT_DIR.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_INT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKT_DIR="$(cd "${TB_INT_DIR}/.." && pwd)"
OUT_DIR="${1:-${TB_INT_DIR}/rtl_gen_monolithic_4lane}"

QUARTUS_SH="${QUARTUS_SH:-/data1/intelFPGA_pro/23.1/quartus/bin/quartus_sh}"
QUARTUS_ROOTDIR="${QUARTUS_ROOTDIR:-/data1/intelFPGA_pro/23.1/quartus}"
OPQ_PAGE_RAM_DEPTH="${OPQ_PAGE_RAM_DEPTH:-65536}"
OPQ_N_SHD="${OPQ_N_SHD:-256}"
OPQ_TICKET_FIFO_DEPTH="${OPQ_TICKET_FIFO_DEPTH:-256}"
OPQ_DEBUG_LV="${OPQ_DEBUG_LV:-1}"

mkdir -p "${OUT_DIR}"

IMPL_VHD="${OUT_DIR}/ordered_priority_queue_dut4_impl.vhd"
WRAP_VHD="${OUT_DIR}/ordered_priority_queue_dut4.vhd"
TCL_FILE="${OUT_DIR}/gen_monolithic_dut4.tcl"

cat > "${TCL_FILE}" <<TCL
lappend auto_path "\$::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages"
package require -exact altera_terp 1.0
set template_file [file normalize {${PKT_DIR}/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd}]
set template [read [open \$template_file r]]
set params(n_lane) 4
set params(fifos_names) [list "ticket_fifo" "lane_fifo" "handle_fifo"]
set params(egress_empty_width) 0
set params(output_name) "ordered_priority_queue_dut4_impl"
set result [altera_terp \$template params]
set out [open {${IMPL_VHD}} w]
puts \$out \$result
close \$out
TCL

QUARTUS_ROOTDIR="${QUARTUS_ROOTDIR}" "${QUARTUS_SH}" -t "${TCL_FILE}" >/dev/null

cat > "${WRAP_VHD}" <<VHDL
library ieee;
use ieee.std_logic_1164.all;

entity ordered_priority_queue_dut4 is
    port (
        asi_ingress_0_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_0_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_0_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_0_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_0_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_0_error         : in  std_logic_vector(2 downto 0);
        asi_ingress_1_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_1_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_1_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_1_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_1_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_1_error         : in  std_logic_vector(2 downto 0);
        asi_ingress_2_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_2_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_2_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_2_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_2_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_2_error         : in  std_logic_vector(2 downto 0);
        asi_ingress_3_data          : in  std_logic_vector(35 downto 0);
        asi_ingress_3_valid         : in  std_logic_vector(0 downto 0);
        asi_ingress_3_channel       : in  std_logic_vector(1 downto 0);
        asi_ingress_3_startofpacket : in  std_logic_vector(0 downto 0);
        asi_ingress_3_endofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_3_error         : in  std_logic_vector(2 downto 0);
        aso_egress_data             : out std_logic_vector(35 downto 0);
        aso_egress_valid            : out std_logic;
        aso_egress_ready            : in  std_logic;
        aso_egress_startofpacket    : out std_logic;
        aso_egress_endofpacket      : out std_logic;
        aso_egress_error            : out std_logic_vector(2 downto 0);
        avs_csr_address             : in  std_logic_vector(8 downto 0);
        avs_csr_read                : in  std_logic;
        avs_csr_write               : in  std_logic;
        avs_csr_writedata           : in  std_logic_vector(31 downto 0);
        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_readdatavalid       : out std_logic;
        avs_csr_waitrequest         : out std_logic;
        avs_csr_burstcount          : in  std_logic;
        d_clk                       : in  std_logic;
        d_reset                     : in  std_logic
    );
end entity ordered_priority_queue_dut4;

architecture rtl of ordered_priority_queue_dut4 is
begin
    u_impl : entity work.ordered_priority_queue_dut4_impl
        generic map (
            N_LANE              => 4,
            MODE                => "MERGING",
            TRACK_HEADER        => true,
            INGRESS_DATA_WIDTH  => 32,
            INGRESS_DATAK_WIDTH => 4,
            CHANNEL_WIDTH       => 2,
            LANE_FIFO_DEPTH     => 1024,
            LANE_FIFO_WIDTH     => 40,
            TICKET_FIFO_DEPTH   => ${OPQ_TICKET_FIFO_DEPTH},
            HANDLE_FIFO_DEPTH   => 64,
            PAGE_RAM_DEPTH      => ${OPQ_PAGE_RAM_DEPTH},
            PAGE_RAM_RD_WIDTH   => 36,
            N_SHD               => ${OPQ_N_SHD},
            N_HIT               => 255,
            HDR_SIZE            => 5,
            SHD_SIZE            => 1,
            HIT_SIZE            => 1,
            TRL_SIZE            => 1,
            FRAME_SERIAL_SIZE   => 16,
            FRAME_SUBH_CNT_SIZE => 16,
            FRAME_HIT_CNT_SIZE  => 16,
            DEBUG_LV            => ${OPQ_DEBUG_LV}
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
            asi_ingress_2_data          => asi_ingress_2_data,
            asi_ingress_2_valid         => asi_ingress_2_valid,
            asi_ingress_2_channel       => asi_ingress_2_channel,
            asi_ingress_2_startofpacket => asi_ingress_2_startofpacket,
            asi_ingress_2_endofpacket   => asi_ingress_2_endofpacket,
            asi_ingress_2_error         => asi_ingress_2_error,
            asi_ingress_3_data          => asi_ingress_3_data,
            asi_ingress_3_valid         => asi_ingress_3_valid,
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
VHDL

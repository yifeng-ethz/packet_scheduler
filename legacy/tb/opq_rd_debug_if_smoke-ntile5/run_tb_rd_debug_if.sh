#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_rd_debug_if
"${MODELSIM_BIN}/vlib" work_rd_debug_if

"${MODELSIM_BIN}/vcom" -2008 -work work_rd_debug_if ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_rd_debug_if ../../rtl/ordered_priority_queue/split/opq/debug/opq_rd_debug_if.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_rd_debug_if tb_opq_rd_debug_if.vhd

"${MODELSIM_BIN}/vsim" -c work_rd_debug_if.tb_opq_rd_debug_if -do "run -all; quit"

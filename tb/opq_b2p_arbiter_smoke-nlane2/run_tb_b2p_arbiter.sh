#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_b2p_arbiter
"${MODELSIM_BIN}/vlib" work_b2p_arbiter

"${MODELSIM_BIN}/vcom" -2008 -work work_b2p_arbiter ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_b2p_arbiter ../../rtl/ordered_priority_queue/split/opq/arbiter/opq_b2p_arbiter.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_b2p_arbiter tb_opq_b2p_arbiter.vhd

"${MODELSIM_BIN}/vsim" -c work_b2p_arbiter.tb_opq_b2p_arbiter -do "run -all; quit"

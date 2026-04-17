#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_ftable_mapper
"${MODELSIM_BIN}/vlib" work_ftable_mapper

"${MODELSIM_BIN}/vcom" -2008 -work work_ftable_mapper ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_ftable_mapper ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_mapper.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_ftable_mapper tb_opq_frame_table_mapper.vhd

"${MODELSIM_BIN}/vsim" -c work_ftable_mapper.tb_opq_frame_table_mapper -do "run -all; quit"

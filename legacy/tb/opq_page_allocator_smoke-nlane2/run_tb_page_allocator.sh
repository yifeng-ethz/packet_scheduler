#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_page_allocator
"${MODELSIM_BIN}/vlib" work_page_allocator

"${MODELSIM_BIN}/vcom" -2008 -work work_page_allocator ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_page_allocator ../../rtl/ordered_priority_queue/split/opq/allocator/opq_page_allocator.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_page_allocator tb_opq_page_allocator.vhd

"${MODELSIM_BIN}/vsim" -c work_page_allocator.tb_opq_page_allocator -do "run -all; quit"

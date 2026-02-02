#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_frame_table
"${MODELSIM_BIN}/vlib" work_frame_table

"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/common/opq_sync_ram.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_mapper.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_tracker.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_presenter.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_frame_table tb_opq_frame_table.vhd

"${MODELSIM_BIN}/vsim" -c work_frame_table.tb_opq_frame_table -do "run -all; quit"

#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf work_opq_top
"${MODELSIM_BIN}/vlib" work_opq_top

"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/common/opq_sync_ram.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/ingress/opq_ingress_parser.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/allocator/opq_page_allocator.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/mover/opq_block_mover.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/arbiter/opq_b2p_arbiter.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_mapper.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_tracker.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_presenter.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/debug/opq_rd_debug_if.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top ../../rtl/ordered_priority_queue/split/opq/top/opq_top.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_opq_top tb_opq_top.vhd

"${MODELSIM_BIN}/vsim" -c work_opq_top.tb_opq_top -do "run -all; quit"

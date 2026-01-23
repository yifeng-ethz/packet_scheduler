#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN=/data1/intelFPGA/18.1/modelsim_ase/bin

"${MODELSIM_BIN}/vlib" work
"./update_preprocessed.sh"
"${MODELSIM_BIN}/vlog" -work work ../../alt_ram/frame_table.v \
  ../../alt_ram/handle_fifo.v \
  ../../alt_ram/lane_fifo.v \
  ../../alt_ram/page_ram.v \
  ../../alt_ram/ticket_fifo.v \
  ../../alt_ram/tile_fifo.v
"${MODELSIM_BIN}/vcom" -2008 -work work ordered_priority_queue.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work ordered_priority_queue_tb.vhd
"${MODELSIM_BIN}/vsim" -novopt -voptargs="+acc" -c work.ordered_priority_queue_tb -do run_tb.do

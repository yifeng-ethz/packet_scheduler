#!/usr/bin/env bash
set -euo pipefail

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

MODELSIM_BIN=/data1/intelFPGA/18.1/modelsim_ase/bin

"${MODELSIM_BIN}/vlib" work
"${MODELSIM_BIN}/vcom" -2008 -work work ../../random_toggler.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work random_toggler_tb.vhd
"${MODELSIM_BIN}/vsim" -c work.random_toggler_tb -do run_tb.do

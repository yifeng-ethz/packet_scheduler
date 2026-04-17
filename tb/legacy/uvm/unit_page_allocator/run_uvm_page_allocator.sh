#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

MODELSIM_BIN="${MODELSIM_BIN:-/data1/intelFPGA/18.1/modelsim_ase/bin}"
UVM_HOME="${UVM_HOME:-}"

# Prefer the UVM copy shipped with ModelSim if the user didn't provide one.
if [[ -z "${UVM_HOME}" ]]; then
  candidate="$(cd "${MODELSIM_BIN}/.." && pwd)/verilog_src/uvm-1.2"
  if [[ -f "${candidate}/src/uvm_pkg.sv" ]]; then
    UVM_HOME="${candidate}"
  fi
fi

: "${LM_LICENSE_FILE:=8182@lic-altera.ethz.ch}"
export LM_LICENSE_FILE

if [[ ! -x "${MODELSIM_BIN}/vsim" ]]; then
  echo "ModelSim not found at: ${MODELSIM_BIN}" >&2
  exit 1
fi

rm -rf work_uvm_page_allocator
"${MODELSIM_BIN}/vlib" work_uvm_page_allocator

UVM_DEFINE_ARGS=(+define+UVM_NO_DPI)

# Provide safe defaults if the caller didn't pass them.
# NOTE: pa_pkg.sv enforces (N_FRAMES * (1+N_SHD)) < TICKET_FIFO_DEPTH to keep the interface-local
# ticket memories in-bounds. With the current defaults (N_SHD=8, TICKET_FIFO_DEPTH=1024), N_FRAMES=100 is safe.
ARGS=("$@")
has_plusarg_prefix() {
  local prefix="$1"
  for a in "${ARGS[@]}"; do
    if [[ "${a}" == "${prefix}"* ]]; then
      return 0
    fi
  done
  return 1
}
if ! has_plusarg_prefix "+N_FRAMES="; then
  ARGS+=("+N_FRAMES=100")
fi

# Split RTL (VHDL)
"${MODELSIM_BIN}/vcom" -2008 -work work_uvm_page_allocator ../../rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_uvm_page_allocator ../../rtl/ordered_priority_queue/split/opq/allocator/opq_page_allocator.vhd
"${MODELSIM_BIN}/vcom" -2008 -work work_uvm_page_allocator opq_page_allocator_uvm_wrapper.vhd

if [[ -n "${UVM_HOME}" ]]; then
  # Patch the UVM sources into the build dir and guard the DPI export under UVM_NO_DPI.
  UVM_SRC="${UVM_HOME}/src"
  UVM_PATCH_DIR="work_uvm_page_allocator/uvm_patched"
  rm -rf "${UVM_PATCH_DIR}"
  mkdir -p "${UVM_PATCH_DIR}"
  cp -a "${UVM_SRC}" "${UVM_PATCH_DIR}/"
  perl -pi -e 's/^export \"DPI-C\" function m__uvm_report_dpi;/`ifndef UVM_NO_DPI\nexport \"DPI-C\" function m__uvm_report_dpi;\n`endif/' "${UVM_PATCH_DIR}/src/base/uvm_globals.svh"

  "${MODELSIM_BIN}/vlog" -sv -work work_uvm_page_allocator "${UVM_DEFINE_ARGS[@]}" +incdir+"${UVM_PATCH_DIR}/src" "${UVM_PATCH_DIR}/src/uvm_pkg.sv"
fi

UVM_INCDIR_ARGS=()
if [[ -n "${UVM_HOME}" ]]; then
  UVM_INCDIR_ARGS+=(+incdir+"${UVM_PATCH_DIR}/src")
fi

"${MODELSIM_BIN}/vlog" -sv -work work_uvm_page_allocator "${UVM_DEFINE_ARGS[@]}" "${UVM_INCDIR_ARGS[@]}" pa_if.sv pa_pkg.sv pa_uvm_tb.sv

"${MODELSIM_BIN}/vsim" -c -voptargs="+acc" work_uvm_page_allocator.pa_uvm_tb "${ARGS[@]}" -do "run -all; quit"

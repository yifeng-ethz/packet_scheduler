#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : packet_scheduler/tb_int/scripts/run_tb_int_longrun_matrix.sh
# Description:
#   Compile tb_int once, then execute the full 128-case long-run matrix as
#   eight 16-case waves. Wave execution is delegated to run_tb_int_longrun_wave.sh
#   with cached compile reuse enabled.
#
# Usage:
#   run_tb_int_longrun_matrix.sh
#
# Environment knobs:
#   SKIP_COMPILE=0
#   START_CASES="1 17 33 49 65 81 97 113"
#   MAX_PARALLEL=16
#   TEST=tb_int_longrun_sanity_test
#   TB_INT_EXTRA_DEFINES='+define+TB_INT_FAST_RBCAM'
#   BASE_PLUSARGS='...'
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_INT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_INT_DIR}/uvm"
SIM_DIR="${TB_INT_DIR}/sim_runs/longrun"
WAVE_SCRIPT="${SCRIPT_DIR}/run_tb_int_longrun_wave.sh"

SKIP_COMPILE="${SKIP_COMPILE:-0}"
START_CASES="${START_CASES:-1 17 33 49 65 81 97 113}"
MAX_PARALLEL="${MAX_PARALLEL:-16}"
TEST="${TEST:-tb_int_longrun_sanity_test}"
TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES:-}"
BASE_PLUSARGS="${BASE_PLUSARGS:-+TB_INT_PREPARE_CYCLES=256 +TB_INT_END_CYCLES=4096}"

mkdir -p "${SIM_DIR}"

if [[ "${SKIP_COMPILE}" != "1" ]]; then
  echo ">>> compile once for full matrix"
  make -C "${UVM_DIR}" compile TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES}"
fi

matrix_summary="${SIM_DIR}/matrix_summary.txt"
: > "${matrix_summary}"

fail=0
for start_case in ${START_CASES}; do
  wave_id=$(( (start_case - 1) / 16 ))
  echo ">>> run wave ${wave_id} (start=${start_case})" | tee -a "${matrix_summary}"
  if ! SKIP_COMPILE=1 \
      MAX_PARALLEL="${MAX_PARALLEL}" \
      TEST="${TEST}" \
      TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES}" \
      BASE_PLUSARGS="${BASE_PLUSARGS}" \
      "${WAVE_SCRIPT}" "${start_case}" 16; then
    fail=$((fail + 1))
  fi
  cat "${SIM_DIR}/wave_$(printf '%03d' "${start_case}")_summary.txt" >> "${matrix_summary}"
done

if [[ "${fail}" -ne 0 ]]; then
  echo ">>> matrix completed with ${fail} failing wave(s)" | tee -a "${matrix_summary}"
  exit 1
fi

echo ">>> matrix completed with all waves passing" | tee -a "${matrix_summary}"

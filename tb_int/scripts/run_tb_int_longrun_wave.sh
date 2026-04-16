#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : packet_scheduler/tb_int/scripts/run_tb_int_longrun_wave.sh
# Description:
#   Compile tb_int once, then launch one long-run wave with up to 16 cached
#   simulations in parallel. Each case gets its own transcript under
#   sim_runs/longrun/<case>/.
#
# Usage:
#   run_tb_int_longrun_wave.sh [START_CASE_ID] [COUNT]
#
# Defaults:
#   START_CASE_ID=1
#   COUNT=16
#
# Environment knobs:
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

START_CASE_ID="${1:-1}"
COUNT="${2:-16}"
MAX_PARALLEL="${MAX_PARALLEL:-16}"
TEST="${TEST:-tb_int_longrun_sanity_test}"
TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES:-}"
BASE_PLUSARGS="${BASE_PLUSARGS:-+TB_INT_PREPARE_CYCLES=256 +TB_INT_END_CYCLES=4096}"
RUN_DO='quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f'

mkdir -p "${SIM_DIR}"

echo ">>> compile once"
make -C "${UVM_DIR}" compile TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES}"

pids=()
case_ids=()
for ((offset=0; offset<COUNT; offset++)); do
  case_id=$((START_CASE_ID + offset))
  case_tag=$(printf 'case_%03d' "${case_id}")
  case_dir="${SIM_DIR}/${case_tag}"
  mkdir -p "${case_dir}"
  log="${case_dir}/transcript.log"
  echo ">>> launch ${case_tag}"
  (
    make -C "${UVM_DIR}" run_cached       TEST="${TEST}"       TB_INT_EXTRA_DEFINES="${TB_INT_EXTRA_DEFINES}"       RUN_DO="${RUN_DO}"       PLUSARGS="${BASE_PLUSARGS} +TB_INT_LONGRUN_CASE_ID=${case_id}"       >"${log}" 2>&1
  ) &
  pids+=("$!")
  case_ids+=("${case_id}")

  while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do
    sleep 1
  done
done

fail=0
summary="${SIM_DIR}/wave_$(printf '%03d' "${START_CASE_ID}")_summary.txt"
: > "${summary}"
for idx in "${!pids[@]}"; do
  pid="${pids[$idx]}"
  case_id="${case_ids[$idx]}"
  case_tag=$(printf 'case_%03d' "${case_id}")
  log="${SIM_DIR}/${case_tag}/transcript.log"
  if wait "${pid}"; then
    if grep -q "UVM_ERROR :    0" "${log}" && grep -q "UVM_FATAL :    0" "${log}"; then
      status="PASS"
    else
      status="FAIL"
      fail=$((fail + 1))
    fi
  else
    status="FAIL"
    fail=$((fail + 1))
  fi
  printf '%s %s\n' "${case_tag}" "${status}" | tee -a "${summary}"
done

echo ">>> wave summary written to ${summary}"
[[ "${fail}" -eq 0 ]]

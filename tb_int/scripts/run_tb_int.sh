#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : packet_scheduler/tb_int/scripts/run_tb_int.sh
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Description:
#   Wrapper around `make -C tb_int/uvm run` for the integration testbench.
#   Usage:
#     run_tb_int.sh [TEST_NAME ...]
#   Default test: tb_int_smoke_test.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_INT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_INT_DIR}/uvm"
LOG_DIR="${TB_INT_DIR}/sim_runs/logs"

mkdir -p "${LOG_DIR}"

if [[ "$#" -eq 0 ]]; then
  TESTS=("tb_int_smoke_test")
else
  TESTS=("$@")
fi

pass=0
fail=0
for t in "${TESTS[@]}"; do
  log="${LOG_DIR}/${t}.log"
  echo ">>> running ${t} (log: ${log})"
  if make -C "${UVM_DIR}" TEST="${t}" run >"${log}" 2>&1; then
    if grep -q "UVM_FATAL :    0" "${log}" && grep -q "UVM_ERROR :    0" "${log}"; then
      echo "    PASS"
      pass=$((pass + 1))
    else
      echo "    FAIL (UVM errors in log)"
      fail=$((fail + 1))
    fi
  else
    echo "    FAIL (make returned non-zero)"
    fail=$((fail + 1))
  fi
done

echo "=== tb_int summary: ${pass} pass, ${fail} fail ==="
[[ "${fail}" -eq 0 ]]

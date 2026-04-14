#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COV_DIR="${TB_DIR}/sim_runs/coverage"
LOG_DIR="${TB_DIR}/sim_runs/logs"

if [[ "$#" -eq 0 ]]; then
  TESTS=(
    opq_basic_smoke_test
    opq_basic_ts_boundary_test
    opq_edge_max_hits_test
  )
else
  TESTS=("$@")
fi

if [[ -n "${OPQ_N_SHD_LIST-}" ]]; then
  IFS=',' read -r -a N_SHD_SWEEP <<< "${OPQ_N_SHD_LIST}"
else
  N_SHD_SWEEP=(128 256 512)
fi

for n_shd in "${N_SHD_SWEEP[@]}"; do
  echo "== OPQ_N_SHD=${n_shd} =="
  OPQ_N_SHD="${n_shd}" "${SCRIPT_DIR}/run_uvm.sh" "${TESTS[@]}"

  for test_name in "${TESTS[@]}"; do
    if [[ -f "${LOG_DIR}/${test_name}.log" ]]; then
      cp -f "${LOG_DIR}/${test_name}.log" "${LOG_DIR}/${test_name}_nshd${n_shd}.log"
    fi
  done

  if [[ "${COV_ENABLE:-0}" == "1" ]]; then
    for test_name in "${TESTS[@]}"; do
      if [[ -f "${COV_DIR}/${test_name}.ucdb" ]]; then
        mv -f "${COV_DIR}/${test_name}.ucdb" "${COV_DIR}/${test_name}_nshd${n_shd}.ucdb"
      fi
    done
  fi
done

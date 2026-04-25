#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COV_DIR="${TB_DIR}/sim_runs/coverage"
LOG_DIR="${TB_DIR}/sim_runs/logs"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_param.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

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
  N_SHD_SWEEP=(64 128 256)
fi

RESTORE_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${RESTORE_DIR}"
}
trap cleanup EXIT

for test_name in "${TESTS[@]}"; do
  if [[ -f "${LOG_DIR}/${test_name}.log" ]]; then
    cp -f "${LOG_DIR}/${test_name}.log" "${RESTORE_DIR}/${test_name}.log"
  fi
  if [[ "${COV_ENABLE:-0}" == "1" ]] && [[ -f "${COV_DIR}/${test_name}.ucdb" ]]; then
    cp -f "${COV_DIR}/${test_name}.ucdb" "${RESTORE_DIR}/${test_name}.ucdb"
  fi
done

for n_shd in "${N_SHD_SWEEP[@]}"; do
  echo "== OPQ_N_SHD=${n_shd} =="
  # Each N_SHD sweep point must use the matching safe ticket FIFO depth rather
  # than inheriting the caller's closure-point depth (for example 256 from the
  # 4x128 signoff slice), otherwise larger sweep points like N_SHD=512 are run
  # with an intentionally undersized ticket FIFO and fail for the wrong reason.
  env -u OPQ_TICKET_FIFO_DEPTH \
    OPQ_N_SHD="${n_shd}" DUT_IMPL="${DUT_IMPL}" \
    "${SCRIPT_DIR}/run_uvm.sh" "${TESTS[@]}"

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

# Restore any pre-existing default-geometry artifacts that were present before
# the parameter sweep so the default buckets keep their unsuffixed evidence.
for test_name in "${TESTS[@]}"; do
  if [[ -f "${RESTORE_DIR}/${test_name}.log" ]]; then
    cp -f "${RESTORE_DIR}/${test_name}.log" "${LOG_DIR}/${test_name}.log"
  fi
  if [[ "${COV_ENABLE:-0}" == "1" ]] && [[ -f "${RESTORE_DIR}/${test_name}.ucdb" ]]; then
    cp -f "${RESTORE_DIR}/${test_name}.ucdb" "${COV_DIR}/${test_name}.ucdb"
  fi
done

# If the caller explicitly swept the default build point, restore the
# unsuffixed artifacts so the default-geometry buckets keep a stable contract.
default_n_shd="${OPQ_N_SHD_DEFAULT:-${OPQ_N_SHD:-128}}"
if [[ " ${N_SHD_SWEEP[*]} " == *" ${default_n_shd} "* ]]; then
  for test_name in "${TESTS[@]}"; do
    if [[ -f "${LOG_DIR}/${test_name}_nshd${default_n_shd}.log" ]]; then
      cp -f "${LOG_DIR}/${test_name}_nshd${default_n_shd}.log" "${LOG_DIR}/${test_name}.log"
    fi
    if [[ "${COV_ENABLE:-0}" == "1" ]] && [[ -f "${COV_DIR}/${test_name}_nshd${default_n_shd}.ucdb" ]]; then
      cp -f "${COV_DIR}/${test_name}_nshd${default_n_shd}.ucdb" "${COV_DIR}/${test_name}.ucdb"
    fi
  done
fi

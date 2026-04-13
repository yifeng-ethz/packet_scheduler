#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_DIR}/uvm"
RUN_DIR="${TB_DIR}/sim_runs"
LOG_DIR="${RUN_DIR}/logs"
COV_DIR="${RUN_DIR}/coverage"

usage() {
  cat <<'EOF'
Usage:
  run_uvm.sh [UVM_TESTNAME ...]

Environment:
  COV_ENABLE        1 to use `make run_cov`
  QUESTA_PREFER_FE  0 by default; set to 1 to force the FE executable
  RUN_DO            Optional override for the vsim `-do` script
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -eq 0 ]]; then
  TESTS=("opq_basic_smoke_test")
else
  TESTS=("$@")
fi

mkdir -p "${LOG_DIR}" "${COV_DIR}"

pass_count=0
fail_count=0

run_one() {
  local test_name="$1"
  local log_file="${LOG_DIR}/${test_name}.log"
  local -a make_args=(
    "-C" "${UVM_DIR}"
    "QUESTA_PREFER_FE=${QUESTA_PREFER_FE:-0}"
    "TEST=${test_name}"
  )
  local target="run"

  if [[ -n "${RUN_DO-}" ]]; then
    make_args+=("RUN_DO=${RUN_DO}")
  fi
  if [[ "${COV_ENABLE:-0}" == "1" ]]; then
    target="run_cov"
  fi

  printf '%s\n' "----------------------------------------------------------------"
  printf 'Running %s\n' "${test_name}"

  if make "${make_args[@]}" "${target}" 2>&1 | tee "${log_file}"; then
    if rg -q \
      -e '# UVM_ERROR :[[:space:]]*[1-9][0-9]*' \
      -e '# UVM_FATAL :[[:space:]]*[1-9][0-9]*' \
      -e '\*\* Error:' \
      -e '\*\* Fatal:' \
      "${log_file}"; then
      echo "[FAIL] ${test_name}"
      fail_count=$((fail_count + 1))
      return
    fi
    if [[ "${COV_ENABLE:-0}" == "1" ]]; then
      if [[ -f "${UVM_DIR}/build/opq_${test_name}.ucdb" ]]; then
        cp -f "${UVM_DIR}/build/opq_${test_name}.ucdb" "${COV_DIR}/${test_name}.ucdb"
      else
        echo "[FAIL] ${test_name} (coverage database missing)"
        fail_count=$((fail_count + 1))
        return
      fi
    fi
    echo "[PASS] ${test_name}"
    pass_count=$((pass_count + 1))
  else
    echo "[FAIL] ${test_name}"
    fail_count=$((fail_count + 1))
  fi
}

for test_name in "${TESTS[@]}"; do
  run_one "${test_name}"
done

printf '%s\n' "----------------------------------------------------------------"
printf 'UVM summary: pass=%d fail=%d total=%d\n' "${pass_count}" "${fail_count}" "$((pass_count + fail_count))"
[[ "${fail_count}" -eq 0 ]]

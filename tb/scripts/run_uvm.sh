#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : run_uvm
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.3 - derive the safe ticket FIFO depth from N_SHD whenever unset
# Description:
#   Wrapper around the active OPQ UVM make targets.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_DIR}/uvm"
RUN_DIR="${RUN_DIR:-${TB_DIR}/sim_runs}"
LOG_DIR="${LOG_DIR:-${RUN_DIR}/logs}"
COV_DIR="${COV_DIR:-${RUN_DIR}/coverage}"

source "${SCRIPT_DIR}/../../../scripts/questa_one_env.sh"

usage() {
  cat <<'EOF'
Usage:
  run_uvm.sh [UVM_TESTNAME|CANONICAL_CASE_ID ...]

Environment:
  COV_ENABLE        1 to use `make run_cov`
  DUT_IMPL          Must be `native_sv` for signoff/report evidence; defaults to `native_sv`
  OPQ_N_SHD         Optional N_SHD override passed into the DUT wrapper generator and UVM package
  OPQ_TICKET_FIFO_DEPTH Optional ticket FIFO depth override; if unset the script derives a safe power-of-two depth from N_SHD
  OPQ_PAGE_RAM_DEPTH Optional page RAM depth override passed into the DUT wrapper generator
  BUILD_DIR         Optional explicit build directory override for a single invocation
  BUILD_ROOT        Optional parent directory used for auto-generated per-run build directories
  RUN_DIR           Optional root for run artifacts; defaults to tb/sim_runs
  LOG_DIR           Optional log directory override; defaults to $RUN_DIR/logs
  COV_DIR           Optional coverage directory override; defaults to $RUN_DIR/coverage
  RUN_DO            Optional override for the vsim `-do` script
  VSIM_PLUSARGS     Optional extra vsim plusargs, for example `+TB_CLK_PERIOD_NS=100000`
EOF
}

derive_ticket_fifo_depth() {
  local n_shd="$1"
  local depth=256

  while (( depth <= n_shd )); do
    depth=$((depth * 2))
  done

  printf '%d\n' "${depth}"
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
declare -A PREPARED_BUILD_KEYS=()

has_nonbenign_tool_error() {
  local log_file="$1"
  awk '
    /\*\* Fatal:/ { bad=1; next }
    /\*\* Error:/ {
      if ($0 ~ /\(vsim-22\) Unable to get current directory path\./) next
      bad=1
      next
    }
    /shell-init: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory/ { next }
    /No such file or directory\. \(errno = ENOENT\)/ { next }
    END { exit bad ? 0 : 1 }
  ' "${log_file}"
}

run_one() {
  local test_name="$1"
  local canonical_case_re='^[BEPX][0-9]{3}$'
  local artifact_name="${test_name}"
  local uvm_test_name="${test_name}"
  local case_plusargs=""
  local log_file="${LOG_DIR}/${test_name}.log"
  local dut_impl="${DUT_IMPL:-native_sv}"
  local page_ram_depth="${OPQ_PAGE_RAM_DEPTH:-65536}"
  local n_shd="${OPQ_N_SHD:-256}"
  local ticket_fifo_depth="${OPQ_TICKET_FIFO_DEPTH:-}"
  local user_build_dir="${BUILD_DIR:-}"
  local build_root="${BUILD_ROOT:-${UVM_DIR}/build_runs}"
  local build_tag=""
  local build_key=""
  local build_dir=""
  local compile_target="compile"
  local -a make_args=(
    "-C" "${UVM_DIR}"
    "DUT_IMPL=${dut_impl}"
  )
  local target="run_no_compile"
  local cov_saved=0

  if [[ "${test_name}" == +* || "${test_name}" == *=* ]]; then
    echo "[FAIL] ${test_name} (looks like a plusarg or env-style token, not a UVM test name; pass simulator plusargs via VSIM_PLUSARGS and shell variables via the environment)" | tee "${log_file}"
    fail_count=$((fail_count + 1))
    return
  fi

  if [[ "${test_name}" =~ ${canonical_case_re} ]]; then
    artifact_name="${test_name}"
    uvm_test_name="$(python3 "${SCRIPT_DIR}/opq_catalog.py" --case-id "${artifact_name}" --field runtime_test)"
    case_plusargs="+OPQ_CASE_ID=${artifact_name} $(python3 "${SCRIPT_DIR}/opq_catalog.py" --case-id "${artifact_name}" --field runtime_plusargs)"
  fi
  log_file="${LOG_DIR}/${artifact_name}.log"

  resolve_cov_src() {
    local -a candidates=(
      "${build_dir}/opq_${uvm_test_name}.ucdb"
      "${build_dir}/opq_opq_${uvm_test_name}.ucdb"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
      if [[ -f "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    done
    return 1
  }

  if [[ "${dut_impl}" != "native_sv" ]]; then
    echo "[FAIL] ${test_name} (DUT_IMPL=${dut_impl}; signoff runners require DUT_IMPL=native_sv)" | tee "${log_file}"
    fail_count=$((fail_count + 1))
    return
  fi

  if [[ -n "${RUN_DO-}" ]]; then
    make_args+=("RUN_DO=${RUN_DO}")
  fi
  if [[ -n "${VSIM_PLUSARGS-}" || -n "${case_plusargs}" ]]; then
    make_args+=("VSIM_PLUSARGS=${case_plusargs} ${VSIM_PLUSARGS-}")
  fi
  if [[ "${uvm_test_name}" == "opq_error_ftable_overflow_test" && -z "${OPQ_PAGE_RAM_DEPTH-}" ]]; then
    page_ram_depth=512
  fi
  if [[ -z "${ticket_fifo_depth}" ]]; then
    ticket_fifo_depth="$(derive_ticket_fifo_depth "${n_shd}")"
  fi
  build_tag="dut${dut_impl}_lane${OPQ_N_LANE:-2}_nshd${n_shd}_ticket${ticket_fifo_depth}_page${page_ram_depth}_cov${COV_ENABLE:-0}"
  build_key="${build_tag}"
  if [[ -n "${user_build_dir}" ]]; then
    build_dir="${user_build_dir}"
    build_key="user:${build_dir}"
  else
    build_dir="${build_root}/${build_tag}"
  fi
  make_args+=("OPQ_PAGE_RAM_DEPTH=${page_ram_depth}")
  make_args+=("OPQ_N_SHD=${n_shd}")
  make_args+=("OPQ_TICKET_FIFO_DEPTH=${ticket_fifo_depth}")
  make_args+=("BUILD_DIR=${build_dir}")
  make_args+=("TEST=${uvm_test_name}")
  if [[ "${COV_ENABLE:-0}" == "1" ]]; then
    target="run_cov_no_compile"
    make_args+=("COV=1")
    if [[ -n "${COV_CODE-}" ]]; then
      make_args+=("COV_CODE=${COV_CODE}")
    fi
  fi

  printf '%s\n' "----------------------------------------------------------------"
  printf 'Running %s\n' "${artifact_name}"

  if {
    printf '[run_uvm] DUT_IMPL=%s TEST=%s ARTIFACT=%s OPQ_N_LANE=%s OPQ_N_SHD=%s OPQ_TICKET_FIFO_DEPTH=%s OPQ_PAGE_RAM_DEPTH=%s COV_ENABLE=%s VSIM_PLUSARGS=%s\n' \
      "${dut_impl}" "${uvm_test_name}" "${artifact_name}" "${OPQ_N_LANE:-2}" "${n_shd}" "${ticket_fifo_depth}" "${page_ram_depth}" "${COV_ENABLE:-0}" "${case_plusargs} ${VSIM_PLUSARGS:-}";
    printf '[run_uvm] BUILD_DIR=%s BUILD_KEY=%s TARGET=%s\n' "${build_dir}" "${build_key}" "${target}";
    if [[ -z "${PREPARED_BUILD_KEYS[${build_key}]+x}" ]]; then
      printf '[run_uvm] COMPILE_TARGET=%s\n' "${compile_target}";
      make "${make_args[@]}" "${compile_target}";
      PREPARED_BUILD_KEYS["${build_key}"]="${build_dir}"
    else
      printf '[run_uvm] REUSE_BUILD=1\n'
    fi
    make "${make_args[@]}" "${target}";
  } > >(tee "${log_file}") 2>&1; then
    if [[ "${COV_ENABLE:-0}" == "1" ]]; then
      if cov_src="$(resolve_cov_src)"; then
        cp -f "${cov_src}" "${COV_DIR}/${artifact_name}.ucdb"
        cov_saved=1
      fi
    fi
    if rg -q \
      -e '# UVM_ERROR :[[:space:]]*[1-9][0-9]*' \
      -e '# UVM_FATAL :[[:space:]]*[1-9][0-9]*' \
      "${log_file}" \
      || has_nonbenign_tool_error "${log_file}"; then
      if [[ "${COV_ENABLE:-0}" == "1" && "${cov_saved}" -eq 0 ]]; then
        echo "[WARN] ${artifact_name} (coverage database missing on failing run)"
      fi
      echo "[FAIL] ${artifact_name}"
      fail_count=$((fail_count + 1))
      return
    fi
    if [[ "${COV_ENABLE:-0}" == "1" && "${cov_saved}" -eq 0 ]]; then
        echo "[FAIL] ${artifact_name} (coverage database missing)"
        fail_count=$((fail_count + 1))
        return
    fi
    echo "[PASS] ${artifact_name}"
    pass_count=$((pass_count + 1))
  else
    echo "[FAIL] ${artifact_name}"
    fail_count=$((fail_count + 1))
  fi
}

for test_name in "${TESTS[@]}"; do
  run_one "${test_name}"
done

printf '%s\n' "----------------------------------------------------------------"
printf 'UVM summary: pass=%d fail=%d total=%d\n' "${pass_count}" "${fail_count}" "$((pass_count + fail_count))"
[[ "${fail_count}" -eq 0 ]]

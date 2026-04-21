#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_common
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.3 - lock simulation to QuestaOne 2026 and retire the old SBY backend
# Description:
#   Shared utilities for the `formal_*.sh` wrappers described in DV_FORMAL.
#   The wrappers intentionally isolate their build trees from the normal UVM
#   regression build so formal checker compile/elaboration cannot corrupt the
#   signoff simulation flow.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/questa_one_env.sh"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_DIR}/uvm"
FORMAL_RUN_DIR="${TB_DIR}/formal_runs"
FORMAL_LOG_DIR="${FORMAL_RUN_DIR}/logs"
FORMAL_CSV_DIR="${FORMAL_RUN_DIR}/csv"
ETH_MENTOR_SERVER="${ETH_MENTOR_SERVER:-${QUESTA_LICENSE_SERVER:-8161@lic-mentor.ethz.ch}}"

mkdir -p "${FORMAL_LOG_DIR}" "${FORMAL_CSV_DIR}"

FORMAL_RESULT_STATUS=""
FORMAL_RESULT_BACKEND=""
FORMAL_RESULT_NOTE=""

formal_csv_escape() {
  local value="$1"
  value="${value//\"/\"\"}"
  printf '"%s"' "${value}"
}

formal_find_qverify() {
  local candidate
  local -a candidates=()
  local questa_home="${QUESTA_HOME:-/data1/questaone_sim/questasim}"
  local questa_formal_home="${QUESTA_FORMAL_HOME:-}"

  if [[ -n "${QVERIFY_BIN:-}" ]]; then
    candidates+=("${QVERIFY_BIN}")
  fi
  if [[ -n "${ZNFORMAL_BIN:-}" ]]; then
    candidates+=("${ZNFORMAL_BIN}")
  fi
  if [[ -n "${questa_formal_home}" ]]; then
    candidates+=(
      "${questa_formal_home}/bin/qverify"
      "${questa_formal_home}/linux_x86_64/qverify"
      "${questa_formal_home}/bin/znformal"
      "${questa_formal_home}/linux_x86_64/znformal"
    )
  fi
  candidates+=(
    qverify
    znformal
    "${questa_home}/bin/qverify"
    "${questa_home}/linux_x86_64/qverify"
    "${questa_home}/bin/znformal"
    "${questa_home}/linux_x86_64/znformal"
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if [[ "${candidate}" == */* ]]; then
      if [[ -x "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    elif command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done

  return 1
}

formal_use_license_env() {
  export QUESTA_HOME="${QUESTA_HOME:-/data1/questaone_sim/questasim}"
  export QSIM_INI="${QSIM_INI:-${QUESTA_HOME}/modelsim.ini}"
  export QUESTA_FORMAL_HOME="${QUESTA_FORMAL_HOME:-}"
  export LM_LICENSE_FILE="${ETH_MENTOR_SERVER}"
  export MGLS_LICENSE_FILE="${ETH_MENTOR_SERVER}"
  export SALT_LICENSE_SERVER="${ETH_MENTOR_SERVER}"
}

formal_log_has_failure() {
  local log_path="$1"

  rg -q \
    -e '# UVM_ERROR :[[:space:]]*[1-9][0-9]*' \
    -e '# UVM_FATAL :[[:space:]]*[1-9][0-9]*' \
    -e '\*\* Error:' \
    -e '\*\* Fatal:' \
    "${log_path}"
}

formal_run_stress_suite() {
  local plane="$1"
  local build_dir="$2"
  local strict_mode="$3"
  local tests="$4"
  local stress_top="$5"
  local timestamp="$6"
  local suite_log="$7"
  local n_lane="$8"
  local n_shd="$9"
  local ticket_fifo_depth="${10}"
  local page_ram_depth="${11}"
  local plane_note="${12}"
  local run_do
  local -a summaries=()
  local -a make_args=()
  local test
  local test_log
  local status
  local pass_count=0
  local fail_count=0
  local summary_joined=""

  if [[ -z "${tests}" ]]; then
    FORMAL_RESULT_STATUS="fallback_stress_not_configured"
    FORMAL_RESULT_BACKEND="simulation_formal_like"
    FORMAL_RESULT_NOTE="${plane_note}; no formal-like stress tests configured"
    return 0
  fi

  run_do="${FORMAL_RUN_DO:-run -all; quit -f}"
  printf '[formal_%s] fallback_backend=stress tests=%s\n' "${plane}" "${tests}" | tee -a "${suite_log}"

  for test in ${tests}; do
    test_log="${FORMAL_LOG_DIR}/formal_${plane}_${test}_${timestamp}.log"
    make_args=(
      "-C" "${UVM_DIR}"
      "run_no_compile"
      "TEST=${test}"
      "TOP=${stress_top}"
      "RUN_DO=${run_do}"
      "DUT_IMPL=native_sv"
      "FORMAL_SVA=1"
      "FORMAL_PLANE=${plane}"
      "FORMAL_STRICT=${strict_mode}"
      "BUILD_DIR=${build_dir}"
      "OPQ_N_LANE=${n_lane}"
      "OPQ_N_SHD=${n_shd}"
      "OPQ_TICKET_FIFO_DEPTH=${ticket_fifo_depth}"
      "OPQ_PAGE_RAM_DEPTH=${page_ram_depth}"
    )
    if [[ -n "${FORMAL_VSIM_PLUSARGS:-}" ]]; then
      make_args+=("VSIM_PLUSARGS=${FORMAL_VSIM_PLUSARGS}")
    fi

    printf '[formal_%s] stress_test=%s log=%s\n' "${plane}" "${test}" "${test_log}" | tee -a "${suite_log}"
    if make "${make_args[@]}" > "${test_log}" 2>&1; then
      if formal_log_has_failure "${test_log}"; then
        status="fail"
        fail_count=$((fail_count + 1))
      else
        status="pass"
        pass_count=$((pass_count + 1))
      fi
    else
      status="fail"
      fail_count=$((fail_count + 1))
    fi
    summaries+=("${test}:${status}")
    printf '[formal_%s] stress_test=%s status=%s\n' "${plane}" "${test}" "${status}" | tee -a "${suite_log}"
  done

  if ((${#summaries[@]} > 0)); then
    summary_joined="$(printf '%s;' "${summaries[@]}")"
    summary_joined="${summary_joined%;}"
  fi

  FORMAL_RESULT_BACKEND="simulation_formal_like"
  FORMAL_RESULT_NOTE="${plane_note}; formal-like stress tests=${summary_joined}; pass=${pass_count}; fail=${fail_count}"
  if ((fail_count == 0)); then
    FORMAL_RESULT_STATUS="fallback_stress_pass"
  else
    FORMAL_RESULT_STATUS="fallback_stress_fail"
  fi
}

formal_write_csv() {
  local csv_path="$1"
  local plane="$2"
  local timestamp="$3"
  local build_dir="$4"
  local tops="$5"
  local compile_status="$6"
  local elab_status="$7"
  local formal_status="$8"
  local backend="$9"
  local n_lane="${10}"
  local n_shd="${11}"
  local ticket_fifo_depth="${12}"
  local page_ram_depth="${13}"
  local strict_mode="${14}"
  local log_file="${15}"
  local note="${16}"

  {
    printf 'plane,timestamp,build_dir,tops,compile_status,elab_status,formal_status,backend,n_lane,n_shd,ticket_fifo_depth,page_ram_depth,strict_mode,log_file,note\n'
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "$(formal_csv_escape "${plane}")" \
      "$(formal_csv_escape "${timestamp}")" \
      "$(formal_csv_escape "${build_dir}")" \
      "$(formal_csv_escape "${tops}")" \
      "$(formal_csv_escape "${compile_status}")" \
      "$(formal_csv_escape "${elab_status}")" \
      "$(formal_csv_escape "${formal_status}")" \
      "$(formal_csv_escape "${backend}")" \
      "$(formal_csv_escape "${n_lane}")" \
      "$(formal_csv_escape "${n_shd}")" \
      "$(formal_csv_escape "${ticket_fifo_depth}")" \
      "$(formal_csv_escape "${page_ram_depth}")" \
      "$(formal_csv_escape "${strict_mode}")" \
      "$(formal_csv_escape "${log_file}")" \
      "$(formal_csv_escape "${note}")"
  } > "${csv_path}"
}

formal_append_history() {
  local csv_path="$1"
  local plane="$2"
  local timestamp="$3"
  local build_dir="$4"
  local tops="$5"
  local compile_status="$6"
  local elab_status="$7"
  local formal_status="$8"
  local backend="$9"
  local n_lane="${10}"
  local n_shd="${11}"
  local ticket_fifo_depth="${12}"
  local page_ram_depth="${13}"
  local strict_mode="${14}"
  local log_file="${15}"
  local note="${16}"

  if [[ ! -f "${csv_path}" ]]; then
    printf 'plane,timestamp,build_dir,tops,compile_status,elab_status,formal_status,backend,n_lane,n_shd,ticket_fifo_depth,page_ram_depth,strict_mode,log_file,note\n' > "${csv_path}"
  fi

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(formal_csv_escape "${plane}")" \
    "$(formal_csv_escape "${timestamp}")" \
    "$(formal_csv_escape "${build_dir}")" \
    "$(formal_csv_escape "${tops}")" \
    "$(formal_csv_escape "${compile_status}")" \
    "$(formal_csv_escape "${elab_status}")" \
    "$(formal_csv_escape "${formal_status}")" \
    "$(formal_csv_escape "${backend}")" \
    "$(formal_csv_escape "${n_lane}")" \
    "$(formal_csv_escape "${n_shd}")" \
    "$(formal_csv_escape "${ticket_fifo_depth}")" \
    "$(formal_csv_escape "${page_ram_depth}")" \
    "$(formal_csv_escape "${strict_mode}")" \
    "$(formal_csv_escape "${log_file}")" \
    "$(formal_csv_escape "${note}")" >> "${csv_path}"
}

formal_run_plane() {
  local plane="$1"
  local tops="$2"
  local default_n_lane="$3"
  local default_n_shd="$4"
  local default_ticket_fifo_depth="$5"
  local default_page_ram_depth="$6"
  local plane_note="$7"
  local stress_tests="${8:-}"
  local probe_tests="${9:-}"
  local _legacy_jobs_unused="${10:-}"
  local timestamp
  local build_dir
  local n_lane
  local n_shd
  local ticket_fifo_depth
  local page_ram_depth
  local strict_mode
  local backend_mode
  local qverify_bin=""
  local compile_status="not_run"
  local elab_status="not_run"
  local formal_status="not_run"
  local backend="compile_elab_only"
  local note="${plane_note}"
  local log_file
  local latest_csv
  local history_csv
  local top
  local elab_fail=0

  timestamp="$(date +%Y%m%d_%H%M%S)"
  build_dir="${BUILD_DIR:-${UVM_DIR}/build_formal_${plane}}"
  n_lane="${FORMAL_OPQ_N_LANE:-${default_n_lane}}"
  n_shd="${FORMAL_OPQ_N_SHD:-${default_n_shd}}"
  ticket_fifo_depth="${FORMAL_OPQ_TICKET_FIFO_DEPTH:-${default_ticket_fifo_depth}}"
  page_ram_depth="${FORMAL_OPQ_PAGE_RAM_DEPTH:-${default_page_ram_depth}}"
  strict_mode="${FORMAL_STRICT:-0}"
  backend_mode="${FORMAL_BACKEND:-auto}"
  log_file="${FORMAL_LOG_DIR}/formal_${plane}_${timestamp}.log"
  latest_csv="${FORMAL_CSV_DIR}/formal_${plane}_latest.csv"
  history_csv="${FORMAL_CSV_DIR}/formal_${plane}_history.csv"

  if [[ -n "${FORMAL_STRESS_TESTS:-}" ]]; then
    stress_tests="${FORMAL_STRESS_TESTS}"
  fi
  if [[ "${FORMAL_STRESS_INCLUDE_PROBES:-0}" == "1" && -n "${probe_tests}" ]]; then
    stress_tests="${stress_tests} ${probe_tests}"
  fi
  if [[ -n "${FORMAL_STRESS_EXTRA_TESTS:-}" ]]; then
    stress_tests="${stress_tests} ${FORMAL_STRESS_EXTRA_TESTS}"
  fi

  formal_use_license_env

  {
    printf '[formal_%s] timestamp=%s\n' "${plane}" "${timestamp}"
    printf '[formal_%s] build_dir=%s tops=%s\n' "${plane}" "${build_dir}" "${tops}"
    printf '[formal_%s] n_lane=%s n_shd=%s ticket_fifo_depth=%s page_ram_depth=%s strict=%s\n' \
      "${plane}" "${n_lane}" "${n_shd}" "${ticket_fifo_depth}" "${page_ram_depth}" "${strict_mode}"
    printf '[formal_%s] note=%s\n' "${plane}" "${plane_note}"
  } | tee "${log_file}"

  if make -C "${UVM_DIR}" compile \
      DUT_IMPL=native_sv \
      FORMAL_SVA=1 \
      FORMAL_PLANE="${plane}" \
      FORMAL_STRICT="${strict_mode}" \
      BUILD_DIR="${build_dir}" \
      OPQ_N_LANE="${n_lane}" \
      OPQ_N_SHD="${n_shd}" \
      OPQ_TICKET_FIFO_DEPTH="${ticket_fifo_depth}" \
      OPQ_PAGE_RAM_DEPTH="${page_ram_depth}" >> "${log_file}" 2>&1; then
    compile_status="pass"
  else
    compile_status="fail"
    elab_status="blocked_compile_failed"
    formal_status="blocked_compile_failed"
    note="${plane_note}; compile failed before formal could run"
  fi

  if [[ "${compile_status}" == "pass" ]]; then
    elab_status="pass"
    for top in ${tops}; do
      if ! make -C "${UVM_DIR}" run \
          TEST=opq_basic_smoke_test \
          TOP="${top}" \
          RUN_DO="quit -f" \
          DUT_IMPL=native_sv \
          FORMAL_SVA=1 \
          FORMAL_PLANE="${plane}" \
          FORMAL_STRICT="${strict_mode}" \
          BUILD_DIR="${build_dir}" \
          OPQ_N_LANE="${n_lane}" \
          OPQ_N_SHD="${n_shd}" \
          OPQ_TICKET_FIFO_DEPTH="${ticket_fifo_depth}" \
          OPQ_PAGE_RAM_DEPTH="${page_ram_depth}" >> "${log_file}" 2>&1; then
        elab_fail=1
        elab_status="fail:${top}"
        note="${plane_note}; elaboration failed at top ${top}"
        break
      fi
    done
  fi

  if [[ "${compile_status}" == "pass" && "${elab_fail}" -eq 0 ]]; then
    case "${backend_mode}" in
      auto)
        if [[ "${FORMAL_STRESS_ENABLE:-0}" == "1" ]]; then
          backend_mode="stress"
        else
          backend_mode="qverify"
        fi
        ;;
    esac

    case "${backend_mode}" in
      qverify)
        if qverify_bin="$(formal_find_qverify 2>/dev/null)"; then
          formal_status="blocked_no_plane_qverify_recipe"
          backend="${qverify_bin}"
          note="${plane_note}; Questa qverify/ZnFormal is the only supported proof backend, but this plane still has no scripted proof recipe wired to ${qverify_bin}"
        else
          formal_status="blocked_no_questa_formal"
          backend="compile_elab_only"
          note="${plane_note}; compile and elaboration passed, but no runnable qverify/ZnFormal executable was found in QUESTA_FORMAL_HOME, QUESTA_HOME=${QUESTA_HOME:-/data1/questaone_sim/questasim}, or PATH"
        fi
        ;;
      sby|yosys|symbiyosys)
        formal_status="blocked_deprecated_backend"
        backend="${backend_mode}"
        note="${plane_note}; deprecated backend ${backend_mode} is disabled in this workspace; use qverify/ZnFormal or explicit FORMAL_BACKEND=stress"
        ;;
      stress)
        formal_run_stress_suite \
          "${plane}" \
          "${build_dir}" \
          "${strict_mode}" \
          "${stress_tests}" \
          "${FORMAL_STRESS_TOP:-tb_top}" \
          "${timestamp}" \
          "${log_file}" \
          "${n_lane}" \
          "${n_shd}" \
          "${ticket_fifo_depth}" \
          "${page_ram_depth}" \
          "${plane_note}"
        formal_status="${FORMAL_RESULT_STATUS}"
        backend="${FORMAL_RESULT_BACKEND}"
        note="${FORMAL_RESULT_NOTE}"
        ;;
      *)
        formal_status="blocked_bad_backend"
        backend="${backend_mode}"
        note="${plane_note}; unsupported FORMAL_BACKEND=${backend_mode}"
        ;;
    esac
  fi

  formal_write_csv \
    "${latest_csv}" \
    "${plane}" \
    "${timestamp}" \
    "${build_dir}" \
    "${tops}" \
    "${compile_status}" \
    "${elab_status}" \
    "${formal_status}" \
    "${backend}" \
    "${n_lane}" \
    "${n_shd}" \
    "${ticket_fifo_depth}" \
    "${page_ram_depth}" \
    "${strict_mode}" \
    "${log_file}" \
    "${note}"

  formal_append_history \
    "${history_csv}" \
    "${plane}" \
    "${timestamp}" \
    "${build_dir}" \
    "${tops}" \
    "${compile_status}" \
    "${elab_status}" \
    "${formal_status}" \
    "${backend}" \
    "${n_lane}" \
    "${n_shd}" \
    "${ticket_fifo_depth}" \
    "${page_ram_depth}" \
    "${strict_mode}" \
    "${log_file}" \
    "${note}"

  printf '[formal_%s] compile=%s elab=%s formal=%s backend=%s\n' \
    "${plane}" "${compile_status}" "${elab_status}" "${formal_status}" "${backend}"
  printf '[formal_%s] log=%s\n' "${plane}" "${log_file}"
  printf '[formal_%s] csv=%s\n' "${plane}" "${latest_csv}"

  [[ "${compile_status}" == "pass" && "${elab_fail}" -eq 0 ]]
}

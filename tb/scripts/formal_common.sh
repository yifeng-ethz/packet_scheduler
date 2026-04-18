#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_common
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.2 - add a stable fallback-stress API alongside the future proof backend
# Description:
#   Shared utilities for the `formal_*.sh` wrappers described in DV_FORMAL.
#   The wrappers intentionally isolate their build trees from the normal UVM
#   regression build so formal checker compile/elaboration cannot corrupt the
#   signoff simulation flow.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${TB_DIR}/uvm"
FORMAL_RUN_DIR="${TB_DIR}/formal_runs"
FORMAL_LOG_DIR="${FORMAL_RUN_DIR}/logs"
FORMAL_CSV_DIR="${FORMAL_RUN_DIR}/csv"
ETH_MENTOR_SERVER="${ETH_MENTOR_SERVER:-8161@lic-mentor.ethz.ch}"

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

  if [[ -n "${QVERIFY_BIN:-}" ]]; then
    candidates+=("${QVERIFY_BIN}")
  fi
  candidates+=(
    qverify
    /data1/intelFPGA_pro/23.1/questa_fse/bin/qverify
    /data1/intelFPGA_pro/23.1/questa_fe/bin/qverify
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

formal_find_sby() {
  local candidate
  local -a candidates=()

  if [[ -n "${SBY_BIN:-}" ]]; then
    candidates+=("${SBY_BIN}")
  fi
  candidates+=(
    /data1/oss_formal/bin/sby
    /data1/oss_formal/bin/symbiyosys
    sby
    symbiyosys
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

formal_find_yosys() {
  local candidate
  local -a candidates=()

  if [[ -n "${YOSYS_BIN:-}" ]]; then
    candidates+=("${YOSYS_BIN}")
  fi
  candidates+=(
    /data1/oss_formal/bin/yosys
    yosys
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

formal_find_bitwuzla() {
  local candidate
  local -a candidates=()

  if [[ -n "${BITWUZLA_BIN:-}" ]]; then
    candidates+=("${BITWUZLA_BIN}")
  fi
  candidates+=(
    /data1/oss_formal/bin/bitwuzla
    bitwuzla
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
  local chain="${ETH_MENTOR_SERVER}"

  if [[ -n "${LM_LICENSE_FILE:-}" ]]; then
    chain="${ETH_MENTOR_SERVER}:${LM_LICENSE_FILE}"
  fi

  export LM_LICENSE_FILE="${chain}"
  export MGLS_LICENSE_FILE="${chain}"
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
      "QUESTA_PREFER_FE=${QUESTA_PREFER_FE:-0}"
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

formal_run_sby_suite() {
  local plane="$1"
  local timestamp="$2"
  local suite_log="$3"
  local sby_bin="$4"
  local sby_engine="$5"
  local sby_jobs="$6"
  local plane_note="$7"
  local sby_tasks="${FORMAL_SBY_TASKS:-prove}"
  local -a summaries=()
  local -a task_args=()
  local job
  local job_log
  local status
  local rc
  local pass_count=0
  local fail_count=0
  local error_count=0
  local summary_joined=""

  if [[ -z "${sby_jobs}" ]]; then
    FORMAL_RESULT_STATUS="blocked_no_scripted_sby_flow"
    FORMAL_RESULT_BACKEND="sby+yosys+${sby_engine}"
    FORMAL_RESULT_NOTE="${plane_note}; OSS formal toolchain is installed, but a plane-specific Yosys/SBY harness is not wired yet."
    return 0
  fi

  for task in ${sby_tasks}; do
    task_args+=("${task}")
  done

  printf '[formal_%s] sby_tasks=%s jobs=%s\n' "${plane}" "${sby_tasks}" "${sby_jobs}" | tee -a "${suite_log}"

  for job in ${sby_jobs}; do
    job_log="${FORMAL_LOG_DIR}/formal_${plane}_${job}_${timestamp}.log"
    printf '[formal_%s] sby_job=%s log=%s\n' "${plane}" "${job}" "${job_log}" | tee -a "${suite_log}"
    set +e
    (
      cd "${TB_DIR}/formal_sby"
      "${sby_bin}" -f "${job}.sby" "${task_args[@]}"
    ) > "${job_log}" 2>&1
    rc=$?
    set -e

    case "${rc}" in
      0)
        status="pass"
        pass_count=$((pass_count + 1))
        ;;
      2)
        status="fail"
        fail_count=$((fail_count + 1))
        ;;
      *)
        status="error"
        error_count=$((error_count + 1))
        ;;
    esac

    summaries+=("${job}:${status}")
    printf '[formal_%s] sby_job=%s status=%s rc=%s\n' "${plane}" "${job}" "${status}" "${rc}" | tee -a "${suite_log}"
  done

  if ((${#summaries[@]} > 0)); then
    summary_joined="$(printf '%s;' "${summaries[@]}")"
    summary_joined="${summary_joined%;}"
  fi

  FORMAL_RESULT_BACKEND="sby+yosys+${sby_engine}"
  FORMAL_RESULT_NOTE="${plane_note}; sby jobs=${summary_joined}; pass=${pass_count}; fail=${fail_count}; error=${error_count}"
  if ((error_count > 0)); then
    FORMAL_RESULT_STATUS="sby_error"
  elif ((fail_count > 0)); then
    FORMAL_RESULT_STATUS="sby_fail"
  else
    FORMAL_RESULT_STATUS="sby_pass"
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
  local sby_jobs="${10:-}"
  local timestamp
  local build_dir
  local n_lane
  local n_shd
  local ticket_fifo_depth
  local page_ram_depth
  local strict_mode
  local backend_mode
  local qverify_bin=""
  local sby_bin=""
  local yosys_bin=""
  local bitwuzla_bin=""
  local sby_engine
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
  local -a missing_tools=()

  timestamp="$(date +%Y%m%d_%H%M%S)"
  build_dir="${BUILD_DIR:-${UVM_DIR}/build_formal_${plane}}"
  n_lane="${FORMAL_OPQ_N_LANE:-${default_n_lane}}"
  n_shd="${FORMAL_OPQ_N_SHD:-${default_n_shd}}"
  ticket_fifo_depth="${FORMAL_OPQ_TICKET_FIFO_DEPTH:-${default_ticket_fifo_depth}}"
  page_ram_depth="${FORMAL_OPQ_PAGE_RAM_DEPTH:-${default_page_ram_depth}}"
  strict_mode="${FORMAL_STRICT:-0}"
  backend_mode="${FORMAL_BACKEND:-auto}"
  sby_engine="${FORMAL_SBY_ENGINE:-bitwuzla}"
  log_file="${FORMAL_LOG_DIR}/formal_${plane}_${timestamp}.log"
  latest_csv="${FORMAL_CSV_DIR}/formal_${plane}_latest.csv"
  history_csv="${FORMAL_CSV_DIR}/formal_${plane}_history.csv"

  if [[ -n "${FORMAL_STRESS_TESTS:-}" ]]; then
    stress_tests="${FORMAL_STRESS_TESTS}"
  fi
  if [[ -n "${FORMAL_SBY_JOBS:-}" ]]; then
    sby_jobs="${FORMAL_SBY_JOBS}"
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
        if [[ "${FORMAL_QVERIFY_ENABLE:-0}" == "1" ]]; then
          backend_mode="qverify"
        elif [[ "${FORMAL_SBY_ENABLE:-0}" == "1" ]]; then
          backend_mode="sby"
        else
          backend_mode="stress"
        fi
        ;;
    esac

    case "${backend_mode}" in
      qverify)
        if qverify_bin="$(formal_find_qverify 2>/dev/null)"; then
          formal_status="blocked_no_scripted_qverify_flow"
          backend="${qverify_bin}"
          note="${plane_note}; qverify is installed but a scripted plane-specific proof harness is not yet wired on this host"
        else
          formal_status="blocked_no_qverify"
          backend="compile_elab_only"
          note="${plane_note}; compile and elaboration passed, but qverify/znformal is not installed on this host"
        fi
        ;;
      sby)
        missing_tools=()
        if ! sby_bin="$(formal_find_sby 2>/dev/null)"; then
          missing_tools+=("sby")
        fi
        if ! yosys_bin="$(formal_find_yosys 2>/dev/null)"; then
          missing_tools+=("yosys")
        fi
        if [[ "${sby_engine}" == "bitwuzla" ]]; then
          if ! bitwuzla_bin="$(formal_find_bitwuzla 2>/dev/null)"; then
            missing_tools+=("bitwuzla")
          fi
        fi

        if ((${#missing_tools[@]} > 0)); then
          formal_status="blocked_no_sby_toolchain"
          backend="compile_elab_only"
          note="${plane_note}; FORMAL_BACKEND=sby requested but missing tools: ${missing_tools[*]}"
        else
          formal_run_sby_suite \
            "${plane}" \
            "${timestamp}" \
            "${log_file}" \
            "${sby_bin}" \
            "${sby_engine}" \
            "${sby_jobs}" \
            "${plane_note}"
          formal_status="${FORMAL_RESULT_STATUS}"
          backend="${FORMAL_RESULT_BACKEND}"
          note="${FORMAL_RESULT_NOTE}"
        fi
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

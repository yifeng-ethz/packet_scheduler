#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_common
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.1 - shared helpers for OPQ packet-formal compile/elab wrappers
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

formal_use_license_env() {
  local chain="${ETH_MENTOR_SERVER}"

  if [[ -n "${LM_LICENSE_FILE:-}" ]]; then
    chain="${ETH_MENTOR_SERVER}:${LM_LICENSE_FILE}"
  fi

  export LM_LICENSE_FILE="${chain}"
  export MGLS_LICENSE_FILE="${chain}"
  export SALT_LICENSE_SERVER="${ETH_MENTOR_SERVER}"
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
  local timestamp
  local build_dir
  local n_lane
  local n_shd
  local ticket_fifo_depth
  local page_ram_depth
  local strict_mode
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
  log_file="${FORMAL_LOG_DIR}/formal_${plane}_${timestamp}.log"
  latest_csv="${FORMAL_CSV_DIR}/formal_${plane}_latest.csv"
  history_csv="${FORMAL_CSV_DIR}/formal_${plane}_history.csv"

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
    if qverify_bin="$(formal_find_qverify 2>/dev/null)"; then
      formal_status="blocked_no_scripted_qverify_flow"
      backend="${qverify_bin}"
      note="${plane_note}; qverify is installed but a scripted plane-specific proof harness is not yet wired on this host"
    else
      formal_status="blocked_no_qverify"
      backend="compile_elab_only"
      note="${plane_note}; compile and elaboration passed, but qverify/znformal is not installed on this host"
    fi
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

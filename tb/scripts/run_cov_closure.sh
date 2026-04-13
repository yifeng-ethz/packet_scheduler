#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COV_DIR="${TB_DIR}/sim_runs/coverage"

QUESTA_HOME="${QUESTA_HOME:-/data1/intelFPGA_pro/23.1/questa_fse}"
VCOVER="$(find "${QUESTA_HOME}" -maxdepth 2 -type f -name vcover | head -n1)"

if [[ -z "${VCOVER}" ]]; then
  echo "vcover not found under ${QUESTA_HOME}" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  TESTS=(
    opq_basic_smoke_test
    opq_edge_placeholder_test
    opq_prof_placeholder_test
    opq_error_placeholder_test
    opq_cross_placeholder_test
  )
else
  TESTS=("$@")
fi

rm -rf "${COV_DIR}"
mkdir -p "${COV_DIR}"

COV_ENABLE=1 "${SCRIPT_DIR}/run_uvm.sh" "${TESTS[@]}"

mapfile -t UCDBS < <(find "${COV_DIR}" -maxdepth 1 -type f -name '*.ucdb' | sort)
if [[ "${#UCDBS[@]}" -eq 0 ]]; then
  echo "No UCDB files produced under ${COV_DIR}" >&2
  exit 1
fi

"${VCOVER}" merge "${COV_DIR}/opq_merged.ucdb" "${UCDBS[@]}"
"${SCRIPT_DIR}/coverage_report.sh" "${COV_DIR}/opq_merged.ucdb"

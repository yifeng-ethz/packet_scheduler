#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

QUESTA_HOME="${QUESTA_HOME:-/data1/intelFPGA_pro/23.1/questa_fse}"
VCOVER="$(find "${QUESTA_HOME}" -maxdepth 2 -type f -name vcover | head -n1)"

if [[ -z "${VCOVER}" ]]; then
  echo "vcover not found under ${QUESTA_HOME}" >&2
  exit 1
fi

UCDB_PATH="${1:-${TB_DIR}/sim_runs/coverage/opq_merged.ucdb}"
if [[ ! -f "${UCDB_PATH}" ]]; then
  echo "UCDB not found: ${UCDB_PATH}" >&2
  exit 1
fi

"${VCOVER}" report -details -all "${UCDB_PATH}"

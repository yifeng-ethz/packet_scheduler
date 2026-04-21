#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/../../../scripts/questa_one_env.sh"

UCDB_PATH="${1:-${TB_DIR}/sim_runs/coverage/opq_merged.ucdb}"
if [[ ! -f "${UCDB_PATH}" ]]; then
  echo "UCDB not found: ${UCDB_PATH}" >&2
  exit 1
fi

"${VCOVER}" report -details -all "${UCDB_PATH}"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/run_basic.sh"
"${SCRIPT_DIR}/run_edge.sh"
"${SCRIPT_DIR}/run_perf.sh"
"${SCRIPT_DIR}/run_error.sh"
"${SCRIPT_DIR}/run_cross.sh"

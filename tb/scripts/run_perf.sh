#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- opq_prof_stress_test opq_prof_lane_skew_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

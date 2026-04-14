#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_cross_bp_credit_test \
    opq_cross_drr_allowance_test \
    opq_cross_drr_idle_lane_test \
    opq_cross_drr_zero_allowance_test \
    opq_cross_drr_short_allowance_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

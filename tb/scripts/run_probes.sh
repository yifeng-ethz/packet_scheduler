#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- opq_cross_drr_bursty_random_test opq_error_lane_mask_recovery_test opq_error_ftable_overflow_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

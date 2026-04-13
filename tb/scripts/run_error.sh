#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- opq_error_lane_mask_test opq_error_ftable_overflow_test opq_error_counter_clear_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

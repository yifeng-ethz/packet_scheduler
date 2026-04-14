#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_edge_backpressure_test \
    opq_edge_always_ready_test \
    opq_edge_ready_medium_profile_test \
    opq_edge_stuck_low_backpressure_test \
    opq_edge_max_hits_test \
    opq_edge_toggle_backpressure_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

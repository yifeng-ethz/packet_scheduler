#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- opq_edge_backpressure_test opq_edge_always_ready_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

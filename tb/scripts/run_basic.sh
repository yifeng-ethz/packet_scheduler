#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- opq_basic_smoke_test opq_basic_ts_boundary_test opq_basic_subheader_shape_test
fi

"${SCRIPT_DIR}/run_uvm.sh" "$@"

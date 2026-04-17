#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_basic.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_basic_smoke_test \
    opq_basic_ts_boundary_test \
    opq_basic_subheader_shape_test \
    opq_basic_feb_packet_contract_test
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"

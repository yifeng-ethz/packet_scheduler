#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_all.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_basic.sh"
DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_param.sh"
DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_edge.sh"
DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_perf.sh"
DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_error.sh"
DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_cross.sh"

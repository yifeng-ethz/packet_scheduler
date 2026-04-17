#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_bucket_frame_native_sv_test \
    opq_all_buckets_frame_native_sv_test
fi

COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" "${SCRIPT_DIR}/run_uvm.sh" "$@"

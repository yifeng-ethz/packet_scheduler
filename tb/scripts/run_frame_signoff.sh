#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$#" -eq 0 ]]; then
  COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" "${SCRIPT_DIR}/run_uvm.sh" \
    opq_bucket_frame_native_sv_test \
    opq_all_buckets_frame_native_sv_test \
    opq_cross_mixed_bucket_random_soak_test \
    opq_error_counter_clear_test

  COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" OPQ_PAGE_RAM_DEPTH=512 "${SCRIPT_DIR}/run_uvm.sh" \
    opq_error_ftable_overflow_test
  exit 0
fi

COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" "${SCRIPT_DIR}/run_uvm.sh" "$@"

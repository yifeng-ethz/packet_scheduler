#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_ingress
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.3 - use a stable wrapper-facing ingress fallback alias and keep malformed cases probe-only
# Description:
#   Executes the ingress-side packet-formal readiness flow from DV_FORMAL
#   plane A/B using an isolated build directory.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/formal_common.sh"

formal_run_plane \
  "ingress" \
  "opq_formal_ingress_tb" \
  "2" \
  "256" \
  "512" \
  "1024" \
  "Plane A/B ingress-parser packet-shape and credit invariants on the live native-SV path" \
  "opq_basic_smoke_test opq_formal_like_ingress_recovery_stress_test" \
  "opq_error_header_mask_recovery_test opq_error_header_word_mask_recovery_test" \
  "opq_oss_ingress"

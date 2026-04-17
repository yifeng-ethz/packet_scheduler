#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_mover
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.1 - plane C/D packet-formal compile/elab wrapper
# Description:
#   Executes the allocator/block-mover packet-formal readiness flow from
#   DV_FORMAL plane C/D using an isolated build directory.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/formal_common.sh"

formal_run_plane \
  "mover" \
  "tb_top" \
  "2" \
  "8" \
  "16" \
  "2048" \
  "Plane C/D allocator, page-writer, and DRR block-mover invariants on the live native-SV path" \
  "opq_cross_drr_allowance_test opq_cross_drr_short_allowance_test opq_cross_bp_credit_test" \
  "opq_cross_drr_bursty_random_test"

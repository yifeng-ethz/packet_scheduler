#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_egress
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.1 - plane E/F packet-formal compile/elab wrapper
# Description:
#   Executes the egress-side packet-formal readiness flow from DV_FORMAL
#   plane E/F using an isolated build directory. This validates both the live
#   basic-presenter top and the standalone tiled frame-table translation top.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/formal_common.sh"

formal_run_plane \
  "egress" \
  "tb_top opq_formal_ftable_tb" \
  "2" \
  "8" \
  "16" \
  "512" \
  "Plane E/F live basic-presenter checks plus standalone frame-table tracker/presenter elaboration" \
  "opq_edge_toggle_backpressure_test opq_edge_stuck_low_backpressure_test" \
  "opq_formal_like_egress_flush_backpressure_stress_test opq_error_ftable_overflow_test"

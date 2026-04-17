#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : formal_ingress
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.1 - plane A/B packet-formal compile/elab wrapper
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
  "8" \
  "16" \
  "256" \
  "Plane A/B ingress-parser packet-shape and credit invariants on the live native-SV path"

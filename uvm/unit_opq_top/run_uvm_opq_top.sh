#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper: run the existing OPQ top UVM TB using the *split* RTL implementation.
#
# This delegates to `uvm_order_priority_queue/run_uvm.sh`, which already handles:
# - TERP preprocessing for stable entity naming + lane-count port generation
# - Compile-time lane-port `define`s for `N_LANE=2..16`
# - UVM_NO_DPI patching for ModelSim
#
# Usage:
#   OPQ_N_LANE=4 OPQ_IMPL=split bash ./run_uvm_opq_top.sh +UVM_TESTNAME=opq_test +EGRESS_READY_MODE=0 ...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

exec bash "${ROOT_DIR}/uvm_order_priority_queue/run_uvm.sh" "$@"

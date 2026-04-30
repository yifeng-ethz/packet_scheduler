#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : packet_scheduler OPQ normalized-share full scan
# Revision  : 0.1 - launchable 128-point RTL/UVM scan around N4/E1 knee
# Description:
#   Runs the corrected physical-cadence OPQ model-publish UVM scan on a
#   normalized per-lane egress-share grid concentrated around the persistent
#   bottleneck knee. After RTL reduction completes, the structural OPQ TLM is
#   replayed against the same rows.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SCAN_ID="${SCAN_ID:-20260429}"
SHALLOW_TARGET_HITS="${SHALLOW_TARGET_HITS:-10000}"
DEEP_TARGET_HITS="${DEEP_TARGET_HITS:-1000000}"
DEEP_LOSS_THRESHOLD="${DEEP_LOSS_THRESHOLD:-0.001}"
TIMEOUT_SEC="${TIMEOUT_SEC:-7200}"
SEED="${SEED:-0x5c1fA001}"

RUN_ROOT="${RUN_ROOT:-${PKT_ROOT}/model/rtl_sim/runs/opq_normalized_share_fullscan_${SCAN_ID}}"
BUILD_ROOT="${BUILD_ROOT:-${PKT_ROOT}/model/rtl_sim/build_runs_opq_normalized_share_fullscan_${SCAN_ID}}"
RTL_CSV="${RTL_CSV:-${PKT_ROOT}/model/rtl_sim/data/opq_normalized_share_fullscan_n4_e1.csv}"
PIN_CSV="${PIN_CSV:-${PKT_ROOT}/model/rtl_sim/data/opq_normalized_share_fullscan_n4_e1_pins.csv}"
TLM_CSV="${TLM_CSV:-${PKT_ROOT}/model/rtl_sim/data/opq_structural_tlm_normalized_share_fullscan_n4_e1.csv}"

mkdir -p "${RUN_ROOT}" "${BUILD_ROOT}" "$(dirname "${RTL_CSV}")"

POINTS="$(python3 - <<'PY'
b_vals = [0, 100, 200, 300, 403, 500, 700, 900]
shares = [
    0.180, 0.200, 0.220, 0.230,
    0.235, 0.240, 0.242, 0.245,
    0.250, 0.255, 0.260, 0.270,
    0.280, 0.300, 0.340, 0.400,
]
print(",".join(f"{b}:{share:.3f}" for b in b_vals for share in shares))
PY
)"

{
  printf 'scan_id=%s\n' "${SCAN_ID}"
  printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'points=128\n'
  printf 'shallow_target_hits=%s\n' "${SHALLOW_TARGET_HITS}"
  printf 'deep_target_hits=%s\n' "${DEEP_TARGET_HITS}"
  printf 'deep_loss_threshold=%s\n' "${DEEP_LOSS_THRESHOLD}"
  printf 'run_root=%s\n' "${RUN_ROOT}"
  printf 'rtl_csv=%s\n' "${RTL_CSV}"
  printf 'tlm_csv=%s\n' "${TLM_CSV}"
} > "${RUN_ROOT}/fullscan.meta"

cd "${PKT_ROOT}"

python3 model/rtl_sim/scripts/run_opq_normalized_share_scan.py \
  --points "${POINTS}" \
  --seed "${SEED}" \
  --shallow-target-hits "${SHALLOW_TARGET_HITS}" \
  --deep-target-hits "${DEEP_TARGET_HITS}" \
  --deep-loss-threshold "${DEEP_LOSS_THRESHOLD}" \
  --run-root "${RUN_ROOT}" \
  --build-root "${BUILD_ROOT}" \
  --csv "${RTL_CSV}" \
  --pin-csv "${PIN_CSV}" \
  --timeout-sec "${TIMEOUT_SEC}" \
  --resume

python3 model/tlm/scripts/opq_structural_tlm.py \
  --input "${RTL_CSV}" \
  --output "${TLM_CSV}"

printf 'completed_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${RUN_ROOT}/fullscan.meta"

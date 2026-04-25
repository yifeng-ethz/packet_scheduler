#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_lane_skew_loss
# Revision  : 0.2 - render OPQ lane-skew loss plot from RTL simulation only
# Description:
#   Emit PNG/SVG artifacts from an explicitly supplied HDL-simulation CSV.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IP_DIR="$(cd "${TB_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${TB_DIR}/REPORT/math}"
BUILD_DIR="${REPORT_DIR}/.build"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"

mkdir -p "${REPORT_DIR}" "${BUILD_DIR}"

if [[ -z "${RTL_LANE_SKEW_CSV:-}" ]]; then
  cat >&2 <<'EOF'
Refusing to render an analytical/proxy lane-skew curve.
Set RTL_LANE_SKEW_CSV to a CSV emitted by an HDL simulation sweep.
EOF
  exit 2
fi

if [[ ! -f "${RTL_LANE_SKEW_CSV}" ]]; then
  printf 'RTL_LANE_SKEW_CSV does not exist: %s\n' "${RTL_LANE_SKEW_CSV}" >&2
  exit 2
fi

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/opq_lane_skew_loss_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_lane_skew_loss_plot"

"${BUILD_DIR}/opq_lane_skew_loss_plot" \
  "${RTL_LANE_SKEW_CSV}" \
  "${REPORT_DIR}/lane_skew_loss.png"

"${BUILD_DIR}/opq_lane_skew_loss_plot" \
  "${RTL_LANE_SKEW_CSV}" \
  "${REPORT_DIR}/lane_skew_loss.svg"

printf 'Wrote %s\n' "${REPORT_DIR}/lane_skew_loss.png"
printf 'Wrote %s\n' "${REPORT_DIR}/lane_skew_loss.svg"

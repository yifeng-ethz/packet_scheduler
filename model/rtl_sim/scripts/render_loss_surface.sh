#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_loss_surface
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.2 - render OPQ loss-surface data from RTL simulation only
# Description:
#   Build the local DISLIN contour renderer and emit PNG/SVG loss-surface plots
#   from an explicitly supplied HDL-simulation matrix.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_SIM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODEL_DIR="$(cd "${RTL_SIM_DIR}/.." && pwd)"
IP_DIR="$(cd "${MODEL_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${RTL_SIM_DIR}/plots}"
BUILD_DIR="${REPORT_DIR}/.build"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"
ANALYTICAL_SCRIPT_DIR="${MODEL_DIR}/analytical/scripts"

mkdir -p "${REPORT_DIR}" "${BUILD_DIR}"

if [[ -z "${RTL_LOSS_SURFACE_DAT:-}" ]]; then
  cat >&2 <<'EOF'
Refusing to render an analytical/proxy loss surface.
Set RTL_LOSS_SURFACE_DAT to a DISLIN matrix emitted by an HDL simulation sweep.
EOF
  exit 2
fi

if [[ ! -f "${RTL_LOSS_SURFACE_DAT}" ]]; then
  printf 'RTL_LOSS_SURFACE_DAT does not exist: %s\n' "${RTL_LOSS_SURFACE_DAT}" >&2
  exit 2
fi

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_loss_surface_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_loss_surface_plot"

"${BUILD_DIR}/opq_loss_surface_plot" \
  "${RTL_LOSS_SURFACE_DAT}" \
  "${REPORT_DIR}/loss_surface_contour.png"

"${BUILD_DIR}/opq_loss_surface_plot" \
  "${RTL_LOSS_SURFACE_DAT}" \
  "${REPORT_DIR}/loss_surface_contour.svg"

printf 'Wrote %s\n' "${REPORT_DIR}/loss_surface_contour.png"
printf 'Wrote %s\n' "${REPORT_DIR}/loss_surface_contour.svg"

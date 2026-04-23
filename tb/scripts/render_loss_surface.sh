#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_loss_surface
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Revision  : 0.1 - generate OPQ analytical loss-surface data and DISLIN plots
# Description:
#   Build the local DISLIN contour renderer and emit PNG/SVG loss-surface plots.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IP_DIR="$(cd "${TB_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${TB_DIR}/REPORT/math}"
BUILD_DIR="${REPORT_DIR}/.build"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"

mkdir -p "${REPORT_DIR}" "${BUILD_DIR}"

python3 "${SCRIPT_DIR}/opq_loss_surface_model.py" --output-dir "${REPORT_DIR}"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/opq_loss_surface_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_loss_surface_plot"

"${BUILD_DIR}/opq_loss_surface_plot" \
  "${REPORT_DIR}/loss_surface_grid.dat" \
  "${REPORT_DIR}/loss_surface_contour.png"

"${BUILD_DIR}/opq_loss_surface_plot" \
  "${REPORT_DIR}/loss_surface_grid.dat" \
  "${REPORT_DIR}/loss_surface_contour.svg"

printf 'Wrote %s\n' "${REPORT_DIR}/loss_surface_contour.png"
printf 'Wrote %s\n' "${REPORT_DIR}/loss_surface_contour.svg"

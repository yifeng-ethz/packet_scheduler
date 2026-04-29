#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_opq_loss_surface_family
# Revision  : 0.2 - render OPQ lane/egress-width RTL contour family
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_SIM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODEL_DIR="$(cd "${RTL_SIM_DIR}/.." && pwd)"
IP_DIR="$(cd "${MODEL_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${RTL_SIM_DIR}/plots/opq_family}"
BUILD_DIR="${REPORT_DIR}/.build"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"
ANALYTICAL_SCRIPT_DIR="${MODEL_DIR}/analytical/scripts"

mkdir -p "${REPORT_DIR}" "${BUILD_DIR}"

if [[ -z "${RTL_OPQ_FAMILY_DIR:-}" ]]; then
  cat >&2 <<'EOF'
Refusing to render an analytical/proxy OPQ lane/egress contour family.
Set RTL_OPQ_FAMILY_DIR to a directory of DISLIN matrices emitted by HDL sweeps.
EOF
  exit 2
fi

if [[ ! -d "${RTL_OPQ_FAMILY_DIR}" ]]; then
  printf 'RTL_OPQ_FAMILY_DIR does not exist: %s\n' "${RTL_OPQ_FAMILY_DIR}" >&2
  exit 2
fi

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_loss_surface_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_loss_surface_plot"

for n_lane in 4 8 16; do
  for egress_symbols in 1 2 4 8; do
    stem="$(printf 'opq_loss_surface_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    if [[ ! -f "${RTL_OPQ_FAMILY_DIR}/${stem}.dat" ]]; then
      printf 'missing RTL family matrix: %s\n' "${RTL_OPQ_FAMILY_DIR}/${stem}.dat" >&2
      exit 2
    fi
    title="OPQ IP-Core Loss Contour N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="x: B=(CV-1)/(CV+1), y: rate/lane; egress=${egress_symbols} symbol(s)/beat, N_LANE=${n_lane}"
    OPQ_LOSS_SURFACE_TITLE="${title}" \
    OPQ_LOSS_SURFACE_NOTE="${note}" \
      "${BUILD_DIR}/opq_loss_surface_plot" "${RTL_OPQ_FAMILY_DIR}/${stem}.dat" "${REPORT_DIR}/${stem}.png"
    OPQ_LOSS_SURFACE_TITLE="${title}" \
    OPQ_LOSS_SURFACE_NOTE="${note}" \
      "${BUILD_DIR}/opq_loss_surface_plot" "${RTL_OPQ_FAMILY_DIR}/${stem}.dat" "${REPORT_DIR}/${stem}.svg"
    printf 'Wrote %s\n' "${REPORT_DIR}/${stem}.png"
    printf 'Wrote %s\n' "${REPORT_DIR}/${stem}.svg"
  done
done

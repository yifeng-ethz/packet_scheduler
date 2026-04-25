#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_tlm_dislin
# Revision  : 0.1 - render TLM packet_scheduler loss-sweep plots with DISLIN
# Description:
#   Generates transaction-level finite-FIFO loss tables, then renders the
#   report-published figures with DISLIN C renderers. Python is used only for
#   TLM event/data generation, not for publishing plots.
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TLM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODEL_DIR_ROOT="$(cd "${TLM_DIR}/.." && pwd)"
IP_DIR="$(cd "${MODEL_DIR_ROOT}/.." && pwd)"
ANALYTICAL_SCRIPT_DIR="${MODEL_DIR_ROOT}/analytical/scripts"
MODEL_DIR="${MODEL_DIR:-${TLM_DIR}/data}"
PLOT_DIR="${PLOT_DIR:-${TLM_DIR}/plots}"
BUILD_DIR="${BUILD_DIR:-${MODEL_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"

mkdir -p "${MODEL_DIR}" "${PLOT_DIR}" "${BUILD_DIR}"

python3 "${SCRIPT_DIR}/opq_tlm_feature_sweep.py" \
  --output-dir "${MODEL_DIR}" \
  --plot-output-dir "${PLOT_DIR}"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_loss_surface_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_loss_surface_plot"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_vs_time_merger_contour_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_vs_time_merger_contour_plot"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_queueing_loss_curve_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_queueing_loss_curve_plot"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_queueing_ratio_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_queueing_ratio_plot"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${ANALYTICAL_SCRIPT_DIR}/opq_queueing_scaling_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_queueing_scaling_plot"

for n_lane in 4 8 16; do
  for egress_symbols in 1 2 4 8; do
    loss_stem="$(printf 'opq_loss_surface_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    overlay_stem="$(printf 'opq_vs_time_merger_loss_contour_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    curve_stem="$(printf 'opq_vs_time_merger_loss_curve_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    ratio_stem="$(printf 'opq_vs_time_merger_ready_burst_ratio_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"

    title="TLM OPQ Loss Surface N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM finite-FIFO event model, ready duty=1.0; egress=${egress_symbols} word(s)/beat, N_LANE=${n_lane}"
    OPQ_LOSS_SURFACE_TITLE="${title}" \
    OPQ_LOSS_SURFACE_NOTE="${note}" \
      "${BUILD_DIR}/opq_loss_surface_plot" \
      "${MODEL_DIR}/dislin/${loss_stem}.dat" \
      "${PLOT_DIR}/${loss_stem}.png"

    title="TLM OPQ vs Time-Merger Loss Contours N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM x: B=(SCV-1)/(SCV+1), y: offered rate/lane; time-merger one-word tree with quadratic depth penalty"
    OPQ_TM_CONTOUR_TITLE="${title}" \
    OPQ_TM_CONTOUR_NOTE="${note}" \
      "${BUILD_DIR}/opq_vs_time_merger_contour_plot" \
      "${MODEL_DIR}/dislin/${overlay_stem}_opq.dat" \
      "${MODEL_DIR}/dislin/${overlay_stem}_time_merger.dat" \
      "${PLOT_DIR}/${overlay_stem}.png"

    title="TLM OPQ vs Time-Merger Loss Curve N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM curve at B=0.70, ready duty=0.75; x sweeps per-lane offered rate"
    OPQ_LOSS_CURVE_TITLE="${title}" \
    OPQ_LOSS_CURVE_NOTE="${note}" \
      "${BUILD_DIR}/opq_queueing_loss_curve_plot" \
      "${MODEL_DIR}/dislin/${curve_stem}.dat" \
      "${PLOT_DIR}/${curve_stem}.png"

    title="TLM OPQ vs Time-Merger Ready/Burst Ratio N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM comparison at rho_lane=0.0075; OPQ egress=${egress_symbols}x, time-merger one-word tree"
    OPQ_RATIO_TITLE="${title}" \
    OPQ_RATIO_NOTE="${note}" \
      "${BUILD_DIR}/opq_queueing_ratio_plot" \
      "${MODEL_DIR}/dislin/${ratio_stem}.dat" \
      "${PLOT_DIR}/${ratio_stem}.png"
  done
done

OPQ_SCALING_TITLE="TLM OPQ vs Time-Merger Feature Sweep Loss Ratio" \
OPQ_SCALING_NOTE="TLM stress point B=0.70, ready duty=0.75, rho_lane=0.0075" \
  "${BUILD_DIR}/opq_queueing_scaling_plot" \
  "${MODEL_DIR}/dislin/opq_vs_time_merger_feature_scaling.dat" \
  "${PLOT_DIR}/opq_vs_time_merger_feature_scaling.png"

printf 'Wrote DISLIN TLM plots under %s\n' "${PLOT_DIR}"

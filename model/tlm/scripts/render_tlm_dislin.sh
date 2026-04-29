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

PIN_CSV="${MODEL_DIR}/dislin/opq_component_replay_12run_pins.csv"
PIN_MARGINAL="${MODEL_DIR_ROOT}/rtl_sim/data/opq_marginal_f100_ridge_12run_pins.csv"
PIN_RIDGE="${MODEL_DIR_ROOT}/rtl_sim/data/opq_component_replay_ridge1pct_30k_closure.csv"
PIN_SOURCE="${MODEL_DIR_ROOT}/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_localpa.csv"
PIN_CLOSURE="${MODEL_DIR_ROOT}/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_closure.csv"
PIN_FALLBACK="${MODEL_DIR_ROOT}/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_rereduce.csv"
pin_source_run_count() {
  python3 - "$1" <<'PY'
import csv
import sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.exists():
    print(0)
    raise SystemExit
with path.open(newline="", encoding="ascii", errors="replace") as handle:
    print(len({row.get("run_tag", "") for row in csv.DictReader(handle) if row.get("run_tag", "")}))
PY
}
if [[ -f "${PIN_MARGINAL}" && "$(pin_source_run_count "${PIN_MARGINAL}")" -ge 12 ]]; then
  cp "${PIN_MARGINAL}" "${PIN_CSV}"
elif [[ -f "${PIN_RIDGE}" && "$(pin_source_run_count "${PIN_RIDGE}")" -ge 12 ]]; then
  python3 "${MODEL_DIR_ROOT}/rtl_sim/scripts/write_component_replay_pin_csv.py" \
    --input "${PIN_RIDGE}" \
    --output "${PIN_CSV}"
elif [[ -f "${PIN_CLOSURE}" && "$(pin_source_run_count "${PIN_CLOSURE}")" -ge 12 ]]; then
  python3 "${MODEL_DIR_ROOT}/rtl_sim/scripts/write_component_replay_pin_csv.py" \
    --input "${PIN_CLOSURE}" \
    --output "${PIN_CSV}"
elif [[ -f "${PIN_SOURCE}" && "$(pin_source_run_count "${PIN_SOURCE}")" -ge 12 ]]; then
  python3 "${MODEL_DIR_ROOT}/rtl_sim/scripts/write_component_replay_pin_csv.py" \
    --input "${PIN_SOURCE}" \
    --output "${PIN_CSV}"
elif [[ -f "${PIN_FALLBACK}" ]]; then
  python3 "${MODEL_DIR_ROOT}/rtl_sim/scripts/write_component_replay_pin_csv.py" \
    --input "${PIN_FALLBACK}" \
    --output "${PIN_CSV}"
fi

ANCHOR_ENV="${MODEL_DIR}/tlm_anchor_sample_point.env"
if [[ -f "${ANCHOR_ENV}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ANCHOR_ENV}"
  set +a
fi

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
    tm_loss_stem="$(printf 'time_merger_loss_surface_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    overlay_stem="$(printf 'opq_vs_time_merger_loss_contour_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    curve_stem="$(printf 'opq_vs_time_merger_loss_curve_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    ratio_stem="$(printf 'opq_vs_time_merger_ready_burst_ratio_nlane%02d_egress%02dx' "${n_lane}" "${egress_symbols}")"
    pin_env=()
    if [[ "${n_lane}" == "4" && "${egress_symbols}" == "1" && -s "${PIN_CSV}" ]]; then
      pin_env=(OPQ_SAMPLE_PINS_CSV="${PIN_CSV}")
    fi

    title="TLM OPQ Loss Surface N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM finite-FIFO event model; transaction closure requires RTL pin/UVM bucket matching"
    env "${pin_env[@]}" \
    OPQ_LOSS_SURFACE_TITLE="${title}" \
    OPQ_LOSS_SURFACE_NOTE="${note}" \
      "${BUILD_DIR}/opq_loss_surface_plot" \
      "${MODEL_DIR}/dislin/${loss_stem}.dat" \
      "${PLOT_DIR}/${loss_stem}.png"

    title="TLM Time-Merger Loss Surface N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM finite-FIFO tree model; one-word merger service with tree/HoL penalty"
    OPQ_LOSS_SURFACE_TITLE="${title}" \
    OPQ_LOSS_SURFACE_NOTE="${note}" \
    OPQ_MODELING_BOX_ANCHOR="upper_left" \
      "${BUILD_DIR}/opq_loss_surface_plot" \
      "${MODEL_DIR}/dislin/${tm_loss_stem}.dat" \
      "${PLOT_DIR}/${tm_loss_stem}.png"

    title="TLM OPQ vs Time-Merger Loss Contours N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM x: B from true hit timestamp CV; y: offered rate/lane; time-merger one-word tree"
    env "${pin_env[@]}" \
    OPQ_TM_CONTOUR_TITLE="${title}" \
    OPQ_TM_CONTOUR_NOTE="${note}" \
      "${BUILD_DIR}/opq_vs_time_merger_contour_plot" \
      "${MODEL_DIR}/dislin/${overlay_stem}_opq.dat" \
      "${MODEL_DIR}/dislin/${overlay_stem}_time_merger.dat" \
      "${PLOT_DIR}/${overlay_stem}.png"

    title="TLM OPQ vs Time-Merger Loss Curve N_LANE=${n_lane}, Egress=${egress_symbols}x"
    note="TLM curve at timestamp-derived B=0.70, ready duty=0.75; x sweeps per-lane offered rate"
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

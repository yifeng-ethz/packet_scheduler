#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_SIM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IP_DIR="$(cd "${RTL_SIM_DIR}/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${RTL_SIM_DIR}/.build_dislin}"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"
DATA_PATH="${DATA_PATH:-${RTL_SIM_DIR}/data/dislin/opq_structural_boundary_nlane04_egress01x.dat}"
PLOT_PATH="${PLOT_PATH:-${RTL_SIM_DIR}/plots/opq_structural_boundary_nlane04_egress01x.png}"

mkdir -p "${BUILD_DIR}" "$(dirname "${PLOT_PATH}")"

python3 "${SCRIPT_DIR}/write_structural_boundary_dislin_data.py" --output "${DATA_PATH}"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/opq_structural_boundary_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_structural_boundary_plot"

"${BUILD_DIR}/opq_structural_boundary_plot" "${DATA_PATH}" "${PLOT_PATH}"
printf 'Wrote DISLIN structural boundary plot %s\n' "${PLOT_PATH}"

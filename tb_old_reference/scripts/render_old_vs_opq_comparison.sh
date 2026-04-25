#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : render_old_vs_opq_comparison
# Revision  : 0.2 - render OPQ vs old time-merger plots from RTL simulation
#------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IP_DIR="$(cd "${REF_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${REF_DIR}/REPORT}"
BUILD_DIR="${REPORT_DIR}/.build"
DISLIN_DIR="${DISLIN_DIR:-${IP_DIR}/.vendor/dislin}"

mkdir -p "${REPORT_DIR}" "${BUILD_DIR}"

if [[ -z "${RTL_OLD_VS_OPQ_CSV:-}" ||
      -z "${RTL_TM_CONTOUR_OPQ_DAT:-}" ||
      -z "${RTL_TM_CONTOUR_TIME_MERGER_DAT:-}" ]]; then
  cat >&2 <<'EOF'
Refusing to render analytical/proxy OPQ-vs-time-merger plots.
Set these inputs to HDL-simulation artifacts:
  RTL_OLD_VS_OPQ_CSV
  RTL_TM_CONTOUR_OPQ_DAT
  RTL_TM_CONTOUR_TIME_MERGER_DAT
EOF
  exit 2
fi

for input_path in "${RTL_OLD_VS_OPQ_CSV}" "${RTL_TM_CONTOUR_OPQ_DAT}" "${RTL_TM_CONTOUR_TIME_MERGER_DAT}"; do
  if [[ ! -f "${input_path}" ]]; then
    printf 'required RTL plot input does not exist: %s\n' "${input_path}" >&2
    exit 2
  fi
done

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/old_vs_opq_comparison_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/old_vs_opq_comparison_plot"

"${BUILD_DIR}/old_vs_opq_comparison_plot" \
  "${RTL_OLD_VS_OPQ_CSV}" \
  "${REPORT_DIR}/old_vs_opq_loss_comparison.png"

"${BUILD_DIR}/old_vs_opq_comparison_plot" \
  "${RTL_OLD_VS_OPQ_CSV}" \
  "${REPORT_DIR}/old_vs_opq_loss_comparison.svg"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/opq_vs_time_merger_contour_plot.c" \
  -L"${DISLIN_DIR}" \
  -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm \
  -o "${BUILD_DIR}/opq_vs_time_merger_contour_plot"

"${BUILD_DIR}/opq_vs_time_merger_contour_plot" \
  "${RTL_TM_CONTOUR_OPQ_DAT}" \
  "${RTL_TM_CONTOUR_TIME_MERGER_DAT}" \
  "${REPORT_DIR}/opq_vs_time_merger_loss_contour.png"

"${BUILD_DIR}/opq_vs_time_merger_contour_plot" \
  "${RTL_TM_CONTOUR_OPQ_DAT}" \
  "${RTL_TM_CONTOUR_TIME_MERGER_DAT}" \
  "${REPORT_DIR}/opq_vs_time_merger_loss_contour.svg"

printf 'Wrote %s\n' "${REPORT_DIR}/old_vs_opq_loss_comparison.png"
printf 'Wrote %s\n' "${REPORT_DIR}/old_vs_opq_loss_comparison.svg"
printf 'Wrote %s\n' "${REPORT_DIR}/opq_vs_time_merger_loss_contour.png"
printf 'Wrote %s\n' "${REPORT_DIR}/opq_vs_time_merger_loss_contour.svg"

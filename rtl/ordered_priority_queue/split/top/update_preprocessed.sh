#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUARTUS_SH="${QUARTUS_SH:-quartus_sh}"
if ! command -v "${QUARTUS_SH}" >/dev/null 2>&1; then
  echo "quartus_sh not found (QUARTUS_SH=${QUARTUS_SH})" >&2
  exit 1
fi

# Generate a plain VHDL file from the TERP template.
#
# Mirrors the generation style used by `packet_scheduler/ordered_priority_queue_hw.tcl`:
#   - params(n_lane)
#   - params(fifos_names)
#   - params(egress_empty_width)
#   - params(output_name)
#
# Env knobs:
#   OPQ_SPLIT_TERP_TEMPLATE         : template path (default: ordered_priority_queue_top.terp.vhd)
#   OPQ_SPLIT_TERP_OUT_FILE         : output filename (default: ordered_priority_queue_top.vhd)
#   OPQ_SPLIT_TERP_OUTPUT_NAME      : entity name to generate (default: ordered_priority_queue_terp_debug)
#   OPQ_SPLIT_TERP_N_LANE           : number of lanes (default: 2)
#   OPQ_SPLIT_TERP_EGRESS_EMPTY_WIDTH : empty width (default: 0)
TERP_TEMPLATE="${OPQ_SPLIT_TERP_TEMPLATE:-${SCRIPT_DIR}/ordered_priority_queue_top.terp.vhd}"
TERP_OUT_FILE="${OPQ_SPLIT_TERP_OUT_FILE:-${SCRIPT_DIR}/ordered_priority_queue_top.vhd}"
TERP_OUT_NAME="${OPQ_SPLIT_TERP_OUTPUT_NAME:-ordered_priority_queue_terp_debug}"
TERP_N_LANE="${OPQ_SPLIT_TERP_N_LANE:-2}"
TERP_EGRESS_EMPTY_WIDTH="${OPQ_SPLIT_TERP_EGRESS_EMPTY_WIDTH:-0}"

tmp_tcl="$(mktemp)"
cat > "${tmp_tcl}" <<TCL
lappend auto_path "\$::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages"
package require -exact altera_terp 1.0
set template_file [file normalize {${TERP_TEMPLATE}}]
set template [read [open \$template_file r]]
set params(n_lane) ${TERP_N_LANE}
set params(fifos_names) [list "ticket_fifo" "lane_fifo" "handle_fifo"]
set params(egress_empty_width) ${TERP_EGRESS_EMPTY_WIDTH}
set params(output_name) "${TERP_OUT_NAME}"
set result [altera_terp \$template params]
set out [open "${TERP_OUT_FILE}" w]
puts \$out \$result
close \$out
puts "Generated ${TERP_OUT_FILE} (entity ${TERP_OUT_NAME}) from template: \$template_file"
TCL

"${QUARTUS_SH}" -t "${tmp_tcl}"
rm -f "${tmp_tcl}"


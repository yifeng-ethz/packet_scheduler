#!/usr/bin/env bash
#------------------------------------------------------------------------------
# IP Name   : opq_native_sv_feature_signoff
# Author    : Yifeng Wang (original OPQ) / native SV staging by Codex
# Revision  : 26.4.0 - generate and run standalone Quartus feature-range fits
#------------------------------------------------------------------------------
set -euo pipefail

mode="${1:---smoke}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

project="opq_native_sv_feature_signoff"
target_device="10AX115N2F45E1SG"

ticket_depth_for() {
  local lane="$1"
  local nshd="$2"
  local depth=256
  local need_a=$((32 * nshd))
  local need_b=$((2 * nshd * lane))
  if (( need_a > depth )); then depth="${need_a}"; fi
  if (( need_b > depth )); then depth="${need_b}"; fi
  local pow=1
  while (( pow < depth )); do pow=$((pow * 2)); done
  echo "${pow}"
}

lane_depth_for() {
  local lane="$1"
  if (( lane <= 2 )); then
    echo 1024
  elif (( lane <= 4 )); then
    echo 2048
  elif (( lane <= 8 )); then
    echo 4096
  elif (( lane <= 16 )); then
    echo 8192
  else
    echo 16384
  fi
}

emit_qsf() {
  local lane="$1"
  local nshd="$2"
  local width="$3"
  local rev="opq_feature_l${lane}_s${nshd}_w${width}"
  local ticket_depth
  local lane_depth
  ticket_depth="$(ticket_depth_for "${lane}" "${nshd}")"
  lane_depth="$(lane_depth_for "${lane}")"

  cat > "${rev}.qsf" <<QSF
set_global_assignment -name FAMILY "Arria 10"
set_global_assignment -name DEVICE ${target_device}
set_global_assignment -name TOP_LEVEL_ENTITY opq_native_sv_feature_signoff_top
set_global_assignment -name ORIGINAL_QUARTUS_VERSION 18.1.0
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files/${rev}
set_global_assignment -name SDC_FILE opq_native_sv_feature_signoff.sdc

set_global_assignment -name VERILOG_MACRO "SYNTHESIS=1"
set_global_assignment -name VERILOG_MACRO "OPQ_USE_NATIVE_SV"
set_global_assignment -name VERILOG_MACRO "OPQ_SYN_N_LANE=${lane}"
set_global_assignment -name VERILOG_MACRO "OPQ_SYN_N_SHD=${nshd}"
set_global_assignment -name VERILOG_MACRO "OPQ_SYN_PAGE_RAM_RD_WIDTH=${width}"
set_global_assignment -name VERILOG_MACRO "OPQ_SYN_TICKET_FIFO_DEPTH=${ticket_depth}"
set_global_assignment -name VERILOG_MACRO "OPQ_SYN_LANE_FIFO_DEPTH=${lane_depth}"

set_global_assignment -name NUM_PARALLEL_PROCESSORS 16
set_global_assignment -name PARALLEL_SYNTHESIS OFF
set_global_assignment -name AUTO_PARALLEL_SYNTHESIS OFF
set_global_assignment -name SEED 1
set_global_assignment -name SAFE_STATE_MACHINE ON
set_global_assignment -name AUTO_SHIFT_REGISTER_RECOGNITION OFF
set_global_assignment -name ALLOW_REGISTER_DUPLICATION ON
set_global_assignment -name ALLOW_REGISTER_MERGING OFF
set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"
set_global_assignment -name OPTIMIZATION_TECHNIQUE SPEED
set_global_assignment -name ROUTER_TIMING_OPTIMIZATION_LEVEL MAXIMUM
set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 4.0
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
set_global_assignment -name ADVANCED_PHYSICAL_SYNTHESIS ON
set_global_assignment -name FINAL_PLACEMENT_OPTIMIZATION ALWAYS

set_instance_assignment -name MUX_RESTRUCTURE OFF -to "*"
set_instance_assignment -name VIRTUAL_PIN ON -to "activity_o[*]"

set_global_assignment -name VERILOG_FILE ../opq_native_sv_4lane_signoff/src_compat/handle_fifo.v
set_global_assignment -name VERILOG_FILE ../opq_native_sv_4lane_signoff/src_compat/lane_fifo.v
set_global_assignment -name VERILOG_FILE ../opq_native_sv_4lane_signoff/src_compat/page_ram.v
set_global_assignment -name VERILOG_FILE ../opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v
set_global_assignment -name VERILOG_FILE ../../../rtl/sv_ver/vendor/alt_ram/tile_fifo.v
set_global_assignment -name VERILOG_FILE ../../../rtl/sv_ver/vendor/alt_ram/frame_table.v

set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_block_path.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_egress_packer.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../../rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv
set_global_assignment -name SYSTEMVERILOG_FILE opq_native_sv_feature_signoff_top.sv

set_global_assignment -name LAST_QUARTUS_VERSION "18.1.0 Standard Edition"
QSF
}

run_one() {
  local lane="$1"
  local nshd="$2"
  local width="$3"
  local rev="opq_feature_l${lane}_s${nshd}_w${width}"
  emit_qsf "${lane}" "${nshd}" "${width}"
  echo "[feature_syn] compile ${rev}"
  quartus_sh --flow compile "${project}" -c "${rev}" |& tee "${rev}.compile.log"
}

case "${mode}" in
  --smoke)
    run_one 4 128 36
    run_one 16 128 288
    ;;
  --matrix)
    for lane in 4 8 16; do
      for width in 36 72 144 288; do
        run_one "${lane}" 128 "${width}"
      done
    done
    run_one 4 64 36
    run_one 4 256 36
    ;;
  --one)
    if (( $# != 4 )); then
      echo "usage: $0 --one <N_LANE> <N_SHD> <PAGE_RAM_RD_WIDTH>" >&2
      exit 2
    fi
    run_one "$2" "$3" "$4"
    ;;
  *)
    echo "usage: $0 [--smoke|--matrix|--one <N_LANE> <N_SHD> <PAGE_RAM_RD_WIDTH>]" >&2
    exit 2
    ;;
esac

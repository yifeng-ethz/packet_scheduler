#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
dut_impl="${DUT_IMPL:-native_sv}"

if [[ "${dut_impl}" != "native_sv" ]]; then
  echo "gen_dv_report.sh only supports DUT_IMPL=native_sv (got ${dut_impl})" >&2
  exit 1
fi

python3 "${SCRIPT_DIR}/build_dv_report_json.py"
python3 "${SCRIPT_DIR}/dv_report_gen_local.py" --tb "${TB_DIR}"

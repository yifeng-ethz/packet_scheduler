#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_JSON="${REPORT_JSON:-${TB_DIR}/DV_REPORT.json}"
DUT_IMPL="${DUT_IMPL:-native_sv}"
BUCKET_FILTER="${BUCKET_FILTER:-}"

usage() {
  cat <<'EOF'
Usage:
  run_pending_cases.sh [CASE_ID ...]

Behavior:
  - With explicit case IDs: runs exactly those canonical cases.
  - Without case IDs: loads `DV_REPORT.json` and runs every case whose
    `implemented` field is `false`.

Environment:
  REPORT_JSON    Override the source report json. Defaults to tb/DV_REPORT.json.
  BUCKET_FILTER  Optional bucket filter (`BASIC`, `EDGE`, `PROF`, `ERROR`)
                 applied only when no explicit case IDs are provided.
  DUT_IMPL       Must remain `native_sv` for signoff/report evidence.
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_pending_cases.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -gt 0 ]]; then
  CASE_IDS=("$@")
else
  if [[ ! -f "${REPORT_JSON}" ]]; then
    echo "missing report json: ${REPORT_JSON}" >&2
    exit 1
  fi
  mapfile -t CASE_IDS < <(
    python3 - "${REPORT_JSON}" "${BUCKET_FILTER}" <<'PY'
import json
import sys
from pathlib import Path

report_json = Path(sys.argv[1])
bucket_filter = sys.argv[2].strip().upper()
data = json.loads(report_json.read_text())

for case in data.get("cases", []):
    if case.get("implemented", True):
        continue
    if bucket_filter and case.get("bucket", "").upper() != bucket_filter:
        continue
    print(case["case_id"])
PY
  )
fi

if [[ "${#CASE_IDS[@]}" -eq 0 ]]; then
  echo "no pending canonical cases selected" >&2
  exit 0
fi

printf 'Running %d pending canonical cases' "${#CASE_IDS[@]}"
if [[ -n "${BUCKET_FILTER}" ]]; then
  printf ' (bucket=%s)' "${BUCKET_FILTER}"
fi
printf '\n'

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "${CASE_IDS[@]}"

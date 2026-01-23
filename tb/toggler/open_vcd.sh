#!/usr/bin/env bash
set -euo pipefail

file="${1:-}"
if [[ -z "${file}" ]]; then
  file="$(ls -t *.vcd 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${file}" ]]; then
  echo "No .vcd file found. Pass a file path or run from a directory with VCDs." >&2
  exit 1
fi

if [[ ! -f "${file}" ]]; then
  echo "VCD file not found: ${file}" >&2
  exit 1
fi

gtkwave_bin=""
if command -v gtkwave >/dev/null 2>&1; then
  gtkwave_bin="$(command -v gtkwave)"
elif [[ -x "${HOME}/.conda/envs/gtkwave/bin/gtkwave" ]]; then
  gtkwave_bin="${HOME}/.conda/envs/gtkwave/bin/gtkwave"
fi

if [[ -n "${gtkwave_bin}" ]]; then
  exec "${gtkwave_bin}" "${file}"
elif command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "${file}"
elif command -v open >/dev/null 2>&1; then
  exec open "${file}"
else
  echo "No VCD viewer found (gtkwave/xdg-open/open)." >&2
  exit 1
fi

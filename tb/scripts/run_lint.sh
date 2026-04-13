#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UVM_DIR="$(cd "${SCRIPT_DIR}/../uvm" && pwd)"

make -C "${UVM_DIR}" lint
make -C "${UVM_DIR}" lint_src
make -C "${UVM_DIR}" lint_elab

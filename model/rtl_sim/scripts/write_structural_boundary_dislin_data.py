#!/usr/bin/env python3
"""Write DISLIN curve data for structural AT vs RTL boundary rows."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


RTL_SIM_DIR = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = RTL_SIM_DIR / "data" / "opq_structural_tlm_boundary.csv"
DEFAULT_OUTPUT = RTL_SIM_DIR / "data" / "dislin" / "opq_structural_boundary_nlane04_egress01x.dat"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    with args.input.open(newline="", encoding="ascii") as handle:
        rows = sorted(csv.DictReader(handle), key=lambda row: float(row["rho_ppm"]))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as handle:
        handle.write(f"{len(rows)}\n")
        handle.write(" ".join(f"{float(row['rho_ppm']) / 10000.0:.8f}" for row in rows) + "\n")
        handle.write(" ".join(f"{float(row['rtl_loss']):.12e}" for row in rows) + "\n")
        handle.write(" ".join(f"{float(row['tlm_loss']):.12e}" for row in rows) + "\n")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

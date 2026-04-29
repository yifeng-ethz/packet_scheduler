#!/usr/bin/env python3
"""Write DISLIN curve data for the 100-frame OPQ marginal loss zoom."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


RTL_SIM_DIR = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = RTL_SIM_DIR / "data" / "opq_structural_tlm_marginal_loss_zoom_f100.csv"
DEFAULT_OUTPUT = RTL_SIM_DIR / "data" / "dislin" / "opq_marginal_loss_zoom_f100_nlane04_egress01x.dat"


def burstiness(row: dict[str, str]) -> float:
    if row.get("burstiness"):
        return float(row["burstiness"])
    return float(row["burstiness_milli"]) / 1000.0


def rho_lane(row: dict[str, str]) -> float:
    if row.get("rho_lane"):
        return float(row["rho_lane"])
    return float(row["rho_ppm"]) / 1.0e6


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    groups: dict[float, list[dict[str, str]]] = defaultdict(list)
    with args.input.open(newline="", encoding="ascii") as handle:
        for row in csv.DictReader(handle):
            groups[burstiness(row)].append(row)

    if not groups:
        raise SystemExit(f"no rows found in {args.input}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as handle:
        handle.write(f"{len(groups)}\n")
        for b_value in sorted(groups):
            rows = sorted(groups[b_value], key=rho_lane)
            handle.write(f"{b_value:.6f} {len(rows)}\n")
            handle.write(" ".join(f"{rho_lane(row):.8f}" for row in rows) + "\n")
            handle.write(" ".join(f"{float(row['rtl_loss']):.12e}" for row in rows) + "\n")
            handle.write(" ".join(f"{float(row['tlm_loss']):.12e}" for row in rows) + "\n")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

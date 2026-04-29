#!/usr/bin/env python3
"""Write DISLIN curve data for the old time-merger first-loss boundary."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


RTL_SIM_DIR = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = RTL_SIM_DIR / "data" / "time_merger_ref_loss_sweep.csv"
DEFAULT_OUTPUT = RTL_SIM_DIR / "data" / "dislin" / "time_merger_boundary_nlane04.dat"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--n-lane", type=int, default=4)
    parser.add_argument("--rho-max", type=float, default=0.3)
    args = parser.parse_args()

    with args.input.open(newline="", encoding="ascii") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if int(row["n_lane"]) == args.n_lane and float(row["rho"]) <= args.rho_max
        ]
    rows.sort(key=lambda row: float(row["rho"]))
    if not rows:
        raise SystemExit(f"no matching rows in {args.input}")

    knee = float(rows[0]["persistent_knee_rho"])
    margin = float(rows[0]["opq_80pct_lossless_target_rho"])
    first_loss = 0.0
    for row in rows:
        if int(row["source_queue_drop_hit_count"]) > 0:
            first_loss = float(row["rho"])
            break

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as handle:
        handle.write(f"{len(rows)}\n")
        handle.write(" ".join(f"{float(row['rho']):.8f}" for row in rows) + "\n")
        handle.write(
            " ".join(f"{float(row['total_inferred_loss_probability']):.12e}" for row in rows)
            + "\n"
        )
        handle.write(f"{knee:.12e} {margin:.12e} {first_loss:.12e}\n")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

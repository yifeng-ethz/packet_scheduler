#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# IP Name : packet_scheduler/tb_int/scripts/plot_latency_hists.py
# Author  : Yifeng Wang (yifenwan@phys.ethz.ch)
# Purpose : Off-sim plotter for per-stage, per-lane latency histograms.
#
# Reads CSV files from tb_int/sim_runs/latency/ with the header:
#   hit_id,feb_id,datapath_id,mutrig_ch,lane,t_prev,t_curr,lat_cycles
# and emits one PNG per stage pair (AB / BC / CD / DE) with per-lane
# histograms overlaid.
#
# No dependencies beyond numpy, matplotlib, and the stdlib. Reads CSVs
# with `csv` from the stdlib so we never hit pandas on this system.
#
# Phase 1: skeleton — scans the directory, complains politely if no CSVs
# exist, and exits zero. Phase 4 fills in the actual plotting.
# -----------------------------------------------------------------------------

from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import defaultdict
from pathlib import Path

try:
    import numpy as np
    import matplotlib.pyplot as plt
except ImportError as exc:
    print(f"matplotlib/numpy required: {exc}", file=sys.stderr)
    sys.exit(2)

STAGE_PAIRS = ("AB", "BC", "CD", "DE")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input-dir",
        default=None,
        help="directory containing tb_int_latency_*.csv files",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="directory to write latency_*.png (defaults to --input-dir)",
    )
    return parser.parse_args()


def default_input_dir() -> Path:
    here = Path(__file__).resolve().parent
    return here.parent / "sim_runs" / "latency"


def load_csv(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open() as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            rows.append(row)
    return rows


def plot_stage_pair(stage: str, csvs: list[Path], output_dir: Path) -> None:
    per_lane: dict[int, list[int]] = defaultdict(list)
    for path in csvs:
        for row in load_csv(path):
            lane = int(row["lane"])
            per_lane[lane].append(int(row["lat_cycles"]))
    if not per_lane:
        print(f"  {stage}: no rows", file=sys.stderr)
        return
    fig, ax = plt.subplots(figsize=(6, 4))
    for lane in sorted(per_lane):
        ax.hist(
            per_lane[lane],
            bins=64,
            histtype="step",
            label=f"lane {lane}",
        )
    ax.set_xlabel("latency (cycles)")
    ax.set_ylabel("hits")
    ax.set_title(f"latency {stage}")
    ax.legend()
    out = output_dir / f"latency_{stage}.png"
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    print(f"  wrote {out}")


def main() -> int:
    args = parse_args()
    input_dir = Path(args.input_dir) if args.input_dir else default_input_dir()
    output_dir = Path(args.output_dir) if args.output_dir else input_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    if not input_dir.is_dir():
        print(f"no latency CSV directory at {input_dir} (nothing to plot)")
        return 0

    found_any = False
    for stage in STAGE_PAIRS:
        csvs = sorted(input_dir.glob(f"tb_int_latency_{stage}_*.csv"))
        if not csvs:
            continue
        found_any = True
        print(f"stage pair {stage}: {len(csvs)} file(s)")
        plot_stage_pair(stage, csvs, output_dir)

    if not found_any:
        print(f"no tb_int_latency_*.csv under {input_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

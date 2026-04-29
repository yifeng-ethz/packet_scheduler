#!/usr/bin/env python3
"""Compare OPQ RTL loss rows against tight, AT, and loose TLM timing.

The tight timing model interprets rho_lane directly as hits per service cycle.
The AT model reconstructs the same timestamp-burst frame envelope used by the
UVM profile=3 stimulus, including independent per-lane RNG streams.
The loose timing model converts the timestamp-slot lane rate into an effective
wall-clock rate using the packetized UVM frame schedule. This is the expected
mode for the current RTL publish stimulus, where timestamp slots are carried in
frames separated by ingress gaps rather than injected every core cycle.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path
from types import SimpleNamespace

import numpy as np


REPO_ROOT = Path(__file__).resolve().parents[4]
MODEL_ROOT = REPO_ROOT / "packet_scheduler" / "model"
RTL_DATA = MODEL_ROOT / "rtl_sim" / "data"
TLM_SCRIPT_DIR = MODEL_ROOT / "tlm" / "scripts"
DEFAULT_INPUT = RTL_DATA / "RTL-LS-002.csv"
DEFAULT_OUTPUT = RTL_DATA / "tlm_rtl_loss_comparison.csv"

sys.path.insert(0, str(TLM_SCRIPT_DIR))
from opq_tlm_feature_sweep import simulate_tlm_grid  # noqa: E402
from opq_structural_tlm import CaseConfig, run_config as run_structural_config  # noqa: E402


GROUP_FIELDS = [
    "run_tag",
    "case",
    "profile",
    "n_lane",
    "n_shd",
    "egress_symbols_per_beat",
    "ready_duty_ppm",
    "rho_ppm",
    "burstiness_milli",
    "frame_count",
    "subheaders_per_frame",
    "inter_frame_gap_cycles",
    "hit_period",
    "hit_count",
    "noise_rho_ppm",
    "cluster_rho_ppm",
    "cluster_size_min",
    "cluster_size_max",
    "rng_seed",
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="ascii") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = [
        "run_tag",
        "case",
        "profile",
        "n_lane",
        "egress_symbols_per_beat",
        "ready_duty",
        "burstiness",
        "rho_lane_timestamp",
        "rho_lane_loose_effective",
        "frame_count",
        "subheaders_per_frame",
        "expected_hits",
        "dropped_hits",
        "rtl_loss",
        "tight_tlm_loss",
        "at_tlm_loss",
        "loose_tlm_loss",
        "tight_rel_err",
        "at_rel_err",
        "loose_rel_err",
        "at_offered_hits",
        "at_dropped_hits",
        "at_max_occupancy",
        "loose_horizon_cycles",
        "loose_frame_words_avg",
        "match_mode",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def tlm_loss(
    implementation: str,
    n_lane: int,
    egress_symbols_per_beat: int,
    ready_duty: float,
    burstiness: float,
    rho_lane: float,
    cycles: int,
) -> float:
    args = SimpleNamespace(
        opq_capacity=255,
        time_merger_credit=96.0,
        cycles=max(8192, int(cycles)),
        warmup_cycles=0,
        ready_period=37,
    )
    result = simulate_tlm_grid(
        implementation,
        n_lane,
        egress_symbols_per_beat,
        np.array([[ready_duty]], dtype=float),
        np.array([[burstiness]], dtype=float),
        np.array([[rho_lane]], dtype=float),
        args,
    )
    return float(result.loss[0, 0])


def relative_error(reference: float, observed: float) -> float:
    if abs(reference) <= 1.0e-12 and abs(observed) <= 1.0e-12:
        return 0.0
    return abs(observed - reference) / max(abs(reference), 1.0e-12)


def int_value(value: str, default: int = 0) -> int:
    return int(value) if value not in {"", "-"} else default


def reduce_rows(rows: list[dict[str, str]], inter_frame_gap_cycles: int, skip_at: bool) -> list[dict[str, object]]:
    grouped: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[tuple(row.get(field, "") for field in GROUP_FIELDS)].append(row)

    out: list[dict[str, object]] = []
    for key, group in sorted(grouped.items()):
        values = dict(zip(GROUP_FIELDS, key))
        n_lane = int(values["n_lane"])
        egress = int(values["egress_symbols_per_beat"])
        ready_duty = int(values["ready_duty_ppm"]) / 1_000_000.0
        rho_lane = int(values["rho_ppm"]) / 1_000_000.0
        burstiness = int(values["burstiness_milli"]) / 1000.0
        frame_count = max(1, int(values["frame_count"]))
        subheaders_per_frame = int(values["subheaders_per_frame"])
        inter_gap = int_value(values["inter_frame_gap_cycles"], inter_frame_gap_cycles)
        expected_hits = sum(int(row.get("expected_hits", "0")) for row in group)
        dropped_hits = sum(int(row.get("dropped_hits", "0")) for row in group)
        rtl_loss = (dropped_hits / expected_hits) if expected_hits else 0.0

        max_lane_hits = 0
        for row in group:
            max_lane_hits = max(max_lane_hits, int(row.get("expected_hits", "0")))
        lane_hits_per_frame = max_lane_hits / frame_count
        frame_words_avg = 6.0 + float(subheaders_per_frame) + lane_hits_per_frame
        horizon_cycles = (
            (float(frame_count) * frame_words_avg)
            + (float(max(frame_count - 1, 0)) * float(inter_gap))
        )
        rho_lane_loose = expected_hits / max(float(n_lane) * horizon_cycles, 1.0)

        tight = tlm_loss(
            "opq",
            n_lane,
            egress,
            ready_duty,
            burstiness,
            rho_lane,
            cycles=8192,
        )
        loose = tlm_loss(
            "opq",
            n_lane,
            egress,
            ready_duty,
            burstiness,
            rho_lane_loose,
            cycles=int(horizon_cycles),
        )
        at_loss: float | None = None
        at_err: float | None = None
        at_offered_hits: int | None = None
        at_dropped_hits: int | None = None
        at_max_occupancy: int | None = None
        if not skip_at:
            at_cfg = CaseConfig(
                run_tag=values["run_tag"],
                case=values["case"],
                profile=int_value(values["profile"], 3),
                n_lane=n_lane,
                n_shd=int_value(values["n_shd"], 128),
                egress_symbols_per_beat=egress,
                ready_duty_ppm=int(values["ready_duty_ppm"]),
                rho_ppm=int(values["rho_ppm"]),
                burstiness_milli=int(values["burstiness_milli"]),
                frame_count=frame_count,
                subheaders_per_frame=subheaders_per_frame,
                inter_frame_gap_cycles=inter_gap,
                noise_rho_ppm=int_value(values["noise_rho_ppm"], 0),
                cluster_rho_ppm=int_value(values["cluster_rho_ppm"], 0),
                cluster_size_min=int_value(values["cluster_size_min"], 4),
                cluster_size_max=int_value(values["cluster_size_max"], 8),
                rng_seed=int_value(values["rng_seed"], 0x5C1F0001),
                rtl_expected_hits=expected_hits,
                rtl_dropped_hits=dropped_hits,
            )
            at_row = run_structural_config(at_cfg)
            at_loss = float(at_row["tlm_loss"])
            at_err = relative_error(at_loss, rtl_loss)
            at_offered_hits = int(at_row["tlm_offered_hits"])
            at_dropped_hits = int(at_row["tlm_dropped_hits"])
            at_max_occupancy = int(at_row["max_page_words"])
        tight_err = relative_error(tight, rtl_loss)
        loose_err = relative_error(loose, rtl_loss)
        mode_errors = {"tight": tight_err, "loose": loose_err}
        if at_err is not None:
            mode_errors["at"] = at_err
        match_mode = min(mode_errors.items(), key=lambda item: item[1])[0]

        out.append(
            {
                "run_tag": values["run_tag"],
                "case": values["case"],
                "profile": values["profile"],
                "n_lane": n_lane,
                "egress_symbols_per_beat": egress,
                "ready_duty": ready_duty,
                "burstiness": burstiness,
                "rho_lane_timestamp": rho_lane,
                "rho_lane_loose_effective": rho_lane_loose,
                "frame_count": frame_count,
                "subheaders_per_frame": subheaders_per_frame,
                "expected_hits": expected_hits,
                "dropped_hits": dropped_hits,
                "rtl_loss": rtl_loss,
                "tight_tlm_loss": tight,
                "at_tlm_loss": at_loss,
                "loose_tlm_loss": loose,
                "tight_rel_err": tight_err,
                "at_rel_err": at_err,
                "loose_rel_err": loose_err,
                "at_offered_hits": at_offered_hits,
                "at_dropped_hits": at_dropped_hits,
                "at_max_occupancy": at_max_occupancy,
                "loose_horizon_cycles": horizon_cycles,
                "loose_frame_words_avg": frame_words_avg,
                "match_mode": match_mode,
            }
        )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--inter-frame-gap-cycles", type=int, default=4000)
    parser.add_argument("--skip-at", action="store_true", help="skip structural AT TLM reconstruction")
    args = parser.parse_args()

    rows = reduce_rows(read_csv(args.input), args.inter_frame_gap_cycles, args.skip_at)
    write_csv(args.output, rows)
    for row in rows:
        print(
            "TLM_RTL_COMPARE "
            f"run_tag={row['run_tag']} rtl_loss={row['rtl_loss']:.12g} "
            f"tight_tlm_loss={row['tight_tlm_loss']:.12g} "
            f"at_tlm_loss={row['at_tlm_loss'] if row['at_tlm_loss'] is not None else 'skip'} "
            f"loose_tlm_loss={row['loose_tlm_loss']:.12g} "
            f"match_mode={row['match_mode']}"
        )
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

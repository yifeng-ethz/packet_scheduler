#!/usr/bin/env python3
"""Write DISLIN sample-pin data from OPQ component replay CSV rows."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PKT_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_INPUT = PKT_ROOT / "model" / "rtl_sim" / "data" / "opq_component_replay_parser_tail_100k_12run.csv"
FALLBACK_INPUT = PKT_ROOT / "model" / "rtl_sim" / "data" / "opq_component_replay_parser_ticket_100k_12run_rereduce.csv"
DEFAULT_OUTPUT = PKT_ROOT / "model" / "tlm" / "data" / "dislin" / "opq_component_replay_12run_pins.csv"

TAG_RE = re.compile(r"component_b(?P<b>-?\d+)_rho(?P<rho>\d+).*_seed(?P<seed>[0-9a-fA-F]+)")
PHYSICAL_N_SHD = 128.0
PHYSICAL_FRAME_PERIOD_CYCLES = 4096.0
PHYSICAL_EGRESS_SYMBOLS = 1.0


def parse_float(text: str) -> float:
    if text in {"", "-"}:
        return 0.0
    return float(text)


def point_from_tag(run_tag: str) -> tuple[float, float, str]:
    match = TAG_RE.search(run_tag)
    if not match:
        raise ValueError(f"cannot parse run tag {run_tag!r}")
    burstiness = int(match.group("b")) / 1000.0
    raw_rho = int(match.group("rho")) / 1000.0
    normalized_share = raw_rho * PHYSICAL_N_SHD / (
        PHYSICAL_FRAME_PERIOD_CYCLES * PHYSICAL_EGRESS_SYMBOLS
    )
    return burstiness, normalized_share, match.group("seed")


def choose_input(path: Path | None) -> Path:
    if path is not None:
        return path
    if DEFAULT_INPUT.exists():
        return DEFAULT_INPUT
    return FALLBACK_INPUT


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    input_path = choose_input(args.input)
    if not input_path.exists():
        raise SystemExit(f"missing replay CSV {input_path}")

    by_run: dict[str, dict[str, dict[str, str]]] = {}
    with input_path.open(newline="", encoding="ascii") as handle:
        for row in csv.DictReader(handle):
            by_run.setdefault(row["run_tag"], {})[row["component"]] = row

    rows: list[dict[str, str]] = []
    for run_tag in sorted(by_run):
        comps = by_run[run_tag]
        offered = comps.get("ingress_parser_ticket_fifo_write_parser_ticket_stream")
        loss = comps.get("page_allocator_local_loss_parser_ticket_stream")
        if offered is None or loss is None:
            continue
        offered_hits = parse_float(offered["rtl_value"])
        if offered_hits <= 0.0:
            continue
        rtl_loss = parse_float(loss["rtl_value"]) / offered_hits
        tlm_loss = parse_float(loss["tlm_value"]) / offered_hits
        burstiness, rho, seed = point_from_tag(run_tag)
        rows.append(
            {
                "run_tag": run_tag,
                "burstiness": f"{burstiness:.6f}",
                "rho_lane": f"{rho:.6f}",
                "rtl_loss": f"{rtl_loss:.8f}",
                "tlm_loss": f"{tlm_loss:.8f}",
                "label": f"{seed} R/T {100.0 * rtl_loss:.2f}/{100.0 * tlm_loss:.2f}%",
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["run_tag", "burstiness", "rho_lane", "rtl_loss", "tlm_loss", "label"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

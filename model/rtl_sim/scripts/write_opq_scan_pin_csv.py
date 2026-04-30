#!/usr/bin/env python3
"""Write DISLIN sample-pin data from OPQ normalized-share RTL/TLM scan rows."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PKT_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_RTL = PKT_ROOT / "model" / "rtl_sim" / "data" / "opq_mu3e_demo_calibration_scan_n4_e1.csv"
DEFAULT_OUTPUT = PKT_ROOT / "model" / "tlm" / "data" / "dislin" / "opq_component_replay_12run_pins.csv"


def parse_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    text = row.get(key, "")
    if text in {"", "-"}:
        return default
    return float(text)


def read_by_run(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    with path.open(newline="", encoding="ascii", errors="replace") as handle:
        return {row["run_tag"]: row for row in csv.DictReader(handle) if row.get("run_tag")}


def choose_rows(rows: list[dict[str, str]], max_pins: int) -> list[dict[str, str]]:
    if max_pins <= 0 or len(rows) <= max_pins:
        return rows

    def score(row: dict[str, str]) -> tuple[float, float, float]:
        rtl_loss = parse_float(row, "rtl_loss")
        rho = parse_float(row, "rho_lane")
        burstiness = parse_float(row, "burstiness")
        near_transition = min(
            abs(rtl_loss - 0.01),
            abs(rtl_loss - 0.05),
            abs(rtl_loss - 0.50),
        )
        return (near_transition, abs(rho - 0.25), abs(burstiness))

    selected = sorted(rows, key=score)[:max_pins]
    return sorted(selected, key=lambda row: (parse_float(row, "burstiness"), parse_float(row, "rho_lane")))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rtl", type=Path, default=DEFAULT_RTL)
    parser.add_argument("--tlm", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--max-pins", type=int, default=24)
    args = parser.parse_args()

    rtl_rows = read_by_run(args.rtl)
    if not rtl_rows:
        raise SystemExit(f"missing or empty RTL scan CSV {args.rtl}")
    tlm_rows = read_by_run(args.tlm) if args.tlm else {}

    pins: list[dict[str, str]] = []
    for run_tag, rtl in sorted(rtl_rows.items()):
        tlm = tlm_rows.get(run_tag, {})
        burstiness = parse_float(rtl, "burstiness")
        rho = parse_float(rtl, "normalized_share_lane", parse_float(rtl, "rho_lane"))
        rtl_loss = parse_float(tlm, "rtl_loss", parse_float(rtl, "loss_probability"))
        tlm_loss = parse_float(tlm, "tlm_loss", rtl_loss)
        loss_tier = rtl.get("loss_tier", "-") or "-"
        pins.append(
            {
                "run_tag": run_tag,
                "burstiness": f"{burstiness:.6f}",
                "rho_lane": f"{rho:.6f}",
                "rtl_loss": f"{rtl_loss:.8f}",
                "tlm_loss": f"{tlm_loss:.8f}",
                "loss_tier": loss_tier,
                "label": "",
            }
        )

    pins = choose_rows(pins, args.max_pins)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "run_tag",
                "burstiness",
                "rho_lane",
                "rtl_loss",
                "tlm_loss",
                "loss_tier",
                "label",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(pins)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Normalize DISLIN sample-pin labels to R/T/A loss percentages."""

from __future__ import annotations

import argparse
import bisect
import csv
from dataclasses import dataclass
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
MODEL_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_ANALYTICAL_DAT = (
    MODEL_ROOT
    / "analytical"
    / "data"
    / "queueing_model"
    / "dislin"
    / "opq_loss_surface_nlane04_egress01x.dat"
)


@dataclass(frozen=True)
class LossGrid:
    x: list[float]
    y: list[float]
    z: list[list[float]]


def parse_float(text: str | None, default: float = 0.0) -> float:
    if text is None:
        return default
    stripped = text.strip()
    if stripped in {"", "-"}:
        return default
    return float(stripped)


def read_dislin_matrix(path: Path) -> LossGrid:
    tokens = path.read_text(encoding="ascii").split()
    if len(tokens) < 3:
        raise SystemExit(f"invalid DISLIN matrix {path}")
    cursor = 0
    nx = int(tokens[cursor])
    cursor += 1
    ny = int(tokens[cursor])
    cursor += 1
    if nx < 2 or ny < 2:
        raise SystemExit(f"invalid DISLIN matrix dimensions in {path}: {nx}x{ny}")
    x = [float(tokens[cursor + idx]) for idx in range(nx)]
    cursor += nx
    y = [float(tokens[cursor + idx]) for idx in range(ny)]
    cursor += ny
    z: list[list[float]] = []
    for _ in range(nx):
        z.append([float(tokens[cursor + idx]) for idx in range(ny)])
        cursor += ny
    return LossGrid(x=x, y=y, z=z)


def bracketing_index(values: list[float], value: float) -> int:
    if value <= values[0]:
        return 0
    if value >= values[-1]:
        return len(values) - 2
    return max(0, min(len(values) - 2, bisect.bisect_right(values, value) - 1))


def interpolate(grid: LossGrid, x_value: float, y_value: float) -> float:
    ix = bracketing_index(grid.x, x_value)
    iy = bracketing_index(grid.y, y_value)
    x0 = grid.x[ix]
    x1 = grid.x[ix + 1]
    y0 = grid.y[iy]
    y1 = grid.y[iy + 1]
    tx = 0.0 if x1 == x0 else (x_value - x0) / (x1 - x0)
    ty = 0.0 if y1 == y0 else (y_value - y0) / (y1 - y0)
    tx = max(0.0, min(1.0, tx))
    ty = max(0.0, min(1.0, ty))
    z00 = grid.z[ix][iy]
    z10 = grid.z[ix + 1][iy]
    z01 = grid.z[ix][iy + 1]
    z11 = grid.z[ix + 1][iy + 1]
    return (
        ((1.0 - tx) * (1.0 - ty) * z00)
        + (tx * (1.0 - ty) * z10)
        + ((1.0 - tx) * ty * z01)
        + (tx * ty * z11)
    )


def percent_triplet(rtl_loss: float, tlm_loss: float, analytical_loss: float) -> str:
    return f"{100.0 * rtl_loss:.1f}%/{100.0 * tlm_loss:.1f}%/{100.0 * analytical_loss:.1f}%"


def normalize_rows(rows: list[dict[str, str]], analytical_grid: LossGrid) -> list[dict[str, str]]:
    normalized: list[dict[str, str]] = []
    for row in rows:
        burstiness = parse_float(row.get("burstiness"))
        rho_lane = parse_float(row.get("rho_lane"))
        rtl_loss = parse_float(row.get("rtl_loss"))
        tlm_loss = parse_float(row.get("tlm_loss"))
        analytical_loss = interpolate(analytical_grid, burstiness, rho_lane)
        loss_tier = row.get("loss_tier", "-").strip() or "-"
        normalized.append(
            {
                "run_tag": row.get("run_tag", ""),
                "burstiness": f"{burstiness:.6f}",
                "rho_lane": f"{rho_lane:.6f}",
                "rtl_loss": f"{rtl_loss:.8f}",
                "tlm_loss": f"{tlm_loss:.8f}",
                "loss_tier": loss_tier,
                "label": percent_triplet(rtl_loss, tlm_loss, analytical_loss),
                "analytical_loss": f"{analytical_loss:.8f}",
            }
        )
    return normalized


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--analytical-dat", type=Path, default=DEFAULT_ANALYTICAL_DAT)
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"missing pin CSV {args.input}")
    if not args.analytical_dat.exists():
        raise SystemExit(f"missing analytical DISLIN matrix {args.analytical_dat}")

    with args.input.open(newline="", encoding="ascii") as handle:
        rows = list(csv.DictReader(handle))
    normalized = normalize_rows(rows, read_dislin_matrix(args.analytical_dat))

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
                "analytical_loss",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(normalized)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

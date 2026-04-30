#!/usr/bin/env python3
"""Calibrate the OPQ analytical loss surface against RTL/TLM scan evidence.

The input analytical matrix remains the reference generator output. This script
creates a separate empirical correction matrix for the N_LANE=4/Egress=1x OPQ
surface and records residuals against both RTL and structural TLM evidence.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
MODEL_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_BASE = (
    MODEL_ROOT
    / "analytical"
    / "data"
    / "queueing_model"
    / "dislin"
    / "opq_loss_surface_nlane04_egress01x.dat"
)
DEFAULT_RTL = (
    MODEL_ROOT
    / "rtl_sim"
    / "data"
    / "opq_mu3e_demo_calibration_scan_n4_e1.csv"
)
DEFAULT_TLM = (
    MODEL_ROOT
    / "rtl_sim"
    / "data"
    / "opq_structural_tlm_mu3e_demo_calibration_scan_n4_e1.csv"
)
DEFAULT_OUT = (
    MODEL_ROOT
    / "analytical"
    / "data"
    / "queueing_model"
    / "dislin"
    / "opq_loss_surface_nlane04_egress01x_calibrated.dat"
)
DEFAULT_RESIDUALS = (
    MODEL_ROOT
    / "analytical"
    / "data"
    / "queueing_model"
    / "opq_calibration_residuals_n4_e1.csv"
)
DEFAULT_SUMMARY = (
    MODEL_ROOT
    / "analytical"
    / "data"
    / "queueing_model"
    / "opq_calibration_summary_n4_e1.json"
)


@dataclass(frozen=True)
class Grid:
    x: list[float]
    y: list[float]
    z: list[list[float]]


@dataclass(frozen=True)
class EvidencePoint:
    run_tag: str
    burstiness: float
    rho_lane: float
    rtl_loss: float
    tlm_loss: float | None
    expected_hits: int
    sim_pass: bool
    loss_tier: str


def parse_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    value = row.get(key, "")
    if value in {"", "-"}:
        return default
    return float(value)


def parse_int(row: dict[str, str], key: str, default: int = 0) -> int:
    value = row.get(key, "")
    if value in {"", "-"}:
        return default
    return int(float(value))


def clamp_probability(value: float, eps: float = 1.0e-9) -> float:
    return max(eps, min(1.0 - eps, value))


def logit(value: float) -> float:
    p = clamp_probability(value)
    return math.log(p / (1.0 - p))


def inv_logit(value: float) -> float:
    if value >= 0.0:
        exp_neg = math.exp(-value)
        return 1.0 / (1.0 + exp_neg)
    exp_pos = math.exp(value)
    return exp_pos / (1.0 + exp_pos)


def read_dislin_matrix(path: Path) -> Grid:
    tokens = path.read_text(encoding="ascii").split()
    cursor = 0
    nx = int(tokens[cursor])
    cursor += 1
    ny = int(tokens[cursor])
    cursor += 1
    x = [float(tokens[cursor + idx]) for idx in range(nx)]
    cursor += nx
    y = [float(tokens[cursor + idx]) for idx in range(ny)]
    cursor += ny
    z: list[list[float]] = []
    for _ in range(nx):
        z.append([float(tokens[cursor + idx]) for idx in range(ny)])
        cursor += ny
    if cursor != len(tokens):
        raise SystemExit(f"unexpected trailing data in {path}")
    return Grid(x=x, y=y, z=z)


def write_dislin_matrix(path: Path, grid: Grid) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as handle:
        handle.write(f"{len(grid.x)} {len(grid.y)}\n")
        handle.write(" ".join(f"{value:.8f}" for value in grid.x))
        handle.write("\n")
        handle.write(" ".join(f"{value:.8f}" for value in grid.y))
        handle.write("\n")
        for row in grid.z:
            handle.write(" ".join(f"{value:.12e}" for value in row))
            handle.write("\n")


def bracketing_index(values: list[float], value: float) -> int:
    if value <= values[0]:
        return 0
    if value >= values[-1]:
        return len(values) - 2
    return max(0, min(len(values) - 2, bisect.bisect_right(values, value) - 1))


def interpolate(grid: Grid, x_value: float, y_value: float) -> float:
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


def read_csv_by_run(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    with path.open(newline="", encoding="ascii", errors="replace") as handle:
        return {
            row["run_tag"]: row
            for row in csv.DictReader(handle)
            if row.get("run_tag")
        }


def read_evidence(rtl_path: Path, tlm_path: Path | None) -> list[EvidencePoint]:
    rtl_rows = read_csv_by_run(rtl_path)
    if not rtl_rows:
        raise SystemExit(f"missing or empty RTL evidence CSV {rtl_path}")
    tlm_rows = read_csv_by_run(tlm_path) if tlm_path and tlm_path.exists() else {}
    evidence: list[EvidencePoint] = []
    for run_tag, rtl in sorted(rtl_rows.items()):
        expected = parse_int(rtl, "expected_hits")
        if expected <= 0:
            continue
        burstiness = parse_float(rtl, "burstiness", parse_float(rtl, "burstiness_milli") / 1000.0)
        rho_lane = parse_float(
            rtl,
            "normalized_share_lane",
            parse_float(rtl, "rho_lane"),
        )
        rtl_loss = parse_float(rtl, "loss_probability")
        tlm = tlm_rows.get(run_tag, {})
        tlm_loss = parse_float(tlm, "tlm_loss", math.nan) if tlm else math.nan
        evidence.append(
            EvidencePoint(
                run_tag=run_tag,
                burstiness=burstiness,
                rho_lane=rho_lane,
                rtl_loss=rtl_loss,
                tlm_loss=None if math.isnan(tlm_loss) else tlm_loss,
                expected_hits=expected,
                sim_pass=rtl.get("sim_pass", "0") == "1",
                loss_tier=rtl.get("loss_tier", "-") or "-",
            )
        )
    return evidence


def evidence_weight(point: EvidencePoint) -> float:
    tier_weight = {
        "-": 0.85,
        "controlled": 1.0,
        "asserted": 0.9,
        "mixed": 0.75,
        "inferred": 0.45,
    }.get(point.loss_tier, 0.65)
    sim_weight = 1.0 if point.sim_pass else 0.70
    tlm_weight = 1.0
    if point.tlm_loss is not None:
        diff = abs(point.rtl_loss - point.tlm_loss)
        tlm_weight = 1.0 / (1.0 + (diff / 0.20) ** 2)
        tlm_weight = max(0.35, tlm_weight)
    sample_weight = min(3.0, max(0.25, math.sqrt(point.expected_hits / 50_000.0)))
    return tier_weight * sim_weight * tlm_weight * sample_weight


def calibrate_grid(
    base: Grid,
    evidence: list[EvidencePoint],
    *,
    sigma_b: float,
    sigma_rho: float,
    regularization: float,
) -> Grid:
    corrected: list[list[float]] = []
    residuals = [
        (
            point,
            logit(point.rtl_loss) - logit(interpolate(base, point.burstiness, point.rho_lane)),
            evidence_weight(point),
        )
        for point in evidence
    ]
    for ix, burstiness in enumerate(base.x):
        row: list[float] = []
        for iy, rho_lane in enumerate(base.y):
            weighted_residual = 0.0
            weight_sum = 0.0
            for point, residual, base_weight in residuals:
                dx = (burstiness - point.burstiness) / sigma_b
                dy = (rho_lane - point.rho_lane) / sigma_rho
                distance2 = (dx * dx) + (dy * dy)
                local_weight = base_weight * math.exp(-0.5 * distance2)
                weighted_residual += local_weight * residual
                weight_sum += local_weight
            base_logit = logit(base.z[ix][iy])
            blend = weight_sum / (weight_sum + regularization) if weight_sum > 0.0 else 0.0
            calibrated = inv_logit(base_logit + (blend * weighted_residual / max(weight_sum, 1.0e-12)))
            row.append(clamp_probability(calibrated, eps=1.0e-12))
        # Loss must not decrease as normalized offered share increases.
        for iy in range(1, len(row)):
            if row[iy] < row[iy - 1]:
                row[iy] = row[iy - 1]
        corrected.append(row)
    return Grid(x=list(base.x), y=list(base.y), z=corrected)


def mean_abs(values: list[float]) -> float:
    return sum(abs(value) for value in values) / len(values) if values else 0.0


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values)) if values else 0.0


def write_residuals(path: Path, base: Grid, calibrated: Grid, evidence: list[EvidencePoint]) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    base_errors: list[float] = []
    calibrated_errors: list[float] = []
    tlm_errors: list[float] = []
    for point in evidence:
        base_loss = interpolate(base, point.burstiness, point.rho_lane)
        calibrated_loss = interpolate(calibrated, point.burstiness, point.rho_lane)
        base_error = base_loss - point.rtl_loss
        calibrated_error = calibrated_loss - point.rtl_loss
        base_errors.append(base_error)
        calibrated_errors.append(calibrated_error)
        if point.tlm_loss is not None:
            tlm_errors.append(point.tlm_loss - point.rtl_loss)
        rows.append(
            {
                "run_tag": point.run_tag,
                "burstiness": f"{point.burstiness:.6f}",
                "rho_lane": f"{point.rho_lane:.6f}",
                "rtl_loss": f"{point.rtl_loss:.8f}",
                "tlm_loss": "" if point.tlm_loss is None else f"{point.tlm_loss:.8f}",
                "base_analytical_loss": f"{base_loss:.8f}",
                "calibrated_analytical_loss": f"{calibrated_loss:.8f}",
                "base_minus_rtl": f"{base_error:.8f}",
                "calibrated_minus_rtl": f"{calibrated_error:.8f}",
                "tlm_minus_rtl": "" if point.tlm_loss is None else f"{point.tlm_loss - point.rtl_loss:.8f}",
                "expected_hits": point.expected_hits,
                "sim_pass": "1" if point.sim_pass else "0",
                "loss_tier": point.loss_tier,
                "weight": f"{evidence_weight(point):.6f}",
            }
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "run_tag",
                "burstiness",
                "rho_lane",
                "rtl_loss",
                "tlm_loss",
                "base_analytical_loss",
                "calibrated_analytical_loss",
                "base_minus_rtl",
                "calibrated_minus_rtl",
                "tlm_minus_rtl",
                "expected_hits",
                "sim_pass",
                "loss_tier",
                "weight",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    worst = max(rows, key=lambda row: abs(float(row["calibrated_minus_rtl"]))) if rows else {}
    return {
        "point_count": len(evidence),
        "rtl_pass_point_count": sum(1 for point in evidence if point.sim_pass),
        "loss_tiers": {
            tier: sum(1 for point in evidence if point.loss_tier == tier)
            for tier in sorted({point.loss_tier for point in evidence})
        },
        "base_mean_abs_error": mean_abs(base_errors),
        "base_rms_error": rms(base_errors),
        "calibrated_mean_abs_error": mean_abs(calibrated_errors),
        "calibrated_rms_error": rms(calibrated_errors),
        "tlm_mean_abs_error": mean_abs(tlm_errors),
        "tlm_rms_error": rms(tlm_errors),
        "mean_abs_error_gain": mean_abs(base_errors) - mean_abs(calibrated_errors),
        "worst_calibrated_point": worst,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-dat", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--rtl", type=Path, default=DEFAULT_RTL)
    parser.add_argument("--tlm", type=Path, default=DEFAULT_TLM)
    parser.add_argument("--output-dat", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--residual-csv", type=Path, default=DEFAULT_RESIDUALS)
    parser.add_argument("--summary-json", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--sigma-b", type=float, default=0.24)
    parser.add_argument("--sigma-rho", type=float, default=0.045)
    parser.add_argument("--regularization", type=float, default=0.20)
    args = parser.parse_args()

    base = read_dislin_matrix(args.base_dat)
    evidence = read_evidence(args.rtl, args.tlm)
    calibrated = calibrate_grid(
        base,
        evidence,
        sigma_b=args.sigma_b,
        sigma_rho=args.sigma_rho,
        regularization=args.regularization,
    )
    write_dislin_matrix(args.output_dat, calibrated)
    summary = write_residuals(args.residual_csv, base, calibrated, evidence)
    summary.update(
        {
            "base_dat": str(args.base_dat),
            "rtl_csv": str(args.rtl),
            "tlm_csv": str(args.tlm) if args.tlm.exists() else "",
            "output_dat": str(args.output_dat),
            "residual_csv": str(args.residual_csv),
            "method": "RTL-targeted logit residual IDW; TLM affects confidence and residual reporting",
            "sigma_b": args.sigma_b,
            "sigma_rho": args.sigma_rho,
            "regularization": args.regularization,
        }
    )
    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

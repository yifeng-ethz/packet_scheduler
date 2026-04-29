#!/usr/bin/env python3
"""Update one row in packet_scheduler/model/doc/MODEL_PLAN.md scoreboard."""

from __future__ import annotations

import argparse
import datetime as dt
import math
from pathlib import Path


PLAN_PATH = Path(__file__).with_name("MODEL_PLAN.md")
BEGIN = "<!-- SCOREBOARD:BEGIN -->"
END = "<!-- SCOREBOARD:END -->"
HEADERS = [
    "case_id",
    "status",
    "tier",
    "impl",
    "N",
    "E",
    "B",
    "rho",
    "timing",
    "points",
    "hits/run",
    "TLM loss",
    "RTL loss",
    "rel err",
    "match",
    "loss tier",
    "evidence",
    "updated",
    "notes",
]
VALID_STATUSES = {"TODO", "IN_PROGRESS", "PASS", "DEBUG", "BLOCKED"}


def escape_cell(value: object) -> str:
    text = str(value)
    text = text.replace("\\", "\\\\")
    text = text.replace("|", "\\|")
    text = " ".join(text.split())
    return text if text else "-"


def split_row(line: str) -> list[str]:
    raw = line.strip()
    if not raw.startswith("|") or not raw.endswith("|"):
        return []
    cells = []
    current = []
    escaped = False
    for char in raw[1:-1]:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == "|":
            cells.append("".join(current).strip())
            current = []
        else:
            current.append(char)
    cells.append("".join(current).strip())
    return cells


def is_separator(line: str) -> bool:
    cells = split_row(line)
    return bool(cells) and all(set(cell.replace(":", "").strip()) <= {"-"} for cell in cells)


def parse_rows(block: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in block.splitlines():
        cells = split_row(line)
        if not cells or cells[0] == "case_id" or is_separator(line):
            continue
        if len(cells) == len(HEADERS) - 1:
            cells.insert(HEADERS.index("loss tier"), "-")
        padded = (cells + ["-"] * len(HEADERS))[: len(HEADERS)]
        rows.append(dict(zip(HEADERS, padded)))
    return rows


def format_row(row: dict[str, str]) -> str:
    return "| " + " | ".join(escape_cell(row.get(header, "-")) for header in HEADERS) + " |"


def format_table(rows: list[dict[str, str]]) -> str:
    lines = [
        format_row(dict(zip(HEADERS, HEADERS))),
        "|---|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|---|---|---|---|",
    ]
    lines.extend(format_row(row) for row in rows)
    return "\n".join(lines)


def parse_float(value: str | None) -> float | None:
    if value is None or value == "" or value == "-":
        return None
    return float(value)


def format_float(value: float | None) -> str:
    if value is None:
        return "-"
    if value == 0.0:
        return "0"
    abs_value = abs(value)
    if abs_value < 1.0e-3 or abs_value >= 1.0e4:
        return f"{value:.6e}"
    return f"{value:.6g}"


def compute_match(row: dict[str, str], abs_tol: float, rel_tol: float) -> None:
    tlm = parse_float(row.get("TLM loss"))
    rtl = parse_float(row.get("RTL loss"))
    if tlm is None or rtl is None:
        row.setdefault("rel err", "-")
        row.setdefault("match", row.get("status", "TODO"))
        return

    abs_delta = abs(rtl - tlm)
    denom = max(abs(tlm), 1.0e-12)
    if abs(tlm) <= abs_tol and abs(rtl) <= abs_tol:
        rel_delta = 0.0
    else:
        rel_delta = abs_delta / denom
    row["rel err"] = format_float(rel_delta)
    if abs_delta <= abs_tol or rel_delta <= rel_tol:
        row["match"] = "PASS"
        if row.get("status") not in {"BLOCKED"}:
            row["status"] = "PASS"
    else:
        row["match"] = "DEBUG"
        if row.get("status") not in {"BLOCKED"}:
            row["status"] = "DEBUG"


def update_plan(args: argparse.Namespace) -> None:
    plan_path = args.plan
    text = plan_path.read_text(encoding="ascii")
    if BEGIN not in text or END not in text:
        raise SystemExit(f"{plan_path} does not contain scoreboard markers")

    before, rest = text.split(BEGIN, 1)
    block, after = rest.split(END, 1)
    rows = parse_rows(block)
    by_case = {row["case_id"]: row for row in rows}
    row = by_case.get(args.case_id)
    if row is None:
        row = {header: "-" for header in HEADERS}
        row["case_id"] = args.case_id
        rows.append(row)

    field_map = {
        "status": args.status,
        "tier": args.tier,
        "impl": args.implementation,
        "N": args.n_lane,
        "E": args.egress,
        "B": args.burstiness,
        "rho": args.rho_lane,
        "timing": args.timing,
        "points": args.points,
        "hits/run": args.hits_per_run,
        "TLM loss": args.tlm_loss,
        "RTL loss": args.rtl_loss,
        "match": args.match,
        "loss tier": args.loss_tier,
        "evidence": args.evidence,
        "notes": args.notes,
    }
    for field, value in field_map.items():
        if value is not None:
            row[field] = str(value)

    status = row.get("status", "TODO")
    if status not in VALID_STATUSES:
        raise SystemExit(f"invalid status {status!r}; expected one of {sorted(VALID_STATUSES)}")

    row["updated"] = args.updated or dt.date.today().isoformat()
    compute_match(row, args.abs_tol, args.rel_tol)
    table = format_table(rows)
    plan_path.write_text(f"{before}{BEGIN}\n{table}\n{END}{after}", encoding="ascii")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, default=PLAN_PATH)
    parser.add_argument("--case-id", required=True)
    parser.add_argument("--status", choices=sorted(VALID_STATUSES))
    parser.add_argument("--tier")
    parser.add_argument("--implementation")
    parser.add_argument("--n-lane")
    parser.add_argument("--egress")
    parser.add_argument("--burstiness")
    parser.add_argument("--rho-lane")
    parser.add_argument("--timing")
    parser.add_argument("--points")
    parser.add_argument("--hits-per-run")
    parser.add_argument("--tlm-loss")
    parser.add_argument("--rtl-loss")
    parser.add_argument("--match")
    parser.add_argument("--loss-tier")
    parser.add_argument("--evidence")
    parser.add_argument("--notes")
    parser.add_argument("--updated")
    parser.add_argument("--abs-tol", type=float, default=1.0e-6)
    parser.add_argument("--rel-tol", type=float, default=0.20)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if not math.isfinite(args.abs_tol) or args.abs_tol < 0.0:
        raise SystemExit("--abs-tol must be finite and non-negative")
    if not math.isfinite(args.rel_tol) or args.rel_tol < 0.0:
        raise SystemExit("--rel-tol must be finite and non-negative")
    update_plan(args)


if __name__ == "__main__":
    main()

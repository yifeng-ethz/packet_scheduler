#!/usr/bin/env python3
"""Parse OPQ residency-proxy trace logs and emit quantiles plus plots."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
from collections import defaultdict
from pathlib import Path


SAMPLE_RE = re.compile(
    r"OPQ_RESIDENCY_PROXY_SAMPLE lane=(?P<lane>\d+) sample_idx=(?P<sample_idx>\d+) "
    r"frame_ts=0x(?P<frame_ts>[0-9a-fA-F]+) proxy_ingress_ts=0x(?P<proxy_ingress_ts>[0-9a-fA-F]+) "
    r"ingress_debug_ts=0x(?P<ingress_debug_ts>[0-9a-fA-F]+) egress_debug_ts=0x(?P<egress_debug_ts>[0-9a-fA-F]+) "
    r"proxy_cycles=(?P<proxy_cycles>-?\d+) debug_delta_cycles=(?P<debug_delta_cycles>-?\d+)"
)
SUMMARY_RE = re.compile(r"UVM_ERROR\s*:\s*(?P<uvm_error>\d+)")


def quantile(values: list[int], q: float) -> float:
    if not values:
        return math.nan
    if len(values) == 1:
        return float(values[0])
    ordered = sorted(values)
    pos = q * (len(ordered) - 1)
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return float(ordered[lo])
    frac = pos - lo
    return ordered[lo] + frac * (ordered[hi] - ordered[lo])


def summarize(values: list[int]) -> dict[str, float | int]:
    ordered = sorted(values)
    return {
        "samples": len(ordered),
        "min": int(ordered[0]),
        "p05": quantile(ordered, 0.05),
        "p50": quantile(ordered, 0.50),
        "p95": quantile(ordered, 0.95),
        "max": int(ordered[-1]),
        "mean": sum(ordered) / len(ordered),
    }


def parse_log(log_path: Path) -> dict:
    per_lane: dict[int, list[int]] = defaultdict(list)
    debug_delta_per_lane: dict[int, list[int]] = defaultdict(list)
    uvm_error_count = None

    with log_path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            sample_match = SAMPLE_RE.search(line)
            if sample_match:
                lane = int(sample_match.group("lane"))
                per_lane[lane].append(int(sample_match.group("proxy_cycles")))
                debug_delta_per_lane[lane].append(int(sample_match.group("debug_delta_cycles")))
                continue

            summary_match = SUMMARY_RE.search(line)
            if summary_match:
                uvm_error_count = int(summary_match.group("uvm_error"))

    combined = []
    combined_debug_delta = []
    for lane in sorted(per_lane):
        combined.extend(per_lane[lane])
        combined_debug_delta.extend(debug_delta_per_lane[lane])

    result = {
        "test": log_path.stem,
        "log_path": str(log_path),
        "pass": (uvm_error_count == 0) if (uvm_error_count is not None) else None,
        "uvm_error_count": uvm_error_count,
        "lanes": {},
        "all_lanes": summarize(combined) if combined else None,
        "all_lanes_debug_delta": summarize(combined_debug_delta) if combined_debug_delta else None,
    }
    for lane in sorted(per_lane):
        result["lanes"][str(lane)] = {
            "proxy_cycles": summarize(per_lane[lane]),
            "debug_delta_cycles": summarize(debug_delta_per_lane[lane]),
        }
    return result


def write_csv(results: list[dict], csv_path: Path) -> None:
    with csv_path.open("w", newline="", encoding="ascii") as f:
        writer = csv.writer(f)
        writer.writerow([
            "test",
            "lane",
            "pass",
            "samples",
            "min",
            "p05",
            "p50",
            "p95",
            "max",
            "mean",
            "debug_delta_p50",
        ])
        for result in results:
            for lane, lane_summary in result["lanes"].items():
                proxy = lane_summary["proxy_cycles"]
                debug_delta = lane_summary["debug_delta_cycles"]
                writer.writerow([
                    result["test"],
                    lane,
                    result["pass"],
                    proxy["samples"],
                    proxy["min"],
                    f"{proxy['p05']:.2f}",
                    f"{proxy['p50']:.2f}",
                    f"{proxy['p95']:.2f}",
                    proxy["max"],
                    f"{proxy['mean']:.2f}",
                    f"{debug_delta['p50']:.2f}",
                ])
            if result["all_lanes"] is not None:
                proxy = result["all_lanes"]
                debug_delta = result["all_lanes_debug_delta"]
                writer.writerow([
                    result["test"],
                    "all",
                    result["pass"],
                    proxy["samples"],
                    proxy["min"],
                    f"{proxy['p05']:.2f}",
                    f"{proxy['p50']:.2f}",
                    f"{proxy['p95']:.2f}",
                    proxy["max"],
                    f"{proxy['mean']:.2f}",
                    f"{debug_delta['p50']:.2f}" if debug_delta is not None else "",
                ])


def render_plots(results: list[dict], output_dir: Path) -> list[str]:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return []

    rendered = []

    aggregate_fig, aggregate_ax = plt.subplots(figsize=(10, 6))
    for result in results:
        if result["all_lanes"] is None:
            continue
        raw_values = []
        log_path = Path(result["log_path"])
        with log_path.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                sample_match = SAMPLE_RE.search(line)
                if sample_match:
                    raw_values.append(int(sample_match.group("proxy_cycles")))
        if not raw_values:
            continue
        raw_values.sort()
        xs = raw_values
        ys = [(idx + 1) / len(raw_values) for idx in range(len(raw_values))]
        aggregate_ax.step(xs, ys, where="post", label=result["test"])
    aggregate_ax.set_title("OPQ Residency Proxy Signature ECDF")
    aggregate_ax.set_xlabel("proxy_cycles")
    aggregate_ax.set_ylabel("empirical CDF")
    aggregate_ax.grid(True, alpha=0.25)
    aggregate_ax.legend(fontsize=8)
    aggregate_path = output_dir / "residency_proxy_signature_ecdf.png"
    aggregate_fig.tight_layout()
    aggregate_fig.savefig(aggregate_path, dpi=160)
    plt.close(aggregate_fig)
    rendered.append(str(aggregate_path))

    plot_results = [result for result in results if result["lanes"]]
    if plot_results:
        cols = 2
        rows = math.ceil(len(plot_results) / cols)
        per_test_fig, axes = plt.subplots(rows, cols, figsize=(12, max(4, 3 * rows)), squeeze=False)
        for axis in axes.flat:
            axis.set_visible(False)
        for axis, result in zip(axes.flat, plot_results):
            axis.set_visible(True)
            raw_per_lane: dict[int, list[int]] = defaultdict(list)
            with Path(result["log_path"]).open("r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    sample_match = SAMPLE_RE.search(line)
                    if sample_match:
                        raw_per_lane[int(sample_match.group("lane"))].append(int(sample_match.group("proxy_cycles")))
            for lane in sorted(raw_per_lane):
                values = sorted(raw_per_lane[lane])
                ys = [(idx + 1) / len(values) for idx in range(len(values))]
                axis.step(values, ys, where="post", label=f"lane{lane}")
            axis.set_title(result["test"])
            axis.set_xlabel("proxy_cycles")
            axis.set_ylabel("empirical CDF")
            axis.grid(True, alpha=0.25)
            axis.legend(fontsize=8)
        per_test_path = output_dir / "residency_proxy_per_test_lane_ecdf.png"
        per_test_fig.tight_layout()
        per_test_fig.savefig(per_test_path, dpi=160)
        plt.close(per_test_fig)
        rendered.append(str(per_test_path))

    return rendered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", nargs="+", help="UVM log files to parse")
    parser.add_argument(
        "--output-dir",
        default="packet_scheduler/tb/REPORT/math",
        help="Directory for generated CSV/JSON/plots",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    results = [parse_log(Path(log)) for log in args.logs]
    results.sort(key=lambda item: item["test"])

    json_path = output_dir / "residency_proxy_summary.json"
    csv_path = output_dir / "residency_proxy_quantiles.csv"
    with json_path.open("w", encoding="ascii") as f:
        json.dump(results, f, indent=2)
    write_csv(results, csv_path)
    rendered_plots = render_plots(results, output_dir)

    print(f"Wrote {json_path}")
    print(f"Wrote {csv_path}")
    for plot_path in rendered_plots:
        print(f"Wrote {plot_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Subframe-level OPQ TLM-vs-RTL debug around LATE_DROP.

This reducer keeps the comparison at the packet/hit bucket where the RTL
reports it: (frame serial, lane, subheader).  It is deliberately separate from
the aggregate component reducer so that a single bad bucket can be followed
from ingress credit, through page-allocator load/late-drop, into the frame and
transaction ledgers.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from dataclasses import asdict
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from opq_component_replay import (  # noqa: E402
    OPQ_SUBHEADER_DURATION_TS_TICKS,
    RtlLog,
    cfg_from_log,
    ingress_decision_override_from_rtl,
    lane_frames_from_rtl_ingress,
    parse_int,
    parse_log,
    rel_delta,
    run_tlm,
)


REPO_ROOT = Path(__file__).resolve().parents[4]
PKT_ROOT = REPO_ROOT / "packet_scheduler"
DEFAULT_LOG_ROOT = PKT_ROOT / "model" / "rtl_sim" / "runs" / "component_replay_100k_ingress_20260429" / "stdout"
DEFAULT_OUT_PREFIX = PKT_ROOT / "model" / "rtl_sim" / "data" / "opq_subframe_late_debug"

Bucket = tuple[int, int, int]  # frame, lane, subheader


def shd_from_timestamp(timestamp: int, n_shd: int) -> int:
    return (timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, n_shd)


def bucket_from_ts(frame: int, lane: int, timestamp: int, n_shd: int) -> Bucket:
    return (frame, lane, shd_from_timestamp(timestamp, n_shd))


def add_count(counter: Counter[Bucket], key: Bucket, amount: int) -> None:
    if amount:
        counter[key] += int(amount)


def rtl_source_hits(rtl: RtlLog) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.ingress:
        add_count(out, (row["pkg_cnt"], row["lane"], row["shd"]), row["hit_count"])
    return out


def rtl_ingress_accept_hits(rtl: RtlLog) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.ingress:
        if not row["drop_valid"]:
            add_count(out, (row["pkg_cnt"], row["lane"], row["shd"]), row["hit_count"])
    return out


def rtl_ingress_flag_predrop_hits(rtl: RtlLog) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.ingress:
        if row["drop_valid"]:
            add_count(out, (row["pkg_cnt"], row["lane"], row["shd"]), row["hit_count"])
    return out


def rtl_exact_predrop_hits(rtl: RtlLog, n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.predrops:
        # The debug line's exact_pre(shd=...) field is a valid/count marker in
        # this trace, not the timestamp bucket.  The object bucket must be
        # recovered from the true hit timestamp.
        shd = shd_from_timestamp(row["timestamp"], n_shd)
        add_count(out, (row["serial"], row["lane"], shd), row["hit_count"])
    return out


def rtl_exact_late_drop_hits(rtl: RtlLog, n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.postdrops:
        shd = shd_from_timestamp(row["timestamp"], n_shd)
        add_count(out, (row["serial"], row["lane"], shd), row["hit_count"])
    return out


def rtl_pa_load_hits(rtl: RtlLog, n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.pa_actions:
        if row["action"] != 2:
            continue
        add_count(out, (row["body_serial"], row["lane"], shd_from_timestamp(row["fetch_ts"], n_shd)), row["block_len"])
    return out


def rtl_pa_late_drop_hits(rtl: RtlLog, n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.pa_actions:
        if row["action"] != 3:
            continue
        add_count(out, (row["body_serial"], row["lane"], shd_from_timestamp(row["fetch_ts"], n_shd)), row["block_len"])
    return out


def rtl_txn_deliver_hits(rtl: RtlLog) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in rtl.txn_events.get("deliver", []):
        bucket = row.get("bucket", "0")
        shd_text = bucket.split(":", 1)[1] if ":" in bucket else bucket
        frame = parse_int(row.get("pkg_cnt", "0"))
        shd = parse_int(shd_text)
        # OPQ_TXN deliver can report lane=-1 after egress payload decoding has
        # lost source-lane identity.  The contract for this checkpoint is
        # bucket membership and count; source-lane identity is checked earlier.
        out[(frame, -1, shd)] += 1
    return out


def tlm_stage_hits(trace: list[dict[str, object]], stage: str, n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in trace:
        if str(row.get("stage", "")) != stage:
            continue
        timestamp = int(row.get("timestamp", 0))
        frame = int(row.get("serial", row.get("frame", 0)))
        lane = int(row.get("lane", 0))
        add_count(out, bucket_from_ts(frame, lane, timestamp, n_shd), int(row.get("hit_count", 0)))
    return out


def tlm_source_hits(trace: list[dict[str, object]], n_shd: int) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for row in trace:
        if str(row.get("stage", "")) not in {"ingress_preaccept", "ingress_predrop"}:
            continue
        timestamp = int(row.get("timestamp", 0))
        frame = int(row.get("serial", row.get("frame", 0)))
        lane = int(row.get("lane", 0))
        add_count(out, bucket_from_ts(frame, lane, timestamp, n_shd), int(row.get("hit_count", 0)))
    return out


def tlm_deliver_hits(tlm) -> Counter[Bucket]:
    out: Counter[Bucket] = Counter()
    for hit in tlm.egress_hits:
        out[(hit.frame, -1, hit.shd)] += 1
    return out


def tlm_frame_close_hits(trace: list[dict[str, object]]) -> Counter[tuple[int, str]]:
    out: Counter[tuple[int, str]] = Counter()
    for row in trace:
        if str(row.get("stage", "")) != "frame_close":
            continue
        frame = int(row.get("serial", row.get("frame", 0)))
        out[(frame, "hit")] += int(row.get("hit_count", 0))
        out[(frame, "subheader")] += int(row.get("subheader_count", 0))
    return out


def rtl_frame_ledger_hits(rtl: RtlLog) -> Counter[tuple[int, str]]:
    out: Counter[tuple[int, str]] = Counter()
    if not rtl.ft_ledgers:
        return out
    last = rtl.ft_ledgers[-1]
    out[(0, "hit")] = last["rd_hit"] + last["drop_hit"]
    out[(0, "subheader")] = last["rd_shd"] + last["drop_shd"]
    return out


def decision_counter_from_rtl(rtl: RtlLog) -> Counter[tuple[int, int, int, str]]:
    out: Counter[tuple[int, int, int, str]] = Counter()
    for row in rtl.ingress:
        kind = "drop" if row["drop_valid"] else "accept"
        out[(row["pkg_cnt"], row["lane"], row["shd"], kind)] += 1
    return out


def decision_counter_from_tlm(trace: list[dict[str, object]], n_shd: int) -> Counter[tuple[int, int, int, str]]:
    out: Counter[tuple[int, int, int, str]] = Counter()
    for row in trace:
        stage = str(row.get("stage", ""))
        if stage not in {"ingress_preaccept", "ingress_predrop"}:
            continue
        timestamp = int(row.get("timestamp", 0))
        frame = int(row.get("serial", row.get("frame", 0)))
        lane = int(row.get("lane", 0))
        kind = "drop" if stage == "ingress_predrop" else "accept"
        out[(frame, lane, shd_from_timestamp(timestamp, n_shd), kind)] += 1
    return out


def credit_notes_from_rtl(rtl: RtlLog) -> dict[Bucket, str]:
    grouped: dict[Bucket, list[dict[str, int]]] = defaultdict(list)
    for row in rtl.ingress:
        grouped[(row["pkg_cnt"], row["lane"], row["shd"])].append(row)
    notes: dict[Bucket, str] = {}
    for key, rows in grouped.items():
        lane_credit = [row["lane_credit"] for row in rows]
        ticket_credit = [row["ticket_credit"] for row in rows]
        drop_count = sum(1 for row in rows if row["drop_valid"])
        notes[key] = (
            f"rtl_ing_rows={len(rows)} rtl_drop_rows={drop_count} "
            f"rtl_lane_credit_min={min(lane_credit)} rtl_lane_credit_max={max(lane_credit)} "
            f"rtl_ticket_credit_min={min(ticket_credit)}"
        )
    return notes


def credit_notes_from_tlm(trace: list[dict[str, object]], n_shd: int) -> dict[Bucket, str]:
    grouped: dict[Bucket, list[dict[str, object]]] = defaultdict(list)
    for row in trace:
        if str(row.get("stage", "")) not in {"ingress_preaccept", "ingress_predrop"}:
            continue
        key = bucket_from_ts(
            int(row.get("serial", row.get("frame", 0))),
            int(row.get("lane", 0)),
            int(row.get("timestamp", 0)),
            n_shd,
        )
        grouped[key].append(row)
    notes: dict[Bucket, str] = {}
    for key, rows in grouped.items():
        lane_credit = [int(row.get("lane_credit_before", 0)) for row in rows]
        effective = [int(row.get("effective_lane_credit", row.get("lane_credit_before", 0))) for row in rows]
        ticket_credit = [int(row.get("ticket_credit_before", 0)) for row in rows]
        reasons = sorted({str(row.get("drop_reason", "accept")) for row in rows})
        notes[key] = (
            f"tlm_ing_rows={len(rows)} tlm_lane_credit_min={min(lane_credit)} "
            f"tlm_effective_min={min(effective)} tlm_ticket_credit_min={min(ticket_credit)} "
            f"tlm_reasons={','.join(reasons)}"
        )
    return notes


def merged_notes(*note_maps: dict[Bucket, str]) -> dict[Bucket, str]:
    keys: set[Bucket] = set()
    for note_map in note_maps:
        keys.update(note_map)
    return {key: " | ".join(note_map[key] for note_map in note_maps if key in note_map) for key in keys}


def compare_buckets(
    *,
    run_tag: str,
    mode: str,
    component: str,
    rtl_counts: Counter[Bucket],
    tlm_counts: Counter[Bucket],
    threshold: float,
    detail_rows: list[dict[str, object]],
    notes_by_key: dict[Bucket, str] | None = None,
) -> dict[str, object]:
    keys = set(rtl_counts) | set(tlm_counts)
    rtl_hits = sum(rtl_counts.values())
    tlm_hits = sum(tlm_counts.values())
    abs_delta_hits = sum(abs(rtl_counts.get(key, 0) - tlm_counts.get(key, 0)) for key in keys)
    mismatched = [key for key in keys if rtl_counts.get(key, 0) != tlm_counts.get(key, 0)]
    first_key = min(mismatched) if mismatched else None
    top = sorted(
        mismatched,
        key=lambda key: (-abs(rtl_counts.get(key, 0) - tlm_counts.get(key, 0)), key),
    )[:8]
    aggregate_delta = rel_delta(tlm_hits, rtl_hits)
    bucket_delta = abs_delta_hits / max(rtl_hits, 1)
    status = "PASS" if aggregate_delta <= threshold and bucket_delta <= threshold else "DEBUG"
    notes_by_key = notes_by_key or {}
    for rank, key in enumerate(top, start=1):
        detail_rows.append(
            {
                "run_tag": run_tag,
                "mode": mode,
                "component": component,
                "rank": rank,
                "frame": key[0],
                "lane": key[1],
                "shd": key[2],
                "rtl_hits": rtl_counts.get(key, 0),
                "tlm_hits": tlm_counts.get(key, 0),
                "delta_hits": tlm_counts.get(key, 0) - rtl_counts.get(key, 0),
                "is_first_by_frame": int(key == first_key),
                "notes": notes_by_key.get(key, ""),
            }
        )
    return {
        "run_tag": run_tag,
        "mode": mode,
        "component": component,
        "status": status,
        "rtl_hits": rtl_hits,
        "tlm_hits": tlm_hits,
        "aggregate_delta": f"{aggregate_delta:.8g}",
        "bucket_abs_delta": f"{bucket_delta:.8g}",
        "compared_buckets": len(keys),
        "mismatched_buckets": len(mismatched),
        "abs_delta_hits": abs_delta_hits,
        "first_mismatch": "-" if first_key is None else f"f{first_key[0]} l{first_key[1]} shd{first_key[2]}",
        "threshold": threshold,
    }


def compare_decisions(
    *,
    run_tag: str,
    mode: str,
    rtl_counts: Counter[tuple[int, int, int, str]],
    tlm_counts: Counter[tuple[int, int, int, str]],
    threshold: float,
    detail_rows: list[dict[str, object]],
    notes_by_key: dict[Bucket, str],
) -> dict[str, object]:
    keys = set(rtl_counts) | set(tlm_counts)
    rtl_events = sum(rtl_counts.values())
    tlm_events = sum(tlm_counts.values())
    abs_delta = sum(abs(rtl_counts.get(key, 0) - tlm_counts.get(key, 0)) for key in keys)
    mismatched = [key for key in keys if rtl_counts.get(key, 0) != tlm_counts.get(key, 0)]
    first_key = min(mismatched) if mismatched else None
    top = sorted(
        mismatched,
        key=lambda key: (-abs(rtl_counts.get(key, 0) - tlm_counts.get(key, 0)), key),
    )[:8]
    aggregate_delta = rel_delta(tlm_events, rtl_events)
    decision_delta = abs_delta / max(rtl_events, 1)
    status = "PASS" if aggregate_delta <= threshold and decision_delta <= threshold else "DEBUG"
    for rank, key in enumerate(top, start=1):
        bucket = (key[0], key[1], key[2])
        detail_rows.append(
            {
                "run_tag": run_tag,
                "mode": mode,
                "component": "ingress_decision_ticket",
                "rank": rank,
                "frame": key[0],
                "lane": key[1],
                "shd": key[2],
                "rtl_hits": rtl_counts.get(key, 0),
                "tlm_hits": tlm_counts.get(key, 0),
                "delta_hits": tlm_counts.get(key, 0) - rtl_counts.get(key, 0),
                "is_first_by_frame": int(key == first_key),
                "notes": f"decision={key[3]} | {notes_by_key.get(bucket, '')}",
            }
        )
    return {
        "run_tag": run_tag,
        "mode": mode,
        "component": "ingress_decision_ticket",
        "status": status,
        "rtl_hits": rtl_events,
        "tlm_hits": tlm_events,
        "aggregate_delta": f"{aggregate_delta:.8g}",
        "bucket_abs_delta": f"{decision_delta:.8g}",
        "compared_buckets": len(keys),
        "mismatched_buckets": len(mismatched),
        "abs_delta_hits": abs_delta,
        "first_mismatch": "-" if first_key is None else f"f{first_key[0]} l{first_key[1]} shd{first_key[2]} {first_key[3]}",
        "threshold": threshold,
    }


def run_mode(
    *,
    run_tag: str,
    rtl: RtlLog,
    cfg,
    mode: str,
    lane_frames_override,
    threshold: float,
    summary_rows: list[dict[str, object]],
    detail_rows: list[dict[str, object]],
) -> dict[str, object]:
    ingress_override = None
    if mode == "forced_ingress":
        ingress_override = ingress_decision_override_from_rtl(rtl, cfg)
    tlm, trace = run_tlm(cfg, lane_frames_override, ingress_override)
    n_shd = cfg.n_shd
    rtl_credit_notes = credit_notes_from_rtl(rtl)
    tlm_credit_notes = credit_notes_from_tlm(trace, n_shd)
    ingress_notes = merged_notes(rtl_credit_notes, tlm_credit_notes)

    comparisons: list[tuple[str, Counter[Bucket], Counter[Bucket], dict[Bucket, str]]] = [
        ("source_hits", rtl_source_hits(rtl), tlm_source_hits(trace, n_shd), ingress_notes),
        ("ingress_accept_hits", rtl_ingress_accept_hits(rtl), tlm_stage_hits(trace, "ingress_preaccept", n_shd), ingress_notes),
        ("ingress_predrop_flag_hits", rtl_ingress_flag_predrop_hits(rtl), tlm_stage_hits(trace, "ingress_predrop", n_shd), ingress_notes),
        ("controlled_predrop_exact_hits", rtl_exact_predrop_hits(rtl, n_shd), tlm_stage_hits(trace, "ingress_predrop", n_shd), ingress_notes),
        ("pa_load_hits", rtl_pa_load_hits(rtl, n_shd), tlm_stage_hits(trace, "handle_accept", n_shd), {}),
        ("late_drop_pa_action_hits", rtl_pa_late_drop_hits(rtl, n_shd), tlm_stage_hits(trace, "allocator_postdrop", n_shd), {}),
        ("late_drop_control_exact_hits", rtl_exact_late_drop_hits(rtl, n_shd), tlm_stage_hits(trace, "allocator_postdrop", n_shd), {}),
        ("transaction_deliver_hits", rtl_txn_deliver_hits(rtl), tlm_deliver_hits(tlm), {}),
    ]
    for component, rtl_counts, tlm_counts, notes in comparisons:
        summary_rows.append(
            compare_buckets(
                run_tag=run_tag,
                mode=mode,
                component=component,
                rtl_counts=rtl_counts,
                tlm_counts=tlm_counts,
                threshold=threshold,
                detail_rows=detail_rows,
                notes_by_key=notes,
            )
        )

    summary_rows.append(
        compare_decisions(
            run_tag=run_tag,
            mode=mode,
            rtl_counts=decision_counter_from_rtl(rtl),
            tlm_counts=decision_counter_from_tlm(trace, n_shd),
            threshold=threshold,
            detail_rows=detail_rows,
            notes_by_key=ingress_notes,
        )
    )

    rtl_frame = rtl_frame_ledger_hits(rtl)
    tlm_frame = tlm_frame_close_hits(trace)
    if rtl_frame and tlm_frame:
        # The RTL ledger is aggregate-only in the current trace; keep this as a
        # run-level sanity check instead of faking a subframe distribution.
        rtl_hit = rtl_frame.get((0, "hit"), 0)
        tlm_hit = sum(value for (_frame, kind), value in tlm_frame.items() if kind == "hit")
        delta = rel_delta(tlm_hit, rtl_hit)
        summary_rows.append(
            {
                "run_tag": run_tag,
                "mode": mode,
                "component": "frame_table_hit_aggregate",
                "status": "PASS" if delta <= threshold else "DEBUG",
                "rtl_hits": rtl_hit,
                "tlm_hits": tlm_hit,
                "aggregate_delta": f"{delta:.8g}",
                "bucket_abs_delta": f"{delta:.8g}",
                "compared_buckets": 1,
                "mismatched_buckets": int(rtl_hit != tlm_hit),
                "abs_delta_hits": abs(rtl_hit - tlm_hit),
                "first_mismatch": "aggregate" if rtl_hit != tlm_hit else "-",
                "threshold": threshold,
            }
        )
    return {
        "mode": mode,
        "tlm_stats": asdict(tlm.stats),
        "trace_events": len(trace),
    }


def write_csv(path: Path, rows: Iterable[dict[str, object]]) -> None:
    rows = list(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="ascii")
        return
    fields = list(rows[0].keys())
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def status_counts(rows: list[dict[str, object]]) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for row in rows:
        counts[str(row["status"])] += 1
    return dict(sorted(counts.items()))


def write_report(path: Path, summary_rows: list[dict[str, object]], detail_rows: list[dict[str, object]], run_summaries: list[dict[str, object]]) -> None:
    by_mode_component: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in summary_rows:
        by_mode_component[(str(row["mode"]), str(row["component"]))].append(row)

    lines = [
        "# OPQ Subframe LATE_DROP Debug",
        "",
        "RTL trace is treated as golden. Buckets are `(frame, lane, subheader)` unless the component is aggregate-only.",
        "",
        f"- Runs parsed: {len(run_summaries)}",
        f"- Summary rows: {len(summary_rows)}",
        f"- Detail rows: {len(detail_rows)}",
        "",
        "## Component Status",
        "",
        "| Mode | Component | PASS | DEBUG | Mean aggregate delta | Max aggregate delta | Mean bucket delta | Max bucket delta |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for (mode, component), rows in sorted(by_mode_component.items()):
        pass_count = sum(1 for row in rows if row["status"] == "PASS")
        debug_count = sum(1 for row in rows if row["status"] == "DEBUG")
        agg = [float(row["aggregate_delta"]) for row in rows]
        bucket = [float(row["bucket_abs_delta"]) for row in rows]
        lines.append(
            f"| {mode} | {component} | {pass_count} | {debug_count} | "
            f"{(sum(agg) / max(len(agg), 1)):.6g} | {max(agg, default=0.0):.6g} | "
            f"{(sum(bucket) / max(len(bucket), 1)):.6g} | {max(bucket, default=0.0):.6g} |"
        )
    lines.extend(["", "## First Mismatches", ""])
    for row in summary_rows:
        if row["status"] == "PASS":
            continue
        lines.append(
            f"- `{row['run_tag']}` `{row['mode']}` `{row['component']}`: "
            f"first={row['first_mismatch']} rtl={row['rtl_hits']} tlm={row['tlm_hits']} "
            f"agg_delta={row['aggregate_delta']} bucket_delta={row['bucket_abs_delta']}"
        )
    lines.extend(["", "## Run Metadata", ""])
    for run in run_summaries:
        cfg = run["config"]
        normal = run.get("normal", {})
        forced = run.get("forced_ingress", {})
        lines.append(
            f"- `{run['run_tag']}`: frames={cfg['frame_count']} rho_ppm={cfg['rho_ppm']} "
            f"burst_milli={cfg['burstiness_milli']} seed=0x{cfg['rng_seed']:08x} "
            f"normal_events={normal.get('trace_events', 0)} forced_events={forced.get('trace_events', 0)}"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-root", type=Path, default=DEFAULT_LOG_ROOT)
    parser.add_argument("--log", type=Path, action="append", default=[])
    parser.add_argument("--out-prefix", type=Path, default=DEFAULT_OUT_PREFIX)
    parser.add_argument("--threshold", type=float, default=0.01)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--normal-only", action="store_true")
    args = parser.parse_args()

    logs = list(args.log)
    if not logs:
        logs = sorted(args.log_root.glob("component_*.stdout.log"))
    if args.limit:
        logs = logs[: args.limit]
    if not logs:
        raise SystemExit(f"no logs found under {args.log_root}")

    summary_rows: list[dict[str, object]] = []
    detail_rows: list[dict[str, object]] = []
    run_summaries: list[dict[str, object]] = []
    for log_path in logs:
        run_tag = log_path.name.removesuffix(".stdout.log")
        print(f"[SUBFRAME] parse {run_tag}", flush=True)
        rtl = parse_log(log_path, run_tag)
        cfg = cfg_from_log(run_tag, rtl)
        lane_frames_override = None
        ingress_stats = {}
        if rtl.ingress:
            lane_frames_override, ingress_stats = lane_frames_from_rtl_ingress(rtl, cfg)
        run_summary = {
            "run_tag": run_tag,
            "log": str(log_path),
            "config": asdict(cfg),
            "ingress_stats": ingress_stats,
            "rtl_counts": {
                "ingress_rows": len(rtl.ingress),
                "predrops": len(rtl.predrops),
                "postdrops": len(rtl.postdrops),
                "pa_actions": len(rtl.pa_actions),
                "txn_deliver": len(rtl.txn_events.get("deliver", [])),
            },
        }
        run_summary["normal"] = run_mode(
            run_tag=run_tag,
            rtl=rtl,
            cfg=cfg,
            mode="normal",
            lane_frames_override=lane_frames_override,
            threshold=args.threshold,
            summary_rows=summary_rows,
            detail_rows=detail_rows,
        )
        if not args.normal_only:
            run_summary["forced_ingress"] = run_mode(
                run_tag=run_tag,
                rtl=rtl,
                cfg=cfg,
                mode="forced_ingress",
                lane_frames_override=lane_frames_override,
                threshold=args.threshold,
                summary_rows=summary_rows,
                detail_rows=detail_rows,
            )
        run_summaries.append(run_summary)
        counts = status_counts([row for row in summary_rows if row["run_tag"] == run_tag])
        print(f"[SUBFRAME_DONE] {run_tag} {counts}", flush=True)

    write_csv(args.out_prefix.with_suffix(".csv"), summary_rows)
    write_csv(args.out_prefix.with_name(args.out_prefix.name + "_detail").with_suffix(".csv"), detail_rows)
    args.out_prefix.with_name(args.out_prefix.name + "_summary").with_suffix(".json").write_text(
        json.dumps(run_summaries, indent=2) + "\n",
        encoding="ascii",
    )
    write_report(args.out_prefix.with_name(args.out_prefix.name + "_report").with_suffix(".md"), summary_rows, detail_rows, run_summaries)
    print(f"[DONE] {args.out_prefix.with_suffix('.csv')}", flush=True)
    print(f"[DONE] {args.out_prefix.with_name(args.out_prefix.name + '_detail').with_suffix('.csv')}", flush=True)
    print(f"[DONE] {args.out_prefix.with_name(args.out_prefix.name + '_report').with_suffix('.md')}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

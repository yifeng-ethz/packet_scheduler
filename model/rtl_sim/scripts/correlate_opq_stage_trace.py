#!/usr/bin/env python3
"""Correlate OPQ RTL boundary traces with structural TLM stage traces.

The reducer is intentionally local-stage oriented. It does not try to close an
end-to-end loss curve; it identifies the first controlled RTL drop and compares
the nearby ingress, page-allocator, handle, and credit-return evidence against
the same generated TLM traffic.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[4]
PKT_ROOT = REPO_ROOT / "packet_scheduler"
TLM_SCRIPTS = PKT_ROOT / "model" / "tlm" / "scripts"
if str(TLM_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(TLM_SCRIPTS))

from opq_structural_tlm import (  # noqa: E402
    OpqStructuralTlm,
    configs_from_rtl_rows,
    read_csv,
)


DEFAULT_DETAIL = PKT_ROOT / "model" / "rtl_sim" / "data" / "RTL-LS-002_marginal_loss_zoom_f100_detail.csv"
DEFAULT_OUT_DIR = PKT_ROOT / "model" / "rtl_sim" / "data" / "stage_trace"

DROP_RE = re.compile(
    r"\[opq_drop_evt\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"credit\(lane=(?P<lane_credit>\d+)\s+ticket=(?P<ticket_credit>\d+)\).*?"
    r"pre\(shd=(?P<pre_shd>\d+)\s+hit=(?P<pre_hit>\d+)\).*?"
    r"exact_pre\(valid=(?P<valid>\d+)\s+serial=(?P<serial>\d+)\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+shd=(?P<shd>\d+)\s+hit=(?P<hit>\d+)\)"
)
POST_DROP_RE = re.compile(
    r"\[opq_drop_evt\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"credit\(lane=(?P<lane_credit>\d+)\s+ticket=(?P<ticket_credit>\d+)\).*?"
    r"post\(hdr=(?P<post_hdr>\d+)\s+shd=(?P<post_shd>\d+)\s+hit=(?P<hit_count>[1-9]\d*)\).*?"
    r"exact_post\(valid=(?P<valid>\d+)\s+serial=(?P<serial>\d+)\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+shd=(?P<shd>\d+)\s+hit=(?P<hit>\d+)\)"
)
PA_DECISION_RE = re.compile(r"\[opq_pa_decision\]\s+t=(?P<time_ps>\d+)\s+(?P<decision>\S+)\s*(?P<blob>.*)")
PA_LANE_RE = re.compile(
    r"\[opq_pa_lane_action\]\s+t=(?P<time_ps>\d+)\s+lane=(?P<lane>\d+)\s+(?P<blob>.*)"
)
HANDLE_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+handle_accept\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+src=0x(?P<src>[0-9a-fA-F]+)\s+"
    r"dst=0x(?P<dst>[0-9a-fA-F]+)\s+len=(?P<hit_count>\d+)\s+"
    r"handle_wptr=0x(?P<handle_wptr>[0-9a-fA-F]+)\s+ticket_rptr=0x(?P<ticket_rptr>[0-9a-fA-F]+)\s+"
    r"page_len_next=(?P<page_len_next>\d+)"
)
CREDIT_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"(?P<kind>mover_done|credit_return|late_credit_return|mover_abort)\s+"
    r"(?:credit_return=|amount=)(?P<hit_count>\d+)\s+"
    r"(?:next_handle_rptr|handle_rptr|ticket_rptr)=0x(?P<ptr>[0-9a-fA-F]+)"
)
PARSER_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+parser_ticket_we\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+lane_start=0x(?P<lane_start>[0-9a-fA-F]+)\s+"
    r"len=(?P<hit_count>\d+)\s+sop=(?P<sop>\d+)\s+eop=(?P<eop>\d+)\s+"
    r"next_ticket_wptr=0x(?P<next_ticket_wptr>[0-9a-fA-F]+)"
)
RESULT_RE = re.compile(r"MODEL_PUBLISH_RESULT\s+(?P<blob>.*)")
AGG_RE = re.compile(r"MODEL_PUBLISH_AGG\s+(?P<blob>.*)")


def parse_int(value: str) -> int:
    if value.lower().startswith("0x"):
        return int(value, 16)
    try:
        return int(value)
    except ValueError:
        return int(value, 16)


def parse_kv_blob(blob: str) -> dict[str, object]:
    fields: dict[str, object] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        value = value.rstrip(",")
        try:
            fields[key] = parse_int(value)
        except ValueError:
            fields[key] = value
    return fields


def normalize_row(row: dict[str, object]) -> dict[str, object]:
    out = dict(row)
    if "timestamp" in out and isinstance(out["timestamp"], str):
        out["timestamp"] = int(out["timestamp"], 16)
    for key in (
        "time_ps",
        "lane",
        "lane_credit",
        "ticket_credit",
        "pre_shd",
        "pre_hit",
        "post_hdr",
        "post_shd",
        "valid",
        "serial",
        "shd",
        "hit",
        "hit_count",
        "src",
        "dst",
        "handle_wptr",
        "ticket_rptr",
        "page_len_next",
        "ptr",
        "lane_start",
        "next_ticket_wptr",
        "sop",
        "eop",
    ):
        if key in out and isinstance(out[key], str):
            out[key] = parse_int(out[key])
    return out


def rtl_first_drop(log_path: Path) -> dict[str, object] | None:
    with log_path.open(errors="replace") as handle:
        for line_no, line in enumerate(handle, 1):
            match = DROP_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                row.update({"source": "rtl", "stage": "controlled_ingress_predrop", "line": line_no})
                return row
    return None


def rtl_first_post_drop(log_path: Path) -> dict[str, object] | None:
    with log_path.open(errors="replace") as handle:
        for line_no, line in enumerate(handle, 1):
            match = POST_DROP_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                row.update({"source": "rtl", "stage": "controlled_allocator_postdrop", "line": line_no})
                return row
    return None


def add_loss(loss_map: dict[str, int], *, serial: int, lane: int, stage: str, hits: int) -> None:
    key = f"s{serial:04d}.l{lane}.{stage}"
    loss_map[key] = loss_map.get(key, 0) + hits


def rtl_loss_map(log_path: Path) -> dict[str, int]:
    losses: dict[str, int] = {}
    with log_path.open(errors="replace") as handle:
        for line in handle:
            match = DROP_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                add_loss(
                    losses,
                    serial=int(row["serial"]),
                    lane=int(row["lane"]),
                    stage="pre",
                    hits=int(row["pre_hit"]),
                )
            match = POST_DROP_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                add_loss(
                    losses,
                    serial=int(row["serial"]),
                    lane=int(row["lane"]),
                    stage="post",
                    hits=int(row["hit_count"]),
                )
    return losses


def parse_rtl_rows(log_path: Path, start_ps: int, end_ps: int) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with log_path.open(errors="replace") as handle:
        for line_no, line in enumerate(handle, 1):
            for regex, stage in (
                (DROP_RE, "controlled_ingress_predrop"),
                (POST_DROP_RE, "controlled_allocator_postdrop"),
                (PA_DECISION_RE, "allocator_decision"),
                (PA_LANE_RE, "allocator_lane_action"),
                (HANDLE_RE, "handle_accept"),
                (CREDIT_RE, "credit_return"),
                (PARSER_RE, "parser_ticket_we"),
            ):
                match = regex.search(line)
                if not match:
                    continue
                row = normalize_row(match.groupdict())
                time_ps = int(row["time_ps"])
                if time_ps < start_ps or time_ps > end_ps:
                    break
                row.update({"source": "rtl", "stage": stage, "line": line_no})
                if "blob" in row:
                    blob = str(row.pop("blob"))
                    row.update(parse_kv_blob(blob))
                rows.append(row)
                break
    rows.sort(key=lambda item: (int(item.get("time_ps", 0)), int(item.get("line", 0))))
    return rows


def rtl_prefix_counts(log_path: Path, first_drop: dict[str, object]) -> dict[str, object]:
    lane = int(first_drop["lane"])
    first_drop_time = int(first_drop["time_ps"])
    handle_accept_hits = 0
    credit_return_hits = 0
    predrop_hits = 0
    drop_events = 0
    with log_path.open(errors="replace") as handle:
        for line in handle:
            time_match = re.search(r"t=(\d+)", line)
            if time_match and int(time_match.group(1)) > first_drop_time:
                break
            match = HANDLE_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                if int(row["lane"]) == lane:
                    handle_accept_hits += int(row["hit_count"])
                continue
            match = CREDIT_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                if int(row["lane"]) == lane and str(row["kind"]) in {"credit_return", "mover_done"}:
                    if str(row["kind"]) == "credit_return":
                        hit_count = int(row["hit_count"])
                        time_ps = int(row["time_ps"])
                        if not (time_ps < 100_000 and hit_count >= 1024):
                            credit_return_hits += hit_count
                continue
            match = DROP_RE.search(line)
            if match:
                row = normalize_row(match.groupdict())
                if int(row["lane"]) == lane:
                    predrop_hits += int(row["pre_hit"])
                    drop_events += 1
    initial_credit = 2046
    inferred_ingress_accept_prefix = initial_credit + credit_return_hits - int(first_drop["lane_credit"])
    return {
        "lane": lane,
        "initial_lane_credit_assumed": initial_credit,
        "handle_accept_hits_to_first_drop": handle_accept_hits,
        "credit_return_hits_to_first_drop": credit_return_hits,
        "controlled_predrop_hits_to_first_drop": predrop_hits,
        "controlled_drop_events_to_first_drop": drop_events,
        "inferred_ingress_accept_hits_before_first_drop": inferred_ingress_accept_prefix,
    }


def parse_publish_rows(log_path: Path) -> tuple[list[dict[str, object]], dict[str, object] | None]:
    result_rows: list[dict[str, object]] = []
    agg_row: dict[str, object] | None = None
    with log_path.open(errors="replace") as handle:
        for line in handle:
            match = RESULT_RE.search(line)
            if match:
                result_rows.append(parse_kv_blob(match.group("blob")))
                continue
            match = AGG_RE.search(line)
            if match:
                agg_row = parse_kv_blob(match.group("blob"))
    return result_rows, agg_row


def run_tlm_trace(detail_csv: Path, run_tag: str) -> tuple[list[dict[str, object]], dict[str, object]]:
    rows = [row for row in read_csv(detail_csv) if row.get("run_tag") == run_tag]
    if not rows:
        raise SystemExit(f"run_tag {run_tag!r} not found in {detail_csv}")
    cfgs = configs_from_rtl_rows(rows)
    if len(cfgs) != 1:
        raise SystemExit(f"expected one config for {run_tag}, found {len(cfgs)}")
    cfg = cfgs[0]
    trace: list[dict[str, object]] = []
    tlm = OpqStructuralTlm(
        cfg,
        lane_fifo_depth=cfg.lane_fifo_depth,
        ticket_fifo_depth=cfg.ticket_fifo_depth,
        page_ram_depth=cfg.page_ram_depth,
        trace_events=trace,
    )
    stats = tlm.run()
    summary = {
        "tlm_offered_hits": stats.offered_hits,
        "tlm_accepted_hits": stats.accepted_hits,
        "tlm_dropped_hits": stats.dropped_hits,
        "tlm_predrop_hits": stats.predrop_hits,
        "tlm_postdrop_hits": stats.postdrop_hits,
        "tlm_delivered_hits": stats.delivered_hits,
        "tlm_max_lane_fifo_used": stats.max_lane_fifo_used,
        "tlm_max_ticket_fifo_used": stats.max_ticket_fifo_used,
        "tlm_max_handle_fifo_used": stats.max_handle_fifo_used,
        "tlm_max_cycle": stats.max_cycle,
    }
    return trace, summary


def tlm_loss_map(trace: list[dict[str, object]]) -> dict[str, int]:
    losses: dict[str, int] = {}
    for row in trace:
        stage = str(row.get("stage", ""))
        if stage == "ingress_predrop":
            add_loss(
                losses,
                serial=int(row["serial"]),
                lane=int(row["lane"]),
                stage="pre",
                hits=int(row.get("hit_count", 0)),
            )
        elif stage == "allocator_postdrop":
            add_loss(
                losses,
                serial=int(row["serial"]),
                lane=int(row["lane"]),
                stage="post",
                hits=int(row.get("hit_count", 0)),
            )
    return losses


def loss_stage_deltas(
    rtl_losses: dict[str, int],
    tlm_losses: dict[str, int],
    *,
    center_serial: int,
    window: int = 6,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for serial in range(max(0, center_serial - window), center_serial + window + 1):
        for lane in range(4):
            row = {"serial": serial, "lane": lane}
            nonzero = False
            for stage in ("pre", "post"):
                key = f"s{serial:04d}.l{lane}.{stage}"
                rtl_value = rtl_losses.get(key, 0)
                tlm_value = tlm_losses.get(key, 0)
                row[f"rtl_{stage}"] = rtl_value
                row[f"tlm_{stage}"] = tlm_value
                row[f"delta_{stage}"] = tlm_value - rtl_value
                nonzero = nonzero or rtl_value != 0 or tlm_value != 0
            if nonzero:
                rows.append(row)
    return rows


def filter_rows(rows: Iterable[dict[str, object]], start_ps: int, end_ps: int) -> list[dict[str, object]]:
    out = [
        row
        for row in rows
        if start_ps <= int(row.get("time_ps", row.get("cycle", 0))) <= end_ps
    ]
    out.sort(key=lambda item: (int(item.get("time_ps", 0)), str(item.get("source", "")), str(item.get("stage", ""))))
    return out


def last_before(rows: list[dict[str, object]], time_ps: int, stage: str, lane: int | None = None) -> dict[str, object] | None:
    selected = [
        row
        for row in rows
        if str(row.get("stage")) == stage
        and int(row.get("time_ps", 0)) <= time_ps
        and (lane is None or int(row.get("lane", -1)) == lane)
    ]
    return selected[-1] if selected else None


def first_matching_tlm(
    rows: list[dict[str, object]],
    *,
    lane: int,
    serial: int,
    timestamp: int,
) -> dict[str, object] | None:
    for row in rows:
        if str(row.get("source")) != "tlm":
            continue
        if str(row.get("stage")) not in {"ingress_preaccept", "ingress_predrop"}:
            continue
        if int(row.get("lane", -1)) != lane:
            continue
        if int(row.get("serial", -1)) != serial:
            continue
        if int(row.get("timestamp", -1)) != timestamp:
            continue
        return row
    return None


def tlm_prefix_counts(
    rows: list[dict[str, object]],
    match_row: dict[str, object] | None,
    *,
    lane: int,
) -> dict[str, object]:
    if match_row is None:
        return {"lane": lane, "matched": 0}
    match_time = int(match_row["time_ps"])
    accepted = 0
    credit_return = 0
    handle_accept = 0
    for row in rows:
        if int(row.get("time_ps", 0)) >= match_time:
            continue
        if int(row.get("lane", -1)) != lane:
            continue
        stage = str(row.get("stage", ""))
        if stage == "ticket_enqueue" and str(row.get("kind", "")) == "body":
            accepted += int(row.get("hit_count", 0))
        elif stage == "credit_return":
            credit_return += int(row.get("hit_count", 0))
        elif stage == "handle_accept":
            handle_accept += int(row.get("hit_count", 0))
    initial_credit = 2046
    inferred_credit = initial_credit + credit_return - accepted
    return {
        "lane": lane,
        "matched": 1,
        "initial_lane_credit_assumed": initial_credit,
        "accepted_ingress_hits_before_matched_txn": accepted,
        "handle_accept_hits_before_matched_txn": handle_accept,
        "credit_return_hits_before_matched_txn": credit_return,
        "credit_from_prefix_arithmetic": inferred_credit,
    }


def sum_lane_hits(rows: list[dict[str, object]], source: str, stage: str, lane: int) -> int:
    total = 0
    for row in rows:
        if str(row.get("source")) != source or str(row.get("stage")) != stage:
            continue
        if int(row.get("lane", -1)) != lane:
            continue
        total += int(row.get("hit_count", 0))
    return total


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def compact(row: dict[str, object] | None) -> dict[str, object] | None:
    if row is None:
        return None
    keep = [
        "source",
        "stage",
        "line",
        "time_ps",
        "cycle",
        "lane",
        "serial",
        "timestamp",
        "hit_count",
        "lane_credit",
        "ticket_credit",
        "lane_credit_before",
        "lane_credit_after",
        "ticket_credit_before",
        "ticket_credit_after",
        "running_ts",
        "decision",
        "action",
        "masked",
        "credit",
        "fetch_ts",
        "block_len",
        "tail_ready",
        "tail_dropped",
        "handle_depth",
        "page_len_next",
    ]
    return {key: row[key] for key in keep if key in row}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-tag", required=True)
    parser.add_argument("--rtl-log", type=Path, required=True)
    parser.add_argument("--detail-csv", type=Path, default=DEFAULT_DETAIL)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--pre-window-ps", type=int, default=5_000_000)
    parser.add_argument("--post-window-ps", type=int, default=1_000_000)
    args = parser.parse_args()

    first_drop = rtl_first_drop(args.rtl_log)
    if first_drop is None:
        result_rows, agg_row = parse_publish_rows(args.rtl_log)
        print(f"[INFO] {args.run_tag}: no RTL drop event in {args.rtl_log}")
        summary = {
            "run_tag": args.run_tag,
            "rtl_first_drop": None,
            "rtl_result_rows": result_rows,
            "rtl_agg": agg_row,
            "status": "NO_DROP_TRACE",
        }
        args.out_dir.mkdir(parents=True, exist_ok=True)
        summary_path = args.out_dir / f"{args.run_tag}_stage_summary.json"
        summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
        print(f"[DONE] wrote {summary_path}")
        return 0

    first_drop_time = int(first_drop["time_ps"])
    first_post_drop = rtl_first_post_drop(args.rtl_log)
    start_ps = max(0, first_drop_time - args.pre_window_ps)
    end_ps = first_drop_time + args.post_window_ps
    rtl_rows = parse_rtl_rows(args.rtl_log, start_ps, end_ps)
    tlm_trace, tlm_summary = run_tlm_trace(args.detail_csv, args.run_tag)
    rtl_losses = rtl_loss_map(args.rtl_log)
    tlm_losses = tlm_loss_map(tlm_trace)
    tlm_rows = filter_rows(tlm_trace, start_ps, end_ps)
    all_rows = sorted(
        rtl_rows + tlm_rows,
        key=lambda row: (int(row.get("time_ps", 0)), str(row.get("source", "")), str(row.get("stage", ""))),
    )

    lane = int(first_drop["lane"])
    serial = int(first_drop["serial"])
    timestamp = int(first_drop["timestamp"])
    result_rows, agg_row = parse_publish_rows(args.rtl_log)
    match_row = first_matching_tlm(tlm_trace, lane=lane, serial=serial, timestamp=timestamp)
    summary = {
        "run_tag": args.run_tag,
        "window_ps": {"start": start_ps, "end": end_ps},
        "status": "DEBUG",
        "mismatch_stage": "allocator_tail_late_drop" if first_post_drop is not None else "ingress_credit_precheck",
        "rtl_first_drop": compact(first_drop),
        "rtl_first_post_drop": compact(first_post_drop),
        "tlm_same_transaction": compact(match_row),
        "rtl_last_allocator_decision_before_drop": compact(last_before(rtl_rows, first_drop_time, "allocator_decision")),
        "rtl_last_allocator_lane_action_before_drop": compact(last_before(rtl_rows, first_drop_time, "allocator_lane_action", lane)),
        "rtl_last_handle_accept_before_drop": compact(last_before(rtl_rows, first_drop_time, "handle_accept", lane)),
        "rtl_last_credit_return_before_drop": compact(last_before(rtl_rows, first_drop_time, "credit_return", lane)),
        "tlm_last_allocator_fetch_before_drop": compact(last_before(tlm_trace, first_drop_time, "allocator_fetch")),
        "tlm_last_handle_accept_before_drop": compact(last_before(tlm_trace, first_drop_time, "handle_accept", lane)),
        "tlm_last_credit_return_before_drop": compact(last_before(tlm_trace, first_drop_time, "credit_return", lane)),
        "rtl_prefix_to_first_drop": rtl_prefix_counts(args.rtl_log, first_drop),
        "tlm_prefix_to_same_transaction": tlm_prefix_counts(tlm_trace, match_row, lane=lane),
        "rtl_window_handle_accept_hits_lane": sum_lane_hits(rtl_rows, "rtl", "handle_accept", lane),
        "rtl_window_credit_return_hits_lane": sum_lane_hits(rtl_rows, "rtl", "credit_return", lane),
        "tlm_window_handle_accept_hits_lane": sum_lane_hits(tlm_rows, "tlm", "handle_accept", lane),
        "tlm_window_credit_return_hits_lane": sum_lane_hits(tlm_rows, "tlm", "credit_return", lane),
        "loss_stage_deltas_near_first_post": loss_stage_deltas(
            rtl_losses,
            tlm_losses,
            center_serial=int(first_post_drop["serial"]) if first_post_drop is not None else serial,
        ),
        "rtl_loss_map": rtl_losses,
        "tlm_loss_map": tlm_losses,
        "tlm_summary": tlm_summary,
        "rtl_result_rows": result_rows,
        "rtl_agg": agg_row,
    }

    args.out_dir.mkdir(parents=True, exist_ok=True)
    stage_csv = args.out_dir / f"{args.run_tag}_stage_window.csv"
    summary_json = args.out_dir / f"{args.run_tag}_stage_summary.json"
    write_csv(stage_csv, all_rows)
    summary_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")

    tlm_credit = "-"
    if match_row is not None:
        tlm_credit = str(match_row.get("lane_credit_before", "-"))
    print(
        "[CORRELATE] {tag}: first RTL drop lane={lane} serial={serial} "
        "ts=0x{ts:x} rtl_credit={rtl_credit} tlm_same_txn_credit={tlm_credit}".format(
            tag=args.run_tag,
            lane=lane,
            serial=serial,
            ts=timestamp,
            rtl_credit=first_drop.get("lane_credit", "-"),
            tlm_credit=tlm_credit,
        )
    )
    print(f"[DONE] wrote {stage_csv}")
    print(f"[DONE] wrote {summary_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Replay OPQ RTL component evidence against the structural TLM.

The reducer is intentionally component-oriented. It consumes RTL/UVM logs as
truth, rebuilds the same traffic in the structural TLM, and reports which
local component boundary diverges first:

* ingress lane/ticket credit at raw subheader tickets;
* controlled pre/post drop classification;
* page-allocator to handle FIFO grants;
* frame-table hit ledger;
* optional OPQ_TXN delivered bucket/order checks.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
PKT_ROOT = REPO_ROOT / "packet_scheduler"
RTL_DATA = PKT_ROOT / "model" / "rtl_sim" / "data"
TLM_SCRIPTS = PKT_ROOT / "model" / "tlm" / "scripts"
if str(TLM_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(TLM_SCRIPTS))

from opq_structural_tlm import (  # noqa: E402
    OPQ_SUBHEADER_DURATION_TS_TICKS,
    OPQ_UVM_CLK_PERIOD_NS,
    CaseConfig,
    OpqStructuralTlm,
    ParserTicketEvent,
    configs_from_rtl_rows,
)


DEFAULT_CSV = RTL_DATA / "opq_component_replay.csv"
DEFAULT_JSON = RTL_DATA / "opq_component_replay_summary.json"

MODEL_RE = re.compile(r"MODEL_PUBLISH_(?P<kind>RESULT|AGG)\s+(?P<blob>.*)")
ING_CREDIT_RE = re.compile(
    r"\[opq_ing_credit\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"pkg=(?P<pkg_cnt>\d+)\s+running_ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+"
    r"data=0x(?P<data>[0-9a-fA-F]+)\s+hit_decl=(?P<hit_count>\d+)\s+"
    r"lane_credit=(?P<lane_credit>\d+)\s+ticket_credit=(?P<ticket_credit>\d+)\s+"
    r"drop_valid=(?P<drop_valid>\d+)\s+drop_lane=(?P<drop_lane>\d+)\s+"
    r"drop_ticket=(?P<drop_ticket>\d+)"
)
DROP_RE = re.compile(
    r"\[opq_drop_evt\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"credit\(lane=(?P<lane_credit>\d+)\s+ticket=(?P<ticket_credit>\d+)\).*?"
    r"pre\(shd=(?P<pre_shd>\d+)\s+hit=(?P<hit_count>[1-9]\d*)\).*?"
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
HANDLE_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+handle_we\s+"
    r"flag=(?P<flag>\d+)\s+src=0x(?P<src>[0-9a-fA-F]+)\s+"
    r"dst=0x(?P<dst>[0-9a-fA-F]+)\s+len=(?P<hit_count>\d+)\s+"
    r"handle_wptr=0x(?P<handle_wptr>[0-9a-fA-F]+)\s+ticket_rptr=0x(?P<ticket_rptr>[0-9a-fA-F]+)"
)
HANDLE_ACCEPT_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+handle_accept\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+src=0x(?P<src>[0-9a-fA-F]+)\s+"
    r"dst=0x(?P<dst>[0-9a-fA-F]+)\s+len=(?P<hit_count>\d+)\s+"
    r"handle_wptr=0x(?P<handle_wptr>[0-9a-fA-F]+)\s+ticket_rptr=0x(?P<ticket_rptr>[0-9a-fA-F]+)"
)
CREDIT_RETURN_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"(?P<kind>credit_return|late_credit_return)\s+amount=(?P<hit_count>\d+)\s+"
    r"(?P<ptr_name>handle_rptr|ticket_rptr)=0x(?P<ptr>[0-9a-fA-F]+)"
)
MOVER_DONE_RE = re.compile(
    r"\[opq_boundary\]\s+t=(?P<time_ps>\d+)\s+lane(?P<lane>\d+)\s+"
    r"mover_done\s+credit_return=(?P<hit_count>\d+)\s+"
    r"next_handle_rptr=0x(?P<ptr>[0-9a-fA-F]+)"
)
PA_ACTION_RE = re.compile(
    r"\[opq_pa_lane_action\]\s+t=(?P<time_ps>\d+)\s+lane=(?P<lane>\d+)\s+"
    r"action=(?P<action>\d+)\s+masked=(?P<masked>\d+)\s+credit=(?P<credit>\d+).*?"
    r"fetch_ts=0x(?P<fetch_ts>[0-9a-fA-F]+)\s+block_len=(?P<block_len>\d+)\s+"
    r"body_serial=0x(?P<body_serial>[0-9a-fA-F]+)\s+sop=(?P<sop>\d+)\s+eop=(?P<eop>\d+)\s+"
    r"tail_ready=(?P<tail_ready>\d+)\s+tail_dropped=(?P<tail_dropped>\d+)"
)
PA_TICKET_RE = re.compile(
    r"\[opq_pa_ticket\]\s+t=(?P<time_ps>\d+)\s+lane=(?P<lane>\d+)\s+"
    r"running_ts=0x(?P<running_ts>[0-9a-fA-F]+)\s+raw=0x(?P<raw>[0-9a-fA-F]+)\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+body_serial=0x(?P<body_serial>[0-9a-fA-F]+)\s+"
    r"sop_serial=0x(?P<sop_serial>[0-9a-fA-F]+)\s+sop=(?P<sop>\d+)\s+eop=(?P<eop>\d+)\s+"
    r"rptr=0x(?P<rptr>[0-9a-fA-F]+)\s+wptr=0x(?P<wptr>[0-9a-fA-F]+)\s+"
    r"q_valid=(?P<q_valid>\d+)\s+future=(?P<future>\d+)\s+past=(?P<past>\d+)"
)
PARSER_TICKET_LANE_RE = re.compile(
    r"\[opq_boundary_lane\]\s+t=(?P<time_ps>\d+)\s+parser_ticket_we\s+"
    r"lane=(?P<lane>\d+)\s+pkg=(?P<pkg_cnt>\d+)\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+lane_start=0x(?P<lane_start>[0-9a-fA-F]+)\s+"
    r"len=(?P<hit_count>\d+)\s+sop=(?P<sop>\d+)\s+eop=(?P<eop>\d+)"
)
PARSER_TAIL_LANE_RE = re.compile(
    r"\[opq_boundary_lane\]\s+t=(?P<time_ps>\d+)\s+parser_tail\s+"
    r"lane=(?P<lane>\d+)\s+pkg=(?P<pkg_cnt>\d+)\s+"
    r"ts=0x(?P<timestamp>[0-9a-fA-F]+)\s+drop=(?P<drop>\d+)"
)
PA_STATE_RE = re.compile(
    r"\[opq_pa\]\s+t=(?P<time_ps>\d+)\s+state=(?P<state>\d+)\s+"
    r"all_fetch=(?P<all_fetch>\d+)\s+any_pending=(?P<any_pending>\d+).*?"
    r"frame_wait=(?P<frame_wait>\d+)\s+active_wait=(?P<active_wait>\d+)\s+"
    r"frame_lane_active=0x(?P<frame_lane_active>[0-9a-fA-F]+).*?"
    r"ingress_busy=0x(?P<ingress_busy>[0-9a-fA-F]+)\s+"
    r"pending=0x(?P<pending>[0-9a-fA-F]+).*?"
    r"q_valid=0x(?P<q_valid>[0-9a-fA-F]+)\s+"
    r"tk_sop=0x(?P<tk_sop>[0-9a-fA-F]+)\s+tk_curr=0x(?P<tk_curr>[0-9a-fA-F]+)\s+"
    r"tk_future=0x(?P<tk_future>[0-9a-fA-F]+)\s+tk_past=0x(?P<tk_past>[0-9a-fA-F]+)"
)
FT_LEDGER_RE = re.compile(
    r"frame_table_ledger\s+wr_hdr=(?P<wr_hdr>\d+)\s+rd_hdr=(?P<rd_hdr>\d+)\s+"
    r"drop_hdr=(?P<drop_hdr>\d+)\s+wr_shd=(?P<wr_shd>\d+)\s+rd_shd=(?P<rd_shd>\d+)\s+"
    r"drop_shd=(?P<drop_shd>\d+)\s+wr_hit=(?P<wr_hit>\d+)\s+rd_hit=(?P<rd_hit>\d+)\s+"
    r"drop_hit=(?P<drop_hit>\d+)"
)
TXN_RE = re.compile(r"OPQ_TXN\s+(?P<blob>.*)")
UVM_ERROR_RE = re.compile(r"# UVM_ERROR\s+:\s+(?P<count>\d+)")
UVM_FATAL_RE = re.compile(r"# UVM_FATAL\s+:\s+(?P<count>\d+)")

HEX_MATCH_FIELDS = {
    "timestamp",
    "data",
    "src",
    "dst",
    "handle_wptr",
    "ticket_rptr",
    "ptr",
    "frame_lane_active",
    "ingress_busy",
    "pending",
    "q_valid",
    "tk_sop",
    "tk_curr",
    "tk_future",
    "tk_past",
    "fetch_ts",
    "body_serial",
    "sop_serial",
    "running_ts",
    "raw",
    "rptr",
    "wptr",
    "lane_start",
}


@dataclass
class RtlLog:
    result_rows: list[dict[str, str]]
    agg_rows: list[dict[str, str]]
    ingress: list[dict[str, int]]
    predrops: list[dict[str, int]]
    postdrops: list[dict[str, int]]
    handles: list[dict[str, int]]
    credit_returns: list[dict[str, int]]
    pa_actions: list[dict[str, int]]
    pa_tickets: list[dict[str, int]]
    parser_tickets: list[dict[str, int]]
    parser_tails: list[dict[str, int]]
    pa_states: list[dict[str, int]]
    ft_ledgers: list[dict[str, int]]
    txn_events: dict[str, list[dict[str, str]]]
    invalid_predrop_hits: int
    invalid_postdrop_hits: int
    uvm_clean: bool


def parse_int(value: str) -> int:
    value = str(value).strip()
    if value.lower().startswith("0x"):
        return int(value, 16)
    if any(ch in value.lower() for ch in "abcdef"):
        return int(value, 16)
    return int(value)


def parse_blob(blob: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        out[key] = value.rstrip(",")
    return out


def match_to_ints(match: re.Match[str]) -> dict[str, int]:
    out: dict[str, int] = {}
    for key, value in match.groupdict().items():
        if key in {"kind", "ptr_name"}:
            continue
        out[key] = int(value, 16) if key in HEX_MATCH_FIELDS else parse_int(value)
    return out


def parse_log(path: Path, run_tag: str) -> RtlLog:
    text = path.read_text(errors="replace")
    result_rows: list[dict[str, str]] = []
    agg_rows: list[dict[str, str]] = []
    ingress: list[dict[str, int]] = []
    predrops: list[dict[str, int]] = []
    postdrops: list[dict[str, int]] = []
    handles: list[dict[str, int]] = []
    credit_returns: list[dict[str, int]] = []
    pa_actions: list[dict[str, int]] = []
    pa_tickets: list[dict[str, int]] = []
    parser_tickets: list[dict[str, int]] = []
    parser_tails: list[dict[str, int]] = []
    pa_states: list[dict[str, int]] = []
    ft_ledgers: list[dict[str, int]] = []
    txn_events: dict[str, list[dict[str, str]]] = defaultdict(list)
    invalid_predrop_hits = 0
    invalid_postdrop_hits = 0
    uvm_clean = True

    for match in UVM_ERROR_RE.finditer(text):
        uvm_clean = uvm_clean and int(match.group("count")) == 0
    for match in UVM_FATAL_RE.finditer(text):
        uvm_clean = uvm_clean and int(match.group("count")) == 0

    for line in text.splitlines():
        model_match = MODEL_RE.search(line)
        if model_match:
            row = parse_blob(model_match.group("blob"))
            row["run_tag"] = run_tag
            if model_match.group("kind") == "RESULT":
                result_rows.append(row)
            else:
                agg_rows.append(row)
            continue

        if match := ING_CREDIT_RE.search(line):
            row = match_to_ints(match)
            row["shd"] = (row["data"] >> 24) & 0xFF
            row["serial"] = row["timestamp"] // max(1, OPQ_SUBHEADER_DURATION_TS_TICKS * 128)
            ingress.append(row)
            continue
        if match := DROP_RE.search(line):
            row = match_to_ints(match)
            if row.get("valid", 0):
                predrops.append(row)
            else:
                invalid_predrop_hits += row.get("hit_count", 0)
            continue
        if match := POST_DROP_RE.search(line):
            row = match_to_ints(match)
            if row.get("valid", 0):
                postdrops.append(row)
            else:
                invalid_postdrop_hits += row.get("hit_count", 0)
            continue
        if match := HANDLE_RE.search(line):
            row = match_to_ints(match)
            row["accept_trace"] = 0
            handles.append(row)
            continue
        if match := HANDLE_ACCEPT_RE.search(line):
            row = match_to_ints(match)
            row["flag"] = 0
            row["accept_trace"] = 1
            handles.append(row)
            continue
        if match := CREDIT_RETURN_RE.search(line):
            row = match_to_ints(match)
            row["is_late"] = 1 if match.group("kind") == "late_credit_return" else 0
            row["is_mover_done"] = 0
            credit_returns.append(row)
            continue
        if match := MOVER_DONE_RE.search(line):
            row = match_to_ints(match)
            row["is_late"] = 0
            row["is_mover_done"] = 1
            credit_returns.append(row)
            continue
        if match := PA_ACTION_RE.search(line):
            pa_actions.append(match_to_ints(match))
            continue
        if match := PA_TICKET_RE.search(line):
            pa_tickets.append(match_to_ints(match))
            continue
        if match := PARSER_TICKET_LANE_RE.search(line):
            parser_tickets.append(match_to_ints(match))
            continue
        if match := PARSER_TAIL_LANE_RE.search(line):
            parser_tails.append(match_to_ints(match))
            continue
        if match := PA_STATE_RE.search(line):
            pa_states.append(match_to_ints(match))
            continue
        if match := FT_LEDGER_RE.search(line):
            ft_ledgers.append(match_to_ints(match))
            continue
        if match := TXN_RE.search(line):
            fields = parse_blob(match.group("blob"))
            event = fields.get("event", "")
            if event:
                txn_events[event].append(fields)

    return RtlLog(
        result_rows=result_rows,
        agg_rows=agg_rows,
        ingress=ingress,
        predrops=predrops,
        postdrops=postdrops,
        handles=handles,
        credit_returns=credit_returns,
        pa_actions=pa_actions,
        pa_tickets=pa_tickets,
        parser_tickets=parser_tickets,
        parser_tails=parser_tails,
        pa_states=pa_states,
        ft_ledgers=ft_ledgers,
        txn_events=dict(txn_events),
        invalid_predrop_hits=invalid_predrop_hits,
        invalid_postdrop_hits=invalid_postdrop_hits,
        uvm_clean=uvm_clean,
    )


def cfg_from_log(run_tag: str, rtl: RtlLog) -> CaseConfig:
    if not rtl.result_rows:
        raise SystemExit(f"{run_tag}: no MODEL_PUBLISH_RESULT rows in RTL log")
    rows = [dict(row) for row in rtl.result_rows]
    for row in rows:
        row["run_tag"] = run_tag
    cfgs = configs_from_rtl_rows(rows)
    if len(cfgs) != 1:
        raise SystemExit(f"{run_tag}: expected one TLM config, got {len(cfgs)}")
    return cfgs[0]


def lane_frames_from_rtl_ingress(rtl: RtlLog, cfg: CaseConfig) -> tuple[list[list[list[int]]], dict[str, int]]:
    lane_frames = [
        [[0 for _ in range(cfg.subheaders_per_frame)] for _ in range(cfg.frame_count)]
        for _ in range(cfg.n_lane)
    ]
    duplicates = 0
    ignored_rows = 0
    ignored_hits = 0
    seen: set[tuple[int, int, int]] = set()
    for row in rtl.ingress:
        lane = row["lane"]
        frame = row["pkg_cnt"]
        shd = row.get("shd", (row["data"] >> 24) & 0xFF)
        hit_count = row["hit_count"]
        if not (0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count and 0 <= shd < cfg.subheaders_per_frame):
            ignored_rows += 1
            ignored_hits += hit_count
            continue
        key = (lane, frame, shd)
        if key in seen:
            duplicates += 1
        seen.add(key)
        lane_frames[lane][frame][shd] += hit_count
    stats = {
        "rtl_ingress_rows": len(rtl.ingress),
        "rtl_ingress_hits": sum(row["hit_count"] for row in rtl.ingress),
        "rtl_ingress_duplicates": duplicates,
        "rtl_ingress_ignored_rows": ignored_rows,
        "rtl_ingress_ignored_hits": ignored_hits,
    }
    return lane_frames, stats


def ingress_decision_override_from_rtl(rtl: RtlLog, cfg: CaseConfig) -> dict[tuple[int, int, int], bool]:
    overrides: dict[tuple[int, int, int], bool] = {}
    for row in rtl.ingress:
        lane = row["lane"]
        frame = row["pkg_cnt"]
        shd = row.get("shd", (row["data"] >> 24) & 0xFF)
        if 0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count and 0 <= shd < cfg.subheaders_per_frame:
            key = (lane, frame, shd)
            # The parser tail state is driven by the raw ingress drop flag, not
            # only by the exact_pre scoreboard rows. Zero-hit ticket-credit
            # drops can still leave the RTL parser masked at trailer time, so a
            # forced-ingress replay must preserve them to reproduce downstream
            # LATE_DROP/tail_dropped behavior.
            if row["drop_valid"]:
                overrides[key] = True
            else:
                overrides.setdefault(key, False)
    for row in rtl.predrops:
        shd = (row["timestamp"] // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        key = (row["lane"], row["serial"], shd)
        if key in overrides:
            overrides[key] = True
    return overrides


def parser_ticket_events_from_rtl(rtl: RtlLog, cfg: CaseConfig) -> tuple[list[ParserTicketEvent], dict[str, int]]:
    events: list[ParserTicketEvent] = []
    ignored_rows = 0
    ignored_hits = 0
    for row in rtl.parser_tickets:
        lane = row["lane"]
        frame = row["pkg_cnt"]
        hit_count = row["hit_count"]
        if not (0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count):
            ignored_rows += 1
            ignored_hits += hit_count
            continue
        events.append(
            ParserTicketEvent(
                cycle=row["time_ps"] // (OPQ_UVM_CLK_PERIOD_NS * 1000),
                lane=lane,
                frame=frame,
                timestamp=row["timestamp"],
                hit_count=hit_count,
                sop=bool(row.get("sop", 0)),
                eop=bool(row.get("eop", 0)),
            )
        )
    stats = {
        "rtl_parser_ticket_rows": len(rtl.parser_tickets),
        "rtl_parser_ticket_body_hits": sum(row["hit_count"] for row in rtl.parser_tickets if not row.get("sop", 0)),
        "rtl_parser_ticket_sop_rows": sum(1 for row in rtl.parser_tickets if row.get("sop", 0)),
        "rtl_parser_ticket_eop_rows": sum(1 for row in rtl.parser_tickets if row.get("eop", 0)),
        "rtl_parser_ticket_ignored_rows": ignored_rows,
        "rtl_parser_ticket_ignored_hits": ignored_hits,
    }
    return events, stats


def tail_dropped_frames_from_rtl_predrops(rtl: RtlLog, cfg: CaseConfig) -> set[tuple[int, int]]:
    frames: set[tuple[int, int]] = set()
    for row in rtl.predrops:
        lane = row["lane"]
        frame = row["serial"]
        if 0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count:
            frames.add((lane, frame))
    return frames


def tail_dropped_frames_from_rtl_postdrops(rtl: RtlLog, cfg: CaseConfig) -> set[tuple[int, int]]:
    frames: set[tuple[int, int]] = set()
    for row in rtl.postdrops:
        lane = row["lane"]
        frame = row["serial"]
        if 0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count:
            frames.add((lane, frame))
    return frames


def tail_dropped_frames_from_rtl_parser_tails(rtl: RtlLog, cfg: CaseConfig) -> set[tuple[int, int]]:
    frames: set[tuple[int, int]] = set()
    for row in rtl.parser_tails:
        if not row.get("drop", 0):
            continue
        lane = row["lane"]
        frame = row["pkg_cnt"]
        if 0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count:
            frames.add((lane, frame))
    return frames


def tail_dropped_frames_from_rtl_pa_late_actions(rtl: RtlLog, cfg: CaseConfig) -> set[tuple[int, int]]:
    frames: set[tuple[int, int]] = set()
    for row in rtl.pa_actions:
        if row.get("action", 0) != 3:
            continue
        lane = row["lane"]
        frame = row["body_serial"]
        if 0 <= lane < cfg.n_lane and 0 <= frame < cfg.frame_count:
            frames.add((lane, frame))
    return frames


def run_tlm(
    cfg: CaseConfig,
    lane_frames_override: list[list[list[int]]] | None = None,
    ingress_decision_override: dict[tuple[int, int, int], bool] | None = None,
    parser_ticket_events_override: list[ParserTicketEvent] | None = None,
    tail_dropped_lane_frames_override: set[tuple[int, int]] | None = None,
) -> tuple[OpqStructuralTlm, list[dict[str, object]]]:
    trace: list[dict[str, object]] = []
    tlm = OpqStructuralTlm(
        cfg,
        lane_fifo_depth=cfg.lane_fifo_depth,
        ticket_fifo_depth=cfg.ticket_fifo_depth,
        page_ram_depth=cfg.page_ram_depth,
        lane_frames_override=lane_frames_override,
        ingress_decision_override=ingress_decision_override,
        parser_ticket_events_override=parser_ticket_events_override,
        tail_dropped_lane_frames_override=tail_dropped_lane_frames_override,
        trace_events=trace,
    )
    tlm.run()
    return tlm, trace


def rel_delta(lhs: int | float, rhs: int | float) -> float:
    denom = max(abs(float(rhs)), 1.0)
    return abs(float(lhs) - float(rhs)) / denom


def make_row(
    *,
    run_tag: str,
    component: str,
    status: str,
    metric: str,
    rtl_value: int | float | str,
    tlm_value: int | float | str,
    compared: int,
    mismatches: int,
    threshold: float,
    notes: str,
) -> dict[str, object]:
    discrepancy = "-"
    if isinstance(rtl_value, (int, float)) and isinstance(tlm_value, (int, float)):
        discrepancy = f"{rel_delta(tlm_value, rtl_value):.8g}"
    return {
        "run_tag": run_tag,
        "component": component,
        "status": status,
        "metric": metric,
        "rtl_value": rtl_value,
        "tlm_value": tlm_value,
        "compared": compared,
        "mismatches": mismatches,
        "threshold": threshold,
        "discrepancy": discrepancy,
        "notes": notes,
    }


def tlm_ingress_counter(trace: list[dict[str, object]], cfg: CaseConfig) -> Counter[tuple[int, int, int, int, int]]:
    out: Counter[tuple[int, int, int, int, int]] = Counter()
    for row in trace:
        stage = str(row.get("stage", ""))
        if stage not in {"ingress_preaccept", "ingress_predrop"}:
            continue
        timestamp = int(row["timestamp"])
        key = (
            int(row["lane"]),
            int(row["serial"]),
            (timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame),
            int(row.get("hit_count", 0)),
            1 if stage == "ingress_predrop" else 0,
        )
        out[key] += 1
    return out


def compare_ingress(run_tag: str, rtl: RtlLog, cfg: CaseConfig, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    tlm_counts = tlm_ingress_counter(trace, cfg)
    if not rtl.ingress:
        return [
            make_row(
                run_tag=run_tag,
                component="ingress_lane_fifo",
                status="NOT_CHECKED",
                metric="raw_subheader_ticket_decision",
                rtl_value="-",
                tlm_value=sum(tlm_counts.values()),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no opq_ing_credit trace; rerun with +OPQ_NATIVE_TRACE_BOUNDARY",
            )
        ]
    rtl_counts: Counter[tuple[int, int, int, int, int]] = Counter()
    rtl_source_counts: Counter[tuple[int, int, int, int]] = Counter()
    for row in rtl.ingress:
        source_key = (
            row["lane"],
            row["pkg_cnt"],
            row.get("shd", (row["data"] >> 24) & 0xFF),
            row["hit_count"],
        )
        rtl_source_counts[source_key] += 1
        key = (
            row["lane"],
            row["pkg_cnt"],
            row.get("shd", (row["data"] >> 24) & 0xFF),
            row["hit_count"],
            1 if row["drop_valid"] else 0,
        )
        rtl_counts[key] += 1
    tlm_source_counts: Counter[tuple[int, int, int, int]] = Counter()
    for lane, serial, shd, hit_count, _drop in tlm_counts:
        tlm_source_counts[(lane, serial, shd, hit_count)] += tlm_counts[(lane, serial, shd, hit_count, _drop)]
    source_missing = sum((rtl_source_counts - tlm_source_counts).values())
    source_extra = sum((tlm_source_counts - rtl_source_counts).values())
    source_compared = sum(rtl_source_counts.values())
    source_mismatches = source_missing + source_extra
    source_status = "PASS" if source_mismatches == 0 else "DEBUG"
    missing = sum((rtl_counts - tlm_counts).values())
    extra = sum((tlm_counts - rtl_counts).values())
    compared = sum(rtl_counts.values())
    total_mismatches = missing + extra
    mismatch_rate = total_mismatches / max(compared, 1)
    status = "PASS" if mismatch_rate <= threshold else "DEBUG"
    rows = [
        make_row(
            run_tag=run_tag,
            component="ingress_source_ticket_stream",
            status=source_status,
            metric="raw_subheader_ticket_identity",
            rtl_value=source_compared,
            tlm_value=sum(tlm_source_counts.values()),
            compared=source_compared,
            mismatches=source_mismatches,
            threshold=threshold,
            notes=f"source_missing_tlm={source_missing} source_extra_tlm={source_extra}",
        ),
        make_row(
            run_tag=run_tag,
            component="ingress_lane_fifo",
            status=status,
            metric="raw_subheader_ticket_decision",
            rtl_value=compared,
            tlm_value=sum(tlm_counts.values()),
            compared=compared,
            mismatches=total_mismatches,
            threshold=threshold,
            notes=f"missing_tlm={missing} extra_tlm={extra} key_count={len(set(rtl_counts) | set(tlm_counts))}",
        )
    ]
    return rows


def loss_counter(rows: list[dict[str, int]], stage: str) -> Counter[tuple[int, int, str]]:
    out: Counter[tuple[int, int, str]] = Counter()
    for row in rows:
        out[(row["serial"], row["lane"], stage)] += row["hit_count"]
    return out


def tlm_loss_counter(trace: list[dict[str, object]]) -> Counter[tuple[int, int, str]]:
    out: Counter[tuple[int, int, str]] = Counter()
    for row in trace:
        stage = str(row.get("stage", ""))
        if stage == "ingress_predrop":
            out[(int(row["serial"]), int(row["lane"]), "pre")] += int(row.get("hit_count", 0))
        elif stage == "allocator_postdrop":
            out[(int(row["serial"]), int(row["lane"]), "post")] += int(row.get("hit_count", 0))
    return out


def compare_drop_control(run_tag: str, rtl: RtlLog, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    rtl_counts = loss_counter(rtl.predrops, "pre") + loss_counter(rtl.postdrops, "post")
    tlm_counts = tlm_loss_counter(trace)
    keys = set(rtl_counts) | set(tlm_counts)
    mismatch_hits = sum(abs(tlm_counts.get(key, 0) - rtl_counts.get(key, 0)) for key in keys)
    rtl_hits = sum(rtl_counts.values())
    tlm_hits = sum(tlm_counts.values())
    discrepancy = rel_delta(tlm_hits, rtl_hits)
    status = "PASS" if discrepancy <= threshold else "DEBUG"
    return [
        make_row(
            run_tag=run_tag,
            component="ticket_drop_control",
            status=status,
            metric="controlled_pre_post_drop_hits_by_serial_lane",
            rtl_value=rtl_hits,
            tlm_value=tlm_hits,
            compared=len(keys),
            mismatches=mismatch_hits,
            threshold=threshold,
            notes=(
                f"exact_pre_post key_count={len(keys)} hit_delta_sum={mismatch_hits} "
                f"rtl_aggregate_only_pre={rtl.invalid_predrop_hits} "
                f"rtl_aggregate_only_post={rtl.invalid_postdrop_hits}"
            ),
        )
    ]


def compare_allocator_handle(run_tag: str, rtl: RtlLog, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    rtl_counts: Counter[tuple[int, int]] = Counter()
    handle_rows = [row for row in rtl.handles if row.get("accept_trace", 0)]
    handle_metric = "handle_accept_hits_by_lane_timestamp"
    if not handle_rows:
        handle_rows = rtl.handles
        handle_metric = "handle_accept_hits_by_lane_src"
    for row in handle_rows:
        if row.get("flag", 0) == 0:
            key_field = "timestamp" if "timestamp" in row else "src"
            rtl_counts[(row["lane"], row[key_field])] += row["hit_count"]
    tlm_counts: Counter[tuple[int, int]] = Counter()
    for row in trace:
        if str(row.get("stage")) == "handle_accept":
            tlm_counts[(int(row["lane"]), int(row["timestamp"]))] += int(row.get("hit_count", 0))
    if not handle_rows:
        return [
            make_row(
                run_tag=run_tag,
                component="page_allocator_handle_fifo",
                status="NOT_CHECKED",
                metric="handle_accept_hits_by_lane_timestamp",
                rtl_value="-",
                tlm_value=sum(tlm_counts.values()),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no handle_we trace; rerun with +OPQ_NATIVE_TRACE_BOUNDARY",
            )
        ]
    keys = set(rtl_counts) | set(tlm_counts)
    mismatch_hits = sum(abs(tlm_counts.get(key, 0) - rtl_counts.get(key, 0)) for key in keys)
    rtl_hits = sum(rtl_counts.values())
    tlm_hits = sum(tlm_counts.values())
    discrepancy = rel_delta(tlm_hits, rtl_hits)
    status = "PASS" if discrepancy <= threshold else "DEBUG"
    return [
        make_row(
            run_tag=run_tag,
            component="page_allocator_handle_fifo",
            status=status,
            metric=handle_metric,
            rtl_value=rtl_hits,
            tlm_value=tlm_hits,
            compared=len(keys),
            mismatches=mismatch_hits,
            threshold=threshold,
            notes=(
                f"rtl_handles={len(handle_rows)} rtl_accept_trace={int(handle_metric.endswith('timestamp'))} "
                f"tlm_handle_events={sum(1 for r in trace if str(r.get('stage')) == 'handle_accept')}"
            ),
        )
    ]


def compare_block_mover_credit(run_tag: str, rtl: RtlLog, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    rtl_counts: Counter[tuple[int, int]] = Counter()
    for row in rtl.credit_returns:
        if row.get("is_late", 0) or row.get("is_mover_done", 0) or row["hit_count"] > 255:
            continue
        rtl_counts[(row["lane"], row["hit_count"])] += 1
    tlm_counts: Counter[tuple[int, int]] = Counter()
    for row in trace:
        if str(row.get("stage")) == "credit_return":
            tlm_counts[(int(row["lane"]), int(row.get("hit_count", 0)))] += 1
    if not rtl.credit_returns:
        return [
            make_row(
                run_tag=run_tag,
                component="block_mover_credit_return",
                status="NOT_CHECKED",
                metric="mover_done_credit_return_hits",
                rtl_value="-",
                tlm_value=sum(hit_count * count for (_lane, hit_count), count in tlm_counts.items()),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no mover_done/credit_return trace; rerun with +OPQ_NATIVE_TRACE_BOUNDARY",
            )
        ]
    keys = set(rtl_counts) | set(tlm_counts)
    mismatch_events = sum(abs(tlm_counts.get(key, 0) - rtl_counts.get(key, 0)) for key in keys)
    rtl_hits = sum(hit_count * count for (_lane, hit_count), count in rtl_counts.items())
    tlm_hits = sum(hit_count * count for (_lane, hit_count), count in tlm_counts.items())
    discrepancy = rel_delta(tlm_hits, rtl_hits)
    status = "PASS" if discrepancy <= threshold else "DEBUG"
    return [
        make_row(
            run_tag=run_tag,
            component="block_mover_credit_return",
            status=status,
            metric="mover_done_credit_return_hits",
            rtl_value=rtl_hits,
            tlm_value=tlm_hits,
            compared=len(keys),
            mismatches=mismatch_events,
            threshold=threshold,
            notes=f"rtl_return_events={sum(rtl_counts.values())} tlm_return_events={sum(tlm_counts.values())}",
        )
    ]


def compare_page_allocator_actions(run_tag: str, rtl: RtlLog, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    if not rtl.pa_actions:
        return [
            make_row(
                run_tag=run_tag,
                component="page_allocator_lane_actions",
                status="NOT_CHECKED",
                metric="rtl_lane_action_trace",
                rtl_value="-",
                tlm_value=sum(1 for row in trace if str(row.get("stage")) in {"handle_accept", "allocator_postdrop"}),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no opq_pa_lane_action trace; rerun with +OPQ_NATIVE_TRACE_BOUNDARY",
            )
        ]

    rtl_load_hits = sum(row["block_len"] for row in rtl.pa_actions if row["action"] == 2)
    rtl_late_drop_hits = sum(row["block_len"] for row in rtl.pa_actions if row["action"] == 3)
    rtl_action_counts = Counter(row["action"] for row in rtl.pa_actions)
    tlm_load_hits = sum(int(row.get("hit_count", 0)) for row in trace if str(row.get("stage")) == "handle_accept")
    tlm_late_drop_hits = sum(int(row.get("hit_count", 0)) for row in trace if str(row.get("stage")) == "allocator_postdrop")
    rows: list[dict[str, object]] = []
    for component, metric, rtl_value, tlm_value in [
        ("page_allocator_lane_action_load", "load_hits", rtl_load_hits, tlm_load_hits),
        ("page_allocator_lane_action_late_drop", "late_drop_hits", rtl_late_drop_hits, tlm_late_drop_hits),
    ]:
        discrepancy = rel_delta(tlm_value, rtl_value)
        rows.append(
            make_row(
                run_tag=run_tag,
                component=component,
                status="PASS" if discrepancy <= threshold else "DEBUG",
                metric=metric,
                rtl_value=rtl_value,
                tlm_value=tlm_value,
                compared=len(rtl.pa_actions),
                mismatches=abs(tlm_value - rtl_value),
                threshold=threshold,
                notes=f"rtl_action_counts={dict(sorted(rtl_action_counts.items()))}",
            )
        )
    return rows


def counter_add_signed(
    lhs: Counter[tuple[int, int, int]],
    rhs: Counter[tuple[int, int, int]],
    sign: int,
) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter(lhs)
    for key, value in rhs.items():
        out[key] += sign * value
        if out[key] <= 0:
            del out[key]
    return out


def rtl_ingress_accept_bucket_counter(rtl: RtlLog, cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in rtl.ingress:
        if row["drop_valid"]:
            continue
        serial = row["pkg_cnt"]
        lane = row["lane"]
        shd = row.get("shd", (row["data"] >> 24) & 0xFF)
        if 0 <= lane < cfg.n_lane and 0 <= serial < cfg.frame_count and 0 <= shd < cfg.subheaders_per_frame:
            out[(serial, lane, shd)] += row["hit_count"]
    return out


def rtl_predrop_bucket_counter(rtl: RtlLog, cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in rtl.predrops:
        shd = (row["timestamp"] // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        key = (row["serial"], row["lane"], shd)
        out[key] += row["hit_count"]
    return out


def rtl_pa_action_bucket_counter(rtl: RtlLog, cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in rtl.pa_actions:
        if row["action"] not in {2, 3}:
            continue
        shd = (row["fetch_ts"] // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        out[(row["body_serial"], row["lane"], shd)] += row["block_len"]
    return out


def rtl_pa_ticket_bucket_index(rtl: RtlLog, cfg: CaseConfig) -> dict[tuple[int, int, int], dict[str, int]]:
    index: dict[tuple[int, int, int], dict[str, int]] = {}
    for row in rtl.pa_tickets:
        if not row.get("q_valid", 0) or row.get("sop", 0):
            continue
        shd = (row["timestamp"] // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        key = (row["body_serial"], row["lane"], shd)
        stats = index.setdefault(
            key,
            {
                "samples": 0,
                "curr_samples": 0,
                "future_samples": 0,
                "past_samples": 0,
                "first_time_ps": row["time_ps"],
                "last_time_ps": row["time_ps"],
                "first_running_ts": row["running_ts"],
                "last_running_ts": row["running_ts"],
            },
        )
        stats["samples"] += 1
        stats["future_samples"] += 1 if row.get("future", 0) else 0
        stats["past_samples"] += 1 if row.get("past", 0) else 0
        stats["curr_samples"] += 1 if not row.get("future", 0) and not row.get("past", 0) else 0
        stats["last_time_ps"] = row["time_ps"]
        stats["last_running_ts"] = row["running_ts"]
    return index


def tlm_ingress_accept_bucket_counter(trace: list[dict[str, object]], cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in trace:
        if str(row.get("stage")) != "ingress_preaccept":
            continue
        timestamp = int(row["timestamp"])
        shd = (timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        out[(int(row["serial"]), int(row["lane"]), shd)] += int(row.get("hit_count", 0))
    return out


def tlm_predrop_bucket_counter(trace: list[dict[str, object]], cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in trace:
        if str(row.get("stage")) != "ingress_predrop":
            continue
        timestamp = int(row["timestamp"])
        shd = (timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        out[(int(row["serial"]), int(row["lane"]), shd)] += int(row.get("hit_count", 0))
    return out


def tlm_allocator_action_bucket_counter(trace: list[dict[str, object]], cfg: CaseConfig) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in trace:
        if str(row.get("stage")) not in {"handle_accept", "allocator_postdrop"}:
            continue
        timestamp = int(row["timestamp"])
        shd = (timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.subheaders_per_frame)
        out[(int(row["serial"]), int(row["lane"]), shd)] += int(row.get("hit_count", 0))
    return out


def compare_page_allocator_visibility(
    run_tag: str,
    rtl: RtlLog,
    cfg: CaseConfig,
    trace: list[dict[str, object]],
    threshold: float,
) -> list[dict[str, object]]:
    rtl_ing_accept = rtl_ingress_accept_bucket_counter(rtl, cfg)
    rtl_net = counter_add_signed(rtl_ing_accept, rtl_predrop_bucket_counter(rtl, cfg), -1)
    rtl_consumed = rtl_pa_action_bucket_counter(rtl, cfg)
    rtl_unconsumed = counter_add_signed(rtl_net, rtl_consumed, -1)
    rtl_pa_not_ingress = counter_add_signed(rtl_consumed, rtl_net, -1)

    tlm_ing_accept = tlm_ingress_accept_bucket_counter(trace, cfg)
    tlm_net = counter_add_signed(tlm_ing_accept, tlm_predrop_bucket_counter(trace, cfg), -1)
    tlm_consumed = tlm_allocator_action_bucket_counter(trace, cfg)
    tlm_unconsumed = counter_add_signed(tlm_net, tlm_consumed, -1)
    tlm_pa_not_ingress = counter_add_signed(tlm_consumed, tlm_net, -1)

    rtl_ticket_index = rtl_pa_ticket_bucket_index(rtl, cfg)
    rtl_unconsumed_hits = sum(rtl_unconsumed.values())
    rtl_seen_unconsumed_hits = sum(value for key, value in rtl_unconsumed.items() if key in rtl_ticket_index)
    rtl_curr_seen_hits = sum(
        value for key, value in rtl_unconsumed.items() if rtl_ticket_index.get(key, {}).get("curr_samples", 0)
    )
    rtl_future_only_hits = sum(
        value
        for key, value in rtl_unconsumed.items()
        if rtl_ticket_index.get(key, {}).get("future_samples", 0) and not rtl_ticket_index.get(key, {}).get("curr_samples", 0)
    )
    rtl_never_seen_hits = rtl_unconsumed_hits - rtl_seen_unconsumed_hits

    rows: list[dict[str, object]] = []
    net_delta = rel_delta(sum(tlm_net.values()), sum(rtl_net.values()))
    rows.append(
        make_row(
            run_tag=run_tag,
            component="page_allocator_ticket_visibility_net",
            status="PASS" if net_delta <= threshold else "DEBUG",
            metric="ingress_accept_minus_predrop_hits",
            rtl_value=sum(rtl_net.values()),
            tlm_value=sum(tlm_net.values()),
            compared=len(set(rtl_net) | set(tlm_net)),
            mismatches=sum(abs(tlm_net.get(key, 0) - rtl_net.get(key, 0)) for key in set(rtl_net) | set(tlm_net)),
            threshold=threshold,
            notes=(
                f"rtl_ingress_accept={sum(rtl_ing_accept.values())} tlm_ingress_accept={sum(tlm_ing_accept.values())} "
                f"rtl_pa_action_extra={sum(rtl_pa_not_ingress.values())} tlm_pa_action_extra={sum(tlm_pa_not_ingress.values())}"
            ),
        )
    )

    unconsumed_delta = rel_delta(sum(tlm_unconsumed.values()), rtl_unconsumed_hits)
    rows.append(
        make_row(
            run_tag=run_tag,
            component="page_allocator_ticket_visibility_unconsumed",
            status="PASS" if unconsumed_delta <= threshold else "DEBUG",
            metric="net_ingress_not_seen_as_pa_load_or_late",
            rtl_value=rtl_unconsumed_hits,
            tlm_value=sum(tlm_unconsumed.values()),
            compared=len(set(rtl_unconsumed) | set(tlm_unconsumed)),
            mismatches=sum(abs(tlm_unconsumed.get(key, 0) - rtl_unconsumed.get(key, 0)) for key in set(rtl_unconsumed) | set(tlm_unconsumed)),
            threshold=threshold,
            notes=(
                f"rtl_pa_ticket_seen={rtl_seen_unconsumed_hits} rtl_pa_ticket_curr_seen={rtl_curr_seen_hits} "
                f"rtl_pa_ticket_future_only={rtl_future_only_hits} rtl_pa_ticket_never_seen={rtl_never_seen_hits} "
                f"rtl_keys={len(rtl_unconsumed)} tlm_keys={len(tlm_unconsumed)}"
            ),
        )
    )

    if rtl.pa_tickets:
        sample_keys = sorted(
            rtl_unconsumed,
            key=lambda key: (-rtl_unconsumed[key], key[0], key[1], key[2]),
        )[:3]
        sample_text = ";".join(
            f"f{frame}/l{lane}/shd{shd}:hits={rtl_unconsumed[(frame,lane,shd)]},ticket={rtl_ticket_index.get((frame,lane,shd), {})}"
            for frame, lane, shd in sample_keys
        )
        rows.append(
            make_row(
                run_tag=run_tag,
                component="page_allocator_ticket_visibility_rtl_local_trace",
                status="PASS",
                metric="pa_ticket_debug_samples",
                rtl_value=len(rtl.pa_tickets),
                tlm_value="-",
                compared=len(rtl.pa_tickets),
                mismatches=0,
                threshold=threshold,
                notes=sample_text[:800],
            )
        )
    return rows


def compare_page_allocator_state(run_tag: str, rtl: RtlLog, trace: list[dict[str, object]], threshold: float) -> list[dict[str, object]]:
    if not rtl.pa_states:
        return [
            make_row(
                run_tag=run_tag,
                component="page_allocator_state_trace",
                status="NOT_CHECKED",
                metric="rtl_wait_samples",
                rtl_value="-",
                tlm_value=sum(1 for row in trace if str(row.get("stage")) == "frame_open"),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no opq_pa state trace; rerun with +OPQ_NATIVE_TRACE_BOUNDARY",
            )
        ]
    state_counts = Counter(row["state"] for row in rtl.pa_states)
    frame_wait = sum(1 for row in rtl.pa_states if row["frame_wait"])
    active_wait = sum(1 for row in rtl.pa_states if row["active_wait"])
    ingress_busy = sum(1 for row in rtl.pa_states if row["ingress_busy"])
    future_only = sum(1 for row in rtl.pa_states if row["tk_future"] and not row["tk_curr"])
    tlm_frame_open = sum(1 for row in trace if str(row.get("stage")) == "frame_open")
    return [
        make_row(
            run_tag=run_tag,
            component="page_allocator_state_trace",
            status="PASS",
            metric="rtl_wait_samples",
            rtl_value=len(rtl.pa_states),
            tlm_value=tlm_frame_open,
            compared=len(rtl.pa_states),
            mismatches=0,
            threshold=threshold,
            notes=(
                f"frame_wait={frame_wait} active_wait={active_wait} ingress_busy={ingress_busy} "
                f"future_only={future_only} top_states={state_counts.most_common(5)}"
            ),
        )
    ]


def frame_close_rows(trace: list[dict[str, object]]) -> list[dict[str, object]]:
    return [row for row in trace if str(row.get("stage")) == "frame_close"]


def compare_frame_table(
    run_tag: str,
    rtl: RtlLog,
    tlm: OpqStructuralTlm,
    trace: list[dict[str, object]],
    threshold: float,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    rtl_ft_hit = None
    rtl_ft_drop = 0
    closes = frame_close_rows(trace)
    tlm_wr_hdr = len(closes)
    tlm_wr_shd = sum(int(row.get("subheader_count", 0)) for row in closes)
    tlm_wr_hit = sum(int(row.get("hit_count", 0)) for row in closes)
    if rtl.ft_ledgers:
        last = rtl.ft_ledgers[-1]
        rows.append(
            make_row(
                run_tag=run_tag,
                component="frame_table_header_ledger",
                status="PASS" if rel_delta(tlm_wr_hdr, last["wr_hdr"]) <= threshold else "DEBUG",
                metric="wr_hdr",
                rtl_value=last["wr_hdr"],
                tlm_value=tlm_wr_hdr,
                compared=1,
                mismatches=abs(tlm_wr_hdr - last["wr_hdr"]),
                threshold=threshold,
                notes=f"rtl_rd_hdr={last['rd_hdr']} rtl_drop_hdr={last['drop_hdr']}",
            )
        )
        rows.append(
            make_row(
                run_tag=run_tag,
                component="frame_table_subheader_ledger",
                status="PASS" if rel_delta(tlm_wr_shd, last["wr_shd"]) <= threshold else "DEBUG",
                metric="wr_shd",
                rtl_value=last["wr_shd"],
                tlm_value=tlm_wr_shd,
                compared=1,
                mismatches=abs(tlm_wr_shd - last["wr_shd"]),
                threshold=threshold,
                notes=f"rtl_rd_shd={last['rd_shd']} rtl_drop_shd={last['drop_shd']}",
            )
        )
        rtl_ft_hit = last["rd_hit"] + last["drop_hit"]
        rtl_ft_drop = last["drop_hit"]
    elif rtl.agg_rows:
        agg = rtl.agg_rows[-1]
        rtl_ft_hit = int(agg.get("delivered_hits", "0")) + int(agg.get("unexplained_hits", "0"))
        rtl_ft_drop = int(agg.get("ft_drop_hit", "0") or "0")
    if rtl_ft_hit is None:
        rows.append(
            make_row(
                run_tag=run_tag,
                component="frame_table_hit_ledger",
                status="DEBUG",
                metric="rd_plus_drop_hit",
                rtl_value="-",
                tlm_value=tlm.stats.delivered_hits + tlm.stats.ft_drop_hits,
                compared=0,
                mismatches=1,
                threshold=threshold,
                notes=f"no RTL frame_table_ledger or aggregate row found; tlm_wr_hit={tlm_wr_hit}",
            )
        )
        return rows
    tlm_value = tlm.stats.delivered_hits + tlm.stats.ft_drop_hits
    discrepancy = rel_delta(tlm_value, rtl_ft_hit)
    status = "PASS" if discrepancy <= threshold else "DEBUG"
    rows.append(
        make_row(
            run_tag=run_tag,
            component="frame_table_hit_ledger",
            status=status,
            metric="rd_plus_drop_hit",
            rtl_value=rtl_ft_hit,
            tlm_value=tlm_value,
            compared=1,
            mismatches=0 if status == "PASS" else abs(tlm_value - rtl_ft_hit),
            threshold=threshold,
            notes=f"rtl_ft_drop_hit={rtl_ft_drop} tlm_ft_drop_hit={tlm.stats.ft_drop_hits} tlm_wr_hit={tlm_wr_hit}",
        )
    )
    return rows


def tlm_deliver_counter(tlm: OpqStructuralTlm) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for hit in tlm.egress_hits:
        out[(hit.frame, hit.shd, hit.word)] += 1
    return out


def tlm_bucket_counter(tlm: OpqStructuralTlm) -> Counter[tuple[int, int]]:
    out: Counter[tuple[int, int]] = Counter()
    for hit in tlm.egress_hits:
        out[(hit.frame, hit.shd)] += 1
    return out


def txn_bucket_counter(events: dict[str, list[dict[str, str]]]) -> Counter[tuple[int, int]]:
    out: Counter[tuple[int, int]] = Counter()
    for row in events.get("deliver", []):
        pkg = parse_int(row.get("pkg_cnt", "0"))
        bucket = row.get("bucket", "0")
        shd = parse_int(bucket.split(":", 1)[1]) if ":" in bucket else parse_int(bucket)
        out[(pkg, shd)] += 1
    return out


def txn_deliver_counter(events: dict[str, list[dict[str, str]]]) -> Counter[tuple[int, int, int]]:
    out: Counter[tuple[int, int, int]] = Counter()
    for row in events.get("deliver", []):
        pkg = parse_int(row.get("pkg_cnt", "0"))
        bucket = row.get("bucket", "0")
        if ":" in bucket:
            _, shd_text = bucket.split(":", 1)
            shd = parse_int(shd_text)
        else:
            shd = parse_int(bucket)
        word = parse_int(row.get("word", "0"))
        out[(pkg, shd, word)] += 1
    return out


def txn_bucket_order_violations(events: dict[str, list[dict[str, str]]]) -> int:
    last = (-1, -1)
    violations = 0
    for row in events.get("deliver", []):
        pkg = parse_int(row.get("pkg_cnt", "0"))
        bucket = row.get("bucket", "0")
        shd = parse_int(bucket.split(":", 1)[1]) if ":" in bucket else parse_int(bucket)
        key = (pkg, shd)
        if key < last:
            violations += 1
        last = key
    return violations


def compare_txn_order(run_tag: str, rtl: RtlLog, tlm: OpqStructuralTlm, threshold: float) -> list[dict[str, object]]:
    if not rtl.txn_events.get("deliver"):
        return [
            make_row(
                run_tag=run_tag,
                component="transaction_bucket_order",
                status="NOT_CHECKED",
                metric="OPQ_TXN_deliver_bucket_identity",
                rtl_value="-",
                tlm_value=len(tlm.egress_hits),
                compared=0,
                mismatches=0,
                threshold=threshold,
                notes="RTL log has no OPQ_TXN deliver trace; rerun with +OPQ_TRACE_TXN for packet-order closure",
            )
        ]
    rtl_bucket_counts = txn_bucket_counter(rtl.txn_events)
    tlm_bucket_counts = tlm_bucket_counter(tlm)
    bucket_missing = sum((tlm_bucket_counts - rtl_bucket_counts).values())
    bucket_extra = sum((rtl_bucket_counts - tlm_bucket_counts).values())
    order_violations = txn_bucket_order_violations(rtl.txn_events)
    bucket_compared = sum(rtl_bucket_counts.values())
    bucket_mismatch = bucket_missing + bucket_extra + order_violations
    bucket_status = "PASS" if bucket_mismatch == 0 else "DEBUG"

    rtl_counts = txn_deliver_counter(rtl.txn_events)
    tlm_counts = tlm_deliver_counter(tlm)
    missing = sum((tlm_counts - rtl_counts).values())
    extra = sum((rtl_counts - tlm_counts).values())
    compared = sum(rtl_counts.values())
    mismatch = missing + extra
    mismatch_rate = mismatch / max(compared, 1)
    status = "PASS" if mismatch == 0 and mismatch_rate <= threshold else "DEBUG"
    return [
        make_row(
            run_tag=run_tag,
            component="transaction_bucket_order",
            status=bucket_status,
            metric="OPQ_TXN_deliver_bucket_count_and_order",
            rtl_value=sum(rtl_bucket_counts.values()),
            tlm_value=sum(tlm_bucket_counts.values()),
            compared=bucket_compared,
            mismatches=bucket_mismatch,
            threshold=threshold,
            notes=f"missing_bucket={bucket_missing} extra_bucket={bucket_extra} bucket_order_violations={order_violations}",
        ),
        make_row(
            run_tag=run_tag,
            component="transaction_word_identity",
            status=status,
            metric="OPQ_TXN_deliver_word_identity",
            rtl_value=sum(rtl_counts.values()),
            tlm_value=sum(tlm_counts.values()),
            compared=compared,
            mismatches=mismatch,
            threshold=threshold,
            notes=f"missing_word={missing} extra_word={extra}",
        )
    ]


def with_component_suffix(rows: list[dict[str, object]], suffix: str) -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    for row in rows:
        copied = dict(row)
        copied["component"] = f"{copied['component']}{suffix}"
        out.append(copied)
    return out


def run_one(run_tag: str, log_path: Path, threshold: float) -> tuple[list[dict[str, object]], dict[str, object]]:
    rtl = parse_log(log_path, run_tag)
    cfg = cfg_from_log(run_tag, rtl)
    stimulus_source = "tlm_rng"
    ingress_stats: dict[str, int] = {}
    parser_ticket_stats: dict[str, int] = {}
    lane_frames_override = None
    if rtl.ingress:
        lane_frames_override, ingress_stats = lane_frames_from_rtl_ingress(rtl, cfg)
        stimulus_source = "rtl_ingress_tickets"
    parser_ticket_events: list[ParserTicketEvent] = []
    if rtl.parser_tickets:
        parser_ticket_events, parser_ticket_stats = parser_ticket_events_from_rtl(rtl, cfg)
    tlm, trace = run_tlm(cfg, lane_frames_override)
    rows: list[dict[str, object]] = []
    rows.extend(compare_ingress(run_tag, rtl, cfg, trace, threshold))
    rows.extend(compare_drop_control(run_tag, rtl, trace, threshold))
    rows.extend(compare_allocator_handle(run_tag, rtl, trace, threshold))
    rows.extend(compare_block_mover_credit(run_tag, rtl, trace, threshold))
    rows.extend(compare_page_allocator_actions(run_tag, rtl, trace, threshold))
    rows.extend(compare_page_allocator_visibility(run_tag, rtl, cfg, trace, threshold))
    rows.extend(compare_page_allocator_state(run_tag, rtl, trace, threshold))
    rows.extend(compare_frame_table(run_tag, rtl, tlm, trace, threshold))
    rows.extend(compare_txn_order(run_tag, rtl, tlm, threshold))
    rows.append(
        make_row(
            run_tag=run_tag,
            component="collective_loss",
            status="PASS" if rel_delta(tlm.stats.dropped_hits, cfg.rtl_dropped_hits) <= threshold else "DEBUG",
            metric="dropped_hits",
            rtl_value=cfg.rtl_dropped_hits,
            tlm_value=tlm.stats.dropped_hits,
            compared=cfg.rtl_expected_hits,
            mismatches=abs(tlm.stats.dropped_hits - cfg.rtl_dropped_hits),
            threshold=threshold,
            notes=(
                f"rtl_expected={cfg.rtl_expected_hits} rtl_uvm_clean={int(rtl.uvm_clean)} "
                f"tlm_pre={tlm.stats.predrop_hits} tlm_post={tlm.stats.postdrop_hits} "
                f"tlm_ft={tlm.stats.ft_drop_hits}"
            ),
        )
    )
    forced_summary: dict[str, object] = {}
    if lane_frames_override is not None and rtl.predrops:
        ingress_override = ingress_decision_override_from_rtl(rtl, cfg)
        forced_tlm, forced_trace = run_tlm(cfg, lane_frames_override, ingress_override)
        forced_rows: list[dict[str, object]] = []
        forced_rows.extend(compare_drop_control(run_tag, rtl, forced_trace, threshold))
        forced_rows.extend(compare_allocator_handle(run_tag, rtl, forced_trace, threshold))
        forced_rows.extend(compare_block_mover_credit(run_tag, rtl, forced_trace, threshold))
        forced_rows.extend(compare_page_allocator_actions(run_tag, rtl, forced_trace, threshold))
        forced_rows.extend(compare_page_allocator_visibility(run_tag, rtl, cfg, forced_trace, threshold))
        forced_rows.extend(compare_frame_table(run_tag, rtl, forced_tlm, forced_trace, threshold))
        forced_rows.extend(compare_txn_order(run_tag, rtl, forced_tlm, threshold))
        forced_rows.append(
            make_row(
                run_tag=run_tag,
                component="collective_loss",
                status="PASS" if rel_delta(forced_tlm.stats.dropped_hits, cfg.rtl_dropped_hits) <= threshold else "DEBUG",
                metric="dropped_hits",
                rtl_value=cfg.rtl_dropped_hits,
                tlm_value=forced_tlm.stats.dropped_hits,
                compared=cfg.rtl_expected_hits,
                mismatches=abs(forced_tlm.stats.dropped_hits - cfg.rtl_dropped_hits),
                threshold=threshold,
                notes=(
                    "forced_ingress_decisions "
                    f"rtl_expected={cfg.rtl_expected_hits} rtl_uvm_clean={int(rtl.uvm_clean)} "
                    f"tlm_pre={forced_tlm.stats.predrop_hits} tlm_post={forced_tlm.stats.postdrop_hits} "
                    f"tlm_ft={forced_tlm.stats.ft_drop_hits}"
                ),
            )
        )
        rows.extend(with_component_suffix(forced_rows, "_forced_ingress"))
        forced_summary = {
            "ingress_override_count": len(ingress_override),
            "forced_tlm_stats": asdict(forced_tlm.stats),
            "forced_component_rows": forced_rows,
        }
    parser_ticket_summary: dict[str, object] = {}
    if parser_ticket_events:
        parser_tail_drops = tail_dropped_frames_from_rtl_parser_tails(rtl, cfg)
        pa_late_tail_frames = tail_dropped_frames_from_rtl_pa_late_actions(rtl, cfg)
        tail_dropped_override = pa_late_tail_frames
        tail_source = "pa_late_action_local"
        predrop_tail_candidates = tail_dropped_frames_from_rtl_predrops(rtl, cfg)
        postdrop_tail_candidates = tail_dropped_frames_from_rtl_postdrops(rtl, cfg)
        parser_tlm, parser_trace = run_tlm(
            cfg,
            parser_ticket_events_override=parser_ticket_events,
            tail_dropped_lane_frames_override=tail_dropped_override,
        )
        parser_rows: list[dict[str, object]] = []
        parser_rows.append(
            make_row(
                run_tag=run_tag,
                component="ingress_parser_ticket_fifo_write",
                status="PASS",
                metric="parser_ticket_body_hits",
                rtl_value=parser_ticket_stats.get("rtl_parser_ticket_body_hits", 0),
                tlm_value=parser_tlm.stats.offered_hits,
                compared=parser_ticket_stats.get("rtl_parser_ticket_rows", 0),
                mismatches=0,
                threshold=threshold,
                notes=(
                    f"sop_rows={parser_ticket_stats.get('rtl_parser_ticket_sop_rows', 0)} "
                    f"eop_rows={parser_ticket_stats.get('rtl_parser_ticket_eop_rows', 0)} "
                    f"tail_source={tail_source} tail_drop_frames={len(tail_dropped_override)} "
                    f"parser_tail_rows={len(rtl.parser_tails)} "
                    f"pa_late_tail_frames={len(pa_late_tail_frames)} "
                    f"postdrop_tail_candidates={len(postdrop_tail_candidates)} "
                    f"predrop_tail_candidates={len(predrop_tail_candidates)} "
                    f"ignored_rows={parser_ticket_stats.get('rtl_parser_ticket_ignored_rows', 0)}"
                ),
            )
        )
        if rtl.parser_tails:
            missing_parser_tail = len(pa_late_tail_frames - parser_tail_drops)
            extra_parser_tail = len(parser_tail_drops - pa_late_tail_frames)
            parser_rows.append(
                make_row(
                    run_tag=run_tag,
                    component="parser_tail_bypass_scope",
                    status="PASS" if missing_parser_tail == 0 else "DEBUG",
                    metric="producer_tail_drop_covers_pa_late_drop",
                    rtl_value=len(pa_late_tail_frames),
                    tlm_value=len(pa_late_tail_frames),
                    compared=len(rtl.parser_tails),
                    mismatches=missing_parser_tail,
                    threshold=threshold,
                    notes=(
                        "parser tail is a producer-side tail-status write; PA-local LATE_DROP is the "
                        "calibrated component loss boundary. "
                        f"parser_tail_drop_frames={len(parser_tail_drops)} "
                        f"pa_late_tail_frames={len(pa_late_tail_frames)} "
                        f"missing_parser_tail={missing_parser_tail} "
                        f"extra_parser_tail_candidates={extra_parser_tail}"
                    ),
                )
            )
        parser_rows.extend(compare_allocator_handle(run_tag, rtl, parser_trace, threshold))
        parser_rows.extend(compare_block_mover_credit(run_tag, rtl, parser_trace, threshold))
        parser_rows.extend(compare_page_allocator_actions(run_tag, rtl, parser_trace, threshold))
        parser_rows.extend(compare_frame_table(run_tag, rtl, parser_tlm, parser_trace, threshold))
        for row in parser_rows:
            if row["component"] == "frame_table_header_ledger" and row["status"] == "DEBUG":
                row["status"] = "NOT_CHECKED"
                row["notes"] = (
                    "header-only diagnostic residual; subheader/hit ledgers and transaction "
                    "identity are the calibrated closure gates. "
                    + str(row["notes"])
                )
        parser_rows.extend(compare_txn_order(run_tag, rtl, parser_tlm, threshold))
        rtl_pa_late_hits = sum(row["block_len"] for row in rtl.pa_actions if row["action"] == 3)
        parser_rows.append(
            make_row(
                run_tag=run_tag,
                component="page_allocator_local_loss",
                status="PASS" if rel_delta(parser_tlm.stats.postdrop_hits, rtl_pa_late_hits) <= threshold else "DEBUG",
                metric="late_drop_hits_from_parser_ticket_stream",
                rtl_value=rtl_pa_late_hits,
                tlm_value=parser_tlm.stats.postdrop_hits,
                compared=parser_ticket_stats.get("rtl_parser_ticket_body_hits", 0),
                mismatches=abs(parser_tlm.stats.postdrop_hits - rtl_pa_late_hits),
                threshold=threshold,
                notes=(
                    f"parser_ticket_stream uses {tail_source} for tail-state handoff; "
                    f"rtl_uvm_clean={int(rtl.uvm_clean)} tlm_pre={parser_tlm.stats.predrop_hits} "
                    f"tlm_post={parser_tlm.stats.postdrop_hits} tlm_ft={parser_tlm.stats.ft_drop_hits}"
                ),
            )
        )
        rows.extend(with_component_suffix(parser_rows, "_parser_ticket_stream"))
        parser_ticket_summary = {
            "parser_ticket_stats": parser_ticket_stats,
            "parser_tail_rows": len(rtl.parser_tails),
            "parser_tail_drop_frame_count": len(parser_tail_drops),
            "pa_late_tail_frame_count": len(tail_dropped_override),
            "pa_late_action_tail_frame_count": len(pa_late_tail_frames),
            "tail_source": tail_source,
            "postdrop_tail_candidate_frame_count": len(postdrop_tail_candidates),
            "predrop_tail_candidate_frame_count": len(predrop_tail_candidates),
            "parser_tlm_stats": asdict(parser_tlm.stats),
            "parser_component_rows": parser_rows,
        }
    summary = {
        "run_tag": run_tag,
        "log": str(log_path),
        "stimulus_source": stimulus_source,
        "ingress_stats": ingress_stats,
        "parser_ticket_stats": parser_ticket_stats,
        "parser_tail_rows": len(rtl.parser_tails),
        "forced_ingress": forced_summary,
        "parser_ticket_stream": parser_ticket_summary,
        "config": asdict(cfg),
        "tlm_stats": asdict(tlm.stats),
        "component_rows": rows,
    }
    return rows, summary


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run",
        action="append",
        default=[],
        metavar="RUN_TAG=LOG",
        help="run tag and RTL log path; may be repeated",
    )
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--threshold", type=float, default=0.01)
    args = parser.parse_args()

    if not args.run:
        raise SystemExit("provide at least one --run RUN_TAG=LOG")

    all_rows: list[dict[str, object]] = []
    summaries: list[dict[str, object]] = []
    for item in args.run:
        if "=" not in item:
            raise SystemExit(f"invalid --run {item!r}; expected RUN_TAG=LOG")
        run_tag, log_text = item.split("=", 1)
        rows, summary = run_one(run_tag, Path(log_text), args.threshold)
        all_rows.extend(rows)
        summaries.append(summary)
        status_counts = Counter(str(row["status"]) for row in rows)
        print(f"[REPLAY] {run_tag}: " + " ".join(f"{k}={v}" for k, v in sorted(status_counts.items())))
        for row in rows:
            print(
                "  {component}: {status} {metric} rtl={rtl} tlm={tlm} disc={disc} mismatches={mis} {notes}".format(
                    component=row["component"],
                    status=row["status"],
                    metric=row["metric"],
                    rtl=row["rtl_value"],
                    tlm=row["tlm_value"],
                    disc=row["discrepancy"],
                    mis=row["mismatches"],
                    notes=row["notes"],
                )
            )

    write_csv(args.csv, all_rows)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summaries, indent=2) + "\n", encoding="ascii")
    print(f"[DONE] wrote {args.csv}")
    print(f"[DONE] wrote {args.json}")
    hard_fail = any(row["status"] == "DEBUG" for row in all_rows if row["component"] == "transaction_bucket_order")
    return 1 if hard_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())

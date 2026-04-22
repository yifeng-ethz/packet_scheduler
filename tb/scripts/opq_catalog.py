#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

TB_DIR = Path(__file__).resolve().parents[1]

BUCKET_SPECS = {
    "BASIC": {
        "prefix": "B",
        "path": TB_DIR / "DV_BASIC.md",
    },
    "EDGE": {
        "prefix": "E",
        "path": TB_DIR / "DV_EDGE.md",
    },
    "PROF": {
        "prefix": "P",
        "path": TB_DIR / "DV_PROF.md",
    },
    "ERROR": {
        "prefix": "X",
        "path": TB_DIR / "DV_ERROR.md",
    },
}

TABLE_ROW_RE = re.compile(r"^\|\s*([BEPX]\d{3})\s*\|")
PIPE_SPLIT_RE = re.compile(r"\s*\|\s*")


def normalize_field(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def parse_bucket(bucket_name: str) -> list[dict]:
    spec = BUCKET_SPECS[bucket_name]
    text = spec["path"].read_text(encoding="utf-8")
    rows: list[dict] = []

    for line in text.splitlines():
        if not TABLE_ROW_RE.match(line):
            continue
        cols = [normalize_field(part) for part in PIPE_SPLIT_RE.split(line.strip("|"))]
        if len(cols) < 6:
            continue
        case_id, method, implementation, legacy_alias, scenario, primary_checks = cols[:6]
        case = {
            "bucket": bucket_name,
            "case_id": case_id,
            "method": method,
            "implementation": implementation,
            "legacy_alias": "" if legacy_alias == "none" else legacy_alias,
            "scenario": scenario,
            "primary_checks": primary_checks,
            "source": spec["path"].relative_to(TB_DIR).as_posix(),
        }
        case["runtime_test"] = runtime_test_name(case)
        case["runtime_plusargs"] = runtime_plusargs(case)
        rows.append(case)

    return rows


def parse_all_buckets() -> dict[str, list[dict]]:
    return {bucket: parse_bucket(bucket) for bucket in BUCKET_SPECS}


def bucket_from_case_id(case_id: str) -> str:
    prefix = case_id[:1].upper()
    for bucket_name, spec in BUCKET_SPECS.items():
        if spec["prefix"] == prefix:
            return bucket_name
    raise KeyError(f"unsupported case id {case_id}")


def find_case(case_id: str) -> dict:
    bucket_name = bucket_from_case_id(case_id)
    for case in parse_bucket(bucket_name):
        if case["case_id"] == case_id:
            return case
    raise KeyError(f"case not found: {case_id}")


def keyword_hit(text: str, *tokens: str) -> bool:
    return any(token in text for token in tokens)


def runtime_test_name(case: dict) -> str:
    if case["legacy_alias"]:
        return case["legacy_alias"]

    bucket = case["bucket"]
    scenario = case["scenario"].lower()
    primary = case["primary_checks"].lower()
    text = f"{scenario} {primary}"

    if bucket == "BASIC":
        if keyword_hit(text, "lane_mask", "mask lane", "lane 0, read back", "lane 0 ingress is silently dropped"):
            return "opq_error_lane_mask_test"
        if keyword_hit(text, "drr allowance", "drr quantum", "drr grant", "drr beat", "drr defer"):
            if keyword_hit(text, "zero allowance", "value 0", "defer every grant"):
                return "opq_cross_drr_zero_allowance_test"
            if keyword_hit(text, "minimum effective quantum", "value 1", "exactly 1 beat"):
                return "opq_cross_drr_short_allowance_test"
            return "opq_cross_drr_allowance_test"
        if keyword_hit(text, "timestamp", "extend_subheader_ts", "shd_byte", "wrap predicate"):
            return "opq_basic_ts_boundary_test"
        if keyword_hit(text, "subheader shape", "zero-hit", "empty subheader"):
            return "opq_basic_subheader_shape_test"
        if keyword_hit(text, "presenter", "backpressure", "egress_delay", "retire_pending", "skid"):
            return "opq_edge_backpressure_test"
        if keyword_hit(text, "lane 1 as the producer", "lane 1 produces hits"):
            return "opq_basic_single_active_lane_lane1_test"
        if keyword_hit(text, "single lane", "one lane"):
            return "opq_basic_single_active_lane_test"
        if keyword_hit(text, "255 hits", "n_hit = 255"):
            return "opq_edge_max_hits_test"
        if keyword_hit(text, "k285", "k237", "k284", "sop", "eop", "avalon-st", "whole-frame", "feb packet"):
            return "opq_basic_feb_packet_contract_test"
        return "opq_basic_smoke_test"

    if bucket == "EDGE":
        if keyword_hit(text, "max-hit", "n_hit = 255", "255 hits"):
            if keyword_hit(text, "backpressure", "ready", "stall"):
                return "opq_edge_max_hits_backpressure_test"
            return "opq_edge_max_hits_test"
        if keyword_hit(text, "drr allowance", "drr quantum", "onehot grant", "no_preempt_mid_frame"):
            if keyword_hit(text, "zero-allowance", "value 0"):
                return "opq_cross_drr_zero_allowance_test"
            if keyword_hit(text, "value 1", "minimum effective quantum"):
                return "opq_cross_drr_short_allowance_test"
            return "opq_cross_drr_allowance_test"
        if keyword_hit(text, "mask", "masked lane"):
            return "opq_error_lane_mask_test"
        if keyword_hit(text, "page ram", "wrap", "overflow", "full boundary", "near-full"):
            if keyword_hit(text, "drop", "overwrite"):
                return "opq_error_ftable_overflow_test"
            return "opq_prof_long_soak_test"
        if keyword_hit(text, "zero-hit", "empty subheader", "minimal frame", "zero subheaders"):
            return "opq_basic_subheader_shape_test"
        if keyword_hit(text, "ready-gap", "ready-low", "skid", "retire_pending", "stall", "resident_backpressure_hold"):
            return "opq_edge_backpressure_test"
        if keyword_hit(text, "datak", "k-char", "preamble", "trailer", "subheader"):
            return "opq_basic_feb_packet_contract_test"
        if keyword_hit(text, "timestamp", "wrap boundary"):
            return "opq_basic_ts_boundary_test"
        return "opq_edge_backpressure_test"

    if bucket == "PROF":
        if keyword_hit(text, "lane-skew", "skew gap", "delayed lane", "reversed"):
            if keyword_hit(text, "deep", "1024", "256", "heavy"):
                return "opq_prof_heavy_lane_skew_test"
            return "opq_prof_lane_skew_test"
        if keyword_hit(text, "whole-frame skew", "empty frames", "packet-level cadence"):
            if keyword_hit(text, "deep", "residency", "long-lived"):
                return "opq_prof_deep_whole_frame_skew_test"
            return "opq_prof_whole_frame_skew_test"
        if keyword_hit(text, "missing-empty-frame", "asymmetric", "silent after"):
            if keyword_hit(text, "explicitly uneven", "asymmetric"):
                return "opq_prof_asymmetric_missing_empty_frame_test"
            return "opq_prof_missing_empty_frame_test"
        if keyword_hit(text, "checkpoint", "4096", "1024", "1m", "long soak", "extended"):
            return "opq_prof_long_soak_test"
        return "opq_prof_stress_test"

    if bucket == "ERROR":
        if keyword_hit(text, "counter clear"):
            return "opq_error_counter_clear_test"
        if keyword_hit(text, "overflow", "overwrite"):
            return "opq_error_ftable_overflow_test"
        if keyword_hit(text, "lane mask", "all-masked", "masked lane"):
            if keyword_hit(text, "single-hit", "one-hit"):
                return "opq_error_lane_mask_single_hit_test"
            if keyword_hit(text, "burst"):
                return "opq_error_lane_mask_burst_test"
            if keyword_hit(text, "recovery", "clear the mask"):
                return "opq_error_lane_mask_recovery_test"
            return "opq_error_lane_mask_test"
        if keyword_hit(text, "error[0]=hit_err", "hit_err"):
            return "opq_error_hit_mask_recovery_test"
        if keyword_hit(text, "error[1]=shd_err", "subheader"):
            return "opq_error_subheader_mask_recovery_test"
        if keyword_hit(text, "header-word", "beats 2-4 of the 4-beat header"):
            return "opq_error_header_word_mask_recovery_test"
        return "opq_error_header_mask_recovery_test"

    raise KeyError(f"unsupported bucket {bucket}")


def runtime_plusargs(case: dict) -> list[str]:
    bucket = case["bucket"]
    case_num = int(case["case_id"][1:])
    plusargs: list[str] = []

    if bucket == "PROF":
        plusargs.append(f"+ntb_random_seed={4096 + case_num}")
    if bucket == "ERROR" and case["runtime_test"] == "opq_error_ftable_overflow_test":
        plusargs.append("+OPQ_FTABLE_OVERFLOW_FRAME_COUNT=32")
    return plusargs


def bucket_case_ids(bucket_name: str, include_planned: bool = True) -> list[str]:
    case_ids: list[str] = []
    for case in parse_bucket(bucket_name):
        if not include_planned and case["implementation"].lower().startswith("planned"):
            continue
        case_ids.append(case["case_id"])
    return case_ids


def build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Parse packet_scheduler DV catalog markdown")
    parser.add_argument("--bucket", choices=sorted(BUCKET_SPECS))
    parser.add_argument("--case-id")
    parser.add_argument("--field")
    parser.add_argument("--ids", action="store_true", help="print only case ids")
    parser.add_argument(
        "--live-only",
        action="store_true",
        help="exclude rows whose implementation starts with 'planned'",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON")
    return parser


def main() -> int:
    parser = build_cli()
    args = parser.parse_args()

    if args.case_id:
        payload = find_case(args.case_id)
        if args.field:
            value = payload.get(args.field)
            if isinstance(value, list):
                print(" ".join(str(item) for item in value))
            elif value is None:
                raise SystemExit(f"unknown field {args.field}")
            else:
                print(value)
            return 0
    elif args.bucket:
        if args.ids:
            payload = bucket_case_ids(args.bucket, include_planned=not args.live_only)
        else:
            payload = parse_bucket(args.bucket)
            if args.live_only:
                payload = [
                    case for case in payload
                    if not case["implementation"].lower().startswith("planned")
                ]
    else:
        payload = parse_all_buckets()
        if args.live_only:
            payload = {
                bucket: [
                    case for case in cases
                    if not case["implementation"].lower().startswith("planned")
                ]
                for bucket, cases in payload.items()
            }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    if isinstance(payload, list):
        for item in payload:
            if isinstance(item, str):
                print(item)
            else:
                print(json.dumps(item, sort_keys=True))
        return 0

    if isinstance(payload, dict):
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

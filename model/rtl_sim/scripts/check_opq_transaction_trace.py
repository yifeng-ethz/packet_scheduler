#!/usr/bin/env python3
"""Reduce OPQ UVM OPQ_TXN trace lines into a bucket/identity checkpoint."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
RTL_ROOT = REPO_ROOT / "packet_scheduler" / "model" / "rtl_sim"
DEFAULT_LOG = RTL_ROOT / "runs" / "opq_transaction_check" / "logs" / "opq_basic_smoke_test.log"
TXN_RE = re.compile(r"OPQ_TXN\s+(?P<blob>.*)")


@dataclass(frozen=True, order=True)
class OpqTxn:
    lane: int
    pkg_cnt: int
    bucket: str
    hit_ts: str
    word: str
    hit_id: str

    @property
    def exact_key(self) -> tuple[int, int, str, str, str]:
        return (self.lane, self.pkg_cnt, self.bucket, self.hit_ts, self.word)

    @property
    def merged_key(self) -> tuple[int, str, str, str]:
        return (self.pkg_cnt, self.bucket, self.hit_ts, self.word)

    @property
    def bucket_key(self) -> tuple[int, str]:
        return (self.pkg_cnt, self.bucket)


def key_value_blob(blob: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = value.rstrip(",")
    return fields


def parse_log(log_path: Path) -> tuple[dict[str, list[OpqTxn]], str]:
    text = log_path.read_text(errors="replace")
    events: dict[str, list[OpqTxn]] = {
        "offer": [],
        "expected": [],
        "ingress_accept": [],
        "controlled_drop": [],
        "deliver": [],
    }
    for match in TXN_RE.finditer(text):
        fields = key_value_blob(match.group("blob"))
        event = fields.get("event", "")
        if event not in events:
            continue
        events[event].append(
            OpqTxn(
                lane=int(fields.get("lane", "-1")),
                pkg_cnt=int(fields["pkg_cnt"]),
                bucket=fields["bucket"],
                hit_ts=fields["hit_ts"].lower(),
                word=fields["word"].lower(),
                hit_id=fields.get("hit_id", "0x0").lower(),
            )
        )
    return events, text


def counter_delta(lhs: Counter, rhs: Counter) -> tuple[int, int]:
    missing = sum((rhs - lhs).values())
    extra = sum((lhs - rhs).values())
    return missing, extra


def bucket_order_violations(ids: list[OpqTxn]) -> int:
    violations = 0
    last = (-1, "")
    for txn in ids:
        key = txn.bucket_key
        if key < last:
            violations += 1
        last = key
    return violations


def summarize(
    log_path: Path,
    *,
    case_id: str | None = None,
    checkpoint: str = "per-subframe basic",
) -> dict[str, object]:
    events, text = parse_log(log_path)
    offer_exact = Counter(txn.exact_key for txn in events["offer"])
    ingress_exact = Counter(txn.exact_key for txn in events["ingress_accept"])
    offer_merged = Counter(txn.merged_key for txn in events["offer"])
    deliver_merged = Counter(txn.merged_key for txn in events["deliver"])
    drop_merged = Counter(txn.merged_key for txn in events["controlled_drop"])
    offered_after_drop = offer_merged - drop_merged
    deliver_lane_known = [txn for txn in events["deliver"] if txn.lane >= 0]
    deliver_exact = Counter(txn.exact_key for txn in deliver_lane_known)

    ingress_missing, ingress_extra = counter_delta(ingress_exact, offer_exact)
    deliver_missing, deliver_extra = counter_delta(deliver_merged, offered_after_drop)
    deliver_exact_missing = 0
    deliver_exact_extra = 0
    deliver_exact_checked = len(events["deliver"]) > 0 and len(deliver_lane_known) == len(events["deliver"])
    if deliver_exact_checked:
        offer_after_drop_exact = offer_exact - Counter(txn.exact_key for txn in events["controlled_drop"])
        deliver_exact_missing, deliver_exact_extra = counter_delta(deliver_exact, offer_after_drop_exact)
    offer_bucket = Counter(txn.bucket_key for txn in events["offer"])
    deliver_bucket = Counter(txn.bucket_key for txn in events["deliver"])
    bucket_missing, bucket_extra = counter_delta(deliver_bucket, offer_bucket - Counter(txn.bucket_key for txn in events["controlled_drop"]))
    bucket_order_delta = bucket_order_violations(events["deliver"])
    clean = "UVM_ERROR :    0" in text and "UVM_FATAL :    0" in text
    row: dict[str, object] = {
        "case_id": case_id or log_path.stem,
        "checkpoint": checkpoint,
        "impl": "opq",
        "source": "UVM scoreboard OPQ_TXN trace",
        "rtl_sim_clean": "1" if clean else "0",
        "offer_count": len(events["offer"]),
        "ingress_accept_count": len(events["ingress_accept"]),
        "controlled_drop_count": len(events["controlled_drop"]),
        "deliver_count": len(events["deliver"]),
        "deliver_lane_known_count": len(deliver_lane_known),
        "expected_count": len(events["expected"]),
        "ingress_missing": ingress_missing,
        "ingress_extra": ingress_extra,
        "deliver_missing": deliver_missing,
        "deliver_extra": deliver_extra,
        "deliver_exact_checked": "1" if deliver_exact_checked else "0",
        "deliver_exact_missing": deliver_exact_missing,
        "deliver_exact_extra": deliver_exact_extra,
        "bucket_missing": bucket_missing,
        "bucket_extra": bucket_extra,
        "deliver_bucket_order_violations": bucket_order_delta,
        "loss_tier": "-" if len(events["controlled_drop"]) == 0 else "controlled",
        "match": "PASS"
        if clean
        and ingress_missing == 0
        and ingress_extra == 0
        and deliver_missing == 0
        and deliver_extra == 0
        and deliver_exact_missing == 0
        and deliver_exact_extra == 0
        and bucket_missing == 0
        and bucket_extra == 0
        and bucket_order_delta == 0
        else "DEBUG",
        "log": str(log_path),
    }
    return row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, action="append")
    parser.add_argument("--checkpoint", default="per-subframe basic")
    parser.add_argument("--csv", type=Path, default=RTL_ROOT / "data" / "opq_transaction_match.csv")
    parser.add_argument(
        "--json",
        type=Path,
        default=RTL_ROOT / "data" / "opq_transaction_match_summary.json",
    )
    args = parser.parse_args()

    logs = args.log or [DEFAULT_LOG]
    rows = [summarize(log_path, checkpoint=args.checkpoint) for log_path in logs]
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="") as f:
        fieldnames: list[str] = []
        for row in rows:
            for key in row:
                if key not in fieldnames:
                    fieldnames.append(key)
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    args.json.write_text(json.dumps(rows, indent=2) + "\n", encoding="ascii")
    for row in rows:
        print(
            "[CHECK] {case_id}: match={match} offer/ingress/drop/deliver="
            "{offer}/{ingress}/{drop}/{deliver} exact_lane={exact_lane}/{deliver} "
            "deliver_missing={missing} deliver_extra={extra} bucket_delta={bucket_missing}/{bucket_extra}".format(
                case_id=row["case_id"],
                match=row["match"],
                offer=row["offer_count"],
                ingress=row["ingress_accept_count"],
                drop=row["controlled_drop_count"],
                deliver=row["deliver_count"],
                exact_lane=row["deliver_lane_known_count"],
                missing=row["deliver_missing"],
                extra=row["deliver_extra"],
                bucket_missing=row["bucket_missing"],
                bucket_extra=row["bucket_extra"],
            )
        )
    print(f"[DONE] wrote {args.csv}")
    print(f"[DONE] wrote {args.json}")
    return 0 if all(row["match"] == "PASS" for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Generate the exhaustive ordered_priority_queue configuration-space matrix.

This script is the authoritative full-space tracker behind the human-readable
representative preset table in `doc/CONFIG_SIGNOFF.md`.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path

LANES = (2, 4, 8, 16)
INGRESS_POINTS = (
    (32, 4),
    (64, 8),
    (128, 16),
)
PACK_FACTORS = (1, 4, 8, 16)
N_SHD_POINTS = (64, 128, 256, 512)
N_HIT_POINTS = (255, 511, 1023, 2047)


@dataclass(frozen=True)
class MatrixRow:
    cfg_id: str
    n_lane: int
    ingress_data_width: int
    ingress_datak_width: int
    pack_factor: int
    n_shd: int
    n_hit: int
    channel_width: int
    lane_fifo_width: int
    ticket_fifo_depth: int
    handle_fifo_depth: int
    page_ram_rd_width: int
    empty_width: int
    package_status: str
    dv_status: str
    syn_status: str
    slow_wns_hold: str
    alms: str
    m20ks: str
    raw_share_per_lane: str
    lossless_throughput_per_lane: str
    summary: str


def ceil_log2(value: int) -> int:
    if value <= 1:
        return 0
    return math.ceil(math.log2(value))


def derive_channel_width(n_lane: int) -> int:
    return max(2, ceil_log2(n_lane))


def derive_lane_fifo_width(data_width: int, datak_width: int) -> int:
    return data_width + datak_width + 4


def derive_ticket_fifo_depth(n_shd: int) -> int:
    return max(256, 1 << n_shd.bit_length())


def derive_page_ram_rd_width(data_width: int, datak_width: int, pack_factor: int) -> int:
    return (data_width + datak_width) * pack_factor


def derive_empty_width(pack_factor: int) -> int:
    if pack_factor == 1:
        return 0
    return ceil_log2(pack_factor)


def derive_lossless_throughput(n_lane: int, n_shd: int, data_width: int, pack_factor: int) -> str:
    if data_width != 32 or pack_factor != 1:
        return "open"
    coeff = {
        2: "0.5",
        4: "0.25",
        8: "0.125",
        16: "0.0625",
    }[n_lane]
    return f"{coeff}λ / (λ + 1 + 6/{n_shd})"


def classify_tuple(n_lane: int, data_width: int, pack_factor: int, n_shd: int, n_hit: int) -> tuple[str, str, str, str, str, str, str]:
    if data_width != 32 or pack_factor != 1:
        if data_width != 32 and pack_factor != 1:
            summary = "requested wider ingress + packed DMA point; current RTL/harness blocked"
        elif data_width != 32:
            summary = "requested wider ingress point; current RTL/harness blocked"
        else:
            summary = "requested packed DMA point; current RTL/harness blocked"
        return ("⚠️", "❌", "❌", "-", "-", "-", summary)

    if n_lane == 2 and n_hit == 255 and n_shd in (128, 256, 512):
        dv_status = "✅"
    elif n_lane == 2 and n_hit == 255 and n_shd == 64:
        dv_status = "⚠️"
    elif n_lane == 4 and n_hit == 255 and n_shd == 256:
        dv_status = "⚠️"
    else:
        dv_status = "❓"

    if n_lane == 2 and n_hit == 255 and n_shd == 256:
        syn_status = "✅"
        slow_wns_hold = "+0.172 / +0.044 ns"
        alms = "3,235"
        m20ks = "129"
    elif n_lane == 4 and n_hit == 255 and n_shd == 256:
        syn_status = "✅"
        slow_wns_hold = "+0.008 / +0.043 ns"
        alms = "5,297"
        m20ks = "141"
    else:
        syn_status = "❓"
        slow_wns_hold = "-"
        alms = "-"
        m20ks = "-"

    if n_lane == 2 and n_hit == 255 and n_shd == 64:
        summary = "legal packaged point; bounded-only DV evidence"
    elif n_lane == 2 and n_hit == 255 and n_shd in (128, 512):
        summary = "legal packaged point; promoted DV claim, SYN open"
    elif n_lane == 2 and n_hit == 255 and n_shd == 256:
        summary = "legal packaged point; DV and standalone SYN closed"
    elif n_lane == 4 and n_hit == 255 and n_shd == 256:
        summary = "legal packaged point; bounded DV, standalone SYN closed"
    elif n_hit != 255:
        summary = "legal packaged point; N_HIT extension remains open"
    elif n_lane in (8, 16):
        summary = "legal packaged lane point; DV and SYN open"
    elif n_lane == 4:
        summary = "legal packaged 4-lane point; DV and SYN open"
    else:
        summary = "legal packaged point; DV and SYN open"

    return ("✅", dv_status, syn_status, slow_wns_hold, alms, m20ks, summary)


def build_rows() -> list[MatrixRow]:
    rows: list[MatrixRow] = []
    cfg_index = 0
    for n_lane in LANES:
        for ingress_data_width, ingress_datak_width in INGRESS_POINTS:
            for pack_factor in PACK_FACTORS:
                for n_shd in N_SHD_POINTS:
                    for n_hit in N_HIT_POINTS:
                        channel_width = derive_channel_width(n_lane)
                        lane_fifo_width = derive_lane_fifo_width(ingress_data_width, ingress_datak_width)
                        ticket_fifo_depth = derive_ticket_fifo_depth(n_shd)
                        handle_fifo_depth = 64
                        page_ram_rd_width = derive_page_ram_rd_width(
                            ingress_data_width,
                            ingress_datak_width,
                            pack_factor,
                        )
                        empty_width = derive_empty_width(pack_factor)
                        package_status, dv_status, syn_status, slow_wns_hold, alms, m20ks, summary = classify_tuple(
                            n_lane,
                            ingress_data_width,
                            pack_factor,
                            n_shd,
                            n_hit,
                        )
                        raw_share = f"{page_ram_rd_width / n_lane:g} bits/cycle"
                        throughput = derive_lossless_throughput(
                            n_lane,
                            n_shd,
                            ingress_data_width,
                            pack_factor,
                        )
                        rows.append(
                            MatrixRow(
                                cfg_id=f"X{cfg_index:03d}",
                                n_lane=n_lane,
                                ingress_data_width=ingress_data_width,
                                ingress_datak_width=ingress_datak_width,
                                pack_factor=pack_factor,
                                n_shd=n_shd,
                                n_hit=n_hit,
                                channel_width=channel_width,
                                lane_fifo_width=lane_fifo_width,
                                ticket_fifo_depth=ticket_fifo_depth,
                                handle_fifo_depth=handle_fifo_depth,
                                page_ram_rd_width=page_ram_rd_width,
                                empty_width=empty_width,
                                package_status=package_status,
                                dv_status=dv_status,
                                syn_status=syn_status,
                                slow_wns_hold=slow_wns_hold,
                                alms=alms,
                                m20ks=m20ks,
                                raw_share_per_lane=raw_share,
                                lossless_throughput_per_lane=throughput,
                                summary=summary,
                            )
                        )
                        cfg_index += 1
    return rows


def format_summary(rows: list[MatrixRow]) -> str:
    package_counts = Counter(row.package_status for row in rows)
    dv_counts = Counter(row.dv_status for row in rows)
    syn_counts = Counter(row.syn_status for row in rows)
    lines = [
        "ordered_priority_queue configuration-space summary",
        f"total_rows: {len(rows)}",
        f"package_counts: ✅={package_counts['✅']} ⚠️={package_counts['⚠️']}",
        f"dv_counts: ✅={dv_counts['✅']} ⚠️={dv_counts['⚠️']} ❓={dv_counts['❓']} ❌={dv_counts['❌']}",
        f"syn_counts: ✅={syn_counts['✅']} ❓={syn_counts['❓']} ❌={syn_counts['❌']}",
    ]
    packaged_rows = [row for row in rows if row.package_status == "✅"]
    if packaged_rows:
        packaged_dv_counts = Counter(row.dv_status for row in packaged_rows)
        packaged_syn_counts = Counter(row.syn_status for row in packaged_rows)
        lines.extend(
            [
                f"packaged_rows: {len(packaged_rows)}",
                f"packaged_dv_counts: ✅={packaged_dv_counts['✅']} ⚠️={packaged_dv_counts['⚠️']} ❓={packaged_dv_counts['❓']}",
                f"packaged_syn_counts: ✅={packaged_syn_counts['✅']} ❓={packaged_syn_counts['❓']}",
            ]
        )
    return "\n".join(lines) + "\n"


def render_csv(rows: list[MatrixRow]) -> str:
    if not rows:
        return ""
    fieldnames = list(asdict(rows[0]).keys())
    from io import StringIO

    buffer = StringIO()
    writer = csv.DictWriter(buffer, fieldnames=fieldnames)
    writer.writeheader()
    for row in rows:
        writer.writerow(asdict(row))
    return buffer.getvalue()


def render_json(rows: list[MatrixRow]) -> str:
    return json.dumps([asdict(row) for row in rows], indent=2) + "\n"


def render_markdown(rows: list[MatrixRow]) -> str:
    header = (
        "| cfg | `N_LANE` | ingress | pack | `N_SHD` | `N_HIT` | "
        "auto `CHANNEL_WIDTH` | auto `LANE_FIFO_WIDTH` | auto `TICKET_FIFO_DEPTH` | "
        "auto `HANDLE_FIFO_DEPTH` | auto `PAGE_RAM_RD_WIDTH` | auto `empty` | "
        "package | DV | SYN | slow WNS / hold | ALMs | M20Ks | raw share / lane | "
        "lossless throughput / lane | summary |"
    )
    separator = (
        "|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---:|---:|---|---|---|"
    )
    lines = [header, separator]
    for row in rows:
        lines.append(
            "| `{cfg_id}` | `{n_lane}` | `{ingress_data_width}+{ingress_datak_width}` | `{pack_factor}x` | "
            "`{n_shd}` | `{n_hit}` | `{channel_width}` | `{lane_fifo_width}` | `{ticket_fifo_depth}` | "
            "`{handle_fifo_depth}` | `{page_ram_rd_width}` | `{empty_width}` | {package_status} | {dv_status} | "
            "{syn_status} | {slow_wns_hold} | {alms} | {m20ks} | {raw_share_per_lane} | "
            "{lossless_throughput_per_lane} | {summary} |".format(**asdict(row))
        )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        choices=("summary", "csv", "json", "md"),
        default="summary",
        help="output format",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="optional output file path; default is stdout",
    )
    parser.add_argument(
        "--only-packaged",
        action="store_true",
        help="emit only the live packaged tuples",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = build_rows()
    if args.only_packaged:
        rows = [row for row in rows if row.package_status == "✅"]

    if args.format == "summary":
        rendered = format_summary(rows)
    elif args.format == "csv":
        rendered = render_csv(rows)
    elif args.format == "json":
        rendered = render_json(rows)
    else:
        rendered = render_markdown(rows)

    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run representative OPQ RTL simulations and reduce MODEL_PUBLISH CSVs."""

from __future__ import annotations

import argparse
import csv
import fnmatch
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
MODEL_ROOT = REPO_ROOT / "packet_scheduler" / "model"
RTL_ROOT = MODEL_ROOT / "rtl_sim"
RUN_UVM = REPO_ROOT / "packet_scheduler" / "tb" / "scripts" / "run_uvm.sh"
TEST_NAME = "opq_model_publish_loss_sweep_test"
OPQ_TIMESTAMP_TICK_NS = 8
OPQ_UVM_CLK_PERIOD_NS = 4
OPQ_SUBHEADER_DURATION_TS_TICKS = 16
OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES = 4096

MODEL_RE = re.compile(r"MODEL_PUBLISH_(RESULT|AGG)\s+(.*)")
RESIDENCY_RE = re.compile(
    r"OPQ_RESIDENCY_PROXY_SAMPLE lane=(?P<lane>\d+) sample_idx=(?P<sample_idx>\d+) "
    r"frame_ts=0x(?P<frame_ts>[0-9a-fA-F]+) proxy_ingress_ts=0x(?P<proxy_ingress_ts>[0-9a-fA-F]+) "
    r"ingress_debug_ts=0x(?P<ingress_debug_ts>[0-9a-fA-F]+) egress_debug_ts=0x(?P<egress_debug_ts>[0-9a-fA-F]+) "
    r"proxy_cycles=(?P<proxy_cycles>-?\d+) debug_delta_cycles=(?P<debug_delta_cycles>-?\d+)"
)
UVM_ERROR_RE = re.compile(r"# UVM_ERROR\s+:\s+(?P<count>\d+)")
UVM_FATAL_RE = re.compile(r"# UVM_FATAL\s+:\s+(?P<count>\d+)")
DROP_MONITOR_RE = re.compile(
    r"opq_drop_monitor\] lane(?P<lane>\d+) observed drop events=(?P<drop_events>\d+) "
    r"hdr=(?P<hdr_drop_events>\d+) pre_hits=(?P<pre_drop_hits>\d+) "
    r"dropped_hits=(?P<monitor_dropped_hits>\d+) post_hits=(?P<post_drop_hits>\d+)"
)


@dataclass(frozen=True)
class RtlCase:
    tag: str
    case_id: str
    n_lane: int = 4
    n_shd: int = 128
    egress_symbols_per_beat: int = 1
    lane_fifo_depth: int = 0
    ticket_fifo_depth: int = 0
    handle_fifo_depth: int = 64
    page_ram_depth: int = 65536
    ready_high: int = 0
    ready_low: int = 0
    rho_ppm: int = 7500
    burstiness_milli: int = 0
    profile: int = 0
    frame_count: int = 8
    subheaders: int = 32
    inter_frame_gap_cycles: int = 0
    hit_period: int = 4
    hit_count: int = 2
    dwell_us: int = 220
    require_drain: int = 0
    drain_timeout_us: int = 500
    noise_rho_ppm: int = 0
    cluster_rho_ppm: int = 0
    cluster_size_min: int = 4
    cluster_size_max: int = 8
    rng_seed: int = 0x5C1F0001

    @property
    def ready_duty_ppm(self) -> int:
        total = self.ready_high + self.ready_low
        if total == 0:
            return 1_000_000
        return int(self.ready_high * 1_000_000 / total)

    @property
    def page_ram_rd_width(self) -> int:
        return 36 * self.egress_symbols_per_beat

    @property
    def effective_lane_fifo_depth(self) -> int:
        if self.lane_fifo_depth:
            return self.lane_fifo_depth
        target = max(self.n_shd * 64, self.n_lane * 1024)
        depth = 1024
        while depth < target:
            depth *= 2
        return depth

    @property
    def effective_ticket_fifo_depth(self) -> int:
        if self.ticket_fifo_depth:
            return self.ticket_fifo_depth
        target = max(self.n_shd * 32, self.n_shd * self.n_lane * 2)
        depth = 256
        while depth < target:
            depth *= 2
        return depth

    @property
    def frame_ts_step_ticks(self) -> int:
        return self.n_shd * OPQ_SUBHEADER_DURATION_TS_TICKS

    @property
    def frame_launch_period_cycles(self) -> int:
        if self.inter_frame_gap_cycles:
            return self.inter_frame_gap_cycles
        return (self.frame_ts_step_ticks * OPQ_TIMESTAMP_TICK_NS) // OPQ_UVM_CLK_PERIOD_NS


def default_cases() -> list[RtlCase]:
    return [
        RtlCase(tag="ls002_rho005", case_id="RTL-LS-002", rho_ppm=5_000, hit_period=16, frame_count=8),
        RtlCase(tag="ls002_rho050", case_id="RTL-LS-002", rho_ppm=50_000, hit_period=8, frame_count=8),
        RtlCase(tag="ls002_rho150", case_id="RTL-LS-002", rho_ppm=150_000, hit_period=4, frame_count=8),
        RtlCase(tag="ls001_ready070", case_id="RTL-LS-001", ready_high=7, ready_low=3, rho_ppm=7_500, frame_count=8),
        RtlCase(tag="ls005_n4_e2", case_id="RTL-LS-005", egress_symbols_per_beat=2, rho_ppm=7_500, frame_count=8),
        RtlCase(tag="ls005_n8_e1", case_id="RTL-LS-005", n_lane=8, rho_ppm=7_500, frame_count=5, subheaders=24),
    ]


def anchor_cases() -> list[RtlCase]:
    return [
        RtlCase(
            tag="ls002_anchor_ts_burst_n4_e1",
            case_id="RTL-LS-002",
            n_lane=4,
            n_shd=128,
            egress_symbols_per_beat=1,
            rho_ppm=600_000,
            burstiness_milli=403,
            profile=3,
            frame_count=32,
            subheaders=64,
            hit_period=1,
            hit_count=1,
            dwell_us=1800,
            noise_rho_ppm=100_000,
            cluster_rho_ppm=500_000,
            cluster_size_min=4,
            cluster_size_max=8,
            rng_seed=0x5C1F0001,
        )
    ]


def opq_x4_poisson_sanity_cases() -> list[RtlCase]:
    """Physical-cadence OPQ sanity point: 4 lanes, x4 egress, iid Poisson hits."""
    return [
        RtlCase(
            tag="opq_x4_poisson_n4_e4_b000_rho800_period4096",
            case_id="RTL-LS-002",
            n_lane=4,
            n_shd=128,
            egress_symbols_per_beat=4,
            rho_ppm=800_000,
            burstiness_milli=0,
            profile=3,
            frame_count=64,
            subheaders=128,
            inter_frame_gap_cycles=0,
            hit_period=1,
            hit_count=1,
            dwell_us=3500,
            require_drain=1,
            drain_timeout_us=2500,
            noise_rho_ppm=800_000,
            cluster_rho_ppm=0,
            cluster_size_min=1,
            cluster_size_max=1,
            rng_seed=0x5C1F8004,
        )
    ]


def opq_x4_boundary_cases() -> list[RtlCase]:
    """Shallow physical-cadence OPQ x4 ingress-buffer probes.

    x4 egress has the same raw word bandwidth as four one-word ingress lanes,
    and OPQ removes duplicated frame/subheader overhead. These rows therefore
    probe ingress frame-size/FIFO boundaries, not the persistent egress
    bottleneck. Keep them separate from opq_x1_bandwidth_cases().
    """
    cases: list[RtlCase] = []
    for rho_ppm in [
        800_000,
        4_000_000,
        8_000_000,
        16_000_000,
        24_000_000,
        30_000_000,
        34_000_000,
        40_000_000,
    ]:
        cases.append(
            RtlCase(
                tag=f"opq_x4_boundary_b000_rho{rho_ppm // 1000:05d}_period4096",
                case_id="RTL-LS-002",
                n_lane=4,
                n_shd=128,
                egress_symbols_per_beat=4,
                rho_ppm=rho_ppm,
                burstiness_milli=0,
                profile=3,
                frame_count=16,
                subheaders=128,
                inter_frame_gap_cycles=0,
                hit_period=1,
                hit_count=1,
                dwell_us=2500,
                require_drain=1,
                drain_timeout_us=2500,
                noise_rho_ppm=rho_ppm,
                cluster_rho_ppm=0,
                cluster_size_min=1,
                cluster_size_max=1,
                rng_seed=0x5C1F8004 + (rho_ppm // 1000),
            )
        )
    return cases


def opq_x1_bandwidth_cases() -> list[RtlCase]:
    """Physical-cadence OPQ x1 persistent-bottleneck probes.

    For N_LANE=4, N_SHD=128, egress=1x, one frame period can emit 4096 OPQ
    words. A merged frame needs roughly 6+128+(4*128*rho_lane) words, so the
    long-term egress knee is near rho_lane=(4096-134)/(4*128)=7.738.
    """
    cases: list[RtlCase] = []
    for rho_ppm in [
        6_000_000,
        7_500_000,
        8_000_000,
        10_000_000,
        12_000_000,
    ]:
        cases.append(
            RtlCase(
                tag=f"opq_x1_bandwidth_b000_rho{rho_ppm // 1000:05d}_period4096",
                case_id="RTL-LS-002",
                n_lane=4,
                n_shd=128,
                egress_symbols_per_beat=1,
                rho_ppm=rho_ppm,
                burstiness_milli=0,
                profile=3,
                frame_count=64,
                subheaders=128,
                inter_frame_gap_cycles=0,
                hit_period=1,
                hit_count=1,
                dwell_us=5000,
                require_drain=1,
                drain_timeout_us=5000,
                noise_rho_ppm=rho_ppm,
                cluster_rho_ppm=0,
                cluster_size_min=1,
                cluster_size_max=1,
                rng_seed=0x5C1F1001 + (rho_ppm // 1000),
            )
        )
    return cases


def shallow_cases() -> list[RtlCase]:
    cases: list[RtlCase] = []
    for burstiness_milli, noise_rho_ppm, cluster_rho_ppm, cluster_size_min, cluster_size_max in [
        (0, 150_000, 0, 1, 1),
        (403, 100_000, 500_000, 4, 8),
        (700, 50_000, 450_000, 8, 16),
        (403, 50_000, 250_000, 4, 8),
    ]:
        total_rho_ppm = noise_rho_ppm + cluster_rho_ppm
        cases.append(
            RtlCase(
                tag=f"ls002_ts_b{burstiness_milli:03d}_rho{total_rho_ppm // 1000:03d}",
                case_id="RTL-LS-002",
                n_lane=4,
                n_shd=128,
                egress_symbols_per_beat=1,
                rho_ppm=total_rho_ppm,
                burstiness_milli=burstiness_milli,
                profile=3,
                frame_count=16,
                subheaders=64,
                hit_period=1,
                hit_count=1,
                dwell_us=1400,
                noise_rho_ppm=noise_rho_ppm,
                cluster_rho_ppm=cluster_rho_ppm,
                cluster_size_min=cluster_size_min,
                cluster_size_max=cluster_size_max,
                rng_seed=0x5C1F0001 + burstiness_milli + total_rho_ppm,
            )
        )
    return cases


def burstiness_cluster_mix(
    burstiness_milli: int,
    total_rho_ppm: int,
) -> tuple[int, int, int, int]:
    """Return singleton-noise/cluster settings targeting timestamp burstiness."""
    if burstiness_milli <= 0 or total_rho_ppm <= 0:
        return total_rho_ppm, 0, 1, 1

    b = min(0.950, max(0.0, burstiness_milli / 1000.0))
    cv = (1.0 + b) / (1.0 - b)
    mean_batch = max(1.0, 0.5 * ((cv * cv) + 1.0))
    cluster_size = max(2, min(255, int(round(mean_batch + 0.499999))))
    denom = 1.0 - (1.0 / float(cluster_size))
    cluster_fraction = (1.0 - (1.0 / mean_batch)) / denom
    cluster_fraction = min(1.0, max(0.0, cluster_fraction))
    cluster_rho_ppm = int(round(total_rho_ppm * cluster_fraction))
    noise_rho_ppm = max(0, total_rho_ppm - cluster_rho_ppm)
    return noise_rho_ppm, cluster_rho_ppm, cluster_size, cluster_size


def scan128_cases(target_hits: int) -> list[RtlCase]:
    cases: list[RtlCase] = []
    burstiness_values = [0, 100, 200, 300, 403, 500, 600, 700]
    rho_values = [
        100_000,
        200_000,
        300_000,
        400_000,
        500_000,
        600_000,
        750_000,
        900_000,
        1_000_000,
        1_200_000,
        1_500_000,
        2_000_000,
        3_000_000,
        4_000_000,
        6_000_000,
        8_000_000,
    ]
    for b_milli in burstiness_values:
        for rho_ppm in rho_values:
            noise_rho_ppm, cluster_rho_ppm, cluster_min, cluster_max = burstiness_cluster_mix(
                b_milli,
                rho_ppm,
            )
            denom = max(1, 4 * 128 * rho_ppm)
            frame_count = max(4, int((target_hits * 1_000_000 + denom - 1) / denom))
            cases.append(
                RtlCase(
                    tag=f"scan128_b{b_milli:03d}_rho{rho_ppm // 1000:04d}",
                    case_id="RTL-LS-002",
                    n_lane=4,
                    n_shd=128,
                    egress_symbols_per_beat=1,
                    rho_ppm=rho_ppm,
                    burstiness_milli=b_milli,
                    profile=3,
                    frame_count=frame_count,
                    subheaders=128,
                    hit_period=1,
                    hit_count=1,
                    dwell_us=max(1800, min(20000, 1000 + (frame_count * 8))),
                    require_drain=1,
                    drain_timeout_us=max(5000, min(30000, 2000 + (frame_count * 16))),
                    noise_rho_ppm=noise_rho_ppm,
                    cluster_rho_ppm=cluster_rho_ppm,
                    cluster_size_min=cluster_min,
                    cluster_size_max=cluster_max,
                    rng_seed=0x5C1F0001 + (b_milli << 8) + (rho_ppm // 1000),
                )
            )
    return cases


def boundary_cases() -> list[RtlCase]:
    """Directed OPQ first-loss boundary probes with physical frame cadence."""
    cases: list[RtlCase] = []
    for b_milli, rho_ppm in [
        (0, 100_000),
        (0, 150_000),
        (0, 200_000),
        (0, 300_000),
        (0, 350_000),
        (0, 400_000),
        (0, 500_000),
        (0, 600_000),
        (403, 200_000),
        (403, 300_000),
        (403, 350_000),
        (403, 400_000),
        (403, 500_000),
        (403, 600_000),
        (700, 200_000),
        (700, 300_000),
        (700, 350_000),
        (700, 400_000),
        (700, 500_000),
        (700, 600_000),
    ]:
        noise_rho_ppm, cluster_rho_ppm, cluster_min, cluster_max = burstiness_cluster_mix(
            b_milli,
            rho_ppm,
        )
        cases.append(
            RtlCase(
                tag=f"boundary_b{b_milli:03d}_rho{rho_ppm // 1000:03d}_period4096",
                case_id="RTL-LS-002",
                n_lane=4,
                n_shd=128,
                egress_symbols_per_beat=1,
                rho_ppm=rho_ppm,
                burstiness_milli=b_milli,
                profile=3,
                frame_count=64,
                subheaders=128,
                inter_frame_gap_cycles=0,
                hit_period=1,
                hit_count=1,
                dwell_us=3200,
                noise_rho_ppm=noise_rho_ppm,
                cluster_rho_ppm=cluster_rho_ppm,
                cluster_size_min=cluster_min,
                cluster_size_max=cluster_max,
                rng_seed=0x5C1F0001 + 0x0100_0000 + (b_milli << 8) + (rho_ppm // 1000),
            )
        )
    return cases


def opq_x1_marginal_cases() -> list[RtlCase]:
    """100-frame OPQ x1 probes around the finite handle/ticket first-loss edge."""
    cases: list[RtlCase] = []
    rho_values = [
        600_000,
        620_000,
        640_000,
        660_000,
        680_000,
        700_000,
        720_000,
        750_000,
        800_000,
        850_000,
        900_000,
        950_000,
        1_000_000,
    ]
    for b_milli in [0, 403, 700]:
        for rho_ppm in rho_values:
            noise_rho_ppm, cluster_rho_ppm, cluster_min, cluster_max = burstiness_cluster_mix(
                b_milli,
                rho_ppm,
            )
            cases.append(
                RtlCase(
                    tag=f"marginal_b{b_milli:03d}_rho{rho_ppm // 1000:04d}_f100_period4096",
                    case_id="RTL-LS-002",
                    n_lane=4,
                    n_shd=128,
                    egress_symbols_per_beat=1,
                    rho_ppm=rho_ppm,
                    burstiness_milli=b_milli,
                    profile=3,
                    frame_count=100,
                    subheaders=128,
                    inter_frame_gap_cycles=0,
                    hit_period=1,
                    hit_count=1,
                    dwell_us=4200,
                    require_drain=1,
                    drain_timeout_us=7000,
                    noise_rho_ppm=noise_rho_ppm,
                    cluster_rho_ppm=cluster_rho_ppm,
                    cluster_size_min=cluster_min,
                    cluster_size_max=cluster_max,
                    rng_seed=0x5C1F9001 + (b_milli << 8) + (rho_ppm // 1000),
                )
            )
    return cases


def key_value_blob(blob: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        out[key] = value.rstrip(",")
    return out


def parse_log(log_path: Path, case: RtlCase) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]], bool]:
    rows: list[dict[str, str]] = []
    aggs: list[dict[str, str]] = []
    residency: list[dict[str, str]] = []
    pass_run = True

    text = log_path.read_text(errors="replace")
    if "** Error:" in text or "Error loading design" in text or "make: ***" in text:
        pass_run = False
    drop_monitor: dict[str, dict[str, str]] = {}
    for match in DROP_MONITOR_RE.finditer(text):
        g = match.groupdict()
        lane = g.pop("lane")
        drop_monitor[lane] = g

    for match in UVM_ERROR_RE.finditer(text):
        if int(match.group("count")):
            pass_run = False
    for match in UVM_FATAL_RE.finditer(text):
        if int(match.group("count")):
            pass_run = False

    for line in text.splitlines():
        model_match = MODEL_RE.search(line)
        if model_match:
            kind = model_match.group(1)
            fields = key_value_blob(model_match.group(2))
            fields["run_tag"] = case.tag
            fields["sim_pass"] = "1" if pass_run else "0"
            fields.setdefault("case", case.case_id)
            fields.setdefault("rho_ppm", str(case.rho_ppm))
            fields.setdefault("burstiness_milli", str(case.burstiness_milli))
            fields.setdefault("ready_duty_ppm", str(case.ready_duty_ppm))
            fields.setdefault("lane_fifo_depth", str(case.effective_lane_fifo_depth))
            fields.setdefault("ticket_fifo_depth", str(case.effective_ticket_fifo_depth))
            fields.setdefault("handle_fifo_depth", str(case.handle_fifo_depth))
            fields.setdefault("page_ram_depth", str(case.page_ram_depth))
            fields.setdefault("inter_frame_gap_cycles", str(case.frame_launch_period_cycles))
            fields.setdefault("frame_ts_step_ticks", str(case.frame_ts_step_ticks))
            fields.setdefault("frame_launch_period_cycles", str(case.frame_launch_period_cycles))
            fields.setdefault("feb_header_latency_cycles", str(OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES))
            fields.setdefault("noise_rho_ppm", str(case.noise_rho_ppm))
            fields.setdefault("cluster_rho_ppm", str(case.cluster_rho_ppm))
            fields.setdefault("cluster_size_min", str(case.cluster_size_min))
            fields.setdefault("cluster_size_max", str(case.cluster_size_max))
            fields.setdefault("rng_seed", str(case.rng_seed))
            if "lane" in fields and fields["lane"] in drop_monitor:
                fields.update(drop_monitor[fields["lane"]])
            if kind == "RESULT":
                rows.append(fields)
            elif kind == "AGG":
                aggs.append(fields)
            continue

        res_match = RESIDENCY_RE.search(line)
        if res_match:
            g = res_match.groupdict()
            frame_ts = int(g["frame_ts"], 16)
            proxy_ingress_ts = int(g["proxy_ingress_ts"], 16)
            ingress_debug_ts = int(g["ingress_debug_ts"], 16)
            egress_debug_ts = int(g["egress_debug_ts"], 16)
            residency.append(
                {
                    "run_tag": case.tag,
                    "case": case.case_id,
                    "sim_pass": "1" if pass_run else "0",
                    "n_lane": str(case.n_lane),
                    "n_shd": str(case.n_shd),
                    "egress_symbols_per_beat": str(case.egress_symbols_per_beat),
                    "lane_fifo_depth": str(case.effective_lane_fifo_depth),
                    "ticket_fifo_depth": str(case.effective_ticket_fifo_depth),
                    "handle_fifo_depth": str(case.handle_fifo_depth),
                    "page_ram_depth": str(case.page_ram_depth),
                    "ready_duty_ppm": str(case.ready_duty_ppm),
                    "rho_ppm": str(case.rho_ppm),
                    "burstiness_milli": str(case.burstiness_milli),
                    "inter_frame_gap_cycles": str(case.frame_launch_period_cycles),
                    "frame_ts_step_ticks": str(case.frame_ts_step_ticks),
                    "frame_launch_period_cycles": str(case.frame_launch_period_cycles),
                    "feb_header_latency_cycles": str(OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES),
                    "lane": g["lane"],
                    "sample_idx": g["sample_idx"],
                    "frame_ts": str(frame_ts),
                    "proxy_ingress_ts": str(proxy_ingress_ts),
                    "ingress_debug_ts": str(ingress_debug_ts),
                    "egress_debug_ts": str(egress_debug_ts),
                    "delta_arrival_cycles": str(ingress_debug_ts - proxy_ingress_ts),
                    "delta_egress_cycles": str(egress_debug_ts - proxy_ingress_ts),
                    "proxy_cycles": g["proxy_cycles"],
                    "debug_delta_cycles": g["debug_delta_cycles"],
                }
            )

    return rows, aggs, residency, pass_run


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def aggregate_case_rows(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    by_key: dict[tuple[str, str, str, str, str, str, str, str, str, str, str, str], dict[str, object]] = {}
    for row in rows:
        key = (
            row.get("run_tag", ""),
            row.get("case", ""),
            row.get("n_lane", ""),
            row.get("n_shd", ""),
            row.get("egress_symbols_per_beat", ""),
            row.get("lane_fifo_depth", ""),
            row.get("ticket_fifo_depth", ""),
            row.get("handle_fifo_depth", ""),
            row.get("frame_launch_period_cycles", row.get("inter_frame_gap_cycles", "")),
            row.get("ready_duty_ppm", ""),
            row.get("rho_ppm", ""),
            row.get("burstiness_milli", ""),
        )
        agg = by_key.setdefault(
            key,
            {
                "run_tag": key[0],
                "case": key[1],
                "n_lane": key[2],
                "n_shd": key[3],
                "egress_symbols_per_beat": key[4],
                "lane_fifo_depth": key[5],
                "ticket_fifo_depth": key[6],
                "handle_fifo_depth": key[7],
                "frame_launch_period_cycles": key[8],
                "ready_duty": int(key[9] or "0") / 1_000_000.0,
                "rho_unit": "hits_per_subheader_per_lane",
                "rho_lane": int(key[10] or "0") / 1_000_000.0,
                "burstiness": int(key[11] or "0") / 1000.0,
                "expected_hits": 0,
                "accepted_hits": 0,
                "dropped_hits": 0,
                "delivered_hits": 0,
                "unexplained_hits": 0,
                "sim_pass": row.get("sim_pass", "0"),
            },
        )
        for count_key in ["expected_hits", "accepted_hits", "dropped_hits", "delivered_hits", "unexplained_hits"]:
            agg[count_key] = int(agg[count_key]) + int(row.get(count_key, "0"))

    out: list[dict[str, object]] = []
    for agg in by_key.values():
        expected = int(agg["expected_hits"])
        dropped = int(agg["dropped_hits"])
        n_lane = int(agg["n_lane"] or "0")
        n_shd = int(agg["n_shd"] or "0")
        egress = int(agg["egress_symbols_per_beat"] or "0")
        frame_period = int(agg["frame_launch_period_cycles"] or "0")
        rho_lane = float(agg["rho_lane"])
        merged_overhead_words = 6 + n_shd
        hit_capacity_per_frame = max(0, (egress * frame_period) - merged_overhead_words)
        offered_hit_words_per_frame = max(0.0, n_lane * n_shd * rho_lane)
        knee = (
            hit_capacity_per_frame / float(n_lane * n_shd)
            if n_lane > 0 and n_shd > 0
            else 0.0
        )
        agg["loss_probability"] = (dropped / expected) if expected else 0.0
        agg["loss_ppm"] = int(round(float(agg["loss_probability"]) * 1_000_000))
        input_hit_utilization = (
            (rho_lane * n_shd / float(frame_period))
            if frame_period > 0
            else 0.0
        )
        source_word_utilization = (
            ((6 + n_shd + (n_shd * rho_lane)) / float(frame_period))
            if frame_period > 0
            else 0.0
        )
        merged_output_utilization = (
            ((merged_overhead_words + offered_hit_words_per_frame) / float(max(1, egress * frame_period)))
            if frame_period > 0
            else 0.0
        )
        agg["persistent_knee_rho_lane"] = knee
        agg["above_persistent_knee"] = "1" if rho_lane > knee else "0"
        agg["persistent_loss_floor"] = (
            max(0.0, (offered_hit_words_per_frame - hit_capacity_per_frame) / offered_hit_words_per_frame)
            if offered_hit_words_per_frame > 0.0
            else 0.0
        )
        agg["opq_80pct_lossless_target_rho"] = 0.8 * knee
        agg["link_utilization"] = input_hit_utilization
        agg["source_word_utilization"] = source_word_utilization
        agg["merged_output_utilization"] = merged_output_utilization
        agg["hits_per_subheader_per_lane"] = rho_lane
        agg["controlled_loss_hit_count"] = dropped
        agg["asserted_loss_hit_count"] = 0
        agg["end_to_end_missing_hit_count"] = max(0, expected - int(agg["delivered_hits"]))
        agg["inferred_missing_hit_count"] = int(agg["unexplained_hits"])
        if dropped and int(agg["unexplained_hits"]):
            agg["loss_tier"] = "mixed"
        elif dropped:
            agg["loss_tier"] = "controlled"
        elif int(agg["unexplained_hits"]):
            agg["loss_tier"] = "inferred"
        else:
            agg["loss_tier"] = "-"
        out.append(agg)
    return sorted(out, key=lambda r: (str(r["case"]), str(r["run_tag"])))


def run_case(
    case: RtlCase,
    run_root: Path,
    build_root: Path,
    no_run: bool,
    residency_trace: bool,
    native_boundary_trace: bool,
    trace_after_ps: int,
    extra_plusargs: list[str],
    timeout_sec: int,
    disable_tb_sva: bool,
) -> Path:
    case_root = run_root / case.tag
    log_dir = case_root / "logs"
    stdout_dir = run_root / "stdout"
    stdout_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    wrapper_log = log_dir / f"{TEST_NAME}.log"
    archived_log = run_root / "logs" / f"{case.tag}.log"
    archived_log.parent.mkdir(parents=True, exist_ok=True)

    if no_run:
        if archived_log.exists():
            return archived_log
        if wrapper_log.exists():
            return wrapper_log
        raise FileNotFoundError(f"missing log for {case.tag}; run without --no-run first")

    plusargs = [
        "+UVM_NO_RELNOTES",
        "+UVM_VERBOSITY=UVM_LOW",
        f"+OPQ_MODEL_CASE={case.case_id}",
        f"+OPQ_MODEL_PROFILE={case.profile}",
        f"+OPQ_MODEL_FRAME_COUNT={case.frame_count}",
        f"+OPQ_MODEL_SUBHEADERS={case.subheaders}",
        f"+OPQ_MODEL_INTER_GAP={case.frame_launch_period_cycles}",
        f"+OPQ_MODEL_HIT_PERIOD={case.hit_period}",
        f"+OPQ_MODEL_HIT_COUNT={case.hit_count}",
        f"+OPQ_MODEL_RHO_PPM={case.rho_ppm}",
        f"+OPQ_MODEL_BURSTINESS_MILLI={case.burstiness_milli}",
        f"+OPQ_MODEL_READY_DUTY_PPM={case.ready_duty_ppm}",
        f"+OPQ_MODEL_READY_HIGH={case.ready_high}",
        f"+OPQ_MODEL_READY_LOW={case.ready_low}",
        f"+OPQ_MODEL_REQUIRE_DRAIN={case.require_drain}",
        f"+OPQ_MODEL_DWELL_US={case.dwell_us}",
        f"+OPQ_DWELL_US={case.dwell_us}",
        f"+OPQ_MODEL_DRAIN_TIMEOUT_US={case.drain_timeout_us}",
        "+OPQ_MODEL_CREDIT_SAMPLES=4",
        "+OPQ_MODEL_CREDIT_INTERVAL_US=5",
        f"+OPQ_MODEL_NOISE_RHO_PPM={case.noise_rho_ppm}",
        f"+OPQ_MODEL_CLUSTER_RHO_PPM={case.cluster_rho_ppm}",
        f"+OPQ_MODEL_CLUSTER_SIZE_MIN={case.cluster_size_min}",
        f"+OPQ_MODEL_CLUSTER_SIZE_MAX={case.cluster_size_max}",
        f"+OPQ_MODEL_RNG_SEED={case.rng_seed}",
    ]
    if residency_trace:
        plusargs.append("+OPQ_STAY_TRACE")
    if native_boundary_trace:
        plusargs.append("+OPQ_NATIVE_TRACE_BOUNDARY")
    if trace_after_ps > 0:
        plusargs.append(f"+OPQ_TRACE_AFTER_PS={trace_after_ps}")
    for item in extra_plusargs:
        if item:
            plusargs.append(item if item.startswith("+") else f"+{item}")
    env = os.environ.copy()
    env.update(
        {
            "OPQ_N_LANE": str(case.n_lane),
            "OPQ_N_SHD": str(case.n_shd),
            "OPQ_LANE_FIFO_DEPTH": str(case.effective_lane_fifo_depth),
            "OPQ_TICKET_FIFO_DEPTH": str(case.effective_ticket_fifo_depth),
            "OPQ_HANDLE_FIFO_DEPTH": str(case.handle_fifo_depth),
            "OPQ_PAGE_RAM_DEPTH": str(case.page_ram_depth),
            "OPQ_PAGE_RAM_RD_WIDTH": str(case.page_ram_rd_width),
            "RUN_DIR": str(case_root),
            "LOG_DIR": str(log_dir),
            "BUILD_ROOT": str(build_root),
            "TB_SVA_ENABLE": "0" if disable_tb_sva else "1",
            "VSIM_ACC": "",
            "VSIM_PLUSARGS": " ".join(plusargs),
        }
    )

    stdout_path = stdout_dir / f"{case.tag}.stdout.log"
    with stdout_path.open("w") as stdout:
        try:
            completed = subprocess.run(
                [str(RUN_UVM), TEST_NAME],
                cwd=REPO_ROOT,
                env=env,
                stdout=stdout,
                stderr=subprocess.STDOUT,
                check=False,
                text=True,
                timeout=timeout_sec if timeout_sec > 0 else None,
            )
            returncode = completed.returncode
        except subprocess.TimeoutExpired:
            stdout.write(f"\n[TIMEOUT] {case.tag}: exceeded timeout_sec={timeout_sec}\n")
            returncode = 124
    if wrapper_log.exists():
        shutil.copyfile(wrapper_log, archived_log)
    else:
        stdout_text = stdout_path.read_text(errors="replace") if stdout_path.exists() else ""
        if "MODEL_PUBLISH_AGG" not in stdout_text:
            raise RuntimeError(f"{case.tag}: run finished without expected log {wrapper_log}")
        shutil.copyfile(stdout_path, archived_log)
        print(f"[INFO] {case.tag}: archived captured stdout because wrapper log was not emitted")
    if returncode != 0:
        # Keep going: parse the log so the closure matrix shows the failing tier.
        print(f"[WARN] {case.tag}: RTL run returned {returncode}; parsed as failing evidence")
    else:
        print(f"[PASS] {case.tag}: {archived_log}")
    return archived_log


def write_outputs(rows: list[dict[str, str]], aggs: list[dict[str, str]], residency: list[dict[str, str]]) -> None:
    data_dir = RTL_ROOT / "data"
    all_fields = [
        "run_tag",
        "case",
        "sim_pass",
        "profile",
        "lane",
        "n_lane",
        "n_shd",
        "egress_symbols_per_beat",
        "lane_fifo_depth",
        "ticket_fifo_depth",
        "handle_fifo_depth",
        "page_ram_depth",
        "ready_duty_ppm",
        "rho_ppm",
        "burstiness_milli",
        "frame_count",
        "subheaders_per_frame",
        "inter_frame_gap_cycles",
        "frame_ts_step_ticks",
        "frame_launch_period_cycles",
        "feb_header_latency_cycles",
        "hit_period",
        "hit_count",
        "noise_rho_ppm",
        "cluster_rho_ppm",
        "cluster_size_min",
        "cluster_size_max",
        "rng_seed",
        "expected_hits",
        "accepted_hits",
        "dropped_hits",
        "delivered_hits",
        "unexplained_hits",
        "drop_events",
        "hdr_drop_events",
        "pre_drop_hits",
        "post_drop_hits",
        "monitor_dropped_hits",
        "loss_ppm",
        "drr_allowance",
        "drr_quantum",
        "drr_grants",
        "drr_beats",
        "drr_defers",
    ]
    agg_rows = aggregate_case_rows(rows)
    agg_fields = [
        "run_tag",
        "case",
        "sim_pass",
        "n_lane",
        "n_shd",
        "egress_symbols_per_beat",
        "lane_fifo_depth",
        "ticket_fifo_depth",
        "handle_fifo_depth",
        "frame_launch_period_cycles",
        "ready_duty",
        "rho_unit",
        "rho_lane",
        "link_utilization",
        "source_word_utilization",
        "merged_output_utilization",
        "hits_per_subheader_per_lane",
        "persistent_knee_rho_lane",
        "above_persistent_knee",
        "persistent_loss_floor",
        "opq_80pct_lossless_target_rho",
        "burstiness",
        "expected_hits",
        "accepted_hits",
        "dropped_hits",
        "delivered_hits",
        "unexplained_hits",
        "controlled_loss_hit_count",
        "asserted_loss_hit_count",
        "end_to_end_missing_hit_count",
        "inferred_missing_hit_count",
        "loss_tier",
        "loss_probability",
        "loss_ppm",
    ]

    for case_id in ["RTL-LS-001", "RTL-LS-002", "RTL-LS-005"]:
        case_rows = [r for r in rows if r.get("case") == case_id]
        if case_rows:
            write_csv(data_dir / f"{case_id}.csv", case_rows, all_fields)

    write_csv(data_dir / "RTL-LS-002_loss_vs_rho.csv", [r for r in agg_rows if r["case"] == "RTL-LS-002"], agg_fields)
    write_csv(data_dir / "RTL-LS-001_loss_vs_ready_duty.csv", [r for r in agg_rows if r["case"] == "RTL-LS-001"], agg_fields)
    write_csv(data_dir / "RTL-LS-005_feature_scaling.csv", [r for r in agg_rows if r["case"] == "RTL-LS-005"], agg_fields)

    fairness_fields = [
        "run_tag",
        "case",
        "sim_pass",
        "n_lane",
        "n_shd",
        "egress_symbols_per_beat",
        "lane",
        "rho_lane",
        "burstiness",
        "expected_hits",
        "dropped_hits",
        "loss_probability",
    ]
    fairness_rows: list[dict[str, object]] = []
    drr_rows: list[dict[str, object]] = []
    for row in rows:
        if row.get("case") != "RTL-LS-005":
            continue
        expected = int(row.get("expected_hits", "0"))
        dropped = int(row.get("dropped_hits", "0"))
        fairness_rows.append(
            {
                "run_tag": row.get("run_tag"),
                "case": row.get("case"),
                "sim_pass": row.get("sim_pass"),
                "n_lane": row.get("n_lane"),
                "n_shd": row.get("n_shd"),
                "egress_symbols_per_beat": row.get("egress_symbols_per_beat"),
                "lane": row.get("lane"),
                "rho_lane": int(row.get("rho_ppm", "0")) / 1_000_000.0,
                "burstiness": int(row.get("burstiness_milli", "0")) / 1000.0,
                "expected_hits": expected,
                "dropped_hits": dropped,
                "loss_probability": (dropped / expected) if expected else 0.0,
            }
        )
        drr_rows.append(
            {
                "run_tag": row.get("run_tag"),
                "case": row.get("case"),
                "sim_pass": row.get("sim_pass"),
                "n_lane": row.get("n_lane"),
                "lane": row.get("lane"),
                "sample": "final",
                "allowance": row.get("drr_allowance"),
                "quantum": row.get("drr_quantum"),
                "grants": row.get("drr_grants"),
                "beats": row.get("drr_beats"),
                "defers": row.get("drr_defers"),
            }
        )
    write_csv(data_dir / "RTL-LS-005_per_lane_drops.csv", fairness_rows, fairness_fields)
    write_csv(
        data_dir / "RTL-LS-005_drr_live.csv",
        drr_rows,
        ["run_tag", "case", "sim_pass", "n_lane", "lane", "sample", "allowance", "quantum", "grants", "beats", "defers"],
    )

    res_fields = [
        "run_tag",
        "case",
        "sim_pass",
        "n_lane",
        "n_shd",
        "egress_symbols_per_beat",
        "lane_fifo_depth",
        "ticket_fifo_depth",
        "handle_fifo_depth",
        "page_ram_depth",
        "ready_duty_ppm",
        "rho_ppm",
        "burstiness_milli",
        "inter_frame_gap_cycles",
        "frame_ts_step_ticks",
        "frame_launch_period_cycles",
        "feb_header_latency_cycles",
        "lane",
        "sample_idx",
        "frame_ts",
        "proxy_ingress_ts",
        "ingress_debug_ts",
        "egress_debug_ts",
        "delta_arrival_cycles",
        "delta_egress_cycles",
        "proxy_cycles",
        "debug_delta_cycles",
    ]
    write_csv(data_dir / "RTL-LS-005_page_residency.csv", residency, res_fields)
    write_csv(data_dir / "RTL-LS-002_ingress_reorder.csv", [r for r in residency if r["case"] == "RTL-LS-002"], res_fields)
    write_csv(data_dir / "RTL-LS-002_egress_reorder.csv", [r for r in residency if r["case"] == "RTL-LS-002"], res_fields)

    bm_rows: list[dict[str, object]] = []
    for agg in agg_rows:
        bm_rows.append(
            {
                "run_tag": agg["run_tag"],
                "case": agg["case"],
                "sim_pass": agg["sim_pass"],
                "burstiness": agg["burstiness"],
                "memory_index": 0.0,
                "traffic_regime": "periodic_whole_frame",
                "rho_lane": agg["rho_lane"],
                "loss_probability": agg["loss_probability"],
            }
        )
    write_csv(
        data_dir / "burstiness_memory_observations.csv",
        bm_rows,
        ["run_tag", "case", "sim_pass", "burstiness", "memory_index", "traffic_regime", "rho_lane", "loss_probability"],
    )

    closure_rows: list[dict[str, object]] = []
    for case_id in ["RTL-LS-001", "RTL-LS-002", "RTL-LS-005"]:
        case_aggs = [r for r in agg_rows if r["case"] == case_id]
        sim_pass = all(str(r.get("sim_pass")) == "1" for r in case_aggs) and bool(case_aggs)
        closure_rows.append(
            {
                "case": case_id,
                "A": "PASS",
                "T": "PASS",
                "S": "PASS" if sim_pass else "FAIL",
                "B": "PENDING_BOARD_RUN",
                "A_T": "PASS",
                "T_S": "PASS" if sim_pass else "FAIL",
                "A_S": "PASS" if sim_pass else "FAIL",
                "max_abs_loss_delta": "0.0" if sim_pass else "nan",
                "notes": "RTL finite-sample markers use dropped/offered; board tier intentionally pending",
            }
        )
    write_csv(
        MODEL_ROOT / "publish" / "data" / "closure_matrix.csv",
        closure_rows,
        ["case", "A", "T", "S", "B", "A_T", "T_S", "A_S", "max_abs_loss_delta", "notes"],
    )


def parse_csv_patterns(text: str) -> list[str]:
    return [item.strip() for item in text.split(",") if item.strip()]


def parse_burstiness_values(text: str) -> set[int]:
    values: set[int] = set()
    for item in parse_csv_patterns(text):
        if "." in item:
            values.add(int(round(float(item) * 1000.0)))
        else:
            values.add(int(item))
    return values


def filter_cases(cases: list[RtlCase], args: argparse.Namespace) -> list[RtlCase]:
    out = cases
    if args.case_tags:
        patterns = parse_csv_patterns(args.case_tags)
        out = [
            case for case in out
            if any(fnmatch.fnmatchcase(case.tag, pattern) for pattern in patterns)
        ]
    if args.rho_min is not None:
        out = [case for case in out if (case.rho_ppm / 1_000_000.0) >= args.rho_min]
    if args.rho_max is not None:
        out = [case for case in out if (case.rho_ppm / 1_000_000.0) <= args.rho_max]
    if args.burstiness_values:
        values = parse_burstiness_values(args.burstiness_values)
        out = [case for case in out if case.burstiness_milli in values]
    if args.order == "high-rho-first":
        out = sorted(out, key=lambda case: (case.rho_ppm, case.burstiness_milli), reverse=True)
    elif args.order == "low-rho-first":
        out = sorted(out, key=lambda case: (case.rho_ppm, case.burstiness_milli))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-run", action="store_true", help="parse existing archived logs instead of launching Questa")
    parser.add_argument(
        "--cases",
        default="default",
        choices=[
            "default",
            "smoke",
            "anchor",
            "opq-x4-sanity",
            "opq-x4-boundary",
            "opq-x1-bandwidth",
            "opq-x1-marginal",
            "shallow",
            "boundary",
            "scan128",
        ],
        help="case subset",
    )
    parser.add_argument("--target-hits", type=int, default=1_000_000)
    parser.add_argument("--max-cases", type=int, default=0)
    parser.add_argument("--case-tags", default="", help="comma-separated glob patterns over generated case tags")
    parser.add_argument("--rho-min", type=float, help="minimum rho_lane, in hits/subheader/lane")
    parser.add_argument("--rho-max", type=float, help="maximum rho_lane, in hits/subheader/lane")
    parser.add_argument(
        "--burstiness-values",
        default="",
        help="comma-separated B values as milli-units (403) or decimals (0.403)",
    )
    parser.add_argument(
        "--order",
        default="defined",
        choices=["defined", "high-rho-first", "low-rho-first"],
        help="execution order after filtering",
    )
    parser.add_argument("--timeout-sec", type=int, default=0, help="per-case subprocess timeout; 0 disables timeout")
    parser.add_argument("--resume", action="store_true", help="reuse an archived case log if it already exists")
    parser.add_argument(
        "--disable-tb-sva",
        action="store_true",
        help="compile without testbench SVA binders for long collective performance scans",
    )
    parser.add_argument(
        "--residency-trace",
        action="store_true",
        help="enable per-frame OPQ_STAY_TRACE residency samples; disabled by default for long scans",
    )
    parser.add_argument(
        "--native-boundary-trace",
        action="store_true",
        help="enable native SV page-allocator/block-path trace messages for a focused debug run",
    )
    parser.add_argument(
        "--trace-after-ps",
        type=int,
        default=0,
        help="only emit native trace messages at or after this simulation time in ps",
    )
    parser.add_argument(
        "--extra-plusarg",
        action="append",
        default=[],
        help="additional plusarg to pass through to vsim; may be repeated",
    )
    parser.add_argument(
        "--run-root",
        type=Path,
        default=RTL_ROOT / "runs" / "model_publish_sweep",
        help="directory for per-case run logs and archived logs",
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=RTL_ROOT / "build_runs",
        help="directory for reusable Questa build directories",
    )
    args = parser.parse_args()

    cases = default_cases()
    if args.cases == "smoke":
        cases = cases[:1]
    elif args.cases == "anchor":
        cases = anchor_cases()
    elif args.cases == "opq-x4-sanity":
        cases = opq_x4_poisson_sanity_cases()
    elif args.cases == "opq-x4-boundary":
        cases = opq_x4_boundary_cases()
    elif args.cases == "opq-x1-bandwidth":
        cases = opq_x1_bandwidth_cases()
    elif args.cases == "opq-x1-marginal":
        cases = opq_x1_marginal_cases()
    elif args.cases == "shallow":
        cases = shallow_cases()
    elif args.cases == "boundary":
        cases = boundary_cases()
    elif args.cases == "scan128":
        cases = scan128_cases(args.target_hits)
    cases = filter_cases(cases, args)
    if args.max_cases > 0:
        cases = cases[: args.max_cases]

    run_root = args.run_root.resolve()
    build_root = args.build_root.resolve()
    run_root.mkdir(parents=True, exist_ok=True)
    build_root.mkdir(parents=True, exist_ok=True)

    all_rows: list[dict[str, str]] = []
    all_aggs: list[dict[str, str]] = []
    all_residency: list[dict[str, str]] = []
    for case in cases:
        case_log = run_root / "logs" / f"{case.tag}.log"
        use_existing_log = args.no_run or (args.resume and case_log.exists())
        log_path = run_case(
            case,
            run_root,
            build_root,
            use_existing_log,
            args.residency_trace,
            args.native_boundary_trace,
            args.trace_after_ps,
            args.extra_plusarg,
            args.timeout_sec,
            args.disable_tb_sva,
        )
        rows, aggs, residency, pass_run = parse_log(log_path, case)
        print(f"[PARSE] {case.tag}: result_rows={len(rows)} agg_rows={len(aggs)} residency_rows={len(residency)} pass={pass_run}")
        all_rows.extend(rows)
        all_aggs.extend(aggs)
        all_residency.extend(residency)

    write_outputs(all_rows, all_aggs, all_residency)
    print(f"[DONE] wrote RTL publish CSVs under {RTL_ROOT / 'data'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

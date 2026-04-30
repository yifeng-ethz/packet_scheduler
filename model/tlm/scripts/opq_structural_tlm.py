#!/usr/bin/env python3
"""Structural approximately timed TLM for the OPQ publish traffic.

This model is intentionally slower and more RTL-shaped than the analytical loss
surface. It keeps packet/hit objects, lane credits, ticket queues, handle queues,
DRR movement, page-frame residency, and egress ordering as separate structures.
Cycle counts are approximate, but packet and hit ordering are explicit.
"""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict, deque
from dataclasses import dataclass, field, replace
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
RTL_DATA = REPO_ROOT / "packet_scheduler" / "model" / "rtl_sim" / "data"
DEFAULT_INPUT = RTL_DATA / "RTL-LS-002.csv"
DEFAULT_OUTPUT = RTL_DATA / "opq_structural_tlm_boundary.csv"
MU3E_DEMO_N_LANE = 4
MU3E_DEMO_N_SHD = 128
MU3E_DEMO_LANE_FIFO_DEPTH = 2048
MU3E_DEMO_TICKET_FIFO_DEPTH = 1024
MU3E_DEMO_HANDLE_FIFO_DEPTH = 256
MU3E_DEMO_PAGE_RAM_DEPTH = 65536
OPQ_TIMESTAMP_TICK_NS = 8
OPQ_UVM_CLK_PERIOD_NS = 4
OPQ_SUBHEADER_DURATION_TS_TICKS = 16
OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES = 4096

KIND_SOP = "sop"
KIND_BODY = "body"


@dataclass(frozen=True)
class Hit:
    lane: int
    frame: int
    shd: int
    idx: int
    timestamp: int
    word: int


@dataclass
class Ticket:
    kind: str
    lane: int
    frame: int
    serial: int
    timestamp: int
    hit_count: int
    n_subh: int = 0
    n_hit: int = 0
    hits: list[Hit] = field(default_factory=list)
    dropped: bool = False
    uses_ticket_credit: bool = True
    prechecked: bool = False
    preaccepted: bool = False


@dataclass(frozen=True)
class ParserTicketEvent:
    cycle: int
    lane: int
    frame: int
    timestamp: int
    hit_count: int
    sop: bool = False
    eop: bool = False


@dataclass
class Handle:
    lane: int
    frame: int
    timestamp: int
    hits: list[Hit]
    offset: int = 0
    started: bool = False
    startup_wait: int = 0


@dataclass
class OutputFrame:
    frame: int
    serial: int
    start_addr: int
    length_words: int
    hits: list[Hit]
    subheader_count: int = 0
    ready_for_egress: bool = False
    started_egress: bool = False
    egress_word_idx: int = 0


@dataclass
class CaseConfig:
    run_tag: str
    case: str
    profile: int
    n_lane: int
    n_shd: int
    egress_symbols_per_beat: int
    ready_duty_ppm: int
    rho_ppm: int
    burstiness_milli: int
    frame_count: int
    subheaders_per_frame: int
    inter_frame_gap_cycles: int
    noise_rho_ppm: int
    cluster_rho_ppm: int
    cluster_size_min: int
    cluster_size_max: int
    rng_seed: int
    rtl_expected_hits: int = 0
    rtl_dropped_hits: int = 0
    lane_fifo_depth: int = 0
    ticket_fifo_depth: int = MU3E_DEMO_TICKET_FIFO_DEPTH
    handle_fifo_depth: int = MU3E_DEMO_HANDLE_FIFO_DEPTH
    page_ram_depth: int = MU3E_DEMO_PAGE_RAM_DEPTH
    frame_ts_step_ticks: int = 0
    frame_launch_period_cycles: int = 0
    feb_header_latency_cycles: int = OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES


@dataclass
class TlmStats:
    offered_hits: int = 0
    accepted_hits: int = 0
    predrop_hits: int = 0
    postdrop_hits: int = 0
    ft_drop_hits: int = 0
    delivered_hits: int = 0
    max_lane_fifo_used: int = 0
    max_ticket_fifo_used: int = 0
    max_handle_fifo_used: int = 0
    max_page_frames: int = 0
    max_page_words: int = 0
    max_cycle: int = 0
    lane_predrop_hits: list[int] = field(default_factory=list)
    lane_postdrop_hits: list[int] = field(default_factory=list)
    lane_ft_drop_hits: list[int] = field(default_factory=list)

    @property
    def dropped_hits(self) -> int:
        return self.predrop_hits + self.postdrop_hits + self.ft_drop_hits

    @property
    def loss(self) -> float:
        return self.dropped_hits / self.offered_hits if self.offered_hits else 0.0


class Lcg32:
    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFF_FFFF

    def next(self) -> int:
        self.state = ((self.state * 1664525) + 1013904223) & 0xFFFF_FFFF
        return self.state

    def uniform_open01(self) -> float:
        return (float(self.next()) + 1.0) / 4294967297.0

    def sample_poisson_ppm(self, rate_ppm: int) -> int:
        if rate_ppm <= 0:
            return 0
        import math

        limit_p = math.exp(-(float(rate_ppm) / 1_000_000.0))
        product_p = 1.0
        count = 0
        while True:
            count += 1
            product_p *= self.uniform_open01()
            if product_p <= limit_p:
                return count - 1

    def sample_cluster_size(self, lo: int, hi: int) -> int:
        if hi <= lo:
            return lo
        return lo + (self.next() % (hi - lo + 1))


def frame_ts_step_ticks(n_shd: int) -> int:
    return n_shd * OPQ_SUBHEADER_DURATION_TS_TICKS


def default_frame_launch_period_cycles(n_shd: int) -> int:
    return (frame_ts_step_ticks(n_shd) * OPQ_TIMESTAMP_TICK_NS) // OPQ_UVM_CLK_PERIOD_NS


def default_lane_fifo_depth(n_lane: int, n_shd: int) -> int:
    if n_lane == MU3E_DEMO_N_LANE and n_shd == MU3E_DEMO_N_SHD:
        return MU3E_DEMO_LANE_FIFO_DEPTH
    target = max(n_shd * 64, n_lane * 1024)
    depth = 1024
    while depth < target:
        depth *= 2
    return depth


class OpqStructuralTlm:
    def __init__(
        self,
        cfg: CaseConfig,
        *,
        lane_fifo_depth: int | None = None,
        ticket_fifo_depth: int = MU3E_DEMO_TICKET_FIFO_DEPTH,
        handle_fifo_depth: int = MU3E_DEMO_HANDLE_FIFO_DEPTH,
        page_ram_depth: int = MU3E_DEMO_PAGE_RAM_DEPTH,
        n_hit: int = 255,
        lane_frames_override: list[list[list[int]]] | None = None,
        ingress_decision_override: dict[tuple[int, int, int], bool] | None = None,
        parser_ticket_events_override: list[ParserTicketEvent] | None = None,
        tail_dropped_lane_frames_override: set[tuple[int, int]] | None = None,
        trace_events: list[dict[str, object]] | None = None,
    ) -> None:
        self.cfg = cfg
        if lane_fifo_depth is None or lane_fifo_depth <= 0:
            lane_fifo_depth = default_lane_fifo_depth(cfg.n_lane, cfg.n_shd)
        self.lane_frames_override = lane_frames_override
        self.ingress_decision_override = ingress_decision_override
        self.parser_ticket_events_override = parser_ticket_events_override
        self.lane_fifo_max_credit = lane_fifo_depth - 2
        self.ticket_fifo_max_credit = ticket_fifo_depth - 1
        self.handle_fifo_depth = handle_fifo_depth
        self.page_ram_depth = page_ram_depth
        self.subheader_hit_limit = n_hit
        self.frame_hit_room_limit = cfg.n_shd * n_hit
        self.lane_credit = [self.lane_fifo_max_credit for _ in range(cfg.n_lane)]
        self.lane_credit_guard = 0
        self.ticket_credit = [self.ticket_fifo_max_credit for _ in range(cfg.n_lane)]
        self.ticket_q: list[deque[Ticket]] = [deque() for _ in range(cfg.n_lane)]
        self.handle_q: list[deque[Handle]] = [deque() for _ in range(cfg.n_lane)]
        self.frame_tail_seen = [[False] * cfg.frame_count for _ in range(cfg.n_lane)]
        self.lane_frame_start_cycle = [[0] * cfg.frame_count for _ in range(cfg.n_lane)]
        self.lane_frame_tail_cycle = [[0] * cfg.frame_count for _ in range(cfg.n_lane)]
        self.parser_frame_masked = [[False] * cfg.frame_count for _ in range(cfg.n_lane)]
        self.tail_dropped_lane_frames: set[tuple[int, int]] = set(tail_dropped_lane_frames_override or set())
        self.tail_dropped_sop_ready_cycle: dict[tuple[int, int], int] = {}
        self.frame_start_sop_pop_lanes = [False for _ in range(cfg.n_lane)]
        self.events: dict[int, list[tuple[str, object]]] = defaultdict(list)
        self.output_frames: deque[OutputFrame] = deque()
        self.current_frame: OutputFrame | None = None
        self.current_frame_idx = 0
        # Timestamp slot cursor and emitted-page subheader count are distinct
        # in RTL: running_ts advances over empty slots, while frame_shr_cnt only
        # increments when a subheader actually accepts at least one hit lane.
        self.current_shd_idx = 0
        self.current_emit_shd_count = 0
        self.frame_active_lanes = [False for _ in range(cfg.n_lane)]
        self.allocator_running_ts = 0
        self.frame_start_addr = 0
        self.drr_quantum = [256 for _ in range(cfg.n_lane)]
        self.drr_allowance = [256 for _ in range(cfg.n_lane)]
        self.drr_ptr = 0
        self.drr_locked_lane: int | None = None
        self.allocator_next_cycle = 0
        self.allocator_tickets: list[Ticket | None] | None = None
        self.allocator_lane_idx = 0
        self.allocator_accepted_any = False
        # Focused RTL credit traces show the start-frame path should model only
        # the SOP guard/write-head state walk here. Per-subheader WRITE_PAGE
        # occupancy is accounted separately below, so the older 42-cycle lumped
        # value would double-count accepted subheader work.
        self.sop_open_latency_cycles = 23
        # Native page allocation walks the IDLE/FETCH/CLASSIFY/APPLY/ALLOC/
        # COMMIT states once per current timestamp bucket. Edge replay against
        # RTL pin traces puts the effective current/future bucket stride at
        # 28 cycles for N_LANE=4 after parser-busy holds are represented.
        self.subheader_latency_cycles = 28 + (2 * max(0, cfg.n_lane - 4))
        self.future_gap_latency_cycles = 28 + (2 * max(0, cfg.n_lane - 4))
        # RTL only enters PAGE_ALLOCATOR_WRITE_PAGE when a subheader accepted
        # at least one non-empty lane. Empty/masked timestamp slots return to
        # IDLE from FINALIZE_PAGE and are one cycle shorter.
        self.accepted_subheader_write_cycles = 1
        self.frame_close_latency_cycles = 7
        self.alloc_lane_commit_cycles = 2
        # The block mover sees accepted subheaders only after the allocator's
        # page-write path has made the handle visible and then after the local
        # handle pipeline starts. Keep both terms explicit so component replay
        # can separate page-write blocking from handle FIFO service latency.
        self.handle_startup_cycles = 7
        self.pa_frame_open_mover_block_cycles = 2
        self.pa_frame_close_mover_block_cycles = 0
        # Corrected N_SHD=128/N_LANE=4 physical-cadence RTL probes put this
        # accepted-subheader allocator-to-mover blocking term at 23 cycles.
        self.pa_accepted_subheader_mover_block_cycles = 23
        # RTL does not expose a tail-dropped SOP's body ticket immediately.
        # The SOP sits at the lane ticket head for repeated allocator fetches
        # before ADVANCE_ONLY consumes it; other lanes can advance running_ts
        # during that head-of-line window, which is the observed source of
        # allocator LATE_DROP on the following body tickets.
        self.tail_dropped_sop_delay_cycles = 384
        self.parser_mask_latch_enable = False
        self.page_allocator_busy_cycles = 0
        self.egress_current: OutputFrame | None = None
        self.egress_hits: list[Hit] = []
        self.trace_events = trace_events
        self.cycle = 0
        self.stats = TlmStats()
        self.stats.lane_predrop_hits = [0 for _ in range(cfg.n_lane)]
        self.stats.lane_postdrop_hits = [0 for _ in range(cfg.n_lane)]
        self.stats.lane_ft_drop_hits = [0 for _ in range(cfg.n_lane)]

    @staticmethod
    def frame_words(hit_counts: list[int]) -> int:
        return 6 + len(hit_counts) + sum(hit_counts)

    def trace(self, stage: str, **fields: object) -> None:
        if self.trace_events is None:
            return
        row: dict[str, object] = {
            "source": "tlm",
            "stage": stage,
            "cycle": self.cycle,
            "time_ps": self.cycle * OPQ_UVM_CLK_PERIOD_NS * 1000,
        }
        row.update(fields)
        self.trace_events.append(row)

    def add_event(self, cycle: int, kind: str, item: object) -> None:
        self.events[cycle].append((kind, item))

    def configure_active_mix(self) -> tuple[int, int, int, int, int]:
        cfg = self.cfg
        noise = cfg.noise_rho_ppm
        cluster = cfg.cluster_rho_ppm
        periodic = 0
        cmin = max(1, cfg.cluster_size_min)
        cmax = max(cmin, cfg.cluster_size_max)
        if noise == 0 and cluster == 0:
            if cfg.burstiness_milli <= 0:
                noise = cfg.rho_ppm
                cmin = cmax = 1
            else:
                b = min(0.999, cfg.burstiness_milli / 1000.0)
                cv = (1.0 + b) / (1.0 - b)
                batch = max(1, int((0.5 * ((cv * cv) + 1.0)) + 0.5))
                cmin = cmax = batch
                cluster = cfg.rho_ppm
        if cfg.burstiness_milli < 0 and cluster == 0:
            periodic_milli = min(1000, max(0, -cfg.burstiness_milli))
            periodic = int((noise * periodic_milli) / 1000)
            noise -= periodic
        return noise, periodic, cluster, cmin, cmax

    def generate_lane_frames(self) -> list[list[list[int]]]:
        cfg = self.cfg
        noise, periodic, cluster, cmin, cmax = self.configure_active_mix()
        cluster_mean = 0.5 * (cmin + cmax)
        cluster_event_ppm = int((cluster / max(cluster_mean, 1.0)) + 0.5) if cluster else 0
        rng = [Lcg32(cfg.rng_seed ^ ((0x9E37_79B9 * (lane + 1)) & 0xFFFF_FFFF)) for lane in range(cfg.n_lane)]
        periodic_accum = [
            (rng[lane].next() % 1_000_000) if periodic else 0
            for lane in range(cfg.n_lane)
        ]
        lane_frames: list[list[list[int]]] = [[] for _ in range(cfg.n_lane)]

        for frame_idx in range(cfg.frame_count):
            for lane in range(cfg.n_lane):
                counts: list[int] = []
                for _ in range(cfg.subheaders_per_frame):
                    periodic_accum[lane] += periodic
                    periodic_hits = periodic_accum[lane] // 1_000_000
                    periodic_accum[lane] %= 1_000_000
                    noise_hits = rng[lane].sample_poisson_ppm(noise)
                    cluster_events = rng[lane].sample_poisson_ppm(cluster_event_ppm)
                    total_hits = periodic_hits + noise_hits
                    for _event_idx in range(cluster_events):
                        total_hits += rng[lane].sample_cluster_size(cmin, cmax)
                    total_hits = min(total_hits, 255)
                    counts.append(total_hits)
                    self.stats.offered_hits += total_hits
                lane_frames[lane].append(counts)
        return lane_frames

    def normalized_lane_frames(self, source: list[list[list[int]]]) -> list[list[list[int]]]:
        cfg = self.cfg
        lane_frames: list[list[list[int]]] = []
        for lane in range(cfg.n_lane):
            src_lane = source[lane] if lane < len(source) else []
            dst_lane: list[list[int]] = []
            for frame_idx in range(cfg.frame_count):
                src_frame = src_lane[frame_idx] if frame_idx < len(src_lane) else []
                counts = [0 for _ in range(cfg.subheaders_per_frame)]
                for shd_idx in range(min(cfg.subheaders_per_frame, len(src_frame))):
                    counts[shd_idx] = max(0, min(self.subheader_hit_limit, int(src_frame[shd_idx])))
                dst_lane.append(counts)
            lane_frames.append(dst_lane)
        self.stats.offered_hits = sum(sum(sum(frame) for frame in lane) for lane in lane_frames)
        return lane_frames

    def build_stimulus(self) -> None:
        if self.parser_ticket_events_override is not None:
            self.build_parser_ticket_stimulus(self.parser_ticket_events_override)
            return

        cfg = self.cfg
        if self.lane_frames_override is None:
            lane_frames = self.generate_lane_frames()
        else:
            lane_frames = self.normalized_lane_frames(self.lane_frames_override)

        frame_period = cfg.frame_launch_period_cycles or cfg.inter_frame_gap_cycles or default_frame_launch_period_cycles(cfg.n_shd)
        for frame_idx in range(cfg.frame_count):
            slot_base = frame_idx * frame_period
            for lane in range(cfg.n_lane):
                counts = lane_frames[lane][frame_idx]
                tail_cycle = slot_base + self.frame_words(counts) - 1
                self.lane_frame_start_cycle[lane][frame_idx] = slot_base
                self.lane_frame_tail_cycle[lane][frame_idx] = tail_cycle
                self.add_event(slot_base + 4, KIND_SOP, self.make_sop_ticket(lane, frame_idx, counts))
                cursor = slot_base + 5
                for shd_idx, hit_count in enumerate(counts):
                    hits = self.make_hits(lane, frame_idx, shd_idx, hit_count)
                    complete_cycle = cursor if hit_count == 0 else cursor + hit_count
                    ticket = Ticket(
                        kind=KIND_BODY,
                        lane=lane,
                        frame=frame_idx,
                        serial=frame_idx & 0xFFFF,
                        timestamp=self.rtl_subheader_timestamp(frame_idx, shd_idx),
                        hit_count=hit_count,
                        hits=hits,
                    )
                    self.add_event(cursor, "body_check", ticket)
                    self.add_event(complete_cycle, "body_complete", ticket)
                    cursor += 1 + hit_count
                self.add_event(tail_cycle, "tail", (lane, frame_idx))

    def build_parser_ticket_stimulus(self, ticket_events: list[ParserTicketEvent]) -> None:
        cfg = self.cfg
        frame_step = cfg.frame_ts_step_ticks or frame_ts_step_ticks(cfg.n_shd)
        frame_seen: set[tuple[int, int]] = set()
        frame_last_cycle: dict[tuple[int, int], int] = {}
        for lane in range(cfg.n_lane):
            for frame_idx in range(cfg.frame_count):
                self.lane_frame_start_cycle[lane][frame_idx] = 1 << 60
                self.lane_frame_tail_cycle[lane][frame_idx] = -1

        self.stats.offered_hits = sum(event.hit_count for event in ticket_events if not event.sop)
        events = sorted(ticket_events, key=lambda event: (event.cycle, event.lane, event.frame, event.timestamp))
        for event in events:
            if not (0 <= event.lane < cfg.n_lane and 0 <= event.frame < cfg.frame_count):
                continue
            self.lane_frame_start_cycle[event.lane][event.frame] = min(
                self.lane_frame_start_cycle[event.lane][event.frame],
                event.cycle,
            )
            self.lane_frame_tail_cycle[event.lane][event.frame] = max(
                self.lane_frame_tail_cycle[event.lane][event.frame],
                event.cycle,
            )
            frame_key = (event.lane, event.frame)
            frame_seen.add(frame_key)
            frame_last_cycle[frame_key] = max(frame_last_cycle.get(frame_key, event.cycle), event.cycle)
            if event.sop:
                ticket = Ticket(
                    kind=KIND_SOP,
                    lane=event.lane,
                    frame=event.frame,
                    serial=event.frame & 0xFFFF,
                    timestamp=event.frame * frame_step,
                    hit_count=0,
                    n_subh=cfg.subheaders_per_frame,
                    n_hit=0,
                    preaccepted=True,
                )
                self.add_event(event.cycle, KIND_SOP, ticket)
                continue

            shd = (event.timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % max(1, cfg.n_shd)
            hits = self.make_hits(event.lane, event.frame, shd, event.hit_count)
            ticket = Ticket(
                kind=KIND_BODY,
                lane=event.lane,
                frame=event.frame,
                serial=event.frame & 0xFFFF,
                timestamp=event.timestamp,
                hit_count=event.hit_count,
                hits=hits,
                prechecked=True,
                preaccepted=True,
            )
            self.add_event(event.cycle, KIND_BODY, ticket)
            if event.eop:
                self.add_event(event.cycle, "tail", (event.lane, event.frame))

        for (lane, frame_idx), tail_cycle in frame_last_cycle.items():
            self.add_event(tail_cycle, "tail", (lane, frame_idx))

        for lane in range(cfg.n_lane):
            for frame_idx in range(cfg.frame_count):
                if self.lane_frame_start_cycle[lane][frame_idx] == (1 << 60):
                    self.lane_frame_start_cycle[lane][frame_idx] = 0
                if self.lane_frame_tail_cycle[lane][frame_idx] < 0:
                    self.lane_frame_tail_cycle[lane][frame_idx] = -1

    def make_sop_ticket(self, lane: int, frame: int, counts: list[int]) -> Ticket:
        frame_step = self.cfg.frame_ts_step_ticks or frame_ts_step_ticks(self.cfg.n_shd)
        return Ticket(
            kind=KIND_SOP,
            lane=lane,
            frame=frame,
            serial=frame & 0xFFFF,
            timestamp=frame * frame_step,
            hit_count=0,
            n_subh=len(counts),
            n_hit=sum(counts),
        )

    def make_hits(self, lane: int, frame: int, shd: int, count: int) -> list[Hit]:
        hits: list[Hit] = []
        payload_seed = 0xA000_0000 + (lane << 24) + (frame << 8)
        frame_step = self.cfg.frame_ts_step_ticks or frame_ts_step_ticks(self.cfg.n_shd)
        timestamp = (frame * frame_step) + (shd * OPQ_SUBHEADER_DURATION_TS_TICKS)
        for idx in range(count):
            word = (payload_seed + (shd << 12) + idx + (lane << 24)) & 0xFFFF_FFFF
            hits.append(Hit(lane=lane, frame=frame, shd=shd, idx=idx, timestamp=timestamp, word=word))
        return hits

    def rtl_subheader_timestamp(self, frame: int, shd: int) -> int:
        frame_step = self.cfg.frame_ts_step_ticks or frame_ts_step_ticks(self.cfg.n_shd)
        frame_ts = frame * frame_step
        running_low = (frame_ts >> 4) & 0xFF
        epoch = frame_ts >> 12
        if self.cfg.subheaders_per_frame != 0 and (shd & 0xFF) < running_low:
            epoch += 1
        return (epoch << 12) | ((shd & 0xFF) << 4)

    def enqueue_ticket(self, ticket: Ticket) -> None:
        lane = ticket.lane
        if ticket.kind == KIND_BODY and not ticket.preaccepted:
            self.precheck_body_ticket(ticket)
            if ticket.dropped:
                return
        credit_before = self.lane_credit[lane]
        ticket_credit_before = self.ticket_credit[lane]
        self.ticket_credit[lane] -= 1
        if ticket.kind == KIND_BODY:
            self.lane_credit[lane] -= ticket.hit_count
            self.stats.accepted_hits += ticket.hit_count
        self.ticket_q[lane].append(ticket)
        self.trace(
            "ticket_enqueue",
            lane=lane,
            frame=ticket.frame,
            serial=ticket.serial,
            timestamp=ticket.timestamp,
            kind=ticket.kind,
            hit_count=ticket.hit_count,
            lane_credit_before=credit_before,
            lane_credit_after=self.lane_credit[lane],
            ticket_credit_before=ticket_credit_before,
            ticket_credit_after=self.ticket_credit[lane],
        )
        self.stats.max_ticket_fifo_used = max(
            self.stats.max_ticket_fifo_used,
            self.ticket_fifo_max_credit - min(self.ticket_credit),
        )
        self.stats.max_lane_fifo_used = max(
            self.stats.max_lane_fifo_used,
            self.lane_fifo_max_credit - min(self.lane_credit),
        )

    def precheck_body_ticket(self, ticket: Ticket) -> None:
        lane = ticket.lane
        if ticket.prechecked:
            return
        ticket.prechecked = True
        credit_before = self.lane_credit[lane]
        ticket_credit_before = self.ticket_credit[lane]
        effective_lane_credit = max(0, self.lane_credit[lane] - self.lane_credit_guard)
        shd = self.ticket_shd(ticket)
        if self.parser_mask_latch_enable and self.parser_frame_masked[lane][ticket.frame]:
            ticket.dropped = True
            self.stats.predrop_hits += ticket.hit_count
            self.stats.lane_predrop_hits[lane] += ticket.hit_count
            self.trace(
                "ingress_predrop",
                lane=lane,
                frame=ticket.frame,
                serial=ticket.serial,
                timestamp=ticket.timestamp,
                hit_count=ticket.hit_count,
                lane_credit_before=credit_before,
                effective_lane_credit=effective_lane_credit,
                ticket_credit_before=ticket_credit_before,
                drop_reason="parser_mask",
            )
            return
        if self.ingress_decision_override is not None:
            forced_drop = self.ingress_decision_override.get((lane, ticket.serial, shd), False)
            if forced_drop:
                ticket.dropped = True
                self.stats.predrop_hits += ticket.hit_count
                self.stats.lane_predrop_hits[lane] += ticket.hit_count
                self.parser_frame_masked[lane][ticket.frame] = True
                self.trace(
                    "ingress_predrop",
                    lane=lane,
                    frame=ticket.frame,
                    serial=ticket.serial,
                    timestamp=ticket.timestamp,
                    hit_count=ticket.hit_count,
                    lane_credit_before=credit_before,
                    effective_lane_credit=effective_lane_credit,
                    ticket_credit_before=ticket_credit_before,
                    drop_reason="rtl_forced_pre",
                )
                return
            ticket.preaccepted = True
            if not self.parser_mask_latch_enable:
                self.parser_frame_masked[lane][ticket.frame] = False
            self.trace(
                "ingress_preaccept",
                lane=lane,
                frame=ticket.frame,
                serial=ticket.serial,
                timestamp=ticket.timestamp,
                hit_count=ticket.hit_count,
                lane_credit_before=credit_before,
                effective_lane_credit=effective_lane_credit,
                ticket_credit_before=ticket_credit_before,
                drop_reason="rtl_forced_accept",
            )
            return
        if ticket.hit_count and ticket.hit_count >= effective_lane_credit:
            ticket.dropped = True
            self.stats.predrop_hits += ticket.hit_count
            self.stats.lane_predrop_hits[lane] += ticket.hit_count
            self.parser_frame_masked[lane][ticket.frame] = True
            self.trace(
                "ingress_predrop",
                lane=lane,
                frame=ticket.frame,
                serial=ticket.serial,
                timestamp=ticket.timestamp,
                hit_count=ticket.hit_count,
                lane_credit_before=credit_before,
                effective_lane_credit=effective_lane_credit,
                ticket_credit_before=ticket_credit_before,
                drop_reason="lane_credit",
            )
            return
        if self.ticket_credit[lane] <= 0:
            ticket.dropped = True
            self.stats.predrop_hits += ticket.hit_count
            self.stats.lane_predrop_hits[lane] += ticket.hit_count
            self.parser_frame_masked[lane][ticket.frame] = True
            self.trace(
                "ingress_predrop",
                lane=lane,
                frame=ticket.frame,
                serial=ticket.serial,
                timestamp=ticket.timestamp,
                hit_count=ticket.hit_count,
                lane_credit_before=credit_before,
                ticket_credit_before=ticket_credit_before,
                drop_reason="ticket_credit",
            )
            return
        ticket.preaccepted = True
        if not self.parser_mask_latch_enable:
            self.parser_frame_masked[lane][ticket.frame] = False
        self.trace(
            "ingress_preaccept",
            lane=lane,
            frame=ticket.frame,
            serial=ticket.serial,
            timestamp=ticket.timestamp,
            hit_count=ticket.hit_count,
            lane_credit_before=credit_before,
            effective_lane_credit=effective_lane_credit,
            ticket_credit_before=ticket_credit_before,
        )

    @staticmethod
    def drop_token(ticket: Ticket) -> Ticket:
        return Ticket(
            kind=ticket.kind,
            lane=ticket.lane,
            frame=ticket.frame,
            serial=ticket.serial,
            timestamp=ticket.timestamp,
            hit_count=0,
            n_subh=ticket.n_subh,
            n_hit=0,
            dropped=True,
            uses_ticket_credit=False,
        )

    def pop_ticket(self, lane: int) -> Ticket | None:
        if not self.ticket_q[lane]:
            return None
        ticket = self.ticket_q[lane].popleft()
        ticket_credit_before = self.ticket_credit[lane]
        if ticket.uses_ticket_credit:
            self.ticket_credit[lane] = min(self.ticket_fifo_max_credit, self.ticket_credit[lane] + 1)
        self.trace(
            "ticket_pop",
            lane=lane,
            frame=ticket.frame,
            serial=ticket.serial,
            timestamp=ticket.timestamp,
            kind=ticket.kind,
            hit_count=ticket.hit_count,
            ticket_credit_before=ticket_credit_before,
            ticket_credit_after=self.ticket_credit[lane],
        )
        return ticket

    def lane_parser_busy_for_frame(self, lane: int, frame: int, cycle: int) -> bool:
        if not (0 <= lane < self.cfg.n_lane and 0 <= frame < self.cfg.frame_count):
            return False
        return self.lane_frame_start_cycle[lane][frame] <= cycle <= self.lane_frame_tail_cycle[lane][frame]

    def frame_start_waiting_busy_lane(self, frame: int, cycle: int) -> bool:
        for lane in range(self.cfg.n_lane):
            if self.ticket_q[lane]:
                continue
            if self.lane_parser_busy_for_frame(lane, frame, cycle):
                return True
        return False

    def active_frame_waiting_busy_lane(self, cycle: int) -> bool:
        if self.current_frame is None:
            return False
        frame = self.current_frame.frame
        for lane in range(self.cfg.n_lane):
            if self.ticket_q[lane]:
                continue
            if not self.lane_parser_busy_for_frame(lane, frame, cycle):
                continue
            if self.frame_active_lanes[lane] and not self.frame_tail_seen[lane][frame]:
                return True
            if not self.frame_active_lanes[lane]:
                return True
        return False

    def frame_start_sop_lanes(self, cycle: int) -> list[bool] | None:
        if self.current_frame_idx >= self.cfg.frame_count:
            return None
        curr_lanes = [False for _ in range(self.cfg.n_lane)]
        current_sop_lanes = [False for _ in range(self.cfg.n_lane)]
        self.frame_start_sop_pop_lanes = [False for _ in range(self.cfg.n_lane)]
        any_current_sop = False
        all_pending_are_sop = True
        min_future_frame: int | None = None
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            ticket = self.ticket_q[lane][0]
            if ticket.kind != KIND_SOP:
                all_pending_are_sop = False
                continue
            if ticket.frame == self.current_frame_idx:
                current_sop_lanes[lane] = True
                if (lane, ticket.frame) not in self.tail_dropped_lane_frames:
                    self.frame_start_sop_pop_lanes[lane] = True
                    curr_lanes[lane] = True
                any_current_sop = True
            elif ticket.frame > self.current_frame_idx:
                min_future_frame = ticket.frame if min_future_frame is None else min(min_future_frame, ticket.frame)

        if any_current_sop and all_pending_are_sop:
            if self.frame_start_waiting_busy_lane(self.current_frame_idx, cycle):
                return None
            if any(curr_lanes):
                return curr_lanes
            return curr_lanes
        if all_pending_are_sop and min_future_frame is not None:
            self.current_frame_idx = min_future_frame
            return self.frame_start_sop_lanes(cycle)
        return None

    def absorb_current_frame_sops(self, cycle: int) -> None:
        if self.current_frame is None:
            return
        for lane in range(self.cfg.n_lane):
            while self.ticket_q[lane]:
                ticket = self.ticket_q[lane][0]
                if ticket.kind != KIND_SOP:
                    break
                if ticket.frame < self.current_frame.frame:
                    self.pop_ticket(lane)
                    continue
                if ticket.frame != self.current_frame.frame:
                    break
                if (lane, ticket.frame) in self.tail_dropped_lane_frames:
                    key = (lane, ticket.frame)
                    ready_cycle = self.tail_dropped_sop_ready_cycle.get(key)
                    if ready_cycle is None:
                        self.tail_dropped_sop_ready_cycle[key] = cycle + self.tail_dropped_sop_delay_cycles
                        self.trace(
                            "tail_dropped_sop_hold",
                            lane=lane,
                            frame=ticket.frame,
                            serial=ticket.serial,
                            timestamp=ticket.timestamp,
                            ready_cycle=self.tail_dropped_sop_ready_cycle[key],
                        )
                        break
                    if cycle < ready_cycle:
                        break
                    self.pop_ticket(lane)
                    self.trace(
                        "tail_dropped_sop_advance_only",
                        lane=lane,
                        frame=ticket.frame,
                        serial=ticket.serial,
                        timestamp=ticket.timestamp,
                    )
                    break
                self.pop_ticket(lane)
                self.frame_active_lanes[lane] = True
                break

    def all_body_ready(self) -> bool:
        if self.current_frame is None:
            return False
        if self.current_shd_idx >= self.cfg.subheaders_per_frame:
            return all(self.frame_tail_seen[lane][self.current_frame.frame] for lane in range(self.cfg.n_lane))
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                return False
            ticket = self.ticket_q[lane][0]
            if (
                ticket.kind != KIND_BODY
                or ticket.frame != self.current_frame.frame
                or ticket.timestamp != self.allocator_running_ts
            ):
                return False
            if ticket.hit_count and len(self.handle_q[lane]) >= self.handle_fifo_depth:
                return False
        return True

    def ticket_shd(self, ticket: Ticket) -> int:
        return int(ticket.timestamp // OPQ_SUBHEADER_DURATION_TS_TICKS) % self.cfg.n_shd

    def drop_ticket_after_allocator_passed(self, lane: int, ticket: Ticket, reason: str = "allocator_passed") -> None:
        self.stats.postdrop_hits += ticket.hit_count
        self.stats.lane_postdrop_hits[lane] += ticket.hit_count
        credit_before = self.lane_credit[lane]
        self.lane_credit[lane] = min(self.lane_fifo_max_credit, self.lane_credit[lane] + ticket.hit_count)
        self.trace(
            "allocator_postdrop",
            lane=lane,
            frame=ticket.frame,
            serial=ticket.serial,
            timestamp=ticket.timestamp,
            hit_count=ticket.hit_count,
            lane_credit_before=credit_before,
            lane_credit_after=self.lane_credit[lane],
            drop_reason=reason,
        )

    def add_ft_drop_hits(self, hits: list[Hit]) -> None:
        self.stats.ft_drop_hits += len(hits)
        for hit in hits:
            self.stats.lane_ft_drop_hits[hit.lane] += 1

    def ticket_ready_for_current_subheader(self, ticket: Ticket, lane: int) -> bool:
        if self.current_frame is None:
            return False
        return (
            ticket.kind == KIND_BODY
            and ticket.frame == self.current_frame.frame
            and ticket.timestamp == self.allocator_running_ts
            and (ticket.hit_count == 0 or len(self.handle_q[lane]) < self.handle_fifo_depth)
        )

    def current_frame_has_future_ticket(self) -> bool:
        if self.current_frame is None:
            return False
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            ticket = self.ticket_q[lane][0]
            if (
                ticket.kind == KIND_BODY
                and ticket.frame == self.current_frame.frame
                and ticket.timestamp > self.allocator_running_ts
            ):
                return True
        return False

    def current_frame_has_pending_ticket(self) -> bool:
        if self.current_frame is None:
            return False
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            ticket = self.ticket_q[lane][0]
            if ticket.frame != self.current_frame.frame:
                continue
            if ticket.kind in {KIND_SOP, KIND_BODY}:
                return True
        return False

    def current_frame_tail_flush_ready(self) -> bool:
        if self.current_frame is None:
            return False
        frame = self.current_frame.frame
        if not any(self.frame_active_lanes):
            return False
        for lane, active in enumerate(self.frame_active_lanes):
            if active and not self.frame_tail_seen[lane][frame]:
                return False
        return not self.current_frame_has_pending_ticket()

    def current_timestamp_has_ready_ticket(self) -> bool:
        if self.current_frame is None:
            return False
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            if self.ticket_ready_for_current_subheader(self.ticket_q[lane][0], lane):
                return True
        return False

    def current_timestamp_waiting_handle_credit(self) -> bool:
        if self.current_frame is None:
            return False
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            ticket = self.ticket_q[lane][0]
            if (
                ticket.kind == KIND_BODY
                and ticket.frame == self.current_frame.frame
                and ticket.timestamp == self.allocator_running_ts
                and ticket.hit_count
                and len(self.handle_q[lane]) >= self.handle_fifo_depth
            ):
                return True
        return False

    def advance_future_gap(self, cycle: int) -> bool:
        if self.current_frame is None:
            return False
        if self.current_shd_idx >= self.cfg.subheaders_per_frame:
            return False
        if self.current_timestamp_has_ready_ticket():
            return False
        if not self.current_frame_has_future_ticket():
            return False
        self.current_shd_idx += 1
        self.allocator_running_ts += OPQ_SUBHEADER_DURATION_TS_TICKS
        self.allocator_next_cycle = cycle + self.future_gap_latency_cycles
        return True

    def begin_subheader_allocation(self) -> bool:
        tickets: list[Ticket | None] = [None for _ in range(self.cfg.n_lane)]
        any_ticket = False
        for lane in range(self.cfg.n_lane):
            if not self.ticket_q[lane]:
                continue
            ticket = self.ticket_q[lane][0]
            if not self.ticket_ready_for_current_subheader(ticket, lane):
                continue
            ticket = self.pop_ticket(lane)
            tickets[lane] = ticket
            any_ticket = True
        self.allocator_tickets = tickets
        self.allocator_lane_idx = 0
        self.allocator_accepted_any = False
        return any_ticket

    def finish_subheader_allocation(self, cycle: int) -> None:
        accepted_any = self.allocator_accepted_any
        if accepted_any and self.current_frame is not None:
            self.current_frame.length_words += 1
            self.current_emit_shd_count += 1
            self.page_allocator_busy_cycles += self.pa_accepted_subheader_mover_block_cycles
        self.allocator_tickets = None
        self.allocator_lane_idx = 0
        self.allocator_accepted_any = False
        self.current_shd_idx += 1
        self.allocator_running_ts += OPQ_SUBHEADER_DURATION_TS_TICKS
        lane_commit_span = self.alloc_lane_commit_cycles * max(1, self.cfg.n_lane)
        residual = max(1, self.subheader_latency_cycles - lane_commit_span)
        if accepted_any:
            residual += self.accepted_subheader_write_cycles
        self.allocator_next_cycle = cycle + residual
        self.stats.max_handle_fifo_used = max(self.stats.max_handle_fifo_used, max(len(q) for q in self.handle_q))

    def allocator_commit_one_lane(self, cycle: int) -> None:
        if self.allocator_tickets is None:
            return
        if self.current_frame is None:
            self.allocator_tickets = None
            return

        while self.allocator_lane_idx < self.cfg.n_lane:
            lane = self.allocator_lane_idx
            ticket = self.allocator_tickets[lane]
            self.allocator_lane_idx += 1
            if ticket is None or ticket.hit_count == 0:
                if ticket is not None:
                    self.trace(
                        "allocator_lane_action",
                        lane=lane,
                        frame=ticket.frame,
                        serial=ticket.serial,
                        timestamp=ticket.timestamp,
                        action="empty",
                        hit_count=ticket.hit_count,
                        running_ts=self.allocator_running_ts,
                    )
                self.allocator_next_cycle = cycle + self.alloc_lane_commit_cycles
                return
            room = self.frame_hit_room_limit - len(self.current_frame.hits)
            if ticket.hit_count <= room:
                self.allocator_accepted_any = True
                self.current_frame.hits.extend(ticket.hits)
                self.current_frame.length_words += ticket.hit_count
                self.handle_q[lane].append(
                    Handle(lane=lane, frame=ticket.frame, timestamp=ticket.timestamp, hits=ticket.hits)
                )
                self.trace(
                    "handle_accept",
                    lane=lane,
                    frame=ticket.frame,
                    serial=ticket.serial,
                    timestamp=ticket.timestamp,
                    hit_count=ticket.hit_count,
                    running_ts=self.allocator_running_ts,
                    handle_depth=len(self.handle_q[lane]),
                    page_len_next=self.current_frame.length_words,
                )
            else:
                self.trace(
                    "allocator_lane_action",
                    lane=lane,
                    frame=ticket.frame,
                    serial=ticket.serial,
                    timestamp=ticket.timestamp,
                    action="frame_full",
                    hit_count=ticket.hit_count,
                    running_ts=self.allocator_running_ts,
                    frame_hit_room=room,
                )
                self.drop_ticket_after_allocator_passed(lane, ticket, reason="frame_full")
            self.allocator_next_cycle = cycle + self.alloc_lane_commit_cycles
            return

        self.finish_subheader_allocation(cycle)

    def drop_stale_tickets(self) -> None:
        for lane in range(self.cfg.n_lane):
            while self.ticket_q[lane]:
                ticket = self.ticket_q[lane][0]
                if ticket.kind == KIND_SOP:
                    if ticket.frame < self.current_frame_idx:
                        self.pop_ticket(lane)
                        continue
                    break
                if ticket.kind != KIND_BODY:
                    break
                stale = ticket.frame < self.current_frame_idx
                if self.current_frame is not None and ticket.frame == self.current_frame.frame:
                    stale = stale or (ticket.timestamp < self.allocator_running_ts)
                if not stale:
                    break
                ticket = self.pop_ticket(lane)
                if ticket is not None and ticket.hit_count:
                    self.drop_ticket_after_allocator_passed(lane, ticket, reason="stale")

    def allocator_step(self, cycle: int) -> None:
        if cycle < self.allocator_next_cycle:
            return
        self.drop_stale_tickets()
        if self.allocator_tickets is not None:
            self.allocator_commit_one_lane(cycle)
            return
        if self.current_frame is None:
            sop_lanes = self.frame_start_sop_lanes(cycle)
            if sop_lanes is None:
                return
            pop_lanes = list(self.frame_start_sop_pop_lanes)
            sop_tickets = [self.pop_ticket(lane) if pop_lanes[lane] else None for lane in range(self.cfg.n_lane)]
            frame = self.current_frame_idx
            if not any(sop_lanes):
                self.trace(
                    "frame_tail_drop_skip",
                    frame=frame,
                    serial=frame & 0xFFFF,
                    tail_dropped_lane_mask=sum(
                        (1 << lane)
                        for lane in range(self.cfg.n_lane)
                        if (lane, frame) in self.tail_dropped_lane_frames
                    ),
                )
                self.current_frame_idx += 1
                self.allocator_next_cycle = cycle + self.frame_close_latency_cycles
                return
            self.current_frame = OutputFrame(
                frame=frame,
                serial=frame & 0xFFFF,
                start_addr=self.frame_start_addr,
                length_words=6,
                hits=[],
            )
            self.current_shd_idx = 0
            self.current_emit_shd_count = 0
            self.frame_active_lanes = list(sop_lanes)
            first_sop = next((ticket for ticket in sop_tickets if ticket is not None), None)
            if first_sop is not None:
                self.allocator_running_ts = first_sop.timestamp
            else:
                frame_step = self.cfg.frame_ts_step_ticks or frame_ts_step_ticks(self.cfg.n_shd)
                self.allocator_running_ts = frame * frame_step
            _ = sop_tickets
            self.page_allocator_busy_cycles += self.pa_frame_open_mover_block_cycles
            self.allocator_next_cycle = cycle + self.sop_open_latency_cycles
            self.trace(
                "frame_open",
                frame=frame,
                serial=frame & 0xFFFF,
                running_ts=self.allocator_running_ts,
                active_lane_mask=sum((1 << lane) for lane, active in enumerate(self.frame_active_lanes) if active),
                allocator_next_cycle=self.allocator_next_cycle,
            )
            return

        if self.current_frame is None:
            return

        self.absorb_current_frame_sops(cycle)

        if self.active_frame_waiting_busy_lane(cycle):
            self.allocator_next_cycle = cycle + 1
            return

        if self.current_timestamp_waiting_handle_credit():
            self.trace(
                "wait_handle_credit",
                frame=self.current_frame.frame,
                serial=self.current_frame.serial,
                running_ts=self.allocator_running_ts,
                current_shd_idx=self.current_shd_idx,
                handle_depth_max=max(len(q) for q in self.handle_q),
            )
            self.allocator_next_cycle = cycle + 1
            return

        if self.advance_future_gap(cycle):
            self.trace(
                "future_gap_advance",
                frame=self.current_frame.frame,
                serial=self.current_frame.serial,
                running_ts=self.allocator_running_ts,
                current_shd_idx=self.current_shd_idx,
                emitted_subheaders=self.current_emit_shd_count,
                allocator_next_cycle=self.allocator_next_cycle,
            )
            return

        if self.current_frame_tail_flush_ready():
            self.close_current_frame()
            self.allocator_next_cycle = cycle + self.frame_close_latency_cycles
            return

        self.trace(
            "allocator_fetch",
            frame=self.current_frame.frame,
            serial=self.current_frame.serial,
            running_ts=self.allocator_running_ts,
            current_shd_idx=self.current_shd_idx,
            emitted_subheaders=self.current_emit_shd_count,
            pending_mask=sum((1 << lane) for lane, q in enumerate(self.ticket_q) if q),
        )
        self.begin_subheader_allocation()
        self.allocator_commit_one_lane(cycle)

    def close_current_frame(self) -> None:
        if self.current_frame is None:
            return
        frame = self.current_frame
        frame.subheader_count = self.current_emit_shd_count
        frame.length_words = 6 + self.current_emit_shd_count + len(frame.hits)
        self.page_allocator_busy_cycles += self.pa_frame_close_mover_block_cycles
        if frame.subheader_count == 0 and not frame.hits:
            self.trace(
                "frame_empty_close",
                frame=frame.frame,
                serial=frame.serial,
                hit_count=0,
                length_words=0,
                subheader_count=0,
            )
            self.current_frame = None
            self.current_frame_idx += 1
            self.current_shd_idx = 0
            self.current_emit_shd_count = 0
            self.frame_active_lanes = [False for _ in range(self.cfg.n_lane)]
            self.allocator_running_ts = 0
            return
        if frame.length_words >= self.page_ram_depth:
            self.add_ft_drop_hits(frame.hits)
        else:
            self.output_frames.append(frame)
            self.drop_overwritten_frames(frame)
            self.frame_start_addr = (frame.start_addr + frame.length_words) % self.page_ram_depth
        self.trace(
            "frame_close",
            frame=frame.frame,
            serial=frame.serial,
            hit_count=len(frame.hits),
            length_words=frame.length_words,
            subheader_count=frame.subheader_count,
        )
        self.current_frame = None
        self.current_frame_idx += 1
        self.current_shd_idx = 0
        self.current_emit_shd_count = 0
        self.frame_active_lanes = [False for _ in range(self.cfg.n_lane)]
        self.allocator_running_ts = 0

    def drop_overwritten_frames(self, new_frame: OutputFrame) -> None:
        while self.output_frames and self.output_frames[0] is not new_frame:
            head = self.output_frames[0]
            if head.started_egress:
                break
            if not ranges_overlap(new_frame.start_addr, new_frame.length_words, head.start_addr, head.length_words, self.page_ram_depth):
                break
            dropped = self.output_frames.popleft()
            self.add_ft_drop_hits(dropped.hits)

    def block_mover_step(self) -> None:
        if self.page_allocator_busy_cycles > 0:
            self.page_allocator_busy_cycles -= 1
            return
        for queue in self.handle_q:
            if queue and queue[0].started and queue[0].startup_wait > 0:
                queue[0].startup_wait -= 1

        if self.drr_locked_lane is not None:
            lane = self.drr_locked_lane
            if self.service_locked_lane(lane):
                return
            self.drr_locked_lane = None

        for _ in range(self.cfg.n_lane):
            lane = self.drr_ptr
            self.drr_ptr = (self.drr_ptr + 1) % self.cfg.n_lane
            if not self.handle_q[lane]:
                continue
            handle = self.handle_q[lane][0]
            if not handle.started:
                handle.started = True
                handle.startup_wait = self.handle_startup_cycles
                continue
            if handle.startup_wait > 0:
                continue
            if self.drr_quantum[lane] < len(handle.hits):
                self.drr_quantum[lane] = min(1023, self.drr_quantum[lane] + self.drr_allowance[lane])
                continue
            self.drr_locked_lane = lane
            self.service_locked_lane(lane)
            break
        active_frames = {h.frame for q in self.handle_q for h in q}
        for frame in self.output_frames:
            if frame.frame not in active_frames:
                frame.ready_for_egress = True

    def service_locked_lane(self, lane: int) -> bool:
        if not self.handle_q[lane]:
            return False
        handle = self.handle_q[lane][0]
        if not handle.started or handle.startup_wait > 0:
            return False
        if self.drr_quantum[lane] <= 0:
            return False
        handle.offset += 1
        self.drr_quantum[lane] -= 1
        if handle.offset >= len(handle.hits):
            self.handle_q[lane].popleft()
            credit_before = self.lane_credit[lane]
            self.lane_credit[lane] = min(self.lane_fifo_max_credit, self.lane_credit[lane] + len(handle.hits))
            self.drr_locked_lane = None
            self.drr_ptr = (lane + 1) % self.cfg.n_lane
            self.trace(
                "credit_return",
                lane=lane,
                frame=handle.frame,
                serial=handle.frame & 0xFFFF,
                timestamp=handle.timestamp,
                hit_count=len(handle.hits),
                lane_credit_before=credit_before,
                lane_credit_after=self.lane_credit[lane],
                handle_depth=len(self.handle_q[lane]),
            )
        return True

    def egress_step(self, cycle: int) -> None:
        symbols = max(1, self.cfg.egress_symbols_per_beat)
        if self.egress_current is None:
            if self.output_frames and self.output_frames[0].ready_for_egress:
                self.egress_current = self.output_frames[0]
                self.egress_current.started_egress = True
        if self.egress_current is None:
            return
        if not ready_active(cycle, self.cfg.ready_duty_ppm):
            return
        for _ in range(symbols):
            frame = self.egress_current
            if frame.egress_word_idx >= frame.length_words:
                self.output_frames.popleft()
                self.egress_current = None
                break
            hit_start_word = 6 + frame.subheader_count
            hit_idx = frame.egress_word_idx - hit_start_word
            if 0 <= hit_idx < len(frame.hits):
                self.egress_hits.append(frame.hits[hit_idx])
                self.stats.delivered_hits += 1
            frame.egress_word_idx += 1

    def run(self) -> TlmStats:
        self.build_stimulus()
        last_event_cycle = max(self.events.keys(), default=0)
        frame_period = (
            self.cfg.frame_launch_period_cycles
            or self.cfg.inter_frame_gap_cycles
            or default_frame_launch_period_cycles(self.cfg.n_shd)
        )
        max_cycles = last_event_cycle + frame_period + 10_000_000
        cycle = 0
        while cycle <= max_cycles:
            self.cycle = cycle
            for kind, item in self.events.pop(cycle, []):
                if kind in {KIND_SOP, KIND_BODY}:
                    self.enqueue_ticket(item)  # type: ignore[arg-type]
                elif kind == "body_check":
                    self.precheck_body_ticket(item)  # type: ignore[arg-type]
                elif kind == "body_complete":
                    ticket = item  # type: ignore[assignment]
                    if not ticket.dropped:
                        self.enqueue_ticket(ticket)
                elif kind == "tail":
                    lane, frame = item  # type: ignore[misc]
                    self.frame_tail_seen[lane][frame] = True
                    if self.parser_frame_masked[lane][frame]:
                        if frame + 1 < self.cfg.frame_count:
                            self.tail_dropped_lane_frames.add((lane, frame))
                            self.trace(
                                "parser_tail_dropped",
                                lane=lane,
                                frame=frame,
                                serial=frame & 0xFFFF,
                            )
                        else:
                            self.trace(
                                "parser_tail_dropped_terminal_suppressed",
                                lane=lane,
                                frame=frame,
                                serial=frame & 0xFFFF,
                            )
            self.allocator_step(cycle)
            self.block_mover_step()
            self.egress_step(cycle)
            self.stats.max_page_frames = max(self.stats.max_page_frames, len(self.output_frames))
            self.stats.max_page_words = max(self.stats.max_page_words, sum(frame.length_words for frame in self.output_frames))
            if self.done():
                self.stats.max_cycle = cycle
                return self.stats
            cycle += 1
        self.stats.max_cycle = max_cycles
        return self.stats

    def done(self) -> bool:
        return (
            not self.events
            and self.current_frame is None
            and self.current_frame_idx >= self.cfg.frame_count
            and all(not q for q in self.ticket_q)
            and all(not q for q in self.handle_q)
            and not self.output_frames
            and self.egress_current is None
        )


def ready_active(cycle: int, ready_duty_ppm: int) -> bool:
    if ready_duty_ppm >= 1_000_000:
        return True
    if ready_duty_ppm <= 0:
        return False
    period = 37
    high = max(0, min(period, int((ready_duty_ppm * period + 999_999) / 1_000_000)))
    return (cycle % period) < high


def ranges_overlap(a_start: int, a_len: int, b_start: int, b_len: int, depth: int) -> bool:
    if a_len <= 0 or b_len <= 0:
        return False
    if a_len >= depth or b_len >= depth:
        return True
    return circular_contains(a_start, a_len, b_start, depth) or circular_contains(b_start, b_len, a_start, depth)


def circular_contains(start: int, length: int, point: int, depth: int) -> bool:
    return ((point - start) % depth) < length


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="ascii") as handle:
        return list(csv.DictReader(handle))


def int_field(row: dict[str, str], name: str, default: int = 0) -> int:
    value = row.get(name, "")
    return int(value) if value not in {"", None} else default


def configs_from_rtl_rows(rows: list[dict[str, str]]) -> list[CaseConfig]:
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        groups[row["run_tag"]].append(row)
    configs: list[CaseConfig] = []
    for tag, group in sorted(groups.items()):
        row = group[0]
        expected = sum(int_field(r, "expected_hits") for r in group)
        dropped = sum(int_field(r, "dropped_hits") for r in group)
        configs.append(
            CaseConfig(
                run_tag=tag,
                case=row.get("case", "RTL-LS-002"),
                profile=int_field(row, "profile", 3),
                n_lane=int_field(row, "n_lane", 4),
                n_shd=int_field(row, "n_shd", 128),
                egress_symbols_per_beat=int_field(row, "egress_symbols_per_beat", 1),
                ready_duty_ppm=int_field(row, "ready_duty_ppm", 1_000_000),
                rho_ppm=int_field(row, "rho_ppm", 0),
                burstiness_milli=int_field(row, "burstiness_milli", 0),
                frame_count=int_field(row, "frame_count", 1),
                subheaders_per_frame=int_field(row, "subheaders_per_frame", 128),
                inter_frame_gap_cycles=int_field(
                    row,
                    "inter_frame_gap_cycles",
                    default_frame_launch_period_cycles(int_field(row, "n_shd", 128)),
                ),
                noise_rho_ppm=int_field(row, "noise_rho_ppm", 0),
                cluster_rho_ppm=int_field(row, "cluster_rho_ppm", 0),
                cluster_size_min=int_field(row, "cluster_size_min", 4),
                cluster_size_max=int_field(row, "cluster_size_max", 8),
                rng_seed=int_field(row, "rng_seed", 0x5C1F0001),
                rtl_expected_hits=expected,
                rtl_dropped_hits=dropped,
                lane_fifo_depth=int_field(
                    row,
                    "lane_fifo_depth",
                    default_lane_fifo_depth(
                        int_field(row, "n_lane", 4),
                        int_field(row, "n_shd", 128),
                    ),
                ),
                ticket_fifo_depth=int_field(row, "ticket_fifo_depth", MU3E_DEMO_TICKET_FIFO_DEPTH),
                handle_fifo_depth=int_field(row, "handle_fifo_depth", MU3E_DEMO_HANDLE_FIFO_DEPTH),
                page_ram_depth=int_field(row, "page_ram_depth", MU3E_DEMO_PAGE_RAM_DEPTH),
                frame_ts_step_ticks=int_field(
                    row,
                    "frame_ts_step_ticks",
                    frame_ts_step_ticks(int_field(row, "n_shd", 128)),
                ),
                frame_launch_period_cycles=int_field(
                    row,
                    "frame_launch_period_cycles",
                    int_field(
                        row,
                        "inter_frame_gap_cycles",
                        default_frame_launch_period_cycles(int_field(row, "n_shd", 128)),
                    ),
                ),
                feb_header_latency_cycles=int_field(
                    row,
                    "feb_header_latency_cycles",
                    OPQ_VIRTUAL_FEB_HEADER_LATENCY_CYCLES,
                ),
            )
        )
    return configs


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "run_tag",
        "case",
        "n_lane",
        "egress_symbols_per_beat",
        "rho_ppm",
        "burstiness_milli",
        "frame_count",
        "subheaders_per_frame",
        "inter_frame_gap_cycles",
        "lane_fifo_depth",
        "ticket_fifo_depth",
        "handle_fifo_depth",
        "page_ram_depth",
        "frame_ts_step_ticks",
        "frame_launch_period_cycles",
        "feb_header_latency_cycles",
        "tlm_offered_hits",
        "rtl_expected_hits",
        "tlm_dropped_hits",
        "tlm_predrop_hits",
        "tlm_postdrop_hits",
        "tlm_ft_drop_hits",
        "tlm_lane_predrop_hits",
        "tlm_lane_postdrop_hits",
        "tlm_lane_ft_drop_hits",
        "tlm_lane_dropped_hits",
        "rtl_dropped_hits",
        "tlm_loss",
        "rtl_loss",
        "max_lane_fifo_used",
        "max_ticket_fifo_used",
        "max_handle_fifo_used",
        "max_page_frames",
        "max_page_words",
        "max_cycle",
        "sequence_monotonic",
    ]
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def run_config(cfg: CaseConfig) -> dict[str, object]:
    tlm = OpqStructuralTlm(
        cfg,
        lane_fifo_depth=cfg.lane_fifo_depth,
        ticket_fifo_depth=cfg.ticket_fifo_depth,
        handle_fifo_depth=cfg.handle_fifo_depth,
        page_ram_depth=cfg.page_ram_depth,
    )
    stats = tlm.run()
    rtl_loss = cfg.rtl_dropped_hits / cfg.rtl_expected_hits if cfg.rtl_expected_hits else 0.0
    monotonic = all(
        (
            tlm.egress_hits[i - 1].frame,
            tlm.egress_hits[i - 1].timestamp,
            tlm.egress_hits[i - 1].lane,
            tlm.egress_hits[i - 1].shd,
            tlm.egress_hits[i - 1].idx,
        )
        <= (
            tlm.egress_hits[i].frame,
            tlm.egress_hits[i].timestamp,
            tlm.egress_hits[i].lane,
            tlm.egress_hits[i].shd,
            tlm.egress_hits[i].idx,
        )
        for i in range(1, len(tlm.egress_hits))
    )
    return {
        "run_tag": cfg.run_tag,
        "case": cfg.case,
        "n_lane": cfg.n_lane,
        "egress_symbols_per_beat": cfg.egress_symbols_per_beat,
        "rho_ppm": cfg.rho_ppm,
        "burstiness_milli": cfg.burstiness_milli,
        "frame_count": cfg.frame_count,
        "subheaders_per_frame": cfg.subheaders_per_frame,
        "inter_frame_gap_cycles": cfg.inter_frame_gap_cycles,
        "lane_fifo_depth": cfg.lane_fifo_depth,
        "ticket_fifo_depth": cfg.ticket_fifo_depth,
        "handle_fifo_depth": cfg.handle_fifo_depth,
        "page_ram_depth": cfg.page_ram_depth,
        "frame_ts_step_ticks": cfg.frame_ts_step_ticks or frame_ts_step_ticks(cfg.n_shd),
        "frame_launch_period_cycles": cfg.frame_launch_period_cycles
        or cfg.inter_frame_gap_cycles
        or default_frame_launch_period_cycles(cfg.n_shd),
        "feb_header_latency_cycles": cfg.feb_header_latency_cycles,
        "tlm_offered_hits": stats.offered_hits,
        "rtl_expected_hits": cfg.rtl_expected_hits,
        "tlm_dropped_hits": stats.dropped_hits,
        "tlm_predrop_hits": stats.predrop_hits,
        "tlm_postdrop_hits": stats.postdrop_hits,
        "tlm_ft_drop_hits": stats.ft_drop_hits,
        "tlm_lane_predrop_hits": ";".join(str(v) for v in stats.lane_predrop_hits),
        "tlm_lane_postdrop_hits": ";".join(str(v) for v in stats.lane_postdrop_hits),
        "tlm_lane_ft_drop_hits": ";".join(str(v) for v in stats.lane_ft_drop_hits),
        "tlm_lane_dropped_hits": ";".join(
            str(stats.lane_predrop_hits[lane] + stats.lane_postdrop_hits[lane] + stats.lane_ft_drop_hits[lane])
            for lane in range(cfg.n_lane)
        ),
        "rtl_dropped_hits": cfg.rtl_dropped_hits,
        "tlm_loss": stats.loss,
        "rtl_loss": rtl_loss,
        "max_lane_fifo_used": stats.max_lane_fifo_used,
        "max_ticket_fifo_used": stats.max_ticket_fifo_used,
        "max_handle_fifo_used": stats.max_handle_fifo_used,
        "max_page_frames": stats.max_page_frames,
        "max_page_words": stats.max_page_words,
        "max_cycle": stats.max_cycle,
        "sequence_monotonic": int(monotonic),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--run-tag", action="append", default=[])
    parser.add_argument(
        "--mu3e-demo-profile",
        action="store_true",
        help=(
            "Override per-row FIFO/RAM fields with the Mu3e Demo profile: "
            "N_LANE=4, N_SHD=128, lane FIFO=2048, ticket FIFO=1024, "
            "handle FIFO=256, page RAM=65536."
        ),
    )
    args = parser.parse_args()

    configs = configs_from_rtl_rows(read_csv(args.input))
    if args.run_tag:
        allowed = set(args.run_tag)
        configs = [cfg for cfg in configs if cfg.run_tag in allowed]
    if args.mu3e_demo_profile:
        configs = [
            replace(
                cfg,
                n_lane=MU3E_DEMO_N_LANE,
                n_shd=MU3E_DEMO_N_SHD,
                lane_fifo_depth=MU3E_DEMO_LANE_FIFO_DEPTH,
                ticket_fifo_depth=MU3E_DEMO_TICKET_FIFO_DEPTH,
                handle_fifo_depth=MU3E_DEMO_HANDLE_FIFO_DEPTH,
                page_ram_depth=MU3E_DEMO_PAGE_RAM_DEPTH,
            )
            for cfg in configs
        ]
    rows = [run_config(cfg) for cfg in configs]
    write_rows(args.output, rows)
    for row in rows:
        print(
            "OPQ_STRUCT_TLM "
            f"run_tag={row['run_tag']} tlm_loss={float(row['tlm_loss']):.12g} "
            f"rtl_loss={float(row['rtl_loss']):.12g} "
            f"tlm_drop={row['tlm_dropped_hits']} rtl_drop={row['rtl_dropped_hits']} "
            f"seq={row['sequence_monotonic']}"
        )
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

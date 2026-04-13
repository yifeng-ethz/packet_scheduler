# DV Bucket: DV_PROF — ordered_priority_queue (monolithic)

**Companion to:** DV_PLAN.md, DV_HARNESS.md
**Bucket prefix:** P   **ID range:** P001..P168   **Minimum cases:** 128

This bucket catalogs the performance, stress, and long-soak runs for the
monolithic OPQ. Every case is a throughput/latency/fairness measurement with
a numeric KPI. Directed bring-up rows live in `DV_BASIC.md`, boundary rows in
`DV_EDGE.md`, fault injection in `DV_ERROR.md`, and multi-axis coverage
closure in `DV_CROSS.md`.

---

## 1. Scope

DV_PROF answers four questions about the DUT:

1. **Can it sustain line rate?** At the admissible offered load for a given
   configuration, does every ingress beat become an egress beat, and does
   the effective throughput stay within 1% of the theoretical ceiling?
2. **Is backpressure handled without leaking or hanging?** Over long duty
   cycles and toggle periods, does RESTART/refill (F1) recover cleanly, and
   do FIFO occupancies reach a stable steady state?
3. **Is the arbiter fair?** Under saturated offered load, does every lane
   get serviced within a bounded number of frames? No lane is allowed to
   starve for more than `2*N_LANE` frames.
4. **Does long-run bookkeeping drift?** Over 1M..100M beats, do `running_ts`,
   segment rotation, arbiter lock windows, and ticket/handle credit
   accounting stay internally consistent?

Non-goals (explicitly handed off to other buckets):

- **Single-boundary FIFO full/empty cases** → `DV_EDGE`.
- **Multi-axis coverage closure** (bp × skew × mode × track_header) where
  the primary purpose is hitting cross bins, not reporting a KPI → `DV_CROSS`.
- **Reset-in-state / error injection** → `DV_ERROR`.
- **Mode switch latency** (requires Qsys regen mid-sim) — out of scope for
  DV entirely.

---

## 2. KPI Definitions

All KPIs are reported per transaction by the scoreboard. The env captures
them from the probe port and the egress monitor. Numeric targets below are
relative to the 4-lane MERGING reference config unless stated.

| KPI | Symbol | Definition | Default pass criterion |
|-----|--------|------------|------------------------|
| Egress throughput | `thr_eg` | `accepted_egress_beats / d_clk_cycles` over the measurement window, after warmup. | ≥ 0.99 × theoretical ceiling (see 2.1). |
| Ingress throughput | `thr_in[lane]` | `accepted_ingress_beats[lane] / d_clk_cycles` per lane. | ≥ 0.99 at 100% offered duty when admissible. |
| Per-hit latency | `lat_hit` | Cycles from ingress monitor accepting a hit word to egress monitor emitting the same hit word. Mean / p50 / p99 / max are all reported. | Mean ≤ `LAT_MEAN_BUDGET`; p99 ≤ `LAT_P99_BUDGET`; max finite and bounded (see 2.2). |
| Service latency per lane | `svc_lat[lane]` | Cycles between consecutive arbiter LOCKED windows owned by the same lane, saturated. | ≤ `2 × N_LANE` frame periods (from F9). |
| FIFO peak occupancy | `peak_lane`, `peak_ticket`, `peak_handle` | Max `wptr-rptr` over the measurement window, per instance. | Bounded, no drop (no mask entry, no handle-drop). |
| RESTART rate | `rate_rst` | Count of `ftable_presenter.RESTART` entries per 1e6 egress beats. | Within ±5% of theoretical `1/(ready_off_run_length + 1)`. |
| Page RAM dwell | `dwell_pr` | Cycles between the clock cycle a word is written into page RAM and the cycle it is read out. Mean / max reported. | Finite; max < `PAGE_RAM_DEPTH * dwell_safety_factor`. |
| Drop counters | `drop_*` | Reference-model drop counters, per FIFO. | **Zero** for all admissible-rate cases in DV_PROF. |
| Running_ts drift | `drift_ts` | `|running_ts_DUT - running_ts_ref|` sampled at end-of-txn. | 0 (exact match). |

### 2.1 Theoretical ceiling

For `INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH=36` and `PAGE_RAM_RD_WIDTH=36`,
the ceiling is 1 egress beat/cycle. For `PAGE_RAM_RD_WIDTH=72/144/288`, the
ceiling is `PAGE_RAM_RD_WIDTH/36` ingress symbols per egress cycle. In
MERGING mode with all N_LANE at 100% duty and admissible load, `thr_eg`
approaches the ceiling minus arbiter lock-release overhead.

### 2.2 Latency budgets

Budgets are per-config and tabulated inside `opq_config::LAT_BUDGET_TABLE`.
The reference values for the 4-lane default config are:

- `LAT_MEAN_BUDGET = 2 * HDR_SIZE + 2 * N_SHD + 32` (pipe + lock + presenter)
- `LAT_P99_BUDGET  = 4 * LAT_MEAN_BUDGET`
- `LAT_MAX_BUDGET  = 16 * LAT_MEAN_BUDGET` (includes one RESTART window)

A test using a deeper `LANE_FIFO_DEPTH` scales `LAT_P99_BUDGET` by
`LANE_FIFO_DEPTH / 1024`.

### 2.3 Reporting format

Every DV_PROF run emits a `opq_prof_report.csv` line with
`{test_id, config_tag, thr_eg, lat_mean, lat_p99, lat_max, peak_lane,
peak_ticket, peak_handle, rate_rst, drift_ts}`. Regression diff against the
golden CSV is what flags a performance regression; the UVM `PASS/FAIL` only
encodes the pass/fail column.

---

## 3. Configuration Groups

DV_PROF cases point at these named configs. Each tag is compiled once and
then re-used across any row that shares it.

| Tag | N_LANE | MODE | TRACK_HEADER | LANE_FIFO_DEPTH | TICKET_FIFO_DEPTH | HANDLE_FIFO_DEPTH | PAGE_RAM_DEPTH | PAGE_RAM_RD_WIDTH | N_SHD | N_HIT | DEBUG_LV | Notes |
|-----|--------|------|--------------|-----------------|-------------------|-------------------|----------------|-------------------|-------|-------|----------|-------|
| CFG_REF | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Nightly reference (same as DV_HARNESS §2). |
| CFG_REF_MUX | 4 | MULTIPLEXING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Reference for MUX mode comparisons. |
| CFG_L1 | 1 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Single lane, no arbiter contention. |
| CFG_L2 | 2 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Min non-trivial arbiter. |
| CFG_L8 | 8 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Medium fan-in. |
| CFG_L16 | 16 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Max fan-in. |
| CFG_RD72 | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 72 | 256 | 255 | 1 | 2 symbols/beat. |
| CFG_RD144 | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 144 | 256 | 255 | 1 | 4 symbols/beat. |
| CFG_RD288 | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 288 | 256 | 255 | 1 | 8 symbols/beat. |
| CFG_PR8K | 4 | MERGING | true | 1024 | 128 | 128 | 8192 | 36 | 256 | 255 | 1 | Smallest PAGE_RAM_DEPTH. |
| CFG_PR16K | 4 | MERGING | true | 1024 | 128 | 128 | 16384 | 36 | 256 | 255 | 1 | 16k PAGE_RAM_DEPTH. |
| CFG_PR32K | 4 | MERGING | true | 1024 | 128 | 128 | 32768 | 36 | 256 | 255 | 1 | 32k PAGE_RAM_DEPTH. |
| CFG_PR64K | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | 64k (== CFG_REF for dwell sweeps). |
| CFG_LFD64 | 4 | MERGING | true | 64 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Shallow lane FIFO. |
| CFG_LFD4K | 4 | MERGING | true | 4096 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | Deep lane FIFO. |
| CFG_TFD16 | 4 | MERGING | true | 1024 | 16 | 128 | 65536 | 36 | 256 | 255 | 1 | Ticket FIFO credit corner. |
| CFG_HFD16 | 4 | MERGING | true | 1024 | 128 | 16 | 65536 | 36 | 256 | 255 | 1 | Handle FIFO corner. |
| CFG_DBG0 | 4 | MERGING | true | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 0 | Debug instrumentation disabled. |
| CFG_NOTRK | 4 | MERGING | false | 1024 | 128 | 128 | 65536 | 36 | 256 | 255 | 1 | TRACK_HEADER=false. |

---

## 4. Test Case Catalog

Columns: `ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status`.
All rows start at `planned`. KPIs are numeric; vague entries are not permitted.

### 4.1 Sustained line-rate per lane (P001..P016)

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P001 | CFG_L1 | 1 frame × 100% ingress duty on lane 0. Egress ALWAYS_READY. | `thr_eg ≥ 0.99`; `drop_*=0`; `lat_mean ≤ LAT_MEAN_BUDGET`. | cov_cfg{n_lane=1}, cov_flow{ready=100%} | `ingress_parser[0]→lane_fifo→ticket_fifo→page_allocator→page_ram→ftable_presenter`. Baseline single-lane throughput; regression mode: pipeline bubble insertion or ticket-fetch stall. | planned |
| P002 | CFG_L1 | 10 frames × 100% duty. | Same as P001, repeated across 10 frames; `drift_ts=0` at end-of-txn. | cov_pkt{hdr_size_words}, cov_fsm{page_allocator} | Confirms `frame_ts` advance timing (F3) holds under back-to-back frames. Regression: off-by-one in `FETCH_TICKET→WRITE_HEAD`. | planned |
| P003 | CFG_L1 | 100 frames × 100% duty. | As above; `peak_lane ≤ HDR_SIZE + N_SHD*2`. | cov_fsm{ftable_presenter} | 100-frame warmup verifies steady state reached; regression: progressive backlog. | planned |
| P004 | CFG_L1 | 1000 frames × 100% duty. | As above; additionally `peak_ticket ≤ 8`, `peak_handle ≤ 8`. | cov_flow{ticket_fifo_occupancy}, cov_flow{handle_fifo_occupancy} | Long-run FIFO levels; regression: slow credit leak in lane or ticket FIFOs. | planned |
| P005 | CFG_L2 | 1000 frames × 100% duty, both lanes in phase. | `thr_eg ≥ 0.99`; per-lane `thr_in ≥ 0.99`; `drop_*=0`. | cov_cfg{n_lane=2} | `arbiter` must alternate LOCKED between two lanes without thrash. Regression: arbiter unfairness at N_LANE=2. | planned |
| P006 | CFG_REF | 1 frame × 100% duty on all 4 lanes, in phase. | `thr_eg ≥ 0.99`; `svc_lat[*] ≤ 2*N_LANE` frames. | cov_cfg{n_lane=4} | Default-config baseline; parent for sweeps P007..P009. | planned |
| P007 | CFG_REF | 10 frames × 100% duty, all 4 lanes. | `thr_eg ≥ 0.99`; `peak_lane ≤ 4*HDR_SIZE`. | cov_fsm{block_mover} | 10-frame window; verifies `block_mover` drain keeps up with `page_allocator.WRITE_PAGE`. | planned |
| P008 | CFG_REF | 100 frames × 100% duty, all 4 lanes. | As P007; `drift_ts=0`. | cov_pkt{frame_ts_wrap} | Long window; regression: `running_ts` lag with 4 concurrent SOP tickets (F4). | planned |
| P009 | CFG_REF | 1000 frames × 100% duty, all 4 lanes. | As P008; additionally `rate_rst=0` (no RESTART if ready always high). | cov_fsm{ftable_presenter} | Confirms ALWAYS_READY path never detours through RESTART. | planned |
| P010 | CFG_L8 | 1000 frames × 100% duty, all 8 lanes. | `thr_eg ≥ 0.98`; `svc_lat[*] ≤ 2*N_LANE` frames. | cov_cfg{n_lane=8} | 8-lane arbiter pressure; `arbiter` LOCKED window dominates. Regression: arbiter state leakage. | planned |
| P011 | CFG_L16 | 1000 frames × 100% duty, all 16 lanes. | `thr_eg ≥ 0.97`; `svc_lat[*] ≤ 2*N_LANE=32` frames. | cov_cfg{n_lane=16} | 16-lane stress; worst-case arbiter rotation; regression: per-lane handle-fifo starvation. | planned |
| P012 | CFG_LFD64 | 100 frames × 100% duty, 4 lanes. | `thr_eg ≥ 0.97`; `peak_lane ≤ LANE_FIFO_DEPTH-1`; `drop_*=0`. | cov_cfg{lane_fifo_depth=64} | Small lane FIFO; regression: parser re-fetch stall when lane_fifo nearly full. | planned |
| P013 | CFG_LFD4K | 1000 frames × 100% duty, 4 lanes. | `thr_eg ≥ 0.99`; `peak_lane` unrestricted, but `lat_max ≤ LAT_MAX_BUDGET*4`. | cov_cfg{lane_fifo_depth=4096} | Deep lane FIFO; regression: dwell accumulation. | planned |
| P014 | CFG_RD72 | 100 frames × 100% duty, 4 lanes. | `thr_eg ≥ 0.99` measured in symbols/cycle (= 2 × beats/cycle). | cov_cfg{page_ram_rd_width=72} | Wider egress bus; regression: `empty` field mis-packing when 2 symbols/beat. | planned |
| P015 | CFG_RD144 | 100 frames × 100% duty, 4 lanes. | `thr_eg ≥ 0.99` measured in symbols/cycle (= 4). | cov_cfg{page_ram_rd_width=144} | Wider egress; checks presenter packing at 4 symbols/beat. | planned |
| P016 | CFG_RD288 | 100 frames × 100% duty, 4 lanes. | `thr_eg ≥ 0.99` measured in symbols/cycle (= 8). | cov_cfg{page_ram_rd_width=288} | Widest egress; regression: last-beat `empty` mispack at 8 symbols/beat. | planned |

### 4.2 Egress backpressure duty-cycle sweeps (P017..P032)

Parent row P017 defines the sweep envelope; children P018..P024 pin each
duty value. The measurement window is 1000 frames in each child unless
noted.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P017 | CFG_REF | Duty-cycle sweep parent: ready held at {100,90,75,50,25,10,5,1}% over 1000 frames each. | Per-duty table of `thr_eg`, `rate_rst`, `peak_lane`, `peak_ticket`. See children. | cov_flow{egress_ready_duty} | `ftable_presenter` RESTART refill pipeline (F1). Parent of P018..P024; sweep must populate the entire duty bin. | planned |
| P018 | CFG_REF | ready=100% for the full window. | `thr_eg ≥ 0.99`; `rate_rst=0`. | cov_flow{ready_duty=100} | Baseline; no RESTART. Regression: spurious RESTART under non-stalled load. | planned |
| P019 | CFG_REF | ready=90% (10 off in 100-cycle windows). | `thr_eg ≈ 0.90 ± 0.005`; `rate_rst` within 5% of theoretical. | cov_flow{ready_duty=90} | One RESTART per off-window; regression: RESTART overshoot. | planned |
| P020 | CFG_REF | ready=75%. | `thr_eg ≈ 0.75 ± 0.005`. | cov_flow{ready_duty=75} | Frequent RESTART; regression: refill stall. | planned |
| P021 | CFG_REF | ready=50%. | `thr_eg ≈ 0.50 ± 0.005`; `peak_lane ≤ LANE_FIFO_DEPTH/2`. | cov_flow{ready_duty=50} | Steady-state fill reaches the lane FIFO mid-line. Regression: credit saturation. | planned |
| P022 | CFG_REF | ready=25%. | `thr_eg ≈ 0.25 ± 0.005`; `peak_lane ≤ LANE_FIFO_DEPTH*3/4`. | cov_flow{ready_duty=25} | Upstream backlog; regression: slow drain on refill. | planned |
| P023 | CFG_REF | ready=10%. | `thr_eg ≈ 0.10 ± 0.005`; `peak_lane` approaches LANE_FIFO_DEPTH but `drop_*=0` if offered rate ≤ admissible. | cov_flow{ready_duty=10} | Heavy backpressure; regression: RESTART thrash. | planned |
| P024 | CFG_REF | ready=5%. | `thr_eg ≈ 0.05 ± 0.005`. Offered rate intentionally matched; `drop_*=0`. | cov_flow{ready_duty=5} | Sustained very-low duty; regression: RESTART rollback miscount. | planned |
| P025 | CFG_REF | ready=1%. | `thr_eg ≈ 0.01 ± 0.002`; `drop_*=0` with matched offered rate. | cov_flow{ready_duty=1} | Minimum non-zero duty; regression: RESTART entry/exit unbalanced. | planned |
| P026 | CFG_L1 | ready=50%, 1000 frames, single lane. | `thr_eg ≈ 0.50`; `rate_rst` matches theoretical, no arbiter involvement. | cov_cfg{n_lane=1}, cov_flow{ready_duty=50} | Isolates RESTART behaviour from arbiter. Regression: presenter refill independent of lane count. | planned |
| P027 | CFG_L8 | ready=50%, 1000 frames, 8 lanes. | `thr_eg ≈ 0.50`; `svc_lat[*] ≤ 4*N_LANE` frames. | cov_cfg{n_lane=8}, cov_flow{ready_duty=50} | Fairness under backpressure; regression: lane starvation when presenter stalls. | planned |
| P028 | CFG_L16 | ready=50%, 1000 frames, 16 lanes. | `thr_eg ≈ 0.50`; `svc_lat[*] ≤ 4*N_LANE` frames. | cov_cfg{n_lane=16}, cov_flow{ready_duty=50} | Max fan-in × heavy bp; regression: `arbiter` LOCKED leakage under RESTART. | planned |
| P029 | CFG_REF_MUX | ready=50%, 1000 frames. | `thr_eg ≈ 0.50`; per-lane `thr_in ≈ 0.125` (round-robin). | cov_cfg{mode=MUX}, cov_flow{ready_duty=50} | MUX path has a different presenter trigger; regression: MUX bp handling divergence from MERGING. | planned |
| P030 | CFG_NOTRK | ready=50%, 1000 frames. | As P021 but TRACK_HEADER=false. | cov_cfg{track_header=false} | Header-tracking path optional under bp; regression: header-less presenter refill. | planned |
| P031 | CFG_RD72 | ready=50%, 1000 frames. | `thr_eg ≈ 0.50` symbols/cycle; `empty` on stall-boundary beats matches reference. | cov_cfg{rd_width=72}, cov_flow{ready_duty=50} | Mid-beat stall at 2 sym/beat; regression: empty rollback mismatch. | planned |
| P032 | CFG_RD288 | ready=50%, 1000 frames. | `thr_eg ≈ 0.50` symbols/cycle; `empty` rollback correct. | cov_cfg{rd_width=288}, cov_flow{ready_duty=50} | 8 sym/beat stall; regression: presenter roll-back by `EGRESS_DELAY+1` at wide bus. | planned |

### 4.3 Backpressure toggle-period sweeps (P033..P048)

Each case holds ready at 50% duty but varies the toggle period, so a
different alias inside the RESTART refill pipeline is exercised. Period is
measured in `d_clk` cycles; ON and OFF phase are equal.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P033 | CFG_REF | toggle period 1 (alternating every cycle). | `thr_eg ≈ 0.50`; `rate_rst` = every 2 cycles; `drop_*=0`. | cov_flow{toggle=1} | Worst alias; regression: presenter cannot re-enter PRESENTING in 1 cycle. | planned |
| P034 | CFG_REF | toggle period 2. | `thr_eg ≈ 0.50`; RESTART once per 4 cycles. | cov_flow{toggle=2} | Regression: presenter state machine register delay alias. | planned |
| P035 | CFG_REF | toggle period 4. | `thr_eg ≈ 0.50`; RESTART once per 8 cycles. | cov_flow{toggle=4} | Regression: aligned with `EGRESS_DELAY+1` (default 3..5). | planned |
| P036 | CFG_REF | toggle period 8. | `thr_eg ≈ 0.50`; RESTART once per 16 cycles. | cov_flow{toggle=8} | Regression: pipeline refill + arbiter grant overlap. | planned |
| P037 | CFG_REF | toggle period 16. | `thr_eg ≈ 0.50`; RESTART once per 32 cycles. | cov_flow{toggle=16} | Regression: `ticket_fifo` depletion between windows. | planned |
| P038 | CFG_REF | toggle period 64. | `thr_eg ≈ 0.50`; `peak_lane ≤ 32`. | cov_flow{toggle=64} | Regression: slow refill + RESTART count leak. | planned |
| P039 | CFG_REF | toggle period 256. | `thr_eg ≈ 0.50`; `peak_lane ≤ 128`. | cov_flow{toggle=256} | Regression: multi-frame stall recovery. | planned |
| P040 | CFG_REF | toggle period 1024. | `thr_eg ≈ 0.50`; `peak_lane ≤ 512`. | cov_flow{toggle=1024} | Long stall window; regression: lane_fifo high-water, ticket_fifo high-water. | planned |
| P041 | CFG_L1 | toggle period 1, 1 lane. | `thr_eg ≈ 0.50`; no arbiter involvement. | cov_cfg{n_lane=1} | Isolates presenter RESTART timing from arbiter. | planned |
| P042 | CFG_L16 | toggle period 1, 16 lanes. | `thr_eg ≈ 0.50`; `svc_lat[*]` bounded. | cov_cfg{n_lane=16} | Worst interaction: alternating ready + full arbiter contention. | planned |
| P043 | CFG_REF | toggle period 3 (asymmetric 2-on, 1-off). | `thr_eg ≈ 0.67`; RESTART every 3 cycles. | cov_flow{toggle=3} | Non-power-of-two alias; regression: period-dependent corner in counter. | planned |
| P044 | CFG_REF | toggle period 5. | `thr_eg ≈ 0.50` (2-on, 3-off). | cov_flow{toggle=5} | Another non-power-of-two. | planned |
| P045 | CFG_RD72 | toggle period 1, 2 sym/beat. | `thr_eg ≈ 0.50` sym/cycle; `empty` on transition beats correct. | cov_cfg{rd_width=72} | Regression: wide bus rollback at 1-cycle toggle. | planned |
| P046 | CFG_RD144 | toggle period 8, 4 sym/beat. | `thr_eg ≈ 0.50` sym/cycle. | cov_cfg{rd_width=144} | Regression: refill with `empty!=0` beats. | planned |
| P047 | CFG_RD288 | toggle period 16, 8 sym/beat. | `thr_eg ≈ 0.50` sym/cycle. | cov_cfg{rd_width=288} | Regression: widest bus + mid-range toggle. | planned |
| P048 | CFG_REF_MUX | toggle period 8. | `thr_eg ≈ 0.50`; round-robin preserved. | cov_cfg{mode=MUX} | MUX path RESTART coverage. | planned |

### 4.4 Worst-case lane skew sustained (P049..P058)

One lane runs ahead of the others by a fixed skew over a long window.
`skew` is in lane-FIFO words of head-start.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P049 | CFG_REF | lane0 ahead by LANE_FIFO_DEPTH/2 (=512) for 100 frames. | Ordered egress, zero drops; `svc_lat[*] ≤ 4*N_LANE` frames. | cov_flow{lane_skew=512} | `page_allocator.FETCH_TICKET` gated by all-lanes-SOP (F7). Regression: skew handling at half-depth. | planned |
| P050 | CFG_REF | lane0 ahead by LANE_FIFO_DEPTH/2, 1000 frames. | As P049; `drift_ts=0`. | cov_fsm{page_allocator} | Long run; regression: slow `running_ts` drift with persistent skew. | planned |
| P051 | CFG_REF | lane0 ahead by LANE_FIFO_DEPTH-1 (=1023), 100 frames. | Ordered egress; `peak_lane=1023`; `drop_*=0`. | cov_flow{lane_skew=LANE_FIFO_DEPTH-1} | Max admissible skew; regression: boundary condition short of full. | planned |
| P052 | CFG_REF | lane3 ahead by LANE_FIFO_DEPTH/2, 1000 frames. | As P050; tests non-lane-0 skew. | cov_flow{lane_skew=512} | Regression: skew-direction-specific bug, e.g. lane-index-biased arbiter. | planned |
| P053 | CFG_REF | lanes 0,1 ahead by 512; lanes 2,3 unchanged. | Ordered egress; `drop_*=0`. | cov_flow{lane_skew=mixed} | Half-population leading; regression: pair-skew arbiter imbalance. | planned |
| P054 | CFG_L8 | lane0 ahead by 512, 1000 frames. | `thr_eg ≥ 0.95`; ordered; `drift_ts=0`. | cov_cfg{n_lane=8}, cov_flow{lane_skew=512} | Regression: fan-in 8 + skew. | planned |
| P055 | CFG_L16 | lane0 ahead by 512, 1000 frames. | `thr_eg ≥ 0.93`; ordered; `drift_ts=0`. | cov_cfg{n_lane=16}, cov_flow{lane_skew=512} | Regression: fan-in 16 + skew. | planned |
| P056 | CFG_LFD64 | lane0 ahead by 32, 1000 frames. | Ordered; `drop_*=0`. | cov_cfg{lane_fifo_depth=64}, cov_flow{lane_skew=32} | Small FIFO; regression: half-depth skew with small credit. | planned |
| P057 | CFG_LFD4K | lane0 ahead by 2048, 1000 frames. | Ordered; `drift_ts=0`. | cov_cfg{lane_fifo_depth=4096} | Deep FIFO; regression: skew measurement at large absolute value. | planned |
| P058 | CFG_REF | alternating skew: lane0 leads for 100 frames, then lane3 leads. | Ordered throughout; `svc_lat[*]` bounded during the crossover. | cov_flow{lane_skew=512} | Regression: crossover instant in arbiter rotation. | planned |

### 4.5 Arbiter fairness / starvation (P059..P074)

Saturated offered load from all lanes. Measures the maximum number of
frames any one lane has to wait between consecutive arbiter LOCKED windows
(`svc_lat`). Frozen behavior F9 says the LOCKED state holds for a full
block; fairness is what prevents priority inversion.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P059 | CFG_L2 | 1000 frames × 100% duty, both lanes saturated. | `svc_lat[0], svc_lat[1] ≤ 2 frames`. | cov_cfg{n_lane=2} | Smallest arbiter; regression: lane0 permanent grant. | planned |
| P060 | CFG_REF | 1000 frames × 100% duty, 4 lanes saturated. | `svc_lat[*] ≤ 4 frames`. | cov_cfg{n_lane=4} | Default arbiter; parent row for sweeps. | planned |
| P061 | CFG_L8 | 1000 frames × 100% duty, 8 lanes saturated. | `svc_lat[*] ≤ 8 frames`. | cov_cfg{n_lane=8} | Regression: rotation miss. | planned |
| P062 | CFG_L16 | 1000 frames × 100% duty, 16 lanes saturated. | `svc_lat[*] ≤ 16 frames`. | cov_cfg{n_lane=16} | Max fan-in; regression: LOCKED-release latency. | planned |
| P063 | CFG_REF | lane0 sends short bursts (8 hits), other lanes send long bursts (N_HIT hits). | Max service latency on lane0 ≤ 2 × arbiter lock window on other lanes. | cov_fsm{arbiter.LOCKED} | Priority-inversion probe: short burst must not starve long. Regression: scheduler bias. | planned |
| P064 | CFG_REF | inverse of P063: lane0 long bursts, lane3 short. | As P063, symmetry check. | cov_fsm{arbiter.LOCKED} | Regression: asymmetric arbitration. | planned |
| P065 | CFG_L8 | lane0 full-length, lanes 1..7 short. | `svc_lat[1..7] ≤ 2 × lock window on lane0`. | cov_cfg{n_lane=8} | Wide fan-in inversion probe. | planned |
| P066 | CFG_L16 | lane0 full-length, lanes 1..15 short. | `svc_lat[1..15] ≤ 2 × lock window on lane0`. | cov_cfg{n_lane=16} | Worst inversion scale. | planned |
| P067 | CFG_REF | Round-robin with one idle lane (lane2 silent for entire run). | Other lanes see `svc_lat ≤ 3` frames; `page_allocator` still reaches IDLE periodically. | cov_fsm{page_allocator.FETCH_TICKET} | Regression: allocator stuck in FETCH_TICKET waiting on silent lane (F7). Note: silent-lane case is NOT an error here - this is the admissible "all-SOP present" aggregator boundary; full silence is in DV_ERROR. | planned |
| P068 | CFG_REF | one lane per frame silent, rotating. | `svc_lat[*] ≤ 8` frames. | cov_fsm{page_allocator} | Regression: rotating gap handling. | planned |
| P069 | CFG_REF | arbiter under ready=50%. | `svc_lat[*] ≤ 4 × 2 = 8` frames (backpressure amplification). | cov_flow{ready_duty=50} | Regression: lock-window amplification under bp. | planned |
| P070 | CFG_L8 | arbiter under ready=25%. | `svc_lat[*] ≤ 8 × 4 = 32` frames. | cov_cfg{n_lane=8}, cov_flow{ready_duty=25} | Regression: amplification at 8 lanes × heavy bp. | planned |
| P071 | CFG_L16 | arbiter under ready=10%. | `svc_lat[*] ≤ 16 × 10 = 160` frames. | cov_cfg{n_lane=16}, cov_flow{ready_duty=10} | Worst admissible case; regression: combined lock + refill. | planned |
| P072 | CFG_REF_MUX | 1000 frames × 100% duty, 4 lanes saturated. | `svc_lat[*]` exactly round-robin (= 4). | cov_cfg{mode=MUX} | MUX has deterministic fairness; regression: MUX slot skip. | planned |
| P073 | CFG_REF | back-to-back frames with zero inter-frame gap. | Arbiter never gets stuck in LOCKING; `thr_eg ≥ 0.99`. | cov_fsm{arbiter.LOCKING} | Regression: LOCKING→LOCKED race. | planned |
| P074 | CFG_REF | lane0 single long block (entire frame as one handle), lanes 1..3 single short blocks. | `svc_lat[1..3] ≤ 1 lock window of lane0`. | cov_fsm{arbiter.LOCKED} | Regression: single super-block starvation. | planned |

### 4.6 FIFO pressure at credit limit (P075..P090)

Sustained drives chosen so the FIFO operates right at the credit limit
without dropping. The goal is to prove the steady state exists.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P075 | CFG_HFD16 | 4-lane sustained drive; block_mover drain matched to handle-FIFO size. | `peak_handle = 15`; `drop_handle=0`; `thr_eg ≥ 0.95`. | cov_flow{handle_fifo=high} | `handle_fifo` full-minus-one; regression: drop-on-full trip point. | planned |
| P076 | CFG_HFD16 | Same as P075 but 1000 frames. | `peak_handle ≤ 15`; steady-state credit. | cov_flow{handle_fifo=high} | Long-run handle credit. | planned |
| P077 | CFG_TFD16 | 4-lane sustained drive at ticket credit limit. | `peak_ticket = 15`; `drop_ticket=0`. | cov_flow{ticket_fifo=high} | Ticket credit boundary; regression: parser credit miscount. | planned |
| P078 | CFG_TFD16 | 1000 frames sustained at ticket credit limit. | As P077; `drift_ts=0`. | cov_flow{ticket_fifo=high} | Long-run ticket credit. | planned |
| P079 | CFG_LFD64 | 4-lane sustained drive at lane-FIFO credit limit. | `peak_lane = 63`; `drop_lane=0`. | cov_flow{lane_fifo=high} | Lane credit boundary; regression: MASK_PKT false trigger. | planned |
| P080 | CFG_LFD64 | 1000 frames sustained at lane credit limit. | As P079. | cov_flow{lane_fifo=high} | Long-run lane credit. | planned |
| P081 | CFG_HFD16 | 8-lane (`N_LANE` override) sustained. | `peak_handle ≤ 15`; `svc_lat[*] ≤ 8` frames. | cov_cfg{n_lane=8}, cov_flow{handle=high} | Fan-in × small handle FIFO. | planned |
| P082 | CFG_TFD16 | 8-lane sustained at ticket credit limit. | As P081 but on ticket. | cov_cfg{n_lane=8} | Ticket credit × fan-in. | planned |
| P083 | CFG_LFD64 | 8-lane sustained at lane credit limit. | As P081 but on lane. | cov_cfg{n_lane=8} | Lane credit × fan-in. | planned |
| P084 | CFG_HFD16 | ready=50% over 1000 frames. | `peak_handle ≤ 15`; `drop_handle=0`. | cov_flow{handle=high,ready_duty=50} | Handle credit × bp. | planned |
| P085 | CFG_TFD16 | ready=50% over 1000 frames. | `peak_ticket ≤ 15`; `drop_ticket=0`. | cov_flow{ticket=high,ready_duty=50} | Ticket credit × bp. | planned |
| P086 | CFG_LFD64 | ready=50% over 1000 frames. | `peak_lane ≤ 63`; `drop_lane=0`. | cov_flow{lane=high,ready_duty=50} | Lane credit × bp. | planned |
| P087 | CFG_REF | all FIFOs driven to 90% capacity for 1000 frames. | All peaks ≤ 90%; `drop_*=0`. | cov_flow{*=high} | Simultaneous high-water; regression: cross-interference between FIFO credit schemes. | planned |
| P088 | CFG_REF | ramp-up offered load from 0 → 100% over 10k cycles, hold for 100 frames. | `peak_*` smoothly tracks; `drop_*=0`. | cov_flow{*=high} | Ramp into credit limit; regression: transient overshoot. | planned |
| P089 | CFG_REF | ramp-down offered load from 100% → 0 over 10k cycles. | `peak_*` decays; all drain to 0 at end. | cov_flow{*=low} | Ramp-down drain behaviour. | planned |
| P090 | CFG_REF | square wave 0%/100% offered load, period 1000 cycles, 100 periods. | `peak_*` alternates low/high; drains each cycle; `drop_*=0`. | cov_flow{*=mixed} | Repeated filling/draining; regression: transient in credit accounting. | planned |

### 4.7 Page RAM dwell / wrap stress (P091..P106)

Dwell = cycles between a word being written into page RAM and it being
read out. Wrap = number of full write-pointer wraps within the test.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P091 | CFG_PR64K | ready=100%, 4 lanes, 1000 frames. | `dwell_pr.mean ≤ 2*HDR_SIZE + EGRESS_DELAY`; `dwell_pr.max ≤ 1024`. | cov_cfg{page_ram=65536}, cov_flow{ready=100} | 3-segment rotation (F2) at minimum dwell. Regression: dwell floor. | planned |
| P092 | CFG_PR64K | ready=75%, 4 lanes. | `dwell_pr.mean ≤ 4*HDR_SIZE`; `dwell_pr.max ≤ 4096`. | cov_flow{ready=75} | Regression: dwell under light bp. | planned |
| P093 | CFG_PR64K | ready=50%, 4 lanes. | `dwell_pr.mean ≤ 8*HDR_SIZE`. | cov_flow{ready=50} | Regression: dwell under mid bp. | planned |
| P094 | CFG_PR64K | ready=25%, 4 lanes. | `dwell_pr.max ≤ PAGE_RAM_DEPTH/8`. | cov_flow{ready=25} | Regression: dwell near segment limit. | planned |
| P095 | CFG_PR64K | ready=10%, 4 lanes. | `dwell_pr.max ≤ PAGE_RAM_DEPTH/4`. | cov_flow{ready=10} | Regression: dwell with heavy bp. | planned |
| P096 | CFG_PR8K | ready=100%, 4 lanes, until ≥10 wraps. | `wraps ≥ 10`; no write/read exclusion violation (SVA `opq_page_ram_sva`); `drop_*=0`. | cov_cfg{page_ram=8192} | 8k wrap; regression: 3-segment rotation at shallow depth. | planned |
| P097 | CFG_PR16K | ready=100%, 4 lanes, ≥10 wraps. | As P096. | cov_cfg{page_ram=16384} | 16k wrap. | planned |
| P098 | CFG_PR32K | ready=100%, 4 lanes, ≥10 wraps. | As P096. | cov_cfg{page_ram=32768} | 32k wrap. | planned |
| P099 | CFG_PR64K | ready=100%, 4 lanes, ≥10 wraps. | As P096 (≥10 wraps at 64k means ~660k frames). | cov_cfg{page_ram=65536} | 64k wrap; long run. | planned |
| P100 | CFG_PR8K | ready=50% during wrap, 4 lanes, ≥10 wraps. | As P096. | cov_cfg{page_ram=8192}, cov_flow{ready=50} | Wrap + bp; regression: segment rotation under RESTART. | planned |
| P101 | CFG_PR8K | ready toggles at period 1 during wrap, ≥10 wraps. | As P096. | cov_cfg{page_ram=8192}, cov_flow{toggle=1} | Worst wrap + toggle combo. | planned |
| P102 | CFG_PR8K | lane-skew LANE_FIFO_DEPTH/2 during wrap, ≥10 wraps. | As P096; no segment exclusion violation. | cov_cfg{page_ram=8192}, cov_flow{skew=512} | Wrap + skew. | planned |
| P103 | CFG_PR16K | lane-skew + ready=50% during wrap, ≥10 wraps. | As P096. | cov_cfg{page_ram=16384} | Wrap + skew + bp. | planned |
| P104 | CFG_PR32K | 8-lane sustained, ≥10 wraps. | As P096. | cov_cfg{page_ram=32768,n_lane=8} | Wrap with 8-lane load. | planned |
| P105 | CFG_PR64K | 16-lane sustained, ≥10 wraps. | As P096; `drift_ts=0`. | cov_cfg{page_ram=65536,n_lane=16} | Wrap with full fan-in. | planned |
| P106 | CFG_PR8K | dwell sweep {100,75,50,25,10}% ready. | Per-duty `dwell_pr.max` monotonic non-decreasing in bp strength. | cov_cfg{page_ram=8192}, cov_flow{ready_duty_all} | Regression: dwell vs bp should be monotone; non-monotone indicates segment rotation bug. | planned |

### 4.8 MERGING vs MULTIPLEXING throughput comparison (P107..P112)

Same offered load, two modes. The point is to report both KPIs so
regression across releases can catch MERGING-specific or MUX-specific
degradations.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P107 | CFG_REF | 1000 frames × 100% duty, 4 lanes. | MERGING `thr_eg ≥ 0.99`. | cov_cfg{mode=MERGING} | MERGING reference row. | planned |
| P108 | CFG_REF_MUX | 1000 frames × 100% duty, 4 lanes. | MUX `thr_eg ≥ 0.99`; per-lane round-robin. | cov_cfg{mode=MUX} | MUX reference row; paired with P107. | planned |
| P109 | CFG_REF | ready=50%, 1000 frames. | MERGING `thr_eg ≈ 0.50`. | cov_cfg{mode=MERGING},cov_flow{ready=50} | MERGING under bp. | planned |
| P110 | CFG_REF_MUX | ready=50%, 1000 frames. | MUX `thr_eg ≈ 0.50`. | cov_cfg{mode=MUX},cov_flow{ready=50} | MUX under bp. | planned |
| P111 | CFG_REF | lane-skew=512, 1000 frames. | MERGING `thr_eg ≥ 0.95`. | cov_cfg{mode=MERGING} | MERGING under skew. | planned |
| P112 | CFG_REF_MUX | lane-skew=512, 1000 frames. | MUX `thr_eg ≥ 0.95` (MUX round-robin is skew-agnostic). | cov_cfg{mode=MUX} | MUX under skew; regression: MUX mishandling skew. | planned |

### 4.9 Long soak runs (P113..P124)

1M / 10M / 100M ingress-beat runs at 100% offered duty with periodic
backpressure pulses. Watches for cumulative bookkeeping drift. These are
the longest cases in the bucket and are run on a separate nightly.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P113 | CFG_REF | 1M ingress beats × 100% duty, ready ALWAYS_READY. | `drift_ts=0`; `drop_*=0`; `thr_eg ≥ 0.99`. | cov_pkt{frame_ts_wrap} | 1M-beat warm-up soak; regression: slow drift. | planned |
| P114 | CFG_REF | 10M ingress beats × 100% duty. | As P113. | cov_pkt{frame_ts_wrap} | 10M soak. | planned |
| P115 | CFG_REF | 100M ingress beats × 100% duty. | As P113; `frame_ts` wraps past 2^48 once. | cov_pkt{frame_ts_wrap} | 100M soak; regression: `frame_ts` wrap handling. | planned |
| P116 | CFG_REF | 1M beats with 1% ready pulses every 10k cycles. | `drift_ts=0`; RESTART counter consistent; `drop_*=0`. | cov_fsm{ftable_presenter.RESTART} | Regression: RESTART counter accumulation. | planned |
| P117 | CFG_REF | 10M beats with 1% ready pulses every 10k cycles. | As P116. | cov_fsm{ftable_presenter.RESTART} | 10M × RESTART. | planned |
| P118 | CFG_REF | 100M beats with 1% ready pulses every 10k cycles. | As P116. | cov_fsm{ftable_presenter.RESTART} | 100M × RESTART; regression: cumulative rollback drift. | planned |
| P119 | CFG_L16 | 1M beats × 100% duty, 16 lanes. | `drift_ts=0`; `svc_lat[*] ≤ 16` frames; `drop_*=0`. | cov_cfg{n_lane=16} | Wide fan-in soak. | planned |
| P120 | CFG_L16 | 10M beats × 100% duty, 16 lanes. | As P119. | cov_cfg{n_lane=16} | 10M 16-lane soak. | planned |
| P121 | CFG_PR8K | 1M beats; forces many wraps. | ≥ 120 wraps; no exclusion violation; `drop_*=0`. | cov_cfg{page_ram=8192} | Many-wrap stress. | planned |
| P122 | CFG_PR8K | 10M beats. | ≥ 1200 wraps; as P121. | cov_cfg{page_ram=8192} | 10M wraps soak. | planned |
| P123 | CFG_HFD16 | 1M beats at handle credit limit. | `peak_handle ≤ 15`; `drop_handle=0`. | cov_flow{handle=high} | Long-run credit stability. | planned |
| P124 | CFG_TFD16 | 1M beats at ticket credit limit. | `peak_ticket ≤ 15`; `drop_ticket=0`. | cov_flow{ticket=high} | Long-run ticket credit stability. | planned |

### 4.10 Latency percentile measurements (P125..P136)

Per-hit ingress→egress latency mean / p50 / p99 / max. A separate row per
offered ingress duty so the latency curve can be plotted.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P125 | CFG_REF | 100 frames × 100% offered, ALWAYS_READY. | `lat_mean ≤ LAT_MEAN_BUDGET`; `lat_p99 ≤ LAT_P99_BUDGET`; `lat_max ≤ LAT_MAX_BUDGET`. | cov_flow{ready=100} | Latency floor under no bp; regression: pipeline stretch. | planned |
| P126 | CFG_REF | 100 frames × 50% offered, ALWAYS_READY. | `lat_mean ≤ LAT_MEAN_BUDGET * 0.75`; `lat_p99 ≤ LAT_P99_BUDGET`. | cov_flow{ready=100} | Half-rate offered; regression: no-bp half-rate path. | planned |
| P127 | CFG_REF | 100 frames × 10% offered, ALWAYS_READY. | `lat_mean ≤ LAT_MEAN_BUDGET * 0.5`; `lat_p99 ≤ LAT_P99_BUDGET`. | cov_flow{ready=100} | Ultra-light offered; regression: dead-time drift. | planned |
| P128 | CFG_REF | 100 frames × 100% offered, ready=50%. | `lat_mean ≤ 2 * LAT_MEAN_BUDGET`; `lat_p99 ≤ 2 * LAT_P99_BUDGET`. | cov_flow{ready=50} | Latency under bp. | planned |
| P129 | CFG_REF | 100 frames × 100% offered, ready=10%. | `lat_mean ≤ 10 * LAT_MEAN_BUDGET`. | cov_flow{ready=10} | Heavy bp latency. | planned |
| P130 | CFG_L1 | 100 frames × 100% offered. | `lat_mean ≤ LAT_MEAN_BUDGET / 2`. | cov_cfg{n_lane=1} | No-arbiter lower bound. | planned |
| P131 | CFG_L16 | 100 frames × 100% offered. | `lat_mean ≤ 4 * LAT_MEAN_BUDGET`; `lat_p99 ≤ 8 * LAT_P99_BUDGET`. | cov_cfg{n_lane=16} | Full fan-in latency. | planned |
| P132 | CFG_RD72 | 100 frames × 100% offered. | `lat_mean ≤ LAT_MEAN_BUDGET` (2 sym/beat halves egress cycles but keeps total latency flat). | cov_cfg{rd_width=72} | Latency vs wider bus; regression: packing penalty. | planned |
| P133 | CFG_RD144 | 100 frames × 100% offered. | `lat_mean ≤ LAT_MEAN_BUDGET`. | cov_cfg{rd_width=144} | 4 sym/beat latency. | planned |
| P134 | CFG_RD288 | 100 frames × 100% offered. | `lat_mean ≤ LAT_MEAN_BUDGET`. | cov_cfg{rd_width=288} | 8 sym/beat latency. | planned |
| P135 | CFG_LFD4K | 100 frames × 100% offered. | `lat_mean ≤ 2 * LAT_MEAN_BUDGET` (deeper FIFO adds dwell). | cov_cfg{lane_fifo_depth=4096} | Deep lane FIFO latency. | planned |
| P136 | CFG_REF_MUX | 100 frames × 100% offered. | `lat_mean ≤ LAT_MEAN_BUDGET`; MUX latency typically matches MERGING within 10%. | cov_cfg{mode=MUX} | MUX latency parity. | planned |

### 4.11 PAGE_RAM_RD_WIDTH efficiency sweep (P137..P146)

The `empty` field on multi-symbol egress beats measures packing efficiency.
`eff = 1 - mean(empty)/symbolsPerBeat`. A drop in eff reveals presenter
padding bugs.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P137 | CFG_REF | 100 frames × 100% duty, symbolsPerBeat=1. | `eff=1.0`; `empty` never asserted on non-final beats. | cov_cfg{rd_width=36} | Reference; regression: spurious empty. | planned |
| P138 | CFG_RD72 | 100 frames × 100% duty. | `eff ≥ 0.98`; `empty=0` on non-final beats. | cov_cfg{rd_width=72} | 2 sym/beat packing. | planned |
| P139 | CFG_RD144 | 100 frames × 100% duty. | `eff ≥ 0.98`. | cov_cfg{rd_width=144} | 4 sym/beat packing. | planned |
| P140 | CFG_RD288 | 100 frames × 100% duty. | `eff ≥ 0.98`. | cov_cfg{rd_width=288} | 8 sym/beat packing. | planned |
| P141 | CFG_RD72 | 100 frames × ready=50%. | `eff ≥ 0.95`; final-beat `empty` within 1 symbol of reference. | cov_cfg{rd_width=72},cov_flow{ready=50} | Packing under bp; regression: rollback disturbs packing. | planned |
| P142 | CFG_RD144 | 100 frames × ready=50%. | As P141 scaled to 4 sym/beat. | cov_cfg{rd_width=144},cov_flow{ready=50} | Packing under bp × 4 sym. | planned |
| P143 | CFG_RD288 | 100 frames × ready=50%. | As P141 scaled to 8 sym/beat. | cov_cfg{rd_width=288},cov_flow{ready=50} | Packing under bp × 8 sym. | planned |
| P144 | CFG_RD144 | 100 frames × ready toggle period 1. | `eff ≥ 0.90` (worst-alias rollback); `empty` never exceeds `symbolsPerBeat-1`. | cov_cfg{rd_width=144},cov_flow{toggle=1} | Worst-alias packing regression. | planned |
| P145 | CFG_RD288 | 100 frames × ready toggle period 1. | As P144 at 8 sym/beat. | cov_cfg{rd_width=288},cov_flow{toggle=1} | Widest bus worst alias. | planned |
| P146 | CFG_RD288 | 100 frames × 100% duty, lane-skew=512. | `eff ≥ 0.98`; skew does not reduce packing. | cov_cfg{rd_width=288} | Wide bus × skew; regression: skew-induced padding. | planned |

### 4.12 DEBUG_LV throughput parity (P147..P152)

Verify `DEBUG_LV=0` and `DEBUG_LV=1` produce identical KPIs within noise.
DEBUG_LV≥2 is explicitly excluded here (it drops simulator files and slows
the run — not a functional concern).

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P147 | CFG_DBG0 | 1000 frames × 100% duty. | `thr_eg, lat_mean, peak_*` within 1% of CFG_REF P009. | cov_cfg{debug_lv=0} | DEBUG_LV=0 vs =1 parity (F10). Regression: debug path leaking into datapath. | planned |
| P148 | CFG_DBG0 | ready=50%, 1000 frames. | Matches CFG_REF P021 within 1%. | cov_cfg{debug_lv=0} | Parity under bp. | planned |
| P149 | CFG_DBG0 | toggle period 1, 1000 frames. | Matches CFG_REF P033 within 1%. | cov_cfg{debug_lv=0} | Parity under worst-alias bp. | planned |
| P150 | CFG_DBG0 | lane-skew=512, 1000 frames. | Matches CFG_REF P050 within 1%. | cov_cfg{debug_lv=0} | Parity under skew. | planned |
| P151 | CFG_DBG0 | 8-lane saturated. | Matches CFG_L8 P010 within 1%. | cov_cfg{debug_lv=0,n_lane=8} | Parity under fan-in. | planned |
| P152 | CFG_DBG0 | 16-lane saturated, 1M beats soak. | Matches CFG_L16 P119 within 1%. | cov_cfg{debug_lv=0,n_lane=16} | Parity under soak. | planned |

### 4.13 TRACK_HEADER off throughput (P153..P156)

`TRACK_HEADER=false` removes the header-tracker side-path. Confirms
throughput / latency don't change under the canonical scenarios.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P153 | CFG_NOTRK | 1000 frames × 100% duty. | `thr_eg ≥ 0.99`; `drop_*=0`. | cov_cfg{track_header=false} | Baseline without TRACK_HEADER; regression: header-tracker removal breaks datapath. | planned |
| P154 | CFG_NOTRK | ready=50%, 1000 frames. | `thr_eg ≈ 0.50`. | cov_cfg{track_header=false},cov_flow{ready=50} | BP × no track. | planned |
| P155 | CFG_NOTRK | lane-skew=512, 1000 frames. | Ordered egress; `drop_*=0`. | cov_cfg{track_header=false} | Skew × no track. | planned |
| P156 | CFG_NOTRK | 1M soak, 100% duty. | `drift_ts=0`. | cov_cfg{track_header=false} | Long soak × no track. | planned |

### 4.14 Multi-lane × backpressure cross-throughput (P157..P168)

These rows sit at the DV_PROF / DV_CROSS boundary. They live here because
the primary metric is a throughput/fairness KPI; the cross-coverage cell
hit is a side effect. Rows whose primary purpose is hitting cross bins
(without a KPI column) are in `DV_CROSS.md` and not duplicated here.

| ID | Config | Stimulus | KPI / Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------------|--------|----------------------|--------|
| P157 | CFG_L16 | 16 lanes saturated + ready=90%, 1000 frames. | `thr_eg ≈ 0.90`; `svc_lat[*] ≤ 32` frames. | cov_cfg{n_lane=16},cov_flow{ready=90} | Wide fan-in × light bp. | planned |
| P158 | CFG_L16 | 16 lanes saturated + ready=75%, 1000 frames. | `thr_eg ≈ 0.75`; `svc_lat[*] ≤ 32` frames. | cov_cfg{n_lane=16},cov_flow{ready=75} | Wide fan-in × medium bp. | planned |
| P159 | CFG_L16 | 16 lanes saturated + ready=50%, 1000 frames. | `thr_eg ≈ 0.50`; `svc_lat[*] ≤ 64` frames. | cov_cfg{n_lane=16},cov_flow{ready=50} | Wide fan-in × heavy bp. | planned |
| P160 | CFG_L16 | 16 lanes saturated + ready=25%, 1000 frames. | `thr_eg ≈ 0.25`; `svc_lat[*] ≤ 128` frames. | cov_cfg{n_lane=16},cov_flow{ready=25} | Wide fan-in × very heavy bp. | planned |
| P161 | CFG_L16 | 16 lanes saturated + ready=10%, 1000 frames. | `thr_eg ≈ 0.10`; `svc_lat[*] ≤ 320` frames. | cov_cfg{n_lane=16},cov_flow{ready=10} | Wide fan-in × near-stall bp. | planned |
| P162 | CFG_L16 | 16 lanes + toggle period 1, 1000 frames. | `thr_eg ≈ 0.50`; `drop_*=0`. | cov_cfg{n_lane=16},cov_flow{toggle=1} | Wide fan-in × worst alias. | planned |
| P163 | CFG_L16 | 16 lanes + toggle period 8, 1000 frames. | `thr_eg ≈ 0.50`. | cov_cfg{n_lane=16},cov_flow{toggle=8} | Wide fan-in × typical alias. | planned |
| P164 | CFG_L16 | 16 lanes + lane-skew=512, 1000 frames. | `thr_eg ≥ 0.95`; ordered. | cov_cfg{n_lane=16} | Wide fan-in × skew. | planned |
| P165 | CFG_L8 | 8 lanes + ready=50% + lane-skew=256, 1000 frames. | `thr_eg ≈ 0.50`; ordered. | cov_cfg{n_lane=8},cov_flow{ready=50} | Fan-in 8 × bp × skew. | planned |
| P166 | CFG_L8 | 8 lanes + toggle=8 + lane-skew=256, 1000 frames. | `thr_eg ≈ 0.50`; ordered. | cov_cfg{n_lane=8},cov_flow{toggle=8} | Fan-in 8 × alias × skew. | planned |
| P167 | CFG_L16 | 16 lanes + ready=50% + lane-skew=512 + 1M soak. | `drift_ts=0`; `drop_*=0`. | cov_cfg{n_lane=16},cov_flow{ready=50} | Soak × full cross. | planned |
| P168 | CFG_L16 | 16 lanes + ready=50% + lane-skew=512 + 10M soak. | As P167. | cov_cfg{n_lane=16},cov_flow{ready=50} | 10M soak × full cross; longest DV_PROF run. | planned |

**Row count:** 168 cases (P001..P168). Minimum 128 satisfied.

---

## 5. Coverage Binding

DV_PROF is not the primary bucket for functional-coverage closure —
`DV_CROSS.md` owns that — but every row populates at least one bin in
`opq_coverage.sv`:

- **`cov_cfg`**: rows P001..P168 collectively exercise `n_lane ∈
  {1,2,4,8,16}`, `mode ∈ {MERGING, MULTIPLEXING}`, `track_header ∈
  {true,false}`, `lane_fifo_depth ∈ {64,1024,4096}`, `ticket_fifo_depth ∈
  {16,128}`, `handle_fifo_depth ∈ {16,128}`, `page_ram_depth ∈
  {8192,16384,32768,65536}`, `page_ram_rd_width ∈ {36,72,144,288}`, and
  `debug_lv ∈ {0,1}`.
- **`cov_fsm`**: the `arbiter.LOCKED` state is the primary DV_PROF target
  (§4.5). `ftable_presenter.RESTART` and `.WARPING` are hit by §4.2/§4.3.
  `page_allocator.FETCH_TICKET` is the §4.4 target (via F7).
- **`cov_flow`**: every `egress_ready_duty` bin and every
  `egress_ready_toggle_period` bin is reached by §4.2/§4.3. The
  `ticket_fifo_occupancy=high`, `lane_fifo_occupancy=high`, and
  `handle_fifo_occupancy=high` bins are the §4.6 target.
- **`cov_pkt.frame_ts_wrap`**: the 100M soak (P115) is the only place this
  bin is hit inside DV_PROF. Also reachable from DV_CROSS, but the 100M
  run is where the KPI is measured.

DV_PROF does **not** populate `cov_fsm` states `RESET`, `ABORT_WRITE_BLK`,
`MASK_PKT`, `MASK_PKT_EXTENDED` — those are `DV_ERROR` territory.

---

## 6. Handoff to Later Buckets

Bins and scenarios deliberately deferred out of DV_PROF:

- **DV_CROSS**: any multi-axis run where the primary purpose is hitting a
  cross-coverage cell and the KPI is secondary. In particular, the full
  `mode × track_header × n_lane × ready_duty × skew` matrix lives there.
  DV_PROF only takes the §4.14 subset that has a throughput KPI.
- **DV_ERROR**: all FIFO overflow / drop-on-full cases (lane FIFO full,
  ticket FIFO full, handle FIFO full), all `hit_err`/`shd_err`/`hdr_err`
  injection, all truncated packets, all reset-in-state, and all
  `page_allocator` FETCH_TICKET stuck-on-silent-lane recovery rows.
  DV_PROF only drives FIFOs up to — not past — their credit limit.
- **DV_EDGE**: `LANE_FIFO_DEPTH ∈ {16,256,16384,65536}`,
  `N_HIT ∈ {1,2047}`, `N_SHD ∈ {1,512}`, `CHANNEL_WIDTH` variations,
  first-frame-shortened case, header-size=0 cases, and the `N_LANE=1`
  single-packet happy paths. DV_PROF picks up only the values useful for a
  KPI sweep.
- **DV_BASIC**: per-FSM happy-path reachability and the per-generic sanity
  matrix — not duplicated here.
- **Mode-switch-latency**: explicitly out of scope for DV; requires
  Qsys regen mid-sim, which the harness does not support.

The DV_PROF golden KPI CSV (`opq_prof_golden.csv`) is the artifact picked
up by regression diff; any row exceeding its golden KPI by more than the
`tolerance` column is an automatic fail regardless of the UVM verdict.

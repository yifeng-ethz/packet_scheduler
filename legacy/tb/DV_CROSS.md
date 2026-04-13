# DV_CROSS: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`
**Prefix:** `C` (C001..C999)
**Scope:** Long multi-axis transaction chains that close cross-coverage cells in `cov_cross` (DV_PLAN §5.5). Each scenario chains many `opq_txn` items **without inter-transaction reset** so cross-coverage cells accumulate across transaction boundaries.
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-13

---

## 0. Ground Rules

1. **No reset between transactions** — the env only applies reset at start-of-test or on an explicit `reset_txn`. Cross-coverage cells accumulate across the txn chain (DV_HARNESS §4).
2. **Cross targets are named** — each scenario lists one or more formal cross targets from DV_PLAN §5.5 / §5.2 (`C_PRESENTER_X_BP`, `C_ALLOC_X_LANES`, `C_BLKMV_X_LANE`) or derived crosses defined below (§0.1).
3. **Termination criterion** — every scenario terminates either on a coverage goal (`cov_cross.sample_*` hit count reached) or on an explicit beat budget (watchdog). No "run forever".
4. **Justification** — every scenario must explain why the cross cell cannot be closed by directed (single-txn) cases in `DV_BASIC` / `DV_EDGE` / `DV_ERROR`. The core reason: each cell is a tuple lookup whose axes only co-fire in the middle of a long chain; a single directed case cannot hit every tuple without resetting the DUT, which wipes the history-dependent axis.
5. **MODE parity** — each sub-bucket runs under both `MERGING` and `MULTIPLEXING` unless the axis is MODE-invariant.
6. **DEBUG_LV parity** — the monolithic-core regression runs at `DEBUG_LV = 1`. A `DEBUG_LV = 0` sub-regression is sampled in C9xx so the non-debug build is cross-covered. `DEBUG_LV = 2` is sampled in C1xx for the `opq_overwrite_debug.log` path.

### 0.1 Derived cross target labels

For brevity, all `cov_cross` cells referenced below use the following labels. Each is a covergroup cell computed in `cov_cross_pkg` from the probe port:

| Label | Axes |
|-------|------|
| `C_PRESENTER_X_BP` | `ftable_presenter_state` × `is_backpressured` × packet-size class |
| `C_ALLOC_X_LANES` | `page_allocator_state` × `pending_lanes_count` (0..N_LANE) |
| `C_BLKMV_X_LANE` | `block_mover_state[lane]` × lane_index × active page segment |
| `C_INGR_X_LANE_X_MODE` | `ingress_parser_state[lane]` × lane_index × MODE |
| `C_ALLOC_X_SEG_X_OCC` | `page_allocator_state` × page-RAM segment id × segment occupancy bucket |
| `C_BLKMV_X_SEG` | `block_mover_state` × active lane × page segment id |
| `C_PRES_X_BP_X_LEN` | `ftable_presenter_state` × egress bp profile × packet length class |
| `C_ARB_X_BACKLOG` | `arbiter_state` × per-lane backlog class (0, low, mid, high) |
| `C_PKT_X_SHD_X_HIT` | packet length class × subh-count bin × hit-count bin |
| `C_ERR_X_FSM` | error-bit class × FSM state (any of the 7 FSMs) |
| `C_FTS_X_RTS` | `frame_ts` wrap bucket × `running_ts` bucket |
| `C_SKEW_X_MODE` | lane-skew class × MODE |

These names match the hooks defined in `opq_coverage.sv` / `cov_cross_pkg`.

---

## C1xx — FSM × lane × MODE (ingress_parser × lane × MODE)

**Why not directed:** `ingress_parser` has 6 legal states, N_LANE instances, and 2 MODEs. That is 6 × N_LANE × 2 = up to 192 cells for N_LANE=16. Each ingress state is triggered by the packet shape currently flowing on that lane; to force every (state, lane, MODE) tuple the stimulus must rotate the triggering packet across every lane without resetting, which only works inside a chained txn run.

### C101 — Rotating SOP start across all lanes, MERGING
- **Targets:** `C_INGR_X_LANE_X_MODE` (IDLE→UPDATE_HEADER_TS × every lane × MERGING), `C_ALLOC_X_LANES[state=FETCH_TICKET, pending=N_LANE]`
- **Axes:** MODE=MERGING, DEBUG_LV=1, ingress bp = ALWAYS_READY
- **Shape:** 200 txns. Each txn sends one frame; the frame's SOP is launched first on lane L = txn_id mod N_LANE, then the other lanes follow 40 beats later. Lane skew rotates every txn.
- **Termination:** `C_INGR_X_LANE_X_MODE[UPDATE_HEADER_TS][*][MERGING]` = 100%.
- **Expected Δ:** +N_LANE cells on UPDATE_HEADER_TS axis, +N_LANE on WR_HITS axis.

### C102 — Rotating SOP start across all lanes, MULTIPLEXING
- **Targets:** same as C101 under MODE=MULTIPLEXING.
- **Shape:** 200 txns, MODE=MULTIPLEXING, otherwise identical to C101.
- **Termination:** `C_INGR_X_LANE_X_MODE[*][*][MULTIPLEXING]` ≥ 95%.
- **Expected Δ:** closes the MULTIPLEXING half of the ingress × lane cross.

### C103 — MASK_PKT rotation via lane-FIFO near-overflow
- **Targets:** `C_INGR_X_LANE_X_MODE[MASK_PKT][*][MERGING]`, `C_ERR_X_FSM[fifo_drop][ingress_parser.MASK_PKT]`
- **Axes:** lane_fifo occupancy sweep, bp = STUCK_LOW for windows of 2048 beats
- **Shape:** 300 txns. Egress parked (STUCK_LOW) for 2k beats, then ALWAYS_READY for 2k, repeat. Ingress driven at 100% duty so each lane hits MASK_PKT before recovery. Rotate the "first-to-fill" lane each period.
- **Termination:** MASK_PKT cell seen on every lane under MERGING.
- **Expected Δ:** closes MASK_PKT × lane cross that directed cases cannot hit without resetting each lane individually.

### C104 — MASK_PKT_EXTENDED rotation
- **Targets:** `C_INGR_X_LANE_X_MODE[MASK_PKT_EXTENDED][*][*]`
- **Shape:** 300 txns. Same as C103 but programmed so the mask lands mid-hit-burst (pre-SOP → EXTENDED variant). Hit count = N_HIT on the rotation-lane, 0 on others.
- **Termination:** MASK_PKT_EXTENDED cell seen on every lane.
- **Expected Δ:** forces the extended mask variant on every lane.

### C105 — UPDATE_HEADER_TS × frame_ts wrap × every lane
- **Targets:** `C_INGR_X_LANE_X_MODE[UPDATE_HEADER_TS][*][*]`, `C_FTS_X_RTS[near-wrap][*]`
- **Shape:** 150 txns. Each txn's first frame carries `frame_ts` close to the 48-bit wrap; the wrap happens during the txn chain. Leading lane rotates.
- **Termination:** UPDATE_HEADER_TS × wrap cell on every lane.
- **Expected Δ:** links the header-TS state to the wrap bucket so F3/F4 coverage co-fires with the per-lane axis.

### C106 — WR_HITS × hit=N_HIT × every lane (MERGING)
- **Targets:** `C_INGR_X_LANE_X_MODE[WR_HITS][*][MERGING]`, `C_PKT_X_SHD_X_HIT[long][max][max]`
- **Shape:** 256 txns. Each txn's "busy lane" carries `hits_per_subh = N_HIT`, `subh_per_frame = N_SHD`; other lanes carry minimum shapes. Rotation across lanes.
- **Termination:** WR_HITS cell on every lane.
- **Expected Δ:** every lane's WR_HITS state seen with max-size hit bursts.

### C107 — WR_HITS × hit=N_HIT × every lane (MULTIPLEXING)
- **Targets:** same as C106 under MULTIPLEXING.
- **Shape:** 256 txns, MODE=MULTIPLEXING.
- **Termination:** cell map covered on every lane.

### C108 — RESET-state entry × every lane via `reset_txn`
- **Targets:** `C_INGR_X_LANE_X_MODE[RESET][*][*]`
- **Shape:** 64 txns. Intersperse a `reset_txn` every 8 txns; each reset occurs while one rotating lane is mid-WR_HITS. Rotation ensures every lane eventually gets the reset hit.
- **Termination:** RESET cell on every lane.
- **Expected Δ:** directed cases only reset one lane at a time with reset dominating the run; this chained form exercises RESET as an axis.

### C109 — IDLE dwell × every lane (ingress gap sweep)
- **Targets:** `C_INGR_X_LANE_X_MODE[IDLE][*][*]` with long dwell
- **Shape:** 512 txns with randomized `ingress_gap_min..gap_max`. Half the txns push gap ≥ 1024 cycles on one rotating lane so IDLE-dwell distribution is non-trivial.
- **Termination:** IDLE-dwell histogram fills every bin for every lane.
- **Expected Δ:** closes IDLE × lane cross in the long-dwell bin.

### C110 — DEBUG_LV=2 overwrite-log path × every lane
- **Targets:** `C_INGR_X_LANE_X_MODE` with DEBUG_LV=2; `C_ERR_X_FSM[overwrite_log][*]`
- **Shape:** 200 txns run under DEBUG_LV=2 so `opq_overwrite_debug.log` is produced. Rotation ensures every lane contributes at least one overwrite event.
- **Termination:** overwrite log has at least one record from every lane AND the per-lane cells are hit.
- **Expected Δ:** F10 frozen behavior now cross-covered with lane × MODE.

### C111 — DEBUG_LV=1 vs DEBUG_LV=0 parity cross
- **Targets:** `C_INGR_X_LANE_X_MODE` × debug-lv axis
- **Shape:** 256 txns split 50/50 between DEBUG_LV=1 and DEBUG_LV=0 configs (two runs, merged into the same UCDB). Identical stimulus.
- **Termination:** same cells hit under both builds.
- **Expected Δ:** closes the debug-axis cross; ensures non-debug build isn't silently pruning states.

### C112 — Single-lane run in N_LANE=16 config
- **Targets:** `C_INGR_X_LANE_X_MODE[*][lane=0][MERGING]` in an N_LANE=16 build
- **Shape:** 400 txns that only ever touch lane 0 (others starved idle) in a 16-lane compile. Verifies idle-lane axis is covered.
- **Termination:** idle-lane bins hit for lanes 1..15 AND active-lane bins hit for lane 0.

### C113 — Lane 0 starved, all other lanes busy
- **Targets:** idle axis inverse to C112.
- **Shape:** 400 txns driving all lanes except 0.
- **Termination:** lane 0 IDLE bin saturated; lanes 1..N_LANE-1 cycle through all states.

### C114 — Lane pair busy, others idle (every adjacent pair)
- **Targets:** `C_INGR_X_LANE_X_MODE` × pairwise lane axis
- **Shape:** N_LANE-1 phases × 128 txns/phase. Phase k drives lanes {k, k+1}.
- **Termination:** every adjacent pair visits WR_HITS simultaneously.
- **Expected Δ:** pairwise cross cells closed without a per-pair directed case.

### C115 — N_LANE sweep chained (1→2→4→8→16) inside a regress file
- **Targets:** `cov_cfg.n_lane` × `C_INGR_X_LANE_X_MODE`
- **Shape:** 5 compile configs in one regress row, each running a 128-txn C101-style chain, UCDBs merged.
- **Termination:** every `n_lane` bin and every lane-ID cell hit.

### C116 — Channel-width sweep chained
- **Targets:** `cov_cfg.channel_width` × `C_INGR_X_LANE_X_MODE`
- **Shape:** 5 configs (CW 0..4), 128 txns each, channel-ID rotated across txns.
- **Termination:** every channel bin hit on every active lane.

### C117 — TRACK_HEADER on × off cross
- **Targets:** `cov_cfg.track_header` × `ingress_parser_state`
- **Shape:** 2 configs × 128 txns. Header-ts path vs non-track path on every lane.
- **Termination:** UPDATE_HEADER_TS hit or suppressed per config consistently.

### C118 — HDR_SIZE sweep cross with lane rotation
- **Targets:** `cov_pkt.hdr_size_words` × `C_INGR_X_LANE_X_MODE`
- **Shape:** 4 configs × 150 txns, HDR_SIZE ∈ {4, 5, 6, 8}. Each config rotates the leading lane.
- **Termination:** every HDR_SIZE × lane cell hit.

### C119 — Ingress gap jitter under random duty egress
- **Targets:** `C_INGR_X_LANE_X_MODE` × `egress_ready_duty[RANDOM_DUTY]`
- **Shape:** 300 txns, ingress `gap_min=0`, `gap_max=64`, egress bp = RANDOM_DUTY(50%).
- **Termination:** ingress FSM histogram saturates every state bin under the random-duty axis.

### C120 — Lane-skew extremes at both ends
- **Targets:** `C_INGR_X_LANE_X_MODE[*]` with `ingress_lane_skew ∈ {0, LANE_FIFO_DEPTH-1}`
- **Shape:** 200 txns split evenly between zero-skew and near-full skew; rotating the laggard lane.
- **Termination:** every lane has been the laggard at least once with skew close to `LANE_FIFO_DEPTH-1`.

---

## C2xx — Allocator × segment × occupancy (page_allocator)

**Why not directed:** `page_allocator` has 7 states, the page RAM has 3 dynamic segments, and occupancy is a bucketed history. The tuple `(state, segment_id, occupancy_bucket)` depends on how much was previously written, so it cannot be hit from a fresh reset. Only a chained run walks the RAM through every occupancy bucket in every segment.

### C201 — FETCH_TICKET × every lane-count (pending 0..N_LANE)
- **Targets:** `C_ALLOC_X_LANES[FETCH_TICKET][*]`
- **Shape:** 300 txns. Each txn sends SOPs on a random subset of lanes; subset size cycles 0..N_LANE. `pending_lanes_count` probed every cycle.
- **Termination:** every `(FETCH_TICKET, k)` for k ∈ 0..N_LANE hit.
- **Expected Δ:** closes the F7 cell family.

### C202 — WRITE_HEAD × every segment
- **Targets:** `C_ALLOC_X_SEG_X_OCC[WRITE_HEAD][seg0..seg2][*]`
- **Shape:** 400 txns, headers continuously written so the allocator walks the ring through seg0→seg1→seg2→seg0 repeatedly.
- **Termination:** WRITE_HEAD × each segment hit ≥ 50 samples.
- **Expected Δ:** header entry on every physical segment.

### C203 — WRITE_TAIL × every segment
- **Targets:** `C_ALLOC_X_SEG_X_OCC[WRITE_TAIL][*][*]`
- **Shape:** 400 txns. Frames ended explicitly so `WRITE_TAIL` fires on every segment as the ring wraps.
- **Termination:** WRITE_TAIL × each segment hit.
- **Expected Δ:** trailer-write path exercised on every segment.

### C204 — ALLOC_PAGE × segment × occupancy bucket
- **Targets:** `C_ALLOC_X_SEG_X_OCC[ALLOC_PAGE][*][empty|low|mid|high]`
- **Shape:** 512 txns. Vary frame size so each segment fills from empty to high occupancy while ALLOC_PAGE is active.
- **Termination:** every `(ALLOC_PAGE, seg, occ)` cell with occ ∈ {empty, low, mid, high} hit.
- **Expected Δ:** the main allocator heat-map cell.

### C205 — WRITE_PAGE × occupancy=high × every segment
- **Targets:** `C_ALLOC_X_SEG_X_OCC[WRITE_PAGE][*][high]`
- **Shape:** 256 txns with large frames; egress throttled to TOGGLE_PERIODIC(64) so segments sit near full.
- **Termination:** WRITE_PAGE on every segment with occupancy ≥ 75%.
- **Expected Δ:** exercises F2 near-overwrite boundary in every segment slot.

### C206 — Allocator IDLE × 0 lanes pending
- **Targets:** `C_ALLOC_X_LANES[IDLE][0]`
- **Shape:** 200 txns with long ingress gaps (`gap_min=512`) so the allocator returns to IDLE between frames.
- **Termination:** IDLE×0 histogram bin ≥ 1000 samples.

### C207 — FETCH_TICKET dwell from a starved single lane
- **Targets:** `C_ALLOC_X_LANES[FETCH_TICKET][N_LANE-1]`
- **Shape:** 150 txns. N-1 lanes push SOPs; the Nth lane waits 2000 cycles. Rotate the starved lane each txn.
- **Termination:** FETCH_TICKET×(N_LANE-1) hit with every lane as the holdout.
- **Expected Δ:** closes F7 "absent lane" cell family under every lane index.

### C208 — RESET during every allocator state
- **Targets:** `C_ALLOC_X_SEG_X_OCC[RESET][*][*]`
- **Shape:** 64 txns interleaved with `reset_txn` items timed to hit IDLE / FETCH_TICKET / WRITE_HEAD / WRITE_TAIL / ALLOC_PAGE / WRITE_PAGE in turn (phased reset windows).
- **Termination:** every non-RESET state has been observed collapsing into RESET once.

### C209 — handle_fifo full × allocator state
- **Targets:** `C_ALLOC_X_SEG_X_OCC[*][*][handle_full]` (derived: adds handle_fifo_full axis to C_ALLOC_X_SEG_X_OCC)
- **Shape:** 300 txns with block_mover artificially stalled by egress bp = STUCK_LOW for 4k beats.
- **Termination:** `handle_fifo = HANDLE_FIFO_DEPTH` × every allocator state hit.
- **Expected Δ:** cell family that directed single-txn cases cannot fill without mid-run chain.

### C210 — ticket_fifo high occupancy × allocator state
- **Targets:** `cov_flow.ticket_fifo_occupancy[high] × page_allocator_state`
- **Shape:** 300 txns. Ingress rate > allocator drain rate by 10% sustained.
- **Termination:** ticket_fifo high × every allocator state hit.

### C211 — ticket_fifo full → drop × allocator state
- **Targets:** `cov_flow.ticket_fifo_occupancy[full] × page_allocator_state`
- **Shape:** 200 txns. Force ticket fifo to drop-on-full window.
- **Termination:** drop cell × every allocator state hit.

### C212 — Segment rollover at PAGE_RAM_DEPTH sweep
- **Targets:** `cov_cfg.page_ram_depth` × `C_ALLOC_X_SEG_X_OCC`
- **Shape:** 4 configs (8192, 16384, 32768, 65536) × 128 txns each, driven to force ≥ 3 full rollovers per run.
- **Termination:** rollover × depth × segment × state cell closed.

### C213 — ticket_fifo empty × allocator IDLE dwell
- **Targets:** `cov_flow.ticket_fifo_occupancy[empty] × allocator.IDLE`
- **Shape:** 150 txns, long idle gaps so allocator sits in IDLE with empty ticket fifo.
- **Termination:** empty × IDLE histogram ≥ 10k cycles.

### C214 — Alternating MERGING / MULTIPLEXING (same compile? No — MODE is generic)
- **Targets:** `cov_cfg.mode` × `C_ALLOC_X_LANES`
- **Shape:** 2 regress rows (MERGING, MULTIPLEXING) × 256 txns; UCDBs merged.
- **Termination:** every (state, pending-lanes, MODE) cell hit.

### C215 — N_LANE=1 allocator degenerate path
- **Targets:** `C_ALLOC_X_LANES[*][pending=1]` and `[pending=0]`
- **Shape:** 128 txns on an N_LANE=1 compile.
- **Termination:** degenerate-allocator states fully exercised.

### C216 — N_LANE=16 allocator fan-in stress
- **Targets:** `C_ALLOC_X_LANES[*][pending=16]`
- **Shape:** 256 txns on N_LANE=16, all lanes sync-pushing SOPs.
- **Termination:** FETCH_TICKET × 16 pending-lane cell hit ≥ 1000 samples.

### C217 — page_ram_rd_width sweep cross
- **Targets:** `cov_cfg.page_ram_rd_width` × `C_ALLOC_X_SEG_X_OCC[WRITE_PAGE]`
- **Shape:** 8 regress rows (36..288 step 36) × 64 txns.
- **Termination:** every width × state cell hit.

### C218 — First-frame-short after long idle
- **Targets:** F4 cell × allocator FETCH_TICKET
- **Shape:** 100 txns each preceded by a 4k-cycle idle; the first frame after idle has `subh_per_frame < N_SHD` and is short.
- **Termination:** F4 re-sync observed with the allocator in FETCH_TICKET.

### C219 — Allocator FSM × lane_fifo_depth sweep
- **Targets:** `cov_cfg.lane_fifo_depth` × `page_allocator_state`
- **Shape:** 7 configs × 64 txns.
- **Termination:** every depth × state cell hit.

### C220 — Allocator FSM × handle_fifo_depth sweep
- **Targets:** `cov_cfg.handle_fifo_depth` × `page_allocator_state`
- **Shape:** 5 configs × 64 txns each.
- **Termination:** every depth × state cell hit.

---

## C3xx — Block-mover × lane × segment

**Why not directed:** `block_mover` is per-lane. Its 5-state FSM must be seen for every (lane, segment) combination. The cell depends on which lane currently owns the arbiter AND which segment is being written; neither is controllable without chained stimulus.

### C301 — PREP × every lane × every segment
- **Targets:** `C_BLKMV_X_LANE[PREP][*][*]`, `C_BLKMV_X_SEG[PREP][*][*]`
- **Shape:** 300 txns. Round-robin grant of the arbiter while segments rotate.
- **Termination:** PREP cell closed for every (lane, segment) pair.

### C302 — WRITE_BLK × every lane × every segment
- **Targets:** `C_BLKMV_X_LANE[WRITE_BLK][*][*]`
- **Shape:** 400 txns. Large frames so WRITE_BLK holds for many cycles; rotate busy-lane.
- **Termination:** WRITE_BLK cell on every (lane, segment) pair.

### C303 — ABORT_WRITE_BLK × every lane
- **Targets:** `C_BLKMV_X_LANE[ABORT_WRITE_BLK][*][*]`, F8 frozen-behavior cell
- **Shape:** 256 txns. Force handle-vs-segment mismatch via deliberate reordering per txn: the rotating lane emits a handle whose segment disagrees with the current page-RAM read segment. Rotate the offending lane every 8 txns.
- **Termination:** ABORT_WRITE_BLK cell seen on every lane with every segment as the "disagreeing" segment.
- **Expected Δ:** F8 cross-covered per lane.

### C304 — IDLE starvation × N-1 lanes
- **Targets:** `C_BLKMV_X_LANE[IDLE][*][*]` with starved lane count = N-1
- **Shape:** 300 txns with only one busy lane rotating every 16 txns.
- **Termination:** every lane observed in IDLE while another lane is in WRITE_BLK.

### C305 — RESET entry during WRITE_BLK per lane
- **Targets:** `C_BLKMV_X_LANE[RESET][*][*]` with RESET entered from WRITE_BLK
- **Shape:** 32 txns interleaved with `reset_txn`. Reset timed to a rotating lane mid-WRITE_BLK.
- **Termination:** RESET-from-WRITE_BLK cell hit on every lane.

### C306 — block_mover × ingress truncation × every lane
- **Targets:** `C_BLKMV_X_LANE` × `inject_truncation[lane]`
- **Shape:** 200 txns. Each txn's rotating lane injects a truncated packet; block_mover must handle the upstream shortfall.
- **Termination:** truncation-response cells closed on every lane.

### C307 — block_mover × egress stall during PREP
- **Targets:** `C_BLKMV_X_LANE[PREP]` × bp=STUCK_LOW
- **Shape:** 200 txns. bp windows of STUCK_LOW(1024) overlap with txn PREP entry.
- **Termination:** PREP × bp=1 cell on every lane.

### C308 — block_mover × N_LANE=16 large configuration
- **Targets:** all `C_BLKMV_X_LANE` cells in N_LANE=16 compile
- **Shape:** 512 txns, N_LANE=16, continuous rotation.
- **Termination:** every lane × state × segment cell closed.

### C309 — block_mover × N_LANE=2 degenerate
- **Targets:** `C_BLKMV_X_LANE` in N_LANE=2
- **Shape:** 128 txns in N_LANE=2 compile.
- **Termination:** PREP, WRITE_BLK, ABORT, IDLE, RESET cells closed for both lanes.

### C310 — block_mover × handle_fifo drain rate stress
- **Targets:** `C_BLKMV_X_LANE[PREP]` × handle_fifo occupancy=high
- **Shape:** 300 txns, handle_fifo throttled by slow egress.
- **Termination:** PREP × high-handle-fifo cell on every lane.

### C311 — block_mover × lane_fifo empty between bursts
- **Targets:** `C_BLKMV_X_LANE[IDLE]` × lane_fifo=empty
- **Shape:** 150 txns with large ingress gaps.
- **Termination:** IDLE × empty cell on every lane.

### C312 — block_mover × segment wrap per lane
- **Targets:** `C_BLKMV_X_SEG[WRITE_BLK][*][seg wraps]`
- **Shape:** 256 txns. Each txn tuned so WRITE_BLK spans a segment boundary on a rotating lane.
- **Termination:** every lane has been the "segment-wrap writer" at least once per segment pair.

### C313 — block_mover × abort-recovery × arbiter release
- **Targets:** `C_BLKMV_X_LANE[ABORT_WRITE_BLK→IDLE]` × arbiter release event
- **Shape:** 150 txns. Each txn pairs an abort with arbiter LOCKED release.
- **Termination:** abort-recovery cell closed on every lane.

### C314 — block_mover × MODE cross
- **Targets:** `C_BLKMV_X_LANE` × MODE axis
- **Shape:** 2 regress rows × 256 txns.
- **Termination:** every lane × state cell hit under both MODEs.

### C315 — block_mover × DEBUG_LV=2 overwrite
- **Targets:** `C_BLKMV_X_LANE` under DEBUG_LV=2
- **Shape:** 128 txns, DEBUG_LV=2, force overwrite-log entries.
- **Termination:** overwrite path hit on every lane.

### C316 — block_mover × PAGE_RAM_RD_WIDTH sweep
- **Targets:** `cov_cfg.page_ram_rd_width` × `C_BLKMV_X_LANE`
- **Shape:** 8 configs × 64 txns.
- **Termination:** every rd_width × state × lane cell hit.

---

## C4xx — Presenter × backpressure × packet size (ftable_presenter)

**Why not directed:** F1 RESTART is the most cross-heavy state: it fires only when a stall crosses a specific pipeline boundary. The `(state, bp_profile, packet_length)` tuple requires chained stimulus that holds the presenter in PRESENTING while driving a specific bp pattern, repeated for every length class.

### C401 — PRESENTING × every bp profile × short packets
- **Targets:** `C_PRESENTER_X_BP[PRESENTING][*][short]`, `C_PRES_X_BP_X_LEN[PRESENTING][*][short]`
- **Shape:** 6 regress rows (one per bp profile ALWAYS_READY..RAMP) × 128 short txns (`hits_per_subh=1`).
- **Termination:** PRESENTING × every bp × short-length cell hit.

### C402 — PRESENTING × every bp × mid packets
- **Targets:** `C_PRES_X_BP_X_LEN[PRESENTING][*][mid]`
- **Shape:** 6 rows × 128 mid txns.
- **Termination:** cells closed.

### C403 — PRESENTING × every bp × long packets
- **Targets:** `C_PRES_X_BP_X_LEN[PRESENTING][*][long]`
- **Shape:** 6 rows × 128 long txns (`hits_per_subh = N_HIT`, `subh_per_frame = N_SHD`).
- **Termination:** cells closed.

### C404 — RESTART × every bp profile × short
- **Targets:** `C_PRESENTER_X_BP[RESTART][*][short]` — F1 per short packet
- **Shape:** 6 rows × 128 txns. bp forced to cause a stall mid-packet.
- **Termination:** RESTART × every bp × short cell hit.
- **Expected Δ:** directed cases exercise RESTART once per reset; chained form triggers it repeatedly across packet lengths.

### C405 — RESTART × every bp profile × mid
- **Targets:** `C_PRESENTER_X_BP[RESTART][*][mid]`
- **Shape:** 6 rows × 128 mid txns, bp-forced stalls.
- **Termination:** cells closed.

### C406 — RESTART × every bp profile × long
- **Targets:** `C_PRESENTER_X_BP[RESTART][*][long]`
- **Shape:** 6 rows × 128 long txns, bp stalls mid-burst.
- **Termination:** cells closed. F1 × max-length cell is the critical closer.

### C407 — WARPING × bp TOGGLE_PERIODIC
- **Targets:** `C_PRESENTER_X_BP[WARPING][TOGGLE_PERIODIC][*]`
- **Shape:** 128 txns under TOGGLE_PERIODIC(1) (max bandwidth loss).
- **Termination:** WARPING cell hit ≥ 100 times.

### C408 — WARPING × bp RAMP
- **Targets:** `C_PRESENTER_X_BP[WARPING][RAMP][*]`
- **Shape:** 128 txns under RAMP bp (ready duty ramps 0→100% over 4k cycles).
- **Termination:** WARPING cell hit on the RAMP axis.

### C409 — VERIFY × bp BURST_STALL × medium
- **Targets:** `C_PRESENTER_X_BP[VERIFY][BURST_STALL][mid]`
- **Shape:** 200 txns, BURST_STALL(burst=256, gap=64).
- **Termination:** VERIFY × BURST_STALL cell closed.

### C410 — WAIT_FOR_COMPLETE × every bp
- **Targets:** `C_PRESENTER_X_BP[WAIT_FOR_COMPLETE][*]`
- **Shape:** 6 rows × 64 txns ending short (forces WAIT_FOR_COMPLETE).
- **Termination:** cells closed.

### C411 — IDLE-dwell × bp STUCK_LOW
- **Targets:** `C_PRESENTER_X_BP[IDLE][STUCK_LOW]`
- **Shape:** 128 txns. Between txns, bp held STUCK_LOW for 2048 cycles.
- **Termination:** IDLE × stuck-low dwell cell ≥ 10k cycles.

### C412 — RESET during each presenter state via `reset_txn`
- **Targets:** `C_PRESENTER_X_BP[RESET][*][*]`
- **Shape:** 48 txns with `reset_txn` items timed to hit each non-RESET presenter state in turn (6 phases × 8 `reset_txn`s).
- **Termination:** RESET entered from every state at least once.

### C413 — PRESENTING × packet-size sweep (every cov_pkt.hits_per_subh bin)
- **Targets:** `C_PRESENTER_X_BP[PRESENTING][*]` × every hits_per_subh bin
- **Shape:** 9 rows (one per bin 0,1,2,4,16,64,128,255,N_HIT) × 64 txns.
- **Termination:** PRESENTING cell hit on every hits_per_subh bin.

### C414 — PRESENTING × subh_per_hdr sweep
- **Targets:** PRESENTING × every subh_per_hdr bin
- **Shape:** 9 rows × 64 txns covering bins 1..N_SHD.
- **Termination:** cells closed.

### C415 — Back-to-back RESTART × RESTART (double stall)
- **Targets:** `C_PRESENTER_X_BP[RESTART][*][*]` repeat count ≥ 2
- **Shape:** 128 txns. bp = BURST_STALL(32,8) so every packet sees ≥ 2 RESTART transitions.
- **Termination:** RESTART hit count ≥ 2 per txn confirmed.
- **Expected Δ:** F1 back-to-back recovery cross-covered (no directed case can produce the double-stall scenario without chained stimulus since it requires the presenter to be in the rolled-back state when the next stall hits).

### C416 — PRESENTING × empty-field edge × every bp
- **Targets:** `C_PRESENTER_X_BP[PRESENTING][*]` × `empty ≠ 0` on final beat
- **Shape:** 6 rows × 128 txns. Packet lengths chosen so the final egress beat has non-zero `empty`.
- **Termination:** cells closed with non-zero empty.

### C417 — PRESENTING × PAGE_RAM_RD_WIDTH sweep
- **Targets:** `cov_cfg.page_ram_rd_width × C_PRESENTER_X_BP[PRESENTING]`
- **Shape:** 8 configs × 64 txns.
- **Termination:** cells closed for every width.

### C418 — RESTART × every hits_per_subh bin
- **Targets:** `C_PRESENTER_X_BP[RESTART] × cov_pkt.hits_per_subh`
- **Shape:** 9 rows × 64 txns. bp = BURST_STALL tuned per row.
- **Termination:** RESTART cell hit per bin.

### C419 — Presenter × handle_fifo high occupancy
- **Targets:** `C_PRESENTER_X_BP` × `cov_flow.handle_fifo_occupancy=high`
- **Shape:** 200 txns with throttled bp causing handle fifo to fill.
- **Termination:** each presenter state × high-handle cell hit.

### C420 — Presenter × DEBUG_LV=2
- **Targets:** `C_PRESENTER_X_BP` × DEBUG_LV=2
- **Shape:** 128 txns under DEBUG_LV=2 with BURST_STALL bp.
- **Termination:** presenter cells closed in the overwrite-logging build.

---

## C5xx — Arbiter × backlog

**Why not directed:** `arbiter` (page-RAM write port) has 4 states. Its cross with per-lane backlog depends on the history of grants across many lanes. Directed single-txn cases cannot produce the "LOCKED × high backlog on lane k" cell for every k without chaining.

### C501 — LOCKING × every lane as requester
- **Targets:** `C_ARB_X_BACKLOG[LOCKING][*]` with requester rotated across lanes
- **Shape:** 200 txns. Each txn forces one specific lane to be the requester entering LOCKING while others hold their requests. Rotate every 8 txns.
- **Termination:** LOCKING × every lane as requester hit.

### C502 — LOCKED × every lane × backlog bucket
- **Targets:** `C_ARB_X_BACKLOG[LOCKED][low|mid|high]` × per-lane
- **Shape:** 400 txns. Vary ingress rate per lane so backlog bucket walks low→mid→high while a rotating lane holds the lock.
- **Termination:** every (LOCKED, lane, backlog bucket) cell hit.

### C503 — Arbiter fairness soak (no starvation)
- **Targets:** `C_ARB_X_BACKLOG[LOCKED][*]` distribution flat
- **Shape:** 1000 txns, all lanes equal rate. Scoreboard asserts grant count per lane within ±5% of mean.
- **Termination:** 1000 txns OR grant-count variance > 5% → FAIL.
- **Expected Δ:** F9 no-priority-inversion cross-covered.

### C504 — Arbiter priority-inversion hunt
- **Targets:** anti-cells — no LOCKED cell with backlog=high on a non-granted lane while a low-backlog lane holds the lock for > T cycles.
- **Shape:** 500 txns stressing one lane with huge bursts while others idle.
- **Termination:** inversion event → FAIL; else coverage goal met.

### C505 — LOCKED dwell × block_mover WRITE_BLK dwell
- **Targets:** `arbiter.LOCKED × block_mover.WRITE_BLK` co-residency per lane
- **Shape:** 200 txns. Large frames so both states dwell together.
- **Termination:** co-residency cell hit on every lane.

### C506 — IDLE × 0 requests
- **Targets:** `C_ARB_X_BACKLOG[IDLE][0 backlog]`
- **Shape:** 100 txns with long ingress gaps.
- **Termination:** IDLE × zero-backlog cell ≥ 1000 cycles.

### C507 — LOCKING → LOCKED → IDLE fast cycle
- **Targets:** fast-cycle transition counts
- **Shape:** 200 txns with very small frames so the arbiter cycles every few cycles.
- **Termination:** legal-transition counts match reference model.

### C508 — RESET from LOCKED
- **Targets:** `arbiter.RESET` entered from LOCKED
- **Shape:** 32 txns with `reset_txn` timed to LOCKED on rotating lanes.
- **Termination:** RESET-from-LOCKED hit for every lane as lock holder.

### C509 — Arbiter × N_LANE=16 fan-in
- **Targets:** `C_ARB_X_BACKLOG` under N_LANE=16
- **Shape:** 512 txns in N_LANE=16.
- **Termination:** every cell closed.

### C510 — Arbiter × N_LANE=1 degenerate
- **Targets:** `C_ARB_X_BACKLOG` under N_LANE=1
- **Shape:** 64 txns in N_LANE=1 (arbiter always grants).
- **Termination:** degenerate cells hit.

### C511 — Arbiter × egress bp = STUCK_LOW
- **Targets:** `C_ARB_X_BACKLOG[LOCKED] × bp=STUCK_LOW`
- **Shape:** 200 txns under STUCK_LOW windows.
- **Termination:** cell hit on every lane.

### C512 — Arbiter × MODE cross
- **Targets:** `arbiter_state × MODE`
- **Shape:** 2 rows × 256 txns.
- **Termination:** every state × MODE cell hit.

### C513 — Arbiter × ticket_fifo empty periods
- **Targets:** `arbiter.IDLE × ticket_fifo=empty`
- **Shape:** 128 txns.
- **Termination:** cell ≥ 1000 cycles.

### C514 — Arbiter × handle_fifo near-full
- **Targets:** `arbiter.LOCKED × handle_fifo=high`
- **Shape:** 200 txns.
- **Termination:** cell closed.

### C515 — Arbiter × page_ram_depth sweep
- **Targets:** `cov_cfg.page_ram_depth × arbiter_state`
- **Shape:** 4 configs × 64 txns.
- **Termination:** every depth × state cell hit.

---

## C6xx — Packet-class × shd × hit

**Why not directed:** `cov_pkt` has 9 × 9 × 6 × 6 = hundreds of cells (`hits_per_subh` × `subh_per_hdr` × `shd_ts_pattern` × `frame_ts_wrap`). A single directed case hits one tuple; only a chained, randomized run walks the full grid without resetting.

### C601 — Full hits_per_subh × subh_per_hdr grid
- **Targets:** `C_PKT_X_SHD_X_HIT` full 9×9 grid
- **Shape:** 500 txns. `hits_per_subh` and `subh_per_hdr` drawn from all bin values round-robin so every (h, s) pair appears ≥ 5 times.
- **Termination:** grid closed.

### C602 — shd_ts_pattern sweep × every hit-bin
- **Targets:** `cov_pkt.shd_ts_pattern × hits_per_subh`
- **Shape:** 400 txns. shd_ts ∈ {0x00,0x01,0x7F,0x80,0xFE,0xFF}; hit bins randomized.
- **Termination:** cells closed.

### C603 — frame_ts_wrap × hit-bin
- **Targets:** `cov_pkt.frame_ts_wrap × hits_per_subh`
- **Shape:** 200 txns crossing the 48-bit wrap at least 3 times.
- **Termination:** cells closed.

### C604 — first_frame_short × every hit-bin
- **Targets:** `cov_pkt.first_frame_short × hits_per_subh`
- **Shape:** 128 txns. Every txn starts with a short first frame after a 2k-cycle idle.
- **Termination:** cells closed. F4 cross-covered.

### C605 — N_SHD/N_HIT extremes × shd_ts_pattern
- **Targets:** max-subh × shd_ts_pattern
- **Shape:** 150 txns with `subh_per_frame = N_SHD` and rotating shd_ts pattern.
- **Termination:** cells closed.

### C606 — HDR_SIZE × hits_per_subh sweep
- **Targets:** `cov_pkt.hdr_size_words × hits_per_subh`
- **Shape:** 4 configs × 128 txns.
- **Termination:** cells closed.

### C607 — TRACK_HEADER on/off × packet class grid
- **Targets:** `cov_cfg.track_header × C_PKT_X_SHD_X_HIT`
- **Shape:** 2 configs × 256 txns.
- **Termination:** cells closed.

### C608 — channel_width sweep × packet class
- **Targets:** `cov_cfg.channel_width × C_PKT_X_SHD_X_HIT`
- **Shape:** 5 configs × 128 txns, channel id rotated.
- **Termination:** cells closed.

### C609 — frame_ts_wrap × every bp profile
- **Targets:** `cov_pkt.frame_ts_wrap × cov_flow.egress_ready_duty`
- **Shape:** 6 bp rows × 100 txns spanning wrap.
- **Termination:** cells closed.

### C610 — hit=0 edge cell × every subh_per_hdr
- **Targets:** `C_PKT_X_SHD_X_HIT[0][*][*]`
- **Shape:** 128 txns with `hits_per_subh = 0`, rotating subh count.
- **Termination:** cells closed; verifies empty-hit subheader path.

### C611 — hit=N_HIT edge cell × every subh_per_hdr
- **Targets:** `C_PKT_X_SHD_X_HIT[N_HIT][*][*]`
- **Shape:** 128 txns with max hits.
- **Termination:** cells closed.

### C612 — hit=N_HIT+1 (overflow) × every subh bin
- **Targets:** `C_PKT_X_SHD_X_HIT[overflow][*]` × `cov_fsm.ingress_parser[WR_HITS]` × hit_err
- **Shape:** 128 txns injecting one hit past N_HIT per subh.
- **Termination:** overflow cells closed. F5 cross-covered.

### C613 — subh=N_SHD+1 (overflow) × shd_err
- **Targets:** overflow × shd_err
- **Shape:** 64 txns injecting one subh past N_SHD.
- **Termination:** cells closed.

### C614 — Mixed grid × egress bp=RANDOM_DUTY
- **Targets:** `C_PKT_X_SHD_X_HIT` × RANDOM_DUTY axis
- **Shape:** 400 txns with RANDOM_DUTY(50%).
- **Termination:** full grid closed under random bp.

### C615 — Mixed grid × egress bp=BURST_STALL
- **Targets:** `C_PKT_X_SHD_X_HIT × BURST_STALL`
- **Shape:** 400 txns with BURST_STALL.
- **Termination:** grid closed under BURST_STALL.

### C616 — Packet class × DEBUG_LV=0 build
- **Targets:** packet class grid × DEBUG_LV=0
- **Shape:** 256 txns under a DEBUG_LV=0 compile.
- **Termination:** same cells hit as DEBUG_LV=1.

### C617 — shd_ts near-wrap (0xFF→0x00) chained
- **Targets:** shd_ts_pattern rollover
- **Shape:** 128 txns stepping shd_ts through 0xFE→0xFF→0x00→0x01.
- **Termination:** rollover sequence hit ≥ 20 times.

### C618 — N_HIT sweep × hits=max
- **Targets:** `cov_cfg.n_hit × C_PKT_X_SHD_X_HIT[max]`
- **Shape:** 4 configs (N_HIT ∈ {255, 511, 1023, 2047}) × 64 txns.
- **Termination:** cells closed.

### C619 — N_SHD sweep × subh=max
- **Targets:** `cov_cfg.n_shd × C_PKT_X_SHD_X_HIT[*][max]`
- **Shape:** 3 configs × 64 txns.
- **Termination:** cells closed.

---

## C7xx — Error × FSM state

**Why not directed:** errors are generated by deliberate injection. Each FSM × error-class cell requires the error to be live while the FSM is in a specific state. Chained stimulus lets many injections happen without resetting — directed cases otherwise need a fresh DUT per (FSM, state, error-class) tuple.

### C701 — hdr_err × every ingress_parser state
- **Targets:** `C_ERR_X_FSM[hdr_err][ingress_parser.*]`
- **Shape:** 150 txns. `inject_hdr_err` on rotating lane; txns shaped so the bad header lands in every ingress state class.
- **Termination:** hdr_err × every non-RESET ingress state hit.

### C702 — shd_err × every ingress_parser state
- **Targets:** `C_ERR_X_FSM[shd_err][ingress_parser.*]`
- **Shape:** 150 txns.
- **Termination:** cells closed.

### C703 — hit_err × every ingress_parser state
- **Targets:** `C_ERR_X_FSM[hit_err][ingress_parser.*]`
- **Shape:** 150 txns. Inject via `hits_per_subh > N_HIT`.
- **Termination:** cells closed. F5 cross-covered.

### C704 — {hdr,shd,hit}_err combined × ingress_parser
- **Targets:** combined-error cells × ingress state
- **Shape:** 128 txns with all three error bits injected on the same packet.
- **Termination:** combined cells hit on every lane at least once.

### C705 — hdr_err × page_allocator state
- **Targets:** `C_ERR_X_FSM[hdr_err][page_allocator.*]`
- **Shape:** 128 txns. Errored header passes into allocator states.
- **Termination:** cells closed.

### C706 — hit_err × block_mover state
- **Targets:** `C_ERR_X_FSM[hit_err][block_mover.*]`
- **Shape:** 128 txns. hit_err lives on a packet as block_mover processes it.
- **Termination:** cells closed.

### C707 — hit_err × ftable_presenter state
- **Targets:** `C_ERR_X_FSM[hit_err][ftable_presenter.*]`
- **Shape:** 128 txns. Errored packets pushed all the way to presenter.
- **Termination:** cells closed.

### C708 — hdr_err × ftable_presenter × bp
- **Targets:** `C_ERR_X_FSM[hdr_err][ftable_presenter.RESTART]` × bp
- **Shape:** 128 txns. Errored header stalls at presenter under BURST_STALL bp.
- **Termination:** RESTART × hdr_err cell hit.

### C709 — Truncation × ingress_parser MASK_PKT
- **Targets:** `C_ERR_X_FSM[truncation][ingress_parser.MASK_PKT]`
- **Shape:** 128 txns with `inject_truncation`.
- **Termination:** MASK_PKT × truncation cell hit on every lane.

### C710 — Missing EOP × ingress_parser MASK_PKT_EXTENDED
- **Targets:** `C_ERR_X_FSM[missing_eop][MASK_PKT_EXTENDED]`
- **Shape:** 128 txns ending without EOP.
- **Termination:** cells closed.

### C711 — Mid-packet SOP × MASK_PKT
- **Targets:** mid-SOP error class × ingress state
- **Shape:** 128 txns injecting second SOP before EOP.
- **Termination:** cells closed.

### C712 — lane_fifo overflow × ingress_parser
- **Targets:** `C_ERR_X_FSM[lane_fifo_ovfl][ingress_parser.*]`
- **Shape:** 200 txns with egress stuck-low until lane fifo overflows.
- **Termination:** overflow × every ingress state cell hit.

### C713 — ticket_fifo overflow × page_allocator
- **Targets:** `C_ERR_X_FSM[ticket_fifo_ovfl][page_allocator.*]`
- **Shape:** 200 txns pushing ticket fifo beyond capacity.
- **Termination:** cells closed.

### C714 — handle_fifo drop × block_mover
- **Targets:** `C_ERR_X_FSM[handle_fifo_drop][block_mover.*]`
- **Shape:** 200 txns with block_mover throttled by bp.
- **Termination:** cells closed.

### C715 — page_ram almost-full × allocator WRITE_PAGE
- **Targets:** `cov_flow.page_ram=high × allocator.WRITE_PAGE`
- **Shape:** 200 txns forcing page ram to stay ≥ 75%.
- **Termination:** cells closed.

### C716 — Error injection × MODE cross
- **Targets:** error class × MODE
- **Shape:** 2 rows × 256 txns with random errors.
- **Termination:** every error × MODE cell hit.

### C717 — Error injection × DEBUG_LV=2 overwrite log
- **Targets:** error class × overwrite log generation
- **Shape:** 128 txns, DEBUG_LV=2, force overwrite.
- **Termination:** overwrite log contains every error class.

### C718 — Error recovery × every FSM
- **Targets:** recovery trajectory × each FSM (error → IDLE)
- **Shape:** 256 txns with error then idle gap.
- **Termination:** all 7 FSMs show error→IDLE return.

### C719 — Error × first_frame_short
- **Targets:** error class × F4 first_frame_short cell
- **Shape:** 128 txns pairing errors with first-frame-short sequences.
- **Termination:** cells closed.

### C720 — Error × frame_ts wrap
- **Targets:** error class × F3 wrap cell
- **Shape:** 128 txns near 48-bit wrap with error injection.
- **Termination:** cells closed.

---

## C8xx — Timestamp buckets (frame_ts × running_ts)

**Why not directed:** the `frame_ts` / `running_ts` cross is history-dependent — `running_ts` only advances as frames are processed. The cell `C_FTS_X_RTS[near-wrap][near-wrap]` requires the DUT to have processed many frames first. Only chained runs can reach these.

### C801 — running_ts sweep low → near-wrap
- **Targets:** `C_FTS_X_RTS[*][low]` → `[*][near-wrap]`
- **Shape:** 512 txns with steadily increasing `frame_ts`. running_ts walks the buckets low→mid→high→near-wrap.
- **Termination:** every bucket cell visited.

### C802 — frame_ts wrap with running_ts just behind
- **Targets:** `C_FTS_X_RTS[near-wrap][near-wrap]`
- **Shape:** 128 txns straddling the 48-bit wrap.
- **Termination:** wrap × near-wrap cell hit.

### C803 — frame_ts post-wrap × running_ts pre-wrap
- **Targets:** `C_FTS_X_RTS[post-wrap][pre-wrap]`
- **Shape:** 128 txns at the wrap boundary with skew so running_ts lags.
- **Termination:** cell hit.
- **Expected Δ:** F3 advance-timing confirmed under wrap skew.

### C804 — First-frame-short × running_ts bucket grid
- **Targets:** `F4 first_frame_short × running_ts bucket`
- **Shape:** 256 txns starting from each running_ts bucket.
- **Termination:** cells closed.

### C805 — running_ts re-sync × lane-skew extremes
- **Targets:** F4 re-sync × `cov_flow.ingress_lane_skew=high`
- **Shape:** 200 txns with skew up to `LANE_FIFO_DEPTH-1`.
- **Termination:** re-sync cell hit under high skew.

### C806 — frame_ts × hits=N_HIT
- **Targets:** `frame_ts bucket × cov_pkt.hits_per_subh=max`
- **Shape:** 256 txns with max hit packets across frame_ts buckets.
- **Termination:** cells closed.

### C807 — frame_ts × bp=RANDOM_DUTY
- **Targets:** `frame_ts bucket × bp profile`
- **Shape:** 6 bp rows × 128 txns.
- **Termination:** cells closed.

### C808 — running_ts × MODE cross
- **Targets:** `running_ts bucket × MODE`
- **Shape:** 2 rows × 256 txns.
- **Termination:** cells closed.

### C809 — Missing-lane allocator stall × frame_ts
- **Targets:** F7 stall × running_ts bucket
- **Shape:** 150 txns with rotating missing lane and varied running_ts.
- **Termination:** cells closed.

### C810 — shd_ts pattern × frame_ts bucket
- **Targets:** `cov_pkt.shd_ts_pattern × frame_ts bucket`
- **Shape:** 256 txns with every shd_ts pattern at every frame_ts bucket.
- **Termination:** cells closed.

### C811 — Long-dwell frame_ts in near-wrap
- **Targets:** F3 wrap cell held under egress stall
- **Shape:** 128 txns. Egress STUCK_LOW while frame_ts advances through wrap.
- **Termination:** cell hit with stuck-low window overlap.

### C812 — running_ts saturation × arbiter backlog
- **Targets:** `running_ts bucket × C_ARB_X_BACKLOG`
- **Shape:** 256 txns at high ingress rate.
- **Termination:** cells closed.

### C813 — running_ts × N_LANE sweep
- **Targets:** `running_ts bucket × N_LANE`
- **Shape:** 5 configs × 64 txns.
- **Termination:** cells closed.

### C814 — running_ts × page_ram_depth sweep
- **Targets:** `running_ts bucket × page_ram_depth`
- **Shape:** 4 configs × 64 txns.
- **Termination:** cells closed.

### C815 — Reset during near-wrap → recovery timestamp
- **Targets:** reset × near-wrap → post-reset running_ts cell
- **Shape:** 32 txns with `reset_txn` timed at near-wrap.
- **Termination:** recovery trajectory captured.

---

## C9xx — Lane skew × MODE

**Why not directed:** lane skew is a per-run property; to cross it with MODE requires multiple chained txns with independently varying skew and lane set under each MODE. Directed cases pick one skew value.

### C901 — Skew=0 × MERGING, all lanes active
- **Targets:** `C_SKEW_X_MODE[0][MERGING]`, `cov_flow.ingress_lane_skew[0]`
- **Shape:** 256 txns zero-skew under MERGING. Long run to also hit arbiter fairness.
- **Termination:** cell hit, fairness variance within bound.

### C902 — Skew=0 × MULTIPLEXING
- **Targets:** `C_SKEW_X_MODE[0][MULTIPLEXING]`
- **Shape:** 256 txns.
- **Termination:** cell hit.

### C903 — Skew small (1 beat) × MERGING × every lane as laggard
- **Targets:** `C_SKEW_X_MODE[1][MERGING]` × lane axis
- **Shape:** 200 txns, rotating laggard lane.
- **Termination:** cells closed.

### C904 — Skew=10 × MERGING
- **Targets:** `C_SKEW_X_MODE[10][MERGING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C905 — Skew=100 × MERGING
- **Targets:** `C_SKEW_X_MODE[100][MERGING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C906 — Skew=1000 × MERGING
- **Targets:** `C_SKEW_X_MODE[1000][MERGING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C907 — Skew=LANE_FIFO_DEPTH/2 × MERGING
- **Targets:** `C_SKEW_X_MODE[LANE_FIFO_DEPTH/2][MERGING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C908 — Skew=LANE_FIFO_DEPTH-1 × MERGING
- **Targets:** `C_SKEW_X_MODE[LANE_FIFO_DEPTH-1][MERGING]`
- **Shape:** 128 txns. Verifies no drop at the very edge.
- **Termination:** cell hit, lane_fifo does not overflow.

### C909 — Skew=LANE_FIFO_DEPTH/2 × MULTIPLEXING
- **Targets:** `C_SKEW_X_MODE[LANE_FIFO_DEPTH/2][MULTIPLEXING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C910 — Skew=LANE_FIFO_DEPTH-1 × MULTIPLEXING
- **Targets:** `C_SKEW_X_MODE[LANE_FIFO_DEPTH-1][MULTIPLEXING]`
- **Shape:** 128 txns.
- **Termination:** cell hit.

### C911 — Skew ramp 0 → LANE_FIFO_DEPTH-1 × MERGING
- **Targets:** ramp trajectory hitting every skew bin × MERGING
- **Shape:** 200 txns with skew increasing monotonically.
- **Termination:** every skew bin hit in sequence.

### C912 — Skew ramp 0 → LANE_FIFO_DEPTH-1 × MULTIPLEXING
- **Targets:** ramp × MULTIPLEXING
- **Shape:** 200 txns.
- **Termination:** cells closed.

### C913 — Skew oscillation (square wave)
- **Targets:** skew × lane-swap axis
- **Shape:** 256 txns with skew sign swapped every 16 txns — laggard lane flips.
- **Termination:** each lane hit both leading and lagging roles.

### C914 — Skew × error injection
- **Targets:** skew × error bit
- **Shape:** 256 txns with skew + random errors.
- **Termination:** skew × error × MODE cells closed.

### C915 — Skew × bp profile cross
- **Targets:** `C_SKEW_X_MODE × cov_flow.egress_ready_duty`
- **Shape:** 6 bp rows × 128 txns at mid-skew.
- **Termination:** cells closed.

### C916 — Skew × lane_fifo_depth sweep
- **Targets:** `C_SKEW_X_MODE × cov_cfg.lane_fifo_depth`
- **Shape:** 7 configs × 64 txns.
- **Termination:** cells closed.

### C917 — Skew × N_LANE sweep
- **Targets:** `C_SKEW_X_MODE × cov_cfg.n_lane`
- **Shape:** 5 configs × 64 txns.
- **Termination:** cells closed.

### C918 — Skew × channel_width sweep
- **Targets:** `C_SKEW_X_MODE × cov_cfg.channel_width`
- **Shape:** 5 configs × 64 txns.
- **Termination:** cells closed.

### C919 — Skew × DEBUG_LV parity
- **Targets:** `C_SKEW_X_MODE × DEBUG_LV`
- **Shape:** 3 configs (DEBUG_LV=0,1,2) × 128 txns.
- **Termination:** cells closed; non-debug build not pruning state.

### C920 — Skew × first_frame_short
- **Targets:** `C_SKEW_X_MODE × F4`
- **Shape:** 128 txns, every txn starts with first-frame-short under skew.
- **Termination:** cells closed; F4 confirmed with skew.

---

## Regression Notes

- The full C-bucket runs on the nightly `regress` target. The test-ID → regress-row mapping lives in `opq_regress_list.f`; each row sets `+OPQ_TEST_ID=C…` and the per-scenario parameters.
- Each scenario's UCDB is merged into `cov/merged.ucdb`; the scoreboard records which `cov_cross` cells each scenario claimed and the `cov_merge` step rejects any scenario that claimed a cell but did not hit it.
- The nightly regression budget is sized so the C-bucket completes within the 12-hour window on `teferi` (Questa full license, single process per row; matrix rows run sequentially to avoid license churn).
- Watchdogs: every scenario sets `watchdog_cycles = 8 × expected_txn_cycles`; the env `UVM_FATAL`s on overrun.
- **No destructive cleanup** occurs between scenarios — each Make row is its own simulator invocation, so there is no shared filesystem state to remove.

# DV Plan: ordered_priority_queue (monolithic)

**DUT:** `packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv`  
**Packaging:** `packet_scheduler/script/ordered_priority_queue_hw.tcl`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-24
**Status:** Active current-tree plan for the native monolithic SystemVerilog DUT and the live `packet_scheduler/tb/uvm` harness. The legacy monolithic VHDL image remains a behavioral reference only and does not count as signoff evidence.

---

## 1. Purpose

This document surfaces the still-valid verification intent from
`packet_scheduler/tb/legacy/tb/DV_PLAN.md` into the current tree, then narrows it
to what the live harness can actually execute and close today.

The core contract remains the same:

- aggregate multiple ingress FEB lanes into one timestamp-ordered egress stream
- preserve hits end-to-end: no missing hits, no ghost-created hits
- place each hit under the correct subheader / time slot
- handle egress backpressure without duplication or reordering
- account for packet drops and overwrite drops in the visible CSR counters

`packet_scheduler/doc/architecture_note.md` freezes one important refinement of
that contract for the active closure phase: overflow is legal only when it is
explicit, counted, and does not leave incomplete packet format or holes in the
frame-table ownership model.

The legacy plan is still useful, but it needs corrections for the current IP
revision and current harness.

---

## 2. Legacy Reconciliation

### Still valid from the archived plan

- The bucket split remains correct: `DV_BASIC`, `DV_EDGE`, `DV_PROF`,
  `DV_ERROR`, and `DV_CROSS`.
- The coverage families remain correct:
  - parameter-space coverage
  - packet-shape coverage
  - flow-control coverage
  - CSR / counter coverage
  - cross coverage
- Structural signoff targets remain the same intent:
  - statement coverage at least 95%
  - branch coverage at least 90%
  - FSM state / transition closure
  - toggle coverage on key ports / state enums
  - functional coverage closure with justified exclusions only
- Assertion families remain valid:
  - ingress Avalon-ST
  - egress Avalon-ST
  - CSR protocol
  - hit-contract / timestamp-order checks
  - overflow / credit / overwrite invariants

### Corrected versus the archived plan

- The IP now has a runtime CSR slave. The archived claim "no Avalon-MM CSR
  slave" is no longer valid.
- The full frame timestamp is now part of the active contract. The DUT uses the
  full frame-base timestamp and extends subheader low-byte wrap into an
  absolute hit timestamp.
- Frame timestamp spacing is measured in FEB header timestamp ticks, not in
  live SWB/UVM clock cycles. One OPQ frame advances `frame_ts` by
  `N_SHD * 16` ticks, where each timestamp tick is `8 ns`: `0x400` for
  `N_SHD=64`, `0x800` for `N_SHD=128`, and `0x1000` for `N_SHD=256`.
  The live SWB/UVM clock is `250 MHz` (`4 ns`), so the equivalent SWB-cycle
  spacing is doubled: `0x800`, `0x1000`, and `0x2000` cycles for those three
  points. Harness fields named `*_CYCLES` must convert between these domains
  explicitly instead of reusing header timestamp increments directly.
- `N_SHD=128` is the active default. Current feature-range signoff covers
  `N_SHD=64 / 128 / 256`, and the `64` point remains mandatory because its
  shorter frame period exposes hard-coded timing assumptions that the default
  point can hide.
- `TICKET_FIFO_DEPTH` must be derived from both frame size and lane count:
  `max(256, 32 * N_SHD, 2 * N_SHD * N_LANE)`, rounded up to a power of two.
  This is now a shared packaging and harness contract.
- The old split-tree scope is deprecated. Live DV is for the monolithic DUT.

### Deferred from the archived plan

- Full `MODE` matrix (`MERGING` plus `MULTIPLEXING`) is not yet closed on the
  live harness.
- The deliverable OPQ feature-range sweep for `N_LANE=4/8/16` and
  `PAGE_RAM_RD_WIDTH=36/72/144/288` is closed by the focused RTL simulation
  matrix below. Wider mode combinations outside that matrix remain backlog.
- The very large legacy directed catalog remains a backlog, not a current-tree
  implementation claim.

---

## 3. Live Harness Scope

The live harness is documented in `packet_scheduler/tb/DV_HARNESS.md`. The
current implementation scope is intentionally narrower than the archived plan:

- DUT implementation under signoff is the native monolithic SystemVerilog core
- mixed-language UVM harness in `packet_scheduler/tb/uvm`
- active generated standalone dashboard slice is
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
- historical 2-lane closure remains useful evidence, but the current deliverable
  feature-range evidence is the `4/8/16` lane and `1x/2x/4x/8x` egress-width
  matrix below
- build-time sweep knobs that already work today and remain planned expansion
  axes:
  - `OPQ_N_SHD = 64 / 128 / 256`
  - derived or explicit `OPQ_TICKET_FIFO_DEPTH`
  - reduced `OPQ_PAGE_RAM_DEPTH` for overflow forcing

The following compile / elaboration-time sweep is part of signoff intent and
must remain in the plan, even though the current generated dashboard is frozen
to the canonical `4-lane/128/256` rerun slice:

- randomize `N_SHD` across `64 / 128 / 256` at build time
- derive a safe `TICKET_FIFO_DEPTH` from `N_SHD`
- extend the same mechanism to other exposed generics once the harness supports
  them cleanly

### 2026-04-24 `N_SHD` timing-domain sanity

The direct standalone sanity sweep was rerun for `OPQ_N_LANE=4`,
`DUT_IMPL=native_sv`, and `N_SHD=64 / 128 / 256`, with logs preserved under
`/tmp/opq_dv_nshd_frame_20260424_rerun2/`.

| `N_SHD` | `frame_ts` step | SWB cycles at 250 MHz | ticket depth | direct no-drop tests | continuous-frame tests |
|---------|----------------:|----------------------:|-------------:|----------------------|------------------------|
| `64` | `0x400` FEB ticks | `0x800` cycles | `2048` | pass: smoke `8/8`, ts `6/6`, max-hits `319/319` | pass: bucket `4306/4306`, all-buckets `4342/4342` |
| `128` | `0x800` FEB ticks | `0x1000` cycles | `4096` | pass: smoke `8/8`, ts `6/6`, max-hits `319/319` | pass: bucket `4306/4306`, all-buckets `4342/4342` |
| `256` | `0x1000` FEB ticks | `0x2000` cycles | `8192` | pass: smoke `8/8`, ts `6/6`, max-hits `319/319` | pass: bucket `4306/4306`, all-buckets `4342/4342` |

This shows that the non-default `N_SHD` values are genuinely compiled and
elaborated; the `64` and `256` points are not silently falling back to the
default. The earlier direct-test failures were harness assumptions:
hard-coded boundary positions were outside `N_SHD=64`, and the max-hit sequence
overdrove aggregate hits when lane count changed. Those stimulus issues are
closed on the rerun.

### 2026-04-24 `N_LANE=8/16` and wide-egress closure status

The `_hw.tcl` package exposes `N_LANE={2,4,8,16}`. The deliverable OPQ
feature range for this release is `N_LANE=4/8/16`, with egress beat width
`PAGE_RAM_RD_WIDTH=36/72/144/288` (1/2/4/8 OPQ 36-bit words per beat).

The full focused matrix was rerun on 2026-04-24 under
`/tmp/opq_dv_lane_width_20260424_rerun2/`.

| matrix axis | values | tests per point | result |
|-------------|--------|-----------------|--------|
| `N_LANE` | `4 / 8 / 16` | 6 | pass |
| `PAGE_RAM_RD_WIDTH` | `36 / 72 / 144 / 288` | 6 | pass |
| total | 12 build points | 72 runs | `72/72` pass, `UVM_ERROR=0`, `UVM_FATAL=0`, Questa `Errors=0` |

The per-point tests are `opq_basic_smoke_test`,
`opq_basic_ts_boundary_test`, `opq_edge_max_hits_test`,
`opq_prof_whole_frame_skew_test`, `opq_bucket_frame_native_sv_test`, and
`opq_all_buckets_frame_native_sv_test`. The worst-size
`N_LANE=16/PAGE_RAM_RD_WIDTH=288` all-buckets run closed with
`expected=5550 actual=5550 missing=0 ghost=0`.

This debug found a real allocator bug before the 8/16-lane screens could be
trusted: same-serial body tickets in an active frame were classified as
`future` when their hit timestamp was ahead of the current subheader cursor,
so the tail-retire path could close the frame after the trailer and late-drop
the body tickets. `ordered_priority_queue_monolithic_page_allocator.sv` now
keeps same-serial active-frame body tickets in-window until the current frame
has consumed or retired them.

This matrix is the current DV closure point for the OPQ lane-count and
multi-symbol egress feature range. It does not claim the deprecated 2-lane
path as a release target and does not expand the full legacy bucket catalog to
every lane/width pair.

The old time-merger comparison path also has a standalone exact-frame
SystemVerilog reference under `packet_scheduler/tb_old_reference/`. It parses
the same OPQ/FEB 36-bit frame words as the UVM ingress driver, builds a
stage-buffered 2-input tree for `N_LANE=4/8/16`, and currently passes:

```sh
make -C packet_scheduler/tb_old_reference BUILD_DIR=/tmp/old_tm_ref smoke-all
```

That reference is intentionally not pin-to-pin integrated into the historical
SWB datapath; the required contract is exact frame-format parsing and a
standalone finite-service tree suitable for matched OPQ/time-merger sweeps.

Loss/contour/skew plot evidence for this DV plan must come from HDL simulation
CSV/DAT artifacts. Analytical or proxy Python/C model outputs must not be used
as `MATH_REPORT` evidence.

`PAGE_RAM_RD_WIDTH > 36` is now covered by the same matrix. The widened
presenter/packer path and `aso_egress_empty` sideband are exercised by the UVM
egress monitor and scoreboard at 2x/4x/8x widths.

---

## 4. Active Buckets

The active current-tree buckets are split into dedicated markdown files and the
matching script wrappers under `packet_scheduler/tb/scripts/`.

| Bucket | Markdown | Wrapper | Current promoted tests | Contract exercised |
|--------|----------|---------|------------------------|--------------------|
| `DV_BASIC` | `DV_BASIC.md` | `run_basic.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_basic_subheader_shape_test`, `opq_basic_feb_packet_contract_test`, `opq_basic_single_active_lane_test`, `opq_basic_single_active_lane_lane1_test`, `opq_basic_single_active_lane_dense_test` | End-to-end hit preservation, full-ts boundary behavior, subheader shape, native FEB whole-frame contract, and single-active-lane healthy-path closure |
| `DV_PARAM` | `DV_PARAM.md` | `run_param.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` across `N_SHD=64/128/256` | Compile / elaboration-time configuration sweep for the active harness |
| `DV_EDGE` | `DV_EDGE.md` | `run_edge.sh` | `opq_edge_backpressure_test`, `opq_edge_always_ready_test`, `opq_edge_ready_medium_profile_test`, `opq_edge_stuck_low_backpressure_test`, `opq_edge_max_hits_test`, `opq_edge_toggle_backpressure_test`, `opq_edge_burst_restart_profile_test`, `opq_edge_long_toggle_backpressure_test`, `opq_edge_max_hits_backpressure_test` | Backpressure restart, always-ready baseline, medium/stuck-low ready profiles, max-hit packet shape, short/long-toggle ready behavior, and max-hit under healthy restart |
| `DV_PROF` | `DV_PROF.md` | `run_perf.sh` | `opq_prof_stress_test`, `opq_prof_lane_skew_test`, `opq_prof_whole_frame_skew_test`, `opq_prof_missing_empty_frame_test`, `opq_prof_long_soak_test`, `opq_prof_heavy_lane_skew_test`, `opq_prof_deep_whole_frame_skew_test`, `opq_prof_per_lane_half_frame_skew_sweep_test`, `opq_prof_asymmetric_missing_empty_frame_test` | Sustained traffic without drop, lane skew, deeper whole-frame cadence skew, 4-lane per-lane half-frame skew sweep, asymmetric missing-empty-frame residency, and longer healthy soaks on the active signoff contract |
| `DV_ERROR` | `DV_ERROR.md` | `run_error.sh` | `opq_error_lane_mask_test`, `opq_error_lane_mask_single_hit_test`, `opq_error_lane_mask_burst_test`, `opq_error_lane_mask_recovery_test`, `opq_error_hit_mask_recovery_test`, `opq_error_subheader_mask_recovery_test`, `opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`, `opq_error_counter_clear_test`, `opq_error_ftable_overflow_test` | Mask-at-boundary recovery, typed ingress error masking at hit/subheader/header scope, the passing counter-clear supplemental screen, and the reduced-depth overwrite/drop elaboration point |
| `DV_CROSS` | `DV_CROSS.md` | `run_cross.sh` | `opq_cross_bp_credit_test`, `opq_cross_drr_allowance_test`, `opq_cross_drr_idle_lane_test`, `opq_cross_drr_zero_allowance_test`, `opq_cross_drr_short_allowance_test`, `opq_cross_idle_lane_backpressure_test`, `opq_cross_mixed_bucket_random_soak_test` | Backpressure × credit, block-level DRR allowance/defer accounting, idle-lane backpressure, and the supplemental mixed-bucket random-soak signoff screen |

Open reproducers stay outside the default bucket runners and are grouped under
`packet_scheduler/tb/scripts/run_probes.sh`, documented in `DV_PROBE.md`.

The merged signoff coverage closure remains separately controlled by
`run_cov_closure.sh`.

The generated `DV_REPORT.md` / `DV_COV.md` intentionally separate:

- full bucket catalog inventory from the archived or derived plan
- promoted native-SV signoff subset
- actually evidenced passing native-SV cases

This prevents the dashboard from collapsing the full verification plan into the
much smaller currently promoted closure set.

Promoted into the live wrappers, generated report flow, and fixed default-build
bucket-frame baselines on `2026-04-20`:

- `DV_BASIC`: `opq_basic_single_active_lane_test`,
  `opq_basic_single_active_lane_lane1_test`,
  `opq_basic_single_active_lane_dense_test`
- `DV_EDGE`: `opq_edge_burst_restart_profile_test`,
  `opq_edge_long_toggle_backpressure_test`,
  `opq_edge_max_hits_backpressure_test`
- `DV_PROF`: `opq_prof_long_soak_test`, `opq_prof_heavy_lane_skew_test`,
  `opq_prof_deep_whole_frame_skew_test`,
  `opq_prof_per_lane_half_frame_skew_sweep_test`,
  `opq_prof_asymmetric_missing_empty_frame_test`
- `DV_ERROR`: `opq_error_header_mask_recovery_test`,
  `opq_error_header_word_mask_recovery_test`

---

## 5. Validated Current Cases

These checks are currently valid and rerun against the live DUT:

- `opq_basic_smoke_test`
  - scoreboards hit integrity
  - checks per-lane credit and no-drop healthy path
  - checks frame-table counters remain clean in the healthy case
- `opq_basic_ts_boundary_test`
  - validates boundary timestamp handling with full-ts reconstruction
  - currently green at `N_SHD=128`, `256`, and `512`
- `opq_basic_subheader_shape_test`
  - validates sparse, mixed hit-count subheader framing on the healthy path
- `opq_basic_feb_packet_contract_test`
  - validates the native FEB whole-frame packet contract
  - checks monitor-side reconstruction from the real ingress pins
- `opq_basic_single_active_lane_test`
  - validates one active hit lane while the peer lane stays on legal
    empty-frame cadence
- `opq_basic_single_active_lane_lane1_test`
  - validates the same single-hit-lane contract when lane 1 owns the active
    traffic and lane 0 provides only legal empty-frame cadence
- `opq_basic_single_active_lane_dense_test`
  - validates denser single-lane subheader and hit packing without changing the
    no-drop healthy-path contract
- `opq_edge_backpressure_test`
  - validates presenter restart behavior under periodic stall
- `opq_edge_always_ready_test`
  - baseline edge profile with explicit ready driving
- `opq_edge_ready_medium_profile_test`
  - validates the medium-ready duty-cycle profile on the healthy path
- `opq_edge_stuck_low_backpressure_test`
  - validates longer low-ready windows short of the known overwrite probe path
- `opq_edge_max_hits_test`
  - validates max-hit path and hit preservation
  - currently green at `N_SHD=128`, `256`, and `512`
- `opq_edge_toggle_backpressure_test`
  - validates single-cycle ready toggling on the healthy datapath
- `opq_edge_burst_restart_profile_test`
  - validates short ready bursts with deeper low stretches to stress repeated
    presenter restart
- `opq_edge_long_toggle_backpressure_test`
  - extends the one-cycle toggle profile deep enough to sample repeated
    presenter restart without crossing into overwrite forcing
- `opq_edge_max_hits_backpressure_test`
  - combines the max-hit packet-shape path with healthy periodic restart so the
    shape and restart cones are exercised together
- `opq_prof_stress_test`
  - validates short soak behavior on the live harness
- `opq_prof_lane_skew_test`
  - validates sustained two-lane skew without data loss
- `opq_prof_whole_frame_skew_test`
  - validates whole-frame skew with alternating active and empty FEB frames
- `opq_prof_missing_empty_frame_test`
  - validates uneven per-lane frame counts on the active 2-lane harness
  - remains separate from the current 4-lane debug-only scope; focused 4-lane
    reruns are green, but they are not part of the promoted signoff claim
- `opq_prof_long_soak_test`
  - validates a longer directed FEB whole-frame soak beyond the short promoted
    stress run
- `opq_prof_heavy_lane_skew_test`
  - extends the healthy skew envelope beyond the promoted lane-skew case while
    remaining inside zero-drop accounting
- `opq_prof_deep_whole_frame_skew_test`
  - extends the whole-frame skew cadence beyond the promoted case with a deeper
    frame chain and reduced subheader density
- `opq_prof_asymmetric_missing_empty_frame_test`
  - explicitly drives uneven 2-lane frame counts on the native-SV harness,
    instead of relying on the 4-lane-only default asymmetry in the shared
    sequence
- `opq_error_lane_mask_test`
  - validates packet-boundary lane mask control and per-lane drop counters
- `opq_error_lane_mask_single_hit_test`
  - validates masked-drop accounting on minimal packets
- `opq_error_lane_mask_burst_test`
  - validates masked-drop accounting across multi-hit bursts
- `opq_error_counter_clear_test`
  - validates counter-clear control behavior
  - tracked as a dedicated supplemental native-SV signoff run because it
    intentionally clears live counters before end-of-run reporting
- `opq_cross_bp_credit_test`
  - validates the current implemented backpressure × credit cross path
- `opq_cross_drr_allowance_test`
  - validates runtime CSR programming of per-lane DRR allowance
  - validates block-level defer behavior and DRR counters on the live DUT
  - currently green on the active harness
- `opq_cross_drr_idle_lane_test`
  - validates DRR behavior when the peer lane is hit-idle but still emits empty
    frames to preserve legal frame cadence
- `opq_cross_drr_zero_allowance_test`
  - validates that a zero-allowance lane defers and later reloads cleanly
- `opq_cross_drr_short_allowance_test`
  - validates repeated short-quantum reload behavior and service fairness on the
    directed path
- `opq_cross_idle_lane_backpressure_test`
  - validates periodic presenter restart while the peer lane stays on legal
    empty-frame cadence
- `opq_cross_mixed_bucket_random_soak_test`
  - validates chained no-restart behavior across safe promoted
    BASIC/EDGE/PROF/ERROR/CROSS slices
  - tracked as a dedicated supplemental native-SV signoff run outside the
    fixed case-ordered bucket-frame baselines
- `opq_cross_drr_bursty_frame2_boundary_test`
  - dedicated bursty DRR supplemental native-SV signoff screen
  - freezes the largest green bursty envelope below `BUG-025-R` on the
    default build
  - closes on `2026-04-20` with `expected=298 actual=298 missing=0 ghost=0`
- `opq_cross_bp_predrop_boundary_test`
  - dedicated default-build supplemental native-SV signoff screen
  - proves the legal ingress pre-drop boundary under sustained backpressure:
    `ft_drop_*` stays at zero, `wr = rd + drop` remains clean, and both lanes
    close with `unexplained=0`
  - this closes the "must not drop" half of the default-build overflow
    contract while the separate reduced-depth must-drop witness covers the
    overwrite-local side explicitly
- `opq_cross_bp_mustdrop_witness_test`
  - dedicated reduced-depth supplemental native-SV signoff screen
  - proves a clean overwrite-local must-drop path under
    `OPQ_PAGE_RAM_DEPTH=512` when run with
    `+OPQ_BP_MUSTDROP_NODROP_FRAME_COUNT=1`,
    `+OPQ_BP_MUSTDROP_NODROP_HITS=1`,
    `+OPQ_BP_MUSTDROP_FRAME_COUNT=12`, and
    `+OPQ_BP_MUSTDROP_HITS=16`
  - the no-drop pre-phase keeps `ft_drop_hdr/shd/hit=0/0/0`, while the
    pressure phase advances `ft_drop_hdr/shd/hit=10/80/2400` and still closes
    with aggregate `accepted=735 delivered=735 unexplained=0` and
    `core_principles first_break=clean`
- `opq_cross_random_ready_overflow_step2_boundary_test`
  - dedicated default-build supplemental native-SV signoff screen
  - freezes the current green early-window random-ready overflow boundary in
    shape-check mode
  - refreshed on `2026-04-21` with final `wr_hdr/shd/hit=6/11/1176`,
    `rd_hdr/shd/hit=6/11/1176`, `ft_drop_hdr/shd/hit=0/0/0`, aggregate
    `accepted=1176 delivered=1176 unexplained=0`, and
    `core_principles first_break=clean`
  - this closes the early legal-overflow half of the default-build
    random-ready path while explicit overwrite-local must-drop coverage is
    carried by the reduced-depth witness
- `opq_error_lane_mask_recovery_test`
  - promoted signoff testcase
  - validates clean recovery after the active-lane mask is cleared
- `opq_error_subheader_mask_recovery_test`
  - promoted signoff testcase
  - validates that a malformed subheader is masked without poisoning the next
    legal FEB packet
- `opq_error_header_mask_recovery_test`
  - promoted signoff testcase
  - validates that a malformed preamble/header is masked without poisoning the
    next legal FEB packet
- `opq_error_header_word_mask_recovery_test`
  - promoted signoff testcase
  - validates that a header-word error is masked without corrupting the next
    legal frame timestamp base
- `opq_error_ftable_overflow_test`
  - dedicated reduced-depth supplemental native-SV signoff screen
  - on the current tree the legacy reduced-depth `frame_count=32` profile is
    back to a shape-check screen by default rather than a must-drop proof:
    it closes with `UVM_ERROR : 0`, frame-table ledger
    `wr_hdr=32 rd_hdr=20 drop_hdr=12`,
    `wr_shd=8191 rd_shd=5120 drop_shd=3071`,
    `wr_hit=44 rd_hit=28 drop_hit=16`, and aggregate
    `accepted=28 delivered=28 unexplained=0`
  - it remains outside the fixed default-build no-restart baseline because it
    requires a separate `OPQ_PAGE_RAM_DEPTH=512` elaboration point
- `opq_cross_drr_bursty_random_test`
  - constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls
  - refreshed native-SV reruns on `2026-04-20` are currently green through
    seeds 1 through 8, all with `missing=0 ghost=0` and per-lane
    `unexplained=0`
  - this no longer serves as an active failing anchor; keep it as a continued
    supplemental confidence screen until the dashboard is refreshed
- `opq_cross_drr_bursty_frame3_repro_test`
  - reduced deterministic bursty DRR retirement screen for the old
    `BUG-025-R` claim
  - freezes the smallest previously failing `2026-04-20` envelope:
    `frame_count=3`, `subheaders=11`, `hot_hits=46`, `cold_hits=4`,
    `hot_gap=8`, `cold_gap=4032`, allowance `1/46`
  - that named repro now reruns green on the current tree with
    `expected=714 actual=714 missing=0 ghost=0`, so it is no longer the
    current shortest failing boundary
- `opq_cross_random_ready_overflow_seconds_soak_test`
  - default-build random-ready overflow / backpressure soak with per-step
    frame-table and per-lane hit ledgers
  - on the current tree this is back to a default-build shape-check screen:
    the 12-step rerun closes with `UVM_ERROR : 0`,
    `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=29/68/5545`,
    `rd_hdr/shd/hit=29/68/5545`, aggregate
    `accepted=5545 delivered=5545 unexplained=0`, and
    `core_principles first_break=clean`
  - it therefore remains useful as a legal-overflow screen, not as the active
    must-drop anchor

---

## 6. Functional Coverage Intent

The archived coverage model is still the right shape. The current live harness
implements and samples these families:

- configuration coverage
- frame / subheader shape coverage
- ingress / egress beat-shape coverage
- backpressure coverage
- CSR access coverage
- credit snapshot coverage
- lane-drop / frame-table-drop snapshot coverage

The current-tree companion files for the still-open signoff axes are:

- `DV_PARAM.md` for compile / elaboration-time configuration sweep
- `DV_PROBE.md` for non-promoted bug reproducers
- `DV_FORMAL.md` for formal-readiness and proof targets

The next closure increments should follow the archived intent, but only for
cases that the current harness can truly execute:

- promote parameter-space bins that already have live build-time support
- use compile / elaboration-time configuration sweep for `N_SHD` and derived ticket depth
- add new bins only when the harness can observe and check the contract

---

## 7. Plan / Code Traceability

The active harness now keeps the implementation and plan side by side. The
table below is intentionally high-level so the chief architect can track
closure progress without reading the whole testcase catalog.

| Feature / contract | Plan evidence | Code / harness hook | Status | Functional gain | Code-path gain |
|--------------------|---------------|---------------------|--------|-----------------|----------------|
| Full-ts hit integrity | `DV_BASIC`, `DV_EDGE` | scoreboard + `opq_hit3_contract_sva` | Implemented / green | High | High |
| Active `N_SHD` sweep | `DV_PARAM` | `run_param.sh`, `cg_cfg`, wrapper defines | Implemented / green at `64/128/256` | Medium | Medium |
| Deliverable lane-count sweep | `DV_PARAM`, focused feature matrix | array DUT wrapper, scoreboard lane accounting | Implemented / green at `N_LANE=4/8/16` | High | High |
| Multi-symbol egress width | focused feature matrix | egress packer, `aso_egress_empty`, egress monitor unpacking | Implemented / green at `PAGE_RAM_RD_WIDTH=36/72/144/288` | High | High |
| Runtime CSR header + counters | `DV_ERROR`, `DV_CROSS` | CSR helpers + `opq_csr_sva` | Implemented / green on the promoted subset | Medium | Medium |
| Lane mask at packet boundary | `DV_ERROR` | CSR lane-mask helpers + counter checks | Implemented / green | Medium | Medium |
| DRR allowance programming | `DV_CROSS` | `opq_cross_drr_allowance_test`, DRR CSR reads | Implemented / green | Medium | Medium |
| DRR defer / lock contract | `DV_CROSS`, formal backlog | `opq_drr_sva`, DRR covergroup bins, DRR CSR counters | Implemented / green on directed allowance case | Medium | Medium |
| Bursty hot-lane DRR stress | `DV_CROSS`, formal backlog | `opq_cross_drr_bursty_random_test`, `opq_cross_drr_bursty_frame2_boundary_test`, `opq_cross_drr_bursty_frame3_repro_test` | Implemented / green on `2026-04-21`: the named `frame2` boundary, the `frame3` repro, and refreshed seeds `1..8` of the large constrained-random screen all close with per-lane `unexplained=0` | High | Medium |
| Default-build legal pre-drop boundary | `DV_CROSS`, architecture note | `opq_cross_bp_predrop_boundary_test`, per-step hit ledgers, FT CSR ledger checks | Implemented / green on `2026-04-20`: sustained pressure keeps `ft_drop_* = 0` while hit conservation and `wr = rd + drop` still close | High | Medium |
| Default-build legal early-overflow boundary | `DV_CROSS`, architecture note | `opq_cross_random_ready_overflow_step2_boundary_test`, per-step hit ledgers, FT CSR ledger checks | Implemented / green on `2026-04-21`: the first two random-ready overflow windows keep `ft_drop_* = 0`, `wr = rd + drop`, and `unexplained = 0` | High | Medium |
| Overflow + random-ready backpressure stress | `DV_CROSS`, formal backlog | `opq_cross_random_ready_overflow_seconds_soak_test`, per-step hit ledgers, FT CSR ledger checks | Shape-check green on the current tree; explicit overwrite-local must-drop progress is now covered separately by the green reduced-depth `opq_cross_bp_mustdrop_witness_test` witness | High | Medium |
| Backpressure hold / restart | `DV_EDGE`, `DV_CROSS`, `DV_ERROR` probe path | `opq_avst_egress_sva`, `opq_hit3_contract_sva`, presenter logic | Implemented / green on the promoted default-build matrix, the refreshed bursty-DRR screens, and the reduced-depth must-drop witness; no active live restart corruption bug is currently reproduced | High | Medium |

---

## 8. Earlier Request Trace

The earlier project requests are tracked explicitly here so the current tree
states which items are really closed and which are still backlog.

| Earlier requested item | Current state | Evidence |
|------------------------|---------------|----------|
| Full-ts hit tracking with no ambiguity after long lane stalls | Implemented / green on promoted path | scoreboard absolute `ts[47:0]`, `opq_hit3_contract_sva`, `DV_BASIC`, `DV_PARAM` |
| UVM-only `HIT_ID` for missing/ghost-hit tracking | Implemented / green | scoreboard contract in `DV_HARNESS.md`, promoted integrity tests |
| `N_SHD=128` default plus `64/128/256` signoff sweep | Implemented / green | `DV_PARAM.md`, `run_param.sh`, `cg_cfg`, `/tmp/opq_dv_nshd_frame_20260424_rerun2/` |
| DRR per-lane allowance through CSR plus monitors/counters | Implemented / green on directed path | `DV_CROSS.md`, `opq_cross_drr_allowance_test`, DRR CSR checks |
| DRR SVA and constrained-random stress | Implemented / green on current named screens: directed SVA closure is green, `opq_cross_drr_bursty_frame2_boundary_test` and `opq_cross_drr_bursty_frame3_repro_test` are both green, and the refreshed `opq_cross_drr_bursty_random_test` seed sweep `1..8` closes with `UVM_ERROR : 0` and per-lane `unexplained=0` | `opq_drr_sva`, `opq_cross_drr_bursty_random_test`, `opq_cross_drr_bursty_frame2_boundary_test`, `opq_cross_drr_bursty_frame3_repro_test`, `DV_FORMAL.md`, `DV_PROBE.md` |
| Formal section separate from directed/random | Implemented in plan | `DV_FORMAL.md` |
| Realistic FEB-like driver contract derived from frontend frame format | Implemented at FEB-frame contract level, not yet the full `online_dpv2` IP chain | `DV_HARNESS.md`, packet builders in `opq_pkg.sv` |
| Full `online_dpv2` FEB datapath in the active harness | Open backlog | not yet wired into the current-tree harness |
| Full native-SV rewrite with same architecture and source-level SVA ownership | Implemented for the deliverable OPQ monolithic feature range; wider legacy mode matrix remains backlog | `rtl/sv_ver/ordered_priority_queue/monolithic_sv`, SVA bind modules, focused feature matrix |
| Non-default `N_SHD` sweep | Implemented / green at `64/256` plus default `128` | build-time config randomization + wrapper defines |
| `N_LANE=8/16` and 2x/4x/8x egress width | Implemented / green on focused RTL simulation closure | `/tmp/opq_dv_lane_width_20260424_rerun2/`, 72/72 pass |

### Current coverage snapshot

| Metric | Current live evidence | Status |
|--------|-----------------------|--------|
| Functional coverage | `run_cov_closure.sh` rerun on `2026-04-24`: baseline `25/25` pass, `N_SHD=64/128/256` supplemental sweep `3/3` each | Active baseline script is clean |
| Structural code coverage | `Total Coverage By Instance (filtered view): 54.89%` on the refreshed merged UCDB | Active baseline, not a raw structural closure claim |
| Directive coverage | assertion/directive report generated with `Errors: 0, Warnings: 0` | Active baseline |
| DRR directed closure | `opq_cross_drr_allowance_test` green | Closed for directed allowance path |
| DRR bursty closure | `opq_cross_drr_bursty_frame2_boundary_test` remains green, `opq_cross_drr_bursty_frame3_repro_test` reruns green with `expected=714 actual=714 missing=0 ghost=0`, and the refreshed `opq_cross_drr_bursty_random_test` seed sweep `1..8` is green on the current `2026-04-21` patchset with per-lane `unexplained=0` | No active failing boundary currently reproduced on the named deterministic or constrained-random screens |
| Default-build legal pre-drop boundary | `opq_cross_bp_predrop_boundary_test` is green on `2026-04-20`, with final `ft_drop_hdr/shd/hit=0/0/0`, aggregate `accepted=13260 dropped=66612 delivered=13260 unexplained=0`, and `core_principles first_break=clean` | Closed for the legal pre-drop half of the default-build overflow contract |
| Default-build legal early-overflow boundary | `opq_cross_random_ready_overflow_step2_boundary_test` is green on `2026-04-21`, with final `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=6/11/1176`, `rd_hdr/shd/hit=6/11/1176`, aggregate `accepted=1176 delivered=1176 unexplained=0`, and `core_principles first_break=clean` | Closed for the named early-window legal-overflow half of the default-build random-ready path |
| Default-build overflow closure | `opq_cross_random_ready_overflow_seconds_soak_test` rerun on `2026-04-20` is back to a shape-check green screen with final `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=29/68/5545`, `rd_hdr/shd/hit=29/68/5545`, aggregate `accepted=5545 delivered=5545 unexplained=0`, and `core_principles first_break=clean` | Closed for the legal-overflow shape-check side of the default-build path; not itself a must-drop witness |
| Forced overwrite closure | The refreshed `opq_cross_bp_mustdrop_witness_test` `12x16` profile on `2026-04-21` now re-establishes the named reduced-depth overwrite-local proof point: no-drop pre-phase `ft_drop_delta hdr/shd/hit=0/0/0`, pressure phase `ft_drop_delta hdr/shd/hit=10/80/2400`, final ledger `wr_hdr/shd/hit=13/224/3135`, `rd_hdr/shd/hit=3/144/735`, `drop_hdr/shd/hit=10/80/2400`, aggregate `accepted=735 delivered=735 unexplained=0`, and `core_principles first_break=clean` | Closed for the named reduced-depth overwrite-local must-drop path |

---

## 9. Formal Verification Plan

Formal verification is a distinct signoff activity from directed or
constrained-random simulation. The immediate formal scope should target the
clear module-boundary contracts before the full native-SV rewrite is complete.

### Candidate formal units

- ingress Avalon-ST acceptance / hold contract
- egress Avalon-ST hold-under-backpressure contract
- DRR arbiter:
  - onehot grant / lock ownership
  - only eligible lanes may win when unlocked
  - defer events imply a blocked raw request
  - page-allocator write preempts block-mover grant
- lane / ticket credit conservation
- frame-table overwrite accounting invariants
- drop-accounting observability:
  - a late-drop event must be traceable to a concrete dropped subheader / hit set
  - CSR totals alone are not sufficient for formal or promoted simulation signoff of per-hit integrity on late-drop paths
- accepted-count consistency:
  - if a subheader/hit is dropped after SOP, the eventual frame-table-visible packet counts must reflect accepted payload, not declared payload
  - packet completion must be derived from accepted/resident content, not only from early frame declaration
- presenter hold contract:
  - once `valid && !ready` is observed at egress, payload and sidebands must stay stable until acceptance
  - no future subheader may become visible before the pending hit count of the current subheader has drained

### Formal method

- current supported path: native-SV SVA modules compiled and elaborated through
  `formal_ingress.sh`, `formal_mover.sh`, and `formal_egress.sh`
- `2026-04-24` result: ingress, mover, and egress formal planes all compile
  and elaborate; proof execution is blocked by the absence of a runnable
  `qverify`/ZnFormal executable in `QUESTA_FORMAL_HOME`, `QUESTA_HOME`, or
  `PATH`

### Simulation vs formal split

- constrained-random is used to discover reachable high-pressure corner cases,
  especially asymmetric burst / backpressure interaction
- formal is used to prove the local timing/ownership invariants once the RTL
  hooks and assertions exist
- a testcase that repeatedly triggers an SVA in simulation should be kept in the
  plan even after the RTL fix, because it becomes the regression proof that the
  property is now reachable and held under stress

---

## 10. Remaining Planned Work

The following legacy expressions remain valid but are not yet closed in the
current tree:

- `MODE=MULTIPLEXING`
- `TRACK_HEADER=false`
- reset-in-state catalog from the archived error bucket
- deeper truncation / malformed packet matrix
- broader CSR / counter crosses
- monolithic accepted-count vs frame-table metadata consistency under bursty DRR drop
- merged structural code-coverage hole disposition after the latest testcase
  expansion
- full legacy bucket expansion across every `N_LANE` and egress-width pair

These are backlog items for closure, not current signoff claims.

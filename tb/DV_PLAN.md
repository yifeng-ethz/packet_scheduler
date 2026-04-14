# DV Plan: ordered_priority_queue (monolithic)

**DUT:** `packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`  
**Packaging:** `packet_scheduler/ordered_priority_queue_hw.tcl`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree plan for the monolithic VHDL DUT and the live `packet_scheduler/tb/uvm` harness.

---

## 1. Purpose

This document surfaces the still-valid verification intent from
`packet_scheduler/legacy/tb/DV_PLAN.md` into the current tree, then narrows it
to what the live harness can actually execute and close today.

The core contract remains the same:

- aggregate multiple ingress FEB lanes into one timestamp-ordered egress stream
- preserve hits end-to-end: no missing hits, no ghost-created hits
- place each hit under the correct subheader / time slot
- handle egress backpressure without duplication or reordering
- account for packet drops and overwrite drops in the visible CSR counters

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
- `N_SHD=256` is the active default, but the current signoff intent must also
  cover `N_SHD=128` and `N_SHD=512`.
- For `N_SHD > 256`, `TICKET_FIFO_DEPTH` must be larger than `N_SHD`; this is a
  packaging and harness contract now.
- The old split-tree scope is deprecated. Live DV is for the monolithic DUT.

### Deferred from the archived plan

- Full `MODE` matrix (`MERGING` plus `MULTIPLEXING`) is not yet closed on the
  live harness.
- Full `N_LANE` sweep is not yet closed on the live harness.
- Full width sweep (`PAGE_RAM_RD_WIDTH`, `CHANNEL_WIDTH`, non-default ingress
  widths) is not yet closed on the live harness.
- The very large legacy directed catalog remains a backlog, not a current-tree
  implementation claim.

---

## 3. Live Harness Scope

The live harness is documented in `packet_scheduler/tb/DV_HARNESS.md`. The
current implementation scope is intentionally narrower than the archived plan:

- DUT implementation under signoff is the monolithic VHDL core
- mixed-language UVM harness in `packet_scheduler/tb/uvm`
- active lane count in the current harness is `OPQ_N_LANE=2`
- build-time sweep knobs that already work today:
  - `OPQ_N_SHD = 128 / 256 / 512`
  - derived or explicit `OPQ_TICKET_FIFO_DEPTH`
  - reduced `OPQ_PAGE_RAM_DEPTH` for overflow forcing

The following compile / elaboration-time sweep is part of signoff intent and
must remain in the plan:

- randomize `N_SHD` across `128 / 256 / 512` at build time
- derive a safe `TICKET_FIFO_DEPTH` from `N_SHD`
- extend the same mechanism to other exposed generics once the harness supports
  them cleanly

---

## 4. Active Buckets

The active current-tree buckets are split into dedicated markdown files and the
matching script wrappers under `packet_scheduler/tb/scripts/`.

| Bucket | Markdown | Wrapper | Current promoted tests | Contract exercised |
|--------|----------|---------|------------------------|--------------------|
| `DV_BASIC` | `DV_BASIC.md` | `run_basic.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_basic_subheader_shape_test` | End-to-end hit preservation, full-ts boundary behavior, subheader shape, zero-drop healthy path |
| `DV_PARAM` | `DV_PARAM.md` | `run_param.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` across `N_SHD=128/256/512` | Compile / elaboration-time configuration sweep for the active harness |
| `DV_EDGE` | `DV_EDGE.md` | `run_edge.sh` | `opq_edge_backpressure_test`, `opq_edge_always_ready_test`, `opq_edge_ready_medium_profile_test`, `opq_edge_stuck_low_backpressure_test`, `opq_edge_max_hits_test`, `opq_edge_toggle_backpressure_test` | Backpressure restart, always-ready baseline, medium/stuck-low ready profiles, max-hit packet shape, short-toggle ready behavior |
| `DV_PROF` | `DV_PROF.md` | `run_perf.sh` | `opq_prof_stress_test`, `opq_prof_lane_skew_test` | Sustained traffic without drop, lane skew under the healthy contract |
| `DV_ERROR` | `DV_ERROR.md` | `run_error.sh` | `opq_error_lane_mask_test`, `opq_error_lane_mask_single_hit_test`, `opq_error_lane_mask_burst_test`, `opq_error_counter_clear_test` | Mask-at-boundary and CSR clear semantics across single-hit and burst packets on the current promoted path |
| `DV_CROSS` | `DV_CROSS.md` | `run_cross.sh` | `opq_cross_bp_credit_test`, `opq_cross_drr_allowance_test`, `opq_cross_drr_idle_lane_test`, `opq_cross_drr_zero_allowance_test`, `opq_cross_drr_short_allowance_test` | Backpressure × credit, block-level DRR allowance/defer accounting, empty-frame-cadence idle lane, zero/short allowance behavior |

Open reproducers stay outside the default bucket runners and are grouped under
`packet_scheduler/tb/scripts/run_probes.sh`, documented in `DV_PROBE.md`.

The merged signoff coverage closure remains separately controlled by
`run_cov_closure.sh`.

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
- `opq_prof_stress_test`
  - validates short soak behavior on the live harness
- `opq_prof_lane_skew_test`
  - validates sustained two-lane skew without data loss
- `opq_error_lane_mask_test`
  - validates packet-boundary lane mask control and per-lane drop counters
- `opq_error_lane_mask_single_hit_test`
  - validates masked-drop accounting on minimal packets
- `opq_error_lane_mask_burst_test`
  - validates masked-drop accounting across multi-hit bursts
- `opq_error_counter_clear_test`
  - validates counter-clear control behavior
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
- `opq_error_lane_mask_recovery_test`
  - implemented as a probe, not a promoted signoff test
  - currently exposes an open recovery bug: clearing `LANE_MASK` after a
    masked-drop phase does not restore clean traffic as expected
- `opq_error_ftable_overflow_test`
  - implemented as a probe, not a promoted signoff test
  - currently exposes an open overwrite/presenter bug: forced overwrite under
    always-stall backpressure still produces malformed accepted egress beats
- `opq_cross_drr_bursty_random_test`
  - constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls
  - intentionally not promoted yet
  - currently reproduces two live closure gaps:
    - a monolithic presenter stall-boundary corruption bug under periodic egress backpressure
    - insufficient late-drop observability for promoted hit-integrity closure when only final CSR totals are available
  - this testcase must remain unpromoted until both gaps are closed

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
| Active `N_SHD` sweep | `DV_PARAM` | `run_param.sh`, `cg_cfg`, wrapper defines | Implemented / green at `128/256/512` | Medium | Medium |
| Runtime CSR header + counters | `DV_ERROR`, `DV_CROSS` | CSR helpers + `opq_csr_sva` | Implemented / green on the promoted subset | Medium | Medium |
| Lane mask at packet boundary | `DV_ERROR` | CSR lane-mask helpers + counter checks | Implemented / green | Medium | Medium |
| DRR allowance programming | `DV_CROSS` | `opq_cross_drr_allowance_test`, DRR CSR reads | Implemented / green | Medium | Medium |
| DRR defer / lock contract | `DV_CROSS`, formal backlog | `opq_drr_sva`, DRR covergroup bins, DRR CSR counters | Implemented / green on directed allowance case | Medium | Medium |
| Bursty hot-lane DRR stress | `DV_CROSS`, formal backlog | `opq_cross_drr_bursty_random_test` | Implemented / open: exact late-drop identity is still not observable enough for promoted hit-integrity closure | High | High |
| Backpressure hold / restart | `DV_EDGE`, `DV_CROSS`, `DV_ERROR` probe path | `opq_avst_egress_sva`, `opq_hit3_contract_sva`, presenter logic | Implemented / open: bursty DRR and forced-overwrite probes still expose presenter/egress bugs | High | High |

---

## 8. Earlier Request Trace

The earlier project requests are tracked explicitly here so the current tree
states which items are really closed and which are still backlog.

| Earlier requested item | Current state | Evidence |
|------------------------|---------------|----------|
| Full-ts hit tracking with no ambiguity after long lane stalls | Implemented / green on promoted path | scoreboard absolute `ts[47:0]`, `opq_hit3_contract_sva`, `DV_BASIC`, `DV_PARAM` |
| UVM-only `HIT_ID` for missing/ghost-hit tracking | Implemented / green | scoreboard contract in `DV_HARNESS.md`, promoted integrity tests |
| `N_SHD=256` default plus `128/256/512` signoff sweep | Implemented / green | `DV_PARAM.md`, `run_param.sh`, `cg_cfg` |
| DRR per-lane allowance through CSR plus monitors/counters | Implemented / green on directed path | `DV_CROSS.md`, `opq_cross_drr_allowance_test`, DRR CSR checks |
| DRR SVA and constrained-random stress | Partial: directed SVA closure is green, bursty constrained-random remains probe-only | `opq_drr_sva`, `opq_cross_drr_bursty_random_test`, `DV_FORMAL.md`, `DV_PROBE.md` |
| Formal section separate from directed/random | Implemented in plan | `DV_FORMAL.md` |
| Realistic FEB-like driver contract derived from frontend frame format | Implemented at FEB-frame contract level, not yet the full `online_dpv2` IP chain | `DV_HARNESS.md`, packet builders in `opq_pkg.sv` |
| Full `online_dpv2` FEB datapath in the active harness | Open backlog | not yet wired into the current-tree harness |
| Full native-SV rewrite with same architecture and source-level SVA ownership | Partial / open | `rtl/ordered_priority_queue/monolithic_sv`, not yet full signoff replacement |
| Non-default `N_SHD` sweep | `DV_BASIC` signoff sweep | build-time config randomization + wrapper defines | Implemented / green at `128/256/512` on the basic trilogy | Medium | Medium |

### Current coverage snapshot

| Metric | Current live evidence | Status |
|--------|-----------------------|--------|
| Functional coverage | `80.42%` merged covergroup coverage on the promoted suite plus active `N_SHD` sweep | Active baseline |
| Structural code coverage | `68.40%` filtered total on the current merged UCDB flow | Active baseline, not closed |
| Directive coverage | `100.00%` on the current merged UCDB flow | Active baseline |
| DRR directed closure | `opq_cross_drr_allowance_test` green | Closed for directed allowance path |
| DRR bursty closure | `opq_cross_drr_bursty_random_test` still reproduces SVA / integrity failures | Open |
| Forced overwrite closure | `opq_error_ftable_overflow_test` still reproduces malformed accepted egress | Open |

---

## 8. Formal Verification Plan

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

- short term: mixed-language bind SVA onto the current monolithic VHDL DUT
- medium term: move the highest-value invariants into the native SV rewrite so
  block-level proofs can run without mixed-language limitations

### Simulation vs formal split

- constrained-random is used to discover reachable high-pressure corner cases,
  especially asymmetric burst / backpressure interaction
- formal is used to prove the local timing/ownership invariants once the RTL
  hooks and assertions exist
- a testcase that repeatedly triggers an SVA in simulation should be kept in the
  plan even after the RTL fix, because it becomes the regression proof that the
  property is now reachable and held under stress

---

## 9. Remaining Planned Work

The following legacy expressions remain valid but are not yet closed in the
current tree:

- `MODE=MULTIPLEXING`
- `TRACK_HEADER=false`
- live `N_LANE` sweep beyond the current 2-lane harness
- wide egress packing (`PAGE_RAM_RD_WIDTH > 36`)
- reset-in-state catalog from the archived error bucket
- deeper truncation / malformed packet matrix
- broader CSR / counter crosses
- monolithic accepted-count vs frame-table metadata consistency under bursty DRR drop
- merged structural code-coverage hole disposition after the latest testcase
  expansion

These are backlog items for closure, not current signoff claims.

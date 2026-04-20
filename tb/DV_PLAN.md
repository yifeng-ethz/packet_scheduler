# DV Plan: ordered_priority_queue (monolithic)

**DUT:** `packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv`  
**Packaging:** `packet_scheduler/script/ordered_priority_queue_hw.tcl`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
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

- DUT implementation under signoff is the native monolithic SystemVerilog core
- mixed-language UVM harness in `packet_scheduler/tb/uvm`
- active lane count in the current harness is `OPQ_N_LANE=2`
- 4-lane native-SV execution exists for debug/integration work, but it remains
  explicitly out of signoff scope until dedicated 4-lane DV evidence is
  promoted; the old sparse-frame cadence bug family is green in focused reruns
  and no longer drives the non-claim by itself
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
| `DV_BASIC` | `DV_BASIC.md` | `run_basic.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_basic_subheader_shape_test`, `opq_basic_feb_packet_contract_test`, `opq_basic_single_active_lane_test`, `opq_basic_single_active_lane_lane1_test`, `opq_basic_single_active_lane_dense_test` | End-to-end hit preservation, full-ts boundary behavior, subheader shape, native FEB whole-frame contract, and single-active-lane healthy-path closure |
| `DV_PARAM` | `DV_PARAM.md` | `run_param.sh` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` across `N_SHD=128/256/512` | Compile / elaboration-time configuration sweep for the active harness |
| `DV_EDGE` | `DV_EDGE.md` | `run_edge.sh` | `opq_edge_backpressure_test`, `opq_edge_always_ready_test`, `opq_edge_ready_medium_profile_test`, `opq_edge_stuck_low_backpressure_test`, `opq_edge_max_hits_test`, `opq_edge_toggle_backpressure_test`, `opq_edge_burst_restart_profile_test`, `opq_edge_long_toggle_backpressure_test`, `opq_edge_max_hits_backpressure_test` | Backpressure restart, always-ready baseline, medium/stuck-low ready profiles, max-hit packet shape, short/long-toggle ready behavior, and max-hit under healthy restart |
| `DV_PROF` | `DV_PROF.md` | `run_perf.sh` | `opq_prof_stress_test`, `opq_prof_lane_skew_test`, `opq_prof_whole_frame_skew_test`, `opq_prof_missing_empty_frame_test`, `opq_prof_long_soak_test`, `opq_prof_heavy_lane_skew_test`, `opq_prof_deep_whole_frame_skew_test`, `opq_prof_asymmetric_missing_empty_frame_test` | Sustained traffic without drop, lane skew, deeper whole-frame cadence skew, asymmetric missing-empty-frame residency, and longer healthy soaks on the active 2-lane contract |
| `DV_ERROR` | `DV_ERROR.md` | `run_error.sh` | `opq_error_lane_mask_test`, `opq_error_lane_mask_single_hit_test`, `opq_error_lane_mask_burst_test`, `opq_error_lane_mask_recovery_test`, `opq_error_subheader_mask_recovery_test`, `opq_error_counter_clear_test`, `opq_error_ftable_overflow_test` | Mask-at-boundary recovery, CSR clear semantics, and reduced-depth overflow/drop accounting on the promoted native-SV path |
| `DV_CROSS` | `DV_CROSS.md` | `run_cross.sh` | `opq_cross_bp_credit_test`, `opq_cross_drr_allowance_test`, `opq_cross_drr_idle_lane_test`, `opq_cross_drr_zero_allowance_test`, `opq_cross_drr_short_allowance_test`, `opq_cross_idle_lane_backpressure_test`, `opq_cross_mixed_bucket_random_soak_test` | Backpressure × credit, block-level DRR allowance/defer accounting, idle-lane backpressure, and promoted mixed-bucket random soak evidence |

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

Promoted into the live wrappers, generated report flow, and default-build
continuous-frame baselines on `2026-04-20`:

- `DV_BASIC`: `opq_basic_single_active_lane_test`,
  `opq_basic_single_active_lane_lane1_test`,
  `opq_basic_single_active_lane_dense_test`
- `DV_EDGE`: `opq_edge_burst_restart_profile_test`,
  `opq_edge_long_toggle_backpressure_test`,
  `opq_edge_max_hits_backpressure_test`
- `DV_PROF`: `opq_prof_long_soak_test`, `opq_prof_heavy_lane_skew_test`,
  `opq_prof_deep_whole_frame_skew_test`,
  `opq_prof_asymmetric_missing_empty_frame_test`

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
  - promoted signoff testcase
  - validates clean recovery after the active-lane mask is cleared
- `opq_error_subheader_mask_recovery_test`
  - promoted signoff testcase
  - validates that a malformed subheader is masked without poisoning the next
    legal FEB packet
- `opq_error_header_mask_recovery_test`
  - implemented as isolated native-SV recovery evidence, not yet a promoted
    signoff test
  - now passes after the ingress header timestamp-base repair; remaining work
    is report hygiene and ERROR-bucket reinsertion
- `opq_error_header_word_mask_recovery_test`
  - implemented as isolated native-SV recovery evidence, not yet a promoted
    signoff test
  - now passes after the same header timestamp-base repair; it remains outside
    the generated signoff set until the ERROR-bucket baseline is refreshed
- `opq_error_ftable_overflow_test`
  - promoted isolated-only native-SV evidence at reduced depth
  - now passes with non-zero `FT_DROP_*` accounting and clean accepted egress,
    but it remains outside the fixed default-build no-restart baseline because
    it requires a separate `OPQ_PAGE_RAM_DEPTH=512` elaboration point
- `opq_cross_drr_bursty_random_test`
  - constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls
  - intentionally kept probe-only until a refreshed large-random rerun is
    captured on the repaired RTL
  - the focused native-SV reproducer is now fixed and closes with
    `unexplained=0`; remaining work is promotion hygiene, not a known live DUT
    corruption on the directed failing window

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
| Bursty hot-lane DRR stress | `DV_CROSS`, formal backlog | `opq_cross_drr_bursty_random_test` | Focused repro fixed; full constrained-random refresh still pending before promotion | High | High |
| Backpressure hold / restart | `DV_EDGE`, `DV_CROSS`, `DV_ERROR` probe path | `opq_avst_egress_sva`, `opq_hit3_contract_sva`, presenter logic | Implemented / green on the promoted default-build matrix; reduced-depth overflow is green in isolated evidence and the remaining DRR work is the larger random refresh | High | High |

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
| DRR SVA and constrained-random stress | Partial: directed SVA closure is green, focused bursty repro is fixed, and the larger constrained-random screen remains probe-only pending a refreshed rerun | `opq_drr_sva`, `opq_cross_drr_bursty_random_test`, `DV_FORMAL.md`, `DV_PROBE.md` |
| Formal section separate from directed/random | Implemented in plan | `DV_FORMAL.md` |
| Realistic FEB-like driver contract derived from frontend frame format | Implemented at FEB-frame contract level, not yet the full `online_dpv2` IP chain | `DV_HARNESS.md`, packet builders in `opq_pkg.sv` |
| Full `online_dpv2` FEB datapath in the active harness | Open backlog | not yet wired into the current-tree harness |
| Full native-SV rewrite with same architecture and source-level SVA ownership | Partial / open | `rtl/sv_ver/ordered_priority_queue/monolithic_sv`, not yet full signoff replacement |
| Non-default `N_SHD` sweep | `DV_BASIC` signoff sweep | build-time config randomization + wrapper defines | Implemented / green at `128/256/512` on the basic trilogy | Medium | Medium |

### Current coverage snapshot

| Metric | Current live evidence | Status |
|--------|-----------------------|--------|
| Functional coverage | `90.71%` promoted functional closure (`44/44` promoted cases evidenced); per-bucket merged covergroup totals are rendered in `DV_COV.md` | Active promoted baseline |
| Structural code coverage | `stmt=76.86`, `branch=68.01`, `fsm_state=86.36`, `fsm_trans=44.00`, `toggle=42.57` on the current merged UCDB flow | Active baseline, not closed |
| Directive coverage | `100.00%` on the current merged UCDB flow | Active baseline |
| DRR directed closure | `opq_cross_drr_allowance_test` green | Closed for directed allowance path |
| DRR bursty closure | Focused `opq_cross_drr_bursty_repro_test` is green with closed late-drop ledgers; the larger `opq_cross_drr_bursty_random_test` still needs a refreshed rerun before promotion | Probe-only pending refresh |
| Forced overwrite closure | `opq_error_ftable_overflow_test` passes as isolated reduced-depth native-SV evidence with non-zero `FT_DROP_*` accounting | Closed for the isolated reduced-depth point |

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

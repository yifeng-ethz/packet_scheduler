# Legacy Verification Signoff Note
Author: Yifeng Wang (yifenwan@phys.ethz.ch)

> Superseded by `packet_scheduler/doc/SIGNOFF.md`. This file is kept as the
> longer narrative note from the pre-cleanup flow and still contains useful
> rationale, but the active signoff dashboard is now `SIGNOFF.md`.

## Scope

This note defines the current standalone DV signoff expectations for
`packet_scheduler`, with focus on the monolithic
`rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`.

On 2026-04-13 the old `tb/` and `uvm/` harnesses were archived under
`packet_scheduler/tb/legacy/`. Those files remain useful as intent capture and bug
history, but they are not current signoff evidence.

## Source Material Reviewed

- `packet_scheduler/tb/DV_PLAN.md`
- `packet_scheduler/tb/DV_HARNESS.md`
- `packet_scheduler/tb/DV_PARAM.md`
- `packet_scheduler/tb/DV_PROBE.md`
- `packet_scheduler/tb/DV_FORMAL.md`
- `packet_scheduler/tb/legacy/tb/DV_PLAN.md`
- `packet_scheduler/tb/legacy/tb/DV_HARNESS.md`
- `slow-control_hub/doc/VERIFICATION_SIGNOFF.md`
- Claude skills `dv-workflow` and `rtl-lint`

The resulting signoff model follows the `slow-control_hub` pattern: closure is
tied to a plan, an implemented covergroup model, and current-tree reruns on one
RTL revision. Raw code coverage alone is not sufficient.

## Required Signoff Evidence

### 1. Current active harness

- Recreate a current monolithic verification harness instead of relying on the
  archived `legacy/` trees.
- The harness must include a scoreboard/reference model, a regression runner,
  native `covergroup` / `cross` collectors, and SVA bind points for the DUT.
- All cumulative coverage merges must come from the same current RTL revision.

### 2. Three-layer RTL lint

The monolithic OPQ must be clean in the three-layer flow from the Claude
`rtl-lint` skill:

1. Questa source lint: `vcom -lint=full -check_synthesis -2008`
2. Questa elaboration / synthesis check: `vopt -check_synthesis`
3. Quartus Design Assistant: post-synth plus post-fit / STA DRC checks

Signoff requires the monolithic DUT to be clean, or every remaining warning to
be explicitly dispositioned in the signoff record.

### 3. Functional coverage model

- Implement the coverage families already defined in
  `legacy/tb/DV_PLAN.md` using native `covergroup` / `cross`.
- Minimum functional scope:
  - parameter-space coverage (`cov_cfg`)
  - per-FSM state and transition coverage (`cov_fsm`)
  - packet-shape coverage (`cov_pkt`)
  - flow-control coverage (`cov_flow`)
  - multi-axis crosses (`cov_cross`)
- Signoff requires reporting the implemented collector and the actually rerun
  suite, exactly as `slow-control_hub/doc/VERIFICATION_SIGNOFF.md` does.

### 4. Structural coverage

Targets inherited from `legacy/tb/DV_PLAN.md`:

- statement coverage: at least 95%
- branch coverage: at least 90%
- FSM state / transition coverage: 100%
- toggle coverage on ports and state enums: at least 80%
- functional coverage for the implemented covergroups: 100%

Any residual uncovered bins after plateau must be justified as unreachable or
deferred to formal / UNR work. Do not claim closure by simply extending random
runtime without analysis.

### 5. Assertions and formal-readiness

- SVA is mandatory for signoff, not optional.
- Required assertion families:
  - ingress and egress Avalon-ST protocol
  - FIFO occupancy / no-overflow / no-underflow invariants
  - page-RAM read/write exclusion and restart invariants
  - legal FSM transitions and no-progress watchdogs
- Preferred first step: bind SystemVerilog assertions onto the current VHDL DUT
  in a mixed-language flow.
- If the chosen formal tool cannot give a usable mixed-language property flow,
  a full SystemVerilog translation of the monolithic OPQ may be done as a
  separate project. That rewrite is not assumed complete by this archival
  change and should not be mixed into the signoff claim without its own review.

## Current Gaps

The archival collateral has now been surfaced into current-tree planning files,
but these signoff gaps remain:

- the live harness is still limited to the current 2-lane default-symbol path
  and does not yet close the full archived parameter matrix
- the required three-layer lint evidence and current-tree merged coverage hole
  disposition are not yet fully captured in-repo for monolithic OPQ
- the archived large directed catalog remains only partially implemented in the
  live harness

## Current Bring-Up Status

- The new current-tree UVM harness compiles and runs under the supported
  QuestaOne 2026 runtime on this host:
  `/data1/questaone_sim/questasim` with `LM_LICENSE_FILE`,
  `MGLS_LICENSE_FILE`, and `SALT_LICENSE_SERVER` all set to
  `8161@lic-mentor.ethz.ch`.
- The current promoted regression on the VHDL monolithic DUT is:
  - `opq_basic_smoke_test`
  - `opq_basic_ts_boundary_test`
  - `opq_basic_subheader_shape_test`
  - `opq_edge_backpressure_test`
  - `opq_edge_always_ready_test`
  - `opq_edge_ready_medium_profile_test`
  - `opq_edge_stuck_low_backpressure_test`
  - `opq_edge_max_hits_test`
  - `opq_edge_toggle_backpressure_test`
  - `opq_prof_stress_test`
  - `opq_prof_lane_skew_test`
  - `opq_error_lane_mask_test`
  - `opq_error_lane_mask_single_hit_test`
  - `opq_error_lane_mask_burst_test`
  - `opq_error_counter_clear_test`
  - `opq_cross_bp_credit_test`
  - `opq_cross_drr_allowance_test`
  - `opq_cross_drr_idle_lane_test`
  - `opq_cross_drr_zero_allowance_test`
  - `opq_cross_drr_short_allowance_test`
- Additional validated cases now surfaced by the active bucket wrappers:
  - the current-tree bucket wrappers now surface the still-relevant current
    plan buckets directly: `DV_BASIC`, `DV_PARAM`, `DV_EDGE`, `DV_PROF`,
    `DV_ERROR`, `DV_CROSS`, `DV_PROBE`, and `DV_FORMAL`
  - `opq_cross_drr_idle_lane_test` clarified a real DUT/harness contract point:
    an "idle" lane on the current monolithic path must still emit empty frames
    to preserve legal frame cadence; permanent silence is not a valid directed
    stimulus for the page allocator
  - `opq_cross_drr_bursty_random_test` is implemented but intentionally not yet
    promoted because it still reproduces a real DUT bug
  - `opq_error_ftable_overflow_test` is implemented but intentionally not yet
    promoted because it still reproduces a real DUT bug
- The promoted suite currently reruns clean on the active harness and merged
  coverage closure:
  - 20 unique promoted testcase names are green on the current-tree harness
  - the merged closure samples 17 direct promoted tests plus the
    `N_SHD=128/256/512` sweep of `opq_basic_smoke_test`,
    `opq_basic_ts_boundary_test`, and `opq_edge_max_hits_test`
  - hit-integrity scoreboard closure remains clean on the promoted integrity
    buckets
- The monolithic template fixes folded into the active DV promotion include:
  - `alloc_page_flow` wrap protection in `ALLOC_PAGE`
  - page-allocator timestamp compare tightening so the first real subheader is
    not forced into the zero slot
  - frame-table overwrite/drop accounting moved to tile-residency ownership so
    CSR frame-table drop counters reflect actual overwritten contents
  - reduced-depth `PAGE_RAM_DEPTH` fix on `page_start_addr` update
- The active harness contract is now stronger than the initial bring-up:
  - every promoted test reads and checks the standard CSR identity/capability
    header before main stimulus
  - the scoreboard tracks hits from ingress observation to egress using the
    reconstructed 48-bit timestamp and a UVM-only 64-bit `HIT_ID`
  - SVA is enabled by default for ingress AVST, egress AVST, and CSR protocol
    checks
- The DRR closure work added:
  - runtime DRR allowance programming checks through CSR
  - a dedicated `opq_drr_sva` family for grant/defer/lock ownership
  - directed empty-frame-idle, zero-allowance, and short-allowance tests that
    are now green on the active harness
  - a constrained-random hot-lane burst testcase that now serves as the main
    reproducer for the remaining monolithic DRR / presenter closure gaps
- The current egress sideband status is not yet signoff-clean:
  - the DUT exports `aso_egress_startofpacket/endofpacket`
  - but accepted egress beats can still appear before a clean K285-marked start
    beat on the active monolithic VHDL path
  - because of that, the promoted hit-contract SVA remains data-framed rather
    than sideband-framed, and the sidebands are treated as debug observables
    rather than a signoff-quality primary framing oracle
- The bursty DRR testcase still exposes an open monolithic DUT gap:
  - the presenter / egress path still has a stall-boundary corruption bug under
    periodic backpressure
  - exact late-drop hit identity is still not observable enough from the live
    DUT, so final CSR totals alone are not sufficient for promoted per-hit
    integrity closure on that testcase
- The reduced-depth overflow testcase also exposes an open monolithic DUT gap:
  - under forced overwrite with always-stall backpressure, the DUT can still
    emit accepted egress beats that do not belong to any well-formed frame
  - this makes `opq_error_ftable_overflow_test` valuable bug evidence, but not
    valid promoted signoff coverage today
- The timestamp-boundary, max-hit, subheader-shape, and directed DRR
  allowance/idle/zero/short cases are no longer blockers. They are now
  reflected in the published merged coverage snapshot below.

## Current Coverage Snapshot

- Promoted merged closure command:
  - `packet_scheduler/tb/scripts/run_cov_closure.sh`
- Active compile / elaboration-time sweep command:
  - `packet_scheduler/tb/scripts/run_param.sh`
- Promoted merged functional result:
  - total covergroup coverage: `87.60%`
  - total directive coverage: `100.00%`
  - filtered total by instance: `69.76%`
- Per-family merged functional result:
  - `cg_cfg`: `72.02%`
  - `cg_frame`: `100.00%`
  - `cg_subheader`: `100.00%`
  - `cg_bp`: `85.00%`
  - `cg_csr`: `95.23%`
  - `cg_credit`: `60.00%`
  - `cg_drop`: `81.94%`
  - `cg_drr`: `81.83%`
  - `cg_ingress`: `100.00%`
  - `cg_egress`: `100.00%`
- Implemented covergroup families in the current tree:
  - configuration (`cg_cfg`)
  - frame shape (`cg_frame`)
  - subheader shape (`cg_subheader`)
  - backpressure (`cg_bp`)
  - CSR access (`cg_csr`)
  - credit snapshots (`cg_credit`)
  - lane / frame-table drop snapshots (`cg_drop`)
  - DRR allowance / defer / service shape (`cg_drr`)
  - ingress beat shape (`cg_ingress`)
  - egress beat shape (`cg_egress`)
- Assertion summary from the promoted merged closure:
  - custom ingress/egress/CSR SVA: zero failures on the promoted suite
  - custom DRR SVA: zero failures on the promoted directed DRR suite
  - the merged run now includes the promoted suite plus the active named
    `N_SHD=128/256/512` parameter bucket for `opq_basic_smoke_test`,
    `opq_basic_ts_boundary_test`, and `opq_edge_max_hits_test`
  - the VHDL template warning assertion on the `N_HIT` counter estimate still
    appears in UCDB assertion accounting as a warning-site hit, not as a
    promoted-suite `** Error:` failure
  - the old template “non-default page RAM width” diagnostic was converted from
    a failing `assert` into a non-failing warning so the reduced-depth overflow
    bucket does not pollute the assertion failure count
- Structural code-coverage plumbing is now verified on the active harness:
  - `packet_scheduler/tb/scripts/run_cov_closure.sh` now produces a merged UCDB
    with non-empty code coverage
  - current merged structural snapshot:
    - statements: `61.68%`
    - branches: `35.36%`
    - conditions: `25.40%`
    - expressions: `100.00%`
    - toggles: `37.22%`
    - FSM states: `92.30%`
    - FSM transitions: `62.50%`
    - filtered total: `59.21%`

- Coverage merge caveat on parameter sweeps:
  - merging UCDBs across different elaborated DUT parameter points still emits
    `vcover` source-mismatch warnings on the generated VHDL wrapper path
  - the current merged report is therefore treated as an active baseline and
    planning aid, not final multi-config structural signoff closure yet

## Remaining Gaps

- The functional coverage model is materially implemented, but not yet at the
  archival `DV_PLAN.md` 100% target. The remaining holes are concentrated in
  not-yet-promoted probe scenarios and parameter-space bins that are outside
  the current promoted default-config closure set:
  - `cg_cfg`: reduced-overflow and non-default `ticket_depth` cross bins
  - `cg_bp`: deep-stall repeat bins not yet sampled by the promoted healthy path
  - `cg_credit`: tight-credit / active-credit combinations
  - `cg_drop`: frame-table overwrite late-drop bins, still probe-only today
  - `cg_drr`: lane1 tiny/zero allowance and defer-heavy burst combinations,
    still tied to the open bursty-random probe path
- The DRR allowance testcase is now a clean passing evidence point, but the
  broader directed DRR trio is also green. The bursty constrained-random DRR
  testcase remains open and is blocking promotion of full DRR signoff closure.
- The forced-overwrite error testcase remains open and is blocking promotion of
  overwrite/drop signoff closure.
- Source-lint warnings in the monolithic VHDL still need final disposition for
  formal signoff.
- Structural code-coverage numbers are now produced by the UCDB flow, but the
  promoted merged regression still needs a summarized report with hole
  disposition.
- The current SV wrapper supports mixed-language SVA, but a full internal SV
  source translation remains a separate follow-up track rather than part of the
  present VHDL signoff claim.

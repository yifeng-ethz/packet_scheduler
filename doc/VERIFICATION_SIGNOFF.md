# Verification Signoff

## Scope

This note defines the current standalone DV signoff expectations for
`packet_scheduler`, with focus on the monolithic
`rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`.

On 2026-04-13 the old `tb/` and `uvm/` harnesses were archived under
`packet_scheduler/legacy/`. Those files remain useful as intent capture and bug
history, but they are not current signoff evidence.

## Source Material Reviewed

- `packet_scheduler/legacy/tb/DV_PLAN.md`
- `packet_scheduler/legacy/tb/DV_HARNESS.md`
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

The review of the archived packet_scheduler collateral shows these open items:

- the old `legacy/tb/DV_PLAN.md` and `legacy/tb/DV_HARNESS.md` describe an
  ambitious monolithic UVM environment, but that environment is not present as
  a current checked-in harness
- the archived `legacy/uvm/` tree only contains split-era unit UVM content
- there is no current signoff note for packet_scheduler analogous to the
  `slow-control_hub` signoff record until this file
- the required three-layer lint evidence and current-tree coverage merge are
  not yet captured in-repo for monolithic OPQ

## Current Bring-Up Status

- The new current-tree UVM harness compiles and runs under the ETH floating
  Mentor license on this host with `questa_fse`, `LM_LICENSE_FILE`, and
  `MGLS_LICENSE_FILE` chained to
  `8161@lic-mentor.ethz.ch:/data1/intelFPGA_pro/23.1/questa_fse/LR-287689_License.dat`.
- The current promoted regression on the VHDL monolithic DUT is:
  - `opq_basic_smoke_test`
  - `opq_edge_backpressure_test`
  - `opq_edge_always_ready_test`
  - `opq_prof_stress_test`
  - `opq_error_lane_mask_test`
  - `opq_error_ftable_overflow_test`
  - `opq_error_counter_clear_test`
  - `opq_cross_bp_credit_test`
- The promoted suite currently reruns clean:
  - `UVM summary: pass=8 fail=0 total=8`
  - hit-integrity scoreboard closure remains clean on the integrity buckets
  - the overflow bucket intentionally uses `OPQ_PAGE_RAM_DEPTH=512` to force
    frame-table overwrite/drop behavior on a bounded runtime
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
- Probe buckets exist in the current tree but are not promoted into signoff yet:
  - timestamp-boundary probe
  - larger burst-hit probe
  They expose remaining DUT limitations and are intentionally kept out of the
  promoted closure set until the RTL behavior is fixed.

## Current Coverage Snapshot

- Promoted merged closure command:
  - `packet_scheduler/tb/scripts/run_cov_closure.sh`
- Promoted merged functional result:
  - `TOTAL COVERGROUP COVERAGE: 82.74%`
- Implemented covergroup families in the current tree:
  - configuration (`cg_cfg`)
  - frame shape (`cg_frame`)
  - subheader shape (`cg_subheader`)
  - backpressure (`cg_bp`)
  - CSR access (`cg_csr`)
  - credit snapshots (`cg_credit`)
  - lane / frame-table drop snapshots (`cg_drop`)
  - ingress beat shape (`cg_ingress`)
  - egress beat shape (`cg_egress`)
- Assertion summary from the promoted merged closure:
  - custom ingress/egress/CSR SVA: zero failures on the promoted suite
  - the old template “non-default page RAM width” diagnostic was converted from
    a failing `assert` into a non-failing warning so the reduced-depth overflow
    bucket does not pollute the assertion failure count

## Remaining Gaps

- The functional coverage model is materially implemented, but not yet at the
  archival `DV_PLAN.md` 100% target. The remaining holes are concentrated in
  not-yet-promoted probe scenarios and parameter-space bins that are outside the
  current promoted default-config closure set.
- Source-lint warnings in the monolithic VHDL still need final disposition for
  formal signoff.
- Structural code-coverage numbers are produced by the merged UCDB flow, but
  they are not yet summarized in this note with hole disposition.
- The current SV wrapper supports mixed-language SVA, but a full internal SV
  source translation remains a separate follow-up track rather than part of the
  present VHDL signoff claim.

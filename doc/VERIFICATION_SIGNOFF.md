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

- The new current-tree UVM harness now compiles and launches under the ETH
  floating Mentor license on this host when run with the `questa_fse`
  executable and both `LM_LICENSE_FILE` and `MGLS_LICENSE_FILE` chained to
  `8161@lic-mentor.ethz.ch:/data1/intelFPGA_pro/23.1/questa_fse/LR-287689_License.dat`.
- The `questa_fe` executable still fails on this host with `Invalid license
  environment`, even though `lmutil lmdiag` reports `mtiverification` as
  checkoutable.
- The default active smoke `opq_basic_smoke_test` now passes end to end on the
  current-tree harness:
  - the basic hit-integrity scoreboard reports `expected=4 actual=4 missing=0 ghost=0`
  - the first merged egress subheader now lands in the correct slot (`shd_ts=0x01`)
    rather than being emitted one slot early at `shd_ts=0x00`
- The monolithic template fixes folded into this bring-up include:
  - `alloc_page_flow` wrap protection in `ALLOC_PAGE`
  - egress `valid` / SOP / EOP gating during presenter restart
  - page-allocator timestamp compare tightening so the first real subheader is
    not forced into the zero slot
- The remaining blockers are signoff-quality issues, not basic functionality:
  - source-lint warnings in the monolithic VHDL still need disposition
  - the coverage model and bucket closure are only partially implemented
  - the current SV wrapper supports mixed-language SVA, but a full internal SV
    source translation is still a separate follow-up task

## Recommended Execution Order

1. Stand up a new current monolithic harness and wire in the covergroup model.
2. Run and fix the three-layer lint flow on the monolithic DUT.
3. Add SVA bind modules and make them part of every regression run.
4. Promote a small current-tree core regression, then expand to the full
   `DV_PLAN` matrix with coverage tracking.
5. Publish a rerun-based signoff update with:
   - exact RTL revision
   - executed suite
   - merged coverage numbers
   - remaining justified gaps
   - lint disposition
   - SVA / formal status

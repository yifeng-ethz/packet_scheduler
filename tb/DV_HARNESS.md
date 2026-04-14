# DV Harness: ordered_priority_queue (monolithic)

**Harness root:** `packet_scheduler/tb/uvm`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree harness description.

---

## 1. Topology

The current harness is a mixed-language UVM environment around the monolithic
VHDL DUT.

- `tb_top.sv`
  - clock / reset generation
  - DUT instantiation
  - interface hookup
  - SVA instantiation
  - config-DB publication of the DUT config object
- `opq_env.sv`
  - one active ingress agent per live lane
  - one active egress agent
  - scoreboard
  - coverage collector
  - virtual sequencer
- `opq_base_test.sv`
  - CSR helper tasks
  - counter checks
  - credit checks
  - scoreboard post-run checks

---

## 2. Current Supported Build Knobs

The harness today supports these build-time sweeps cleanly:

- `OPQ_N_SHD`
  - `128`
  - `256` (default)
  - `512`
- `OPQ_TICKET_FIFO_DEPTH`
  - explicit override
  - derived automatically from `OPQ_N_SHD` when needed
- `OPQ_PAGE_RAM_DEPTH`
  - default healthy depth
  - reduced depth for overflow / overwrite forcing

Current harness limits:

- `OPQ_N_LANE` is fixed to `2` in the checked-in live harness
- the current `tb_top.sv` wiring is not yet a general `N_LANE` generator
- width sweeps beyond the default 36-bit symbol path are not yet wired into the
  live harness contract

---

## 3. Contract Model

### Ingress contract

- Each ingress agent drives the real FEB-like frame structure used by the live
  tests:
  - frame header words
  - fixed-time subheaders
  - hit words
- The packet builders in `opq_pkg.sv` are the source of truth for this harness
  contract.
- A lane may be idle in hits, but not fully silent in frame cadence on the
  current monolithic DUT contract. The page allocator still expects per-lane
  frame progression, so single-active-lane tests drive empty frames on the
  inactive peer lane instead of leaving it permanently silent.

### Egress / scoreboard contract

- The scoreboard observes hits at ingress and egress.
- Each hit is tracked by:
  - reconstructed absolute timestamp
  - lane identity
  - UVM-only `HIT_ID`
- The scoreboard checks:
  - no missing hits
  - no ghost hits
  - hit lands in the correct subheader / time slot

### CSR contract

- Every promoted test can access the CSR aperture through `opq_csr_if`.
- The harness checks:
  - common UID + META header
  - lane-mask control
  - counter clear
  - per-lane counters
  - frame-table counters

---

## 4. Assertions

The active SVA families are:

- `opq_avst_ingress_sva.sv`
  - ingress Avalon-ST protocol checks
- `opq_avst_egress_sva.sv`
  - egress Avalon-ST protocol checks
- `opq_csr_sva.sv`
  - CSR protocol checks
- `opq_hit3_contract_sva.sv`
  - absolute timestamp / subheader hit-count contract on egress
- `opq_drr_sva.sv`
  - block-level DRR grant / defer / lock contract

The DRR property set now also carries cover intent for the constrained-random
bursty testcase:

- blocked eligible-late requests must create `defer_event`
- a deferred lane must later become grantable after allowance reload
- page-allocator page writes must suppress block-mover grants cleanly

Planned extension points:

- credit / free-space invariants at the lane and ticket boundaries
- overwrite-accounting invariants between frame-table ownership and drop
  counters
- packet-complete gating invariants between frame-table visibility, delayed
  DRR block writes, and accepted-count correction after late drop

The current hit-contract checker intentionally remains data-framed rather than
sideband-framed:

- the live DUT does export `aso_egress_startofpacket/endofpacket`
- but accepted egress beats can still appear before a clean K285-marked start
  beat on the active monolithic VHDL path
- that makes the sidebands useful debug signals, but not yet a trustworthy
  primary framing oracle for promoted signoff SVA

---

## 5. Current Regression Shape

The active testcase files are:

- `tests/opq_basic_tests.sv`
- `tests/opq_edge_tests.sv`
- `tests/opq_prof_tests.sv`
- `tests/opq_error_tests.sv`
- `tests/opq_cross_tests.sv`

The wrapper scripts are:

- `scripts/run_basic.sh`
- `scripts/run_param.sh`
- `scripts/run_edge.sh`
- `scripts/run_perf.sh`
- `scripts/run_error.sh`
- `scripts/run_cross.sh`
- `scripts/run_probes.sh`
- `scripts/run_cov_closure.sh`

The current promoted signoff subset is still tracked separately in
`packet_scheduler/doc/VERIFICATION_SIGNOFF.md`.

---

## 6. Compile / Elaboration-Time Configuration Sweep

The precise term for the existing parameter mechanism is a compile /
elaboration-time configuration sweep.

- The UVM build phase publishes the effective DUT config through config-DB.
- The actual DUT generic selection still happens at compile/elaboration time
  through wrapper defines and the generated VHDL shell.
- Signoff samples a bounded legal set of compile-time points instead of
  claiming exhaustive closure across the full parameter space.

Currently implemented points:

- `OPQ_N_SHD = 128 / 256 / 512`
- derived or explicit `OPQ_TICKET_FIFO_DEPTH`
- reduced `OPQ_PAGE_RAM_DEPTH` for overwrite forcing

---

## 7. Random-Stress Contract

The DRR path now has both directed and constrained-random evidence:

- `opq_cross_drr_allowance_test`
  - directed allowance/defer case
  - checks CSR-programmed DRR allowance, defer counters, and scoreboard closure
- `opq_cross_drr_bursty_random_test`
  - constrained-random hot-lane / cold-lane burst asymmetry
  - applies periodic egress backpressure on top of asymmetric block sizes and
    inter-frame gaps
  - is intended to trigger SVA / scoreboard failures if the timing contract
    between page allocator, DRR arbiter, block mover, and presenter is
    incomplete
- `opq_cross_drr_idle_lane_test`, `opq_cross_drr_zero_allowance_test`, and
  `opq_cross_drr_short_allowance_test`
  - directed DRR stress around empty-frame cadence, allowance starvation, and
    short quantum settings
  - close the stable directed part of the current DRR contract before the
    bursty probe path

This bursty testcase is currently exposing a real DUT bug, not a harness bug:

- the monolithic presenter / egress path still has an open stall-boundary bug
  under periodic backpressure
- the live harness still lacks precise late-drop hit identity from the DUT, so
  final CSR totals alone are not enough to promote this testcase as a full
  hit-integrity signoff bucket

That means the testcase is doing the right job today: it is a reproducer and a
future signoff bucket, but not yet a promoted closure point.

---

## 8. Known Harness Gaps

- no live general `N_LANE` generator yet
- no live `MULTIPLEXING` mode regression yet
- no live `TRACK_HEADER=false` regression yet
- no live packed-multi-symbol egress width regression yet
- coverage closure still needs merged structural-hole disposition
- the active monolithic VHDL DUT still has an open accepted-count /
  frame-table-metadata bug under asymmetric bursty DRR traffic; the harness is
  exposing it correctly

These are real harness limitations and must remain explicit in the plan.

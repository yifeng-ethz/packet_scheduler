# DV_CROSS: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-21
**Status:** Active current-tree bucket for promoted mixed-axis cases, including the supplemental mixed-bucket random-soak signoff screen, refreshed bursty-DRR closure screens, and explicit non-promoted long-runtime stress screens.

---

## Scope

`DV_CROSS` covers the current mixed-axis cases that combine:

- backpressure
- credit restoration
- DRR allowance programming
- block-level defer / grant behavior

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_bp_credit_test` | Backpressure × credit restoration on the healthy path | Passing |
| `opq_cross_drr_allowance_test` | Runtime per-lane DRR allowance programming, defer counters, and service counts | Passing |
| `opq_cross_drr_idle_lane_test` | DRR with one hit-idle peer lane that still emits empty frames to preserve legal frame cadence | Passing |
| `opq_cross_drr_zero_allowance_test` | Zero-allowance lane defers until reload and then resumes service cleanly | Passing |
| `opq_cross_drr_short_allowance_test` | Short-quantum reload behavior with repeated directed service handoff | Passing |
| `opq_cross_idle_lane_backpressure_test` | Idle-lane cadence crossed with periodic egress stalls on the active lane | Passing |
| `opq_cross_mixed_bucket_random_soak_test` | Random mixed-bucket soak that chains safe BASIC/EDGE/PROF/ERROR/CROSS cases without restart | Passing; the refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256` rerun on `2026-04-21` closes with `expected=14547 actual=14547 missing=0 ghost=0` and per-lane `unexplained=0`; tracked as a dedicated supplemental native-SV signoff run outside the fixed case-ordered bucket-frame baselines |
| `opq_cross_drr_bursty_frame2_boundary_test` | Deterministic bursty DRR frame_count=2 boundary companion to the green frame_count=3 repro | Passing on `2026-04-21`; the refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256` rerun closes with `expected=484 actual=484 missing=0 ghost=0`; tracked as a dedicated supplemental native-SV signoff run outside the fixed case-ordered bucket-frame baselines |
| `opq_cross_bp_predrop_boundary_test` | Directed default-build backpressure boundary proof that shows heavy sustained pressure can stay in the legal ingress pre-drop regime with `ft_drop_* = 0` while hit and frame-table ledgers still close | Passing; tracked as a dedicated supplemental native-SV signoff run outside the fixed case-ordered bucket-frame baselines |
| `opq_cross_random_ready_overflow_step2_boundary_test` | Named default-build two-step legal-overflow boundary in random-ready shape-check mode | Passing on `2026-04-21`; the refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256` rerun closes with final `wr_hdr/shd/hit=7/19/1607`, `rd_hdr/shd/hit=7/19/1607`, `ft_drop_hdr/shd/hit=0/0/0`, aggregate `accepted=1607 delivered=1607 unexplained=0`, and `core_principles first_break=clean`; tracked as a dedicated supplemental native-SV signoff run outside the fixed case-ordered bucket-frame baselines |

---

## Non-Promoted Stress Screens

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Refreshed on the current `2026-04-21` patchset: seed `1` closes with `expected=990 actual=990 missing=0 ghost=0`, seeds `2..8` close with `expected=1864 actual=1864 missing=0 ghost=0`, and every refreshed seed ends with per-lane `unexplained=0`; kept non-promoted as supplemental random evidence rather than a fixed matrix case |
| `opq_cross_drr_bursty_frame3_repro_test` | Reduced deterministic bursty DRR retirement anchor for `BUG-025-R` | Passing on `2026-04-21` with `expected=714 actual=714 missing=0 ghost=0`; retained as the shortest historical closure check for the former active-lane retirement bug |
| `opq_cross_bp_mustdrop_witness_test` | Reduced-depth overwrite-local must-drop witness at the named `12x16` pressure profile | Passing on `2026-04-21`: the no-drop pre-phase keeps `ft_drop_delta hdr/shd/hit=0/0/0`, the pressure phase advances `ft_drop_delta hdr/shd/hit=10/80/2400`, the final frame-table ledger closes at `wr_hdr/shd/hit=13/224/3135`, `rd_hdr/shd/hit=3/144/735`, `drop_hdr/shd/hit=10/80/2400`, and aggregate `accepted=735 delivered=735 unexplained=0`; the same witness now reruns green on the refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 OPQ_PAGE_RAM_DEPTH=512` build; kept non-promoted because it requires the dedicated reduced-depth elaboration point |
| `opq_cross_random_ready_overflow_seconds_soak_test` | Default-build random-ready overflow / backpressure soak with ledger checkpoints after each step | Current-tree shape-check green rerun closes with `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=29/68/5545`, `rd_hdr/shd/hit=29/68/5545`, aggregate `accepted=5545 delivered=5545 unexplained=0`, and `core_principles first_break=clean`; kept probe-only because it is not the named overwrite-local must-drop witness |
| `opq_cross_mixed_bucket_seconds_soak_test` | Earlier extended mixed-bucket random soak with longer chained no-restart traffic and stretched simulated time | Passing extended probe: the full stretched rerun now crosses the old `mixed_sparse_191`, `mixed_soak_261`, `mixed_whole_skew_275`, `mixed_whole_skew_418`, and `mixed_whole_skew_435` windows cleanly and exits with `UVM_ERROR : 0`; kept probe-only because it is a long runtime stress screen rather than a promoted matrix case |

The current default-build overflow/backpressure space is therefore split
deliberately:

- `opq_cross_bp_predrop_boundary_test` is the green proof that sustained
  default-build backpressure may remain entirely in the legal ingress pre-drop
  regime with clean `wr = rd + drop` accounting and `unexplained = 0`.
- `opq_cross_random_ready_overflow_step2_boundary_test` is the green proof
  that the first two default-build random-ready overflow windows may still stay
  legal even under very heavy pre-drop pressure: both checkpoints keep
  `ft_drop_* = 0`, `wr = rd + drop`, and `unexplained = 0`.
- the explicit overwrite-local must-drop proof now lives in the reduced-depth
  `opq_cross_bp_mustdrop_witness_test` profile: the default-build random-ready
  shape checks are green, and the named reduced-depth witness is also green
  again with `ft_drop_*` progress and `unexplained = 0`.

---

## Extended Soak Evidence

- `opq_cross_mixed_bucket_long_simtime_soak_test` passes with `+TB_CLK_PERIOD_NS=1000000 +OPQ_MIXED_SOAK_STEPS=64`, finishing at `2194139500 us` of sim time, which is about `36.6 minutes`, with `expected=5798 actual=5798 missing=0 ghost=0`.
- `opq_cross_mixed_bucket_seconds_soak_test` is the earlier extended screen: with `+TB_CLK_PERIOD_NS=250`, the repaired RTL now reaches the end of the full stretched rerun cleanly, including repeated chained `subheader_error_recovery` steps deep into the run, and still closes with `UVM_ERROR : 0`, `UVM_FATAL : 0`, and `Errors: 0`. It remains probe-only instead of promoted evidence because it is retained as a long-runtime stress screen outside the default promoted matrix.

---

## Coverage Intent

This bucket is the owner for the current live DRR closure path:

- `cg_drr` allowance / defer bins
- `cg_drr` zero/short allowance directed bins
- DRR CSR accesses
- `opq_drr_sva` onehot / defer / preemption checks

---

## Still Relevant Legacy Backlog

The archived cross catalog remains relevant for:

- broader parameter crosses
- MODE parity once live `MULTIPLEXING` support exists
- longer chained mixed-axis regressions after the larger bursty DRR random
  screens and the reduced-depth must-drop witness have either been promoted or
  are no longer needed as separate supplemental evidence

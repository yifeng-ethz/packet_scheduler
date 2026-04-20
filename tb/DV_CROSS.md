# DV_CROSS: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-20
**Status:** Active current-tree bucket for promoted mixed-axis cases, including the supplemental mixed-bucket random-soak signoff screen and explicit non-promoted stress screens.

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
| `opq_cross_mixed_bucket_random_soak_test` | Random mixed-bucket soak that chains safe BASIC/EDGE/PROF/ERROR/CROSS cases without restart | Passing; tracked as a dedicated supplemental native-SV signoff run outside the fixed case-ordered bucket-frame baselines |

---

## Non-Promoted Stress Screens

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Focused native-SV repro remains fixed, but the refreshed larger constrained-random rerun on `2026-04-20` still fails with lane0 `unexplained=368` and hit-integrity summary `expected=852 actual=622 missing=368 ghost=138`; keep probe-only |
| `opq_cross_mixed_bucket_seconds_soak_test` | Earlier extended mixed-bucket random soak with longer chained no-restart traffic and stretched simulated time | Passing extended probe: the full stretched rerun now crosses the old `mixed_sparse_191`, `mixed_soak_261`, `mixed_whole_skew_275`, `mixed_whole_skew_418`, and `mixed_whole_skew_435` windows cleanly and exits with `UVM_ERROR : 0`; kept probe-only because it is a long runtime stress screen rather than a promoted matrix case |

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
  screen is refreshed and either promoted or explicitly retired

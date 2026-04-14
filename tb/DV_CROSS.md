# DV_CROSS: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for promoted mixed-axis cases and explicit stress reproducers.

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

---

## Open Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Open repro: still exposes the monolithic presenter stall-boundary bug and incomplete late-drop observability for promoted hit-integrity closure |

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
- longer chained mixed-axis regressions after the current open DRR bug is fixed

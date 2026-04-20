# DV_EDGE: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for boundary and restart cases that are promoted today.

---

## Scope

`DV_EDGE` covers the currently supported boundary conditions around:

- egress backpressure and presenter restart
- always-ready baseline vs explicit ready driving
- max-hit packet shape in the live harness
- short-toggle ready behavior

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_edge_backpressure_test` | Periodic stall / restart path with hit-integrity checks | Passing |
| `opq_edge_always_ready_test` | Explicit ready-high baseline under the same harness plumbing | Passing |
| `opq_edge_ready_medium_profile_test` | Medium-duty periodic-stall ready profile to sample non-trivial but healthy backpressure bins | Passing |
| `opq_edge_stuck_low_backpressure_test` | Longer low-ready windows short of the known overwrite probe path | Passing |
| `opq_edge_max_hits_test` | Max-hit packet shape on the live symbol path | Passing |
| `opq_edge_toggle_backpressure_test` | One-cycle ready toggle stress to close short backpressure bins | Passing |
| `opq_edge_burst_restart_profile_test` | Short ready bursts with deeper low stretches to stress repeated presenter restart | Passing |
| `opq_edge_long_toggle_backpressure_test` | Extends one-cycle ready toggling deep enough to stress repeated restart transitions under the healthy path | Passing |
| `opq_edge_max_hits_backpressure_test` | Exercises the max-hit packet shape while periodic egress stalls force presenter restart | Passing |

The `2026-04-20` edge expansion set is now part of the default `run_edge.sh`
wrapper, the generated signoff report flow, and the default-build
continuous-frame baselines.

---

## Coverage Intent

These cases currently drive:

- `cg_bp` periodic stall and always-ready bins
- `cg_bp` medium-profile and stuck-low bins that are still legal on the healthy path
- `cg_subheader.hit_cnt` burst bins
- edge backpressure contract checked by `opq_avst_egress_sva`

---

## Still Relevant Legacy Backlog

The archived edge matrix is still useful for later closure of:

- wider `PAGE_RAM_RD_WIDTH`
- FIFO near-full boundaries beyond the current promoted cases
- broader page-segment / wrap transitions

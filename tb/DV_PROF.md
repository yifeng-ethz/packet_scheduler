# DV_PROF: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing stress and skew cases.

---

## Scope

`DV_PROF` is the current performance-oriented bucket for cases that stay inside
the healthy contract but exercise longer runtime, more frames, or sustained
lane skew.

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_prof_stress_test` | Short soak with repeated long frames and credit restoration checks | Passing |
| `opq_prof_lane_skew_test` | Sustained two-lane skew using the stress sequence rather than zero-skew bring-up traffic | Passing |

---

## Coverage Intent

These cases are the main owners for:

- longer multi-frame residency
- `cg_frame.pre_gap` skew-gap bin
- credit snapshot sampling under sustained traffic

---

## Still Relevant Legacy Backlog

The archived perf catalog is still relevant for later work on:

- deeper soak lengths
- higher-pressure burst asymmetry
- larger parameter-space sweeps once the live harness supports them

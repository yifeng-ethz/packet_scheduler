# DV_PROF: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing native-SV stress and skew cases.

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
| `opq_prof_whole_frame_skew_test` | Whole-frame skew with alternating active/empty FEB frames to close packet-level cadence under sustained traffic | Passing |
| `opq_prof_missing_empty_frame_test` | Uneven per-lane frame-count stress for the active 2-lane harness contract, preserving hit integrity while sampling sparse-frame cadence | Passing |

---

## Coverage Intent

These cases are the main owners for:

- longer multi-frame residency
- `cg_frame.pre_gap` skew-gap bin
- whole-frame activity / inactivity cadence bins
- credit snapshot sampling under sustained traffic

---

## Still Relevant Legacy Backlog

The archived perf catalog is still relevant for later work on:

- deeper soak lengths
- higher-pressure burst asymmetry
- larger parameter-space sweeps once the live harness supports them

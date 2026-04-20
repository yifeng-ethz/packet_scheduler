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
| `opq_prof_long_soak_test` | Longer directed FEB whole-frame soak beyond the short promoted stress run | Passing |
| `opq_prof_heavy_lane_skew_test` | Extends the skew-gap envelope beyond the promoted stress pair while keeping zero-drop accounting | Passing |
| `opq_prof_deep_whole_frame_skew_test` | Extends the whole-frame skew chain with deeper residency and reduced subheader density | Passing |
| `opq_prof_asymmetric_missing_empty_frame_test` | Explicitly drives uneven 2-lane frame counts instead of relying on the 4-lane-only default sequence asymmetry | Passing |

The `2026-04-20` stress/skew expansion set is now part of the default
`run_perf.sh` wrapper, the generated signoff report flow, and the default-build
continuous-frame baselines.

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

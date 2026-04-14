# DV_PROBE: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for non-promoted bug reproducers and closure probes.

---

## Scope

`DV_PROBE` is intentionally separate from the promoted signoff buckets.

These cases are still valuable because they exercise the right contract edges,
but they currently expose real DUT or observability bugs. They therefore add
debug value and coverage evidence, but they must not be counted as promoted
signoff closure until the failing behavior is fixed and rerun cleanly.

The runner for this bucket is `packet_scheduler/tb/scripts/run_probes.sh`.

---

## Active Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Open repro: still exposes presenter stall-boundary corruption and repeated subheaders under asymmetric block sizes |
| `opq_error_lane_mask_recovery_test` | Mask all lanes, accumulate drops, then clear the mask and expect clean recovery | Open repro: lane-mask clear does not yet restore clean traffic on the active DUT path |
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite with always-stall egress to exercise frame-table drop accounting | Open repro: forced overwrite still produces malformed accepted egress beats |

---

## Coverage Intent

This bucket is still sampled because it touches holes the promoted suite does
not:

- `cg_drop` on frame-table overwrite paths
- `cg_drr` hot-lane defer-heavy behavior
- replay of recovery-after-drop sequences
- assertion firing points that should later move from probe-only to green

Probe coverage is diagnostic evidence, not closure evidence.

---

## Promotion Rule

A probe moves into a promoted bucket only after:

- zero `UVM_ERROR` / `UVM_FATAL`
- zero `** Error:` assertion failures
- scoreboard integrity or justified drop accounting is clean
- the testcase adds distinct coverage on a stable contract path

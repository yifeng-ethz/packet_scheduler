# DV_ERROR: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing control/error cases, plus explicit open probes for the remaining overwrite and recovery bugs.

---

## Scope

`DV_ERROR` holds the currently supported runtime error/control cases:

- lane masking
- counter-clear behavior

This bucket also carries non-promoted reproducers when they expose real DUT
recovery gaps.

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_lane_mask_test` | Packet-boundary lane masking with per-lane drop-counter checks | Passing |
| `opq_error_lane_mask_single_hit_test` | Minimal masked-drop packet to close one-hit counter behavior | Passing |
| `opq_error_lane_mask_burst_test` | Multi-hit masked-drop packet to close burst counter behavior | Passing |
| `opq_error_counter_clear_test` | Runtime counter clear semantics | Passing |

---

## Open Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite / frame-table drop accounting | Open repro: forced overwrite still produces malformed accepted egress beats under always-stall backpressure, so the testcase is useful bug evidence but not promotable signoff coverage today |
| `opq_error_lane_mask_recovery_test` | Mask, drop, then clear the mask and expect clean recovery | Open repro: lane-mask clear does not recover as expected; masked headers remain counted as drops and no clean egress packet returns |

---

## Still Relevant Legacy Backlog

The archived error matrix remains the source for later closure of:

- reset-in-state
- malformed / truncated packet paths
- broader recovery-after-drop cases

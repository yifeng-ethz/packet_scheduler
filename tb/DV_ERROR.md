# DV_ERROR: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing control/error cases, plus explicit open probes for the remaining overwrite and recovery bugs.

---

## Scope

`DV_ERROR` holds the currently supported runtime error/control cases:

- lane masking
- recovery after masking / malformed subheader suppression
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
| `opq_error_lane_mask_recovery_test` | Mask, drop, then clear the mask and expect clean recovery on the next legal FEB packets | Passing |
| `opq_error_subheader_mask_recovery_test` | Malformed subheader suppression followed by a legal recovery frame | Passing |
| `opq_error_counter_clear_test` | Runtime counter clear semantics | Passing |

---

## Open Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_header_mask_recovery_test` | Malformed preamble/header suppression followed by a legal recovery frame | Open repro: the native-SV ingress parser still loses the recovery frame timestamp context after a header-error mask path, producing ghost/missing hits with low-byte-only timestamps |
| `opq_error_header_word_mask_recovery_test` | Header-word error injection followed by a legal recovery frame | Open repro: isolated native-SV still ends at `expected=4 actual=4 missing=4 ghost=4`, with recovery hits emitted at `ts=0x0010` instead of `ts=0x1010`; attempted promotion into the no-restart ERROR bucket was backed out because it also poisoned later continuous-frame accounting |
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite / frame-table drop accounting | Open repro: forced overwrite still produces malformed accepted egress beats under always-stall backpressure, so the testcase is useful bug evidence but not promotable signoff coverage today |

---

## Still Relevant Legacy Backlog

The archived error matrix remains the source for later closure of:

- reset-in-state
- malformed header / truncated packet paths beyond the current subheader recovery closure
- broader recovery-after-drop cases

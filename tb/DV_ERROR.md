# DV_ERROR: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-20
**Status:** Active current-tree bucket for passing control/error cases, including the restored malformed-header recovery closure and the reduced-depth overflow special elaboration point.

---

## Scope

`DV_ERROR` holds the currently supported runtime error/control cases:

- lane masking
- recovery after masking / malformed subheader suppression / malformed header suppression
- counter-clear behavior

This bucket also carries the reduced-depth overflow elaboration point when it
needs separate build/report handling outside the fixed default no-restart
baseline.

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_lane_mask_test` | Packet-boundary lane masking with per-lane drop-counter checks | Passing |
| `opq_error_lane_mask_single_hit_test` | Minimal masked-drop packet to close one-hit counter behavior | Passing |
| `opq_error_lane_mask_burst_test` | Multi-hit masked-drop packet to close burst counter behavior | Passing |
| `opq_error_lane_mask_recovery_test` | Mask, drop, then clear the mask and expect clean recovery on the next legal FEB packets | Passing |
| `opq_error_subheader_mask_recovery_test` | Malformed subheader suppression followed by a legal recovery frame | Passing |
| `opq_error_header_mask_recovery_test` | Malformed preamble/header suppression followed by a legal recovery frame | Passing; restored to the live ERROR runner, generated report, and default-build no-restart baseline on `2026-04-20` |
| `opq_error_header_word_mask_recovery_test` | Header-word error injection followed by a legal recovery frame | Passing; restored to the live ERROR runner, generated report, and default-build no-restart baseline on `2026-04-20` |
| `opq_error_counter_clear_test` | Runtime counter clear semantics | Passing |

---

## Special Elaboration Point

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite / frame-table drop accounting | Passing isolated-only at reduced depth; remains outside the fixed default no-restart baseline because it requires a separate `OPQ_PAGE_RAM_DEPTH=512` elaboration point |

---

## Still Relevant Legacy Backlog

The archived error matrix remains the source for later closure of:

- reset-in-state
- malformed header / truncated packet paths beyond the current subheader + header recovery closure
- broader recovery-after-drop cases

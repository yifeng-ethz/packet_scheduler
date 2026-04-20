# DV_ERROR: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing control/error cases, including the reduced-depth overwrite closure, plus isolated recovery cases that are fixed in native-SV and awaiting regenerated report integration.

---

## Scope

`DV_ERROR` holds the currently supported runtime error/control cases:

- lane masking
- recovery after masking / malformed subheader suppression
- counter-clear behavior

This bucket also carries non-default elaboration points and not-yet-promoted
recovery cases when they need separate report integration.

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
| `opq_error_ftable_overflow_test` | Reduced-depth `OPQ_PAGE_RAM_DEPTH=512` overwrite pressure under hard egress stall | Passing in isolated native-SV evidence; promoted as a separate elaboration point, not part of the fixed no-restart baseline |

---

## Special-Handling Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_header_mask_recovery_test` | Malformed preamble/header suppression followed by a legal recovery frame | Passing in isolated native-SV after the `2026-04-18` header timestamp-base repair; still outside the generated signoff set pending ERROR-bucket/report refresh |
| `opq_error_header_word_mask_recovery_test` | Header-word error injection followed by a legal recovery frame | Passing in isolated native-SV after the `2026-04-18` header timestamp-base repair; still outside the generated ERROR bucket pending baseline refresh |
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite / frame-table drop accounting | Passing isolated-only at reduced depth; remains outside the fixed default no-restart baseline because it requires a separate `OPQ_PAGE_RAM_DEPTH=512` elaboration point |

---

## Still Relevant Legacy Backlog

The archived error matrix remains the source for later closure of:

- reset-in-state
- malformed header / truncated packet paths beyond the current subheader recovery closure
- broader recovery-after-drop cases

# DV_ERROR: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-21
**Status:** Active current-tree bucket for passing control/error cases, including typed ingress-error masking at header/subheader/hit granularity, the restored malformed-header recovery closure, the passing counter-clear supplemental screen, and the refreshed reduced-depth overwrite shape-check. The explicit overwrite-local must-drop witness now lives in `DV_CROSS.md`.

---

## Scope

`DV_ERROR` holds the currently supported runtime error/control cases:

- lane masking
- typed ingress error masking and recovery
- counter-clear behavior

The supported ingress-error contract is intentionally typed and is still
secondary to the default no-error path:

- `hdr_err` on the preamble/header masks the full frame
- `shd_err` on a subheader masks that subheader and its associated hits
- `hit_err` on a hit masks only that hit, while the parser still consumes the
  declared hit beat and emits a ticket length that reflects only accepted hits

Those bits are location-specific. The legal runtime mode is `onehot0`
error injection at the correct beat type. Asserting an ingress error bit at the
wrong location is illegal input and is owned by the formal contract, not by the
runtime ERROR bucket.

This bucket also carries the reduced-depth overflow elaboration point when it
needs separate build/report handling outside the fixed default no-restart
baseline.

Counter-clear semantics are also tracked as a dedicated supplemental signoff
screen because that testcase intentionally zeroes live CSR counters mid-run
instead of preserving a single monotonic end-of-run counter image.

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_lane_mask_test` | Packet-boundary lane masking with per-lane drop-counter checks | Passing |
| `opq_error_lane_mask_single_hit_test` | Minimal masked-drop packet to close one-hit counter behavior | Passing |
| `opq_error_lane_mask_burst_test` | Multi-hit masked-drop packet to close burst counter behavior | Passing |
| `opq_error_lane_mask_recovery_test` | Mask, drop, then clear the mask and expect clean recovery on the next legal FEB packets | Passing |
| `opq_error_hit_mask_recovery_test` | Mask the first or last hit of a subheader, then follow with legal recovery traffic | Passing on `2026-04-21`; isolated native-SV rerun closes with `expected=6 actual=6 missing=0 ghost=0`, and the targeted ingress formal-wrapper stress rerun also passes |
| `opq_error_subheader_mask_recovery_test` | Malformed subheader suppression, including its associated hit payload, followed by a legal recovery frame | Passing on `2026-04-21`; isolated native-SV rerun closes with `expected=2 actual=2 missing=0 ghost=0`, and the refreshed ingress formal-wrapper stress is green after the zero-hit recovery branch was returned to the normal body state |
| `opq_error_header_mask_recovery_test` | Malformed preamble/header suppression with full-frame mask, followed by a legal recovery frame | Passing; restored to the live ERROR runner, generated report, and default-build no-restart baseline on `2026-04-20` |
| `opq_error_header_word_mask_recovery_test` | Header-word error injection followed by a legal recovery frame | Passing; restored to the live ERROR runner, generated report, and default-build no-restart baseline on `2026-04-20` |
| `opq_error_counter_clear_test` | Runtime counter clear semantics | Passing; tracked as a dedicated supplemental native-SV signoff run because it intentionally clears live counters mid-run |

---

## Special Elaboration Point

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_error_ftable_overflow_test` | Reduced-depth overwrite-pressure shape check on the native-SV presenter path | Historical `2-lane/256/512` supplemental screen remains green with frame-table ledger `wr_hdr=32 rd_hdr=20 drop_hdr=12`, `wr_shd=8191 rd_shd=5120 drop_shd=3071`, `wr_hit=44 rd_hit=28 drop_hit=16`, aggregate `accepted=28 delivered=28 unexplained=0`, and `UVM_ERROR : 0`. The refreshed `4-lane/128/512` rerun does not force `ft_drop_*` progress in either the legacy or dense traffic mode, so this testcase is now treated as preset-limited shape-check evidence; the explicit overwrite-local must-drop closure on the wider matrix is carried by `opq_cross_bp_mustdrop_witness_test` in `DV_CROSS.md` |

---

## Still Relevant Legacy Backlog

The archived error matrix remains the source for later closure of:

- reset-in-state
- malformed header / truncated packet paths beyond the current subheader + header recovery closure
- broader recovery-after-drop cases

# ✅ drr_bursty_frame2_boundary_native_sv

**Kind:** `drr_bursty_frame2_boundary` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_DRR_BURSTY_FRAME2_BOUNDARY`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `4` |
| ✅ | functional_cross_pct | `58.32` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that freezes a deterministic bursty DRR frame_count=2 boundary alongside the separately tracked green frame_count=3 repro. |
| ⚠️ | limitation | It is intentionally tracked outside the promoted fixed bucket-frame baselines because bursty DRR stress evidence is maintained as a supplemental screen, not because of an active correctness failure. |

## Execution Order

### drr_bursty_frame2_boundary

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test`](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md) (`opq_cross_drr_bursty_frame2_boundary_test`)
- limitation: This is a supplemental signoff run that freezes a deterministic bursty DRR frame_count=2 boundary alongside the separately tracked green frame_count=3 repro.
- limitation: It is intentionally tracked outside the promoted fixed bucket-frame baselines because bursty DRR stress evidence is maintained as a supplemental screen, not because of an active correctness failure.

## Code coverage

| metric | pct |
|---|---|
| stmt | 77.72 |
| branch | 71.62 |
| cond | 45.08 |
| expr | 56.74 |
| fsm_state | 88.64 |
| fsm_trans | 45.00 |
| toggle | 23.37 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

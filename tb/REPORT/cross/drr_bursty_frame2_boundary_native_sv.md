# ✅ drr_bursty_frame2_boundary_native_sv

**Kind:** `drr_bursty_frame2_boundary` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_DRR_BURSTY_FRAME2_BOUNDARY`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `4` |
| ✅ | functional_cross_pct | `57.35` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that freezes the largest green bursty DRR envelope below the open frame_count=3 active-lane retirement failure. |
| ⚠️ | limitation | It is intentionally tracked outside the promoted fixed bucket-frame baselines because the larger bursty DRR probe family remains open. |

## Execution Order

### drr_bursty_frame2_boundary

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test`](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md) (`opq_cross_drr_bursty_frame2_boundary_test`)
- limitation: This is a supplemental signoff run that freezes the largest green bursty DRR envelope below the open frame_count=3 active-lane retirement failure.
- limitation: It is intentionally tracked outside the promoted fixed bucket-frame baselines because the larger bursty DRR probe family remains open.

## Code coverage

| metric | pct |
|---|---|
| stmt | 74.20 |
| branch | 67.51 |
| cond | 43.82 |
| expr | 60.20 |
| fsm_state | 86.36 |
| fsm_trans | 43.00 |
| toggle | 24.49 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

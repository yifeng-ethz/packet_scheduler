# ✅ mixed_bucket_random_soak_native_sv

**Kind:** `mixed_bucket_random_soak` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_MIXED_BUCKET_RANDOM_SOAK`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `1220` |
| ✅ | functional_cross_pct | `71.1` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run, not the fixed bucket-frame baseline; execution order is intentionally seed-driven rather than case-id ordered. |
| ⚠️ | limitation | The run reuses only already-promoted safe bucket slices so it can stress chained no-restart behavior without folding the separate bursty DRR supplemental screens into the fixed baseline. |

## Execution Order

### mixed_bucket_random_soak

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) (`opq_cross_mixed_bucket_random_soak_test`)
- limitation: This is a supplemental signoff run, not the fixed bucket-frame baseline; execution order is intentionally seed-driven rather than case-id ordered.
- limitation: The run reuses only already-promoted safe bucket slices so it can stress chained no-restart behavior without folding the separate bursty DRR supplemental screens into the fixed baseline.

## Code coverage

| metric | pct |
|---|---|
| stmt | 78.79 |
| branch | 76.45 |
| cond | 52.85 |
| expr | 68.79 |
| fsm_state | 90.91 |
| fsm_trans | 48.00 |
| toggle | 44.22 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

# ✅ mixed_bucket_random_soak_native_sv

**Kind:** `mixed_bucket_random_soak` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_MIXED_BUCKET_RANDOM_SOAK`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `1160` |
| ✅ | functional_cross_pct | `70.96` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run, not the fixed bucket-frame baseline; execution order is intentionally seed-driven rather than case-id ordered. |
| ⚠️ | limitation | The run reuses only already-promoted safe bucket slices so it can stress chained no-restart behavior without reopening known probe-only bursty DRR loss. |

## Execution Order

### mixed_bucket_random_soak

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) (`opq_cross_mixed_bucket_random_soak_test`)
- limitation: This is a supplemental signoff run, not the fixed bucket-frame baseline; execution order is intentionally seed-driven rather than case-id ordered.
- limitation: The run reuses only already-promoted safe bucket slices so it can stress chained no-restart behavior without reopening known probe-only bursty DRR loss.

## Code coverage

| metric | pct |
|---|---|
| stmt | 82.40 |
| branch | 79.02 |
| cond | 54.67 |
| expr | 77.08 |
| fsm_state | 90.91 |
| fsm_trans | 48.00 |
| toggle | 45.23 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

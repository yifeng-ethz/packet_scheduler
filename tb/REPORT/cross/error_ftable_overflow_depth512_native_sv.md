# ✅ error_ftable_overflow_depth512_native_sv

**Kind:** `error_ftable_overflow_depth512` &nbsp; **Build:** `native_sv_depth512` &nbsp; **Sequence:** `OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `64` |
| ✅ | functional_cross_pct | `58.88` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that intentionally uses OPQ_PAGE_RAM_DEPTH=512 to force the overwrite / frame-table-drop path. |
| ⚠️ | limitation | Because it requires a separate elaboration point, it cannot be folded into the fixed default-build no-restart baselines. |

## Execution Order

### error_ftable_overflow_depth512

- bucket_order: `ERROR`
- ordered_steps:
  `ERROR` -> [`CORNER_OPQ_410_error_ftable_overflow_test`](../cases/CORNER_OPQ_410_error_ftable_overflow_test.md) (`opq_error_ftable_overflow_test`)
- limitation: This is a supplemental signoff run that intentionally uses OPQ_PAGE_RAM_DEPTH=512 to force the overwrite / frame-table-drop path.
- limitation: Because it requires a separate elaboration point, it cannot be folded into the fixed default-build no-restart baselines.

## Code coverage

| metric | pct |
|---|---|
| stmt | 73.05 |
| branch | 64.86 |
| cond | 34.46 |
| expr | 51.06 |
| fsm_state | 86.36 |
| fsm_trans | 43.00 |
| toggle | 26.48 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

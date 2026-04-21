# ⚠️ error_counter_clear_native_sv

**Kind:** `error_counter_clear` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_ERROR_COUNTER_CLEAR`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `2` |
| ⚠️ | functional_cross_pct | `38.3` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that validates CSR zeroization semantics after masked-drop traffic. |
| ⚠️ | limitation | The testcase intentionally clears live counters before end-of-run reporting, so it is tracked outside the fixed bucket-frame baselines. |

## Execution Order

### error_counter_clear

- bucket_order: `ERROR`
- ordered_steps:
  `ERROR` -> [`CORNER_OPQ_409_error_counter_clear_test`](../cases/CORNER_OPQ_409_error_counter_clear_test.md) (`opq_error_counter_clear_test`)
- limitation: This is a supplemental signoff run that validates CSR zeroization semantics after masked-drop traffic.
- limitation: The testcase intentionally clears live counters before end-of-run reporting, so it is tracked outside the fixed bucket-frame baselines.

## Code coverage

| metric | pct |
|---|---|
| stmt | 45.67 |
| branch | 32.25 |
| cond | 7.77 |
| expr | 12.77 |
| fsm_state | 29.55 |
| fsm_trans | 5.00 |
| toggle | 3.06 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

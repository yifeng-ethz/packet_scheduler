# ✅ overflow_step2_boundary_native_sv

**Kind:** `overflow_step2_boundary` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_OVERFLOW_STEP2_BOUNDARY`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `14` |
| ✅ | functional_cross_pct | `61.9` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that freezes the current green two-step legal-overflow boundary on the default build with ft_drop counters held at zero. |
| ⚠️ | limitation | It does not close the later must-drop path; the longer random-ready overflow soak remains probe-only until the presenter overwrite accounting bug is fixed. |

## Execution Order

### overflow_step2_boundary

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test`](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md) (`opq_cross_random_ready_overflow_step2_boundary_test`)
- limitation: This is a supplemental signoff run that freezes the current green two-step legal-overflow boundary on the default build with ft_drop counters held at zero.
- limitation: It does not close the later must-drop path; the longer random-ready overflow soak remains probe-only until the presenter overwrite accounting bug is fixed.

## Code coverage

| metric | pct |
|---|---|
| stmt | 80.25 |
| branch | 74.27 |
| cond | 50.84 |
| expr | 71.43 |
| fsm_state | 93.18 |
| fsm_trans | 52.00 |
| toggle | 36.91 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

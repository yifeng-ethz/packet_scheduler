# ✅ bp_predrop_boundary_native_sv

**Kind:** `bp_predrop_boundary` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_BP_PREDROP_BOUNDARY`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `104` |
| ✅ | functional_cross_pct | `62.07` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that proves the default-build legal pre-drop boundary under sustained backpressure while keeping frame-table drop counters at zero. |
| ⚠️ | limitation | The testcase intentionally stages a mild no-drop phase followed by a heavier pressure phase, so it is tracked outside the promoted fixed bucket-frame baselines. |

## Execution Order

### bp_predrop_boundary

- bucket_order: `CROSS`
- limitation: This is a supplemental signoff run that proves the default-build legal pre-drop boundary under sustained backpressure while keeping frame-table drop counters at zero.
- limitation: The testcase intentionally stages a mild no-drop phase followed by a heavier pressure phase, so it is tracked outside the promoted fixed bucket-frame baselines.

## Code coverage

| metric | pct |
|---|---|
| stmt | 75.12 |
| branch | 67.64 |
| cond | 42.13 |
| expr | 59.18 |
| fsm_state | 88.64 |
| fsm_trans | 45.00 |
| toggle | 33.07 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

# ✅ overflow_step2_boundary_native_sv

**Kind:** `overflow_step2_boundary` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_OVERFLOW_STEP2_BOUNDARY`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `1` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `10` |
| ✅ | functional_cross_pct | `62.4` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | This is a supplemental signoff run that freezes the current green two-step legal-overflow boundary on the default build with ft_drop counters held at zero. |
| ⚠️ | limitation | The explicit overwrite-local must-drop proof is carried separately by the reduced-depth opq_cross_bp_mustdrop_witness_test witness, so this run remains the early-window legal-overflow boundary only. |

## Execution Order

### overflow_step2_boundary

- bucket_order: `CROSS`
- ordered_steps:
  `CROSS` -> [`COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test`](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md) (`opq_cross_random_ready_overflow_step2_boundary_test`)
- limitation: This is a supplemental signoff run that freezes the current green two-step legal-overflow boundary on the default build with ft_drop counters held at zero.
- limitation: The explicit overwrite-local must-drop proof is carried separately by the reduced-depth opq_cross_bp_mustdrop_witness_test witness, so this run remains the early-window legal-overflow boundary only.

## Code coverage

| metric | pct |
|---|---|
| stmt | 77.24 |
| branch | 71.01 |
| cond | 48.70 |
| expr | 63.83 |
| fsm_state | 88.64 |
| fsm_trans | 45.00 |
| toggle | 33.12 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

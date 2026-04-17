# ⚠️ CROSS bucket

**Planned:** `5` &nbsp; **Evidenced:** `5` &nbsp; **Status:** ⚠️

## Merged code coverage (this bucket)

<!-- column legend:
  metric          = code-coverage category (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle)
  merged_pct      = bucket-local ordered-merge percentage across all evidenced cases
  target          = workflow coverage target (blank = no hard target for that category)
  status          = target check vs merged_pct
-->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 86.01 | 95.0 |
| ⚠️ | branch | 74.85 | 90.0 |
| ℹ️ | cond | 51.85 | - |
| ℹ️ | expr | 70.91 | - |
| ⚠️ | fsm_state | 88.57 | 95.0 |
| ⚠️ | fsm_trans | 46.25 | 90.0 |
| ⚠️ | toggle | 51.18 | 80.0 |

## Ordered merge trace

<!-- each row is the merged coverage total after that case was added to the bucket in case-id order. -->

| status | step | case_id | merged_total (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle) | detail |
|:---:|---:|---|---|---|
| ✅ | 1 | `opq_cross_bp_credit_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=38.28 | [case](../cases/opq_cross_bp_credit_test.md) |
| ✅ | 2 | `opq_cross_drr_allowance_test` | stmt=85.79, branch=74.46, cond=51.85, expr=67.27, fsm_state=88.57, fsm_trans=46.25, toggle=47.84 | [case](../cases/opq_cross_drr_allowance_test.md) |
| ✅ | 3 | `opq_cross_drr_idle_lane_test` | stmt=85.90, branch=74.66, cond=51.85, expr=67.27, fsm_state=88.57, fsm_trans=46.25, toggle=49.03 | [case](../cases/opq_cross_drr_idle_lane_test.md) |
| ✅ | 4 | `opq_cross_drr_zero_allowance_test` | stmt=86.01, branch=74.85, cond=51.85, expr=70.91, fsm_state=88.57, fsm_trans=46.25, toggle=50.12 | [case](../cases/opq_cross_drr_zero_allowance_test.md) |
| ✅ | 5 | `opq_cross_drr_short_allowance_test` | stmt=86.01, branch=74.85, cond=51.85, expr=70.91, fsm_state=88.57, fsm_trans=46.25, toggle=51.18 | [case](../cases/opq_cross_drr_short_allowance_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

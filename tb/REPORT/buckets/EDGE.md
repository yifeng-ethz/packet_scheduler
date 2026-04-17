# ⚠️ EDGE bucket

**Planned:** `6` &nbsp; **Evidenced:** `6` &nbsp; **Status:** ⚠️

## Merged code coverage (this bucket)

<!-- column legend:
  metric          = code-coverage category (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle)
  merged_pct      = bucket-local ordered-merge percentage across all evidenced cases
  target          = workflow coverage target (blank = no hard target for that category)
  status          = target check vs merged_pct
-->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 83.64 | 95.0 |
| ⚠️ | branch | 71.73 | 90.0 |
| ℹ️ | cond | 48.68 | - |
| ℹ️ | expr | 70.91 | - |
| ⚠️ | fsm_state | 85.71 | 95.0 |
| ⚠️ | fsm_trans | 43.75 | 90.0 |
| ⚠️ | toggle | 43.87 | 80.0 |

## Ordered merge trace

<!-- each row is the merged coverage total after that case was added to the bucket in case-id order. -->

| status | step | case_id | merged_total (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle) | detail |
|:---:|---:|---|---|---|
| ✅ | 1 | `opq_edge_backpressure_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/opq_edge_backpressure_test.md) |
| ✅ | 2 | `opq_edge_always_ready_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/opq_edge_always_ready_test.md) |
| ✅ | 3 | `opq_edge_ready_medium_profile_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/opq_edge_ready_medium_profile_test.md) |
| ✅ | 4 | `opq_edge_stuck_low_backpressure_test` | stmt=83.53, branch=71.54, cond=47.62, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=39.20 | [case](../cases/opq_edge_stuck_low_backpressure_test.md) |
| ✅ | 5 | `opq_edge_max_hits_test` | stmt=83.64, branch=71.73, cond=48.68, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 | [case](../cases/opq_edge_max_hits_test.md) |
| ✅ | 6 | `opq_edge_toggle_backpressure_test` | stmt=83.64, branch=71.73, cond=48.68, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 | [case](../cases/opq_edge_toggle_backpressure_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

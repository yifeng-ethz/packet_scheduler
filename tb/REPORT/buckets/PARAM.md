# ⚠️ PARAM bucket

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
| ⚠️ | stmt | 84.28 | 95.0 |
| ⚠️ | branch | 72.12 | 90.0 |
| ℹ️ | cond | 48.15 | - |
| ℹ️ | expr | 70.91 | - |
| ⚠️ | fsm_state | 85.71 | 95.0 |
| ⚠️ | fsm_trans | 43.75 | 90.0 |
| ⚠️ | toggle | 46.76 | 80.0 |

## Ordered merge trace

<!-- each row is the merged coverage total after that case was added to the bucket in case-id order. -->

| status | step | case_id | merged_total (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle) | detail |
|:---:|---:|---|---|---|
| ✅ | 1 | `opq_basic_smoke_test_nshd128` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=37.77 | [case](../cases/opq_basic_smoke_test_nshd128.md) |
| ✅ | 2 | `opq_basic_smoke_test_nshd512` | stmt=83.75, branch=71.54, cond=46.56, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=40.66 | [case](../cases/opq_basic_smoke_test_nshd512.md) |
| ✅ | 3 | `opq_basic_ts_boundary_test_nshd128` | stmt=84.28, branch=72.12, cond=47.09, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.19 | [case](../cases/opq_basic_ts_boundary_test_nshd128.md) |
| ✅ | 4 | `opq_basic_ts_boundary_test_nshd512` | stmt=84.28, branch=72.12, cond=47.09, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.19 | [case](../cases/opq_basic_ts_boundary_test_nshd512.md) |
| ✅ | 5 | `opq_edge_max_hits_test_nshd128` | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 | [case](../cases/opq_edge_max_hits_test_nshd128.md) |
| ✅ | 6 | `opq_edge_max_hits_test_nshd512` | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 | [case](../cases/opq_edge_max_hits_test_nshd512.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

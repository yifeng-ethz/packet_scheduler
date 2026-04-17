# ⚠️ BASIC bucket

**Planned:** `4` &nbsp; **Evidenced:** `4` &nbsp; **Status:** ⚠️

## Merged code coverage (this bucket)

<!-- column legend:
  metric          = code-coverage category (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle)
  merged_pct      = bucket-local ordered-merge percentage across all evidenced cases
  target          = workflow coverage target (blank = no hard target for that category)
  status          = target check vs merged_pct
-->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 84.07 | 95.0 |
| ⚠️ | branch | 71.93 | 90.0 |
| ℹ️ | cond | 46.56 | - |
| ℹ️ | expr | 70.91 | - |
| ⚠️ | fsm_state | 85.71 | 95.0 |
| ⚠️ | fsm_trans | 43.75 | 90.0 |
| ⚠️ | toggle | 45.51 | 80.0 |

## Ordered merge trace

<!-- each row is the merged coverage total after that case was added to the bucket in case-id order. -->

| status | step | case_id | merged_total (stmt/branch/cond/expr/fsm_state/fsm_trans/toggle) | detail |
|:---:|---:|---|---|---|
| ✅ | 1 | `opq_basic_smoke_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.17 | [case](../cases/opq_basic_smoke_test.md) |
| ✅ | 2 | `opq_basic_ts_boundary_test` | stmt=84.07, branch=71.93, cond=46.03, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=41.71 | [case](../cases/opq_basic_ts_boundary_test.md) |
| ✅ | 3 | `opq_basic_subheader_shape_test` | stmt=84.07, branch=71.93, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=45.27 | [case](../cases/opq_basic_subheader_shape_test.md) |
| ✅ | 4 | `opq_basic_feb_packet_contract_test` | stmt=84.07, branch=71.93, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=45.51 | [case](../cases/opq_basic_feb_packet_contract_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

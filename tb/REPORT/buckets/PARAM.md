# ⚠️ PARAM bucket

**Catalog planned:** `180` &nbsp; **Promoted:** `6` &nbsp; **Evidenced:** `6` &nbsp; **Catalog backlog:** `174` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`DV_PARAM.md`](../../DV_PARAM.md)
- summary: Derived compile/elaboration matrix inventory: 3 testcase families x 3 N_SHD points x 5 N_LANE points x 2 MODE points x 2 TRACK_HEADER points.

## Ordered isolated baseline

- execution order: [`COMBO_OPQ_101_basic_smoke_test_nshd128`](../cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md), [`COMBO_OPQ_102_basic_smoke_test_nshd512`](../cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md), [`COMBO_OPQ_103_basic_ts_boundary_test_nshd128`](../cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md), [`COMBO_OPQ_104_basic_ts_boundary_test_nshd512`](../cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md), [`COMBO_OPQ_105_edge_max_hits_test_nshd128`](../cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md), [`COMBO_OPQ_106_edge_max_hits_test_nshd512`](../cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md)

## Merged code coverage (this bucket)

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

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_101_basic_smoke_test_nshd128` | `opq_basic_smoke_test_nshd128` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=37.77 | [case](../cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md) |
| ✅ | 2 | `COMBO_OPQ_102_basic_smoke_test_nshd512` | `opq_basic_smoke_test_nshd512` | stmt=83.75, branch=71.54, cond=46.56, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=40.66 | [case](../cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md) |
| ✅ | 3 | `COMBO_OPQ_103_basic_ts_boundary_test_nshd128` | `opq_basic_ts_boundary_test_nshd128` | stmt=84.28, branch=72.12, cond=47.09, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.19 | [case](../cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md) |
| ✅ | 4 | `COMBO_OPQ_104_basic_ts_boundary_test_nshd512` | `opq_basic_ts_boundary_test_nshd512` | stmt=84.28, branch=72.12, cond=47.09, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.19 | [case](../cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md) |
| ✅ | 5 | `COMBO_OPQ_105_edge_max_hits_test_nshd128` | `opq_edge_max_hits_test_nshd128` | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 | [case](../cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md) |
| ✅ | 6 | `COMBO_OPQ_106_edge_max_hits_test_nshd512` | `opq_edge_max_hits_test_nshd512` | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 | [case](../cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

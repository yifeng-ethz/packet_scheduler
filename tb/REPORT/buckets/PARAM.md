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
| ⚠️ | stmt | 71.98 | 95.0 |
| ⚠️ | branch | 64.49 | 90.0 |
| ℹ️ | cond | 33.94 | - |
| ℹ️ | expr | 50.35 | - |
| ⚠️ | fsm_state | 84.09 | 95.0 |
| ⚠️ | fsm_trans | 41.00 | 90.0 |
| ⚠️ | toggle | 25.23 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_101_basic_smoke_test_nshd128` | `opq_basic_smoke_test_nshd128` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=20.25 | [case](../cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md) |
| ✅ | 2 | `COMBO_OPQ_102_basic_smoke_test_nshd512` | `opq_basic_smoke_test_nshd512` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.29 | [case](../cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md) |
| ✅ | 3 | `COMBO_OPQ_103_basic_ts_boundary_test_nshd128` | `opq_basic_ts_boundary_test_nshd128` | stmt=71.94, branch=64.25, cond=32.38, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=22.73 | [case](../cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md) |
| ✅ | 4 | `COMBO_OPQ_104_basic_ts_boundary_test_nshd512` | `opq_basic_ts_boundary_test_nshd512` | stmt=71.94, branch=64.25, cond=32.38, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=22.74 | [case](../cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md) |
| ✅ | 5 | `COMBO_OPQ_105_edge_max_hits_test_nshd128` | `opq_edge_max_hits_test_nshd128` | stmt=71.98, branch=64.49, cond=33.94, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.22 | [case](../cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md) |
| ✅ | 6 | `COMBO_OPQ_106_edge_max_hits_test_nshd512` | `opq_edge_max_hits_test_nshd512` | stmt=71.98, branch=64.49, cond=33.94, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.23 | [case](../cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

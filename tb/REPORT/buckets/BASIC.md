# ⚠️ BASIC bucket

**Catalog planned:** `146` &nbsp; **Promoted:** `7` &nbsp; **Evidenced:** `7` &nbsp; **Catalog backlog:** `139` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_BASIC.md`](../../legacy/tb/DV_BASIC.md)
- summary: Archived directed BASIC catalog preserved in tb/legacy/tb/DV_BASIC.md.

## Ordered isolated baseline

- execution order: [`STD_OPQ_001_basic_smoke_test`](../cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](../cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](../cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md), [`STD_OPQ_005_basic_single_active_lane_test`](../cases/STD_OPQ_005_basic_single_active_lane_test.md), [`STD_OPQ_006_basic_single_active_lane_lane1_test`](../cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md), [`STD_OPQ_007_basic_single_active_lane_dense_test`](../cases/STD_OPQ_007_basic_single_active_lane_dense_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 76.78 | 95.0 |
| ⚠️ | branch | 68.80 | 90.0 |
| ℹ️ | cond | 39.09 | - |
| ℹ️ | expr | 58.33 | - |
| ⚠️ | fsm_state | 86.36 | 95.0 |
| ⚠️ | fsm_trans | 44.00 | 90.0 |
| ⚠️ | toggle | 33.73 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `STD_OPQ_001_basic_smoke_test` | `opq_basic_smoke_test` | stmt=74.09, branch=64.44, cond=32.29, expr=54.17, fsm_state=84.09, fsm_trans=41.00, toggle=25.02 | [case](../cases/STD_OPQ_001_basic_smoke_test.md) |
| ✅ | 2 | `STD_OPQ_002_basic_ts_boundary_test` | `opq_basic_ts_boundary_test` | stmt=74.39, branch=64.85, cond=32.86, expr=57.29, fsm_state=84.09, fsm_trans=41.00, toggle=26.65 | [case](../cases/STD_OPQ_002_basic_ts_boundary_test.md) |
| ✅ | 3 | `STD_OPQ_003_basic_subheader_shape_test` | `opq_basic_subheader_shape_test` | stmt=75.91, branch=67.30, cond=37.39, expr=58.33, fsm_state=84.09, fsm_trans=42.00, toggle=29.09 | [case](../cases/STD_OPQ_003_basic_subheader_shape_test.md) |
| ✅ | 4 | `STD_OPQ_004_basic_feb_packet_contract_test` | `opq_basic_feb_packet_contract_test` | stmt=75.91, branch=67.30, cond=37.39, expr=58.33, fsm_state=84.09, fsm_trans=42.00, toggle=29.94 | [case](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md) |
| ✅ | 5 | `STD_OPQ_005_basic_single_active_lane_test` | `opq_basic_single_active_lane_test` | stmt=75.96, branch=67.44, cond=37.39, expr=58.33, fsm_state=84.09, fsm_trans=42.00, toggle=31.19 | [case](../cases/STD_OPQ_005_basic_single_active_lane_test.md) |
| ✅ | 6 | `STD_OPQ_006_basic_single_active_lane_lane1_test` | `opq_basic_single_active_lane_lane1_test` | stmt=76.02, branch=67.57, cond=37.39, expr=58.33, fsm_state=84.09, fsm_trans=42.00, toggle=32.85 | [case](../cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md) |
| ✅ | 7 | `STD_OPQ_007_basic_single_active_lane_dense_test` | `opq_basic_single_active_lane_dense_test` | stmt=76.78, branch=68.80, cond=39.09, expr=58.33, fsm_state=86.36, fsm_trans=44.00, toggle=33.73 | [case](../cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

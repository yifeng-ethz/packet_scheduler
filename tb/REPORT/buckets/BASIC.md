# ⚠️ BASIC bucket

**Catalog planned:** `146` &nbsp; **Promoted:** `7` &nbsp; **Evidenced:** `4` &nbsp; **Catalog backlog:** `139` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_BASIC.md`](../../legacy/tb/DV_BASIC.md)
- summary: Archived directed BASIC catalog preserved in tb/legacy/tb/DV_BASIC.md.

## Ordered isolated baseline

- execution order: [`STD_OPQ_001_basic_smoke_test`](../cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](../cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](../cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md), [`STD_OPQ_005_basic_single_active_lane_test`](../cases/STD_OPQ_005_basic_single_active_lane_test.md), [`STD_OPQ_006_basic_single_active_lane_lane1_test`](../cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md), [`STD_OPQ_007_basic_single_active_lane_dense_test`](../cases/STD_OPQ_007_basic_single_active_lane_dense_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 72.71 | 95.0 |
| ⚠️ | branch | 65.70 | 90.0 |
| ℹ️ | cond | 36.53 | - |
| ℹ️ | expr | 51.06 | - |
| ⚠️ | fsm_state | 84.09 | 95.0 |
| ⚠️ | fsm_trans | 42.00 | 90.0 |
| ⚠️ | toggle | 26.75 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `STD_OPQ_001_basic_smoke_test` | `opq_basic_smoke_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.76 | [case](../cases/STD_OPQ_001_basic_smoke_test.md) |
| ✅ | 2 | `STD_OPQ_002_basic_ts_boundary_test` | `opq_basic_ts_boundary_test` | stmt=71.94, branch=64.25, cond=32.38, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=23.53 | [case](../cases/STD_OPQ_002_basic_ts_boundary_test.md) |
| ✅ | 3 | `STD_OPQ_003_basic_subheader_shape_test` | `opq_basic_subheader_shape_test` | stmt=72.71, branch=65.70, cond=36.53, expr=51.06, fsm_state=84.09, fsm_trans=42.00, toggle=26.33 | [case](../cases/STD_OPQ_003_basic_subheader_shape_test.md) |
| ✅ | 4 | `STD_OPQ_004_basic_feb_packet_contract_test` | `opq_basic_feb_packet_contract_test` | stmt=72.71, branch=65.70, cond=36.53, expr=51.06, fsm_state=84.09, fsm_trans=42.00, toggle=26.75 | [case](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

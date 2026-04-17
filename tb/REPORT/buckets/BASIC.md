# ⚠️ BASIC bucket

**Catalog planned:** `146` &nbsp; **Promoted:** `4` &nbsp; **Evidenced:** `4` &nbsp; **Catalog backlog:** `142` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_BASIC.md`](../../legacy/tb/DV_BASIC.md)
- summary: Archived directed BASIC catalog preserved in tb/legacy/tb/DV_BASIC.md.

## Ordered isolated baseline

- execution order: [`STD_OPQ_001_basic_smoke_test`](../cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](../cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](../cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md)

## Merged code coverage (this bucket)

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

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `STD_OPQ_001_basic_smoke_test` | `opq_basic_smoke_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.17 | [case](../cases/STD_OPQ_001_basic_smoke_test.md) |
| ✅ | 2 | `STD_OPQ_002_basic_ts_boundary_test` | `opq_basic_ts_boundary_test` | stmt=84.07, branch=71.93, cond=46.03, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=41.71 | [case](../cases/STD_OPQ_002_basic_ts_boundary_test.md) |
| ✅ | 3 | `STD_OPQ_003_basic_subheader_shape_test` | `opq_basic_subheader_shape_test` | stmt=84.07, branch=71.93, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=45.27 | [case](../cases/STD_OPQ_003_basic_subheader_shape_test.md) |
| ✅ | 4 | `STD_OPQ_004_basic_feb_packet_contract_test` | `opq_basic_feb_packet_contract_test` | stmt=84.07, branch=71.93, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=45.51 | [case](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

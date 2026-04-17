# ⚠️ EDGE bucket

**Catalog planned:** `168` &nbsp; **Promoted:** `6` &nbsp; **Evidenced:** `6` &nbsp; **Catalog backlog:** `162` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_EDGE.md`](../../legacy/tb/DV_EDGE.md)
- summary: Archived directed EDGE catalog preserved in tb/legacy/tb/DV_EDGE.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_201_edge_backpressure_test`](../cases/CORNER_OPQ_201_edge_backpressure_test.md), [`CORNER_OPQ_202_edge_always_ready_test`](../cases/CORNER_OPQ_202_edge_always_ready_test.md), [`CORNER_OPQ_203_edge_ready_medium_profile_test`](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md), [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md), [`CORNER_OPQ_205_edge_max_hits_test`](../cases/CORNER_OPQ_205_edge_max_hits_test.md), [`CORNER_OPQ_206_edge_toggle_backpressure_test`](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md)

## Merged code coverage (this bucket)

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

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_201_edge_backpressure_test` | `opq_edge_backpressure_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/CORNER_OPQ_201_edge_backpressure_test.md) |
| ✅ | 2 | `CORNER_OPQ_202_edge_always_ready_test` | `opq_edge_always_ready_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/CORNER_OPQ_202_edge_always_ready_test.md) |
| ✅ | 3 | `CORNER_OPQ_203_edge_ready_medium_profile_test` | `opq_edge_ready_medium_profile_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=39.19 | [case](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) |
| ✅ | 4 | `CORNER_OPQ_204_edge_stuck_low_backpressure_test` | `opq_edge_stuck_low_backpressure_test` | stmt=83.53, branch=71.54, cond=47.62, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=39.20 | [case](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) |
| ✅ | 5 | `CORNER_OPQ_205_edge_max_hits_test` | `opq_edge_max_hits_test` | stmt=83.64, branch=71.73, cond=48.68, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 | [case](../cases/CORNER_OPQ_205_edge_max_hits_test.md) |
| ✅ | 6 | `CORNER_OPQ_206_edge_toggle_backpressure_test` | `opq_edge_toggle_backpressure_test` | stmt=83.64, branch=71.73, cond=48.68, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 | [case](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

# ⚠️ EDGE bucket

**Catalog planned:** `168` &nbsp; **Promoted:** `9` &nbsp; **Evidenced:** `6` &nbsp; **Catalog backlog:** `159` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_EDGE.md`](../../legacy/tb/DV_EDGE.md)
- summary: Archived directed EDGE catalog preserved in tb/legacy/tb/DV_EDGE.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_201_edge_backpressure_test`](../cases/CORNER_OPQ_201_edge_backpressure_test.md), [`CORNER_OPQ_202_edge_always_ready_test`](../cases/CORNER_OPQ_202_edge_always_ready_test.md), [`CORNER_OPQ_203_edge_ready_medium_profile_test`](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md), [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md), [`CORNER_OPQ_205_edge_max_hits_test`](../cases/CORNER_OPQ_205_edge_max_hits_test.md), [`CORNER_OPQ_206_edge_toggle_backpressure_test`](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md), [`CORNER_OPQ_207_edge_burst_restart_profile_test`](../cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md), [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](../cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md), [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](../cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 71.74 | 95.0 |
| ⚠️ | branch | 64.13 | 90.0 |
| ℹ️ | cond | 33.42 | - |
| ℹ️ | expr | 50.35 | - |
| ⚠️ | fsm_state | 84.09 | 95.0 |
| ⚠️ | fsm_trans | 41.00 | 90.0 |
| ⚠️ | toggle | 25.10 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_201_edge_backpressure_test` | `opq_edge_backpressure_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.78 | [case](../cases/CORNER_OPQ_201_edge_backpressure_test.md) |
| ✅ | 2 | `CORNER_OPQ_202_edge_always_ready_test` | `opq_edge_always_ready_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.78 | [case](../cases/CORNER_OPQ_202_edge_always_ready_test.md) |
| ✅ | 3 | `CORNER_OPQ_203_edge_ready_medium_profile_test` | `opq_edge_ready_medium_profile_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.78 | [case](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) |
| ✅ | 4 | `CORNER_OPQ_204_edge_stuck_low_backpressure_test` | `opq_edge_stuck_low_backpressure_test` | stmt=71.64, branch=63.89, cond=31.87, expr=49.65, fsm_state=84.09, fsm_trans=41.00, toggle=21.81 | [case](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) |
| ✅ | 5 | `CORNER_OPQ_205_edge_max_hits_test` | `opq_edge_max_hits_test` | stmt=71.74, branch=64.13, cond=33.42, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.10 | [case](../cases/CORNER_OPQ_205_edge_max_hits_test.md) |
| ✅ | 6 | `CORNER_OPQ_206_edge_toggle_backpressure_test` | `opq_edge_toggle_backpressure_test` | stmt=71.74, branch=64.13, cond=33.42, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.10 | [case](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

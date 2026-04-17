# ⚠️ ERROR bucket

**Catalog planned:** `166` &nbsp; **Promoted:** `7` &nbsp; **Evidenced:** `7` &nbsp; **Catalog backlog:** `159` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_ERROR.md`](../../legacy/tb/DV_ERROR.md)
- summary: Archived directed ERROR catalog preserved in tb/legacy/tb/DV_ERROR.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_406_error_counter_clear_test`](../cases/CORNER_OPQ_406_error_counter_clear_test.md), [`CORNER_OPQ_407_error_ftable_overflow_test`](../cases/CORNER_OPQ_407_error_ftable_overflow_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 85.44 | 95.0 |
| ⚠️ | branch | 76.11 | 90.0 |
| ℹ️ | cond | 53.88 | - |
| ℹ️ | expr | 69.44 | - |
| ⚠️ | fsm_state | 91.43 | 95.0 |
| ⚠️ | fsm_trans | 48.75 | 90.0 |
| ⚠️ | toggle | 46.04 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_401_error_lane_mask_test` | `opq_error_lane_mask_test` | stmt=52.74, branch=35.67, cond=4.76, expr=14.55, fsm_state=34.29, fsm_trans=6.25, toggle=6.51 | [case](../cases/CORNER_OPQ_401_error_lane_mask_test.md) |
| ✅ | 2 | `CORNER_OPQ_402_error_lane_mask_single_hit_test` | `opq_error_lane_mask_single_hit_test` | stmt=52.74, branch=35.67, cond=4.76, expr=14.55, fsm_state=34.29, fsm_trans=6.25, toggle=6.53 | [case](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) |
| ✅ | 3 | `CORNER_OPQ_403_error_lane_mask_burst_test` | `opq_error_lane_mask_burst_test` | stmt=52.74, branch=35.67, cond=4.76, expr=14.55, fsm_state=34.29, fsm_trans=6.25, toggle=7.92 | [case](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) |
| ✅ | 4 | `CORNER_OPQ_404_error_lane_mask_recovery_test` | `opq_error_lane_mask_recovery_test` | stmt=84.28, branch=72.51, cond=47.09, expr=74.55, fsm_state=85.71, fsm_trans=43.75, toggle=39.59 | [case](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) |
| ✅ | 5 | `CORNER_OPQ_405_error_subheader_mask_recovery_test` | `opq_error_subheader_mask_recovery_test` | stmt=86.44, branch=76.41, cond=50.26, expr=74.55, fsm_state=91.43, fsm_trans=48.75, toggle=41.11 | [case](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) |
| ✅ | 6 | `CORNER_OPQ_406_error_counter_clear_test` | `opq_error_counter_clear_test` | stmt=86.54, branch=76.61, cond=50.26, expr=74.55, fsm_state=91.43, fsm_trans=48.75, toggle=41.13 | [case](../cases/CORNER_OPQ_406_error_counter_clear_test.md) |
| ✅ | 7 | `CORNER_OPQ_407_error_ftable_overflow_test` | `opq_error_ftable_overflow_test` | stmt=85.44, branch=76.11, cond=53.88, expr=69.44, fsm_state=91.43, fsm_trans=48.75, toggle=46.04 | [case](../cases/CORNER_OPQ_407_error_ftable_overflow_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

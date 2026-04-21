# ⚠️ ERROR bucket

**Catalog planned:** `166` &nbsp; **Promoted:** `10` &nbsp; **Evidenced:** `7` &nbsp; **Catalog backlog:** `156` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_ERROR.md`](../../legacy/tb/DV_ERROR.md)
- summary: Archived directed ERROR catalog preserved in tb/legacy/tb/DV_ERROR.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_hit_mask_recovery_test`](../cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md), [`CORNER_OPQ_406_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_407_error_header_mask_recovery_test`](../cases/CORNER_OPQ_407_error_header_mask_recovery_test.md), [`CORNER_OPQ_408_error_header_word_mask_recovery_test`](../cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md), [`CORNER_OPQ_409_error_counter_clear_test`](../cases/CORNER_OPQ_409_error_counter_clear_test.md), [`CORNER_OPQ_410_error_ftable_overflow_test`](../cases/CORNER_OPQ_410_error_ftable_overflow_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 76.99 | 95.0 |
| ⚠️ | branch | 71.86 | 90.0 |
| ℹ️ | cond | 41.97 | - |
| ℹ️ | expr | 60.28 | - |
| ⚠️ | fsm_state | 90.91 | 95.0 |
| ⚠️ | fsm_trans | 47.00 | 90.0 |
| ⚠️ | toggle | 30.33 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_401_error_lane_mask_test` | `opq_error_lane_mask_test` | stmt=45.53, branch=31.88, cond=7.77, expr=12.77, fsm_state=29.55, fsm_trans=5.00, toggle=3.03 | [case](../cases/CORNER_OPQ_401_error_lane_mask_test.md) |
| ✅ | 2 | `CORNER_OPQ_402_error_lane_mask_single_hit_test` | `opq_error_lane_mask_single_hit_test` | stmt=45.53, branch=31.88, cond=7.77, expr=12.77, fsm_state=29.55, fsm_trans=5.00, toggle=3.15 | [case](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) |
| ✅ | 3 | `CORNER_OPQ_403_error_lane_mask_burst_test` | `opq_error_lane_mask_burst_test` | stmt=45.53, branch=31.88, cond=7.77, expr=12.77, fsm_state=29.55, fsm_trans=5.00, toggle=4.27 | [case](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) |
| ✅ | 4 | `CORNER_OPQ_404_error_lane_mask_recovery_test` | `opq_error_lane_mask_recovery_test` | stmt=73.93, branch=67.15, cond=37.82, expr=53.90, fsm_state=84.09, fsm_trans=41.00, toggle=22.48 | [case](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) |
| ✅ | 6 | `CORNER_OPQ_406_error_subheader_mask_recovery_test` | `opq_error_subheader_mask_recovery_test` | stmt=75.19, branch=69.93, cond=39.38, expr=56.03, fsm_state=88.64, fsm_trans=45.00, toggle=23.49 | [case](../cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md) |
| ✅ | 9 | `CORNER_OPQ_409_error_counter_clear_test` | `opq_error_counter_clear_test` | stmt=75.24, branch=70.05, cond=39.38, expr=56.03, fsm_state=88.64, fsm_trans=45.00, toggle=23.50 | [case](../cases/CORNER_OPQ_409_error_counter_clear_test.md) |
| ✅ | 10 | `CORNER_OPQ_410_error_ftable_overflow_test` | `opq_error_ftable_overflow_test` | stmt=76.99, branch=71.86, cond=41.97, expr=60.28, fsm_state=90.91, fsm_trans=47.00, toggle=30.33 | [case](../cases/CORNER_OPQ_410_error_ftable_overflow_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

# ⚠️ ERROR bucket

**Catalog planned:** `166` &nbsp; **Promoted:** `10` &nbsp; **Evidenced:** `10` &nbsp; **Catalog backlog:** `156` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_ERROR.md`](../../legacy/tb/DV_ERROR.md)
- summary: Archived directed ERROR catalog preserved in tb/legacy/tb/DV_ERROR.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_hit_mask_recovery_test`](../cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md), [`CORNER_OPQ_406_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_407_error_header_mask_recovery_test`](../cases/CORNER_OPQ_407_error_header_mask_recovery_test.md), [`CORNER_OPQ_408_error_header_word_mask_recovery_test`](../cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md), [`CORNER_OPQ_409_error_counter_clear_test`](../cases/CORNER_OPQ_409_error_counter_clear_test.md), [`CORNER_OPQ_410_error_ftable_overflow_test`](../cases/CORNER_OPQ_410_error_ftable_overflow_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 82.54 | 95.0 |
| ⚠️ | branch | 75.09 | 90.0 |
| ℹ️ | cond | 44.50 | - |
| ℹ️ | expr | 59.48 | - |
| ✅ | fsm_state | 95.45 | 95.0 |
| ⚠️ | fsm_trans | 58.00 | 90.0 |
| ⚠️ | toggle | 31.98 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_401_error_lane_mask_test` | `opq_error_lane_mask_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=4.11 | [case](../cases/CORNER_OPQ_401_error_lane_mask_test.md) |
| ✅ | 2 | `CORNER_OPQ_402_error_lane_mask_single_hit_test` | `opq_error_lane_mask_single_hit_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=4.19 | [case](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) |
| ✅ | 3 | `CORNER_OPQ_403_error_lane_mask_burst_test` | `opq_error_lane_mask_burst_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=5.16 | [case](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) |
| ✅ | 4 | `CORNER_OPQ_404_error_lane_mask_recovery_test` | `opq_error_lane_mask_recovery_test` | stmt=76.61, branch=68.26, cond=39.09, expr=64.58, fsm_state=84.09, fsm_trans=41.00, toggle=25.78 | [case](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) |
| ✅ | 5 | `CORNER_OPQ_405_error_hit_mask_recovery_test` | `opq_error_hit_mask_recovery_test` | stmt=76.53, branch=67.57, cond=37.43, expr=55.17, fsm_state=84.09, fsm_trans=41.00, toggle=25.28 | [case](../cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md) |
| ✅ | 6 | `CORNER_OPQ_406_error_subheader_mask_recovery_test` | `opq_error_subheader_mask_recovery_test` | stmt=77.77, branch=70.53, cond=39.27, expr=56.03, fsm_state=88.64, fsm_trans=45.00, toggle=25.60 | [case](../cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md) |
| ✅ | 7 | `CORNER_OPQ_407_error_header_mask_recovery_test` | `opq_error_header_mask_recovery_test` | stmt=78.83, branch=72.75, cond=41.36, expr=56.03, fsm_state=93.18, fsm_trans=50.00, toggle=25.68 | [case](../cases/CORNER_OPQ_407_error_header_mask_recovery_test.md) |
| ✅ | 8 | `CORNER_OPQ_408_error_header_word_mask_recovery_test` | `opq_error_header_word_mask_recovery_test` | stmt=79.06, branch=73.24, cond=41.36, expr=56.03, fsm_state=93.18, fsm_trans=56.00, toggle=25.68 | [case](../cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md) |
| ✅ | 9 | `CORNER_OPQ_409_error_counter_clear_test` | `opq_error_counter_clear_test` | stmt=79.11, branch=73.37, cond=41.36, expr=56.03, fsm_state=93.18, fsm_trans=56.00, toggle=25.69 | [case](../cases/CORNER_OPQ_409_error_counter_clear_test.md) |
| ✅ | 10 | `CORNER_OPQ_410_error_ftable_overflow_test` | `opq_error_ftable_overflow_test` | stmt=82.54, branch=75.09, cond=44.50, expr=59.48, fsm_state=95.45, fsm_trans=58.00, toggle=31.98 | [case](../cases/CORNER_OPQ_410_error_ftable_overflow_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

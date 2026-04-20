# ⚠️ ERROR bucket

**Catalog planned:** `166` &nbsp; **Promoted:** `9` &nbsp; **Evidenced:** `8` &nbsp; **Catalog backlog:** `157` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_ERROR.md`](../../legacy/tb/DV_ERROR.md)
- summary: Archived directed ERROR catalog preserved in tb/legacy/tb/DV_ERROR.md.

## Ordered isolated baseline

- execution order: [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_406_error_header_mask_recovery_test`](../cases/CORNER_OPQ_406_error_header_mask_recovery_test.md), [`CORNER_OPQ_407_error_header_word_mask_recovery_test`](../cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md), [`CORNER_OPQ_408_error_counter_clear_test`](../cases/CORNER_OPQ_408_error_counter_clear_test.md), [`CORNER_OPQ_409_error_ftable_overflow_test`](../cases/CORNER_OPQ_409_error_ftable_overflow_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 79.30 | 95.0 |
| ⚠️ | branch | 74.66 | 90.0 |
| ℹ️ | cond | 43.34 | - |
| ℹ️ | expr | 65.62 | - |
| ⚠️ | fsm_state | 93.18 | 95.0 |
| ⚠️ | fsm_trans | 56.00 | 90.0 |
| ⚠️ | toggle | 26.96 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `CORNER_OPQ_401_error_lane_mask_test` | `opq_error_lane_mask_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=4.11 | [case](../cases/CORNER_OPQ_401_error_lane_mask_test.md) |
| ✅ | 2 | `CORNER_OPQ_402_error_lane_mask_single_hit_test` | `opq_error_lane_mask_single_hit_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=4.19 | [case](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) |
| ✅ | 3 | `CORNER_OPQ_403_error_lane_mask_burst_test` | `opq_error_lane_mask_burst_test` | stmt=47.66, branch=32.70, cond=8.50, expr=18.75, fsm_state=29.55, fsm_trans=5.00, toggle=5.16 | [case](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) |
| ✅ | 4 | `CORNER_OPQ_404_error_lane_mask_recovery_test` | `opq_error_lane_mask_recovery_test` | stmt=76.61, branch=68.26, cond=39.09, expr=64.58, fsm_state=84.09, fsm_trans=41.00, toggle=25.78 | [case](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) |
| ✅ | 5 | `CORNER_OPQ_405_error_subheader_mask_recovery_test` | `opq_error_subheader_mask_recovery_test` | stmt=77.89, branch=71.53, cond=41.08, expr=65.62, fsm_state=88.64, fsm_trans=45.00, toggle=26.76 | [case](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) |
| ✅ | 6 | `CORNER_OPQ_406_error_header_mask_recovery_test` | `opq_error_header_mask_recovery_test` | stmt=79.01, branch=73.98, cond=43.34, expr=65.62, fsm_state=93.18, fsm_trans=50.00, toggle=26.91 | [case](../cases/CORNER_OPQ_406_error_header_mask_recovery_test.md) |
| ✅ | 7 | `CORNER_OPQ_407_error_header_word_mask_recovery_test` | `opq_error_header_word_mask_recovery_test` | stmt=79.24, branch=74.52, cond=43.34, expr=65.62, fsm_state=93.18, fsm_trans=56.00, toggle=26.95 | [case](../cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md) |
| ✅ | 8 | `CORNER_OPQ_408_error_counter_clear_test` | `opq_error_counter_clear_test` | stmt=79.30, branch=74.66, cond=43.34, expr=65.62, fsm_state=93.18, fsm_trans=56.00, toggle=26.96 | [case](../cases/CORNER_OPQ_408_error_counter_clear_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

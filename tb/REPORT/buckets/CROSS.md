# ⚠️ CROSS bucket

**Catalog planned:** `165` &nbsp; **Promoted:** `9` &nbsp; **Evidenced:** `8` &nbsp; **Catalog backlog:** `156` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_CROSS.md`](../../legacy/tb/DV_CROSS.md)
- summary: Archived chained CROSS catalog preserved in tb/legacy/tb/DV_CROSS.md.

## Ordered isolated baseline

- execution order: [`COMBO_OPQ_501_cross_bp_credit_test`](../cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md), [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](../cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md), [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md), [`COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test`](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md), [`COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test`](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 82.59 | 95.0 |
| ⚠️ | branch | 81.04 | 90.0 |
| ℹ️ | cond | 58.81 | - |
| ℹ️ | expr | 75.18 | - |
| ⚠️ | fsm_state | 93.18 | 95.0 |
| ⚠️ | fsm_trans | 50.00 | 90.0 |
| ⚠️ | toggle | 49.09 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_501_cross_bp_credit_test` | `opq_cross_bp_credit_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.15 | [case](../cases/COMBO_OPQ_501_cross_bp_credit_test.md) |
| ✅ | 2 | `COMBO_OPQ_502_cross_drr_allowance_test` | `opq_cross_drr_allowance_test` | stmt=74.22, branch=67.63, cond=40.41, expr=50.35, fsm_state=86.36, fsm_trans=43.00, toggle=28.11 | [case](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md) |
| ✅ | 3 | `COMBO_OPQ_503_cross_drr_idle_lane_test` | `opq_cross_drr_idle_lane_test` | stmt=74.32, branch=67.87, cond=40.41, expr=50.35, fsm_state=86.36, fsm_trans=43.00, toggle=29.11 | [case](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) |
| ✅ | 4 | `COMBO_OPQ_504_cross_drr_zero_allowance_test` | `opq_cross_drr_zero_allowance_test` | stmt=74.42, branch=68.12, cond=40.41, expr=51.06, fsm_state=86.36, fsm_trans=43.00, toggle=29.84 | [case](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) |
| ✅ | 5 | `COMBO_OPQ_505_cross_drr_short_allowance_test` | `opq_cross_drr_short_allowance_test` | stmt=74.42, branch=68.24, cond=40.67, expr=51.06, fsm_state=86.36, fsm_trans=43.00, toggle=30.84 | [case](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) |
| ✅ | 7 | `COMBO_OPQ_507_cross_mixed_bucket_random_soak_test` | `opq_cross_mixed_bucket_random_soak_test` | stmt=78.84, branch=76.81, cond=54.15, expr=70.21, fsm_state=90.91, fsm_trans=48.00, toggle=44.88 | [case](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) |
| ✅ | 8 | `COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test` | `opq_cross_drr_bursty_frame2_boundary_test` | stmt=82.20, branch=80.07, cond=56.99, expr=73.05, fsm_state=93.18, fsm_trans=50.00, toggle=45.54 | [case](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md) |
| ✅ | 9 | `COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test` | `opq_cross_random_ready_overflow_step2_boundary_test` | stmt=82.59, branch=81.04, cond=58.81, expr=75.18, fsm_state=93.18, fsm_trans=50.00, toggle=49.09 | [case](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

# ⚠️ CROSS bucket

**Catalog planned:** `165` &nbsp; **Promoted:** `9` &nbsp; **Evidenced:** `9` &nbsp; **Catalog backlog:** `156` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_CROSS.md`](../../legacy/tb/DV_CROSS.md)
- summary: Archived chained CROSS catalog preserved in tb/legacy/tb/DV_CROSS.md.

## Ordered isolated baseline

- execution order: [`COMBO_OPQ_501_cross_bp_credit_test`](../cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md), [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](../cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md), [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md), [`COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test`](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md), [`COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test`](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 77.61 | 95.0 |
| ⚠️ | branch | 73.24 | 90.0 |
| ℹ️ | cond | 48.32 | - |
| ℹ️ | expr | 70.34 | - |
| ⚠️ | fsm_state | 90.91 | 95.0 |
| ⚠️ | fsm_trans | 47.00 | 90.0 |
| ⚠️ | toggle | 49.87 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_501_cross_bp_credit_test` | `opq_cross_bp_credit_test` | stmt=71.36, branch=63.13, cond=32.02, expr=53.06, fsm_state=84.09, fsm_trans=41.00, toggle=25.16 | [case](../cases/COMBO_OPQ_501_cross_bp_credit_test.md) |
| ✅ | 2 | `COMBO_OPQ_502_cross_drr_allowance_test` | `opq_cross_drr_allowance_test` | stmt=74.14, branch=67.24, cond=41.57, expr=58.16, fsm_state=86.36, fsm_trans=43.00, toggle=30.98 | [case](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md) |
| ✅ | 3 | `COMBO_OPQ_503_cross_drr_idle_lane_test` | `opq_cross_drr_idle_lane_test` | stmt=74.25, branch=67.51, cond=41.57, expr=58.16, fsm_state=86.36, fsm_trans=43.00, toggle=31.83 | [case](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) |
| ✅ | 4 | `COMBO_OPQ_504_cross_drr_zero_allowance_test` | `opq_cross_drr_zero_allowance_test` | stmt=74.36, branch=67.77, cond=41.57, expr=59.18, fsm_state=86.36, fsm_trans=43.00, toggle=32.49 | [case](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) |
| ✅ | 5 | `COMBO_OPQ_505_cross_drr_short_allowance_test` | `opq_cross_drr_short_allowance_test` | stmt=74.36, branch=67.90, cond=41.85, expr=59.18, fsm_state=86.36, fsm_trans=43.00, toggle=33.52 | [case](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) |
| ✅ | 6 | `COMBO_OPQ_506_cross_idle_lane_backpressure_test` | `opq_cross_idle_lane_backpressure_test` | stmt=74.36, branch=67.90, cond=41.85, expr=59.18, fsm_state=86.36, fsm_trans=43.00, toggle=33.58 | [case](../cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) |
| ✅ | 7 | `COMBO_OPQ_507_cross_mixed_bucket_random_soak_test` | `opq_cross_mixed_bucket_random_soak_test` | stmt=75.74, branch=70.91, cond=44.36, expr=67.24, fsm_state=90.91, fsm_trans=47.00, toggle=44.93 | [case](../cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) |
| ✅ | 8 | `COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test` | `opq_cross_drr_bursty_frame2_boundary_test` | stmt=76.27, branch=71.88, cond=46.98, expr=68.10, fsm_state=90.91, fsm_trans=47.00, toggle=45.33 | [case](../cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md) |
| ✅ | 9 | `COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test` | `opq_cross_random_ready_overflow_step2_boundary_test` | stmt=77.61, branch=73.24, cond=48.32, expr=70.34, fsm_state=90.91, fsm_trans=47.00, toggle=49.87 | [case](../cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

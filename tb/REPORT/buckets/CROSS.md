# ⚠️ CROSS bucket

**Catalog planned:** `165` &nbsp; **Promoted:** `5` &nbsp; **Evidenced:** `5` &nbsp; **Catalog backlog:** `160` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_CROSS.md`](../../legacy/tb/DV_CROSS.md)
- summary: Archived chained CROSS catalog preserved in tb/legacy/tb/DV_CROSS.md.

## Ordered isolated baseline

- execution order: [`COMBO_OPQ_501_cross_bp_credit_test`](../cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 86.01 | 95.0 |
| ⚠️ | branch | 74.85 | 90.0 |
| ℹ️ | cond | 51.85 | - |
| ℹ️ | expr | 70.91 | - |
| ⚠️ | fsm_state | 88.57 | 95.0 |
| ⚠️ | fsm_trans | 46.25 | 90.0 |
| ⚠️ | toggle | 51.18 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_501_cross_bp_credit_test` | `opq_cross_bp_credit_test` | stmt=83.53, branch=71.35, cond=45.50, expr=67.27, fsm_state=85.71, fsm_trans=43.75, toggle=38.28 | [case](../cases/COMBO_OPQ_501_cross_bp_credit_test.md) |
| ✅ | 2 | `COMBO_OPQ_502_cross_drr_allowance_test` | `opq_cross_drr_allowance_test` | stmt=85.79, branch=74.46, cond=51.85, expr=67.27, fsm_state=88.57, fsm_trans=46.25, toggle=47.84 | [case](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md) |
| ✅ | 3 | `COMBO_OPQ_503_cross_drr_idle_lane_test` | `opq_cross_drr_idle_lane_test` | stmt=85.90, branch=74.66, cond=51.85, expr=67.27, fsm_state=88.57, fsm_trans=46.25, toggle=49.03 | [case](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) |
| ✅ | 4 | `COMBO_OPQ_504_cross_drr_zero_allowance_test` | `opq_cross_drr_zero_allowance_test` | stmt=86.01, branch=74.85, cond=51.85, expr=70.91, fsm_state=88.57, fsm_trans=46.25, toggle=50.12 | [case](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) |
| ✅ | 5 | `COMBO_OPQ_505_cross_drr_short_allowance_test` | `opq_cross_drr_short_allowance_test` | stmt=86.01, branch=74.85, cond=51.85, expr=70.91, fsm_state=88.57, fsm_trans=46.25, toggle=51.18 | [case](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

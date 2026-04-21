# ⚠️ PROF bucket

**Catalog planned:** `168` &nbsp; **Promoted:** `8` &nbsp; **Evidenced:** `4` &nbsp; **Catalog backlog:** `160` &nbsp; **Status:** ⚠️

## Catalog Inventory

- source: [`legacy/tb/DV_PROF.md`](../../legacy/tb/DV_PROF.md)
- summary: Archived directed PROF catalog preserved in tb/legacy/tb/DV_PROF.md.

## Ordered isolated baseline

- execution order: [`COMBO_OPQ_301_prof_stress_test`](../cases/COMBO_OPQ_301_prof_stress_test.md), [`COMBO_OPQ_302_prof_lane_skew_test`](../cases/COMBO_OPQ_302_prof_lane_skew_test.md), [`COMBO_OPQ_303_prof_whole_frame_skew_test`](../cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md), [`COMBO_OPQ_304_prof_missing_empty_frame_test`](../cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md), [`COMBO_OPQ_305_prof_long_soak_test`](../cases/COMBO_OPQ_305_prof_long_soak_test.md), [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](../cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md), [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](../cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md), [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](../cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md)

## Merged code coverage (this bucket)

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 72.62 | 95.0 |
| ⚠️ | branch | 65.34 | 90.0 |
| ℹ️ | cond | 35.23 | - |
| ℹ️ | expr | 50.35 | - |
| ⚠️ | fsm_state | 84.09 | 95.0 |
| ⚠️ | fsm_trans | 42.00 | 90.0 |
| ⚠️ | toggle | 25.88 | 80.0 |

## Ordered merge trace

| status | step | report_case_id | legacy_test_name | merged_total | detail |
|:---:|---:|---|---|---|---|
| ✅ | 1 | `COMBO_OPQ_301_prof_stress_test` | `opq_prof_stress_test` | stmt=71.64, branch=63.77, cond=31.61, expr=46.81, fsm_state=84.09, fsm_trans=41.00, toggle=21.13 | [case](../cases/COMBO_OPQ_301_prof_stress_test.md) |
| ✅ | 2 | `COMBO_OPQ_302_prof_lane_skew_test` | `opq_prof_lane_skew_test` | stmt=72.57, branch=65.22, cond=34.97, expr=48.94, fsm_state=84.09, fsm_trans=42.00, toggle=23.00 | [case](../cases/COMBO_OPQ_302_prof_lane_skew_test.md) |
| ✅ | 3 | `COMBO_OPQ_303_prof_whole_frame_skew_test` | `opq_prof_whole_frame_skew_test` | stmt=72.62, branch=65.34, cond=35.23, expr=50.35, fsm_state=84.09, fsm_trans=42.00, toggle=25.79 | [case](../cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) |
| ✅ | 4 | `COMBO_OPQ_304_prof_missing_empty_frame_test` | `opq_prof_missing_empty_frame_test` | stmt=72.62, branch=65.34, cond=35.23, expr=50.35, fsm_state=84.09, fsm_trans=42.00, toggle=25.88 | [case](../cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) |

---
_Back to [dashboard](../../DV_REPORT.md)_

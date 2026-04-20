# ✅ bucket_frame_native_sv

**Kind:** `bucket_frame` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_BUCKET_FRAME_NATIVE_SV`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `37` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `406` |
| ✅ | functional_cross_pct | `77.94` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime. |
| ⚠️ | limitation | opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic. |
| ⚠️ | limitation | opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the last known green bursty DRR envelope below the open frame_count=3 retirement failure. |
| ⚠️ | limitation | opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case. |
| ⚠️ | limitation | opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the later must-drop path remains probe-only. |
| ⚠️ | limitation | opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run. |
| ⚠️ | limitation | opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration. |

## Execution Order

### bucket_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](../cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](../cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](../cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](../cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `BASIC` -> [`STD_OPQ_006_basic_single_active_lane_lane1_test`](../cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md) (`opq_basic_single_active_lane_lane1_test`)
  `BASIC` -> [`STD_OPQ_007_basic_single_active_lane_dense_test`](../cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) (`opq_basic_single_active_lane_dense_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](../cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](../cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](../cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](../cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](../cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md) (`opq_edge_long_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](../cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md) (`opq_edge_max_hits_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](../cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](../cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](../cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](../cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](../cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `PROF` -> [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](../cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md) (`opq_prof_heavy_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](../cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md) (`opq_prof_deep_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](../cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md) (`opq_prof_asymmetric_missing_empty_frame_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_406_error_header_mask_recovery_test`](../cases/CORNER_OPQ_406_error_header_mask_recovery_test.md) (`opq_error_header_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_407_error_header_word_mask_recovery_test`](../cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md) (`opq_error_header_word_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](../cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](../cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.
- limitation: opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the last known green bursty DRR envelope below the open frame_count=3 retirement failure.
- limitation: opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case.
- limitation: opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the later must-drop path remains probe-only.
- limitation: opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.
- limitation: opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.

## Code coverage

| metric | pct |
|---|---|
| stmt | 83.39 |
| branch | 81.06 |
| cond | 55.52 |
| expr | 77.08 |
| fsm_state | 95.45 |
| fsm_trans | 58.00 |
| toggle | 43.56 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

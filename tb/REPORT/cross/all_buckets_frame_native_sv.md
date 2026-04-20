# ✅ all_buckets_frame_native_sv

**Kind:** `all_buckets_frame` &nbsp; **Build:** `native_sv` &nbsp; **Sequence:** `OPQ_ALL_BUCKETS_FRAME_NATIVE_SV`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `28` |
| ℹ️ | effort | `practical` |
| ℹ️ | txns | `304` |
| ✅ | functional_cross_pct | `77.74` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |
| ⚠️ | limitation | PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime. |
| ⚠️ | limitation | opq_error_ftable_overflow_test is isolated-only evidence because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration. |
| ⚠️ | limitation | opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow. |
| ⚠️ | limitation | opq_cross_mixed_bucket_random_soak_test is isolated-only evidence; it intentionally randomizes across buckets rather than serving as the fixed promoted no-restart baseline. |
| ⚠️ | limitation | This run appends two extra tail sequences after the 28 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases. |

## Execution Order

### all_buckets_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](../cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](../cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](../cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](../cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](../cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](../cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](../cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](../cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](../cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](../cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](../cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](../cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](../cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](../cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](../cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](../cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](../cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](../cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](../cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](../cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](../cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](../cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](../cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](../cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](../cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](../cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](../cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](../cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- extra_tail: `PROF` -> `extra_prof_seq` (extra whole-frame skew tail beyond the promoted default-build matrix)
- extra_tail: `ERROR` -> `extra_err_seq` (extra subheader-recovery tail beyond the promoted default-build matrix)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_error_ftable_overflow_test is isolated-only evidence because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.
- limitation: opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow.
- limitation: opq_cross_mixed_bucket_random_soak_test is isolated-only evidence; it intentionally randomizes across buckets rather than serving as the fixed promoted no-restart baseline.
- limitation: This run appends two extra tail sequences after the 28 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.

## Code coverage

| metric | pct |
|---|---|
| stmt | 83.57 |
| branch | 78.50 |
| cond | 56.10 |
| expr | 71.43 |
| fsm_state | 94.29 |
| fsm_trans | 51.22 |
| toggle | 44.23 |

## Transaction growth curve

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

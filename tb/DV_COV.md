# DV Coverage Summary — packet_scheduler ordered_priority_queue native_sv

This page is the coverage summary only. Per-case incremental coverage lives under
[`REPORT/cases/`](REPORT/cases/); per-bucket ordered-merge traces live under
[`REPORT/buckets/`](REPORT/buckets/).

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions | `opq_error_ftable_overflow_test`, `opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`, `opq_cross_drr_bursty_random_test` |

## Non-Claims

- lane scope: native-SV signoff claim is OPQ_N_LANE=2 only
- excluded probe cases: `opq_error_ftable_overflow_test`, `opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`, `opq_cross_drr_bursty_random_test`
- mode scope: MERGING mode only is claimed in the active native-SV report
- n shd scope: native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only
- four lane status: 4-lane native-SV remains out of signoff scope until the sparse-frame cadence bug in BUG_HISTORY.md is closed
- continuous frame scope: continuous-frame baselines currently cover the default-build promoted matrix only; PARAM build points require separate elaboration and are excluded from no-restart baselines

## Coverage Category Status

| metric | status | note |
|---|---|---|
| stmt | supported_with_target | supported in the native-SV Questa flow; tracked against the 95% workflow target |
| branch | supported_with_target | supported in the native-SV Questa flow; tracked against the 90% workflow target |
| fsm_state | supported_with_target | supported in the native-SV Questa flow; tracked against the 95% workflow target |
| fsm_trans | supported_with_target | supported in the native-SV Questa flow; tracked against the 90% workflow target |
| toggle | supported_with_target | supported in the native-SV Questa flow; tracked against the 80% workflow target |
| cond | supported_no_fixed_target | supported in the native-SV Questa flow and reported explicitly even though the workflow does not impose a fixed threshold |
| expr | supported_no_fixed_target | supported in the native-SV Questa flow and reported explicitly even though the workflow does not impose a fixed threshold |
| - | unsupported | none; no code-coverage category is silently omitted from this report |

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced promoted isolated-mode UCDBs across all signoff buckets. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 88.54 | 95.0 |
| ⚠️ | branch | 78.85 | 90.0 |
| ℹ️ | cond | 58.99 | - |
| ℹ️ | expr | 87.27 | - |
| ⚠️ | fsm_state | 94.29 | 95.0 |
| ⚠️ | fsm_trans | 51.25 | 90.0 |
| ⚠️ | toggle | 65.16 | 80.0 |

## Per-bucket merged totals

| status | bucket | catalog_planned | promoted | evidenced | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---:|---:|---:|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 146 | 5 | 5 | 82.72 | 70.18 | 45.50 | 69.09 | 85.71 | 43.75 | 47.43 |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 180 | 6 | 6 | 84.28 | 72.12 | 48.15 | 70.91 | 85.71 | 43.75 | 46.76 |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 168 | 7 | 7 | 83.58 | 71.54 | 47.09 | 69.09 | 85.71 | 43.75 | 43.87 |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 168 | 5 | 5 | 83.80 | 71.54 | 46.03 | 69.09 | 85.71 | 43.75 | 44.68 |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 166 | 6 | 6 | 86.54 | 76.61 | 50.26 | 74.55 | 91.43 | 48.75 | 41.13 |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 165 | 7 | 7 | 86.65 | 75.73 | 54.76 | 81.82 | 88.57 | 46.25 | 64.10 |

## Isolated execution order and traceability

| bucket | ordered case IDs | trace |
|---|---|---|
| BASIC | [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md), [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md) | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| PARAM | [`COMBO_OPQ_101_basic_smoke_test_nshd128`](REPORT/cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md), [`COMBO_OPQ_102_basic_smoke_test_nshd512`](REPORT/cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md), [`COMBO_OPQ_103_basic_ts_boundary_test_nshd128`](REPORT/cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md), [`COMBO_OPQ_104_basic_ts_boundary_test_nshd512`](REPORT/cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md), [`COMBO_OPQ_105_edge_max_hits_test_nshd128`](REPORT/cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md), [`COMBO_OPQ_106_edge_max_hits_test_nshd512`](REPORT/cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md) | [`REPORT/buckets/PARAM.md`](REPORT/buckets/PARAM.md) |
| EDGE | [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md), [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md), [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md), [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md), [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md), [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md), [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| PROF | [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md), [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md), [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md), [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md), [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md) | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ERROR | [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_406_error_counter_clear_test`](REPORT/cases/CORNER_OPQ_406_error_counter_clear_test.md) | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |
| CROSS | [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md), [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md), [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](REPORT/cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) | [`REPORT/buckets/CROSS.md`](REPORT/buckets/CROSS.md) |

## Continuous-frame baselines by build

| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | 28 | 89.45 | 80.51 | 63.05 | 77.94 | 276 |
| ✅ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | 28 | 89.45 | 80.51 | 63.05 | 77.74 | 304 |

## Continuous-frame execution order

### bucket_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow.
- limitation: opq_cross_mixed_bucket_random_soak_test is isolated-only evidence; it intentionally randomizes across buckets rather than serving as the fixed promoted no-restart baseline.

### all_buckets_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- extra_tail: `PROF` -> `extra_prof_seq` (extra whole-frame skew tail beyond the promoted default-build matrix)
- extra_tail: `ERROR` -> `extra_err_seq` (extra subheader-recovery tail beyond the promoted default-build matrix)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow.
- limitation: opq_cross_mixed_bucket_random_soak_test is isolated-only evidence; it intentionally randomizes across buckets rather than serving as the fixed promoted no-restart baseline.
- limitation: This run appends two extra tail sequences after the 28 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.

_Regenerate with `bash packet_scheduler/tb/scripts/gen_dv_report.sh`._

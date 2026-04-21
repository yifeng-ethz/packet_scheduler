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
| probe_only_exclusions |  |

## Non-Claims

- lane scope: native-SV signoff claim is OPQ_N_LANE=2 only
- excluded probe cases: 
- mode scope: MERGING mode only is claimed in the active native-SV report
- n shd scope: native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only
- four lane status: 4-lane native-SV remains out of signoff scope until dedicated 4-lane DV evidence is promoted; the standalone Arria 10 synthesis result is now recorded separately in signoff
- mixed bucket seconds probe status: the exact 183..190 reproducer is green, and the full stretched mixed-bucket seconds soak now also passes end to end on the repaired allocator state; the screen remains probe-only because of runtime, not because of a live failure
- continuous frame scope: fixed bucket-frame baselines cover the default-build promoted matrix only; dedicated supplemental signoff runs now track mixed-bucket random soak, the bursty DRR frame_count=2/frame_count=3 boundary pair, the refreshed bursty DRR large-random seed sweep, the default-build legal pre-drop boundary, the default-build two-step legal overflow boundary, counter-clear semantics, the reduced-depth overwrite shape-check, and the named reduced-depth must-drop witness, while PARAM elaboration points still remain separate

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

## Coverage-Hole Disposition

| area | measured summary | disposition | evidence anchor | next action |
|---|---|---|---|---|
| Ingress parser recovery states | stmt=74.41, branch=69.81, cond=35.00, fsm_trans=45.83, toggle=56.10 (min across 2 instances) | real gap: The promoted header-error and header-word recovery cases now exercise the repaired parser re-entry path, but MASK_PKT_EXTENDED cleanup and the broader malformed-header recovery state space still sit below the merged signoff targets. | ordered_priority_queue_monolithic_ingress_parser.sv:305-320, 409-410; BUG-005-R / BUG-010-R; opq_error_header_mask_recovery_test, opq_error_header_word_mask_recovery_test | Keep the header-recovery cases in the promoted ERROR bucket and add more chained malformed-header variants only if parser recovery coverage remains the limiting closure gap. |
| Allocator and DRR transition space | stmt=93.14, branch=86.72, cond=62.50, fsm_trans=56.66, toggle=36.10 (min across 2 instances) | real gap: The remaining low FSM-transition coverage is no longer attached to an active 2-lane bursty-DRR correctness failure after the refreshed 2026-04-21 seed sweep, but it still reflects unswept DRR profile diversity plus the lack of dedicated signed-off 4-lane DV evidence. | BUG-009-R; opq_cross_drr_bursty_random_test; opq_prof_missing_empty_frame_test @ OPQ_N_LANE=4; doc/SIGNOFF.md standalone_syn | Keep the refreshed bursty DRR large-random screen in the regression matrix, expand DRR profile diversity only if coverage still stalls, and record real 4-lane DV plus A10 standalone closure before expanding the signoff claim. |
| Presenter flush/backpressure hybrids | toggle=40.00 (min across 1 instance) | real gap: The new default-build pre-drop boundary screen now closes the "must not drop" half of the presenter/backpressure space, but the suite still lacks a complementary signed-off default-build hybrid that advances frame-table drop counters without falling back to the reduced-depth elaboration point. | ordered_priority_queue_monolithic_basic_presenter.sv:128-145, 165-188; DV_FORMAL.md B27/B28; CORNER_OPQ_409_error_ftable_overflow_test; opq_cross_bp_predrop_boundary_test | Keep the reduced-depth overwrite point as the current must-drop proof, use opq_cross_bp_predrop_boundary_test as the default-build legal pre-drop proof, and only promote a default-build must-drop hybrid once it can advance ft_drop_* cleanly without relying on the separate reduced-depth elaboration. |
| Native wrapper fixed-scope decode paths | stmt=91.36, branch=84.27, cond=68.11, toggle=34.22 (min across 2 instances) | justified exclusion: A large part of the wrapper hole count comes from fixed-scope native-SV configuration, dormant CSR decode/default branches, and status/meta observability that are outside the active 2-lane signoff claim. | ordered_priority_queue_dut_sv.sv:227-245, 268-337, 494-505; DV_REPORT non-claims for OPQ_N_LANE=2 and the reduced-depth supplemental overflow point | Keep the wrapper holes documented as non-claims unless a dedicated CSR decode sweep becomes a signoff requirement. |
| FIFO and page-RAM data-bit toggles | stmt=100.00, branch=100.00, cond=100.00, toggle=61.90 (min across 7 instances) | redundant case: The lowest remaining toggle bins are wide storage-array data bits. Extra fill-pattern tests would mostly churn memory bit coverage without closing a new architectural contract. | ticket_fifo / lane_fifo / handle_fifo / page_ram toggle summaries in the merged native-SV UCDB | Do not promote memory-bit churn tests for signoff; only revisit if a real storage-corruption bug appears. |

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced promoted isolated-mode UCDBs across all signoff buckets. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 82.59 | 95.0 |
| ⚠️ | branch | 81.04 | 90.0 |
| ℹ️ | cond | 58.81 | - |
| ℹ️ | expr | 75.18 | - |
| ⚠️ | fsm_state | 93.18 | 95.0 |
| ⚠️ | fsm_trans | 50.00 | 90.0 |
| ⚠️ | toggle | 46.34 | 80.0 |

## Per-bucket merged totals

| status | bucket | catalog_planned | promoted | evidenced | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---:|---:|---:|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 146 | 7 | 4 | 72.71 | 65.70 | 36.53 | 51.06 | 84.09 | 42.00 | 26.75 |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 180 | 6 | 6 | 71.98 | 64.49 | 33.94 | 50.35 | 84.09 | 41.00 | 25.23 |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 168 | 9 | 6 | 71.74 | 64.13 | 33.42 | 50.35 | 84.09 | 41.00 | 25.10 |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 168 | 8 | 4 | 72.62 | 65.34 | 35.23 | 50.35 | 84.09 | 42.00 | 25.88 |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 166 | 10 | 7 | 76.99 | 71.86 | 41.97 | 60.28 | 90.91 | 47.00 | 30.33 |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 165 | 9 | 8 | 82.59 | 81.04 | 58.81 | 75.18 | 93.18 | 50.00 | 49.09 |

## Isolated execution order and traceability

| bucket | ordered case IDs | trace |
|---|---|---|
| BASIC | [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md), [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md), [`STD_OPQ_006_basic_single_active_lane_lane1_test`](REPORT/cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md), [`STD_OPQ_007_basic_single_active_lane_dense_test`](REPORT/cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| PARAM | [`COMBO_OPQ_101_basic_smoke_test_nshd128`](REPORT/cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md), [`COMBO_OPQ_102_basic_smoke_test_nshd512`](REPORT/cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md), [`COMBO_OPQ_103_basic_ts_boundary_test_nshd128`](REPORT/cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md), [`COMBO_OPQ_104_basic_ts_boundary_test_nshd512`](REPORT/cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md), [`COMBO_OPQ_105_edge_max_hits_test_nshd128`](REPORT/cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md), [`COMBO_OPQ_106_edge_max_hits_test_nshd512`](REPORT/cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md) | [`REPORT/buckets/PARAM.md`](REPORT/buckets/PARAM.md) |
| EDGE | [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md), [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md), [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md), [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md), [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md), [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md), [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md), [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md), [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](REPORT/cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md) | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| PROF | [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md), [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md), [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md), [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md), [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md), [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](REPORT/cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md), [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md), [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md) | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ERROR | [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_hit_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md), [`CORNER_OPQ_406_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_407_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_mask_recovery_test.md), [`CORNER_OPQ_408_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md), [`CORNER_OPQ_409_error_counter_clear_test`](REPORT/cases/CORNER_OPQ_409_error_counter_clear_test.md), [`CORNER_OPQ_410_error_ftable_overflow_test`](REPORT/cases/CORNER_OPQ_410_error_ftable_overflow_test.md) | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |
| CROSS | [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md), [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md), [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](REPORT/cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md), [`COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test`](REPORT/cases/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test.md), [`COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test`](REPORT/cases/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test.md) | [`REPORT/buckets/CROSS.md`](REPORT/buckets/CROSS.md) |

## Signoff runs by build

| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | 38 | 79.38 | 78.14 | 42.09 | 77.94 | 410 |
| ✅ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | 38 | 79.38 | 78.14 | 42.09 | 77.74 | 438 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](REPORT/cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | native_sv | 1 | 78.79 | 76.45 | 44.22 | 71.1 | 1220 |
| ✅ | [`drr_bursty_frame2_boundary_native_sv`](REPORT/cross/drr_bursty_frame2_boundary_native_sv.md) | drr_bursty_frame2_boundary | native_sv | 1 | 77.72 | 71.62 | 23.37 | 58.32 | 4 |
| ❌ | [`bp_predrop_boundary_native_sv`](REPORT/cross/bp_predrop_boundary_native_sv.md) | bp_predrop_boundary | native_sv | 1 | 75.29 | 68.24 | 33.01 | 62.07 | 104 |
| ✅ | [`overflow_step2_boundary_native_sv`](REPORT/cross/overflow_step2_boundary_native_sv.md) | overflow_step2_boundary | native_sv | 1 | 77.24 | 71.01 | 33.12 | 62.4 | 10 |
| ⚠️ | [`error_counter_clear_native_sv`](REPORT/cross/error_counter_clear_native_sv.md) | error_counter_clear | native_sv | 1 | 45.67 | 32.25 | 3.06 | 38.3 | 2 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](REPORT/cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | native_sv_depth512 | 1 | 73.05 | 64.86 | 26.48 | 58.88 | 64 |

## Fixed baseline execution order

### bucket_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `BASIC` -> [`STD_OPQ_006_basic_single_active_lane_lane1_test`](REPORT/cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md) (`opq_basic_single_active_lane_lane1_test`)
  `BASIC` -> [`STD_OPQ_007_basic_single_active_lane_dense_test`](REPORT/cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) (`opq_basic_single_active_lane_dense_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md) (`opq_edge_long_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](REPORT/cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md) (`opq_edge_max_hits_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `PROF` -> [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](REPORT/cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md) (`opq_prof_heavy_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md) (`opq_prof_deep_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md) (`opq_prof_asymmetric_missing_empty_frame_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_hit_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md) (`opq_error_hit_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_406_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_407_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_mask_recovery_test.md) (`opq_error_header_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_408_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md) (`opq_error_header_word_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.
- limitation: opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes one deterministic bursty DRR boundary while the complementary frame_count=3 repro and large-random sweep remain tracked separately.
- limitation: opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case.
- limitation: opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the explicit overwrite-local must-drop proof is carried by a separate reduced-depth witness.
- limitation: opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.
- limitation: opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.

### all_buckets_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- ordered_steps:
  `BASIC` -> [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md) (`opq_basic_smoke_test`)
  `BASIC` -> [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md) (`opq_basic_ts_boundary_test`)
  `BASIC` -> [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md) (`opq_basic_feb_packet_contract_test`)
  `BASIC` -> [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md) (`opq_basic_subheader_shape_test`)
  `BASIC` -> [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md) (`opq_basic_single_active_lane_test`)
  `BASIC` -> [`STD_OPQ_006_basic_single_active_lane_lane1_test`](REPORT/cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md) (`opq_basic_single_active_lane_lane1_test`)
  `BASIC` -> [`STD_OPQ_007_basic_single_active_lane_dense_test`](REPORT/cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) (`opq_basic_single_active_lane_dense_test`)
  `EDGE` -> [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md) (`opq_edge_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md) (`opq_edge_always_ready_test`)
  `EDGE` -> [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md) (`opq_edge_ready_medium_profile_test`)
  `EDGE` -> [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md) (`opq_edge_burst_restart_profile_test`)
  `EDGE` -> [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md) (`opq_edge_stuck_low_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md) (`opq_edge_max_hits_test`)
  `EDGE` -> [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md) (`opq_edge_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md) (`opq_edge_long_toggle_backpressure_test`)
  `EDGE` -> [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](REPORT/cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md) (`opq_edge_max_hits_backpressure_test`)
  `PROF` -> [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md) (`opq_prof_stress_test`)
  `PROF` -> [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md) (`opq_prof_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md) (`opq_prof_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md) (`opq_prof_missing_empty_frame_test`)
  `PROF` -> [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md) (`opq_prof_long_soak_test`)
  `PROF` -> [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](REPORT/cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md) (`opq_prof_heavy_lane_skew_test`)
  `PROF` -> [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md) (`opq_prof_deep_whole_frame_skew_test`)
  `PROF` -> [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md) (`opq_prof_asymmetric_missing_empty_frame_test`)
  `ERROR` -> [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md) (`opq_error_lane_mask_test`)
  `ERROR` -> [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md) (`opq_error_lane_mask_single_hit_test`)
  `ERROR` -> [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md) (`opq_error_lane_mask_burst_test`)
  `ERROR` -> [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md) (`opq_error_lane_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_405_error_hit_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_hit_mask_recovery_test.md) (`opq_error_hit_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_406_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_407_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_mask_recovery_test.md) (`opq_error_header_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_408_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_408_error_header_word_mask_recovery_test.md) (`opq_error_header_word_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- extra_tail: `PROF` -> `extra_prof_seq` (extra whole-frame skew tail beyond the promoted default-build matrix)
- extra_tail: `ERROR` -> `extra_err_seq` (extra subheader-recovery tail beyond the promoted default-build matrix)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.
- limitation: opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes one deterministic bursty DRR boundary while the complementary frame_count=3 repro and large-random sweep remain tracked separately.
- limitation: opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case.
- limitation: opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the explicit overwrite-local must-drop proof is carried by a separate reduced-depth witness.
- limitation: opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.
- limitation: opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.
- limitation: This run appends two extra tail sequences after the 38 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.

_Regenerate with `bash packet_scheduler/tb/scripts/gen_dv_report.sh`._

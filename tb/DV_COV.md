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
| probe_only_exclusions | `opq_cross_drr_bursty_random_test` |

## Non-Claims

- lane scope: native-SV signoff claim is OPQ_N_LANE=2 only
- excluded probe cases: `opq_cross_drr_bursty_random_test`
- mode scope: MERGING mode only is claimed in the active native-SV report
- n shd scope: native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only
- four lane status: 4-lane native-SV remains out of signoff scope until dedicated 4-lane DV evidence is promoted; the standalone Arria 10 synthesis result is now recorded separately in signoff
- bursty drr probe status: the focused bursty DRR reproducer is green, but the refreshed larger constrained-random rerun on 2026-04-20 still fails with lane0 unexplained=368 and hit-integrity summary expected=852 actual=622 missing=368 ghost=138; the screen remains probe-only
- mixed bucket seconds probe status: the exact 183..190 reproducer is green, and the full stretched mixed-bucket seconds soak now also passes end to end on the repaired allocator state; the screen remains probe-only because of runtime, not because of a live failure
- continuous frame scope: fixed bucket-frame baselines cover the default-build promoted matrix only; dedicated supplemental signoff runs now track mixed-bucket random soak, counter-clear semantics, and the reduced-depth overflow build point, while PARAM elaboration points still remain separate

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
| Ingress parser recovery states | stmt=76.96, branch=75.53, cond=32.50, fsm_trans=66.66, toggle=51.76 (min across 2 instances) | real gap: The promoted header-error and header-word recovery cases now exercise the repaired parser re-entry path, but MASK_PKT_EXTENDED cleanup and the broader malformed-header recovery state space still sit below the merged signoff targets. | ordered_priority_queue_monolithic_ingress_parser.sv:305-320, 409-410; BUG-005-R / BUG-010-R; opq_error_header_mask_recovery_test, opq_error_header_word_mask_recovery_test | Keep the header-recovery cases in the promoted ERROR bucket and add more chained malformed-header variants only if parser recovery coverage remains the limiting closure gap. |
| Allocator and DRR transition space | stmt=92.03, branch=86.38, cond=60.00, fsm_trans=56.66, toggle=42.21 (min across 2 instances) | real gap: The remaining low FSM-transition coverage still lines up with the bursty DRR large-random screen, which re-opened hit-accounting loss on the latest native-SV rerun, plus the lack of dedicated signed-off 4-lane DV evidence. | BUG-009-R; opq_cross_drr_bursty_random_test; opq_prof_missing_empty_frame_test @ OPQ_N_LANE=4; doc/SIGNOFF.md standalone_syn | Keep the bursty DRR large-random screen probe-only, root-cause the remaining lane0 unexplained-hit loss, and record real 4-lane DV plus A10 standalone closure before expanding the signoff claim. |
| Presenter flush/backpressure hybrids | toggle=60.08 (min across 1 instance) | needs-new-test: The reduced-depth overwrite screen now closes cleanly on the repaired presenter path, but the promoted suite still lacks a directed hybrid that couples legal backpressure windows with default-build overwrite pressure and proves when frame-table drops must, and must not, appear. | ordered_priority_queue_monolithic_basic_presenter.sv:128-145, 165-188; DV_FORMAL.md B27/B28; CORNER_OPQ_409_error_ftable_overflow_test | Add the default-build backpressure-plus-overwrite directed hybrid and use it to raise presenter transition and toggle coverage. |
| Native wrapper fixed-scope decode paths | stmt=86.66, branch=77.68, cond=60.52, toggle=30.38 (min across 2 instances) | justified exclusion: A large part of the wrapper hole count comes from fixed-scope native-SV configuration, dormant CSR decode/default branches, and status/meta observability that are outside the active 2-lane signoff claim. | ordered_priority_queue_dut_sv.sv:227-245, 268-337, 494-505; DV_REPORT non-claims for OPQ_N_LANE=2 and the reduced-depth supplemental overflow point | Keep the wrapper holes documented as non-claims unless a dedicated CSR decode sweep becomes a signoff requirement. |
| FIFO and page-RAM data-bit toggles | stmt=100.00, branch=100.00, cond=100.00, toggle=50.34 (min across 7 instances) | redundant case: The lowest remaining toggle bins are wide storage-array data bits. Extra fill-pattern tests would mostly churn memory bit coverage without closing a new architectural contract. | ticket_fifo / lane_fifo / handle_fifo / page_ram toggle summaries in the merged native-SV UCDB | Do not promote memory-bit churn tests for signoff; only revisit if a real storage-corruption bug appears. |

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced promoted isolated-mode UCDBs across all signoff buckets. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 86.91 | 95.0 |
| ⚠️ | branch | 82.38 | 90.0 |
| ℹ️ | cond | 58.36 | - |
| ℹ️ | expr | 73.21 | - |
| ✅ | fsm_state | 97.73 | 95.0 |
| ⚠️ | fsm_trans | 60.00 | 90.0 |
| ⚠️ | toggle | 47.50 | 80.0 |

## Per-bucket merged totals

| status | bucket | catalog_planned | promoted | evidenced | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---:|---:|---:|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 146 | 7 | 7 | 76.78 | 68.80 | 39.09 | 58.33 | 86.36 | 44.00 | 33.73 |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 180 | 6 | 6 | 84.28 | 72.12 | 48.15 | 70.91 | 85.71 | 43.75 | 46.76 |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 168 | 9 | 9 | 74.21 | 64.99 | 34.56 | 55.21 | 84.09 | 41.00 | 27.95 |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 168 | 8 | 8 | 75.50 | 66.49 | 35.69 | 57.29 | 84.09 | 42.00 | 30.59 |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 166 | 9 | 9 | 82.87 | 76.57 | 46.74 | 69.79 | 95.45 | 58.00 | 34.10 |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 165 | 7 | 7 | 81.54 | 72.64 | 49.78 | 66.67 | 85.71 | 43.62 | 45.76 |

## Isolated execution order and traceability

| bucket | ordered case IDs | trace |
|---|---|---|
| BASIC | [`STD_OPQ_001_basic_smoke_test`](REPORT/cases/STD_OPQ_001_basic_smoke_test.md), [`STD_OPQ_002_basic_ts_boundary_test`](REPORT/cases/STD_OPQ_002_basic_ts_boundary_test.md), [`STD_OPQ_003_basic_subheader_shape_test`](REPORT/cases/STD_OPQ_003_basic_subheader_shape_test.md), [`STD_OPQ_004_basic_feb_packet_contract_test`](REPORT/cases/STD_OPQ_004_basic_feb_packet_contract_test.md), [`STD_OPQ_005_basic_single_active_lane_test`](REPORT/cases/STD_OPQ_005_basic_single_active_lane_test.md), [`STD_OPQ_006_basic_single_active_lane_lane1_test`](REPORT/cases/STD_OPQ_006_basic_single_active_lane_lane1_test.md), [`STD_OPQ_007_basic_single_active_lane_dense_test`](REPORT/cases/STD_OPQ_007_basic_single_active_lane_dense_test.md) | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| PARAM | [`COMBO_OPQ_101_basic_smoke_test_nshd128`](REPORT/cases/COMBO_OPQ_101_basic_smoke_test_nshd128.md), [`COMBO_OPQ_102_basic_smoke_test_nshd512`](REPORT/cases/COMBO_OPQ_102_basic_smoke_test_nshd512.md), [`COMBO_OPQ_103_basic_ts_boundary_test_nshd128`](REPORT/cases/COMBO_OPQ_103_basic_ts_boundary_test_nshd128.md), [`COMBO_OPQ_104_basic_ts_boundary_test_nshd512`](REPORT/cases/COMBO_OPQ_104_basic_ts_boundary_test_nshd512.md), [`COMBO_OPQ_105_edge_max_hits_test_nshd128`](REPORT/cases/COMBO_OPQ_105_edge_max_hits_test_nshd128.md), [`COMBO_OPQ_106_edge_max_hits_test_nshd512`](REPORT/cases/COMBO_OPQ_106_edge_max_hits_test_nshd512.md) | [`REPORT/buckets/PARAM.md`](REPORT/buckets/PARAM.md) |
| EDGE | [`CORNER_OPQ_201_edge_backpressure_test`](REPORT/cases/CORNER_OPQ_201_edge_backpressure_test.md), [`CORNER_OPQ_202_edge_always_ready_test`](REPORT/cases/CORNER_OPQ_202_edge_always_ready_test.md), [`CORNER_OPQ_203_edge_ready_medium_profile_test`](REPORT/cases/CORNER_OPQ_203_edge_ready_medium_profile_test.md), [`CORNER_OPQ_204_edge_stuck_low_backpressure_test`](REPORT/cases/CORNER_OPQ_204_edge_stuck_low_backpressure_test.md), [`CORNER_OPQ_205_edge_max_hits_test`](REPORT/cases/CORNER_OPQ_205_edge_max_hits_test.md), [`CORNER_OPQ_206_edge_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_206_edge_toggle_backpressure_test.md), [`CORNER_OPQ_207_edge_burst_restart_profile_test`](REPORT/cases/CORNER_OPQ_207_edge_burst_restart_profile_test.md), [`CORNER_OPQ_208_edge_long_toggle_backpressure_test`](REPORT/cases/CORNER_OPQ_208_edge_long_toggle_backpressure_test.md), [`CORNER_OPQ_209_edge_max_hits_backpressure_test`](REPORT/cases/CORNER_OPQ_209_edge_max_hits_backpressure_test.md) | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| PROF | [`COMBO_OPQ_301_prof_stress_test`](REPORT/cases/COMBO_OPQ_301_prof_stress_test.md), [`COMBO_OPQ_302_prof_lane_skew_test`](REPORT/cases/COMBO_OPQ_302_prof_lane_skew_test.md), [`COMBO_OPQ_303_prof_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_303_prof_whole_frame_skew_test.md), [`COMBO_OPQ_304_prof_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_304_prof_missing_empty_frame_test.md), [`COMBO_OPQ_305_prof_long_soak_test`](REPORT/cases/COMBO_OPQ_305_prof_long_soak_test.md), [`COMBO_OPQ_306_prof_heavy_lane_skew_test`](REPORT/cases/COMBO_OPQ_306_prof_heavy_lane_skew_test.md), [`COMBO_OPQ_307_prof_deep_whole_frame_skew_test`](REPORT/cases/COMBO_OPQ_307_prof_deep_whole_frame_skew_test.md), [`COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test`](REPORT/cases/COMBO_OPQ_308_prof_asymmetric_missing_empty_frame_test.md) | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ERROR | [`CORNER_OPQ_401_error_lane_mask_test`](REPORT/cases/CORNER_OPQ_401_error_lane_mask_test.md), [`CORNER_OPQ_402_error_lane_mask_single_hit_test`](REPORT/cases/CORNER_OPQ_402_error_lane_mask_single_hit_test.md), [`CORNER_OPQ_403_error_lane_mask_burst_test`](REPORT/cases/CORNER_OPQ_403_error_lane_mask_burst_test.md), [`CORNER_OPQ_404_error_lane_mask_recovery_test`](REPORT/cases/CORNER_OPQ_404_error_lane_mask_recovery_test.md), [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md), [`CORNER_OPQ_406_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_header_mask_recovery_test.md), [`CORNER_OPQ_407_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md), [`CORNER_OPQ_408_error_counter_clear_test`](REPORT/cases/CORNER_OPQ_408_error_counter_clear_test.md), [`CORNER_OPQ_409_error_ftable_overflow_test`](REPORT/cases/CORNER_OPQ_409_error_ftable_overflow_test.md) | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |
| CROSS | [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md), [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md), [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md), [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md), [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md), [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md), [`COMBO_OPQ_507_cross_mixed_bucket_random_soak_test`](REPORT/cases/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md) | [`REPORT/buckets/CROSS.md`](REPORT/buckets/CROSS.md) |

## Signoff runs by build

| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | 37 | 83.39 | 81.06 | 43.56 | 77.94 | 406 |
| ✅ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | 37 | 83.39 | 81.06 | 43.85 | 77.74 | 434 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](REPORT/cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | native_sv | 1 | 82.40 | 79.02 | 45.23 | 70.96 | 1160 |
| ⚠️ | [`error_counter_clear_native_sv`](REPORT/cross/error_counter_clear_native_sv.md) | error_counter_clear | native_sv | 1 | 47.84 | 33.11 | 4.15 | 38.3 | 2 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](REPORT/cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | native_sv_depth512 | 1 | 77.08 | 64.85 | 30.11 | 60.27 | 64 |

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
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_406_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_header_mask_recovery_test.md) (`opq_error_header_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_407_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md) (`opq_error_header_word_mask_recovery_test`)
  `CROSS` -> [`COMBO_OPQ_501_cross_bp_credit_test`](REPORT/cases/COMBO_OPQ_501_cross_bp_credit_test.md) (`opq_cross_bp_credit_test`)
  `CROSS` -> [`COMBO_OPQ_502_cross_drr_allowance_test`](REPORT/cases/COMBO_OPQ_502_cross_drr_allowance_test.md) (`opq_cross_drr_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_503_cross_drr_idle_lane_test`](REPORT/cases/COMBO_OPQ_503_cross_drr_idle_lane_test.md) (`opq_cross_drr_idle_lane_test`)
  `CROSS` -> [`COMBO_OPQ_504_cross_drr_zero_allowance_test`](REPORT/cases/COMBO_OPQ_504_cross_drr_zero_allowance_test.md) (`opq_cross_drr_zero_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_505_cross_drr_short_allowance_test`](REPORT/cases/COMBO_OPQ_505_cross_drr_short_allowance_test.md) (`opq_cross_drr_short_allowance_test`)
  `CROSS` -> [`COMBO_OPQ_506_cross_idle_lane_backpressure_test`](REPORT/cases/COMBO_OPQ_506_cross_idle_lane_backpressure_test.md) (`opq_cross_idle_lane_backpressure_test`)
- limitation: PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.
- limitation: opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.
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
  `ERROR` -> [`CORNER_OPQ_405_error_subheader_mask_recovery_test`](REPORT/cases/CORNER_OPQ_405_error_subheader_mask_recovery_test.md) (`opq_error_subheader_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_406_error_header_mask_recovery_test`](REPORT/cases/CORNER_OPQ_406_error_header_mask_recovery_test.md) (`opq_error_header_mask_recovery_test`)
  `ERROR` -> [`CORNER_OPQ_407_error_header_word_mask_recovery_test`](REPORT/cases/CORNER_OPQ_407_error_header_word_mask_recovery_test.md) (`opq_error_header_word_mask_recovery_test`)
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
- limitation: opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.
- limitation: opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.
- limitation: This run appends two extra tail sequences after the 37 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.

_Regenerate with `bash packet_scheduler/tb/scripts/gen_dv_report.sh`._

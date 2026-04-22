# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-22` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `4` |
| OPQ_N_SHD | `128` |
| OPQ_TICKET_FIFO_DEPTH | `256` |
| OPQ_PAGE_RAM_DEPTH | `512`, `65536` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 129 | 0 | stmt=71.93, branch=64.94, cond=36.18, expr=49.18, fsm_state=86.92, fsm_trans=43.09, toggle=23.41 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 129 | 0 | stmt=72.88, branch=66.22, cond=37.10, expr=50.82, fsm_state=87.85, fsm_trans=43.90, toggle=26.73 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 129 | 129 | 129 | 0 | stmt=70.52, branch=62.97, cond=31.35, expr=45.11, fsm_state=86.92, fsm_trans=43.09, toggle=25.47 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 129 | 0 | stmt=72.50, branch=67.26, cond=35.15, expr=54.35, fsm_state=92.52, fsm_trans=52.44, toggle=22.38 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`opq_bucket_frame_native_sv_test`](cross/opq_bucket_frame_native_sv_test.md) | bucket_frame | run_promoted_default_build_matrix | 764 | 77.34 |
| ✅ | [`opq_all_buckets_frame_native_sv_test`](cross/opq_all_buckets_frame_native_sv_test.md) | all_buckets_frame | run_promoted_default_build_matrix_plus_tail | 820 | 77.14 |
| ✅ | [`opq_cross_bp_mustdrop_witness_test`](cross/opq_cross_bp_mustdrop_witness_test.md) | cross | opq_cross_bp_mustdrop_witness_test | 52 | 65.74 |
| ✅ | [`opq_cross_bp_predrop_boundary_test`](cross/opq_cross_bp_predrop_boundary_test.md) | cross | opq_cross_bp_predrop_boundary_test | 208 | 61.71 |
| ✅ | [`opq_cross_drr_bursty_frame2_boundary_test`](cross/opq_cross_drr_bursty_frame2_boundary_test.md) | cross | opq_cross_drr_bursty_frame2_boundary_test | 8 | 59.27 |
| ✅ | [`opq_cross_drr_bursty_frame3_repro_test`](cross/opq_cross_drr_bursty_frame3_repro_test.md) | cross | opq_cross_drr_bursty_frame3_repro_test | 12 | 59.84 |
| ✅ | [`opq_cross_drr_bursty_large_repro_test`](cross/opq_cross_drr_bursty_large_repro_test.md) | cross | opq_cross_drr_bursty_large_repro_test | 24 | 60.64 |
| ✅ | [`opq_cross_drr_bursty_random_test`](cross/opq_cross_drr_bursty_random_test.md) | cross | opq_cross_drr_bursty_random_test | 24 | 60.64 |
| ✅ | [`opq_cross_drr_bursty_repro_test`](cross/opq_cross_drr_bursty_repro_test.md) | cross | opq_cross_drr_bursty_repro_test | 32 | 59.84 |
| ✅ | [`opq_cross_drr_then_idle_lane_bp_repro_test`](cross/opq_cross_drr_then_idle_lane_bp_repro_test.md) | cross | opq_cross_drr_then_idle_lane_bp_repro_test | 44 | 62.47 |
| ✅ | [`opq_cross_hit3_exact_183_190_repro_test`](cross/opq_cross_hit3_exact_183_190_repro_test.md) | cross | opq_cross_hit3_exact_183_190_repro_test | 166 | 66.65 |
| ✅ | [`opq_cross_hit3_lead_in_repro_test`](cross/opq_cross_hit3_lead_in_repro_test.md) | cross | opq_cross_hit3_lead_in_repro_test | 148 | 67.69 |
| ✅ | [`opq_cross_idle_lane_backpressure_test`](cross/opq_cross_idle_lane_backpressure_test.md) | cross | opq_cross_idle_lane_backpressure_test | 24 | 59.91 |
| ✅ | [`opq_cross_masked_drop_exact_102_117_repro_test`](cross/opq_cross_masked_drop_exact_102_117_repro_test.md) | cross | opq_cross_masked_drop_exact_102_117_repro_test | 218 | 70.1 |
| ✅ | [`opq_cross_mixed_bucket_random_soak_test`](cross/opq_cross_mixed_bucket_random_soak_test.md) | cross | opq_cross_mixed_bucket_random_soak_test | 2096 | 72.87 |
| ✅ | [`opq_cross_random_ready_overflow_extensive_soak_test`](cross/opq_cross_random_ready_overflow_extensive_soak_test.md) | cross | opq_cross_random_ready_overflow_extensive_soak_test | 76 | 66.77 |
| ✅ | [`opq_cross_random_ready_overflow_step2_boundary_test`](cross/opq_cross_random_ready_overflow_step2_boundary_test.md) | cross | opq_cross_random_ready_overflow_step2_boundary_test | 20 | 64.02 |
| ✅ | [`opq_cross_single_hit_masked_then_sparse_repro_test`](cross/opq_cross_single_hit_masked_then_sparse_repro_test.md) | cross | opq_cross_single_hit_masked_then_sparse_repro_test | 24 | 65.28 |
| ✅ | [`opq_cross_sparse_single_lane_drr_credit_restore_repro_test`](cross/opq_cross_sparse_single_lane_drr_credit_restore_repro_test.md) | cross | opq_cross_sparse_single_lane_drr_credit_restore_repro_test | 46 | 64.03 |
| ⚠️ | [`opq_error_counter_clear_test`](cross/opq_error_counter_clear_test.md) | cross | opq_error_counter_clear_test | 4 | 38.24 |
| ✅ | [`opq_error_ftable_overflow_test`](cross/opq_error_ftable_overflow_test.md) | cross | opq_error_ftable_overflow_test | 64 | 58.05 |
| ✅ | [`opq_formal_like_egress_flush_backpressure_stress_test`](cross/opq_formal_like_egress_flush_backpressure_stress_test.md) | cross | opq_formal_like_egress_flush_backpressure_stress_test | 80 | 60.47 |

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `516`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=74.41, branch=70.36, cond=41.62, expr=57.88, fsm_state=94.39, fsm_trans=54.47, toggle=33.52`
- promoted functional coverage: `89.89% (516/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

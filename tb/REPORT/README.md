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
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 129 | 0 | stmt=76.54, branch=70.52, cond=45.63, expr=58.20, fsm_state=87.30, fsm_trans=43.84, toggle=28.61 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 129 | 0 | stmt=77.91, branch=71.90, cond=47.57, expr=61.90, fsm_state=87.30, fsm_trans=43.84, toggle=29.70 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 129 | 129 | 129 | 0 | stmt=72.97, branch=64.37, cond=33.40, expr=44.97, fsm_state=85.71, fsm_trans=42.47, toggle=24.86 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 129 | 0 | stmt=72.13, branch=64.28, cond=37.09, expr=56.08, fsm_state=76.19, fsm_trans=41.10, toggle=19.94 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`opq_bucket_frame_native_sv_test`](cross/opq_bucket_frame_native_sv_test.md) | bucket_frame | run_promoted_default_build_matrix | 644 | 78.14 |
| ✅ | [`opq_all_buckets_frame_native_sv_test`](cross/opq_all_buckets_frame_native_sv_test.md) | all_buckets_frame | run_promoted_default_build_matrix_plus_tail | 700 | 77.94 |
| ✅ | [`opq_cross_bp_credit_test`](cross/opq_cross_bp_credit_test.md) | cross | opq_cross_bp_credit_test | 12 | 64.03 |
| ✅ | [`opq_cross_bp_predrop_boundary_test`](cross/opq_cross_bp_predrop_boundary_test.md) | cross | opq_cross_bp_predrop_boundary_test | 104 | 63.34 |
| ✅ | [`opq_cross_drr_allowance_test`](cross/opq_cross_drr_allowance_test.md) | cross | opq_cross_drr_allowance_test | 16 | 56.65 |
| ✅ | [`opq_cross_drr_bursty_frame2_boundary_test`](cross/opq_cross_drr_bursty_frame2_boundary_test.md) | cross | opq_cross_drr_bursty_frame2_boundary_test | 4 | 58.66 |
| ✅ | [`opq_cross_drr_bursty_frame3_repro_test`](cross/opq_cross_drr_bursty_frame3_repro_test.md) | cross | opq_cross_drr_bursty_frame3_repro_test | 6 | 59.71 |
| ✅ | [`opq_cross_drr_bursty_large_repro_test`](cross/opq_cross_drr_bursty_large_repro_test.md) | cross | opq_cross_drr_bursty_large_repro_test | 12 | 60.51 |
| ✅ | [`opq_cross_drr_bursty_random_test`](cross/opq_cross_drr_bursty_random_test.md) | cross | opq_cross_drr_bursty_random_test | 24 | 60.58 |
| ✅ | [`opq_cross_drr_bursty_repro_test`](cross/opq_cross_drr_bursty_repro_test.md) | cross | opq_cross_drr_bursty_repro_test | 16 | 59.71 |
| ✅ | [`opq_cross_drr_idle_lane_test`](cross/opq_cross_drr_idle_lane_test.md) | cross | opq_cross_drr_idle_lane_test | 16 | 54.92 |
| ✅ | [`opq_cross_drr_short_allowance_test`](cross/opq_cross_drr_short_allowance_test.md) | cross | opq_cross_drr_short_allowance_test | 12 | 55.2 |
| ✅ | [`opq_cross_drr_then_idle_lane_bp_repro_test`](cross/opq_cross_drr_then_idle_lane_bp_repro_test.md) | cross | opq_cross_drr_then_idle_lane_bp_repro_test | 34 | 61.22 |
| ✅ | [`opq_cross_drr_zero_allowance_test`](cross/opq_cross_drr_zero_allowance_test.md) | cross | opq_cross_drr_zero_allowance_test | 16 | 55.01 |
| ✅ | [`opq_cross_hit3_exact_183_190_repro_test`](cross/opq_cross_hit3_exact_183_190_repro_test.md) | cross | opq_cross_hit3_exact_183_190_repro_test | 150 | 67.11 |
| ✅ | [`opq_cross_hit3_lead_in_repro_test`](cross/opq_cross_hit3_lead_in_repro_test.md) | cross | opq_cross_hit3_lead_in_repro_test | 138 | 66.44 |
| ✅ | [`opq_cross_idle_lane_backpressure_test`](cross/opq_cross_idle_lane_backpressure_test.md) | cross | opq_cross_idle_lane_backpressure_test | 24 | 59.91 |
| ✅ | [`opq_cross_masked_drop_exact_102_117_repro_test`](cross/opq_cross_masked_drop_exact_102_117_repro_test.md) | cross | opq_cross_masked_drop_exact_102_117_repro_test | 214 | 70.56 |
| ✅ | [`opq_cross_mixed_bucket_random_soak_test`](cross/opq_cross_mixed_bucket_random_soak_test.md) | cross | opq_cross_mixed_bucket_random_soak_test | 2026 | 72.41 |
| ✅ | [`opq_cross_random_ready_overflow_step2_boundary_test`](cross/opq_cross_random_ready_overflow_step2_boundary_test.md) | cross | opq_cross_random_ready_overflow_step2_boundary_test | 20 | 65.59 |
| ✅ | [`opq_cross_single_hit_masked_then_sparse_repro_test`](cross/opq_cross_single_hit_masked_then_sparse_repro_test.md) | cross | opq_cross_single_hit_masked_then_sparse_repro_test | 24 | 65.28 |
| ✅ | [`opq_cross_sparse_single_lane_drr_credit_restore_repro_test`](cross/opq_cross_sparse_single_lane_drr_credit_restore_repro_test.md) | cross | opq_cross_sparse_single_lane_drr_credit_restore_repro_test | 40 | 65.3 |

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `516`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=79.73, branch=76.31, cond=51.46, expr=64.02, fsm_state=93.65, fsm_trans=53.42, toggle=33.95`
- promoted functional coverage: `88.48% (516/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

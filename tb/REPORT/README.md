# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-28` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

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
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 0 | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 1 | 0 | stmt=72.51, branch=60.33, cond=26.28, expr=48.67, fsm_state=76.71, fsm_trans=36.53, toggle=17.98 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 129 | 129 | 0 | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 8 | 0 | stmt=72.25, branch=60.77, cond=30.63, expr=56.67, fsm_state=76.71, fsm_trans=36.53, toggle=18.79 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`opq_bucket_frame_native_sv_test`](cross/opq_bucket_frame_native_sv_test.md) | bucket_frame | run_promoted_default_build_matrix | 738 | 76.72 |
| ✅ | [`opq_all_buckets_frame_native_sv_test`](cross/opq_all_buckets_frame_native_sv_test.md) | all_buckets_frame | run_promoted_default_build_matrix_plus_tail | 794 | 76.52 |
| ✅ | [`opq_cross_bp_predrop_boundary_test`](cross/opq_cross_bp_predrop_boundary_test.md) | cross | opq_cross_bp_predrop_boundary_test | 208 | 61.71 |
| ✅ | [`opq_cross_drr_bursty_frame2_boundary_test`](cross/opq_cross_drr_bursty_frame2_boundary_test.md) | cross | opq_cross_drr_bursty_frame2_boundary_test | 8 | 59.27 |
| ✅ | [`opq_cross_mixed_bucket_random_soak_test`](cross/opq_cross_mixed_bucket_random_soak_test.md) | cross | opq_cross_mixed_bucket_random_soak_test | 2038 | 72.05 |
| ✅ | [`opq_cross_random_ready_overflow_step2_boundary_test`](cross/opq_cross_random_ready_overflow_step2_boundary_test.md) | cross | opq_cross_random_ready_overflow_step2_boundary_test | 20 | 63.48 |
| ⚠️ | [`opq_error_counter_clear_test`](cross/opq_error_counter_clear_test.md) | cross | opq_error_counter_clear_test | 4 | 38.24 |
| ✅ | [`opq_error_ftable_overflow_test`](cross/opq_error_ftable_overflow_test.md) | cross | opq_error_ftable_overflow_test | 64 | 60.78 |

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `9`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=72.98, branch=61.81, cond=31.03, expr=56.67, fsm_state=76.71, fsm_trans=36.53, toggle=18.79`
- promoted functional coverage: `63.23% (9/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

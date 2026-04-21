# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-21` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 146 | 7 | 4 | 139 | stmt=72.71, branch=65.70, cond=36.53, expr=51.06, fsm_state=84.09, fsm_trans=42.00, toggle=26.75 |
| ⚠️ | [`PARAM`](buckets/PARAM.md) | 180 | 6 | 6 | 174 | stmt=71.98, branch=64.49, cond=33.94, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.23 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 168 | 9 | 6 | 159 | stmt=71.74, branch=64.13, cond=33.42, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.10 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 168 | 8 | 4 | 160 | stmt=72.62, branch=65.34, cond=35.23, expr=50.35, fsm_state=84.09, fsm_trans=42.00, toggle=25.88 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 166 | 10 | 7 | 156 | stmt=76.99, branch=71.86, cond=41.97, expr=60.28, fsm_state=90.91, fsm_trans=47.00, toggle=30.33 |
| ⚠️ | [`CROSS`](buckets/CROSS.md) | 165 | 9 | 8 | 156 | stmt=82.59, branch=81.04, cond=58.81, expr=75.18, fsm_state=93.18, fsm_trans=50.00, toggle=49.09 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](cross/bucket_frame_native_sv.md) | bucket_frame | OPQ_BUCKET_FRAME_NATIVE_SV | 410 | 77.94 |
| ✅ | [`all_buckets_frame_native_sv`](cross/all_buckets_frame_native_sv.md) | all_buckets_frame | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 438 | 77.74 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | OPQ_MIXED_BUCKET_RANDOM_SOAK | 1220 | 71.1 |
| ✅ | [`drr_bursty_frame2_boundary_native_sv`](cross/drr_bursty_frame2_boundary_native_sv.md) | drr_bursty_frame2_boundary | OPQ_DRR_BURSTY_FRAME2_BOUNDARY | 4 | 58.32 |
| ❌ | [`bp_predrop_boundary_native_sv`](cross/bp_predrop_boundary_native_sv.md) | bp_predrop_boundary | OPQ_BP_PREDROP_BOUNDARY | 104 | 62.07 |
| ✅ | [`overflow_step2_boundary_native_sv`](cross/overflow_step2_boundary_native_sv.md) | overflow_step2_boundary | OPQ_OVERFLOW_STEP2_BOUNDARY | 10 | 62.4 |
| ⚠️ | [`error_counter_clear_native_sv`](cross/error_counter_clear_native_sv.md) | error_counter_clear | OPQ_ERROR_COUNTER_CLEAR | 2 | 38.3 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512 | 64 | 58.88 |

## Totals

- catalog_planned_cases: `993`
- promoted_signoff_cases: `49`
- catalog_pending_cases: `944`
- evidenced_promoted_cases: `35`
- excluded_cases: `0`
- promoted_random_cases: `2`
- merged total code coverage across promoted isolated evidence: `stmt=82.59, branch=81.04, cond=58.81, expr=75.18, fsm_state=93.18, fsm_trans=50.00, toggle=46.34`
- promoted functional coverage: `93.07% (35/49)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

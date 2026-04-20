# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-20` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions | `opq_cross_drr_bursty_random_test` |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 146 | 7 | 7 | 139 | stmt=76.78, branch=68.80, cond=39.09, expr=58.33, fsm_state=86.36, fsm_trans=44.00, toggle=33.73 |
| ⚠️ | [`PARAM`](buckets/PARAM.md) | 180 | 6 | 6 | 174 | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 168 | 9 | 9 | 159 | stmt=74.21, branch=64.99, cond=34.56, expr=55.21, fsm_state=84.09, fsm_trans=41.00, toggle=27.95 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 168 | 8 | 8 | 160 | stmt=75.50, branch=66.49, cond=35.69, expr=57.29, fsm_state=84.09, fsm_trans=42.00, toggle=30.59 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 166 | 9 | 9 | 157 | stmt=82.87, branch=76.57, cond=46.74, expr=69.79, fsm_state=95.45, fsm_trans=58.00, toggle=34.10 |
| ⚠️ | [`CROSS`](buckets/CROSS.md) | 165 | 7 | 7 | 158 | stmt=81.54, branch=72.64, cond=49.78, expr=66.67, fsm_state=85.71, fsm_trans=43.62, toggle=45.76 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](cross/bucket_frame_native_sv.md) | bucket_frame | OPQ_BUCKET_FRAME_NATIVE_SV | 406 | 77.94 |
| ✅ | [`all_buckets_frame_native_sv`](cross/all_buckets_frame_native_sv.md) | all_buckets_frame | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 434 | 77.74 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | OPQ_MIXED_BUCKET_RANDOM_SOAK | 1160 | 70.96 |
| ⚠️ | [`error_counter_clear_native_sv`](cross/error_counter_clear_native_sv.md) | error_counter_clear | OPQ_ERROR_COUNTER_CLEAR | 2 | 38.3 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512 | 64 | 60.27 |

## Totals

- catalog_planned_cases: `993`
- promoted_signoff_cases: `46`
- catalog_pending_cases: `947`
- evidenced_promoted_cases: `46`
- excluded_cases: `1`
- promoted_random_cases: `1`
- merged total code coverage across promoted isolated evidence: `stmt=86.91, branch=82.38, cond=58.36, expr=73.21, fsm_state=97.73, fsm_trans=60.00, toggle=47.50`
- promoted functional coverage: `91.07% (46/46)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-19` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions | `opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`, `opq_cross_drr_bursty_random_test` |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 146 | 5 | 5 | 141 | stmt=82.72, branch=70.18, cond=45.50, expr=69.09, fsm_state=85.71, fsm_trans=43.75, toggle=47.43 |
| ⚠️ | [`PARAM`](buckets/PARAM.md) | 180 | 6 | 6 | 174 | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 168 | 7 | 7 | 161 | stmt=83.58, branch=71.54, cond=47.09, expr=69.09, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 168 | 5 | 5 | 163 | stmt=83.80, branch=71.54, cond=46.03, expr=69.09, fsm_state=85.71, fsm_trans=43.75, toggle=44.68 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 166 | 7 | 7 | 159 | stmt=85.44, branch=76.11, cond=53.88, expr=69.44, fsm_state=91.43, fsm_trans=48.75, toggle=46.04 |
| ⚠️ | [`CROSS`](buckets/CROSS.md) | 165 | 7 | 7 | 158 | stmt=86.65, branch=75.73, cond=54.76, expr=81.82, fsm_state=88.57, fsm_trans=46.25, toggle=64.10 |

## Cross / continuous-frame runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](cross/bucket_frame_native_sv.md) | bucket_frame | OPQ_BUCKET_FRAME_NATIVE_SV | 276 | 77.94 |
| ✅ | [`all_buckets_frame_native_sv`](cross/all_buckets_frame_native_sv.md) | all_buckets_frame | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 304 | 77.74 |

## Totals

- catalog_planned_cases: `993`
- promoted_signoff_cases: `37`
- catalog_pending_cases: `956`
- evidenced_promoted_cases: `37`
- excluded_cases: `3`
- promoted_random_cases: `1`
- merged total code coverage across promoted isolated evidence: `stmt=87.54, branch=76.97, cond=58.49, expr=83.05, fsm_state=94.29, fsm_trans=51.25, toggle=62.26`
- promoted functional coverage: `90.71% (37/37)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

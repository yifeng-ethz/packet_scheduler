# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-17` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions | `opq_error_ftable_overflow_test`, `opq_error_header_mask_recovery_test`, `opq_cross_drr_bursty_random_test` |

## Buckets

| status | bucket | planned | evidenced | merged |
|:---:|---|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 4 | 4 | stmt=84.07, branch=71.93, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=45.51 |
| ⚠️ | [`PARAM`](buckets/PARAM.md) | 6 | 6 | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 6 | 6 | stmt=83.64, branch=71.73, cond=48.68, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=43.87 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 4 | 4 | stmt=84.07, branch=71.73, cond=46.56, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=44.68 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 6 | 6 | stmt=86.54, branch=76.61, cond=50.26, expr=74.55, fsm_state=91.43, fsm_trans=48.75, toggle=41.13 |
| ⚠️ | [`CROSS`](buckets/CROSS.md) | 5 | 5 | stmt=86.01, branch=74.85, cond=51.85, expr=70.91, fsm_state=88.57, fsm_trans=46.25, toggle=51.18 |

## Cross / continuous-frame runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ❌ | [`bucket_frame_native_sv`](cross/bucket_frame_native_sv.md) | bucket_frame | OPQ_BUCKET_FRAME_NATIVE_SV | 202 | 78.11 |
| ❌ | [`all_buckets_frame_native_sv`](cross/all_buckets_frame_native_sv.md) | all_buckets_frame | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 230 | 78.11 |

## Totals

- planned_cases: `31`
- evidenced_cases: `31`
- excluded_cases: `3`
- merged total code coverage: `stmt=89.77, branch=81.09, cond=60.32, expr=81.82, fsm_state=94.29, fsm_trans=51.25, toggle=59.29`
- functional coverage: `89.08% (31/31)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

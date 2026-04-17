# DV Coverage Summary — packet_scheduler ordered_priority_queue native_sv

This page is the coverage summary only. Per-case incremental coverage lives under
[`REPORT/cases/`](REPORT/cases/); per-bucket ordered-merge traces live under
[`REPORT/buckets/`](REPORT/buckets/).

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced isolated-mode UCDBs across all buckets. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 89.77 | 95.0 |
| ⚠️ | branch | 81.09 | 90.0 |
| ℹ️ | cond | 60.32 | - |
| ℹ️ | expr | 81.82 | - |
| ⚠️ | fsm_state | 94.29 | 95.0 |
| ⚠️ | fsm_trans | 51.25 | 90.0 |
| ⚠️ | toggle | 59.29 | 80.0 |

## Per-bucket merged totals

| status | bucket | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 84.07 | 71.93 | 46.56 | 70.91 | 85.71 | 43.75 | 45.51 |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 84.28 | 72.12 | 48.15 | 70.91 | 85.71 | 43.75 | 46.76 |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 83.64 | 71.73 | 48.68 | 70.91 | 85.71 | 43.75 | 43.87 |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 84.07 | 71.73 | 46.56 | 70.91 | 85.71 | 43.75 | 44.68 |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 86.54 | 76.61 | 50.26 | 74.55 | 91.43 | 48.75 | 41.13 |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 86.01 | 74.85 | 51.85 | 70.91 | 88.57 | 46.25 | 51.18 |

## Continuous-frame baselines by build

<!-- one row per bucket_frame / all_buckets_frame signoff run (see REPORT/cross/ for curves). -->

| status | run_id | kind | build | bucket | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---|---:|---|---|---|---:|---:|
| ❌ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | - | 24 | 89.02 | 80.12 | 54.54 | 78.11 | 202 |
| ❌ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | - | 24 | 89.24 | 80.51 | 54.77 | 78.11 | 230 |

_Regenerate with `python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb <tb>`._

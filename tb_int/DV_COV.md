# DV Coverage Summary — `packet_scheduler/tb_int long-run matrix`

This page is the coverage summary only. Per-case incremental coverage lives under
[`REPORT/cases/`](REPORT/cases/); per-bucket ordered-merge traces live under
[`REPORT/buckets/`](REPORT/buckets/).

## Legend

✅ pass / closed &middot; ⚠️ partial / below target &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced isolated-mode UCDBs across all buckets. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ❓ | stmt | n/a | 95.0 |
| ❓ | branch | n/a | 90.0 |
| ❓ | cond | n/a | - |
| ❓ | expr | n/a | - |
| ❓ | fsm_state | n/a | 95.0 |
| ❓ | fsm_trans | n/a | 90.0 |
| ❓ | toggle | n/a | 80.0 |

## Per-bucket merged totals

| status | bucket | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---|---|---|---|---|---|---|
| ✅ | [`B0`](REPORT/buckets/B0.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B1`](REPORT/buckets/B1.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B2`](REPORT/buckets/B2.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B3`](REPORT/buckets/B3.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B4`](REPORT/buckets/B4.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B5`](REPORT/buckets/B5.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B6`](REPORT/buckets/B6.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ✅ | [`B7`](REPORT/buckets/B7.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

## Continuous-frame baselines by build

<!-- one row per bucket_frame / all_buckets_frame signoff run (see REPORT/cross/ for curves). -->

| status | run_id | kind | build | bucket | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---|---:|---|---|---|---:|---:|

_Regenerate with `python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb <tb>`._

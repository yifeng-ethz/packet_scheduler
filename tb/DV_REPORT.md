# ❌ DV Report — packet_scheduler ordered_priority_queue native_sv

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-21` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Health

| status | field | value |
|:---:|---|---|
| ❌ | failed_cases | `14` |
| ✅ | signoff_runs_with_failures | `0` |
| ⚠️ | catalog_backlog_cases | `944` |
| ⚠️ | unimplemented_cases | `14` |
| ✅ | stale_artifacts | `0` |

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Non-Claims

- lane scope: native-SV signoff claim is OPQ_N_LANE=2 only
- excluded probe cases: 
- mode scope: MERGING mode only is claimed in the active native-SV report
- n shd scope: native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only
- four lane status: 4-lane native-SV remains out of signoff scope until dedicated 4-lane DV evidence is promoted; the standalone Arria 10 synthesis result is now recorded separately in signoff
- mixed bucket seconds probe status: the exact 183..190 reproducer is green, and the full stretched mixed-bucket seconds soak now also passes end to end on the repaired allocator state; the screen remains probe-only because of runtime, not because of a live failure
- continuous frame scope: fixed bucket-frame baselines cover the default-build promoted matrix only; dedicated supplemental signoff runs now track mixed-bucket random soak, the bursty DRR frame_count=2/frame_count=3 boundary pair, the refreshed bursty DRR large-random seed sweep, the default-build legal pre-drop boundary, the default-build two-step legal overflow boundary, counter-clear semantics, the reduced-depth overwrite shape-check, and the named reduced-depth must-drop witness, while PARAM elaboration points still remain separate

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 146 | 7 | 4 | 139 | stmt=72.71, branch=65.70, cond=36.53, expr=51.06, fsm_state=84.09, fsm_trans=42.00, toggle=26.75 | 66.97% (4/7) |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 180 | 6 | 6 | 174 | stmt=71.98, branch=64.49, cond=33.94, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.23 | 67.37% (6/6) |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 168 | 9 | 6 | 159 | stmt=71.74, branch=64.13, cond=33.42, expr=50.35, fsm_state=84.09, fsm_trans=41.00, toggle=25.10 | 68.42% (6/9) |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 168 | 8 | 4 | 160 | stmt=72.62, branch=65.34, cond=35.23, expr=50.35, fsm_state=84.09, fsm_trans=42.00, toggle=25.88 | 64.37% (4/8) |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 166 | 10 | 7 | 156 | stmt=76.99, branch=71.86, cond=41.97, expr=60.28, fsm_state=90.91, fsm_trans=47.00, toggle=30.33 | 71.26% (7/10) |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 165 | 9 | 8 | 156 | stmt=82.59, branch=81.04, cond=58.81, expr=75.18, fsm_state=93.18, fsm_trans=50.00, toggle=49.09 | 83.69% (8/9) |

## Totals

| status | metric | pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 82.59 | 95.0 |
| ⚠️ | branch | 81.04 | 90.0 |
| ℹ️ | cond | 58.81 | - |
| ℹ️ | expr | 75.18 | - |
| ⚠️ | fsm_state | 93.18 | 95.0 |
| ⚠️ | fsm_trans | 50.00 | 90.0 |
| ⚠️ | toggle | 46.34 | 80.0 |

- catalog_planned_cases: `993`
- promoted_signoff_cases: `49`
- evidenced_promoted_cases: `35`
- promoted functional coverage: `93.07% (35/49)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | OPQ_BUCKET_FRAME_NATIVE_SV | 410 | 77.94 |
| ✅ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 438 | 77.74 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](REPORT/cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | native_sv | OPQ_MIXED_BUCKET_RANDOM_SOAK | 1220 | 71.1 |
| ✅ | [`drr_bursty_frame2_boundary_native_sv`](REPORT/cross/drr_bursty_frame2_boundary_native_sv.md) | drr_bursty_frame2_boundary | native_sv | OPQ_DRR_BURSTY_FRAME2_BOUNDARY | 4 | 58.32 |
| ✅ | [`bp_predrop_boundary_native_sv`](REPORT/cross/bp_predrop_boundary_native_sv.md) | bp_predrop_boundary | native_sv | OPQ_BP_PREDROP_BOUNDARY | 104 | 62.07 |
| ✅ | [`overflow_step2_boundary_native_sv`](REPORT/cross/overflow_step2_boundary_native_sv.md) | overflow_step2_boundary | native_sv | OPQ_OVERFLOW_STEP2_BOUNDARY | 10 | 62.4 |
| ⚠️ | [`error_counter_clear_native_sv`](REPORT/cross/error_counter_clear_native_sv.md) | error_counter_clear | native_sv | OPQ_ERROR_COUNTER_CLEAR | 2 | 38.3 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](REPORT/cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | native_sv_depth512 | OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512 | 64 | 58.88 |

## Index

- [`REPORT/README.md`](REPORT/README.md) — reviewer entry point
- [`REPORT/buckets/`](REPORT/buckets/) — ordered-merge trace per bucket
- [`REPORT/cases/`](REPORT/cases/) — one page per stable report case ID
- [`REPORT/cross/`](REPORT/cross/) — one page per signoff run
- [`DV_COV.md`](DV_COV.md) — coverage totals, ordering, and baseline scope
- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable source of truth

_This dashboard is generated by `packet_scheduler/tb/scripts/dv_report_gen_local.py`. Edits are overwritten; fix the JSON or the local generator instead._

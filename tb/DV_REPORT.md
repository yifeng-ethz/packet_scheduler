# ✅ DV Report — packet_scheduler ordered_priority_queue native_sv

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-20` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Health

| status | field | value |
|:---:|---|---|
| ✅ | failed_cases | `0` |
| ✅ | signoff_runs_with_failures | `0` |
| ⚠️ | catalog_backlog_cases | `945` |
| ✅ | unimplemented_cases | `0` |
| ✅ | stale_artifacts | `0` |

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `2` |
| OPQ_N_SHD | `128`, `256`, `512` |
| MODE | `MERGING` |
| probe_only_exclusions | `opq_cross_drr_bursty_random_test` |

## Non-Claims

- lane scope: native-SV signoff claim is OPQ_N_LANE=2 only
- excluded probe cases: `opq_cross_drr_bursty_random_test`
- mode scope: MERGING mode only is claimed in the active native-SV report
- n shd scope: native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only
- four lane status: 4-lane native-SV remains out of signoff scope until dedicated 4-lane DV evidence is promoted; the standalone Arria 10 synthesis result is now recorded separately in signoff
- bursty drr probe status: the named green-side companion opq_cross_drr_bursty_frame2_boundary_test now passes with expected=298 actual=298 missing=0 ghost=0, but the reduced deterministic opq_cross_drr_bursty_frame3_repro_test still fails with expected=484 actual=254 missing=230 ghost=0 and the full 8-frame screen still fails with lane0 unexplained=368; the larger failure family remains probe-only
- mixed bucket seconds probe status: the exact 183..190 reproducer is green, and the full stretched mixed-bucket seconds soak now also passes end to end on the repaired allocator state; the screen remains probe-only because of runtime, not because of a live failure
- continuous frame scope: fixed bucket-frame baselines cover the default-build promoted matrix only; dedicated supplemental signoff runs now track mixed-bucket random soak, the bursty DRR frame_count=2 green boundary, the default-build legal pre-drop boundary, the default-build two-step legal overflow boundary, counter-clear semantics, and the reduced-depth overflow build point, while PARAM elaboration points still remain separate

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 146 | 7 | 7 | 139 | stmt=76.78, branch=68.80, cond=39.09, expr=58.33, fsm_state=86.36, fsm_trans=44.00, toggle=33.73 | 69.27% (7/7) |
| ⚠️ | [`PARAM`](REPORT/buckets/PARAM.md) | 180 | 6 | 6 | 174 | stmt=84.28, branch=72.12, cond=48.15, expr=70.91, fsm_state=85.71, fsm_trans=43.75, toggle=46.76 | 67.37% (6/6) |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 168 | 9 | 9 | 159 | stmt=74.21, branch=64.99, cond=34.56, expr=55.21, fsm_state=84.09, fsm_trans=41.00, toggle=27.95 | 68.42% (9/9) |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 168 | 8 | 8 | 160 | stmt=75.50, branch=66.49, cond=35.69, expr=57.29, fsm_state=84.09, fsm_trans=42.00, toggle=30.59 | 64.03% (8/8) |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 166 | 9 | 9 | 157 | stmt=82.87, branch=76.57, cond=46.74, expr=69.79, fsm_state=95.45, fsm_trans=58.00, toggle=34.10 | 71.74% (9/9) |
| ⚠️ | [`CROSS`](REPORT/buckets/CROSS.md) | 165 | 9 | 9 | 156 | stmt=82.43, branch=78.30, cond=54.33, expr=72.41, fsm_state=93.18, fsm_trans=52.00, toggle=50.51 | 83.26% (9/9) |

## Totals

| status | metric | pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 88.75 | 95.0 |
| ⚠️ | branch | 83.53 | 90.0 |
| ℹ️ | cond | 59.22 | - |
| ℹ️ | expr | 72.58 | - |
| ✅ | fsm_state | 97.73 | 95.0 |
| ⚠️ | fsm_trans | 62.00 | 90.0 |
| ⚠️ | toggle | 51.85 | 80.0 |

- catalog_planned_cases: `993`
- promoted_signoff_cases: `48`
- evidenced_promoted_cases: `48`
- promoted functional coverage: `92.94% (48/48)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| ✅ | [`bucket_frame_native_sv`](REPORT/cross/bucket_frame_native_sv.md) | bucket_frame | native_sv | OPQ_BUCKET_FRAME_NATIVE_SV | 406 | 77.94 |
| ✅ | [`all_buckets_frame_native_sv`](REPORT/cross/all_buckets_frame_native_sv.md) | all_buckets_frame | native_sv | OPQ_ALL_BUCKETS_FRAME_NATIVE_SV | 434 | 77.74 |
| ✅ | [`mixed_bucket_random_soak_native_sv`](REPORT/cross/mixed_bucket_random_soak_native_sv.md) | mixed_bucket_random_soak | native_sv | OPQ_MIXED_BUCKET_RANDOM_SOAK | 1160 | 70.96 |
| ✅ | [`drr_bursty_frame2_boundary_native_sv`](REPORT/cross/drr_bursty_frame2_boundary_native_sv.md) | drr_bursty_frame2_boundary | native_sv | OPQ_DRR_BURSTY_FRAME2_BOUNDARY | 4 | 57.35 |
| ✅ | [`bp_predrop_boundary_native_sv`](REPORT/cross/bp_predrop_boundary_native_sv.md) | bp_predrop_boundary | native_sv | OPQ_BP_PREDROP_BOUNDARY | 104 | 62.07 |
| ✅ | [`overflow_step2_boundary_native_sv`](REPORT/cross/overflow_step2_boundary_native_sv.md) | overflow_step2_boundary | native_sv | OPQ_OVERFLOW_STEP2_BOUNDARY | 14 | 61.9 |
| ⚠️ | [`error_counter_clear_native_sv`](REPORT/cross/error_counter_clear_native_sv.md) | error_counter_clear | native_sv | OPQ_ERROR_COUNTER_CLEAR | 2 | 38.3 |
| ✅ | [`error_ftable_overflow_depth512_native_sv`](REPORT/cross/error_ftable_overflow_depth512_native_sv.md) | error_ftable_overflow_depth512 | native_sv_depth512 | OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512 | 64 | 60.27 |

## Index

- [`REPORT/README.md`](REPORT/README.md) — reviewer entry point
- [`REPORT/buckets/`](REPORT/buckets/) — ordered-merge trace per bucket
- [`REPORT/cases/`](REPORT/cases/) — one page per stable report case ID
- [`REPORT/cross/`](REPORT/cross/) — one page per signoff run
- [`DV_COV.md`](DV_COV.md) — coverage totals, ordering, and baseline scope
- [`DV_REPORT.json`](DV_REPORT.json) — machine-readable source of truth

_This dashboard is generated by `packet_scheduler/tb/scripts/dv_report_gen_local.py`. Edits are overwritten; fix the JSON or the local generator instead._

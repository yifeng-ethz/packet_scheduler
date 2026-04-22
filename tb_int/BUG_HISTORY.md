# BUG_HISTORY.md - packet_scheduler/tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal traffic, about `50%` link load, iid per-lane behavior, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus
- detailed `min / p50 / max` first-hit sim-time studies may still appear inside individual bug sections; current measured mixed-soak encounter data is archived in `/tmp/opq_bug_encounter_20260419/encounter_summary.tsv`

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- `BUG-015-H` through `BUG-017-H` are archived OSS `sby` / `yosys` evidence
  from the pre-`2026-04-21` migration window.
- The current supported formal direction is `qverify` / `znformal`, and the
  current supported simulator runtime is `QuestaOne 2026` at
  `/data1/questaone_sim/questasim`.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-cluster-domain-long-run-cases-falsely-failed-on-source-lane-silence) | H | non-datapath-refactor | `corner-only (cluster-domain long-run matrix)` | fixed | `PROF_TBINT_053_LCB0` | `pending` | Cluster-domain long-run cases falsely failed when legally quiet source lanes were treated as errors. |
| [BUG-002-H](#bug-002-h-short-mode-long-run-cases-falsely-failed-on-a-h0-exact-identity-matching) | H | non-datapath-refactor | `corner-only (short-frame long-run matrix)` | fixed | `PROF_TBINT_065_SUP0` | `pending` | Short-mode A->H0 scoreboard matching compared the wrong projected identity and falsely reported missing/ghost hits. |
| [BUG-003-H](#bug-003-h-sparse-stochastic-long-run-cases-falsely-failed-on-legal-quiet-lanes) | H | non-datapath-refactor | `corner-only (sparse stochastic long-run matrix)` | fixed | `PROF_TBINT_105_SHN0` | `pending` | Sparse stochastic profiles falsely failed when legal zero-hit lanes were still required to show source activity. |

## 2026-04-17

### BUG-001-H: Cluster-domain long-run cases falsely failed on source-lane silence
- First seen in: `PROF_TBINT_053_LCB0`, `PROF_TBINT_054_LCB1`, `PROF_TBINT_055_LCB2`, `PROF_TBINT_056_LCB3`
- Symptom:
  - the `L/C/B/*` long-run bucket failed with `UVM_ERROR` reports such as `stage A lane X silent`, `stage H0 lane X silent`, and `stage H1 lane X silent`
  - the same transcripts still showed clean FEB closure through `C->D`; the only lane-level loss was `D->E`, which is observational in this matrix
- Root cause:
  - `tb_int_scoreboard::report_phase()` unconditionally enforced per-lane source activity at stages `A`, `H0`, and `H1`
  - cluster-domain profiles (`cluster_cross_asic=1`) are allowed to concentrate traffic onto a subset of lanes, so silence on the non-selected lanes is legal and should not be escalated as a failure
- Fix status: fixed in working tree, not yet committed
- Runtime / coverage context:
  - the scoreboard now suppresses source-side per-lane silence errors when the configured emulator profile enables cross-ASIC clustering
  - aggregate stage activity checks and the required FEB lossless boundaries (`A->H0`, `H0->H1`, `H1e->B`, `B->C`, `C->D`) remain enforced
- Commit: pending

### BUG-002-H: Short-mode long-run cases falsely failed on A->H0 exact-identity matching
- First seen in: `PROF_TBINT_065_SUP0` through `PROF_TBINT_080_SUM3`
- Symptom:
  - every short-frame case in bucket `B4` failed with large `A->H0` missing/ghost counts even though `tb_int_top` debug showed non-zero `h0_valid_term` and normal downstream closure
  - the failing logs showed `A=1 H0=0` for thousands of exact-match buckets while the coarse `(channel, t_fine)` ledgers still tracked correctly
- Root cause:
  - the scoreboard treated the raw stage-A emulator storage word as if long-mode parser fields survived unchanged into `frame_rcv_ip` hit_type0 output
  - in short mode, `frame_rcv_ip` only preserves `channel`, `TCC`, and `T_Fine`, and zeroes the lower parser fields; the scoreboard was comparing the wrong projection
- Fix status: fixed in working tree, not yet committed
- Runtime / coverage context:
  - `extract_key_stage_a_h0()` now projects stage-A words through the same short/long parser contract used by `frame_rcv_ip`
  - rerunning wave `65-80` after the fix cleared the entire short-frame bucket without RTL changes
- Commit: pending

### BUG-003-H: Sparse stochastic long-run cases falsely failed on legal quiet lanes
- First seen in: `PROF_TBINT_105_SHN0`
- Symptom:
  - the rerun matrix uncovered a new failure in `case_105` with `stage A/H0/H1 lane X silent` errors on lanes that were configured for sparse short-frame noise traffic
  - the active lanes still showed clean `A->H0`, `H0->H1`, `H1e->B`, `B->C`, and `C->D` closure; only `D->E` telemetry deltas remained, which are observational in this matrix
- Root cause:
  - after the cluster-domain fix, the scoreboard still assumed every enabled lane must emit at least one source hit
  - that assumption is invalid for sparse stochastic Poisson/noise/mixed profiles, where a lane can legally produce zero hits within the bounded run window
- Fix status: fixed in working tree, not yet committed
- Runtime / coverage context:
  - source-lane silence checks are now mode-aware: they hard-fail only when a lane is structurally required to be active or when upstream activity disappears across `A->H0` or `H0->H1`
  - rerunning wave `97-112` after the fix cleared `case_105` and restored a full `PASS` wave summary
- Commit: pending

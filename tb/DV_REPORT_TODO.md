# OPQ Native-SV DV Report Todo

**Target report:** `packet_scheduler/tb/DV_REPORT.md`  
**Target DUT:** `packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv` via `DUT_IMPL=native_sv`  
**Date:** 2026-04-17

This checklist is the worklist required to produce a full `dv-workflow`
report for the native-SV OPQ path. The final `DV_REPORT.md` must be generated
from `DV_REPORT.json`; it is not the place to hand-maintain todo items.

Assumption frozen on 2026-04-17: the current harness must be upgraded into a
full native-SV signoff harness. The VHDL path may remain as a debug/reference
comparison path, but it must not contribute to final signoff evidence.

## Exit Criteria

- [x] `DV_REPORT.json` exists and is the single source of truth for the OPQ
      report tree.
- [x] `DV_REPORT.md`, `DV_COV.md`, and `REPORT/` are generated from the JSON
      and reflect the native-SV DUT only.
- [x] Every promoted case has isolated native-SV log and UCDB evidence.
- [x] `bucket_frame` and `all_buckets_frame` baselines exist, are reproducible,
      and are linked from the report.
- [ ] `BUG_HISTORY.md` records every real DV-found bug with fix status and
      commit hash when fixed.
- [x] Open probe-only failures are either fixed and promoted or explicitly
      excluded from signoff with justification.

## 1. Upgrade The Harness To Native-SV-Only Signoff

- [x] Scope decision: OPQ signoff for this report is `DUT_IMPL=native_sv` for
      all promoted runs; the VHDL path is reference-only.
- [x] Make the bucket runners and report-generation flow default to
      `DUT_IMPL=native_sv`.
- [x] Add guardrails so signoff/report scripts fail fast if a promoted run is
      attempted with `DUT_IMPL!=native_sv`.
- [x] Keep any VHDL comparison data segregated from signoff artifacts so it
      cannot be merged into native-SV totals by accident.
- [x] Reconcile the current docs so they stop mixing "native SV target" and
      "VHDL reference harness" language:
      - `packet_scheduler/tb/DV_PLAN.md`
      - `packet_scheduler/tb/DV_HARNESS.md`
      - `packet_scheduler/tb/README.md`
- [x] Freeze the promoted scope that this report will claim:
      - lane count: `OPQ_N_LANE=2` only
      - `N_SHD`: `128 / 256 / 512`
      - `MODE`: `MERGING` only
      - probe-only exclusions that remain outside signoff:
        `opq_cross_drr_bursty_random_test`,
        `opq_error_header_mask_recovery_test`,
        `opq_error_ftable_overflow_test`
- [x] Write the explicit non-claims in `DV_REPORT.json` / `DV_COV.md` so the
      dashboard does not imply closure on unsupported sweeps.
      Status: both generated top-level pages now surface signoff scope,
      exclusions, and current continuous-frame non-claims directly from JSON.

## 2. Create The Mandatory dv-workflow Report Scaffold

- [x] Create `packet_scheduler/tb/DV_REPORT.json`.
- [x] Create `packet_scheduler/tb/DV_COV.md`.
- [x] Create the generated tree:
      - `packet_scheduler/tb/REPORT/README.md`
      - `packet_scheduler/tb/REPORT/buckets/`
      - `packet_scheduler/tb/REPORT/cases/`
      - `packet_scheduler/tb/REPORT/cross/`
      - `packet_scheduler/tb/REPORT/txn_growth/`
- [x] Add a repo-local wrapper to regenerate the report, for example
      `packet_scheduler/tb/scripts/gen_dv_report.sh`, which calls
      the repo-local `packet_scheduler/tb/scripts/dv_report_gen_local.py`
      wrapper after rebuilding `DV_REPORT.json`.
- [x] Keep `DV_REPORT.md` one-screen-per-bucket and move per-case detail into
      `REPORT/`.

## 3. Normalize Case Inventory And Naming

- [x] Convert the promoted testcase catalog into stable report case IDs that
      follow the `TYPE_MODULE_ID_description` rule from `dv-workflow`.
- [x] Decide whether the UVM class names will be renamed, or whether the report
      will carry an alias map from legacy test names to compliant case IDs.
      Decision: keep live UVM testcase names as evidence anchors and publish a
      generated alias map to stable report case IDs.
- [x] Build the per-bucket promoted list in JSON for:
      - `DV_BASIC`
      - `DV_PARAM`
      - `DV_EDGE`
      - `DV_PROF`
      - `DV_ERROR`
      - `DV_CROSS`
- [x] Keep `DV_PROBE.md` reproducers out of the promoted bucket counts until
      they are genuinely signoff-ready.

## 4. Collect Isolated Native-SV Evidence

- [x] Rerun every promoted testcase with `DUT_IMPL=native_sv`.
- [x] Save one passing isolated log and one UCDB per promoted case under a
      stable naming convention that the report generator can link to.
- [x] Record for each case:
      - pass/fail
      - seed
      - observed transaction count
      - build knobs (`OPQ_N_LANE`, `OPQ_N_SHD`, `OPQ_TICKET_FIFO_DEPTH`,
        `OPQ_PAGE_RAM_DEPTH`)
      - log summary fields worth surfacing to the chief architect
- [x] Ensure `DV_PARAM` evidence is separated by build point rather than
      collapsed into one generic testcase row.
- [x] Make sure the isolated evidence is all native-SV before it is allowed to
      contribute to the final report totals.
- [x] Re-run any currently "green" bucket that was last evidenced on the VHDL
      wrapper path so the native-SV signoff claim is real rather than inferred.

## 5. Build The Coverage Accounting Required By dv-workflow

- [x] Extend the current coverage flow so each passing isolated testcase has:
      - standalone code coverage
      - ordered incremental bucket gain
      - ordered merged total after the case
      - per-transaction gain for random tests
- [x] Populate `DV_COV.md` with the required per-bucket ordering and merged
      totals for:
      - statement
      - branch
      - condition
      - expression
      - FSM state / transition
      - toggle
- [x] Document unsupported categories explicitly instead of silently omitting
      them.
- [x] Preserve traceability from each bucket total back to the per-case rows in
      `REPORT/cases/` and `REPORT/buckets/`.
- [ ] Capture coverage-hole disposition: real gap, justified exclusion,
      redundant case, or needs-new-test.

## 6. Implement Continuous-Frame Baselines

- [x] Define explicit bucket order and case order for `bucket_frame`.
- [x] Define explicit bucket order and case order for `all_buckets_frame`.
- [x] Add runners for no-restart execution; the current scripts only cover
      isolated execution.
- [x] Verify the scoreboard, reset handling, counters, and sequence plumbing can
      run multiple cases in one continuous frame without hidden restart
      assumptions.
      Result: the native-SV continuous-frame runner now carries serial and
      timestamp identity across composed cases, and both mandatory no-restart
      baselines pass on the signoff default build.
- [x] Generate one report page per continuous-frame signoff run under
      `REPORT/cross/`.
- [x] Link the continuous-frame baselines from both `DV_COV.md` and
      `DV_REPORT.md`.

## 7. Add Random-Test Transaction-Growth Evidence

- [ ] Identify which promoted cases are random and require checkpoint growth
      curves.
- [ ] Add checkpoint-UCDB collection for those cases.
- [ ] Generate `REPORT/txn_growth/<case_id>.md` for each promoted random case.
- [ ] If checkpoint UCDBs are not yet practical, create the required pages
      anyway and state the limitation explicitly until the flow is implemented.

## 8. Close Native-SV DUT And Observability Blockers

- [ ] Resolve the open lane-mask recovery bug before promoting
      `opq_error_lane_mask_recovery_test`.
- [ ] Resolve the forced-overwrite / malformed-egress bug before promoting
      `opq_error_ftable_overflow_test`.
- [ ] Resolve the bursty DRR stall-boundary corruption before promoting
      `opq_cross_drr_bursty_random_test`.
- [x] Resolve the native-SV no-reset drain / credit-restore bug before calling
      `bucket_frame` or `all_buckets_frame` signoff closed.
- [ ] Add enough late-drop observability to prove hit integrity on the bursty
      DRR path, or explicitly keep that path probe-only.
- [ ] Close the remaining harness-upgrade gaps that would block full native-SV
      ownership:
      - scoreboard and SVA parity between native-SV and prior reference runs
      - build/run support for every promoted bucket under `DUT_IMPL=native_sv`
      - native-SV-only closure for any parameter points claimed in the report
- [ ] Decide whether 4-lane native-SV closure is in scope for this report:
      - if yes, fix the sparse-frame cadence issue logged in `BUG_HISTORY.md`
      - if no, mark 4-lane as a non-claim in the report

## 9. Update BUG_HISTORY With Signoff Discipline

- [ ] Audit `packet_scheduler/tb/BUG_HISTORY.md` against every real bug exposed
      during the report build.
- [ ] Add first-seen testcase / regression context for any missing entries.
- [ ] Add fix commit hashes for every fixed issue.
- [ ] Mark deferred issues with explicit blocking reasons instead of leaving
      them ambiguous.

## 10. Generate And Review The Final Report

- [x] Generate the report tree from `DV_REPORT.json`.
- [x] Verify that `DV_REPORT.md` is a chief-architect dashboard, not a testcase
      dump.
- [x] Verify that every bucket summary count matches the JSON and real evidence.
- [x] Verify that every case link resolves to an actual log, UCDB, and case
      detail page.
- [x] Verify that `DV_COV.md` and `DV_REPORT.md` agree on bucket totals and
      execution-mode baselines.
- [x] Run one final native-SV regression pass before calling the report closed.

## Recommended Execution Order

- [x] Phase 1: freeze scope, create `DV_REPORT.json`, and add the generator
      wrapper.
- [x] Phase 2: rerun isolated promoted cases and populate per-case evidence.
- [x] Phase 3: compute incremental coverage and fill `DV_COV.md`.
- [x] Phase 4: implement `bucket_frame` and `all_buckets_frame`.
- [ ] Phase 5: close or explicitly defer the open probe-only SV bugs.
- [x] Phase 6: generate `DV_REPORT.md` / `REPORT/` and review for signoff.

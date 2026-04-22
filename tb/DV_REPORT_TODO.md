# OPQ Native-SV DV Report Todo

**Target report:** `packet_scheduler/tb/DV_REPORT.md`  
**Target DUT:** `packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv` via `DUT_IMPL=native_sv`  
**Date:** 2026-04-22

This checklist is the worklist required to produce a full `dv-workflow`
report for the native-SV OPQ path. The final `DV_REPORT.md` must be generated
from `DV_REPORT.json`; it is not the place to hand-maintain todo items.

Current toolchain migration note on 2026-04-21:

- The maintained packet_scheduler UVM makefiles now target the supported
  QuestaOne 2026 runtime with `-ini` instead of the deprecated
  `-modelsimini` flag for `vlog` / `vcom` / `vsim` / `vopt`.
- The current QuestaOne compatibility reruns are now split cleanly between
  real current evidence and the remaining documented non-claim:
  `opq_basic_smoke_test`,
  `opq_cross_drr_bursty_large_repro_test`, and
  `opq_cross_random_ready_overflow_extensive_soak_test` all rerun green on
  `2026-04-21`, while the full-depth
  `opq_cross_bp_mustdrop_witness_test` still fails only because
  `ft_drop_*` never advances even though aggregate hit conservation and the
  frame-table `wr = rd + drop` ledger stay clean.
- The supported QuestaOne reruns of `tb/scripts/run_all.sh` and
  `tb/scripts/run_cov_closure.sh` are clean on this host.
- The refreshed `tb/scripts/run_frame_signoff.sh` evidence is now coherent on
  the supported runtime: `bucket_frame`, `all_buckets_frame`, mixed-bucket
  random soak, bursty DRR frame2 boundary, overflow step2 boundary,
  counter-clear, reduced-depth overflow, and the legal pre-drop boundary all
  rerun coherently; there is no longer a red supplemental signoff run in this
  maintained default-build set.
- Those reruns remain useful supplemental evidence, but the active generated
  dashboard is now the canonical
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  slice and credits only current-scope reruns. That slice is now fully staged
  into the generated dashboard with `516/516` isolated catalog rows evidenced
  and `22/22` maintained signoff runs green; older stale `sim_runs/logs/*.log`
  artifacts and pre-2026 FSE logs must still not be counted as current
  evidence.

Assumption frozen on 2026-04-17: the current harness must be upgraded into a
full native-SV signoff harness. The VHDL path may remain as a debug/reference
comparison path, but it must not contribute to final signoff evidence.

Execution order frozen on 2026-04-18 for the next closure phase:

1. Re-anchor the harness and report flow on invariant-first sanity checks:
   end-to-end accepted hits, expected drops, per-lane throughput, and packet
   correctness at ingress, internal OPQ boundaries, and egress.
2. Use those invariants to close the real native-SV DUT and observability
   blockers before spending effort on narrow cycle-level cleanups.
3. Keep long mixed-bucket and overflow/backpressure soaks in the loop, but
   tune them to reach useful checkpoints quickly enough that they remain
   practical closure evidence rather than passive background runs.

## Exit Criteria

- [x] `DV_REPORT.json` exists and is the single source of truth for the OPQ
      report tree.
- [x] `DV_REPORT.md`, `DV_COV.md`, and `REPORT/` are generated from the JSON
      and reflect the native-SV DUT only.
- [x] Every canonical catalog case has isolated current-scope native-SV log and
      UCDB evidence.
      Status on `2026-04-22`: the active canonical dashboard now carries
      `516/516` evidenced rows with `failed_cases=0`,
      `catalog_backlog_cases=0`, and `unimplemented_cases=0`.
- [x] `bucket_frame` and `all_buckets_frame` baselines exist, are reproducible,
      and are linked from the report.
- [x] `BUG_HISTORY.md` records every real DV-found bug with fix status and
      commit hash when fixed.
- [x] Open probe-only failures are either fixed and promoted or explicitly
      excluded from signoff with justification.
- [ ] Structural coverage targets are closed or dispositioned against the
      current native-SV isolated merged baseline.
      Status on `2026-04-22`: testcase implementation and evidence collection
      are closed, but the active merged isolated report is still below target
      on `stmt`, `branch`, `fsm_state`, `fsm_trans`, and `toggle`, so the
      remaining work is coverage closure rather than report scaffolding.

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
- [x] Freeze the active generated scope that this report will claim:
      - lane count: `OPQ_N_LANE=4`
      - `N_SHD`: `128`
      - `OPQ_TICKET_FIFO_DEPTH`: `256`
      - `MODE`: `MERGING` only
      - `DUT_IMPL`: `native_sv`
      - probe-only exclusions remain outside the isolated generated matrix and
        must be tracked separately in supplemental notes / bug history
- [x] Write the explicit non-claims in `DV_REPORT.json` / `DV_COV.md` so the
      dashboard does not imply closure on unsupported sweeps.
      Status: both generated top-level pages now surface signoff scope,
      exclusions, and current signoff-run non-claims directly from JSON.
- [ ] Record the post-signoff parameter-expansion phase explicitly:
      - future synthesis target family is `online_sc/a10_board`
      - future lane sweep must cover `OPQ_N_LANE={2,4,8,16}`
      - timing closure for those lane points is allowed to add adaptive
        pipeline insertion and/or FSM repartitioning at the real critical cones
      - those later parameter points do not inherit DV closure from the current
        generated `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256`
        baseline and need their own DV evidence
- [x] Add an explicit invariant-first sanity plan to the live todo and keep it
      ahead of case-by-case cleanup:
      - quantify accepted hits, expected drops, and per-lane rates end to end
      - check packet structure at ingress, data mover / frame table, and
        egress boundaries
      - require long-run screens to report whether losses were observed through
        legal counted paths or through unexpected silent corruption
      Status on `2026-04-19`:
      - the same invariant-first guidance is now frozen in the repo-root
        `AGENTS.md`
      - the live closure screens use per-lane checkpoint ledgers and treat the
        first non-zero `unexplained` hit count as a hard stop for debug
- [ ] Freeze the per-lane hit conservation law that all long-run debug must use:
      `accepted_ingress_hits = legal_drops + delivered_egress_hits + unexplained_hits`
      with `legal_drops` split into the currently observable buckets:
      parser reject, lane-local late/masked drop, and frame-table drop.
- [ ] Freeze the three authoritative packet ledgers for the active monolithic
      signoff path:
      - ingress accepted-frame ledger
      - mover / frame-table write-drop ledger
      - egress emitted-frame ledger
      Each ledger must carry `frame_id/pkg_cnt`, `lane_id`, sub-header count,
      total hit count, and drop-reason classification or `none`.
      Priority frozen on `2026-04-19`: the mover / frame-table write-drop
      ledger is the first missing authoritative boundary and must be added
      before further broad random reruns are trusted.

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
- [x] Capture coverage-hole disposition: real gap, justified exclusion,
      redundant case, or needs-new-test.
      Status: `DV_REPORT.json` now records generated hole-disposition rows from
      the merged native-SV UCDB, and `DV_COV.md` renders them as a coverage
      closure table tied to open bugs, justified non-claims, or no-value
      memory-toggle churn.

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
- [x] Promote the remaining passing supplemental screens into first-class
      signoff runs instead of leaving them as isolated evidence only.
      Status on `2026-04-20`:
      - `run_frame_signoff.sh` now refreshes the fixed bucket-frame baselines
        plus six supplemental signoff runs:
        `opq_cross_mixed_bucket_random_soak_test`,
        `opq_cross_drr_bursty_frame2_boundary_test`,
        `opq_cross_bp_predrop_boundary_test`,
        `opq_cross_random_ready_overflow_step2_boundary_test`,
        `opq_error_counter_clear_test`, and
        `opq_error_ftable_overflow_test`
      - the generated dashboard now gives each of those screens its own
        `REPORT/cross/*.md` page and keeps the fixed baselines explicit about
        their limited default-build scope
      - the current green supplemental screens are the mixed-soak run, the
        bursty DRR `frame_count=2` boundary, the legal pre-drop boundary, the
        legal two-step random-ready overflow boundary, and the counter-clear
        screen
      - the reduced-depth overflow rerun still reopens `opq_hit3_contract`
        frame-trailer/pkg_cnt/timestamp errors, so that elaboration point
        remains red

## 7. Add Random-Test Transaction-Growth Evidence

- [x] Identify which promoted cases are random and require checkpoint growth
      curves.
      Result: `opq_cross_mixed_bucket_random_soak_test` is now a promoted
      native-SV random signoff case and is recorded as such in the generated
      report set.
- [x] Add checkpoint-UCDB collection for those cases.
      Result: the current flow still saves only the final UCDB for
      `opq_cross_mixed_bucket_random_soak_test`; the required txn-growth page
      exists and explicitly records the missing checkpoint-UCDB limitation.
- [x] Generate `REPORT/txn_growth/<case_id>.md` for each promoted random case.
      Result: `REPORT/txn_growth/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test.md`
      is generated and linked from `REPORT/txn_growth/README.md`.
- [x] Add an earlier extended mixed-bucket random soak run to the live closure
      flow so long chained no-restart bugs are exercised before final signoff
      report freeze, and keep it tracked as a supplemental signoff run rather
      than silently folding it into the fixed no-restart baseline.
      Status refreshed on `2026-04-19`:
      - implemented as `opq_cross_mixed_bucket_seconds_soak_test`
      - canonical bug-hunt config uses `+TB_CLK_PERIOD_NS=250`
      - current result is probe-only, not promoted, because of runtime only:
        the full stretched rerun is now green end to end and is kept as an
        isolated long-run stress screen outside the default promoted matrix
- [x] If checkpoint UCDBs are not yet practical, create the required pages
      anyway and state the limitation explicitly until the flow is implemented.

## 8. Close Native-SV DUT And Observability Blockers

- [ ] Reclassify the remaining open blockers by violated invariant family so
      debug stays ledger-driven instead of testcase-driven:
      - hit accounting / silent-loss risk
      - packet-boundary contract corruption
      - missing legal-drop observability
      - out-of-scope parameter / lane non-claim
      Current mapping refreshed on `2026-04-19`:
      - the former `BUG-011-R` packet-boundary corruption is closed by the
        repaired chained malformed-subheader recovery path
      - the former `BUG-018-H` long-run hit-accounting risk is closed by the
        clean full stretched mixed-bucket seconds soak rerun
      - 4-lane scope statement remains the only active out-of-scope parameter /
        lane non-claim until native-SV 4-lane DV evidence is live; standalone
        A10 synthesis evidence is already closed
- [ ] Resolve the forced-overwrite / malformed-egress bug before promoting
      `opq_error_ftable_overflow_test`.
      Status refreshed on `2026-04-20`:
      - the dedicated reduced-depth supplemental signoff plumbing is now in
        place, but the fresh rerun is not clean
      - `opq_error_ftable_overflow_test` now reopens
        `opq_hit3_contract` frame-trailer/pkg_cnt/timestamp errors on accepted
        egress
      - keep the testcase outside the fixed no-restart baselines and do not
        treat the reduced-depth point as closed until that accepted-egress
        contract failure is debugged again
- [x] Refresh the larger bursty DRR random closure path before promoting
      `opq_cross_drr_bursty_random_test`.
      Status on `2026-04-21`:
      - the allocator repair now holds merged-frame progress until every
        already-active busy lane has surfaced its current ticket, so the late
        same-frame ticket loss is no longer reproduced
      - the named `opq_cross_drr_bursty_frame3_repro_test` is green again with
        `expected=714 actual=714 missing=0 ghost=0`
      - the refreshed larger constrained-random reruns are also green:
        seed `1` closes with `expected=990 actual=990 missing=0 ghost=0`,
        seeds `2..8` close with `expected=1864 actual=1864 missing=0 ghost=0`,
        and every rerun ends with per-lane `unexplained=0`
      - the bursty DRR random screen stays supplemental by reporting choice,
        not because of an active correctness failure
- [x] Promote the `2026-04-20` isolated-pass bucket expansions into the live
      report flow only after wrapper order, bucket-frame coverage ordering, and
      no-restart evidence are captured:
      - `DV_BASIC`: `opq_basic_single_active_lane_lane1_test`,
        `opq_basic_single_active_lane_dense_test`
      - `DV_EDGE`: `opq_edge_long_toggle_backpressure_test`,
        `opq_edge_max_hits_backpressure_test`
      - `DV_PROF`: `opq_prof_heavy_lane_skew_test`,
        `opq_prof_deep_whole_frame_skew_test`,
        `opq_prof_asymmetric_missing_empty_frame_test`
      - `DV_ERROR`: `opq_error_header_mask_recovery_test`,
        `opq_error_header_word_mask_recovery_test`
      Status on `2026-04-20`:
      - `run_basic.sh`, `run_edge.sh`, and `run_perf.sh` now wire the expanded
        promoted sets by default
      - `opq_frame_signoff_tests.sv` and `build_dv_report_json.py` now include
        the expanded BASIC / EDGE / PROF / ERROR matrices in both isolated
        ordering and default-build no-restart baselines
      - clean native-SV reruns now close the expanded isolated buckets plus
        `opq_bucket_frame_native_sv_test` and
        `opq_all_buckets_frame_native_sv_test`
      - after the fresh reduced-depth overflow rerun and the report pass/fail
        fix, regenerated totals now record `promoted_signoff_cases=46` and
        `evidenced_promoted_cases=45`
- [x] Resolve the chained malformed-header recovery corruption before
      promoting `opq_error_header_mask_recovery_test` and
      `opq_error_header_word_mask_recovery_test`.
      Status on `2026-04-20`:
      - isolated native-SV is green for both restored header-recovery cases
      - the live ERROR runner now wires both cases by default
      - `opq_bucket_frame_native_sv_test` and
        `opq_all_buckets_frame_native_sv_test` both pass with
        `header_recovery_seq` and `header_word_recovery_seq` live
      - the generated report exclusions now leave only
        `opq_cross_drr_bursty_random_test` outside the signoff claim
- [x] Resolve the chained malformed-subheader recovery corruption before adding
      `opq_error_subheader_mask_recovery_test` back into the mixed-bucket soak
      pool.
      Status on `2026-04-19`:
      - the mixed ERROR pool now re-exercises `subheader_error_recovery`
      - `opq_cross_mixed_bucket_random_soak_test` passes with that case live
      - the full stretched `opq_cross_mixed_bucket_seconds_soak_test` reaches
        repeated deep chained recovery steps, including step `509`, and still
        exits with `UVM_ERROR : 0`
      - `opq_all_buckets_frame_native_sv_test` also remains clean after the
        no-restart masked-recovery tail sequence
- [x] Resolve the hit-without-subheader contract failure still exposed by
      `opq_cross_mixed_bucket_seconds_soak_test` before promoting the earlier
      extended mixed-soak screen into the live report set.
      Status on `2026-04-19`:
      - the exact deterministic reproducer
        `opq_cross_hit3_exact_183_190_repro_test` passes cleanly
      - the companion `opq_cross_mixed_bucket_random_soak_test` also passes
      - the full stretched seconds soak now crosses the later former failure
        windows (`mixed_soak_261`, `mixed_whole_skew_275`,
        `mixed_whole_skew_418`, `mixed_whole_skew_435`) and exits with
        `UVM_ERROR : 0`, `UVM_FATAL : 0`, and `Errors: 0`
      - the screen stays probe-only only because it is a long runtime stress
        check outside the default promoted matrix, not because of a live bug
- [x] Resolve late-frame legal-drop overcount in the half-saturation random
      ready overflow screen before trusting longer overflow/backpressure
      conservation evidence.
      Status on `2026-04-19`:
      - `BUG-021-R` is now fixed on the live native-SV RTL
      - focused rerun `/tmp/opq_overflow_fix6.log` closes with
        `UVM_ERROR : 0` and per-lane
        `accepted = delivered + unexplained(0)` under the configured legal-drop
        path
      - the repaired invariant is now ticket-tail based: late-frame SOP emits
        header-drop only, and unread non-SOP tickets emit one post-drop
        subheader each with exact `block_length` / `ticket_ts`
- [x] Resolve the native-SV no-reset drain / credit-restore bug before calling
      `bucket_frame` or `all_buckets_frame` signoff closed.
- [x] Add enough late-drop observability to prove hit integrity on the bursty
      DRR path, or explicitly keep that path probe-only.
      Status on `2026-04-19`:
      - native-SV now exports pre/post ingress drop-event visibility into the
        live drop monitor and scoreboard
      - that observability now brackets the live retirement bug cleanly on the
        current tree: the identical bursty envelope passes at `frame_count=2`
        and fails at `frame_count=3`, with explicit per-lane
        `accepted / dropped / delivered / unexplained` evidence instead of
        only final CSR totals
- [ ] Add checkpoint summaries to the long mixed soak so each checkpoint
      reports, per lane:
      accepted hits, legal dropped hits, delivered hits, unexplained hits, and
      the current frame-table `wr = rd + drop` ledger state.
- [x] Add checkpoint summaries to the overflow/backpressure soaks so each
      checkpoint reports, per lane:
      accepted hits, legal dropped hits, delivered hits, unexplained hits, and
      the current frame-table `wr = rd + drop` ledger state.
      Status on `2026-04-19`:
      - `opq_cross_random_ready_overflow_seconds_soak_test` now reports both
        `overflow_step_*` and `overflow_final` ledgers with per-lane
        `expected / accepted / dropped / delivered / unexplained` plus the
        frame-table `wr = rd + drop` summary
      Status on `2026-04-20`:
      - the fresh rerun of
        `opq_cross_random_ready_overflow_seconds_soak_test` still fails at
        `overflow_step_0` with
        `ft_wr_shd wr=5 rd=7 drop=0`,
        `ft_wr_hit wr=540 rd=545 drop=0`, and lane1 `unexplained=174`
      - this confirms the checkpoint plumbing is useful, but the default-build
        overflow path is still not signoff-clean because the presenter can
        suppress unread-tail drop accounting while a live head is resident
- [x] Add a dedicated default-build legal pre-drop boundary screen so the
      report distinguishes "must not drop" evidence from the still-open
      default-build must-drop bug anchor.
      Status on `2026-04-20`:
      - implemented as `opq_cross_bp_predrop_boundary_test`
      - the passing native-SV signoff rerun closes with
        `ft_drop_hdr/shd/hit=0/0/0`, aggregate
        `accepted=13260 dropped=66612 delivered=13260 unexplained=0`, and
        `core_principles first_break=clean`
      - keep the testcase as a supplemental signoff run outside the fixed
        bucket-frame baselines because it qualifies the legal default-build
        pre-drop boundary instead of widening the promoted fixed matrix
- [ ] Close the remaining harness-upgrade gaps that would block full native-SV
      ownership:
      - scoreboard and SVA parity between native-SV and prior reference runs
      - build/run support for every promoted bucket under `DUT_IMPL=native_sv`
      - native-SV-only closure for any parameter points claimed in the report
- [x] Refresh the 4-lane native-SV scope statement in the report:
      - the old sparse-frame cadence reproducer (`BUG-007-R`) is now green on
        current RTL and should no longer be treated as an automatic non-claim
      - keep 4-lane signoff tied to real evidence instead:
        current 4-lane DV status plus the standalone A10 `N_LANE=4` synthesis
        result
      - remove the stale 4-lane non-claim wording from the report only after
        the active A10 standalone refresh is recorded
      Status on `2026-04-20`:
      - generated `DV_REPORT.md` / `DV_COV.md` now state that 4-lane native-SV
        is out of the current signoff claim because dedicated 4-lane DV
        evidence is not yet promoted, not because the old sparse-cadence bug is
        still live
      - the separate standalone Arria 10 synthesis result remains recorded as a
        signoff-side note without widening the active DV claim

## 9. Update BUG_HISTORY With Signoff Discipline

- [x] Audit `packet_scheduler/tb/BUG_HISTORY.md` against every real bug exposed
      during the report build.
- [x] Add first-seen testcase / regression context for any missing entries.
- [x] Add fix commit hashes for every fixed issue.
- [x] Mark deferred issues with explicit blocking reasons instead of leaving
      them ambiguous.
      Status: `BUG_HISTORY.md` now carries an index, numbered bug IDs, explicit
      first-seen contexts, commit linkage for fixed items, and blocking reasons
      for the current open probe-only exclusions and 4-lane non-claim.

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

## 11. Execute The Packet-Formal Plan From `DV_FORMAL.md`

- [x] Add the formal packet-shape plan as an explicit tracked workstream in the
      live todo rather than leaving it only in `DV_FORMAL.md`.
- [x] Land dedicated native-SV formal SVA for the **live signoff path**:
      - ingress parser credit / packet-write coupling
      - block mover / page-writer ownership
      - basic presenter backpressure / packet-boundary checks
      Status: implemented in `tb/uvm/sva/opq_native_*formal_sva.sv` and wired
      into the standalone UVM compile list.
- [x] Land dedicated formal SVA for the **standalone tiled path modules**:
      - frame-table tracker flush / update ordering
      - tiled presenter backpressure / packet-boundary checks
      Status: implemented as standalone native-SV checker modules so the
      assertions are present before the tiled path is promoted into the live
      top.
- [x] Add formal runner wrappers per `DV_FORMAL.md` section 10:
      - `formal_ingress.sh`
      - `formal_mover.sh`
      - `formal_egress.sh`
- [x] Run the first formal compile/elaboration round and record the current
      host/tool status in `DV_FORMAL.md`.
      Status on `2026-04-18`:
      - `formal_ingress.sh`: compile/elab pass on `opq_formal_ingress_tb`
      - `formal_mover.sh`: compile/elab pass
      - `formal_egress.sh`: compile/elab pass, including the standalone
        `opq_formal_ftable_tb` elaboration top
      - blocker: `znformal` licenses are available, but this host refresh
        still did not find a runnable `qverify` / `znformal` binary in
        `QUESTA_FORMAL_HOME`, `QUESTA_HOME=/data1/questaone_sim/questasim`,
        or `PATH`
- [x] Stabilize a no-backend fallback API that keeps the future proof entry
      points intact.
      Status on `2026-04-18`:
      - wrappers now support `FORMAL_BACKEND=auto|stress|qverify`
      - wrappers now support `QVERIFY_BIN=/path/to/qverify` as the
        backend handoff point once the proof binary is installed
      - wrappers now support `QUESTA_FORMAL_HOME=/path/to/questa_formal`
        for a separate Questa Formal / ZnFormal installation
      - wrappers now support `FORMAL_STRESS_TESTS` for targeted fallback runs
      - default fallback status:
        - ingress: pass on `opq_basic_smoke_test` +
          `opq_formal_like_ingress_recovery_stress_test` with
          `FORMAL_OPQ_N_SHD=256`, `FORMAL_OPQ_TICKET_FIFO_DEPTH=512`
        - mover: pass on
          `opq_cross_bp_credit_test`,
          `opq_formal_like_mover_drr_credit_stress_test`
        - egress: pass on
          `opq_edge_toggle_backpressure_test`,
          `opq_edge_stuck_low_backpressure_test`
      - targeted probe status:
        - `FORMAL_STRESS_TESTS=opq_formal_like_egress_flush_backpressure_stress_test`
          now passes as a clean backpressure/hold regression after the
          `BUG-014-R` presenter read-data skid fix
      - ingress probe-only exclusions: none in the current promoted matrix
- [x] Record the old OSS formal bring-up as historical evidence only.
      Status on `2026-04-21`:
      - the old `FORMAL_BACKEND=sby` path is now deprecated and blocked
      - the wrapper entry points remain stable
        (`formal_ingress.sh`, `formal_mover.sh`, `formal_egress.sh`)
      - any existing OSS `sby` results remain historical evidence only
- [x] Run the first actual formal proof round once the proof backend is
      installed, then record any failing properties back into
      `DV_FORMAL.md` and `BUG_HISTORY.md` when a real RTL issue is exposed.
      Status on `2026-04-18`:
      - the old wrapper-managed `sby` round remains captured in
        `tb/formal_runs/csv/formal_{ingress,mover,egress}_latest.csv`
        as historical evidence; the active path is now `qverify`
      - current tracked blockers:
        - `BUG-015-H`: closed for the current OSS ingress subset; the
          harness now freezes credit accounting until post-reset tracking
          is valid and proves pulse-level write/drop consistency without
          using phase-ambiguous public credit buses as exact anchors
        - `BUG-016-H`: closed for the current OSS egress subset; the
          live hold-under-backpressure presenter proof now passes
        - `BUG-017-H`: closed for the current OSS mover subset;
          `formal_mover.sh` now records `formal=sby_pass`
- [x] Close `BUG-015-H` by removing reset-warmup credit pollution from
      the ingress OSS harness and proving packet/write/drop consistency
      on pulse-level signals instead of phase-ambiguous debug counters.
      Status on `2026-04-18`:
      - `formal_ingress.sh` now records `formal=sby_pass`
      - the current OSS ingress subset proves packet-shape assumptions,
        write/drop exclusivity, and `lane_we` / `ticket_we` pulse
        consistency on the live parser path
      - public free-credit debug counters remain a documented non-claim
        for the OSS subset because they are observability signals, not
        stable proof anchors
- [x] Close `BUG-016-H` by rewriting or isolating the overwrite-drop scan
      so the basic-presenter OSS proof can reach actual hold-under-backpressure
      properties instead of stopping in Yosys lowering.
      Status on `2026-04-18`:
      - `formal_egress.sh` now records `formal=sby_pass`
      - the current OSS subset proves the live Avalon-ST hold contract
      - the old targeted stress probe now also passes after the live
        presenter fix for synchronous page-RAM return under held `ready`
      - unread-overwrite scan proof remains a documented non-claim for
        the OSS subset and still needs a separate proof strategy later
- [x] Close `BUG-017-H` by exporting or constraining a proof-clean arbiter
      state bundle in `opq_oss_block_path` so the remaining onehot/event
      invariants become basecase-clean after the page-writer ownership fix.
      Status on `2026-04-18`:
      - `formal_mover.sh` now records `formal=sby_pass`
      - the current OSS mover subset proves page-writer ownership and the
        proof-clean arbiter-shape view now stays basecase/induction clean
      - the native-SV path is unchanged; this is an OSS harness/debug export
        closure only
- [ ] Close the cross-module flush-under-backpressure proof for the tiled
      frame-table path (`ap_flush_does_not_touch_live_page`,
      `ap_tail_flush_preserves_head_region`) once the live native-SV top swaps
      from `ordered_priority_queue_monolithic_basic_presenter` to the
      frame-table tracker/presenter hookup. Today that cross-module flush proof
      is structurally blocked because the active signoff top does not yet
      instantiate the tiled presenter path.

## Recommended Execution Order

- [x] Phase 1: freeze scope, create `DV_REPORT.json`, and add the generator
      wrapper.
- [x] Phase 2: rerun isolated promoted cases and populate per-case evidence.
- [x] Phase 3: compute incremental coverage and fill `DV_COV.md`.
- [x] Phase 4: implement `bucket_frame` and `all_buckets_frame`.
- [x] Phase 5: close or explicitly defer the open probe-only SV bugs.
- [x] Phase 6: generate `DV_REPORT.md` / `REPORT/` and review for signoff.
- [ ] Phase 7: execute the `DV_FORMAL.md` packet-shape backlog, starting with
      the live basic-presenter path and then the tiled frame-table swap-over.

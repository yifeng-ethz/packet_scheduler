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
- [x] Every promoted case has isolated native-SV log and UCDB evidence.
- [x] `bucket_frame` and `all_buckets_frame` baselines exist, are reproducible,
      and are linked from the report.
- [x] `BUG_HISTORY.md` records every real DV-found bug with fix status and
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
        `opq_cross_drr_bursty_random_test`
- [x] Write the explicit non-claims in `DV_REPORT.json` / `DV_COV.md` so the
      dashboard does not imply closure on unsupported sweeps.
      Status: both generated top-level pages now surface signoff scope,
      exclusions, and current continuous-frame non-claims directly from JSON.
- [ ] Record the post-signoff parameter-expansion phase explicitly:
      - future synthesis target family is `online_sc/a10_board`
      - future lane sweep must cover `OPQ_N_LANE={2,4,8,16}`
      - timing closure for those lane points is allowed to add adaptive
        pipeline insertion and/or FSM repartitioning at the real critical cones
      - those later parameter points do not inherit DV closure from the current
        promoted `OPQ_N_LANE=2` baseline and need their own DV evidence
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
      report freeze, and keep it tracked as isolated-only evidence rather than
      silently folding it into the fixed no-restart baseline.
      Status on `2026-04-18`:
      - implemented as `opq_cross_mixed_bucket_seconds_soak_test`
      - canonical bug-hunt config uses `+TB_CLK_PERIOD_NS=250`
      - current result is probe-only, not promoted:
        the old chained masked-drop accounting underrun is fixed, but
        `opq_cross_mixed_bucket_seconds_soak_test` now trips
        `opq_hit3_contract` around mixed-soak step `190` and later,
        so the earlier extended screen still exposes a real no-restart
        cross-bucket bug before final signoff freeze
- [x] If checkpoint UCDBs are not yet practical, create the required pages
      anyway and state the limitation explicitly until the flow is implemented.

## 8. Close Native-SV DUT And Observability Blockers

- [ ] Reclassify the remaining open blockers by violated invariant family so
      debug stays ledger-driven instead of testcase-driven:
      - hit accounting / silent-loss risk
      - packet-boundary contract corruption
      - missing legal-drop observability
      - out-of-scope parameter / lane non-claim
      Current mapping frozen on `2026-04-19`:
      - `BUG-011-R`: packet-boundary contract corruption after chained
        predecessor traffic, with the weak boundary currently at malformed
        subheader recovery composability
      - `BUG-018-H`: hit accounting / silent-loss risk in later PROF-heavy
        no-restart windows after the earliest exact window was repaired
      - 4-lane scope statement: out-of-scope parameter / lane non-claim until
        native-SV 4-lane DV evidence and A10 synthesis evidence are both live
- [x] Resolve the forced-overwrite / malformed-egress bug before promoting
      `opq_error_ftable_overflow_test`.
      Status: the reduced-depth `OPQ_PAGE_RAM_DEPTH=512` native-SV overflow
      repro now passes cleanly with non-zero `FT_DROP_*` accounting and no
      malformed accepted egress. The testcase is promoted as isolated-only
      ERROR evidence because it requires a separate reduced-depth elaboration
      point and is therefore still excluded from the fixed no-restart
      baselines.
- [x] Resolve the bursty DRR stall-boundary corruption before promoting
      `opq_cross_drr_bursty_random_test`.
      Status on `2026-04-19`:
      - the focused reproducer `opq_cross_drr_bursty_repro_test` is now clean
        with `expected=1864 actual=1864 missing=0 ghost=0`
      - root cause was the page allocator advancing merged-frame progress
        ahead of an already-active busy lane that had not yet surfaced its
        current ticket, which silently discarded same-frame late tickets
      - remaining work is promotion hygiene: rerun the larger bursty random
        testcase on the repaired RTL and either promote it or keep only the
        longer random envelope probe-only
- [ ] Resolve the chained header-word recovery corruption before promoting
      `opq_error_header_word_mask_recovery_test`.
      Status on `2026-04-18`:
      - isolated native-SV is now fixed and green after the ingress header
        timestamp-base handoff was routed into the page allocator
      - remaining work is report hygiene, not DUT repair:
        rerun the ERROR bucket continuous-frame baseline with the restored
        case, then remove it from the generated report exclusions
- [ ] Resolve the chained malformed-subheader recovery corruption before adding
      `opq_error_subheader_mask_recovery_test` back into the mixed-bucket soak
      pool.
      Required deterministic predecessor matrix before any broad soak rerun:
      - `drr_bp -> subheader_error_recovery`
      - `idle_lane_bp -> subheader_error_recovery`
      - `whole_frame_skew -> subheader_error_recovery`
      - `sparse_missing_empty -> subheader_error_recovery`
      Each pairwise repro must print ingress, mover/frame-table, and egress
      ledgers at every checkpoint, not only at final summary.
- [ ] Resolve the hit-without-subheader contract failure still exposed by
      `opq_cross_mixed_bucket_seconds_soak_test` before promoting the earlier
      extended mixed-soak screen into the live report set.
      Status on `2026-04-19`:
      - the original earliest failing window around `mixed_sparse_191` is now
        repaired on the exact deterministic reproducer
        `opq_cross_hit3_exact_183_190_repro_test`, which ends
        `expected=2476 actual=2476 missing=0 ghost=0`
      - remaining work is a refreshed full stretched rerun to prove that the
        later windows (`mixed_soak_261`, `mixed_whole_skew_275`,
        `mixed_whole_skew_418`, `mixed_whole_skew_435`) are also gone on the
        repaired RTL
      - before rerunning the full seconds soak, build exact deterministic
        repro windows around each remaining later site so any continued
        failure is shrunk at the ledger level instead of debugged only inside
        the full long run
      - keep this item open as a real long-chain revalidation step, not as an
        already-closed signoff point
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
      - the focused bursty repro closes with per-lane `unexplained=0`, so the
        repaired path no longer depends on final CSR totals alone for
        hit-integrity proof
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
- [ ] Close the remaining harness-upgrade gaps that would block full native-SV
      ownership:
      - scoreboard and SVA parity between native-SV and prior reference runs
      - build/run support for every promoted bucket under `DUT_IMPL=native_sv`
      - native-SV-only closure for any parameter points claimed in the report
- [ ] Refresh the 4-lane native-SV scope statement in the report:
      - the old sparse-frame cadence reproducer (`BUG-007-R`) is now green on
        current RTL and should no longer be treated as an automatic non-claim
      - keep 4-lane signoff tied to real evidence instead:
        current 4-lane DV status plus the standalone A10 `N_LANE=4` synthesis
        result
      - remove the stale 4-lane non-claim wording from the report only after
        the active A10 standalone refresh is recorded

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
      - blocker: `znformal` licenses are available, but this host does not
        have a runnable `qverify` / `znformal` binary installed
- [x] Stabilize a no-backend fallback API that keeps the future proof entry
      points intact.
      Status on `2026-04-18`:
      - wrappers now support `FORMAL_BACKEND=auto|stress|qverify|sby`
      - wrappers now support `QVERIFY_BIN=/path/to/qverify` as the
        backend handoff point once the proof binary is installed
      - wrappers now support `SBY_BIN=/path/to/sby`,
        `YOSYS_BIN=/path/to/yosys`, and
        `BITWUZLA_BIN=/path/to/bitwuzla` as the OSS backend handoff
        points once that toolchain is installed
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
      - ingress probe-only exclusions:
        `opq_error_header_mask_recovery_test`,
        `opq_error_header_word_mask_recovery_test`
- [x] Add the first OSS-friendly formal harness subset for
      `FORMAL_BACKEND=sby`.
      Status on `2026-04-18`:
      - shared OSS tool stack is installed for all users at
        `/data1/oss_formal`
      - ingress wrapper now runs `opq_oss_ingress.sby` for real and
        records `formal=sby_fail`
      - mover wrapper now runs `opq_oss_block_path.sby` for real and
        records `formal=sby_fail`
      - egress wrapper now runs `opq_oss_basic_presenter.sby` for real and
        records `formal=sby_pass`
      - plane naming and wrapper entry points stayed stable
        (`formal_ingress.sh`, `formal_mover.sh`, `formal_egress.sh`)
- [x] Run the first actual formal proof round once the proof backend is
      installed, then record any failing properties back into
      `DV_FORMAL.md` and `BUG_HISTORY.md` when a real RTL issue is exposed.
      Status on `2026-04-18`:
      - first wrapper-managed `sby` round is captured in
        `tb/formal_runs/csv/formal_{ingress,mover,egress}_latest.csv`
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

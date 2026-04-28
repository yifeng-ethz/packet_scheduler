# Changelog
Author: Yifeng Wang (yifenwan@phys.ethz.ch)

> Note on formal-tool history: older entries below that mention
> `OSS` / `sby` / `yosys` are archived evidence only from the temporary
> pre-migration fallback flow. Since the `2026-04-21` toolchain refresh,
> the supported simulator runtime is `QuestaOne 2026` at
> `/data1/questaone_sim/questasim`, and the active formal direction is
> `qverify` / `znformal` with simulation stress fallback only when the
> Siemens formal binaries are not present on the host.

## 26.4.13.0428

- **RTL / Native-SV Presenter Timing**: preserved the existing native
  presenter metadata and head staging registers and disabled advanced netlist
  optimization on those cuts. This keeps frame-length/count arithmetic behind
  the intended register boundary before page-RAM pointer launch control in
  MuSiP integration builds without adding latency or changing queue order.
- **RTL / Page Allocator Recovery**: allowed same-frame-timestamp forward
  serial rebase after masked/drop-only frames. This restores no-restart
  4-lane mixed-soak progress when the allocator timestamp has already advanced
  but serial ownership must reopen at the same frame timestamp.
- **Verification**: aligned the native presenter startup-backpressure SVA with
  the two quiet prime cycles in the registered page-RAM handoff, then refreshed
  directed native-SV and 4-lane mixed-soak/report evidence for
  `26.4.13.0428`.
- **Packaging**: advanced the Platform Designer identity and `VERSION` file to
  `26.4.13.0428` for the refreshed MuSiP timing-closure candidate, including
  the native-SV UVM and fixed4 synthesis-wrapper CSR META identity constants.

## 26.4.12.0428

- **RTL / Native-SV Presenter Timing**: registered completed-frame metadata at
  the presenter boundary before metadata writes, overlap requests, and
  presentation launch gating. This cuts the MuSiP critical path from
  frame-count arithmetic through `block_present_start_v` into the page-RAM
  read-pointer launch enable while preserving one-new-frame-per-cycle intake.
- **Verification / Native-SV Assertions**: tightened the tail-lookahead
  presenter assertion so it only fires on cycles where the one-entry
  lookahead/pending capture path is actually free. The reduced-depth overflow
  directed case already fell back through the normal restart path cleanly, but
  the older assertion still flagged those cycles as tool errors.
- **Packaging**: advanced the delivered OPQ Platform Designer identity and
  `VERSION` file to `26.4.12.0428` for the MuSiP integration image.

## 26.4.3.0425

- **RTL / Feature Timing Closure**: closed the focused
  `N_LANE=16`, `N_SHD=256`, `PAGE_RAM_RD_WIDTH=36` native-SV feature
  signoff point at the tightened `275 MHz` standalone clock without
  multicycle constraints. The fix uses real pipeline cuts on ticket-FIFO
  read addresses, allocator fetch/page-commit reductions, SOP-hit reduction,
  and lane-vector ready qualification; the accepted tradeoff is extra ticket
  processing latency rather than a relaxed timing exception.
- **Synthesis / Feature Evidence**: the refreshed
  `opq_feature_l16_s256_w36` Arria-10 compile reports slow-100 setup
  `+0.047 ns` / TNS `0.000 ns`, slow-100 hold `+0.041 ns`, and positive hold
  slack on all checked corners at the 3.636 ns signoff clock.
- **Math / Queueing Model**: added the queueing/network-calculus model,
  transaction-level feature sweep, and reproducible DISLIN full-feature plots
  for OPQ loss surfaces and OPQ-vs-time-merger loss comparisons. The report now
  keeps analytical artifacts under `model/analytical/`, TLM artifacts under
  `model/tlm/`, and RTL/board evidence tiers explicitly separated.

## 26.3.66.0423

- **RTL / Native-SV Allocator Retirement Closure**: fixed the active-frame
  tail-retirement gate so a registered future body ticket no longer keeps the
  current frame alive indefinitely. This closes the overflow-step2 boundary
  timeout where the allocator stayed live with `frame_lane_active=0xf`,
  `frame_lane_tail_seen=0xf`, and only future tickets pending.
- **Verification / Maintained Signoff Refresh**: reran the maintained
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  frame-signoff suite on QuestaOne 2026. The refreshed generated dashboard
  remains `516/516` isolated cases green and now reflects the maintained
  current-scope `8/8` signoff-run set with no signoff-run failures.
- **Tooling / Report Hygiene**: folded the local support fixes needed for the
  refreshed closure batch: README ASCII-art alignment, `_hw.tcl` version sync,
  `tb/legacy/tb/lint/lint_opq.py` path recovery after the `tb/legacy/` move,
  the safe `run_param.sh` ticket-depth sweep behavior, and regenerated
  `tb/DV_REPORT.*` plus `tb/REPORT/` from the live evidence set.

## 26.3.59.0422

- **Verification / Canonical 4-Lane Dashboard**: refreshed the generated
  standalone dashboard so the active claim is the canonical
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  rerun slice on QuestaOne 2026.
- **Verification / Pending vs Failing**: fixed the report builder so
  unevidenced canonical rows render as pending instead of being counted as
  fresh failures. Only current-scope reruns are now staged into
  `tb/uvm/logs/`, `tb/uvm/cov_after/`, `tb/DV_REPORT.md`, and `tb/DV_COV.md`.
- **Verification / Current Scope Evidence**: the active slice now carries fresh
  anchor evidence for `B001`, `E001`, `P001`, and `X001`, while stale
  historical 2-lane artifacts remain archived but are no longer credited into
  the current generated totals.
- **Documentation / Consistency Refresh**: synchronized `tb/README.md`,
  `doc/SIGNOFF.md`, `doc/CONFIG_SIGNOFF.md`, and `tb/BUG_HISTORY.md` to the
  current reporting model and release metadata.

## 26.3.64.0422

- **RTL / Native-SV Presenter Restart Closure**: fixed the monolithic basic
  presenter so a replayed overlap request cannot rescan the metadata entry
  that created it. When the queued overlap stop pointer has already caught up
  to `meta_rptr`, the presenter now discards that stale self-request instead
  of launching a self-overlap walk that can synthesize a zero-length head.
- **Verification / Canonical Dashboard Refresh**: regenerated the canonical
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  dashboard from current QuestaOne 2026 evidence. The generated report now
  shows `516/516` isolated catalog cases evidenced, `0` failing cases,
  `0` unimplemented cases, and `22/22` current signoff runs green. The
  remaining warnings are structural coverage-target gaps rather than missing
  testcase evidence.
- **Documentation / Release Sync**: updated the master signoff note, config
  matrix note, architecture note, TB README, and DV worklist so the author-
  owned Markdown files match the regenerated `tb/DV_REPORT.md` state and the
  current package release stamp.

## 26.3.56.0421

- **RTL / Native-SV Allocator + Ingress Closure**: closed the current
  `BUG-025-R` / `BUG-027-R` bug family by carrying frame serial identity on
  non-SOP tickets and credit-drop debug paths, removing dependence on the
  transient ingress `alert_eop` level, and restoring the zero-hit masked
  subheader recovery branch back to the normal body state.
- **Verification / 4-Lane Supplemental Matrix**: refreshed the
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256` supplemental reruns.
  `opq_basic_single_active_lane_test`,
  `opq_basic_feb_packet_contract_test`,
  `opq_error_hit_mask_recovery_test`,
  `opq_cross_drr_bursty_frame2_boundary_test`,
  `opq_cross_random_ready_overflow_step2_boundary_test`,
  `opq_cross_masked_drop_exact_102_117_repro_test`, and
  `opq_cross_mixed_bucket_random_soak_test` all now exit with `UVM_ERROR : 0`.
- **Verification / Overwrite Witness Scope**: kept the reduced-depth
  overwrite-local must-drop proof on the named `opq_cross_bp_mustdrop_witness_test`
  profile, which now reruns green on `OPQ_PAGE_RAM_DEPTH=512` for the same
  refreshed `4-lane/128` preset. The older `opq_error_ftable_overflow_test`
  legacy profile remains a historical reduced-depth shape-check and is no
  longer the portable must-drop witness on the wider-lane matrix.
- **Harness / Lane Ledger Repair**: fixed the scoreboard's lane-accounting
  model so delivered hits retire against canonical delivery timestamps while
  exact-drop bookkeeping keeps the parser/accounting timestamp domain. This
  closes the false `unexplained` residue that had reopened clean 4-lane/128
  overflow-step2 and mixed-soak reruns after the RTL bug family was already
  fixed.

## 26.3.29.0420

- **Packaging / Representative Presets**: added a GUI-visible `PRESET` selector to `ordered_priority_queue_hw.tcl` with nine visible options (`CUSTOM` plus eight named presets). All concrete named presets intentionally pin `N_SHD=128`, keep the safe `32 data + 4 datak` / `36-bit` egress contract, and scale `N_LANE` plus `LANE_FIFO_DEPTH` as representative starting points for later quantitative closure work.
- **Packaging / Width-Axis Guardrail**: kept the wider-ingress and wider-egress preset families out of the live `_hw.tcl` selector because the current monolithic RTL still contains fixed `36`/`40`-bit assumptions in the ingress parser and basic presenter path. Those axes remain tracked as staged future work instead of being exposed as misleading package presets.
- **Documentation / Matrix Ownership**: reduced `doc/CONFIG_SIGNOFF.md` back to a representative preset matrix that matches the `_hw.tcl` selector and moved the authoritative `768`-tuple Cartesian-product closure tracking into `tb/scripts/gen_config_signoff_matrix.py`, which can emit summary, CSV, JSON, or Markdown views of the full space.

## 26.3.28.0420

- **Packaging / `_hw.tcl` Contract**: constrained the monolithic OPQ package to the honest live release envelope. `ordered_priority_queue_hw.tcl` now exposes `N_LANE={2,4,8,16}`, `MODE=MERGING`, `TRACK_HEADER=true`, `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`, `N_SHD={64,128,256,512}`, and auto-derived `CHANNEL_WIDTH`, `LANE_FIFO_WIDTH`, `TICKET_FIFO_DEPTH`, `HANDLE_FIFO_DEPTH`, and `PAGE_RAM_RD_WIDTH`. Wider `64/128`-bit hit words and wider DMA-packed egress beats remain documented staged axes, not legal packaged points.
- **Packaging / GUI Documentation**: refreshed the monolithic OPQ `_hw.tcl` HTML descriptions so the packet contract now explicitly shows header / payload / trailer format, the current 36-bit symbol layout, the auto-sized parameter rules, and the delivered release profile for `26.3.28.0420`.
- **Synthesis / 2-Lane Standalone Closure**: repaired the stale `opq_native_sv_2lane_signoff` collateral by aligning its local `src_compat/` files to the live 4-lane synthesis-compat set and correcting the stale SDC clock target from `d_clk` to the real harness port `clk`. The refreshed 2-lane standalone Arria-10 build now closes the `275 MHz` signoff target with `+0.172 ns` setup slack and `129` M20Ks.
- **Documentation / Config Matrix**: added `doc/CONFIG_SIGNOFF.md` and linked it from the root README, signoff dashboard, script README, TB README, and synthesis README so grouped parameter legality, measured points, staged non-claims, and bounded DV extensions are visible from the main entry points.

## 26.3.26.0419

- **RTL / Native-SV Mixed-Soak Exact Window**: fixed the monolithic page allocator so a new frame seeds `running_ts` from the parser's current running subheader timestamp instead of the frame header timestamp. The allocator no longer misclassifies the first live payload tickets as `future` and no longer closes an empty frame tail before fetching same-frame payload.
- **Verification / Exact-Window Closure**: reran the deterministic `opq_cross_hit3_exact_183_190_repro_test` and the focused 5-step `opq_cross_mixed_bucket_seconds_soak_test` bug-hunt configuration. Both now pass with `UVM_ERROR : 0`, which closes the old earliest `mixed_sparse_191` failing window on current native-SV RTL.
- **Documentation / Signoff Discipline**: refreshed the standalone signoff dashboard, generated DV dashboard, and live TODO so they record the repaired exact-window evidence without overstating closure. The stretched mixed-bucket seconds-soak rerun and the 4-lane standalone Arria 10 synthesis refresh both remain explicit pending signoff items.

## 26.3.25.0419

- **RTL / Native-SV Late-Frame Drop Accounting**: fixed the page allocator's late-frame accounting so a stale past SOP ticket no longer reports the whole frame's stored `n_subh/n_hit` metadata as one monolithic post-drop event. The live native-SV path now emits header-drop only on a past SOP ticket and one post-drop event per unread non-SOP ticket using that ticket's exact `block_length` and `ticket_ts`.
- **Verification / Overflow Conservation Closure**: reran the focused half-saturation random-ready overflow screen in shape-check mode. `opq_cross_random_ready_overflow_seconds_soak_test` now closes with `UVM_ERROR : 0`, lane0 `accepted=460 delivered=460 unexplained=0`, lane1 `accepted=444 delivered=444 unexplained=0`, and no drop-total mismatch against expected traffic.
- **Documentation / Signoff Status**: refreshed the standalone signoff dashboards to the live `online_sc/a10_board` / Arria 10 state. `doc/SIGNOFF.md` now reflects green native-SV continuous-frame baselines plus the repaired overflow invariant screen, while `syn/SYN_REPORT.md` now points at the active 4-lane A10 standalone revision still in progress.

## 26.3.24.0419

- **RTL / Native-SV Burst DRR Closure**: fixed the monolithic page allocator so merged-frame progress no longer advances past an already-active busy lane that has not yet surfaced its current ticket. Under asymmetric bursty DRR traffic, the allocator now waits for every active busy lane before advancing the current subheader, which removes the silent late-ticket loss seen at the stall boundary.
- **Verification / Drop Identity**: exported pre/post ingress drop-event visibility through the native-SV wrapper into the standalone drop monitor and scoreboard. The focused bursty reproducer now closes with exact per-lane accounting instead of relying on final CSR totals alone.
- **Verification / Bursty Repro Evidence**: reran `opq_cross_drr_bursty_repro_test` on the repaired native-SV RTL. The testcase now passes with `expected=1864 actual=1864 missing=0 ghost=0`, and both lanes finish with `unexplained=0`.

## 26.3.23.0418

- **RTL / Native-SV Recovery Timestamp Closure**: closed the masked-header and masked-header-word recovery bugs on the live monolithic native-SV path. The ingress parser now captures the full header timestamp base when the legal frame header is rebuilt, and the page allocator seeds recovery-frame `frame_ts` / `running_ts` from that dedicated header timestamp instead of falling back to stale allocator state.
- **Verification / Recovery Assertions**: fixed the standalone ingress AVST assertion semantics for intentionally truncated malformed packets. Error-tainted open packets are now treated as abortable at the next legal recovery preamble, so `opq_error_header_mask_recovery_test` no longer false-fails on an artificial nested-SOP assertion after the DUT has already masked the bad frame.
- **Verification / Recovery Evidence**: reran `opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`, and `opq_basic_smoke_test` on the native-SV path. All three now pass with `missing=0 ghost=0`; the two recovery cases are ready for ERROR-bucket re-promotion on the next report refresh.

## 26.3.22.0418

- **RTL / Native-SV Presenter Hold Fix**: fixed the basic-presenter synchronous page-RAM return path under held output backpressure. The presenter now skids a returned RAM word across `valid && !ready` and reuses that preserved word on resume, which removes the stale-word skip/duplicate behavior exposed by the aggressive flush-under-backpressure probe.
- **Verification / Historical OSS Formal Closure**: closed the then-active
  OSS `sby+yosys+bitwuzla` plane bring-up on this host. `formal_ingress.sh`,
  `formal_mover.sh`, and `formal_egress.sh` all recorded `formal=sby_pass`,
  and the targeted `opq_formal_like_egress_flush_backpressure_stress_test`
  also passed after the live presenter fix.
- **Verification / Cross Soak Tracking**: kept the stretched mixed-bucket seconds-soak screen honest. After the presenter repair, an exploratory rerun advanced through the earlier failure window without reproducing `opq_hit3_contract`, but the full promoted-length rerun is still pending and remains an explicit open TODO rather than a silent signoff claim.

## 26.3.20.0418

- **Verification / Historical OSS Formal Egress**: split the
  basic-presenter overwrite-drop scan under `OPQ_OSS_FORMAL` into a
  feed-forward oversize-only subset so the Yosys/SBY backend no longer died
  in SMT2 lowering. `formal_egress.sh` recorded `formal=sby_pass` on the
  live Avalon-ST hold-under-backpressure slice while leaving the native-SV
  signoff path unchanged.
- **Verification / Historical OSS Formal Ingress**: added
  `shd_len_dbg_oss`, stretched the post-reset warmup window, and encoded the
  legal `WR_HITS` / drop-cause local-state assumptions explicitly in the
  ingress OSS harness. The remaining ingress blocker was narrowed to the
  lane-credit bound plus `lane_issue_dbg_oss` sampled-write alignment.
- **Verification / Historical OSS Formal Mover**: added combinational
  page-writer source mirrors plus sampled source shadows in the mover
  harness. The remaining mover blocker was isolated to
  `page_ram_wr_data_o` equality against the sampled write source after
  reset/phase cleanup attempts.

## 26.3.21.0418

- **Verification / Mixed Soak Screen**: fixed the earlier mixed-bucket seconds-soak scoreboard accounting handoff so the old `Drop accounting underrun ... source=monitor` failure no longer reproduces under the stretched `+TB_CLK_PERIOD_NS=250` bug-hunt run. The same earlier long-run screen now reaches much deeper chained traffic and exposes a stricter open hit/sub-header contract failure (`opq_hit3_contract`) instead of dying in the scoreboard first.
- **Verification / Historical OSS Formal Mover**: closed the then-active OSS
  mover subset. `formal_mover.sh` recorded `formal=sby_pass` on the
  proof-clean block-path ownership / arbiter slice, leaving ingress as the
  only remaining OSS proof blocker at that time.
- **Verification / Historical OSS Formal Ingress**: kept the ingress proof
  honest and narrowed the remaining blocker to the phase-sensitive
  ticket-credit/write coupling in the OSS harness. The lane-credit bound and
  mover-side arbiter issues were no longer the active formal blockers in
  that historical flow.

## 26.3.19.0418

- **RTL / Native-SV Drop Accounting**: exposed ingress parser credit-mask rejection pulses through the monolithic native-SV path and into the standalone CSR/debug surface. The live native-SV DUT now counts parser-side lane-credit and ticket-credit packet rejection in the same software-visible drop counters used by the report and the fallback stress harness.
- **Verification / Formal-Like API**: stabilized wrapper-facing fallback testcase names for the future formal backend handoff. `formal_ingress.sh` and `formal_mover.sh` now run stable `opq_formal_like_*` entry tests, so switching from today's simulation-backed fallback to a later `FORMAL_BACKEND=qverify` flow can reuse the same plane wrappers, testcase names, and report wording.
- **Verification / Probe Tracking**: recorded the current live egress flush-under-backpressure failure as open `BUG-014-R`. The default fallback egress summary stays green on the directed hold tests, while the aggressive `opq_formal_like_egress_flush_backpressure_stress_test` remains a targeted probe until the presenter/flush hold violation is fixed.

## 26.3.17.0418

- **Verification / Formal Fallback API**: stabilized the no-backend packet-formal wrappers so the same `formal_ingress.sh`, `formal_mover.sh`, and `formal_egress.sh` entry points can serve both today's simulation-backed fallback and a future `qverify`/`znformal` backend. The shared wrapper layer now accepts `FORMAL_BACKEND=auto|stress|qverify` and `FORMAL_STRESS_TESTS` for targeted per-plane fallback runs without editing the scripts.
- **Verification / Native-SV Formal SVA**: fixed the native ingress and block-mover SVA timing model to match the real DUT sampling points. Ingress pointer/write assertions now check the same-sampled `*_we`/`*_wptr` contract, and the mover/page-writer assertions now compare the registered page-RAM outputs against the previous cycle's selected source instead of the current combinational arbiter state.
- **Verification / Fallback Status**: the default simulation-backed packet-formal plane status is now coherent on this host: ingress passes on `opq_basic_smoke_test` plus `opq_error_subheader_mask_recovery_test` at `N_SHD=256` / `TICKET_FIFO_DEPTH=512`, mover passes on the directed DRR tests, and egress passes on the directed backpressure tests. Intentionally contract-breaking ingress recovery cases (`opq_error_header_mask_recovery_test`, `opq_error_header_word_mask_recovery_test`) are explicitly left in the probe-only set instead of polluting the default fallback result.

## 26.3.18.0418

- **RTL / Native-SV Overwrite Recovery**: fixed the basic-presenter frame-table overwrite path so reduced-depth overwrite pressure no longer replays corrupted resident data at egress. The native-SV presenter now detects self-oversize frames before enqueue, flushes unread overwritten residents out of its metadata queue, and suppresses their completion bookkeeping instead of letting stale page-RAM contents drain as accepted traffic.
- **RTL / Native-SV FT Drop Accounting**: wired frame-table overwrite-drop accounting from the monolithic presenter into the native-SV DUT CSR plane. `FT_DROP_HDR/SHD/HIT` counters now increment on the same overwrite / oversize events that retire resident metadata, which closes the reduced-depth `opq_error_ftable_overflow_test` contract on the live signoff path.
- **Verification / Reduced-Depth Error Closure**: the isolated `OPQ_PAGE_RAM_DEPTH=512` overflow repro now passes cleanly with no malformed accepted egress, and guard reruns of `opq_basic_smoke_test` plus `opq_edge_stuck_low_backpressure_test` remain green after the overwrite/drop fix.

## 26.3.16.0417

- **Verification / Bucket Promotion**: promoted additional native-SV passing cases into the active report inventory and no-restart baseline. The current directed signoff set now includes `opq_basic_single_active_lane_test`, `opq_edge_burst_restart_profile_test`, `opq_prof_long_soak_test`, and `opq_cross_idle_lane_backpressure_test`, and the fixed `bucket_frame` ordering expands from 24 to 28 composed steps.
- **Verification / Harness Timing**: added a bench clock-period override (`+TB_CLK_PERIOD_NS`) and converted the frame-signoff waits from fixed absolute delays to cycle-scaled timing in the composed no-restart harness. This keeps the mixed-bucket soak and the continuous-frame baselines stable when the testbench clock is intentionally slowed for long sim-time evidence.
- **Verification / Mixed Soak**: added `opq_cross_mixed_bucket_random_soak_test` plus the long-simtime companion `opq_cross_mixed_bucket_long_simtime_soak_test`. The bounded mixed soak now passes with full bucket visitation and `expected=5798 actual=5798 missing=0 ghost=0`, while the slowed-clock companion reaches `2194139500 us` of sim time without DUT or scoreboard errors.
- **Verification / Open Probes**: recorded two still-open native-SV recovery issues in `tb/BUG_HISTORY.md`: `opq_error_header_word_mask_recovery_test` remains a failing header-recovery probe, and chained `opq_error_subheader_mask_recovery_test` behavior remains excluded from the mixed-soak pool until the no-restart recovery contract is fixed.

## 26.3.15.0417

- **Verification / Continuous Frame**: fixed the native-SV no-restart signoff harness so composed `bucket_frame` and `all_buckets_frame` runs carry continuous `pkg_cnt` and frame-timestamp identity instead of restarting those fields at each case boundary. This matches the native allocator contract and removes the false credit-restore / missing-hit collapse in long no-restart runs.
- **Verification / Scoreboard Contract**: corrected lane-counter accounting for malformed subheaders on the native-SV path. The scoreboard now distinguishes declared FEB packet geometry from parser-accepted lane traffic, so a subheader with `error_bits[1]` no longer inflates expected `wr_shd` / `rd_shd` counts during continuous-frame signoff.
- **Verification / Error Coverage**: strengthened `opq_error_subheader_mask_recovery_test` to check the same lane/frame-table counters that the signoff baselines use, so malformed-subheader accounting regressions are caught in isolated runs instead of surfacing only at the end of composed regressions.
- **Verification / Signoff Evidence**: reran the mandatory native-SV continuous-frame baselines and closed them cleanly: `opq_bucket_frame_native_sv_test` now finishes with `expected=3770 actual=3770 missing=0 ghost=0`, and `opq_all_buckets_frame_native_sv_test` now finishes with `expected=3788 actual=3788 missing=0 ghost=0`.

## 26.3.10.0414

- **RTL / Monolithic VHDL**: committed the currently exercised DRR and presenter fixes into the packaged source tree. The monolithic OPQ now carries the block-level deficit scheduling state, per-lane DRR allowance and service/defer counters, frame-table actual-count side storage, and the presenter skid/hold tightening that the active DV probes have been running against.
- **RTL / Default Contract**: propagated the active `N_SHD=256` default into the remaining maintained debug/split entry points and the native-SV staging wrapper so the checked-in source defaults match the live harness and package contract.
- **Packaging**: advanced the packaged OPQ catalog revision to `26.3.10.0414` and aligned the `_hw.tcl` identity defaults, GUI register-map text, and DRR CSR description with the current RTL contract.
- **RTL / Native SV Staging**: kept the native-SV rewrite in sync with the active default/basic contract by applying the same `N_SHD=256` default and the already-debugged basic-path fixes in the page allocator, block path, and basic presenter.

## 26.3.9.0414

- **Verification / Bucket Promotion**: promoted additional still-relevant current-tree cases into the active bucket wrappers. `run_basic.sh` now includes `opq_basic_subheader_shape_test`; `run_edge.sh` adds `opq_edge_ready_medium_profile_test` and `opq_edge_stuck_low_backpressure_test`; `run_error.sh` adds `opq_error_lane_mask_single_hit_test` and `opq_error_lane_mask_burst_test`; `run_cross.sh` adds `opq_cross_drr_idle_lane_test`, `opq_cross_drr_zero_allowance_test`, and `opq_cross_drr_short_allowance_test`.
- **Verification / DRR Contract**: fixed the directed single-active-lane DRR stimulus to keep the inactive peer lane on empty-frame cadence instead of making it permanently silent. This matches the current monolithic page-allocator contract and closes the directed idle-lane/zero-allowance/short-allowance DRR tests without weakening the scoreboard or SVA contract.
- **Verification / Coverage Closure**: reran the merged closure on the promoted suite plus the `N_SHD=128/256/512` parameter bucket. The current merged result is `87.60%` total covergroup coverage, `100.00%` directive coverage, and `69.76%` filtered total by instance. The merged structural snapshot is now `61.68%` statements, `35.36%` branches, `25.40%` conditions, `37.22%` toggles, `92.30%` FSM states, and `62.50%` FSM transitions.
- **Verification / Current Docs**: updated the current-tree DV collateral (`DV_PLAN.md`, `DV_HARNESS.md`, `DV_BASIC.md`, `DV_EDGE.md`, `DV_ERROR.md`, `DV_CROSS.md`, `tb/README.md`, and `doc/VERIFICATION_SIGNOFF.md`) to reflect the promoted bucket set, the empty-frame-cadence clarification for idle lanes, and a direct trace from earlier requested features to implemented evidence versus remaining backlog.

## 26.3.8.0414

- **Verification / Plan Surface**: promoted three still-relevant current-tree DV companions from the archived intent into active collateral: `tb/DV_PARAM.md` for compile/elaboration-time configuration sweep, `tb/DV_PROBE.md` for non-promoted bug reproducers, and `tb/DV_FORMAL.md` for formal-readiness and proof targets. `tb/README.md`, `tb/DV_PLAN.md`, `tb/DV_HARNESS.md`, and `doc/VERIFICATION_SIGNOFF.md` now reference these files directly.
- **Verification / Sweep Runner**: added `tb/scripts/run_param.sh` and wired it into `run_all.sh`. The new runner executes the active `N_SHD=128/256/512` sweep on `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, and `opq_edge_max_hits_test`, while preserving per-configuration logs and UCDB names for auditability.
- **Verification / Coverage Model**: refactored `tb/uvm/opq_coverage.sv` so `cg_cfg` now has explicit active signoff bins for `N_SHD`, ticket depth, and their cross, instead of collapsing the current configuration into single active-point bins. This makes the non-default parameter sweep visible in merged functional coverage instead of being implied by ad hoc reruns.
- **Verification**: reran `tb/scripts/run_param.sh` successfully across `N_SHD=128/256/512`; the three active sweep tests remain green with zero `UVM_ERROR` / `UVM_FATAL`.
- **Verification / Coverage Baseline**: reran the merged coverage closure with the active promoted suite plus the named parameter bucket. The current baseline is `80.42%` total covergroup coverage, `100.00%` directive coverage, and `68.40%` filtered total by instance. The generated-VHDL `line__1367` warning assertion remains visible in UCDB assertion accounting as a warning-site hit, and multi-config UCDB merge on the generated wrapper still emits source-mismatch warnings, so multi-config structural coverage remains an active baseline rather than final signoff closure.

## 26.3.7.0414

- **Verification / DRR Contract**: added active monolithic DRR signoff collateral in the current tree. `tb/DV_PLAN.md` and `tb/DV_HARNESS.md` now include the block-level DRR allowance/defer intent, build-time configuration randomization terminology, a formal-verification section, and a high-level plan/code traceability table for chief-architect closure tracking.
- **Verification / SVA**: added `tb/uvm/sva/opq_drr_sva.sv` and bound it in `tb_top.sv`. The active mixed-language harness now checks onehot grant / lock ownership, defer-event legality, and page-allocator preemption on the monolithic VHDL DRR arbiter.
- **Verification / Current Cases**: added the directed `opq_cross_drr_allowance_test` and the constrained-random `opq_cross_drr_bursty_random_test` to the live cross bucket. The allowance case is green on the active harness and now serves as the stable DRR evidence point for CSR-programmed allowance/defer behavior.
- **RTL / Presenter Backpressure**: tightened the monolithic frame-table presenter for egress stalls. The output-valid pipe is no longer unconditionally cleared every cycle, and the page-RAM read-data path now captures a skid copy of the unfreezable RAM-q stage before resuming. This removes the immediate Avalon-ST hold violation seen under the new DRR burst stress.
- **Verification / Bug Exposure**: the new bursty constrained-random DRR testcase still reproduces an open monolithic DUT bug: the frame-table path can expose a frame as complete before all delayed DRR block writes are resident. The current symptom is repeated subheaders plus missing/ghost hits under asymmetric block sizes and periodic backpressure. This remains an active backlog item rather than a closed signoff claim.

## 26.3.6.0414

- **RTL / Timestamp Contract**: kept the full frame-base timestamp visible in the packet/header path and closed the `N_SHD=512` ambiguity by extending the subheader `ts[11:4]` low byte across wrap inside both the monolithic and split ingress parsers. Subheader tickets now keep an absolute `ts[47:0]` ordering basis even when a frame spans the second 256-subheader epoch or a lane stalls for a long time before resuming.
- **RTL / Configuration Contract**: documented and enforced the real ticket-credit requirement for long frames. The packaged IP now rejects `N_SHD > 256` configurations unless `TICKET_FIFO_DEPTH > N_SHD`, because empty-subframe bursts otherwise consume ticket credit before the frame completes.
- **Verification Harness Contract**: parameterized the active UVM wrapper and configuration model for `N_SHD` and `TICKET_FIFO_DEPTH`, and taught the regression launcher to derive a safe power-of-two ticket FIFO depth for non-default `N_SHD` sweeps. This keeps the default `N_SHD=256` resource point unchanged while allowing `N_SHD=512` validation without false credit starvation.
- **Verification / SVA**: promoted the egress hit-contract checker from dead compiled code into an active `tb_top` assertion block. The checker now follows the same implicit 5-word-header / `K237` subheader / `K284` trailer contract as the scoreboard, and reconstructs absolute subheader timestamps from the full frame header so wrap at `N_SHD=512` does not create false assertion failures.
- **Verification / Coverage Plumbing**: fixed the active `run_uvm.sh` coverage path so `COV_ENABLE=1` now propagates `COV=1` and optional `COV_CODE` into the UVM make targets. The generated UCDBs now contain real code-coverage data instead of functional-coverage-only runs mislabeled as closure.
- **Verification**: reran the promoted basic parameter sweep on the VHDL DUT for `N_SHD=128`, `256`, and `512`. `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, and `opq_edge_max_hits_test` now pass across all three points, so the non-default frame-size debug path is closed at the active smoke level.

## 26.3.5.0414

- **Verification Harness Contract**: fixed the active max-hit virtual sequence so non-default `N_SHD` runs derive second-frame subheader timestamps from the actual frame base (`frame_ts[11:4]`) instead of reusing a hard-coded low-byte slot value. This preserves the restored absolute `ts[11:4]` contract when `N_SHD=128`.
- **Verification**: the promoted basic non-default sweep now keeps `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, and `opq_edge_max_hits_test` passing at both `N_SHD=256` and `N_SHD=128`. The remaining `N_SHD=512` mismatch stays open as a separate packet-format / timestamp-epoch issue, because the subheader timestamp field itself is still only 8 bits wide and the current VHDL DUT does not yet extend that low-byte slot across the second 256-subheader epoch.

## 26.3.4.0414

- **RTL**: kept the full ingress header `ts[15:0]` exposure, but fixed the subheader reconstruction semantics back to the original absolute contract. Monolithic and split ingress parsers now form per-subheader timestamps as `frame_ts[47:12] | shd_ts[11:4] | 4'b0` instead of treating the subheader byte as an additive offset into the full low word.
- **Verification Harness Contract**: corrected the UVM scoreboard to use the same absolute timestamp contract for both ingress expectation and egress observation. This removes the false `N_SHD=128` boundary mismatch that appeared only when frame periods were smaller than the old `4096`-cycle default spacing.
- **Verification**: default `N_SHD=256` behavior remains compatible, while the restored absolute subheader contract reopens the reduced-window parameter sweep on a sound timestamp basis. `N_SHD=512` stays an explicit open contract/debug topic because the ingress subheader timestamp field itself is still only 8 bits wide and the original OPQ header documents that counts above 256 subheaders are dropped.

## 26.3.1.0413

- **RTL**: fixed the monolithic frame-table metadata width so whole-frame span tracking no longer reuses the per-block `MAX_PKT_LENGTH_BITS` path. The mapper and presenter now size packet-span bookkeeping with a dedicated full-frame span width, which prevents silent wrap in reduced-depth configurations.
- **RTL**: fixed the reduced-depth overflow path for the active VHDL DUT by performing frame-span arithmetic in the whole-frame domain before spill detection. This restores real spill/overwrite behavior when `PAGE_RAM_DEPTH` is reduced for verification and unblocks the frame-table drop-counter path.
- **Verification**: the promoted reduced-depth overflow bucket is now green again on the VHDL implementation: `opq_error_ftable_overflow_test` passes with `OPQ_PAGE_RAM_DEPTH=512`, and the default `N_SHD=256` regression checks `opq_basic_smoke_test`, `opq_edge_max_hits_test`, and `opq_basic_ts_boundary_test` remain passing after the fix.
- **Verification / Parameter Sweep**: added explicit evidence for non-default `N_SHD` behavior during debug. `N_SHD=128` keeps `opq_basic_smoke_test` and `opq_basic_ts_boundary_test` passing but still fails `opq_edge_max_hits_test` with hit loss in the max-hit path. `N_SHD=512` keeps `opq_edge_max_hits_test` and `opq_basic_ts_boundary_test` passing but still fails `opq_basic_smoke_test` through subheader/drop-counter mismatches. These remaining parameterized bugs are intentionally left open for the next patch batches.

## 26.3.0.0413

- **RTL**: tightened the monolithic frame-table/drop accounting around actual tile residency rather than derived broken-link symptoms. Frame-table overwrite/flush now pushes header/subheader/hit loss into the CSR counters at the overwrite point, and the tracker retires linked trail/body residency when the presenter drains or invalidates a packet.
- **RTL**: fixed the monolithic page allocator for reduced `PAGE_RAM_DEPTH` verification runs by resizing the page-length contribution when updating `page_start_addr`. This is required for the active reduced-depth overflow bucket and keeps the default 16-bit configuration behavior unchanged.
- **RTL**: kept the non-default page-RAM-width diagnostic, but converted it from a failing template assertion into a non-failing warning so the promoted overflow bucket does not contaminate the SVA/assertion summary with an expected configuration note.
- **Verification Harness Contract**: promoted the current-tree monolithic UVM harness to an active eight-test regression on the VHDL DUT: `opq_basic_smoke_test`, `opq_edge_backpressure_test`, `opq_edge_always_ready_test`, `opq_prof_stress_test`, `opq_error_lane_mask_test`, `opq_error_ftable_overflow_test`, `opq_error_counter_clear_test`, and `opq_cross_bp_credit_test`.
- **Verification Harness Contract**: every promoted test now reads and checks the standard CSR identity/capability header before stimulus, exercises the runtime counter-clear path where relevant, and shares the same HIT-integrity scoreboard contract. The scoreboard still tracks ingress-to-egress hits by reconstructed 48-bit timestamp plus UVM-only `HIT_ID`, so missing and ghost hits are checked independently of CSR counter comparisons.
- **Verification / SVA**: added active interface-level SVA for ingress AVST framing, egress AVST hold/packet markers, and CSR single-beat protocol. The promoted suite now reruns with these checks enabled by default.
- **Verification / Coverage**: expanded the native covergroup model with configuration, frame/subheader shape, backpressure mode, CSR region access, credit snapshots, and lane/frame-table drop coverage. The promoted merged closure run uses the default configuration plus the reduced-depth overflow bucket (`OPQ_PAGE_RAM_DEPTH=512`) and reached `82.74%` total covergroup coverage on the current model.
- **Verification / Probes**: added non-promoted probe tests for timestamp-boundary and larger burst-hit cases in the current tree. They are intentionally not part of the promoted closure set yet, because they expose remaining monolithic DUT limitations rather than stable signoff behavior.

## 26.3.14.0417

- **Packaging / Versioning**: aligned the active `packet_scheduler/VERSION`, catalog `_hw.tcl` revision, and native-SV CSR META identity stamp on `26.3.14.0417` so the packaged IP version no longer lags the exercised native-SV DUT image.
- **Verification Reporting**: promoted the OPQ native-SV report flow to stable report case IDs with an explicit alias map back to the live UVM testcase names, plus generated signoff-scope / non-claim sections on the dashboard pages.
- **Verification Reporting**: recorded the actual no-restart `bucket_frame` / `all_buckets_frame` ordering and limitations in generated markdown so the current continuous-frame evidence is explicit about default-build-only scope and the extra tail stress steps.

## 26.2.0.0413

- **RTL / Packaging**: added a real Avalon-MM CSR slave to the monolithic OPQ. The packaged IP now exposes the common Mu3e `UID + META` identity header at CSR words `0x000/0x001`, a software `LANE_MASK` control register, a `CTRL` clear pulse, status/capability words, and a per-lane counter window.
- **RTL**: implemented per-lane runtime counters in the monolithic VHDL for header/subheader/hit write, read, and drop activity, plus live lane/ticket free-credit readback. The lane mask applies at packet boundaries: in-flight packets drain, then newly arriving packets on masked lanes are dropped and counted.
- **Synthesis Example**: updated `syn/opq_monolithic_4lane_merge` to the new catalog revision, fixed its local search path to discover the IP from `packet_scheduler/`, and regenerated the example `.qsys` / `.sopcinfo` / synthesis outputs with the exported `csr` interface.
- **Verification**: reran the active UVM basic smoke on the VHDL implementation after the CSR insertion. The shared scoreboard still closes with `expected=4 actual=4 missing=0 ghost=0`, so the observability/control add did not disturb the exercised data path.

## 26.1.0.0413

- **RTL**: promoted the native SystemVerilog rewrite to a versioned milestone. The exercised default/basic monolithic path is now native SV for the per-lane ingress parser, shared page allocator, handle-reader/block-mover/B2P arbiter, and the current single-page presenter. The `opq_basic_smoke_test` default case passes on `DUT_IMPL=native_sv` with the same observable behavior as the VHDL wrapper path.
- **RTL**: started the frame-table side of the rewrite in the preserved split architecture. New standalone SV blocks now exist for the frame-table tracker and frame-table presenter under `rtl/ordered_priority_queue/monolithic_sv/`. They are compile-clean staging blocks for the later top-level swap; the active monolithic shell still uses the basic presenter until the frame-table mapper and tiled top wiring are completed.
- **Verification Harness**: froze the current UVM contract around the real ingress packet format. The driver/monitor contract remains FEB-frame oriented, and the scoreboard checks hit integrity end to end: every hit observed at ingress must reappear at egress with the correct subheader slot and without ghost creation. The scoreboard timestamp key is the reconstructed 48-bit hit timestamp from frame header + subheader timing, and a UVM-only 64-bit `HIT_ID` side channel is carried in the harness for exact missing/ghost-hit tracking without changing synthesizable RTL.
- **Verification Harness**: `DUT_IMPL=vhdl` and `DUT_IMPL=native_sv` intentionally share the same sequencer, monitors, scoreboard, and SVA contract. The native-SV bring-up currently closes the basic smoke case with `expected=4 actual=4 missing=0 ghost=0`, while the placeholder edge/error/cross/prof buckets remain compile-clean entry points for the full DV-plan expansion.
- **Packaging**: established `packet_scheduler/VERSION` as the active monolithic OPQ rewrite release stamp and bumped the ordered-priority-queue catalog minor version from `26.0.0.0413` to `26.1.0.0413`.

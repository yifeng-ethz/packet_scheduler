# BUG_HISTORY.md - packet_scheduler OPQ DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounter sim-time legend:
- `min / p50 / max` = first encounter in simulation time under a still-traceable randomized long-run screen
- `n/a (...)` = directed-only, formal-only, reporting-only, or otherwise not honestly measurable in the current randomized harness
- current measured mixed-soak encounter stats come from `10` seeded `opq_cross_mixed_bucket_seconds_soak_test` runs with `+OPQ_MIXED_SOAK_STEPS=200`; raw per-seed data is archived in `/tmp/opq_bug_encounter_20260419/encounter_summary.tsv`

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

## Index

| bug_id | class | severity | encounter sim-time | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-native-sv-empty-frame-drain-replays-trailer-only-packets) | R | hard stuck error | `n/a (directed-only)` | fixed | `opq_basic_feb_packet_contract_test` | `37c4b2a` | Native-SV empty-frame drain replayed trailer-only packets after the first legal frame. |
| [BUG-002-R](#bug-002-r-native-sv-4-lane-feb-path-corrupted-middle-lane-hit-placement) | R | soft error | `n/a (4-lane directed)` | fixed | `opq_basic_feb_packet_contract_test` @ `OPQ_N_LANE=4` | `37c4b2a` | Native-SV 4-lane allocator used the wrong block-start prefix and misplaced middle-lane hits. |
| [BUG-003-R](#bug-003-r-native-sv-csr-plane-returned-zeros-and-hid-live-credits) | R | non-datapath-refactor | `n/a (CSR/readback)` | fixed | `opq_basic_feb_packet_contract_test` | `6b9ed41` | Native-SV wrapper CSR plane was still a stub and returned zero readback. |
| [BUG-004-H](#bug-004-h-cross-bucket-csr-proof-used-non-feb-ingress-framing) | H | non-datapath-refactor | `n/a (harness proof)` | fixed | `opq_cross_bp_credit_test`, `opq_cross_drr_allowance_test` | `6b9ed41` | Cross-bucket CSR proof sequences drove split packets instead of FEB whole-frame traffic. |
| [BUG-005-R](#bug-005-r-header-error-mask-path-corrupts-the-next-legal-frame-timestamp) | R | soft error | `n/a (directed-only)` | fixed | `opq_error_header_mask_recovery_test` | `5c0d90f` | Header-error mask recovery no longer leaks stale timestamp context into the next legal frame after the allocator was re-seeded from the captured ingress header timestamp base. |
| [BUG-006-H](#bug-006-h-native-sv-no-restart-signoff-accounting-broke-continuous-frame-closure) | H | non-datapath-refactor | `n/a (no-restart directed)` | fixed | `opq_bucket_frame_native_sv_test`, `opq_all_buckets_frame_native_sv_test` | `b799f94` | No-restart signoff reused frame identity and miscounted malformed subheaders. |
| [BUG-007-R](#bug-007-r-swb-4-lane-sparse-frame-cadence-drops-later-hits) | R | soft error | `n/a (4-lane directed)` | fixed | `opq_prof_missing_empty_frame_test` @ `OPQ_N_LANE=4` | `466b935` | The old 4-lane sparse-cadence drop is no longer reproducible on current native-SV RTL. |
| [BUG-008-R](#bug-008-r-forced-overwrite-path-still-emits-malformed-accepted-egress-and-no-frame-table-drop-accounting) | R | soft error | `n/a (forced overflow directed)` | fixed | `opq_error_ftable_overflow_test` | `41948b1` | Reduced-depth forced overwrite under always-stall corrupted accepted egress and hid frame-table drop events until the native-SV presenter and CSR path were fixed. |
| [BUG-009-R](#bug-009-r-bursty-drr-stall-boundary-path-still-corrupts-egress-ordering-and-lacks-late-drop-identity) | R | soft error | `n/a (focused repro only)` | fixed | `opq_cross_drr_bursty_random_test` | `9b516d7` | Bursty DRR plus periodic stall no longer loses late active-lane traffic after the allocator holds merged-frame progress until every active busy lane has surfaced its current ticket. |
| [BUG-010-R](#bug-010-r-header-word-recovery-path-still-corrupts-the-next-legal-frame) | R | soft error | `n/a (directed-only)` | fixed | `opq_error_header_word_mask_recovery_test` | `5c0d90f` | Header-word error injection no longer corrupts the next legal timestamp base after the recovery frame seeds from the captured ingress header timestamp base. |
| [BUG-011-R](#bug-011-r-chained-malformed-subheader-recovery-is-not-composable-in-mixed-bucket-soak) | R | hard stuck error | `0.000102 / 0.541364 / 1.952250 ms` | fixed | `opq_cross_mixed_bucket_random_soak_test` | `466b935` | Chained malformed-subheader recovery now stays clean in the mixed-bucket soaks and the default no-restart baseline. |
| [BUG-012-H](#bug-012-h-edge-medium-ready-profile-testcase-was-wired-as-always-ready) | H | non-datapath-refactor | `n/a (testcase wiring)` | fixed | promoted EDGE isolated rerun on `2026-04-17` | `cbb05e0` | The supposed medium-backpressure testcase never applied stalls and gave false evidence. |
| [BUG-013-H](#bug-013-h-mixed-bucket-random-soak-was-reported-as-directed-and-omitted-txn-growth-traceability) | H | non-datapath-refactor | `n/a (reporting-only)` | fixed | regenerated native-SV report on `2026-04-17` | `cbb05e0` | The promoted mixed-soak testcase was misclassified as directed and hid required random-case reporting. |
| [BUG-014-R](#bug-014-r-formal-like-egress-flush-under-backpressure-violates-the-avalon-st-hold-contract) | R | soft error | `n/a (formal probe)` | fixed | `formal_egress.sh` targeted stress probe on `2026-04-18` | `dd6fe75` | Formal-like egress flush-under-backpressure no longer breaks the live Avalon-ST hold contract after the basic presenter preserves synchronous page-RAM return data across held `ready`. |
| [BUG-015-H](#bug-015-h-oss-ingress-sby-harness-still-false-fails-on-phase-sensitive-write-and-drop-checks) | H | non-datapath-refactor | `n/a (formal-only)` | fixed | `formal_ingress.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `1048b6c` | The ingress OSS proof now passes after the harness stopped consuming reset-warmup debug pulses and switched from phase-ambiguous credit-bus checks to pulse-level write/drop contracts. |
| [BUG-016-H](#bug-016-h-oss-basic-presenter-sby-lowering-hits-a-logic-loop-in-the-overwrite-scan-path) | H | non-datapath-refactor | `n/a (formal-only)` | fixed | `formal_egress.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `f8448ac` | The OSS basic-presenter proof no longer dies in SMT2 lowering; the live Avalon-ST hold-under-backpressure slice now passes on the OSS subset. |
| [BUG-017-H](#bug-017-h-oss-mover-sby-harness-now-reaches-proof-but-still-fails-on-arbiter-shape-invariants) | H | non-datapath-refactor | `n/a (formal-only)` | fixed | `formal_mover.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `de65125` | The live OSS mover proof now passes on the current block-path subset after the proof-clean arbiter view was exported and constrained. |
| [BUG-018-H](#bug-018-h-extended-mixed-bucket-seconds-soak-exposes-chained-masked-drop-accounting-underrun) | H | non-datapath-refactor | `11.277854 / 12.797138 / 13.457942 ms` | fixed | `opq_cross_mixed_bucket_seconds_soak_test` on `2026-04-18` | `466b935` | The full stretched mixed-bucket seconds soak now passes end to end after the allocator repairs and the mixed ERROR pool restoration. |
| [BUG-019-R](#bug-019-r-merged-frame-header-counts-incremented-per-accepted-lane-instead-of-per-emitted-subheader) | R | soft error | `n/a (invariant smoke)` | fixed | `opq_basic_smoke_test` on `2026-04-18` | `466b935` | The native-SV page allocator was double-counting merged subheaders in the frame header, so the advertised subheader count could exceed the emitted K237 count under multi-lane merge. |
| [BUG-020-R](#bug-020-r-late-drop-lane-credit-return-added-stale-block-path-credit-and-poisoned-no-restart-state) | R | hard stuck error | `n/a (exact repro)` | fixed | `opq_cross_hit3_exact_183_190_repro_test` on `2026-04-19` | `466b935` | Late-drop lane-credit return pulses were adding stale block-path credit data when only one source was valid, corrupting no-restart lane-credit state and the mixed-soak exact failing window. |
| [BUG-021-R](#bug-021-r-late-frame-drop-accounting-counted-whole-frame-sop-metadata-instead-of-the-unread-ticket-tail) | R | non-datapath-refactor | `n/a (overflow random-ready)` | fixed | `opq_cross_random_ready_overflow_seconds_soak_test` on `2026-04-19` | `5c0d90f` | Late-frame drop accounting used full-frame SOP metadata instead of the unread ticket tail, which double-counted already credit-dropped subheaders and broke long overflow hit conservation. |
| [BUG-022-R](#bug-022-r-new-frame-running-ts-seeded-from-frame-header-ts-instead-of-the-current-subheader-ts) | R | hard stuck error | `n/a (exact repro)` | fixed | `opq_cross_hit3_exact_183_190_repro_test` on `2026-04-19` | `466b935` | A new frame seeded allocator `running_ts` from the frame header timestamp instead of the parser's current running subheader timestamp, so same-frame payload tickets were misclassified as `future` and the allocator could emit an empty tail before fetching payload. |
| [BUG-023-H](#bug-023-h-expanded-no-restart-signoff-matrix-reused-stale-frame-identity-and-under-specified-credit-restore-idle) | H | non-datapath-refactor | `n/a (no-restart directed)` | fixed | `opq_bucket_frame_native_sv_test`, `opq_all_buckets_frame_native_sv_test` on `2026-04-20` | `36de7a3` | The expanded no-restart signoff matrix falsely failed until composed sequences carried monotonic frame identity across lanes and waited for true idle credit restore. |
| [BUG-024-R](#bug-024-r-overwrite-launch-window-can-still-flush-the-live-head-before-first-accept) | R | soft error | `n/a (reduced-depth directed)` | fixed | `opq_error_ftable_overflow_test` on `2026-04-20` | `89de4bf` | The reduced-depth overwrite screen is clean again after the presenter protects the live head through the first visible beat and exports lane-resolved overwrite-drop accounting. |
| [BUG-025-R](#bug-025-r-active-lane-retirement-still-depends-on-a-level-eop-flag-that-the-parser-can-clear-too-early) | R | hard stuck error | `n/a (large constrained-random)` | fixed | `opq_cross_drr_bursty_random_test` on `2026-04-20` | `a813795` | The active-lane retirement race is no longer reproducible after the allocator switched from level EOP dependence to serial-tagged tail-seen/drop state; the `frame_count=3` repro and refreshed seed `1..8` constrained-random reruns are green on `2026-04-21`. |
| [BUG-026-R](#bug-026-r-live-head-overwrite-protection-suppresses-unread-tail-drop-accounting) | R | soft error | `n/a (overflow random-ready)` | fixed | `opq_cross_random_ready_overflow_seconds_soak_test` on `2026-04-20` | `a813795` | Default-build random-ready overflow no longer corrupts accepted egress after the presenter preserves every stalled resident RAM word, and the reduced-depth `12x16` overwrite-local must-drop witness is green again on `2026-04-21`. |
| [BUG-027-R](#bug-027-r-masked-zero-hit-subheader-recovery-kept-tail-bypass-drop-asserted-through-the-trailer) | R | soft error | `n/a (localized formal-like ingress stress)` | fixed | `formal_ingress.sh` / `opq_formal_like_ingress_recovery_stress_test` on `2026-04-21` | `a813795` | A legal zero-hit subheader after a masked subheader no longer leaves the parser in `MASK_PKT`; trailer bypass now reports only the surviving local drop semantics and the refreshed ingress fallback suite is green on `2026-04-21`. |
| [BUG-028-H](#bug-028-h-lane-hit-ledger-retired-delivered-beats-against-parser-timestamps-instead-of-canonical-egress-timestamps) | H | non-datapath-refactor | `n/a (4-lane supplemental rerun)` | fixed | `opq_cross_random_ready_overflow_step2_boundary_test` on `2026-04-21` @ `OPQ_N_LANE=4 OPQ_N_SHD=128` | `a813795` | The 4-lane no-restart ledger is clean again after the scoreboard started carrying both canonical delivery timestamps and parser/accounting timestamps per hit. |

## 2026-04-17

### BUG-001-R: Native-SV empty-frame drain replays trailer-only packets
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_feb_packet_contract_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
  - VHDL reference under the same FEB-contract sequence emitted full empty frames; native SV emitted trailer-only packets at later frame boundaries and tripped `opq_hit3_contract_sva`
- Symptom:
  - frame 0 hit integrity was clean after the presenter tail fix, but the next frames collapsed to lone trailers
  - native egress around the second frame was `... trailer, trailer, trailer ...` instead of `header, 8 empty subheaders, trailer`
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` declared and updated `eop_flush_ack`, but never drove `eop_flush_ack_o`
  - the ingress parser therefore never cleared `alert_eop`, and the page allocator kept re-entering `tail_only_flush`
- Fix status:
  - fixed
- Runtime / coverage context:
  - this was the first native-SV FEB-contract blocker and had to close before the FEB whole-frame path could be trusted as the report anchor
- Commit:
  - `37c4b2a` `Fix native OPQ FEB reference path`

### BUG-002-R: Native-SV 4-lane FEB path corrupted middle-lane hit placement
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_feb_packet_contract_test OPQ_N_LANE=4 DUT_IMPL=native_sv`
  - VHDL reference under the same FEB-contract sequence produced `missing=0 ghost=0`
- Symptom:
  - native 4-lane egress emitted lane0 hits, then lane3 hits, then four zero ghosts; lane1 and lane2 hits were missing
  - before the datapath bug was visible, the native 4-lane UVM harness also hard-failed because `tb_top` still blocked `OPQ_USE_NATIVE_SV` at 4 lanes and instantiated the VHDL-only `ordered_priority_queue_dut4`
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` computed `page_allocator_if_alloc_blk_start[i]` from only `ticket[i-1].block_length`, which is sufficient for 2 lanes but wrong for 4 lanes; the VHDL reference uses a cumulative prefix offset across accepted prior lanes
  - the native-SV wrapper/harness was still 2-lane hard-coded, so the 4-lane FEB-contract testcase could not reach the datapath until the wrapper and `tb_top` were extended
- Fix status:
  - fixed
- Runtime / coverage context:
  - this closed the visible 4-lane FEB corruption path, but it did not close the later sparse-cadence non-claim tracked separately in `BUG-007-R`
- Commit:
  - `37c4b2a` `Fix native OPQ FEB reference path`

### BUG-003-R: Native-SV CSR plane returned zeros and hid live credits
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_feb_packet_contract_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - native-SV datapath matched the VHDL FEB reference, but the CSR wrapper hard-returned zero data, could not program DRR allowance before traffic, and misreported restored lane/ticket credits at the end of the run
  - the first native bring-up also tripped the CSR SVA because `readdatavalid` did not match the expected Avalon-MM read contract
- Root cause:
  - `ordered_priority_queue_dut_sv.sv` still contained a stub CSR plane instead of the VHDL-visible register map
  - there was no native plumbing for programmable DRR allowance into the block path, no live counter accumulation logic, and the wrapper exposed raw internal credit state rather than the visible restored-credit contract used by the VHDL DUT
- Fix status:
  - fixed
- Runtime / coverage context:
  - this fix made native-SV signoff evidence trustworthy for CSR identity, capability, counter, and credit-restore checks
- Commit:
  - `6b9ed41` `Fix native SV OPQ CSR plane and CSR proof traffic`

### BUG-004-H: Cross-bucket CSR proof used non-FEB ingress framing
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_bp_credit_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_drr_allowance_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - both tests completed with clean scoreboard accounting, but the ingress SVA fired on every frame because the stress sequences asserted fresh `sop` on subheaders instead of using one FEB whole-frame packet with trailer-only `eop`
- Root cause:
  - `opq_soak_virtual_sequence` and `opq_drr_saturation_virtual_sequence` were still driving split-packet synthetic traffic while the active signoff contract for OPQ debug had already moved to FEB whole-frame traffic
- Fix status:
  - fixed
- Runtime / coverage context:
  - this was a harness-contract bug; leaving it unfixed would have made the cross bucket look green while violating the real ingress protocol
- Commit:
  - `6b9ed41` `Fix native SV OPQ CSR plane and CSR proof traffic`

### BUG-005-R: Header-error mask path corrupts the next legal frame timestamp
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_error_header_mask_recovery_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - a malformed preamble/header frame is masked as intended, but the next legal recovery frame emerges with hits at the correct payload words and the wrong timestamp base
  - observed failure is `expected=4 actual=4 missing=4 ghost=4`, with ghost hits reconstructed at `ts=0x10` instead of the legal recovery timestamp `0x1010`
  - the ingress monitor also reports `capture_err=1` on the malformed frame, which is expected for the truncated stimulus and not the root cause of the timestamp corruption
- Root cause:
  - the recovery frame rebuilt the legal header timestamp correctly inside the ingress parser, but the page allocator had no dedicated header timestamp-base input for the next legal SOP
  - on the masked-header recovery path, the allocator seeded `frame_ts` / `running_ts` from stale allocator state instead of the just-rebuilt legal frame timestamp base, so the payload hits were emitted in the wrong frame slot (`0x0010` instead of `0x1010`)
- Fix status:
  - fixed in isolated native-SV on `2026-04-18`
- Runtime / coverage context:
  - `opq_error_header_mask_recovery_test` now ends with `expected=4 actual=4 missing=0 ghost=0`
  - the standalone ingress AVST SVA also had to learn that an error-tainted open packet is abortable at the next legal recovery preamble, otherwise the intentionally truncated malformed frame still raised a false nested-SOP assertion after the DUT had already masked it
- Commit:
  - `5c0d90f` `Fix OPQ late-frame drop accounting and refresh signoff docs`

### BUG-006-H: Native-SV no-restart signoff accounting broke continuous-frame closure
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_bucket_frame_native_sv_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
  - `packet_scheduler/tb/uvm` `TEST=opq_all_buckets_frame_native_sv_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - the generated `bucket_frame` / `all_buckets_frame` signoff runs existed but initially failed under native SV
  - early failing evidence showed severe end-of-run mismatch:
    - `bucket_frame`: `expected=3770 actual=4 missing=3766 ghost=0`
    - `all_buckets_frame`: `expected=3788 actual=4 missing=3784 ghost=0`
  - after tightening the harness so each composed case waited for full credit restore, the runner still timed out case-by-case on restore checks
- Root cause:
  - the first failure was a harness identity bug, not a real no-reset drain failure: composed no-restart cases restarted `pkg_cnt` and frame timestamp context from zero even though the native page allocator uses the SOP serial as frame identity
  - after the serial/timestamp carry fix, the last residual failure was a scoreboard accounting bug: malformed subheaders were still counted as accepted lane traffic even though the native parser masks a subheader with `error_bits[1]` and does not issue a ticket write for it
- Fix status:
  - fixed
- Runtime / coverage context:
  - carrying continuous-frame `pkg_cnt` / timestamp identity through composed sequences and counting only parser-accepted subheaders/hits closed both mandatory no-restart baselines
- Commit:
  - `b799f94` `Fix OPQ native-SV continuous-frame signoff accounting`

### BUG-007-R: SWB 4-lane sparse-frame cadence drops later hits
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_prof_missing_empty_frame_test OPQ_N_LANE=4`
  - consistent with `packet_scheduler/tb_int/uvm` `tb_int_longrun_sanity_test +TB_INT_LONGRUN_CASE_ID=1`
- Symptom:
  - standalone 4-lane OPQ passes equal-cadence FEB whole-frame traffic but drops later hits when some lanes stop emitting frames instead of sending empty-frame cadence
  - reproducer result: `expected=6 actual=4 missing=2 ghost=0`
  - integrated clue: stage-D per-lane frame counts are highly uneven (`57/128/57/73`) and OPQ remains stuck near the first frame
- Root cause status:
  - fixed on current native-SV RTL
  - the old failure is no longer reproducible after the allocator / late-drop
    credit repair series that culminated in `BUG-020-R`; current evidence
    points to stale lane-credit state rather than a permanent 4-lane cadence
    contract violation
  - OPQ still supports the explicit ingress lane-mask CSR, but the focused
    unmasked sparse-cadence testcase is now green and no longer forces a hard
    4-lane non-claim by itself
- Fix status:
  - fixed in focused native-SV rerun on `2026-04-19`
- Runtime / coverage context:
  - `OPQ_N_LANE=4 BUILD_DIR=/tmp/opq_uvm_build_n4 bash packet_scheduler/tb/scripts/run_uvm.sh opq_prof_missing_empty_frame_test`
    now ends with `expected=4 actual=4 missing=0 ghost=0`
  - current per-lane ledgers close as:
    - lane0 `accepted=2 dropped=0 delivered=2 unexplained=0`
    - lane1 `accepted=2 dropped=0 delivered=2 unexplained=0`
    - lane2 `accepted=0 dropped=0 delivered=0 unexplained=0`
    - lane3 `accepted=0 dropped=2 post_drop=2 delivered=0 unexplained=0`
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

### BUG-008-R: Forced-overwrite path still emits malformed accepted egress and no frame-table drop accounting
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_error_ftable_overflow_test OPQ_N_LANE=2 OPQ_PAGE_RAM_DEPTH=512 DUT_IMPL=native_sv`
- Symptom:
  - the reduced-depth forced-overwrite probe should accumulate non-zero frame-table drop counters under always-stall backpressure, but instead emits malformed accepted egress while leaving frame-table drop accounting at zero
  - current probe failure ends with `Expected non-zero frame-table drop counters during forced egress stall overflow run`
  - the same run reports repeated `opq_hit3_contract_sva` failures and `lane0/1 observed drop events=0 dropped_hits=0`
- Root cause:
  - the native-SV basic presenter computed the incoming frame length through the truncated page-RAM address type before checking for oversize, so a frame larger than `PAGE_RAM_DEPTH` could wrap its stored length and still enter the presenter metadata queue
  - the same presenter path had no overwrite-drop plan for unread residents, so always-stall overwrite pressure could leave resident metadata pointing at page-RAM contents that had already been overwritten
  - `ordered_priority_queue_dut_sv.sv` never accumulated the presenter's frame-table drop pulses into the visible `FT_DROP_HDR/SHD/HIT` CSRs, so the overflow path also looked silent in software-visible accounting
- Fix status:
  - fixed
- Runtime / coverage context:
  - the earlier fix closed the original silent-drop / malformed-egress symptom and enabled the testcase to move into the reduced-depth supplemental signoff plumbing
  - the fresh `2026-04-20` reduced-depth rerun reopens accepted-egress `opq_hit3_contract` frame-trailer/pkg_cnt/timestamp errors, so the point is not currently signoff-clean even though it remains the canonical reduced-depth bug anchor
- Commit:
  - `41948b1` `Fix OPQ native-SV overwrite drop accounting`

### BUG-009-R: Bursty DRR stall-boundary path still corrupts egress ordering and lacks late-drop identity
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_drr_bursty_random_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls still trips repeated `opq_hit3_contract_sva` failures and large scoreboard drift
  - current probe log ends with `expected=4400 actual=1335 missing=3168 ghost=103` and `UVM_ERROR : 3286`
- Root cause:
  - the page allocator was allowed to advance merged-frame `running_ts` once one active lane had surfaced a current subheader ticket, even when another already-active busy lane had not yet produced its ticket for that same subheader
  - under bursty asymmetric DRR traffic, that let the slow active lane's same-frame non-SOP ticket arrive "late" relative to the allocator's advanced frame state and get consumed as stale/past traffic without a legal-drop identity, which manifested as missing hits at egress
  - the harness-side late-drop blind spot was closed at the same time by exporting pre/post ingress drop-event identity into the drop monitor and scoreboard, so the repaired path can now prove `accepted = delivered + explained_drops` per lane instead of relying on final CSR totals alone
- Fix status:
  - fixed in focused native-SV repro on `2026-04-19`
- Runtime / coverage context:
  - at fix landing, `opq_cross_drr_bursty_repro_test` closed with
    `expected=1864 actual=1864 missing=0 ghost=0`
  - the repaired focused repro at that point also closed the per-lane hit ledger:
    - lane0 `accepted=1840 dropped=2208 pre_drop=0 post_drop=2208 delivered=1840 unexplained=0`
    - lane1 `accepted=24 dropped=328 pre_drop=0 post_drop=328 delivered=24 unexplained=0`
  - the original running-timestamp loss remains closed at commit `9b516d7`, and
    the former reopening through `BUG-025-R` is no longer reproduced on the
    refreshed current-tree reruns
- Commit:
  - `9b516d7` `Fix OPQ bursty DRR frame-progress loss`

### BUG-010-R: Header-word recovery path still corrupts the next legal frame
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_error_header_word_mask_recovery_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - isolated native-SV still ends at `expected=4 actual=4 missing=4 ghost=4`, with the recovery hits reconstructed at `ts=0x10` instead of `ts=0x1010`
  - when this testcase was temporarily inserted into the promoted no-restart ERROR bucket on `2026-04-17`, `opq_bucket_frame_native_sv_test` and `opq_all_buckets_frame_native_sv_test` both stopped being signoff-clean until the promotion was reverted
- Root cause:
  - this path exercised the same missing handoff as `BUG-005-R`: the parser rebuilt the legal recovery header, but the page allocator still lacked a dedicated ingress header timestamp-base input and therefore restarted the recovery frame from stale allocator state
  - the DUT symptom was identical at egress: correct payload ordering under the wrong frame timestamp base
- Fix status:
  - fixed in isolated native-SV on `2026-04-18`
- Runtime / coverage context:
  - `opq_error_header_word_mask_recovery_test` now ends with `expected=4 actual=4 missing=0 ghost=0`
  - the testcase still needs to be reinserted into the generated ERROR bucket / no-restart baseline on the next report refresh before it is removed from the report exclusions
- Commit:
  - `5c0d90f` `Fix OPQ late-frame drop accounting and refresh signoff docs`

### BUG-011-R: Chained malformed-subheader recovery is not composable in mixed-bucket soak
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_mixed_bucket_random_soak_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - the isolated `opq_error_subheader_mask_recovery_test` remains green, but when the same malformed-subheader recovery is chained behind prior mixed-bucket traffic it can emit malformed egress framing and trip `opq_hit3_contract_sva`
  - the first mixed-soak failure showed `Egress expected hit payload, got datak=0x1` followed by `sub-header arrived before the previous sub-header drained` and a later credit-restore timeout on the chained recovery step
- Root cause status:
  - fixed on `2026-04-19`
  - the mixed ERROR pool now genuinely re-exercises `subheader_error_recovery`, and the repaired allocator/presenter state no longer corrupts chained no-restart framing after predecessor traffic
- Runtime / coverage context:
  - `opq_cross_mixed_bucket_random_soak_test` now passes with the malformed-subheader recovery case back in the active mixed ERROR pool
  - encounter study on `2026-04-19`:
    - `10` seeded `opq_cross_mixed_bucket_seconds_soak_test` runs with `+OPQ_MIXED_SOAK_STEPS=200` hit the first
      `case=subheader_error_recovery` at `0.000102 / 0.541364 / 1.952250 ms`
      (`min / p50 / max`)
    - raw per-seed timings are archived in
      `/tmp/opq_bug_encounter_20260419/encounter_summary.tsv`
  - `opq_cross_mixed_bucket_seconds_soak_test` reaches repeated chained `subheader_error_recovery` steps, including `Mixed ERROR step 509 case=subheader_error_recovery`, and still exits with `UVM_ERROR : 0`
  - `opq_all_buckets_frame_native_sv_test` remains clean with the no-restart recovery tail sequence (`masked_recovery_masked_seq` then `masked_recovery_recovery_seq`) after the promoted matrix
- Fix status:
  - fixed
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

### BUG-012-H: EDGE medium-ready profile testcase was wired as always-ready
- First seen in:
  - promoted EDGE isolated rerun on `2026-04-17` while refreshing the native-SV report inventory
- Symptom:
  - `opq_edge_ready_medium_profile_test` was reported as a medium-backpressure evidence point, but the testcase configuration still used `BP_ALWAYS_READY`
  - this gave a false sense of closure because the testcase never exercised the intended ready/stall envelope
- Root cause:
  - the testcase profile was copied from the always-ready variant and never switched to a periodic-stall backpressure item
- Fix status:
  - fixed
- Runtime / coverage context:
  - the testcase now uses `BP_PERIODIC_STALL` with a medium duty profile and remains green after the fix, so the promoted EDGE evidence now matches the written intent
- Commit:
  - `cbb05e0` `Expand OPQ native-SV promoted coverage and mixed soak`

### BUG-013-H: Mixed-bucket random soak was reported as directed and omitted txn-growth traceability
- First seen in:
  - regenerated native-SV report set on `2026-04-17` after promoting `opq_cross_mixed_bucket_random_soak_test`
- Symptom:
  - the promoted mixed-soak case rendered as `Method: D` with `observed_txn=1`
  - `REPORT/txn_growth/README.md` simultaneously claimed that no promoted random cases existed even though the run log contained `64` `Mixed-soak step` selections
- Root cause:
  - `build_dv_report_json.py` still defaulted every `case_entry()` to directed mode with one observed transaction and did not harvest the actual random-step count from the soak log or populate `random_cases`
- Fix status:
  - fixed
- Runtime / coverage context:
  - the report now classifies `COMBO_OPQ_507_cross_mixed_bucket_random_soak_test` as random, records `observed_txn=64`, and generates the required `txn_growth` placeholder page until checkpoint UCDBs are implemented
- Commit:
  - `cbb05e0` `Expand OPQ native-SV promoted coverage and mixed soak`

### BUG-014-R: Formal-like egress flush-under-backpressure violates the Avalon-ST hold contract
- First seen in:
  - `packet_scheduler/tb/scripts/formal_egress.sh` with
    `FORMAL_BACKEND=stress`
    `FORMAL_STRESS_TESTS=opq_formal_like_egress_flush_backpressure_stress_test`
    on `2026-04-18`
- Symptom:
  - the targeted formal-like egress probe originally failed with
    repeated `opq_avst_egress_sva.sv` line `51`
    `p_hold_under_backpressure` assertion hits while the test forced a
    long flush window under deasserted output `ready`
  - the first failing logs showed assertion timestamps such as
    `32302 ns`, `48374 ns`, and `64454 ns`
  - after the presenter repair, the same targeted probe now passes as a
    clean backpressure/hold regression and the old malformed first
    packet no longer appears at egress
- Root cause status:
  - fixed
  - the live native-SV basic presenter consumed `page_ram_rd_data_i`
    directly even though the page RAM is synchronous-read; when the head
    beat was held under `valid && !ready`, the returned RAM word could
    advance underneath the held output state and the resumed packet
    could skip or duplicate words
- Fix:
  - add a read-data skid in
    `ordered_priority_queue_monolithic_basic_presenter.sv` so a RAM
    return observed under held `ready` is preserved and then fed back
    into the launch pipe on resume
  - keep the aggressive formal-like testcase focused on the real hold
    contract by requiring accepted egress activity under backpressure,
    not an unrelated frame-table-drop signature
- Runtime / proof context:
  - `FORMAL_BACKEND=sby bash tb/scripts/formal_egress.sh` now records
    `formal=sby_pass`
  - the targeted fallback probe
    `opq_formal_like_egress_flush_backpressure_stress_test` now passes
    without `p_hold_under_backpressure` assertion hits
  - the unread-overwrite scan remains a documented OSS non-claim, but
    the live Avalon-ST hold-under-backpressure defect is closed
- Fix status:
  - fixed
- Commit:
  - `dd6fe75` `Fix OPQ presenter hold bug and close OSS formal slice`

### BUG-015-H: OSS ingress SBY harness still false-fails on phase-sensitive write and drop checks
- First seen in:
  - `packet_scheduler/tb/scripts/formal_ingress.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
    on `2026-04-18`
- Symptom:
  - the first live `opq_oss_ingress` proof parsed, elaborated, and
    reached Bitwuzla, but it false-failed on apparent credit-range and
    ticket-write assertions
  - the counterexample showed the harness was consuming `lane_issue_dbg_oss`
    / `ticket_issue_dbg_oss` during reset-warmup, before the parser had
    reached a meaningful post-reset tracking window
  - that created fake outstanding-credit state in the harness, which in
    turn allowed over-return traces and later drove false failures on
    phase-ambiguous public `*_credit_dbg_oss` observability ports
- Root cause status:
  - fixed
  - the bug was in the OSS harness, not the DUT: credit accounting began
    one phase too early and treated debug-credit buses as exact proof
    anchors even though same-cycle return/write behavior can legitimately
    make those observability signals ambiguous under SBY sampling
- Fix:
  - freeze harness credit accounting until a real post-reset tracking
    window is active
  - prove pulse-level contracts instead of phase-ambiguous free-credit
    buses:
    `lane_issue_dbg_oss == lane_we`,
    `ticket_issue_dbg_oss == ticket_we`,
    and drop-vs-write exclusivity
- Runtime / proof context:
  - `formal_ingress.sh` now records `compile=pass`, `elab=pass`,
    `formal=sby_pass`
  - the current ingress OSS subset proves packet-shape assumptions plus
    live write/drop consistency on the native parser path
  - non-claim: public free-credit debug counters remain observability
    signals and are not used as exact proof anchors in the OSS subset
- Fix status:
  - fixed
- Commit:
  - `1048b6c` `Tighten OPQ OSS ingress proof warmup gating`

### BUG-016-H: OSS basic-presenter SBY lowering hits a logic loop in the overwrite scan path
- First seen in:
  - `packet_scheduler/tb/scripts/formal_egress.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
    on `2026-04-18`
- Symptom:
  - the first live `opq_oss_basic_presenter` proof originally parsed and
    elaborated cleanly, but the Yosys SMT2 backend exited with
    `Found logic loop ... ordered_priority_queue_monolithic_basic_presenter`
  - after splitting the `OPQ_OSS_FORMAL` presenter subset away from the
    unread-overwrite scan, `formal_egress.sh` now records
    `formal=sby_pass` on the live Avalon-ST hold-under-backpressure slice
- Root cause status:
  - fixed for the current OSS hold-contract subset
  - the current unread-overwrite scan coding style remains on the
    native-SV path, but the `OPQ_OSS_FORMAL` branch now isolates a
    feed-forward oversize-only drop subset so the OSS backend can reach
    the egress hold proof
- Residual non-claim:
  - the unread-overwrite scan itself is still not proven in the OSS path;
    the pass only covers the live presenter hold-under-backpressure subset
- Fix status:
  - fixed
- Commit:
  - `f8448ac` `Advance OPQ OSS formal proof slices`

### BUG-017-H: OSS mover SBY harness now reaches proof but still fails on arbiter-shape invariants
- First seen in:
  - `packet_scheduler/tb/scripts/formal_mover.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
    on `2026-04-18`
- Symptom:
  - the first live `opq_oss_block_path` proof now parses, elaborates,
    and reaches the Bitwuzla engine on this host
  - after exporting the proof-clean arbiter view and tightening the
    reset/output contract, `formal_mover.sh` now records
    `formal=sby_pass`
- Root cause status:
  - fixed for the current OSS mover subset
  - the remaining proof-clean arbiter/debug view is now sufficient for
    the ownership/invariant slice the mover wrapper runs today
- Residual non-claim:
  - this pass does not claim full end-to-end frame-table/presenter proof;
    it closes the current OSS block-path subset only
- Fix status:
  - fixed
- Commit:
  - `de65125` `Stabilize OPQ mixed-soak accounting and OSS proofs`

### BUG-018-H: Extended mixed-bucket seconds soak exposes chained masked-drop accounting underrun
- First seen in:
  - `packet_scheduler/tb/scripts/run_uvm.sh`
    `TEST=opq_cross_mixed_bucket_seconds_soak_test`
    `VSIM_PLUSARGS=+TB_CLK_PERIOD_NS=250`
    on `2026-04-18`
- Symptom:
  - the earlier extended mixed-soak bug-hunt screen no longer reproduces
    the old scoreboard `Drop accounting underrun ... source=monitor`
    hole from step `3` / `5`
  - the first stretched rerun after that scoreboard repair was able to
    reach much deeper chained traffic and then tripped the live
    `opq_hit3_contract` SVA instead:
    `hit word arrived without a pending non-empty sub-header`
  - the full rerun on the `BUG-014-R` presenter fix gets much farther
    than the earlier exploratory cutoff, but it still fails: the first
    current hit is at `11.642702 ms`, just before `mixed_sparse_191`,
    and later repeats around `mixed_soak_261`,
    `mixed_whole_skew_275`, `mixed_whole_skew_418`, and again before
    `mixed_whole_skew_435`
- Root cause status:
  - fixed on `2026-04-19`
  - the remaining long-chain failure was closed by the allocator state repairs (`BUG-020-R` and `BUG-022-R`) plus the mixed ERROR pool restore that puts malformed-subheader recovery back into the stretched run
- Runtime / coverage context:
  - the exact deterministic reproducer `opq_cross_hit3_exact_183_190_repro_test` passes cleanly on current RTL
  - encounter study on `2026-04-19`:
    - `10` seeded `opq_cross_mixed_bucket_seconds_soak_test` runs with `+OPQ_MIXED_SOAK_STEPS=200` reached the earliest historical
      `BUG-018-H` failure depth (`Mixed-soak step 191`) at
      `11.277854 / 12.797138 / 13.457942 ms` (`min / p50 / max`)
    - raw per-seed timings are archived in
      `/tmp/opq_bug_encounter_20260419/encounter_summary.tsv`
  - the full stretched `opq_cross_mixed_bucket_seconds_soak_test` now crosses the previously cited later windows (`mixed_soak_261`, `mixed_whole_skew_275`, `mixed_whole_skew_418`, `mixed_whole_skew_435`) and exits with `UVM_ERROR : 0`, `UVM_FATAL : 0`, and `Errors: 0`
  - the companion `opq_cross_mixed_bucket_random_soak_test` also passes, so both long mixed-bucket envelopes are back to green
- Fix status:
  - fixed
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

### BUG-019-R: Merged frame header counts incremented per accepted lane instead of per emitted subheader
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_smoke_test OPQ_N_LANE=2 DUT_IMPL=native_sv` on `2026-04-18`
  - exposed immediately after tightening the packet-boundary invariant to compare emitted K237 subheaders against the frame-header subheader count
- Symptom:
  - the merged egress frame header advertised `510` / `512` subheaders while the body emitted only `255` / `256` K237 subheaders
  - `opq_hit3_contract_sva` failed with:
    - `frame trailer sub-header count mismatch: expected=510 actual=255`
    - `frame trailer sub-header count mismatch: expected=512 actual=256`
  - the hit-integrity scoreboard still passed, which confirmed this was a boundary-ledger bug rather than a payload corruption bug
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` incremented `frame_shr_cnt` once per accepted lane inside a merged subheader
  - the merged body emits one K237 per subheader timestamp, so the frame header must count emitted subheaders, not contributing lanes
- Fix status:
  - fixed
- Runtime / coverage context:
  - this bug was found by the invariant-first smoke rerun before the retuned overflow soak was allowed to continue
  - the fix restores agreement between the advertised merged frame header and the emitted packet body, which is a prerequisite for trusting longer soak evidence
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

### BUG-020-R: Late-drop lane-credit return added stale block-path credit and poisoned no-restart state
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_cross_hit3_exact_183_190_repro_test DUT_IMPL=native_sv`
    on `2026-04-19`
  - derived while shrinking `BUG-018-H` from the full seconds-soak failure
    window down to the exact `183..190` no-restart chain
- Symptom:
  - before the final fix, the exact reproducer could advance through the old
    failing traffic family but then hang on credit restore with under-restored
    lane credit, for example:
    - lane0 `lane_credit=304/1022`
    - lane1 `lane_credit=505/1022`
  - the hit ledger at that point was already telling the real story: payload
    delivery was otherwise consistent, so the remaining corruption had moved
    into lane-credit state rather than raw egress ordering
  - once enough of those stale credit additions accumulated, the longer mixed
    soak manifested the same root issue as `opq_hit3_contract` failures in the
    later exact chain
- Root cause:
  - `ordered_priority_queue_monolithic.sv` merged
    `block_path_lane_credit_update[i]` and `late_drop_lane_credit_update[i]`
    with a plain sum whenever either valid bit was asserted
  - that meant a late-drop credit-return pulse could add a stale
    block-path-credit bus value even when `block_path_lane_credit_update_valid`
    was low, corrupting the visible lane-credit state that no-restart chaining
    depends on
- Fix status:
  - fixed in focused native-SV exact repro on `2026-04-19`
- Runtime / coverage context:
  - this fix removed one residual no-restart state corruption from the exact
    deterministic chain, but it was not the last root cause in that window
  - the final exact-window closure still required `BUG-022-R`, which repaired
    the page allocator's new-frame `running_ts` seed
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

### BUG-021-R: Late-frame drop accounting counted whole-frame SOP metadata instead of the unread ticket tail
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_cross_random_ready_overflow_seconds_soak_test DUT_IMPL=native_sv`
    on `2026-04-19`
  - focused half-saturation shape-check configuration:
    `+TB_CLK_PERIOD_NS=100000 +OPQ_OVERFLOW_SOAK_STEPS=1 +OPQ_OVERFLOW_MIN_HIT_PERCENT=0 +OPQ_OVERFLOW_MAX_HIT_PERCENT=50 +OPQ_OVERFLOW_HOT_MIN_HIT_PERCENT=25 +OPQ_OVERFLOW_SUBHEADERS_PER_FRAME=128 +OPQ_OVERFLOW_FRAMES_PER_STEP=4 +OPQ_OVERFLOW_GAP_CYCLES=0 +OPQ_OVERFLOW_REQUIRE_FT_DROP=0`
- Symptom:
  - the previous half-saturation rerun no longer hit the old scoreboard underrun, but it still failed the big-picture conservation check:
    - lane0 `expected=54400 accepted=460 dropped=53940 delivered=386 unexplained=74`
    - lane1 `expected=54016 accepted=359 dropped=53657 delivered=304 unexplained=55`
  - lane drop CSR totals were higher than the scoreboard’s exact accounting by exact whole-subheader quanta:
    - lane0 `+13 * 105`
    - lane1 `+14 * 85`
  - this proved the error was no longer random residue; it was deterministic overcount in the legal-drop path
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` exported late-frame drop counts from the past SOP ticket using the stored whole-frame `n_subh/n_hit` metadata
  - that metadata still includes subheaders that later never become unread tail tickets because ingress credit-drop already rejected them
  - under long overflow/backpressure screens, the SOP-based late-frame count therefore double-counted part of the frame: once in the full-frame late-drop aggregate and again through later exact pre-drop accounting
- Fix status:
  - fixed in focused native-SV overflow rerun on `2026-04-19`
- Runtime / coverage context:
  - the repair changes late-frame accounting to the invariant that actually matches unread ownership:
    - past SOP ticket emits header-drop only
    - each unread non-SOP past ticket emits exactly one dropped subheader with its own `block_length` and `ticket_ts`
  - `/tmp/opq_overflow_fix6.log` now closes cleanly with:
    - lane0 `expected=54400 accepted=460 dropped=53940 delivered=460 unexplained=0`
    - lane1 `expected=54016 accepted=444 dropped=53572 delivered=444 unexplained=0`
    - aggregate `accepted=904 dropped=107512 delivered=904 unexplained=0`
    - `UVM_ERROR : 0`
  - this is shape-check overflow evidence only; frame-table overflow signoff remains a separate requirement
- Commit:
  - `5c0d90f` `Fix OPQ late-frame drop accounting and refresh signoff docs`

### BUG-022-R: New-frame `running_ts` seeded from frame header `ts` instead of the current subheader `ts`
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_cross_hit3_exact_183_190_repro_test DUT_IMPL=native_sv`
    on `2026-04-19`
  - derived while finishing closure of the earliest `BUG-018-H` mixed-soak
    failure window after the stale lane-credit return bug in `BUG-020-R` had
    already been repaired
- Symptom:
  - the focused exact-window repro could still emit an empty trailer for a new
    frame before fetching the first live payload ticket from that same frame
  - boundary tracing showed the broken sequence directly:
    - the new frame opened with `header_ts=0xb000`
    - the first payload ticket arrived at `ts=0xb020`
    - the allocator still decided `idle_to_write_tail` with `running_ts=0xb000`
      and `tk_future=0x3`, then completed `page_len=0`
  - this manifested as the live `opq_hit3_contract` failure
    `hit word arrived without a pending non-empty sub-header` in the old
    `mixed_sparse_191` window
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` seeded a new frame's
    `running_ts` from the frame header timestamp (`header_frame_ts`) instead of
    the parser's current running subheader timestamp (`header_running_ts`)
  - for a frame whose first live payload subheader timestamp was later than the
    header base, the allocator immediately classified those same-frame payload
    tickets as `future` and could close the frame tail before fetching them
- Fix status:
  - fixed in focused native-SV repro on `2026-04-19`
- Runtime / coverage context:
  - the allocator now seeds `running_ts` from `ingress_running_ts_i` /
    `header_running_ts` when the frame is created
  - `/tmp/opq_hit3_exact_183_190_after_fix.log` now ends with:
    - `expected=2476 actual=2476 missing=0 ghost=0`
    - `UVM_ERROR : 0`
  - the focused 5-step bug-hunt rerun
    `/tmp/opq_pa_trace_fixed2.log` also ends with `EXIT:0`
- Commit:
  - `466b935` `Fix OPQ mixed-soak exact-window allocator state and refresh signoff docs`

## 2026-04-20

### BUG-023-H: Expanded no-restart signoff matrix reused stale frame identity and under-specified credit-restore idle
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_bucket_frame_native_sv_test DUT_IMPL=native_sv`
    on `2026-04-20` while promoting the expanded BASIC / EDGE / PROF matrix
  - `packet_scheduler/tb/uvm`
    `TEST=opq_all_buckets_frame_native_sv_test DUT_IMPL=native_sv`
    on `2026-04-20` under the same full-case promotion rerun
- Symptom:
  - after wiring the new passing BASIC / EDGE / PROF cases into the
    continuous-frame baselines, the composed native-SV signoff runs were no
    longer reliably clean
  - intermediate reruns could either:
    - hand the next sequence a reused frame identity when active traffic moved
      from one lane to the other, or
    - hang on the harness-side credit-restore wait even though the datapath was
      still draining toward a legal idle boundary
  - the user-visible failure signature on the clean reproducer family was the
    repeated no-restart message
    `timed out waiting for lane/ticket credit restore`
- Root cause:
  - `tb/uvm/tests/opq_frame_signoff_tests.sv`
    `advance_no_restart_sequence()` still tracked per-lane `pkg_cnt` bases and
    advanced them lane-locally after each composed sequence
  - that was no longer sufficient once the promoted matrix included more
    single-lane and asymmetric traffic shapes: a later composed sequence could
    legitimately switch which lane owned the active frame stream, while the
    harness still reused an earlier frame serial on the newly active lane
  - `tb/uvm/opq_base_test.sv` `wait_for_credit_restore()` also treated
    restored lane/ticket credits as the only quiescence condition and used a
    timeout sized for the smaller pre-expansion matrix
  - the expanded full-case baseline needed the harness to wait for true idle:
    credits restored, error-path restore bits clear, and no residual egress
    beat still pending
- Fix status:
  - fixed in the live native-SV harness on `2026-04-20`
- Runtime / coverage context:
  - the signoff runner now carries one monotonic `pkg_cnt` base across lanes
    after every composed sequence, instead of lane-local bases
  - `wait_for_credit_restore()` now requires full credits, cleared restore
    status, and idle egress before handing off to the next sequence, and the
    timeout was widened for the expanded promoted matrix
  - after the fix, the clean rerun
    `BUILD_DIR=/tmp/opq_uvm_frame_clean_20260420 DUT_IMPL=native_sv bash packet_scheduler/tb/scripts/run_frame_signoff.sh`
    closes with:
    - `opq_bucket_frame_native_sv_test`: `UVM_ERROR : 0`
    - `opq_all_buckets_frame_native_sv_test`: `UVM_ERROR : 0`
    - aggregate summary `pass=2 fail=0 total=2`
  - this is a harness-only signoff-closure bug; it does not change the DUT's
    architectural packet contract
- Commit:
  - `36de7a3` `Wire OPQ full-case signoff expansions and refresh DV docs`

### BUG-024-R: Overwrite launch window can still flush the live head before first accept
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_error_ftable_overflow_test OPQ_PAGE_RAM_DEPTH=512 DUT_IMPL=native_sv`
    on `2026-04-20`
- Symptom:
  - the reduced-depth forced-overwrite rerun now trips accepted-egress
    `opq_hit3_contract` failures instead of closing as a clean reduced-depth
    bug anchor
  - the fresh failing log reports:
    - `frame pkg_cnt did not increase: prev=247 new=247`
    - `frame timestamp did not increase: prev=0xf60000f7f700 new=0xf20000f7f300`
    - later `frame pkg_cnt did not increase: prev=247 new=13`
- Root cause:
  - `ordered_priority_queue_monolithic_basic_presenter.sv`
    `proc_overwrite_drop_plan` only treats the head as protected when
    `pkt_accept_started || output_data_valid[EGRESS_DELAY]`
  - that leaves a launch window where the presenter is already in
    `FTABLE_PRESENTER_PRESENTING`, but the first beat is still in startup
    prefetch and therefore not yet accepted or visible
  - in that window, the overlap path can still assert
    `overwrite_drop_flush_head`, reset the presenter state, and discard the
    just-launched resident head before the first legal acceptance boundary
- Fix status:
  - fixed
- Runtime / coverage context:
  - the repaired reduced-depth rerun on `2026-04-20`
    `BUILD_DIR=/tmp/opq_wrapfix9_build RUN_DIR=/tmp/opq_wrapfix9_run LOG_DIR=/tmp/opq_wrapfix9_run/logs COV_DIR=/tmp/opq_wrapfix9_run/coverage DUT_IMPL=native_sv UVM_TESTNAME=opq_error_ftable_overflow_test UVM_TEST_SEQ=opq_error_ftable_overflow_seq OPQ_PAGE_RAM_DEPTH=512 OPQ_N_SHD=256 OPQ_TICKET_FIFO_DEPTH=512 OPQ_N_LANE=2 VSIM_PLUSARGS='+OPQ_NATIVE_TRACE_OWNERSHIP +OPQ_NATIVE_TRACE_FT_DROP +OPQ_TRACE_AFTER_PS=0' bash packet_scheduler/tb/scripts/run_uvm.sh opq_error_ftable_overflow_test`
    now closes with:
    - `UVM_ERROR : 0`
    - reduced-depth frame-table ledger
      `wr_hdr=32 rd_hdr=20 drop_hdr=12 wr_shd=8191 rd_shd=5120 drop_shd=3071 wr_hit=44 rd_hit=28 drop_hit=16`
    - lane0 and lane1 both ending
      `expected=22 accepted=14 dropped=8 delivered=14 unexplained=0`
    - `core_principles first_break=clean ft_ownership= ok hit_conservation= ok accepted_delivery= ok drained= ok`
  - the same closure depended on carrying per-frame lane summaries through the
    reduced-depth overwrite path so the presenter can surface overwrite drops
    as lane-resolved post-drop deltas instead of leaving drained hits
    unexplained
- Commit:
  - `89de4bf` `Fix OPQ reduced-depth overwrite closure and refresh DV docs`

### BUG-025-R: Active-lane retirement still depends on a level EOP flag that the parser can clear too early
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_cross_drr_bursty_random_test DUT_IMPL=native_sv`
    on `2026-04-20`
- Symptom:
  - the larger bursty DRR constrained-random probe still exits with
    `expected=852 actual=622 missing=368 ghost=138`
  - the per-lane ledger ends with lane0
    `accepted=828 dropped=3220 delivered=460 unexplained=368`
  - a traced rerun at the failing window reaches allocator idle with:
    - `frame_lane_active=0x3`
    - `pending=0x0`
    - `ticket_wptr=0x3f/0x60`
    - `ticket_rptr=0x3f/0x60`
    - `ingress_busy=0x0`
    while the active frame still has not retired
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` uses live
    `ingress_alert_eop_i` as a level-sensitive prerequisite for
    `all_lanes_alert_eop` and `all_active_lanes_tail_ready`
  - `ordered_priority_queue_monolithic_ingress_parser.sv` clears
    `alert_eop` as soon as the next ticket is issued
  - under bursty no-restart DRR traffic, a completed active lane can therefore
    lose its tail-ready state before the allocator observes the flush point,
    leaving `frame_lane_active` stuck high and stranding accepted traffic
- Fix status:
  - state:
    - fixed on the current patchset; the exact reduced boundary and the
      refreshed constrained-random seed sweep now both close with
      `unexplained=0`
  - mechanism:
    - the ingress parser already exports serial-tagged `tail_bypass_valid`,
      `tail_bypass_drop`, `tail_bypass_serial`, and `tail_bypass_ts`
    - the page allocator no longer depends on transient
      `alert_eop` / `all_lanes_alert_eop` levels to retire active lanes
    - active-frame retirement now uses the latched `frame_lane_tail_seen`
      state plus the serial-tagged tail-bypass high-water mark
    - current-SOP classification now also consults an exact per-serial
      tail-status shadow, so a later tail can prove readiness without erasing
      the drop status of the earlier packet currently being classified
    - if a current SOP is already known dropped, the allocator now advances and
      returns ticket credit instead of opening a header-only frame
  - before_fix_outcome:
    - the original hazard could strand `frame_lane_active` after the parser had
      already cleared its level EOP flag, and later-tail aliasing could still
      let an already-dropped SOP seed a synthetic header-only frame
  - after_fix_outcome:
    - `opq_cross_drr_bursty_frame3_repro_test` rerun on `2026-04-21` closes with
      `expected=714 actual=714 missing=0 ghost=0`
    - the same rerun ends with:
      - lane0 `accepted=690 dropped=828 delivered=690 unexplained=0`
      - lane1 `accepted=24 dropped=108 delivered=24 unexplained=0`
    - the refreshed `opq_cross_drr_bursty_random_test` seed sweep on
      `2026-04-21` is also green on seeds `1` through `8`
    - representative refreshed endpoints on the current patchset are:
      - seed 1: `expected=990 actual=990 missing=0 ghost=0`
      - seeds 2 through 8: `expected=1864 actual=1864 missing=0 ghost=0`
    - every refreshed seed closes with per-lane `unexplained=0`
    - the allocator-side exact-drop repair also removes the stale extra-header
      ownership leak in the reduced-depth pressure witness:
      - before: `wr_hdr=4 rd_hdr=3 drop_hdr=0`
      - after: `wr_hdr=2 rd_hdr=2 drop_hdr=0`
  - potential_hazard:
    - this looks like a permanent architectural fix for the alert-EOP race and
      later-tail drop-status aliasing
    - residual risk is now normal regression drift rather than an active known
      failure family; keep the bursty DRR screen in the promoted random
      matrix, but the specific `BUG-025-R` retirement hole is not reproduced on
      the refreshed seed set
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - the original reduced deterministic bracket is now green on the current
    tree:
    - `opq_cross_drr_bursty_frame2_boundary_test` still passes with
      `expected=298 actual=298 missing=0 ghost=0`
    - `opq_cross_drr_bursty_frame3_repro_test` now reruns green with
      `expected=714 actual=714 missing=0 ghost=0`
  - refreshed constrained-random reruns on the current `2026-04-21` patchset
    also stay green on seeds 1 through 8:
    - each seed closes with `UVM_ERROR : 0`, `missing=0 ghost=0`, and
      per-lane `unexplained=0`
    - current refreshed endpoints include:
      - seed 1: `expected=990 actual=990 missing=0 ghost=0`
      - seed 2: `expected=1864 actual=1864 missing=0 ghost=0`
      - seed 8: `expected=1864 actual=1864 missing=0 ghost=0`
  - no active `BUG-025-R` failure boundary is currently reproduced on the
    named deterministic bracket or the refreshed constrained-random seed sweep
- Commit:
  - a813795

### BUG-028-H: Lane hit ledger retired delivered beats against parser timestamps instead of canonical egress timestamps
- First seen in:
  - refreshed `2026-04-21` supplemental rerun
    `TEST=opq_cross_random_ready_overflow_step2_boundary_test`
    with `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256`
  - later confirmed by the same residual pattern in
    `opq_cross_masked_drop_exact_102_117_repro_test` and
    `opq_cross_mixed_bucket_random_soak_test` on the same `4-lane/128`
    preset
- Symptom:
  - the 4-lane/128 overflow-step2 rerun kept the frame-table ledger perfectly
    closed at
    `wr_hdr/shd/hit=7/19/1607`, `rd_hdr/shd/hit=7/19/1607`,
    `drop_hdr/shd/hit=0/0/0`, but still ended with
    `accepted=1607 delivered=941 unexplained=666` and
    `core_principles first_break=drain_not_closed`
  - the failing unexplained residue clustered on delivered lane0/lane1 traffic
    even though the same tests stayed hit-integrity clean or frame-table clean,
    which pointed away from a datapath loss and toward the lane-accounting
    harness
- Root cause:
  - `opq_scoreboard.sv` stored only one timestamp per accepted hit in
    `lane_accounting_hits`, and that timestamp followed the parser / exact-drop
    bookkeeping convention rather than the canonical ingress/egress delivery
    timestamp
  - actual egress retirement then tried to delete delivered hits from the same
    queue using the canonical egress timestamp, so delivered beats could remain
    stranded in the lane ledger even when the packet contract and frame-table
    ownership were both correct
- Fix status:
  - state:
    - fixed on the refreshed `2026-04-21` 4-lane/128 reruns
  - mechanism:
    - `opq_scoreboard.sv` now carries both `hit_ts` and
      `accounting_hit_ts` per accepted hit
    - actual egress retirement uses canonical `hit_ts`
    - exact-drop and parser-side bookkeeping keep using
      `accounting_hit_ts`
    - the earlier unique `ts + word` fallback is kept only as a secondary
      safeguard when merged egress serials differ
  - before_fix_outcome:
    - the first failing 4-lane/128 overflow-step2 rerun on `2026-04-21`
      ended with:
      - `accepted=1607 delivered=941 unexplained=666`
      - `core_principles first_break=drain_not_closed`
      - `UVM_ERROR : 6`
    - the 4-lane/128 masked-drop exact rerun was hit-integrity clean but still
      reported residual lane ledger drift:
      - lane1 `accepted=158 delivered=148 unexplained=10`
      - lane3 `accepted=16 delivered=6 unexplained=10`
    - the 4-lane/128 mixed-bucket random soak was also hit-integrity clean but
      still ended with lane ledger residue:
      - lane0 `accepted=8801 delivered=8779 unexplained=22`
      - lane1 `accepted=4950 delivered=4910 unexplained=40`
      - lane2 `accepted=460 delivered=438 unexplained=22`
      - lane3 `accepted=336 delivered=292 unexplained=44`
  - after_fix_outcome:
    - the refreshed `opq_cross_random_ready_overflow_step2_boundary_test`
      rerun on `2026-04-21` now closes with:
      - `wr_hdr/shd/hit=7/19/1607`
      - `rd_hdr/shd/hit=7/19/1607`
      - `ft_drop_hdr/shd/hit=0/0/0`
      - aggregate `accepted=1607 delivered=1607 unexplained=0`
      - `core_principles first_break=clean`
      - `UVM_ERROR : 0`
    - the refreshed `opq_cross_masked_drop_exact_102_117_repro_test` rerun on
      the same preset now exits with
      `expected=752 actual=752 missing=0 ghost=0` and per-lane
      `accepted=delivered unexplained=0`
    - the refreshed `opq_cross_mixed_bucket_random_soak_test` rerun on the
      same preset now exits with
      `expected=14547 actual=14547 missing=0 ghost=0` and per-lane
      `accepted=delivered unexplained=0`
  - potential_hazard:
    - this looks like a permanent harness fix rather than a provisional
      testcase tweak, because the scoreboard now models both timestamp domains
      explicitly instead of overloading one field for two contracts
    - the only residual limitation is the secondary merged-serial fallback:
      it still assumes `ts + word` uniqueness when the packet serial itself is
      not canonical, but the main delivery path no longer depends on that
      fallback
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - this repaired the first 4-lane/128 rerun failure after the RTL bug family
    was already fixed, so the supplemental wider-lane screens are again usable
    for closure instead of falsely reopening clean datapath cases
- Commit:
  - a813795

### BUG-026-R: Live-head overwrite protection suppresses unread-tail drop accounting
- First seen in:
  - `packet_scheduler/tb/uvm`
    `TEST=opq_cross_random_ready_overflow_seconds_soak_test DUT_IMPL=native_sv`
    on `2026-04-20`
- Symptom:
  - the fresh default-build random-ready overflow rerun now fails at
    `overflow_step_0`
  - the first failing ledger reports:
    - `ft_wr_shd accounting mismatch wr=5 rd=7 drop=0`
    - `ft_wr_hit accounting mismatch wr=540 rd=545 drop=0`
    - lane1
      `expected=91392 accepted=174 dropped=91218 delivered=0 unexplained=174`
  - the same log also fires accepted-egress `opq_hit3_contract` monotonicity
    errors at the first overflow window
- Root cause:
  - `ordered_priority_queue_monolithic_basic_presenter.sv`
    `proc_overwrite_drop_plan` blocks the entire overlap-drop scan whenever
    `overwrite_head_accepted_or_accepting` is true
  - that protects the live head itself, but it also prevents the presenter
    from accounting overlapped unread tail residents behind that live head
  - the same presenter was also still treating `page_ram.q` as if it were
    stable whenever the launch pipe paused; in reality the synchronous RAM
    rereads `page_ram_rptr` every cycle, so an unread resident header word
    could roll from `word2` to `word3` before it was loaded, corrupting the
    emitted five-word frame header under early or repeated backpressure
  - under random-ready overflow backpressure, accepted tail subheaders can
    therefore be overwritten in page RAM without corresponding
    `ft_drop_*` accounting, and the same backpressure windows could also skip
    an unread resident header word, leaving `ft_wr < ft_rd + ft_drop` and
    tripping accepted-egress `opq_hit3_contract` monotonicity checks
- Fix status:
  - state:
    - fixed on the refreshed `2026-04-21` verification set
  - mechanism:
    - `ordered_priority_queue_monolithic_basic_presenter.sv` now retires a
      resident frame only after the final egress beat is actually accepted and
      preserves unread resident `page_ram.q` contents in a skid path on every
      non-advance cycle, not only at the startup head
    - the allocator-side exact per-serial tail-drop shadow prevents
      already-dropped SOPs from reopening synthetic zero-payload frames while
      the presenter is protecting the live head
    - localized formal assertions now pin both hazards mathematically:
      stalled resident unread words must become skid-visible on the next cycle,
      and the first visible beat of a packet must remain SOP
    - together, those changes delay internal ownership updates until data is
      consumed and remove the resident-header hole that used to poison the
      default-build overflow witness
  - before_fix_outcome:
    - the default-build overflow failure could emit a malformed five-word
      header at the first overflow window:
      `header -> word1 -> word3 -> word3 -> word4`
    - that exact skipped-`word2` trace fired
      `opq_hit3_contract` frame timestamp / pkg-count monotonicity errors in
      `opq_cross_random_ready_overflow_step2_boundary_test`
    - the reduced-depth `12x16` must-drop witness also previously ended with a
      credit-restore timeout after `10000000000`, flat `ft_drop_*`, and a bad
      frame-table ledger `wr_hdr=4 rd_hdr=3 drop_hdr=0`
  - after_fix_outcome:
    - the focused `2026-04-21` trace at the original bad window now emits the
      correct resident header sequence:
      `header -> word1 -> word2(0x0050000005) -> word3 -> word4`
    - the full `opq_cross_random_ready_overflow_step2_boundary_test` rerun on
      `2026-04-21` now exits with `UVM_ERROR : 0` and final:
      - `wr_hdr/shd/hit=6/11/1176`
      - `rd_hdr/shd/hit=6/11/1176`
      - `ft_drop_hdr/shd/hit=0/0/0`
      - aggregate `accepted=1176 delivered=1176 unexplained=0`
      - `core_principles first_break=clean ft_ownership= ok hit_conservation= ok accepted_delivery= ok drained= ok`
    - the refreshed reduced-depth `opq_cross_bp_mustdrop_witness_test`
      `12x16` rerun on `2026-04-21` now re-establishes the overwrite-local
      proof point end to end:
      - no-drop pre-phase keeps `ft_drop_delta hdr/shd/hit=0/0/0`
      - pressure phase advances `ft_drop_delta hdr/shd/hit=10/80/2400`
      - final frame-table ledger closes at
        `wr_hdr/shd/hit=13/224/3135`,
        `rd_hdr/shd/hit=3/144/735`,
        `drop_hdr/shd/hit=10/80/2400`
      - aggregate `accepted=735 delivered=735 unexplained=0`
      - `core_principles first_break=clean ft_ownership= ok hit_conservation= ok accepted_delivery= ok drained= ok`
      - `UVM_ERROR : 0`
  - potential_hazard:
    - the no-hole / consumed-before-retire part looks like a permanent fix for
      the observed live-head ownership hazard
    - the remaining limitation is coverage-shaped rather than bug-shaped: the
      current green overwrite-local proof point is still a reduced-depth
      elaboration, so a default-build must-drop hybrid is still optional future
      coverage work rather than a blocker for this bug
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - the original default-build failure is no longer reproduced by the named
    two-step boundary testcase `opq_cross_random_ready_overflow_step2_boundary_test`
    on the refreshed `2026-04-21` rerun
  - that testcase keeps the first two overflow checkpoints clean:
    - `overflow_step_0`: `wr_shd=3 rd_shd=3 drop_shd=0`,
      `wr_hit=540 rd_hit=540 drop_hit=0`, aggregate `unexplained=0`
    - `overflow_step_1`: `wr_shd=11 rd_shd=11 drop_shd=0`,
      `wr_hit=1176 rd_hit=1176 drop_hit=0`, aggregate `unexplained=0`
    - both checkpoints end with
      `core_principles first_break=clean ft_ownership= ok hit_conservation= ok accepted_delivery= ok drained= ok`
  - the named testcase also exits green with final
    `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=6/11/1176`,
    `rd_hdr/shd/hit=6/11/1176`, and aggregate
    `accepted=1176 delivered=1176 unexplained=0`
  - the new default-build supplemental signoff run
    `opq_cross_bp_predrop_boundary_test` now closes the legal pre-drop half of
    the contract on `2026-04-20`:
    - final `ft_drop_hdr/shd/hit=0/0/0`
    - aggregate `accepted=13260 dropped=66612 delivered=13260 unexplained=0`
    - `core_principles first_break=clean ft_ownership= ok hit_conservation= ok accepted_delivery= ok drained= ok`
  - the default-build `opq_cross_random_ready_overflow_seconds_soak_test` is
    also back to a shape-check green rerun on the current tree:
    - final `ft_drop_hdr/shd/hit=0/0/0`
    - `wr_hdr/shd/hit=29/68/5545`
    - `rd_hdr/shd/hit=29/68/5545`
    - aggregate `accepted=5545 delivered=5545 unexplained=0`
    - `core_principles first_break=clean`
  - the reduced-depth `opq_error_ftable_overflow_test` shape-check screen is
    also green again on the current tree, with final frame-table ledger
    `wr_hdr=32 rd_hdr=20 drop_hdr=12`, `wr_shd=8191 rd_shd=5120 drop_shd=3071`,
    `wr_hit=44 rd_hit=28 drop_hit=16`, aggregate
    `accepted=28 delivered=28 unexplained=0`, and `UVM_ERROR : 0`
  - the explicit reduced-depth overwrite-local proof point is now restored by
    `opq_cross_bp_mustdrop_witness_test` at the named `12x16` profile:
    - no-drop pre-phase `ft_drop_delta hdr/shd/hit=0/0/0`
    - pressure phase `ft_drop_delta hdr/shd/hit=10/80/2400`
    - final aggregate `accepted=735 delivered=735 unexplained=0`
    - final `core_principles first_break=clean`
    - `UVM_ERROR : 0`
  - this bug can therefore be closed on the current tree: the default-build
    legal-overflow screens remain useful shape-checks, and the dedicated
    reduced-depth overwrite-local witness is green again
- Commit:
  - a813795

## 2026-04-21

### BUG-027-R: Masked zero-hit subheader recovery kept `tail_bypass_drop` asserted through the trailer
- First seen in:
  - `packet_scheduler/tb/scripts/formal_ingress.sh` fallback-stress rerun on
    `2026-04-21`
  - localized failure anchor:
    `opq_formal_like_ingress_recovery_stress_test`
- Symptom:
  - the new localized ingress assertion fired on both lanes at `154 ns`:
    `OPQ_NATIVE_INGRESS_FORMAL trailer-bypass drop flag did not match the parser mask state`
  - the failing trace was a masked subheader followed by a legal zero-hit
    recovery subheader and then a trailer; the parser emitted a legal zero-hit
    ticket, but the trailer still advertised `tail_bypass_drop=1`
  - the end-to-end scoreboard stayed green, which is exactly why this was a
    useful localized assume/assert/cover catch instead of a broad scoreboard
    hunt
- Root cause:
  - in
    `ordered_priority_queue_monolithic_ingress_parser.sv`
    `INGRESS_PARSER_MASK_PKT`, the legal zero-hit subheader branch wrote the
    recovery ticket and cleared `alert_eop`, but it never returned the parser
    to the normal body/idle state
  - the parser therefore stayed in `MASK_PKT` until the trailer beat, so the
    trailer-side bypass metadata continued to report the old mask state even
    after the legal zero-hit recovery subheader had been accepted
- Fix status:
  - state:
    - fixed on the refreshed `2026-04-21` ingress formal and directed
      recovery reruns
  - mechanism:
    - the legal zero-hit recovery branch inside `INGRESS_PARSER_MASK_PKT` now
      returns to `INGRESS_PARSER_IDLE`, which is the parser's normal in-frame
      body state after a zero-hit subheader
    - localized ingress formal checks now assert and cover the trailer-bypass
      pulse/drop contract directly, and allocator-side localized assertions now
      pin the live/shadow tail-bypass consumption path used by `BUG-025-R`
  - before_fix_outcome:
    - `formal_ingress.sh` on `2026-04-21` initially ended
      `compile=pass elab=pass formal=fallback_stress_fail`
    - the only failing fallback testcase was
      `opq_formal_like_ingress_recovery_stress_test`, and the concrete
      failure was the new trailer-bypass drop assertion at `154 ns`
  - after_fix_outcome:
    - the refreshed `formal_ingress.sh` rerun on `2026-04-21` now closes with
      `compile=pass elab=pass formal=fallback_stress_pass`
    - the default ingress fallback stress suite is green:
      `opq_basic_smoke_test`,
      `opq_formal_like_ingress_recovery_stress_test`,
      `opq_error_hit_mask_recovery_test`
    - the direct native-SV rerun
      `TEST=opq_error_subheader_mask_recovery_test DUT_IMPL=native_sv`
      is also green on `2026-04-21` with
      `expected=2 actual=2 missing=0 ghost=0` and `UVM_ERROR : 0`
  - potential_hazard:
    - this looks like a permanent local fix: the bug was a missing state
      transition in the zero-hit recovery branch, and the repaired contract is
      now guarded by localized formal assertions plus the named recovery test
    - the only remaining limitation is tooling-shaped rather than RTL-shaped:
      the current host still uses the simulation-backed ingress fallback flow
      instead of a live `qverify` proof engine
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - this closure strengthens the typed ingress error contract the user asked
    for: subheader masking is now local to the bad subheader and its associated
    hits, and a later legal zero-hit subheader no longer inherits the old drop
    state through the trailer
  - the refreshed ingress fallback suite on `2026-04-21` is again usable as a
    fast local checker for that contract instead of a known failing probe
- Commit:
  - a813795

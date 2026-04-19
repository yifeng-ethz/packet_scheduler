# BUG_HISTORY.md - packet_scheduler OPQ DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

## Index

| bug_id | class | status | first seen | commit | summary |
|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-native-sv-empty-frame-drain-replays-trailer-only-packets) | R | fixed | `opq_basic_feb_packet_contract_test` | `37c4b2a` | Native-SV empty-frame drain replayed trailer-only packets after the first legal frame. |
| [BUG-002-R](#bug-002-r-native-sv-4-lane-feb-path-corrupted-middle-lane-hit-placement) | R | fixed | `opq_basic_feb_packet_contract_test` @ `OPQ_N_LANE=4` | `37c4b2a` | Native-SV 4-lane allocator used the wrong block-start prefix and misplaced middle-lane hits. |
| [BUG-003-R](#bug-003-r-native-sv-csr-plane-returned-zeros-and-hid-live-credits) | R | fixed | `opq_basic_feb_packet_contract_test` | `6b9ed41` | Native-SV wrapper CSR plane was still a stub and returned zero readback. |
| [BUG-004-H](#bug-004-h-cross-bucket-csr-proof-used-non-feb-ingress-framing) | H | fixed | `opq_cross_bp_credit_test`, `opq_cross_drr_allowance_test` | `6b9ed41` | Cross-bucket CSR proof sequences drove split packets instead of FEB whole-frame traffic. |
| [BUG-005-R](#bug-005-r-header-error-mask-path-corrupts-the-next-legal-frame-timestamp) | R | fixed | `opq_error_header_mask_recovery_test` | `pending` | Header-error mask recovery no longer leaks stale timestamp context into the next legal frame after the allocator was re-seeded from the captured ingress header timestamp base. |
| [BUG-006-H](#bug-006-h-native-sv-no-restart-signoff-accounting-broke-continuous-frame-closure) | H | fixed | `opq_bucket_frame_native_sv_test`, `opq_all_buckets_frame_native_sv_test` | `b799f94` | No-restart signoff reused frame identity and miscounted malformed subheaders. |
| [BUG-007-R](#bug-007-r-swb-4-lane-sparse-frame-cadence-drops-later-hits) | R | open | `opq_prof_missing_empty_frame_test` @ `OPQ_N_LANE=4` | `pending` | Unmasked quiescent lanes can block later active-lane traffic when empty-frame cadence is absent. |
| [BUG-008-R](#bug-008-r-forced-overwrite-path-still-emits-malformed-accepted-egress-and-no-frame-table-drop-accounting) | R | fixed | `opq_error_ftable_overflow_test` | `41948b1` | Reduced-depth forced overwrite under always-stall corrupted accepted egress and hid frame-table drop events until the native-SV presenter and CSR path were fixed. |
| [BUG-009-R](#bug-009-r-bursty-drr-stall-boundary-path-still-corrupts-egress-ordering-and-lacks-late-drop-identity) | R | fixed | `opq_cross_drr_bursty_random_test` | `pending` | Bursty DRR plus periodic stall no longer loses late active-lane traffic after the allocator holds merged-frame progress until every active busy lane has surfaced its current ticket. |
| [BUG-010-R](#bug-010-r-header-word-recovery-path-still-corrupts-the-next-legal-frame) | R | fixed | `opq_error_header_word_mask_recovery_test` | `pending` | Header-word error injection no longer corrupts the next legal timestamp base after the recovery frame seeds from the captured ingress header timestamp base. |
| [BUG-011-R](#bug-011-r-chained-malformed-subheader-recovery-is-not-composable-in-mixed-bucket-soak) | R | open | `opq_cross_mixed_bucket_random_soak_test` | `pending` | Isolated malformed-subheader recovery is green, but chained mixed-soak recovery still breaks no-restart framing. |
| [BUG-012-H](#bug-012-h-edge-medium-ready-profile-testcase-was-wired-as-always-ready) | H | fixed | promoted EDGE isolated rerun on `2026-04-17` | `cbb05e0` | The supposed medium-backpressure testcase never applied stalls and gave false evidence. |
| [BUG-013-H](#bug-013-h-mixed-bucket-random-soak-was-reported-as-directed-and-omitted-txn-growth-traceability) | H | fixed | regenerated native-SV report on `2026-04-17` | `cbb05e0` | The promoted mixed-soak testcase was misclassified as directed and hid required random-case reporting. |
| [BUG-014-R](#bug-014-r-formal-like-egress-flush-under-backpressure-violates-the-avalon-st-hold-contract) | R | fixed | `formal_egress.sh` targeted stress probe on `2026-04-18` | `dd6fe75` | Formal-like egress flush-under-backpressure no longer breaks the live Avalon-ST hold contract after the basic presenter preserves synchronous page-RAM return data across held `ready`. |
| [BUG-015-H](#bug-015-h-oss-ingress-sby-harness-still-false-fails-on-phase-sensitive-write-and-drop-checks) | H | fixed | `formal_ingress.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `1048b6c` | The ingress OSS proof now passes after the harness stopped consuming reset-warmup debug pulses and switched from phase-ambiguous credit-bus checks to pulse-level write/drop contracts. |
| [BUG-016-H](#bug-016-h-oss-basic-presenter-sby-lowering-hits-a-logic-loop-in-the-overwrite-scan-path) | H | fixed | `formal_egress.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `f8448ac` | The OSS basic-presenter proof no longer dies in SMT2 lowering; the live Avalon-ST hold-under-backpressure slice now passes on the OSS subset. |
| [BUG-017-H](#bug-017-h-oss-mover-sby-harness-now-reaches-proof-but-still-fails-on-arbiter-shape-invariants) | H | fixed | `formal_mover.sh` with `FORMAL_BACKEND=sby` on `2026-04-18` | `de65125` | The live OSS mover proof now passes on the current block-path subset after the proof-clean arbiter view was exported and constrained. |
| [BUG-018-H](#bug-018-h-extended-mixed-bucket-seconds-soak-exposes-chained-masked-drop-accounting-underrun) | H | open | `opq_cross_mixed_bucket_seconds_soak_test` on `2026-04-18` | `pending` | The old seconds-soak accounting underrun is fixed, but the full stretched rerun still trips `opq_hit3_contract`, first around mixed step `191` and later in repeated PROF-heavy windows. |
| [BUG-019-R](#bug-019-r-merged-frame-header-counts-incremented-per-accepted-lane-instead-of-per-emitted-subheader) | R | fixed | `opq_basic_smoke_test` on `2026-04-18` | `pending` | The native-SV page allocator was double-counting merged subheaders in the frame header, so the advertised subheader count could exceed the emitted K237 count under multi-lane merge. |

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
  - pending

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
  - open, but the evidence points to a contract mismatch around sparse per-lane frame cadence
  - OPQ already has an explicit ingress lane-mask CSR; this bug therefore applies to the unmasked case (`lane_mask=0`), not to intentionally quiescent lanes that are masked off by configuration
  - the monolithic 4-lane page allocator advances only when every lane has a stable pending ticket or an end-of-frame condition, so lanes that simply stop producing frames can hold back later active-lane traffic
- Blocking reason:
  - 4-lane native-SV remains an explicit non-claim in the active report until the sparse-frame cadence contract is fixed or the intended lane-mask/empty-frame normalization policy is frozen
- Candidate fixes:
  - configure the existing OPQ lane-mask CSR whenever a lane is intentionally quiescent
  - add an SWB/FEB ingress normalizer that synthesizes empty frames for idle lanes when masking is not available or not desirable
  - or upgrade OPQ fetch/allocation so quiescent lanes do not block later active-lane frames
- Fix status:
  - open
- Commit:
  - pending

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
  - `opq_error_ftable_overflow_test` now passes as promoted isolated native-SV evidence at `OPQ_PAGE_RAM_DEPTH=512`, with non-zero `FT_DROP_*` counters and no malformed accepted egress
  - the testcase remains isolated-only in signoff because that reduced-depth overflow point requires separate elaboration and is not part of the fixed default-build no-restart baseline
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
  - `opq_cross_drr_bursty_repro_test` now ends with `expected=1864 actual=1864 missing=0 ghost=0`
  - the repaired focused repro also closes the per-lane hit ledger:
    - lane0 `accepted=1840 dropped=2208 pre_drop=0 post_drop=2208 delivered=1840 unexplained=0`
    - lane1 `accepted=24 dropped=328 pre_drop=0 post_drop=328 delivered=24 unexplained=0`
  - the full constrained-random bursty testcase still needs a refresh run before promotion, but the invariant family that caused silent hit loss is now closed on the directed reproducer
- Commit:
  - pending

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
  - pending

### BUG-011-R: Chained malformed-subheader recovery is not composable in mixed-bucket soak
- First seen in:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_mixed_bucket_random_soak_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - the isolated `opq_error_subheader_mask_recovery_test` remains green, but when the same malformed-subheader recovery is chained behind prior mixed-bucket traffic it can emit malformed egress framing and trip `opq_hit3_contract_sva`
  - the first mixed-soak failure showed `Egress expected hit payload, got datak=0x1` followed by `sub-header arrived before the previous sub-header drained` and a later credit-restore timeout on the chained recovery step
- Root cause status:
  - open
  - the native-SV malformed-subheader recovery path is not fully composable after prior no-restart traffic; the mixed-bucket soak therefore excludes that step today
- Blocking reason:
  - the malformed-subheader recovery step stays out of the mixed-soak pool until chained no-restart recovery is repaired; otherwise the soak would claim stable long-run coverage with a known broken recovery transition
- Candidate fixes:
  - root-cause the lingering parser/presenter state that survives the malformed-subheader recovery path across chained no-restart traffic
  - add a focused chained-recovery testcase once the recovery state machine is repaired, then return that step to the mixed-soak pool
- Fix status:
  - open
- Commit:
  - pending

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
  - open
  - isolated lane-mask and lane-mask-recovery cases are green, so the
    remaining failure is specific to longer no-restart chaining rather
    than the isolated drop path itself
  - the old scoreboard/accounting bug is fixed, but the earlier extended
    mixed-soak screen is still exposing a real hit/sub-header contract
    break under longer chained traffic
- Blocking reason:
  - `opq_cross_mixed_bucket_seconds_soak_test` is intentionally kept
    probe-only because the full stretched rerun still produces real
    `opq_hit3_contract` failures on the fixed presenter state; this is
    no longer just a short-run uncertainty
- Candidate fixes:
  - correlate the `opq_hit3_contract` failures against the mixed-step
    schedule and reconstruct the missing sub-header/hit sequence in the
    egress contract monitor
  - once the hit/sub-header ordering bug is repaired, rerun the same
    stretched mixed-soak screen to confirm that the old scoreboard
    underrun stays gone and no new contract failures remain
- Fix status:
  - open
- Commit:
  - pending

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
  - pending

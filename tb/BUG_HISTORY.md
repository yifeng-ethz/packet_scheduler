# OPQ Bug History

## 2026-04-17 Header-word recovery path still corrupts the next legal frame

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_error_header_word_mask_recovery_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - a malformed header-word frame is counted twice by the lane counters and the following legal recovery frame emerges with the right payload words but the wrong timestamp base
  - observed isolated failure is `expected=4 actual=4 missing=4 ghost=4`, with the recovery hits reconstructed at `ts=0x10` instead of `ts=0x1010`
- Root cause status:
  - open
  - the native-SV header-error handling path still lets stale frame context leak into the next legal frame, even when the malformed stimulus is injected at header-word granularity instead of by truncating the whole packet
- Candidate fixes:
  - complete the native-SV header-word mask recovery reinitialization so the next legal preamble rebuilds timestamp/ticket context from a clean parser state
  - add a parser-boundary assertion for header-word recovery so stale frame context is caught before egress
- Fix status:
  - open
- Fix commit:
  - pending

## 2026-04-17 Chained malformed-subheader recovery is not composable in mixed-bucket soak

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_mixed_bucket_random_soak_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - the isolated `opq_error_subheader_mask_recovery_test` remains green, but when the same malformed-subheader recovery is chained behind prior mixed-bucket traffic it can emit malformed egress framing and trip `opq_hit3_contract_sva`
  - the first mixed-soak failure showed `Egress expected hit payload, got datak=0x1` followed by `sub-header arrived before the previous sub-header drained` and a later credit-restore timeout on the chained recovery step
- Root cause status:
  - open
  - the native-SV malformed-subheader recovery path is not fully composable after prior no-restart traffic; the mixed-bucket soak now excludes that step until the chained recovery contract is fixed
- Candidate fixes:
  - root-cause the lingering parser/presenter state that survives the malformed-subheader recovery path across chained no-restart traffic
  - add a focused chained-recovery testcase once the recovery state machine is repaired, then return that step to the mixed-soak pool
- Fix status:
  - open
- Fix commit:
  - pending

## 2026-04-17 Native-SV no-restart signoff accounting breaks continuous-frame closure

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_bucket_frame_native_sv_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
  - `packet_scheduler/tb/uvm` `TEST=opq_all_buckets_frame_native_sv_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - the generated `bucket_frame` / `all_buckets_frame` signoff runs now exist and both fail under native SV
  - the original failing evidence showed severe end-of-run mismatch:
    - `bucket_frame`: `expected=3770 actual=4 missing=3766 ghost=0`
    - `all_buckets_frame`: `expected=3788 actual=4 missing=3784 ghost=0`
  - after tightening the harness so each composed case waits for full credit restore, the no-restart runner now times out case-by-case on the restore check itself, for example:
    - `basic_seq_4336314000_credit_restore timed out waiting for lane/ticket credit restore`
    - `soak_seq_credit_restore timed out waiting for lane/ticket credit restore`
    - `whole_frame_seq_credit_restore timed out waiting for lane/ticket credit restore`
- Root cause status:
  - fixed
  - the first failure was a harness identity bug, not a real no-reset drain failure: composed no-restart cases restarted `pkg_cnt` and frame timestamp context from zero, while the native page allocator uses the SOP serial as the frame identity. Reusing those identities across one continuous frame caused later tickets to alias earlier frames and left the signoff runner appearing to stall on credit restore.
  - after the serial/timestamp carry fix, the last residual `bucket_frame` failure was a scoreboard accounting bug: the harness still counted malformed subheaders as accepted lane traffic even though the native ingress parser masks a subheader with `error_bits[1]` and does not issue a ticket write for it.
  - carrying continuous-frame `pkg_cnt` / timestamp identity through the composed sequences and counting only parser-accepted subheaders/hits in the scoreboard closes both mandatory no-restart baselines.
- Fix status:
  - fixed
- Fix commit:
  - `b799f94` `Fix OPQ native-SV continuous-frame signoff accounting`

## 2026-04-17 SWB 4-lane sparse-frame cadence drops later hits

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_prof_missing_empty_frame_test OPQ_N_LANE=4`
  - consistent with `packet_scheduler/tb_int/uvm` `tb_int_longrun_sanity_test +TB_INT_LONGRUN_CASE_ID=1`
- Symptom:
  - standalone 4-lane OPQ passes equal-cadence FEB whole-frame traffic but drops later hits when some lanes stop emitting frames instead of sending empty-frame cadence
  - reproducer result: `expected=6 actual=4 missing=2 ghost=0`
  - integrated clue: stage-D per-lane frame counts are highly uneven (`57/128/57/73`) and OPQ remains stuck near the first frame (`ft_wr_hdr=1 ft_wr_shd=0 ft_wr_hit=0 stage_e=0` in the earlier long-run snapshot)
- Root cause status:
  - open, but the evidence points to a contract mismatch around sparse per-lane frame cadence
  - OPQ already has an explicit ingress lane-mask CSR; verified in standalone 4-lane DV with `opq_error_lane_mask_test`
  - this bug therefore applies to the unmasked case (`lane_mask=0`), not to intentionally quiescent lanes that are masked off by configuration
  - the monolithic 4-lane page allocator advances only when every lane has a stable pending ticket or an end-of-frame condition, so lanes that simply stop producing frames can hold back later active-lane traffic
  - this is consistent with the standalone reproducer, where unequal lane frame counts without empty-frame padding lose real lane-1 hits
- Candidate fixes:
  - configure the existing OPQ lane-mask CSR whenever a lane is intentionally quiescent
  - add an SWB/FEB ingress normalizer that synthesizes empty frames for idle lanes when masking is not available or not desirable
  - or upgrade OPQ fetch/allocation so quiescent lanes do not block later active-lane frames
- Fix status:
  - open
- Fix commit:
  - pending


## 2026-04-17 Native SV empty-frame drain replays trailer-only packets

- First seen:
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
- Fix commit:
  - `37c4b2a` `Fix native OPQ FEB reference path`

## 2026-04-17 Native SV 4-lane FEB path corrupts middle-lane hit placement

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_feb_packet_contract_test OPQ_N_LANE=4 DUT_IMPL=native_sv`
  - VHDL reference under the same FEB-contract sequence produced `missing=0 ghost=0`
- Symptom:
  - native 4-lane egress emitted lane0 hits, then lane3 hits, then four zero ghosts; lane1 and lane2 hits were missing
  - before the datapath bug was visible, the native 4-lane UVM harness also hard-failed because `tb_top` still blocked `OPQ_USE_NATIVE_SV` at 4 lanes and instantiated the VHDL-only `ordered_priority_queue_dut4`
- Root cause:
  - `ordered_priority_queue_monolithic_page_allocator.sv` computed `page_allocator_if_alloc_blk_start[i]` from only `ticket[i-1].block_length`, which is sufficient for 2 lanes but wrong for 4 lanes; the VHDL reference uses a cumulative prefix offset across accepted prior lanes
  - the native SV wrapper/harness was still 2-lane hard-coded, so the 4-lane FEB-contract testcase could not reach the datapath until the wrapper and `tb_top` were extended
- Fix status:
  - fixed
- Fix commit:
  - `37c4b2a` `Fix native OPQ FEB reference path`

## 2026-04-17 Native SV CSR plane returned zeros and hid live credits

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_basic_feb_packet_contract_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - native SV datapath matched the VHDL FEB reference, but the CSR wrapper hard-returned zero data, could not program DRR allowance before traffic, and misreported restored lane/ticket credits at the end of the run
  - the first native bring-up also tripped the CSR SVA because `readdatavalid` did not match the expected Avalon/MM read contract
- Root cause:
  - `ordered_priority_queue_dut_sv.sv` still contained a stub CSR plane instead of the VHDL-visible register map
  - there was no native plumbing for programmable DRR allowance into the block path, no live counter/counter-accumulation logic, and the wrapper exposed raw internal credit state rather than the visible restored credit contract used by the VHDL DUT
- Fix status:
  - fixed
- Fix commit:
  - `6b9ed41` `Fix native SV OPQ CSR plane and CSR proof traffic`

## 2026-04-17 Cross-bucket CSR proof used non-FEB ingress framing

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_bp_credit_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
  - `packet_scheduler/tb/uvm` `TEST=opq_cross_drr_allowance_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - both tests completed with clean UVM scoreboard accounting, but the ingress SVA fired on every frame because the stress sequences asserted fresh `sop` on subheaders instead of using one whole-frame packet with trailer-only `eop`
- Root cause:
  - `opq_soak_virtual_sequence` and `opq_drr_saturation_virtual_sequence` were still driving split-packet synthetic traffic, while the active signoff contract for OPQ debug is FEB whole-frame traffic
- Fix status:
  - fixed
- Fix commit:
  - `6b9ed41` `Fix native SV OPQ CSR plane and CSR proof traffic`

## 2026-04-17 Header-error mask path corrupts the next legal frame timestamp

- First seen:
  - `packet_scheduler/tb/uvm` `TEST=opq_error_header_mask_recovery_test OPQ_N_LANE=2 DUT_IMPL=native_sv`
- Symptom:
  - a malformed preamble/header frame is masked as intended, but the next legal recovery frame emerges with hits at the correct payload words and the wrong timestamp base
  - observed failure is `expected=4 actual=4 missing=4 ghost=4`, with ghost hits reconstructed at `ts=0x10` instead of the legal recovery timestamp `0x1010`
  - the ingress monitor also reports `capture_err=1` on the malformed frame, which is expected for the truncated stimulus and not the root cause of the timestamp corruption
- Root cause status:
  - open
  - the native-SV ingress parser still mishandles the header-error recovery path after `INGRESS_PARSER_MASK_PKT_EXTENDED`
  - reasserting `alert_sop` on the next legal preamble was necessary but not sufficient; the recovery frame still reaches the downstream path with stale timestamp context
- Candidate fixes:
  - complete the `MASK_PKT_EXTENDED` recovery reinitialization so the next legal header rebuilds the full timestamp/ticket context exactly as the idle path does
  - add a focused assertion on header-error recovery so stale frame timestamp state is caught at the parser boundary instead of later at egress
- Fix status:
  - open
- Fix commit:
  - pending

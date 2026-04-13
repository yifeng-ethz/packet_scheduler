# DV_ERROR: ordered_priority_queue (monolithic)

**Bucket:** `X` — error injection, fault response, reset during FSM state, drop-on-full recovery
**Prefix:** `X001..X999`
**Parent plan:** `DV_PLAN.md` (see §4 bucket overview, §5 coverage model, §6 frozen behaviors F1–F10)
**Harness:** `DV_HARNESS.md` (see §3 agents, §4 `opq_txn`, §5 scoreboard drop model, §7 SVA binds)
**RTL source of truth:** `packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`
**Reference config (unless noted):** `N_LANE=4, MODE=MERGING, TRACK_HEADER=true, N_SHD=256, N_HIT=255, LANE_FIFO_DEPTH=1024, TICKET_FIFO_DEPTH=64, HANDLE_FIFO_DEPTH=64, PAGE_RAM_DEPTH=65536, PAGE_RAM_RD_WIDTH=36, DEBUG_LV=1`.
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-13
**Status:** Planning. All 128 cases below are authoritative IDs; implementation must not renumber.

---

## 0. Bucket Charter

This bucket owns every stimulus where the input stream, the backpressure environment, or the reset path **violates** the nominal protocol the DUT was packaged for. Happy-path bring-up lives in `DV_BASIC`, pure boundary sweeps live in `DV_EDGE`, KPI measurements live in `DV_PROF`, and multi-axis soak runs live in `DV_CROSS`.

Every case here must:

1. Name a specific RTL target (FSM state, FIFO full/empty edge, arbiter branch, segment rotation, error bit, mask path).
2. Either assert scoreboard equivalence after recovery, or assert that the DUT reaches a quiescent state within the per-txn watchdog (`opq_config::WATCHDOG_DEFAULT`).
3. Feed at least one `cov_fsm` or `cov_flow` bin from `DV_PLAN.md` §5.2/§5.4, and at least one directed "error-class" bin on the local `cov_err` counter collector (defined in `opq_coverage.sv` — one bin per X1xx..X8xx class plus one bin per recovery type: `REC_CLEAN`, `REC_MASKED`, `REC_RESET`).
4. Where the case exercises a frozen behavior from `DV_PLAN.md` §6, the F-tag is listed.

**Watchdog policy.** Every X-case runs under `opq_base_test::watchdog_cycles = max(100k, 8 × expected_packets × EGRESS_LATENCY_MAX)`. A hang past that is `UVM_FATAL`; no silent pass.

**Recovery rule.** Unless the case caption says otherwise, every error case must be followed by a 2-frame clean sequence and the scoreboard must observe *both* frames egress bit-exact. Any case that cannot recover is tagged `NO-RECOVERY` in the Expected column and must terminate with an explicit reset.

**Cross-reference to DV_HARNESS.** Stimulus is driven by `opq_error_seq.sv` (see harness §1); backpressure by the egress driver's `STUCK_LOW` / `BURST_STALL` profiles (harness §3.2); passive probes for FSM state and FIFO pointers come from the `opq_probe_if` bind (harness §3.4).

**Covergroup references used below** (all defined per `DV_PLAN.md` §5 unless a local bin is named):

- `cov_fsm.ingress_parser[lane].<STATE>`, `cov_fsm.page_allocator.<STATE>`, `cov_fsm.block_mover[lane].<STATE>`, `cov_fsm.arbiter.<STATE>`, `cov_fsm.ftable_mapper.<STATE>`, `cov_fsm.ftable_tracker.<STATE>`, `cov_fsm.ftable_presenter.<STATE>`
- `cov_fsm.C_PRESENTER_X_BP`, `cov_fsm.C_ALLOC_X_LANES`, `cov_fsm.C_BLKMV_X_LANE`
- `cov_flow.lane_fifo_occupancy.FULL`, `cov_flow.ticket_fifo_occupancy.FULL`, `cov_flow.handle_fifo_occupancy.FULL`
- `cov_flow.egress_ready_duty.{STUCK_LOW,1PCT,10PCT}`
- `cov_err.<CLASS>` where `<CLASS>` ∈ `{HIT_ERR, SHD_ERR, HDR_ERR, COMBO_ERR, FRAMING_SOP_NO_EOP, FRAMING_EOP_NO_SOP, FRAMING_ZERO_LEN, FRAMING_MID_GAP, TRUNC_PKT, OVERSIZE_FIFO, OVERSIZE_SEG, RESET_IN_STATE, DROP_ON_FULL, ALLOC_STARVE, EGRESS_STALL, BOGUS_CHAN, K_MISALIGN, DOUBLE_DROP, RESTART_MULTI, COMBO}`
- `cov_err.REC_{CLEAN,MASKED,RESET}` — sampled once per X-case recovery phase.

---

## X1xx — Upstream error-bit injection

Targets `asi_ingress_<i>_error[2:0] = {hit_err, shd_err, hdr_err}` latched at lines 1130–1132 of the RTL and propagated through the `ingress_parser` FSM at lines 1205–1444. All cases here use the reference 4-lane MERGING config. Unless noted, error is asserted by the ingress driver on exactly the beats spelled out in the Stimulus column; error must be stable across SOP..EOP per `opq_avst_ingress_sva.sv` §7.1 (the SVA has an `assume` override when `inject_*_err` is set).

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X101 | hit_err single hit mid-subh | One `hit_err` beat mid-subheader; rest of frame clean. | 1 frame, 4 subh, 8 hits each; set `error=3'b001` on hit 4 of subh 2 of lane 0. | DUT drops that hit (hit count = 7 for that subh); `aso_egress_error[0]` sticky on the egress packet; scoreboard equivalence on all other hits. | `ingress_parser.WR_HITS` @ L1427 `if (asi_ingress_valid and not hit_err)` | F5 | `cov_err.HIT_ERR`, `cov_fsm.ingress_parser[0].WR_HITS`, `cov_err.REC_CLEAN` |
| X102 | hit_err on every hit in one subh | All hits of one subheader carry `hit_err=1`. | 1 frame, subh 3 of lane 1, set `error=3'b001` on all hits. | That subh egresses with `hit_cnt=0` and `hit_err` sticky; the full frame still egresses cleanly after recovery. | `ingress_parser.WR_HITS` hit-skip branch | F5 | `cov_err.HIT_ERR` |
| X103 | hit_err on first hit of subh | First hit of subh 1 carries `hit_err`. | Single subh, first hit = error. | That hit dropped; subsequent hits accepted; `hit_err` sticky on egress. | `ingress_parser.WR_HITS` @ L1427 | F5 | `cov_err.HIT_ERR` |
| X104 | hit_err on last hit of subh | Last hit before EOP carries `hit_err`. | Single subh, final hit = error, then EOP. | Last hit dropped; EOP still captured; subh length decremented in the ticket. | `ingress_parser.WR_HITS` L1439 length check | F5 | `cov_err.HIT_ERR` |
| X105 | hit_err burst (4 consecutive) | 4 consecutive hits flagged. | Subh with 16 hits, beats 5..8 carry `hit_err`. | 12 hits reach egress; `hit_err` sticky. | `ingress_parser.WR_HITS` | F5 | `cov_err.HIT_ERR` |
| X106 | shd_err on subh header word | `shd_err=1` on the subh header beat itself. | 4-subh frame, set `error=3'b010` on subh 2 header beat. | Parser transitions into `MASK_PKT` (L1255); subh 2 fully suppressed; subh 1,3,4 pass; egress `shd_err` sticky. | `ingress_parser.IDLE->MASK_PKT` @ L1254–1256 | F5 | `cov_err.SHD_ERR`, `cov_fsm.ingress_parser[*].MASK_PKT` |
| X107 | shd_err across whole subh | `shd_err=1` stable SOP..EOP on one subh. | As X106 but error stable until EOP. | Same as X106; verify SVA `error`-stability holds. | `ingress_parser.MASK_PKT` body @ L1332 | F5 | `cov_err.SHD_ERR` |
| X108 | shd_err on subh after 255 clean subh | Error on the final subh of the frame. | Max-subh frame, shd_err on subh `N_SHD-1`. | Only last subh suppressed; frame trailer still closes. | `ingress_parser` MASK_PKT → UPDATE_HEADER_TS recovery @ L1329 | F5 | `cov_err.SHD_ERR` |
| X109 | shd_err on subh 0 | Error on first subh only. | First subh flagged. | First subh masked; parser reopens at subh 1. | `ingress_parser.MASK_PKT` | F5 | `cov_err.SHD_ERR` |
| X110 | shd_err every other subh | Alternating shd_err. | 8 subh, even indices flagged. | 4 subh egress, 4 masked; `shd_err` sticky on egress frame. | `ingress_parser` MASK_PKT repeated entry | F5 | `cov_err.SHD_ERR` |
| X111 | hdr_err on preamble beat | `hdr_err=1` on word 0 of header. | 1 frame, `error=3'b100` on SOP. | Parser forces `MASK_PKT_EXTENDED` (L1259–1260); the entire frame is suppressed until next SOP; `hdr_err` sticky. | `ingress_parser.IDLE->MASK_PKT_EXTENDED` @ L1259 | F5 | `cov_err.HDR_ERR`, `cov_fsm.ingress_parser[*].MASK_PKT_EXTENDED` |
| X112 | hdr_err on frame_ts word | `hdr_err=1` on header word 1. | Error on beat 1 of header, stable until EOP. | Full frame suppressed; `running_ts` not advanced for this frame (F4 re-sync on next SOP). | `ingress_parser.MASK_PKT_EXTENDED` | F4, F5 | `cov_err.HDR_ERR` |
| X113 | hdr_err on trailer only | `hdr_err=1` only on the trailer word. | Error set exactly on trailer beat. | Frame body is accepted but trailer drops the ticket; parser returns to UPDATE_HEADER_TS. | `ingress_parser.UPDATE_HEADER_TS` trailer path @ L1312 | F5 | `cov_err.HDR_ERR` |
| X114 | hit_err + shd_err combined | Both bits set on same hit. | Hit in subh 2: `error=3'b011`. | `shd_err` dominates — whole subh masked via `MASK_PKT`; `hit_err` and `shd_err` both sticky. | `ingress_parser.MASK_PKT` | F5 | `cov_err.COMBO_ERR` |
| X115 | hit_err + hdr_err combined | Error on header trailer. | Error `3'b101` on trailer. | `hdr_err` causes ticket drop; `hit_err` recorded sticky. | `ingress_parser.UPDATE_HEADER_TS` | F5 | `cov_err.COMBO_ERR` |
| X116 | shd_err + hdr_err combined | Error `3'b110` on header preamble. | SOP beat error. | Full frame masked; both error bits sticky on next frame's egress `aso_egress_error`. | `ingress_parser.MASK_PKT_EXTENDED` | F5 | `cov_err.COMBO_ERR` |
| X117 | all three error bits set | `error=3'b111` on hit, subh, header in separate frames. | Three back-to-back frames each with one bit. | Error sticky semantics per-bit; scoreboard tallies each. | `ingress_parser` all branches | F5 | `cov_err.HIT_ERR`, `cov_err.SHD_ERR`, `cov_err.HDR_ERR` |
| X118 | hit_err on lane 0 only, multi-lane frame | Asymmetric error. | 4-lane frame, hit_err only on lane 0. | Lane 0 drops hits; lanes 1..3 clean; MERGING order still monotonic; `hit_err` sticky only on frames from lane 0. | `ingress_parser[0]` WR_HITS vs lane 1..3 IDLE/WR_HITS | F5 | `cov_err.HIT_ERR` |
| X119 | hit_err rotation across 4 lanes | Each lane hits error in a different subh. | 4 lanes, 4 subh; lane i hits error on subh i. | Aggregate hit_err sticky on every frame; each lane's MASK_PKT visited once. | `ingress_parser[0..3].WR_HITS` | F5 | `cov_err.HIT_ERR`, `cov_fsm.C_BLKMV_X_LANE` |
| X120 | hdr_err on all lanes same cycle | Synchronised hdr_err on SOP. | 4-lane aligned SOP, all with `hdr_err`. | Every lane enters MASK_PKT_EXTENDED; page_allocator stays in FETCH_TICKET (no SOP tickets delivered); next clean frame must complete; no hang. | `ingress_parser[*].MASK_PKT_EXTENDED` × `page_allocator.FETCH_TICKET` | F5, F7 | `cov_err.HDR_ERR`, `cov_fsm.page_allocator.FETCH_TICKET` |
| X121 | hit_err with error-stable glitch | Driver briefly deasserts error mid-subh (glitch). | Error high for 3 beats then low for 1 then high. | SVA `error`-stability holds (assume override), parser treats the whole window as error, scoreboard equivalence. | SVA `opq_avst_ingress_sva` error-stable cover branch | — | `cov_err.HIT_ERR` |
| X122 | hit_err with hit_cnt=0 subh | Empty subh with hit_err asserted on header beat. | subh length 0, hit_err=1 on subh header. | Ingress parser treats as SHD with hit_err sticky; no hits to drop. | `ingress_parser.WR_HITS` L1438 end-of-subh kick | F5 | `cov_err.HIT_ERR` |
| X123 | shd_err at shd_ts wrap | shd_err on the subh whose shd_ts wraps 0xFF->0x00. | 1 frame long enough to wrap; shd_err on the wrap subh. | Wrap subh masked; next subh's shd_ts must still be consistent. | `ingress_parser.IDLE` subh decode | F5 | `cov_err.SHD_ERR`, `cov_pkt.shd_ts_pattern.0xFF` |

## X2xx — Framing violations

Targets Avalon-ST `sop`/`eop` framing, `valid` continuity, and K-symbol discipline enforced by `opq_avst_ingress_sva.sv` (harness §7.1). The ingress driver (harness §3.1) uses the `pre_delay_cycles` / mid-packet `valid` drop feature. Framing violations normally blow the SVA; each X2xx case must disable the specific protocol property via `$assertoff`/`inject_truncation=1` and assert only the recovery property. Recovery is always "next clean frame egresses bit-exact".

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X201 | SOP without EOP | Driver asserts SOP on a header, then stops valid indefinitely (no EOP). | Start header, hold valid after trailer word, never assert EOP. | Parser stays in `UPDATE_HEADER_TS` / `WR_HITS`; next SOP forces return to IDLE via the `startofpacket and is_preamble` branches at L1240/L1371; masked frame never egresses; clean recovery frame passes. | `ingress_parser` SOP-without-EOP reopen @ L1240 | F6 | `cov_err.FRAMING_SOP_NO_EOP`, `cov_err.REC_MASKED` |
| X202 | EOP without SOP | Driver sends an `eop=1, sop=0` beat while parser is in IDLE. | Single beat, EOP=1, VALID=1, SOP=0. | Parser ignores it (IDLE body has no EOP branch); no ticket written; scoreboard reports no drop. | `ingress_parser.IDLE` default branch | F6 | `cov_err.FRAMING_EOP_NO_SOP` |
| X203 | Mid-packet valid gap 1 cycle | `valid` glitches low for 1 cycle mid-subh. | 1-cycle valid drop at hit 4 of 8. | No corruption — AVST allows valid gap; lane FIFO simply idles for the cycle. | Lane FIFO write-enable gating | — | `cov_err.FRAMING_MID_GAP` |
| X204 | Mid-packet valid gap 100 cycles | Large mid-subh gap below watchdog. | 100-cycle valid low gap. | Parser remains in `WR_HITS`; FIFO pointer unchanged; frame completes. | `ingress_parser.WR_HITS` hold | — | `cov_err.FRAMING_MID_GAP` |
| X205 | Zero-length packet (SOP+EOP same beat, no payload) | Single-beat frame with SOP=EOP=1 but not a valid header. | One beat, `k=0x0`, SOP=EOP=1. | Not a preamble → IDLE branch at L1240 doesn't fire; ticket not written; parser stays IDLE; SVA reports no error because valid=0 next cycle. | `ingress_parser.IDLE` preamble-check | F6 | `cov_err.FRAMING_ZERO_LEN` |
| X206 | Zero-payload subh (hit_cnt=0) | Subheader with `hit_cnt=0`. | Header + one subh, hit_cnt field = 0, immediate trailer next. | Legal shape — frame egresses with a subh of length 0. Used as a reference; scoreboard equivalence. | `ingress_parser.WR_HITS` zero-hit path L1438 | — | `cov_pkt.hits_per_subh.0` |
| X207 | Double SOP without EOP | Two SOP beats separated by a few body beats, no EOP between. | SOP, 4 body, SOP again. | Parser treats second SOP as new frame; first frame masked; scoreboard drop; recovery clean. | `ingress_parser.IDLE/UPDATE_HEADER_TS` reopen | F6 | `cov_err.FRAMING_SOP_NO_EOP` |
| X208 | Double EOP | Two consecutive EOP beats. | Normal subh ending in EOP, next beat also EOP=1. | Second EOP falls in IDLE → ignored. Scoreboard equivalence on rest of frame. | `ingress_parser.IDLE` default | — | `cov_err.FRAMING_EOP_NO_SOP` |
| X209 | SOP inside WR_HITS | SOP beat asserted while WR_HITS is active. | Mid-hit SOP=1, valid=1. | New frame started; current subh masked (see L1371 preamble-in-WR_HITS branch). | `ingress_parser.WR_HITS` → UPDATE_HEADER_TS @ L1371 | F6 | `cov_err.FRAMING_SOP_NO_EOP` |
| X210 | EOP without full hit_cnt | EOP arrives before `hit_cnt` hits are delivered. | subh says hit_cnt=8, EOP after hit 5. | Subh ticket has length=5 not 8; scoreboard's drop model must match; egress `empty` field correct. | `ingress_parser.WR_HITS` length check L1439 | F6 | `cov_err.TRUNC_PKT` |
| X211 | EOP after first hit of subh | EOP right after first hit. | Subh hit_cnt=16, EOP after hit 1. | Ticket length=1. | `ingress_parser.WR_HITS` | — | `cov_err.TRUNC_PKT` |
| X212 | EOP on subh header beat | EOP on the subh header word itself. | subh header with EOP=1. | Empty subh committed (length 0). | `ingress_parser.IDLE` subh-SOP | — | `cov_err.FRAMING_ZERO_LEN` |
| X213 | K-symbol misalignment in body | K-flag set on a body beat (should be k=0 for hits). | Hit beat with `byte_is_k=4'b0001`. | Parser treats it as a new preamble attempt (is_preamble false) → falls to default body write. Used to exercise decode-path robustness. | `ingress_parser_is_preamble` decode | — | `cov_err.K_MISALIGN` |
| X214 | K-symbol missing on preamble | K-flag zeroed on the preamble word. | SOP beat with `byte_is_k=4'b0000`. | `is_preamble=false` → parser ignores SOP; frame masked. | `ingress_parser_is_preamble` L1240 gate | F6 | `cov_err.K_MISALIGN`, `cov_err.FRAMING_SOP_NO_EOP` |
| X215 | K-symbol on subh body hit | Body hit has K=1. | Hit with K=1 mid-subh. | Treated as not-a-hit; depending on decode, falls into default path. Verify no corruption. | `ingress_parser.WR_HITS` decode | — | `cov_err.K_MISALIGN` |
| X216 | Bogus channel mid-frame | `channel` field flips mid-frame (SVA says stable). | 4 beats with `channel=3`, next beat `channel=5`. | SVA `channel`-stable fires (with `$assertoff` override); parser does not observe channel for routing here; scoreboard flags. | `opq_avst_ingress_sva` channel-stable | — | `cov_err.BOGUS_CHAN` |
| X217 | Zero-length frame (header with no subh) | Header SOP..EOP with no subh inside. | 5-word header, immediate EOP, no subh. | Ticket queue has one SOP/EOP pair, page_allocator writes head+tail only; egress frame has 0 subh. First-frame-short path (F4) exercised. | `page_allocator.WRITE_HEAD`→`WRITE_TAIL` | F4 | `cov_pkt.first_frame_short`, `cov_err.FRAMING_ZERO_LEN` |
| X218 | SOP/EOP same beat, header-size mismatch | SOP+EOP on a 3-word frame (< HDR_SIZE=5). | 3-beat frame. | Parser rejects via header-size check; masked. | `ingress_parser.UPDATE_HEADER_TS` length branch | F6 | `cov_err.TRUNC_PKT` |
| X219 | `valid` dropped during SOP beat | Driver drops valid the same cycle it asserts SOP. | Glitch valid low when SOP high. | SVA fires / assume override; parser does not accept; next clean SOP wins. | SVA `opq_avst_ingress_sva` | F6 | `cov_err.FRAMING_SOP_NO_EOP` |
| X220 | Trailer k-flag missing | Trailer beat has k=0 instead of k=1. | Trailer word with zero K. | Parser treats as body, misses frame close; next SOP forces recovery via preamble-in-non-IDLE branch. | `ingress_parser.UPDATE_HEADER_TS` trailer path | F6 | `cov_err.K_MISALIGN` |

## X3xx — Truncation and oversize

Targets lane FIFO overflow, page RAM segment overflow, and every allowed packet length cut off at every possible word index. "Allowed packet lengths" here means the four canonical shapes: 1-hit subh, 16-hit subh, 255-hit (N_HIT-1) subh, and full-width header.

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X301 | Truncate 1-hit subh at word 0 | Cut before subh header beat. | Send header, then kill valid before first subh SOP. | Parser stuck in `UPDATE_HEADER_TS`; next SOP reopens; first frame masked. | `ingress_parser.UPDATE_HEADER_TS` | F6 | `cov_err.TRUNC_PKT` |
| X302 | Truncate 1-hit subh at word 1 | Cut at hit word, no EOP. | subh header + 1 hit, never EOP. | `WR_HITS` held; next SOP masks. | `ingress_parser.WR_HITS` | F6 | `cov_err.TRUNC_PKT` |
| X303 | Truncate 16-hit subh at word 8 | Mid-subh truncation. | 16-hit subh, EOP at hit 8 (short). | Ticket length=8; short subh accepted. | `ingress_parser.WR_HITS` length | — | `cov_err.TRUNC_PKT` |
| X304 | Truncate 16-hit subh at word 15 | Off-by-one at last hit. | 16-hit subh, 15 hits + EOP. | Ticket length=15; match reference. | same | — | `cov_err.TRUNC_PKT` |
| X305 | Truncate 255-hit subh at word 128 | Halfway truncation. | Max subh, cut at hit 128. | Length=128. | `ingress_parser.WR_HITS` | — | `cov_err.TRUNC_PKT` |
| X306 | Truncate 255-hit subh at word 254 | One hit missing. | 254 hits + EOP. | Length=254. | same | — | `cov_err.TRUNC_PKT` |
| X307 | Truncate header at word 0 | Kill valid after SOP. | SOP, no body. | Parser in UPDATE_HEADER_TS then reopens on next SOP. | `ingress_parser.UPDATE_HEADER_TS` | F6 | `cov_err.TRUNC_PKT` |
| X308 | Truncate header at word 1 | One body word then stop. | 2 beats of header. | Same as X307; different hold point. | same | — | `cov_err.TRUNC_PKT` |
| X309 | Truncate header at word 2 | `frame_ts` low word missing. | 3 beats. | Reopen on next SOP. | `ingress_parser.UPDATE_HEADER_TS` L1312 | F6 | `cov_err.TRUNC_PKT` |
| X310 | Truncate header at word 3 | dt_type/feb_id missing. | 4 beats. | Reopen. | same | — | `cov_err.TRUNC_PKT` |
| X311 | Truncate header at word 4 (trailer missing) | All body but no trailer. | 5 beats, no EOP. | Parser waits for trailer, reopens on next SOP. | same | — | `cov_err.TRUNC_PKT` |
| X312 | Oversize subh (hit_cnt exceeds N_HIT) | Subh declares `hit_cnt=N_HIT+1`. | Drive subh header with over-spec hit_cnt. | Parser asserts `hit_err` at L1427 when hit count overruns; overflow hits dropped. | `ingress_parser.WR_HITS` hit-overflow | F5 | `cov_err.OVERSIZE_SEG`, `cov_err.HIT_ERR` |
| X313 | Oversize subh by 1 | Subh with exactly N_HIT+1 hits. | subh length N_HIT+1. | Last hit dropped, `hit_err` sticky. | same | F5 | `cov_err.OVERSIZE_SEG` |
| X314 | Oversize subh by 100 | Large overshoot. | subh length 2×N_HIT. | N_HIT hits accepted, rest dropped. | same | F5 | `cov_err.OVERSIZE_SEG` |
| X315 | Oversize frame (subh_cnt > N_SHD) | Frame with `N_SHD+1` subh. | Long frame. | Extra subh drop path; page_allocator WRITE_PAGE does not exceed segment. | `ftable_mapper.MODIFY_FRAME_TABLE` overflow | F5 | `cov_err.OVERSIZE_SEG` |
| X316 | Lane FIFO overflow — one huge burst | Single lane sends burst > LANE_FIFO_DEPTH. | Back-to-back subh totaling > 1024 beats while egress is stuck low. | Lane FIFO saturates; parser enters `MASK_PKT_EXTENDED`; lane-fifo-full drop branch exercised; recovery clean. | `ingress_parser.MASK_PKT_EXTENDED` | F6 | `cov_err.DROP_ON_FULL`, `cov_flow.lane_fifo_occupancy.FULL` |
| X317 | Lane FIFO overflow — sustained line rate | All 4 lanes sustain 100% valid for > FIFO depth. | 4-lane full-rate burst, egress stuck low. | All lanes drop-on-full; ticket FIFO also saturates. | `ingress_parser` × ticket_fifo full | F6 | `cov_err.DROP_ON_FULL`, `cov_flow.ticket_fifo_occupancy.FULL` |
| X318 | Oversize packet exceeds page-RAM segment | Single frame's aggregated bytes > segment size. | Large N_SHD × N_HIT frame. | `page_allocator.ALLOC_PAGE` rotates segments; F2 exclusion invariant must hold. SVA `opq_page_ram_sva` must not fire. | `page_allocator.ALLOC_PAGE` segment rotation | F2 | `cov_err.OVERSIZE_SEG`, `cov_fsm.page_allocator.ALLOC_PAGE` |
| X319 | Truncation at ticket_fifo boundary | Truncate the SOP ticket just as ticket FIFO fills. | Fill ticket FIFO to capacity minus 1, then truncated SOP. | Parser cannot write sop ticket → `MASK_PKT_EXTENDED` via L1304. | `ingress_parser` L1304 branch | F6 | `cov_err.TRUNC_PKT`, `cov_flow.ticket_fifo_occupancy.FULL` |
| X320 | Back-to-back truncations | 5 consecutive truncated frames. | 5 frames each cut at a different word. | All 5 masked; first clean frame after the burst egresses correctly. | `ingress_parser` mask-path re-entry | F6 | `cov_err.TRUNC_PKT`, `cov_err.REC_MASKED` |
| X321 | Truncation during WR_HITS with lane FIFO near-full | Combo of X303 and X316. | Near-full FIFO + mid-subh truncation. | Truncation wins; parser goes to MASK_PKT; FIFO drains. | `ingress_parser.MASK_PKT` | F6 | `cov_err.TRUNC_PKT`, `cov_err.DROP_ON_FULL` |
| X322 | Truncation of header word 0 with clean recovery | Cut header word 0, then immediately send clean frame. | SOP, no more valid, SOP (new) next cycle. | Parser reopens via L1240. | `ingress_parser.IDLE` | F6 | `cov_err.TRUNC_PKT`, `cov_err.REC_CLEAN` |

## X4xx — Reset during FSM state

Asserts `d_reset` for 2 cycles while the DUT is provably in each target state, then releases and requires clean recovery. For each FSM the target state is reached by a deterministic pre-sequence (documented inline). The reset hits `ingress_parser_state(i) <= RESET` / `page_allocator_state <= RESET` / etc. at the RESET lines cited. For per-lane FSMs the reset is applied globally; the probe port confirms state before the pulse.

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X401 | Reset in `ingress_parser.IDLE` | Baseline reset timing. | Quiet lane, reset 2 cy. | IDLE→RESET→IDLE; no tickets lost (none in flight). | L1205 case | — | `cov_fsm.ingress_parser[*].IDLE`, `cov_fsm.ingress_parser[*].RESET`, `cov_err.RESET_IN_STATE` |
| X402 | Reset in `ingress_parser.UPDATE_HEADER_TS` | Catch parser in header update. | Drive SOP, wait 1 cy, reset. | Parser returns to IDLE; header dropped; scoreboard reports drop; recovery clean. | L1270 | — | `cov_fsm.ingress_parser[*].UPDATE_HEADER_TS`, `cov_err.RESET_IN_STATE` |
| X403 | Reset in `ingress_parser.WR_HITS` | Mid-hit reset. | SOP, header, subh, 4 hits, reset. | Partial subh dropped; lane FIFO flushed. | L1425 | — | `cov_fsm.ingress_parser[*].WR_HITS`, `cov_err.RESET_IN_STATE` |
| X404 | Reset in `ingress_parser.MASK_PKT` | Reset while masking a subh. | Trigger shd_err, hold until reset. | RESET→IDLE. | L1332 | — | `cov_fsm.ingress_parser[*].MASK_PKT`, `cov_err.RESET_IN_STATE` |
| X405 | Reset in `ingress_parser.MASK_PKT_EXTENDED` | Reset while masking a full frame. | Trigger hdr_err, hold until reset. | RESET→IDLE. | L1318 | — | `cov_fsm.ingress_parser[*].MASK_PKT_EXTENDED`, `cov_err.RESET_IN_STATE` |
| X406 | Reset in `page_allocator.IDLE` | Quiet. | Reset at t=0. | Allocator RESET branch L1856. | L1670 | — | `cov_fsm.page_allocator.IDLE`, `cov_err.RESET_IN_STATE` |
| X407 | Reset in `page_allocator.FETCH_TICKET` | Block allocator in ticket fetch (one lane silent). | 3 of 4 lanes send SOP, one silent → allocator stuck in FETCH_TICKET, reset. | State returns to RESET→IDLE. | L1711 | F7 | `cov_fsm.page_allocator.FETCH_TICKET`, `cov_err.RESET_IN_STATE` |
| X408 | Reset in `page_allocator.ALLOC_PAGE` | Reset mid page allocation. | Drive full SOPs so allocator enters ALLOC_PAGE, reset. | Segment rotation aborted; next frame starts fresh. | L1711–1730 | F2 | `cov_fsm.page_allocator.ALLOC_PAGE`, `cov_err.RESET_IN_STATE` |
| X409 | Reset in `page_allocator.WRITE_HEAD` | Mid-head write. | Reset one cycle into WRITE_HEAD. | Head partially written; next frame must not reuse that page. | L1730 | F2 | `cov_fsm.page_allocator.WRITE_HEAD`, `cov_err.RESET_IN_STATE` |
| X410 | Reset in `page_allocator.WRITE_TAIL` | Mid-tail. | Reset during WRITE_TAIL. | Same as X409. | L1744 | F2 | `cov_fsm.page_allocator.WRITE_TAIL`, `cov_err.RESET_IN_STATE` |
| X411 | Reset in `page_allocator.WRITE_PAGE` | Mid page body write. | Long subh, reset mid-WRITE_PAGE. | Partial page data garbage; next page allocation uses fresh segment. | L1817 | F2 | `cov_fsm.page_allocator.WRITE_PAGE`, `cov_err.RESET_IN_STATE` |
| X412 | Reset in `block_mover.IDLE` | Baseline. | Reset during idle. | IDLE→RESET→IDLE. | L1940 approx (block_mover process) | — | `cov_fsm.block_mover[*].IDLE`, `cov_err.RESET_IN_STATE` |
| X413 | Reset in `block_mover.PREP` | Reset 1 cycle into PREP. | Reset after PREP entry. | `block_mover_state(i) <= IDLE` after release. | L1955 | — | `cov_fsm.block_mover[*].PREP`, `cov_err.RESET_IN_STATE` |
| X414 | Reset in `block_mover.WRITE_BLK` | Mid write. | Long handle write, reset at beat 4. | Partial write; arbiter LOCKED forcibly released; no LOCKED deadlock. | L1962 | F8, F9 | `cov_fsm.block_mover[*].WRITE_BLK`, `cov_err.RESET_IN_STATE` |
| X415 | Reset in `block_mover.ABORT_WRITE_BLK` | Mid abort. | Trigger ABORT_WRITE_BLK (handle disagrees with segment), reset. | `block_mover_state(i) <= IDLE`; no corruption. | L1979 | F8 | `cov_fsm.block_mover[*].ABORT_WRITE_BLK`, `cov_err.RESET_IN_STATE` |
| X416 | Reset in `arbiter.IDLE` | Baseline. | Reset while IDLE. | RESET L2104. | L2090 | — | `cov_fsm.arbiter.IDLE`, `cov_err.RESET_IN_STATE` |
| X417 | Reset in `arbiter.LOCKING` | Mid lock grant. | Two lanes request, reset in LOCKING. | Arbiter IDLE on release; no priority inversion on next round. | L2063 | F9 | `cov_fsm.arbiter.LOCKING`, `cov_err.RESET_IN_STATE` |
| X418 | Reset in `arbiter.LOCKED` | Mid locked write. | Active block write, reset mid. | Arbiter IDLE; F9 release-invariant holds after reset. | L2070–2083 | F9 | `cov_fsm.arbiter.LOCKED`, `cov_err.RESET_IN_STATE` |
| X419 | Reset in `ftable_mapper.IDLE` | Baseline. | Reset idle. | RESET L2386. | L2248 | — | `cov_fsm.ftable_mapper.IDLE`, `cov_err.RESET_IN_STATE` |
| X420 | Reset in `ftable_mapper.PREP_UPDATE` | Pre-update. | Reset just after entering PREP_UPDATE. | State IDLE on release. | L2254 | — | `cov_fsm.ftable_mapper.PREP_UPDATE`, `cov_err.RESET_IN_STATE` |
| X421 | Reset in `ftable_mapper.UPDATE_FRAME_TABLE` | Mid-update. | Reset mid update. | IDLE on release; F3 advance may be mid-flight; F3 re-sync next frame. | L2334 | F3 | `cov_fsm.ftable_mapper.UPDATE_FRAME_TABLE`, `cov_err.RESET_IN_STATE` |
| X422 | Reset in `ftable_mapper.MODIFY_FRAME_TABLE` | Mid-modify. | Reset mid modify. | IDLE on release. | L2337 | — | `cov_fsm.ftable_mapper.MODIFY_FRAME_TABLE`, `cov_err.RESET_IN_STATE` |
| X423 | Reset in `ftable_tracker.IDLE` | Baseline. | Reset idle. | RESET L2585. | L2522 | — | `cov_fsm.ftable_tracker.IDLE`, `cov_err.RESET_IN_STATE` |
| X424 | Reset in `ftable_tracker.RECORD_TILE` | Mid tile record. | Reset while RECORD_TILE. | IDLE on release. | L2522/L2526 | — | `cov_fsm.ftable_tracker.RECORD_TILE`, `cov_err.RESET_IN_STATE` |
| X425 | Reset in `ftable_tracker.FLUSH_TILE` | Mid tile flush. | Reset while FLUSH_TILE. | IDLE on release. | L2556 | — | `cov_fsm.ftable_tracker.FLUSH_TILE`, `cov_err.RESET_IN_STATE` |
| X426 | Reset in `ftable_presenter.IDLE` | Baseline. | Reset idle. | RESET L2834. | L2621 | — | `cov_fsm.ftable_presenter.IDLE`, `cov_err.RESET_IN_STATE` |
| X427 | Reset in `ftable_presenter.WAIT_FOR_COMPLETE` | Mid wait. | Reset while waiting. | IDLE. | L2621 | — | `cov_fsm.ftable_presenter.WAIT_FOR_COMPLETE`, `cov_err.RESET_IN_STATE` |
| X428 | Reset in `ftable_presenter.VERIFY` | Mid verify. | Reset while VERIFY. | IDLE. | L2666 | — | `cov_fsm.ftable_presenter.VERIFY`, `cov_err.RESET_IN_STATE` |
| X429 | Reset in `ftable_presenter.PRESENTING` | Mid presentation. | Reset while presenting beat 5 of packet. | IDLE; aso_egress_valid must drop; next recovery packet egresses clean. | L2650 | F1 | `cov_fsm.ftable_presenter.PRESENTING`, `cov_err.RESET_IN_STATE` |
| X430 | Reset in `ftable_presenter.RESTART` | Mid restart refill. | Force BP → RESTART, reset during refill. | IDLE; rollback abandoned; clean egress next frame. | L2735 | F1 | `cov_fsm.ftable_presenter.RESTART`, `cov_err.RESET_IN_STATE` |
| X431 | Reset in `ftable_presenter.WARPING` | Mid segment warp. | Drive into WARPING, reset. | IDLE. | L2631 | F2 | `cov_fsm.ftable_presenter.WARPING`, `cov_err.RESET_IN_STATE` |
| X432 | Reset during async assertion window | Reset with async assert, sync deassert. | Assert reset async, deassert sync. | Synchronous behavior preserved; no metastability pulse captured by SVA. | global `d_reset` path | — | `cov_err.RESET_IN_STATE` |
| X433 | Reset while egress packet half-delivered | Reset after 4 of 10 egress beats. | BP high, normal stream, reset mid-egress. | Presenter→IDLE; egress EOP gating per F1 valid-only-in-PRESENTING prevents partial beat. | L2650–2771 | F1 | `cov_fsm.ftable_presenter.PRESENTING`, `cov_err.RESET_IN_STATE` |
| X434 | Back-to-back resets | Two reset pulses 3 cy apart. | Reset, 3 cy, reset again. | DUT remains IDLE across both; recovery clean. | global | — | `cov_err.RESET_IN_STATE` |
| X435 | Reset pulse of width 1 cy | Minimum-width pulse. | 1-cycle reset. | All FSMs re-enter RESET state at least once. | all RESET branches | — | `cov_err.RESET_IN_STATE` |
| X436 | Reset pulse width 1000 cy | Long hold. | 1000 cy reset. | No drift while held; clean recovery. | global | — | `cov_err.RESET_IN_STATE` |

## X5xx — Ingress FIFO full + downstream stall

Combines egress backpressure with ingress bursts to drive lane FIFO, ticket FIFO, and handle FIFO to full at the exact same cycle a drop decision is made. Uses the egress driver's `STUCK_LOW` profile (harness §3.2) and the `opq_multilane_seq` burst generator.

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X501 | Lane FIFO full, 1 lane | Egress stuck, one lane bursts past LANE_FIFO_DEPTH. | `STUCK_LOW` 5000 cy; lane 0 full-rate. | Lane 0 drops (MASK_PKT_EXTENDED); drop count matches reference. | `ingress_parser.MASK_PKT_EXTENDED` × lane_fifo.full | F6 | `cov_flow.lane_fifo_occupancy.FULL`, `cov_err.DROP_ON_FULL` |
| X502 | Lane FIFO full, all lanes | Sustained stall, all lanes. | `STUCK_LOW` 10k cy; all 4 lanes full-rate. | All lanes drop; egress resumes cleanly when ready rises. | same | F6 | `cov_flow.lane_fifo_occupancy.FULL`, `cov_err.DROP_ON_FULL` |
| X503 | Ticket FIFO full while lane FIFO has space | Frequent SOP/EOP, few hits. | Short (1-hit) subh at max rate; egress stuck. | Ticket FIFO saturates first; parser enters MASK_PKT_EXTENDED via L1304 (cannot write SOP ticket). | `ingress_parser` L1304 | F6 | `cov_flow.ticket_fifo_occupancy.FULL`, `cov_err.DROP_ON_FULL` |
| X504 | Handle FIFO full | Force many small handles. | Small N_HIT, egress stuck enough to keep block_mover busy. | Handle FIFO saturates; new handles silently dropped; scoreboard `exp_handle_drop_count` increments. | `page_allocator` handle write × handle_fifo.full | F6 | `cov_flow.handle_fifo_occupancy.FULL`, `cov_err.DROP_ON_FULL` |
| X505 | Simultaneous lane+ticket+handle full | Worst-case saturation. | Long stall + full-rate + small subh + many handles. | All three drop paths engage simultaneously; scoreboard matches each. | all drop-on-full branches | F6 | `cov_flow.lane_fifo_occupancy.FULL`, `cov_flow.ticket_fifo_occupancy.FULL`, `cov_flow.handle_fifo_occupancy.FULL` |
| X506 | Ticket FIFO full + truncated SOP | Ticket FIFO pressure meets a truncated frame. | X319-like with multi-lane. | Parser masks; no deadlock. | `ingress_parser` L1304 | F6 | `cov_err.TRUNC_PKT`, `cov_flow.ticket_fifo_occupancy.FULL` |
| X507 | BP release then re-stall mid-drain | Slam open briefly, then stuck again. | 5000 cy stuck, 50 cy open, 5000 cy stuck. | Lanes partially drain then re-saturate; recovery frame still lands. | egress driver `BURST_STALL` × FIFO full | F1, F6 | `cov_err.DROP_ON_FULL`, `cov_err.EGRESS_STALL` |
| X508 | Stall releases exactly at lane FIFO full | Edge-of-drop timing. | BP rises on the same cycle lane_fifo.wptr == depth-1. | Either drop or pass; reference model must match DUT. | `ingress_parser` wr/rd race | F6 | `cov_flow.lane_fifo_occupancy.FULL` |
| X509 | Drop-on-full recovery — clean frame after | After X501 drops, single clean frame. | X501 sequence + 1 clean frame. | Clean frame egresses bit-exact; scoreboard reports `REC_CLEAN`. | `ingress_parser.IDLE` reopen | — | `cov_err.REC_CLEAN` |
| X510 | Drop-on-full recovery — masked frame after | After drop, another burst that should drop. | X501 repeated. | Second burst also drops; no cumulative bookkeeping error. | same | F6 | `cov_err.REC_MASKED` |
| X511 | Drop followed by reset | Drop burst + reset. | X502 + reset. | Reset clears all pending state. | global reset | — | `cov_err.REC_RESET`, `cov_err.DROP_ON_FULL` |
| X512 | Single-lane drop then 3-lane clean | Asymmetric recovery. | Lane 0 bursts into stuck-low drop; lanes 1..3 send 1 clean frame each. | Only lane 0 drops; other lanes unaffected (F7 applies to SOP alignment but drop is lane-local). | `ingress_parser[0]` MASK_PKT_EXTENDED × others IDLE | F6, F7 | `cov_err.DROP_ON_FULL` |
| X513 | Drop during frame_ts near-wrap | Saturate near `frame_ts` 48-bit wrap. | X502 around frame wrap. | Wrap still tracked correctly on next clean frame. | `ingress_parser` UPDATE_HEADER_TS + `running_ts` | F3, F4 | `cov_err.DROP_ON_FULL`, `cov_pkt.frame_ts_wrap.near-wrap` |
| X514 | Drop with TRACK_HEADER=false | Behavior without header tracking. | X502 with generic override. | Same drop semantics; scoreboard uses no-header mode. | `ingress_parser` L1254–1260 | F6 | `cov_cfg.track_header.false`, `cov_err.DROP_ON_FULL` |
| X515 | Drop with N_LANE=1 | Minimal parallelism. | Single-lane burst + stuck-low. | Single-lane drop-on-full; recovery clean. | `ingress_parser[0]` | F6 | `cov_cfg.n_lane.1`, `cov_err.DROP_ON_FULL` |
| X516 | Drop with N_LANE=16 | Maximum parallelism. | 16-lane burst + stuck-low. | All 16 lanes drop; arbiter fairness across 16 releases. | `arbiter.LOCKED` × 16 lanes | F6, F9 | `cov_cfg.n_lane.16`, `cov_err.DROP_ON_FULL` |
| X517 | Slow ramp to full | Gradually add ingress load until lane FIFO saturates. | Egress at 10%, ingress rate steps 25/50/75/100%. | Drop begins at the critical load; no dropping below. | `ingress_parser` + lane_fifo.wr | F6 | `cov_flow.egress_ready_duty.10PCT`, `cov_flow.lane_fifo_occupancy.FULL` |

## X6xx — Page-allocator starvation

Drives the three page-RAM segments into worst-case occupancy so `page_allocator` cannot find a free page, plus missing-lane deadlocks on FETCH_TICKET (F7).

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X601 | All 3 segments busy (read blocked) | Stuck-low while 2 writing segments fill and the read segment is held. | Fill two write segments + hold presenter in PRESENTING via BP. | `page_allocator.ALLOC_PAGE` waits; next frame allocation deferred; no invariant F2 violation. | L1711 → ALLOC_PAGE wait | F2 | `cov_fsm.page_allocator.ALLOC_PAGE`, `cov_err.ALLOC_STARVE` |
| X602 | 3 segments busy + BP release | Recovery. | X601 + BP rise. | Read segment drains; allocator proceeds on next cycle. | same | F1, F2 | `cov_err.ALLOC_STARVE`, `cov_err.REC_CLEAN` |
| X603 | Missing lane SOP → allocator stuck | One lane silent while others send SOP. | 3 of 4 lanes present SOP, lane 3 silent. | `page_allocator.FETCH_TICKET` never completes; no forward progress until lane 3 sends SOP. | L1670 FETCH_TICKET per F7 | F7 | `cov_fsm.page_allocator.FETCH_TICKET`, `cov_err.ALLOC_STARVE` |
| X604 | Missing lane + watchdog | Watchdog fires if silent > threshold. | X603 held past watchdog. | Test marked `NO-RECOVERY`; terminates with reset. | same | F7 | `cov_err.ALLOC_STARVE`, `cov_err.REC_RESET` |
| X605 | Segment rotation under backpressure | Force segment rotation while BP toggles. | 4 segments worth of data with 25% duty BP. | All 3 segments rotate cleanly; F2 exclusion holds; SVA `opq_page_ram_sva` silent. | L1711–1730 rotation | F1, F2 | `cov_fsm.page_allocator.ALLOC_PAGE`, `cov_err.EGRESS_STALL` |
| X606 | WARPING from starvation | Presenter enters WARPING when segment swap needed mid-egress. | Force segment swap mid-packet. | `ftable_presenter.WARPING` visited; no egress data loss. | L2631 | F2 | `cov_fsm.ftable_presenter.WARPING` |
| X607 | Allocator starvation + ticket FIFO full | Combined. | X601 + X503. | Allocator stuck; ticket FIFO full; no deadlock if BP releases. | L1711 + L1304 | F2, F6 | `cov_err.ALLOC_STARVE`, `cov_flow.ticket_fifo_occupancy.FULL` |
| X608 | 3-segment exclusion under heavy writer | Max write rate, presenter slow. | Full-rate ingress + 10% BP. | F2 holds; `opq_page_ram_sva` silent. | `page_ram` wptr/rptr | F2 | `cov_err.ALLOC_STARVE` |
| X609 | Lane count > segments | 8 lanes, 3 segments. | 8-lane full-rate. | Segments rotate fast; no pointer confusion. | `page_allocator.ALLOC_PAGE` | F2 | `cov_cfg.n_lane.8`, `cov_err.ALLOC_STARVE` |
| X610 | Allocator stuck + reset recovery | Reset releases allocator. | X603 + reset. | Allocator exits via RESET branch L1856; recovery clean. | L1856 | F7 | `cov_err.REC_RESET`, `cov_err.ALLOC_STARVE` |

## X7xx — Egress stall during error conditions

Egress stall combined with error-bearing frames. Validates F1 (RESTART rollback) against the 2026-01-29 changelog when the in-flight packet has a sticky error, and checks that `aso_egress_error` survives the rollback/refill cycle unmodified.

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X701 | Stall mid-error-packet | Sticky `hit_err`, stall during PRESENTING. | hit_err frame, BP drop mid-packet. | RESTART rollback; first post-stall beat equals pre-stall beat including `hit_err`. | L2735 restart | F1, F5 | `cov_fsm.C_PRESENTER_X_BP` PRESENTING×bp, `cov_err.HIT_ERR`, `cov_err.EGRESS_STALL` |
| X702 | Stall at SOP beat of error packet | BP drop on the first egress beat of an error frame. | hdr_err frame, BP low on SOP. | Presenter stays in WAIT_FOR_COMPLETE/VERIFY; recovery; error bits preserved. | L2621 | F1 | `cov_err.EGRESS_STALL`, `cov_err.HDR_ERR` |
| X703 | Stall at EOP beat of error packet | BP drop on final beat. | shd_err frame, BP low on EOP. | RESTART rollback includes EOP beat; next resume delivers EOP exactly once. | L2735 | F1 | `cov_err.EGRESS_STALL`, `cov_err.SHD_ERR` |
| X704 | Stall between two error packets | Back pressure during inter-packet gap. | Two shd_err frames, BP between. | No RESTART needed if valid was low; clean resume. | `ftable_presenter.IDLE` | F1 | `cov_err.EGRESS_STALL` |
| X705 | Stall + toggle ready 1-cy periodic | Ready toggles every cycle. | hit_err frame, ready toggles 1010... | Presenter handles every-other-cycle ready; RESTART not triggered (no full stall). | L2650 | F1 | `cov_flow.egress_ready_toggle_period.1` |
| X706 | Stall during WARPING | BP drop while WARPING. | Force segment swap + BP drop mid-warp. | WARPING waits; next ready resumes; F2 still holds. | L2631 | F1, F2 | `cov_fsm.ftable_presenter.WARPING` |
| X707 | Stall during RESTART | BP drops again mid-restart refill. | BP drop → RESTART begins → BP drops again. | Refill blocks; recovers when ready rises; single rollback window, not nested. | L2735 | F1 | `cov_fsm.ftable_presenter.RESTART` |
| X708 | Stall + error bit change before resume | Scenario intentionally violating SVA `error`-stable to test scoreboard. | Apply stall, flip error bit on probe injection (test-only). | Test marks SVA assertion expected; scoreboard flags mismatch. | SVA `opq_avst_egress_sva` | F1 | `cov_err.EGRESS_STALL` |
| X709 | Stall 1000 cy + 100 consecutive error frames | Soak. | Long BP, then release, then 100 hit_err frames with intermittent stalls. | All 100 frames egress with correct error bits. | PRESENTING loop | F1, F5 | `cov_err.HIT_ERR`, `cov_err.EGRESS_STALL` |
| X710 | Stall at end of restart, BP release on last refill cycle | Corner of F1 timing. | BP drops into RESTART, released exactly as refill hits PRESENTING. | No double-accept; first beat unique. | L2735 → L2674 | F1 | `cov_fsm.ftable_presenter.PRESENTING` |

## X8xx — Combined faults and recovery

Multi-axis fault combinations that do not fit the other buckets. Used to catch cross-talk between the ingress parser error path and the presenter rollback path, the arbiter's LOCKED-release path, and the mid-frame reset path.

| ID | Title | Intent | Stimulus | Expected | RTL target | F-tag | Cov bins |
|----|-------|--------|----------|----------|------------|-------|----------|
| X801 | Double-drop: lane FIFO full + shd_err | Masking path triggered by both error and drop-on-full. | Stuck BP + shd_err mid-frame. | MASK_PKT wins first, MASK_PKT_EXTENDED continues; no double-count; reference model matches. | L1254 + L1304 | F5, F6 | `cov_err.DOUBLE_DROP`, `cov_err.DROP_ON_FULL` |
| X802 | Error + reset | shd_err + reset mid-mask. | shd_err → MASK_PKT, reset 2 cy. | IDLE; recovery clean. | L1332 | F5 | `cov_err.RESET_IN_STATE`, `cov_err.SHD_ERR` |
| X803 | Truncation + BP stall | Truncated frame while BP is low. | X303 + STUCK_LOW. | Scoreboard records dropped ticket + no egress leak. | L1439 + L2735 | F1, F6 | `cov_err.TRUNC_PKT`, `cov_err.EGRESS_STALL` |
| X804 | RESTART × ABORT_WRITE_BLK | F1 and F8 together. | BP drop during block_mover abort. | Both RESTART and ABORT_WRITE_BLK visited; no lost handle. | L1979 + L2735 | F1, F8 | `cov_fsm.block_mover[*].ABORT_WRITE_BLK`, `cov_fsm.ftable_presenter.RESTART` |
| X805 | Allocator starve + RESTART | Presenter BP drop while allocator is stuck on missing lane. | X603 + BP drop. | RESTART drains what was already in flight; allocator still waits; clean after missing lane sends SOP. | L1670 + L2735 | F1, F7 | `cov_err.ALLOC_STARVE`, `cov_fsm.ftable_presenter.RESTART` |
| X806 | Multiple consecutive RESTART | 5 BP stalls in a row mid-frame. | 5 BP drops over one large packet. | 5 RESTART visits; presenter eventually completes packet; no bit corruption. | L2735 | F1 | `cov_err.RESTART_MULTI`, `cov_fsm.ftable_presenter.RESTART` |
| X807 | Arbiter LOCKED × reset | Reset with arbiter mid-LOCKED + BP stall. | Lane 0 in WRITE_BLK + BP + reset. | Arbiter releases; no deadlock; recovery clean. | L2070 + L2735 | F1, F9 | `cov_fsm.arbiter.LOCKED`, `cov_err.RESET_IN_STATE` |
| X808 | hdr_err on one lane + clean on others + BP | Asymmetric error under stall. | Lane 0 hdr_err, lanes 1..3 clean, BP 50%. | Lane 0 masked full frame; others egress; MERGING order preserved. | L1259 + L2650 | F1, F5, F7 | `cov_err.HDR_ERR`, `cov_err.EGRESS_STALL` |
| X809 | All-lanes hdr_err + BP | Fully silenced ingress under stall. | Lanes 0..3 all hdr_err, BP stuck. | No egress; no RESTART; no invariant violation; clean recovery after new clean frame. | L1259 + FETCH_TICKET | F5, F7 | `cov_err.HDR_ERR`, `cov_fsm.page_allocator.FETCH_TICKET` |
| X810 | Bogus channel + shd_err + BP | Three-way combined. | Channel flip + shd_err + BP 25%. | SVA for channel stable fires (suppressed), scoreboard still matches on non-flipped beats. | SVA channel stable + L1255 | F5 | `cov_err.BOGUS_CHAN`, `cov_err.SHD_ERR` |
| X811 | K-symbol misalignment + oversize | hit_err implied via decode + oversize. | Hit with K=1 in an oversize subh. | Oversize drop + K misalignment; no corruption. | L1425 | F5 | `cov_err.K_MISALIGN`, `cov_err.OVERSIZE_SEG` |
| X812 | Page RAM segment swap mid-error-packet | Force segment rotation while hit_err sticky. | Long hit_err frame spanning segment boundary. | Rotation happens (F2); hit_err preserved on egress. | L1711 + PRESENTING | F2, F5 | `cov_err.HIT_ERR`, `cov_fsm.page_allocator.ALLOC_PAGE` |
| X813 | BP stall during allocator ALLOC_PAGE | Presenter BP drop as new page allocates. | ALLOC_PAGE concurrent with RESTART. | Both flows co-exist; no corruption. | L1711 + L2735 | F1, F2 | `cov_fsm.page_allocator.ALLOC_PAGE`, `cov_fsm.ftable_presenter.RESTART` |
| X814 | DEBUG_LV=2 overwrite log + error frame | Confirm overwrite log records the error frame. | DEBUG_LV=2 rebuild; run X101. | `opq_overwrite_debug.log` contains expected line per F10. | sim-only debug path | F10 | `cov_err.HIT_ERR` |
| X815 | DEBUG_LV=0 error frame | Confirm non-debug build still passes. | DEBUG_LV=0 rebuild; run X101. | No log file; functional result identical. | sim-only debug path | F10 | `cov_err.HIT_ERR` |
| X816 | Multi-fault recovery — drop + error + reset | End-to-end recovery sanity. | Lane-FIFO-full + shd_err + reset + clean frame. | After reset and one clean frame scoreboard equivalence holds. | all mask/reset branches | F5, F6 | `cov_err.REC_RESET`, `cov_err.DROP_ON_FULL`, `cov_err.SHD_ERR` |
| X817 | Wrap frame_ts during error burst | Timestamp wrap under sticky error. | hit_err frames spanning 48-bit wrap. | F3/F4 hold, error sticky. | L1153 frame_ts update | F3, F4, F5 | `cov_pkt.frame_ts_wrap.near-wrap`, `cov_err.HIT_ERR` |
| X818 | First-frame-short under error | First frame after reset is short and has hdr_err. | Reset; immediately first frame with < N_SHD subh and hdr_err. | Frame masked; next frame's running_ts re-sync via F4 works. | L1670 + L1259 | F4, F5 | `cov_pkt.first_frame_short`, `cov_err.HDR_ERR` |
| X819 | Max-length error frame | Maximum legal packet with every subh flagged shd_err. | Max-subh frame, every subh with shd_err. | Entire frame masked subh-by-subh; parser visits MASK_PKT 256 times. | L1332 | F5 | `cov_err.SHD_ERR` |
| X820 | Recovery after 1000 error frames | Long error soak followed by 10 clean frames. | 1000 alternating error frames (rotating error bit), then 10 clean. | Clean frames egress bit-exact; no state corruption. | all parser error branches | F5 | `cov_err.REC_CLEAN`, `cov_err.HIT_ERR`, `cov_err.SHD_ERR`, `cov_err.HDR_ERR` |

---

## Summary: Case Distribution

| Sub-bucket | Range | Count |
|---|---|---|
| X1xx Upstream error-bit injection | X101–X123 | 23 |
| X2xx Framing violations | X201–X220 | 20 |
| X3xx Truncation / oversize | X301–X322 | 22 |
| X4xx Reset during FSM state | X401–X436 | 36 |
| X5xx Ingress FIFO full + downstream stall | X501–X517 | 17 |
| X6xx Page-allocator starvation | X601–X610 | 10 |
| X7xx Egress stall during error | X701–X710 | 10 |
| X8xx Combined faults | X801–X820 | 20 |
| **Total** | | **158** |

Total: **158 cases** ( ≥ 128 minimum required by `DV_PLAN.md` §4 ).

---

## Gaps / Open Questions (for signoff review)

1. **X432 async-reset assertion window** depends on the harness choosing to treat `d_reset` as the top-level synchronous reset even when the env releases it asynchronously. The plan currently assumes this; if `tb_top.sv` opts to model a fully async reset input, X432 must split into two IDs (`X432a` sync-release, `X432b` async-release).
2. **X708 intentional SVA violation** needs an `$assertoff` entry in the harness' test pragma list; not yet listed in `DV_HARNESS.md` §7.2. Add a cross-reference when the harness is frozen.
3. **X604 NO-RECOVERY watchdog expiry** currently depends on an env-level `end_of_test_phase` hook to convert the UVM_FATAL watchdog into a pass-with-terminate. Confirm that hook exists in `opq_base_test`.
4. **X503 ticket FIFO full path via L1304** assumes the `ingress_parser` branch that masks a frame when the SOP ticket cannot be written. No case in this bucket checks what happens if the ticket FIFO becomes full *after* the SOP ticket is written but *before* the subh tickets — that is a separate subh-ticket-drop path that should be enumerated in a follow-up review (candidate ID range `X5xx extension`).
5. **Per-lane reset** (X4xx) currently uses a global `d_reset` assertion. The DUT does not expose per-lane reset, so any per-lane reset case would be fictional; confirmed out of scope. Flagged only for completeness.
6. **DEBUG_LV matrix** (X814/X815) exercises two corners; intermediate `DEBUG_LV=1` is already the reference config. No gap.
7. **Cross with cross-bucket cases**: several X8xx cases (X806, X812, X813) overlap with candidate `DV_CROSS` C-series soak runs. Decision: keep in X-bucket because the fault trigger is the primary intent; the C-bucket should reference these IDs as prerequisites rather than duplicate them.

---

## 9. Dependencies

- `DV_PLAN.md` §4, §5, §6
- `DV_HARNESS.md` §1 (opq_error_seq), §3 (agents), §4 (opq_txn), §5 (scoreboard drop model), §7 (SVA binds)
- `ordered_priority_queue.terp.vhd` line references are for the 2026-04-13 snapshot; any RTL re-preprocess must re-verify the line numbers here.
- `OPQ_RTL_CHANGELOG_backpressure_2026-01-29.txt` (F1), `OPQ_RTL_CHANGELOG_timestamp_alignment_2026-01-29.txt` (F3/F4), `OPQ_RTL_CHANGELOG_overwrite_2026-01-30.txt` (F10).

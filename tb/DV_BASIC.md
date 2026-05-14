# DV_BASIC.md — ordered_priority_queue

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md)
**Canonical ID Range:** `B001-B129`
**Intent:** deterministic functional contracts and state-machine invariants on the monolithic `ordered_priority_queue_dut_sv` before stress, error, and cross composition. Every row pins one specific RTL signal, CSR word, FSM state, or K-char decode anchored in `rtl/sv_ver/ordered_priority_queue/monolithic_sv/*.sv`.

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| B001 | D | live UVM | `opq_basic_smoke_test` | healthy two-lane bring-up spine with long frames, zero backpressure, and full scoreboard | `wr_hdr==rd_hdr`, `wr_shd==rd_shd`, `wr_hit==rd_hit`, no `ft_drop_*` beats, `unexplained=0` per lane |
| B002 | D | live UVM | `opq_basic_ts_boundary_test` | sparse/boundary subheader-byte timestamp values exercising the `extend_subheader_ts` wrap predicate (`shd_byte < running_ts[11:4]`) | reconstructed 48-bit timestamp matches reference for both no-wrap and wrap samples; no ordering inversion on egress |
| B003 | D | live UVM | `opq_basic_subheader_shape_test` | mixed empty and non-empty subheader sequence inside one frame on the healthy path | zero-hit subheaders still advance `running_shd_cnt`; data-bearing subheaders carry the correct `hit_cnt` body length |
| B004 | D | live UVM | `opq_basic_feb_packet_contract_test` | native FEB whole-frame packet contract with monitor-side reconstruction from real DUT pins | exact datak/SOP/EOP placement for preamble/header/subheader/body/trailer, one ticket per frame closure |
| B005 | D | live UVM | `opq_basic_single_active_lane_test` | lane 0 produces hits while lane 1 emits legal empty-frame cadence only | lane 0 ledger closes normally, lane 1 produces zero hits and non-zero header/subheader counters |
| B006 | D | live UVM | `opq_basic_single_active_lane_lane1_test` | mirror of B005 with lane 1 as the producer and lane 0 on empty-frame cadence | lane 1 ledger closes normally, lane 0 empty-lane accounting clean |
| B007 | D | live UVM | `opq_basic_single_active_lane_dense_test` | denser single-lane subheader and hit packing without leaving the healthy no-drop path | lane ledger closes, `ft_drop_*=0`, basic presenter `resident_hold` never engaged |

# Canonical Planned Cases (B008-B129)

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| B008 | D | live UVM | none | CSR[0x000] UID readback returns literal `UID_CONST = 0x4F50514D` ("OPQM") on every read regardless of prior run activity | UID stable across reset, traffic-active, and post-terminate reads; catches accidental writability or mux swap with META |
| B009 | D | live UVM | none | CSR[0x001] META with `meta_sel = 2'b00` (VERSION) returns `pack_version_func(major, minor, patch, build)` bit layout | META word reads `{major[31:24], minor[23:16], patch[15:12], build[11:0]}`; catches bit-field packing regression in `pack_version_word` |
| B010 | D | live UVM | none | CSR[0x001] META with `meta_sel = 2'b01` (DATE) returns `VERSION_DATE` generic | META reads the 32-bit date integer; catches a stale META mux leftover after meta_sel write |
| B011 | D | live UVM | none | CSR[0x001] META with `meta_sel = 2'b10` (GIT) returns `VERSION_GIT` hash | META reads git hash constant; catches mis-decoded 2-bit selector |
| B012 | D | live UVM | none | CSR[0x001] META with `meta_sel = 2'b11` (INSTANCE) returns `INSTANCE_ID` | META reads instance id; catches default-branch fallthrough when other selectors are live |
| B013 | D | live UVM | none | CSR[0x002] LANE_MASK reset default = 0 (every lane effective, since `lane_mask_effective = ~csr.lane_mask` after pruning) | initial LANE_MASK read = 0; `STATUS[19]` = OR of `lane_mask_effective` = 1; catches a reset literal regression |
| B014 | D | live UVM | none | CSR[0x002] LANE_MASK full-write RW: set bit[0]=1 to gate lane 0, read back, and verify lane 0 ingress is silently dropped at the parser boundary | after write, lane 0 `wr_hdr_cnt` freezes; lane 1 counters continue; catches mask not reaching `u_ingress_parser[0]` enable |
| B015 | D | live UVM | none | CSR[0x003] CTRL bit[0] `soft_reset_request` self-clears within one idle cycle after host write-1 | write CTRL=1, readback may be 1 once, then settles to 0 within one CSR poll; catches a missing self-clear |
| B016 | D | live UVM | none | CSR[0x003] CTRL full-32-bit writable surface: write 0xFFFF_FFFF and verify only the defined bits latch; reserved bits read 0 | readback `(CTRL & ~DEFINED_MASK) == 0`; catches accidental mapping of spare bits |
| B017 | D | live UVM | none | CSR[0x004] STATUS[16] = `page_allocator_active` mirrors the u_page_allocator activity handshake | observe bit[16]=1 while a block is being written, =0 otherwise; catches wrong signal tap |
| B018 | D | live UVM | none | CSR[0x004] STATUS[17] = `arbiter_active` mirrors the B2P arbiter lock path | observe bit[17]=1 while `ARBITER_LOCKED`, 0 in `ARBITER_IDLE`; catches arbiter_active tied to wrong state |
| B019 | D | live UVM | none | CSR[0x004] STATUS[18] = `aso_egress_valid` mirrors the basic presenter valid stream | bit[18] high-coverage aligns with `aso_*_valid` beats; catches tap regressed to `_ready` |
| B020 | D | live UVM | none | CSR[0x004] STATUS[19] = OR of `lane_mask_effective` per lane | toggling LANE_MASK to `{1,1}` drops bit[19] to 0; catches AND/OR swap |
| B021 | D | live UVM | none | CSR[0x004] STATUS[23:20] = `N_LANE` generic integer | read STATUS>>20 == OPQ_N_LANE; catches an N_LANE constant frozen at build-time wrong value |
| B022 | D | live UVM | none | CSR[0x005] CAP returns the static capability word (N_LANE, N_SHD, TICKET_FIFO_DEPTH, PAGE_RAM_DEPTH encoded) | readback equals expected packed word for `default_p2_s256_t256_r65536` build; catches CAP bit-ordering regression |
| B023 | D | live UVM | none | CSR[0x008] FT_WR_HDR global counter matches sum of per-lane `wr_hdr` across all lanes at any poll point | global == Σ per-lane; catches mis-adder or race between global and lane counters |
| B024 | D | live UVM | none | CSR[0x009] FT_WR_SHD global counter matches sum of per-lane `wr_shd` | global == Σ per-lane; catches same adder regression on subheader axis |
| B025 | D | live UVM | none | CSR[0x00A] FT_WR_HIT global counter matches sum of per-lane `wr_hit` | global == Σ per-lane; catches adder regression on hit axis |
| B026 | D | live UVM | none | CSR[0x00B] FT_RD_HDR global counter increments exactly once per retired header via the basic presenter's `PRESENTING -> WAIT_FOR_COMPLETE` retirement path | FT_RD_HDR delta over a drained frame equals the number of retired headers; catches missed retirement pulse |
| B027 | D | live UVM | none | CSR[0x00C] FT_RD_SHD global counter increments exactly once per retired subheader | delta equals retired subheader count; catches double-count when `retire_pending` is asserted with `EGRESS_DELAY` alignment |
| B028 | D | live UVM | none | CSR[0x00D] FT_RD_HIT global counter increments exactly once per retired hit | delta equals retired hit count; catches off-by-one in retire-pending counter in the EGRESS_DELAY pipeline |
| B029 | D | live UVM | none | CSR[0x00E]/[0x00F]/[0x010] FT_DROP_HDR/SHD/HIT all read 0 on any healthy no-drop run | three drop counters flat at 0 for B001-B007; catches a phantom drop pulse |
| B030 | D | live UVM | none | CSR lane region stride: lane `i` block sits at `CSR_LANE_REGION_BASE + i*0x010` (base 0x040) and each lane word at `+0x0..+0xF` is disjoint from global 0x000-0x010 | crafted walk across `i=0..N_LANE-1` reads distinct live counters; catches a mis-sized stride constant |
| B031 | D | live UVM | none | lane[i] offset +0x0 (WR_HDR) reflects the per-lane `wr_hdr` counter driven out of `u_ingress_parser[i]` | per-lane count equals number of K285 preamble beats accepted on that lane; catches wrong signal taped to this offset |
| B032 | D | live UVM | none | lane[i] offset +0x1 (WR_SHD) reflects per-lane `wr_shd` (K237 subheader beats accepted) | per-lane count equals subheader beats; catches K237 miscount at parser boundary |
| B033 | D | live UVM | none | lane[i] offset +0x2 (WR_HIT) reflects per-lane `wr_hit` | per-lane count equals hit beats forwarded into the lane body path; catches hit count polluted by header/subheader beats |
| B034 | D | live UVM | none | lane[i] offset +0x3 (RD_HDR) reflects retirement at the presenter, one pulse per retired header for this lane | retired header count equals lane's originated-frame count on a clean drain; catches RD_HDR plumbed to the wrong lane tap |
| B035 | D | live UVM | none | lane[i] offset +0x4 (RD_SHD) reflects retired subheader count for this lane | retired subheader count equals lane-originated subheader count; catches RD_SHD tap regression |
| B036 | D | live UVM | none | lane[i] offset +0x5 (RD_HIT) reflects retired hit count for this lane | retired hit count equals ingress hit count on the healthy path; catches RD_HIT tap regression |
| B037 | D | live UVM | none | lane[i] offsets +0x6/+0x7/+0x8 (DROP_HDR/SHD/HIT) all stay 0 on the healthy path | per-lane drop counters flat; catches a lane-local drop pulse leaking into the healthy path |
| B038 | D | live UVM | none | lane[i] offset +0x9 (LANE_CREDIT_VISIBLE) reflects `lane_credit_visible_word(i)` — the current lane-FIFO free credit exposed to hosts | at quiescence the word reads `LANE_FIFO_MAX_CREDIT = 1022`; catches a stale credit latch |
| B039 | D | live UVM | none | lane[i] offset +0xA (TICKET_CREDIT_VISIBLE) reflects `ticket_credit_visible_word(i)` | at quiescence reads `TICKET_FIFO_MAX_CREDIT = 255`; catches credit stuck after one frame |
| B040 | D | live UVM | none | lane[i] offset +0xB (DRR_ALLOWANCE) defaults to `DRR_DEFAULT_ALLOWANCE = 256` at reset | readback at reset == 256 on every active lane; catches a default literal regression |
| B041 | D | live UVM | none | lane[i] offset +0xB (DRR_ALLOWANCE) is RW; write 0x000 (zero allowance) then read back | writable round-trip; and the lane defers every grant until reload (tested functionally in DV_CROSS); catches accidental RO flag |
| B042 | D | live UVM | none | lane[i] offset +0xB (DRR_ALLOWANCE) rejects values > `QUANTUM_MAX = 0x3ff` via width clamp or range check | write 0x7FFF and read back == 0x3FF (or whichever clamp the RTL applies); catches a missing clamp |
| B043 | D | live UVM | none | lane[i] offset +0xC (DRR_QUANTUM) exposes the current running quantum after `sat_add_quantum` application | in idle-lane window the quantum equals programmed allowance; catches wrong quantum mirror |
| B044 | D | live UVM | none | lane[i] offset +0xD (DRR_GRANT_CNT) increments once per arbiter grant that landed on this lane in the B2P `ARBITER_LOCKED` state | count == number of grant events seen by `u_block_path`; catches double-count on re-grant |
| B045 | D | live UVM | none | lane[i] offset +0xE (DRR_BEAT_CNT) counts block-path beats actually written (not just grants) | beat count == subheader+hit beats written into page_ram under the lane's grant; catches beat miscount on aborted writes |
| B046 | D | live UVM | none | lane[i] offset +0xF (DRR_DEFER_CNT) increments once per defer event (lane had hits but zero allowance) | matches number of forced defers across a run with programmed zero-allowance windows; catches defer miscount |
| B047 | D | live UVM | none | CSR write to a reserved lane[i]+0x(10..1F) offset is ignored (within-region but out-of-stride) | readback unchanged; catches a stray assignment bleeding into reserved words |
| B048 | D | live UVM | none | CSR write to an unmapped global offset 0x011..0x03F is ignored | readback = default (0) and waitrequest handshake still completes; catches bus hang on undecoded offsets |
| B049 | D | live UVM | none | CSR `avs_csr_waitrequest` drops to 0 exactly one cycle after any read or write, returns to 1 in idle | observe waitrequest waveform across a 3-beat CSR sequence; catches a stuck waitrequest that would hang the host hub |
| B050 | D | live UVM | none | CSR uses 9-bit word-addressed bus `avs_csr_address[8:0]`; byte addresses from host must be divided by 4 to land on the correct word | a word address decode of 0x008 returns FT_WR_HDR; catches byte/word address confusion at the bus boundary |
| B051 | D | live UVM | none | ingress K285 preamble recognition: `is_preamble_word()` returns 1 only when `data[7:0]=0x9C` AND `data[35:32]=4'b0001` (datak nibble) | inject K285 on data[7:0] with datak=0001 and verify `wr_hdr` increments; catches K-char byte swap |
| B052 | D | live UVM | none | ingress K237 subheader recognition: `is_subheader_word()` returns 1 only when `data[7:0]=0xF7` AND `data[35:32]=4'b0001` | inject K237 with datak=0001 and verify `wr_shd` increments; catches K237 byte swap |
| B053 | D | live UVM | none | ingress K284 trailer recognition: `is_trailer_word()` returns 1 only when `data[7:0]=0xBC` AND `data[35:32]=4'b0001` | inject K284 and verify the ingress parser exits to IDLE via frame closure; catches trailer miscount |
| B054 | D | live UVM | none | ingress rejects a fake K285 where `datak` bits are 4'b0000 (data-valued 0x9C treated as normal data) | the parser does NOT increment wr_hdr nor leave IDLE; catches datak-unaware preamble match |
| B055 | D | live UVM | none | ingress rejects a fake K237 where `datak` bits are 4'b0000 | wr_shd does not increment; catches datak-unaware subheader match |
| B056 | D | live UVM | none | ingress rejects a fake K284 where `datak` bits are 4'b0000 | parser stays in its current state; catches datak-unaware trailer match |
| B057 | D | live UVM | none | ingress parser `INGRESS_PARSER_IDLE -> UPDATE_HEADER_TS` on legal K285 preamble beat | FSM debug tap shows one-cycle transition; catches premature transition on any non-preamble beat |
| B058 | D | live UVM | none | ingress parser 4-beat header flow: captures `running_ts` on beat 1, `frame_ts_base` on beat 2, `pkg_cnt` on beat 3, and `running_shd_cnt + hit_cnt` on beat 4 before entering WR_HITS | scoreboard snapshot of captured fields matches injected header; catches off-by-one field slicing |
| B059 | D | live UVM | none | ingress parser transitions `UPDATE_HEADER_TS -> WR_HITS` only after `send_ts` capture on beat 4 | verify no WR_HITS entry before 4-beat header completion; catches premature body-state transition |
| B060 | D | live UVM | none | ingress parser `WR_HITS -> WR_HITS` loops on hit beats until a K237 subheader or K284 trailer arrives | parser debug tap shows sustained WR_HITS across hit beats; catches a spurious exit |
| B061 | D | live UVM | none | ingress parser `WR_HITS -> UPDATE_HEADER_TS` on a mid-frame K237 subheader for the next subheader body | verify subheader beat is captured, body continues in WR_HITS; catches subheader being misclassified as header |
| B062 | D | live UVM | none | ingress parser `WR_HITS -> IDLE` on legal K284 trailer beat and the frame is closed with a ticket write | one ticket write per K284 observed; catches missed ticket closure |
| B063 | D | live UVM | none | ingress parser `alert_eop` flag latches on K284 and clears after the ticket write is retired (SVA `p_alert_eop_clears_after_ticket_write`) | flag falls within N cycles of ticket-fifo write pulse; catches a stuck alert_eop |
| B064 | D | live UVM | none | ingress parser `alert_sop` flag latches on K285 and clears inside the 4-beat header cycle | flag falls before entry into WR_HITS; catches stuck alert_sop across frames |
| B065 | D | live UVM | none | subheader TS reconstruction no-wrap case: `shd_byte >= running_ts[11:4]` | `extend_subheader_ts = {running_ts[47:12], shd_byte, 4'b0000}`; catches sign/extend miscue |
| B066 | D | live UVM | none | subheader TS reconstruction wrap case: `shd_byte < running_ts[11:4]` | reconstructed TS increments `running_ts[47:12]` by 1 before stitching `shd_byte`; catches missed wrap predicate |
| B067 | D | live UVM | none | subheader TS reconstruction at the low boundary `shd_byte=0x00` with `running_ts[11:4]=0x00` | no-wrap branch taken; reconstructed TS lower 12 bits = 0x000; catches default-branch fallthrough |
| B068 | D | live UVM | none | subheader TS reconstruction at the high boundary `shd_byte=0xFF` with `running_ts[11:4]=0x00` | no-wrap branch taken; catches a wrap path false-firing on high shd_byte |
| B069 | D | live UVM | none | subheader TS reconstruction at the exact-match boundary `shd_byte == running_ts[11:4]` | no-wrap branch taken per the `<` predicate; catches off-by-one on wrap compare |
| B070 | D | live UVM | none | subheader TS reconstruction at `shd_byte = running_ts[11:4] - 1` | wrap branch taken; catches wrap missed by one |
| B071 | D | live UVM | none | frame header `pkg_cnt` field is captured unchanged in the ticket `TICKET_FEB_ID` composite, preserving FEB identity through to egress | egress ticket FEB_ID equals ingress pkg_cnt; catches a field swap |
| B072 | D | live UVM | none | frame header `send_ts` field is captured into `TICKET_FRAME_TS` at beat 4 | egress frame_ts equals ingress send_ts; catches TICKET_FRAME_TS tap regression |
| B073 | D | live UVM | none | frame header `running_shd_cnt` at beat 4 equals the promised subheader count for the frame | egress `TICKET_N_SUBH` matches the promised count; catches miscount when frame has exactly one subheader |
| B074 | D | live UVM | none | frame header `hit_cnt` at beat 4 equals the promised hit count for the frame | egress `TICKET_N_HIT` matches the promised count; catches hit_cnt being zero-extended wrong |
| B075 | D | live UVM | none | page allocator returns one free handle per frame opening and recycles it on frame close | free-handle count returns to the initial pool between frames; catches leaked handle |
| B076 | D | live UVM | none | page allocator `o_n_free_handle` is visible via the STATUS bit[16] and the handle FIFO depth = `HANDLE_FIFO_DEPTH = 64` is never exceeded | monitor of handle FIFO usedw <= 64; catches handle FIFO overrun |
| B077 | D | live UVM | none | page allocator walks `page_ram_wptr` monotonically across a frame body until a frame-close beats lands a `block_len` write into `TICKET_BLOCK_LEN` | `TICKET_BLOCK_LEN` = final beat count; catches ticket length lagging real writes |
| B078 | D | live UVM | none | page allocator free-pointer equals `OPQ_PAGE_RAM_DEPTH = 65536` at reset | pre-traffic poll returns the full depth; catches allocator reset regression |
| B079 | D | live UVM | none | page allocator does not advance free-pointer on aborted block writes (BLOCK_MOVER_ABORT_WRITE_BLK path) | after a forced abort the free-pointer matches the pre-abort value; catches accounting leak on abort |
| B080 | D | live UVM | none | page allocator emits the ticket `TICKET_LANE_RD_OFST` pointing at the base of the just-written block | basic presenter reads from the declared offset exactly; catches offset field swap |
| B081 | D | live UVM | none | block mover `BLOCK_MOVER_IDLE -> PREP` on the arbiter `ARBITER_LOCKED` grant for this lane | FSM debug tap shows the transition only on grant; catches a spurious PREP entry |
| B082 | D | live UVM | none | block mover `PREP -> WRITE_BLK` once the handle FIFO returns a page handle | FSM debug shows transition only after handle pop; catches premature WRITE_BLK |
| B083 | D | live UVM | none | block mover `WRITE_BLK -> IDLE` on last beat of a legal frame body with a ticket write at the same cycle | one ticket per block observed; catches ticket omission |
| B084 | D | live UVM | none | block mover `WRITE_BLK -> ABORT_WRITE_BLK` when the lane FIFO reports an integrity error (BUG-018 historical) | FSM takes the abort leg; `TICKET_ALT_EOP_LOC` records the alternate EOP; catches abort leg missed on integrity fault |
| B085 | D | live UVM | none | block mover `ABORT_WRITE_BLK -> RESET` releases the page back to the allocator without advancing `page_ram_wptr` | allocator pointer unchanged after abort; catches pointer leak on abort (SVA `p_abort_returns_credit`) |
| B086 | D | live UVM | none | block mover `RESET -> IDLE` after the abort credit is returned | FSM exits RESET within N cycles; catches stuck RESET |
| B087 | D | live UVM | none | B2P arbiter `ARBITER_IDLE -> LOCKING` on first grant request | transition observed once per frame; catches LOCKING entry missed |
| B088 | D | live UVM | none | B2P arbiter `LOCKING -> LOCKED` after the grant fans out to the selected lane's block mover | `arbiter_active` STATUS bit[17] rises; catches LOCKED never reached |
| B089 | D | live UVM | none | B2P arbiter `LOCKED -> ARBITER_IDLE` on block completion (last beat written) | bit[17] falls within 1 cycle of block completion; catches stuck LOCKED |
| B090 | D | live UVM | none | B2P arbiter uses `rr_grant` with a rotating `priority_mask` per grant event | successive grants favor the next lane in the rotation; catches stuck priority_mask |
| B091 | D | live UVM | none | B2P arbiter grants only lanes whose `lane_credit_visible > 0` AND `ticket_credit_visible > 0` | lanes with either credit at 0 get zero grants in that window; catches credit gate omission |
| B092 | D | live UVM | none | B2P arbiter rejects a lane whose `lane_mask_effective` bit is cleared | masked lane sees no grants; catches mask gate bypass |
| B093 | D | live UVM | none | DRR default service on one lane uses `DRR_DEFAULT_ALLOWANCE = 256` quantum before the mover yields | on the default build the lane moves exactly 256 beats before yielding; catches wrong default allowance |
| B094 | D | live UVM | none | DRR `sat_add_quantum` saturates at `QUANTUM_MAX = 0x3ff` on repeated defers | after multiple defers the quantum shown at lane[i]+0xC equals 0x3FF; catches saturation miss |
| B095 | D | live UVM | none | DRR zero-defer window: on a healthy steady-state frame the `drr_defer_cnt` stays 0 | no defer events in B001-B007 equivalent traffic; catches spurious defers on healthy path |
| B096 | D | live UVM | none | DRR grant count delta equals the number of frames served on that lane across the window (one grant per frame) | `drr_grant_cnt` delta == frame count; catches grant per-beat counting |
| B097 | D | live UVM | none | DRR beat count delta equals subheader+hit beats moved across the window | `drr_beat_cnt` delta == moved beats; catches header beats counted as DRR beats |
| B098 | D | live UVM | none | DRR allowance reload via `drr_allowance_reload_i` refreshes the programmed allowance at the start of each subframe | after reload the running quantum resets; catches a stale quantum surviving reload |
| B099 | D | live UVM | none | basic presenter `FTABLE_PRESENTER_IDLE -> WAIT_FOR_COMPLETE` on ticket arrival | FSM tap shows transition one cycle after ticket_fifo write; catches missed transition |
| B100 | D | live UVM | none | basic presenter `WAIT_FOR_COMPLETE -> PRESENTING` once page_ram has all beats of the frame committed | latency from ticket to first egress beat bounded by `EGRESS_DELAY = 3`; catches early PRESENTING entry |
| B101 | D | live UVM | none | basic presenter `PRESENTING -> WAIT_FOR_COMPLETE` after frame retirement (one per frame) | retirement pulse observed; catches a stuck PRESENTING |
| B102 | D | live UVM | none | basic presenter `PRESENTING -> RESET` on external reset and reset clears meta table pointers (meta_wptr/rptr), retire_pending, and resident_hold | all cleared after reset exits; catches residual meta-table leakage |
| B103 | D | live UVM | none | basic presenter skid buffer holds one beat under downstream stall, then forwards it on ready-high | skid buffer never doubles a beat; egress ordering preserved; catches skid duplicate |
| B104 | D | live UVM | none | basic presenter `EGRESS_DELAY = 3` pipeline matches ticket-to-first-beat latency in the absence of backpressure | measured delay = 3 cycles on steady state; catches pipeline depth regression |
| B105 | D | live UVM | none | basic presenter retire_pending path fires exactly one retirement per frame at the end of PRESENTING | one retire pulse observed per PRESENTING episode; catches double-retire |
| B106 | D | live UVM | none | basic presenter retire_pending contributes to FT_RD_HDR/SHD/HIT in a single cycle (atomic retirement) | the three RD counters move together; catches staggered retirement |
| B107 | D | live UVM | none | basic presenter `resident_backpressure_hold` path is only entered when downstream ready is low for at least 2 consecutive cycles | hold never engages on 1-cycle ready gap; catches hold fired on single-cycle gap |
| B108 | D | live UVM | none | basic presenter overwrite-drop decision is based on `circular_distance`/`circular_range_overlaps` and `frame_length_from_counts` | on the healthy path the decision evaluates to 0 (no drop) for every frame; catches a false-positive drop |
| B109 | D | live UVM | none | basic presenter `new_frame_oversize` predicate does not fire on healthy frames (frame_length <= PAGE_RAM free slots) | no oversize path taken; catches spurious oversize firing |
| B110 | D | live UVM | none | ticket field `TICKET_TS` at egress equals ingress `frame_ts_base + running_ts` reconstruction | scoreboard matches on TICKET_TS; catches TS field swap |
| B111 | D | live UVM | none | ticket field `TICKET_BODY_SERIAL` is monotone increasing across the run and never repeats | run-long monotonicity check; catches serial reset or dup |
| B112 | D | live UVM | none | ticket field `TICKET_SERIAL` is per-lane monotone and distinct from BODY_SERIAL | per-lane serial stream checked; catches lane-mix of serial fields |
| B113 | D | live UVM | none | ticket field `TICKET_DT_TYPE` is preserved from ingress header and emitted at egress unchanged | type field round-trips through the monolith; catches DT field corruption |
| B114 | D | live UVM | none | ticket field `TICKET_ALT_EOP_LOC` is 0 on healthy frames (no alternate EOP) | field reads 0 on B001-B007 analogs; catches alt-EOP firing without abort |
| B115 | D | live UVM | none | ticket field `TICKET_ALT_SOP_LOC` is 0 on healthy frames (no alternate SOP) | field reads 0 on B001-B007 analogs; catches alt-SOP firing without abort |
| B116 | D | live UVM | none | Avalon-ST egress SOP asserts on the K285 preamble beat of every presented frame (SVA `opq_avst_egress_sva` startofpacket rule) | one SOP per frame; catches SOP on wrong beat |
| B117 | D | live UVM | none | Avalon-ST egress EOP asserts on the K284 trailer beat of every presented frame | one EOP per frame; catches EOP on wrong beat |
| B118 | D | live UVM | none | Avalon-ST egress valid/ready handshake: beat advances only on `valid & ready` and holds data on a stall | no beat is dropped on a ready-low cycle; catches lost beat |
| B119 | D | live UVM | none | Avalon-ST ingress valid/ready handshake per SVA `opq_avst_ingress_sva`: no beat progresses while ready=0 | scoreboard confirms no ingress advance under held ready-low; catches a missed stall |
| B120 | D | live UVM | none | CSR SVA `opq_csr_sva`: waitrequest rises in idle and falls for one cycle on each accepted transaction | SVA never asserts; catches hung waitrequest |
| B121 | D | live UVM | none | hit3 contract SVA `opq_hit3_contract_sva`: every retired hit carries ts[2:0] fields matching the injected hit | SVA never asserts; catches hit3 corruption |
| B122 | D | live UVM | none | DRR SVA `opq_drr_sva`: onehot grant, no defer on a lane with nonzero allowance, no preemption mid-frame | SVA never asserts; catches DRR invariant violation on healthy path |
| B123 | D | live UVM | none | full run quiescence: after the last frame retires, `STATUS[18]=aso_egress_valid` returns to 0 and all retirement counters are idle | post-run quiescence clean; catches a stuck `egress_valid` |
| B124 | D | live UVM | none | full run quiescence: `STATUS[17]=arbiter_active` returns to 0 within 1 cycle of last frame closure | arbiter returns to IDLE; catches stuck LOCKED |
| B125 | D | live UVM | none | full run quiescence: `STATUS[16]=page_allocator_active` returns to 0 within 1 cycle of last frame closure | page allocator returns to IDLE; catches stuck allocator |
| B126 | D | live UVM | none | end-to-end: one lane, one frame, one subheader, one hit; final global `wr_hdr/shd/hit` equal `rd_hdr/shd/hit` | balanced ledger on the smallest healthy frame; catches minimal-frame regression |
| B127 | D | live UVM | none | end-to-end: one lane, one frame, one subheader, zero hits (empty subheader frame) | egress produces SOP+EOP framing with zero hit beats; wr_hit=rd_hit=0; catches zero-hit frame corruption |
| B128 | D | live UVM | `opq_basic_rn001_board_shape_test` | end-to-end: RN.BASIC.001-shaped 4-lane whole-frame packets at configured `OPQ_N_SHD` width | strict packet-format checks plus no-drop ledger closure for full-width board-like frames |
| B129 | D | live UVM | none | end-to-end: one lane, one frame, `N_HIT = 255` hits on a single subheader (per-subheader max hit count) | all 255 hits retire; RD_HIT delta == 255; catches hit cap miscount |

---

## Coverage Intent

These rows are the primary owners for:

- healthy `cg_frame` bins, `cg_subheader.shd_ts` no-wrap and wrap, `cg_subheader.hit_cnt` low/mid/high
- CSR identity/activity/capability/counter coverage on the 9-bit word-addressed aperture
- ingress K-char recognition (`K285/K237/K284`) with correct `datak` nibble
- 4-beat header capture fields (`running_ts`, `frame_ts_base`, `pkg_cnt`, `running_shd_cnt`, `hit_cnt`, `send_ts`)
- per-lane CSR stride (`CSR_LANE_REGION_BASE=0x040`, `0x010` stride) counters, credit visibility, and DRR telemetry
- FSM state coverage for `ingress_parser`, `block_mover`, `b2p_arbiter`, `basic_presenter`
- page allocator free-pool monotonicity, handle FIFO bounds, `TICKET_LANE_RD_OFST/BLOCK_LEN` accuracy
- Avalon-ST egress SOP/EOP alignment and valid/ready protocol
- STATUS bit[16..19] and [23:20] reporting
- SVA families (`opq_avst_ingress_sva`, `opq_avst_egress_sva`, `opq_csr_sva`, `opq_hit3_contract_sva`, `opq_drr_sva`) never fire on healthy runs

## Still Relevant Legacy Backlog

- `MODE=MULTIPLEXING` parity is still unimplemented and lives in the legacy plan
- `TRACK_HEADER=false` lightweight build is backlog
- non-default width and `OPQ_N_LANE > 2` sweeps are covered only by the variant-only rows that remain `planned` until the build lands

## Regenerate

After editing, rerun:

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb .
```

Keep `B###` IDs contiguous from `001` to `129`; do not reuse numbers across rewrites.

# DV_EDGE.md — ordered_priority_queue

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md)
**Canonical ID Range:** `E001-E129`
**Intent:** boundary, timing, and arbitration corners for ordered_priority_queue contracts — ready-gap profiles, FIFO near-full boundaries, subheader/hit-count extrema, K-char datak edges, DRR quantum boundaries, page-RAM wraparound, and presenter skid/retire corners. Every row pins one specific RTL signal or generic boundary anchored in `rtl/sv_ver/ordered_priority_queue/monolithic_sv/*.sv`.

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| E001 | D | live UVM | `opq_edge_backpressure_test` | periodic stall / restart path with hit-integrity checks on the healthy body | basic presenter returns to `PRESENTING` cleanly after each stall window; `ft_drop_*=0` |
| E002 | D | live UVM | `opq_edge_always_ready_test` | explicit ready-high baseline under the same harness plumbing as E001 | ledger closes with zero drops and no skid buffer engagement |
| E003 | D | live UVM | `opq_edge_ready_medium_profile_test` | medium-duty periodic-stall ready profile to sample non-trivial but healthy backpressure bins | skid buffer engages on every stall window but never duplicates a beat |
| E004 | D | live UVM | `opq_edge_stuck_low_backpressure_test` | longer low-ready windows short of the known overwrite probe path | presenter `resident_backpressure_hold` engages and releases cleanly |
| E005 | D | live UVM | `opq_edge_max_hits_test` | max-hit packet shape on the live symbol path with `N_HIT = 255` in one subheader | full 255-hit body retires; `wr_hit = rd_hit = 255` |
| E006 | D | live UVM | `opq_edge_toggle_backpressure_test` | one-cycle ready toggle stress to close short backpressure bins | skid buffer fires every toggle; no beat loss |
| E007 | D | live UVM | `opq_edge_burst_restart_profile_test` | short ready bursts with deeper low stretches to stress repeated presenter restart | every `PRESENTING -> WAIT_FOR_COMPLETE -> PRESENTING` cycle is clean |
| E008 | D | live UVM | `opq_edge_long_toggle_backpressure_test` | extends one-cycle ready toggling deep enough to stress repeated restart transitions under the healthy path | toggle bin saturated; `opq_avst_egress_sva` does not fire |
| E009 | D | live UVM | `opq_edge_max_hits_backpressure_test` | exercises the max-hit packet shape while periodic egress stalls force presenter restart | max-hit drain survives stalls; `ft_drop_*=0` |

# Canonical Planned Cases (E010-E129)

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| E010 | D | live UVM | none | lane FIFO near-full boundary at `LANE_FIFO_MAX_CREDIT - 1 = 1021` outstanding beats before the first drain | credit visible word reads 1; no overwrite; catches off-by-one in credit subtraction |
| E011 | D | live UVM | none | lane FIFO near-full boundary at exactly `LANE_FIFO_MAX_CREDIT = 1022` beats before first drain | credit visible word reads 0; ingress paces immediately; catches lane FIFO overrun |
| E012 | D | planned | none | lane FIFO over-subscription by one beat (1023 beats offered) | ingress is backpressured on beat 1023 via `asi_*_ready=0`; catches a missing full check |
| E013 | D | live UVM | none | ticket FIFO near-full boundary at `TICKET_FIFO_MAX_CREDIT - 1 = 254` | ticket credit visible reads 1; catches ticket credit off-by-one |
| E014 | D | live UVM | none | ticket FIFO full boundary at exactly `TICKET_FIFO_MAX_CREDIT = 255` | ticket credit visible reads 0; frame closure stalls at 255th ticket; catches ticket FIFO overrun |
| E015 | D | planned | none | ticket FIFO over-subscription (256th ticket requested) | arbiter withholds grant to the offending lane; catches grant leaked through full ticket FIFO |
| E016 | D | live UVM | none | handle FIFO near-full boundary at `HANDLE_FIFO_DEPTH - 1 = 63` outstanding handles | handle FIFO usedw observable at 63; catches missing near-full warning |
| E017 | D | live UVM | none | handle FIFO full boundary at exactly `HANDLE_FIFO_DEPTH = 64` | handle FIFO blocks new frame opens; catches handle FIFO overrun |
| E018 | D | planned | none | handle FIFO over-subscription (65th frame open requested) | frame open is deferred until a handle recycles; catches leaked handle on abort |
| E019 | D | live UVM | none | page RAM wrap boundary: push enough frame bodies to wrap `page_ram_wptr` through `OPQ_PAGE_RAM_DEPTH = 65536` and observe recycle | retire all prior frames first; wptr wraps cleanly; no data corruption |
| E020 | D | planned | none | page RAM wptr at exactly `OPQ_PAGE_RAM_DEPTH - 1` with one more beat pending | beat lands at address 0 on the next cycle (modulo arithmetic); catches wrap miss |
| E021 | D | planned | none | page RAM wptr at exactly 0 after a wrap with one more beat pending | beat lands at address 1; catches stuck wptr after wrap |
| E022 | D | live UVM | none | per-subheader max-hit boundary at `N_HIT = 255` (B129 analog but with backpressure) | 255 hits drain under ready gaps; catches hit count off-by-one under backpressure |
| E023 | D | live UVM | none | zero-hit subheader at the start of a frame (first subheader is empty) | first subheader has `hit_cnt=0`; frame body starts with next subheader |
| E024 | D | live UVM | none | zero-hit subheader at the end of a frame (last subheader is empty) | last subheader has `hit_cnt=0`; K284 trailer follows immediately |
| E025 | D | live UVM | none | zero-hit subheader in the middle of a non-empty frame | middle subheader has `hit_cnt=0`; flanking hits survive; catches zero-hit subheader mis-framed as header |
| E026 | D | planned | none | per-frame max subheaders at `OPQ_N_SHD = 256` on the default build | exactly 256 subheaders retire within one frame; catches subheader cap regression |
| E027 | D | planned | none | per-frame max subheaders + max hits: 256 subheaders × 255 hits = 65280 beats in one frame body | frame fits if page RAM free slots allow; otherwise deferred; catches single-frame body overflow |
| E028 | D | live UVM | none | single-hit single-subheader minimal frame (one K285, one K237, one hit, one K284) | four-beat minimal frame retires cleanly; catches minimal-frame regression |
| E029 | D | live UVM | none | SOP-adjacent-EOP frame with zero subheaders (header + trailer only, no body) | frame emits SOP+EOP framing with zero subheaders; retire counters move by 0 on shd/hit axes; catches zero-body frame corruption |
| E030 | D | live UVM | none | SOP-adjacent-EOP frame with one empty subheader only | one K237 subheader retired with zero hits; catches empty-subheader mis-classified as hit |
| E031 | D | live UVM | none | DRR allowance boundary at programmed value 0 (zero-allowance lane) | lane defers every grant until reload; `drr_defer_cnt` advances by grant opportunities; catches missing defer path |
| E032 | D | live UVM | none | DRR allowance boundary at programmed value 1 (minimum effective quantum) | lane moves exactly 1 beat per grant before yielding; catches off-by-one in `sat_add_quantum` |
| E033 | D | live UVM | none | DRR allowance boundary at programmed value `QUANTUM_PER_SUBFRAME = 256` (default) | lane moves exactly 256 beats per grant; catches quantum pacing regression |
| E034 | D | live UVM | none | DRR allowance boundary at `QUANTUM_MAX = 0x3ff = 1023` | lane moves up to 1023 beats per grant before yielding; catches quantum saturation |
| E035 | D | planned | none | DRR allowance boundary at `QUANTUM_MAX + 1` (illegal write) | CSR clamps to 0x3FF or rejects; catches missing clamp |
| E036 | D | planned | none | DRR running quantum saturation after repeated defers reaches `QUANTUM_MAX` and holds | quantum never exceeds 0x3FF; catches saturation overflow |
| E037 | D | live UVM | none | DRR preemption boundary: a frame in progress on lane A must not be preempted by lane B even if A's quantum goes to 0 mid-frame | DRR SVA `p_no_preempt_mid_frame` does not fire; catches preemption leaking through LOCKED state |
| E038 | D | live UVM | none | DRR onehot grant boundary: exactly one lane is granted at any cycle, never two | DRR SVA `p_onehot_grant` does not fire; catches multi-grant race |
| E039 | D | planned | none | DRR reload on subframe boundary: `drr_allowance_reload_i` pulse refreshes quantum at exact boundary | post-reload quantum equals programmed allowance; catches reload pulse missed |
| E040 | D | live UVM | none | ready-gap profile: exactly 1 ready-low cycle between every hit beat of a long subheader | skid buffer engages once per beat, releases on next cycle; catches skid beat duplication |
| E041 | D | live UVM | none | ready-gap profile: exactly 2 ready-low cycles (triggers `resident_backpressure_hold` per B107 contract) | hold engages on the 2-cycle threshold; catches hold firing on 1-cycle gap |
| E042 | D | live UVM | none | ready-gap profile: 4-cycle ready-low window followed by 1 ready-high cycle, repeated | hold engages, then advances one beat per ready-high cycle; catches stuck hold |
| E043 | D | live UVM | none | ready-gap profile: 16-cycle ready-low followed by 1 ready-high, repeated (very low duty cycle) | long hold tolerated; no timeout asserted; catches premature timeout on long stall |
| E044 | D | live UVM | none | ready-gap profile: 256-cycle ready-low blanket (close to stuck-low) without entering drop territory | hold survives; egress resumes cleanly on release; catches stuck-low regression |
| E045 | D | planned | none | ready-gap profile: ready-low for exactly one `EGRESS_DELAY = 3` pipeline depth | the 3-deep skid is exercised but not overrun; catches EGRESS_DELAY alignment |
| E046 | D | planned | none | ready-gap profile: ready-low for `EGRESS_DELAY + 1 = 4` cycles then resume | first beat after resume is correct; catches a lost beat on deeper stall |
| E047 | D | live UVM | none | skid buffer at exactly one beat holding under ready=0, then ready=1 for one cycle | the held beat forwards exactly once; catches skid double-forward |
| E048 | D | live UVM | none | skid buffer recovery after a burst of 16 consecutive ready-low cycles | skid drains in order; catches out-of-order drain |
| E049 | D | planned | none | skid buffer boundary during a frame's final hit beat (EOP on held beat) | EOP is carried on the forwarded beat; catches EOP dropped in skid |
| E050 | D | planned | none | skid buffer boundary during a frame's K285 preamble beat (SOP on held beat) | SOP is carried on the forwarded beat; catches SOP dropped in skid |
| E051 | D | live UVM | none | retire_pending boundary: frame closes with simultaneous RD_HDR/SHD/HIT increment (atomic retirement) | the three RD counters move in lockstep; catches staggered retirement (B106 extension) |
| E052 | D | planned | none | retire_pending with zero-hit last subheader: RD_HDR + RD_SHD move; RD_HIT stays flat | atomic retirement still atomic across the zero-hit edge; catches RD_HIT sampling bug |
| E053 | D | live UVM | none | EGRESS_DELAY pipeline depth: first beat after ticket ready is exactly 3 cycles later on the healthy path | latency = 3; catches pipeline bubble |
| E054 | D | planned | none | EGRESS_DELAY pipeline with a 1-cycle mid-frame stall: depth recovers to 3 after stall release | post-stall latency remains 3; catches permanent slip |
| E055 | D | live UVM | none | K285 preamble appearing on a lane with `lane_mask_effective=0` is silently dropped (no ingress counter increments) | masked lane's `wr_hdr` stays flat; catches mask not reaching parser |
| E056 | D | live UVM | none | K237 subheader appearing on a masked lane is silently dropped | masked lane's `wr_shd` stays flat; catches lane mask partial application |
| E057 | D | live UVM | none | K284 trailer appearing on a masked lane does not create a frame closure | masked lane's ticket count stays flat; catches false ticket from masked lane |
| E058 | D | planned | none | K-char datak boundary: datak=0001 at data[35:32] selects K-char decode; datak=0000 selects data-only | the same byte value on data[7:0] is interpreted differently by datak bit; catches datak polarity flip |
| E059 | D | planned | none | K-char datak boundary: datak=0010 or higher lanes is treated as data (only low bit enables K) | non-low-lane K bits ignored; catches multi-bit datak false-enable |
| E060 | D | planned | none | K-char mid-stream appearance: a K237 byte value in the data path without datak does not increment `wr_shd` | wr_shd remains flat when datak=0 on a 0xF7 beat; catches data-valued K-char false match |
| E061 | D | planned | none | K-char at byte lane other than [7:0] (e.g. on [15:8]) is not decoded as a K-char | K-char decode is strictly on [7:0]; catches wide-K miscue |
| E062 | D | live UVM | none | 4-beat header flow boundary: arrival of a K285 in the middle of a WR_HITS body closes the current frame early via `alert_sop` | a forced early K285 triggers abort path; catches missed alert_sop |
| E063 | D | planned | none | 4-beat header flow boundary: beat 2 K285 (two preambles in two cycles) is illegal input and enters `MASK_PKT` | parser masks the malformed frame; catches double-preamble pass-through |
| E064 | D | planned | none | 4-beat header flow boundary: K284 trailer at beat 3 of header (before body) closes empty frame | frame retires with zero hits and zero subheaders; catches truncated header pass-through |
| E065 | D | live UVM | none | subheader TS reconstruction at wrap boundary: `shd_byte = running_ts[11:4] - 1` (exact wrap) | wrap branch taken; catches off-by-one on wrap predicate (B070 extension) |
| E066 | D | live UVM | none | subheader TS reconstruction at `running_ts[47:12] = 0xFFFFFFFFF` (max upper TS) with a wrap | wrap branch increments upper bits to 0x0 (full wrap); catches upper-bit wrap miss |
| E067 | D | planned | none | frame-header `running_ts` delta across two consecutive frames equals frame separation in TS units | scoreboard TS advancement check; catches ts freeze between frames |
| E068 | D | planned | none | frame-header `frame_ts_base` remains constant within a frame and updates exactly once per frame | base stays static during WR_HITS; catches mid-frame base mutation |
| E069 | D | planned | none | frame-header `pkg_cnt` increments by exactly 1 per frame, wrapping at its field width | increment audited across multiple frames; catches miscount or wrap regression |
| E070 | D | planned | none | frame-header `running_shd_cnt` at end of frame equals the subheader count observed on ingress | the running count captured at beat 4 matches actual subheaders; catches a pre-increment off-by-one |
| E071 | D | planned | none | frame-header `hit_cnt` at end of frame equals total hit beats across all subheaders | the running hit count captured at beat 4 matches total hits; catches hit count corruption on multi-subheader frames |
| E072 | D | planned | none | frame-header `send_ts` equals the TS at the K284 trailer beat, not at the K285 preamble | `send_ts` captured at last beat, not first; catches send_ts capture point |
| E073 | D | live UVM | none | B2P arbiter tie: two lanes both eligible and both have credit on the same cycle | arbiter picks per `rr_grant` rotation; catches fixed-priority regression (DRR fairness) |
| E074 | D | live UVM | none | B2P arbiter starvation avoidance: a lane with low rate still gets served within bounded cycles | slow-lane service window bounded; catches starvation |
| E075 | D | planned | none | B2P arbiter `ARBITER_LOCKED` held across multi-beat block write; no re-arbitration mid-block | lock holds until block completion; catches re-arbitration race |
| E076 | D | planned | none | B2P arbiter `ARBITER_IDLE -> LOCKING` rejected when no lane has both credits available | arbiter stays IDLE; catches grant issued under empty-credit condition |
| E077 | D | live UVM | none | block mover `PREP -> WRITE_BLK` deferred when handle FIFO is empty (allocator starvation) | PREP holds until handle available; catches PREP leak to WRITE_BLK |
| E078 | D | planned | none | block mover abort path on a forced lane-FIFO integrity error at mid-body | `ABORT_WRITE_BLK -> RESET` taken; `TICKET_ALT_EOP_LOC` set; catches missed abort on mid-body fault |
| E079 | D | planned | none | block mover abort path on a forced lane-FIFO integrity error at first body beat | abort taken before any payload lands; page allocator unaffected; catches leaked page on very-early abort |
| E080 | D | planned | none | block mover abort path on a forced lane-FIFO integrity error at the very last body beat | abort sets `TICKET_ALT_EOP_LOC` to the last beat; catches alt-EOP off-by-one |
| E081 | D | live UVM | none | ingress parser reset entry: external reset drives `INGRESS_PARSER_RESET` state on the next cycle (SVA `p_reset_drives_ingress_parser_reset`) | SVA fires if reset fails to enter RESET state; catches reset bypass |
| E082 | D | live UVM | none | ingress parser reset exit: returns to IDLE within N cycles of reset release | no stuck RESET; catches reset deadlock |
| E083 | D | planned | none | ingress parser `MASK_PKT` entry on illegal mid-header beat (e.g. K237 at beat 2 of 4-beat header) | parser enters MASK_PKT until next K285; catches no-mask regression |
| E084 | D | planned | none | ingress parser `MASK_PKT_EXTENDED` entry when a second illegal event occurs during masking | extended mask state taken; catches missed extended-mask path |
| E085 | D | live UVM | none | credit restoration after a healthy frame: `lane_credit_visible` returns to `LANE_FIFO_MAX_CREDIT` within the retirement window | credit restored; catches permanent credit loss |
| E086 | D | live UVM | none | credit restoration after max-hit frame: credit returns to max after all 255+ hits retire | credit restored; catches miscounted credit after burst |
| E087 | D | planned | none | credit restoration boundary: consecutive frames drain credit to 0 then restore between frames | credit oscillates between 0 and max; catches credit freeze at 0 |
| E088 | D | live UVM | none | frame closure boundary: K284 trailer and a zero-hit subheader in the same frame (empty tail) | frame closes with last subheader having zero hits; catches EOP on zero-hit subheader |
| E089 | D | planned | none | frame closure boundary: K284 trailer immediately after K237 with 1 hit | tight-pack frame; one hit, one subheader, EOP; catches tight-pack regression |
| E090 | D | planned | none | frame closure boundary: K284 trailer immediately after K237 with `N_HIT=255` hits | tight-pack max-hit frame; catches max-hit tight-pack regression |
| E091 | D | planned | none | ticket fifo ordering boundary: two frames closing back-to-back on two lanes produce two tickets in strict lane-grant order | ticket order matches arbiter grant order; catches ticket reordering |
| E092 | D | planned | none | ticket fifo ordering boundary: two frames closing on the same lane produce two tickets in ingress order | same-lane ticket order preserved; catches in-lane reordering |
| E093 | D | live UVM | none | presenter meta table boundary: `meta_wptr` wraps at its width and continues monotonically | wrap audited; catches stuck meta_wptr on wrap |
| E094 | D | live UVM | none | presenter meta table boundary: `meta_rptr` catches up to `meta_wptr` after drain | rptr == wptr post-drain; catches stuck rptr |
| E095 | D | live UVM | none | presenter `meta_pkt_wcnt` and `meta_pkt_rcnt` match after drain | counts equal at quiescence; catches one-sided count update |
| E096 | D | planned | none | presenter `circular_distance` evaluates correctly at wrap boundaries | distance is computed modulo meta table size; catches sign bug at wrap |
| E097 | D | planned | none | presenter `circular_range_overlaps` correctly detects an overlap case at the wrap point | overlap flag correct across wrap; catches range logic bug |
| E098 | D | planned | none | presenter `frame_length_from_counts` evaluates to `hdr + shd + hit + trailer` exactly | length matches beat count; catches length miscount |
| E099 | D | planned | none | presenter overwrite-drop binary search boundary at `ft_drop_hdr_cnt = 0` (no drop) | binary search returns early; catches false drop |
| E100 | D | planned | none | presenter overwrite-drop binary search boundary at `ft_drop_hdr_cnt = 1` (single drop) | drop applied once; catches drop off-by-one |
| E101 | D | planned | none | presenter `new_frame_oversize` boundary: new frame length equals remaining page-RAM free slots exactly | fits without drop; catches a false oversize |
| E102 | D | planned | none | presenter `new_frame_oversize` boundary: new frame length is remaining slots + 1 | oversize drop taken; catches missed oversize |
| E103 | D | planned | none | presenter `resident_hold` engages on the exact 2-cycle ready-low threshold | hold entry audited; catches hold firing on 1-cycle or delayed past 3 cycles |
| E104 | D | planned | none | presenter `resident_hold` releases immediately on ready-high after the threshold | release audited; catches stuck hold |
| E105 | D | live UVM | none | two lanes with exact-same frame opening cycle: arbiter decides via rotating priority, both frames eventually served | both lanes retire frames; catches one-lane starvation |
| E106 | D | live UVM | none | two lanes with interleaved subheader cadence: each lane produces subheaders at different rates | both lane ledgers close; catches cross-lane ledger pollution |
| E107 | D | planned | none | Avalon-ST egress empty bits at EOP match actual valid byte count on the trailer beat | `empty` field correct at EOP; catches empty miscount |
| E108 | D | planned | none | Avalon-ST egress `channel` field (if wired) is stable within a frame | channel constant within frame; catches channel flip |
| E109 | D | live UVM | none | Avalon-ST ingress beat holds under `asi_*_ready=0` without advancing | ingress stall audited; catches stall bypass |
| E110 | D | live UVM | none | Avalon-ST ingress backpressure propagates from lane FIFO full upstream to `asi_*_ready` | ready drops when lane FIFO is full; catches missing backpressure link |
| E111 | D | planned | none | CSR burst access: 10 back-to-back reads across 0x008-0x010 finishes within 10 cycles on a quiet bus | burst completes; catches waitrequest stall |
| E112 | D | planned | none | CSR write-then-read round-trip on LANE_MASK completes within 2 cycles | round-trip latency bounded; catches waitrequest hang on RW word |
| E113 | D | planned | none | CSR STATUS read during active traffic is never stale by more than 1 cycle | STATUS bit[16]/[17]/[18] match ground truth ±1 cycle; catches stale CSR latch |
| E114 | D | planned | none | CSR address x'008' reads return the correct global `FT_WR_HDR` even when called mid-frame | global counter is live and accurate; catches frozen CSR counter |
| E115 | D | planned | none | Frame-table tracker legacy tile boundary: `N_TILE = 5` tiles cycle correctly through `RECORDING_TILE` state (legacy/backlog) | tracker tiles observable; catches tile index advance regression |
| E116 | D | planned | none | Frame-table tracker `TILE_FIFO_DEPTH = 512` near-full boundary (legacy/backlog) | tile FIFO usedw bounded; catches overflow |
| E117 | D | planned | none | Frame-table presenter `WAITING_FOR_COMPLETE -> VERIFYING` transition on complete frame (legacy tile path) | FSM transition audited; catches stuck WAITING state (legacy) |
| E118 | D | planned | none | Frame-table presenter `PRESENTING -> RESTARTING -> WARPING` path exists and cycles clean (legacy tile path) | legacy FSM walk; catches dead code in tile path |
| E119 | D | planned | none | page allocator boundary: free pointer at `OPQ_PAGE_RAM_DEPTH - 1` with concurrent handle return and frame open | both operations succeed in order; catches arbiter race inside allocator |
| E120 | D | planned | none | page allocator boundary: free pointer wraps from 0xFFFF to 0x0000 during active frame (address overflow is modular) | wrap clean; catches non-modular pointer |
| E121 | D | planned | none | page allocator boundary: handle return on the same cycle as a handle request; request may block one cycle | handle returns are drained first; catches handle arbiter deadlock |
| E122 | D | planned | none | STATUS bit[19] (OR of `lane_mask_effective`) flips correctly when all lanes are masked (=0) | bit[19] falls to 0; catches stuck bit[19] |
| E123 | D | planned | none | STATUS bit[19] flips correctly when at least one lane is unmasked (=1) | bit[19] rises to 1 on unmask; catches stuck bit[19] low |
| E124 | D | planned | none | STATUS bit[23:20] (`N_LANE`) remains constant across a full run (generic-sourced) | bit[23:20] monotonic across traffic; catches accidental runtime write |
| E125 | D | planned | none | CAP word (0x005) remains constant across a full run (generic-sourced) | CAP stable; catches runtime write to CAP |
| E126 | D | planned | none | CSR UID (0x000) remains constant across a full run even with concurrent meta_sel writes | UID stable across META writes; catches UID path pollution |
| E127 | D | planned | none | Reset corner: external reset during WR_HITS aborts the frame cleanly; no ticket escapes; page allocator credit returned | no orphan ticket; allocator pointer unchanged; catches leaked ticket on reset |
| E128 | D | planned | none | Reset corner: external reset during LOCKED arbiter state returns to `ARBITER_IDLE` within 1 cycle | arbiter reset clean; catches stuck LOCKED after reset |
| E129 | D | planned | none | Reset corner: external reset during `PRESENTING` clears the basic presenter meta table pointers to 0 | pointers = 0 post-reset; catches presenter pointer leak |

---

## Coverage Intent

These rows drive:

- `cg_bp` backpressure bins: always-ready, medium-profile, stuck-low, toggle-short, toggle-long, burst-restart, max-hits-backpressured
- `cg_subheader.hit_cnt` low/mid/high/max bins including zero-hit and `N_HIT=255`
- `cg_fifo_depth`: lane-FIFO near-full (1021/1022), ticket-FIFO (254/255), handle-FIFO (63/64)
- K-char decode coverage: K285/K237/K284 with correct datak nibble; datak flip negative cases
- 4-beat header flow FSM bin; ingress MASK_PKT / MASK_PKT_EXTENDED bin
- DRR boundary bins: 0, 1, 256, 0x3FF, saturation
- B2P arbiter tie, starvation-avoidance, LOCKED hold
- Presenter skid buffer, resident_hold, retire_pending, EGRESS_DELAY pipeline
- Frame-table presenter legacy tile-path coverage (backlog/variant-only)

## Still Relevant Legacy Backlog

- wider `PAGE_RAM_RD_WIDTH` variants
- `MODE=MULTIPLEXING` with real Avalon-ST per-channel multiplexing
- `N_LANE > 2` beyond `default_p2_s256_t256_r65536` build

## Regenerate

After editing, rerun:

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb .
```

Keep `E###` IDs contiguous from `001` to `129`; do not reuse numbers across rewrites.

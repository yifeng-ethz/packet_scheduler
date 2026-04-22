# DV_ERROR.md — ordered_priority_queue

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md)
**Canonical ID Range:** `X001-X129`
**Intent:** fault, lane-mask, typed-ingress-error, counter-clear, overflow, terminate/flush, and recovery scenarios on the monolithic `ordered_priority_queue_dut_sv`. Every row pins one specific RTL error mechanism, CSR write, or recovery invariant anchored in `rtl/sv_ver/ordered_priority_queue/monolithic_sv/*.sv`.

The supported ingress-error contract is typed and location-specific:

- `error[0]=hit_err` masks exactly one hit, and only when asserted on a hit beat
- `error[1]=shd_err` masks a subheader and all its associated hits, and only when asserted on a K237 subheader beat
- `error[2]=hdr_err` masks the entire frame, and only when asserted on a K285 preamble beat

Asserting an ingress error bit on the wrong beat type is illegal input owned by the formal contract, not the runtime ERROR bucket.

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| X001 | D | live UVM | `opq_error_lane_mask_test` | packet-boundary lane masking with per-lane drop-counter checks | masked lane's ingress silently dropped; per-lane `drop_*` CSR counters advance; unmasked lane unaffected |
| X002 | D | live UVM | `opq_error_lane_mask_single_hit_test` | minimal masked-drop packet to close one-hit counter behavior | one-hit masked drop; `drop_hit` +=1 on masked lane; scoreboard confirms no accept on that hit |
| X003 | D | live UVM | `opq_error_lane_mask_burst_test` | multi-hit masked-drop packet to close burst counter behavior | burst masked drop; per-lane `drop_hdr/shd/hit` counters match burst shape; no cross-lane pollution |
| X004 | D | live UVM | `opq_error_lane_mask_recovery_test` | mask, drop, then clear the mask and expect clean recovery on the next legal FEB packets | post-unmask first frame retires cleanly; `drop_*` stop advancing; catches stuck mask |
| X005 | D | live UVM | `opq_error_hit_mask_recovery_test` | mask the first or last hit of a subheader, then follow with legal recovery traffic | `error[0]=hit_err` on a hit beat drops exactly one hit; ticket length reflects only accepted hits; recovery frame retires cleanly |
| X006 | D | live UVM | `opq_error_subheader_mask_recovery_test` | malformed subheader suppression, including its associated hit payload, followed by a legal recovery frame | `error[1]=shd_err` on a K237 beat drops subheader and all hits under it; zero-hit recovery branch returns to normal body; catches stuck masked subheader |
| X007 | D | live UVM | `opq_error_header_mask_recovery_test` | malformed preamble/header suppression with full-frame mask, followed by a legal recovery frame | `error[2]=hdr_err` on a K285 beat drops the entire frame; recovery frame retires cleanly; `ft_drop_hdr/shd/hit` advance correctly |
| X008 | D | live UVM | `opq_error_header_word_mask_recovery_test` | header-word error injection (beats 2-4 of the 4-beat header) followed by a legal recovery frame | header-word error triggers `MASK_PKT` in the ingress parser; recovery frame retires; catches header-word error leak |
| X009 | D | live UVM | `opq_error_counter_clear_test` | runtime counter clear semantics (zeroing live CSR counters mid-run) | counter-clear is honored mid-run; scoreboard references live values from the clear window forward; tracked as supplemental signoff screen |
| X010 | D | live UVM | `opq_error_ftable_overflow_test` | reduced-depth overwrite-pressure shape check on the native-SV presenter path at the `2-lane/256/512` elaboration point | `ft_drop_hdr/shd/hit` advance; final ledger `wr = rd + drop`; `unexplained=0`; shape-check evidence vs full closure |

# Canonical Planned Cases (X011-X129)

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| X011 | D | live UVM | none | `error[0]=hit_err` injected on the first hit beat of a multi-hit subheader | exactly one hit dropped; subsequent hits retained; `ticket_n_hit` promise reflects accepted count; catches hit-error mislocation |
| X012 | D | live UVM | none | `error[0]=hit_err` injected on the last hit beat of a multi-hit subheader | last hit dropped; earlier hits retained; `TICKET_ALT_EOP_LOC` unchanged (error is not abort); catches late-hit-error regression |
| X013 | D | live UVM | none | `error[0]=hit_err` injected on a mid-body hit beat | middle hit dropped; earlier and later hits retained; catches drop window off-by-one |
| X014 | D | live UVM | none | `error[0]=hit_err` injected on every hit of a 5-hit subheader (all hits masked) | all 5 hits dropped; subheader still retired with `hit_cnt=0` effective; catches zero-accepted-hit handling |
| X015 | D | live UVM | none | `error[0]=hit_err` injected on a zero-hit subheader's phantom hit beat (illegal — no hit beat exists) | injection at wrong location: formal contract owns; runtime bucket must not accept the hit; catches accidental hit beat injection |
| X016 | D | live UVM | none | `error[0]=hit_err` injected on a K285 preamble beat (wrong location, illegal input) | runtime behavior: ignored at non-hit beat; no silent drop of the frame header; formal contract owns the assertion |
| X017 | D | live UVM | none | `error[0]=hit_err` injected on a K237 subheader beat (wrong location, illegal input) | runtime behavior: not treated as shd_err; formal contract owns the assertion |
| X018 | D | live UVM | none | `error[0]=hit_err` injected on a K284 trailer beat (wrong location, illegal input) | runtime behavior: ignored at trailer beat; frame still closes; formal contract owns |
| X019 | D | live UVM | none | `error[1]=shd_err` injected on a K237 subheader beat with 0 hits below it | subheader dropped; no hits to mask; scoreboard confirms `wr_shd += 0` effective but `drop_shd += 1`; catches zero-hit subheader mask |
| X020 | D | live UVM | none | `error[1]=shd_err` injected on a K237 with 1 hit below it | subheader and 1 hit dropped; `drop_shd += 1`, `drop_hit += 1`; catches 1-hit subheader mask regression |
| X021 | D | live UVM | none | `error[1]=shd_err` injected on a K237 with `N_HIT=255` hits below it | subheader and 255 hits all dropped; `drop_hit += 255`; catches max-hit subheader mask |
| X022 | D | live UVM | none | `error[1]=shd_err` injected on the first subheader of a frame | first-subheader drop; remaining subheaders of the frame retire cleanly; catches cross-subheader mask leak |
| X023 | D | live UVM | none | `error[1]=shd_err` injected on the last subheader of a frame | last-subheader drop; frame closure on K284 still clean; catches end-of-frame mask regression |
| X024 | D | live UVM | none | `error[1]=shd_err` injected on a mid-frame subheader | mid-frame subheader drop; flanking subheaders retain their hits; catches mid-frame mask alignment |
| X025 | D | live UVM | none | `error[1]=shd_err` injected on 2 consecutive subheaders | both subheaders and their hits dropped; `drop_shd += 2`; catches consecutive-mask miscount |
| X026 | D | live UVM | none | `error[1]=shd_err` injected on every subheader of a frame (all subheaders masked) | all subheaders dropped; frame still closes on K284; ticket accepted count = 0; catches all-subheader-mask frame handling |
| X027 | D | live UVM | none | `error[1]=shd_err` injected on a K285 preamble beat (wrong location, illegal input) | runtime behavior: not treated as hdr_err; formal contract owns |
| X028 | D | live UVM | none | `error[1]=shd_err` injected on a hit beat (wrong location, illegal input) | runtime behavior: not treated as hit_err; formal contract owns |
| X029 | D | live UVM | none | `error[1]=shd_err` injected on a K284 trailer beat (wrong location, illegal input) | runtime behavior: ignored; frame closes; formal contract owns |
| X030 | D | live UVM | none | `error[2]=hdr_err` injected on a K285 preamble beat | entire frame dropped; `drop_hdr += 1`, all subheader and hit counts for that frame added to `drop_shd/hit`; catches partial-frame leak on hdr_err |
| X031 | D | live UVM | none | `error[2]=hdr_err` on a frame with 1 subheader and 1 hit | `drop_hdr += 1`, `drop_shd += 1`, `drop_hit += 1`; catches tiny-frame mask miscount |
| X032 | D | live UVM | none | `error[2]=hdr_err` on a frame with `OPQ_N_SHD=256` subheaders and max hits | full-frame mask on max-width frame; per-lane drop counters add max values; catches max-frame mask overflow |
| X033 | D | live UVM | none | `error[2]=hdr_err` on a frame with 0 hits and 0 subheaders (empty frame) | `drop_hdr += 1`, `drop_shd += 0`, `drop_hit += 0`; catches empty-frame mask regression |
| X034 | D | live UVM | none | `error[2]=hdr_err` on 2 consecutive frames | both frames dropped; lane FIFO / ticket FIFO / page allocator not affected beyond the drop accounting; catches consecutive-frame mask regression |
| X035 | D | live UVM | none | `error[2]=hdr_err` injected on a K237 subheader beat (wrong location, illegal input) | runtime behavior: not treated as shd_err; formal contract owns |
| X036 | D | live UVM | none | `error[2]=hdr_err` injected on a hit beat (wrong location, illegal input) | runtime behavior: not treated as hit_err; formal contract owns |
| X037 | D | live UVM | none | `error[2]=hdr_err` injected on a K284 trailer beat (wrong location, illegal input) | runtime behavior: ignored at trailer; formal contract owns |
| X038 | D | live UVM | none | onehot0 invariant: `error[2:0]` may have at most one bit set at a time on any beat | harness never asserts multiple error bits; formal contract owns the onehot0 rule; runtime bucket confirms single-bit injection only |
| X039 | D | live UVM | none | ingress parser `MASK_PKT` state entry on `hdr_err` | parser enters `MASK_PKT` on the errored K285 beat; subsequent beats until next K285 swallowed; catches missed `MASK_PKT` entry |
| X040 | D | live UVM | none | ingress parser `MASK_PKT_EXTENDED` entry on a second error during masking | `MASK_PKT_EXTENDED` taken; catches double-error regression |
| X041 | D | live UVM | none | ingress parser `MASK_PKT -> IDLE` on the next K285 preamble | parser resumes normal parsing on the next valid frame start; catches stuck `MASK_PKT` |
| X042 | D | live UVM | none | LANE_MASK CSR write sets bit[0]=1 mid-frame | lane 0 parser ingress stops accepting beats on the next lane-mask re-evaluation boundary; catches mid-frame mask leak |
| X043 | D | live UVM | none | LANE_MASK CSR write sets bit[0]=1 between frames | lane 0 next frame fully dropped; `STATUS[19]` = OR of `lane_mask_effective` drops when all lanes masked |
| X044 | D | live UVM | none | LANE_MASK CSR write sets bit[1]=1 mid-frame (mask lane 1) | mirror of X042 for lane 1; catches lane-1 mask bit swap |
| X045 | D | live UVM | none | LANE_MASK CSR write sets both bits mid-run then clears both | all lanes silenced then resumed; `STATUS[19]` falls to 0 then rises to 1; catches all-masked stuck state |
| X046 | D | live UVM | none | LANE_MASK CSR write with `STATUS[19]=0` then first frame after unmask | first frame after unmask retires cleanly; catches stale mask on wakeup |
| X047 | D | live UVM | none | LANE_MASK write to a lane with a frame already in `WR_HITS` state | current frame completes (lane mask affects next frame boundary); catches mid-frame abort on mask |
| X048 | D | live UVM | none | LANE_MASK write while the masked lane's ingress `asi_*_valid` is high | ingress beat dropped silently; `asi_*_ready` may or may not flip (implementation-defined); catches mask inducing ready glitch |
| X049 | D | live UVM | none | LANE_MASK write while the masked lane has outstanding residents in lane FIFO | residents continue to drain; mask blocks new ingress only; catches mask wiping in-flight residents |
| X050 | D | live UVM | none | counter-clear: CSR write to `FT_WR_HDR` (RO) is inert | readback unchanged; catches write-side-effect on RO counter |
| X051 | D | live UVM | none | counter-clear: CSR write to `FT_WR_SHD` (RO) is inert | readback unchanged |
| X052 | D | live UVM | none | counter-clear: CSR write to `FT_WR_HIT` (RO) is inert | readback unchanged |
| X053 | D | live UVM | none | counter-clear: CSR write to `FT_RD_HDR` (RO) is inert | readback unchanged |
| X054 | D | live UVM | none | counter-clear: CSR write to `FT_RD_SHD` (RO) is inert | readback unchanged |
| X055 | D | live UVM | none | counter-clear: CSR write to `FT_RD_HIT` (RO) is inert | readback unchanged |
| X056 | D | live UVM | none | counter-clear: CSR write to `FT_DROP_HDR` (RO) is inert | readback unchanged |
| X057 | D | live UVM | none | counter-clear: CSR write to `FT_DROP_SHD` (RO) is inert | readback unchanged |
| X058 | D | live UVM | none | counter-clear: CSR write to `FT_DROP_HIT` (RO) is inert | readback unchanged |
| X059 | D | live UVM | none | counter-clear: explicit clear path (if implemented) zeroes all `FT_*` counters simultaneously | after clear all 9 global FT counters read 0; per-lane counters also clear if the clear scope is global; catches partial clear |
| X060 | D | live UVM | none | counter-clear: clear mid-frame (while a frame is still in `WR_HITS`) | counters cleared; in-flight frame completes with its own accounting; catches counter underflow on clear |
| X061 | D | live UVM | none | counter-clear: clear followed by a new frame; first frame's counts start from 0 | post-clear `wr_hdr += 1` after first frame; catches residual counter bits |
| X062 | D | live UVM | none | counter-clear: clear during `ARBITER_LOCKED` state | arbiter finishes the current grant; counters cleared; catches clear inducing arbiter stall |
| X063 | D | live UVM | none | counter-clear: clear during `PRESENTING` state | presenter finishes the current frame; counters cleared; catches clear inducing presenter stall |
| X064 | D | live UVM | none | counter-clear: clear the per-lane counters only (CSR lane region) | per-lane counters clear; global counters may or may not clear (implementation-defined); catches partial per-lane clear |
| X065 | D | live UVM | none | counter-clear: clear the global `FT_DROP_*` counters only | drop counters clear; WR/RD counters unchanged; catches cross-counter pollution on clear |
| X066 | D | live UVM | none | `ft_drop_hdr/shd/hit` mechanics: overwrite-pressure induces a drop in the basic presenter path | `ft_drop_hdr += 1` on a dropped frame; per-lane drop counter also advances; catches drop miscount on overwrite |
| X067 | D | live UVM | none | `ft_drop_hdr/shd/hit` mechanics: all drop counters advance together on a single full-frame drop | hdr/shd/hit drop deltas equal frame counts; catches partial drop miscount |
| X068 | D | live UVM | none | `ft_drop_hdr/shd/hit` mechanics: subheader-level drop via `shd_err` advances `drop_shd` and `drop_hit` but not `drop_hdr` | correct per-axis drop attribution; catches hdr-drop leaking on subheader-only error |
| X069 | D | live UVM | none | `ft_drop_hdr/shd/hit` mechanics: hit-level drop via `hit_err` advances `drop_hit` only | only `drop_hit += 1`; `drop_shd` and `drop_hdr` unchanged; catches cross-axis drop leak on hit_err |
| X070 | D | live UVM | none | `ft_drop_hdr/shd/hit` mechanics: lane-mask drop advances per-lane `drop_*` but not global `ft_drop_*` (lane-mask drop is accounted separately) | per-lane drop counts advance; `ft_drop_*` may or may not (implementation-specific); catches drop axis cross-contamination |
| X071 | D | live UVM | none | reduced-depth overflow: `2-lane/256/512` elaboration point with heavy overwrite pressure | `ft_drop_*` all advance; `wr = rd + drop` ledger closes; shape-check invariant holds |
| X072 | D | live UVM | none | reduced-depth overflow: `4-lane/128/512` elaboration point with legacy traffic | `ft_drop_*` may or may not advance at this profile (preset-limited); shape-check confirms evidence-only status |
| X073 | D | live UVM | none | reduced-depth overflow: `4-lane/128/512` with dense traffic | dense-traffic shape; catches drop regression on wider N_LANE / smaller N_SHD |
| X074 | D | live UVM | none | overwrite-local must-drop witness (CROSS-anchored, referenced here for continuity) | overwrite-pressure induces a must-drop in the presenter; `ft_drop_*` advance; catches must-drop regression |
| X075 | D | live UVM | none | TERMINATE-equivalent quiescence: stop ingress, let in-flight drain, verify full ledger closure | `wr_hdr == rd_hdr + drop_hdr`; same for shd/hit; catches residual ledger drift at quiescence |
| X076 | D | live UVM | none | TERMINATE with empty lane FIFO and empty ticket FIFO | trivial quiescence; `STATUS[16..18]` all 0 within N cycles; catches stuck-active STATUS |
| X077 | D | live UVM | none | TERMINATE with ~32 in-flight beats in lane FIFO | in-flight drains before quiescence; scoreboard confirms no loss; catches terminate-induced loss |
| X078 | D | live UVM | none | TERMINATE with ~1000 in-flight beats in lane FIFO (near max credit) | near-full drain; `lane_credit_visible` returns to `LANE_FIFO_MAX_CREDIT=1022` at end; catches credit freeze on deep drain |
| X079 | D | live UVM | none | TERMINATE with handle FIFO at `HANDLE_FIFO_DEPTH=64` | all handles return to allocator; free-pool count returns to full depth; catches handle leak on terminate |
| X080 | D | live UVM | none | TERMINATE with ticket FIFO at `TICKET_FIFO_MAX_CREDIT=255` | all tickets drain; `ticket_credit_visible` returns to 255; catches ticket leak on terminate |
| X081 | D | live UVM | none | FLUSH-equivalent: external reset pulse during active traffic | reset drains; on release all counters at 0 and all FSMs at IDLE; catches reset-induced ledger corruption |
| X082 | D | live UVM | none | FLUSH-equivalent: `soft_reset_request` CTRL write during active traffic | soft-reset self-clears bit[0]; counters may or may not clear (implementation-defined); catches soft-reset leak |
| X083 | D | live UVM | none | FLUSH then run: first frame after flush starts from clean state | first frame's `wr_hdr=1`, `rd_hdr=1` delta on retirement; catches stale state on wakeup |
| X084 | D | live UVM | none | FLUSH then LANE_MASK write then run | post-flush mask takes effect on first frame; catches mask / flush interaction |
| X085 | D | live UVM | none | FLUSH then DRR_ALLOWANCE reprogram then run | post-flush quantum is the newly programmed value; catches DRR reload through flush |
| X086 | D | live UVM | none | FLUSH then ingress error injection on next frame | error handling resumes on first frame; catches error path broken by flush |
| X087 | D | live UVM | none | recovery: after `hit_err` injection, subsequent frames retire cleanly with no residual drop | `ft_drop_hit` stays flat after injection window; catches residual drop pulses |
| X088 | D | live UVM | none | recovery: after `shd_err` injection, subsequent frames retire cleanly | `ft_drop_shd` stays flat after window; catches residual drop pulses |
| X089 | D | live UVM | none | recovery: after `hdr_err` injection, subsequent frames retire cleanly | `ft_drop_hdr` stays flat after window; catches residual drop |
| X090 | D | live UVM | none | recovery: after LANE_MASK drop, unmask and confirm next frame retires | post-unmask first frame retires cleanly; catches stuck drop accounting |
| X091 | D | live UVM | none | recovery: after `ftable_overflow_test`-style drop window, subsequent frames retire if presenter capacity recovers | post-overflow first-fit frame retires; catches presenter stuck after overflow |
| X092 | D | live UVM | none | recovery: after `counter_clear`, subsequent counter increments start from 0 | first post-clear increment `wr_hdr=1`; catches stale counter state |
| X093 | D | live UVM | none | recovery invariant: ledger `wr == rd + drop` holds after every recovery window | invariant audited at quiescence post-recovery; catches off-by-one from error accounting |
| X094 | D | live UVM | none | recovery invariant: `TICKET_ALT_EOP_LOC` is 0 after recovery (no lingering abort) | post-recovery tickets have clean alt-EOP; catches stuck ALT_EOP |
| X095 | D | live UVM | none | recovery invariant: `TICKET_ALT_SOP_LOC` is 0 after recovery (no lingering abort) | post-recovery tickets have clean alt-SOP; catches stuck ALT_SOP |
| X096 | D | live UVM | none | recovery invariant: `STATUS[16..19]` accurately reflect post-recovery state | STATUS bits correct at quiescence; catches STATUS staleness |
| X097 | D | live UVM | none | recovery invariant: `CAP` word unchanged across recovery | CAP stable; catches accidental write during error path |
| X098 | D | live UVM | none | recovery invariant: `UID` unchanged across recovery | UID stable at 0x4F50514D; catches UID path corruption |
| X099 | D | live UVM | none | recovery invariant: META with `meta_sel=VERSION/DATE/GIT/INSTANCE` returns correct words after recovery | META readbacks unchanged; catches META mux regression |
| X100 | D | live UVM | none | illegal CSR write: reserved bit in CTRL set to 1 | only defined bits latch; readback preserves only defined bits; catches reserved-bit write-through |
| X101 | D | live UVM | none | illegal CSR write: out-of-range DRR_ALLOWANCE (> `QUANTUM_MAX=0x3FF`) | write is clamped or rejected (B042 contract); readback <= 0x3FF; catches missing clamp |
| X102 | D | live UVM | none | illegal CSR write: CSR address decode at unmapped offset (0x011..0x03F, 0x050..0x0FF) | write has no effect; readback is default; catches stray assignment to unmapped space |
| X103 | D | live UVM | none | illegal CSR write: CSR address decode at reserved per-lane offset (lane[i]+0x10..0x1F) | write has no effect; catches within-region but out-of-stride regression |
| X104 | D | live UVM | none | illegal CSR write: byte-address (not word-address) access that would mis-align the 9-bit word decode | host must divide byte address by 4; catches byte/word confusion |
| X105 | D | live UVM | none | illegal CSR write: concurrent reads and writes to the same address within one cycle | read reflects the pre-write value; catches read-write race |
| X106 | D | live UVM | none | illegal CSR write: write during `avs_csr_waitrequest=1` (waiting) | the host respects waitrequest; no corruption on held bus; catches waitrequest-ignored regression |
| X107 | D | live UVM | none | illegal ingress: injecting a K284 trailer without a prior K285 preamble | parser stays in IDLE; no ticket write; catches premature frame closure |
| X108 | D | live UVM | none | illegal ingress: injecting a second K285 preamble mid-frame (per E062) | parser closes current frame early via `alert_sop`; catches missed early-close |
| X109 | D | live UVM | none | illegal ingress: injecting K237 subheader on beat 2 of the 4-beat header (per E063) | parser enters `MASK_PKT`; catches header-beat misclassification |
| X110 | D | live UVM | none | illegal ingress: injecting K284 trailer on beat 3 of header (per E064) | parser closes empty frame; catches truncated-header pass-through |
| X111 | D | live UVM | none | illegal ingress: datak bit=0 on a K-char byte value (data-valued K-char) | parser ignores the data-valued K-char; catches datak-unaware decode |
| X112 | D | live UVM | none | illegal ingress: datak bits on non-low lane (e.g. datak=0010 with K-char on [15:8]) | parser does not decode non-low-lane K-chars; catches multi-bit datak false-enable |
| X113 | D | live UVM | none | illegal ingress: valid signal glitching mid-beat | parser respects Avalon-ST contract (valid stable during ready-low); catches glitch pass-through |
| X114 | D | live UVM | none | illegal ingress: channel field changing mid-frame | parser treats channel as per-frame constant; catches channel flip regression |
| X115 | D | live UVM | none | block mover abort on forced lane-FIFO integrity error (B084 variant) | `BLOCK_MOVER_WRITE_BLK -> ABORT_WRITE_BLK -> RESET`; `TICKET_ALT_EOP_LOC` set; page credit returned to allocator |
| X116 | D | live UVM | none | block mover abort with `TICKET_ALT_EOP_LOC` = first body beat | abort at earliest beat; `drop_hdr += 1` but per-lane `drop_hit=0`; catches abort accounting at earliest cycle |
| X117 | D | live UVM | none | block mover abort with `TICKET_ALT_EOP_LOC` = mid body | abort mid-body; partial hit count dropped; catches mid-body abort accounting |
| X118 | D | live UVM | none | block mover abort with `TICKET_ALT_EOP_LOC` = last body beat | abort at latest beat; all-but-one hit accepted; catches late-abort off-by-one |
| X119 | D | live UVM | none | block mover abort followed by normal frame on the same lane | normal frame retires cleanly after abort; catches persistent abort state |
| X120 | D | live UVM | none | block mover abort followed by frame on the other lane | other-lane frame unaffected; catches cross-lane pollution on abort |
| X121 | D | live UVM | none | arbiter deadlock avoidance: both lanes' `lane_credit_visible=0` simultaneously | arbiter stays in `ARBITER_IDLE`; no spurious grant; catches zero-credit grant regression |
| X122 | D | live UVM | none | arbiter deadlock avoidance: both lanes' `ticket_credit_visible=0` simultaneously | arbiter stays in `ARBITER_IDLE`; catches zero-ticket-credit grant regression |
| X123 | D | live UVM | none | arbiter deadlock avoidance: all lanes masked via LANE_MASK | arbiter stays in `ARBITER_IDLE`; `STATUS[17]=0`; catches stuck arbiter on all-masked |
| X124 | D | live UVM | none | presenter deadlock avoidance: ticket FIFO drains while lane FIFO is empty | presenter retires all tickets; `STATUS[18]` falls; catches stuck presenter on empty lane |
| X125 | D | live UVM | none | presenter deadlock avoidance: downstream `aso_*_ready` held low for 4096 cycles | presenter holds via `resident_backpressure_hold`; no timeout; catches premature timeout |
| X126 | D | live UVM | none | end-to-end error drill: inject `hit_err` on first frame, `shd_err` on second, `hdr_err` on third, recovery frame fourth | all three error types exercised in one run; per-axis drop counts match; recovery frame retires cleanly; catches accumulated state drift |
| X127 | D | live UVM | none | end-to-end mask drill: LANE_MASK set, masked traffic, unmask, recovery traffic | full mask lifecycle; catches stuck mask state |
| X128 | D | live UVM | none | end-to-end CSR stress: randomized CTRL / LANE_MASK / DRR_ALLOWANCE writes during error and recovery windows | CSR stress through error windows; catches race between CSR write and error path |
| X129 | D | live UVM | none | full signoff drill: mixed `hit_err/shd_err/hdr_err` injection + LANE_MASK mid-run + counter-clear + DRR reprogramming + recovery | all error and recovery paths composed in one run; final ledger closes; all SVAs clean; catches integration regression across error subsystem |

---

## Coverage Intent

These rows are the primary owners for:

- typed ingress-error coverage (`hit_err`/`shd_err`/`hdr_err` at correct and illegal locations)
- LANE_MASK CSR write path at packet boundary, mid-frame, and during active traffic
- per-lane `drop_hdr/shd/hit` counter behavior under error and mask conditions
- global `ft_drop_hdr/shd/hit` counter behavior under overwrite-local must-drop and full-frame masks
- ingress parser `MASK_PKT` / `MASK_PKT_EXTENDED` state coverage
- block mover abort path (`ABORT_WRITE_BLK -> RESET`) with `TICKET_ALT_EOP_LOC` / `TICKET_ALT_SOP_LOC` evidence
- counter-clear semantics and RO-CSR write-inertness
- TERMINATE-equivalent quiescence and FLUSH-equivalent reset recovery
- reduced-depth overflow shape-check at the `2-lane/256/512` and `4-lane/128/512` elaboration points

## Special Elaboration Point

`X010 (opq_error_ftable_overflow_test)` remains tracked as the reduced-depth shape-check evidence at the `2-lane/256/512` preset. The explicit overwrite-local must-drop witness on the wider `4-lane/128/512` matrix is carried by `opq_cross_bp_mustdrop_witness_test` in [DV_CROSS.md](DV_CROSS.md). Both are retained so the evidence tree shows preset-limited shape evidence and the full must-drop closure side-by-side.

## Still Relevant Legacy Backlog

- reset-in-state coverage beyond the current `soft_reset_request` self-clear
- malformed header / truncated packet paths beyond the current subheader + header recovery closure
- broader recovery-after-drop cases including multi-window error chains with intervening CSR writes

## Regenerate

After editing, rerun:

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb .
```

Keep `X###` IDs contiguous from `001` to `129`; do not reuse numbers across rewrites.

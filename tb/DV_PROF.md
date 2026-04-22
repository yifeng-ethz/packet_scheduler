# DV_PROF.md — ordered_priority_queue

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md)
**Canonical ID Range:** `P001-P129`
**Intent:** random, profile, soak, and throughput-oriented scenarios for sustained-signoff confidence on the monolithic `ordered_priority_queue_dut_sv`. Every row pins one specific stimulus profile, traffic shape, or coverage axis anchored in `rtl/sv_ver/ordered_priority_queue/monolithic_sv/*.sv` and the `opq_prof_*` sequence library.

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| P001 | R | live UVM | `opq_prof_stress_test` | short soak with repeated long frames and credit restoration checks on the 2-lane default build | `wr_hdr==rd_hdr`, `wr_shd==rd_shd`, `wr_hit==rd_hit`, no `ft_drop_*`, `unexplained=0`; `lane_credit_visible` returns to `LANE_FIFO_MAX_CREDIT=1022` between frames |
| P002 | R | live UVM | `opq_prof_lane_skew_test` | sustained two-lane skew using the stress sequence (not the zero-skew bring-up shape) | both lane ledgers close; `cg_frame.pre_gap` skew bin exercised; arbiter `rr_grant` rotates fairly |
| P003 | R | live UVM | `opq_prof_whole_frame_skew_test` | whole-frame skew with alternating active/empty FEB frames to close packet-level cadence under sustained traffic | lane 0 active / lane 1 empty frames interleave; lane 1 still emits legal empty-frame cadence; no `ft_drop_*` |
| P004 | R | live UVM | `opq_prof_missing_empty_frame_test` | uneven per-lane frame-count stress for the active 2-lane harness contract | lane frame counts differ; hit integrity preserved; sparse-frame cadence covered |
| P005 | R | live UVM | `opq_prof_long_soak_test` | longer directed FEB whole-frame soak beyond the short promoted stress run | extended multi-frame residency; `FT_WR_*` counters advance deeper; still zero drops |
| P006 | R | live UVM | `opq_prof_heavy_lane_skew_test` | extends the skew-gap envelope beyond the promoted stress pair while keeping zero-drop accounting | deeper `cg_frame.pre_gap` bins hit; DRR onehot invariant never violated |
| P007 | R | live UVM | `opq_prof_deep_whole_frame_skew_test` | whole-frame skew chain with deeper residency and reduced subheader density | long-lived tickets retire in order; presenter meta table wrap exercised |
| P008 | R | live UVM | `opq_prof_asymmetric_missing_empty_frame_test` | explicitly uneven 2-lane frame counts instead of relying on 4-lane-only default sequence asymmetry | per-lane ledger closes with asymmetric `FT_WR_HDR`; cross-lane interleave bin saturated |

# Canonical Planned Cases (P009-P129)

| case_id | method | implementation | legacy alias | scenario | primary checks |
|---|---|---|---|---|---|
| P009 | R | live UVM | none | seed-axis stress: `opq_prof_stress_test` shape with seed `0x0001` | run closes with `unexplained=0`; per-seed UCDB emitted for merge; catches seed-dependent scoreboard corner |
| P010 | R | live UVM | none | seed-axis stress: same shape with seed `0x0002` | orthogonal seed; per-lane `drr_grant_cnt` matches frame count; catches grant double-count on different phase |
| P011 | R | live UVM | none | seed-axis stress: seed `0x0003` | orthogonal seed; `lane_credit_visible` snapshot captured mid-run; catches credit freeze under seed drift |
| P012 | R | live UVM | none | seed-axis stress: seed `0x0004` | orthogonal seed; `ticket_credit_visible` snapshot captured mid-run; catches ticket credit latch leak |
| P013 | R | live UVM | none | seed-axis stress: seed `0x0005` | orthogonal seed; `drr_beat_cnt` matches subheader+hit beats written; catches DRR beat miscount under random shape |
| P014 | R | live UVM | none | seed-axis stress: seed `0x0006` with 30% ingress gap randomization | ingress-gap bin saturated; presenter `EGRESS_DELAY=3` latency measured; catches pipeline bubble on irregular ingress |
| P015 | R | live UVM | none | seed-axis stress: seed `0x0007` with randomized subheader density 1..8 per frame | mixed subheader density bin exercised; `wr_shd` counter accurate at each density; catches subheader underflow on random density |
| P016 | R | live UVM | none | seed-axis stress: seed `0x0008` with randomized hit count 0..255 per subheader | zero-hit / max-hit histogram populated; `wr_hit=rd_hit` holds; catches hit accounting drift under random hit counts |
| P017 | R | live UVM | none | long soak: 2-lane uniform traffic, seed `0x0010`, 256 frames per lane, dense subheader shape | end-of-run ledger closes exact; `FT_WR_HDR delta = 512`; catches accumulation regression across 512-frame window |
| P018 | R | live UVM | none | long soak: 2-lane uniform traffic, seed `0x0011`, 1024 frames per lane, mixed density | extended run; per-lane `drr_defer_cnt` stays 0 on healthy path; catches spurious defer under long traffic |
| P019 | R | live UVM | none | long soak: 2-lane traffic with checkpoint UCDB at `256`, `512`, `1024`, `2048`, `4096` frames | log-spaced evidence pages; coverage growth curve captured; catches bins that saturate only at deep txn counts |
| P020 | R | live UVM | none | long soak: 2-lane traffic with 4096 frames per lane, `opq_csr_sva` / `opq_drr_sva` / `opq_avst_*_sva` all armed throughout | no SVA fires across the long run; catches rare invariant violation under long traffic |
| P021 | R | live UVM | none | throughput profile: 2-lane back-to-back frames with zero inter-frame gap on both lanes | sustained throughput measured; arbiter never stalls; catches arbiter gap regression |
| P022 | R | live UVM | none | throughput profile: 2-lane back-to-back frames, one lane with double subheader density | throughput imbalance ok; DRR quantum pacing kicks in (`QUANTUM_PER_SUBFRAME=256`); catches quantum miss |
| P023 | R | live UVM | none | throughput profile: 2-lane back-to-back frames, asymmetric hit counts (lane 0 dense, lane 1 sparse) | both lanes retire; no presenter stall; catches presenter meta table pressure under asymmetric frames |
| P024 | R | live UVM | none | throughput profile: 2-lane back-to-back frames with egress ready=100% for 4096 beats | presenter never engages `resident_backpressure_hold`; catches false hold under sustained ready-high |
| P025 | R | live UVM | none | throughput profile: sustained 4-beat header followed by 256-beat body, repeated without gap | frame closure cadence stable; `EGRESS_DELAY=3` respected; catches bubble insertion between tight-pack frames |
| P026 | R | live UVM | none | lane-skew profile: lane 0 starts at cycle 0, lane 1 starts at cycle 16 | skew gap bin exercised; both lanes retire in correct interleave order; catches lane-mix ordering regression |
| P027 | R | live UVM | none | lane-skew profile: lane 0 starts at cycle 0, lane 1 starts at cycle 64 | deeper skew gap; `drr_grant_cnt` rotation still fair; catches starvation on delayed lane |
| P028 | R | live UVM | none | lane-skew profile: lane 0 starts at cycle 0, lane 1 starts at cycle 256 | skew exceeds one frame length; lane 1 joins mid-run without disrupting lane 0 retirement |
| P029 | R | live UVM | none | lane-skew profile: lane 0 starts at cycle 0, lane 1 starts at cycle 1024 | very deep skew; lane 0 completes multiple frames before lane 1 begins; catches cross-lane latching bug |
| P030 | R | live UVM | none | lane-skew profile: lane-start order reversed (lane 1 first, lane 0 delayed) | mirror skew; catches lane-0 bias in arbiter or credit accounting |
| P031 | R | live UVM | none | whole-frame skew: lane 0 emits all-frames-active while lane 1 emits all-frames-empty | empty-frame cadence covered; lane 1 `FT_WR_HDR` increments without `FT_WR_HIT`; catches empty-lane ledger pollution |
| P032 | R | live UVM | none | whole-frame skew: lane 0 emits active / lane 1 emits empty alternating per frame | alternation bin saturated; catches cadence sync bug between lanes |
| P033 | R | live UVM | none | whole-frame skew: lane 0 emits two active then one empty / lane 1 opposite | 3-frame period cadence covered; catches periodic framing regression |
| P034 | R | live UVM | none | missing-empty-frame: lane 0 emits N frames, lane 1 emits N-1 frames (lagging by one) | asymmetric `FT_WR_HDR`; both lanes retire in correct order; catches frame-count mismatch handling |
| P035 | R | live UVM | none | missing-empty-frame: lane 0 emits N frames, lane 1 emits N-2 frames | larger asymmetry; catches cross-lane ledger regression at deeper delta |
| P036 | R | live UVM | none | missing-empty-frame: lane 0 emits N frames, lane 1 emits only the first frame | extreme asymmetry; lane 1 goes silent after frame 1; catches silent-lane ledger drift |
| P037 | R | live UVM | none | missing-empty-frame: lane 0 goes silent after N-1 frames, lane 1 continues | mirror of P036; catches silent-lane bias toward one lane |
| P038 | R | live UVM | none | sustained rate profile: 2-lane traffic with 50% subheader density (half subheaders are zero-hit) | zero-hit subheader count matches injected count; catches zero-hit subheader dropped in body-count |
| P039 | R | live UVM | none | sustained rate profile: 2-lane traffic with 75% subheader density | denser subheaders; `wr_shd` / `rd_shd` delta accurate; catches subheader overrun in presenter |
| P040 | R | live UVM | none | sustained rate profile: 2-lane traffic with 25% subheader density | sparse subheaders; long body with few subheader boundaries; catches body-only traffic regression |
| P041 | R | live UVM | none | sustained rate profile: 2-lane with random ingress beat gap 0..4 cycles | irregular ingress; lane FIFO usage bounded; catches lane FIFO under-fill regression |
| P042 | R | live UVM | none | sustained rate profile: 2-lane with random ingress beat gap 0..16 cycles | wider gap range; credit restoration correct; catches credit freeze on sparse ingress |
| P043 | R | live UVM | none | sustained rate profile: 2-lane with random ingress beat gap 0..64 cycles | very sparse ingress; lane FIFO often empty; catches idle-path regression |
| P044 | R | live UVM | none | sustained rate profile: 2-lane with burst ingress (32-beat bursts, 32-cycle gaps) | bursty ingress; lane FIFO approaches `LANE_FIFO_MAX_CREDIT`; catches credit accounting under bursts |
| P045 | R | live UVM | none | sustained rate profile: 2-lane with burst ingress (256-beat bursts, 128-cycle gaps) | deeper bursts; lane FIFO approaches full; catches lane FIFO overrun on burst-end |
| P046 | R | live UVM | none | sustained rate profile: 2-lane with 64-beat body bursts, random density | burst+density cross exercised; catches burst-density interaction regression |
| P047 | R | live UVM | none | sustained rate profile: 2-lane at stressed DRR pacing (quantum at `QUANTUM_MAX=0x3FF`) | long quantum windows per lane; arbiter rotation slower; catches quantum saturation regression |
| P048 | R | live UVM | none | sustained rate profile: 2-lane at minimum DRR pacing (quantum=1) | very short quantum; arbiter rotation fast; catches yield miss at minimal quantum |
| P049 | R | live UVM | none | sustained rate profile: 2-lane at default DRR pacing (`DRR_DEFAULT_ALLOWANCE=256`) | default pacing verified on stress traffic; catches default quantum regression |
| P050 | R | live UVM | none | credit-snapshot profile: 2-lane stress with periodic `lane_credit_visible` polling every 64 cycles | credit oscillation captured; never stuck at 0 or max; catches credit stuck-high regression |
| P051 | R | live UVM | none | credit-snapshot profile: 2-lane stress with periodic `ticket_credit_visible` polling every 64 cycles | ticket credit oscillation captured; never stuck at 0 or max; catches ticket credit latch |
| P052 | R | live UVM | none | credit-snapshot profile: 2-lane stress with `drr_grant_cnt` delta check every 128 cycles | grant count monotone; delta matches served frames in window; catches grant miscount at poll boundary |
| P053 | R | live UVM | none | credit-snapshot profile: 2-lane stress with `drr_beat_cnt` delta check every 128 cycles | beat count monotone; delta matches moved beats in window; catches beat count stall |
| P054 | R | live UVM | none | credit-snapshot profile: 2-lane stress with all 16 per-lane CSRs polled per 256 cycles | full lane region read; no stale values; catches CSR freeze under stress |
| P055 | R | live UVM | none | latency profile: measure ingress-to-egress latency distribution across 256 frames | median latency matches `EGRESS_DELAY=3` pipeline; tail bounded; catches latency creep |
| P056 | R | live UVM | none | latency profile: measure ingress-to-egress latency with random mid-run backpressure | latency widens under backpressure; bounded by skid buffer depth; catches latency explosion |
| P057 | R | live UVM | none | latency profile: measure arbiter-to-block-mover latency from `ARBITER_LOCKED` entry | latency bounded; catches arbiter-to-mover bubble |
| P058 | R | live UVM | none | latency profile: measure page-allocator handle-request to handle-grant latency | allocator latency bounded; catches allocator stall |
| P059 | R | live UVM | none | latency profile: measure ticket-enqueue to basic-presenter `WAIT_FOR_COMPLETE` entry latency | ticket-to-presenter latency bounded; catches ticket FIFO stall |
| P060 | R | live UVM | none | ingress-shape variety: 2-lane with each lane using a different subheader density profile | cross-lane shape diversity; catches shape-specific regression |
| P061 | R | live UVM | none | ingress-shape variety: 2-lane with each lane using a different ingress gap profile | cross-lane gap diversity; catches gap-specific regression |
| P062 | R | live UVM | none | ingress-shape variety: 2-lane with each lane using a different hit count distribution | cross-lane hit count diversity; catches hit count distribution bias |
| P063 | R | live UVM | none | ingress-shape variety: 2-lane with randomized per-frame ingress start phase (0..15 cycles) | arbitrary sub-cycle alignment; catches alignment-sensitive regression |
| P064 | R | live UVM | none | framing-shape variety: variable `pkg_cnt` and `send_ts` per frame drawn from a uniform distribution | `TICKET_FEB_ID` / `TICKET_FRAME_TS` carry injected values unchanged; catches field corruption under randomized header |
| P065 | R | live UVM | none | framing-shape variety: variable `running_shd_cnt` per frame | `TICKET_N_SUBH` matches promise; catches subheader promise mismatch |
| P066 | R | live UVM | none | framing-shape variety: variable `hit_cnt` per frame (up to `N_HIT=255`) | `TICKET_N_HIT` matches promise; catches hit promise mismatch |
| P067 | R | live UVM | none | framing-shape variety: random `DT_TYPE` field per frame | `TICKET_DT_TYPE` round-trips; catches DT type swap |
| P068 | R | live UVM | none | framing-shape variety: random `frame_ts_base` per frame exercising low and high TS values | TS reconstruction correct at both boundaries; catches TS reconstruction regression under randomized base |
| P069 | R | live UVM | none | framing-shape variety: random `running_ts` advancing monotonically across frames | TS monotonicity check; catches TS freeze or inversion |
| P070 | R | live UVM | none | framing-shape variety: random subheader TS bytes, some wrap, some no-wrap | both `extend_subheader_ts` branches exercised; catches branch bias |
| P071 | R | live UVM | none | long soak: 2-lane stress with checkpoint UCDB and `resident_hold` coverage sampled every 128 cycles | hold engagement rate sampled; catches hold firing on wrong threshold |
| P072 | R | live UVM | none | long soak: 2-lane stress with egress ready profile randomly toggled (50% duty) | `resident_hold` engages frequently; skid buffer exercised; catches skid regression on long duty |
| P073 | R | live UVM | none | long soak: 2-lane stress with egress ready profile at 75% duty | moderate stall; catches duty-dependent latency creep |
| P074 | R | live UVM | none | long soak: 2-lane stress with egress ready profile at 25% duty | heavy stall; `resident_hold` sustained; catches hold-release regression |
| P075 | R | live UVM | none | long soak: 2-lane stress with egress ready toggled per cycle (alternate 0/1) | skid buffer fires every cycle; catches skid duplicate on alternation |
| P076 | R | live UVM | none | long soak: 2-lane stress with egress ready held low for `EGRESS_DELAY=3` cycles at random times | pipeline exactly filled then drained; catches off-by-one at pipeline depth |
| P077 | R | live UVM | none | long soak: 2-lane stress with egress ready held low for `EGRESS_DELAY+1=4` cycles | skid buffer overrun-candidate; catches skid overrun |
| P078 | R | live UVM | none | long soak: 2-lane stress with egress ready held low for 16 cycles at random points | sustained hold; release clean; catches stuck hold on deep stall |
| P079 | R | live UVM | none | long soak: 2-lane stress with egress ready held low for 128 cycles (deep stall) | very deep hold; catches hold timeout regression |
| P080 | R | live UVM | none | long soak: 2-lane stress with egress ready held low for 1024 cycles | near-stuck low; catches stuck-low regression |
| P081 | R | live UVM | none | bucket-frame soak: concatenate BASIC bucket traffic (B001-B007-equivalent shapes) without restart | case-boundary cleanup observed; no state carry between cases; catches cross-case pollution |
| P082 | R | live UVM | none | bucket-frame soak: concatenate EDGE bucket traffic without restart | edge corners composed in one continuous run; catches cross-case carry |
| P083 | R | live UVM | none | bucket-frame soak: concatenate PROF bucket promoted shapes without restart | promoted stress shapes chained; catches restart-dependent regression |
| P084 | R | live UVM | none | bucket-frame soak: concatenate BASIC → EDGE in order without restart | full-stack composition; catches bucket transition regression |
| P085 | R | live UVM | none | bucket-frame soak: concatenate BASIC → EDGE → PROF in order without restart | three-bucket chain; catches deep carry between buckets |
| P086 | R | live UVM | none | bucket-frame soak: full 4-bucket chain (BASIC → EDGE → PROF → ERROR safe shapes) | full all-buckets chain; catches cross-bucket state leak |
| P087 | R | live UVM | none | randomized bucket-mix: random selection of BASIC/EDGE/PROF shapes per window | mixed traffic across a run; catches schedule-dependent regression |
| P088 | R | live UVM | none | randomized bucket-mix: same but with random inter-window gap [0..256] cycles | idle-gap insensitivity; catches idle-length bias |
| P089 | R | live UVM | none | randomized bucket-mix: same but with random window length [1..4] frames | variable window sizing; catches window-length bias |
| P090 | R | live UVM | none | randomized bucket-mix: shape selection biased to overwrite-light regimes | stays in healthy no-drop path; catches drop leak on bias |
| P091 | R | live UVM | none | stress re-run variant: `opq_prof_stress_test` with `+TB_CLK_PERIOD_NS=500` (slow clock) | timing-insensitive invariants hold; catches clock-period-dependent regression |
| P092 | R | live UVM | none | stress re-run variant: `opq_prof_stress_test` with `+TB_CLK_PERIOD_NS=2000` | very slow clock; catches metastability-like issues only visible at long periods (simulation-only) |
| P093 | R | live UVM | none | stress re-run variant: `opq_prof_stress_test` with `+OPQ_MIXED_SOAK_STEPS=32` | longer mixed-soak override; catches step-count-dependent regression |
| P094 | R | live UVM | none | stress re-run variant: `opq_prof_stress_test` with `+OPQ_MIXED_SOAK_STEPS=64` | even longer mixed-soak; catches deep-chain regression |
| P095 | R | live UVM | none | stress re-run variant: `opq_prof_stress_test` with `+DV_LONG_TXN_OVERRIDE=2` reduced-txn override | fast regression mode; catches override-dependent regression |
| P096 | R | live UVM | none | DRR reprogramming profile: programmed allowance cycled through {1, 64, 128, 256, 512, 0x3FF} across a run | all allowance values exercised; `drr_quantum` mirror correct; catches reprogramming race |
| P097 | R | live UVM | none | DRR reprogramming profile: allowance randomized every 64 cycles | very frequent reprogramming; reload path exercised; catches reload pulse miss |
| P098 | R | live UVM | none | DRR reprogramming profile: zero-allowance on lane 0 for 256 cycles, then reload to default | defer count advances then lane resumes; `drr_defer_cnt` delta matches forced defers; catches defer miscount |
| P099 | R | live UVM | none | DRR reprogramming profile: zero-allowance on lane 1 for 256 cycles, then reload | mirror of P098; catches lane-0 bias in defer path |
| P100 | R | live UVM | none | LANE_MASK reprogramming profile: mask lane 0 mid-run for 128 cycles then unmask | lane 0 silent during mask window; `STATUS[19]` transitions correctly; catches mask not reaching parser |
| P101 | R | live UVM | none | LANE_MASK reprogramming profile: mask lane 1 mid-run for 128 cycles then unmask | mirror of P100; catches mask-bit lane swap |
| P102 | R | live UVM | none | LANE_MASK reprogramming profile: toggle LANE_MASK every 64 cycles across a run | frequent mask toggles; catches transient leak when mask changes |
| P103 | R | live UVM | none | LANE_MASK reprogramming profile: mask all lanes for 256 cycles then release | `STATUS[19]` = 0 during mask; resumes on release; catches stuck-masked regression |
| P104 | R | live UVM | none | CTRL soft-reset profile: issue `soft_reset_request` every 4096 cycles, verify self-clear | bit[0] self-clears within one cycle; subsequent traffic unaffected; catches stuck soft-reset |
| P105 | R | live UVM | none | STATUS polling profile: read STATUS every 16 cycles during sustained traffic | bits[16]/[17]/[18]/[19] track ground truth; catches stale STATUS latch |
| P106 | R | live UVM | none | CSR burst profile: read all 16 per-lane CSRs back-to-back during steady state | burst completes within N cycles; no waitrequest hang; catches CSR burst stall |
| P107 | R | live UVM | none | CSR burst profile: read all global CSRs 0x000-0x010 back-to-back during steady state | global burst completes; catches global CSR burst stall |
| P108 | R | live UVM | none | CSR burst profile: interleaved per-lane reads and global reads (e.g. L0+0x00, 0x008, L1+0x00, 0x008) | interleave completes; catches CSR address decode regression on mixed reads |
| P109 | R | live UVM | none | frame-table ledger invariants: `FT_WR_HDR - FT_RD_HDR - FT_DROP_HDR = 0` at quiescence | invariant holds on every P0xx run; catches counter drift |
| P110 | R | live UVM | none | frame-table ledger invariants: `FT_WR_SHD - FT_RD_SHD - FT_DROP_SHD = 0` at quiescence | invariant holds; catches subheader counter drift |
| P111 | R | live UVM | none | frame-table ledger invariants: `FT_WR_HIT - FT_RD_HIT - FT_DROP_HIT = 0` at quiescence | invariant holds; catches hit counter drift |
| P112 | R | live UVM | none | ingress noise profile: injection of spurious non-K-char bytes on data[7:0] with datak=0 | parser stays in `INGRESS_PARSER_IDLE`; `wr_hdr` flat; catches false preamble on noise |
| P113 | R | live UVM | none | ingress noise profile: injection of K285/K237/K284 with datak=0 (data-valued K-chars) | parser ignores data-valued K-chars; catches datak-unaware decode |
| P114 | R | live UVM | none | ingress noise profile: 50% noise + 50% real K-chars with correct datak | only real K-chars parsed; noise drops silently; catches noise-induced mis-classification |
| P115 | R | live UVM | none | egress noise profile: downstream ready randomly toggled at full rate | skid buffer fires per toggle; no beat lost; catches skid regression on full-rate toggle |
| P116 | R | live UVM | none | long soak: 2-lane traffic with periodic TERMINATE simulation (cycle between runs every 8192 cycles) | run-boundary cleanup verified; catches run-boundary state leak |
| P117 | R | live UVM | none | long soak: 2-lane traffic with periodic CTRL[0]=1 pulses every 4096 cycles | soft-reset bursts; traffic resumes cleanly; catches soft-reset induced ledger regression |
| P118 | R | live UVM | none | long soak: 2-lane traffic with periodic LANE_MASK toggles every 2048 cycles | mask bursts; traffic adapts; catches mask-induced transient regression |
| P119 | R | live UVM | none | long soak: 2-lane traffic with periodic DRR_ALLOWANCE reprogramming every 1024 cycles | quantum reprogramming bursts; catches reprogramming accumulation regression |
| P120 | R | live UVM | none | long soak: 2-lane traffic with combined LANE_MASK + DRR reprogramming every 2048 cycles | mixed CSR stress; catches CSR interaction regression |
| P121 | R | live UVM | none | long soak: 4096 frames per lane with `opq_prof_long_soak_test` shape and seed `0x0100` | deep soak reference; catches slow-saturating coverage bin regression |
| P122 | R | live UVM | none | long soak: 8192 frames per lane with seed `0x0200` | very deep soak; catches bins that only saturate past 4k frames |
| P123 | R | live UVM | none | long soak: 16384 frames per lane with seed `0x0300` | even deeper; catches deepest bins; 10+ minute simtime |
| P124 | R | live UVM | none | long-simtime profile: `+TB_CLK_PERIOD_NS=1000000` with 256 frames | stretched simtime covers timing-insensitive corners; catches wall-time regression |
| P125 | R | live UVM | none | long-simtime profile: `+TB_CLK_PERIOD_NS=250` with `opq_prof_stress_test` chained many times | extended run with chained traffic; catches long-chain regression |
| P126 | R | planned (variant-only) | none | 4-lane variant profile: `OPQ_N_LANE=4` stress traffic across all lanes | 4-lane arbiter fairness verified; catches `OPQ_N_LANE=4` build regression |
| P127 | R | live UVM | `opq_prof_per_lane_half_frame_skew_sweep_test` | 4-lane variant profile: per-lane skew sweep with fixed spreads stepping from 0 to half of the frame time | all four lane ledgers close across the 0..half-frame sweep; 4-lane skew/cadence bins advance; catches delayed-lane ordering regression on the active 4-lane build |
| P128 | R | planned (variant-only) | none | wider page-RAM variant: `OPQ_PAGE_RAM_DEPTH=131072` with deep residency | wider page-RAM exercised; catches page-RAM width regression |
| P129 | R | planned (variant-only) | none | deeper ticket-FIFO variant: `OPQ_TICKET_FIFO_DEPTH=512` with high-frame-rate traffic | deeper ticket FIFO exercised; catches FIFO depth regression |

---

## Coverage Intent

These rows are the primary owners for:

- longer multi-frame residency and `cg_frame.pre_gap` skew-gap bins
- whole-frame activity/inactivity cadence bins (`opq_prof_whole_frame_skew_test` family)
- credit snapshot sampling under sustained traffic (`lane_credit_visible`, `ticket_credit_visible`)
- DRR telemetry (`drr_grant_cnt`, `drr_beat_cnt`, `drr_defer_cnt`) under long soaks
- seed-axis diversity via orthogonal LCG seeds
- randomized CSR reprogramming (LANE_MASK, DRR_ALLOWANCE, CTRL) during active traffic
- long-simtime and long-txn soaks

## Still Relevant Legacy Backlog

- deeper soak lengths beyond `16384` frames per lane
- higher-pressure burst asymmetry once the sustained-pressure arbiter path is further characterized
- larger parameter-space sweeps once the `OPQ_N_LANE > 2` build and `OPQ_PAGE_RAM_DEPTH > 65536` variants land

## Regenerate

After editing, rerun:

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb .
```

Keep `P###` IDs contiguous from `001` to `129`; do not reuse numbers across rewrites.

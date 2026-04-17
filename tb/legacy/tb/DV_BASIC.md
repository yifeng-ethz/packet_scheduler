# DV Bucket: DV_BASIC -- ordered_priority_queue (monolithic)

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md)
**Bucket prefix:** B    **ID range:** B001..B136    **Minimum cases:** 128
**DUT RTL:** `packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-13
**Status:** planned (awaiting chief-architect signoff per `dv-workflow`)

---

## 1. Scope

DV_BASIC is the **bring-up spine** for the monolithic `ordered_priority_queue` core. Every case here is a single directed, healthy-path scenario: one packet shape, one config row, one FSM path to exercise, and the egress always-ready backpressure profile (`ALWAYS_READY`). The bucket proves that, given well-formed Avalon-ST ingress and no flow-control pressure, the DUT correctly decodes, stores, aggregates, and emits DAQ frames across every reachable FSM state and every in-spec generic value. The goal is **100 % reachability** of all non-error FSM states, all `cov_cfg` bins except the flow-control ones, and the healthy variants of the packet-shape bins in `cov_pkt`.

**Bright line against later buckets.** DV_BASIC deliberately stays inside the healthy envelope:

- FIFO full / empty edges and segment-rotation boundaries -> **DV_EDGE** (E-series)
- Lane skew other than zero -> **DV_EDGE / DV_PROF**
- Any backpressure profile other than `ALWAYS_READY` -> **DV_PROF** (P-series, includes F1 RESTART)
- `hit_err` / `shd_err` / `hdr_err` injection, truncation, missing EOP, drop-on-full, reset-in-state -> **DV_ERROR** (X-series)
- Multi-axis scenarios that simultaneously hit `FSM x BP x skew x err` cells -> **DV_CROSS** (C-series)

A case that drifts across the line must be moved to the correct bucket. The coverage handoff in sec 5 lists every bin DV_BASIC does **not** close.

---

## 2. Configuration groups

Each case's `Config` column refers to one of the tagged rows below. Parameters not listed take the `_hw.tcl` default. All rows use `HDR_SIZE=5`, `SHD_SIZE=1`, `HIT_SIZE=1`, `TRL_SIZE=1`, `FRAME_SERIAL_SIZE=16`, `FRAME_SUBH_CNT_SIZE=16`, `FRAME_HIT_CNT_SIZE=16` unless stated.

| Tag | MODE | N_LANE | TRACK_HEADER | INGRESS_DATA_WIDTH | INGRESS_DATAK_WIDTH | CHANNEL_WIDTH | LANE_FIFO_DEPTH | LANE_FIFO_WIDTH | TICKET_FIFO_DEPTH | HANDLE_FIFO_DEPTH | PAGE_RAM_DEPTH | PAGE_RAM_RD_WIDTH | N_SHD | N_HIT | DEBUG_LV | Notes |
|-----|------|--------|--------------|--------------------|---------------------|---------------|-----------------|-----------------|-------------------|-------------------|----------------|-------------------|-------|-------|----------|-------|
| CFG_A | MERGING | 4  | true  | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | 256 | 255  | 1 | **Default nightly regression row (DV_HARNESS sec 2).** |
| CFG_B | MERGING | 1  | true  | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | 256 | 255  | 1 | Single-lane reference. |
| CFG_C | MERGING | 2  | true  | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | 256 | 255  | 1 | Two-lane minimum merge. |
| CFG_D | MERGING | 8  | true  | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | 256 | 255  | 1 | Mid-width multi-lane. |
| CFG_E | MERGING | 16 | true  | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | 256 | 255  | 1 | Max `N_LANE`. |
| CFG_F | MULTIPLEXING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Multiplex mode at default width. |
| CFG_G | MULTIPLEXING | 1 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Single-lane multiplex (degenerate round-robin). |
| CFG_H | MULTIPLEXING | 8 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Mid multiplex. |
| CFG_I | MULTIPLEXING | 16 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Max multiplex. |
| CFG_J | MERGING | 4 | **false** | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | TRACK_HEADER=off; `ftable_tracker` stays in IDLE. |
| CFG_K | MERGING | 4 | true | 32 | 4 | **0** | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Channel width 0 (port collapses). |
| CFG_L | MERGING | 4 | true | 32 | 4 | **1** | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Channel width 1. |
| CFG_M | MERGING | 4 | true | 32 | 4 | **3** | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Channel width 3. |
| CFG_N | MERGING | 4 | true | 32 | 4 | **4** | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Channel width 4 (max). |
| CFG_O | MERGING | 4 | true | **64**  | **8**  | 2 | 1024 | 72  | 64 | 64 | 65536 | 72  | 256 | 255 | 1 | 64/8 ingress; 2-symbol egress beat. |
| CFG_P | MERGING | 4 | true | **96**  | **12** | 2 | 1024 | 108 | 64 | 64 | 65536 | 108 | 256 | 255 | 1 | 96/12 ingress. |
| CFG_Q | MERGING | 4 | true | **128** | **16** | 2 | 1024 | 144 | 64 | 64 | 65536 | 144 | 256 | 255 | 1 | Max ingress beat. |
| CFG_R | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **72**  | 256 | 255 | 1 | symbolsPerBeat=2. |
| CFG_S | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **108** | 256 | 255 | 1 | symbolsPerBeat=3. |
| CFG_T | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **144** | 256 | 255 | 1 | symbolsPerBeat=4. |
| CFG_U | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **180** | 256 | 255 | 1 | symbolsPerBeat=5. |
| CFG_V | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **216** | 256 | 255 | 1 | symbolsPerBeat=6. |
| CFG_W | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **252** | 256 | 255 | 1 | symbolsPerBeat=7. |
| CFG_X | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | **288** | 256 | 255 | 1 | symbolsPerBeat=8 (max). |
| CFG_Y | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | **128** | 255  | 1 | Min `N_SHD`. |
| CFG_Z | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36  | **512** | 255  | 1 | Max `N_SHD`. |
| CFG_AA | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | **511**  | 1 | `N_HIT`=511. |
| CFG_AB | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | **1023** | 1 | `N_HIT`=1023. |
| CFG_AC | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | **2047** | 1 | Max `N_HIT`. |
| CFG_AD | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | **8192**  | 36 | 256 | 255 | 1 | Min `PAGE_RAM_DEPTH`. |
| CFG_AE | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | **16384** | 36 | 256 | 255 | 1 | Page RAM 16 k. |
| CFG_AF | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | **32768** | 36 | 256 | 255 | 1 | Page RAM 32 k. |
| CFG_AG | MERGING | 4 | true | 32 | 4 | 2 | **16** | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Min lane FIFO (tests depth plumbing only; no pressure). |
| CFG_AH | MERGING | 4 | true | 32 | 4 | 2 | **256** | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Lane FIFO 256. |
| CFG_AI | MERGING | 4 | true | 32 | 4 | 2 | **4096** | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Lane FIFO 4k. |
| CFG_AJ | MERGING | 4 | true | 32 | 4 | 2 | **65536** | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Max lane FIFO. |
| CFG_AK | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | **2**  | 64 | 65536 | 36 | 256 | 255 | 1 | Min `TICKET_FIFO_DEPTH`. |
| CFG_AL | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | **256** | 64 | 65536 | 36 | 256 | 255 | 1 | Max `TICKET_FIFO_DEPTH`. |
| CFG_AM | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | **2** | 65536 | 36 | 256 | 255 | 1 | Min `HANDLE_FIFO_DEPTH`. |
| CFG_AN | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | **256** | 65536 | 36 | 256 | 255 | 1 | Max `HANDLE_FIFO_DEPTH`. |
| CFG_AO | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | **0** | `DEBUG_LV`=0 (non-debug build). |
| CFG_AP | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | **2** | `DEBUG_LV`=2 (full debug + overwrite log). |
| CFG_AQ | MERGING | 4 | true | 32 | 4 | 2 | 1024 | **48** | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Lane FIFO width 48 (extra tag bits). |
| CFG_AR | MERGING | 4 | true | 32 | 4 | 2 | 1024 | **64** | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Lane FIFO width 64. |
| CFG_AS | MERGING | 4 | true | 32 | 4 | 2 | 1024 | **80** | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Lane FIFO width 80. |
| CFG_AT | MERGING | 1 | false | 32 | 4 | 0 | 1024 | 40 | 64 | 64 | 65536 | 36 | 128 | 255 | 1 | Absolute minimum footprint config. |
| CFG_AU | MERGING | 4 | true | 32 | 4 | 2 | 1024 | 40 | 64 | 64 | 65536 | 36 | 256 | 255 | 1 | Alias of CFG_A with FRAME_SERIAL_SIZE stress. |

CFG_AU exists so parametric cases that only twist the `FRAME_*_SIZE` generics do not churn the default row.

---

## 3. Test Case Catalog

All rows share these conventions: egress agent drives `ALWAYS_READY` (backpressure profile with `ready` permanently asserted); ingress lane skew is **zero beats** (all lanes start SOP on the same cycle); no error injection; no truncation; one transaction per case unless stated. The "Covers" column lists the specific `cov_*` bins the case is expected to close. "RTL path / rationale" names the sub-block and the concrete control flow being exercised.

### 3.1 Bring-up spine (B001..B012)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B001_reset_idle_state | CFG_A | Assert `d_reset`, hold 16 d_clk, release. No ingress traffic. | All 7 FSMs land and stay in IDLE; `aso_egress_valid=0`; lane/ticket/handle FIFO levels = 0; `running_ts=0`, `frame_ts=0`. | `cov_fsm.ingress_parser[*].IDLE`, `cov_fsm.page_allocator.IDLE`, `cov_fsm.block_mover[*].IDLE`, `cov_fsm.arbiter.IDLE`, `cov_fsm.ftable_mapper.IDLE`, `cov_fsm.ftable_tracker.IDLE`, `cov_fsm.ftable_presenter.IDLE` | Verifies every FSM's RESET -> IDLE edge and the default register load. Catches any FSM that powers up in a non-IDLE state, which would cause ghost writes into page RAM on the first real transaction. Baseline for all subsequent cases. | planned |
| B002_reset_then_first_sop | CFG_A | Reset, wait 8 cycles, drive exactly one header-only packet (HDR_SIZE=5 words) on lane 0 (others idle -- will park allocator in FETCH_TICKET). | `ingress_parser[0]`: IDLE->UPDATE_HEADER_TS->IDLE. Ticket FIFO receives exactly 1 SOP ticket. `page_allocator` steps IDLE->FETCH_TICKET and **stays** there (F7: needs all lanes to have SOP). No egress. | `cov_fsm.ingress_parser[0].UPDATE_HEADER_TS`, `cov_fsm.page_allocator.FETCH_TICKET` | Drives only the header-decode path of `ingress_parser` and proves that `page_allocator.FETCH_TICKET` blocks on missing lane SOPs (F7). Catches a decode that spuriously advances the allocator. | planned |
| B003_single_lane_header_all_lanes | CFG_A | Reset, then simultaneously drive a header-only packet on **all 4 lanes** (zero skew, zero hits). | All four `ingress_parser` lanes walk IDLE->UPDATE_HEADER_TS->IDLE. `page_allocator` runs FETCH_TICKET->WRITE_HEAD->ALLOC_PAGE->WRITE_PAGE->FETCH_TICKET. `ftable_mapper` visits PREP_UPDATE->UPDATE_FRAME_TABLE->IDLE. `ftable_presenter` visits WAIT_FOR_COMPLETE->VERIFY->PRESENTING->IDLE. Egress emits one ordered packet carrying the header. | `cov_fsm.page_allocator.{WRITE_HEAD,ALLOC_PAGE,WRITE_PAGE}`, `cov_fsm.ftable_mapper.{PREP_UPDATE,UPDATE_FRAME_TABLE}`, `cov_fsm.ftable_presenter.{WAIT_FOR_COMPLETE,VERIFY,PRESENTING}` | First end-to-end bring-up: the all-lane-SOP re-sync gate releases, the allocator crosses its full linear happy-path, the frame-table mapper records a header entry, and the presenter evaluates and emits. This is the minimum path that touches every major sub-block. | planned |
| B004_hdr_then_one_subh_zero_hits | CFG_A | Header + 1 subheader with `hit_cnt=0` on every lane. | `ingress_parser[*]` enters WR_HITS and immediately returns to IDLE through the zero-iteration loop. Scoreboard sees one subheader ticket per lane; egress emits HDR + 1 empty SHD. | `cov_fsm.ingress_parser[*].WR_HITS`, `cov_pkt.hits_per_subh[0]`, `cov_pkt.subh_per_hdr[1]` | Exercises `ingress_parser.WR_HITS` zero-iteration loop exit -> `page_allocator.FETCH_TICKET` with zero-length handle -> `block_mover.PREP` -> `block_mover.WRITE_BLK` length-0 path. Catches an off-by-one in the hit counter that would publish a stray hit word. | planned |
| B005_hdr_then_one_subh_one_hit | CFG_A | Header + 1 subheader with `hit_cnt=1`. | Egress emits HDR + SHD + 1 hit word; hit payload bit-exact equal to ingress. | `cov_pkt.hits_per_subh[1]` | Minimum non-trivial hit loop; verifies the `WR_HITS` increment-and-compare. Catches a decrement-before-use bug. | planned |
| B006_hdr_then_one_subh_two_hits | CFG_A | Header + 1 subheader with `hit_cnt=2`. | Egress emits HDR + SHD + 2 hits in order. | `cov_pkt.hits_per_subh[2]` | Proves the hit loop iterates at least twice; catches a single-beat latch that freezes on hit[0]. | planned |
| B007_hdr_then_two_subh_single_hit_each | CFG_A | Header + 2 subheaders, 1 hit each. | Two subheader tickets per lane; `page_allocator` cycles FETCH_TICKET->WRITE_PAGE twice before `WRITE_TAIL`. | `cov_pkt.subh_per_hdr[2]`, `cov_fsm.page_allocator.WRITE_PAGE` (repeat count) | Verifies that `page_allocator` returns to `FETCH_TICKET` cleanly after a non-final subheader and does **not** prematurely transition to `WRITE_TAIL`. Catches a sticky `is_last_subh` flag. | planned |
| B008_hdr_then_trailer_only | CFG_A | Header, no subheaders, then an explicit frame trailer word (TRL_SIZE=1). | `ingress_parser[*]` visits UPDATE_HEADER_TS -> IDLE and the trailer ticket drives `page_allocator.WRITE_TAIL`. | `cov_fsm.page_allocator.WRITE_TAIL` | Isolates the WRITE_TAIL path without subheader traffic. Catches a WRITE_TAIL that depends on having seen at least one subheader (a common latch pitfall). | planned |
| B009_first_frame_short_reset_sync | CFG_A | Release reset, then within 8 cycles drive HDR + 1 SHD + 1 hit on all lanes. | `running_ts` is overwritten with `frame_ts` at the all-lane SOP gate (F4). Scoreboard's expected timestamps must match the re-synced value. | `cov_pkt.first_frame_short`, `cov_fsm.page_allocator.FETCH_TICKET` (F4 transition) | Exercises the F4 healthy path: `page_allocator` absorbs the reset-induced drift by loading `running_ts <= frame_ts` at the gate. Catches a missing `running_ts` load that would produce wrong expected timestamps on every subsequent frame. | planned |
| B010_header_ts_capture_low_frame_ts | CFG_A | HDR with `frame_ts=0x0000_0000_0001` on all lanes; 1 SHD, 1 hit. | `frame_ts` register advances to 0x1 **after** the header + trailer has been written (F3). Scoreboard expected ts matches. | `cov_pkt.shd_ts_pattern[0x01]`, F3 probe check | Verifies F3 healthy path: `frame_ts` advance is gated on the full header being in page RAM. Catches an early advance that would mis-tag the header. | planned |
| B011_header_ts_capture_mid_frame_ts | CFG_A | HDR with `frame_ts=0x0000_1234_5678`; 1 SHD, 1 hit. | Same as B010 with mid-range timestamp. | `cov_pkt.shd_ts_pattern[0x7F]` | Mid-range `frame_ts` proof-point. Catches sign-extension in the 48-bit ts path. | planned |
| B012_header_ts_capture_high_frame_ts | CFG_A | HDR with `frame_ts=0x00FF_FFFF_FFF0`; 1 SHD, 1 hit. | Expected egress ts matches. | `cov_pkt.frame_ts_wrap[low]` | High-range non-wrapping ts. Catches truncation in the 48-bit concat or register width. | planned |

### 3.2 Single-lane happy path (B013..B024)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B013_sl_smallest_packet | CFG_B | HDR + 1 SHD + 1 hit, single lane, single frame. | 1 egress packet, bit-exact hit list. | `cov_cfg.n_lane[1]`, `cov_pkt.subh_per_hdr[1]`, `cov_pkt.hits_per_subh[1]` | Smallest single-lane transaction that still exercises every FSM. In `MERGING` with `N_LANE=1`, the aggregator degenerates to passthrough -- catches an N-way merge that assumes N>=2. | planned |
| B014_sl_two_subh | CFG_B | HDR + 2 SHD + 1 hit each. | 2 subheader egress events. | `cov_pkt.subh_per_hdr[2]` | Proves the subheader loop in a single-lane aggregator. Catches a `page_allocator` that drops subheader 2 when no other lane is contending. | planned |
| B015_sl_eight_subh | CFG_B | HDR + 8 SHD + 1 hit each. | 8 subheader egress events. | `cov_pkt.subh_per_hdr[8]` | Mid-count subheader run. Catches an intermediate sticky flag in the WRITE_PAGE loop. | planned |
| B016_sl_32_subh | CFG_B | HDR + 32 SHD + 1 hit each. | 32 subheader egress events. | `cov_pkt.subh_per_hdr[32]` | Matches `cov_pkt.subh_per_hdr[32]` bin and begins to exercise ticket-fifo backlog within a single header. | planned |
| B017_sl_64_subh | CFG_B | HDR + 64 SHD + 1 hit each. | 64 subheader egress events. | `cov_pkt.subh_per_hdr[64]` | Proof-point for mid-range subheader counts. | planned |
| B018_sl_127_subh | CFG_B | HDR + 127 SHD + 1 hit each. | 127 subheader egress events. | `cov_pkt.subh_per_hdr[127]` | Approaches `N_SHD/2`; catches a comparator mis-aligned between ">= N_SHD/2" and "> N_SHD/2". | planned |
| B019_sl_128_subh | CFG_B | HDR + 128 SHD + 1 hit each. | 128 subheader egress events. | `cov_pkt.subh_per_hdr[128]` | Power-of-two boundary for the ticket counter. | planned |
| B020_sl_nshd_minus_one | CFG_B | HDR + (`N_SHD`-1=255) SHD + 1 hit each. | 255 subheader egress events. | `cov_pkt.subh_per_hdr[N_SHD-1]` | One shy of the hard subheader cap. Catches an off-by-one that would fire the subheader-overflow mask one subheader too early. | planned |
| B021_sl_nshd_full | CFG_B | HDR + `N_SHD` (256) SHD + 1 hit each. | 256 subheader egress events. | `cov_pkt.subh_per_hdr[N_SHD]` | Healthy maximum: exactly `N_SHD` subheaders, no overflow. Catches a ">=" vs ">" flip that would drop the last legal subheader. | planned |
| B022_sl_hit_cnt_4 | CFG_B | HDR + 1 SHD + 4 hits. | 4 hits emitted. | `cov_pkt.hits_per_subh[4]` | Small hit-loop depth bin. | planned |
| B023_sl_hit_cnt_16 | CFG_B | HDR + 1 SHD + 16 hits. | 16 hits. | `cov_pkt.hits_per_subh[16]` | Mid hit-loop. | planned |
| B024_sl_hit_cnt_64 | CFG_B | HDR + 1 SHD + 64 hits. | 64 hits. | `cov_pkt.hits_per_subh[64]` | Mid-large hit-loop. | planned |

### 3.3 Multi-lane MERGING happy path (B025..B040)

All multi-lane cases below drive **zero-skew** ingress (every lane's SOP arrives the same cycle). Skew variants belong to DV_EDGE.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B025_mrg_nlane2_min_pkt | CFG_C | All lanes: HDR + 1 SHD + 1 hit. | 1 ordered egress packet; monotonic non-decreasing ts within packet. | `cov_cfg.n_lane[2]`, `cov_cfg.mode[MERGING]` | Minimum 2-way merge; catches a 2-way comparator that feeds back onto itself. | planned |
| B026_mrg_nlane2_subh8 | CFG_C | All lanes: HDR + 8 SHD + 4 hits each. | 1 ordered egress packet. | `cov_pkt.hits_per_subh[4]` (per-lane) | Two-way merge with realistic subheader depth. | planned |
| B027_mrg_nlane4_min_pkt | CFG_A | All lanes: HDR + 1 SHD + 1 hit. | 1 egress packet. | `cov_cfg.n_lane[4]` | Default 4-lane merge, minimum payload. Baseline for nightly regression. | planned |
| B028_mrg_nlane4_subh32 | CFG_A | All lanes: HDR + 32 SHD + 16 hits each. | 1 egress packet, `32*16*4`=2048 hits total. | `cov_pkt.subh_per_hdr[32]`, `cov_pkt.hits_per_subh[16]` | Mid-depth realistic workload on the default config. | planned |
| B029_mrg_nlane4_subh128 | CFG_A | All lanes: HDR + 128 SHD + 64 hits. | 1 egress packet. | `cov_pkt.subh_per_hdr[128]`, `cov_pkt.hits_per_subh[64]` | Deeper merge over the default ticket FIFO depth of 64; proves the ticket FIFO drains fast enough with `ALWAYS_READY`. | planned |
| B030_mrg_nlane4_nshd_full | CFG_A | All lanes: HDR + 256 SHD + 1 hit each. | 1 egress packet. | `cov_pkt.subh_per_hdr[N_SHD]` | Full subheader cap across 4 lanes; exercises WRITE_PAGE x (4*256) in the allocator. | planned |
| B031_mrg_nlane8_min_pkt | CFG_D | All lanes: HDR + 1 SHD + 1 hit. | 1 egress packet. | `cov_cfg.n_lane[8]` | 8-way MERGING minimum. Catches a merge comparator tree that was only tested at 4 inputs. | planned |
| B032_mrg_nlane8_subh16 | CFG_D | All lanes: HDR + 16 SHD + 4 hits. | 1 egress packet. | `cov_pkt.subh_per_hdr[*]` | 8-way mid-depth. | planned |
| B033_mrg_nlane8_nshd_full | CFG_D | All lanes: HDR + 256 SHD + 1 hit. | 1 egress packet. | -- | Full cap on 8 lanes; proves the 8-way aggregator's worst happy-path depth. | planned |
| B034_mrg_nlane16_min_pkt | CFG_E | All lanes: HDR + 1 SHD + 1 hit. | 1 egress packet. | `cov_cfg.n_lane[16]` | Maximum N_LANE lane count; bring-up proof that the lane-index-wide buses fit. Catches any `(N_LANE-1)` mis-sized slice. | planned |
| B035_mrg_nlane16_subh2 | CFG_E | All lanes: HDR + 2 SHD + 1 hit. | 1 egress packet. | -- | 16 x 2-subheader merge, light. | planned |
| B036_mrg_nlane16_subh8 | CFG_E | All lanes: HDR + 8 SHD + 2 hits. | 1 egress packet. | `cov_cfg.n_lane[16]` | 16-way merge at 8 subheaders per lane; `page_allocator` cycles FETCH_TICKET 16*8 times. Catches a FETCH_TICKET round-robin that mis-indexes when `lane_ptr` rolls over `N_LANE`. | planned |
| B037_mrg_nlane16_nshd_full | CFG_E | All lanes: HDR + 256 SHD + 1 hit. | 1 egress packet. | -- | 16-lane `N_SHD`-full; heaviest healthy merge workload. | planned |
| B038_mrg_two_consecutive_frames | CFG_A | Drive 2 back-to-back frames (HDR-SHD-HIT-TRL, HDR-SHD-HIT-TRL) with `frame_ts` incremented. | 2 egress packets in order; `frame_ts` advances between them. | `cov_pkt.frame_ts_wrap[low]` | Proves frame-boundary handling: `page_allocator.WRITE_TAIL` -> next `FETCH_TICKET` without reset. Catches a sticky frame-done flag that would block the second frame. | planned |
| B039_mrg_four_consecutive_frames | CFG_A | 4 back-to-back frames. | 4 egress packets in order. | -- | Confirms multi-frame steady state in MERGING. | planned |
| B040_mrg_nlane4_different_ts_per_lane | CFG_A | All lanes same `frame_ts`, but per-lane `shd_ts` = lane index (0,1,2,3). | Egress hits sorted lane 0, lane 1, lane 2, lane 3 by `ts`. | -- | Proves MERGING actually sorts. Catches a MERGING mode that accidentally behaves as MULTIPLEXING. | planned |

### 3.4 Multi-lane MULTIPLEXING happy path (B041..B054)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B041_mux_nlane1_min_pkt | CFG_G | HDR + 1 SHD + 1 hit. | 1 egress packet. | `cov_cfg.mode[MULTIPLEXING]`, `cov_cfg.n_lane[1]` | Degenerate single-lane multiplex (round-robin with one participant). Catches a mod-N that divides by zero when N=1. | planned |
| B042_mux_nlane2_min_pkt | CFG_F (N_LANE=2 override) | HDR + 1 SHD + 1 hit, 2 lanes. | 2 packets emitted (one per lane, round-robin). | -- | Minimum 2-way round-robin in MULTIPLEXING. | planned |
| B043_mux_nlane4_min_pkt | CFG_F | HDR + 1 SHD + 1 hit, 4 lanes. | 4 packets emitted round-robin. | `cov_cfg.n_lane[4]` | Default multiplex row. | planned |
| B044_mux_nlane4_subh8 | CFG_F | HDR + 8 SHD + 4 hits, 4 lanes. | 4 packets, each with 8 subheaders. | -- | Mid multiplex workload. | planned |
| B045_mux_nlane4_subh32 | CFG_F | HDR + 32 SHD + 16 hits, 4 lanes. | 4 packets. | `cov_pkt.subh_per_hdr[32]` | Deeper multiplex payload. | planned |
| B046_mux_nlane4_nshd_full | CFG_F | HDR + 256 SHD + 1 hit. | 4 packets. | -- | Full cap per lane in multiplex mode. | planned |
| B047_mux_nlane8_min_pkt | CFG_H | HDR + 1 SHD + 1 hit. | 8 packets round-robin. | `cov_cfg.n_lane[8]` with MUX | 8-way multiplex bring-up. | planned |
| B048_mux_nlane8_subh16 | CFG_H | HDR + 16 SHD + 4 hits. | 8 packets. | -- | 8-lane mid multiplex. | planned |
| B049_mux_nlane8_nshd_full | CFG_H | HDR + 256 SHD + 1 hit. | 8 packets. | -- | 8-lane multiplex at `N_SHD` cap. | planned |
| B050_mux_nlane16_min_pkt | CFG_I | HDR + 1 SHD + 1 hit. | 16 packets round-robin. | `cov_cfg.n_lane[16]` with MUX | 16-way multiplex bring-up. Catches a round-robin pointer that fails the wrap from lane 15 back to lane 0. | planned |
| B051_mux_nlane16_subh2 | CFG_I | HDR + 2 SHD + 1 hit. | 16 packets. | -- | 16-lane multiplex, light payload. | planned |
| B052_mux_nlane16_subh64 | CFG_I | HDR + 64 SHD + 4 hits. | 16 packets. | -- | 16-lane multiplex, mid payload. | planned |
| B053_mux_two_frames | CFG_F | 2 back-to-back frames on all 4 lanes. | 8 packets (two rounds of round-robin). | -- | Proves multiplex round-robin re-enters cleanly on frame boundary. | planned |
| B054_mux_distinguishable_channels | CFG_F | Lane i tagged with `channel=i`. | Scoreboard sees each egress packet's `channel` field match the source lane. | `cov_cfg.channel_width[2]` | Proves MULTIPLEXING preserves channel ID end-to-end. Catches a channel port tied to lane 0 by mistake. | planned |

### 3.5 N_LANE + channel-width sweep (B055..B063)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B055_chw0 | CFG_K | HDR + 1 SHD + 1 hit, N_LANE=4. | Egress `channel` port absent (or tied 0). | `cov_cfg.channel_width[0]` | Zero-width channel -- proves the port vanishes cleanly. Catches a VHDL concat that dereferences a null slice. | planned |
| B056_chw1 | CFG_L | HDR + 1 SHD + 1 hit, per-lane channel=lane&1. | Egress channel[0] matches source. | `cov_cfg.channel_width[1]` | 1-bit channel; catches a 1-bit packed slice bug. | planned |
| B057_chw2 | CFG_A | Channel=lane (2 bits). | Matches. | `cov_cfg.channel_width[2]` | Default channel width. | planned |
| B058_chw3 | CFG_M | Channel=lane+3 (3 bits). | Matches. | `cov_cfg.channel_width[3]` | 3-bit channel. | planned |
| B059_chw4 | CFG_N | Channel=lane+0xA (4 bits). | Matches. | `cov_cfg.channel_width[4]` | Max channel width 4. Catches sign extension inside the channel FIFO slice. | planned |
| B060_chw_stable_sop_eop | CFG_N | Drive channel=0xA at SOP, keep stable through all HDR+SHD+HIT+TRL beats. | `opq_avst_ingress_sva` does not fire; egress sees 0xA. | `cov_cfg.channel_width[4]`, SVA stability | Verifies the DV_HARNESS-mandated "channel stable across SOP..EOP" rule on the widest channel. | planned |
| B061_nlane1_only | CFG_B | HDR + 1 SHD + 1 hit. | Egress passthrough. | `cov_cfg.n_lane[1]` sanity | N=1 sanity separate from B013 to confirm the coverage bin under `MERGING`. | planned |
| B062_nlane2_only | CFG_C | HDR + 1 SHD + 1 hit. | 1 packet. | `cov_cfg.n_lane[2]` | N=2 sanity. | planned |
| B063_nlane_matrix_proof | CFG_E | HDR + 1 SHD + 1 hit x 16 lanes. | 1 packet. | `cov_cfg.n_lane[16]` | N=16 sanity. Lane-sweep closure row. | planned |

### 3.6 Ingress data/dataK width sweep (B064..B070)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B064_idw32_idk4 | CFG_A | Default 32/4 ingress, HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_width[40]` | Default ingress width sanity. | planned |
| B065_idw64_idk8 | CFG_O | 64-bit data, 8-bit datak. | Matches. | `cov_cfg.lane_fifo_width[*=72]` | Doubled ingress beat width. Catches a VHDL range that assumed 36. | planned |
| B066_idw96_idk12 | CFG_P | 96/12 ingress. | Matches. | -- | Tripled beat width. Catches arithmetic that assumed a power-of-two width. | planned |
| B067_idw128_idk16 | CFG_Q | 128/16 ingress (maximum legal). | Matches. | -- | Max ingress beat width. Catches an overflow in the internal address bus from a too-narrow slice. | planned |
| B068_idw64_idk8_multi_subh | CFG_O | HDR + 8 SHD + 4 hits. | Matches. | -- | Multi-subh on doubled-beat config. | planned |
| B069_idw128_idk16_nshd_full | CFG_Q | HDR + 256 SHD + 1 hit. | Matches. | `cov_pkt.subh_per_hdr[N_SHD]` on max width | Heaviest healthy load on the widest ingress. | planned |
| B070_idw32_idk4_hit_cnt_255 | CFG_A | HDR + 1 SHD + 255 hits. | Matches. | `cov_pkt.hits_per_subh[255]` | Default-width `N_HIT`-cap hit loop. | planned |

### 3.7 PAGE_RAM_RD_WIDTH / symbolsPerBeat / empty sweep (B071..B079)

Every row below drives HDR + 4 SHD + 7 hits, a payload chosen so the final egress beat is guaranteed to be partial (forcing a non-zero `empty` field on the last beat across all widths).

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B071_prw36_sym1 | CFG_A | HDR+4SHD+7hit. | `symbolsPerBeat=1`, `empty` absent. | `cov_cfg.page_ram_rd_width[36]` | Single-symbol egress beat. Baseline. | planned |
| B072_prw72_sym2 | CFG_R | Same. | `symbolsPerBeat=2`, `empty[0]` valid on final beat if unpaired. | `cov_cfg.page_ram_rd_width[72]` | Exercises the 2-symbol packer; final-beat `empty=1` when symbol count is odd. Catches a packer that pads with garbage instead of using `empty`. | planned |
| B073_prw108_sym3 | CFG_S | Same. | `symbolsPerBeat=3`, `empty in {0,1,2}`. | `cov_cfg.page_ram_rd_width[108]` | 3-symbol packer, non-power-of-two. Catches a shifter that assumes symbolsPerBeat is a power of two. | planned |
| B074_prw144_sym4 | CFG_T | Same. | `symbolsPerBeat=4`, `empty in {0..3}`. | `cov_cfg.page_ram_rd_width[144]` | 4-symbol packer. | planned |
| B075_prw180_sym5 | CFG_U | Same. | `symbolsPerBeat=5`. | `cov_cfg.page_ram_rd_width[180]` | 5-symbol packer; non-power-of-two. | planned |
| B076_prw216_sym6 | CFG_V | Same. | `symbolsPerBeat=6`. | `cov_cfg.page_ram_rd_width[216]` | 6-symbol packer. | planned |
| B077_prw252_sym7 | CFG_W | Same. | `symbolsPerBeat=7`. | `cov_cfg.page_ram_rd_width[252]` | 7-symbol packer. Catches a corner where symbolsPerBeat is prime. | planned |
| B078_prw288_sym8 | CFG_X | Same. | `symbolsPerBeat=8` (max). | `cov_cfg.page_ram_rd_width[288]` | Widest egress beat. Catches a page-RAM read-port width assumption. | planned |
| B079_prw36_exact_multiple | CFG_A | HDR+2SHD+2hits (payload exactly fills egress beats). | `empty=0` on final beat. | -- | Complement to the non-zero `empty` rows; proves `empty` is not stuck high. | planned |

### 3.8 N_SHD and N_HIT parameter sweep (B080..B087)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B080_nshd128 | CFG_Y | HDR + 128 SHD + 1 hit (exactly `N_SHD`). | 1 egress packet. | `cov_cfg.n_shd[128]` | Minimum `N_SHD` at its cap. Catches a parser that uses 256 regardless of the generic. | planned |
| B081_nshd256 | CFG_A | HDR + 256 SHD + 1 hit. | 1 packet. | `cov_cfg.n_shd[256]` | Default `N_SHD`. | planned |
| B082_nshd512 | CFG_Z | HDR + 512 SHD + 1 hit. | 1 packet. | `cov_cfg.n_shd[512]` | Maximum `N_SHD`. Catches a ticket-fifo depth generic that cannot absorb 512 pending subheaders with `ALWAYS_READY`. | planned |
| B083_nhit255 | CFG_A | HDR + 1 SHD + 255 hits (=default `N_HIT`). | 1 packet. | `cov_cfg.n_hit[255]`, `cov_pkt.hits_per_subh[255]` | Default `N_HIT` at the cap. | planned |
| B084_nhit511 | CFG_AA | HDR + 1 SHD + 511 hits. | 1 packet. | `cov_cfg.n_hit[511]` | `N_HIT`=511 cap. | planned |
| B085_nhit1023 | CFG_AB | HDR + 1 SHD + 1023 hits. | 1 packet. | `cov_cfg.n_hit[1023]` | `N_HIT`=1023 cap. | planned |
| B086_nhit2047 | CFG_AC | HDR + 1 SHD + 2047 hits. | 1 packet. | `cov_cfg.n_hit[2047]` | Maximum `N_HIT`. Catches a hit-count field too narrow for 11 bits. | planned |
| B087_nshd512_nhit2047_one_each | CFG_Z + N_HIT=2047 override | HDR + 512 SHD + 2047 hits. | 1 packet, `512*2047` hits. | -- | Largest healthy single-frame payload; proves the page RAM and lane FIFO carry it. Note: this remains inside `LANE_FIFO_DEPTH` because payload is streamed out under ALWAYS_READY. | planned |

### 3.9 TRACK_HEADER on/off (B088..B092)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B088_th_on_default | CFG_A | HDR + 1 SHD + 1 hit. | `ftable_tracker` visits RECORD_TILE + FLUSH_TILE per header. | `cov_cfg.track_header[true]`, `cov_fsm.ftable_tracker.{RECORD_TILE,FLUSH_TILE}` | Verifies TRACK_HEADER=true actually engages the tracker. | planned |
| B089_th_off_no_tracker | CFG_J | HDR + 1 SHD + 1 hit. | `ftable_tracker` stays IDLE (never leaves); egress still correct. | `cov_cfg.track_header[false]`, `cov_fsm.ftable_tracker.IDLE` | Proves the tracker is fully bypassed when TRACK_HEADER=false. Catches a tracker that runs unconditionally. | planned |
| B090_th_off_two_frames | CFG_J | 2 frames. | 2 egress packets; tracker never leaves IDLE. | -- | Proves TRACK_HEADER=false is stable across frame boundary. | planned |
| B091_th_on_nshd_full | CFG_A | HDR + 256 SHD + 1 hit. | Tracker cycles RECORD_TILE->FLUSH_TILE on every tile. | `cov_fsm.ftable_tracker.*` | Deep tile traffic on tracker. Catches a tile counter that overflows when N_SHD is at cap. | planned |
| B092_th_on_two_frames | CFG_A | 2 frames. | Tracker re-enters and flushes per frame. | -- | Proves tracker tile flush happens on frame boundary. | planned |

### 3.10 FSM state reachability (B093..B102)

These rows target FSM states that are not trivially reached by the bring-up spine. Every row is a single healthy transaction crafted to force the probe observer to visit the named state once.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B093_parser_mask_pkt_extended | CFG_A | HDR that straddles a page-RAM tile boundary (HDR + 0 SHD + TRL where `HDR_SIZE+TRL_SIZE` crosses a tile alignment). | `ingress_parser[*]` transits through MASK_PKT_EXTENDED once (the extended-mask healthy path that exists to align writes across tile boundaries). | `cov_fsm.ingress_parser[*].MASK_PKT_EXTENDED` | Exercises `MASK_PKT_EXTENDED` on its healthy alignment path (not as a drop-on-full response). Catches a parser that only reaches MASK_PKT_EXTENDED via the error path. **NB: in DV_BASIC this state must be reached without forcing an overflow; if the RTL does not have a healthy entry to MASK_PKT_EXTENDED, this case is explicitly deferred to DV_ERROR and noted in sec 5.** | planned |
| B094_allocator_alloc_page_repeat | CFG_A | HDR + 8 SHD + 1 hit each (forces `page_allocator.ALLOC_PAGE` to run 9 times total). | Allocator visits ALLOC_PAGE in rapid succession. | `cov_fsm.page_allocator.ALLOC_PAGE[>=9]` | Confirms `ALLOC_PAGE` is re-entrant from `WRITE_PAGE`. | planned |
| B095_allocator_write_tail_every_frame | CFG_A | 4 back-to-back frames. | Allocator visits WRITE_TAIL 4 times. | `cov_fsm.page_allocator.WRITE_TAIL[>=4]` | Proves the tail path fires exactly once per frame. | planned |
| B096_blkmv_prep_writeblk | CFG_A | HDR + 1 SHD + 1 hit. | `block_mover[0]` visits PREP then WRITE_BLK then IDLE. | `cov_fsm.block_mover[0].{PREP,WRITE_BLK}` | Minimum block-mover happy path for lane 0. | planned |
| B097_blkmv_all_lanes_writeblk | CFG_A | HDR + 2 SHD + 1 hit on all 4 lanes. | Each per-lane `block_mover[i]` visits WRITE_BLK at least once. | `cov_fsm.block_mover[0..3].WRITE_BLK`, `C_BLKMV_X_LANE` | Proves the per-lane generate actually instantiates 4 distinct FSMs. Catches a shared FSM bug. | planned |
| B098_arbiter_locking_locked | CFG_A | HDR + 8 SHD + 1 hit on all 4 lanes. | `arbiter` cycles IDLE->LOCKING->LOCKED->IDLE many times. | `cov_fsm.arbiter.{LOCKING,LOCKED}` | Forces arbitration. F9 (LOCKED hold) is only hit this way. Catches an arbiter that skips LOCKING. | planned |
| B099_fmapper_modify_frame_table | CFG_A | 2 back-to-back frames. | `ftable_mapper` visits MODIFY_FRAME_TABLE (distinct from UPDATE) on the second frame. | `cov_fsm.ftable_mapper.MODIFY_FRAME_TABLE` | Proves the MODIFY path (modify-existing vs first-create) is reachable on the healthy 2-frame sequence. Catches a mapper that never transitions out of UPDATE. | planned |
| B100_fpresenter_verify | CFG_A | 1 header-only frame. | `ftable_presenter` passes through WAIT_FOR_COMPLETE->VERIFY->PRESENTING. | `cov_fsm.ftable_presenter.VERIFY` | Isolates the VERIFY state (compute/cross-check of the frame table before presenting). | planned |
| B101_fpresenter_presenting | CFG_A | HDR + 1 SHD + 1 hit. | Presenter visits PRESENTING for at least 1 egress beat. | `cov_fsm.ftable_presenter.PRESENTING` | Standalone PRESENTING reach. | planned |
| B102_allocator_fetch_ticket_loop | CFG_A | HDR + 16 SHD + 0 hits each. | `page_allocator` visits FETCH_TICKET -> WRITE_PAGE -> FETCH_TICKET -> ... 16 times. | `cov_fsm.page_allocator.FETCH_TICKET[>=16]` | Proves the allocator's FETCH_TICKET->WRITE_PAGE self-loop is clean when subheaders are empty. | planned |

### 3.11 Lane FIFO / ticket FIFO / handle FIFO plumbing (B103..B110)

These rows only change FIFO depths; the payload is fixed so the FIFOs stay well below half-full. They prove the depth generic is actually wired into the inferred FIFO, not that pressure works.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B103_lane_fifo_16 | CFG_AG | HDR + 1 SHD + 1 hit. | Passthrough; probe confirms lane FIFO depth generic = 16. | `cov_cfg.lane_fifo_depth[16]` | Minimum lane FIFO depth. Catches a hardcoded depth override. | planned |
| B104_lane_fifo_256 | CFG_AH | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_depth[256]` | Mid lane FIFO depth. | planned |
| B105_lane_fifo_4096 | CFG_AI | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_depth[4096]` | Large lane FIFO depth. | planned |
| B106_lane_fifo_65536 | CFG_AJ | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_depth[65536]` | Maximum lane FIFO depth; proves the address-bus width scales. | planned |
| B107_ticket_fifo_min | CFG_AK | HDR + 1 SHD + 1 hit. | Passthrough; ticket FIFO depth = 2. | `cov_cfg.ticket_fifo_depth[2]` | Minimum ticket FIFO; proves the depth=2 corner where the FIFO degrades to a two-register handshake. | planned |
| B108_ticket_fifo_max | CFG_AL | HDR + 1 SHD + 1 hit. | Passthrough; ticket FIFO depth = 256. | `cov_cfg.ticket_fifo_depth[256]` | Maximum ticket FIFO. | planned |
| B109_handle_fifo_min | CFG_AM | HDR + 1 SHD + 1 hit. | Passthrough; handle FIFO depth = 2. | `cov_cfg.handle_fifo_depth[2]` | Minimum handle FIFO. | planned |
| B110_handle_fifo_max | CFG_AN | HDR + 1 SHD + 1 hit. | Passthrough; handle FIFO depth = 256. | `cov_cfg.handle_fifo_depth[256]` | Maximum handle FIFO. | planned |

### 3.12 PAGE_RAM_DEPTH and lane FIFO width (B111..B117)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B111_page_ram_8192 | CFG_AD | HDR + 1 SHD + 1 hit. | Passthrough; page RAM depth = 8 k. | `cov_cfg.page_ram_depth[8192]` | Minimum page RAM depth. Catches a page pointer too wide for 13 bits. | planned |
| B112_page_ram_16384 | CFG_AE | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.page_ram_depth[16384]` | 14-bit page pointer. | planned |
| B113_page_ram_32768 | CFG_AF | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.page_ram_depth[32768]` | 15-bit page pointer. | planned |
| B114_page_ram_65536 | CFG_A | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.page_ram_depth[65536]` | 16-bit page pointer (default). | planned |
| B115_lane_fifo_width_48 | CFG_AQ | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_width[48]` | 48-bit lane FIFO (8 extra tag bits). Catches an upper-bits slice not wired. | planned |
| B116_lane_fifo_width_64 | CFG_AR | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_width[64]` | 64-bit lane FIFO. | planned |
| B117_lane_fifo_width_80 | CFG_AS | HDR + 1 SHD + 1 hit. | Passthrough. | `cov_cfg.lane_fifo_width[80]` | 80-bit lane FIFO (widest). | planned |

### 3.13 Subheader TS low-byte pattern coverage (B118..B123)

All rows drive 6 subheaders with `shd_ts[7:0]` = {0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF}. Separate cases because the coverage bins are per-value, and mixing them in one txn would not let the scoreboard prove each bin is actually sampled.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B118_shd_ts_00 | CFG_A | HDR + 1 SHD (shd_ts=0x00) + 1 hit. | Passthrough; scoreboard sees shd_ts=0x00. | `cov_pkt.shd_ts_pattern[0x00]` | Lowest shd_ts. Catches a zero-value suppression bug. | planned |
| B119_shd_ts_01 | CFG_A | Same, shd_ts=0x01. | Match. | `cov_pkt.shd_ts_pattern[0x01]` | Just-above-zero. | planned |
| B120_shd_ts_7F | CFG_A | shd_ts=0x7F. | Match. | `cov_pkt.shd_ts_pattern[0x7F]` | Just-below half. | planned |
| B121_shd_ts_80 | CFG_A | shd_ts=0x80. | Match. | `cov_pkt.shd_ts_pattern[0x80]` | High-bit-set boundary; catches a signed-vs-unsigned compare. | planned |
| B122_shd_ts_FE | CFG_A | shd_ts=0xFE. | Match. | `cov_pkt.shd_ts_pattern[0xFE]` | Near-top. | planned |
| B123_shd_ts_FF | CFG_A | shd_ts=0xFF. | Match. | `cov_pkt.shd_ts_pattern[0xFF]` | Top value; catches a wrap-to-zero mis-handling. | planned |

### 3.14 DEBUG_LV matrix and FRAME_*_SIZE sanity (B124..B130)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B124_debug_lv0_build | CFG_AO | HDR + 1 SHD + 1 hit. | Passthrough; no `opq_overwrite_debug.log` file produced. | F10 `DEBUG_LV=0` | Proves the non-debug build path compiles and simulates. Catches a debug-only signal referenced unconditionally. | planned |
| B125_debug_lv1_build | CFG_A | HDR + 1 SHD + 1 hit. | Passthrough; synthesizable debug probes active; no sim-only log. | F10 `DEBUG_LV=1` | Default DV row; proves the synthesizable debug level is the nightly baseline. | planned |
| B126_debug_lv2_build | CFG_AP | HDR + 1 SHD + 1 hit. | Passthrough; `opq_overwrite_debug.log` opened by the sim. | F10 `DEBUG_LV=2` | Exercises the sim-only debug log write. Catches a DEBUG_LV=2 path broken by an earlier refactor. | planned |
| B127_frame_serial_bin_zero | CFG_AU | HDR with `frame_serial=0` + 1 SHD + 1 hit. | Passthrough. | -- | Proves frame serial = 0 is accepted (it is a valid first-frame value). Catches a "nonzero frame_serial" assumption. | planned |
| B128_frame_serial_bin_mid | CFG_AU | HDR with `frame_serial=0x1234` + 1 SHD + 1 hit. | Passthrough; scoreboard matches. | -- | Mid-range serial. Catches truncation in the serial slice. | planned |
| B129_frame_subh_cnt_field | CFG_AU | HDR whose internal `FRAME_SUBH_CNT` field = 4, actually drive 4 SHD. | Passthrough; metadata consistent. | -- | Proves the `FRAME_SUBH_CNT_SIZE` field is carried through. | planned |
| B130_frame_hit_cnt_field | CFG_AU | HDR whose `FRAME_HIT_CNT` field = 8, drive 4 SHD x 2 hits = 8. | Passthrough. | -- | Proves the hit-count field in the header metadata is carried through unmodified. | planned |

### 3.15 End-to-end sanity and closure (B131..B136)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|---|---|---|---|---|---|---|
| B131_full_daq_frame_default | CFG_A | 1 frame with `N_SHD=256` x `N_HIT=255` hits x 4 lanes = 261120 hits. | 1 ordered egress packet bit-exact against scoreboard. | closes the intersection of `subh_per_hdr[N_SHD]` and `hits_per_subh[255]` | Heaviest healthy single-frame stimulus on the default config. Catches any silent corruption that only appears at cap payload. | planned |
| B132_full_daq_frame_max_nlane | CFG_E | 1 frame with 256 SHD x 255 hits x 16 lanes. | 1 packet. | `cov_cfg.n_lane[16]` x full payload | Heaviest healthy 16-lane merge. | planned |
| B133_full_daq_frame_mux | CFG_F | 1 frame, default payload. | 4 packets. | -- | Heaviest multiplex counterpart. | planned |
| B134_three_frames_default | CFG_A | 3 back-to-back frames, each HDR+8 SHD+4 hits. | 3 egress packets. | -- | Steady-state multi-frame sanity for the nightly row. | planned |
| B135_all_channel_widths_proof | mini-matrix CFG_K,L,A,M,N | Each row: HDR + 1 SHD + 1 hit. | Every run passes. | `cov_cfg.channel_width[0..4]` closure | Closure row that runs the full channel width sweep as one regression job. This is how the nightly UCDB is guaranteed to have every `channel_width` bin hit. | planned |
| B136_all_prw_widths_proof | mini-matrix CFG_A,R,S,T,U,V,W,X | Each row: HDR+4SHD+7hit. | Every run passes. | `cov_cfg.page_ram_rd_width[36..288]` closure | Closure row for the page-RAM read-width sweep. Ensures all 8 bins are sampled by a single regression invocation. | planned |

**Row count: 136 cases (B001..B136).**

---

## 4. Coverage binding

This section maps each sub-bucket to the covergroup bins it is responsible for closing. Any bin not listed here is either not in scope for DV_BASIC or is reached indirectly as a side effect (in which case it is deliberately not the responsibility of this bucket to guarantee).

### 4.1 Configuration coverage (`cov_cfg`)

| Bin | Closed by | Deferred to |
|---|---|---|
| `mode.MERGING`         | B003, all §3.3, §3.5..§3.14 rows on MERGING configs | -- |
| `mode.MULTIPLEXING`    | B041..B054, B133 | -- |
| `track_header.true`    | B088, B091, B092, most others | -- |
| `track_header.false`   | B089, B090 | -- |
| `n_lane.1`             | B013..B024, B041, B061 | -- |
| `n_lane.2`             | B025, B026, B042, B062 | -- |
| `n_lane.4`             | B027..B030, B043..B046, B057, default nightly | -- |
| `n_lane.8`             | B031..B033, B047..B049 | -- |
| `n_lane.16`            | B034..B037, B050..B052, B063, B132 | -- |
| `channel_width.0`      | B055, B135 | -- |
| `channel_width.1`      | B056, B135 | -- |
| `channel_width.2`      | B057, B135 | -- |
| `channel_width.3`      | B058, B135 | -- |
| `channel_width.4`      | B059, B060, B135 | -- |
| `lane_fifo_depth.{16,256,1024,4096,65536}` | B103..B106 (1024 = default via B001 etc) | bins 64 and 16384 -> **DV_EDGE** |
| `lane_fifo_width.{40,48,64,80}`            | B064 (40), B115, B116, B117 | bin 39 -> DV_EDGE |
| `ticket_fifo_depth.{2,64,256}`             | B107, B108, default | bins 16, 128 -> DV_EDGE |
| `handle_fifo_depth.{2,64,256}`             | B109, B110, default | bins 16, 128 -> DV_EDGE |
| `page_ram_depth.{8192,16384,32768,65536}`  | B111..B114 | -- |
| `page_ram_rd_width.{36..288 step 36}`      | B071..B078, B136 | -- |
| `n_shd.{128,256,512}`                      | B080..B082 | -- |
| `n_hit.{255,511,1023,2047}`                | B083..B086 | -- |

### 4.2 FSM coverage (`cov_fsm`)

DV_BASIC closes every **non-error reachable state** in every FSM. The exceptions documented in §5 are the states that can only be reached through error injection, backpressure, or mid-packet reset.

| FSM | State | Closed by | Deferred |
|---|---|---|---|
| `ingress_parser[*]` | IDLE | B001 | -- |
|  | UPDATE_HEADER_TS | B002, B003 | -- |
|  | MASK_PKT_EXTENDED | B093 **(healthy alignment path only)** | full drop-on-full path -> DV_ERROR |
|  | MASK_PKT | -- | DV_ERROR (drop-on-full) |
|  | WR_HITS | B004..B007, most others | -- |
|  | RESET | B001 | -- |
| `page_allocator` | IDLE, FETCH_TICKET, ALLOC_PAGE, WRITE_HEAD, WRITE_TAIL, WRITE_PAGE | B001, B003, B007, B008, B094..B096, B102 | -- |
| `block_mover[*]` | IDLE, PREP, WRITE_BLK | B001, B096, B097 | -- |
|  | ABORT_WRITE_BLK | -- | DV_ERROR (F8 mid-handle abort) |
| `arbiter` | IDLE, LOCKING, LOCKED | B001, B098 | -- |
| `ftable_mapper` | IDLE, PREP_UPDATE, UPDATE_FRAME_TABLE, MODIFY_FRAME_TABLE | B001, B003, B099 | -- |
| `ftable_tracker` | IDLE, RECORD_TILE, FLUSH_TILE | B001, B088, B091 | -- |
| `ftable_presenter` | IDLE, WAIT_FOR_COMPLETE, VERIFY, PRESENTING | B001, B003, B100, B101 | RESTART, WARPING -> DV_PROF (F1); formal RESTART SVA is checked there |

`C_BLKMV_X_LANE` (per-lane block-mover cross) is closed by B097 and B132.
`C_ALLOC_X_LANES` is closed by the combination of B031..B037 (8-/16-way) and B034.
`C_PRESENTER_X_BP` is entirely **deferred to DV_PROF** -- DV_BASIC never backpressures.

### 4.3 Packet-shape coverage (`cov_pkt`)

| Bin | Closed by | Deferred |
|---|---|---|
| `hits_per_subh.{0,1,2,4,16,64,128,255}` | B004, B005, B006, B022, B023, B024, (128 via B028), B083 | -- |
| `hits_per_subh.N_HIT` (511/1023/2047) | B084, B085, B086 | -- |
| `subh_per_hdr.{1,2,8,32,64,127,128,N_SHD-1,N_SHD}` | B014, B015, B016, B017, B018, B019, B020, B021, B082 | -- |
| `hdr_size_words` = 5 + optional trailer | B008 | HDR_SIZE != 5 variations -> DV_EDGE |
| `shd_ts_pattern.{0x00,0x01,0x7F,0x80,0xFE,0xFF}` | B118..B123 | -- |
| `frame_ts_wrap.low` | B010, B011, B012, B038 | `near-wrap`, `post-wrap` -> DV_EDGE |
| `first_frame_short` | B009 | -- |

### 4.4 Flow-control coverage (`cov_flow`)

DV_BASIC closes only the trivial bins:

| Bin | Closed by | Deferred |
|---|---|---|
| `egress_ready_duty.100%` | every row (ALWAYS_READY) | the 75/50/25/10/1/0 bins -> DV_PROF |
| `egress_ready_toggle_period.*` | -- | DV_PROF |
| `ingress_lane_skew.0` | every multi-lane row | 1, 10, 100, 1000, LANE_FIFO_DEPTH/2, LANE_FIFO_DEPTH-1 -> DV_EDGE / DV_PROF |
| `ticket_fifo_occupancy.low` | by default | mid, high, full -> DV_EDGE / DV_ERROR |
| `lane_fifo_occupancy.low` | by default | mid, high, full -> DV_EDGE / DV_ERROR |
| `handle_fifo_occupancy.low` | by default | mid, high, full -> DV_EDGE / DV_ERROR |

### 4.5 Frozen-behavior bindings

| F# | DV_BASIC closure |
|---|---|
| F1 egress stall -> RESTART | **not closed** -- all DV_BASIC cases use ALWAYS_READY. Closed in DV_PROF. |
| F2 3-segment page RAM | partially exercised by all normal runs; segment-rotation **boundaries** are deferred to DV_EDGE. |
| F3 frame_ts advance timing | closed by B010, B011, B012. |
| F4 running_ts re-sync on all-lane SOP | closed by B009. |
| F5 hit overflow -> `hit_err` | **not closed** -- DV_BASIC never injects overflow. Closed in DV_ERROR. |
| F6 drop-on-full | **not closed** -- Closed in DV_ERROR. |
| F7 FETCH_TICKET blocks on missing SOP | closed by B002 (held in FETCH_TICKET until all-lane SOP in later rows). |
| F8 ABORT_WRITE_BLK | **not closed** -- Closed in DV_ERROR. |
| F9 arbiter LOCKED hold | reached by B098; fairness/starvation proof belongs to DV_PROF. |
| F10 DEBUG_LV matrix | closed by B124, B125, B126. |

---

## 5. Handoff to later buckets

DV_BASIC deliberately leaves the following bins open, and each is assigned to the bucket that owns the corresponding stimulus family. DV_EDGE / DV_PROF / DV_ERROR / DV_CROSS authors should treat this list as their pre-existing work:

1. **`ingress_parser[*].MASK_PKT` and the drop-on-full half of `MASK_PKT_EXTENDED`** -> DV_ERROR. Only the healthy alignment entry to `MASK_PKT_EXTENDED` is attempted here (B093); if the RTL does not provide a healthy entry, delete B093 and let DV_ERROR own the state.
2. **`block_mover[*].ABORT_WRITE_BLK`** -> DV_ERROR (F8 mid-handle abort).
3. **`ftable_presenter.{RESTART, WARPING}`** and `C_PRESENTER_X_BP` cross -> DV_PROF (F1 backpressure RESTART and the warping scheme).
4. **`cov_flow.egress_ready_duty.{75%,50%,25%,10%,1%,0%}` and all `toggle_period` bins** -> DV_PROF.
5. **`cov_flow.ingress_lane_skew.{1,10,100,1000,LANE_FIFO_DEPTH/2,LANE_FIFO_DEPTH-1}`** -> DV_EDGE (boundary skews) and DV_PROF (stress skews).
6. **`cov_flow.{ticket,lane,handle}_fifo_occupancy.{mid,high,full}`** -> DV_EDGE (boundary) and DV_ERROR (full-triggered drop).
7. **`cov_pkt.frame_ts_wrap.{near-wrap, post-wrap}`** -> DV_EDGE.
8. **`cov_cfg.lane_fifo_depth.{64, 16384}`, `ticket_fifo_depth.{16,128}`, `handle_fifo_depth.{16,128}`, `lane_fifo_width.39`** -> DV_EDGE.
9. **Frozen behaviors F1, F5, F6, F8** -> DV_ERROR / DV_PROF as tagged above.
10. **Cross-axis cells** (FSM x backpressure x skew x err x config) -> DV_CROSS. DV_BASIC never hits more than one axis non-trivially per case; every cross-cell is the responsibility of C-series.
11. **Segment-rotation boundary** of the 3-segment page RAM (F2 boundary, as opposed to the happy-path coexistence exercised by every normal run here) -> DV_EDGE.
12. **Lint and coverage closure pass** -> performed by the regression driver after DV_BASIC + the other buckets land; DV_BASIC alone is not required to reach the §5.6 statement/branch coverage targets in DV_PLAN.

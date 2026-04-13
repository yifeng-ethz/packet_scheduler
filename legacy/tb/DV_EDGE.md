# DV Bucket: DV_EDGE — ordered_priority_queue (monolithic)

**Companion to:** DV_PLAN.md, DV_HARNESS.md
**Bucket prefix:** E   **ID range:** E001..Ennn   **Minimum cases:** 128

---

## 1. Scope

DV_EDGE holds boundary / corner cases for the `ordered_priority_queue` monolithic
core. Every row targets an off-by-one, wrap, full-vs-empty distinguisher, or
segment-transition edge in the RTL datapath — **not** stress, not error injection,
not long mixed runs. Each case isolates one narrow arithmetic/control boundary and
names the exact RTL path whose mis-coding would manifest.

Explicit exclusions (handled in sibling buckets):

- `hit_err` / `shd_err` / `hdr_err` injection, truncation, missing EOP, mid-packet
  reset, drop-on-full mask propagation → **DV_ERROR**
- Sustained line-rate soak, backpressure duty sweeps, arbiter fairness starvation,
  page-RAM dwell/wrap stress → **DV_PROF**
- Multi-axis long-running cross-coverage scenarios → **DV_CROSS**
- Per-FSM state reachability, happy-path sanity, MODE matrix (these are the
  pre-boundary baselines in **DV_BASIC**)

The bucket exercises the frozen behaviors where the boundary specifically stresses
the frozen path: **F1** (RESTART rollback), **F2** (3-segment page RAM),
**F3** (frame_ts advance timing), **F4** (running_ts re-sync), **F7** (FETCH_TICKET
all-lanes requirement), **F8** (ABORT_WRITE_BLK healthy path), **F10**
(`DEBUG_LV=0` build boundary).

---

## 2. Configuration groups

All rows in §3 reference one of the tags below. Each tag is a complete generic
snapshot (only the deltas from the nightly default are shown; everything else
inherits from the DV_HARNESS 4-lane MERGING default: `N_LANE=4`, `MODE=MERGING`,
`TRACK_HEADER=true`, `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`, `N_SHD=256`,
`N_HIT=255`, `LANE_FIFO_DEPTH=1024`, `LANE_FIFO_WIDTH=40`, `TICKET_FIFO_DEPTH=64`,
`HANDLE_FIFO_DEPTH=64`, `PAGE_RAM_DEPTH=65536`, `PAGE_RAM_RD_WIDTH=36`,
`CHANNEL_WIDTH=2`, `DEBUG_LV=1`). Configs are chosen so the boundary **lands on a
sub-word boundary** of the RTL arithmetic under test.

| Tag | Deltas from default | Purpose |
|-----|---------------------|---------|
| `CFG_E_A` | `LANE_FIFO_DEPTH=16` | Shallow lane FIFO — makes `wptr==rptr` vs `wptr==rptr+DEPTH` full/empty disambiguation reachable in single-digit beats. |
| `CFG_E_B` | `LANE_FIFO_DEPTH=64` | Mid-shallow lane FIFO, exercises the same pointer logic at a different bit width (6 vs 4). |
| `CFG_E_C` | `LANE_FIFO_DEPTH=4096` | Deep lane FIFO, forces the `ptr` counter to wrap within a single txn. |
| `CFG_E_D` | `LANE_FIFO_DEPTH=65536` | Max lane FIFO, exercises the full 17-bit credit bookkeeping. |
| `CFG_E_E` | `TICKET_FIFO_DEPTH=2` | Credit starvation — ticket slot count is one-less-than two; makes the credit checker's "0→1" transition the hot path. |
| `CFG_E_F` | `TICKET_FIFO_DEPTH=16` | Smallest power-of-two ticket FIFO above starvation. |
| `CFG_E_G` | `TICKET_FIFO_DEPTH=128` | Matches `N_SHD=128` — the occupancy equals the max ticket count from a single frame. |
| `CFG_E_H` | `TICKET_FIFO_DEPTH=256` | Maximum ticket FIFO depth in the covered set. |
| `CFG_E_I` | `HANDLE_FIFO_DEPTH=2` | Handle FIFO depth = 2; exercises "empty → 1 entry → full" in two writes. |
| `CFG_E_J` | `HANDLE_FIFO_DEPTH=16` | Mid-shallow handle FIFO for cross-lane block-mover drain tests. |
| `CFG_E_K` | `HANDLE_FIFO_DEPTH=256` | Deep handle FIFO — block mover drain never the bottleneck. |
| `CFG_E_L` | `PAGE_RAM_DEPTH=8192` | Min page RAM — guarantees a wrap inside one regression txn. |
| `CFG_E_M` | `PAGE_RAM_DEPTH=16384` | Smaller non-default, exercises the 14-bit addressing width. |
| `CFG_E_N` | `N_SHD=128` | Smallest N_SHD — `shd_ts[7:0]` counts 0..127 within a frame, forces the 0x7F→0x80 carry. |
| `CFG_E_O` | `N_SHD=256` | Default — `shd_ts` wraps at 0xFF→0x00 within a single frame. |
| `CFG_E_P` | `N_SHD=512` | Largest N_SHD — `shd_ts[7:0]` wraps twice within a frame. |
| `CFG_E_Q` | `N_HIT=255` | Exercises `hit_cnt` at 8-bit boundary (0xFF). |
| `CFG_E_R` | `N_HIT=2047` | Exercises `hit_cnt` at 11-bit boundary. |
| `CFG_E_S` | `INGRESS_DATA_WIDTH=32, INGRESS_DATAK_WIDTH=4` | Default 36-bit beat. |
| `CFG_E_T` | `INGRESS_DATA_WIDTH=64, INGRESS_DATAK_WIDTH=8` | 72-bit beat; shortest valid `SHD` packet drops from 2 beats to 1. |
| `CFG_E_U` | `INGRESS_DATA_WIDTH=96, INGRESS_DATAK_WIDTH=12` | 108-bit beat. |
| `CFG_E_V` | `INGRESS_DATA_WIDTH=128, INGRESS_DATAK_WIDTH=16` | 144-bit beat — exercises `LANE_FIFO_WIDTH=144+3` min. |
| `CFG_E_W` | `PAGE_RAM_RD_WIDTH=72`  | 2 ingress symbols per egress beat — `empty[0:0]`. |
| `CFG_E_X` | `PAGE_RAM_RD_WIDTH=108` | 3 symbols per beat — `empty[1:0]`. |
| `CFG_E_Y` | `PAGE_RAM_RD_WIDTH=144` | 4 symbols per beat. |
| `CFG_E_Z` | `PAGE_RAM_RD_WIDTH=288` | 8 symbols per beat — max egress packing, largest `empty` field. |
| `CFG_E_AA` | `LANE_FIFO_WIDTH=39` | Min lane FIFO word = data+datak+3 control bits. |
| `CFG_E_AB` | `LANE_FIFO_WIDTH=80` | Larger lane FIFO word, paired with `CFG_E_T`. |
| `CFG_E_AC` | `CHANNEL_WIDTH=0` | Channel port is absent — egress port drops the `channel` signal. |
| `CFG_E_AD` | `CHANNEL_WIDTH=4` | Max channel width in `cov_cfg`. |
| `CFG_E_AE` | `TRACK_HEADER=false` | `running_ts` is inferred (F4 inferred-ts path). |
| `CFG_E_AF` | `DEBUG_LV=0` | Non-debug build boundary (F10 corner). |
| `CFG_E_AG` | `MODE=MULTIPLEXING` | Round-robin egress ordering. |
| `CFG_E_AH` | `N_LANE=1` | Single-lane degenerate arbiter path. |
| `CFG_E_AI` | `N_LANE=2` | Minimum multi-lane arbiter. |
| `CFG_E_AJ` | `N_LANE=16` | Max lane count in `cov_cfg`. |
| `CFG_E_AK` | `HDR_SIZE=3` | Minimum header size — compresses `WRITE_HEAD` window. |
| `CFG_E_AL` | `HDR_SIZE=8` | Max header size in the parameter space. |
| `CFG_E_AM` | `TRL_SIZE=0` | No trailer — `WRITE_TAIL` is a single-cycle pass-through. |
| `CFG_E_AN` | `TRL_SIZE=2` | Larger trailer. |
| `CFG_E_AO` | `SHD_SIZE=1, HIT_SIZE=1` | Default — 1 beat each. |
| `CFG_E_AP` | `N_LANE=4, LANE_FIFO_DEPTH=16, TICKET_FIFO_DEPTH=2` | Compound-edge config: every FIFO is at its shallow edge. |
| `CFG_E_AQ` | `LANE_FIFO_DEPTH=16, HANDLE_FIFO_DEPTH=2` | Shallow lane + shallow handle pair. |

---

## 3. Test Case Catalog

All status fields start `planned`. IDs are 3-digit zero-padded. The rationale cell
is the part the reviewer reads — it names the RTL path and the off-by-one.

### 3.1 Lane FIFO depth boundaries

Targets the per-lane `lane_fifo` credit logic inside `ingress_parser` and the
`wptr == rptr` vs `wptr == rptr + DEPTH` full/empty distinguisher.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E001 | CFG_E_A | Drive exactly `LANE_FIFO_DEPTH-1` beats (15) into lane 0, stop; no block_mover drain yet. | No mask; all 15 beats cleanly retained; parser still accepts next beat. | cov_flow.lane_fifo_occupancy[high] | One-below-full: credit checker must report 1 credit remaining. Catches a distinguisher-bit off-by-one where `full` asserts one cycle early. | planned |
| E002 | CFG_E_A | Drive exactly `LANE_FIFO_DEPTH` beats (16) into lane 0, stop. | Last beat accepted, credits at 0, `full` asserted the next cycle. | cov_flow.lane_fifo_occupancy[full] | Exactly-full: `wptr == rptr + DEPTH`. Verifies the full flag does not coincide with an off-by-one false empty. | planned |
| E003 | CFG_E_A | Drive `LANE_FIFO_DEPTH` beats, then one more beat of the **same** packet. | 17th beat drops the whole in-flight packet via MASK_PKT. Scoreboard records a masked packet. | cov_flow.lane_fifo_occupancy[full] | Exactly-full + 1: parser must transition IDLE→MASK_PKT at the exact `full` cycle, not one cycle late. | planned |
| E004 | CFG_E_A | Fill lane 0 to full, let block_mover drain exactly 1 beat, push 1 more beat. | Accepted (credit restored). | cov_flow.lane_fifo_occupancy[high] | Credit return on pop: rptr advance must visibly release a credit in the same cycle it advances, not one cycle later. | planned |
| E005 | CFG_E_A | Drain to empty after filling to full; on the cycle rptr catches wptr, drive a new beat. | Beat accepted; `empty` drops immediately. | cov_flow.lane_fifo_occupancy[empty] | Empty→non-empty edge on simultaneous push/pop. Catches a stale `empty` latch. | planned |
| E006 | CFG_E_A | Simultaneous push+pop from the empty state (rptr==wptr). | Push accepted, pop blocked (empty wins); next cycle pop accepted. | cov_flow.lane_fifo_occupancy[empty] | Read-while-empty guard. | planned |
| E007 | CFG_E_A | Simultaneous push+pop from the full state (rptr+DEPTH==wptr). | Pop wins; push accepted immediately after. | cov_flow.lane_fifo_occupancy[full] | Write-while-full guard vs drain priority. | planned |
| E008 | CFG_E_B | Fill to `DEPTH-1` (63), pause, then alternate 1 push / 1 pop for 4 × DEPTH beats. | Occupancy oscillates around `DEPTH-1`. | cov_flow.lane_fifo_occupancy[high] | Steady-state near-full oscillation — catches races where `full` latches. | planned |
| E009 | CFG_E_B | Drive `DEPTH` beats, drain `DEPTH` beats, drive `DEPTH` beats. | First wptr wrap observed; no credit leak. | cov_flow.lane_fifo_occupancy[full→empty→full] | Pointer wrap at `DEPTH`. Catches pointer-extension missing the guard bit. | planned |
| E010 | CFG_E_C | Drive `DEPTH-1` (4095) beats, one drain, one push. | Accepted; `full` reached exactly at 4096. | cov_flow.lane_fifo_occupancy[full] | 12-bit pointer width boundary. | planned |
| E011 | CFG_E_C | Drive `DEPTH` (4096) beats uniformly over all 4 lanes simultaneously (each lane == full at same cycle). | All four lanes at exactly full; `page_allocator` FETCH_TICKET must fairly service all. | cov_fsm.page_allocator[FETCH_TICKET] | 4-way simultaneous-full edge — checks that the cross-lane credit accounting is independent. | planned |
| E012 | CFG_E_D | Drive `DEPTH-2`, `DEPTH-1`, `DEPTH` beats across three txns. | 17-bit pointer reaches exact full. | cov_flow.lane_fifo_occupancy[full] | Max depth, max pointer width. | planned |
| E013 | CFG_E_D | Drive `DEPTH` beats, drain 1, drive 1 (pointer wraps through `DEPTH`). | Smooth wrap. | cov_flow.lane_fifo_occupancy[full] | 17-bit wrap at the extreme. | planned |
| E014 | CFG_E_A | Drive beats slowly (1 beat every 16 cycles) while the block_mover drains at full rate. | Fifo hovers at 0..1 entries. | cov_flow.lane_fifo_occupancy[low] | Near-empty steady state — stresses the empty-flag hysteresis. | planned |
| E015 | CFG_E_AP | 4 lanes fill simultaneously to exactly `DEPTH` (16). | All four reach full on the same cycle; FETCH_TICKET sees 4 pending SOPs. | cov_fsm.page_allocator[FETCH_TICKET] | Compound shallow-edge config, multi-lane simultaneous full. | planned |

### 3.2 Ticket FIFO depth boundaries

Targets `ticket_fifo` credit plumbing between `ingress_parser` (producer) and
`page_allocator.FETCH_TICKET` (consumer). The critical arithmetic is the credit
window that gates whether a subheader can produce a ticket at all.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E016 | CFG_E_E | Drive 2 subheaders into lane 0 before page_allocator drains any ticket. | 2 tickets in FIFO, `full`; parser masks the 3rd subheader. | cov_flow.ticket_fifo_occupancy[full] | Depth-2 FIFO: the "two credits and no more" edge. Catches a credit-counter overflow. | planned |
| E017 | CFG_E_E | Drive 1 subheader, let allocator drain it, drive 2 more subheaders rapidly. | 2 tickets accepted; 3rd masks. | cov_flow.ticket_fifo_occupancy[full] | Credit return edge on a depth-2 FIFO — catches a 1-cycle-delayed credit return. | planned |
| E018 | CFG_E_E | Allocator drains one ticket while parser pushes another in the same cycle (rptr++ and wptr++ simultaneous on a depth-2 FIFO). | Both succeed. | cov_flow.ticket_fifo_occupancy[mid] | Simultaneous push/pop on shallowest FIFO — exposes the race. | planned |
| E019 | CFG_E_F | Parser produces tickets faster than allocator drains until exactly 16 tickets are queued; no further pushes. | Ticket FIFO full; 17th push masks. | cov_flow.ticket_fifo_occupancy[full] | Exact fill to 16 — 4-bit counter boundary. | planned |
| E020 | CFG_E_G | `N_SHD=128`, `TICKET_FIFO_DEPTH=128`. Stream one complete frame; exactly 128 tickets accumulate before allocator catches up. | All 128 tickets fit, no mask. | cov_flow.ticket_fifo_occupancy[full] | "Single-frame fit" edge: depth exactly equals worst-case per-frame ticket count. | planned |
| E021 | CFG_E_G | Same as E020 but send 1 extra trailing subheader (129th). | 129th subheader produces a masked packet. | cov_flow.ticket_fifo_occupancy[full] | One-over the N_SHD fit edge. | planned |
| E022 | CFG_E_H | Drive 255 subheaders, pause, drive 1 more. | 256 tickets in FIFO, full reached. | cov_flow.ticket_fifo_occupancy[full] | 8-bit counter boundary. | planned |
| E023 | CFG_E_H | Drive 256 subheaders in one burst, then drain via allocator, then drive 1. | Drain empties the FIFO to 0, then 1 accepted. | cov_flow.ticket_fifo_occupancy[empty] | 256→0→1 transition at max depth. | planned |
| E024 | CFG_E_F | Alternate 1 subheader / 1 drain for 64 cycles. | Occupancy hovers at 1. | cov_flow.ticket_fifo_occupancy[low] | Steady-state low-water mark. | planned |
| E025 | CFG_E_E | Simultaneous push/pop from empty on a depth-2 FIFO. | Push accepted, pop blocks; next cycle pop succeeds. | cov_flow.ticket_fifo_occupancy[empty] | Empty priority on the shallowest FIFO. | planned |
| E026 | CFG_E_E | Drain 2 tickets simultaneously while parser tries to push 2 tickets in the same cycle (if the architecture permits; otherwise sequential). | Matches expected credit arithmetic. | cov_flow.ticket_fifo_occupancy[mid] | Dual-port race on a depth-2 FIFO — catches a credit double-counting bug. | planned |

### 3.3 Handle FIFO depth boundaries

Note: handle FIFO has **no credit** — boundary rows cover the healthy
block-mover drain edge only. Drop-on-full goes to DV_ERROR.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E027 | CFG_E_I | Allocator produces 1 handle, block mover drains it, allocator produces 1 more. | Occupancy oscillates 0↔1, no drop. | cov_flow.handle_fifo_occupancy[empty] | Depth-2 min — exposes the `wptr==rptr` idle condition. | planned |
| E028 | CFG_E_I | Allocator produces 2 handles while block_mover is in PREP; they queue to full. | Both handles accepted, `full` signalled (drop only if a 3rd arrives; none does here). | cov_flow.handle_fifo_occupancy[full] | Depth-exact full with no overflow. | planned |
| E029 | CFG_E_I | Allocator produces 2 handles, block_mover drains 1, allocator produces 1 more (refill to full). | Full reached again; no drop. | cov_flow.handle_fifo_occupancy[full] | Full→non-full→full transition on a depth-2 FIFO. | planned |
| E030 | CFG_E_J | Fill to 16 while block_mover is PREP (e.g. artificially slow via lane config). | Exactly-full reached. | cov_flow.handle_fifo_occupancy[full] | 4-bit counter boundary on the drain-rate edge. | planned |
| E031 | CFG_E_K | Maximum depth (256) — drive enough ingress to nearly fill, then accelerate the drain. | Occupancy peaks at 255, never full. | cov_flow.handle_fifo_occupancy[high] | 8-bit counter near-full. Max depth without hitting the DV_ERROR drop path. | planned |
| E032 | CFG_E_J | Alternate 1 push / 1 drain for 64 cycles (steady 1). | Occupancy holds at 1. | cov_flow.handle_fifo_occupancy[low] | Low-water steady state. | planned |
| E033 | CFG_E_AQ | Compound config: shallow lane + shallow handle. Drive one well-shaped frame. | Block_mover keeps up; no drop. | cov_flow.handle_fifo_occupancy[mid] | Compound shallow-edge config — two slow paths meeting. | planned |

### 3.4 Page RAM 3-segment transitions (F2)

Targets the 3-segment dynamic page-RAM path in `ftable_presenter` and
`page_allocator.ALLOC_PAGE` / `WRITE_PAGE`. Boundaries are the segment edges and
the wrap of `PAGE_RAM_DEPTH`.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E034 | CFG_E_L | Frame whose write address lands exactly on segment boundary 1→2. | Segment rotation recorded; no double-write. | cov_fsm.ftable_presenter[PRESENTING], SVA opq_page_ram_sva | Write crosses segment 1→2: `ALLOC_PAGE` must compute the new segment base in the same cycle the old fills. Catches an off-by-one in the segment selector. | planned |
| E035 | CFG_E_L | Frame whose write address lands exactly on segment boundary 2→0 (i.e. the segment-index wrap). | Segment index wraps 2→0 cleanly. | SVA opq_page_ram_sva | Segment-index wrap — a 2-bit counter guarded by modulo-3 logic. Classic wrap bug. | planned |
| E036 | CFG_E_L | Read packet that spans the segment boundary exactly mid-packet. | Read continues into the continuation segment; presenter stays PRESENTING. | cov_fsm.ftable_presenter[PRESENTING] | F2 read-continuation path — the "current-read" segment must be treated as read-only until the packet finishes. | planned |
| E037 | CFG_E_L | Write thread catches up to read thread by exactly one segment (write wptr+PAGE_RAM_DEPTH/3 == read rptr). | Write stalls; read continues; once read releases the segment, write resumes. | SVA opq_page_ram_sva | Write-stall-on-segment-collision — verifies the F2 read/write exclusion invariant at the exact collision cycle. | planned |
| E038 | CFG_E_L | Write thread catches up exactly one beat **before** the one-segment guard (wptr+PAGE_RAM_DEPTH/3-1 == rptr). | Write still allowed; guard not yet tripped. | SVA opq_page_ram_sva | Off-by-one on the guard distance. | planned |
| E039 | CFG_E_L | Page RAM wptr reaches `PAGE_RAM_DEPTH-1`, next write. | Wraps to 0 cleanly. | cov_fsm.page_allocator[WRITE_PAGE] | Page RAM pointer wrap — 13-bit width on CFG_E_L. | planned |
| E040 | CFG_E_L | Fill the page RAM with enough packets that rptr wraps from `DEPTH-1`→0 between egress beats. | Egress continues without glitch. | SVA opq_page_ram_sva | Reader-side wrap. | planned |
| E041 | CFG_E_L | Simultaneous wrap: wptr and rptr both at `DEPTH-1` → both wrap. | Both pointers wrap cleanly; no deadlock. | SVA opq_page_ram_sva | Double-wrap-in-same-cycle edge. | planned |
| E042 | CFG_E_M | Repeat E034..E041 on CFG_E_M (`PAGE_RAM_DEPTH=16384`). | Same behavior at 14-bit pointer width. | SVA opq_page_ram_sva | Pointer-width parametric — catches a pointer signal truncated to the wrong width. | planned |
| E043 | CFG_E_L | Read packet that ends exactly on a segment boundary (last beat = last address of segment). | Next packet starts in new segment. | cov_fsm.ftable_presenter[PRESENTING] | End-of-packet exactly at end-of-segment — tests both the EOP latch and the segment-advance latch firing in the same cycle. | planned |
| E044 | CFG_E_L | Write packet that is exactly one segment long. | Consumes one segment in one `ALLOC_PAGE`. | cov_fsm.page_allocator[ALLOC_PAGE] | Packet length == segment length — the max-length no-wrap case. | planned |
| E045 | CFG_E_L | Write packet that is segment-length + 1 beat long. | Spans two segments; segment rotation happens mid-packet. | cov_fsm.page_allocator[ALLOC_PAGE] | One-over segment, stresses the "segment advance inside a write" path. | planned |
| E046 | CFG_E_L | Write thread rotates through all 3 segments consecutively inside one txn. | All three segments used; all three are visible in the probe. | SVA opq_page_ram_sva | Full rotation in one txn — coverage and liveness. | planned |

### 3.5 Lane skew boundaries

Inter-lane skew stresses `page_allocator.FETCH_TICKET`'s "all lanes ready"
requirement (F7). Skew larger than `LANE_FIFO_DEPTH` drops packets → DV_ERROR.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E047 | CFG_E_AI | 2 lanes, skew = 0 (both SOP same cycle). | FETCH_TICKET fires immediately. | cov_flow.ingress_lane_skew[0] | Zero-skew baseline for the boundary comparison. | planned |
| E048 | CFG_E_AI | 2 lanes, skew = 1. | FETCH_TICKET stalls 1 cycle then fires. | cov_flow.ingress_lane_skew[1] | Minimum non-zero skew — tests the per-lane pending-SOP tracker latch. | planned |
| E049 | CFG_E_AI | 2 lanes, skew = 2. | FETCH_TICKET stalls 2 cycles. | cov_flow.ingress_lane_skew[1] | Second-smallest skew. | planned |
| E050 | CFG_E_A | 4 lanes (inherits CFG_E_A), skew = `LANE_FIFO_DEPTH/8` (2). | Stalls 2, then fires; no drop. | cov_flow.ingress_lane_skew[1] | Low skew as fraction of depth. | planned |
| E051 | CFG_E_A | 4 lanes, skew = `LANE_FIFO_DEPTH/4` (4). | No drop. | cov_flow.ingress_lane_skew[10] | Quarter-depth skew. | planned |
| E052 | CFG_E_A | 4 lanes, skew = `LANE_FIFO_DEPTH/2` (8). | No drop, boundary between healthy and near-full. | cov_flow.ingress_lane_skew[LANE_FIFO_DEPTH/2] | Half-depth skew — DV_PLAN §5.4 explicit bin. | planned |
| E053 | CFG_E_A | 4 lanes, skew = `LANE_FIFO_DEPTH-1` (15). | Slowest lane's FIFO fills to `DEPTH-1`, no drop. | cov_flow.ingress_lane_skew[LANE_FIFO_DEPTH-1] | Exact one-under the drop boundary. | planned |
| E054 | CFG_E_C | 4 lanes at CFG_E_C (depth 4096), skew = 100. | No drop; page_allocator stalls appropriately. | cov_flow.ingress_lane_skew[100] | Mid-magnitude skew on a deep FIFO. | planned |
| E055 | CFG_E_C | 4 lanes, skew = 1000. | No drop; large FETCH_TICKET stall visible. | cov_flow.ingress_lane_skew[1000] | Large skew well under depth. | planned |
| E056 | CFG_E_C | 4 lanes, skew = 4095 (`DEPTH-1`). | No drop; slowest lane fills to `DEPTH-1`. | cov_flow.ingress_lane_skew[LANE_FIFO_DEPTH-1] | Largest healthy skew on a deep config. | planned |
| E057 | CFG_E_A | 3 of 4 lanes send SOP same cycle, the 4th is delayed by 1 beat. | FETCH_TICKET stalls 1 cycle then fires. | cov_flow.ingress_lane_skew[1] | N-1 ready, 1 straggler — single-lane tail edge. | planned |
| E058 | CFG_E_A | 3 of 4 lanes send SOP same cycle, the 4th is delayed by `DEPTH-1`. | FETCH_TICKET stalls `DEPTH-1` cycles. | cov_flow.ingress_lane_skew[LANE_FIFO_DEPTH-1] | Maximum single-lane tail. | planned |
| E059 | CFG_E_AJ | 16 lanes, skew = 0. | 16-way simultaneous FETCH_TICKET. | cov_flow.ingress_lane_skew[0] | Wide-fanout zero-skew — stresses the N-way AND reduction. | planned |
| E060 | CFG_E_AJ | 16 lanes, skew = 15 (one per lane, monotonic staircase). | Staircase FETCH_TICKET stalls. | cov_flow.ingress_lane_skew[10] | Each lane 1 cycle apart — every lane is the last at some point. | planned |
| E061 | CFG_E_AH | 1 lane (N_LANE=1), skew is meaningless — drive frame and verify FETCH_TICKET fires unconditionally on first SOP. | Immediate fire. | cov_fsm.page_allocator[FETCH_TICKET] | N_LANE=1 degenerate case — the N-way AND is 1-way. | planned |

### 3.6 N_SHD / N_HIT extremes

Targets `ingress_parser.WR_HITS` hit counter and the per-frame subheader count.
(`N_HIT+1` overflow is DV_ERROR; here we only go up to the exact max.)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E062 | CFG_E_N | Frame with exactly 1 subheader. | Single subheader accepted, EOP at subh 1. | cov_pkt.subh_per_hdr[1] | Minimum subh count — tests the "first subh is also last" path. | planned |
| E063 | CFG_E_N | Frame with exactly 2 subheaders. | Both accepted. | cov_pkt.subh_per_hdr[2] | Smallest multi-subh frame. | planned |
| E064 | CFG_E_N | Frame with exactly `N_SHD-1` = 127 subheaders. | All 127 accepted; EOP at 127. | cov_pkt.subh_per_hdr[127] | One-under max — catches a premature EOP. | planned |
| E065 | CFG_E_N | Frame with exactly `N_SHD` = 128 subheaders. | All 128 accepted; EOP at 128. | cov_pkt.subh_per_hdr[128] | Exact max — the EOP-forced path. | planned |
| E066 | CFG_E_O | Frame with exactly `N_SHD` = 256 subheaders. | All accepted. | cov_pkt.subh_per_hdr[N_SHD] | Max at default N_SHD. | planned |
| E067 | CFG_E_P | Frame with exactly 511 subheaders. | All accepted. | cov_pkt.subh_per_hdr[N_SHD-1] | One-under max at N_SHD=512. | planned |
| E068 | CFG_E_P | Frame with exactly 512 subheaders. | All accepted. | cov_pkt.subh_per_hdr[N_SHD] | Exact max on the largest N_SHD. | planned |
| E069 | CFG_E_N | Two consecutive frames, each with exactly `N_SHD` subheaders. | First frame EOP, second frame SOP, no gap-merge error. | cov_pkt.subh_per_hdr[N_SHD] | Frame-boundary at max subh — exercises the "last+1 transitions to next frame" path. | planned |
| E070 | CFG_E_O | One subheader with 0 hits. | Subheader accepted, zero hit beats emitted. | cov_pkt.hits_per_subh[0] | Empty-subheader path — no WR_HITS work at all. | planned |
| E071 | CFG_E_O | One subheader with 1 hit. | 1 hit beat. | cov_pkt.hits_per_subh[1] | Smallest non-empty. | planned |
| E072 | CFG_E_O | One subheader with 2 hits. | 2 hit beats. | cov_pkt.hits_per_subh[2] | Second smallest. | planned |
| E073 | CFG_E_Q | One subheader with `N_HIT-1` = 254 hits. | All accepted. | cov_pkt.hits_per_subh[N_HIT] | One-under — checks the hit counter doesn't prematurely hit_err. | planned |
| E074 | CFG_E_Q | One subheader with exactly `N_HIT` = 255 hits. | All accepted, no hit_err. | cov_pkt.hits_per_subh[N_HIT] | Exact max — the "255 accepted, 256 would drop" boundary. (The 256 case belongs to DV_ERROR F5.) | planned |
| E075 | CFG_E_R | One subheader with exactly `N_HIT` = 2047 hits. | All accepted. | cov_pkt.hits_per_subh[N_HIT] | 11-bit hit counter boundary. | planned |
| E076 | CFG_E_O | A frame in which every subheader has exactly `N_HIT` hits. | Maximum density frame. | cov_pkt.hits_per_subh[N_HIT] | Dense-hit frame exposes the `WR_HITS` reset-on-new-subh path at max density. | planned |

### 3.7 frame_ts / shd_ts wrap

Targets F3 (`frame_ts` advance-after-header timing) and the 8-bit `shd_ts` wrap.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E077 | CFG_E_S | Frame with frame_ts = `2^48 - 2`. | Accepted; running_ts at end equals `2^48 - 2`. | cov_pkt.frame_ts_wrap[near-wrap] | 2 ticks from wrap, no wrap yet. | planned |
| E078 | CFG_E_S | Frame with frame_ts = `2^48 - 1`. | Accepted. | cov_pkt.frame_ts_wrap[near-wrap] | Exact wrap-minus-1. | planned |
| E079 | CFG_E_S | Frame with frame_ts = `2^48 - 1` followed immediately by frame_ts = 0. | 48-bit wrap observed; no MERGING sort inversion. | cov_pkt.frame_ts_wrap[post-wrap] | The wrap edge — tests the MERGING aggregator understands post-wrap ordering. | planned |
| E080 | CFG_E_S | Stream across the wrap such that `running_ts` crosses wrap mid-frame (frame with subheaders straddling). | Each subh advances correctly; no subh lost. | cov_pkt.frame_ts_wrap[post-wrap] | Mid-frame running_ts wrap — stresses the F3 advance-after-header path. | planned |
| E081 | CFG_E_N | `N_SHD=128` — drive one frame so `shd_ts[7:0]` counts 0x00..0x7F. | All accepted. | cov_pkt.shd_ts_pattern[0x00], [0x7F] | 0x7F is the MSB-transition point on an 8-bit counter; must increment to 0x80 at subh 0x80. | planned |
| E082 | CFG_E_O | `N_SHD=256` — drive one frame with shd_ts touching 0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF. | All 6 patterns hit. | cov_pkt.shd_ts_pattern[all] | 8-bit full sweep inside one frame. | planned |
| E083 | CFG_E_O | Frame whose first subh has shd_ts=0x7F. | Accepted. | cov_pkt.shd_ts_pattern[0x7F] | High-bit-set SOP. | planned |
| E084 | CFG_E_O | Frame whose first subh has shd_ts=0x80. | Accepted. | cov_pkt.shd_ts_pattern[0x80] | MSB set at SOP. | planned |
| E085 | CFG_E_O | Frame whose last subh has shd_ts=0xFE. | Accepted; EOP at 0xFE. | cov_pkt.shd_ts_pattern[0xFE] | One-under 8-bit max. | planned |
| E086 | CFG_E_O | Frame whose last subh has shd_ts=0xFF. | Accepted; EOP at 0xFF. | cov_pkt.shd_ts_pattern[0xFF] | Exact 8-bit max at EOP. | planned |
| E087 | CFG_E_P | `N_SHD=512` — shd_ts wraps 0xFF→0x00 inside a single frame (twice). | All 512 accepted. | cov_pkt.shd_ts_pattern[0xFF, 0x00] | In-frame shd_ts wrap — exposes whether the parser confuses wrap with new-frame. | planned |
| E088 | CFG_E_S | Two consecutive frames with shd_ts patterns [...0xFF] and [0x00...]. | No frame-merge. | cov_pkt.shd_ts_pattern[wrap across frame] | Tests SOP detection is not confused by shd_ts alone. | planned |

### 3.8 Ingress / egress width extremes

Targets `INGRESS_DATA_WIDTH`, `INGRESS_DATAK_WIDTH`, `LANE_FIFO_WIDTH`, and
`PAGE_RAM_RD_WIDTH` parameterisation. Each row is a small-but-complete txn to
confirm the width path wires cleanly.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E089 | CFG_E_T  | 1 frame, 4 subh, 4 hits each, 64+8-bit beats. | Cleanly egressed. | cov_cfg.ingress_data_width[64] | 72-bit beat; smallest valid SHD becomes 1 beat. Tests DATAK alignment. | planned |
| E090 | CFG_E_U  | 1 frame, 96+12-bit beats. | Cleanly egressed. | cov_cfg.ingress_data_width[96] | 108-bit beat. | planned |
| E091 | CFG_E_V  | 1 frame, 128+16-bit beats. | Cleanly egressed. | cov_cfg.ingress_data_width[128] | Largest ingress beat. | planned |
| E092 | CFG_E_W  | 1 frame at 72-bit egress (2 symbols/beat). | `empty[0]` non-zero only on final beat if odd symbol count. | cov_cfg.page_ram_rd_width[72] | 2:1 pack — smallest non-trivial `empty`. | planned |
| E093 | CFG_E_X  | 1 frame at 108-bit egress (3 symbols/beat). | `empty[1:0]` ∈ {0,1,2}. | cov_cfg.page_ram_rd_width[108] | 3:1 pack — non-power-of-2 divide. | planned |
| E094 | CFG_E_Y  | 1 frame at 144-bit egress (4 symbols/beat). | `empty[1:0]` used. | cov_cfg.page_ram_rd_width[144] | 4:1 pack. | planned |
| E095 | CFG_E_Z  | 1 frame at 288-bit egress (8 symbols/beat). | `empty[2:0]` used; exercises the largest `empty` field. | cov_cfg.page_ram_rd_width[288] | Maximum egress packing — largest `empty` width path. | planned |
| E096 | CFG_E_Z  | Packet length = 1 symbol (so `empty = 7` on the final beat). | `empty=7`, single beat, SOP+EOP. | cov_cfg.page_ram_rd_width[288] | Exact max-`empty` case. | planned |
| E097 | CFG_E_Z  | Packet length = 8 symbols (exactly one beat, `empty=0`). | `empty=0`, single beat. | cov_cfg.page_ram_rd_width[288] | Exact fit into one beat. | planned |
| E098 | CFG_E_Z  | Packet length = 9 symbols (two beats, `empty=7` on the second). | Two beats, `empty=7`. | cov_cfg.page_ram_rd_width[288] | One-over exact fit — exposes any off-by-one in the pack counter. | planned |
| E099 | CFG_E_AA | Min lane FIFO word = `data+datak+3`. | Cleanly written/read. | cov_cfg.lane_fifo_width[39] | Minimum LANE_FIFO_WIDTH — catches silently-widened probes. | planned |
| E100 | CFG_E_AB | 80-bit lane FIFO word with CFG_E_T. | Cleanly written/read. | cov_cfg.lane_fifo_width[80] | Wide lane FIFO word paired with 72-bit beat. | planned |

### 3.9 Egress `ready` boundary patterns

Healthy backpressure edges only — duty sweeps and sustained patterns are DV_PROF.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E101 | CFG_E_S | egress `ready` stuck high for entire txn. | No RESTART entry. | cov_flow.egress_ready_duty[100%] | Baseline — no F1 path. | planned |
| E102 | CFG_E_S | 1-beat stuck-low window on the first beat of a packet. | Presenter enters RESTART; pre-stall beat equals post-restart beat. | cov_fsm.ftable_presenter[RESTART] | Stall at SOP — edge of the "no work done yet" path. | planned |
| E103 | CFG_E_S | 1-beat stuck-low window on beat 1 of a packet. | RESTART; rollback equals `EGRESS_DELAY+1` beats. | cov_fsm.ftable_presenter[RESTART] | First-mid-packet stall — smallest rollback. | planned |
| E104 | CFG_E_S | 1-beat stuck-low window on beat `EGRESS_DELAY` of a packet. | RESTART; rollback refills correctly. | cov_fsm.ftable_presenter[RESTART] | Stall exactly at the pipeline-fill boundary. | planned |
| E105 | CFG_E_S | 1-beat stuck-low window on beat `EGRESS_DELAY+1` of a packet. | RESTART; rollback one deeper. | cov_fsm.ftable_presenter[RESTART] | One-over pipeline depth — rollback must still work. | planned |
| E106 | CFG_E_S | 1-beat stuck-low window on the last beat of a packet. | RESTART; only last beat rolls back and re-emits. | cov_fsm.ftable_presenter[RESTART] | Stall at EOP — the "last beat already latched for EOP" path. | planned |
| E107 | CFG_E_S | 1-beat stuck-low window one beat after EOP (idle phase). | No RESTART; no presenter work. | cov_fsm.ftable_presenter[IDLE] | Post-EOP stall is a no-op — catches a spurious RESTART. | planned |
| E108 | CFG_E_S | Toggle period of 2 (alternating ready/!ready) for 16 beats of a packet. | Each stall enters RESTART; eventually packet completes. | cov_flow.egress_ready_toggle_period[2] | Tightest toggle — every other cycle is a rollback. | planned |
| E109 | CFG_E_S | Toggle period equal to `EGRESS_DELAY+1` for one full packet. | Each stall is one rollback window deep. | cov_flow.egress_ready_toggle_period[EGRESS_DELAY+1] | Period matching the pipeline depth — rollback exactly re-fills. | planned |
| E110 | CFG_E_S | Toggle period of 4 for one packet. | Stalls at predictable positions. | cov_flow.egress_ready_toggle_period[4] | Small period, not matching pipeline depth. | planned |
| E111 | CFG_E_S | Stuck-low for 1 beat, then high for 1 beat, repeated 3×, inside one packet. | 3 distinct RESTART entries. | cov_fsm.ftable_presenter[RESTART] | Multiple RESTART entries within a single packet — catches a latched RESTART state. | planned |
| E112 | CFG_E_S | Stuck-low exactly `EGRESS_DELAY` cycles, then released. | One RESTART entry; rollback exactly equal to the delay. | cov_fsm.ftable_presenter[RESTART] | Stall duration equals rollback distance. | planned |
| E113 | CFG_E_S | Stuck-low `EGRESS_DELAY+1` cycles. | RESTART; rollback still correct. | cov_fsm.ftable_presenter[RESTART] | One-over — stall outlasts the refill window. | planned |

### 3.10 RESTART entry boundaries (F1)

Additional granular stall-position cases, decoupled from the toggle tests above.
Each row pins the stall to an explicit beat index to force the refill window to
operate on a specific packet-layout alignment.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E114 | CFG_E_W | Stall on beat 0 with `PAGE_RAM_RD_WIDTH=72`. | RESTART; pre-stall symbol is re-emitted, `empty` field unchanged. | cov_fsm.ftable_presenter[RESTART] | Stall at SOP on a 2:1 packed beat — tests `empty` field restoration. | planned |
| E115 | CFG_E_W | Stall on the beat that carries EOP + non-zero `empty`. | RESTART; rollback preserves the `empty` marker. | cov_fsm.ftable_presenter[RESTART] | EOP beat with `empty` != 0 — rollback must preserve both flags. | planned |
| E116 | CFG_E_Z | Stall on beat 0 of an 8-symbol packed egress (`empty=0`). | RESTART; beat is re-emitted identically. | cov_fsm.ftable_presenter[RESTART] | Widest egress word, stall at SOP. | planned |
| E117 | CFG_E_Z | Stall on the last beat of an 8-symbol packed egress with `empty=7`. | RESTART; re-emitted with `empty=7`. | cov_fsm.ftable_presenter[RESTART] | Combines the widest word with max `empty` and the EOP stall. | planned |
| E118 | CFG_E_S | Stall mid-packet while `block_mover` is still writing new packets into the adjacent segment. | RESTART; F2 read/write exclusion still holds. | SVA opq_page_ram_sva | RESTART × active writer in a different segment — cross-path check. | planned |
| E119 | CFG_E_S | Stall immediately after the presenter leaves VERIFY. | RESTART from VERIFY→PRESENTING→RESTART path. | cov_fsm.ftable_presenter[VERIFY,RESTART] | Tight VERIFY→RESTART sequence — catches a missing VERIFY exit guard. | planned |
| E120 | CFG_E_S | Stall during WARPING. | WARPING must complete or be rolled back per F1 semantics. | cov_fsm.ftable_presenter[WARPING,RESTART] | WARPING × backpressure — rare state cross. | planned |

### 3.11 Arbiter + block_mover boundary

Targets `arbiter` LOCKING/LOCKED and `block_mover.ABORT_WRITE_BLK` healthy path.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E121 | CFG_E_AI | Two lanes release + pending in the same cycle (lane A releases, lane B presents a pending handle). | Arbiter transitions LOCKED→IDLE→LOCKING→LOCKED in consecutive cycles; lane B wins cleanly. | cov_fsm.arbiter[LOCKING,LOCKED] | Cycle-exact handoff — catches a missing IDLE slot or a priority inversion. | planned |
| E122 | CFG_E_AI | Two lanes exactly one cycle apart — lane A handle lands, 1 cycle later lane B handle lands. | Sequential arbiter grants, no contention. | cov_fsm.arbiter[LOCKING,LOCKED] | Smallest gap that does not race. | planned |
| E123 | CFG_E_AI | Two lanes present pending handles exactly simultaneously at LOCKING. | Arbiter deterministic tiebreak per spec. | cov_fsm.arbiter[LOCKING] | Simultaneous-pending — tiebreak correctness. | planned |
| E124 | CFG_E_AJ | 16 lanes all present handles in the same cycle. | Arbiter services all 16 across 16 LOCKED windows. | cov_fsm.arbiter[LOCKED] | Wide-fanout contention, still fair — no priority inversion. | planned |
| E125 | CFG_E_AI | Block_mover enters PREP, handle is stale (stale flag set by probe-assisted sequence but the page has not been torn). | PREP→ABORT_WRITE_BLK→IDLE; no page corruption, no ingress error. | cov_fsm.block_mover[ABORT_WRITE_BLK] | F8 healthy abort — stale handle without actual tear, the "rollback only" path. | planned |
| E126 | CFG_E_AI | Block_mover enters PREP, immediately sees new handle that is valid — does **not** take the abort path. | PREP→WRITE_BLK; no abort. | cov_fsm.block_mover[WRITE_BLK] | Negative control for E125 — catches a falsely-triggered abort. | planned |
| E127 | CFG_E_AI | ABORT_WRITE_BLK exits while a second handle is already in the handle FIFO. | ABORT→IDLE→PREP on the next handle with no drop. | cov_fsm.block_mover[ABORT_WRITE_BLK,PREP] | Exit edge with queued work — catches a dropped second handle. | planned |

### 3.12 TRACK_HEADER=false inferred-ts boundary

Targets the F4 running-ts re-sync path when `TRACK_HEADER=false` and per-frame
loss approaches `N_SHD`.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E128 | CFG_E_AE | `TRACK_HEADER=false`, drive a frame where all lanes emit normally (no loss). | running_ts tracks frame_ts cleanly. | cov_cfg.track_header[false] | Baseline for the inferred-ts path. | planned |
| E129 | CFG_E_AE | `TRACK_HEADER=false`, drop 1 subheader via a non-error rate-limit gap (not an error injection — just lane idle). | Inferred running_ts advances by 1 tick. | cov_cfg.track_header[false] | Tiny inference gap. | planned |
| E130 | CFG_E_AE | Gap equal to `N_SHD/2` subheaders. | Inferred running_ts advances by N_SHD/2 ticks; no wrap. | cov_cfg.track_header[false] | Mid-magnitude inference. | planned |
| E131 | CFG_E_AE | Gap equal to `N_SHD-1` subheaders. | Inferred running_ts advances by N_SHD-1 ticks; one-under boundary. | cov_cfg.track_header[false] | One-under the maximum safe inference window. Past this, ts information is lost and the path becomes DV_ERROR territory. | planned |
| E132 | CFG_E_AE | Gap equal to exactly `N_SHD` subheaders. | Inferred running_ts rolls forward by exactly one frame. | cov_cfg.track_header[false] | Exact-frame inference — the edge between "still in this frame" and "next frame" when there's no header. | planned |
| E133 | CFG_E_AE | Gap across a frame_ts 48-bit wrap. | Inferred running_ts wraps correctly. | cov_cfg.track_header[false], cov_pkt.frame_ts_wrap[post-wrap] | Inference × frame_ts wrap — compound edge. | planned |

### 3.13 Minimum CHANNEL_WIDTH / DEBUG_LV build boundaries

Build-time boundaries. Each row is a small happy-path txn whose point is that
the RTL still elaborates and behaves correctly when an optional signal is absent.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E134 | CFG_E_AC | `CHANNEL_WIDTH=0` — drive one frame, no `channel` port on either ingress or egress. | Egress packet correctly routed using only lane index. | cov_cfg.channel_width[0] | The channel port is elided; catches any signal the RTL still drives into a 0-width bus. | planned |
| E135 | CFG_E_AC | `CHANNEL_WIDTH=0` × `N_LANE=4`. | All 4 lanes round-trip. | cov_cfg.channel_width[0] | 0-width channel × multi-lane. | planned |
| E136 | CFG_E_AD | `CHANNEL_WIDTH=4` — drive 16 distinct channel values across a txn. | Channel propagates unchanged through the egress. | cov_cfg.channel_width[4] | Max channel width. | planned |
| E137 | CFG_E_AF | `DEBUG_LV=0` — regression smoke on the non-debug build. | No `opq_overwrite_debug.log` written; functional behavior identical to CFG_E_S. | cov_cfg (DEBUG_LV=0 bin if present) | F10 — non-debug build must not regress. Catches code that's guarded behind `DEBUG_LV ≥ 1`. | planned |
| E138 | CFG_E_AF | `DEBUG_LV=0` with the 3-segment rotation path fully exercised. | Rotation still works without debug hooks. | SVA opq_page_ram_sva | Non-debug build × F2 path. | planned |

### 3.14 MODE × HDR_SIZE / TRL_SIZE boundaries

Boundary cases for HDR_SIZE/TRL_SIZE min/max and for the MULTIPLEXING mode edge.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E139 | CFG_E_AK | `HDR_SIZE=3`. Drive one normal frame. | `WRITE_HEAD` completes in 3 cycles. | cov_cfg.hdr_size[min] | Min header — the shortest WRITE_HEAD window. | planned |
| E140 | CFG_E_AL | `HDR_SIZE=8`. Drive one normal frame. | `WRITE_HEAD` completes in 8 cycles. | cov_cfg.hdr_size[max] | Max header — the longest WRITE_HEAD window. | planned |
| E141 | CFG_E_AM | `TRL_SIZE=0`. `WRITE_TAIL` is a pass-through. | Frame ends at last subheader; no trailer beat. | cov_cfg.trl_size[0] | Min trailer — state machine must skip WRITE_TAIL. | planned |
| E142 | CFG_E_AN | `TRL_SIZE=2`. | 2-beat trailer. | cov_cfg.trl_size[2] | Larger trailer. | planned |
| E143 | CFG_E_AG | `MODE=MULTIPLEXING`, 4 lanes, 4 frames each. | Round-robin egress order; no sort. | cov_cfg.mode[MULTIPLEXING] | Mode edge: aggregator takes the non-sorting path. | planned |
| E144 | CFG_E_AG | `MODE=MULTIPLEXING` × `N_LANE=1`. | Single-lane MULTIPLEXING degenerates to identity. | cov_cfg.mode[MULTIPLEXING] | Degenerate MULTIPLEXING. | planned |

### 3.15 First-frame shortened (F4)

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E145 | CFG_E_N | First frame after reset has exactly 127 subheaders (N_SHD=128, so 1 short). | FETCH_TICKET re-sync via `running_ts <- frame_ts` on the second frame's SOP. | cov_pkt.first_frame_short | F4 re-sync path — one-under N_SHD on the very first frame. | planned |
| E146 | CFG_E_N | First frame has exactly 1 subheader. | Re-sync still works. | cov_pkt.first_frame_short | Smallest legal first frame. | planned |
| E147 | CFG_E_O | First frame short (255 subh instead of 256) at default N_SHD. | Re-sync. | cov_pkt.first_frame_short | Mid-value shortened-first-frame. | planned |
| E148 | CFG_E_P | First frame short (511 subh instead of 512). | Re-sync. | cov_pkt.first_frame_short | Largest N_SHD shortened-first-frame. | planned |

### 3.16 Compound shallow-edge cases

Compound configs where multiple edges coexist. These are intentionally narrow
single-event transactions — the multi-axis long runs live in DV_CROSS.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E149 | CFG_E_AP | Shallow lane + depth-2 ticket + default handle. One well-sized frame. | All three queues stay within their shallow bounds. | cov_flow.lane_fifo_occupancy, ticket_fifo_occupancy | Compound shallow lane + ticket — two credit counters in tandem. | planned |
| E150 | CFG_E_AQ | Shallow lane + shallow handle. | Lane stays near full; handle drains 1-by-1. | cov_flow.lane_fifo_occupancy, handle_fifo_occupancy | Compound lane + handle — the two "fullest" signals at once. | planned |
| E151 | CFG_E_AP | 4 lanes, skew = `LANE_FIFO_DEPTH-1` = 15, `TICKET_FIFO_DEPTH=2`. | Slowest lane fills to `DEPTH-1`; ticket FIFO never overflows because allocator drains as fast as parser produces. | cov_flow.ingress_lane_skew, ticket_fifo_occupancy | Skew × ticket-shallow compound edge. | planned |
| E152 | CFG_E_AP | 2 frames back-to-back on the compound config with `shd_ts` crossing 0xFF→0x00. | Both frames clean, shallow FIFOs oscillate between 0 and full. | cov_pkt.shd_ts_pattern, cov_flow.lane_fifo_occupancy | Compound config + in-frame shd_ts wrap. | planned |
| E153 | CFG_E_AQ × CFG_E_AE | `TRACK_HEADER=false` on shallow config. | Inferred-ts path survives shallow queues. | cov_cfg.track_header[false] | Inference × shallow FIFOs. | planned |

### 3.17 Reset-state idle edges (no reset *during* state — that is DV_ERROR)

Boundary on starting a transaction from a **specific** idle FSM state so each
state's "first beat out of idle" edge is covered without a mid-state reset.

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E154 | CFG_E_S | Txn starts with all FSMs in IDLE (post-reset cold start). | Normal happy-path frame. | cov_fsm.* | Cold-start baseline for every boundary below — post-reset first beat. | planned |
| E155 | CFG_E_S | Txn starts after a previous txn left `ftable_tracker` in RECORD_TILE. | Next frame still starts cleanly. | cov_fsm.ftable_tracker[RECORD_TILE] | Cross-txn handoff from a non-IDLE state. | planned |
| E156 | CFG_E_S | Txn starts after `ftable_mapper` was just in MODIFY_FRAME_TABLE. | Clean new frame. | cov_fsm.ftable_mapper[MODIFY_FRAME_TABLE] | Cross-txn non-IDLE handoff for the mapper. | planned |
| E157 | CFG_E_S | Txn starts after `ftable_presenter` just left WARPING. | Clean new frame. | cov_fsm.ftable_presenter[WARPING] | Rare-state cross-txn handoff. | planned |

### 3.18 Miscellaneous arithmetic boundaries

| ID | Config | Stimulus | Expected | Covers | RTL path / rationale | Status |
|----|--------|----------|----------|--------|----------------------|--------|
| E158 | CFG_E_S | Packet length exactly equals the page RAM segment length in beats. | No segment rotation mid-packet. | cov_fsm.ftable_presenter[PRESENTING] | Single-packet fits exactly one segment. | planned |
| E159 | CFG_E_S | Packet length = segment length - 1. | No rotation. | cov_fsm.ftable_presenter[PRESENTING] | One-under fit. | planned |
| E160 | CFG_E_S | Packet length = segment length + 1. | Rotation mid-packet. | cov_fsm.ftable_presenter[PRESENTING] | One-over fit — rotation inside an active presentation. | planned |
| E161 | CFG_E_S | Packet length = 1 beat (smallest legal). | SOP == EOP on the same beat. | cov_pkt.hdr_size_words[1] | Single-beat packet — both framing flags on one cycle. | planned |
| E162 | CFG_E_S | Packet with HDR only (no subheaders). | Header-only packet cleanly egressed. | cov_pkt.subh_per_hdr[0] | Minimum meaningful packet — header but no subh body. | planned |
| E163 | CFG_E_S | Packet where `hit_cnt` in the subheader equals exactly `N_HIT`. | No hit_err. | cov_pkt.hits_per_subh[N_HIT] | Exact-max explicit `hit_cnt` field. | planned |
| E164 | CFG_E_S | Back-to-back packets with no idle gap (valid high through both SOPs). | Both cleanly parsed; SVA opq_avst_ingress_sva does not flag. | cov_fsm.ingress_parser[IDLE] | Zero-gap inter-packet — IDLE visited for exactly 0 cycles. | planned |
| E165 | CFG_E_S | Back-to-back packets with exactly 1 idle beat between. | IDLE visited for exactly 1 cycle. | cov_fsm.ingress_parser[IDLE] | One-cycle gap. | planned |
| E166 | CFG_E_S | Frame with subh #1 carrying 0 hits and subh #2 carrying `N_HIT` hits (min→max jump inside one frame). | Both accepted. | cov_pkt.hits_per_subh[0,N_HIT] | Intra-frame density swing — `WR_HITS` must reset cleanly between subheaders. | planned |
| E167 | CFG_E_S | Frame with alternating 0-hit and max-hit subheaders (16 total). | All accepted. | cov_pkt.hits_per_subh[0,N_HIT] | Pattern forces 16 WR_HITS resets. | planned |
| E168 | CFG_E_S | Frame with all-identical subh timestamps (shd_ts constant). | All accepted; ordering within the frame respects insertion. | cov_pkt.shd_ts_pattern[0x00] | Degenerate timestamp — stresses the MERGING tie rule. | planned |

---

## 4. Coverage binding

Each case row's `Covers` column names the covergroup bins it increments; the
sampler hooks in `opq_coverage.sv` (see DV_HARNESS §6) take care of the actual
sampling. The DV_EDGE bucket's minimum coverage obligations:

- **`cov_flow.lane_fifo_occupancy`**: all 5 bins (`empty`, `low`, `mid`, `high`,
  `full`) hit via §3.1 and §3.16.
- **`cov_flow.ticket_fifo_occupancy`**: all 5 bins via §3.2.
- **`cov_flow.handle_fifo_occupancy`**: `empty`, `low`, `mid`, `high`, `full`
  hit via §3.3 healthy-drain rows. The `full → drop` bin is NOT claimed by
  DV_EDGE — it lives in DV_ERROR X-series.
- **`cov_flow.ingress_lane_skew`**: all 7 bins (0, 1, 10, 100, 1000,
  LANE_FIFO_DEPTH/2, LANE_FIFO_DEPTH-1) hit via §3.5.
- **`cov_flow.egress_ready_duty[100%]`** and **`egress_ready_toggle_period`**
  partial bins via §3.9 / §3.10 (full sweep is DV_PROF).
- **`cov_pkt.first_frame_short`**: claimed entirely by §3.15.
- **`cov_pkt.frame_ts_wrap[near-wrap, post-wrap]`**: §3.7.
- **`cov_pkt.shd_ts_pattern`**: all 6 bins via §3.7.
- **`cov_pkt.subh_per_hdr`**: extreme bins (1, 2, 127, 128, N_SHD-1, N_SHD) via
  §3.6; middle bins shared with DV_BASIC.
- **`cov_pkt.hits_per_subh`**: 0, 1, 2, N_HIT-1, N_HIT bins via §3.6 and §3.18.
- **`cov_fsm.ftable_presenter[RESTART]`**: §3.9 + §3.10.
- **`cov_fsm.arbiter[LOCKING, LOCKED]`** boundary cells: §3.11.
- **`cov_fsm.block_mover[ABORT_WRITE_BLK]`** healthy entry: §3.11 E125..E127.
- **`cov_cfg`**: §3.8 exercises every non-default `INGRESS_DATA_WIDTH`,
  `PAGE_RAM_RD_WIDTH`, `LANE_FIFO_WIDTH` bin; §3.13 exercises the min/max
  `CHANNEL_WIDTH` and the `DEBUG_LV=0` boundary; §3.14 exercises `HDR_SIZE`,
  `TRL_SIZE`, and `MODE=MULTIPLEXING`; §3.12 exercises `TRACK_HEADER=false`.

---

## 5. Handoff to later buckets

- **Drop-on-full paths** (lane, ticket, handle, page RAM) are *reached* at their
  credit boundary in DV_EDGE but never *exceeded*. The excess-over-boundary
  cases belong to DV_ERROR (X-series). Each DV_EDGE row that sits one-cycle or
  one-beat short of a drop names the DV_ERROR X-series row that picks up from
  the overflow.
- **Sustained backpressure duty cycles** and **arbiter fairness starvation**
  belong to DV_PROF (P-series). DV_EDGE only fires single-window stalls and
  tight-period toggles to probe the RESTART entry.
- **Error flag propagation** (`hit_err`/`shd_err`/`hdr_err`) is not exercised
  here. Any case touching those flags is a DV_ERROR row.
- **Multi-axis long runs** (FSM × BP × skew × error × config) belong to
  DV_CROSS. DV_EDGE rows are deliberately narrow single-event transactions so
  the boundary under test is unambiguous.

Total case count in §3: **168** (E001..E168). Above the 128 minimum by 40
rows, which reflects the compound-edge §3.16 additions and the §3.8 width
sweep coverage obligations.

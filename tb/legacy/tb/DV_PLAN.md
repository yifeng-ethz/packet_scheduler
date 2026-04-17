# DV Plan: ordered_priority_queue (monolithic)

> Archived with the deprecated `packet_scheduler/tb` + `packet_scheduler/uvm` harness on 2026-04-13. This file remains useful as intent capture, but the live signoff review is now `packet_scheduler/doc/VERIFICATION_SIGNOFF.md`.

**DUT:** `ordered_priority_queue` (monolithic core)
**RTL source:** `packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`
**Packaging:** `packet_scheduler/ordered_priority_queue_hw.tcl` (v26.0.0.0413, no CSR)
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-13
**Status:** Planning. Bucket files are authoritative for the expanded IDs. The split-core `.../split/` tree is deprecated and explicitly out of scope.

---

## 1. Purpose & Scope

`ordered_priority_queue` aggregates `N_LANE` synchronous ingress Avalon-ST flows (one per FEB link) into a single timestamp-ordered egress Avalon-ST flow. The monolithic core owns the full datapath from the per-lane ingress parser down to the read-side page-RAM presenter.

### In-scope

- **Monolithic pipeline only.** All split-tree blocks (`rtl/ordered_priority_queue/split/**`) are deprecated and excluded.
- **All FSMs inside the monolithic core:**
  - `ingress_parser` (per lane): `IDLE, UPDATE_HEADER_TS, MASK_PKT_EXTENDED, MASK_PKT, WR_HITS, RESET`
  - `page_allocator` (global): `IDLE, FETCH_TICKET, WRITE_HEAD, WRITE_TAIL, ALLOC_PAGE, WRITE_PAGE, RESET`
  - `block_mover` (per lane): `IDLE, PREP, WRITE_BLK, ABORT_WRITE_BLK, RESET`
  - `arbiter` (page-RAM write port): `IDLE, LOCKING, LOCKED, RESET`
  - `ftable_mapper`: `IDLE, PREP_UPDATE, UPDATE_FRAME_TABLE, MODIFY_FRAME_TABLE, RESET`
  - `ftable_tracker`: `IDLE, RECORD_TILE, FLUSH_TILE, RESET`
  - `ftable_presenter`: `IDLE, WAIT_FOR_COMPLETE, VERIFY, PRESENTING, RESTART, WARPING, RESET`
- **All HDL generics** surfaced in the `_hw.tcl`: `N_LANE`, `MODE`, `TRACK_HEADER`, `INGRESS_DATA_WIDTH`, `INGRESS_DATAK_WIDTH`, `CHANNEL_WIDTH`, `LANE_FIFO_DEPTH`, `LANE_FIFO_WIDTH`, `TICKET_FIFO_DEPTH`, `HANDLE_FIFO_DEPTH`, `PAGE_RAM_DEPTH`, `PAGE_RAM_RD_WIDTH`, `N_SHD`, `N_HIT`, `HDR_SIZE`, `SHD_SIZE`, `HIT_SIZE`, `TRL_SIZE`, `FRAME_SERIAL_SIZE`, `FRAME_SUBH_CNT_SIZE`, `FRAME_HIT_CNT_SIZE`, `DEBUG_LV`.
- **Ingress FIFO chain:** lane FIFO, ticket FIFO, handle FIFO (credit flow where applicable, drop-on-full where not).
- **Page RAM 3-segment dynamic scheme:** 2 segments for ring-buffer write, 1 for read continuation. Read always sees the current reading packet; write never overwrites the active read segment.
- **Egress backpressure (rollback / RESTART state).** The 2026-01-29 backpressure fix is in scope as a frozen behavior.
- **Timestamp alignment fixes.** The 2026-01-29 `running_ts` / `frame_ts` fixes are frozen.
- **Avalon-ST protocol compliance** on all `ingress_<i>` sinks and the `egress` source.

### Out-of-scope

- Split-tree blocks (`opq_ingress_parser`, `opq_block_mover`, `opq_page_allocator`, `opq_frame_table*`, `opq_top`). Their directed testbenches under `legacy/tb/opq_*` remain but this plan does not retest them.
- `intf_adapter` (covered by its own plan if one exists).
- `random_toggler` (only an in-lane RNG helper).
- The parent Qsys system (`feb_system_v2`, `debug_sc_system_v2`). System-level simulation stays under `system_level_sim/`.
- Quartus place-and-route timing closure (verified separately).
- The vendor RAM primitives (`page_ram`, `tile_fifo`, `handle_fifo`, `lane_fifo`, `ticket_fifo`). They are treated as correct inferred-RAM IP.
- **Runtime software configuration:** there is **no CSR aperture** on this IP (see the `_hw.tcl` Register Map tab). All configuration is at Qsys-generate time; no software path is verified.

---

## 2. DUT Interfaces

| Interface | Type | Width (bits) | Clock | Direction | Notes |
|-----------|------|--------------|-------|-----------|-------|
| `ingress_0 … ingress_<N_LANE-1>` | AVST sink | data = `INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH` (default 36); channel = `CHANNEL_WIDTH`; error = 3 | `d_clk` | in | **Non-backlog**: no `ready` exported. FIFO-full drops the in-flight packet. `error[2:0] = {hit_err, shd_err, hdr_err}`. |
| `egress` | AVST source | data = `PAGE_RAM_RD_WIDTH`; empty = `ceil(log2(symbolsPerBeat))` when &gt;1; error = 3 | `d_clk` | out | Backpressured (`ready` in). Symbol width = ingress beat; symbolsPerBeat = `PAGE_RAM_RD_WIDTH / (INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH)`. |
| `clk_interface` (`d_clk`) | clock | 1 | self | in | Single synchronous datapath clock for all lanes, page RAM, and egress. |
| `rst_interface` (`d_reset`) | reset | 1 | `d_clk` | in | Synchronous both edges. |

There is **no Avalon-MM CSR slave**. The DUT has no software-visible register map; runtime behavior is frozen at Qsys generate time.

---

## 3. Packet / Data Format

All numbers assume the default integration: `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`, so each ingress beat is 36 bits; the upper nibble is `byte_is_k`.

### 3.1 Header packet (super-packet)

Produced by the upstream FEB frame-assembly for each DAQ frame.

| Word | Content |
|------|---------|
| 0 | `k=0x1`, preamble / frame-sync marker (MuTRiG `K28.5`-class symbol) |
| 1 | `frame_ts[47:16]` (upper 32 bits of the 48-bit global timestamp) |
| 2 | `frame_ts[15:0]` concatenated with frame metadata (serial, flags) — parsed by `ingress_parser.UPDATE_HEADER_TS` |
| 3 | `preamble.dt_type[5:0]`, `preamble.feb_id[15:0]` |
| 4 | Frame trailer / checksum (k-flag set) |

`HDR_SIZE` (default 5) is the number of lane-FIFO words claimed by the header packet. The header is written into page RAM by `page_allocator.WRITE_HEAD`.

### 3.2 Subheader packet

Each header packet contains up to `N_SHD` subheader packets. Each subheader holds up to `N_HIT` hits.

| Word | Content |
|------|---------|
| 0 | Subheader: `k=0x1`, `shd_ts[7:0]` (low 8 bits of frame-relative timestamp), `hit_cnt[MAX_PKT_LENGTH_BITS-1:0]` |
| 1 … hit_cnt | Hit words: `k=0x0`, hit payload |

`SHD_SIZE` / `HIT_SIZE` = 1 each. Ingress parser drops hits past `N_HIT` within a subheader and asserts `hit_err` on the egress side.

### 3.3 Ticket (ingress parser → page allocator)

Written to the ticket FIFO as one ticket per decoded event:

```
ticket = { ts[47:0], start_addr[9:0], length[9:0], alert_sop_eop[1:0] }
```

`alert_sop_eop` encodes whether the ticket is an SOP (header start), EOP (header trailer), or plain subheader. Ticket width = `TICKET_FIFO_DATA_WIDTH`.

### 3.4 Handle (page allocator → block mover)

```
handle = { page_ram_start_addr, length, is_header_flag }
```

Width = `HANDLE_LENGTH`. No credit flow — drops mean block mover is too slow (see `DV_ERROR` R-series).

### 3.5 Page-RAM word

Width = `LANE_FIFO_WIDTH` (default 40 bits). The page RAM is read at `PAGE_RAM_RD_WIDTH` (default 36) after the 3-segment dynamic layout remaps addressing.

### 3.6 Egress Avalon-ST beat

| Field | Bits | Description |
|-------|------|-------------|
| `data[PAGE_RAM_RD_WIDTH-1 : 0]` | variable | One or more 36-bit ingress symbols packed MSB-first. |
| `empty[ceil(log2(symbolsPerBeat))-1 : 0]` | present if symbolsPerBeat &gt; 1 | Number of unused symbols in the final beat. |
| `startofpacket / endofpacket` | 1 each | Packet framing for the ordered egress packet. |
| `error[2:0]` | 3 | `{hit_err, shd_err, hdr_err}` — propagated from the ingress parser. |
| `valid / ready` | 1 each | Standard Avalon-ST handshake; egress is backpressured. |

---

## 4. Test Bucket Overview

Test ID convention: `<bucket><nnn>_<short_tag>`. `nnn` is a 3-digit zero-padded ordinal. Each bucket catalog is a standalone markdown file under `legacy/tb/`.

| File | Prefix | Range | Min cases | Rationale |
|------|--------|-------|-----------|-----------|
| `DV_BASIC.md` | B | B001–B999 | **128** | Directed bring-up: per-FSM state-reachability, single-lane & multi-lane happy paths, MERGING vs MULTIPLEXING, TRACK_HEADER on/off, per-generic sanity matrix, smallest valid packet shapes. |
| `DV_EDGE.md`  | E | E001–E999 | **128** | Boundary conditions: FIFO full/empty edges, lane-skew boundaries, `N_SHD`/`N_HIT` extremes, page-RAM 3-segment transitions, `PAGE_RAM_RD_WIDTH` / `INGRESS_DATA_WIDTH` width sweeps, ticket/handle depth corners, first-frame shortened-subframe case. |
| `DV_PROF.md`  | P | P001–P999 | **128** | Performance, stress, and soak: sustained line-rate per lane, worst-case inter-lane skew, arbiter fairness/starvation, long soak runs, backpressure duty cycle sweeps, page-RAM dwell/wrap stress. |
| `DV_ERROR.md` | X | X001–X999 | **128** | Error / reset / fault: `hit_err` / `shd_err` / `hdr_err` injection, truncated packets, mid-packet SOP / missing EOP, reset during every FSM state, lane FIFO / ticket FIFO / handle FIFO / page RAM overflow & drop-on-full, recovery validation. |
| `DV_CROSS.md` | C | C001–C999 | **128** | Long mixed-axis runs exercising cross-coverage cells (FSM × backpressure × skew × error × config). Each scenario is a multi-thousand-cycle transaction that increments multiple bin groups simultaneously. |

Total minimum planned test IDs: **640** (128 × 5). The actual catalog will be ≥ this; bucket files are free to exceed 128.

A separate `DV_HARNESS.md` describes the UVM environment, agents, scoreboard reference model, and SVA bind modules. This DV_PLAN does not specify harness internals beyond names and references.

---

## 5. Coverage Model (functional coverage)

Implementation uses the **full Mentor floating license** (`8161@lic-mentor.ethz.ch`) — `covergroup`, `coverpoint`, `cross`, `rand`, `constraint`, and DPI-C are all allowed. Counter-based collectors are reserved for cases where `covergroup` semantics do not fit (e.g. multi-transaction histories); otherwise use native coverage.

### 5.1 Parameter-space coverage (`cov_cfg`)

| Bin group | Bins |
|-----------|------|
| `mode`              | `MERGING`, `MULTIPLEXING` |
| `track_header`      | `true`, `false` |
| `n_lane`            | 1, 2, 4, 8, 16 |
| `channel_width`     | 0, 1, 2, 3, 4 |
| `lane_fifo_depth`   | 16, 64, 256, 1024, 4096, 16384, 65536 |
| `lane_fifo_width`   | 39, 40, 48, 64, 80 |
| `ticket_fifo_depth` | 2, 16, 64, 128, 256 |
| `handle_fifo_depth` | 2, 16, 64, 128, 256 |
| `page_ram_depth`    | 8192, 16384, 32768, 65536 |
| `page_ram_rd_width` | 36, 72, 108, 144, 180, 216, 252, 288 |
| `n_shd`             | 128, 256, 512 |
| `n_hit`             | 255, 511, 1023, 2047 |

Goal: at least one run of the regression per bin. Aggregated across the full DV_BASIC + DV_EDGE + DV_PROF suite.

### 5.2 FSM coverage (`cov_fsm`)

One `coverpoint` per FSM, one bin per state, and a `cross` of that coverpoint against `is_backpressured` (egress ready low) and `is_errored` (any ingress error asserted during the sample window).

| FSM | States |
|-----|--------|
| `ingress_parser[lane]` | IDLE, UPDATE_HEADER_TS, MASK_PKT_EXTENDED, MASK_PKT, WR_HITS, RESET |
| `page_allocator`       | IDLE, FETCH_TICKET, WRITE_HEAD, WRITE_TAIL, ALLOC_PAGE, WRITE_PAGE, RESET |
| `block_mover[lane]`    | IDLE, PREP, WRITE_BLK, ABORT_WRITE_BLK, RESET |
| `arbiter`              | IDLE, LOCKING, LOCKED, RESET |
| `ftable_mapper`        | IDLE, PREP_UPDATE, UPDATE_FRAME_TABLE, MODIFY_FRAME_TABLE, RESET |
| `ftable_tracker`       | IDLE, RECORD_TILE, FLUSH_TILE, RESET |
| `ftable_presenter`     | IDLE, WAIT_FOR_COMPLETE, VERIFY, PRESENTING, RESTART, WARPING, RESET |

Cross targets:
- `C_PRESENTER_X_BP`: `ftable_presenter` state × `is_backpressured` — must hit PRESENTING×bp, RESTART×bp, WARPING×bp.
- `C_ALLOC_X_LANES`: `page_allocator` state × number-of-pending-lanes.
- `C_BLKMV_X_LANE`: `block_mover[lane]` state × lane index (covers per-lane instances).

### 5.3 Packet-shape coverage (`cov_pkt`)

| Bin group | Bins |
|-----------|------|
| `hits_per_subh`   | 0, 1, 2, 4, 16, 64, 128, 255, `N_HIT` |
| `subh_per_hdr`    | 1, 2, 8, 32, 64, 127, 128, `N_SHD-1`, `N_SHD` |
| `hdr_size_words`  | matches `HDR_SIZE` + optional trailer |
| `shd_ts_pattern`  | 0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF — exercises the low-8-bit subheader timestamp field |
| `frame_ts_wrap`   | low, near-wrap, post-wrap — covers `frame_ts` 48-bit wrap |
| `first_frame_short` | first frame after reset with &lt; `N_SHD` subheaders (2026-01-29 fix) |

### 5.4 Flow-control coverage (`cov_flow`)

| Bin group | Bins |
|-----------|------|
| `egress_ready_duty` | 100%, 75%, 50%, 25%, 10%, 1%, 0% (stuck-low) |
| `egress_ready_toggle_period` | 1, 2, 4, 8, 16, 64 cycles |
| `ingress_lane_skew` | 0, 1, 10, 100, 1000, `LANE_FIFO_DEPTH/2`, `LANE_FIFO_DEPTH-1` beats |
| `ticket_fifo_occupancy` | empty, low, mid, high, full (triggers drop) |
| `lane_fifo_occupancy`   | empty, low, mid, high, full (triggers drop) |
| `handle_fifo_occupancy` | empty, low, mid, high, full (triggers drop) |

### 5.5 Cross-axis coverage (`cov_cross`)

Formal targets listed in `DV_CROSS.md`. Minimum 128 scenario IDs, each driving one or more cells. Cross cells are computed by tuple lookup inside `cov_cross_pkg`.

### 5.6 Coverage targets

| Metric | Target |
|--------|--------|
| Statement (Questa HDL coverage) | ≥ 95 % |
| Branch | ≥ 90 % |
| FSM state / transition | 100 % |
| Toggle (ports + FSM state enums) | ≥ 80 % |
| Functional (covergroups defined in 5.1–5.5) | 100 % |

---

## 6. Frozen RTL Behaviors (reconciled from RTL + changelogs)

These behaviors are locked and the scoreboard must reproduce them. Evidence lives in `rtl/ordered_priority_queue/docs/`.

| # | Behavior | Source | Test binding |
|---|----------|--------|--------------|
| F1 | **Egress stall → RESTART.** On `aso_egress_ready` deassertion at the egress tap, `ftable_presenter` transitions IDLE→…→RESTART, rolls `page_ram_rptr` back by `EGRESS_DELAY+1`, refills the pipeline, and re-enters PRESENTING. `aso_egress_valid` is gated to `PRESENTING` so no word is double-accepted. | `OPQ_RTL_CHANGELOG_backpressure_2026-01-29.txt` | E-series backpressure cases; P-series duty-cycle sweeps; C-series cross × BP. |
| F2 | **3-segment dynamic page-RAM.** 2 segments for ring-buffer write, 1 for current-read continuation. Write never overwrites the active read segment; the next post-read packet leaps to the write-thread tail. Read/write contention is resolved in favour of read-continuation. | `ordered_priority_queue.terp.vhd` (`ftable_presenter` + page_allocator) | E-series page-segment rotation cases. |
| F3 | **`frame_ts` advance timing.** `frame_ts` is advanced *after* the header (and optional trailer) is written, not before. Fixes header-ts off-by-one. | `OPQ_RTL_CHANGELOG_timestamp_alignment_2026-01-29.txt` | B-series header-ts capture case; C-series frame-wrap cross. |
| F4 | **`running_ts` re-sync on frame SOP.** When all lanes have an SOP ticket, `page_allocator.running_ts <= frame_ts` absorbs any drift from shortened first-frame runs. | same | B-series first-frame-short case. |
| F5 | **Ingress hits past `N_HIT`** are dropped by the parser, and `hit_err` is propagated on the produced egress packet. | `ingress_parser.WR_HITS` | X-series hit-overflow cases. |
| F6 | **Ingress lanes are drop-on-full.** No `ready` is exported. When the lane or ticket FIFO cannot accept, the in-flight packet is masked via `MASK_PKT` / `MASK_PKT_EXTENDED`; the next SOP reopens the parser. | `ingress_parser` | X-series drop-on-full cases. |
| F7 | **Page allocator FETCH_TICKET** requires all lanes to have a pending SOP ticket before re-syncing `running_ts`. Absent lanes hold the allocator in FETCH_TICKET. | `page_allocator` | X-series missing-lane case; E-series lane-skew boundary. |
| F8 | **Block mover ABORT_WRITE_BLK.** Entered when the active handle disagrees with the current page-RAM read segment → partial block is rolled back. Recovery returns to IDLE with no output corruption. | `block_mover` | X-series mid-handle abort cases. |
| F9 | **Arbiter LOCKED state** holds page-RAM write-port ownership across a full block. Other lanes wait in IDLE until the active lane releases. No priority inversion is tolerated. | `arbiter` | P-series fairness cases. |
| F10 | **`DEBUG_LV ≥ 2`** enables the sim-only `opq_overwrite_debug.log`. DV regression runs at `DEBUG_LV = 1` (synthesizable debug only). `DEBUG_LV = 0` is a separate corner case (ensures non-debug build still passes). | `OPQ_RTL_CHANGELOG_overwrite_2026-01-30.txt` | B-series DEBUG_LV matrix. |

---

## 7. Signoff Criteria

- **All ≥640 test IDs** across `DV_BASIC` / `DV_EDGE` / `DV_PROF` / `DV_ERROR` / `DV_CROSS` implemented and PASS.
- **Code coverage** (Questa HDL coverage) meets the targets in §5.6.
- **Functional coverage** 100 % of the covergroup bins listed in §5.1–5.5 and the cells listed in `DV_CROSS.md`.
- **Zero SVA firings** across the full regression. SVA modules (see `DV_HARNESS.md`) cover:
  - AVST protocol on each `ingress_<i>` sink
  - AVST protocol on the `egress` source
  - Lane FIFO / ticket FIFO / handle FIFO level invariants
  - 3-segment page-RAM read/write exclusion invariant
  - FSM transition legality for all seven DUT FSMs
- **Zero `UVM_ERROR` / `UVM_FATAL`**. Scoreboard agrees on every egress beat (data, framing, channel, error) and every ticket / handle transition observed through internal probes.
- **Three-layer RTL lint** (Questa source lint, Questa elaboration, Quartus Design Assistant) clean for the monolithic core.
- **No simulator hangs.** Every test is bounded by an env-level watchdog.
- **Chief-architect signoff** on the plan before implementation begins (signoff gate per `dv-workflow`).

---

## 8. Dependencies

- **Harness:** `legacy/tb/DV_HARNESS.md` — UVM environment topology, agent classes, scoreboard reference model, SVA bind modules. This plan defers all harness internals to that file.
- **Simulator:** Questa with the **full Mentor floating license** `8161@lic-mentor.ethz.ch`. Use `rand`/`constraint`, `covergroup`, and DPI-C freely. The `CLAUDE.md` Questa FSE Starter constraints do not apply to this DV run — the floating license overrides them.
- **Reference DV plans:** `ring-buffer_cam/tb/DV_PLAN.md`, `run-control_mgmt/tb/DV_PLAN.md` (bucket-file split pattern).
- **Reference RTL changelogs:** `packet_scheduler/rtl/ordered_priority_queue/docs/OPQ_RTL_CHANGELOG_*.txt` — source-of-truth for frozen behaviors F1–F10.
- **Legacy directed TBs under `packet_scheduler/legacy/tb/opq_*`** are kept as regression input for RTL history but this plan does not re-verify them.
- **Style:** `doc/STYLE.md` for test-ID format and RTL coding rules.

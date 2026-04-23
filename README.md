# Ordered Priority Queue Mu3e IP

Timestamp-ordered packet scheduler for Mu3e merged-frame traffic. It accepts
one `36`-bit ingress symbol per beat (`{datak[3:0], data[31:0]}`) on each FEB
lane, merges lane-local packet streams into shared page storage, and emits a
single ordered Avalon-ST egress stream with explicit per-lane and frame-table
drop accounting.

**Version:** 26.3.66.0423
**Module name:** `ordered_priority_queue`
**Platform Designer group:** Mu3e Data Plane / Modules

---

## Use Case

The Mu3e FEB datapath needs to merge several lane-local packet streams into one
ordered egress while retaining packet boundaries, bounded skew tolerance, and
visible accounting for any legal loss. `ordered_priority_queue` provides that
merge stage.

Typical deployment:

- **Multi-lane packet merge:** aggregate `N_LANE` independent FEB ingress
  streams into one ordered egress stream.
- **Shared-buffer scheduling:** absorb lane skew with per-lane FIFOs, ticket
  FIFOs, and shared dynamic page storage.
- **Backpressure containment:** honour Avalon-ST `ready` on egress while
  keeping ingress non-backlog and explicitly accounting drops on the ingress
  side when local resources saturate.
- **Runtime observability:** expose common Mu3e identity words, per-lane
  counters, frame-table counters, lane masking, and DRR tuning through the
  `csr` Avalon-MM slave.

The packaged release exposes representative legal points
`N_LANE={2,4,8,16}`, fixed `MODE=MERGING`, fixed `TRACK_HEADER=true`,
`N_SHD={64,128,256,512}`, and the safe current `32+4` ingress / `36`-bit
single-symbol egress contract. The active release closure is the
`4-lane / N_SHD=128 / TICKET_FIFO_DEPTH=256 / native_sv` slice documented in
[`doc/SIGNOFF.md`](doc/SIGNOFF.md).

---

## Architecture

```text
+----------------------------------------------------------------------------------------+
| ingress_0 .. ingress_N-1 --> [ingress parser / lane FIFO / ticket FIFO] --+            |
|                                                                            |           |
|                                                                            v           |
|                                           [page allocator / block mover / DRR arbiter] |
|                                                                            |           |
|                                                                            v           |
|                                                   [page RAM / frame ownership ledger]  |
|                                                                            |           |
| avs_csr <------------------- [identity / mask / counters / DRR control] ---+           |
|                                                                            |           |
|                                                                            v           |
|                                                                          egress        |
+----------------------------------------------------------------------------------------+
```

### Pipeline Stages

| Stage | Component | Latency | Description |
|-------|-----------|---------|-------------|
| 1 | `ingress parser` | 0-1 cycles | Decode header / subheader / hit / trailer symbols, track packet boundaries, and revoke errored packets. |
| 2 | `lane FIFO + ticket FIFO` | 1+ cycles | Buffer per-lane symbols and ticket metadata. No ingress `ready` is exported; full local resources force a counted drop at packet boundaries. |
| 3 | `page allocator` | multi-cycle | Consume eligible lane tickets, allocate shared-page ownership, and advance per-lane read / drop accounting. |
| 4 | `block mover / ordered DRR arbiter` | multi-cycle | Move complete blocks into shared page RAM under per-lane DRR allowance and backpressure constraints. |
| 5 | `page RAM / frame ownership` | streaming | Hold merged packet data and maintain frame-table write / read / drop visibility across the shared store. |
| 6 | `egress presenter` | backpressured | Emit one ordered `36`-bit symbol per beat on Avalon-ST egress while honouring `ready`. |
| 7 | `CSR / counters` | 1 cycle | Expose identity, `LANE_MASK`, status, capability bits, frame-table counters, per-lane counters, and DRR live statistics. |

### Delivered Configuration

| Generic / Control | Value | Description |
|-------------------|-------|-------------|
| `PRESET` | `2LANE_BASE` default, plus eight named presets and `CUSTOM` | Representative GUI starting point for the packaged component. |
| `N_LANE` | `{2,4,8,16}` | Packaged legal lane-count points. |
| `MODE` | `MERGING` | Fixed in the packaged release. |
| `TRACK_HEADER` | `true` | Fixed in the packaged release. |
| `INGRESS_DATA_WIDTH` | `32` | Packaged payload width per ingress symbol. |
| `INGRESS_DATAK_WIDTH` | `4` | One control bit per ingress byte. |
| `CHANNEL_WIDTH` | auto from `N_LANE` | Compatibility floor of `2`; maps `{2,4,8,16}` to `{2,2,3,4}`. |
| `N_SHD` | `{64,128,256,512}` | Legal packaged subheader-count points. |
| `N_HIT` | `{255,511,1023,2047}` | Legal packaged hit-count limit points. |
| `LANE_FIFO_WIDTH` | `40` | Base `36`-bit symbol plus local control bits. |
| `TICKET_FIFO_DEPTH` | smallest power-of-two above `N_SHD`, minimum `256` | Auto-derived ticket depth policy. |
| `HANDLE_FIFO_DEPTH` | `64` | Fixed in the packaged release. |
| `PAGE_RAM_DEPTH` | `{8192,16384,32768,65536}` | Legal shared page-storage depth points. |
| `PAGE_RAM_RD_WIDTH` | `36` | Current packaged egress width; no `empty` sideband is exported. |
| Active signoff slice | `N_LANE=4`, `N_SHD=128`, `TICKET_FIFO_DEPTH=256`, `DUT_IMPL=native_sv` | Current release dashboarded closure point. |

### Legal Drop and Accounting Semantics

`ordered_priority_queue` is not an unbounded lossless queue. Loss is legal only
when it is visible and counted.

- Before frame ownership, lane masking and local lane / ticket FIFO saturation
  can drop packets at packet boundaries. Those losses are counted in the
  per-lane `DROP_*` counters.
- After shared ownership, overwrite / recovery losses are counted separately in
  the frame-table `FT_DROP_*` counters.
- Signoff follows the conservation rule
  `expected_hits = pre_drop + post_drop + ft_drop + delivered + unexplained`,
  with `unexplained` required to stay `0` at maintained checkpoints and at
  end-of-test for the claimed closure slice.

---

## CSR Register Map

All registers are word-addressed through the `csr` Avalon-MM slave
(`32`-bit data, `9`-bit word address). Words `0` and `1` form the common Mu3e
identity header.

| Word | Name | Access | Description |
|------|------|--------|-------------|
| `0x000` | `UID` | RO | Immutable Mu3e IP identifier. Default ASCII `OPQM`. |
| `0x001` | `META` | RW/RO | Write page selector `[1:0]`. Read selected page: VERSION / DATE / GIT / `INSTANCE_ID`. |
| `0x002` | `LANE_MASK` | RW | Bit `i = 1` masks lane `i` at packet boundaries. In-flight packets drain; new packets on masked lanes are dropped and counted. |
| `0x003` | `CTRL` | WO | Bit `0` is a write-`1` pulse to clear software-visible counters. |
| `0x004` | `STATUS` | RO | Lane-mask summary, busy flags, and effective-mask state. |
| `0x005` | `CAP` | RO | Capability summary and per-lane counter-window geometry. |
| `0x008..0x010` | `FT_*` counters | RO | Frame-table write / read / drop counters for headers, subheaders, and hits. |
| `0x040 + lane*0x10 + 0..A` | Lane counters | RO | Per-lane write / read / drop counters plus live lane and ticket free-credit counters. |
| `0x040 + lane*0x10 + B` | `DRR_ALLOWANCE` | RW | Per-lane DRR refill allowance in page words per participating subheader. Writing also reseeds the live quantum. |
| `0x040 + lane*0x10 + C..F` | DRR live / stats | RO | Live DRR deficit budget plus per-lane block-grant, served-beat, and defer-round counters. |

### Runtime Configuration Workflow

1. Read `UID`, `META`, and `CAP` to confirm the instantiated packaged point.
2. Program any desired `DRR_ALLOWANCE` values and an initial `LANE_MASK`
   policy.
3. Clear counters with `CTRL[0]` before a measurement run.
4. Stream traffic and monitor `STATUS`, the per-lane region, and the
   frame-table `FT_*` counters.
5. When masking lanes at runtime, rely on the packet-boundary rule: the
   currently active packet drains, and later packets on that lane are dropped
   and counted.

---

## Platform Designer GUI

The `_hw.tcl` presents four tabs in Platform Designer:

### Configuration Tab

**Overview** -- block function, current packaged scope, clocking, and the
non-backlog ingress / backpressured egress flow-control model.

**Presets** -- `CUSTOM` plus the eight representative named presets.

**Aggregation** -- `N_LANE`, `MODE`, and `TRACK_HEADER`.

**Ingress Format** -- `INGRESS_DATA_WIDTH`, `INGRESS_DATAK_WIDTH`, and derived
`CHANNEL_WIDTH`.

**Sizing** -- `LANE_FIFO_DEPTH`, `LANE_FIFO_WIDTH`, `TICKET_FIFO_DEPTH`,
`HANDLE_FIFO_DEPTH`, `PAGE_RAM_DEPTH`, and `PAGE_RAM_RD_WIDTH`.

**Packet Format** -- `N_SHD`, `N_HIT`, `HDR_SIZE`, `SHD_SIZE`, `HIT_SIZE`,
`TRL_SIZE`, and the frame count / serial field widths.

**Throughput** -- validation-callback summary of derived storage and expected
throughput.

**Debug** -- `DEBUG_LV`.

### Identity Tab

**Delivered Profile** -- packaged contract, preset-family scope, and runtime
visibility summary.

**Versioning** -- `IP_UID`, `VERSION_MAJOR`, `VERSION_MINOR`,
`VERSION_PATCH`, `BUILD`, `VERSION_DATE`, `VERSION_GIT`, and `INSTANCE_ID`.

### Interfaces Tab

Clock/reset, one Avalon-ST ingress sink per lane, one Avalon-ST egress source,
and the `csr` Avalon-MM slave.

### Register Map Tab

Interactive HTML views for the CSR window, `META`, `CTRL`, `STATUS`, `CAP`,
frame-table counters, and the per-lane region with `DRR_ALLOWANCE` plus live
DRR statistics.

### Tab Overview

```text
+--------------------------------------------------------------------------------+
|  Platform Designer Component Editor: ordered_priority_queue                    |
|                                                                                |
|  [Configuration Tab]                                                           |
|    |- Overview -- function, clocking, flow-control summary                     |
|    |- Presets -- CUSTOM plus 8 representative presets                          |
|    |- Aggregation -- N_LANE, MODE, TRACK_HEADER                                |
|    |- Ingress Format -- data/datak contract and CHANNEL_WIDTH                  |
|    |- Sizing -- lane FIFO, ticket FIFO, handle FIFO, page RAM                  |
|    |- Packet Format -- N_SHD, N_HIT, header/subheader/hit/trailer sizing       |
|    |- Throughput -- validation-derived storage / throughput text               |
|    `- Debug -- DEBUG_LV                                                        |
|                                                                                |
|  [Identity Tab]                                                                |
|    |- Delivered Profile -- packaged contract summary                           |
|    `- Versioning -- UID, VERSION_*, DATE, GIT, INSTANCE_ID                     |
|                                                                                |
|  [Interfaces Tab] -- clock/reset, per-lane ingress, egress, csr                |
|  [Register Map Tab] -- CSR window, META, CTRL, STATUS, CAP, FT, lane region    |
|                                                                                |
+--------------------------------------------------------------------------------+
```

---

## Presets

Eight representative named presets are shipped in the `_hw.tcl`, plus
`CUSTOM` for manual edits:

| Preset | Lanes | Lane FIFO Depth | `N_SHD` | Use Case |
|--------|------:|----------------:|--------:|----------|
| `2LANE_BASE` | 2 | 1024 | 128 | Default shipped preset and base 2-lane starting point. |
| `2LANE_DEEP` | 2 | 2048 | 128 | 2-lane point with additional skew tolerance. |
| `4LANE_BASE` | 4 | 2048 | 128 | Representative 4-lane starting point. |
| `4LANE_DEEP` | 4 | 4096 | 128 | 4-lane point with deeper per-lane buffering. |
| `8LANE_BASE` | 8 | 4096 | 128 | Representative 8-lane starting point. |
| `8LANE_DEEP` | 8 | 8192 | 128 | 8-lane point with additional skew tolerance. |
| `16LANE_BASE` | 16 | 8192 | 128 | Representative 16-lane starting point. |
| `16LANE_DEEP` | 16 | 16384 | 128 | 16-lane point with deeper per-lane buffering. |

All named presets intentionally keep the safe current width contract:
`32` data bits + `4` datak bits on ingress and `36`-bit single-symbol egress.
They are representative starting points, not a blanket signoff claim across the
full matrix space. The active closure point is tracked separately in
[`doc/SIGNOFF.md`](doc/SIGNOFF.md) and
[`doc/CONFIG_SIGNOFF.md`](doc/CONFIG_SIGNOFF.md).

---

## Verification Workflow

The active verification workflow lives under [`tb/`](tb/README.md) and
[`tb_int/`](tb_int/README.md), not in the older archive paths.

- [`tb/DV_REPORT.md`](tb/DV_REPORT.md) -- standalone DV dashboard for the
  active closure slice
- [`tb/REPORT/README.md`](tb/REPORT/README.md) -- per-case and per-cross-run
  evidence tree
- [`tb/DV_PLAN.md`](tb/DV_PLAN.md) -- frozen standalone bucket plan and signoff
  rules
- [`tb/BUG_HISTORY.md`](tb/BUG_HISTORY.md) -- standalone bug ledger
- [`tb_int/DV_REPORT.md`](tb_int/DV_REPORT.md) -- integrated FEB-chain matrix
  evidence
- [`doc/SIGNOFF.md`](doc/SIGNOFF.md) -- master signoff dashboard linking DV and
  synthesis closure
- [`doc/CONFIG_SIGNOFF.md`](doc/CONFIG_SIGNOFF.md) -- packaged-configuration
  legality and representative preset matrix
- [`syn/SYN_REPORT.md`](syn/SYN_REPORT.md) -- standalone Quartus timing and
  resource evidence

Current release signoff is closed on the active
`OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
slice, with broader package-space expansion tracked explicitly as later work in
[`doc/CONFIG_SIGNOFF.md`](doc/CONFIG_SIGNOFF.md).

---

## Repository Layout

- [`rtl/`](rtl/README.md) -- canonical RTL tree: legacy monolithic VHDL,
  split VHDL, and native-SV signoff sources
- [`rtl/sv_ver/ordered_priority_queue/monolithic_sv/`](rtl/sv_ver/ordered_priority_queue/monolithic_sv/README.md)
  -- active native-SV architectural split and DUT wrapper path
- [`script/ordered_priority_queue_hw.tcl`](script/ordered_priority_queue_hw.tcl)
  -- primary Platform Designer packaging entry point
- [`script/ordered_priority_queue_v2_hw.tcl`](script/ordered_priority_queue_v2_hw.tcl)
  -- alternate split OPQ packaging track
- [`script/intf_adapter_hw.tcl`](script/intf_adapter_hw.tcl) -- compatibility
  adapter packaging collateral
- [`tb/`](tb/README.md) -- standalone UVM signoff harness, reports, and bug
  history
- [`tb_int/`](tb_int/README.md) -- integrated FEB-side UVM harness and merged
  traffic evidence
- [`doc/`](doc/README.md) -- signoff dashboards, migration notes, and package
  matrices
- [`syn/`](syn/README.md) -- standalone Quartus signoff work area

`legacy/` remains a compatibility symlink to `tb/legacy/`, but canonical
references should point at `tb/legacy/` directly.

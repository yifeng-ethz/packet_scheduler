# DV_INT Harness: packet_scheduler end-to-end

**Companion to:** `DV_INT_PLAN.md`
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-15
**Status:** Parser/SVA coverage across H0/B/C/D/E, MuTRiG drain-safe run control, SWB gate alignment, and unmatched-hit candidate dumps are in tree.

---

## 1. Clock / reset

| Clock | Freq | Used by |
|-------|------|---------|
| `clk_ref`  | 125 MHz | single simulation clock shared by FEB and SWB in tb_int |
| `rst_n`    | active-low | synchronous to `clk_ref`, held for `N` cycles at time zero |

`tb_int` uses one clock domain. The real design has GXB crossings FEB→SWB
but this harness is xcvr-less by design. If the tb later grows a FIFO on
each link to model xcvr latency it stays inside the same domain.

---

## 2. RTL skeleton

`rtl/tb_int_top.sv` is the top-level wrapper currently in tree:

```
tb_int_top
 ├─ clk / reset generation
 ├─ g_datapath[0..3]
 │    └─ datapath_stub #(.FEB_ID(i/2), .DATAPATH_ID(i%2))
 │         ├─ emulator_mutrig
 │         ├─ frame_rcv_ip
 │         ├─ mts_processor
 │         ├─ ring_buffer_cam x 4
 │         └─ feb_frame_assembly
 ├─ swb_ingress_stub u_swb
 │    ├─ pre-gate datapath links `dp_*`
 │    ├─ post-gate OPQ ingress links `v0..v3`
 │    └─ ordered_priority_queue_dut4
 └─ tb_int_if
      ├─ Stage A taps
      ├─ pre-gate / post-gate lane taps
      ├─ egress tap
      ├─ CSR tap
      └─ run-control tap
```

`tb_int_top.sv` groups the 4 datapath chains into 2 FEBs logically through
`FEB_ID` / `DATAPATH_ID`; it does not currently instantiate separate
`feb_stub` wrappers. `datapath_stub` is the thin integration shell that maps
the live emulator → frame_rcv → mts_processor → ring_buffer_cam →
feb_frame_assembly chain into the same AvST contract used by the generated
Qsys subsystem.

The OPQ itself is the monolithic VHDL core, instantiated as
`ordered_priority_queue_dut4` with the default `N_SHD=256`.

---

## 3. Stage taps (bind-only monitors and passive interfaces)

All promoted stage monitors are passive observers. No source file of any
shipping datapath IP is modified.

| Stage | Tap point | Contract family | Current status |
|-------|-----------|-----------------|----------------|
| A | `hit_generator` FIFO write | raw-hit commit monitor | implemented in `uvm/tb_int_pkg.sv` |
| H0 | `frame_rcv_ip` `aso_hit_type0_*` | recovery-aware hit-stream parser + SVA | implemented in `uvm/tb_int_pkg.sv` + `uvm/tb_int_hit0_contract_sva.sv` |
| H1 | `mts_processor` `aso_hit_type1_*` | passive hit monitor + slot-aware matcher | implemented in `uvm/tb_int_pkg.sv` |
| B | `ring_buffer_cam_v2_core` `aso_hit_type2_*` | hit-stream parser + SVA | implemented in `uvm/tb_int_pkg.sv` + `uvm/tb_int_hit2_contract_sva.sv` |
| C | datapath pre-gate `feb_frame_assembly` tx stream | framed parser + SVA | implemented in `uvm/tb_int_pkg.sv` + `uvm/tb_int_frame_contract_sva.sv` |
| D | SWB post-gate `v0..v3` stream into OPQ | framed parser + SVA | implemented in `uvm/tb_int_pkg.sv` + `uvm/tb_int_frame_contract_sva.sv` |
| E | `opq_egress_if` accepted beat | framed parser + SVA | implemented in `uvm/tb_int_pkg.sv` + `uvm/tb_int_frame_contract_sva.sv` |

Binding example (A):

```systemverilog
bind hit_generator tb_int_stage_a_mutrig_monitor u_mon (
    .clk      (clk),
    .rst      (rst),
    .wr_en    (hit_wr_en),
    .wr_data  (hit_wr_data),
    .fifo_full(fifo_full)
);
```

Each monitor raises a SystemVerilog event or analysis-port-like `write()`
into the scoreboard (`tb_int_scoreboard`). Nothing goes through TLM or
analysis FIFOs between FEB and SWB: the RTL signals are wired directly and
the monitors only observe real accepted beats or commit points.

In the current tree the monitor, parser, agent, and env classes all live in
`uvm/tb_int_pkg.sv`. A later split into `uvm/agents/*` and `uvm/sva/*` is
cleanup, not a functional requirement.

### Tag transport

Stage A assigns a monotonic 64-bit `hit_id` at the FIFO-write moment and
publishes `{hit_id, abs_ts, mutrig_origin, payload}` into the scoreboard.
There is no tag bus transported in RTL.

The promoted architecture does **not** rely on one global downstream key:

- Stage A owns the canonical `hit_id`.
- Stage H0 uses a recovery-aware parser because `frame_rcv_ip` in
  `MODE_HALT=0` can legally emit `sop ... sop eop` recovery patterns.
- Stage H1 uses `mts_processor` `channel[1:0]` as the expected rb-cam slot.
- Stage B uses a stage-local matcher on `hit_type2` observations.
- Stages C/D/E use a shared framed parser that emits canonical
  `{abs_hit_ts, hit_word, lane_ctx}` observations.

Stage-pair reconciliation remains FIFO-ordered within a key bucket so
collisions are consumed deterministically. The scoreboard also propagates a
candidate Stage-A lineage id downstream using that same FIFO order. This is
exact at `A->H0`; later stages keep the lineage only while earlier
boundaries stayed aligned. When earlier loss or ghost events already broke
that alignment, the residual dump prints `id=?` instead of pretending the
mapping is known.

---

## 4. Contract parser, assertions, and scoreboard

`tb_int` promotes one passive contract stack per stage boundary:

- Stage H0: one recovery-aware `hit_type0` parser/SVA pair that enforces only
  the sideband guarantees actually made by `frame_rcv_ip` and reports
  `restart_sop` / `orphan_eop` as recovery statistics.
- Stage H1: one passive `hit_type1` monitor whose slot sideband is preserved
  into the scoreboard so `H1->B` loss can be localized per rb-cam slot.
- Stage B: `hit_type2` hit-stream monitor plus SVA at the ring-buffer CAM
  boundary.
- Stages C/D/E: one shared data-framed parser and one shared SVA family,
  derived from the standalone OPQ harness, that reconstruct absolute
  subheader timestamps, track pending hit counts, and reject malformed
  framing.

The parser/SVA layer is responsible for local contract correctness. The
scoreboard is responsible for cross-stage identity continuity.

The scoreboard owns:

- per-stage ledgers keyed by `(lane, channel, t_fine)`
- slot-local H1/B ledgers for rb-cam localization
- raw observation snapshots per stage
- candidate Stage-A lineage ids propagated downstream by FIFO-order matching
- per-stage parser / contract-error counters
- per-lane and per-slot reconciliation summaries
- residual-bucket dumps with the first unmatched observations at each failing
  boundary

At end-of-test:

1. Every `hit_id` whose stage-A timestamp is within the run-enabled window
   must reach every required downstream stage. Any first missing boundary is
   reported explicitly as `A->H0`, `H0->H1`, `H1->B`, `B->C`, `C->D`, or `D->E`.
2. Every downstream-stage observation must reconcile to a known upstream
   `hit_id`. Unknown = ghost hit.
3. Framed-stage contract errors are promoted independently of hit-integrity
   mismatches, so malformed subheaders / trailers do not get hidden inside a
   generic "missing hit" bucket.
4. Dump the first unmatched observations at any failing boundary so debug can
   start from concrete items rather than bucket counts alone. Current output
   includes exact Stage-A `hit_id`s where the lineage is still known.

---

## 5. Latency histogram format

This section is the planned follow-on shape, not the current promoted
implementation. The live tree does not yet dump latency CSVs.

One CSV per `(stage_pair, lane)`. Header:

```
hit_id,feb_id,datapath_id,mutrig_ch,lane,t_prev,t_curr,lat_cycles
```

Off-sim plotter `scripts/plot_latency_hists.py` reads all CSVs and emits
a single matplotlib figure per stage pair with per-lane histograms
overlaid:

- `latency_AB.png` — FEB hit preprocessor: short mode expected bimodal,
  upper edge at `910*2` cycles exact
- `latency_BC.png` — feb frame assembly: small jitter, mean ≈ frame period
- `latency_CD.png` — SWB xcvr stub: ≈ zero in this tb
- `latency_DE.png` — OPQ residency: bounded by frame-table depth

The Python script has **no dependency beyond matplotlib and numpy**. It
reads CSVs with the stdlib.

---

## 6. Run-control agent

The run-control agent, currently implemented in `uvm/tb_int_pkg.sv`, drives:

- `run_state` broadcast to each FEB's `runctl_mgmt_host` input
- `run_enable` to `swb_ingress_stub`
- `emulator_mutrig.csr_enable` via the current tb-side control path

Sequence item `run_control_item`:

```
typedef enum { RC_PREPARE, RC_START, RC_END } rc_op_e;

class run_control_item extends uvm_sequence_item;
  rc_op_e op;
  int unsigned hold_cycles;
endclass
```

The driver sequences `RC_PREPARE` → wait → `RC_START` → wait → `RC_END`.
Stage A remains a passive raw-commit observer, but the promoted contract
expects no new Stage-A commits outside `RUNNING`. Stage C observes the
ungated FEB tx stream. Stage D observes the post-gate stream that actually
reaches OPQ. The scoreboard's missing-hit check is gated by the run-enabled
window.

Most promoted runs rely on the child IP default CSR configuration. Full
Avalon/MM programming of every datapath IP is deferred until an upgraded IP
actually requires non-default configuration.

For the MuTRiG emulator specifically, the promoted run-control contract is:

- commit new hits into the internal FIFO only while `RUNNING`
- stop committing new hits when leaving `RUNNING`
- keep already committed FIFO contents alive long enough to drain through the
  frame assembler during `RUN_END` / `TERMINATING`

The live tree now meets that contract by:

- keeping MuTRiG internal state alive through `TERMINATING`
- suppressing new hit commits outside `RUNNING`
- keeping the SWB ingress gate open through the explicit `RC_END` drain hold
  before returning to `IDLE`
- registering the SWB ingress gate so Stage D opens on the same internal
  datapath-side `RUNNING` edge seen by the FEB chain

---

## 7. Compile / elaboration order

1. Questa FSE license block from the top-level `CLAUDE.md` pattern.
2. Compile UVM 1.2 package with `+define+UVM_NO_DPI`.
3. Compile `packet_scheduler` monolithic VHDL (same file set as `tb/`).
4. Compile `emulator_mutrig` SV, `ring_buffer_cam` VHDL, `feb_frame_assembly`
   VHDL from `mu3e-ip-cores`. Use the IP source directly, not the generated
   Qsys copies, so we stay on the head of each submodule.
5. Compile `runctl_mgmt_host` (FEB run-control IP) sources.
6. Compile `rtl/tb_int_top.sv` and its stubs.
7. Compile `uvm/tb_int_pkg.sv` with all agent / env / test files.
8. Elaborate with `-nodpiexports -suppress 19 -suppress 3009`.

The generator-side VHDL from `feb_system_v2/synthesis/submodules/` is
**not** used; we pull each IP from `mu3e-ip-cores/<ip>/rtl` to avoid
stale Qsys copies. The only thing lifted from the Qsys is the interface
contract.

---

## 8. Known harness gaps

- No xcvr FIFO on the FEB→SWB links.
- No CSR-driven rate randomisation inside the mutrig emulator; the
  emulator is driven at fixed rates from the scoreboard config object.
- Full end-to-end latency CSV dumping and off-sim histogram generation are
  still planned, not implemented in the live tree.
- Stage-pair association is still contract-aware FIFO matching within
  `(lane, channel, t_fine)` buckets. Candidate Stage-A lineage ids are
  propagated downstream, but once an earlier boundary diverges a later
  boundary may legitimately report `id=?`.
- OPQ backpressure (from egress) is not exercised until phase 5.
- Full Avalon/MM child-IP configuration is deferred; phase 1..5 use default
  CSR settings unless a specific upgrade requires more.

These gaps are explicit here so they do not become surprises later.

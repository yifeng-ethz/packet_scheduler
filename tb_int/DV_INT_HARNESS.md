# DV_INT Harness: packet_scheduler end-to-end

**Companion to:** `DV_INT_PLAN.md`
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-14
**Status:** Phase 0 description. Phase 1 scaffold under construction.

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

`rtl/tb_int_top.sv` is the top:

```
tb_int_top
 ├─ clk_reset_gen
 ├─ feb_stub #(.FEB_ID(0)) u_feb0
 │    ├─ datapath_stub #(.DATAPATH_ID(0)) u_up
 │    │    ├─ emulator_mutrig
 │    │    ├─ ring_buffer_cam
 │    │    └─ feb_frame_assembly
 │    └─ datapath_stub #(.DATAPATH_ID(1)) u_dn
 │         ├─ emulator_mutrig
 │         ├─ ring_buffer_cam
 │         └─ feb_frame_assembly
 ├─ feb_stub #(.FEB_ID(1)) u_feb1     (same internal structure)
 ├─ swb_ingress_stub u_swb
 │    ├─ 4 × run_enable qualifier
 │    └─ ordered_priority_queue (OPQ_N_LANE = 4)
 └─ tb_int_if                         (interfaces handed to UVM)
```

`feb_stub` is a thin wrapper — its only purpose is to carry the
`FEB_ID`/`DATAPATH_ID` hierarchical parameters so that the bind-only
stage-A monitor can tag each hit with its origin without us touching any
source file. `datapath_stub` is equally thin and maps the three IPs into
their AvST contract exactly as `feb_system_v2_data_path_subsystem.vhd`
does in the generated Qsys.

The OPQ itself is the monolithic VHDL core, instantiated with
`OPQ_N_LANE=4` and the default `N_SHD=256`.

---

## 3. Stage taps (bind-only monitors)

All five stage monitors are **bind-only**. No source file of any shipping
IP is modified.

| Stage | Bind target | File | What it snoops |
|-------|-------------|------|----------------|
| A | `hit_generator` | `uvm/agents/stage_a_mutrig_monitor.sv` | FIFO-write cycle, payload, per-channel origin |
| B | `ring_buffer_cam_v2_core` | `uvm/agents/stage_b_rbcam_monitor.sv` | cam output valid beat, payload shadow |
| C | `feb_frame_assembly` | `uvm/agents/stage_c_febtx_monitor.sv` | tx AvST beat at the FEB tx boundary |
| D | `opq_ingress_if` (interface) | `uvm/agents/stage_d_opq_ingress_monitor.sv` | per-lane ingress beat into OPQ |
| E | `opq_egress_if` (interface) | `uvm/agents/stage_e_opq_egress_monitor.sv` | egress beat |

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

Each bound monitor raises a SystemVerilog event or analysis-port-like
`write()` into the scoreboard (`tb_int_scoreboard`). Nothing goes through
TLM / analysis fifos between FEB and SWB: the RTL signals are wired
directly. The monitors are passive observers of the same wires.

### Tag transport

Stage A assigns a monotonic 64-bit `hit_id` at the FIFO-write moment and
publishes `{hit_id, abs_ts, mutrig_origin, payload}` into a global
scoreboard map keyed by `{mutrig_origin, payload}`. Downstream monitors
(B..E) look up the hit by that key; there is no tag bus transported in
RTL.

Collision handling: if two hits ever collide on
`{mutrig_origin, payload}`, the scoreboard enqueues them in a per-key
FIFO and consumes them in order at each downstream stage. The
`hit_generator`'s PRNG rarely produces exact-payload collisions but the
code path must exist.

---

## 4. Scoreboard

`uvm/env/tb_int_scoreboard.sv` owns:

- `hit_db[hit_id] -> hit_record`
  - `stage_ts[5]` — timestamps captured at each stage
  - `stage_seen[5]` — observed bitmask
  - `origin.feb_id, datapath_id, mutrig_ch`
  - `payload`
  - `expected_subheader_slot`
  - `expected_lane`
- `key_lookup[{mutrig_origin, payload}] -> queue of hit_id` for downstream
  lookups
- per-stage latency histograms (cycle-bucketed)
- per-lane drop counters

At end-of-test:

1. Every `hit_id` whose stage-A timestamp is within the run-enabled window
   must have `stage_seen == 5'b11111`. Any other state = missing hit.
2. Every downstream-stage observation must match a known `hit_id`. Unknown
   = ghost hit.
3. For every `hit_id`, the subheader slot observed at stage C and stage D
   must equal `abs_ts[11:4]` per the OPQ contract. Otherwise slot
   violation.
4. Dump latency CSV: `tb_int_latency_{stage}_{lane}.csv`. One row per hit,
   columns `hit_id,lane,channel,stage_ts,latency_from_prev_stage`.

---

## 5. Latency histogram format

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

`uvm/agents/run_control_agent.sv` drives:

- `run_state` broadcast to each FEB's `runctl_mgmt_host` input
- `run_enable` to `swb_ingress_stub`
- `emulator_mutrig.csr_enable` via the CSR AvMM (or a tb-side backdoor to
  keep bring-up simple)

Sequence item `run_control_item`:

```
typedef enum { RC_PREPARE, RC_START, RC_END } rc_op_e;

class run_control_item extends uvm_sequence_item;
  rc_op_e op;
  int unsigned hold_cycles;
endclass
```

The driver sequences `RC_PREPARE` → wait → `RC_START` → wait → `RC_END`.
Stage-A monitor observes every hit regardless of run_state. Stage-E
expects to see only the hits whose stage-A timestamp fell inside the
run-enabled window; the scoreboard's missing-hit check is gated by that
window.

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

## 8. Known harness gaps (phase 1 baseline)

- No xcvr FIFO on the FEB→SWB links.
- No CSR-driven rate randomisation inside the mutrig emulator; the
  emulator is driven at fixed rates from the scoreboard config object.
- Stage-A monitor assumes payload uniqueness for the scoreboard key.
  Collision FIFO handling lands in phase 3, not phase 2.
- OPQ backpressure (from egress) is not exercised until phase 5.
- `run-control_mgmt` IP integration is phase 6; phase 1..5 use the tb-side
  run_enable broadcast directly.

These gaps are explicit here so they do not become surprises later.

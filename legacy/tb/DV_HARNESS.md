# DV Harness: ordered_priority_queue (monolithic)

> Archived on 2026-04-13 with the deprecated packet_scheduler harness. The checked-in `packet_scheduler/legacy/uvm/` tree only contains older split-era unit UVM pieces; the monolithic environment described below is target-state planning, not a complete current implementation.

**Companion to:** `DV_PLAN.md`
**Prefix:** `opq_`
**Simulator:** Questa (full Mentor floating license `8161@lic-mentor.ethz.ch`) — `rand`, `constraint`, `covergroup`, `cross`, and DPI-C are all permitted.
**Methodology:** UVM 1.2 (native DPI, no `+define+UVM_NO_DPI`).

This document specifies the reusable UVM environment that sits under every test case in `DV_BASIC` / `DV_EDGE` / `DV_PROF` / `DV_ERROR` / `DV_CROSS`. It is frozen at the same signoff gate as the plan.

---

## 1. Directory Layout

```
packet_scheduler/legacy/uvm/
  Makefile
  tb_top.sv                   # top module, DUT instantiation, clock/reset, SVA binds
  opq_env_pkg.sv              # env package (imports all UVM components)
  opq_env.sv                  # env: agents, scoreboard, coverage, virtual sequencer
  opq_ingress_agent/
    opq_ingress_seq_item.sv
    opq_ingress_driver.sv
    opq_ingress_monitor.sv
    opq_ingress_sequencer.sv
    opq_ingress_agent.sv
  opq_egress_agent/
    opq_egress_seq_item.sv
    opq_egress_driver.sv      # drives `ready` backpressure
    opq_egress_monitor.sv
    opq_egress_sequencer.sv
    opq_egress_agent.sv
  opq_scoreboard.sv           # reference model (see §5)
  opq_coverage.sv             # covergroups per DV_PLAN §5
  opq_txn.sv                  # transaction class (cfg + stimulus + expected)
  opq_base_test.sv            # base test class
  tests/                      # one file per test ID group
    opq_basic_tests.sv        # B001..Bnnn
    opq_edge_tests.sv         # E001..Ennn
    opq_prof_tests.sv         # P001..Pnnn
    opq_error_tests.sv        # X001..Xnnn
    opq_cross_tests.sv        # C001..Cnnn
  sequences/
    opq_packet_seq.sv         # builds HDR + N_SHD×(SHD+hits) + TRL ingress streams
    opq_multilane_seq.sv      # coordinates N_LANE streams with configurable skew
    opq_error_seq.sv          # error / truncation / reset-in-state sequences
  sva/
    opq_avst_ingress_sva.sv   # per-lane ingress AVST protocol
    opq_avst_egress_sva.sv    # egress AVST protocol
    opq_fifo_inv_sva.sv       # lane/ticket/handle FIFO level invariants
    opq_page_ram_sva.sv       # 3-segment read/write exclusion
    opq_fsm_sva.sv            # legal-transition checks for all 7 FSMs
```

Prefix `opq_` is used for every filename, class name, and package identifier.

---

## 2. DUT Parameterisation

`tb_top.sv` instantiates the DUT with a single configuration per invocation. Parameters are passed via Make variables so the same `tb_top.sv` can be rebuilt for each row of the parameter matrix:

```
+define+OPQ_N_LANE=4 +define+OPQ_MODE=\"MERGING\" ... etc
```

The parameter-space covergroup (`cov_cfg`) is sampled **once per run** from `tb_top`'s compile-time parameters and merged across the regression UCDB. This is how the DV_BASIC / DV_EDGE / DV_PROF matrices sweep the generic space in §5.1 of `DV_PLAN.md`.

The 4-lane MERGING default (`N_LANE=4`, `MODE=MERGING`, `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`, `N_SHD=256`, `N_HIT=255`, `LANE_FIFO_DEPTH=1024`, `PAGE_RAM_DEPTH=65536`, `PAGE_RAM_RD_WIDTH=36`) is the reference configuration for nightly regression; sweeps run on top of it.

---

## 3. Agent Topology

### 3.1 Ingress agents

One `opq_ingress_agent` per lane, instantiated as a SystemVerilog generate in `tb_top.sv` (array of interfaces). Each agent is **active** in DV_BASIC/DV_EDGE/DV_PROF (drives stimulus) and can be switched to **passive** for replay runs.

- **Seq item** (`opq_ingress_seq_item`): carries one beat — `data[INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0]`, `channel`, `startofpacket`, `endofpacket`, `valid`, `error[2:0]`, and a `pre_delay_cycles` field for gap injection.
- **Driver**: drives the lane with `valid` only (no `ready` on ingress). Honors `pre_delay_cycles`. Supports deliberate mid-packet `valid` drop (DV_ERROR truncation cases).
- **Monitor**: samples every accepted beat and emits two analysis ports — one for the scoreboard (complete-packet view), one for the covergroup sampler.

### 3.2 Egress agent

Single `opq_egress_agent`. Always active — it drives `ready` backpressure.

- **Seq item**: represents a backpressure profile over a time window — either a fixed duty cycle, a toggle period, a stuck-low window, or a replay of a recorded profile.
- **Driver**: owns `aso_egress_ready`. Exposes six macro profiles via sequence items: `ALWAYS_READY`, `STUCK_LOW`, `TOGGLE_PERIODIC`, `RANDOM_DUTY`, `BURST_STALL`, `RAMP`.
- **Monitor**: samples every accepted beat (valid & ready), reassembles packets using `startofpacket`/`endofpacket`/`empty`, emits reassembled packets to the scoreboard and the covergroup.

### 3.3 Virtual sequencer

`opq_virtual_sequencer` holds handles to every ingress sequencer plus the egress sequencer. All multi-lane and cross-axis tests run virtual sequences on top of it to coordinate lane skew, backpressure windows, and error injection.

### 3.4 Passive probes (internal)

A passive `opq_probe_if` is `bind`-inserted into the DUT to expose the internal signals we need for SVA, scoreboard cross-checks, and FSM coverage. It is read-only — no driver ever touches it. Probed signals:

- per-FSM state enums (`ingress_parser_state`, `page_allocator_state`, `block_mover_state`, `arbiter_state`, `ftable_mapper_state`, `ftable_tracker_state`, `ftable_presenter_state`)
- FIFO occupancy (`lane_fifo` wr/rd pointers, `ticket_fifo` wr/rd, `handle_fifo` wr/rd)
- `page_ram` wptr / rptr / segment boundaries
- `running_ts`, `frame_ts`
- `output_data_valid` pipeline (for the RESTART/refill SVA)

All probe accesses are through a `bind` of `opq_probe_if` inside `ordered_priority_queue` — no RTL edits are required.

---

## 4. Transaction Model

Tests compose transactions rather than individually resetting the DUT. A transaction is a unit that can be legally started from the DUT's current idle state. Definition:

```systemverilog
class opq_txn extends uvm_sequence_item;
  // ---- Configuration (applied before stimulus starts) ----
  rand int unsigned  n_frames;        // number of DAQ frames in this txn
  rand int unsigned  subh_per_frame;  // 1..N_SHD
  rand int unsigned  hits_per_subh;   // 0..N_HIT
  rand int unsigned  lane_skew_max;   // max per-txn skew in beats
  rand int unsigned  ingress_gap_min;
  rand int unsigned  ingress_gap_max;
  rand opq_bp_profile_e egress_bp_profile;
  rand bit           inject_hit_err;
  rand bit           inject_shd_err;
  rand bit           inject_hdr_err;
  rand bit           inject_truncation;
  rand int unsigned  watchdog_cycles;

  // ---- Derived expected (filled by the scoreboard reference model) ----
  int unsigned       exp_eg_packets;
  int unsigned       exp_ingress_drops;
  int unsigned       exp_hit_err_count;
endclass
```

Key rules:

1. **No reset between transactions.** The env only resets at start-of-test and on explicit `reset_txn` items. This is what lets cross-coverage cells span transaction boundaries (§5 of `DV_PLAN.md`).
2. **Watchdog per txn.** Each txn carries a watchdog; the env fires `UVM_FATAL` if the scoreboard does not declare the txn complete within `watchdog_cycles`.
3. **Expected fields are reference-model outputs**, not hand-filled. The scoreboard's reference model (§5) computes them from the txn's stimulus spec and the current DUT idle state.

---

## 5. Scoreboard Reference Model

`opq_scoreboard` is the end-to-end reference model. It consumes:

- **Ingress analysis port** (per lane) → complete ingress packet view
- **Egress analysis port** → reassembled egress packet view
- **Probe port** (passive) → internal FSM transitions, FIFO levels, running_ts / frame_ts

And produces:

- **Expected egress packet stream** (ordered by the reference aggregator)
- **Expected drop counters** (per lane FIFO, ticket FIFO, handle FIFO)
- **Expected error flags** per egress packet
- **Expected timestamp reconstruction** (honoring frozen behaviors F3 and F4 from `DV_PLAN.md` §6)

### 5.1 Reference aggregator

A software model of the N-way merge / mux that matches the DUT's `MODE`:

- `MERGING`: N-way sorted merge by per-lane `ts` field extracted from ticket payloads. When all lanes present an SOP, the aggregator is allowed to re-sync `running_ts <- frame_ts` (F4).
- `MULTIPLEXING`: round-robin pick, one packet per lane per round. Timestamps are interleaved, not sorted.

The aggregator operates in untimed space: it takes the set of ingress packets the monitors accepted and produces the expected egress packet order. The scoreboard then compares the DUT's egress stream against this expected order, tolerating at most the pipeline latency declared in `opq_config::EGRESS_LATENCY_MAX`.

### 5.2 FIFO-drop model

Three parallel counters model the FIFOs:

- **Lane FIFO**: credit-based; the reference model runs the same credit bookkeeping as the DUT parser. On credit exhaustion, the in-flight packet is marked "masked" and the reference aggregator suppresses it. The DUT must match the mask set.
- **Ticket FIFO**: same credit scheme.
- **Handle FIFO**: no credit — drop-new on write-side full. The reference model increments `exp_handle_drop_count` when the DUT's internal handle-FIFO is full at a write.

Every drop in the reference model is paired against the DUT's actual behavior via the probe port. A mismatch is a `UVM_ERROR`.

### 5.3 Packet-equivalence checker

Packets are compared by reconstructing the full hit list from both sides:

- **Ingress side**: hit list = all hits accepted by the ingress monitor for the packet, minus any that were dropped by the FIFO-drop model.
- **Egress side**: hit list = all hits reassembled by the egress monitor for the corresponding ordered packet.

Comparison dimensions:
1. Hit count (allowing hit drops when `hit_err` is propagated)
2. Hit payload equality (bit-exact)
3. Timestamp ordering (must be monotonic non-decreasing within a packet for MERGING)
4. Error-flag propagation: `{hit_err, shd_err, hdr_err}` must match the reference model's expectation
5. `empty` field on multi-symbol egress beats

### 5.4 FSM observer

A side-thread watches the probe port's FSM enums and asserts:
- Legal-transition-only (via `opq_fsm_sva.sv`, but also tracked in the scoreboard for reporting)
- No FSM deadlocks (state unchanged for `watchdog_cycles` with input pending)
- Per-FSM state histogram fed to `cov_fsm`

---

## 6. Coverage Collectors

`opq_coverage.sv` declares the covergroups listed in `DV_PLAN.md` §5. One instance per env, sampled by:

- **`cov_cfg`**: sampled once at `start_of_simulation_phase` from the compile-time parameters.
- **`cov_fsm`**: sampled every cycle from the probe port (through a lightweight sampler task; no X in enum).
- **`cov_pkt`**: sampled per complete ingress packet (monitor analysis port).
- **`cov_flow`**: sampled per complete txn by the scoreboard, based on monitored lane skew, ticket occupancy peaks, and egress ready duty cycle.
- **`cov_cross`**: scenario-driven — `DV_CROSS` sequences call `cov_cross.sample_*()` hooks directly with the multi-axis key.

`report_coverage()` in `report_phase()` prints per-covergroup percentages and lists any bin with zero hits. Zero bins at signoff = fail.

---

## 7. SystemVerilog Assertions (SVA)

All SVA modules are `bind`-instantiated from `tb_top.sv`. Assertion failures are `$error` (not `$fatal`), so the scoreboard has a chance to also report the mismatch.

### 7.1 `opq_avst_ingress_sva`

Bound to each `ingress_<i>` interface.

- SOP/EOP well-formed: never two SOP without an intervening EOP.
- `valid=1` is stable from SOP through EOP (no mid-packet `valid` glitch *unless* the test explicitly sets `inject_truncation`, in which case the SVA has an `assume` override).
- `error[2:0]` stable across an SOP..EOP window (errors are per-packet, not per-beat).
- `channel` stable across an SOP..EOP window.
- No X/Z on `data`, `channel`, `error` while `valid=1`.

### 7.2 `opq_avst_egress_sva`

Bound to the `egress` interface.

- Standard AVST valid/ready handshake. Once `valid=1` without `ready`, `data/empty/sop/eop/error` must hold until `ready` rises.
- SOP/EOP framing well-formed.
- `empty ≤ symbolsPerBeat - 1` and only non-zero on the final beat of a packet.
- **Frozen behavior F1** check: after a `ready` deassertion during PRESENTING, `valid` must return to 0 before the next rise, the presenter must visit the RESTART state, and the first post-restart beat must equal the pre-stall beat. Implemented against the probe port's `ftable_presenter_state` and `output_data_valid` pipeline.

### 7.3 `opq_fifo_inv_sva`

Bound against the probe port for each internal FIFO.

- Lane FIFO: `wptr - rptr` never exceeds `LANE_FIFO_DEPTH`. Never pop when empty. Never push when full *unless* the parser is in MASK_PKT / MASK_PKT_EXTENDED (drop-on-full path).
- Ticket FIFO: same invariants.
- Handle FIFO: no credit — pushes when full are silently ignored *and* `exp_handle_drop_count` must increment on the reference side.

### 7.4 `opq_page_ram_sva`

Bound against the probe port's `page_ram` pointers.

- **Read/write exclusion (F2):** a write never lands in the segment currently being read by the presenter.
- Segment rotation is monotonic and strictly follows the 3-segment dynamic scheme.
- The rolled-back `page_ram_rptr` after a stall equals `previous_rptr - (EGRESS_DELAY + 1)` (F1).

### 7.5 `opq_fsm_sva`

Legal-transition enumeration for every FSM. Each state has an explicit allowed next-state set, encoded as a case statement:

```systemverilog
property p_legal_ingress_parser_trans(state, next_state);
  @(posedge d_clk) disable iff (d_reset)
    case (state)
      IDLE: next_state inside {IDLE, UPDATE_HEADER_TS, MASK_PKT, RESET};
      UPDATE_HEADER_TS: next_state inside {UPDATE_HEADER_TS, WR_HITS, MASK_PKT, RESET};
      ...
    endcase
endproperty
```

One property per FSM, seven properties total. Any un-listed transition is an error.

---

## 8. Build / Run Flow

Planned `packet_scheduler/legacy/uvm/Makefile` targets:

| Target | Action |
|--------|--------|
| `compile` | `vlib`, `vlog`, `vcom` all sources + UVM package + SVA binds. |
| `run TEST=<uvm_test_name>` | Runs one test with coverage disabled (debug). |
| `run_cov TEST=<uvm_test_name>` | Runs one test with `-coverage` and dumps `.ucdb`. |
| `regress` | Matrix loop over `opq_regress_list.f` (one line per test × parameter config), writes a per-run `.ucdb` into `cov/`. |
| `cov_merge` | `vcover merge cov/merged.ucdb cov/*.ucdb`. |
| `cov_report` | `vcover report -html -output cov_html cov/merged.ucdb`. |
| `run_vcd TEST=…` | Runs with a full-hierarchy VCD for the wavedrom viewer. |
| `lint` | Questa source lint + elaboration lint on the monolithic DUT. |

License: `LM_LICENSE_FILE := 8161@lic-mentor.ethz.ch` (unconditional — no fallback to the local FSE license). A `lmstat` preflight check runs at the top of `regress` to make sure Questa/UVM features are actually available before burning a matrix run.

---

## 9. Dependencies

- `DV_PLAN.md` — bucket overview, packet format, FSM inventory, coverage targets, frozen behaviors.
- `DV_BASIC.md`, `DV_EDGE.md`, `DV_PROF.md`, `DV_ERROR.md`, `DV_CROSS.md` — authoritative test ID catalogs.
- `ordered_priority_queue.terp.vhd` — RTL source; probe `bind` targets.
- `OPQ_RTL_CHANGELOG_backpressure_2026-01-29.txt`, `OPQ_RTL_CHANGELOG_timestamp_alignment_2026-01-29.txt`, `OPQ_RTL_CHANGELOG_overwrite_2026-01-30.txt` — source of truth for frozen behaviors F1–F4 / F10.

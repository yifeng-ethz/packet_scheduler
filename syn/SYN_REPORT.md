# ⚠️ SYN Report — packet_scheduler ordered_priority_queue

**Revision:** `opq_native_sv_4lane_signoff` &nbsp; **Date:** `2026-04-19` &nbsp;
**Device:** `10AX115N2F45E1SG` (`online_sc/a10_board`) &nbsp; **Quartus:** `18.1 Standard` &nbsp;
**Build basis:** `live standalone Arria 10 refresh in progress`

This file is the detailed standalone synthesis and timing report for the active
`packet_scheduler` standalone signoff harness. The master signoff dashboard is
[`../doc/SIGNOFF.md`](../doc/SIGNOFF.md).

## Build Intent

- keep standalone synthesis collateral under `syn/quartus/`
- rerun a true standalone Quartus compile after the tree cleanup instead of
  reusing the older example-system numbers
- use that refresh to validate timing, resource usage, and the RAM/CAM storage
  model on the current packaged release
- use the `online_sc/a10_board` target device rather than the older Arria V
  FE board device
- establish the first live standalone baseline at `N_LANE=4`, because the board
  target is `250 MHz` and later lane-point closure must start from the real
  4-lane Arria 10 cone rather than the older 2-lane placeholder revision

## Pre-Fit Model

- expected storage owners:
  - lane / ticket / handle / tile FIFOs from `rtl/sv_ver/vendor/alt_ram/`
  - page RAM structures in the monolithic OPQ path
  - CAM-like lookup behavior that may not be reflected honestly by the older
    RAM-block estimate
- expected critical regions:
  - ingress parsing and page-allocation control
  - frame-table / presenter drain logic
  - backpressure and credit-return bookkeeping in the merged egress path

This model is currently being checked against a fresh standalone A10 compile in
the cleaned tree. The current active run has already cleared the old
synthesis-only lane-FIFO inference problem by forcing the local compatibility
lane FIFO onto explicit `M20K` storage; fit/STA artifacts are still pending.

## Timing Summary

Signoff target:

- target clock: `d_clk`
- target frequency: `275 MHz`
- target period: `3.636364 ns`

| status | model | setup WNS (ns) | hold WNS (ns) | Fmax |
|:---:|---|---:|---:|---:|
| ❓ | 4-lane A10 standalone refresh in progress | n/a | n/a | n/a |

Key conclusions:

- no standalone timing closure claim is made yet
- the live signoff revision is now `opq_native_sv_4lane_signoff`; the older
  `opq_native_sv_2lane_signoff` placeholder is no longer the active baseline
- lane-scaled timing closure for `N_LANE={8,16}` remains a later phase and will
  require adaptive pipeline controls plus its own DV evidence

## Resource Summary

| item | value |
|---|---|
| Logic utilization | `pending standalone refresh` |
| Registers | `pending standalone refresh` |
| Pins | `pending standalone refresh` |
| Block memory bits | `pending standalone refresh` |
| RAM blocks | `under review; do not trust the earlier low estimate` |
| DSP blocks | `pending standalone refresh` |
| PLLs | `pending standalone refresh` |

## Flow Runtime

| module | elapsed | CPU time |
|---|---:|---:|
| Analysis & Synthesis | `running` | `pending` |
| Fitter | `pending` | `pending` |
| Assembler | `pending` | `pending` |
| Timing Analyzer | `pending` | `pending` |
| Total | `pending` | `pending` |

## Constraint Caveats

- the current `quartus/opq_monolithic_4lane_merge/` collateral is an example
  system generation point, not the refreshed standalone timing signoff harness
- RAM / CAM accounting is explicitly considered unresolved: the next fitter run
  must be reviewed for whether CAM-backed behavior is consuming more memory
  than the old estimate implied
- until that refresh exists, do not quote RAM-block counts or Fmax from older
  collateral as signoff numbers
- the active standalone refresh uses a synthesis-only harness top and local
  compatibility copies for old-parser and simulation-only constructs; functional
  RTL changes still belong in `rtl/`
- the active compile currently has no fit or STA report, so no ALM, M20K,
  WNS, TNS, or Fmax number in this file is allowed to be treated as signoff
  evidence yet

## Artifacts

- [`quartus/opq_native_sv_4lane_signoff/README.md`](quartus/opq_native_sv_4lane_signoff/README.md)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv)
- [`quartus/opq_native_sv_4lane_signoff/compile_live.log`](quartus/opq_native_sv_4lane_signoff/compile_live.log)

## Result

**⚠️ PENDING for standalone timing / resource signoff**

The active standalone Arria 10 refresh is now the 4-lane revision under
`syn/quartus/opq_native_sv_4lane_signoff/`, but the fitter and timing analyzer
have not produced signoff artifacts yet. Timing, fitted resource, and RAM/CAM
accounting remain open until that refresh completes.

# ✅ SYN Report — packet_scheduler ordered_priority_queue

**Revision:** `opq_native_sv_4lane_signoff` &nbsp; **Date:** `2026-04-20` &nbsp;
**Device:** `10AX115N2F45E1SG` (`online_sc/a10_board`) &nbsp; **Quartus:** `18.1 Standard` &nbsp;
**Build basis:** `completed standalone Arria 10 refresh`

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

This model is now checked against a fresh standalone A10 compile in the cleaned
tree. The active 4-lane refresh keeps the storage-heavy structures on explicit
`M20K` resources and no longer leaves RAM/CAM accounting unresolved.

## Timing Summary

Signoff target:

- target clock: `d_clk`
- target frequency: `275 MHz`
- target period: `3.636364 ns`

| status | model | setup WNS (ns) | hold WNS (ns) | Fmax |
|:---:|---|---:|---:|---:|
| ✅ | 4-lane A10 standalone refresh | `+0.008` | `+0.043` | `275.63 MHz` |

Key conclusions:

- standalone lane-4 timing closes at the `275 MHz` signoff target on the live
  `10AX115N2F45E1SG` harness
- the registered overlap-launch split moves the presenter's former long
  combinational selector path off the top slot; the worst fitted path is now in
  page-allocator ticket-RAM to state-decode logic
- lane-scaled timing closure for `N_LANE={8,16}` remains a later phase and will
  require adaptive pipeline controls plus its own DV evidence

## Resource Summary

| item | value |
|---|---|
| Logic utilization | `5,297 ALMs / 427,200 (1%)` |
| Registers | `4,855` |
| Pins | `0 physical, 18 virtual` |
| Block memory bits | `2,280,192 / 55,562,240 (4%)` |
| RAM blocks | `141 / 2,713 (5%)` |
| M20K blocks | `141 / 2,713 (5%)` |
| MLAB memory bits | `0` |
| DSP blocks | `0 / 1,518` |
| PLLs | `0 / 112` |

## Flow Runtime

| module | elapsed | CPU time |
|---|---:|---:|
| Analysis & Synthesis | `00:00:33` | `00:00:50` |
| Fitter | `00:03:15` | `00:16:15` |
| Assembler | `00:00:46` | `00:00:47` |
| Timing Analyzer | `00:00:06` | `00:00:10` |
| Total | `00:04:45` | `00:18:04` |

## Constraint Caveats

- the current `quartus/opq_monolithic_4lane_merge/` collateral is an example
  system generation point, not the refreshed standalone timing signoff harness
- this standalone harness still uses virtual top-level pins, so Quartus reports
  unconstrained external I/O and the clock is modeled from a virtual input; the
  quoted slack/Fmax numbers are therefore core-internal standalone signoff
  numbers, not board I/O timing closure numbers
- the active standalone refresh uses a synthesis-only harness top and local
  compatibility copies for old-parser and simulation-only constructs; functional
  RTL changes still belong in `rtl/`
- the M20K mapping has been checked explicitly in both the fit report and the
  instantiated RAM parameters; the current lane-4 build does not spill storage
  into MLAB

## Artifacts

- [`quartus/opq_native_sv_4lane_signoff/README.md`](quartus/opq_native_sv_4lane_signoff/README.md)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv)
- [`quartus/opq_native_sv_4lane_signoff/compile_live.log`](quartus/opq_native_sv_4lane_signoff/compile_live.log)

## Result

**✅ PASS for standalone timing / resource signoff**

The active standalone Arria 10 refresh under
`syn/quartus/opq_native_sv_4lane_signoff/` closes the `275 MHz` target with
`+0.008 ns` slow-corner setup slack. Fitted logic stays well under the user
resource cap at `5,297` ALMs, and all fitted memory is carried by `141` M20K
blocks with `0` MLAB memory bits.

# ✅ SYN Report — packet_scheduler ordered_priority_queue

**Measured revisions:** `opq_native_sv_2lane_signoff`, `opq_native_sv_4lane_signoff` &nbsp;
**Date:** `2026-04-22` &nbsp; **Device:** `10AX115N2F45E1SG` (`online_sc/a10_board`) &nbsp;
**Quartus:** `18.1 Standard`

This file is the detailed standalone synthesis and timing report for the active
`packet_scheduler` standalone signoff harness. The master signoff dashboard is
[`../doc/SIGNOFF.md`](../doc/SIGNOFF.md). The grouped configuration matrix is
[`../doc/CONFIG_SIGNOFF.md`](../doc/CONFIG_SIGNOFF.md).

The measured numbers below remain the active standalone synthesis evidence as
of `2026-04-22`; the DV dashboard was refreshed independently onto the
canonical `4-lane/128/256/native_sv` rerun slice without changing these
Quartus fit results.

## Build Intent

- keep standalone synthesis collateral under `syn/quartus/`
- rerun a true standalone Quartus compile after the tree cleanup instead of
  reusing the older example-system numbers
- use that refresh to validate timing, resource usage, and the RAM/CAM storage
  model on the current packaged release
- use the `online_sc/a10_board` target device rather than the older Arria V
  FE board device
- establish live standalone baselines at `N_LANE=2` and `N_LANE=4`, because the
  board target is `250 MHz` and later lane-point closure must start from
  measured Arria 10 cones instead of placeholder revisions

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

This model is now checked against fresh standalone A10 compiles in the cleaned
tree. The active 2-lane and 4-lane refreshes keep the storage-heavy structures
on explicit `M20K` resources and no longer leave RAM/CAM accounting unresolved.

## Measured Standalone Points

Signoff target:

- target clock: `clk`
- target frequency: `275 MHz`
- target period: `3.636364 ns`

| status | revision | lane point | setup WNS (ns) | hold WNS (ns) | Fmax | ALMs | registers | M20Ks | MLAB bits |
|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ✅ | `opq_native_sv_2lane_signoff` | `2` | `+0.172` | `+0.044` | `288.68 MHz` | `3,235` | `3,132` | `129` | `0` |
| ✅ | `opq_native_sv_4lane_signoff` | `4` | `+0.008` | `+0.043` | `275.63 MHz` | `5,297` | `4,855` | `141` | `0` |

Key conclusions:

- standalone lane-2 timing closes at the `275 MHz` signoff target on the live
  `10AX115N2F45E1SG` harness with comfortable positive slack
- standalone lane-4 timing closes at the `275 MHz` signoff target on the live
  `10AX115N2F45E1SG` harness
- the registered overlap-launch split moves the presenter's former long
  combinational selector path off the top slot; the worst fitted path is now in
  page-allocator ticket-RAM to state-decode logic
- lane-scaled timing closure for `N_LANE={8,16}` remains a later phase and will
  require adaptive pipeline controls plus its own DV evidence

## Resource Summary

| item | 2-lane | 4-lane |
|---|---:|---:|
| Logic utilization | `3,235 ALMs / 427,200 (<1%)` | `5,297 ALMs / 427,200 (1%)` |
| Registers | `3,132` | `4,855` |
| Pins | `0 physical, 18 virtual` | `0 physical, 18 virtual` |
| Block memory bits | `2,098,560 / 55,562,240 (4%)` | `2,280,192 / 55,562,240 (4%)` |
| RAM blocks | `129 / 2,713 (5%)` | `141 / 2,713 (5%)` |
| M20K blocks | `129 / 2,713 (5%)` | `141 / 2,713 (5%)` |
| MLAB memory bits | `0` | `0` |
| DSP blocks | `0 / 1,518` | `0 / 1,518` |
| PLLs | `0 / 112` | `0 / 112` |

## Flow Runtime

| module | 2-lane elapsed / CPU | 4-lane elapsed / CPU |
|---|---|---|
| Analysis & Synthesis | `00:00:23 / 00:00:40` | `00:00:33 / 00:00:50` |
| Fitter | `00:02:58 / 00:13:23` | `00:03:15 / 00:16:15` |
| Assembler | `00:00:46 / 00:00:46` | `00:00:46 / 00:00:47` |
| Timing Analyzer | `00:00:09 / 00:00:26` | `00:00:06 / 00:00:10` |
| Total | `00:04:16 / 00:15:15` | `00:04:45 / 00:18:04` |

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
- the refreshed 2-lane harness needed two collateral repairs before it could
  become a trustworthy signoff point:
  - stale `src_compat/` local copies were aligned to the live 4-lane synthesis
    compatibility set
  - the stale SDC target `d_clk` was corrected to the real harness top-level
    port `clk`

## Artifacts

- [`quartus/opq_native_sv_2lane_signoff/README.md`](quartus/opq_native_sv_2lane_signoff/README.md)
- [`quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff.qsf`](quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff.qsf)
- [`quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff.sdc`](quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff.sdc)
- [`quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff_top.sv`](quartus/opq_native_sv_2lane_signoff/opq_native_sv_2lane_signoff_top.sv)
- [`quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.fit.summary`](quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.fit.summary)
- [`quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.sta.summary`](quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.sta.summary)
- [`quartus/opq_native_sv_4lane_signoff/README.md`](quartus/opq_native_sv_4lane_signoff/README.md)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.qsf)
- [`quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv`](quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff_top.sv)
- [`quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.fit.summary`](quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.fit.summary)
- [`quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.sta.summary`](quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.sta.summary)
- [`quartus/opq_native_sv_4lane_signoff/compile_live.log`](quartus/opq_native_sv_4lane_signoff/compile_live.log)

## Result

**✅ PASS for measured standalone timing / resource signoff at `N_LANE={2,4}`**

The refreshed standalone Arria 10 harnesses under
`syn/quartus/opq_native_sv_{2,4}lane_signoff/` both close the `275 MHz` target.
The new 2-lane point closes with `+0.172 ns` slow-corner setup slack and
`3,235` ALMs; the 4-lane point closes with `+0.008 ns` slow-corner setup slack
and `5,297` ALMs. Both measured points keep all fitted memory on `M20K` blocks
with `0` MLAB memory bits.

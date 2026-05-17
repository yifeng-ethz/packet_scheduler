# ⚠️ SYN Report — packet_scheduler ordered_priority_queue

**Measured revisions:** `opq_native_sv_2lane_signoff`, `opq_native_sv_4lane_signoff` &nbsp;
**Date:** `2026-05-17` &nbsp; **Device:** `10AX115N2F45E1SG` (`online_sc/a10_board`) &nbsp;
**Quartus:** `18.1 Standard`

This file is the detailed standalone synthesis and timing report for the active
`packet_scheduler` standalone signoff harness. The master signoff dashboard is
[`../doc/SIGNOFF.md`](../doc/SIGNOFF.md). The grouped configuration matrix is
[`../doc/CONFIG_SIGNOFF.md`](../doc/CONFIG_SIGNOFF.md).

The measured numbers below are the active standalone synthesis evidence as of
`2026-05-17`. The current 4-lane point uses the corrected Mu3e Demo fixed4
profile `OPQ_N_SHD=128`, `OPQ_N_HIT=255`, `OPQ_TICKET_FIFO_DEPTH=1024`, and
`OPQ_PAGE_RAM_DEPTH=65536`, and now instantiates the fixed4 CSR wrapper so the
parser-ingress frame/subframe counters are included in synthesis.

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
| ✅ | `opq_native_sv_4lane_signoff` | `4`, `N_SHD=128`, `N_HIT=255`, fixed4 CSR wrapper | `+0.076` | `+0.012` | `280.87 MHz` | `9,665` | `9,966` | `187` | `0` |

Key conclusions:

- standalone lane-2 timing closes at the `275 MHz` signoff target on the live
  `10AX115N2F45E1SG` harness with comfortable positive slack
- standalone lane-4 timing now closes at the `275 MHz` signoff target with
  slow `900mV 100C` setup slack `+0.076 ns`
- the previous 4-lane failure was in the native-SV page allocator
  same-timestamp body-ticket path, originally through `fast_zero_lane_onehot`
  and the serial block-length adder; the fix keeps the all-active-lane fast path
  throughput intact while staging the commit and using pair-wise length sums
  before ticket-pointer advance and page write, instead of applying a constraint
  workaround
- lane-scaled timing closure for `N_LANE={8,16}` remains a later phase and will
  require adaptive pipeline controls plus its own DV evidence

## Resource Summary

| item | 2-lane | Mu3e Demo 4-lane |
|---|---:|---:|
| Logic utilization | `3,235 ALMs / 427,200 (<1%)` | `9,665 ALMs / 427,200 (2%)` |
| Registers | `3,132` | `9,966` |
| Pins | `0 physical, 18 virtual` | `0 physical, 18 virtual` |
| Block memory bits | `2,098,560 / 55,562,240 (4%)` | `3,069,824 / 55,562,240 (6%)` |
| RAM blocks | `129 / 2,713 (5%)` | `187 / 2,713 (7%)` |
| M20K blocks | `129 / 2,713 (5%)` | `187 / 2,713 (7%)` |
| MLAB memory bits | `0` | `0` |
| DSP blocks | `0 / 1,518` | `0 / 1,518` |
| PLLs | `0 / 112` | `0 / 112` |

## Flow Runtime

| module | 2-lane elapsed / CPU | Mu3e Demo 4-lane elapsed / CPU |
|---|---|---|
| Analysis & Synthesis | `00:00:23 / 00:00:40` | `00:01:06 / 00:01:23` |
| Fitter | `00:02:58 / 00:13:23` | `00:04:05 / 00:23:00` |
| Assembler | `00:00:46 / 00:00:46` | `00:00:45 / 00:00:46` |
| Timing Analyzer | `00:00:09 / 00:00:26` | `00:00:14 / 00:00:52` |
| Total | `00:04:16 / 00:15:15` | `00:06:15 / 00:26:04` |

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
- the refreshed 4-lane harness needed one additional collateral repair before
  the numbers became trustworthy:
  - stale `src_compat/ordered_priority_queue_monolithic_block_path.sv` still
    used the older direct lane-FIFO-to-page-RAM write cone and was re-aligned
    to the registered mover page-write stage before the final timing-clean
    rerun
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
- [`quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.flow.rpt`](quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.flow.rpt)

## Result

**✅ PASS for current measured standalone timing signoff at the fixed4 4-lane point**

The 2-lane baseline still closes with `+0.172 ns` slow-corner setup slack and
`3,235` ALMs. The refreshed 4-lane fixed4-wrapper compile completes with no
Quartus errors and closes timing: slow `900mV 100C` setup slack is `+0.076 ns`
with `TNS=0.000 ns`; slow `900mV 0C` setup slack is `+0.171 ns`. Worst reported
hold across corners remains positive at `+0.012 ns`. The current 4-lane resource
point is `9,665` ALMs, `9,966` registers, and `187` M20Ks.

This standalone timing gate now approves the SWB firmware compile from this OPQ
point.

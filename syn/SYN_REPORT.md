# ⚠️ SYN Report — packet_scheduler ordered_priority_queue

**Revision:** `pending standalone refresh` &nbsp; **Date:** `2026-04-17` &nbsp;
**Device:** `5AGXBA7D4F31C5` &nbsp; **Quartus:** `pending rerun` &nbsp;
**Build basis:** `cleaned tree refresh only`

This file is the detailed standalone synthesis and timing report for the active
`packet_scheduler` cleanup point. The master signoff dashboard is
[`../doc/SIGNOFF.md`](../doc/SIGNOFF.md).

## Build Intent

- keep standalone synthesis collateral under `syn/quartus/`
- rerun a true standalone Quartus compile after the tree cleanup instead of
  reusing the older example-system numbers
- use that refresh to validate timing, resource usage, and the RAM/CAM storage
  model on the current packaged release

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

This model has not yet been checked against a fresh standalone fitter run in
the cleaned tree.

## Timing Summary

Signoff target:

- target clock: `pending`
- target frequency: `pending`
- target period: `pending`

| status | model | setup WNS (ns) | hold WNS (ns) | Fmax |
|:---:|---|---:|---:|---:|
| ❓ | Standalone cleaned-tree refresh not yet rerun | n/a | n/a | n/a |

Key conclusions:

- no standalone timing closure claim is made yet
- the cleaned tree only reorganizes the collateral; it does not replace the
  required Quartus refresh

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
| Analysis & Synthesis | `pending` | `pending` |
| Fitter | `pending` | `pending` |
| Assembler | `pending` | `pending` |
| Timing Analyzer | `pending` | `pending` |
| Total | `pending` | `pending` |

## Constraint Caveats

- the current `quartus/opq_monolithic_4lane_merge/` collateral is an example
  system generation point, not a refreshed standalone timing signoff harness
- RAM / CAM accounting is explicitly considered unresolved: the next fitter run
  must be reviewed for whether CAM-backed behavior is consuming more memory
  than the old estimate implied
- until that refresh exists, do not quote RAM-block counts or Fmax from older
  collateral as signoff numbers

## Artifacts

- [`quartus/opq_monolithic_4lane_merge/generate.sh`](quartus/opq_monolithic_4lane_merge/generate.sh)
- [`quartus/opq_monolithic_4lane_merge/opq_monolithic_4lane_merge.tcl`](quartus/opq_monolithic_4lane_merge/opq_monolithic_4lane_merge.tcl)
- [`quartus/opq_monolithic_4lane_merge/opq_monolithic_4lane_merge.qsys`](quartus/opq_monolithic_4lane_merge/opq_monolithic_4lane_merge.qsys)
- [`quartus/opq_monolithic_4lane_merge/generated/opq_monolithic_4lane_merge_generation.rpt`](quartus/opq_monolithic_4lane_merge/generated/opq_monolithic_4lane_merge_generation.rpt)

## Result

**⚠️ PENDING for standalone timing / resource signoff**

The tree cleanup is complete, but the standalone Quartus signoff rerun has not
been executed from the new `syn/quartus/` layout yet. Timing, fitted resource,
and RAM/CAM accounting remain open until that refresh is done.

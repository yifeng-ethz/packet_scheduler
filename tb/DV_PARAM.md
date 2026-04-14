# DV_PARAM: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for compile/elaboration-time configuration sweep.

---

## Scope

`DV_PARAM` captures the still-relevant parameter-space closure that cannot be
exercised by runtime UVM randomization because the DUT shape changes at compile
/ elaboration time.

The active current-tree scope is intentionally narrow and evidence-driven:

- `N_SHD = 128 / 256 / 512`
- derived `TICKET_FIFO_DEPTH` that remains safe for the selected `N_SHD`
- default `PAGE_RAM_DEPTH=65536` on healthy-path checks

This is the correct place to record what the old prompt asked for as
"build-phase randomization". In current terms, this is a **compile /
elaboration-time parameter sweep**. The harness samples the chosen values into
`cg_cfg`, then the merged UCDB closes those bins across runs.

---

## Promoted Sweep

| `N_SHD` | Ticket depth policy | Tests | Current status |
|---------|---------------------|-------|----------------|
| `128` | default / derived safe depth | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` | Passing |
| `256` | default `256` | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` | Passing |
| `512` | derived `> N_SHD` depth | `opq_basic_smoke_test`, `opq_basic_ts_boundary_test`, `opq_edge_max_hits_test` | Passing |

The runner for this bucket is `packet_scheduler/tb/scripts/run_param.sh`.

---

## Coverage Intent

This bucket owns the signoff-visible configuration bins for the active harness:

- `cg_cfg.n_shd = 128 / 256 / 512`
- `cg_cfg.ticket_depth = 256 / 512 / 1024+`
- `cg_cfg.n_shd x ticket_depth`
- `cg_cfg.page_depth = default / reduced-overflow`

The healthy-path sweep intentionally reuses `DV_BASIC` plus `opq_edge_max_hits`
because those tests are the highest-signal checks for the current non-default
`N_SHD` closure.

---

## Still Relevant Legacy Backlog

The archived parameter matrix remains relevant, but is not yet a live claim:

- `MODE=MULTIPLEXING`
- `TRACK_HEADER=false`
- wider `N_LANE` sweep
- non-default `PAGE_RAM_RD_WIDTH`
- non-default ingress width / channel width / FIFO depth sweeps

These stay in the backlog until the live harness and packaging path support
them cleanly enough for signoff-quality closure.

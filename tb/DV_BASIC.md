# DV_BASIC: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for passing native-SV directed healthy-path cases.

---

## Scope

`DV_BASIC` holds the low-risk, no-drop, always-correctness cases that define
the current harness contract:

- hit-integrity end to end
- full timestamp reconstruction from header plus subheader
- correct subheader slot placement
- zero unexpected lane or frame-table drops

The current harness only claims the live 2-lane monolithic VHDL DUT.
The current signoff claim is the live 2-lane native monolithic SystemVerilog
DUT; the archived VHDL image remains reference-only.

---

## Promoted Cases

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_basic_smoke_test` | Healthy bring-up spine with long frames and scoreboard hit integrity | Passing |
| `opq_basic_ts_boundary_test` | Sparse/boundary subheader timestamp values with full-ts reconstruction | Passing |
| `opq_basic_subheader_shape_test` | Mixed empty / non-empty subheader structure on the healthy path | Passing |
| `opq_basic_feb_packet_contract_test` | Native FEB whole-frame packet contract, including monitor-side frame reconstruction from real DUT pins | Passing |
| `opq_basic_single_active_lane_test` | One hit-producing lane while the peer lane stays on legal empty-frame cadence | Passing |

---

## Coverage Intent

These cases are the primary owners for:

- healthy `cg_frame` bins
- boundary `cg_subheader.shd_ts` bins
- subheader hit-count and empty/non-empty shape bins
- FEB whole-frame cadence and packetized-header bins
- ingress / egress beat-shape baseline bins
- default `N_SHD` plus signoff sweep at `128 / 256 / 512`

---

## Still Relevant Legacy Backlog

The following archived `DV_BASIC` expressions remain valid but are not live
claims yet:

- `MODE=MULTIPLEXING`
- `TRACK_HEADER=false`
- non-default width sweeps
- live `N_LANE` sweep beyond the checked-in 2-lane harness

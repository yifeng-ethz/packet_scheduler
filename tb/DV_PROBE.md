# DV_PROBE: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-21
**Status:** Active current-tree bucket for non-promoted historical bug anchors, long-runtime closure probes, and supplemental screens that stay outside the fixed promoted matrix.

---

## Scope

`DV_PROBE` is intentionally separate from the promoted signoff buckets.

These cases are still valuable because they exercise the right contract edges,
but they are intentionally outside the fixed promoted signoff matrix. Some are
historical bug anchors that are now kept green on the current tree, while
others are longer-runtime or supplemental reduced-depth screens whose clean
evidence is intentionally tracked outside the promoted set. They therefore add
debug value and coverage evidence, but they must not be counted as promoted
signoff closure until the required refresh or promotion step is complete.

The runner for this bucket is `packet_scheduler/tb/scripts/run_probes.sh`.

---

## Active Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Refreshed on `2026-04-21`: seed `1` closes with `expected=990 actual=990 missing=0 ghost=0`, seeds `2..8` close with `expected=1864 actual=1864 missing=0 ghost=0`, and every refreshed seed ends with per-lane `unexplained=0`; kept probe-only as supplemental large-random confidence rather than a fixed matrix case |
| `opq_cross_drr_bursty_frame3_repro_test` | Reduced deterministic bursty DRR retirement anchor | Passing on `2026-04-21` with `expected=714 actual=714 missing=0 ghost=0`; retained as the shortest historical closure check for the former `BUG-025-R` boundary |
| `opq_cross_random_ready_overflow_seconds_soak_test` | Default-build random-ready overflow / backpressure soak with per-step `wr = rd + drop` ledger checks | Current-tree shape-check green rerun closes with `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=29/68/5545`, `rd_hdr/shd/hit=29/68/5545`, aggregate `accepted=5545 delivered=5545 unexplained=0`, and `core_principles first_break=clean`; kept probe-only because it is a long random-ready stress screen rather than a fixed promoted case |
| `opq_cross_mixed_bucket_seconds_soak_test` | Earlier extended mixed-bucket random soak with longer chained no-restart traffic and stretched simulated time | Passing long-runtime probe; retained outside the promoted matrix because it is a runtime stress screen rather than a fixed signoff case |
| `opq_error_ftable_overflow_test` | Reduced-depth forced overwrite / frame-table drop accounting on the dedicated `OPQ_PAGE_RAM_DEPTH=512` elaboration point | Current-tree reduced-depth supplemental screen is green again: the refreshed rerun closes with `wr_hdr=32 rd_hdr=20 drop_hdr=12`, `wr_shd=8191 rd_shd=5120 drop_shd=3071`, `wr_hit=44 rd_hit=28 drop_hit=16`, aggregate `accepted=28 delivered=28 unexplained=0`, and `UVM_ERROR : 0`; retained here as a separate-depth probe while the stronger overwrite-local witness lives in `opq_cross_bp_mustdrop_witness_test` |

---

## Coverage Intent

This bucket is still sampled because it touches holes the promoted suite does
not:

- `cg_drop` on frame-table overwrite paths
- `cg_drr` hot-lane defer-heavy behavior and large-random failure checkpoints
- default-build overflow / backpressure checkpoints that prove `ft_wr = ft_rd + ft_drop`
- runtime-stress checkpoints and historical bug anchors that are kept green
  outside the promoted matrix

Probe coverage is diagnostic evidence, not closure evidence.

---

## Promotion Rule

A probe moves into a promoted bucket only after:

- zero `UVM_ERROR` / `UVM_FATAL`
- zero `** Error:` assertion failures
- scoreboard integrity or justified drop accounting is clean
- the testcase adds distinct coverage on a stable contract path

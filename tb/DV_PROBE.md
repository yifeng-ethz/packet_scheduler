# DV_PROBE: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree bucket for non-promoted bug reproducers and closure probes.

---

## Scope

`DV_PROBE` is intentionally separate from the promoted signoff buckets.

These cases are still valuable because they exercise the right contract edges,
but they are intentionally outside the fixed promoted signoff matrix. Some are
still open bug reproducers, while others are longer-runtime or report-hygiene
screens whose clean evidence has not yet been folded into the promoted set.
They therefore add debug value and coverage evidence, but they must not be
counted as promoted signoff closure until the required refresh or promotion
step is complete.

The runner for this bucket is `packet_scheduler/tb/scripts/run_probes.sh`.

---

## Active Probes

| Test | Purpose | Current status |
|------|---------|----------------|
| `opq_cross_drr_bursty_random_test` | Constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | Focused reproducer is fixed on current native-SV RTL; the larger constrained-random testcase remains probe-only until a refreshed rerun is recorded |
| `opq_cross_mixed_bucket_seconds_soak_test` | Earlier extended mixed-bucket random soak with longer chained no-restart traffic and stretched simulated time | Passing long-runtime probe; retained outside the promoted matrix because it is a runtime stress screen rather than a fixed signoff case |
| `opq_error_header_mask_recovery_test` | Inject a malformed preamble/header, then expect the next legal FEB frame to recover cleanly | Passing isolated native-SV after the header timestamp-base repair; still excluded from the generated signoff set pending ERROR-bucket/report refresh |
| `opq_error_header_word_mask_recovery_test` | Header-word error injection followed by a legal recovery frame | Passing isolated native-SV after the same repair; still outside the generated ERROR bucket until the baseline is refreshed |

---

## Coverage Intent

This bucket is still sampled because it touches holes the promoted suite does
not:

- `cg_drop` on frame-table overwrite paths
- `cg_drr` hot-lane defer-heavy behavior
- replay of malformed-header recovery sequences
- runtime-stress checkpoints and assertion firing points that should later move
  from probe-only to green

Probe coverage is diagnostic evidence, not closure evidence.

---

## Promotion Rule

A probe moves into a promoted bucket only after:

- zero `UVM_ERROR` / `UVM_FATAL`
- zero `** Error:` assertion failures
- scoreboard integrity or justified drop accounting is clean
- the testcase adds distinct coverage on a stable contract path

# DV_FORMAL: ordered_priority_queue (monolithic)

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`  
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)  
**Date:** 2026-04-14  
**Status:** Active current-tree formal-readiness plan for the monolithic OPQ.

---

## Purpose

Formal is a separate signoff activity from directed or constrained-random
simulation. Its job here is to prove the local timing / ownership invariants
that remain expensive to close only with simulation.

The immediate strategy is:

- short term: mixed-language SVA bind onto the active monolithic VHDL DUT
- medium term: move the highest-value properties into the native SV rewrite so
  proofs can run on block-level SV without mixed-language friction

---

## Candidate Proof Units

| Unit | Property family | Current evidence | Next step |
|------|-----------------|------------------|-----------|
| Ingress AVST | sideband requires valid, no illegal nested packet markers | `opq_avst_ingress_sva` green in promoted suite | keep as proof candidate once bind flow is stable |
| Egress AVST | hold-under-backpressure, no payload/sideband change while stalled | `opq_avst_egress_sva` green on promoted path | promote to formal once sideband oracle is trustworthy |
| Hit contract | no hit outside an open non-empty subheader, monotonic non-empty subheader ts | `opq_hit3_contract_sva` green only on promoted healthy path | keep probe-only for bursty/overwrite until RTL bug is fixed |
| DRR arbiter | onehot grant, defer legality, page-allocator preemption, no grant without eligibility | `opq_drr_sva` green on directed allowance case | formalize at arbiter boundary first |
| Credit conservation | lane/ticket free-credit must remain in-range and recover after drain | CSR + scoreboard checks on promoted tests | add internal conservation properties at FIFO boundaries |
| Frame-table overwrite | overwritten resident content must be counted in drop counters | CSR probe only; overflow testcase still open | add tracker/presenter-local properties after late-drop observability is improved |

---

## Simulation / Formal Split

Simulation should continue to own:

- end-to-end hit integrity
- packet formatting
- runtime CSR programming sequences
- multi-frame / multi-lane traffic realism

Formal should own:

- cycle-local boundary contracts
- resource ownership and exclusion
- legal FSM transitions
- no-underflow / no-overflow invariants
- bounded-response properties for arbitration and restart

---

## Trace To Current Tests

| Formal target | Matching simulation stress |
|---------------|---------------------------|
| DRR defer / recover | `opq_cross_drr_allowance_test`, `opq_cross_drr_bursty_random_test` |
| Egress hold / restart | `opq_edge_backpressure_test`, `opq_edge_toggle_backpressure_test` |
| Drop / overwrite accounting | `opq_error_ftable_overflow_test` |
| Recovery after control action | `opq_error_lane_mask_test`, `opq_error_lane_mask_recovery_test` |

This split is intentional: constrained-random tests are used to trigger the
same contracts that later become proof targets.

# OPQ Architecture Note

## Purpose

This note freezes the intended overflow and frame-ownership contract for the
monolithic `packet_scheduler` ordered-priority-queue path. It is meant to keep
DV, RTL debug, and future refactors anchored on the same architectural rules.

The active implementation target is the native SystemVerilog monolithic DUT.
The old monolithic VHDL image remains useful as a behavioral reference,
especially the Appendix A discussion of the asynchronous multi-page ping-pong
read/write structure.

## Core Model

The OPQ is built as a fully asynchronous multi-page read/write structure so
that page allocation, frame-table ownership, and presentation can make progress
without turning the whole datapath into a single lock-step pipeline.

That design is intentional. The trade is not "no overflow ever". The trade is:

- read and write should remain as non-blocking as practical
- overflow is allowed at clearly defined ownership boundaries
- incomplete packet format is never allowed
- the frame table must not contain holes once ownership has been declared

## Legal Overflow Boundaries

Overflow is legal only when it is explicit, observable, and accounted for at a
boundary that already owns the decision.

The currently intended legal boundaries are:

- ingress parse under credit backpressure
- frame-table overwrite by the write thread when unread resident storage is
  overwritten

Overflow is not itself a bug. Silent overflow is the bug.

## Forbidden Outcomes

The following outcomes are architecturally forbidden:

- incomplete or malformed packet structure at egress
- frame-table holes after the allocator has declared ownership for a block
- silent loss where accepted hits disappear without a drop identity
- whole-pipeline HoL behavior where one lane stalls unrelated lanes long after
  its own local decision should have been made

In particular, overflow must not create a partially filled resident frame that
still looks committed to later stages.

## Lane-Local Responsibility And HoL

The intended rule is "each lane is responsible for itself".

- If a lane can no longer contribute legally before ownership is declared, it
  should drop at its own lane-local boundary.
- If a lane has already declared hits into the data mover / allocator
  ownership path, those hits must be completed and filled.
- A later or slower lane must not create avoidable HoL blocking for other
  lanes once its local drop/keep decision is available.

The merged frame in interleaving mode may therefore contain a missing subframe
only when that absence is itself declared by a legal counted drop path.

## Declared Hits Must Fill

One rule matters more than the others:

- once the page allocator / data mover has declared that hits belong to a
  frame-table block, those hits must fill that ownership

This is the "no holes in the frame table" rule.

It means:

- header-only or partially committed resident blocks are not acceptable once
  ownership is visible
- overwrite/drop handling must either retire the unread resident traffic with a
  counted drop identity, or keep the resident block intact until it drains
- the system may drop before declaration, but it may not declare and then leave
  sparse ownership behind

## Ingress Error Contract

The architectural default is still the clean ingress path with no error bits
asserted. Error injection is supported only as an explicit typed mask contract,
not as generic undefined corruption.

The supported ingress-error meanings are:

- header / preamble error masks the full frame
- subheader error masks that subheader and its associated hits
- hit error masks only that hit

Two details are architecturally important:

- a hit-error beat is still consumed from the declared subheader stream, but it
  must not allocate lane storage and must not inflate the ticket block length;
  block ownership counts accepted hits, not merely observed hit beats
- a later legal zero-hit subheader after a masked subheader returns the parser
  to the normal body state; trailer-side bypass/drop metadata must describe
  only the surviving local masked subheader semantics and must not latch the
  old drop state through the rest of the frame
- the three ingress error bits are location-specific; asserting one on the
  wrong beat type is illegal input and belongs to the formal legality contract,
  not to a supported runtime behavior

This keeps the no-error datapath simple while still giving users a controlled
way to mask bad content at frame, subheader, or hit granularity.

## Practical Consequences For DV

The invariant-first DV view should treat losses as legal only when they are:

- counted
- classified
- lane-local or overwrite-local
- consistent with `frame_table_write = frame_table_read + frame_table_drop`

Useful checkpoints are:

- ingress accepted-frame ledger
- mover / frame-table ownership ledger
- egress emitted-frame ledger

The first checkpoint with non-zero unexplained hits is the primary debug
anchor.

## Current Closure Readout

The latest DV evidence now splits the default-build overflow space into two
architecturally different halves:

- `opq_cross_bp_predrop_boundary_test` is the green proof that sustained
  default-build backpressure can stay entirely in the legal ingress pre-drop
  regime. In that case `ft_drop_*` remains zero, the per-lane hit ledgers close
  with `unexplained=0`, and `frame_table_write = frame_table_read + frame_table_drop`
  still holds.
- `opq_cross_random_ready_overflow_step2_boundary_test` is the green proof
  that the first two default-build random-ready overflow windows may also stay
  entirely legal: `ft_drop_*` remains zero, the per-step hit ledgers close
  with `unexplained=0`, and `frame_table_write = frame_table_read + frame_table_drop`
  still holds at both checkpoints and at end-of-test.
- the refreshed supplemental `OPQ_N_LANE=4`, `OPQ_N_SHD=128`,
  `OPQ_TICKET_FIFO_DEPTH=256` reruns now close on the same architectural
  rules: `opq_basic_single_active_lane_test`,
  `opq_basic_feb_packet_contract_test`,
  `opq_error_hit_mask_recovery_test`,
  `opq_cross_drr_bursty_frame2_boundary_test`,
  `opq_cross_random_ready_overflow_step2_boundary_test`,
  `opq_cross_masked_drop_exact_102_117_repro_test`, and
  `opq_cross_mixed_bucket_random_soak_test` all exit with `UVM_ERROR : 0`;
  the overflow-step2 and mixed-soak reruns now also keep per-lane
  `accepted=delivered` and `unexplained=0` after the scoreboard stopped using
  parser-only timestamps for delivered-hit retirement.
- `opq_error_ftable_overflow_test` at `OPQ_PAGE_RAM_DEPTH=512` remains a
  reduced-depth supplemental shape-check screen rather than the primary
  must-drop witness. The historical `2-lane/256/512` rerun still closes with
  `UVM_ERROR : 0`, frame-table ledger
  `wr_hdr=32 rd_hdr=20 drop_hdr=12`,
  `wr_shd=8191 rd_shd=5120 drop_shd=3071`,
  `wr_hit=44 rd_hit=28 drop_hit=16`, and aggregate
  `accepted=28 delivered=28 unexplained=0`. On the refreshed
  `4-lane/128/512` preset, both the legacy and dense traffic profiles stay
  shape-check-only and do not advance `ft_drop_*`, so that testcase is no
  longer the portable must-drop witness on the wider lane matrix.
- `opq_cross_random_ready_overflow_seconds_soak_test` is also a shape-check
  screen by default on the current tree. The 12-step full-depth rerun closes
  with `UVM_ERROR : 0`, `ft_drop_hdr/shd/hit=0/0/0`,
  `wr_hdr/shd/hit=29/68/5545`, `rd_hdr/shd/hit=29/68/5545`, aggregate
  `accepted=5545 delivered=5545 unexplained=0`, and
  `core_principles first_break=clean`.
- `opq_cross_bp_mustdrop_witness_test` at the reduced-depth `12x16` profile is
  now back to being the clean overwrite-local proof point. On the refreshed
  `2026-04-21` rerun with
  `OPQ_PAGE_RAM_DEPTH=512`,
  `+OPQ_BP_MUSTDROP_NODROP_FRAME_COUNT=1`,
  `+OPQ_BP_MUSTDROP_NODROP_HITS=1`,
  `+OPQ_BP_MUSTDROP_FRAME_COUNT=12`, and
  `+OPQ_BP_MUSTDROP_HITS=16`, the no-drop pre-phase keeps
  `ft_drop_delta hdr/shd/hit=0/0/0`, the pressure phase advances
  `ft_drop_delta hdr/shd/hit=10/80/2400`, the final frame-table ledger closes
  at `wr_hdr/shd/hit=13/224/3135`, `rd_hdr/shd/hit=3/144/735`,
  `drop_hdr/shd/hit=10/80/2400`, and aggregate
  `accepted=735 delivered=735 unexplained=0` with
  `core_principles first_break=clean`.
- The remaining architectural coverage gap is no longer an active bug. It is
  that the explicit must-drop proof today is reduced-depth and named, while a
  comparable default-build must-drop hybrid is still optional future coverage
  work.

## Current Debug Reading

The current open debug picture is now narrower:

- `BUG-025-R` is now understood as two coupled hazards:
  - active-lane retirement must not depend on the transient parser
    `alert_eop` level
  - later tails must not erase the exact drop status of the earlier packet
    currently being classified
  The current repair does both: active retirement uses latched tail-seen state,
  and current-SOP classification now consults an exact per-serial tail-status
  shadow. The named `opq_cross_drr_bursty_frame3_repro_test` rerun on
  `2026-04-21` closes with `expected=714 actual=714 missing=0 ghost=0`, and
  the refreshed `opq_cross_drr_bursty_random_test` seed sweep `1..8` is also
  green on the same patchset with `UVM_ERROR : 0` and per-lane
  `unexplained=0`. This bug family is therefore not currently reproduced on
  the named deterministic or constrained-random screens.
- `BUG-026-R` is now closed on the current tree. The presenter delays
  retirement until the final egress acceptance boundary and preserves any
  unread resident `page_ram.q` word in a skid path whenever the launch pipe
  stops, while the allocator-side exact-drop repair removes the old synthetic
  zero-payload frame leak. The refreshed full
  `opq_cross_random_ready_overflow_step2_boundary_test` rerun on `2026-04-21`
  is green again with final `wr_hdr/shd/hit=6/11/1176`,
  `rd_hdr/shd/hit=6/11/1176`, aggregate
  `accepted=1176 delivered=1176 unexplained=0`, and
  `core_principles first_break=clean`. The named reduced-depth
  `opq_cross_bp_mustdrop_witness_test` `12x16` profile is also green again on
  `2026-04-21`, and the same witness now reruns green on the refreshed
  `4-lane/128/512` preset with pressure-phase
  `ft_drop_delta hdr/shd/hit=10/80/2400`, final aggregate
  `accepted=735 delivered=735 unexplained=0`, and `UVM_ERROR : 0`. The
  remaining work is therefore coverage expansion and testcase portability, not
  an active overwrite bug.

Those bugs should be judged against this note, not against an informal "avoid
overflow" goal. Overflow is allowed. Silent or malformed overflow is not.

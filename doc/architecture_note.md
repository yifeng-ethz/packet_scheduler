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

## Current Debug Reading

The current open bug family is consistent with three separate architectural
violations, not one:

- `BUG-024-R`: accepted-egress framing corruption at the reduced-depth
  overwrite launch boundary
- `BUG-025-R`: large random mixed traffic still shows silent hit loss / ghost
  creation before the failing boundary is fully proven
- `BUG-026-R`: random-ready overflow still shows unread tail traffic being
  consumed without matching frame-table drop identity

Those bugs should be judged against this note, not against an informal "avoid
overflow" goal. Overflow is allowed. Silent or malformed overflow is not.

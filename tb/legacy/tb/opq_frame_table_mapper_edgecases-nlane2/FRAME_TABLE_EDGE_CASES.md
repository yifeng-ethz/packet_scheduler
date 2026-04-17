# Frame Table (mapper+tracker+presenter) edge-case plan

Goal: reproduce and prevent the “broken packet / missing hits / wrong packet association” class of failures
observed in the monolithic OPQ when the egress is backpressured and the write window overwrites tiles.

This plan is implemented as directed stimuli (and a small stress loop) in `tb_opq_frame_table.vhd`.

## Edge cases to cover

1) **Basic non-spill, ready always**
   - One frame, no wrap/spill.
   - Expect: presenter outputs exactly the written words, no duplicates, correct packet termination.

2) **Spill across page boundary (two tiles)**
   - Start address near `PAGE_RAM_DEPTH-1` so frame wraps.
   - Expect: correct trail-tile link verify (`trail_tid`/`body_tid`), seamless output across tiles.

3) **Backpressure restart mid-packet**
   - Deassert `egress_ready` while `valid=1`.
   - Expect: no duplicated/missing words; presenter uses RESTART refill and continues cleanly.

4) **Flush/overwrite of a tile containing queued meta**
   - Queue packet meta in a tile, then force a mapper-driven flush of that tile (simulating overwrite).
   - Expect: tile FIFO pointers and `tile_pkt_*cnt` are aligned so presenter never outputs stale meta.

5) **Long egress stall + continuous writes (overwrite pressure)**
   - Hold `egress_ready=0` for a long time while new frames are started/finished.
   - Expect: no “broken” output (either correct packets, or dropped packets via frame_invalid/flush policy).
   - Monitor `wr_blocked_by_rd_lock`: when asserted, the write side must treat the in-flight frame as invalid.
   - Implemented (basic form) as Test 4: write attempts into an rd-locked tile must not cause stale-meta replay.

6) **Simultaneous multi-command update (spill update_ftable_valid = \"11\")**
   - Ensure tracker can accept/update both head and spill tiles in the same cycle.

7) **Broken spill link verification**
   - Corrupt `body_tid`/`trail_tid` link (or simulate by flushing one side) and ensure presenter skips/drop
     rather than outputting a mis-associated spill body.

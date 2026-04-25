# packet_scheduler model evidence ladder

This tree follows the `modeling-rtl` evidence sequence:

1. `analytical/`: queueing and network-calculus equations, generated CSVs,
   DISLIN matrices, and DISLIN-rendered architecture plots.
2. `tlm/`: deterministic transaction-level finite-FIFO event model, generated
   CSVs, DISLIN matrices, and DISLIN-rendered feature-sweep plots.
3. `rtl_sim/`: HDL-derived evidence only. The current contents are residency
   proxy artifacts from UVM logs plus a case catalog for the pending matched
   OPQ/time-merger loss sweep.
4. `on_board/`: board-derived evidence only. This tier is intentionally empty
   until hardware counters are collected.

Do not copy analytical or TLM plots into lower evidence tiers. Lower tiers must
be generated from their own raw observables and use the same axis definitions:
`B=(SCV-1)/(SCV+1)`, `rho_lane`, `ready_duty`, `N_LANE`, and egress width.

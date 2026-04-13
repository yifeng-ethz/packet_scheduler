# packet_scheduler
Various packet schedulers implementations for aggregating high-speed upload data flows

## Structure (2026-04-13)
- `rtl/`: synthesizable RTL + TERP templates (see `rtl/README.md`).
- `tb/`: current active verification harness for monolithic OPQ.
- `syn/`: Platform Designer / Qsys example systems and generation scripts.
- `doc/`: current verification review and signoff notes.
- `legacy/`: deprecated directed TB and UVM harness archive (see `legacy/README.md`).
- `trash_bin/`: generated artifacts + legacy snapshots (see `trash_bin/README.md`).

## Platform Designer components (kept at repo root)
- `intf_adapter_hw.tcl`
- `ordered_priority_queue_hw.tcl` (monolithic OPQ)
- `ordered_priority_queue_v2_hw.tcl` (split OPQ)

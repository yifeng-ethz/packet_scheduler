# packet_scheduler
Various packet schedulers implementations for aggregating high-speed upload data flows

## Structure (2026-02-02)
- `rtl/`: synthesizable RTL + TERP templates (see `rtl/README.md`).
- `tb/`: directed testbenches (see `tb/README.md`).
- `uvm/`: unit UVM tests for split blocks (see `uvm/README.md`).
- `trash_bin/`: generated artifacts + legacy snapshots (see `trash_bin/README.md`).

## Platform Designer components (kept at repo root)
- `intf_adapter_hw.tcl`
- `ordered_priority_queue_hw.tcl` (monolithic OPQ)
- `ordered_priority_queue_v2_hw.tcl` (split OPQ)

# packet_scheduler RTL

Synthesizable RTL sources and TERP templates for the packet scheduler IPs.

## Layout (2026-02-02)
- `common/`: small reusable blocks (e.g. `random_toggler.vhd`).
- `vendor/alt_ram/`: pre-generated RAM/FIFO wrappers used by the monolithic OPQ integration.
- `intf_adapter/`: `intf_adapter.terp.vhd` (Platform Designer component template).
- `ordered_priority_queue/`:
  - `monolithic/`: original OPQ TERP template (`ordered_priority_queue.terp.vhd`).
  - `debug/`: debug/experiment TERP copy (`ordered_priority_queue.debug.terp.vhd`).
  - `split/`: refactored OPQ implementation and wrapper template:
    - `split/top/`: TERP-facing wrapper template (`ordered_priority_queue_top.terp.vhd`) and helper script.
    - `split/opq/`: split architecture blocks (parser/allocator/mover/frame_table/...).
    - `split/docs/`: notes and changelogs.

## Notes
- `LANE_FIFO_DEPTH` is assumed to be **power-of-two** for ring-buffer pointer wrap; enforced in HW Tcl and asserted in split RTL.

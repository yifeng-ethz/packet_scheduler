# packet_scheduler TB

Archived directed testbenches for packet_scheduler RTL blocks.

This tree was moved under `legacy/` on 2026-04-13 after the old harness was deprecated. Keep it runnable for historical debug, but do not treat it as the active monolithic DV signoff environment.

## Naming convention
TB folders follow:

`<module_name(s)>_<scenario>-<attributes>`

Examples:
- `opq_block_mover_smoke-nlane1`
- `ordered_priority_queue_monolithic_smoke-nlane2`

## Quick runs
- Split module TBs: `bash packet_scheduler/legacy/tb/run_all_split_tb.sh`
- Monolithic OPQ TB: `bash packet_scheduler/legacy/tb/ordered_priority_queue_monolithic_smoke-nlane2/run_tb.sh`
- Archive lint helper: `bash packet_scheduler/legacy/tb/lint/lint.sh`

## Generated artifacts
ModelSim outputs (`work*`, `transcript`, `vsim.wlf`, `.vcd`, logs) should be treated as generated and are moved under `packet_scheduler/trash_bin/<date>/`.

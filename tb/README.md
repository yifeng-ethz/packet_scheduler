# packet_scheduler TB

Directed testbenches for packet_scheduler RTL blocks.

## Naming convention
TB folders follow:

`<module_name(s)>_<scenario>-<attributes>`

Examples:
- `opq_block_mover_smoke-nlane1`
- `ordered_priority_queue_monolithic_smoke-nlane2`

## Quick runs
- Split module TBs: `bash packet_scheduler/tb/run_all_split_tb.sh`
- Monolithic OPQ TB: `bash packet_scheduler/tb/ordered_priority_queue_monolithic_smoke-nlane2/run_tb.sh`
- Lint: `bash packet_scheduler/tb/lint/lint.sh`

## Generated artifacts
ModelSim outputs (`work*`, `transcript`, `vsim.wlf`, `.vcd`, logs) should be treated as generated and are moved under `packet_scheduler/trash_bin/<date>/`.

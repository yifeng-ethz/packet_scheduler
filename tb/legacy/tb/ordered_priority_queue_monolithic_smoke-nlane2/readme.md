# ordered_priority_queue testbench quickstart

## Run
- From this folder run `bash run_tb.sh`. It regenerates `ordered_priority_queue.vhd` from the external preprocessed source, applies local patches (debug signals, parameter defaults), compiles, and runs ModelSim in console mode. Output VCD: `ordered_priority_queue_tb.vcd`.
- ModelSim path is set in `run_tb.sh` (`/data1/intelFPGA/18.1/modelsim_ase/bin`). Update if your install differs.
- `update_preprocessed.sh` expects the preprocessed VHDL in `SRC_DIR=/home/yifeng/packages/online_dpv2/.../ordered_priority_queue_250722/synth`. If missing, the script exits with an error.

## Debug instrumentation
- Debug signals (`dbg_page_allocator_state`, `dbg_ftable_presenter_state`, `dbg_block_mover_state[*]`) are injected by `update_preprocessed.sh` so they remain even after regenerating the DUT file. VCD includes these plus egress flags.
- Testbench uses `ts_step=2048` (N_SHD=128) and drives three epochs with `aso_egress_ready` held high to flush packets.

## Keeping patches when source changes
- `ordered_priority_queue.vhd` is overwritten each run. Any manual edits must be encoded in `update_preprocessed.sh`; otherwise they will be lost.
- If the preprocessed source changes and the script fails to match patterns, update `update_preprocessed.sh` to reapply parameter defaults and debug inserts before rerunning the simulation.

## Notes
- This TB folder generates the DUT from a local TERP template when `OPQ_USE_DEBUG_TERP=1` (see `update_preprocessed.sh`).

# Debugging notes for ordered_priority_queue TB

- Testbench drives three epochs (ts_step=2048 ticks) with `aso_egress_ready` held high to let packets drain as soon as they are produced. Egress activity now appears around ~16.6 µs and ~33.2 µs.
- Added always-on debug taps (`dbg_page_allocator_state`, `dbg_ftable_presenter_state`, `dbg_block_mover_state[*]`) via `update_preprocessed.sh` so they survive regenerating `ordered_priority_queue.vhd`. They are emitted in `ordered_priority_queue_tb.vcd`.
- Block mover lane 0 stays IDLE; lane 1 briefly hits ABORT_WRITE_BLK early. Presenter toggles to PRESENTING at the same times `aso_egress_valid` pulses.
- Use the VCD (`ordered_priority_queue_tb.vcd`) to inspect internal states. Useful signals: `dbg_page_allocator_state`, `dbg_ftable_presenter_state`, `dbg_block_mover_state[0/1]`, `aso_egress_valid/startofpacket/endofpacket`, lane/ticket FIFO interfaces.
- If the preprocessed source changes, rerun `bash update_preprocessed.sh`. If patterns no longer match, adjust the script so debug signals and parameter defaults (N_LANE=2, N_SHD=128, ts_step=2048) remain injected before running the sim.

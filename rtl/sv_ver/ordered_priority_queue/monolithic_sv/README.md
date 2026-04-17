# ordered_priority_queue monolithic_sv

This directory is the active SystemVerilog-facing shell for the monolithic OPQ.

## Current status
- `ordered_priority_queue_dut_sv.sv` is a stable SystemVerilog module that wraps the generated VHDL monolithic DUT used by the current UVM harness.
- This is enough to host SystemVerilog assertions and mixed-language verification in `packet_scheduler/tb/uvm`.
- `ordered_priority_queue_monolithic.sv` is now a slim top-level shell for the source-level translation track.
- `ordered_priority_queue_monolithic_ingress_parser.sv` carries the translated per-lane ingress parser and its local SVA.
- `ordered_priority_queue_monolithic_page_allocator.sv` carries the translated shared page allocator and its local SVA.
- `ordered_priority_queue_monolithic_block_path.sv` carries the translated handle-reader, lane-to-page block mover, and B2P arbiter.
- `ordered_priority_queue_monolithic_basic_presenter.sv` is a non-spill presenter used to validate the native SV data path on the current default/basic UVM smoke.
- `ordered_priority_queue_monolithic_frame_table_tracker.sv` carries the translated frame-table tracker block.
- `ordered_priority_queue_monolithic_frame_table_presenter.sv` carries the translated frame-table presenter block.
- The native split path now passes `opq_basic_smoke_test` in `packet_scheduler/tb/uvm` with the same scoreboard/sequencer contract as the VHDL wrapper path.
- The active monolithic shell still uses the basic presenter for the current regression-backed default path.
- The remaining rewrite gap is the full frame-table/tile architecture hookup from the VHDL monolith:
  - frame-table mapper
  - multi-tile page RAM routing
  - top-level integration of the translated tracker/presenter blocks
- A full source-level translation of the internal VHDL implementation into maintainable hand-edited SystemVerilog is still in progress, but the exercised default path is now native-SV and regression-backed.

## Why this exists
- It gives the DV harness a native SV DUT handle today.
- It avoids mutating the monolithic VHDL source while the assertion/formal flow is being built up.
- It provides a place to split the rewrite by architectural block instead of growing another monolith.

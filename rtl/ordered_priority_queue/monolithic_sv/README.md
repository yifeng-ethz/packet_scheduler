# ordered_priority_queue monolithic_sv

This directory is the active SystemVerilog-facing shell for the monolithic OPQ.

## Current status
- `ordered_priority_queue_dut_sv.sv` is a stable SystemVerilog module that wraps the generated VHDL monolithic DUT used by the current UVM harness.
- This is enough to host SystemVerilog assertions and mixed-language verification in `packet_scheduler/tb/uvm`.
- A full source-level translation of the internal VHDL implementation into maintainable hand-edited SystemVerilog is still a separate follow-up task. The practical blocker is that the available automatic export path does not yet cleanly synthesize the VHDL-2008 template into a reusable SV model.

## Why this exists
- It gives the DV harness a native SV DUT handle today.
- It avoids mutating the monolithic VHDL source while the assertion/formal flow is being built up.

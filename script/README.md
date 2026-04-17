# packet_scheduler script

Platform Designer packaging and root-level IP scripts for `packet_scheduler`.

## Contents

- `ordered_priority_queue_hw.tcl`: monolithic OPQ component packaging.
- `ordered_priority_queue_v2_hw.tcl`: split OPQ component packaging.
- `intf_adapter_hw.tcl`: interface-adapter component packaging.

## Usage

Add `packet_scheduler/script` to the Platform Designer IP search path. The
scripts now reference the canonical `rtl/legacy/`, `rtl/vhdl_ver/`, and
`rtl/sv_ver/` trees directly.

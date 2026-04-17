# packet_scheduler RTL

Synthesizable RTL sources and TERP templates for the packet scheduler IPs.

## Canonical Layout

- `legacy/`: legacy monolithic VHDL sources and helpers.
  - `legacy/common/random_toggler.vhd`
  - `legacy/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd`
  - `legacy/ordered_priority_queue/debug/ordered_priority_queue.debug.terp.vhd`
- `vhdl_ver/`: maintained VHDL implementations.
  - `vhdl_ver/intf_adapter/intf_adapter.terp.vhd`
  - `vhdl_ver/ordered_priority_queue/split/`
- `sv_ver/`: maintained SystemVerilog implementations and vendor memory wrappers.
  - `sv_ver/ordered_priority_queue/monolithic_sv/`
  - `sv_ver/vendor/alt_ram/`

## Compatibility Paths

The pre-cleanup names are still present as symlinks so archived benches and
older scripts keep working:

- `common/` -> `legacy/common/`
- `intf_adapter/` -> `vhdl_ver/intf_adapter/`
- `vendor/` -> `sv_ver/vendor/`
- `ordered_priority_queue/monolithic` -> `legacy/ordered_priority_queue/monolithic`
- `ordered_priority_queue/debug` -> `legacy/ordered_priority_queue/debug`
- `ordered_priority_queue/split` -> `vhdl_ver/ordered_priority_queue/split`
- `ordered_priority_queue/monolithic_sv` -> `sv_ver/ordered_priority_queue/monolithic_sv`
- `ordered_priority_queue/docs` -> `../doc/rtl_notes/`

## Notes

- The standalone native-SV signoff DUT lives under
  `sv_ver/ordered_priority_queue/monolithic_sv/`.
- `LANE_FIFO_DEPTH` is assumed to be power-of-two for ring-buffer pointer wrap;
  that assumption is still enforced in the packaged split RTL.

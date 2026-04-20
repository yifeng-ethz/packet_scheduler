# packet_scheduler

Ordered-priority-queue packaging, verification, and synthesis collateral for
Mu3e packet scheduling IPs.

## Root Layout

- `rtl/`: canonical RTL tree. `rtl/legacy/` holds the legacy monolithic VHDL
  TERP sources, `rtl/vhdl_ver/` holds the split VHDL sources, and
  `rtl/sv_ver/` holds the native-SV signoff RTL. See `rtl/README.md`.
- `tb/`: standalone native-SV UVM signoff harness and DV report tree. See
  `tb/README.md`.
- `tb_int/`: integrated UVM harness that feeds OPQ from the FEB-side chain and
  checks merged-frame behavior in context. See `tb_int/README.md`.
- `script/`: Platform Designer packaging `_hw.tcl` files and other root-level
  IP scripting. See `script/README.md`.
- `doc/`: signoff dashboards, changelog, and migration / RTL notes. See
  `doc/README.md`.
- `syn/`: standalone Quartus and synthesis-side collateral. See
  `syn/README.md`.
- `VERSION`: active ordered-priority-queue package revision stamp.

`legacy/` remains as a compatibility symlink to `tb/legacy/` so older archive
paths still resolve, but new references should point at `tb/legacy/`
explicitly.

## Active Entry Points

- `doc/SIGNOFF.md`
- `doc/CONFIG_SIGNOFF.md`
- `tb/DV_REPORT.md`
- `syn/SYN_REPORT.md`
- `tb_int/DV_REPORT.md`

## Platform Designer Components

Add `packet_scheduler/script` to the Platform Designer IP search path.

- `script/intf_adapter_hw.tcl`
- `script/ordered_priority_queue_hw.tcl` (monolithic OPQ)
- `script/ordered_priority_queue_v2_hw.tcl` (split OPQ)

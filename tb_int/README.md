# packet_scheduler tb_int

Integrated UVM harness for `packet_scheduler`. This tree drives OPQ from the
real FEB-side datapath instead of only synthetic ingress beats.

OPQ signoff still comes from `../tb/`; `tb_int/` exists to prove contract
alignment, merged-frame behavior, and long-run integration sanity.

## Structure

- `uvm/`: integration UVM package, interfaces, SVA, and Makefile.
- `rtl/`: integration-only stubs and the `tb_int_top` wiring.
- `scripts/`: long-run launchers, report collectors, and 4-lane DUT generation.
- `rtl_gen_monolithic_4lane/`: generated 4-lane monolithic OPQ wrapper used by the integration harness.
- `REPORT/`: generated long-run evidence tree.
- `DV_INT_PLAN.md`, `DV_INT_HARNESS.md`, `DV_INT_LONGRUN.md`: integration intent and harness notes.
- `DV_REPORT.md`, `DV_COV.md`, `BUG_HISTORY.md`: generated dashboard plus tracked integration issues.

## Quick Start

- `make -C packet_scheduler/tb_int/uvm run TEST=tb_int_smoke_test`
- `packet_scheduler/tb_int/scripts/run_tb_int.sh tb_int_basic_e2e_test`
- `packet_scheduler/tb_int/scripts/run_tb_int_longrun_matrix.sh`

## Notes

- Two FEB-to-OPQ feed paths are preserved:
  - TLM capture path: FEB framed output can be lifted into transactions and
    observed in UVM through the hooks in `uvm/tb_int_pkg.sv`.
  - Direct pin path: FEB lane signals can still drive OPQ directly through
    `rtl/tb_int_top.sv` and `rtl/swb_ingress_stub.vhd`.
- `DV_REPORT.md` is the current integration dashboard.
- Code coverage in this tree is not yet the standalone OPQ signoff source.

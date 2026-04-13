# packet_scheduler TB

Current active verification harness for the monolithic `ordered_priority_queue`.

## Structure
- `uvm/`: SystemVerilog UVM harness, SVA modules, and runners.
- `scripts/`: regression, lint, and coverage entry points grouped by DV-plan bucket.
- `rtl_gen_monolithic/`: generated concrete VHDL DUT files for the default packaged configuration.

## Quick start
- Generate + compile + run the default smoke case:
  - `make -C packet_scheduler/tb/uvm run TEST=opq_basic_smoke_test`
- Run the plan buckets through the script wrappers:
  - `packet_scheduler/tb/scripts/run_basic.sh`
  - `packet_scheduler/tb/scripts/run_edge.sh`
  - `packet_scheduler/tb/scripts/run_perf.sh`
  - `packet_scheduler/tb/scripts/run_error.sh`
  - `packet_scheduler/tb/scripts/run_cross.sh`
- Run the current lint entry points:
  - `packet_scheduler/tb/scripts/run_lint.sh`
- Run coverage-enabled cases and merge their UCDBs:
  - `packet_scheduler/tb/scripts/run_cov_closure.sh`

## Notes
- Deprecated directed benches and split-era UVM experiments live under `packet_scheduler/legacy/`.
- The current signoff expectations are tracked in `packet_scheduler/doc/VERIFICATION_SIGNOFF.md`.
- On this host the working floating-license path is `questa_fse` with `LM_LICENSE_FILE` and `MGLS_LICENSE_FILE`
  chained to `8161@lic-mentor.ethz.ch:/data1/intelFPGA_pro/23.1/questa_fse/LR-287689_License.dat`.
  The FE executable still rejects the environment here.
- The live `opq_basic_smoke_test` now passes on the active monolithic harness with scoreboard hit-integrity
  checks enabled: same hits in, same hits out, and the first merged subheader lands in the correct time slot.
- The remaining signoff work is closure, not basic bring-up: lint disposition, coverage closure, more buckets from
  `DV_PLAN`, and a full internal SystemVerilog rewrite if the project wants source-level SVA/formal ownership.

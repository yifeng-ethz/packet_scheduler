# packet_scheduler TB

Current active verification harness for the monolithic `ordered_priority_queue`.
Signoff evidence in this tree is required to come from `DUT_IMPL=native_sv`.

## Structure
- `uvm/`: SystemVerilog UVM harness, SVA modules, and runners.
- `scripts/`: regression, lint, and coverage entry points grouped by DV-plan bucket.
- `rtl_gen_monolithic/`: generated concrete VHDL DUT files for the default packaged configuration.
- `REPORT/`: generated per-case / per-bucket / cross-run evidence tree.
- `legacy/`: archived directed benches and split-era UVM experiments preserved for reference.
- `DV_PLAN.md`: current-tree testcase / bucket intent surfaced from the archived plan.
- `DV_HARNESS.md`: current-tree harness contract and known limitations.
- `DV_BASIC.md`, `DV_PARAM.md`, `DV_EDGE.md`, `DV_PROF.md`, `DV_ERROR.md`, `DV_CROSS.md`, `DV_PROBE.md`, `DV_FORMAL.md`: current-tree bucket detail.

## Quick start
- Generate + compile + run the default smoke case:
  - `make -C packet_scheduler/tb/uvm run TEST=opq_basic_smoke_test`
- Run the plan buckets through the script wrappers:
  - `packet_scheduler/tb/scripts/run_basic.sh`
  - `packet_scheduler/tb/scripts/run_param.sh`
  - `packet_scheduler/tb/scripts/run_edge.sh`
  - `packet_scheduler/tb/scripts/run_perf.sh`
  - `packet_scheduler/tb/scripts/run_error.sh`
  - `packet_scheduler/tb/scripts/run_cross.sh`
  - `packet_scheduler/tb/scripts/run_probes.sh`
- Run the current lint entry points:
  - `packet_scheduler/tb/scripts/run_lint.sh`
- Run coverage-enabled cases and merge their UCDBs:
  - `packet_scheduler/tb/scripts/run_cov_closure.sh`

## Notes
- The canonical native-SV signoff DUT lives under
  `packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/`.
- Deprecated directed benches and split-era UVM experiments now live under
  `packet_scheduler/tb/legacy/`.
- The surfaced current DV plan is `packet_scheduler/tb/DV_PLAN.md`; the archived broad catalog remains in `packet_scheduler/tb/legacy/tb/`.
- `DV_PARAM.md` is the active compile / elaboration-time sweep, `DV_PROBE.md` groups non-promoted bug reproducers, and `DV_FORMAL.md` tracks proof targets and formal-readiness.
- The master signoff dashboard is `packet_scheduler/doc/SIGNOFF.md`.
- `packet_scheduler/doc/VERIFICATION_SIGNOFF.md` is preserved as the older long-form narrative note.
- Native-SV signoff scope is currently the 2-lane harness plus the
  `N_SHD=128/256/512` sweep; 4-lane native-SV remains a non-claim until the
  sparse-frame cadence bug in `BUG_HISTORY.md` is closed.
- The probe runner carries the currently useful non-promoted reproducers, including the forced-overwrite error case and the bursty DRR stress case.
- In the current monolithic harness, a lane may be idle in hits but not silent in frame cadence. Directed single-lane tests therefore drive empty frames on the inactive peer lane instead of holding it permanently quiet.
- On this host the working floating-license path is `questa_fse` with `LM_LICENSE_FILE` and `MGLS_LICENSE_FILE`
  chained to `8161@lic-mentor.ethz.ch:/data1/intelFPGA_pro/23.1/questa_fse/LR-287689_License.dat`.
  The FE executable still rejects the environment here.
- The live `opq_basic_smoke_test` now passes on the active monolithic harness with scoreboard hit-integrity
  checks enabled: same hits in, same hits out, and the first merged subheader lands in the correct time slot.
- The remaining signoff work is closure, not basic bring-up: lint disposition, coverage closure, more buckets from
  `DV_PLAN`, and a full internal SystemVerilog rewrite if the project wants source-level SVA/formal ownership.

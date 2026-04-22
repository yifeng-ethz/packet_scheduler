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
- The grouped parameter / bounded-evidence matrix is
  `packet_scheduler/doc/CONFIG_SIGNOFF.md`.
- The exhaustive parameter-space tracer behind that matrix is
  `packet_scheduler/tb/scripts/gen_config_signoff_matrix.py`.
- `packet_scheduler/doc/VERIFICATION_SIGNOFF.md` is preserved as the older long-form narrative note.
- The active generated standalone dashboard is the canonical
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  rerun slice on QuestaOne 2026.
- That current-scope dashboard is now fully populated: `516/516` isolated
  catalog cases are evidenced, `failed_cases=0`, `unimplemented_cases=0`, and
  `22/22` maintained signoff runs are green in the generated report tree.
- Historical 2-lane closure, bounded matrix extensions, and supplemental
  long-run evidence remain useful and are tracked in `doc/SIGNOFF.md`,
  `doc/CONFIG_SIGNOFF.md`, and `tb/BUG_HISTORY.md`, but they are no longer
  backfilled into the active generated dashboard unless rerun in the current
  `4-lane/128/256/native_sv` scope.
- The probe runner carries the currently useful non-promoted screens,
  including the bursty DRR large-random stress and the long-runtime mixed-bucket
  seconds soak. The reduced-depth overwrite shape-check remains tracked under
  `DV_ERROR.md`, while the explicit reduced-depth must-drop witness is tracked
  under `DV_CROSS.md`.
- In the current monolithic harness, a lane may be idle in hits but not silent in frame cadence. Directed single-lane tests therefore drive empty frames on the inactive peer lane instead of holding it permanently quiet.
- On this host the only supported simulator runtime is `QuestaOne 2026` at
  `/data1/questaone_sim/questasim`, with `LM_LICENSE_FILE`,
  `MGLS_LICENSE_FILE`, and `SALT_LICENSE_SERVER` all set to
  `8161@lic-mentor.ethz.ch`.
- Validation note on `2026-04-22`: the supported QuestaOne 2026 reruns are
  refreshed on the maintained native-SV flow, and the generated
  [`DV_REPORT.md`](DV_REPORT.md) / [`DV_COV.md`](DV_COV.md) bundle now reports
  current-scope evidence only. Out-of-scope historical artifacts are preserved
  on disk for reference but are not credited into the active canonical report
  slice.
- The active standalone signoff claim is no longer blocked on testcase
  presence. The current merged isolated totals are
  `stmt=74.41`, `branch=70.36`, `fsm_state=94.39`, `fsm_trans=54.47`, and
  `toggle=33.37`, and those raw structural deltas are now explicitly
  dispositioned in the generated [`DV_COV.md`](DV_COV.md) table rather than
  hidden behind a partial dashboard.
- The live `opq_basic_smoke_test` now passes on the active monolithic harness with scoreboard hit-integrity
  checks enabled: same hits in, same hits out, and the first merged subheader lands in the correct time slot.
- Post-signoff follow-on work is expansion rather than current-scope closure:
  parameter/lane extension, deeper formal ownership, and any future effort to
  turn the raw structural coverage deltas into hard target closure instead of
  justified disposition.

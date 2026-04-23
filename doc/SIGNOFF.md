# ✅ Signoff — packet_scheduler ordered_priority_queue

**DUT:** `ordered_priority_queue` &nbsp; **Date:** `2026-04-23` &nbsp;
**Release under check:** `26.3.66.0423` &nbsp; **Git base:** `post-26.3.65.0422 local signoff batch`

This page is the master signoff dashboard. Detailed standalone synthesis
evidence lives in [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md); detailed DV
evidence lives in [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md). The grouped
configuration legality and evidence matrix lives in
[`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / caveat &middot; ❌ failed / blocked &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ✅ | overall_signoff | `closed` on the active `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv` slice; raw structural coverage deltas are explicitly dispositioned in `../tb/DV_COV.md` |
| ⚠️ | config_matrix | `representative 2-lane and 4-lane measured; active generated dashboard is the canonical 4-lane/128 rerun slice and full package-space closure remains a later phase` |
| ✅ | standalone_syn | `2-lane and 4-lane A10 standalone Quartus signoff both close at 275 MHz on 10AX115N2F45E1SG; the corrected 4-lane refresh now reports +0.077 ns setup slack` |
| ✅ | isolated_dv_closure | `516/516` canonical isolated cases are evidenced in the active `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv` slice; `failed_cases=0`, `unimplemented_cases=0`, and the remaining raw structural deltas are covered by explicit hole disposition rather than missing evidence |
| ✅ | cross_bucket_signoff | `8/8` current maintained signoff runs are green for the active native-SV scope: `bucket_frame`, `all_buckets_frame`, mixed-bucket random soak, DRR frame2 boundary, BP pre-drop boundary, overflow step2 boundary, counter-clear, and reduced-depth frame-table overflow |
| ✅ | tb_int_longrun_matrix | `128/128` integrated matrix cases green |
| ✅ | resource_model | `3,235 ALMs / 129 M20Ks at 2-lane and 10,245 ALMs / 147 M20Ks at 4-lane on the active standalone fits` |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| ✅ | isolated DV closure | active generated standalone report is the canonical `4-lane/128/256/native_sv` rerun slice and now carries `516/516` isolated catalog rows with `failed_cases=0` and `unimplemented_cases=0`; `DV_COV.md` records the remaining raw structural deltas as explicit justified non-claims / exclusions instead of a missing-evidence blocker | [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md), [`../tb/DV_COV.md`](../tb/DV_COV.md) |
| ⚠️ | bounded parameter extension evidence | historical 2-lane closure, bounded `N_SHD=64`, and bounded 4-lane points remain documented planning evidence, but they are not mixed into the active generated standalone dashboard unless rerun in the current signoff scope | [`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md) |
| ✅ | current continuous-frame / soak evidence | current-scope native-SV continuous-frame runs, overflow shape screens, exact-window repros, and the maintained mixed/DRR supplemental screens are linked directly from the active generated report; historical out-of-scope artifacts remain archived separately | [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md), [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md) |
| ✅ | integrated long-run matrix | `128/128` long-run cases green; merged-frame contract evidence exists in `tb_int/` | [`../tb_int/DV_REPORT.md`](../tb_int/DV_REPORT.md) |
| ✅ | bug ledgers | standalone and integrated bugs are both tracked in live ledgers | [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md), [`../tb_int/BUG_HISTORY.md`](../tb_int/BUG_HISTORY.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| ✅ | revisions | `opq_native_sv_2lane_signoff` and `opq_native_sv_4lane_signoff` standalone A10 refreshes completed |
| ℹ️ | device | `10AX115N2F45E1SG` (`online_sc/a10_board`) planned signoff target |
| ℹ️ | signoff constraint | `275 MHz` (`1.1x` the `250 MHz` board target) |
| ✅ | timing summary | `2-lane: +0.172 / +0.044 ns, Fmax 288.68 MHz; 4-lane: +0.077 / +0.039 ns, Fmax 280.98 MHz` |
| ✅ | fitted resources | `2-lane: 3,235 ALMs, 129 M20Ks, 0 MLAB bits; 4-lane: 10,245 ALMs, 147 M20Ks, 0 MLAB bits` |
| ℹ️ | detail report | [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md), [`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md) |

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| ✅ | Structure | root layout normalized to `rtl/`, `tb/`, `tb_int/`, `script/`, `doc/`, and `syn/` with canonical README entry points |
| ✅ | Packaging | `_hw.tcl` files moved under `script/`, updated to reference the canonical RTL trees, and now constrain only the honest packaged width / lane / `N_SHD` contract |
| ✅ | Harness | FEB output can be captured into TLM transactions for OPQ and can still directly pin-drive OPQ for later `tb_int/` work |
| ✅ | Native-SV no-restart signoff | default-build continuous-frame native-SV signoff is closed on the current baseline |
| ✅ | Native-SV overflow accounting | focused half-saturation random-ready overflow screen now closes with `unexplained=0` after the late-frame ticket-tail accounting fix |
| ✅ | Native-SV presenter restart safety | stale overlap replay can no longer self-scan the current head into a synthetic zero-length packet; the targeted flush-under-backpressure formal-like stress is green again on the 4-lane/128 preset |
| ✅ | Native-SV mixed-soak long chain | exact-window reproducer, long random soak, and the full stretched seconds-soak rerun are all green after the allocator repairs and mixed ERROR pool restoration |
| ✅ | Standalone synthesis | 2-lane stale compat collateral and the stale `d_clk` SDC target were repaired, and the stale 4-lane top-level compat wrapper plus fitter settings were refreshed; both 2-lane and 4-lane standalone A10 signoff points are now green |

## Evidence Index

- [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md) — active standalone DV dashboard
- [`../tb/DV_COV.md`](../tb/DV_COV.md) — standalone coverage summary
- [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md) — standalone bug ledger
- [`../tb_int/DV_REPORT.md`](../tb_int/DV_REPORT.md) — integrated long-run dashboard
- [`../tb_int/BUG_HISTORY.md`](../tb_int/BUG_HISTORY.md) — integrated bug ledger
- [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md) — standalone synthesis dashboard
- [`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md) — representative preset matrix and generator-backed full-space closure counts
- [`../tb/scripts/gen_config_signoff_matrix.py`](../tb/scripts/gen_config_signoff_matrix.py) — exhaustive configuration-space tracer
- [`../script/ordered_priority_queue_hw.tcl`](../script/ordered_priority_queue_hw.tcl) — monolithic OPQ packaging entry point

## Notes

- The standalone OPQ signoff claim comes from `tb/`; `tb_int/` adds integrated
  FEB-chain confidence and merged-frame evidence but does not replace the
  standalone DV closure requirement.
- The generated standalone `tb/` dashboard now follows a strict current-scope
  rule: only reruns matching the active `4-lane/128/256/native_sv` scope are
  credited into `DV_REPORT.md` and `DV_COV.md`. That current-scope matrix is
  now fully populated at `516/516` isolated rows with `8/8` maintained
  signoff runs discovered and no signoff-run failures. Historical 2-lane
  evidence is still valuable, but it stays historical until explicitly rerun
  in the active scope.
- The current standalone DV closure no longer depends on pretending the raw
  structural metrics hit the generic workflow targets. `DV_COV.md` now records
  the merged isolated totals (`stmt=74.41`, `branch=70.36`, `fsm_state=94.39`,
  `fsm_trans=54.47`, `toggle=33.37`) together with explicit coverage-hole
  disposition for parser asymmetry, allocator reset / fast-close arcs,
  presenter must-drop scan, RAM toggle churn, and wrapper bookkeeping.
- `legacy/` is now a compatibility symlink only. Canonical archived references
  should use `tb/legacy/`.
- The active standalone 4-lane Arria 10 refresh resolves the RAM/CAM concern
  for the current signoff point: the fitted design uses `147` M20K blocks and
  `0` MLAB bits, so the storage implementation is no longer being inferred as
  a large LUT/MLAB surrogate on this build.
- The refreshed 2-lane standalone harness now also closes at the intended
  `275 MHz` target after the stale local synthesis-compat copies were aligned
  to the live 4-lane compat set and the stale `d_clk` SDC target was corrected
  to the actual harness port `clk`.
- The formerly dominant presenter overlap-start cone is no longer the blocker
  on the current timing-clean standalone build; the refreshed 4-lane rerun now
  closes with `+0.077 ns` slow-corner setup slack at the tightened signoff
  target.
- Future parameterized timing closure is still a later phase: `N_LANE={8,16}`
  plus the staged wider ingress / DMA-packed egress axes need their own
  synthesis-safe pipeline options and matching DV closure rather than
  inheriting the current 2-lane or 4-lane baselines.

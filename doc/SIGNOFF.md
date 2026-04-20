# ⚠️ Signoff — packet_scheduler ordered_priority_queue

**DUT:** `ordered_priority_queue` &nbsp; **Date:** `2026-04-20` &nbsp;
**Release under check:** `26.3.29.0420` &nbsp; **Git base:** `local working tree`

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
| ⚠️ | overall_signoff | `partial` |
| ⚠️ | config_matrix | `2-lane and 4-lane measured; 8-lane and 16-lane still pending` |
| ✅ | standalone_syn | `2-lane and 4-lane A10 standalone Quartus signoff both close at 275 MHz on 10AX115N2F45E1SG` |
| ⚠️ | isolated_dv_closure | `37/37` promoted isolated cases evidenced; merged code coverage below target |
| ✅ | cross_bucket_signoff | `2` native-SV continuous-frame runs recorded, both green |
| ✅ | tb_int_longrun_matrix | `128/128` integrated matrix cases green |
| ✅ | resource_model | `3,235 ALMs / 129 M20Ks at 2-lane and 5,297 ALMs / 141 M20Ks at 4-lane on the active standalone fits` |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| ⚠️ | isolated DV closure | `37/37` promoted isolated native-SV cases evidenced; merged code coverage remains below `dv-workflow` targets | [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md) |
| ⚠️ | bounded parameter extension evidence | `OPQ_N_SHD=64` basic trio passed at 2-lane and `OPQ_N_LANE=4` smoke passed at `N_SHD=256`, but those points are not yet promoted into the generated DV dashboard | [`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md) |
| ✅ | bucket / continuous-frame signoff | `bucket_frame_native_sv` and `all_buckets_frame_native_sv` both pass on the current native-SV baseline | [`../tb/DV_COV.md`](../tb/DV_COV.md) |
| ✅ | long-run invariant screens | focused half-saturation random-ready overflow rerun is clean, the exact `183..190` reproducer is clean, the long mixed random soak is clean, and the full `512`-step mixed-bucket seconds soak now ends with `expected=63271 actual=63271 missing=0 ghost=0` | [`../tb/DV_REPORT_TODO.md`](../tb/DV_REPORT_TODO.md), [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md) |
| ✅ | integrated long-run matrix | `128/128` long-run cases green; merged-frame contract evidence exists in `tb_int/` | [`../tb_int/DV_REPORT.md`](../tb_int/DV_REPORT.md) |
| ✅ | bug ledgers | standalone and integrated bugs are both tracked in live ledgers | [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md), [`../tb_int/BUG_HISTORY.md`](../tb_int/BUG_HISTORY.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| ✅ | revisions | `opq_native_sv_2lane_signoff` and `opq_native_sv_4lane_signoff` standalone A10 refreshes completed |
| ℹ️ | device | `10AX115N2F45E1SG` (`online_sc/a10_board`) planned signoff target |
| ℹ️ | signoff constraint | `275 MHz` (`1.1x` the `250 MHz` board target) |
| ✅ | timing summary | `2-lane: +0.172 / +0.044 ns, Fmax 288.68 MHz; 4-lane: +0.008 / +0.043 ns, Fmax 275.63 MHz` |
| ✅ | fitted resources | `2-lane: 3,235 ALMs, 129 M20Ks, 0 MLAB bits; 4-lane: 5,297 ALMs, 141 M20Ks, 0 MLAB bits` |
| ℹ️ | detail report | [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md), [`CONFIG_SIGNOFF.md`](CONFIG_SIGNOFF.md) |

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| ✅ | Structure | root layout normalized to `rtl/`, `tb/`, `tb_int/`, `script/`, `doc/`, and `syn/` with canonical README entry points |
| ✅ | Packaging | `_hw.tcl` files moved under `script/`, updated to reference the canonical RTL trees, and now constrain only the honest packaged width / lane / `N_SHD` contract |
| ✅ | Harness | FEB output can be captured into TLM transactions for OPQ and can still directly pin-drive OPQ for later `tb_int/` work |
| ✅ | Native-SV no-restart signoff | default-build continuous-frame native-SV signoff is closed on the current baseline |
| ✅ | Native-SV overflow accounting | focused half-saturation random-ready overflow screen now closes with `unexplained=0` after the late-frame ticket-tail accounting fix |
| ✅ | Native-SV mixed-soak long chain | exact-window reproducer, long random soak, and the full stretched seconds-soak rerun are all green after the allocator repairs and mixed ERROR pool restoration |
| ✅ | Standalone synthesis | 2-lane stale compat collateral and the stale `d_clk` SDC target were repaired; both 2-lane and 4-lane standalone A10 signoff points are now green |

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
- `legacy/` is now a compatibility symlink only. Canonical archived references
  should use `tb/legacy/`.
- The active standalone 4-lane Arria 10 refresh resolves the RAM/CAM concern
  for the current signoff point: the fitted design uses `141` M20K blocks and
  `0` MLAB bits, so the storage implementation is no longer being inferred as
  a large LUT/MLAB surrogate on this build.
- The refreshed 2-lane standalone harness now also closes at the intended
  `275 MHz` target after the stale local synthesis-compat copies were aligned
  to the live 4-lane compat set and the stale `d_clk` SDC target was corrected
  to the actual harness port `clk`.
- The presenter overlap-start cone is no longer the top timing limiter after
  the registered launch split; the current worst fitted path is the
  page-allocator ticket-RAM to state-decode cone.
- Future parameterized timing closure is still a later phase: `N_LANE={8,16}`
  plus the staged wider ingress / DMA-packed egress axes need their own
  synthesis-safe pipeline options and matching DV closure rather than
  inheriting the current 2-lane or 4-lane baselines.

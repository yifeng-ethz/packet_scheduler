# ⚠️ Signoff — packet_scheduler ordered_priority_queue

**DUT:** `ordered_priority_queue` &nbsp; **Date:** `2026-04-17` &nbsp;
**Release under check:** `26.3.10.0414` &nbsp; **Git base:** `local working tree`

This page is the master signoff dashboard. Detailed standalone synthesis
evidence lives in [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md); detailed DV
evidence lives in [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / caveat &middot; ❌ failed / blocked &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ⚠️ | overall_signoff | `partial` |
| ❓ | standalone_syn | `pending standalone Quartus refresh in the cleaned tree` |
| ⚠️ | isolated_dv_closure | `31/31 isolated cases evidenced; code coverage below target` |
| ❌ | cross_bucket_signoff | `2` native-SV continuous-frame runs recorded, both failing |
| ✅ | tb_int_longrun_matrix | `128/128` integrated matrix cases green |
| ⚠️ | resource_model | `RAM/CAM standalone estimate under review` |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| ⚠️ | isolated DV closure | `31/31` planned isolated cases evidenced; merged code coverage remains below `dv-workflow` targets | [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md) |
| ❌ | bucket / continuous-frame signoff | `bucket_frame_native_sv` and `all_buckets_frame_native_sv` both fail on the open no-reset credit-restore bug | [`../tb/DV_COV.md`](../tb/DV_COV.md) |
| ✅ | integrated long-run matrix | `128/128` long-run cases green; merged-frame contract evidence exists in `tb_int/` | [`../tb_int/DV_REPORT.md`](../tb_int/DV_REPORT.md) |
| ✅ | bug ledgers | standalone and integrated bugs are both tracked in live ledgers | [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md), [`../tb_int/BUG_HISTORY.md`](../tb_int/BUG_HISTORY.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| ❓ | revision | `standalone cleaned-tree revision not yet rerun` |
| ℹ️ | device | `5AGXBA7D4F31C5` planned signoff target |
| ❓ | signoff constraint | `pending standalone refresh` |
| ❓ | timing summary | `no standalone WNS/TNS/Fmax claim yet` |
| ⚠️ | fitted resources | `existing RAM-block estimate is not trusted until the standalone refresh is rerun` |
| ℹ️ | detail report | [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md) |

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| ✅ | Structure | root layout normalized to `rtl/`, `tb/`, `tb_int/`, `script/`, `doc/`, and `syn/` with canonical README entry points |
| ✅ | Packaging | `_hw.tcl` files moved under `script/` and updated to reference the canonical RTL trees |
| ✅ | Harness | FEB output can be captured into TLM transactions for OPQ and can still directly pin-drive OPQ for later `tb_int/` work |
| ❌ | Native-SV long run | no-reset drain / lane-credit restore bug still blocks continuous-frame signoff closure |
| ❓ | Standalone synthesis | standalone Quartus signoff rerun and RAM/CAM resource audit still pending |

## Evidence Index

- [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md) — active standalone DV dashboard
- [`../tb/DV_COV.md`](../tb/DV_COV.md) — standalone coverage summary
- [`../tb/BUG_HISTORY.md`](../tb/BUG_HISTORY.md) — standalone bug ledger
- [`../tb_int/DV_REPORT.md`](../tb_int/DV_REPORT.md) — integrated long-run dashboard
- [`../tb_int/BUG_HISTORY.md`](../tb_int/BUG_HISTORY.md) — integrated bug ledger
- [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md) — standalone synthesis dashboard
- [`../script/ordered_priority_queue_hw.tcl`](../script/ordered_priority_queue_hw.tcl) — monolithic OPQ packaging entry point

## Notes

- The standalone OPQ signoff claim comes from `tb/`; `tb_int/` adds integrated
  FEB-chain confidence and merged-frame evidence but does not replace the
  standalone DV closure requirement.
- `legacy/` is now a compatibility symlink only. Canonical archived references
  should use `tb/legacy/`.
- The RAM/CAM fitter concern is explicitly left open here: the next standalone
  Quartus refresh must reconcile the RAM-block count with the CAM-backed
  storage implementation instead of reusing the older estimate.

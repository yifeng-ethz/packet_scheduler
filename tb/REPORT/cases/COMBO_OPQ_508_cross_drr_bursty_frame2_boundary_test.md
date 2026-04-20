# ✅ COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `high` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Deterministic bursty DRR boundary at the last green frame_count=2 envelope below the active retirement failure.
- **Primary checks:** Named green-side DRR boundary where the hot-lane/cold-lane asymmetry still closes with complete hit conservation and no ghost hits.
- **Contract anchor:** DV_CROSS bursty DRR green-side boundary evidence.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test` |
| ℹ️ | legacy_test_name | `opq_cross_drr_bursty_frame2_boundary_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `298` |
| ℹ️ | log.hit_actual | `298` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `43.33` |
| ℹ️ | log.cg_subh | `11.11` |
| ℹ️ | log.cg_bp | `20.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `61.81` |
| ℹ️ | log.cg_drr | `46.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `2` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `2` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 74.20 | 74.20 | 0.53 | 76.27 | 0.53 |
| branch | 67.51 | 67.51 | 0.97 | 71.88 | 0.97 |
| cond | 43.82 | 43.82 | 2.62 | 46.98 | 2.62 |
| expr | 60.20 | 60.20 | 0.86 | 68.10 | 0.86 |
| fsm_state | 86.36 | 86.36 | 0.00 | 90.91 | 0.00 |
| fsm_trans | 43.00 | 43.00 | 0.00 | 47.00 | 0.00 |
| toggle | 24.49 | 24.49 | 0.40 | 45.33 | 0.40 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

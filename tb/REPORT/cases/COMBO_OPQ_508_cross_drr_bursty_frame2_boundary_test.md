# ✅ COMBO_OPQ_508_cross_drr_bursty_frame2_boundary_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `high` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Deterministic bursty DRR frame_count=2 boundary companion to the separately tracked green frame_count=3 repro.
- **Primary checks:** Named bursty DRR boundary where the hot-lane/cold-lane asymmetry still closes with complete hit conservation and no ghost hits.
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
| ℹ️ | log.hit_expected | `484` |
| ℹ️ | log.hit_actual | `484` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `43.33` |
| ℹ️ | log.cg_subh | `11.11` |
| ℹ️ | log.cg_bp | `20.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `63.19` |
| ℹ️ | log.cg_drr | `54.33` |
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
| stmt | 77.72 | 77.72 | 3.36 | 82.20 | 3.36 |
| branch | 71.62 | 71.62 | 3.26 | 80.07 | 3.26 |
| cond | 45.08 | 45.08 | 2.84 | 56.99 | 2.84 |
| expr | 56.74 | 56.74 | 2.84 | 73.05 | 2.84 |
| fsm_state | 88.64 | 88.64 | 2.27 | 93.18 | 2.27 |
| fsm_trans | 45.00 | 45.00 | 2.00 | 50.00 | 2.00 |
| toggle | 23.37 | 23.37 | 0.66 | 45.54 | 0.66 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

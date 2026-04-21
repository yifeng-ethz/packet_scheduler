# ✅ COMBO_OPQ_504_cross_drr_zero_allowance_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Zero-allowance lane starvation followed by reload and resumed service.
- **Primary checks:** Directed defer/reload behavior and zero-allowance fairness recovery.
- **Contract anchor:** DV_CROSS zero-allowance closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_504_cross_drr_zero_allowance_test` |
| ℹ️ | legacy_test_name | `opq_cross_drr_zero_allowance_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_504_cross_drr_zero_allowance_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_504_cross_drr_zero_allowance_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_504_cross_drr_zero_allowance_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_504_cross_drr_zero_allowance_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `256` |
| ℹ️ | log.hit_actual | `256` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `47.5` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `4` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `4` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 70.91 | 70.91 | 0.10 | 74.42 | 0.10 |
| branch | 62.32 | 62.32 | 0.25 | 68.12 | 0.25 |
| cond | 32.38 | 32.38 | 0.00 | 40.41 | 0.00 |
| expr | 46.81 | 46.81 | 0.71 | 51.06 | 0.71 |
| fsm_state | 81.82 | 81.82 | 0.00 | 86.36 | 0.00 |
| fsm_trans | 39.00 | 39.00 | 0.00 | 43.00 | 0.00 |
| toggle | 17.24 | 17.24 | 0.73 | 29.84 | 0.73 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

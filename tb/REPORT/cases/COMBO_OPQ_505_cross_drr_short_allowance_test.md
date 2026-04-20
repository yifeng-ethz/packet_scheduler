# ✅ COMBO_OPQ_505_cross_drr_short_allowance_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Short-quantum reload with repeated service handoff.
- **Primary checks:** Directed DRR reload and service-handoff behavior under constrained allowance.
- **Contract anchor:** DV_CROSS short-allowance closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_505_cross_drr_short_allowance_test` |
| ℹ️ | legacy_test_name | `opq_cross_drr_short_allowance_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_505_cross_drr_short_allowance_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_505_cross_drr_short_allowance_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_505_cross_drr_short_allowance_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_505_cross_drr_short_allowance_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `720` |
| ℹ️ | log.hit_actual | `720` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `43.33` |
| ℹ️ | log.cg_subh | `11.11` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `56.94` |
| ℹ️ | log.cg_drr | `37.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `3` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `3` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 73.49 | 73.49 | 0.00 | 74.36 | 0.00 |
| branch | 65.92 | 65.92 | 0.13 | 67.90 | 0.13 |
| cond | 39.33 | 39.33 | 0.28 | 41.85 | 0.28 |
| expr | 58.16 | 58.16 | 0.00 | 59.18 | 0.00 |
| fsm_state | 86.36 | 86.36 | 0.00 | 86.36 | 0.00 |
| fsm_trans | 43.00 | 43.00 | 0.00 | 43.00 | 0.00 |
| toggle | 22.26 | 22.26 | 1.03 | 33.52 | 1.03 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

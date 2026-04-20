# ✅ COMBO_OPQ_507_cross_mixed_bucket_random_soak_test

**Bucket:** `CROSS` &nbsp; **Method:** `R` &nbsp; **Build:** `after` &nbsp; **Effort:** `high` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Random mixed-bucket soak that draws safe directed scenarios from BASIC, EDGE, PROF, ERROR, and CROSS.
- **Primary checks:** Multi-bucket chained hit integrity, bucket visitation, and no-restart drain stability under randomized sequencing.
- **Contract anchor:** DV_CROSS mixed-bucket random soak closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_507_cross_mixed_bucket_random_soak_test` |
| ℹ️ | legacy_test_name | `opq_cross_mixed_bucket_random_soak_test` |
| ℹ️ | observed_txn | `128` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_507_cross_mixed_bucket_random_soak_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `11348` |
| ℹ️ | log.hit_actual | `11342` |
| ℹ️ | log.hit_missing | `6` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `90.0` |
| ℹ️ | log.cg_subh | `80.56` |
| ℹ️ | log.cg_bp | `40.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
| ℹ️ | log.cg_drr | `42.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `551` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `551` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |
| ℹ️ | log.random_txn | `128` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 87.30 | 0.68 | 2.26 | 86.65 | 0.02 |
| branch | 76.61 | 0.60 | 3.22 | 75.73 | 0.03 |
| cond | 57.67 | 0.45 | 6.08 | 54.76 | 0.05 |
| expr | 92.73 | 0.72 | 12.73 | 81.82 | 0.10 |
| fsm_state | 88.57 | 0.69 | 0.00 | 88.57 | 0.00 |
| fsm_trans | 46.25 | 0.36 | 0.00 | 46.25 | 0.00 |
| toggle | 63.26 | 0.49 | 12.88 | 64.10 | 0.10 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

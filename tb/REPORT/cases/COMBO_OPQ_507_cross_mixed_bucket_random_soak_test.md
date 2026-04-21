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
| ℹ️ | log.hit_expected | `16133` |
| ℹ️ | log.hit_actual | `16133` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `90.0` |
| ℹ️ | log.cg_subh | `81.94` |
| ℹ️ | log.cg_bp | `45.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `610` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `610` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |
| ℹ️ | log.random_txn | `128` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 78.79 | 0.62 | 4.42 | 78.84 | 0.03 |
| branch | 76.45 | 0.60 | 8.57 | 76.81 | 0.07 |
| cond | 52.85 | 0.41 | 13.48 | 54.15 | 0.11 |
| expr | 68.79 | 0.54 | 19.15 | 70.21 | 0.15 |
| fsm_state | 90.91 | 0.71 | 4.55 | 90.91 | 0.04 |
| fsm_trans | 48.00 | 0.38 | 5.00 | 48.00 | 0.04 |
| toggle | 44.22 | 0.35 | 14.04 | 44.88 | 0.11 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

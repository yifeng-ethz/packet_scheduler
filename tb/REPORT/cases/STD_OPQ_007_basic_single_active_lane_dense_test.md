# ✅ STD_OPQ_007_basic_single_active_lane_dense_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Denser single-lane subheader packing on the healthy no-drop path.
- **Primary checks:** Single-lane hit integrity under deeper subheader occupancy without introducing legal drops.
- **Contract anchor:** DV_BASIC dense single-lane closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_007_basic_single_active_lane_dense_test` |
| ℹ️ | legacy_test_name | `opq_basic_single_active_lane_dense_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_007_basic_single_active_lane_dense_test_after_s1.log`](../../uvm/logs/STD_OPQ_007_basic_single_active_lane_dense_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_007_basic_single_active_lane_dense_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_007_basic_single_active_lane_dense_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `384` |
| ℹ️ | log.hit_actual | `384` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `57.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `6` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `6` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 73.74 | 73.74 | 0.76 | 76.78 | 0.76 |
| branch | 63.62 | 63.62 | 1.23 | 68.80 | 1.23 |
| cond | 32.86 | 32.86 | 1.70 | 39.09 | 1.70 |
| expr | 55.21 | 55.21 | 0.00 | 58.33 | 0.00 |
| fsm_state | 84.09 | 84.09 | 2.27 | 86.36 | 2.27 |
| fsm_trans | 41.00 | 41.00 | 2.00 | 44.00 | 2.00 |
| toggle | 20.37 | 20.37 | 0.88 | 33.73 | 0.88 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

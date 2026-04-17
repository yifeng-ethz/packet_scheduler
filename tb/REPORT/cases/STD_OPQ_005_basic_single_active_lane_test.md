# ✅ STD_OPQ_005_basic_single_active_lane_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Only one active hit-producing lane while the peer lane still emits legal empty-frame cadence.
- **Primary checks:** Hit integrity and credit restore with asymmetric legal FEB frame cadence.
- **Contract anchor:** DV_BASIC single-active-lane closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_005_basic_single_active_lane_test` |
| ℹ️ | legacy_test_name | `opq_basic_single_active_lane_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_005_basic_single_active_lane_test_after_s1.log`](../../uvm/logs/STD_OPQ_005_basic_single_active_lane_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_005_basic_single_active_lane_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_005_basic_single_active_lane_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `64` |
| ℹ️ | log.hit_actual | `64` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `58.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `49.0` |
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
| stmt | 81.38 | 81.38 | 0.00 | 82.72 | 0.00 |
| branch | 68.42 | 68.42 | 0.00 | 70.18 | 0.00 |
| cond | 44.44 | 44.44 | 0.00 | 45.50 | 0.00 |
| expr | 67.27 | 67.27 | 0.00 | 69.09 | 0.00 |
| fsm_state | 82.86 | 82.86 | 0.00 | 85.71 | 0.00 |
| fsm_trans | 41.25 | 41.25 | 0.00 | 43.75 | 0.00 |
| toggle | 24.90 | 24.90 | 1.92 | 47.43 | 1.92 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

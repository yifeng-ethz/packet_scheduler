# ✅ COMBO_OPQ_503_cross_drr_idle_lane_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** One hit-idle peer lane that still emits legal empty-frame cadence.
- **Primary checks:** DRR fairness with empty-frame cadence preserved on the idle lane.
- **Contract anchor:** DV_CROSS idle-lane cadence closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_503_cross_drr_idle_lane_test` |
| ℹ️ | legacy_test_name | `opq_cross_drr_idle_lane_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_503_cross_drr_idle_lane_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_503_cross_drr_idle_lane_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_503_cross_drr_idle_lane_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_503_cross_drr_idle_lane_test_s1.ucdb) |
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
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `51.0` |
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
| stmt | 70.43 | 70.43 | 0.11 | 74.25 | 0.11 |
| branch | 61.41 | 61.41 | 0.27 | 67.51 | 0.27 |
| cond | 33.15 | 33.15 | 0.00 | 41.57 | 0.00 |
| expr | 54.08 | 54.08 | 0.00 | 58.16 | 0.00 |
| fsm_state | 81.82 | 81.82 | 0.00 | 86.36 | 0.00 |
| fsm_trans | 39.00 | 39.00 | 0.00 | 43.00 | 0.00 |
| toggle | 17.41 | 17.41 | 0.85 | 31.83 | 0.85 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

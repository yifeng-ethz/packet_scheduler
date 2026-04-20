# ✅ COMBO_OPQ_506_cross_idle_lane_backpressure_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** One hit-idle lane crossed with periodic egress stalls on the active lane.
- **Primary checks:** Idle-lane cadence preservation and clean restart behavior under backpressure.
- **Contract anchor:** DV_CROSS idle-lane cadence x backpressure closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_506_cross_idle_lane_backpressure_test` |
| ℹ️ | legacy_test_name | `opq_cross_idle_lane_backpressure_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_506_cross_idle_lane_backpressure_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_506_cross_idle_lane_backpressure_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_506_cross_idle_lane_backpressure_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_506_cross_idle_lane_backpressure_test_s1.ucdb) |
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
| ℹ️ | log.cg_bp | `25.0` |
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
| stmt | 71.03 | 71.03 | 0.00 | 74.36 | 0.00 |
| branch | 62.33 | 62.33 | 0.00 | 67.90 | 0.00 |
| cond | 33.43 | 33.43 | 0.00 | 41.85 | 0.00 |
| expr | 54.08 | 54.08 | 0.00 | 59.18 | 0.00 |
| fsm_state | 84.09 | 84.09 | 0.00 | 86.36 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 43.00 | 0.00 |
| toggle | 18.74 | 18.74 | 0.06 | 33.58 | 0.06 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

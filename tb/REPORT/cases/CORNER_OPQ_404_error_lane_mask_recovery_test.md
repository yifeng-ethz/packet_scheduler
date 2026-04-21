# ✅ CORNER_OPQ_404_error_lane_mask_recovery_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Mask all active lanes, accumulate drops, then clear the mask and resume healthy traffic.
- **Primary checks:** Masked-header drop accounting plus verified clean recovery on the next legal FEB packets.
- **Contract anchor:** DV_ERROR control-action recovery closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_404_error_lane_mask_recovery_test` |
| ℹ️ | legacy_test_name | `opq_error_lane_mask_recovery_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_404_error_lane_mask_recovery_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_404_error_lane_mask_recovery_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_404_error_lane_mask_recovery_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_404_error_lane_mask_recovery_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `4` |
| ℹ️ | log.hit_actual | `4` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `58.33` |
| ℹ️ | log.cg_subh | `38.89` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
| ℹ️ | log.cg_drr | `40.33` |
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
| stmt | 73.78 | 73.78 | 28.40 | 73.93 | 28.40 |
| branch | 66.79 | 66.79 | 35.27 | 67.15 | 35.27 |
| cond | 37.82 | 37.82 | 30.05 | 37.82 | 30.05 |
| expr | 53.90 | 53.90 | 41.13 | 53.90 | 41.13 |
| fsm_state | 84.09 | 84.09 | 54.54 | 84.09 | 54.54 |
| fsm_trans | 41.00 | 41.00 | 36.00 | 41.00 | 36.00 |
| toggle | 22.06 | 22.06 | 18.21 | 22.48 | 18.21 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

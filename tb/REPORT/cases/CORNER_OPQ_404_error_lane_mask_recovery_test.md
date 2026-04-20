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
| stmt | 83.96 | 83.96 | 31.54 | 84.28 | 31.54 |
| branch | 71.93 | 71.93 | 36.84 | 72.51 | 36.84 |
| cond | 47.09 | 47.09 | 42.33 | 47.09 | 42.33 |
| expr | 74.55 | 74.55 | 60.00 | 74.55 | 60.00 |
| fsm_state | 85.71 | 85.71 | 51.42 | 85.71 | 51.42 |
| fsm_trans | 43.75 | 43.75 | 37.50 | 43.75 | 37.50 |
| toggle | 39.28 | 39.28 | 31.67 | 39.59 | 31.67 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

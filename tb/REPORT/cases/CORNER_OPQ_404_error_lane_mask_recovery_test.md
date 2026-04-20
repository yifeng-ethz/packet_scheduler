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
| stmt | 76.43 | 76.43 | 28.95 | 76.61 | 28.95 |
| branch | 67.85 | 67.85 | 35.56 | 68.26 | 35.56 |
| cond | 39.09 | 39.09 | 30.59 | 39.09 | 30.59 |
| expr | 64.58 | 64.58 | 45.83 | 64.58 | 45.83 |
| fsm_state | 84.09 | 84.09 | 54.54 | 84.09 | 54.54 |
| fsm_trans | 41.00 | 41.00 | 36.00 | 41.00 | 36.00 |
| toggle | 25.35 | 25.35 | 20.62 | 25.78 | 20.62 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

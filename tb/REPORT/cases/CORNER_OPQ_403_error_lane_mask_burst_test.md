# ✅ CORNER_OPQ_403_error_lane_mask_burst_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Burst masked-drop traffic across several packets.
- **Primary checks:** Burst drop accounting and no-drop recovery on the still-enabled lane.
- **Contract anchor:** DV_ERROR burst lane-mask closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_403_error_lane_mask_burst_test` |
| ℹ️ | legacy_test_name | `opq_error_lane_mask_burst_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_403_error_lane_mask_burst_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_403_error_lane_mask_burst_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_403_error_lane_mask_burst_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_403_error_lane_mask_burst_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `53.33` |
| ℹ️ | log.cg_subh | `11.11` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `81.43` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
| ℹ️ | log.cg_drr | `0.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `0.0` |
| ℹ️ | log.lane0_monitored_frames | `3` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `3` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 45.38 | 45.38 | 0.00 | 45.53 | 0.00 |
| branch | 31.52 | 31.52 | 0.00 | 31.88 | 0.00 |
| cond | 7.77 | 7.77 | 0.00 | 7.77 | 0.00 |
| expr | 12.77 | 12.77 | 0.00 | 12.77 | 0.00 |
| fsm_state | 29.55 | 29.55 | 0.00 | 29.55 | 0.00 |
| fsm_trans | 5.00 | 5.00 | 0.00 | 5.00 | 0.00 |
| toggle | 3.93 | 3.93 | 1.12 | 4.27 | 1.12 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

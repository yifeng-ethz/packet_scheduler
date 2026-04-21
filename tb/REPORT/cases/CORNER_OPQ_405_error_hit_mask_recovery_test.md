# ✅ CORNER_OPQ_405_error_hit_mask_recovery_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Mask the first or last hit of a subheader, then follow with legal recovery traffic on both active lanes.
- **Primary checks:** Hit-error masking consumes the declared beat, suppresses the lane write, and preserves accepted-hit ticket length plus clean recovery.
- **Contract anchor:** DV_ERROR hit-word recovery closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_405_error_hit_mask_recovery_test` |
| ℹ️ | legacy_test_name | `opq_error_hit_mask_recovery_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_405_error_hit_mask_recovery_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_405_error_hit_mask_recovery_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_405_error_hit_mask_recovery_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_405_error_hit_mask_recovery_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `6` |
| ℹ️ | log.hit_actual | `6` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `15.28` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `2` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `2` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 71.64 | 71.64 | 0.00 | 76.53 | 0.00 |
| branch | 63.43 | 63.43 | 0.00 | 67.57 | 0.00 |
| cond | 30.93 | 30.93 | 0.00 | 37.43 | 0.00 |
| expr | 48.94 | 48.94 | 0.00 | 55.17 | 0.00 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 41.00 | 0.00 |
| toggle | 14.69 | 14.69 | 0.00 | 25.28 | 0.00 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

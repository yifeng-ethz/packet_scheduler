# ✅ CORNER_OPQ_406_error_subheader_mask_recovery_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Inject a malformed subheader, then follow with a legal recovery frame on both active lanes.
- **Primary checks:** Ingress subheader-error masking without poisoning the following legal packet.
- **Contract anchor:** DV_ERROR malformed-subheader recovery closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_406_error_subheader_mask_recovery_test` |
| ℹ️ | legacy_test_name | `opq_error_subheader_mask_recovery_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_406_error_subheader_mask_recovery_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_406_error_subheader_mask_recovery_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_406_error_subheader_mask_recovery_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_406_error_subheader_mask_recovery_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `2` |
| ℹ️ | log.hit_actual | `2` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `58.33` |
| ℹ️ | log.cg_subh | `23.61` |
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
| stmt | 74.62 | 74.62 | 1.24 | 77.77 | 1.24 |
| branch | 65.94 | 65.94 | 2.96 | 70.53 | 2.96 |
| cond | 31.44 | 31.44 | 1.84 | 39.27 | 1.84 |
| expr | 55.21 | 55.21 | 0.86 | 56.03 | 0.86 |
| fsm_state | 88.64 | 88.64 | 4.55 | 88.64 | 4.55 |
| fsm_trans | 45.00 | 45.00 | 4.00 | 45.00 | 4.00 |
| toggle | 13.99 | 13.99 | 0.32 | 25.60 | 0.32 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

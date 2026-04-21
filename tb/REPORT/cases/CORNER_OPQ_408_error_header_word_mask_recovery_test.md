# ✅ CORNER_OPQ_408_error_header_word_mask_recovery_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Inject a header-word error, then follow with a legal recovery frame on both active lanes.
- **Primary checks:** Header-word suppression without corrupting the next legal frame timestamp base.
- **Contract anchor:** DV_ERROR header-word recovery closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_408_error_header_word_mask_recovery_test` |
| ℹ️ | legacy_test_name | `opq_error_header_word_mask_recovery_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_408_error_header_word_mask_recovery_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_408_error_header_word_mask_recovery_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_408_error_header_word_mask_recovery_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_408_error_header_word_mask_recovery_test_s1.ucdb) |
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
| stmt | 73.98 | 73.98 | 0.23 | 79.06 | 0.23 |
| branch | 65.26 | 65.26 | 0.49 | 73.24 | 0.49 |
| cond | 30.88 | 30.88 | 0.00 | 41.36 | 0.00 |
| expr | 55.21 | 55.21 | 0.00 | 56.03 | 0.00 |
| fsm_state | 88.64 | 88.64 | 0.00 | 93.18 | 0.00 |
| fsm_trans | 48.00 | 48.00 | 6.00 | 56.00 | 6.00 |
| toggle | 13.20 | 13.20 | 0.00 | 25.68 | 0.00 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

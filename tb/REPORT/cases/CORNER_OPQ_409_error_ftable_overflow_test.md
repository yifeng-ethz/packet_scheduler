# ✅ CORNER_OPQ_409_error_ftable_overflow_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Reduced-depth overwrite pressure under hard egress stall on the native-SV presenter path.
- **Primary checks:** Frame-table drop counters increment, overwritten residents are suppressed, and no malformed accepted egress escapes under overwrite pressure.
- **Contract anchor:** DV_ERROR reduced-depth overwrite / flush-atomicity closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_409_error_ftable_overflow_test` |
| ℹ️ | legacy_test_name | `opq_error_ftable_overflow_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_409_error_ftable_overflow_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_409_error_ftable_overflow_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_409_error_ftable_overflow_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_409_error_ftable_overflow_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `512` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `63.33` |
| ℹ️ | log.cg_subh | `61.11` |
| ℹ️ | log.cg_bp | `25.0` |
| ℹ️ | log.cg_csr | `81.43` |
| ℹ️ | log.cg_credit | `60.0` |
| ℹ️ | log.cg_drop | `54.17` |
| ℹ️ | log.cg_drr | `0.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `32` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `32` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 77.08 | 77.08 | 3.57 | 82.87 | 3.57 |
| branch | 64.85 | 64.85 | 1.91 | 76.57 | 1.91 |
| cond | 35.98 | 35.98 | 3.40 | 46.74 | 3.40 |
| expr | 58.33 | 58.33 | 4.17 | 69.79 | 4.17 |
| fsm_state | 86.36 | 86.36 | 2.27 | 95.45 | 2.27 |
| fsm_trans | 43.00 | 43.00 | 2.00 | 58.00 | 2.00 |
| toggle | 30.11 | 30.11 | 7.14 | 34.10 | 7.14 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

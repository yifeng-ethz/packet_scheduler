# ✅ CORNER_OPQ_407_error_ftable_overflow_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Reduced-depth overwrite pressure under hard egress stall on the native-SV presenter path.
- **Primary checks:** Frame-table drop counters increment, overwritten residents are suppressed, and no malformed accepted egress escapes under overwrite pressure.
- **Contract anchor:** DV_ERROR reduced-depth overwrite / flush-atomicity closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_407_error_ftable_overflow_test` |
| ℹ️ | legacy_test_name | `opq_error_ftable_overflow_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_407_error_ftable_overflow_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_407_error_ftable_overflow_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_407_error_ftable_overflow_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_407_error_ftable_overflow_test_s1.ucdb) |
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
| ℹ️ | log.cg_drop | `57.64` |
| ℹ️ | log.cg_drr | `0.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `0.0` |
| ℹ️ | log.lane0_monitored_frames | `32` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `32` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 75.74 | 75.74 | 0.00 | 85.44 | 0.00 |
| branch | 61.97 | 61.97 | 0.00 | 76.11 | 0.00 |
| cond | 37.82 | 37.82 | 3.62 | 53.88 | 3.62 |
| expr | 47.69 | 47.69 | 0.00 | 69.44 | 0.00 |
| fsm_state | 80.00 | 80.00 | 0.00 | 91.43 | 0.00 |
| fsm_trans | 39.51 | 39.51 | 0.00 | 48.75 | 0.00 |
| toggle | 37.87 | 37.87 | 4.91 | 46.04 | 4.91 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

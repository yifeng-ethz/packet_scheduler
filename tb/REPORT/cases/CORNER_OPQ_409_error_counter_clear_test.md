# ✅ CORNER_OPQ_409_error_counter_clear_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Runtime counter clear after drop-producing traffic.
- **Primary checks:** Visible CSR counter reset semantics and post-clear clean state.
- **Contract anchor:** DV_ERROR counter-clear closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_409_error_counter_clear_test` |
| ℹ️ | legacy_test_name | `opq_error_counter_clear_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_409_error_counter_clear_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_409_error_counter_clear_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_409_error_counter_clear_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_409_error_counter_clear_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `41.67` |
| ℹ️ | log.cg_subh | `15.28` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `81.43` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `0.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `0.0` |
| ℹ️ | log.lane0_monitored_frames | `1` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `1` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 47.84 | 47.84 | 0.05 | 79.11 | 0.05 |
| branch | 33.11 | 33.11 | 0.13 | 73.37 | 0.13 |
| cond | 8.50 | 8.50 | 0.00 | 41.36 | 0.00 |
| expr | 18.75 | 18.75 | 0.00 | 56.03 | 0.00 |
| fsm_state | 29.55 | 29.55 | 0.00 | 93.18 | 0.00 |
| fsm_trans | 5.00 | 5.00 | 0.00 | 56.00 | 0.00 |
| toggle | 4.15 | 4.15 | 0.01 | 25.69 | 0.01 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

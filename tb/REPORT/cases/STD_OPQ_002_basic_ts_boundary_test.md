# ✅ STD_OPQ_002_basic_ts_boundary_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Sparse timestamp-boundary traffic across low and high subheader values.
- **Primary checks:** Full timestamp reconstruction and zero ghost/missing hits.
- **Contract anchor:** DV_BASIC full-ts boundary closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_002_basic_ts_boundary_test` |
| ℹ️ | legacy_test_name | `opq_basic_ts_boundary_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_002_basic_ts_boundary_test_after_s1.log`](../../uvm/logs/STD_OPQ_002_basic_ts_boundary_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_002_basic_ts_boundary_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_002_basic_ts_boundary_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 82.99 | 82.99 | 0.54 | 84.07 | 0.54 |
| branch | 70.18 | 70.18 | 0.58 | 71.93 | 0.58 |
| cond | 42.86 | 42.86 | 0.53 | 46.03 | 0.53 |
| expr | 70.91 | 70.91 | 3.64 | 70.91 | 3.64 |
| fsm_state | 85.71 | 85.71 | 0.00 | 85.71 | 0.00 |
| fsm_trans | 43.75 | 43.75 | 0.00 | 43.75 | 0.00 |
| toggle | 26.12 | 26.12 | 2.54 | 41.71 | 2.54 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

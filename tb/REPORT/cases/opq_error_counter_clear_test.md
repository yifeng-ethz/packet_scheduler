# ✅ opq_error_counter_clear_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Runtime counter clear after drop-producing traffic.
- **Primary checks:** Visible CSR counter reset semantics and post-clear clean state.
- **Contract anchor:** DV_ERROR counter-clear closure.

## Execution Evidence

<!-- fields (chief-architect legend)
  status                       = this case's overall health (legend: ✅ pass / ⚠️ partial / ❌ fail / ❓ pending)
  method                       = D = directed (1 txn); R = randomised (N txns)
  observed_txn                 = number of scoreboard-observed transactions driven by this case
  standalone_coverage          = code coverage measured from this case's own isolated UCDB
  isolated_cov_per_txn         = standalone_coverage averaged over observed_txn (useful for random cases)
  bucket_gain_by_case          = incremental code coverage this case added to the bucket's ordered merge
  bucket_merged_total_after    = the bucket's merged code coverage after this case was merged
  bucket_gain_per_txn          = bucket_gain_by_case averaged over observed_txn
-->

| status | field | value |
|:---:|---|---|
| ✅ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/opq_error_counter_clear_test_after_s1.log`](../../uvm/logs/opq_error_counter_clear_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/opq_error_counter_clear_test_s1.ucdb`](../../uvm/cov_after/opq_error_counter_clear_test_s1.ucdb) |
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

<!-- code coverage vectors: stmt/branch/cond/expr/fsm_state/fsm_trans/toggle (percent) -->

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 53.07 | 53.07 | 0.10 | 86.54 | 0.10 |
| branch | 36.26 | 36.26 | 0.20 | 76.61 | 0.20 |
| cond | 4.76 | 4.76 | 0.00 | 50.26 | 0.00 |
| expr | 14.55 | 14.55 | 0.00 | 74.55 | 0.00 |
| fsm_state | 34.29 | 34.29 | 0.00 | 91.43 | 0.00 |
| fsm_trans | 6.25 | 6.25 | 0.00 | 48.75 | 0.00 |
| toggle | 6.58 | 6.58 | 0.02 | 41.13 | 0.02 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

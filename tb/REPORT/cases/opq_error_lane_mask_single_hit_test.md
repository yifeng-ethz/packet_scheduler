# ✅ opq_error_lane_mask_single_hit_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Minimal masked-drop packet on the active native-SV path.
- **Primary checks:** Single-hit drop accounting and CSR counter closure.
- **Contract anchor:** DV_ERROR single-hit lane-mask closure.

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
| ℹ️ | log | [`uvm/logs/opq_error_lane_mask_single_hit_test_after_s1.log`](../../uvm/logs/opq_error_lane_mask_single_hit_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/opq_error_lane_mask_single_hit_test_s1.ucdb`](../../uvm/cov_after/opq_error_lane_mask_single_hit_test_s1.ucdb) |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `41.67` |
| ℹ️ | log.cg_subh | `15.28` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `81.43` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
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
| stmt | 52.42 | 52.42 | 0.00 | 52.74 | 0.00 |
| branch | 35.09 | 35.09 | 0.00 | 35.67 | 0.00 |
| cond | 4.76 | 4.76 | 0.00 | 4.76 | 0.00 |
| expr | 14.55 | 14.55 | 0.00 | 14.55 | 0.00 |
| fsm_state | 34.29 | 34.29 | 0.00 | 34.29 | 0.00 |
| fsm_trans | 6.25 | 6.25 | 0.00 | 6.25 | 0.00 |
| toggle | 5.95 | 5.95 | 0.02 | 6.53 | 0.02 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

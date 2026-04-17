# ✅ opq_cross_drr_zero_allowance_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Zero-allowance lane starvation followed by reload and resumed service.
- **Primary checks:** Directed defer/reload behavior and zero-allowance fairness recovery.
- **Contract anchor:** DV_CROSS zero-allowance closure.

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
| ℹ️ | log | [`uvm/logs/opq_cross_drr_zero_allowance_test_after_s1.log`](../../uvm/logs/opq_cross_drr_zero_allowance_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/opq_cross_drr_zero_allowance_test_s1.ucdb`](../../uvm/cov_after/opq_cross_drr_zero_allowance_test_s1.ucdb) |
| ℹ️ | log.hit_expected | `256` |
| ℹ️ | log.hit_actual | `256` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `47.5` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `4` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `4` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

<!-- code coverage vectors: stmt/branch/cond/expr/fsm_state/fsm_trans/toggle (percent) -->

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 82.13 | 82.13 | 0.11 | 86.01 | 0.11 |
| branch | 69.59 | 69.59 | 0.19 | 74.85 | 0.19 |
| cond | 45.50 | 45.50 | 0.00 | 51.85 | 0.00 |
| expr | 70.91 | 70.91 | 3.64 | 70.91 | 3.64 |
| fsm_state | 82.86 | 82.86 | 0.00 | 88.57 | 0.00 |
| fsm_trans | 41.25 | 41.25 | 0.00 | 46.25 | 0.00 |
| toggle | 27.99 | 27.99 | 1.09 | 50.12 | 1.09 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

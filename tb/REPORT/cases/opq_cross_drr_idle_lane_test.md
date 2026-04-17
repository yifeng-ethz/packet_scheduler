# ✅ opq_cross_drr_idle_lane_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** One hit-idle peer lane that still emits legal empty-frame cadence.
- **Primary checks:** DRR fairness with empty-frame cadence preserved on the idle lane.
- **Contract anchor:** DV_CROSS idle-lane cadence closure.

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
| ℹ️ | log | [`uvm/logs/opq_cross_drr_idle_lane_test_after_s1.log`](../../uvm/logs/opq_cross_drr_idle_lane_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/opq_cross_drr_idle_lane_test_s1.ucdb`](../../uvm/cov_after/opq_cross_drr_idle_lane_test_s1.ucdb) |
| ℹ️ | log.hit_expected | `256` |
| ℹ️ | log.hit_actual | `256` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `51.0` |
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
| stmt | 81.59 | 81.59 | 0.11 | 85.90 | 0.11 |
| branch | 68.81 | 68.81 | 0.20 | 74.66 | 0.20 |
| cond | 44.97 | 44.97 | 0.00 | 51.85 | 0.00 |
| expr | 67.27 | 67.27 | 0.00 | 67.27 | 0.00 |
| fsm_state | 82.86 | 82.86 | 0.00 | 88.57 | 0.00 |
| fsm_trans | 41.25 | 41.25 | 0.00 | 46.25 | 0.00 |
| toggle | 27.68 | 27.68 | 1.19 | 49.03 | 1.19 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

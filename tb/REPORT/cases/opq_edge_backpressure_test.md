# ✅ opq_edge_backpressure_test

**Bucket:** `EDGE` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Periodic egress stalls on the default native-SV datapath.
- **Primary checks:** Presenter hold/restart behavior and hit integrity under legal backpressure.
- **Contract anchor:** DV_EDGE periodic-stall closure.

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
| ℹ️ | log | [`uvm/logs/opq_edge_backpressure_test_after_s1.log`](../../uvm/logs/opq_edge_backpressure_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/opq_edge_backpressure_test_s1.ucdb`](../../uvm/cov_after/opq_edge_backpressure_test_s1.ucdb) |
| ℹ️ | log.hit_expected | `4` |
| ℹ️ | log.hit_actual | `4` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `63.33` |
| ℹ️ | log.cg_subh | `59.72` |
| ℹ️ | log.cg_bp | `25.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `60.0` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `3` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `3` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

<!-- code coverage vectors: stmt/branch/cond/expr/fsm_state/fsm_trans/toggle (percent) -->

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 83.53 | 83.53 | 83.53 | 83.53 | 83.53 |
| branch | 71.35 | 71.35 | 71.35 | 71.35 | 71.35 |
| cond | 45.50 | 45.50 | 45.50 | 45.50 | 45.50 |
| expr | 67.27 | 67.27 | 67.27 | 67.27 | 67.27 |
| fsm_state | 85.71 | 85.71 | 85.71 | 85.71 | 85.71 |
| fsm_trans | 43.75 | 43.75 | 43.75 | 43.75 | 43.75 |
| toggle | 39.19 | 39.19 | 39.19 | 39.19 | 39.19 |

---
_Back to [bucket](../buckets/EDGE.md) &middot; [dashboard](../../DV_REPORT.md)_

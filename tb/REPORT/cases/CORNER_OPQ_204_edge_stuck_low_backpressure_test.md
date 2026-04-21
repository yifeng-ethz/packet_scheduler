# ✅ CORNER_OPQ_204_edge_stuck_low_backpressure_test

**Bucket:** `EDGE` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Longer low-ready windows short of the forced-overwrite probe.
- **Primary checks:** Hold-under-backpressure and clean restart behavior without malformed egress.
- **Contract anchor:** DV_EDGE stuck-low ready closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_204_edge_stuck_low_backpressure_test` |
| ℹ️ | legacy_test_name | `opq_edge_stuck_low_backpressure_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_204_edge_stuck_low_backpressure_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_204_edge_stuck_low_backpressure_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_204_edge_stuck_low_backpressure_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_204_edge_stuck_low_backpressure_test_s1.ucdb) |
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
| ℹ️ | log.cg_frame | `53.33` |
| ℹ️ | log.cg_subh | `38.89` |
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

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 71.64 | 71.64 | 0.00 | 71.64 | 0.00 |
| branch | 63.89 | 63.89 | 0.12 | 63.89 | 0.12 |
| cond | 31.87 | 31.87 | 0.26 | 31.87 | 0.26 |
| expr | 49.65 | 49.65 | 2.84 | 49.65 | 2.84 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 41.00 | 0.00 |
| toggle | 21.81 | 21.81 | 0.03 | 21.81 | 0.03 |

---
_Back to [bucket](../buckets/EDGE.md) &middot; [dashboard](../../DV_REPORT.md)_

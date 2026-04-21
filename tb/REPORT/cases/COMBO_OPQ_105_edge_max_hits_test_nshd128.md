# ✅ COMBO_OPQ_105_edge_max_hits_test_nshd128

**Bucket:** `PARAM` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Maximum-hit packet shape at N_SHD=128.
- **Primary checks:** Max-hit frame shape and hit preservation at the smallest claimed build point.
- **Contract anchor:** DV_PARAM max-hit sweep, N_SHD=128.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_105_edge_max_hits_test_nshd128` |
| ℹ️ | legacy_test_name | `opq_edge_max_hits_test_nshd128` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_105_edge_max_hits_test_nshd128_after_s1.log`](../../uvm/logs/COMBO_OPQ_105_edge_max_hits_test_nshd128_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_105_edge_max_hits_test_nshd128_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_105_edge_max_hits_test_nshd128_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `128` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `256` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `96` |
| ℹ️ | log.hit_actual | `96` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `15.28` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `2` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `2` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 71.21 | 71.21 | 0.04 | 71.98 | 0.04 |
| branch | 63.04 | 63.04 | 0.24 | 64.49 | 0.24 |
| cond | 31.09 | 31.09 | 1.56 | 33.94 | 1.56 |
| expr | 47.52 | 47.52 | 0.00 | 50.35 | 0.00 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 41.00 | 0.00 |
| toggle | 14.71 | 14.71 | 2.48 | 25.22 | 2.48 |

---
_Back to [bucket](../buckets/PARAM.md) &middot; [dashboard](../../DV_REPORT.md)_

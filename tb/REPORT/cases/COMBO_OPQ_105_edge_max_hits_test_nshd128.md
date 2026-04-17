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
| stmt | 82.45 | 82.45 | 0.00 | 84.28 | 0.00 |
| branch | 70.18 | 70.18 | 0.00 | 72.12 | 0.00 |
| cond | 43.92 | 43.92 | 1.06 | 48.15 | 1.06 |
| expr | 67.27 | 67.27 | 0.00 | 70.91 | 0.00 |
| fsm_state | 85.71 | 85.71 | 0.00 | 85.71 | 0.00 |
| fsm_trans | 43.75 | 43.75 | 0.00 | 43.75 | 0.00 |
| toggle | 25.89 | 25.89 | 3.57 | 46.76 | 3.57 |

---
_Back to [bucket](../buckets/PARAM.md) &middot; [dashboard](../../DV_REPORT.md)_

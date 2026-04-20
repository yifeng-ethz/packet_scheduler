# ✅ COMBO_OPQ_502_cross_drr_allowance_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Runtime DRR allowance programming with asymmetric lane service.
- **Primary checks:** CSR programming, defer counters, and directed service fairness.
- **Contract anchor:** DV_CROSS DRR allowance closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_502_cross_drr_allowance_test` |
| ℹ️ | legacy_test_name | `opq_cross_drr_allowance_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_502_cross_drr_allowance_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_502_cross_drr_allowance_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_502_cross_drr_allowance_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_502_cross_drr_allowance_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `896` |
| ℹ️ | log.hit_actual | `896` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `43.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `95.24` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `61.81` |
| ℹ️ | log.cg_drr | `40.67` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `4` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `4` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 73.49 | 73.49 | 2.78 | 74.14 | 2.78 |
| branch | 65.78 | 65.78 | 4.11 | 67.24 | 4.11 |
| cond | 39.04 | 39.04 | 9.55 | 41.57 | 9.55 |
| expr | 58.16 | 58.16 | 5.10 | 58.16 | 5.10 |
| fsm_state | 86.36 | 86.36 | 2.27 | 86.36 | 2.27 |
| fsm_trans | 43.00 | 43.00 | 2.00 | 43.00 | 2.00 |
| toggle | 21.85 | 21.85 | 5.82 | 30.98 | 5.82 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

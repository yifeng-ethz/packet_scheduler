# ✅ COMBO_OPQ_104_basic_ts_boundary_test_nshd512

**Bucket:** `PARAM` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Timestamp-boundary sparse packets at N_SHD=512.
- **Primary checks:** Boundary timestamp reconstruction with derived deep ticket FIFO.
- **Contract anchor:** DV_PARAM timestamp sweep, N_SHD=512.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_104_basic_ts_boundary_test_nshd512` |
| ℹ️ | legacy_test_name | `opq_basic_ts_boundary_test_nshd512` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_104_basic_ts_boundary_test_nshd512_after_s1.log`](../../uvm/logs/COMBO_OPQ_104_basic_ts_boundary_test_nshd512_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_104_basic_ts_boundary_test_nshd512_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_104_basic_ts_boundary_test_nshd512_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `512` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `1024` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `6` |
| ℹ️ | log.hit_actual | `6` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `73.33` |
| ℹ️ | log.cg_subh | `50.0` |
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
| stmt | 71.45 | 71.45 | 0.00 | 71.94 | 0.00 |
| branch | 62.80 | 62.80 | 0.00 | 64.25 | 0.00 |
| cond | 29.79 | 29.79 | 0.00 | 32.38 | 0.00 |
| expr | 50.35 | 50.35 | 0.00 | 50.35 | 0.00 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 41.00 | 0.00 |
| toggle | 15.54 | 15.54 | 0.01 | 22.74 | 0.01 |

---
_Back to [bucket](../buckets/PARAM.md) &middot; [dashboard](../../DV_REPORT.md)_

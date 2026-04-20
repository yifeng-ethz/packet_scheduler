# ✅ COMBO_OPQ_102_basic_smoke_test_nshd512

**Bucket:** `PARAM` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Default healthy-path bring-up at non-default build point N_SHD=512.
- **Primary checks:** Hit integrity and restored credits with derived deep ticket FIFO.
- **Contract anchor:** DV_PARAM compile/elaboration sweep, N_SHD=512.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_102_basic_smoke_test_nshd512` |
| ℹ️ | legacy_test_name | `opq_basic_smoke_test_nshd512` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_102_basic_smoke_test_nshd512_after_s1.log`](../../uvm/logs/COMBO_OPQ_102_basic_smoke_test_nshd512_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_102_basic_smoke_test_nshd512_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_102_basic_smoke_test_nshd512_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `512` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `1024` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `4` |
| ℹ️ | log.hit_actual | `4` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `53.33` |
| ℹ️ | log.cg_subh | `38.89` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
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
| stmt | 83.75 | 83.75 | 0.22 | 83.75 | 0.22 |
| branch | 71.54 | 71.54 | 0.19 | 71.54 | 0.19 |
| cond | 46.56 | 46.56 | 1.06 | 46.56 | 1.06 |
| expr | 67.27 | 67.27 | 0.00 | 67.27 | 0.00 |
| fsm_state | 85.71 | 85.71 | 0.00 | 85.71 | 0.00 |
| fsm_trans | 43.75 | 43.75 | 0.00 | 43.75 | 0.00 |
| toggle | 40.22 | 40.22 | 2.89 | 40.66 | 2.89 |

---
_Back to [bucket](../buckets/PARAM.md) &middot; [dashboard](../../DV_REPORT.md)_

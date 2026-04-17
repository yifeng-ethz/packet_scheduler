# ✅ STD_OPQ_001_basic_smoke_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Healthy long-frame bring-up on the default 2-lane native-SV path.
- **Primary checks:** Hit integrity, zero drops, and restored credits on both lanes.
- **Contract anchor:** DV_BASIC healthy-path closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_001_basic_smoke_test` |
| ℹ️ | legacy_test_name | `opq_basic_smoke_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_001_basic_smoke_test_after_s1.log`](../../uvm/logs/STD_OPQ_001_basic_smoke_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_001_basic_smoke_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_001_basic_smoke_test_s1.ucdb) |
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
| ℹ️ | log.cg_frame | `63.33` |
| ℹ️ | log.cg_subh | `59.72` |
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
| stmt | 83.53 | 83.53 | 83.53 | 83.53 | 83.53 |
| branch | 71.35 | 71.35 | 71.35 | 71.35 | 71.35 |
| cond | 45.50 | 45.50 | 45.50 | 45.50 | 45.50 |
| expr | 67.27 | 67.27 | 67.27 | 67.27 | 67.27 |
| fsm_state | 85.71 | 85.71 | 85.71 | 85.71 | 85.71 |
| fsm_trans | 43.75 | 43.75 | 43.75 | 43.75 | 43.75 |
| toggle | 39.17 | 39.17 | 39.17 | 39.17 | 39.17 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

# ✅ STD_OPQ_006_basic_single_active_lane_lane1_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Only lane 1 produces hits while lane 0 remains on legal empty-frame cadence.
- **Primary checks:** Hit integrity and credit restore when the non-default active lane owns all live traffic.
- **Contract anchor:** DV_BASIC single-active-lane lane-1 closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_006_basic_single_active_lane_lane1_test` |
| ℹ️ | legacy_test_name | `opq_basic_single_active_lane_lane1_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_006_basic_single_active_lane_lane1_test_after_s1.log`](../../uvm/logs/STD_OPQ_006_basic_single_active_lane_lane1_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_006_basic_single_active_lane_lane1_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_006_basic_single_active_lane_lane1_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `108` |
| ℹ️ | log.hit_actual | `108` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `48.33` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `49.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `6` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `6` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 72.92 | 72.92 | 0.06 | 76.02 | 0.06 |
| branch | 62.26 | 62.26 | 0.13 | 67.57 | 0.13 |
| cond | 31.16 | 31.16 | 0.00 | 37.39 | 0.00 |
| expr | 55.21 | 55.21 | 0.00 | 58.33 | 0.00 |
| fsm_state | 81.82 | 81.82 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 39.00 | 39.00 | 0.00 | 42.00 | 0.00 |
| toggle | 19.49 | 19.49 | 1.66 | 32.85 | 1.66 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

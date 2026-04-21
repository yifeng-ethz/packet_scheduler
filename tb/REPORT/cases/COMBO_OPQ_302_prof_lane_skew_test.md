# ✅ COMBO_OPQ_302_prof_lane_skew_test

**Bucket:** `PROF` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Deterministic two-lane skew with repeated long frames.
- **Primary checks:** No missing or ghost hits under sustained lane skew.
- **Contract anchor:** DV_PROF lane-skew closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_302_prof_lane_skew_test` |
| ℹ️ | legacy_test_name | `opq_prof_lane_skew_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_302_prof_lane_skew_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_302_prof_lane_skew_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_302_prof_lane_skew_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_302_prof_lane_skew_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `32` |
| ℹ️ | log.hit_actual | `32` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `50.0` |
| ℹ️ | log.cg_subh | `23.61` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `73.33` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `8` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `8` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 72.47 | 72.47 | 0.93 | 72.57 | 0.93 |
| branch | 64.98 | 64.98 | 1.45 | 65.22 | 1.45 |
| cond | 33.94 | 33.94 | 3.36 | 34.97 | 3.36 |
| expr | 48.94 | 48.94 | 2.13 | 48.94 | 2.13 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 42.00 | 42.00 | 1.00 | 42.00 | 1.00 |
| toggle | 19.25 | 19.25 | 1.87 | 23.00 | 1.87 |

---
_Back to [bucket](../buckets/PROF.md) &middot; [dashboard](../../DV_REPORT.md)_

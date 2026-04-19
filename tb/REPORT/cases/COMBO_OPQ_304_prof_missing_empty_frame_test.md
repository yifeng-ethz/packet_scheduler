# ✅ COMBO_OPQ_304_prof_missing_empty_frame_test

**Bucket:** `PROF` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Uneven per-lane frame-count stress on the active 2-lane harness contract.
- **Primary checks:** Sparse-frame residency, credit stability, and hit integrity without claiming 4-lane closure.
- **Contract anchor:** DV_PROF sparse-frame residency closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_304_prof_missing_empty_frame_test` |
| ℹ️ | legacy_test_name | `opq_prof_missing_empty_frame_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_304_prof_missing_empty_frame_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_304_prof_missing_empty_frame_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_304_prof_missing_empty_frame_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_304_prof_missing_empty_frame_test_s1.ucdb) |
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
| ℹ️ | log.cg_frame | `60.0` |
| ℹ️ | log.cg_subh | `59.72` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `60.0` |
| ℹ️ | log.cg_drop | `63.19` |
| ℹ️ | log.cg_drr | `49.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `2` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `6` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 81.49 | 81.49 | 0.00 | 84.07 | 0.00 |
| branch | 67.64 | 67.64 | 0.00 | 71.73 | 0.00 |
| cond | 43.92 | 43.92 | 0.00 | 46.56 | 0.00 |
| expr | 70.91 | 70.91 | 0.00 | 70.91 | 0.00 |
| fsm_state | 82.86 | 82.86 | 0.00 | 85.71 | 0.00 |
| fsm_trans | 41.25 | 41.25 | 0.00 | 43.75 | 0.00 |
| toggle | 27.31 | 27.31 | 0.17 | 44.68 | 0.17 |

---
_Back to [bucket](../buckets/PROF.md) &middot; [dashboard](../../DV_REPORT.md)_

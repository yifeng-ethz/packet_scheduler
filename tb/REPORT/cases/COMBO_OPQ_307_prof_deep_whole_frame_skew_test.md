# ❌ COMBO_OPQ_307_prof_deep_whole_frame_skew_test

**Bucket:** `PROF` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `fail`

## Intent

- **Scenario:** Deeper whole-frame skew residency with reduced subheader density.
- **Primary checks:** Longer packet-level cadence skew while preserving hit integrity and legal frame ordering.
- **Contract anchor:** DV_PROF deep whole-frame skew closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ❌ | report_case_id | `COMBO_OPQ_307_prof_deep_whole_frame_skew_test` |
| ℹ️ | legacy_test_name | `opq_prof_deep_whole_frame_skew_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_307_prof_deep_whole_frame_skew_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_307_prof_deep_whole_frame_skew_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_307_prof_deep_whole_frame_skew_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_307_prof_deep_whole_frame_skew_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `38` |
| ℹ️ | log.hit_actual | `38` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `55.0` |
| ℹ️ | log.cg_subh | `37.5` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `70.0` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `28` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `28` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | n/a | n/a | n/a | n/a | n/a |
| branch | n/a | n/a | n/a | n/a | n/a |
| cond | n/a | n/a | n/a | n/a | n/a |
| expr | n/a | n/a | n/a | n/a | n/a |
| fsm_state | n/a | n/a | n/a | n/a | n/a |
| fsm_trans | n/a | n/a | n/a | n/a | n/a |
| toggle | n/a | n/a | n/a | n/a | n/a |

---
_Back to [bucket](../buckets/PROF.md) &middot; [dashboard](../../DV_REPORT.md)_

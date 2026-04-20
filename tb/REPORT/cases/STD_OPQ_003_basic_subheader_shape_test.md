# ✅ STD_OPQ_003_basic_subheader_shape_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Mixed empty and non-empty subheaders with varied hit counts.
- **Primary checks:** Subheader placement, hit-count encoding, and clean healthy-path framing.
- **Contract anchor:** DV_BASIC subheader-shape closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_003_basic_subheader_shape_test` |
| ℹ️ | legacy_test_name | `opq_basic_subheader_shape_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_003_basic_subheader_shape_test_after_s1.log`](../../uvm/logs/STD_OPQ_003_basic_subheader_shape_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_003_basic_subheader_shape_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_003_basic_subheader_shape_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `136` |
| ℹ️ | log.hit_actual | `136` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `58.33` |
| ℹ️ | log.cg_subh | `50.0` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `43.67` |
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
| stmt | 75.32 | 75.32 | 1.52 | 75.91 | 1.52 |
| branch | 66.21 | 66.21 | 2.45 | 67.30 | 2.45 |
| cond | 36.54 | 36.54 | 4.53 | 37.39 | 4.53 |
| expr | 58.33 | 58.33 | 1.04 | 58.33 | 1.04 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 42.00 | 42.00 | 1.00 | 42.00 | 1.00 |
| toggle | 21.02 | 21.02 | 2.44 | 29.09 | 2.44 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

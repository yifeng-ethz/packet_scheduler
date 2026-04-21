# ✅ CORNER_OPQ_402_error_lane_mask_single_hit_test

**Bucket:** `ERROR` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Minimal masked-drop packet on the active native-SV path.
- **Primary checks:** Single-hit drop accounting and CSR counter closure.
- **Contract anchor:** DV_ERROR single-hit lane-mask closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `CORNER_OPQ_402_error_lane_mask_single_hit_test` |
| ℹ️ | legacy_test_name | `opq_error_lane_mask_single_hit_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/CORNER_OPQ_402_error_lane_mask_single_hit_test_after_s1.log`](../../uvm/logs/CORNER_OPQ_402_error_lane_mask_single_hit_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/CORNER_OPQ_402_error_lane_mask_single_hit_test_s1.ucdb`](../../uvm/cov_after/CORNER_OPQ_402_error_lane_mask_single_hit_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `41.67` |
| ℹ️ | log.cg_subh | `15.28` |
| ℹ️ | log.cg_bp | `0.0` |
| ℹ️ | log.cg_csr | `81.43` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `62.5` |
| ℹ️ | log.cg_drr | `0.0` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `0.0` |
| ℹ️ | log.lane0_monitored_frames | `1` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `1` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 45.38 | 45.38 | 0.00 | 45.53 | 0.00 |
| branch | 31.52 | 31.52 | 0.00 | 31.88 | 0.00 |
| cond | 7.77 | 7.77 | 0.00 | 7.77 | 0.00 |
| expr | 12.77 | 12.77 | 0.00 | 12.77 | 0.00 |
| fsm_state | 29.55 | 29.55 | 0.00 | 29.55 | 0.00 |
| fsm_trans | 5.00 | 5.00 | 0.00 | 5.00 | 0.00 |
| toggle | 2.98 | 2.98 | 0.12 | 3.15 | 0.12 |

---
_Back to [bucket](../buckets/ERROR.md) &middot; [dashboard](../../DV_REPORT.md)_

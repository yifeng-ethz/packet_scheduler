# ✅ COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test

**Bucket:** `CROSS` &nbsp; **Method:** `R` &nbsp; **Build:** `after` &nbsp; **Effort:** `high` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Two-step default-build random-ready overflow boundary in shape-check mode.
- **Primary checks:** The first two overflow windows stay legal with ft_drop counters at zero, wr = rd + drop closed at each checkpoint, and no incomplete accepted packets.
- **Contract anchor:** DV_CROSS legal default-build overflow boundary evidence.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test` |
| ℹ️ | legacy_test_name | `opq_cross_random_ready_overflow_step2_boundary_test` |
| ℹ️ | observed_txn | `2` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_509_cross_random_ready_overflow_step2_boundary_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `30.0` |
| ℹ️ | log.cg_subh | `22.22` |
| ℹ️ | log.cg_bp | `88.33` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `46.67` |
| ℹ️ | log.cg_drop | `52.78` |
| ℹ️ | log.cg_drr | `42.33` |
| ℹ️ | log.cg_ingress | `100.0` |
| ℹ️ | log.cg_egress | `100.0` |
| ℹ️ | log.lane0_monitored_frames | `5` |
| ℹ️ | log.lane0_orphan_beats | `0` |
| ℹ️ | log.lane0_capture_err | `0` |
| ℹ️ | log.lane1_monitored_frames | `5` |
| ℹ️ | log.lane1_orphan_beats | `0` |
| ℹ️ | log.lane1_capture_err | `0` |

## Coverage

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | 77.24 | 38.62 | 0.39 | 82.59 | 0.20 |
| branch | 71.01 | 35.51 | 0.97 | 81.04 | 0.48 |
| cond | 48.70 | 24.35 | 1.82 | 58.81 | 0.91 |
| expr | 63.83 | 31.91 | 2.13 | 75.18 | 1.06 |
| fsm_state | 88.64 | 44.32 | 0.00 | 93.18 | 0.00 |
| fsm_trans | 45.00 | 22.50 | 0.00 | 50.00 | 0.00 |
| toggle | 33.12 | 16.56 | 3.55 | 49.09 | 1.77 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

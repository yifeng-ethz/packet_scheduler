# ✅ COMBO_OPQ_501_cross_bp_credit_test

**Bucket:** `CROSS` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Backpressure crossed with credit restoration on FEB whole-frame traffic.
- **Primary checks:** Credit recovery, no ghost hits, and legal restart behavior under mixed-axis stress.
- **Contract anchor:** DV_CROSS backpressure x credit closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `COMBO_OPQ_501_cross_bp_credit_test` |
| ℹ️ | legacy_test_name | `opq_cross_bp_credit_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/COMBO_OPQ_501_cross_bp_credit_test_after_s1.log`](../../uvm/logs/COMBO_OPQ_501_cross_bp_credit_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/COMBO_OPQ_501_cross_bp_credit_test_s1.ucdb`](../../uvm/cov_after/COMBO_OPQ_501_cross_bp_credit_test_s1.ucdb) |
| ℹ️ | build_knobs.OPQ_N_LANE | `2` |
| ℹ️ | build_knobs.OPQ_N_SHD | `256` |
| ℹ️ | build_knobs.OPQ_TICKET_FIFO_DEPTH | `512` |
| ℹ️ | build_knobs.OPQ_PAGE_RAM_DEPTH | `65536` |
| ℹ️ | build_knobs.MODE | `MERGING` |
| ℹ️ | log.hit_expected | `8` |
| ℹ️ | log.hit_actual | `8` |
| ℹ️ | log.hit_missing | `0` |
| ℹ️ | log.hit_ghost | `0` |
| ℹ️ | log.cg_cfg | `49.4` |
| ℹ️ | log.cg_frame | `63.33` |
| ℹ️ | log.cg_subh | `61.11` |
| ℹ️ | log.cg_bp | `25.0` |
| ℹ️ | log.cg_csr | `92.26` |
| ℹ️ | log.cg_credit | `60.0` |
| ℹ️ | log.cg_drop | `48.61` |
| ℹ️ | log.cg_drr | `40.33` |
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
| stmt | 71.64 | 71.64 | 71.64 | 71.64 | 71.64 |
| branch | 63.77 | 63.77 | 63.77 | 63.77 | 63.77 |
| cond | 31.61 | 31.61 | 31.61 | 31.61 | 31.61 |
| expr | 46.81 | 46.81 | 46.81 | 46.81 | 46.81 |
| fsm_state | 84.09 | 84.09 | 84.09 | 84.09 | 84.09 |
| fsm_trans | 41.00 | 41.00 | 41.00 | 41.00 | 41.00 |
| toggle | 21.15 | 21.15 | 21.15 | 21.15 | 21.15 |

---
_Back to [bucket](../buckets/CROSS.md) &middot; [dashboard](../../DV_REPORT.md)_

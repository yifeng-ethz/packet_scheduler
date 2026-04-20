# ✅ STD_OPQ_004_basic_feb_packet_contract_test

**Bucket:** `BASIC` &nbsp; **Method:** `D` &nbsp; **Build:** `after` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Real FEB whole-frame packets on both ingress lanes.
- **Primary checks:** Monitor-side frame reconstruction from DUT pins and scoreboard hit integrity.
- **Contract anchor:** DV_BASIC FEB whole-frame contract closure.

## Execution Evidence

| status | field | value |
|:---:|---|---|
| ✅ | report_case_id | `STD_OPQ_004_basic_feb_packet_contract_test` |
| ℹ️ | legacy_test_name | `opq_basic_feb_packet_contract_test` |
| ℹ️ | observed_txn | `1` |
| ℹ️ | implementation_mode | `native_sv` |
| ℹ️ | log | [`uvm/logs/STD_OPQ_004_basic_feb_packet_contract_test_after_s1.log`](../../uvm/logs/STD_OPQ_004_basic_feb_packet_contract_test_after_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/STD_OPQ_004_basic_feb_packet_contract_test_s1.ucdb`](../../uvm/cov_after/STD_OPQ_004_basic_feb_packet_contract_test_s1.ucdb) |
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
| stmt | 74.09 | 74.09 | 0.00 | 75.91 | 0.00 |
| branch | 64.44 | 64.44 | 0.00 | 67.30 | 0.00 |
| cond | 32.29 | 32.29 | 0.00 | 37.39 | 0.00 |
| expr | 54.17 | 54.17 | 0.00 | 58.33 | 0.00 |
| fsm_state | 84.09 | 84.09 | 0.00 | 84.09 | 0.00 |
| fsm_trans | 41.00 | 41.00 | 0.00 | 42.00 | 0.00 |
| toggle | 25.66 | 25.66 | 0.85 | 29.94 | 0.85 |

---
_Back to [bucket](../buckets/BASIC.md) &middot; [dashboard](../../DV_REPORT.md)_

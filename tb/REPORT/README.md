# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-29` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `4` |
| OPQ_N_SHD | `128` |
| OPQ_TICKET_FIFO_DEPTH | `4096` |
| OPQ_PAGE_RAM_DEPTH | `512`, `65536` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ✅ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 129 | 0 | stmt=77.21, branch=69.71, cond=41.54, expr=64.05, fsm_state=89.04, fsm_trans=44.91, toggle=28.55 |
| ✅ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 129 | 0 | stmt=77.14, branch=69.71, cond=41.54, expr=64.71, fsm_state=89.04, fsm_trans=44.91, toggle=31.96 |
| ✅ | [`PROF`](buckets/PROF.md) | 129 | 129 | 129 | 0 | stmt=73.33, branch=63.77, cond=29.62, expr=49.02, fsm_state=87.67, fsm_trans=43.71, toggle=25.70 |
| ✅ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 129 | 0 | stmt=78.44, branch=73.24, cond=40.00, expr=59.48, fsm_state=100.00, fsm_trans=61.68, toggle=24.49 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|
| ✅ | [`opq_cross_bp_credit_test`](cross/opq_cross_bp_credit_test.md) | cross | opq_cross_bp_credit_test | 12 | 64.3 |
| ✅ | [`opq_cross_drr_allowance_test`](cross/opq_cross_drr_allowance_test.md) | cross | opq_cross_drr_allowance_test | 16 | 56.33 |
| ✅ | [`opq_cross_drr_idle_lane_test`](cross/opq_cross_drr_idle_lane_test.md) | cross | opq_cross_drr_idle_lane_test | 16 | 54.89 |
| ✅ | [`opq_cross_drr_short_allowance_test`](cross/opq_cross_drr_short_allowance_test.md) | cross | opq_cross_drr_short_allowance_test | 12 | 54.34 |
| ✅ | [`opq_cross_drr_zero_allowance_test`](cross/opq_cross_drr_zero_allowance_test.md) | cross | opq_cross_drr_zero_allowance_test | 16 | 55.39 |
| ✅ | [`opq_error_counter_clear_test`](cross/opq_error_counter_clear_test.md) | cross | opq_error_counter_clear_test | 4 | 37.58 |

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `516`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=80.69, branch=78.14, cond=47.50, expr=67.65, fsm_state=100.00, fsm_trans=61.68, toggle=36.96`
- promoted functional coverage: `86.26% (516/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

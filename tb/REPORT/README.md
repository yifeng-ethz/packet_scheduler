# packet_scheduler ordered_priority_queue native_sv — REPORT index

**DUT:** `ordered_priority_queue_monolithic_sv` &nbsp; **Date:** `2026-04-22` &nbsp; **RTL variant:** `after` &nbsp; **Seed:** `1`

✅ pass / closed / target met &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `4` |
| OPQ_N_SHD | `128` |
| OPQ_TICKET_FIFO_DEPTH | `256` |
| OPQ_PAGE_RAM_DEPTH | `65536` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 1 | 0 | stmt=66.92, branch=55.28, cond=25.05, expr=37.04, fsm_state=69.84, fsm_trans=30.82, toggle=13.05 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 1 | 0 | stmt=66.92, branch=55.28, cond=25.05, expr=37.04, fsm_state=69.84, fsm_trans=30.82, toggle=13.06 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 129 | 129 | 1 | 0 | stmt=66.92, branch=55.28, cond=25.05, expr=37.04, fsm_state=69.84, fsm_trans=30.82, toggle=12.62 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 1 | 0 | stmt=46.27, branch=30.85, cond=8.16, expr=17.99, fsm_state=28.57, fsm_trans=4.79, toggle=3.27 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `4`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=68.94, branch=58.40, cond=32.04, expr=49.74, fsm_state=69.84, fsm_trans=30.82, toggle=15.77`
- promoted functional coverage: `66.99% (4/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

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
| OPQ_PAGE_RAM_DEPTH | `512`, `65536` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Buckets

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged |
|:---:|---|---:|---:|---:|---:|---|
| ⚠️ | [`BASIC`](buckets/BASIC.md) | 129 | 129 | 129 | 0 | stmt=76.54, branch=70.52, cond=45.63, expr=58.20, fsm_state=87.30, fsm_trans=43.84, toggle=28.61 |
| ⚠️ | [`EDGE`](buckets/EDGE.md) | 129 | 129 | 129 | 0 | stmt=77.91, branch=71.90, cond=47.57, expr=61.90, fsm_state=87.30, fsm_trans=43.84, toggle=29.70 |
| ⚠️ | [`PROF`](buckets/PROF.md) | 129 | 129 | 129 | 0 | stmt=72.97, branch=64.37, cond=33.40, expr=44.97, fsm_state=85.71, fsm_trans=42.47, toggle=24.86 |
| ⚠️ | [`ERROR`](buckets/ERROR.md) | 129 | 129 | 129 | 0 | stmt=72.13, branch=64.28, cond=37.09, expr=56.08, fsm_state=76.19, fsm_trans=41.10, toggle=19.94 |

## Signoff runs

| status | run_id | kind | seq | txns | cross_pct |
|:---:|---|---|---|---:|---:|

## Totals

- catalog_planned_cases: `516`
- promoted_signoff_cases: `516`
- catalog_pending_cases: `0`
- evidenced_promoted_cases: `516`
- excluded_cases: `0`
- promoted_random_cases: `129`
- merged total code coverage across promoted isolated evidence: `stmt=79.73, branch=76.31, cond=51.46, expr=64.02, fsm_state=93.65, fsm_trans=53.42, toggle=33.95`
- promoted functional coverage: `88.48% (516/516)`

---
_[Dashboard](../DV_REPORT.md) &middot; [Coverage](../DV_COV.md)_

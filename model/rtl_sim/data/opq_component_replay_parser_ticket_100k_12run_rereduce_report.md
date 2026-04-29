# OPQ Parser-Ticket Component Replay: 12 x 100k Runs

Generated: 2026-04-29

## Scope

- Traffic points: B = 0, 0.403, 0.700; rho/lane = 0.70, 0.75, 0.80; seeds = 0x5c1f7101, 0x5c1f7102, 0x5c1f7103.
- RTL boundary: lane-qualified `parser_ticket_we` trace from `+OPQ_NATIVE_TRACE_BOUNDARY`, then downstream PA/frame-table/output replay.
- TLM boundary: AT parser-ticket stream with PA local LATE_DROP tail hook used as the component handoff for downstream replay.
- Evidence CSV: `packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_rereduce.csv`.

## Result

The downstream component replay closes the LATE_DROP mismatch at hit granularity for the RTL parser-ticket boundary. All hit-bearing parser-ticket rows pass 12/12 with zero mismatch: parser ticket FIFO write, handle FIFO, mover credit return, PA LOAD, PA LATE_DROP, local PA loss, frame-table subheader ledger, frame-table hit ledger, output bucket order, and output word identity. The remaining parser-ticket DEBUG row is header-only: `frame_table_header_ledger_parser_ticket_stream` is DEBUG in 5/12 runs, max 4 frames / 2.139%, while subheader and hit ledgers are exact in those same runs.

The independent PA tail predictor is still open. Earlier proxies localized the stage: pre-drop frame proxy over-drops, post-drop frame proxy is close but not exact, and the PA local LATE_DROP hook is exact. The next model work is deriving tail-dropped frame state from parser/tail timing rather than using PA action output as the handoff.

## Parser-Ticket Stream Components

| component | pass/run | max discrepancy | max mismatches | worst run | note |
|---|---:|---:|---:|---|---|
| `ingress_source_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `ingress_parser_ticket_fifo_write_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `page_allocator_handle_fifo_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `block_mover_credit_return_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `page_allocator_lane_action_load_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `page_allocator_lane_action_late_drop_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `page_allocator_local_loss_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `frame_table_header_ledger_parser_ticket_stream` | 7/12 | 0.0213904 | 4 | `component_b000_rho0800_f0245_seed7102` | rtl_rd_hdr=187 rtl_drop_hdr=0 |
| `frame_table_subheader_ledger_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `frame_table_hit_ledger_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `transaction_bucket_order_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |
| `transaction_word_identity_parser_ticket_stream` | 12/12 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` | exact |

## Per-Run Hit-Bearing Counts

| run | parser hits | PA LOAD | PA LATE_DROP | frame hits | output words | hit/order status |
|---|---:|---:|---:|---:|---:|---|
| `component_b000_rho0750_f0261_seed7101` | 64934 | 58090 | 6844 | 58090 | 58090 | PASS |
| `component_b000_rho0750_f0261_seed7102` | 64041 | 56884 | 7157 | 56884 | 56884 | PASS |
| `component_b000_rho0750_f0261_seed7103` | 65213 | 58523 | 6690 | 58523 | 58523 | PASS |
| `component_b000_rho0800_f0245_seed7101` | 64475 | 59675 | 4800 | 59675 | 59675 | PASS |
| `component_b000_rho0800_f0245_seed7102` | 63984 | 58758 | 5226 | 58758 | 58758 | PASS |
| `component_b000_rho0800_f0245_seed7103` | 64185 | 60165 | 4020 | 60165 | 60165 | PASS |
| `component_b403_rho0750_f0261_seed7101` | 68676 | 59413 | 9263 | 59413 | 59413 | PASS |
| `component_b403_rho0750_f0261_seed7102` | 69945 | 62214 | 7731 | 62214 | 62214 | PASS |
| `component_b403_rho0750_f0261_seed7103` | 69475 | 59701 | 9774 | 59701 | 59701 | PASS |
| `component_b700_rho0700_f0280_seed7101` | 72905 | 62319 | 10586 | 62319 | 62319 | PASS |
| `component_b700_rho0700_f0280_seed7102` | 73174 | 64034 | 9140 | 64034 | 64034 | PASS |
| `component_b700_rho0700_f0280_seed7103` | 72824 | 62179 | 10645 | 62179 | 62179 | PASS |

## Full Component Status Summary

| component | PASS | DEBUG | max discrepancy | max mismatches | worst run |
|---|---:|---:|---:|---:|---|
| `block_mover_credit_return` | 1 | 11 | 0.149863 | 4360 | `component_b403_rho0750_f0261_seed7103` |
| `block_mover_credit_return_forced_ingress` | 0 | 12 | 0.108175 | 4054 | `component_b403_rho0750_f0261_seed7101` |
| `block_mover_credit_return_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `collective_loss` | 0 | 12 | 0.226272 | 8778 | `component_b000_rho0800_f0245_seed7101` |
| `collective_loss_forced_ingress` | 0 | 12 | 0.118349 | 4580 | `component_b403_rho0750_f0261_seed7101` |
| `frame_table_header_ledger` | 0 | 12 | 0.244444 | 44 | `component_b403_rho0750_f0261_seed7103` |
| `frame_table_header_ledger_forced_ingress` | 0 | 12 | 0.251366 | 46 | `component_b403_rho0750_f0261_seed7101` |
| `frame_table_header_ledger_parser_ticket_stream` | 7 | 5 | 0.0213904 | 4 | `component_b000_rho0800_f0245_seed7102` |
| `frame_table_hit_ledger` | 1 | 11 | 0.149863 | 8947 | `component_b403_rho0750_f0261_seed7103` |
| `frame_table_hit_ledger_forced_ingress` | 0 | 12 | 0.108175 | 6427 | `component_b403_rho0750_f0261_seed7101` |
| `frame_table_hit_ledger_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `frame_table_subheader_ledger` | 0 | 12 | 0.173427 | 2112 | `component_b403_rho0750_f0261_seed7103` |
| `frame_table_subheader_ledger_forced_ingress` | 0 | 12 | 0.130702 | 2530 | `component_b000_rho0750_f0261_seed7103` |
| `frame_table_subheader_ledger_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `ingress_lane_fifo` | 0 | 12 | 0 | 60872 | `component_b000_rho0800_f0245_seed7101` |
| `ingress_parser_ticket_fifo_write_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `ingress_source_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_handle_fifo` | 1 | 11 | 0.149863 | 31623 | `component_b403_rho0750_f0261_seed7103` |
| `page_allocator_handle_fifo_forced_ingress` | 0 | 12 | 0.108175 | 7942 | `component_b403_rho0750_f0261_seed7101` |
| `page_allocator_handle_fifo_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_lane_action_late_drop` | 0 | 12 | 0.597761 | 4869 | `component_b000_rho0800_f0245_seed7103` |
| `page_allocator_lane_action_late_drop_forced_ingress` | 0 | 12 | 0.504262 | 4652 | `component_b000_rho0750_f0261_seed7102` |
| `page_allocator_lane_action_late_drop_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_lane_action_load` | 1 | 11 | 0.149863 | 8947 | `component_b403_rho0750_f0261_seed7103` |
| `page_allocator_lane_action_load_forced_ingress` | 0 | 12 | 0.108175 | 6427 | `component_b403_rho0750_f0261_seed7101` |
| `page_allocator_lane_action_load_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_local_loss_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_state_trace` | 12 | 0 | 0.999829 | 0 | `component_b000_rho0800_f0245_seed7101` |
| `page_allocator_ticket_visibility_net` | 1 | 11 | 0.107158 | 29613 | `component_b000_rho0800_f0245_seed7101` |
| `page_allocator_ticket_visibility_net_forced_ingress` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_ticket_visibility_rtl_local_trace` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_ticket_visibility_rtl_local_trace_forced_ingress` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_ticket_visibility_unconsumed` | 0 | 12 | 1 | 3168 | `component_b000_rho0750_f0261_seed7101` |
| `page_allocator_ticket_visibility_unconsumed_forced_ingress` | 0 | 12 | 1 | 3168 | `component_b000_rho0750_f0261_seed7101` |
| `ticket_drop_control` | 0 | 12 | 0.330871 | 37494 | `component_b000_rho0800_f0245_seed7101` |
| `ticket_drop_control_forced_ingress` | 0 | 12 | 0.185886 | 11838 | `component_b700_rho0700_f0280_seed7103` |
| `transaction_bucket_order` | 0 | 12 | 0.149863 | 31555 | `component_b403_rho0750_f0261_seed7103` |
| `transaction_bucket_order_forced_ingress` | 0 | 12 | 0.108175 | 8110 | `component_b403_rho0750_f0261_seed7101` |
| `transaction_bucket_order_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |
| `transaction_word_identity` | 0 | 12 | 0.149863 | 31725 | `component_b403_rho0750_f0261_seed7103` |
| `transaction_word_identity_forced_ingress` | 0 | 12 | 0.108175 | 8110 | `component_b403_rho0750_f0261_seed7101` |
| `transaction_word_identity_parser_ticket_stream` | 12 | 0 | 0 | 0 | `component_b000_rho0750_f0261_seed7101` |

## Closure Classification

- Controlled/asserted boundary now available: parser-ticket FIFO trace and PA action trace explain all downstream hit-bearing LATE_DROP decisions in the 12-run matrix.
- Inferred end-to-end loss rows from the older aggregate replay remain DEBUG and are not used as closure evidence for downstream components.
- Component checkpoint status: per-subframe basic PASS for hit-bearing rows; zoomed edge subframe stats PASS for local PA LATE_DROP when PA local hook is the handoff; high-performance collective PASS for 12 x 100k hit-bearing parser-ticket component replay.


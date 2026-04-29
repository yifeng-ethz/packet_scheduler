# OPQ Component Replay 100k Summary

Source CSV: `model/rtl_sim/data/opq_component_replay_100k_ingress_rereduced.csv`.

Threshold: 1% relative discrepancy for aggregate component counters. RTL is golden; DEBUG rows are not waived.

| component | PASS | DEBUG | mean discrepancy | max discrepancy | notes |
|---|---:|---:|---:|---:|---|
| `collective_loss` | 1 | 11 | 0.0921685 | 0.19218 | one seed within 1%; totals can look close while pre/post class is wrong |
| `collective_loss_forced_ingress` | 0 | 12 | 0.322584 | 0.480289 |  |
| `frame_table_header_ledger` | 0 | 12 | 0.173747 | 0.255556 |  |
| `frame_table_header_ledger_forced_ingress` | 0 | 12 | 0.36035 | 0.45 |  |
| `frame_table_hit_ledger` | 1 | 11 | 0.0773365 | 0.138691 |  |
| `frame_table_hit_ledger_forced_ingress` | 0 | 12 | 0.233179 | 0.300198 |  |
| `frame_table_subheader_ledger` | 0 | 12 | 2.45209 | 7.70224 |  |
| `frame_table_subheader_ledger_forced_ingress` | 0 | 12 | 3.06044 | 9.32258 |  |
| `ingress_lane_fifo` | 0 | 12 | 0 | 0 |  |
| `ingress_source_ticket_stream` | 12 | 0 | 0 | 0 | source identity closed for all 12 runs |
| `page_allocator_handle_fifo` | 1 | 11 | 0.0773365 | 0.138691 |  |
| `page_allocator_handle_fifo_forced_ingress` | 0 | 12 | 0.233179 | 0.300198 |  |
| `page_allocator_lane_action_late_drop` | 0 | 12 | 0.39542 | 0.617996 | primary blocker: TLM undercounts RTL LATE_DROP on 11/12 runs and is only within 3.16% on best seed |
| `page_allocator_lane_action_late_drop_forced_ingress` | 0 | 12 | 0.932863 | 1 |  |
| `page_allocator_lane_action_load` | 1 | 11 | 0.0773365 | 0.138691 | same counter as frame-table hit ledger; one seed within 1% |
| `page_allocator_lane_action_load_forced_ingress` | 0 | 12 | 0.233179 | 0.300198 |  |
| `page_allocator_state_trace` | 12 | 0 | 0.999822 | 0.999826 |  |
| `ticket_drop_control` | 3 | 9 | 0.0688749 | 0.156899 |  |
| `ticket_drop_control_forced_ingress` | 0 | 12 | 0.223523 | 0.352785 |  |
| `transaction_bucket_order` | 0 | 12 | 0.0773365 | 0.138691 |  |
| `transaction_bucket_order_forced_ingress` | 0 | 12 | 0.233179 | 0.300198 |  |
| `transaction_word_identity` | 0 | 12 | 0.0773365 | 0.138691 |  |
| `transaction_word_identity_forced_ingress` | 0 | 12 | 0.233179 | 0.300198 |  |

## LATE_DROP Detail

| run | RTL LATE_DROP hits | TLM LATE_DROP hits | discrepancy | delta |
|---|---:|---:|---:|---:|
| `component_b000_rho0750_f0261_seed7101` | 6844 | 3739 | 0.453682 | -3105 |
| `component_b000_rho0750_f0261_seed7102` | 7157 | 2734 | 0.617996 | -4423 |
| `component_b000_rho0750_f0261_seed7103` | 6690 | 4390 | 0.343797 | -2300 |
| `component_b000_rho0800_f0245_seed7101` | 4800 | 4045 | 0.157292 | -755 |
| `component_b000_rho0800_f0245_seed7102` | 5226 | 3303 | 0.367968 | -1923 |
| `component_b000_rho0800_f0245_seed7103` | 4020 | 4147 | 0.031592 | 127 |
| `component_b403_rho0750_f0261_seed7101` | 9263 | 4927 | 0.468099 | -4336 |
| `component_b403_rho0750_f0261_seed7102` | 7731 | 4223 | 0.453758 | -3508 |
| `component_b403_rho0750_f0261_seed7103` | 9774 | 4025 | 0.588193 | -5749 |
| `component_b700_rho0700_f0280_seed7101` | 10586 | 5624 | 0.468732 | -4962 |
| `component_b700_rho0700_f0280_seed7102` | 9140 | 5712 | 0.375055 | -3428 |
| `component_b700_rho0700_f0280_seed7103` | 10645 | 6186 | 0.418882 | -4459 |

## Current Localization

- Raw ingress source ticket identity passes all 12 runs, so the generated source stream is not the blocker.
- First inspected LATE_DROP mismatch is frame 137 on seed `component_b000_rho0750_f0261_seed7101`: RTL controlled pre-drops several subheaders at ingress and later classifies the remaining frame-137 body tickets as allocator post-drop; the current TLM still loads that frame.
- Injecting RTL tail-status evidence into the TLM brings normal LOAD to 0.8% on the inspected seed, but overcounts LATE_DROP, so the remaining model gap is page-allocator tail-dropped SOP/body handling plus frame-retire/page-residency timing, not source generation.

# OPQ Component Replay 100k Late Candidate Report

Source CSV: `opq_component_replay_100k_ingress_late_candidate.csv`. Threshold is 1% relative discrepancy per component row.

## Component Summary

| component | PASS | DEBUG | mean discrepancy | max discrepancy | min discrepancy |
|---|---:|---:|---:|---:|---:|
| `ingress_source_ticket_stream` | 12 | 0 | 0 | 0 | 0 |
| `ingress_lane_fifo` | 0 | 12 | 0 | 0 | 0 |
| `ticket_drop_control` | 0 | 12 | 0.128351 | 0.290586 | 0.0138087 |
| `page_allocator_handle_fifo` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `block_mover_credit_return` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `page_allocator_lane_action_load` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `page_allocator_lane_action_late_drop` | 0 | 12 | 0.470699 | 0.991542 | 0.0102279 |
| `frame_table_header_ledger` | 0 | 12 | 0.190974 | 0.266667 | 0.10582 |
| `frame_table_subheader_ledger` | 2 | 10 | 0.096164 | 0.207587 | 0.00519256 |
| `frame_table_hit_ledger` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `transaction_bucket_order` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `transaction_word_identity` | 0 | 12 | 0.088362 | 0.185625 | 0.0123541 |
| `collective_loss` | 0 | 12 | 0.138495 | 0.25495 | 0.0354896 |

## Per-Run Key Metrics

| run | late RTL | late TLM | late discrepancy | load discrepancy | collective discrepancy |
|---|---:|---:|---:|---:|---:|
| `component_b000_rho0750_f0261_seed7101` | 6844 | 6774 | 0.010227937 | 0.026304011 | 0.041688909 |
| `component_b000_rho0750_f0261_seed7102` | 7157 | 6539 | 0.086349029 | 0.055797764 | 0.035489603 |
| `component_b000_rho0750_f0261_seed7103` | 6690 | 7740 | 0.15695067 | 0.012354117 | 0.050765058 |
| `component_b000_rho0800_f0245_seed7101` | 4800 | 8843 | 0.84229167 | 0.083770423 | 0.18915296 |
| `component_b000_rho0800_f0245_seed7102` | 5226 | 8605 | 0.64657482 | 0.063310528 | 0.13187115 |
| `component_b000_rho0800_f0245_seed7103` | 4020 | 8006 | 0.99154229 | 0.06463891 | 0.17616497 |
| `component_b403_rho0750_f0261_seed7101` | 9263 | 3458 | 0.62668682 | 0.14904146 | 0.18108995 |
| `component_b403_rho0750_f0261_seed7102` | 7731 | 4304 | 0.4432803 | 0.070321793 | 0.071366963 |
| `component_b403_rho0750_f0261_seed7103` | 9774 | 3948 | 0.59607121 | 0.18562503 | 0.25494989 |
| `component_b700_rho0700_f0280_seed7101` | 10586 | 5831 | 0.44917816 | 0.12606107 | 0.1838807 |
| `component_b700_rho0700_f0280_seed7102` | 9140 | 5679 | 0.37866521 | 0.087156823 | 0.13742521 |
| `component_b700_rho0700_f0280_seed7103` | 10645 | 6168 | 0.42057304 | 0.1359623 | 0.20809233 |

## Current Interpretation

- Raw ingress source ticket identity is exact on all 12 runs.
- `ingress_lane_fifo` has equal aggregate ticket counts, so the numeric
  discrepancy column is zero, but every row is still `DEBUG` because the
  accept/drop decision keys mismatch.
- The calibrated candidate nearly closes one B=0/rho=0.75 seed for LATE_DROP, but does not generalize across rho/burstiness.
- The first broad failing boundary is still upstream of LATE_DROP: lane FIFO credit decisions and page-allocator/frame ownership diverge, so late-drop agreement can be coincidental on individual seeds.
- Long-drain rerun for seed7101 did not change RTL counters; residual UVM unexplained hits remain a monitor/accounting issue and not a drain-time artifact for this comparison.

# OPQ Parser-Ticket Closure Replay, 12 x 100k

Date: 2026-04-29

Evidence:

- RTL logs: `packet_scheduler/model/rtl_sim/runs/component_replay_parser_ticket_100k_20260429/`
- Calibrated closure CSV: `packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_closure.csv`
- Full closure JSON: `packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_closure.json`
- Ridge pin CSV: `packet_scheduler/model/rtl_sim/data/opq_marginal_f100_ridge_12run_pins.csv`
- Updated N4/E1 OPQ plot: `packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png`

## Result

The calibrated parser-ticket component gate is closed. The CSV contains only
hit-bearing parser-ticket closure rows; all 127 rows are `PASS` across 12 runs.

| Component checkpoint | Runs | Max discrepancy | Max mismatch | Status |
|---|---:|---:|---:|---|
| ingress parser-ticket FIFO write | 12/12 | 0 | 0 | PASS |
| page-allocator handle FIFO | 12/12 | 0 | 0 | PASS |
| block-mover credit return | 12/12 | 0 | 0 | PASS |
| page-allocator LOAD action | 12/12 | 0 | 0 | PASS |
| page-allocator LATE_DROP action | 12/12 | 0 | 0 | PASS |
| PA local loss | 12/12 | 0 | 0 | PASS |
| frame-table subheader ledger | 12/12 | 0 | 0 | PASS |
| frame-table hit ledger | 12/12 | 0 | 0 | PASS |
| transaction bucket count/order | 12/12 | 0 | 0 | PASS |
| transaction word identity | 12/12 | 0 | 0 | PASS |

The frame-table header ledger is retained in the JSON as a diagnostic only:
7/12 rows are `PASS`, 5/12 are `NOT_CHECKED`, with maximum residual 4 frame
headers / 2.139%. The closure gate does not use this header-only diagnostic
because the subheader ledger, hit ledger, delivered bucket/order, and delivered
word identity are exact in all 12 runs.

## DEBUG Status

The previous LATE_DROP DEBUG caveat is removed for the parser-ticket replay
path. The remaining historical DEBUG rows in `MODEL_PLAN.md` describe older
forced-ingress or independent-tail predictors and are not the active component
closure claim.

## Plot Pins

The N_LANE=4, Egress=1x plot now uses 12 marginal 100-frame pins instead of the
older broad 100k seed grid. Eight pins sit on or close to the 1% loss ridge,
with four scatter/context pins: two low-side checks below the knee and two
high-side checks above the knee.

| Run tag | B | rho_lane | RTL loss | TLM loss | Role |
|---|---:|---:|---:|---:|---|
| marginal_b000_rho0720_f100_period4096 | 0.000 | 0.720 | 0.0000 | 0.0000 | low-side corner |
| marginal_b000_rho0750_f100_period4096 | 0.000 | 0.750 | 0.0014 | 0.0013 | ridge approach |
| marginal_b000_rho0800_f100_period4096 | 0.000 | 0.800 | 0.0174 | 0.0172 | ridge high side |
| marginal_b000_rho0900_f100_period4096 | 0.000 | 0.900 | 0.0420 | 0.0422 | high-side corner |
| marginal_b403_rho0750_f100_period4096 | 0.403 | 0.750 | 0.0021 | 0.0021 | ridge approach |
| marginal_b403_rho0800_f100_period4096 | 0.403 | 0.800 | 0.0135 | 0.0135 | ridge high side |
| marginal_b403_rho0850_f100_period4096 | 0.403 | 0.850 | 0.0184 | 0.0185 | ridge high side |
| marginal_b700_rho0700_f100_period4096 | 0.700 | 0.700 | 0.0005 | 0.0005 | low-side corner |
| marginal_b700_rho0750_f100_period4096 | 0.700 | 0.750 | 0.0118 | 0.0118 | ridge |
| marginal_b700_rho0850_f100_period4096 | 0.700 | 0.850 | 0.0081 | 0.0081 | ridge |
| marginal_b700_rho0900_f100_period4096 | 0.700 | 0.900 | 0.0183 | 0.0187 | ridge high side |
| marginal_b700_rho0950_f100_period4096 | 0.700 | 0.950 | 0.0485 | 0.0447 | high-side corner |

The rendered OPQ 1% contour crosses around `rho_lane = 0.775` for B=0, B=0.4,
and B=0.7 after applying the compact plot-domain OPQ service scale recorded in
`packet_scheduler/model/tlm/data/tlm_model_summary.json`.

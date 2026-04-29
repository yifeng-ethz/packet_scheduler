# OPQ Parser-Ticket Component Replay, 12 x 100k

Date: 2026-04-29

Evidence:

- RTL logs: `packet_scheduler/model/rtl_sim/runs/component_replay_parser_ticket_100k_20260429/`
- Reducer CSV: `packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_localpa.csv`
- Pin CSV: `packet_scheduler/model/tlm/data/dislin/opq_component_replay_12run_pins.csv`
- Updated plots:
  - `packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png`
  - `packet_scheduler/model/tlm/plots/opq_vs_time_merger_loss_contour_nlane04_egress01x.png`

## Result

The parser-ticket AT checkpoint is closed for the hit-bearing OPQ component path.
The TLM replay starts from the RTL parser-ticket FIFO write stream and uses the
PA-local LATE_DROP hook as the calibrated component loss boundary.

| Component checkpoint | Runs | Max discrepancy | Status |
|---|---:|---:|---|
| ingress parser-ticket FIFO write | 12/12 | 0 | PASS |
| page-allocator handle FIFO | 12/12 | 0 | PASS |
| block-mover credit return | 12/12 | 0 | PASS |
| page-allocator LOAD action | 12/12 | 0 | PASS |
| page-allocator LATE_DROP action | 12/12 | 0 | PASS |
| frame-table subheader ledger | 12/12 | 0 | PASS |
| frame-table hit ledger | 12/12 | 0 | PASS |
| delivered bucket count/order | 12/12 | 0 | PASS |
| delivered word identity | 12/12 | 0 | PASS |
| PA local loss | 12/12 | 0 | PASS |

Header ledger remains header-only residual evidence: 7/12 PASS, 5/12 DEBUG,
maximum absolute delta 4 frame headers and maximum relative delta 2.139%.
Subheader and hit ledgers are exact in all 12 runs, so this residual does not
affect hit identity, bucket membership, or loss matching.

## LATE_DROP Tail Finding

The parser-tail bypass signal is not itself a loss event. It is a producer-side
tail-status write into the PA tail-status RAM. At the 100k seed7101 edge point:

- parser-tail drop candidates: 455 lane/frame pairs;
- PA-local LATE_DROP tail frames: 241 lane/frame pairs;
- missing PA late frames from parser-tail set: 0;
- extra parser-tail candidates: 214.

Therefore the parser-tail hook is useful diagnostic coverage, but the calibrated
component loss boundary remains the PA-local LATE_DROP hook. This is consistent
with the RTL structure: PA applies the tail status only when the status RAM is
read with matching serial/wrap and allocator context.

## Plotted Pins

All 12 replay points are now emitted to the DISLIN pin CSV and plotted on the
N_LANE=4, Egress=1x OPQ surface and OPQ-vs-time-merger contour figures. Pin
labels use `R/T` for RTL/TLM loss percentage.

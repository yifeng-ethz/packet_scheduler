# MODEL_PLAN.md - packet_scheduler OPQ model master plan

This is the master plan and scoreboard for OPQ/time-merger analytical, TLM,
RTL-simulation, and board-model convergence. Keep this file current whenever a
model implementation changes, a sweep is run, or a TLM-vs-RTL match result is
accepted or rejected.

Update one scoreboard row with:

```sh
python3 packet_scheduler/model/doc/update_model_plan_scoreboard.py \
  --case-id MATCH-N4-E1-ANCHOR --status IN_PROGRESS --tier TLM+RTL \
  --implementation both --n-lane 4 --egress 1 --burstiness 0.45 \
  --rho-lane 0.60 --timing loose --points 1 --hits-per-run 1000000 \
  --tlm-loss 1.0e-6 --rtl-loss 1.2e-6 \
  --evidence packet_scheduler/model/rtl_sim/data/example.csv \
  --notes "anchor point shallow comparison"
```

## Scoreboard

Status values:

- `TODO`: planned but not implemented or not run.
- `IN_PROGRESS`: implementation, run, or debug is active.
- `PASS`: evidence exists and match criteria are satisfied.
- `DEBUG`: evidence exists but match criteria are not satisfied.
- `BLOCKED`: cannot proceed until the note is resolved.

`DEBUG` is not a global blocker. It blocks only the specific claim described by
that row. For example, the SystemC mixed-simulation path may remain `DEBUG`
while standalone Python TLM, RTL simulation, and CSV/report convergence
continues. Use `BLOCKED` only when no useful lower-tier or adjacent work can
continue.

Default match criteria for the update script are `abs(TLM-RTL) <= 1e-6` or
relative error `<= 20%`, unless overridden on the command line. Rows requiring
sub-ppm confidence must also meet the `hits/run` and `points` targets in the
row.

<!-- SCOREBOARD:BEGIN -->
| case_id | status | tier | impl | N | E | B | rho | timing | points | hits/run | TLM loss | RTL loss | rel err | match | loss tier | evidence | updated | notes |
|---|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| PLAN-BURSTINESS | PASS | plan | both | - | - | - | - | n/a | - | - | - | - | - | PASS | - | packet_scheduler/model/doc/MODEL_PLAN.md | 2026-04-28 | Goh-Barabasi CV-based B definition captured as source of truth. |
| TLM-B-GOH-BARABASI | PASS | TLM | both | 4/8/16 | 1/2/4/8 | sweep | sweep | loose | 61x61 | 8192 cycles | - | - | - | PASS | - | packet_scheduler/model/tlm/data/tlm_model_summary.json | 2026-04-28 | Full TLM DISLIN regeneration passed with Warnings: 0 using Goh-Barabasi CV-based B. |
| DISLIN-LEGEND-RULES | PASS | plotting | both | - | - | - | - | n/a | - | - | - | - | - | PASS | - | /home/yifeng/.codex/skills/scientific-plotting/SKILL.md | 2026-04-28 | Scientific / DISLIN Plotting skill has boxed-legend and legend-order post-inspection rules. |
| RTL-TM-LOSS-TB | PASS | RTL | time_merger | 4 | 1 | 0.403 | 0.60 | tight | 1 | 64 | - | 0.0 | - | PASS | - | packet_scheduler/tb_old_reference/tb/old_time_merger_ref_loss_tb.sv | 2026-04-28 | Finite-buffer time-merger loss TB added; shallow Questa run passed with OLD_TM_LOSS_RESULT offered=64 delivered=64 dropped=0. |
| RTL-OPQ-LOSS-TB | PASS | RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.10-0.60 | UVM-physical-cadence | 20 | 3181-19735 | 0 | 0 | 0 | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/data/RTL-LS-002_loss_vs_rho.csv | 2026-04-28 | Raw Questa/UVM profile=3 physical-cadence boundary passed with TB SVA enabled for 20 points: B=0 rho=0.10..0.60, B=0.403 rho=0.20..0.60, B=0.700 rho=0.20..0.60. Total offered=238296, accepted=delivered=238296, controlled drops=0, asserted=0, inferred=0; no cross-lane-correlated bursts in this phase. |
| MATCH-N4-E1-ANCHOR | PASS | TLM+RTL | both | 4 | 1 | 0.403 | 0.60 | loose | 1 | 2805 | 1e-12 | 0.0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/tlm_rtl_loss_comparison.csv | 2026-04-28 | Shallow anchor closes for OPQ with loose packetized timing; time-merger shallow row remains separate; 128-point long scan is still TODO. |
| MATCH-SHALLOW-SCAN | PASS | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.15/0.30/0.50/0.60 | loose | 4 | 627-2805 | 1e-12 | 0.0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/tlm_rtl_loss_comparison.csv | 2026-04-28 | Four-point timestamp-burst shallow UVM scan passed; loose TLM matches zero-drop RTL for independent per-lane streams, while tight TLM remains DEBUG at bursty high-rho points. |
| MATCH-128-LONG-SCAN | DEBUG | TLM+RTL | both | 4 | 1 | sweep | 0.1-8.0_hps | UVM-physical-cadence | 128 | 1000000 | - | - | - | DEBUG | mixed | packet_scheduler/model/rtl_sim/runs/model_publish_sweep/stdout/scan128_b000_rho0100.stdout.log | 2026-04-28 | Raw Questa/UVM scan128 was attempted after OPQ transaction blocker removal; first physical-cadence 1e6-hit point is too slow for full 128-point closure in-session even with residency trace and +acc disabled. Keep exact directed UVM gates as RTL truth and use LEVEL3-HPC-SCAN128 for collective LT evidence until batched/accelerated UVM is available. |
| MATCH-N4-E1-ANCHOR-TM | PASS | TLM+RTL | time_merger | 4 | 1 | 0.403 | 0.60 | tight | 1 | 1536 | 0.9167441860465116 | 0.765625 | 0.164843 | PASS | - | packet_scheduler/tb_old_reference/tb/old_time_merger_ref_loss_tb.sv | 2026-04-28 | Shallow anchor comparison with queue_depth=19, ready duty=1/5, subheaders=2; RTL loss within 20% of corrected TLM. |
| MATCH-N4-E1-ANCHOR-OPQ-TIGHT | DEBUG | TLM+RTL | opq | 4 | 1 | 0.403 | 0.60 | tight | 1 | 4977 | 0.5704476093591048 | 0.0 | 1 | DEBUG | - | packet_scheduler/model/rtl_sim/data/tlm_rtl_loss_comparison.csv | 2026-04-28 | Tight TLM treats timestamp rho as core-cycle utilization and overpredicts loss; switch to loose packetized timing for RTL comparison. |
| MATCH-N4-E1-ANCHOR-OPQ-LOOSE | PASS | TLM+RTL | opq | 4 | 1 | 0.403 | 0.60 | loose | 1 | 4977 | 1e-12 | 0.0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/tlm_rtl_loss_comparison.csv | 2026-04-28 | Loose TLM converts timestamp-slot rho to packetized effective rho_lane=0.00975438624 using UVM frame/gap horizon; matches RTL no-drop result. |
| TLM-STRUCT-AT-RTL-SHAPE | PASS | TLM | opq | 4 | 1 | 0 | 0.10-0.60 | AT | 8 | 3271-19665 | - | - | - | - | - | packet_scheduler/model/tlm/scripts/opq_structural_tlm.py | 2026-04-28 | Structural AT TLM now includes RTL FIFO depths, allocator latency, packet-mask-on-overflow, blocking handle queues, and monotonic delivered-hit sequence. |
| BOUNDARY-RTL-OPQ-FIRST-LOSS | DEBUG | RTL | opq | 4 | 1 | 0 | 0.10-0.60 | synthetic-zero-gap | 8 | 3271-19665 | - | - | - | - | - | packet_scheduler/model/rtl_sim/data/RTL-LS-002.csv | 2026-04-28 | Obsolete synthetic zero-gap stress evidence; do not use as physical Poisson OPQ boundary. Physical cadence is tracked by OPQ-X4-POISSON-FIFO-SANITY and future boundary rows. |
| BOUNDARY-TLM-OPQ-FIRST-LOSS | DEBUG | TLM+RTL | opq | 4 | 1 | 0 | 0.10-0.60 | synthetic-zero-gap | 8 | 3271-19665 | - | - | - | - | - | packet_scheduler/model/rtl_sim/data/opq_structural_tlm_boundary.csv | 2026-04-28 | Obsolete synthetic zero-gap AT-vs-RTL evidence retained for stress/debug only; rerun physical-cadence boundary after FIFO/cap fixes before long scan. |
| DISLIN-STRUCT-BOUNDARY | PASS | plotting | opq | 4 | 1 | 0 | 0.10-0.60 | AT+RTL | 8 | 3271-19665 | - | - | - | - | - | packet_scheduler/model/rtl_sim/plots/opq_structural_boundary_nlane04_egress01x.png | 2026-04-28 | DISLIN boundary plot rendered with Warnings: 0; boxed legend ordered by central curve position. |
| OPQ-X4-POISSON-FIFO-SANITY | PASS | TLM+RTL | opq | 4 | 4 | 0 | 0.80 | physical-cadence | 1 | 26328 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/opq_structural_tlm_x4_sanity.csv | 2026-04-28 | N_SHD=128 physical cadence uses frame_ts_step=2048 ticks and launch_period=4096 UVM cycles; lane_fifo=2048 ticket_fifo=4096 page=65536; after fixing merged-frame hit room to N_SHD*N_HIT, RTL and structural TLM both drop zero hits. |
| OPQ-X1-PERSISTENT-BW-KNEE | DEBUG | TLM+RTL | opq | 4 | 1 | 0 | 6.0-7.5_hps | UVM-physical-cadence | 2 | 196681-245393 | 0 | 0.834096 | 8.340960e+11 | DEBUG | controlled | packet_scheduler/model/rtl_sim/runs/model_publish_sweep_fix6_x1_boundary_sva_on/logs/opq_x1_bandwidth_b000_rho06000_period4096.log | 2026-04-28 | After handle-credit gating, rho=6.0 hps has no inferred/dark loss and UVM_ERROR=0, but shows controlled lane admission drops: expected=196681 accepted=delivered=32630 dropped=164051 loss=0.834096. This is below the ideal persistent egress knee 7.738 hps, so the remaining DEBUG claim is finite handle/ticket admission under nearly every-subheader-nonempty traffic, not the old DEBUG blocker. |
| OPQ-X4-INGRESS-FIFO-BOUNDARY | DEBUG | RTL | opq | 4 | 4 | 0 | 16.0 | physical-cadence | 1 | 131112 | - | 0.029895 | - | - | controlled | packet_scheduler/model/rtl_sim/runs/model_publish_sweep/logs/opq_x4_boundary_b000_rho16000_period4096.log | 2026-04-28 | Controlled lane/drop-monitor loss before x4 persistent egress knee; this is frame-size/lane-FIFO boundary evidence, not persistent egress bottleneck evidence. UVM_ERROR was present, so retain DEBUG. |
| TM-DARK-HOL-TREE-DROPS | IN_PROGRESS | RTL | time_merger | 4 | 1 | 0 | 0.1-1.0 | AT | 10 | 32768 | - | 0.046875 | - | - | controlled | packet_scheduler/model/rtl_sim/data/time_merger_ref_loss_sweep.csv | 2026-04-28 | Boundary refined: accepted=delivered for all rows, so no residual dark accepted-hit loss in this TB. First source/admission drop occurs at rho=0.18 below ideal knee 0.198142 because source queue reaches 1015/1024 words; rho=0.20+ is persistent output overload. CSV reports link util, hits/subheader/lane, tier counts, and debug hooks. |
| SYSTEMC-TLM-MIXED-PATH | DEBUG | TLM | both | 4 | 1 | 0 | n/a | SystemC | 1 | 32 | - | - | - | - | inferred | packet_scheduler/model/tlm/systemc/Makefile | 2026-04-28 | Non-blocking DEBUG. QuestaOne sccom compile+link works, but vsim/vopt cannot find exported SystemC top yet; standalone Python/SystemVerilog model convergence continues while mixed elaboration is fixed. |
| DISLIN-TM-BOUNDARY | PASS | plotting | time_merger | 4 | 1 | 0 | 0.10-0.30 | RTL | 8 | 32768 | - | - | - | PASS | controlled | packet_scheduler/model/rtl_sim/plots/time_merger_boundary_nlane04.png | 2026-04-29 | Re-rendered time-merger first-loss boundary plot; DISLIN Warnings: 0. Post-inspection passed: legend is boxed because vertical markers cross the legend region, and source-loss / 80% margin / ideal-knee marker order follows the plotted vertical sequence. |
| TXN-MATCH-RTL-TLM | IN_PROGRESS | TLM+RTL | both | 4 | 1 | sweep | knee-zoom | AT+LT | directed+soak | TBD | - | - | - | IN_PROGRESS | mixed | packet_scheduler/model/rtl_sim/data/opq_transaction_match.csv | 2026-04-28 | Exact RTL pin/UVM transaction extraction passes OPQ and time-merger directed gates, including OPQ skew-stress after ticket RAW fix. LEVEL3-HPC-SCAN128 completed the collective LT scan; remaining work is OPQ structural TLM ID replay and zoomed first-loss RTL/TLM matching around the knee. |
| TXN-TM-PER-SUBFRAME-BASIC | PASS | TLM+RTL | time_merger | 4 | 1 | 0 | 0.1 | AT | 1 | 64 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/time_merger_transaction_match.csv | 2026-04-28 | Directed time-merger RTL trace + structural TLM IDs match offer/source-accept/ingress-pin/deliver by frame:subheader bucket; deliver order is relaxed only inside bucket due to round-robin data arbitration. |
| TXN-TM-SOURCE-QUEUE-BOUNDARY | PASS | TLM+RTL | time_merger | 4 | 1 | 0 | 0.1 | AT | 1 | 32 | 1 | 1 | 0 | PASS | controlled | packet_scheduler/model/rtl_sim/data/time_merger_transaction_match.csv | 2026-04-28 | Forced source-queue boundary with queue_depth=8 and frame_words=12: every offered hit is source-dropped, zero ingress-pin accepts, zero delivered, exact TLM/RTL transaction ID match. |
| TXN-OPQ-UVM-PER-SUBFRAME-BASIC | PASS | RTL | opq | 4 | 1 | 0 | smoke | UVM | 1 | 8 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/opq_transaction_match.csv | 2026-04-28 | OPQ UVM scoreboard OPQ_TXN trace passes: 8 offered, 8 ingress-accepted, 0 controlled drops, 8 delivered; checked by pkg/bucket/timestamp/word identity. |
| TXN-TM-MULTI-PACKET-BASIC | PASS | TLM+RTL | time_merger | 4 | 1 | 0 | 0.1 | AT | 3 | 480 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/time_merger_transaction_match.csv | 2026-04-28 | Time-merger exact transaction gate now includes multi-packet and backpressure-drain directed cases: 480-hit multi-packet and 128-hit ready 3/1 both pass with zero missing/extra/bucket mismatch; source-queue boundary remains separately controlled. |
| TXN-OPQ-ALIGNED-MULTIFRAME | PASS | RTL | opq | 4 | 1 | 0 | aligned | UVM | 1 | 128 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/opq_transaction_match_profile1_multiframe.csv | 2026-04-28 | OPQ aligned DRR-saturation multi-frame exact gate passed: 4 frames x 4 subheaders x 2 hits x 4 lanes = 128 offered/accepted/delivered, exact lane+bucket identity, no controlled drops. |
| TXN-OPQ-PHYSICAL-SCIFI-ANCHOR | PASS | RTL | opq | 4 | 1 | 0.403 | 0.60 | UVM-physical-cadence | 1 | 160 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/opq_transaction_match_profile3_anchor.csv | 2026-04-28 | Physical timestamp-burst SciFi anchor passed exact OPQ transaction check: independent lanes, noise rho 0.10 + cluster rho 0.50, cluster size 4-8, 4 frames x 16 subheaders, 160 offered/accepted/delivered with exact lane+bucket identity. |
| TXN-OPQ-WHOLE-FRAME-SKEW-RTL-BUG | PASS | RTL | opq | 4 | 1 | 0 | skew-stress | UVM | 1 | 32 | 0 | 0 | 0 | PASS | - | packet_scheduler/model/rtl_sim/data/opq_transaction_match.csv | 2026-04-28 | Fixed ticket-read RAW alignment: staged ticket data is now validated against a FIFO_RAW_DELAY-aligned read pointer; OPQ skew stress passes 32 offered/accepted/delivered, zero controlled/inferred loss. |
| LEVEL3-HPC-SCAN128 | PASS | TLM | both | 4 | 1 | sweep | 0.1-8.0_hps | LT-high-performance | 128 | 1000000 | 0.8326977396500924 | - | - | PASS | mixed | packet_scheduler/model/tlm/data/tlm_high_perf_collective_scan128.csv | 2026-04-30 | Level-3 collective scan rerun under Mu3e Demo metadata/profile: lane FIFO=2048, ticket FIFO=1024, handle FIFO=256, page RAM=65536, event-queue capacity=2048. OPQ total dropped=245372/128M, max loss=0.0306825; time-merger total dropped=26140582/128M, max loss=0.832698. |
| DISLIN-TLM-REFRESH | PASS | plotting | both | 4/8/16 | 1/2/4/8 | sweep | sweep | n/a | all | - | - | - | - | PASS | - | packet_scheduler/model/tlm/plots/opq_vs_time_merger_loss_contour_nlane08_egress08x.png | 2026-04-30 | Regenerated TLM and DISLIN plot families after Mu3e Demo preset/default update. DISLIN 11.5.2 completed all plot renders with Warnings: 0; plot data now reports OPQ capacity/profile as Mu3e Demo. |
| DISLIN-TM-LOSS-SURFACE | PASS | plotting | time_merger | 4/8/16 | 1/2/4/8 | sweep | sweep | n/a | 12x2 | - | - | - | - | PASS | - | packet_scheduler/model/tlm/plots/time_merger_loss_surface_nlane04_egress01x.png | 2026-04-28 | Generated standalone time-merger loss-surface DISLIN plot family for TLM and analytical models; N=4 E=1 visually inspected, modeling gate box moved upper-left for TM surfaces so it does not cover the knee or contour labels; DISLIN Warnings: 0. |
| DISLIN-RANGE-BFULL-RHO01 | PASS | plotting | both | 4/8/16 | 1/2/4/8 | -1..1 | 0..1_share | n/a | all | - | - | - | - | PASS | - | packet_scheduler/model/tlm/plots/opq_vs_time_merger_loss_contour_nlane08_egress08x.png | 2026-04-29 | TLM and analytical DISLIN families regenerated with B axis -1..1 and normalized per-lane throughput share axis 0..1 for loss surfaces, contour overlays, and loss curves. DISLIN Warnings: 0; labels/notes distinguish raw OPQ rho_lane from normalized plotted share. |
| RTL-OPQ-HANDLE-CREDIT-GATE | PASS | RTL | opq | 4 | 1 | 0 | 6.0_hps | UVM-physical-cadence | 1 | 12557 | 0 | 0 | 0 | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/model_publish_sweep_debug_fix5_sva_on/logs/scan128_b000_rho6000.log | 2026-04-28 | Raw Questa/UVM with TB SVA enabled passes after OPQ page-allocator rebase and handle-FIFO credit gate: accepted=delivered=12557, controlled drops=0, unexplained=0, UVM_ERROR=0. This removes the local DEBUG caveat for the directed rho=6 packet identity gate; boundary sweep remains separate. |
| BOUNDARY-RTL-OPQ-PHYSICAL-RHO01-06 | PASS | RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.10-0.60 | UVM-physical-cadence | 20 | 3181-19735 | 0 | 0 | 0 | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/model_publish_sweep_fix7_boundary_rho01_06_sva_on | 2026-04-28 | Boundary/knee zoom in the plot-domain range passed all 20 raw UVM runs with SVA on: accepted=delivered for every point; controlled, asserted, and inferred loss counts are all zero. This replaces the obsolete zero-gap boundary for low-rho physical cadence evidence. |
| BOUNDARY-RTL-OPQ-MARGINAL-F100 | PASS | RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.60-1.00 | UVM-physical-cadence | 39 | 30186-51718 | - | - | - | PASS | controlled | packet_scheduler/model/rtl_sim/data/RTL-LS-002_marginal_loss_zoom_f100.csv | 2026-04-28 | 100-frame knee zoom passed UVM with SVA on; all rows have unexplained=0 and loss tier is controlled. First-loss brackets: B=0 and B=0.403 clean at rho=0.72/loss at 0.75; B=0.700 clean at 0.68/loss at 0.70. |
| MATCH-OPQ-MARGINAL-F100-TLM | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.60-1.00 | AT-structural | 39 | 30186-51718 | 0.015434109090428659 | 0.016967346857886496 | 0.0993409 | DEBUG | controlled | packet_scheduler/model/rtl_sim/data/opq_structural_tlm_marginal_loss_zoom_f100.csv | 2026-04-29 | Tail-dropped SOP semantics fixed against RTL: partial-tail frames now open/load body path; all-tail frames age into allocator late-drop. 39-point zoom: 24 exact drop-count rows, 37/39 within 20%, aggregate TLM/RTL drops 23364/25685 rel=9.93%; worst residual B=0 rho=1.0 in high-loss page-residency/drain region. Directed B=0 rho=0.8 is 704 vs 715 with serial95 lane0 exact and lane1-3 equal/opposite pre/post deltas. |
| DISLIN-OPQ-MARGINAL-F100-ZOOM | PASS | plotting | opq | 4 | 1 | 0/0.403/0.700 | 0.60-1.00 | AT+RTL | 39 | 30186-51718 | - | - | - | PASS | controlled | packet_scheduler/model/rtl_sim/plots/opq_marginal_loss_zoom_f100_nlane04_egress01x.png | 2026-04-29 | Re-rendered after tail-dropped SOP structural TLM fix; DISLIN Warnings: 0. Post-inspection passed: boxed legend clear of grid/curves, solid RTL/dash TLM mapping readable, B legend ordered by plotted curve position. Plot now shows tight knee match and remaining high-rho B=0 residual. |
| NIGHTLY-RTL-SCAN128-20260428 | IN_PROGRESS | RTL | opq | 4 | 1 | 0/0.1/0.2/0.3/0.403/0.5/0.6/0.7 | 0.1-8.0_hps | UVM-physical-cadence | 128 | 1000000 | - | - | - | IN_PROGRESS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/nightly_scan128_20260428 | 2026-04-29 | Detached PID 5126 remains live. 121 stdout logs/case dirs exist. High-rho WARN rows retained as failing evidence; resume remains enabled. |
| RTL-OPQ-B700-RHO0640-CREDIT-TRACE | PASS | RTL | opq | 4 | 1 | 0.700 | 0.64 | UVM-physical-cadence | 1 | 33735 | - | 0 | - | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/debug_b700_rho0640_credit/logs/opq_model_publish_loss_sweep_test.log | 2026-04-29 | Focused credit trace PASS: expected=accepted=delivered=33735, controlled/asserted/inferred loss all zero. At ts=0x317d0 RTL had lane1 credit=188 and accepted the 17-hit subheader; the old TLM false drop at credit=3 was isolated to frame-open/allocator timing, not burst generation. |
| RTL-OPQ-B403-RHO0750-CREDIT-TRACE | PASS | RTL | opq | 4 | 1 | 0.403 | 0.75 | UVM-physical-cadence | 1 | 38524 | - | 0.00210258540131 | - | PASS | controlled | packet_scheduler/model/rtl_sim/runs/debug_b403_rho0750_credit/logs/marginal_b403_rho0750_f100_period4096.log | 2026-04-29 | Focused credit trace PASS with UVM_ERROR=0: RTL controlled drops=81, delivered=38443, unexplained=0. Drop events are pre-credit drops in frame 99; lane0 reaches credit=4 at ts=0x321e0 while allocator is still processing running_ts=0x28140, proving the remaining TLM gap is allocator IDLE/fetch/ingress-busy lag rather than generator or loss-tier accounting. |
| RTL-OPQ-B000-RHO0750-CREDIT-TRACE | PASS | RTL | opq | 4 | 1 | 0 | 0.75 | UVM-physical-cadence | 1 | 38420 | - | 0.0013534617387 | - | - | controlled | packet_scheduler/model/rtl_sim/runs/model_publish_sweep_fix10_trace_credit_b000_rho0750/marginal_b000_rho0750_f100_period4096/logs/opq_model_publish_loss_sweep_test.log | 2026-04-29 | Focused credit trace PASS with UVM_ERROR=0: expected=38420 accepted=delivered=38368 controlled drops=52 all on lane1. First controlled pre-drop is lane1 serial=95 ts=0x307c0 with RTL lane credit=1; the same generated TLM transaction has lane_credit_before about 153 and no drop, proving offered stream identity matches and the remaining gap is credit-return/allocation structure. |
| TLM-OPQ-MARGINAL-RULEOUTS | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.72-1.00 | AT-structural | focused | 30186-51718 | - | - | - | - | controlled | packet_scheduler/model/tlm/scripts/opq_structural_tlm.py | 2026-04-29 | Earlier scalar probes were ruled out. The productive fix is structural: model parser tail status, partial-tail SOP frame open, and all-tail frame skip/late-drop separately. This closes the level-2 knee cases to 1.25-5.56% on focused points; remaining DEBUG is high-rho B=0 page-residency/drain and pre/post classification drift, not generator identity. |
| RTL-OPQ-STAGE-CORRELATION-F100 | PASS | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | knee-zoom | AT+UVM | 4 | 35967-41031 | 0.005265097836 | 0.005338532222 | 0.0139474 | PASS | controlled | packet_scheduler/model/rtl_sim/data/stage_trace | 2026-04-29 | Stage reducer now records RTL controlled pre-drop and controlled allocator post-drop maps by serial/lane plus TLM maps. Focus points: B0/rho0.75 51 vs 52, B0/rho0.80 704 vs 715, B0.403/rho0.75 80 vs 81, B0.700/rho0.70 18 vs 17. B0/rho0.80 mismatch localizes to allocator tail-late-drop classification: serial95 lane0 exact, lane1-3 pre/post deltas cancel in total. |
| COMP-REPLAY-OPQ-100K-SEEDS | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.70/0.75/0.80 | UVM+AT-component | 12 | 100000 | - | - | - | DEBUG | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/data/opq_component_replay_100k_ingress_rereduced_report.md | 2026-04-29 | Re-reduced 12x100k component logs after PA body_serial hex parse fix. Ingress source identity PASS 12/12. Collective loss PASS 1/12; ticket/drop PASS 3/12; frame-table hit/LOAD PASS 1/12. LATE_DROP remains DEBUG 12/12: mean discrepancy 39.5%, best 3.16%, worst 61.8%. |
| COMP-REPLAY-OPQ-STANDALONE | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.70-0.80 | AT-component | focused | 100frames-100k | - | - | - | DEBUG | controlled/inferred | packet_scheduler/model/rtl_sim/data/opq_component_replay_100k_ingress_seed7101_pa_action.csv | 2026-04-29 | Seed7101 after current TLM patch: source identity PASS; LOAD 58090 RTL vs 61895 TLM; LATE_DROP 6844 RTL vs 3739 TLM. First localized blocker is frame137: RTL ingress controlled pre-drops then allocator late-drops remaining body; TLM still loads that frame. RTL tail-status injection proves source stream is clean but page-allocator tail/body retire semantics remain DEBUG. |
| COMP-REPLAY-OPQ-LATE-CANDIDATE | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.70/0.75/0.80 | AT-component | 12 | 100000 | - | - | - | DEBUG | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/data/opq_component_replay_100k_ingress_late_candidate_report.md | 2026-04-29 | Candidate TLM adds separate timestamp-slot/emitted-subheader accounting, RTL tail-flush close semantics, accepted-subheader mover blocking, and calibrated small handle startup. It nearly closes one B=0/rho=0.75 seed for LATE_DROP (RTL 6844, TLM 6774, 1.02%) but does not generalize: source identity PASS 12/12, LATE_DROP mean discrepancy 47.1%, LOAD/frame-hit mean 8.84%, collective mean 13.85%. Keep DEBUG; the next blocker is lane-credit/frame-ownership divergence upstream of LATE_DROP, not the hit generator. |
| COMP-REPLAY-OPQ-LONG-DRAIN-CHECK | DEBUG | RTL | opq | 4 | 1 | 0 | 0.75 | UVM-component | 1 | 100000 | - | - | - | DEBUG | inferred | packet_scheduler/model/rtl_sim/runs/component_replay_100k_ingress_longdrain_20260429 | 2026-04-29 | Re-ran seed7101 with 200 ms requested drain timeout. RTL counters were unchanged from the original 100k run: accepted=61258, dropped=39339, delivered=55536, unexplained=5838, frame table wr/rd hit=58090. This rules out simple drain-time extension as the reason for the component mismatch; residual unexplained hits are a monitor/accounting issue for this failing evidence row. |
| COMP-REPLAY-OPQ-PARSER-TICKET-12RUN | PASS | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.70/0.75/0.80 | AT-component | 12 | 100000 | - | - | - | PASS | controlled/asserted | packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_closure_report.md | 2026-04-29 | Calibrated parser-ticket component closure has 127/127 PASS rows across 12 runs. Parser FIFO, handle FIFO, mover credit return, PA LOAD, PA LATE_DROP, PA local loss, frame-table subheader/hit ledgers, transaction bucket order, and word identity are exact. Header-only diagnostic residual is marked NOT_CHECKED in JSON and filtered out of the hit-bearing closure CSV. |
| COMP-REPLAY-OPQ-INDEPENDENT-PA-TAIL | DEBUG | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.70/0.75/0.80 | AT-component | 12 | 100000 | - | - | - | DEBUG | asserted | packet_scheduler/model/rtl_sim/data/opq_component_replay_parser_ticket_100k_12run_localpa_report.md | 2026-04-29 | Parser-tail bypass is a producer-side tail-status write, not an exact loss boundary. Seed7101 100k: parser-tail drop candidates 455, PA-local LATE_DROP tail frames 241, missing PA frames 0, extra candidates 214. Keep independent predictor DEBUG; PA-local LATE_DROP hook is exact for component handoff. |
| TLM-OPQ-SERVICE-SCALE-RIDGE | PASS | TLM | opq | 4 | 1 | 0/0.4/0.7 | disabled | plot-domain | 1 | 8192 cycles | - | - | - | PASS | controlled | packet_scheduler/model/tlm/data/tlm_model_summary.json | 2026-04-29 | Closed as obsolete: scalar opq_service_scale is now disabled in opq_tlm_feature_sweep.py. OPQ RTL matching must use structural FIFO/credit/allocator TLM and real RTL pins, not service-scale tuning. |
| DISLIN-OPQ-N4E1-RIDGE-PINS-HIRES | PASS | plotting | opq | 4 | 1 | -1..1 | 0..1_share | n/a | 6 | 100 frames | - | - | - | PASS | controlled | packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png | 2026-04-29 | Superseded old 12-run marginal pins for this plot pass. Current high-res PNG uses corrected normalized-share RTL pins: 5 shallow clean points around share 0.23-0.27 and one 100k controlled-loss point at share 0.30. DISLIN Warnings: 0. |
| RTL-OPQ-N4E1-NORMALIZED-SHARE-SCAN | PASS | RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.23-0.30_share | UVM-physical-cadence | 6 | 10k-100k | - | 0.3396799010 | - | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/data/opq_normalized_share_scan_n4_e1_report.md | 2026-04-29 | Corrected real RTL/UVM normalized-share scan after fixing lane FIFO depth contract to 8192 for N_SHD=128,N_LANE=4. False below-knee controlled loss from old 2048-depth contract is invalidated. Corrected pins are clean at share 0.23/0.25/0.27 shallow and show controlled loss 33.97% at share 0.30 with 100k hits; long matrix still needs rerun. |
| DISLIN-OPQ-N4E1-NORMALIZED-AXIS | PASS | plotting | opq | 4 | 1 | -1..1 | 0..1_share | n/a | 6 | 100 frames + shallow/100k probes | - | - | - | PASS | controlled | packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png | 2026-04-29 | Regenerated at 4096x2896 after corrected real RTL normalized-share scan. Pin priority now uses opq_normalized_share_scan_n4_e1_pins.csv before obsolete marginal pins; labels show clean below-knee points and the 100k above-knee controlled-loss point. Plot now includes the OPQ persistent-knee line and corrected RTL/TLM evidence box. DISLIN Warnings: 0; visual post-inspection passed. |
| RTL-OPQ-LFIFO-CONTRACT | PASS | RTL | opq | 4 | 1 | 0 | 6.0_hps | UVM-physical-cadence | 5 | 24497-49211 | 0 | 0 | 0 | PASS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/fix_default_lfifo/logs/fix_default_lfifo_x1_b000_rho6000_f8.log | 2026-04-29 | Fixed OPQ lane FIFO depth contract from lane-count-only 2048 to geometry-derived 8192 for N_SHD=128,N_LANE=4. Directed UVM: depth2048 loses 5436/24497 at rho=6; corrected default depth8192 has 0 drops at rho=6 f8 and rho=6/7.5/8 f12 explicit-depth probes. Earlier normalized-share contour pins below persistent knee were invalid under the old FIFO contract. |
| MATCH-OPQ-N4E1-LFIFO-STRUCT-TLM | PASS | TLM+RTL | opq | 4 | 1 | 0/0.403/0.700 | 0.23-0.30_share | AT-structural | 6 | 10k-100k | 0.338094869911 | 0.339679901032 | 0.00468813 | PASS | controlled | packet_scheduler/model/rtl_sim/data/opq_structural_tlm_normalized_share_n4_e1.csv | 2026-04-29 | Structural OPQ TLM replay of corrected normalized-share RTL pins. Explicit lane FIFO/ticket FIFO/handle FIFO/allocator/DRR/presenter model matches all clean rows exactly and the 100k above-knee point within 0.47% drop-count error (34982 TLM vs 35146 RTL), without scalar service scaling. |
| NIGHTLY-RTL-OPQ-N4E1-NORMALIZED-FULLSCAN | IN_PROGRESS | RTL+TLM | opq | 4 | 1 | 0/0.1/0.2/0.3/0.403/0.5/0.7/0.9 | 0.18-0.40_share | UVM-physical-cadence + AT-structural | 128 | 10k shallow, 1e6 deep loss rows | - | - | - | IN_PROGRESS | controlled/asserted/inferred | packet_scheduler/model/rtl_sim/runs/opq_normalized_share_fullscan_20260429/fullscan.meta | 2026-04-29 | Detached PID 26185 normalized-share full scan launched with corrected FIFO=8192 and resume enabled. Grid is concentrated around the expected N4/E1 persistent knee at normalized share about 0.242, with scatter to 0.18 and 0.40. RTL CSV target: opq_normalized_share_fullscan_n4_e1.csv; structural TLM replay target: opq_structural_tlm_normalized_share_fullscan_n4_e1.csv. |
| TLM-MU3E-DEMO-PRESET | PASS | TLM | opq | 4 | 1 | sweep | 0..1_share | AT+LT | all | 8192 cycles + 1e6 LT | - | - | - | PASS | controlled | packet_scheduler/model/tlm/data/tlm_model_summary.json | 2026-04-30 | Mu3e Demo profile installed as TLM baseline: N_LANE=4, N_SHD=128, lane FIFO=2048, ticket FIFO=1024, handle FIFO=256, page RAM=65536. Coarse event-grid capacity now defaults to 2048; structural AT TLM has an explicit --mu3e-demo-profile override. |
| TLM-STRUCT-MU3E-DEMO-OVERRIDE | PASS | TLM | opq | 4 | 1 | 0/0.403/0.700 | 0.23-0.30_share | AT-structural | 6 | 10k-100k | - | - | - | PASS | controlled | packet_scheduler/model/rtl_sim/data/opq_structural_tlm_mu3e_demo_profile_n4_e1.csv | 2026-04-30 | Structural AT TLM replay with --mu3e-demo-profile forced all rows to lane FIFO=2048, ticket FIFO=1024, handle FIFO=256, page RAM=65536. This is a TLM-profile sanity run over older normalized-share stimuli, not an RTL-match closure row; forced profile predicts earlier finite-buffer loss than previous deeper-depth RTL rows. |
| DISLIN-RTA-SCIFI-ANCHOR | PASS | plotting | opq | 4 | 1 | 0.424685 | 0.175_share | n/a | 6 pins + anchor | - | - | - | - | - | controlled | packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png | 2026-04-30 | N4/E1 plot pins now label R/T/A = RTL/TLM/Analytical loss. SciFi anchor recalibrated to data=0.6*0.25=0.150 plus noise=0.1*0.25=0.025, total share=0.175, and drawn as a filled dot distinct from scan crosses. DISLIN Warnings: 0. |
<!-- SCOREBOARD:END -->

## Active OPQ Preset

The active TLM/IP-packaging comparison preset is `Mu3e Demo`.

| field | value |
|---|---:|
| `N_LANE` | 4 |
| `N_SHD` | 128 |
| `LANE_FIFO_DEPTH` | 2048 |
| `TICKET_FIFO_DEPTH` | 1024 |
| `HANDLE_FIFO_DEPTH` | 256 |
| `PAGE_RAM_DEPTH` | 65536 |

`packet_scheduler/script/ordered_priority_queue_hw.tcl` exposes this as the
default representative preset. The coarse TLM loss surface uses
`LANE_FIFO_DEPTH` as the finite OPQ capacity. The structural AT TLM models lane
FIFO, ticket FIFO, handle FIFO, and page RAM separately and can force this
profile with `--mu3e-demo-profile` when replaying older CSV stimuli that contain
different per-row depth fields.

## Burstiness Definition

The model axis `B` must follow the Goh-Barabasi burstiness parameter for
discrete event streams. The source event is one hit, not one packet, one
subheader, or one RTL accept pulse.

Source reference:

- K.-I. Goh and A.-L. Barabasi, "Burstiness and Memory in Complex Systems",
  arXiv:physics/0610233 / EPL 81 (2008) 48002,
  https://arxiv.org/abs/physics/0610233.

For each lane:

1. Sort all hits by the true physical generation timestamp.
2. Build interevent times `tau_i = t_i - t_{i-1}` from consecutive hits.
3. Preserve zero interevent times. A physical particle cluster with 4-8 hits
   at the same timestamp contributes repeated `tau_i = 0` entries.
4. Compute `m_tau = mean(tau_i)` and `sigma_tau = stddev(tau_i)`.
5. Define burstiness as:

`B = ((sigma_tau / m_tau) - 1) / ((sigma_tau / m_tau) + 1)`

equivalently:

`B = (sigma_tau - m_tau) / (sigma_tau + m_tau)`

This gives `B = 0` for an exponential interevent-time distribution from a
Poisson source, `B < 0` for regular/anti-bursty streams, and `B > 0` for
bursty streams. The axis range remains bounded by `-1 < B < 1` for finite
positive `m_tau` and `sigma_tau`.

Do not use the older repo shortcut:

`B = (SCV_tau - 1) / (SCV_tau + 1)`

If the implementation works with squared coefficient of variation
`SCV_tau = (sigma_tau / m_tau)^2`, first convert back to coefficient of
variation:

`CV_tau = sqrt(SCV_tau)`

then:

`B = (CV_tau - 1) / (CV_tau + 1)`

and the inverse used by traffic generators is:

`CV_tau = (1 + B) / (1 - B)`

`SCV_tau = ((1 + B) / (1 - B))^2`

## SciFi Anchor

For the SciFi lane anchor, each lane is the aggregate of 128 iid noise
channels plus a physical-particle source:

- Noise: iid Poisson per channel, aggregated at the lane.
- Physical particle source: Poisson in true generation time.
- Physical cluster: each particle produces 4-8 hits at the same timestamp.
- Anchor point in normalized per-lane throughput-share units:
  `rho_noise = 0.10 * 0.25 = 0.025`,
  `rho_cluster = 0.60 * 0.25 = 0.150`, and
  `rho_total = 0.175`.
- Phase-1 correlation scope: lanes are independent. No physical-particle burst
  is shared across lanes in this phase; cross-lane-correlated bursts are a
  future model mode and must have separate scoreboard rows.

The anchor point must be derived from generated hit timestamps using the `B`
definition above. Plot annotations and CSVs should label it as a timestamp
sample point, not as a fitted queueing-model parameter. In DISLIN plots the
SciFi anchor uses a filled dot; cross markers are reserved for scan/sample pins.

## Frame Cadence Contract

Do not use zero inter-frame gap for physical OPQ Poisson points. Zero gap is a
synthetic stress mode only.

For the current OPQ RTL timestamp contract:

- FEB header timestamp tick: `8 ns`.
- Subheader timestamp step: `16` FEB timestamp ticks.
- Frame timestamp step: `frame_ts_step_ticks = N_SHD * 16`.
- UVM/SWB clock: `4 ns`.
- Physical frame-launch period in UVM cycles:
  `frame_launch_period_cycles = frame_ts_step_ticks * 8 ns / 4 ns`.
- For `N_SHD=128`: `frame_ts_step_ticks = 2048` and
  `frame_launch_period_cycles = 4096`.
- Virtual FEB dispatch latency:
  `ingress_debug_ts = frame_ts[30:0] + 4096`.

The UVM timestamp-burst profile must schedule every lane frame header at this
fixed launch cadence. The frame body length must not stretch the next frame
header launch; if a frame body would exceed the physical period, the test must
report that explicitly as a source-side overrun rather than silently increasing
the frame period.

## Rate Units Contract

The symbol `rho` is not enough by itself. Every CSV, plot, scoreboard row, and
debug note must report a `rho_unit` field next to the value.

For physical-cadence OPQ rows:

- `rho_lane` is the Poisson mean hit count per subheader per lane.
- `rho_ppm` is `rho_lane * 1e6` for integer plusarg transport.
- Example: `rho_ppm=6000000` means `rho_lane=6.0` hits/subheader/lane. It is
  not 6 percent.
- `normalized_share_lane` is the plotted normalized per-lane throughput share:
  `rho_lane * N_SHD / (frame_launch_period_cycles * egress_symbols_per_beat)`.
- With `N_SHD=128`, `frame_launch_period_cycles=4096`, and `Egress=1x`,
  `normalized_share_lane = rho_lane / 32`. Thus `rho_lane=0.75` plots at
  `0.0234375`, while `rho_lane=8.0` plots at `0.25`.
- For `N_LANE=4`, `Egress=1x`, the ideal persistent 4:1 output-bandwidth knee
  is `normalized_share_lane=0.25` per lane. If real RTL loss appears below this
  value, classify it as finite OPQ admission/window behavior until the
  frame-table, presenter, credit, and allocator evidence proves otherwise.

For the current old time-merger reference sweep:

- `rho` is normalized hit-word demand per cycle per lane.
- Example: `rho=0.3` means `0.3` hit words/cycle/lane, or 30 percent of a
  one-hit-word-per-cycle lane source.
- This is not the same unit as OPQ `rho_lane`; conversion requires the selected
  `subheaders`, `hits_per_subheader`, and generated frame gap.

Plots may use a shorter axis label only if the caption or source CSV states the
full unit. Mixed OPQ/time-merger plots must not share one unlabeled rho axis.

## Loss Observability Contract

OPQ and time-merger loss are not observed through the same mechanism.
This plan follows the Codex `rtl-modeling` skill evidence ladder:

1. `controlled`: RTL intentionally drops/rejects and exposes the event through
   a CSR, drop monitor, counter, or explicit sideband. This is preferred for
   signoff.
2. `asserted`: debug or formal logic catches a local dark loss, such as FIFO
   overwrite or valid-data replacement before handshake, and reports enough
   hit metadata to correlate with the scoreboard.
3. `inferred`: the end-to-end scoreboard offered a hit and did not see it after
   the run drained. This is a symptom and should remain debug-stage evidence
   unless controlled/asserted observability is unavailable and waived.

For OPQ:

- Loss is a controlled datapath decision and must be visible in RTL simulation
  through drop monitor / CSR-style counters.
- Evidence must keep `expected_hits`, `accepted_hits`, `dropped_hits`,
  `delivered_hits`, lane pre-drop hits, lane post-drop hits, and frame-table
  drop counters separate.
- A valid OPQ first-loss claim must state which boundary fired: persistent
  egress bandwidth, lane ingress FIFO/source serialization, ticket credit,
  merged-frame hit room, page residency, or drain/observation timeout.
- OPQ should not be declared lossy under iid Poisson traffic until the summed
  long-term ingress demand exceeds the effective egress bandwidth, unless the
  row is explicitly labeled as an ingress FIFO/source-frame boundary.

For the old time-merger reference:

- Loss is a dark drop from the model point of view. The tree has no equivalent
  OPQ CSR/drop monitor, so the first observable is inferred: offered hits minus
  delivered hits after a bounded drain window.
- If the TB reports `accepted_hit_count == delivered_hit_count`, the current
  probe has no residual accepted-hit dark drop. Any offered-minus-accepted delta
  is source/admission loss caused by backpressure, and must be reported
  separately as `source_queue_drop_hit_count`.
- The TLM/RTL comparison must track missing hit identity and delivered-hit
  order. A cycle timestamp may drift during AT calibration, but delivered hits
  may not reorder.
- Low-level debug should add asserted-loss hooks at the stage FIFO and merger
  boundaries: write-while-full, overwrite, valid data replaced before
  handshake, enqueue/dequeue imbalance, and HoL stall with queued data behind
  the blocked head word. Assertion messages should include lane, stage, FIFO
  index, frame/timestamp, subheader, hit index, sequence, and overwritten
  old/new metadata where possible.
- Tree depth is itself a stress dimension. Higher depth adds more stage FIFOs
  and more points where structural-role mismatch can hold a queue behind a
  blocked head word. This is head-of-line blocking, like a packet switch with
  staged queues.
- Time-merger is therefore expected to lose much earlier than OPQ for the same
  offered lane stream when the traffic creates enough role mismatch or queue
  hold-up across the merge tree. Do not tune OPQ loss thresholds to explain
  time-merger dark drops.

Every scoreboard row that claims loss must fill `loss tier` as `controlled`,
`asserted`, `inferred`, or `mixed`. `mixed` means controlled/asserted local
events explain the inferred end-to-end missing-hit count.

Every run summary that claims loss, including DEBUG rows, must also report:

- offered or expected hit count;
- accepted hit count, if the interface has a distinct accept point;
- delivered hit count after drain;
- source/admission drop count when the source queue rejects complete frames;
- controlled loss hit count;
- asserted loss hit count;
- inferred end-to-end missing hit count after drain;
- per-tier loss probability where the denominator is offered or expected hits;
- drain policy and timeout;
- `rho_unit`, link utilization, hits/subheader/lane, the expected
  persistent-bottleneck knee, and whether the sample is below or above that
  knee.

## Transaction-Level Match Contract

Aggregate loss curves are not enough to close OPQ/time-merger TLM matching.
RTL pin-level or UVM monitor transactions are the DUT truth. The TLM must
compare against those extracted transactions object by object.

Required transaction key:

- lane/source;
- frame;
- subframe or subheader bucket;
- true generation timestamp;
- hit index or sequence;
- payload when available;
- accept/drop/deliver state;
- RTL observation cycle.

For AT comparisons, the TLM must put every delivered hit in the same
frame/subframe bucket as RTL. Cycle timing may drift within a bounded tolerance,
and hit order inside one bucket may differ only when RTL arbitration makes that
order non-contractual. For LT comparisons of OPQ and time-merger, the same
bucket and count rules still apply; LT relaxes cycle time, not transaction
identity.

Use the boundary as the calibration surface:

1. Run coarse sweeps to bracket the knee.
2. Zoom around the first-loss edge.
3. Match RTL and TLM through the first lost hit/frame by transaction ID and
   bucket.
4. Classify the first loss by tier and root cause.
5. Only then run broad 128-point or million-hit scans.

The model build-up should use the UVM/directed RTL environment as the reference
and swap one structure at a time in the comparison: FIFO, credit manager,
allocator, page/frame table, arbiter, presenter, merger node, and source queue.
Maintain one external transaction scoreboard while swapping internals.

Network-simulator reference check: keep the TLM at packet/hit-transaction level.
The ns-3 queue-disc model uses explicit internal queues, classes/filters,
enqueue/dequeue/drop traces, and device-queue flow-control/requeue behavior.
Use that as the minimum abstraction level here: every OPQ/time-merger modeled
queue, credit gate, arbiter decision, and controlled/asserted drop must have a
traceable transaction counterpart before aggregate loss curves are trusted.

Checkpoint levels:

1. Per-subframe basic: small directed frames with exact bucket counts.
2. Zoomed edge subframe statistics: first-loss boundary with local counters.
3. High-performance collective: soak and broad scans once the first two levels
   match.

## Current Transaction Checkpoint Evidence

The first implemented transaction gates are intentionally small. They prove
that the monitors and parsers preserve object identity before any broad loss
surface is trusted.

- Time-merger directed gate:
  `packet_scheduler/model/rtl_sim/scripts/run_time_merger_transaction_check.py`
  runs `+OLD_TM_TRACE_TXN=1` and emits
  `packet_scheduler/model/rtl_sim/data/time_merger_transaction_match.csv`.
  The `tm_txn_per_subframe_basic` case matched 64 offered/source-accepted/
  ingress-accepted/delivered hit IDs with zero bucket mismatch. Delivered
  order differed inside a subheader bucket only under the round-robin data
  arbitration rule. The `tm_txn_source_queue_boundary` case forced
  `queue_depth=8 < frame_words=12`; all 32 offered hits were source-dropped,
  with zero ingress accepts and zero delivered hits. The current multi-packet
  additions also pass: 480 hits across five frames and 128 hits with periodic
  egress-ready backpressure both preserve frame/subheader bucket identity and
  object counts.
- OPQ UVM gate:
  `packet_scheduler/tb/uvm/opq_scoreboard.sv` now has an opt-in
  `+OPQ_TRACE_TXN` path that emits source offer, ingress accept,
  controlled-drop, and deliver transaction lines from the UVM/DUT monitor
  surface. `packet_scheduler/model/rtl_sim/scripts/check_opq_transaction_trace.py`
  reduces the UVM traces into CSV/JSON rows. Current passing gates are:
  smoke/FEB packet contract/single-lane multi-packet in
  `packet_scheduler/model/rtl_sim/data/opq_transaction_match.csv`, aligned
  4-lane multi-frame exact identity in
  `packet_scheduler/model/rtl_sim/data/opq_transaction_match_profile1_multiframe.csv`,
  and the physical timestamp-burst SciFi anchor in
  `packet_scheduler/model/rtl_sim/data/opq_transaction_match_profile3_anchor.csv`.
  The physical anchor uses independent lanes with noise rho 0.10, cluster rho
  0.50, cluster size 4-8, and 4096-cycle frame cadence; it delivered all 160
  accepted hits with exact lane/bucket/payload identity.
- OPQ skew-stress debug:
  `TXN-OPQ-WHOLE-FRAME-SKEW-RTL-BUG` is now `PASS`. The root cause was stale
  ticket read data after a lane rptr advance. The page allocator now validates
  ticket data against a `FIFO_RAW_DELAY`-aligned read pointer before acting on
  fetch-pending lanes. The skew-stress UVM gate now passes 32 offered,
  32 ingress-accepted, 0 controlled drops, and 32 delivered hits with exact
  lane/bucket identity.

Remaining transaction gates are tracked as `TXN-MATCH-RTL-TLM` in the
scoreboard: OPQ structural TLM ID replay and zoomed knee/first-loss matching.
The high-performance collective scan is separately tracked as
`LEVEL3-HPC-SCAN128`; it is useful level-3 evidence only because the
per-subframe directed gates and the skew-stress blocker now pass.

## Current High-Performance Collective Evidence

The level-3 LT collective scan is generated by:

```sh
python3 packet_scheduler/model/tlm/scripts/run_high_perf_collective_scan.py
```

Output:

- `packet_scheduler/model/tlm/data/tlm_high_perf_collective_scan128.csv`
- `packet_scheduler/model/tlm/data/tlm_high_perf_collective_scan128_summary.json`

For each implementation, the scan covers 128 points:

- `B = {0.0, 0.1, 0.2, 0.3, 0.403, 0.5, 0.6, 0.7}`;
- `rho = {0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0, 1.2, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0}`
  in hits/subheader/lane;
- `N_LANE=4`, `egress=1x`, `N_SHD=128`, `frame_period_cycles=4096`;
- `1e6` offered hits per point.

The scan charges frame/subheader overhead against the hit service budget:
`effective_hit_service = raw_service - (6 + N_SHD) / frame_period_cycles`.
This moves the OPQ persistent knee to the same physical-cadence value as the
RTL plan:

`rho_lane = (4096 - 134) / (4 * 128) = 7.73828125`

Current result:

- OPQ first drops only at `rho=8.0`, just above the persistent bottleneck
  knee. Max OPQ LT loss in the 128-point scan is `0.03248`.
- Time-merger first drops at `rho=1.5`, above the one-word tree-service knee
  of `1.33828125`. Max time-merger LT loss is `0.83270`.

The raw Questa/UVM `scan128` remains `DEBUG` because a physical-cadence
1e6-hit point is too slow for a full 128-point in-session run. The exact
directed UVM transaction gates remain the RTL truth until batched/accelerated
UVM can replay the full long scan.

## Persistent-Bottleneck Boundary Contract

Use persistent bandwidth math before interpreting high-rate RTL loss.

For physical-cadence OPQ rows with `N_SHD=128`, the frame period is 4096 UVM
cycles. A merged OPQ frame contains approximately:

`6 + 128 + (N_LANE * 128 * rho_lane)` words.

The expected persistent egress knee is:

`rho_lane_knee = (E * frame_period_cycles - (6 + N_SHD)) / (N_LANE * N_SHD)`

For `N_LANE=4`, `egress=1x`, the persistent egress knee is:

`rho_lane = (4096 - 134) / (4 * 128) = 7.73828125`

so iid Poisson rows below this point should drain eventually unless another
explicit resource boundary is reached.

For `N_LANE=4`, `egress=4x`, the egress knee moves to:

`rho_lane = (4 * 4096 - 134) / (4 * 128) = 31.73828125`

but a single ingress lane can only serialize about:

`rho_lane = (4096 - 134) / 128 = 30.953125`

hits per subheader before the source frame no longer fits the physical launch
period. In addition, finite lane FIFO depth can create controlled OPQ drops
earlier than the x4 egress knee if the source frame itself exceeds the lane
credit window. Those rows are ingress-buffer boundary probes, not persistent
egress bottleneck evidence.

For the current old time-merger reference sweep with fixed
`hits_per_subheader`, the ideal persistent-output knee before tree HoL penalty
is:

`rho_knee = (N_SHD * hits_per_subheader) / (6 + N_SHD + N_LANE * N_SHD * hits_per_subheader)`

For `N_LANE=4`, `N_SHD=128`, and `hits_per_subheader=1`, this is:

`rho_knee = 128 / 646 = 0.19814241486068113`

Time-merger loss above that knee can be persistent-bandwidth loss, HoL/tree
loss, source backpressure loss, or a mix. The report must identify which tier
of evidence supports that classification. Loss below the knee is not explained
by persistent output bandwidth and must remain `DEBUG` until localized to a
finite queue, source-frame boundary, assertion, or harness issue.

OPQ should be lossless with margin around 80 percent of the persistent
bottleneck knee. For OPQ `N_LANE=4`, `egress=1x`, this target is:

`0.8 * 7.73828125 = 6.190625 hits/subheader/lane`

The x1 OPQ RTL rows currently violate that expectation, so those rows remain
`DEBUG` and point at lane credit/FIFO restore or harness drain behavior rather
than accepted OPQ model loss.

## Current Time-Merger Failure Analysis

The shallow old time-merger reference sweep now has local debug hooks and
tiered counts in
`packet_scheduler/model/rtl_sim/data/time_merger_ref_loss_sweep.csv`.

For `N_LANE=4`, `N_SHD=128`, `hits_per_subheader=1`, `stage_fifo_depth=128`,
and `queue_depth_words=1024`, the first shallow boundary is:

| rho | link util | merged output util | offered | accepted | delivered | source drop | inferred residual | root cause |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0.1 | 0.100000 | 0.504688 | 32768 | 32768 | 32768 | 0 | 0 | no loss observed |
| 0.15 | 0.149883 | 0.756440 | 32768 | 32768 | 32768 | 0 | 0 | no loss observed |
| 0.18 | 0.179775 | 0.907303 | 32768 | 31232 | 31232 | 1536 | 0 | finite source queue backpressure |
| 0.19 | 0.189911 | 0.958457 | 32768 | 29696 | 29696 | 3072 | 0 | finite source queue backpressure |
| 0.2 | 0.200000 | 1.009375 | 32768 | 28160 | 28160 | 4608 | 0 | persistent output overload |
| 0.3 | 0.299766 | 1.512881 | 32768 | 19456 | 19456 | 13312 | 0 | persistent output overload |
| 0.6 | 0.598131 | 3.018692 | 32768 | 10752 | 10752 | 22016 | 0 | persistent output overload |
| 1.0 | 1.000000 | 5.046875 | 32768 | 7168 | 7168 | 25600 | 0 | persistent output overload |

This shows the time-merger is broken as an architecture before the ideal
persistent-output knee. The ideal knee is `rho=0.198142`, but the finite source
queue already drops at `rho=0.18`, where the average merged output utilization
is only `0.907303`. The source queue reaches about `1015/1024` words, so the
TB rejects complete frame sets before the average egress formula predicts
persistent overload. At `rho=0.3`, the output frame is about
`6 + 128 + 4*128*1 = 646` words and the frame period is 427 cycles, so the
required merged output utilization is `646/427 = 1.51288` on a 1x egress. The
accepted hits still deliver exactly in these probes; the failure is
source/admission loss caused by backpressure.

The current debug hooks report join-wait cycles, role-mismatch cycles,
node-blocked cycles, stage-FIFO full-stall cycles, max FIFO occupancy,
source-dropped frame count, and max source queue occupancy. Deeper HoL-specific
cases should sweep unequal per-lane hit counts or burst-aligned subheaders; the
current equal-`hps=1` case mainly proves the persistent-output overload knee.

## Structural AT TLM Contract

The first calibration target is a structural approximately timed TLM, not the
loose/effective-rate model. The AT model must be closer to a packet-level
network-switch simulator than to a closed-form queue surface:

- Preserve packet and hit objects from generation through egress. Each hit
  carries lane, frame, subheader, true generation timestamp, lane-local hit
  index, payload word, and drop/delivery state.
- Keep RTL-shaped modules as explicit synchronized structures: source,
  ingress parser, lane FIFO credit, ticket FIFO credit, page allocator,
  handle FIFO, block mover, DRR arbiter, page RAM/frame table, presenter, and
  egress ready service.
- Model blocking at every FIFO and allocation boundary before replacing it
  with an asynchronous or effective-rate approximation.
- Maintain legal drop classes separately: ingress pre-drop from lane/ticket
  credit, allocator/post-allocation frame hit room drop, late/current-frame
  drop, and presenter/page-residency overwrite drop.
- Require output ordering to match RTL packet/hit order for all delivered
  traffic. Cycle timestamps may drift during AT calibration, but delivered
  hits must not be out of order.
- Use first-loss boundary points as calibration evidence. OPQ merged-frame hit
  room is `N_SHD * N_HIT`; `N_HIT=255` is the per-subheader hit-count field
  limit, not the total merged-frame hit-room limit.
- Only after AT and RTL agree on packet sequence and first-loss boundaries may
  a loosely timed model be used as an accelerated scan approximation.

This level matches the modeling discipline used by packet-level network
simulators: ns-3 queue discs model enqueue/dequeue/requeue/drop statistics and
internal queues/classes/filters, while HTSim models packets entering fixed-size
FIFO/priority queues with event-scheduled service and explicit drops. OPQ TLM
must be at least as structural because the RTL loss boundary depends on
credits, allocator state, and frame-table residency, not only on average rate.

External modeling references:

- ns-3 QueueDisc class reference:
  https://www.nsnam.org/docs/release/3.28/doxygen/classns3_1_1_queue_disc.html
- Broadcom HTSim repository and queue model source:
  https://github.com/Broadcom/csg-htsim
  https://raw.githubusercontent.com/Broadcom/csg-htsim/master/sim/queue.cpp

### Obsolete Zero-Gap Boundary Snapshot

Traffic assumption: `N_LANE=4`, `E=1`, `N_SHD=128`, independent lanes,
`B=0`, zero inter-frame gap, profile-3 timestamp source. RTL rows are from
`packet_scheduler/model/rtl_sim/data/RTL-LS-002.csv`; AT rows are from
`packet_scheduler/model/rtl_sim/data/opq_structural_tlm_boundary.csv`.

This snapshot is retained only as a synthetic stress record. It is not the
physical OPQ Poisson operating point because frame headers were compressed with
zero inter-frame gap. Physical cadence rows must use the contract above.

| rho_lane | RTL loss | AT loss | rel err | AT pre | AT post | seq |
|---:|---:|---:|---:|---:|---:|---:|
| 0.10 | 0.190767 | 0.187099 | 0.019 | 612 | 0 | 1 |
| 0.15 | 0.178398 | 0.185882 | 0.042 | 919 | 0 | 1 |
| 0.20 | 0.212455 | 0.172346 | 0.189 | 1143 | 0 | 1 |
| 0.30 | 0.239821 | 0.227097 | 0.053 | 2231 | 0 | 1 |
| 0.35 | 0.276849 | 0.273435 | 0.012 | 3124 | 0 | 1 |
| 0.40 | 0.274036 | 0.306235 | 0.118 | 4042 | 0 | 1 |
| 0.50 | 0.290197 | 0.339457 | 0.170 | 5403 | 103 | 1 |
| 0.60 | 0.518942 | 0.462954 | 0.108 | 7793 | 1311 | 1 |

Current status: first parsed RTL drop is already present at `rho_lane=0.10`
for zero-gap `N_SHD=128`, so the first-loss boundary is below 0.10 for this
traffic assumption. The AT model is within 18.9% max relative error over these
eight parsed points, with monotonic delivered-hit sequence for every row. The
`rho=0.50` and `rho=0.60` RTL runs still flag accepted-delivery accounting in
UVM, so the boundary row remains `DEBUG` until those runs are made fully clean
or rerun with a stricter drain/observation policy.

## Evidence Rules

TLM, RTL simulation, and board evidence must use the same burstiness
definition. Any sweep table that includes `B` should also retain enough fields
to audit it: `m_tau`, `sigma_tau`, `CV_tau`, `SCV_tau`, random seed, event
count, and whether same-timestamp hit clusters were enabled.

For OPQ-vs-time-merger comparison, both implementations must receive the same
ordered hit-generation stream for a given sample point. Only service timing,
buffering, and merge policy may differ between the two modeled datapaths.

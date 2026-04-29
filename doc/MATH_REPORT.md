# MATH_REPORT.md - packet_scheduler OPQ stay-time proxy analysis

**DUT:** `ordered_priority_queue`  
**Date:** `2026-04-25`
**Active scope:** `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`, plus analytical and TLM full-feature queueing models for `N_LANE={4,8,16}` and egress width `{1,2,4,8}` words/beat

This note studies frame stay behavior with a queueing-theory abstraction and
explicitly separates what is already measurable from what is still only a
future claim.

## Executive Summary

- The `48`-bit `frame_ts` is the canonical time-slice anchor.
- Consecutive frame slices advance by `N_SHD * 16` FEB header timestamp ticks,
  where one timestamp tick is `8 ns`: `0x400` for `N_SHD=64`, `0x800` for
  `N_SHD=128`, and `0x1000` for `N_SHD=256`. In the `250 MHz` SWB/UVM clock
  domain these are `0x800`, `0x1000`, and `0x2000` cycles respectively.
- The sequencer now models ingress debug time as virtual FEB dispatch time:
  `ingress_debug_ts = frame_ts[30:0] + 4096 + lane_skew_offset`.
- The current egress debug field is still allocator-side
  `running_ts[30:0]`.
- Therefore the honest current metric is a **residency proxy**, not yet a
  physical OPQ residence time:

`R_proxy = egress_debug_ts - frame_ts[30:0]`

- The raw debug-delta

`Delta_dbg = egress_debug_ts - ingress_debug_ts`

  is negative in normal clean runs, which is expected with the current mixed
  timestamp domains and proves that `Delta_dbg` is not yet the physical
  ingress-to-egress stay time.

## Timestamp Contract

| field | width | meaning | current use |
|---|---:|---|---|
| `frame_ts` | `48` | canonical slice anchor for true hit time | correctness, ordering, packet reconstruction |
| `ingress_debug_ts` | `31` | virtual FEB dispatch time | packet-contract field only; future stay-time anchor |
| `egress_debug_ts` | `31` | allocator-side dispatch/debug stamp | current proxy egress marker |

Implications:

1. `frame_ts` is the authoritative timebase.
2. `ingress_debug_ts` now obeys the intended virtual-FEB rule: it is later
   than `frame_ts` by at least `4096` debug-timestamp ticks and also carries
   lane-skew elasticity.
3. `egress_debug_ts` is useful, but it is not yet in the same physical-time
   convention as the new ingress field.
4. A future physical stay-time claim should use

`T_stay = T_egress_dispatch - T_ingress_dispatch`

   only after both debug fields are in the same dispatch-time domain.

## Queueing-Theory Abstraction

The OPQ can be modeled as a staged finite-buffer queueing system:

| stage | RTL / source view | abstraction | main effect on delay |
|---|---|---|---|
| `S0` | virtual FEB / sequencer | deterministic dispatch offset plus lane-skew elasticity | shifts ingress debug time by `4096 + skew` |
| `S1` | ingress parser | near-deterministic feed-forward parser | small bounded service cost |
| `S2` | lane FIFO + ticket creation | finite per-lane admission queue | local waiting and phase offset |
| `S3` | page allocator + frame-table ownership | shared finite-buffer server with frame/join gating | queue buildup, synchronization penalty, allocator lag |
| `S4` | presenter + egress ready/valid sink | output server with occasional vacations from backpressure | right-tail growth under stall/overflow |

At the current instrumentation point, the measurable proxy is best described as

`R_proxy = W_shared + S_present + E_stamp`

where:

- `W_shared` is waiting due to shared service and contention,
- `S_present` is bounded drain/presentation time, and
- `E_stamp` is the allocator timestamp-path contribution that keeps the metric
  anchored to canonical `frame_ts`, not to virtual-FEB dispatch time.

This is enough to compare regimes. It is not enough to claim physical dwell
time inside OPQ.

## Quantile Method

For a random variable `X = R_proxy`, the report uses:

- `q_p = inf{x : P(X <= x) >= p}`
- `p05` for a low-end bound
- `p50` for the median
- `p95` for tail pressure

The key derived indicators are:

- compactness: `p95 - p05`
- asymmetry / tail growth: `p95 - p50`
- lane asymmetry: per-lane `p50` and `p95` differences

Small-sample cases are kept, but they are explicitly labeled as such and are
not treated as stable steady-state tail estimates.

## Measured Regimes

Clean passing cases used for the current signature study:

| test | regime | samples | `p05` | `p50` | `p95` | `max` | reading |
|---|---|---:|---:|---:|---:|---:|---|
| `opq_bucket_frame_native_sv_test` | steady bounded frame traffic | `736` | `0` | `64` | `176` | `176` | bounded multi-modal |
| `opq_cross_drr_bursty_frame2_boundary_test` | burst-driven boundary | `8` | `16` | `112` | `208` | `208` | small-sample two-point / bimodal boundary |
| `opq_cross_mixed_bucket_random_soak_test` | mixed-rate random soak | `2008` | `0` | `64` | `176` | `176` | bounded multi-modal with lane asymmetry |
| `opq_cross_random_ready_overflow_step2_boundary_test` | sustained overflow / stall pressure | `20` | `2704` | `3920` | `4128` | `4128` | long-tail congestion regime |

### Lane-Level Detail

The bounded steady and mixed cases are not single-point distributions.
They show lane structure:

- `bucket_frame_native_sv`: lane `0/1` medians are `16`, lane `2/3` medians
  are `144` and `128`.
- `mixed_bucket_random_soak`: lane `0/1` medians are `16`, lane `2/3` medians
  are `80`.
- In both cases `p95=176` for every lane, so the regime is lane-asymmetric
  but still tightly bounded.

This is consistent with phase / service-position structure rather than
explosive backlog.

## Signature Families

### 1. Bounded Multi-Modal Regime

Representative tests:

- `opq_bucket_frame_native_sv_test`
- `opq_cross_mixed_bucket_random_soak_test`

Observed shape:

- mass starts at `0` or `16`
- medians remain small
- `p95` is capped at `176`
- no heavy right tail appears

Intuition:

- OPQ is behaving like a lightly loaded shared server with discrete service
  bands.
- The multi-modality comes from lane phase, packet shape, and bounded
  presentation granularity, not from runaway queue growth.

### 2. Bursty Boundary Regime

Representative test:

- `opq_cross_drr_bursty_frame2_boundary_test`

Observed shape:

- `p05=16`, `p50=112`, `p95=208`
- only `8` total samples

Intuition:

- This looks like a burst-triggered fast-path / blocked-path split, not a
  smooth steady-state queue.
- The regime is useful as a signature, but not as a statistically strong tail
  estimate.

### 3. Overflow Long-Tail Regime

Representative test:

- `opq_cross_random_ready_overflow_step2_boundary_test`

Observed shape:

- `p05=2704`
- `p50=3920`
- `p95=4128`
- tail mass is now thousands of cycles, not hundreds

Intuition:

- This is the queueing regime where backpressure and finite-buffer effects
  dominate.
- The large `p95 - p50` shift is the clearest signature that the system has
  moved from bounded service bands into persistent congestion.

## Lane-Skew Axis: Current Non-Claim

Two dedicated skew-focused studies were rerun with the new virtual-FEB ingress
timestamp semantics:

- [`../tb/sim_runs_math_residency/logs/opq_prof_per_lane_half_frame_skew_sweep_test.log`](../tb/sim_runs_math_residency/logs/opq_prof_per_lane_half_frame_skew_sweep_test.log)
- [`../tb/sim_runs_math_residency/logs/opq_prof_heavy_lane_skew_test.log`](../tb/sim_runs_math_residency/logs/opq_prof_heavy_lane_skew_test.log)

Result:

- both tests currently fail functionally and are therefore **not** part of the
  clean signature set
- their matched early samples collapse to `R_proxy = 0`
- their `Delta_dbg` values move from roughly `-4096` down to about `-5120`
  depending on skew

Interpretation:

- the new ingress debug field correctly exposes virtual-FEB skew
- the current egress-side proxy does **not** yet capture pure lane-skew
  residence
- therefore a lane-skew-only stay-time distribution remains an open item

This is an important result in itself: it shows that the present proxy is good
for congestion signatures, but weak for pure skew elasticity.

## Loss Plot Evidence Tiers

The modeling ladder for loss evidence is:

1. architectural truth from the reordering slides and source RTL contracts;
2. analytical queueing/network-calculus equations;
3. executable TLM event tables;
4. RTL simulation counters from HDL runs;
5. on-board measurement counters.

The upstream slide truth is `../../docs/Archive/ethhw_reordering.pptx`: the relevant
physical quantities are delay jitter `V`, resequencing timeout `T`, RTO `lambda`,
finite buffer size `B`, and loss caused by dropping outlier packets when a
finite resequencing resource is exceeded. This report maps those quantities to
`burstiness`, `ready_duty`, `rho_lane`, finite OPQ ticket capacity, and the old
time-merger tree-depth penalty.

Analytical and TLM plots may be used for architecture comparison and
design-space reasoning. They are not direct RTL or board drop-probability
evidence. RTL loss evidence must come from real HDL simulation output. Board
loss evidence must come from a hardware run using the same observable schema.

Legacy analytical lane-skew, burst/rate contour, OPQ-vs-time-merger, and
lane/egress-width families outside `model/` remain stale development artifacts
and are intentionally excluded from the promoted evidence list.

The accepted raw data sources are:

- OPQ: the native SystemVerilog DUT under the live UVM harness
- time-merger: the standalone SystemVerilog tree model in
  `../tb_old_reference/rtl/old_time_merger_ref.sv`, driven with the same
  36-bit OPQ/FEB frame-word format as the OPQ ingress driver

The plotted quantities must be computed from HDL counters and scoreboard
events:

`p_loss = dropped_hit_count / offered_hit_count`

where `offered_hit_count` counts legal hit words driven into the tested RTL
and `dropped_hit_count` is either the DUT-reported OPQ drop count or, for the
standalone time-merger reference, the standalone scoreboard's missing-hit
count under a finite FIFO/output-service configuration.

For lane skew, the x-axis is measured in frame units:

`skew_frames = Delta(frame_header_ts) / (N_SHD * 16)`

with three lanes aligned and one lane delayed. The same skew point has
different absolute timestamp and SWB-cycle distances for different `N_SHD`:

| `N_SHD` | one-frame FEB timestamp skew | one-frame SWB-cycle skew |
|---:|---:|---:|
| `64` | `0x400` | `0x800` |
| `128` | `0x800` | `0x1000` |
| `256` | `0x1000` | `0x2000` |

For promoted RTL burst/rate surfaces, the axes remain:

`B = (CV_tau - 1) / (CV_tau + 1)`

where `CV_tau = sigma_tau / m_tau` is measured from true hit-generation
interevent times.

`rho_lane = offered_hit_rate_per_lane / nominal_lane_hit_service_rate`

but every sampled `(B, rho_lane)` point in the RTL evidence tier must come
from an HDL run. Python or C may format and render measured tables, but must
not generate loss values for the RTL evidence tier from a queueing proxy.

The promoted RTL OPQ/time-merger comparison must use the same packet stream
generator, packet fields, lane skew, offered rate, burstiness seed policy,
warm-up discard, run length, and finite-output-service rule for both RTLs. The
time-merger path does not need pin-to-pin integration into the old SWB
datapath, but it must parse the exact OPQ/FEB frame words and build the
requested 2-input tree for `N_LANE=4/8/16`.

## Analytical Queueing And Network-Calculus Model

The new full-feature plots are analytical model plots, not RTL loss evidence.
They are included because they make the architectural scaling argument
explicit and reproducible before descending to TLM and HDL evidence.

Burstiness is parameterized by the Goh-Barabasi coefficient-of-variation form:

`B = (CV_tau - 1) / (CV_tau + 1)`

`CV_tau = (1 + B) / (1 - B)`

`SCV_tau = CV_tau^2`

The plotted model uses a Kingman-style variability multiplier:

`V(B) = sqrt((1 + SCV) / 2)`

with the numerical endpoint clipped in the renderer so the `B -> 1` limit stays
finite on the plot.

The aggregate arrival envelope is written as a network-calculus arrival curve:

`A_i(t) <= sigma_i(B, rho_lane) + rho_lane * t`

`A(t) <= N_LANE * sigma_i(B, rho_lane) + N_LANE * rho_lane * t`

The OPQ service curve for an egress packing factor `E` and ready duty `q` is:

`beta_opq(t) = R_opq * [t - T_opq]^+`

`R_opq = E * q`

For the old time-merger comparison model, the binary tree depth is:

`D = ceil(log2(N_LANE))`

The historical time-merger path is modeled as a one-word egress tree whose
service and effective local credit degrade with the quadratic tree penalty:

`P_tm = 1 + D^2`

`beta_tm(t) = R_tm * [t - T_tm]^+`

`R_tm = q / P_tm`

`K_tm = round(96 / P_tm)`

The OPQ finite window uses:

`K_opq = TICKET_FIFO_DEPTH - 1 = 255`

The smooth finite-buffer loss proxy uses effective load:

`rho_eff = (N_LANE * rho_lane / R) * V(B)`

and an `M/M/1/K` blocking probability:

`P_K(rho_eff) = ((1 - rho_eff) * rho_eff^K) / (1 - rho_eff^(K + 1))`

with the continuous limit:

`P_K(1) = 1 / (K + 1)`

The deterministic network-calculus lossless condition remains:

`N_LANE * rho_lane < R`

and

`sup_t(A(t) - beta(t)) <= K`

The plot uses the stochastic blocking proxy to draw smooth contours, while the
network-calculus inequalities document the hard lossless design direction.

### Model Reading

The generated OPQ full-feature loss surface shows the expected expansion of
the low-loss region as egress width grows. The `N_LANE=4`, `egress=1`
one-word point is already favorable versus the time-merger model once either
egress ready is deasserted or traffic becomes bursty.

At `rho_lane=0.0075`, the OPQ-vs-time-merger ratio contour gives the following
model summary:

| feature point | ratio reading |
|---|---|
| `N_LANE=4`, `egress=1x` | ratio is at least `1e3` over `31.4%` of the sampled ready/burst plane and reaches the clipped `1e6` region over `12.8%` |
| `N_LANE=8`, `egress=2x` | full sampled ready/burst plane is clipped at `1e6` time-merger/OPQ loss ratio |
| `N_LANE=16`, `egress=4x` | full sampled ready/burst plane is clipped at `1e6` time-merger/OPQ loss ratio |
| `N_LANE=16`, `egress=8x` | full sampled ready/burst plane is clipped at `1e6` time-merger/OPQ loss ratio |

At the stress point `B=0.70`, ready duty `0.75`, and `rho_lane=0.0075`, the
feature-scaling heatmap reports about `3.1e3` time-merger/OPQ loss ratio for
`N_LANE=4` and clipped `1e6` ratios for `N_LANE=8/16`. This is the expected
architectural result: OPQ can recover service by widening egress, while the
time-merger model keeps a one-word tree service path whose effective service
falls with the quadratic tree penalty.

## TLM Event Model

The TLM tier implements the same feature grid as an executable deterministic
finite-FIFO event model. It emits explicit transaction counters:

`p_loss = dropped_transactions / offered_transactions`

The TLM traffic source is a generation-timestamp event model whose mean hit
arrival rate is:

`lambda = N_LANE * rho_lane`

Burstiness is now defined from the true generation timestamp sequence, not from
a renderer-side duty heuristic. For each lane, sort hits by their true
generation timestamp, compute `CV_timestamp = sigma_tau / m_tau` from the
hit-to-hit interevent times including zero deltas for same-timestamp cluster
hits, then use:

`B = (CV_timestamp - 1) / (CV_timestamp + 1)`

For a Poisson generation-event source with same-timestamp mean hit batch size
`m`, the hit-interval SCV is:

`SCV_timestamp = 2m - 1`

so clustered traffic has:

`m = (((1 + B) / (1 - B))^2 + 1) / 2`

The SciFi anchor in `model/tlm/data/tlm_anchor_sample_point.csv` uses 128 iid
noise channels per lane, a DC-beam Poisson physical-particle source, physical
clusters of 4-8 same-timestamp hits, `rho_noise=0.10`, and
`rho_cluster=0.50`. That sample point is generated from hit timestamps and then
reported in the TLM summary.

The source emits arrivals into a finite queue for `8192` cycles after a `1024`
cycle warm-up. Egress ready is a deterministic vacation process with duty `q`.
OPQ receives `E` service tokens on each ready cycle. The time-merger path
receives:

`1 / (1 + ceil(log2(N_LANE))^2)`

service tokens on each ready cycle, matching the old one-word tree path and
quadratic depth penalty used by the analytical model.

The TLM result is intentionally not tuned to the HDL. It is an executable
bridge between the slide-level finite-buffer/RTO argument and future RTL
simulation. If RTL simulation disagrees, the RTL stimulus, counters, and queue
contracts must be debugged before changing this model.

At `rho_lane=0.0075`, the TLM OPQ-vs-time-merger ratio contour gives:

| feature point | TLM ratio reading |
|---|---|
| `N_LANE=4`, `egress=1x` | ratio is at least `1e3` over `37.9%` of the sampled ready/burst plane and reaches the clipped `1e6` region over `37.9%` |
| `N_LANE=8`, `egress=2x` | ratio is at least `1e3` over `83.6%` of the sampled ready/burst plane and reaches the clipped `1e6` region over `83.6%` |
| `N_LANE=16`, `egress=4x` | full sampled ready/burst plane is clipped at `1e6` time-merger/OPQ loss ratio |
| `N_LANE=16`, `egress=8x` | full sampled ready/burst plane is clipped at `1e6` time-merger/OPQ loss ratio |

At the same stress point used by the analytical heatmap, `B=0.70`, ready duty
`0.75`, and `rho_lane=0.0075`, the TLM feature-scaling heatmap is clipped at
`1e6` for the representative `N_LANE=4,E=1x`, `N_LANE=8,E=2x`, and higher
lane/egress feature points. This is the expected executable-model reading of
the slide claim: a burst can overflow a small time-merger resequencing resource
even when the average rate is modest, while OPQ has a larger finite window and
recovers with wider egress.

## Published DISLIN Feature Plot Set

Published `MATH_REPORT.md` figures are rendered with DISLIN. Python is used
only to generate analytical/TLM data tables and DISLIN matrix files, not to
render report figures.

The plot outputs are separated by evidence tier:

| evidence tier | plot folder | status |
|---|---|---|
| analytical | [`../model/analytical/plots/`](../model/analytical/plots/) | populated with DISLIN model plots |
| TLM | [`../model/tlm/plots/`](../model/tlm/plots/) | populated with DISLIN TLM plots |
| RTL simulation | [`../model/rtl_sim/plots/`](../model/rtl_sim/plots/) | residency proxy plots only; full loss-sweep plots pending HDL tables |
| on-board measurement | [`../model/on_board/`](../model/on_board/) | no board measurements published |

For both analytical and TLM tiers, each feature point has the same DISLIN figure
family:

| feature point | OPQ loss surface | OPQ/time-merger loss contour | OPQ/time-merger loss curve | ready/burst ratio |
|---|---|---|---|---|
| `N=4`, `E=1x` | [`analytical`](../model/analytical/plots/opq_loss_surface_nlane04_egress01x.png), [`TLM`](../model/tlm/plots/opq_loss_surface_nlane04_egress01x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_loss_contour_nlane04_egress01x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_loss_contour_nlane04_egress01x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_loss_curve_nlane04_egress01x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_loss_curve_nlane04_egress01x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_ready_burst_ratio_nlane04_egress01x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_ready_burst_ratio_nlane04_egress01x.png) |
| `N=4`, `E=2x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=4`, `E=4x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=4`, `E=8x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=8`, `E=1x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=8`, `E=2x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=8`, `E=4x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=8`, `E=8x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=16`, `E=1x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=16`, `E=2x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=16`, `E=4x` | full set in both tier folders | full set in both tier folders | full set in both tier folders | full set in both tier folders |
| `N=16`, `E=8x` | [`analytical`](../model/analytical/plots/opq_loss_surface_nlane16_egress08x.png), [`TLM`](../model/tlm/plots/opq_loss_surface_nlane16_egress08x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_loss_contour_nlane16_egress08x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_loss_contour_nlane16_egress08x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_loss_curve_nlane16_egress08x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_loss_curve_nlane16_egress08x.png) | [`analytical`](../model/analytical/plots/opq_vs_time_merger_ready_burst_ratio_nlane16_egress08x.png), [`TLM`](../model/tlm/plots/opq_vs_time_merger_ready_burst_ratio_nlane16_egress08x.png) |

The feature-scaling DISLIN heatmaps are:
[`analytical`](../model/analytical/plots/opq_vs_time_merger_feature_scaling.png)
and [`TLM`](../model/tlm/plots/opq_vs_time_merger_feature_scaling.png).

## Independent Queueing Review

An independent second-pass review of the math framing gave the following
guidance:

1. The queueing abstraction is defensible **only if** `R_proxy` is explicitly
   called a proxy or mixed delay metric, not physical residence time.
2. The report must state that the observed metric mixes fixed anchor offset,
   allocator timestamp effects, lane-skew elasticity, and queueing delay.
3. The bounded steady / mixed regime should be described as compact and
   multi-modal, not heavy-tailed.
4. The burst boundary should be described as a bimodal or two-point boundary
   effect, not as a stable steady-state distribution.
5. The overflow regime should be described as a true long-tail congestion
   signature.
6. Wrap / modulo handling on `31`-bit subtraction must be treated explicitly in
   future revisions; the current evidence stays inside a safe non-wrap window.

## Practical Reading Of The Numbers

For the current scope, the measured signatures can be summarized as:

- **Steady / mixed traffic:** compact bounded delay bands, lane-structured but
  not tail-dominated.
- **Burst boundary traffic:** small-sample split between fast and delayed
  service.
- **Overflow traffic:** clear right-tail growth and persistent congestion.
- **Pure lane skew:** not yet observable as a trustworthy RTL residence-time
  distribution through the current proxy path; loss-vs-skew plots are pending
  a dedicated HDL sweep with aligned packet format and matched OPQ/time-merger
  drivers.

## Loss Surface RTL Sweep Definition

To promote the analytical and TLM contours above into RTL evidence, the raw grid
must be generated by HDL simulation. The required grid schema is:

| column | definition |
|---|---|
| `implementation` | `opq` or `time_merger` |
| `n_lane` | `4`, `8`, or `16` |
| `n_shd` | active OPQ shadow-window point |
| `egress_symbols_per_beat` | OPQ egress width in 36-bit ingress symbols, or `1` for time-merger |
| `burstiness_b` | `B = (CV_tau - 1) / (CV_tau + 1)` |
| `rho_lane` | offered rate per lane normalized to one lane's nominal hit service rate |
| `offered_hit_count` | legal hit words accepted by the RTL input side |
| `delivered_hit_count` | legal hit words observed on the RTL output side |
| `dropped_hit_count` | accounted drops, or scoreboard missing hits for the bounded standalone time-merger run |
| `loss_probability` | `dropped_hit_count / offered_hit_count` |

The displayed axes are:

`B = (CV_tau - 1) / (CV_tau + 1)`

where periodic traffic maps to `-1`, Poisson maps to `0`, and increasingly
clustered traffic approaches `+1`, and

`rho = lambda / mu`

where `lambda` is the measured offered hit rate per lane and `mu` is the
nominal one-lane hit service rate used for the tested configuration.

The color quantity is:

`z = p_loss = dropped_hit_count / offered_hit_count`

The accepted contour levels remain `1e-6`, `1%`, and `5%`. The renderer must
use a filled log-gradient color map over the full sampled phase-space region,
not contour-band-only shading.

The current RTL-simulation tier contains residency-proxy evidence and the loss
sweep execution contract under [`../model/rtl_sim/`](../model/rtl_sim/). It does
not yet contain promoted OPQ/time-merger loss-surface plots because the HDL
loss table for matched OPQ and standalone time-merger runs has not been
generated.

## Lane And Egress Width Sweep

- `N_LANE = 4 / 8 / 16`
- egress width = `1 / 2 / 4 / 8` ingress symbols per beat
- each plotted point must use real RTL simulation data
- `N_LANE=8/16` and egress widths above one symbol per beat are not reportable
  as plots until the matching RTL feature and UVM scoreboard path are closed

## Next Step To Reach Physical Stay Time

To promote this from a proxy study into a physical stay-time study:

1. keep ingress debug time as virtual FEB dispatch time
2. move egress debug time to the same dispatch-time convention
3. then measure

`T_stay = egress_debug_ts - ingress_debug_ts`

4. rerun the dedicated skew tests and promote them into the clean signature set
5. keep the current `R_proxy` plots as a secondary canonical-domain view,
   because they remain useful for congestion classification

## Evidence And Artifacts

- Queueing/network-calculus model generator:
  [`../model/analytical/scripts/opq_queueing_network_calculus_model.py`](../model/analytical/scripts/opq_queueing_network_calculus_model.py)
- Queueing model summary:
  [`../model/analytical/data/queueing_model/queueing_model_summary.json`](../model/analytical/data/queueing_model/queueing_model_summary.json)
- Published analytical DISLIN plot folder:
  [`../model/analytical/plots/`](../model/analytical/plots/)
- TLM model generator:
  [`../model/tlm/scripts/opq_tlm_feature_sweep.py`](../model/tlm/scripts/opq_tlm_feature_sweep.py)
- TLM model summary:
  [`../model/tlm/data/tlm_model_summary.json`](../model/tlm/data/tlm_model_summary.json)
- Published TLM DISLIN plot folder:
  [`../model/tlm/plots/`](../model/tlm/plots/)
- Plot evidence-tier index:
  [`../model/README.md`](../model/README.md)
- Queueing model CSV grids:
  [`../model/analytical/data/queueing_model/opq_full_feature_loss_surface_grid.csv`](../model/analytical/data/queueing_model/opq_full_feature_loss_surface_grid.csv),
  [`../model/analytical/data/queueing_model/opq_vs_time_merger_ready_burst_ratio_grid.csv`](../model/analytical/data/queueing_model/opq_vs_time_merger_ready_burst_ratio_grid.csv),
  [`../model/analytical/data/queueing_model/opq_vs_time_merger_feature_scaling_grid.csv`](../model/analytical/data/queueing_model/opq_vs_time_merger_feature_scaling_grid.csv)
- DISLIN matrix grids:
  [`../model/analytical/data/queueing_model/dislin/`](../model/analytical/data/queueing_model/dislin/)
- TLM CSV grids:
  [`../model/tlm/data/tlm_full_feature_loss_surface_grid.csv`](../model/tlm/data/tlm_full_feature_loss_surface_grid.csv),
  [`../model/tlm/data/tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv`](../model/tlm/data/tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv),
  [`../model/tlm/data/tlm_opq_vs_time_merger_feature_scaling_grid.csv`](../model/tlm/data/tlm_opq_vs_time_merger_feature_scaling_grid.csv)
- TLM DISLIN matrix grids:
  [`../model/tlm/data/dislin/`](../model/tlm/data/dislin/)
- Quantiles CSV:
  [`../model/rtl_sim/data/residency_proxy_quantiles.csv`](../model/rtl_sim/data/residency_proxy_quantiles.csv)
- JSON summary:
  [`../model/rtl_sim/data/residency_proxy_summary.json`](../model/rtl_sim/data/residency_proxy_summary.json)
- Signature ECDF:
  [`../model/rtl_sim/plots/residency_proxy_signature_ecdf.png`](../model/rtl_sim/plots/residency_proxy_signature_ecdf.png)
- Per-test / per-lane ECDF:
  [`../model/rtl_sim/plots/residency_proxy_per_test_lane_ecdf.png`](../model/rtl_sim/plots/residency_proxy_per_test_lane_ecdf.png)
- Old-reference README:
  [`../tb_old_reference/README.md`](../tb_old_reference/README.md)
- Old-reference RTL model:
  [`../tb_old_reference/rtl/old_time_merger_ref.sv`](../tb_old_reference/rtl/old_time_merger_ref.sv)
- Old-reference exact-frame smoke:
  `make -C ../tb_old_reference BUILD_DIR=/tmp/old_tm_ref smoke-all`
- Old-reference formal harness:
  [`../tb_old_reference/formal/old_time_merger_ref_formal_tb.sv`](../tb_old_reference/formal/old_time_merger_ref_formal_tb.sv)
- Generator:
  [`../tb/scripts/opq_residency_math_report.py`](../tb/scripts/opq_residency_math_report.py)
- Loss-surface DISLIN renderer:
  [`../model/analytical/scripts/opq_loss_surface_plot.c`](../model/analytical/scripts/opq_loss_surface_plot.c)
- Loss-surface build wrapper, now requiring externally supplied RTL-sim data:
  [`../model/rtl_sim/scripts/render_loss_surface.sh`](../model/rtl_sim/scripts/render_loss_surface.sh)
- Lane-skew build wrapper, now requiring externally supplied RTL-sim data:
  [`../model/rtl_sim/scripts/render_lane_skew_loss.sh`](../model/rtl_sim/scripts/render_lane_skew_loss.sh)
- Old-vs-OPQ DISLIN renderer:
  [`../tb_old_reference/scripts/old_vs_opq_comparison_plot.c`](../tb_old_reference/scripts/old_vs_opq_comparison_plot.c)
- Old-vs-OPQ build wrapper, now requiring externally supplied RTL-sim data:
  [`../tb_old_reference/scripts/render_old_vs_opq_comparison.sh`](../tb_old_reference/scripts/render_old_vs_opq_comparison.sh)
- OPQ-vs-Time-Merger contour DISLIN renderer:
  [`../model/analytical/scripts/opq_vs_time_merger_contour_plot.c`](../model/analytical/scripts/opq_vs_time_merger_contour_plot.c)
- OPQ family contour build wrapper, now requiring externally supplied RTL-sim data:
  [`../model/rtl_sim/scripts/render_opq_loss_surface_family.sh`](../model/rtl_sim/scripts/render_opq_loss_surface_family.sh)

Legacy analytical/proxy plot artifacts that remain directly under
`../tb_old_reference/REPORT/` are stale development artifacts and are not
math-report evidence for this revision. The promoted analytical model data
lives under `../model/analytical/data/queueing_model/`; the TLM data lives
under `../model/tlm/data/`; and the published DISLIN figures live in the
matching tier `plots/` directories. All model-derived artifacts are explicitly
labeled as non-RTL and non-board evidence.

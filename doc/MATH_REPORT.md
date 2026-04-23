# MATH_REPORT.md - packet_scheduler OPQ stay-time proxy analysis

**DUT:** `ordered_priority_queue`  
**Date:** `2026-04-23`  
**Active scope:** `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`

This note studies frame stay behavior with a queueing-theory abstraction and
explicitly separates what is already measurable from what is still only a
future claim.

## Executive Summary

- The `48`-bit `frame_ts` is the canonical time-slice anchor.
- Consecutive frame slices are separated by `N_SHD * 16` cycles:
  `0x800` for `N_SHD=128`, `0x1000` for `N_SHD=256`, and so on.
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
   than `frame_ts` by at least `4096` cycles and also carries lane-skew
   elasticity.
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
- **Pure lane skew:** not yet observable as a trustworthy residence-time
  distribution through the current proxy path.

## Analytical Loss Surface

To make the burstiness/rate tradeoff visible on one page, the report now also
ships a small OPQ-inspired analytical contour:

- `x` is burstiness

`B = (SCV - 1) / (SCV + 1)`

  where periodic traffic maps to `-1`, Poisson maps to `0`, and increasingly
  clustered traffic approaches `+1`
- `y` is offered rate per lane

`rho = lambda / mu`

- `z` is steady-state loss probability from a finite-buffer `GI/D/1/K`
  abstraction with `K=255`

This is **not** a direct RTL drop-probability measurement. It is an analytical
companion surface that answers the user-facing question "where does loss start
to become likely as rate and burstiness move together?" without pretending to
replace the scoreboard evidence.

The plotting window is intentionally trimmed around the transition region and
then padded in the renderer, so the main contour sits inside the figure instead
of hugging the top or right border.

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

- Quantiles CSV:
  [`../tb/REPORT/math/residency_proxy_quantiles.csv`](../tb/REPORT/math/residency_proxy_quantiles.csv)
- JSON summary:
  [`../tb/REPORT/math/residency_proxy_summary.json`](../tb/REPORT/math/residency_proxy_summary.json)
- Signature ECDF:
  [`../tb/REPORT/math/residency_proxy_signature_ecdf.png`](../tb/REPORT/math/residency_proxy_signature_ecdf.png)
- Per-test / per-lane ECDF:
  [`../tb/REPORT/math/residency_proxy_per_test_lane_ecdf.png`](../tb/REPORT/math/residency_proxy_per_test_lane_ecdf.png)
- Loss-surface CSV:
  [`../tb/REPORT/math/loss_surface_grid.csv`](../tb/REPORT/math/loss_surface_grid.csv)
- Loss-surface JSON summary:
  [`../tb/REPORT/math/loss_surface_summary.json`](../tb/REPORT/math/loss_surface_summary.json)
- Loss-surface contour PNG:
  [`../tb/REPORT/math/loss_surface_contour.png`](../tb/REPORT/math/loss_surface_contour.png)
- Loss-surface contour SVG:
  [`../tb/REPORT/math/loss_surface_contour.svg`](../tb/REPORT/math/loss_surface_contour.svg)
- Generator:
  [`../tb/scripts/opq_residency_math_report.py`](../tb/scripts/opq_residency_math_report.py)
- Loss-surface generator:
  [`../tb/scripts/opq_loss_surface_model.py`](../tb/scripts/opq_loss_surface_model.py)
- Loss-surface DISLIN renderer:
  [`../tb/scripts/opq_loss_surface_plot.c`](../tb/scripts/opq_loss_surface_plot.c)
- Loss-surface build wrapper:
  [`../tb/scripts/render_loss_surface.sh`](../tb/scripts/render_loss_surface.sh)

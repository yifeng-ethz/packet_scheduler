# MODEL_PUBLISH.md — packet_scheduler / OPQ publication-grade figure catalog

**Companion:** [`README.md`](README.md) · [`analytical/README.md`](analytical/README.md) · [`tlm/README.md`](tlm/README.md) · [`rtl_sim/README.md`](rtl_sim/README.md) · [`rtl_sim/CASE_CATALOG.md`](rtl_sim/CASE_CATALOG.md) · [`on_board/README.md`](on_board/README.md) · [`../README.md`](../README.md) · [`../doc/SIGNOFF.md`](../doc/SIGNOFF.md)
**Renderer:** DISLIN 11.5.2 (vendored at `../.vendor/dislin`), invoked from C wrappers under `analytical/scripts/`, `tlm/scripts/`, and the per-set renderers added under `publish/scripts/`.
**Skill enforced:** [`~/.codex/skills/scientific-plotting/SKILL.md`](~/.codex/skills/scientific-plotting/SKILL.md) plus [`~/.codex/skills/scientific-plotting/references/visual-checklist.md`](~/.codex/skills/scientific-plotting/references/visual-checklist.md). Every figure passes the checklist (axis ranges centered on the regime where the response changes, sequential darker-is-worse palette for loss/risk, inline contour labels broken cleanly, color bar height matched to plot body, no overlapping titles or legends, sub-unit axes show enough decimal digits, DISLIN log `Warnings: 0`, golden-reference freeze).
**Audience:** chief architect signoff for OPQ vs old time-merger comparison and for OPQ feature scaling. Each set is the published-grade golden reference for one architectural claim.

## Definitions used by every figure

Write the meaning of every axis and metric on the figure or in its caption. Definitions used throughout this catalog (consistent with `README.md` "evidence ladder", `rtl_sim/CASE_CATALOG.md` schema, and `../doc/SIGNOFF.md`):

| Symbol | Meaning |
|---|---|
| `N_LANE` | OPQ ingress lane count, packaged points `{2, 4, 8, 16}` |
| `N_SHD` | OPQ shadow-window depth, packaged points `{64, 128, 256, 512}` |
| `E` (`egress_symbols_per_beat`) | OPQ egress width, packaged points `{1, 2, 4, 8}` (time-merger remains `1`) |
| `ρ_lane` | offered hit rate per lane, sampled `[0.005, 0.30]` |
| `B` | burstiness, `B = (SCV − 1) / (SCV + 1)` (slide 44 / 45 convention; `−1` periodic, `0` Poisson, `+1` bursty) |
| `M` | Goh–Barabási memory index over inter-arrival times |
| `ready_duty` | egress `ready` duty cycle, sampled `[0.45, 1.0]` |
| `loss` | `dropped_hit_count / offered_hit_count` from the schema in `rtl_sim/CASE_CATALOG.md` |
| `gain` | OPQ vs time-merger improvement: `loss_time_merger / loss_opq` (≥ 1 means OPQ wins) |
| `latency` | per-packet egress latency (cycles, 1 cycle = 8 ns at 125 MHz) |
| `RBO` | reordering byte offset (slide 13 metric) of inversions out of the merge stage |
| `RTO` | reordering time offset (slide 13 metric) |
| `T` | re-sequencing buffer timeout, `T = V` per slide 26 |
| `K` | OPQ shared-page count (proportional to `N_SHD`) |

Tier abbreviations (used in every set): **A** = analytical model (`analytical/`), **T** = TLM (`tlm/`), **S** = RTL SIM (`rtl_sim/`), **B** = on-board (`on_board/`).

## Catalog layout

Each set is delivered as one published figure (one PNG and one matching SVG export, identical layout). Subplots inside a set are explicitly enumerated. Every set names the source CSV, the renderer, the architectural claim, the `rtl_sim/CASE_CATALOG.md` case that supplies the data, and the chief-architect acceptance criteria. The 28 sets are ordered by the architectural flow (loss surface → feature scaling → ordering → queueing → ratio vs old time-merger → cross-tier signoff).

---

### Set 1 — Loss surface (B × ρ_lane) at the delivered slice

- **Subplots:** 1 contour panel `loss(B, ρ_lane)` for the delivered config `N_LANE=4, N_SHD=128, E=1, ready_duty=1.0` overlaying A (filled), T (dashed isolines), S (markers).
- **CSV:** `analytical/data/queueing_model/opq_loss_surface_nlane04_egress01x.csv`, `tlm/data/tlm_full_feature_loss_surface_grid.csv`, `rtl_sim/data/RTL-LS-002.csv`
- **Renderer:** `publish/scripts/set01_loss_surface_delivered.c`
- **Claim:** the delivered closure slice (per `../doc/SIGNOFF.md`) operates in a region where `loss < 1 ppm` for the expected Mu3e `(B, ρ_lane)` range.
- **Source case:** RTL-LS-002.
- **Acceptance:** sequential darker-is-worse palette; reference isolines `loss ∈ {1 %, 0.1 %, 1 ppm}` overlaid in the interior; color-bar height matches plot body; A / T / S overlays coincide; the `(B=0, ρ_lane=0.0075)` operating point sits inside the `1 ppm` isoline.

### Set 2 — OPQ loss-surface family by N_LANE × E

- **Subplots:** 3×4 grid (rows = `N_LANE ∈ {4, 8, 16}`, cols = `E ∈ {1, 2, 4, 8}`), each cell a `loss(B, ρ_lane)` contour for OPQ.
- **CSV:** the 12 grids `analytical/data/queueing_model/opq_loss_surface_nlane{04,08,16}_egress{01,02,04,08}x.csv` cross-validated against `tlm/data/...` and `rtl_sim/data/RTL-LS-005.csv`.
- **Renderer:** `publish/scripts/set02_loss_surface_family.c`
- **Claim:** OPQ scales monotonically with both `N_LANE` and `E`; widening egress wins more than adding lanes at fixed cost.
- **Source case:** RTL-LS-005.
- **Acceptance:** every cell uses the same color scale and same isolines; cells visibly darker (worse) toward upper-left (high `B`, high `ρ_lane`), lighter toward bottom-right; rows/columns labelled exactly once on the outer axes; color bar shared and matched to grid body height.

### Set 3 — OPQ vs time-merger contour (gain heatmap)

- **Subplots:** 3×4 grid mirroring Set 2, each cell `gain(B, ρ_lane)` on log color scale.
- **CSV:** `analytical/data/queueing_model/opq_vs_time_merger_loss_contour_nlane{04,08,16}_egress{01,02,04,08}x.csv`.
- **Renderer:** `publish/scripts/set03_opq_vs_time_merger_gain.c`
- **Claim:** OPQ outperforms the old time-merger across the full `(B, ρ_lane)` envelope; the lift grows with feature scaling.
- **Source case:** RTL-LS-005.
- **Acceptance:** sequential palette with white at `gain=1` (parity) and darker for `gain ≫ 1` (OPQ wins); reference contours at `gain ∈ {2, 10, 100}` overlaid; no cell shows `gain < 1` outside the documented exception envelope.

### Set 4 — Feature scaling line plot (loss vs N_LANE)

- **Subplots:** 1 panel, 4 line series (one per `E ∈ {1, 2, 4, 8}`) of `loss(N_LANE)` at `(B=0, ρ_lane=0.0075, ready_duty=1.0)`; A solid, T dashed, S markers.
- **CSV:** derived projection of Set 2 grids.
- **Renderer:** `publish/scripts/set04_feature_scaling_nlane.c`
- **Claim:** OPQ loss scales sub-linearly with `N_LANE` for fixed `E`.
- **Source case:** RTL-LS-005 reduction.
- **Acceptance:** all curves monotone non-decreasing; overlay across A / T / S within tolerance; legend distinguishes the three tiers and the four egress widths.

### Set 5 — Feature scaling line plot (loss vs E)

- **Subplots:** 1 panel, 3 line series (one per `N_LANE ∈ {4, 8, 16}`) of `loss(E)` at `(B=0, ρ_lane=0.0075)`.
- **CSV:** projection of Set 2.
- **Renderer:** `publish/scripts/set05_feature_scaling_egress.c`
- **Claim:** widening egress (`E`) gives near-`1/E` loss reduction up to the page-allocator bottleneck.
- **Source case:** RTL-LS-005.
- **Acceptance:** lines on log-y; reference slope `1/E` annotated; A / T / S overlay.

### Set 6 — Loss vs ready_duty at fixed (N_LANE, E, ρ_lane)

- **Subplots:** 4 panels (one per `E`), each with 3 lines (`N_LANE`); `loss(ready_duty)` over `[0.45, 1.0]` at `B=0`, `ρ_lane=0.0075`.
- **CSV:** `tlm/data/tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv` reduction.
- **Renderer:** `publish/scripts/set06_loss_vs_ready_duty.c`
- **Claim:** OPQ tolerates ready-deassertion gracefully; loss grows smoothly as `ready_duty` falls below 0.85.
- **Source case:** RTL-LS-001.
- **Acceptance:** monotone non-increasing curves toward `ready_duty = 1.0`; `1 ppm` reference horizontal line drawn; small-multiples share axes.

### Set 7 — Loss vs B at fixed (N_LANE, E, ρ_lane)

- **Subplots:** 4 panels (one per `E`), each with 3 lines (`N_LANE`); `loss(B)` for `B ∈ [-0.25, 0.95]`.
- **CSV:** projection of Set 2 / TLM.
- **Renderer:** `publish/scripts/set07_loss_vs_burstiness.c`
- **Claim:** OPQ degrades smoothly with burstiness; old time-merger collapses at `B > 0.4` (reference curve overlaid).
- **Source case:** RTL-LS-002.
- **Acceptance:** OPQ curves stay below the time-merger reference at every `B`; curves smooth (no kinks from numerical artifacts).

### Set 8 — Loss vs ρ_lane at fixed (N_LANE, E, B)

- **Subplots:** 4 panels per `E`, each with 3 lines per `N_LANE`; `loss(ρ_lane)` log-y for `ρ_lane ∈ [0.005, 0.30]`.
- **CSV:** projection of Set 2 / TLM.
- **Renderer:** `publish/scripts/set08_loss_vs_rate.c`
- **Claim:** OPQ has a wide `ρ_lane` range below the `1 ppm` line; the knee shifts right as `E` grows.
- **Source case:** RTL-LS-002.
- **Acceptance:** every panel shows the `1 ppm` and `1 %` reference horizontal lines; A / T / S overlay; knee location annotated for the delivered slice.

### Set 9 — OPQ vs time-merger ratio plot (1-D feature scaling)

- **Subplots:** 1 panel matching `analytical/plots/opq_vs_time_merger_feature_scaling.png` style — `gain` vs (`N_LANE × E`) feature index, with a 4×4 grid plus a fitted `gain ∝ N_LANE · E` reference.
- **CSV:** `analytical/data/queueing_model/opq_vs_time_merger_feature_scaling.csv`.
- **Renderer:** `publish/scripts/set09_feature_scaling_gain.c`
- **Claim:** the OPQ advantage scales linearly with the architecture knob `N_LANE · E`.
- **Source case:** RTL-LS-005 reduction.
- **Acceptance:** fitted reference line drawn; A / T / S markers visible; chi-square of the fit reported in the caption.

### Set 10 — Loss surface (B × ρ_lane) for the time-merger baseline

- **Subplots:** 1 contour panel `loss_time_merger(B, ρ_lane)` at `N_LANE=4, E=1, ready_duty=1.0`.
- **CSV:** `analytical/data/legacy/legacy_loss_surface_contour.csv`.
- **Renderer:** `publish/scripts/set10_legacy_loss_surface.c`
- **Claim:** the legacy time-merger collapses early in the `(B, ρ_lane)` plane; this is the reference surface that Set 1 has to beat.
- **Source case:** legacy reference.
- **Acceptance:** sequential darker-is-worse palette; same axes as Set 1 to allow side-by-side reading; `1 %` and `5 %` isolines overlaid.

### Set 11 — Side-by-side OPQ vs time-merger surfaces (Set 1 vs Set 10)

- **Subplots:** 1 figure with 2 panels (left = OPQ from Set 1, right = time-merger from Set 10) using identical color scale and isolines.
- **CSV:** Set 1 + Set 10.
- **Renderer:** `publish/scripts/set11_opq_vs_legacy_side_by_side.c`
- **Claim:** at the delivered slice, the OPQ region under `1 ppm` is at least an order of magnitude wider than the time-merger.
- **Source case:** RTL-LS-002 + legacy.
- **Acceptance:** identical axes, color scale, color bar; both panels labelled with the operating point; reference operating point marked the same way on both.

### Set 12 — Latency CDF for OPQ (rate sweep)

- **Subplots:** 1 panel, 4 CDFs (`F(latency | ρ_lane)` for `ρ_lane ∈ {0.005, 0.05, 0.15, 0.30}`) at `N_LANE=4, E=1, B=0, ready_duty=1.0`; A / T / S overlaid.
- **CSV:** `tlm/data/tlm_latency_cdf_*.csv` (extracted) + RTL-LS-002 latency tap.
- **Renderer:** `publish/scripts/set12_latency_cdf.c`
- **Claim:** OPQ keeps p99 latency bounded across the `ρ_lane` sweep.
- **Source case:** RTL-LS-002 latency reduction.
- **Acceptance:** all CDFs monotone non-decreasing; reference vertical line at the architectural latency budget; T / S agree with A within tolerance.

### Set 13 — Latency PDF (loaded vs unloaded)

- **Subplots:** 4 panels per `ρ_lane ∈ {0.005, 0.05, 0.15, 0.30}`; each panel shows `P(latency)` overlaying A / T / S.
- **CSV:** Set 12 raw.
- **Renderer:** `publish/scripts/set13_latency_pdf.c`
- **Claim:** OPQ latency PDF stays single-modal up to the design `ρ_lane`; multi-modal tail appears only past the page-allocator knee.
- **Source case:** Set 12 raw.
- **Acceptance:** every panel shows the same axis range; multi-modal tail in the rightmost panel labelled.

### Set 14 — Latency p50/p90/p99/max envelope

- **Subplots:** 1 panel, 4 quantile traces of `latency` vs `ρ_lane`, with A / T / S overlay.
- **CSV:** Set 12 / Set 13 reduction.
- **Renderer:** `publish/scripts/set14_latency_quantiles.c`
- **Claim:** the p99 envelope grows smoothly to the page-allocator knee; max trace is bounded.
- **Source case:** Set 12 / Set 13.
- **Acceptance:** every quantile monotone non-decreasing; reference budget lines drawn; A / T / S overlay.

### Set 15 — Latency 2-D contour (ρ_lane × latency)

- **Subplots:** 1 contour panel `P(latency | ρ_lane)` log-z, with the principal ridge isoline drawn.
- **CSV:** Set 12 raw expansion.
- **Renderer:** `publish/scripts/set15_latency_contour.c`
- **Claim:** the latency response surface is convex in `ρ_lane`; no fold or hysteresis.
- **Source case:** Set 12.
- **Acceptance:** color bar height matches plot body; sequential palette; reference isoline drawn.

### Set 16 — Reordering (δ_arrival × δ_timestamp) at OPQ ingress

- **Subplots:** 4 panels per `ρ_lane ∈ {0.005, 0.05, 0.15, 0.30}`, x/y heatmap with the on-time line dashed (slide-32 layout).
- **CSV:** `rtl_sim/data/RTL-LS-002_ingress_reorder.csv`.
- **Renderer:** `publish/scripts/set16_ingress_reorder.c`
- **Claim:** OPQ ingress sees the lane-multiplexed arrival jitter expected from the upstream slides.
- **Source case:** RTL-LS-002 ingress tap.
- **Acceptance:** lagging-arrival lobe visible at every rate; on-time line drawn; sequential palette.

### Set 17 — Reordering (δ_arrival × δ_timestamp) at OPQ egress

- **Subplots:** 4 panels matching Set 16, after OPQ merge.
- **CSV:** `rtl_sim/data/RTL-LS-002_egress_reorder.csv`.
- **Renderer:** `publish/scripts/set17_egress_reorder.c`
- **Claim:** OPQ collapses ingress reordering into an on-time-dominant egress.
- **Source case:** RTL-LS-002 egress tap.
- **Acceptance:** lagging-arrival lobe absent or strongly suppressed; on-time concentration visible. Side-by-side print with Set 16 recommended.

### Set 18 — RBO distribution

- **Subplots:** 1 panel of `P(RBO)` overlaid for `ρ_lane ∈ {0.005, 0.05, 0.15, 0.30}` at the delivered slice; reference `RBO ≤ α(V) − 1` (slide 16) drawn.
- **CSV:** projection of Set 16 / Set 17.
- **Renderer:** `publish/scripts/set18_rbo_distribution.c`
- **Claim:** the RBO never exceeds the architectural bound at any rate in the operating range.
- **Source case:** RTL-LS-002.
- **Acceptance:** bound line clearly labelled; tail of every distribution to the left of the bound.

### Set 19 — RTO distribution

- **Subplots:** 4 panels per `ρ_lane` of `P(RTO)` overlaid with the `V` envelope (slide 22) and the `T = V` reference (slide 26).
- **CSV:** projection of Set 16 / Set 17.
- **Renderer:** `publish/scripts/set19_rto_distribution.c`
- **Claim:** `RTO ≤ V` for every observation; the re-sequencer timeout `T = V` suffices.
- **Source case:** RTL-LS-002.
- **Acceptance:** every distribution stays inside the `V` envelope; `T = V` line drawn.

### Set 20 — Per-lane drop accounting fairness

- **Subplots:** 1 panel — stacked bar per lane (`N_LANE=8` × 8 bars, then `N_LANE=16` × 16 bars on a second row) of `dropped_hit_count / offered_hit_count`.
- **CSV:** `rtl_sim/data/RTL-LS-005_per_lane_drops.csv`.
- **Renderer:** `publish/scripts/set20_per_lane_fairness.c`
- **Claim:** OPQ's DRR allocator drops fairly across lanes; max-min ratio stays inside the documented fairness budget.
- **Source case:** RTL-LS-005.
- **Acceptance:** max/min lane drop ratio annotated; reference fairness budget line drawn.

### Set 21 — Page-allocator occupancy PDF (queue residency)

- **Subplots:** 3 panels per `N_LANE ∈ {4, 8, 16}` of `P(page_in_use)` log-y, with reference `K = N_SHD` vertical line.
- **CSV:** `rtl_sim/data/RTL-LS-005_page_residency.csv`.
- **Renderer:** `publish/scripts/set21_page_residency.c`
- **Claim:** the page allocator stays well under the shared-store cap at the delivered slice.
- **Source case:** RTL-LS-005.
- **Acceptance:** every panel's tail bounded by `N_SHD`; T / S coincide.

### Set 22 — Drop-probability surface (N_SHD × ρ_lane) at fixed (N_LANE, E, B)

- **Subplots:** 1 contour panel `loss(N_SHD, ρ_lane)` at `N_LANE=4, E=1, B=0, ready_duty=1.0`, log-z.
- **CSV:** `analytical/data/queueing_model/opq_loss_vs_nshd_rho.csv`.
- **Renderer:** `publish/scripts/set22_drop_vs_nshd_rho.c`
- **Claim:** N_SHD sizing buys orders-of-magnitude loss reduction up to the page-allocator throughput limit.
- **Source case:** A / T cross-sized for RTL-LS-005.
- **Acceptance:** sequential darker-is-worse palette; reference isolines `1 %, 0.1 %, 1 ppm` overlaid; color-bar height matched.

### Set 23 — Drop-probability surface (N_SHD × B) at fixed (N_LANE, E, ρ_lane)

- **Subplots:** 1 contour panel `loss(N_SHD, B)` at the delivered `ρ_lane`.
- **CSV:** projection of Set 22 / Set 7.
- **Renderer:** `publish/scripts/set23_drop_vs_nshd_burstiness.c`
- **Claim:** doubling N_SHD compensates roughly one step of `B` increase.
- **Source case:** A / T / S cross.
- **Acceptance:** sequential palette; reference isolines; `B = 0` operating column at `1 ppm` highlighted.

### Set 24 — Burstiness–memory map (slide 45 reproduction, OPQ traffic regimes)

- **Subplots:** 1 panel `(M, B)` scatter with the slide-45 trapezoidal envelope drawn; markers for the OPQ-fed traffic regimes (Poisson background, signal-like physics, charge-injection, re-curling), arrow annotations matching slide 45.
- **CSV:** `rtl_sim/data/burstiness_memory_observations.csv`.
- **Renderer:** `publish/scripts/set24_burstiness_memory.c`
- **Claim:** OPQ's loss surface is exercised across the full slide-45 envelope (background → signal → charge-injection corner cases).
- **Source case:** RTL-LS-002 / RTL-LS-005 traffic-regime catalog.
- **Acceptance:** every marker inside the predicted regime; envelope drawn but not overwhelming the markers; legend matches slide 45.

### Set 25 — DRR live-statistics convergence (per-lane allowance)

- **Subplots:** 2 panels — top: per-lane DRR allowance time series for `N_LANE=8`; bottom: histogram of inter-grant interval per lane.
- **CSV:** `rtl_sim/data/RTL-LS-005_drr_live.csv`.
- **Renderer:** `publish/scripts/set25_drr_live.c`
- **Claim:** the DRR allowance converges to a flat per-lane share within the documented warm-up window.
- **Source case:** RTL-LS-005.
- **Acceptance:** allowance traces flatten by the published warm-up time; per-lane inter-grant histograms have stddev within the documented bound.

### Set 26 — Cross-tier closure matrix (A ↔ T ↔ S agreement)

- **Subplots:** 1 heatmap, rows = case IDs from `rtl_sim/CASE_CATALOG.md` (`RTL-LS-001..RTL-LS-005` plus extensions), columns = `{A, T, S, A-T, T-S, A-S}`, cells = pass/fail or numerical agreement ratio.
- **CSV:** scoreboard rollup `publish/data/closure_matrix.csv`.
- **Renderer:** `publish/scripts/set26_closure_matrix.c`
- **Claim:** every closure case has A, T, S evidence and they agree within the configured tolerance.
- **Source case:** entire `rtl_sim/CASE_CATALOG.md`.
- **Acceptance:** all cells PASS; failing cells highlighted with a high-luminance hue separated from the sequential pass palette; row/column labels readable at the printed export size.

### Set 27 — Promotion ledger (loss-curve from A to T to S to B)

- **Subplots:** 4 panels per closure case (one column per tier A / T / S / B), each showing `loss(ρ_lane)` log-y at `(N_LANE=4, E=1, B=0)`; the same axes across columns.
- **CSV:** `analytical/data/queueing_model/opq_loss_vs_rho_n4_e1.csv`, `tlm/data/tlm_loss_vs_rho_n4_e1.csv`, `rtl_sim/data/RTL-LS-002_loss_vs_rho.csv`, `on_board/data/<board_run>_loss_vs_rho.csv` (placeholder until board run lands).
- **Renderer:** `publish/scripts/set27_promotion_ledger.c`
- **Claim:** the loss curve is continuous across the four tiers; each tier reproduces the previous tier's shape within tolerance.
- **Source case:** RTL-LS-002 + future board run.
- **Acceptance:** A / T / S already coincide; B column flagged "pending board run" until populated; once populated, tolerance band drawn around A and B markers must overlay.

### Set 28 — Chief-architect closure cover (golden-reference page)

- **Subplots:** 2×2 grid — top-left: OPQ loss surface at the delivered slice (Set 1 collapsed), top-right: OPQ vs time-merger gain (Set 3, `N_LANE=4, E=1` cell), bottom-left: feature-scaling gain (Set 9), bottom-right: cross-tier closure matrix (Set 26).
- **CSV:** the four CSVs above (no new data).
- **Renderer:** `publish/scripts/set28_closure_cover.c`
- **Claim:** the OPQ delivered slice closes against the slide-25 / slide-38 / `MATH_REPORT`-style architectural targets, the cross-tier scoreboard is green, and the OPQ wins versus the legacy time-merger across the feature grid.
- **Source case:** RTL-LS-005 + RTL-LS-002.
- **Acceptance:** every quadrant carries its short caption; layout passes the visual checklist (no overlap, color-bar height matched, sequential palette for the loss surface, decimal digits restored on sub-unit axes); DISLIN log `Warnings: 0`; matches the golden-reference rule sheet stored next to the figure.

---

## Tier / data provenance per figure

Every figure in this catalog is built from artifacts under the existing tier folders:

- **A (analytical):** [`analytical/scripts/render_queueing_model_dislin.sh`](analytical/scripts/render_queueing_model_dislin.sh) writes CSVs and DISLIN matrices in `analytical/data/queueing_model/` and `analytical/data/legacy/`. Per-set extensions live under `publish/scripts/analytical_<setNN>.py` and emit publish-grade CSVs without changing the upstream model.
- **T (TLM):** [`tlm/scripts/render_tlm_dislin.sh`](tlm/scripts/render_tlm_dislin.sh) drives `tlm/scripts/opq_tlm_feature_sweep.py` over the same feature grid as the analytical model. Per-set reductions live under `publish/scripts/tlm_<setNN>.py`.
- **S (RTL SIM):** runs from `tb_int/` per `rtl_sim/CASE_CATALOG.md` schema; per-set reducers `publish/scripts/sim_<setNN>.py` consume the case CSVs in `rtl_sim/data/`.
- **B (on-board):** placeholder under `on_board/`; figures that need board data declare it in their acceptance section and remain "pending board run" until the data lands. No tier may borrow plot data from another (per the prohibition in `README.md`).

The renderer for every set lives at `publish/scripts/setNN_<name>.c` (DISLIN). A wrapper at `publish/scripts/render_publish.sh` builds and runs all 28 sets, then re-runs the visual-checklist linter (per the codex skill) and fails the run if any rule below trips.

## Visual-checklist enforcement (must pass before signoff)

Every figure delivered for chief-architect review must pass these checks; the linter wrapper checks them per render.

1. Title band ≤ 2 lines; long definitions move to a caption beneath the plot body.
2. No overlap between titles, axis labels, ticks, legends, color bars; sub-unit axes show enough decimal digits.
3. Sequential palette darker-is-worse on every loss / drop / risk / overflow surface (sets 1, 2, 3, 10, 15, 22, 23, 26).
4. Color-bar vertical height matches the plot-body y-extent on every contour (sets 1, 2, 3, 10, 11, 15, 22, 23).
5. Inline contour labels broken cleanly on the contour stroke; no grid line / isoline crossing the label (sets 1, 2, 3, 10, 11, 22, 23).
6. Reference isolines drawn 2–4 levels in the interior of the sampled range; not at the min/max edge (sets 1, 2, 3, 10, 22, 23).
7. Axis range padded so the principal contour or knee is not glued to the border (every contour and every CDF/PDF set).
8. Every set distinguishes A (analytical), T (TLM), S (RTL SIM), B (board) in legend or panel label.
9. DISLIN log reports `Warnings: 0` for every render; warnings treated as a layout bug until proven otherwise.
10. Each accepted figure is frozen as `publish/golden/setNN_<name>.png` plus a one-page rule sheet `publish/golden/setNN_<name>.rules.md` recording the exact accepted layout, scaling, labeling, and visual-balance constraints (per the skill).

## Acceptance for chief-architect signoff

The publish bundle is signed when:

- All 28 sets are rendered with `Warnings: 0` and pass the visual checklist.
- Every set's A / T / S traces overlay within the configured tolerance, or the discrepancy is recorded with the analytic explanation and routed per the disagreement protocol below.
- Every set that requires B data is either populated with a board run from `on_board/` or explicitly tagged "pending board run" with the case ID that will produce it.
- The 28 golden references and 28 rule sheets exist under `publish/golden/`.
- The render wrapper `publish/scripts/render_publish.sh` exits 0 on a clean `make` from a fresh artifact directory.

Without this bundle signed, `packet_scheduler` (OPQ) closure reporting cannot quote the architectural claims above as published-grade evidence.

## Disagreement protocol (lower tier is suspect first)

When the in-figure tier overlay shows the layers disagree:

1. The analytical model is the architectural truth (per `README.md`: "start from upstream slides/spec/source RTL and analytical truth, then make TLM, RTL simulation, and on-board evidence converge to that abstraction"). Do not modify A to chase a T, S, or B observation.
2. If T disagrees with A, debug the TLM event model in `tlm/scripts/opq_tlm_feature_sweep.py` first, then the matrix definitions.
3. If S disagrees with T, debug the RTL — `rtl/`, the integration tb stimulus, the protocol checks listed in `rtl_sim/CASE_CATALOG.md` "Promotion Rule" — in that order.
4. If B disagrees with S, debug the on-board collection (counter-clear semantics, address aliasing, link integrity) before touching RTL.
5. Re-run the disagreeing case end-to-end. Append the discrepancy and the resolution to the relevant IP's `BUG_HISTORY.md` per the rtl-doc-style convention.

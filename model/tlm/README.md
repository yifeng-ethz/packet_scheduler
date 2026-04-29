# TLM evidence tier

This folder contains the deterministic transaction-level finite-FIFO event
model for OPQ versus the old time-merger tree. The TLM model emits explicit
offered, delivered, and dropped transaction counters for the same feature grid
as the analytical model.

Key outputs:

- `data/tlm_full_feature_loss_surface_grid.csv`: raw TLM counter/loss table.
- `data/tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv`: ready/burst ratio
  table at the report stress rate.
- `data/tlm_anchor_sample_point.csv`: SciFi timestamp-derived sample point with
  128 iid noise channels/lane and same-timestamp physical clusters of 4-8 hits.
- `data/tlm_model_summary.json`: model parameters and headline ratios.
- `data/dislin/`: DISLIN matrix files.
- `plots/`: DISLIN PNG plot family for all `N_LANE={4,8,16}` and egress
  width `{1,2,4,8}` feature combinations.
- `scripts/render_tlm_dislin.sh`: regenerates the TLM data and report plots.

Burstiness is defined from true hit generation timestamps: sort hits per lane
by timestamp, compute the coefficient of variation `CV_timestamp =
sigma_tau/m_tau` from hit-to-hit interevent times, then use
`B = (CV_timestamp - 1) / (CV_timestamp + 1)`. Same-timestamp physical cluster
hits contribute zero deltas. The default SciFi anchor uses
`rho_noise=0.10` and `rho_cluster=0.50` per lane.

Do not copy analytical, RTL-simulation, or board plots here.

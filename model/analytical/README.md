# Analytical evidence tier

This folder contains the queueing/network-calculus model. Python is used to
generate analytical CSV tables and DISLIN matrix files; report figures in
`plots/` are rendered by the C DISLIN wrappers under `scripts/`.

The plots are design-space model artifacts, not direct RTL drop evidence.

Key outputs:

- `data/queueing_model/`: analytical CSV grids, summary JSON, and DISLIN
  matrices.
- `plots/`: DISLIN PNG plot family for all `N_LANE={4,8,16}` and egress
  width `{1,2,4,8}` feature combinations.
- `scripts/render_queueing_model_dislin.sh`: regenerates the analytical data
  and report plots.

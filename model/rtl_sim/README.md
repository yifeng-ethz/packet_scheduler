# RTL simulation evidence tier

This folder is reserved for HDL-simulation evidence only.

Current published contents:

- `data/residency_proxy_quantiles.csv`: RTL-log-derived residency proxy
  quantiles.
- `data/residency_proxy_summary.json`: parsed UVM log summary.
- `plots/residency_proxy_signature_ecdf.png`: RTL-derived proxy ECDF.
- `plots/residency_proxy_per_test_lane_ecdf.png`: RTL-derived per-lane proxy
  ECDF.
- `CASE_CATALOG.md`: matched OPQ/time-merger HDL loss-sweep execution contract.
- `scripts/`: DISLIN wrappers that require externally supplied HDL tables.

Pending contents:

- matched OPQ and standalone old-time-merger HDL loss-sweep CSV tables;
- DISLIN loss surfaces, OPQ/time-merger contour overlays, loss curves, and
  ready/burst ratio plots generated from those HDL tables.

Do not promote analytical or TLM loss plots into this tier.

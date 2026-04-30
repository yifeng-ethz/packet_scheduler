# OPQ N=4 Egress=1x Normalized-Share Scan Report

Date: 2026-04-29

## Finding

The loss pins were not correlated with the contour because the contour was a
compact TLM/analytical surface, while the pins were real RTL/UVM evidence. There
was also a unit mismatch in the plot contract: RTL/UVM `rho_lane` is a raw mean
hit count per subheader per lane, but the plotted y-axis was intended to be
normalized throughput share per lane.

For OPQ physical cadence with `N_SHD=128`, `frame_launch_period_cycles=4096`,
and `egress_symbols_per_beat=1`:

```text
normalized_share_lane =
  raw_rho_lane_hits_per_subheader * N_SHD /
  (frame_launch_period_cycles * egress_symbols_per_beat)

normalized_share_lane = raw_rho_lane_hits_per_subheader / 32
```

Examples:

```text
raw rho_lane = 0.75  -> normalized share = 0.0234375
raw rho_lane = 8.00  -> normalized share = 0.25
```

The ideal persistent 4:1 bandwidth knee is therefore
`normalized_share_lane = 0.25` for `N_LANE=4`, `Egress=1x`.

## RTL Evidence

The 100-frame marginal ridge pins were converted from raw `rho_lane` into the
normalized-share axis before plotting:

- `packet_scheduler/model/rtl_sim/data/opq_marginal_f100_ridge_12run_pins.csv`
- `packet_scheduler/model/tlm/plots/opq_loss_surface_nlane04_egress01x.png`
- `packet_scheduler/model/tlm/plots/opq_vs_time_merger_loss_contour_nlane04_egress01x.png`

Those 12 pins are near normalized share `0.021875..0.029687`, not near
`0.70..0.95`. The labels now include both RTL/TLM loss ratios and raw
`rho_lane`.

The first normalized-share scan used the wrong UVM/model-publish lane FIFO
contract. It derived `OPQ_LANE_FIFO_DEPTH` from lane count only, so
`N_SHD=128,N_LANE=4` ran with `2048` entries/lane and reported false controlled
pre-drops below the persistent knee. The corrected contract derives the depth
from geometry:

```text
OPQ_LANE_FIFO_DEPTH = next_power_of_two(max(N_SHD * 64, N_LANE * 1024))
```

For this feature point the default is now `8192`.

Corrected real RTL/UVM scans were rerun around the ideal persistent bottleneck:

| CSV | rows | hits/run | share range | result |
|---|---:|---:|---|---|
| `opq_normalized_share_scan_n4_e1.csv` | 6 | ~10k/100k | 0.23..0.30 | corrected FIFO-depth probe; clean below/at the knee, controlled loss above the knee |

Representative corrected rows:

- `B=0.0`, share `0.23`, raw rho `7.36`: expected `15273`,
  delivered `15273`, controlled dropped `0`, loss `0.00%`.
- `B=0.0`, share `0.25`, raw rho `8.00`: expected `16600`,
  delivered `16600`, controlled dropped `0`, loss `0.00%` in the shallow
  4-frame run.
- `B=0.0`, share `0.30`, raw rho `9.60`: expected `103468`,
  delivered `68322`, controlled dropped `35146`, loss `33.97%`.

The corrected data now follows the expected first-order boundary: the false
below-knee loss is gone, and a deeper above-knee point shows controlled loss.
The 4-frame clean rows at share `0.25..0.27` are not a contradiction of the
persistent limit; finite OPQ storage plus end-of-run drain can absorb short
overload bursts. Long-run pins must therefore report frame count, hit count,
and FIFO depth beside the loss ratio.

## Modeling Consequence

Do not fit the TLM contour by applying a scalar service scale to force the RTL
pins onto the analytical surface. Scalar OPQ service tuning is now disabled in
the compact plot model. The correct TLM path is structural:

- retain raw `rho_lane` and normalized-share fields in all CSVs;
- use normalized share only for the y-axis in this plot family;
- model OPQ lane FIFO, ticket FIFO, handle FIFO, page allocator, DRR mover,
  frame table, presenter, credit return, and blocking behavior before claiming
  the broad contour is RTL-calibrated;
- keep the real RTL pins and scans as calibration evidence, not as analytical
truth.

The corrected structural OPQ TLM replay is archived in
`opq_structural_tlm_normalized_share_n4_e1.csv`. It matches every clean
below-knee row exactly and matches the 100k above-knee row to within `0.47%`
drop-count error:

```text
share=0.30, raw rho=9.60, B=0:
  RTL dropped = 35146 / 103468
  TLM dropped = 34982 / 103468
```

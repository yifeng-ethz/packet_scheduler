# OPQ Native-SV Feature-Range Standalone Signoff

This Quartus project is the standalone synthesis closure harness for the
deliverable OPQ feature range.

Target build:

- device: `10AX115N2F45E1SG` (`online_sc/a10_board`)
- nominal target clock: `250 MHz`
- signoff clock: `275 MHz` (`1.1 x 250 MHz`)
- top entity: `opq_native_sv_feature_signoff_top`
- active RTL: `rtl/sv_ver/ordered_priority_queue/monolithic_sv`
- supported sweep axes:
  - `OPQ_SYN_N_LANE=4/8/16`
  - `OPQ_SYN_N_SHD=64/128/256`
  - `OPQ_SYN_PAGE_RAM_RD_WIDTH=36/72/144/288`

The harness drives legal FEB/OPQ 36-bit ingress words into all lanes and folds
accepted egress payload, sidebands, and source state into preserved activity
outputs. It is a synthesis-only preservation and timing harness, not a DV
testbench.

Use:

```bash
./run_feature_matrix.sh --smoke
./run_feature_matrix.sh --matrix
```

The `--smoke` target compiles the default deliverable point and the largest
lane/egress point first. The `--matrix` target compiles the full focused
feature range at `N_SHD=128`, plus `N_SHD=64/256` baseline timing points.

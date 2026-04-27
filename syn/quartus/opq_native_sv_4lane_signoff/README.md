# OPQ Native-SV 4-Lane Standalone Signoff

This Quartus revision compiles the native-SV standalone OPQ core through a
local synthesizable harness, without the older Qsys example-system wrapper.

Target build:

- device: `10AX115N2F45E1SG` (`online_sc/a10_board`)
- nominal target clock: `250 MHz`
- signoff clock: `275 MHz` (`1.1 x 250 MHz`)
- top entity: `opq_native_sv_4lane_signoff_top`
- signoff config:
  - `OPQ_USE_NATIVE_SV`
  - `OPQ_N_LANE=4`
  - `OPQ_N_SHD=128`
  - `OPQ_TICKET_FIFO_DEPTH=1024`
  - `OPQ_PAGE_RAM_DEPTH=65536`

Key commands:

```bash
quartus_sh --flow compile opq_native_sv_4lane_signoff -c opq_native_sv_4lane_signoff
quartus_sta opq_native_sv_4lane_signoff -c opq_native_sv_4lane_signoff
```

Compatibility layer:

- `src_compat/` carries synthesis-only copies or harness-local compatibility
  variants of the parser-sensitive native-SV files from the matching checked-in
  `rtl/` tree.
- Those copies primarily preserve Quartus 18.1 compatibility for inline
  `for (genvar ...)` loops, and in a few cases retain harness-local observe
  taps or explicit RAM wrappers that the standalone synthesis flow needs.
- Functional fixes still belong in `rtl/`; when the live wrapper or datapath
  contract changes, the affected `src_compat/` copy must be re-aligned before
  trusting a standalone signoff rerun.

Current closure scope:

- this standalone point now matches the active DV closure preset
  `OPQ_N_LANE=4`, `OPQ_N_SHD=128`, `OPQ_TICKET_FIFO_DEPTH=1024`
- the older `4-lane / 256-subheader / ticket512` point remains a later
  expanded signoff target rather than the current closure gate

Planned follow-up:

- keep synthesis closure on the A10 target aligned with future lane-scaled
  settings `N_LANE={2,4,8,16}`
- add adaptive pipeline controls at the real critical stages once the first A10
  baseline compile identifies whether arbitration, presenter, or another cone is
  the dominant limiter

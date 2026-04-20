# packet_scheduler syn

Standalone synthesis-side collateral for `packet_scheduler`.

## Contents

- `SYN_REPORT.md`: synthesis dashboard in the same entry-table style used by
  `ring-buffer_cam`.
- `../doc/CONFIG_SIGNOFF.md`: grouped parameter matrix that summarizes which
  lane / width / `N_SHD` points are actually measured, bounded, blocked, or
  still pending.
- `quartus/`: Quartus projects, generated systems, and synthesis helpers.

## Status

The cleaned tree now keeps the older example collateral under
`quartus/opq_monolithic_4lane_merge/` and the standalone native-SV signoff
harnesses under `quartus/opq_native_sv_{2,4}lane_signoff/`.

The active Arria-10 lane-2 and lane-4 standalone refreshes have completed and
their timing/resource evidence is recorded in `SYN_REPORT.md`. Wider `N_LANE`
points and staged ingress / DMA-width axes remain tracked in
`doc/CONFIG_SIGNOFF.md`.

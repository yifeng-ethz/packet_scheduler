# packet_scheduler syn

Standalone synthesis-side collateral for `packet_scheduler`.

## Contents

- `SYN_REPORT.md`: synthesis dashboard in the same entry-table style used by
  `ring-buffer_cam`.
- `quartus/`: Quartus projects, generated systems, and synthesis helpers.

## Status

The cleaned tree now places the existing OPQ example collateral under
`quartus/opq_monolithic_4lane_merge/`. A fresh standalone signoff compile has
not yet been rerun from this layout, so `SYN_REPORT.md` remains an honest
pending report rather than a green claim.

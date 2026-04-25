# packet_scheduler plot evidence tiers

This directory separates published plot artifacts by evidence tier:

- `analytical/`: queueing/network-calculus design-space model plots rendered
  with DISLIN.
- `tlm/`: reserved for transaction-level model plots generated from a TLM
  event stream.
- `rtl_sim/`: reserved for plots generated from RTL simulation tables.
- `on_board/`: reserved for plots generated from board measurements.

Do not mix evidence tiers in one folder. Each published plot must identify the
data source tier in the report text.

# packet_scheduler UVM

Archived unit-level UVM tests for split OPQ modules.

This directory is preserved under `legacy/` for reference only. It is not the current monolithic OPQ signoff environment.

## Suites
- `unit_frame_table/`: random stress on frame-table mapper/tracker/presenter wrapper.
- `unit_page_allocator/`: random stress on page allocator wrapper.
- `unit_opq_top/`: convenience entrypoint to the full OPQ UVM TB (delegates to repo-root `uvm_order_priority_queue/run_uvm.sh`).

## Notes
- The full regression/soak infrastructure lives under `uvm_order_priority_queue/` at the repo root and can run against `OPQ_IMPL=monolithic` or `OPQ_IMPL=split`.
- Current packet_scheduler signoff requirements are documented in `packet_scheduler/doc/VERIFICATION_SIGNOFF.md`.

# OPQ split (WIP)

This folder is the start of refactoring the monolithic OPQ (`packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue*.terp.vhd`)
into smaller, unit-testable blocks.

Current status:
- `opq_util_pkg.vhd`: small helper package (clog2 + array typedefs).
- `opq_b2p_arbiter.vhd`: extracted block-mover-to-page-RAM arbiter (DRR/quantum aware).
- `opq_block_mover.vhd`: extracted block mover (lane FIFO -> page RAM).
- `opq_page_allocator.vhd`: extracted ticket consumer + page allocator (MERGING mode) with header/shd/trailer writes.
- `opq_frame_table_mapper.vhd`: extracted write-window/tile mapper and tile-FIFO update command generator.
- `opq_frame_table_tracker.vhd`: extracted per-tile FIFO meta + spill linkage tracking.
- `opq_frame_table_presenter.vhd`: extracted egress framing + spill-warp, backpressure handling.
- `opq_frame_table.vhd`: mapper/tracker/presenter integration.
- `opq_ingress_parser.vhd`: ingress decode + hit trimming + ticket/lane FIFO writes (unit-testable subset).
- `opq_rd_debug_if.vhd`: read-only debug register interface (frame-table status for now).

Planned split (from the monolithic OPQ):
- `opq_ingress_parser.vhd`: ingress decode, ticket + lane FIFO write, trimming/drop policy.
- `opq_page_allocator.vhd`: ticket timeliness, handle generation, page RAM header/trailer writes.
- `opq_frame_table_mapper.vhd`: segment/tile mapping, spill-over bookkeeping.
- `opq_frame_table_tracker.vhd`: per-tile FIFO meta + spill linkage tracking.
- `opq_frame_table_presenter.vhd`: egress framing + spill-warp, backpressure handling.
- `opq_frame_table_top.vhd`: instantiates mapper/tracker/presenter as one “frame table complex”.
- `opq_rd_debug_if.vhd`: read-only debug register interface (per OPQ register map).
- `opq_top.vhd`: instantiates ingress/parser/allocator/movers/frame-table/debug.
- `ordered_priority_queue_split.terp.vhd`: TERP-facing wrapper that exposes Avalon-ST ports and instantiates `opq_top`.

Testing plan:
- Add small directed TBs per module (VHDL or SV as appropriate).
- Add UVM sequences to stress each module boundary (hit count extremes, backpressure, FIFO overflow).
- Integrate into `opq_top` and re-run the full OPQ UVM regression.

Current unit tests:
- `packet_scheduler/tb/opq_b2p_arbiter_smoke-nlane2/tb_opq_b2p_arbiter.vhd` + `packet_scheduler/tb/opq_b2p_arbiter_smoke-nlane2/run_tb_b2p_arbiter.sh`
- `packet_scheduler/tb/opq_block_mover_smoke-nlane1/tb_opq_block_mover.vhd` + `packet_scheduler/tb/opq_block_mover_smoke-nlane1/run_tb_block_mover.sh`
- `packet_scheduler/tb/opq_frame_table_mapper_edgecases-nlane2/tb_opq_frame_table_mapper.vhd` + `packet_scheduler/tb/opq_frame_table_mapper_edgecases-nlane2/run_tb_frame_table_mapper.sh`
- `packet_scheduler/tb/opq_frame_table_smoke-nlane2/tb_opq_frame_table.vhd` + `packet_scheduler/tb/opq_frame_table_smoke-nlane2/run_tb_frame_table.sh`
- `packet_scheduler/tb/opq_ingress_parser_smoke-nlane1/tb_opq_ingress_parser.vhd` + `packet_scheduler/tb/opq_ingress_parser_smoke-nlane1/run_tb_ingress_parser.sh`
- `packet_scheduler/tb/opq_page_allocator_smoke-nlane2/tb_opq_page_allocator.vhd` + `packet_scheduler/tb/opq_page_allocator_smoke-nlane2/run_tb_page_allocator.sh`
- `packet_scheduler/tb/opq_rd_debug_if_smoke-ntile5/tb_opq_rd_debug_if.vhd` + `packet_scheduler/tb/opq_rd_debug_if_smoke-ntile5/run_tb_rd_debug_if.sh`
- `packet_scheduler/tb/opq_top_smoke-nlane2/tb_opq_top.vhd` + `packet_scheduler/tb/opq_top_smoke-nlane2/run_tb_opq_top.sh`

Current UVM:
- `packet_scheduler/uvm/unit_frame_table/`: frame-table UVM random stress (compile/run via `run_uvm_frame_table.sh`).
- `packet_scheduler/uvm/unit_page_allocator/`: page-allocator UVM random stress (compile/run via `run_uvm_page_allocator.sh`).
- `packet_scheduler/uvm/unit_opq_top/`: top-level OPQ UVM reuse plan in `OPQ_TOP_UVM_PLAN.md` (runner `run_uvm_opq_top.sh`).

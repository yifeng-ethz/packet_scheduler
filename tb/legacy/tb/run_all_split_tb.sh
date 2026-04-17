#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

bash ./lint/lint.sh

bash ./opq_b2p_arbiter_smoke-nlane2/run_tb_b2p_arbiter.sh
bash ./opq_block_mover_smoke-nlane1/run_tb_block_mover.sh
bash ./opq_frame_table_mapper_edgecases-nlane2/run_tb_frame_table_mapper.sh
bash ./opq_frame_table_smoke-nlane2/run_tb_frame_table.sh
bash ./opq_page_allocator_smoke-nlane2/run_tb_page_allocator.sh
bash ./opq_ingress_parser_smoke-nlane1/run_tb_ingress_parser.sh
bash ./opq_rd_debug_if_smoke-ntile5/run_tb_rd_debug_if.sh
bash ./opq_top_smoke-nlane2/run_tb_opq_top.sh

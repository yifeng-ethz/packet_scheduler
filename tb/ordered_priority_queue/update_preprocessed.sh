#!/usr/bin/env bash
set -euo pipefail

SRC_DIR=/home/yifeng/packages/online_dpv2/online/switching_pc/a10_board/qsys_saved/debug_queue_system/ordered_priority_queue_250722/synth
DST_FILE=ordered_priority_queue.vhd

latest_src=$(ls -t "${SRC_DIR}"/debug_queue_system_ordered_priority_queue_250722_*.vhd 2>/dev/null | head -n 1 || true)
if [[ -z "${latest_src}" ]]; then
  echo "No preprocessed VHDL found in ${SRC_DIR}" >&2
  exit 1
fi

cp -f "${latest_src}" "${DST_FILE}"
perl -pi -e 's/unsigned\\(asi_ingress_data\\(i\\)\\)\\(15 downto 8\\)/unsigned(asi_ingress_data(i)(15 downto 8))/g' "${DST_FILE}"
perl -pi -e 's/std_logic_vector\\(ingress_parser\\(i\\)\\.running_ts\\)\\(47 downto 12\\)/std_logic_vector(ingress_parser(i).running_ts(47 downto 12))/g' "${DST_FILE}"
perl -pi -e 's/std_logic_vector\\(ingress_parser\\(i\\)\\.running_ts\\)\\(47 downto 0\\)/std_logic_vector(ingress_parser(i).running_ts(47 downto 0))/g' "${DST_FILE}"
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
old = (
    "        -- if spill, what is the remainder unusable part in the expanding tile\n"
    "        ftable_mapper_update_ftable_trail_span      <= to_unsigned(to_integer(ftable_mapper.new_frame_raw_addr) + to_integer(ftable_mapper_update_ftable_fspan) - PAGE_RAM_DEPTH, ftable_mapper_update_ftable_trail_span'length);\n"
)
new = (
    "        -- if spill, what is the remainder unusable part in the expanding tile\n"
    "        if (to_integer(ftable_mapper.new_frame_raw_addr) + to_integer(ftable_mapper_update_ftable_fspan) > PAGE_RAM_DEPTH) then\n"
    "            ftable_mapper_update_ftable_trail_span  <= to_unsigned(\n"
    "                to_integer(ftable_mapper.new_frame_raw_addr) + to_integer(ftable_mapper_update_ftable_fspan) - PAGE_RAM_DEPTH,\n"
    "                ftable_mapper_update_ftable_trail_span'length\n"
    "            );\n"
    "        else\n"
    "            ftable_mapper_update_ftable_trail_span  <= (others => '0');\n"
    "        end if;\n"
)
if old in text:
    text = text.replace(old, new)
elif new not in text:
    raise SystemExit("update_preprocessed: pattern not found for trail span patch")
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path
import re

path = Path("ordered_priority_queue.vhd")
text = path.read_text()

needle = (
    "            handle_fifo_if_rd(i).handle.src        <= unsigned(handle_fifos_rd_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO));\n"
    "            handle_fifo_if_rd(i).handle.dst        <= unsigned(handle_fifos_rd_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO));\n"
    "            handle_fifo_if_rd(i).handle.blk_len    <= unsigned(handle_fifos_rd_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO));\n"
)
patched = needle + "            handle_fifo_if_rd(i).flag              <= handle_fifos_rd_data(i)(HANDLE_LENGTH);\n"

if re.search(r"handle_fifo_if_rd\\(i\\)\\.flag\\s*<=", text) is None:
    if needle not in text:
        raise SystemExit("update_preprocessed: pattern not found for handle flag decode")
    text = text.replace(needle, patched)

path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
old = "                        page_allocator.alloc_page_flow         <= page_allocator.alloc_page_flow + 1; -- increment flow \n"
new = (
    "                        if (page_allocator.alloc_page_flow = N_LANE-1) then\n"
    "                            page_allocator.alloc_page_flow     <= 0; -- wrap to avoid out-of-range\n"
    "                        else\n"
    "                            page_allocator.alloc_page_flow     <= page_allocator.alloc_page_flow + 1; -- increment flow\n"
    "                        end if;\n"
)
if old in text:
    text = text.replace(old, new)
elif new not in text:
    raise SystemExit("update_preprocessed: pattern not found for alloc_page_flow patch")
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
old_lane = "        N_LANE                  : natural := 4; -- number of ingress lanes, e.g., 4 for x4\n"
new_lane = "        N_LANE                  : natural := 2; -- number of ingress lanes, e.g., 4 for x4\n"
if old_lane in text:
    text = text.replace(old_lane, new_lane)
elif new_lane not in text:
    raise SystemExit("update_preprocessed: pattern not found for N_LANE default")
old_nshd = "        N_SHD                   : natural := 256; -- number of subheader, e.g., 256, more than 256 will be dropped. each subframe is 16 cycles\n"
new_nshd = "        N_SHD                   : natural := 128; -- number of subheader, e.g., 256, more than 256 will be dropped. each subframe is 16 cycles\n"
if old_nshd in text:
    text = text.replace(old_nshd, new_nshd)
elif new_nshd not in text:
    raise SystemExit("update_preprocessed: pattern not found for N_SHD default")
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
old1 = "            ingress_parser_if_subheader_hit_cnt(i)        <= unsigned(asi_ingress_data(i))(15 downto 8);\n"
new1 = "            ingress_parser_if_subheader_hit_cnt(i)        <= unsigned(asi_ingress_data(i)(15 downto 8));\n"
old2 = "                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts)(47 downto 12) & ingress_parser_if_subheader_shd_ts(i) & \"0000\"; -- ts[47:0]\n"
new2 = "                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts(47 downto 12)) & ingress_parser_if_subheader_shd_ts(i) & \"0000\"; -- ts[47:0]\n"
old3 = "                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts)(47 downto 0); -- ts[47:0]\n"
new3 = "                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts(47 downto 0)); -- ts[47:0]\n"
if old1 in text:
    text = text.replace(old1, new1)
elif new1 not in text:
    raise SystemExit("update_preprocessed: pattern not found for slice fixes (subheader hit cnt)")
if old2 in text:
    text = text.replace(old2, new2)
elif new2 not in text:
    raise SystemExit("update_preprocessed: pattern not found for slice fixes (running_ts[47:12])")
if old3 in text:
    text = text.replace(old3, new3)
elif new3 not in text:
    raise SystemExit("update_preprocessed: pattern not found for slice fixes (running_ts[47:0])")
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
if "dbg_page_allocator_state" not in text:
    anchor = "    signal block_mover_if_write_page_data       : block_mover_if_write_page_data_t;\n\n    -- ────────────────────────────────────────────────\n"
    insert = (
        "    signal block_mover_if_write_page_data       : block_mover_if_write_page_data_t;\n"
        "\n"
        "    -- debug signals for simulation visibility\n"
        "    signal dbg_page_allocator_state        : integer range 0 to 6;\n"
        "    signal dbg_ftable_presenter_state      : integer range 0 to 6;\n"
        "    type dbg_block_mover_state_t is array (0 to N_LANE-1) of integer range 0 to 4;\n"
        "    signal dbg_block_mover_state           : dbg_block_mover_state_t;\n"
        "\n"
        "    -- ────────────────────────────────────────────────\n"
    )
    if anchor not in text:
        raise SystemExit("update_preprocessed: anchor for debug declarations not found")
    text = text.replace(anchor, insert)
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
if "dbg_page_allocator_state <=" not in text:
    anchor = (
        "    assert PAGE_RAM_ADDR_WIDTH = 16 report \"PAGE RAM ADDR NON-DEFAULT (16 bits)\" severity warning;\n"
        "    assert integer(ceil(log2(real(N_SHD*N_HIT)))) + 1 <= 16 report \"N Hits counter will likely to overflow, resulting in functional error\" severity warning;\n"
        "\n"
        "    -- io mapping \n"
        "    i_clk           <= d_clk;\n"
        "    i_rst           <= d_reset;\n"
        "\n"
        "    -- ────────────────────────────────────────────────\n"
    )
    insert = (
        "    assert PAGE_RAM_ADDR_WIDTH = 16 report \"PAGE RAM ADDR NON-DEFAULT (16 bits)\" severity warning;\n"
        "    assert integer(ceil(log2(real(N_SHD*N_HIT)))) + 1 <= 16 report \"N Hits counter will likely to overflow, resulting in functional error\" severity warning;\n"
        "\n"
        "    dbg_page_allocator_state    <= page_allocator_state_t'pos(page_allocator_state);\n"
        "    dbg_ftable_presenter_state  <= ftable_presenter_state_t'pos(ftable_presenter_state);\n"
        "    gen_dbg_block_mover_state : for i in 0 to N_LANE-1 generate\n"
        "        dbg_block_mover_state(i) <= block_mover_state_t'pos(block_mover_state(i));\n"
        "    end generate;\n"
        "\n"
        "    -- io mapping \n"
        "    i_clk           <= d_clk;\n"
        "    i_rst           <= d_reset;\n"
        "\n"
        "    -- ────────────────────────────────────────────────\n"
    )
    if anchor not in text:
        raise SystemExit("update_preprocessed: anchor for debug assignments not found")
    text = text.replace(anchor, insert)
path.write_text(text)
PY
python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()
old = (
    "        -- derive timeliness of the showahead ticket\n"
    "        for i in 0 to N_LANE-1 loop\n"
    "            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket\n"
    "                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) >= page_allocator.frame_serial + 1 then -- check serial number, TODO: handle the frame serial overflow case\n"
    "                    page_allocator_is_tk_future(i)              <= '1'; -- \"stall\"\n"
    "                else \n"
    "                    page_allocator_is_tk_future(i)              <= '0'; -- ok : expected\n"
    "                end if;\n"
    "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) > page_allocator.running_ts) then -- shr ticket\n"
    "                page_allocator_is_tk_future(i)              <= '1';\n"
    "            else \n"
    "                page_allocator_is_tk_future(i)              <= '0';\n"
    "            end if;\n"
    "\n"
    "            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket\n"
    "                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) < page_allocator.frame_serial then -- check serial number\n"
    "                    page_allocator_is_tk_past(i)                <= '1'; -- \"drop\"\n"
    "                else \n"
    "                    page_allocator_is_tk_past(i)                <= '0'; -- ok : expected\n"
    "                end if;\n"
    "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) < page_allocator.running_ts) then -- shr ticket\n"
    "                page_allocator_is_tk_past(i)                <= '1';\n"
    "            else \n"
    "                page_allocator_is_tk_past(i)                <= '0';\n"
    "            end if;\n"
    "        end loop;\n"
)
new = (
    "        -- derive timeliness of the showahead ticket\n"
    "        for i in 0 to N_LANE-1 loop\n"
    "            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket\n"
    "                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) >= page_allocator.frame_serial + 1 then -- check serial number, TODO: handle the frame serial overflow case\n"
    "                    page_allocator_is_tk_future(i)              <= '1'; -- \"stall\"\n"
    "                else \n"
    "                    page_allocator_is_tk_future(i)              <= '0'; -- ok : expected\n"
    "                end if;\n"
    "            elsif (page_allocator.running_ts = to_unsigned(0, page_allocator.running_ts'length)) then -- initialize baseline, do not mask the first ticket\n"
    "                page_allocator_is_tk_future(i)              <= '0';\n"
    "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) > page_allocator.running_ts + to_unsigned(16, page_allocator.running_ts'length)) then -- shr ticket (allow 1 tick slack)\n"
    "                page_allocator_is_tk_future(i)              <= '1';\n"
    "            else \n"
    "                page_allocator_is_tk_future(i)              <= '0';\n"
    "            end if;\n"
    "\n"
    "            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket\n"
    "                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) < page_allocator.frame_serial then -- check serial number\n"
    "                    page_allocator_is_tk_past(i)                <= '1'; -- \"drop\"\n"
    "                else \n"
    "                    page_allocator_is_tk_past(i)                <= '0'; -- ok : expected\n"
    "                end if;\n"
    "            elsif (page_allocator.running_ts = to_unsigned(0, page_allocator.running_ts'length)) then -- initialize baseline, do not skip the first ticket\n"
    "                page_allocator_is_tk_past(i)                <= '0';\n"
    "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) + to_unsigned(16, page_allocator.running_ts'length) < page_allocator.running_ts) then -- shr ticket (allow 1 tick slack)\n"
    "                page_allocator_is_tk_past(i)                <= '1';\n"
    "            else \n"
    "                page_allocator_is_tk_past(i)                <= '0';\n"
    "            end if;\n"
    "        end loop;\n"
)
if old in text:
    text = text.replace(old, new)
elif new not in text:
    raise SystemExit("update_preprocessed: pattern not found for ticket timeliness guard")
path.write_text(text)
PY
echo "Updated ${DST_FILE} from ${latest_src}"

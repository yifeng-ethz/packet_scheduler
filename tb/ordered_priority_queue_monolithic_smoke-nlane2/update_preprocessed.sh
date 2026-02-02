#!/usr/bin/env bash
set -euo pipefail

SRC_DIR=/home/yifeng/packages/online_dpv2/online/switching_pc/a10_board/qsys_saved/debug_queue_system/ordered_priority_queue_250722/synth
DST_FILE=ordered_priority_queue.vhd
latest_src=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Option B (debug): generate ordered_priority_queue.vhd directly from a local .terp.vhd template.
# This lets us iterate on sim-only debug instrumentation without touching external preprocessed RTL.
#
# Enable by setting one of:
#   - OPQ_TERP_TEMPLATE=/abs/or/rel/path/to/*.terp.vhd
#   - OPQ_USE_DEBUG_TERP=1  (uses ../../ordered_priority_queue.debug.terp.vhd)
TERP_TEMPLATE="${OPQ_TERP_TEMPLATE:-}"
if [[ -z "${TERP_TEMPLATE}" && "${OPQ_USE_DEBUG_TERP:-0}" == "1" ]]; then
  TERP_TEMPLATE="${SCRIPT_DIR}/../../rtl/ordered_priority_queue/debug/ordered_priority_queue.debug.terp.vhd"
fi

if [[ -n "${TERP_TEMPLATE}" ]]; then
  QUARTUS_SH="${QUARTUS_SH:-quartus_sh}"
  if ! command -v "${QUARTUS_SH}" >/dev/null 2>&1; then
    echo "quartus_sh not found (QUARTUS_SH=${QUARTUS_SH})" >&2
    exit 1
  fi

  TERP_OUT_NAME="${OPQ_TERP_OUTPUT_NAME:-ordered_priority_queue_terp_debug}"
  TERP_N_LANE="${OPQ_TERP_N_LANE:-2}"
  TERP_EGRESS_EMPTY_WIDTH="${OPQ_TERP_EGRESS_EMPTY_WIDTH:-0}"

  tmp_tcl="$(mktemp)"
  cat > "${tmp_tcl}" <<TCL
lappend auto_path "\$::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages"
package require -exact altera_terp 1.0
set template_file [file normalize {${TERP_TEMPLATE}}]
set template [read [open \$template_file r]]
set params(n_lane) ${TERP_N_LANE}
set params(fifos_names) [list "ticket_fifo" "lane_fifo" "handle_fifo"]
set params(egress_empty_width) ${TERP_EGRESS_EMPTY_WIDTH}
set params(output_name) "${TERP_OUT_NAME}"
set result [altera_terp \$template params]
set out [open "${DST_FILE}" w]
puts \$out \$result
close \$out
puts "Generated ${DST_FILE} from template: \$template_file"
TCL
  "${QUARTUS_SH}" -t "${tmp_tcl}"
  rm -f "${tmp_tcl}"
else
  latest_src=$(ls -t "${SRC_DIR}"/debug_queue_system_ordered_priority_queue_250722_*.vhd 2>/dev/null | head -n 1 || true)
  if [[ -z "${latest_src}" ]]; then
    echo "No preprocessed VHDL found in ${SRC_DIR}" >&2
    exit 1
  fi
  cp -f "${latest_src}" "${DST_FILE}"
fi

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

path = Path("ordered_priority_queue.vhd")
text = path.read_text()

# 1) Make SOP ticket carry a complete header timestamp (needed for N_SHD=128 bit11 phase).
old_hdr_ts = (
    "                                    ingress_parser(i).running_ts(15 downto 12)      <= unsigned(asi_ingress_data(i)(31 downto 28)); -- note: do not overwrite subheader ts bit field\n"
)
new_hdr_ts = (
    "                                    -- Capture the full low 16 timestamp bits from the header word so the SOP ticket can\n"
    "                                    -- carry an accurate frame timestamp even in N_SHD=128 mode (bit11 toggles).\n"
    "                                    ingress_parser(i).running_ts(15 downto 0)       <= unsigned(asi_ingress_data(i)(31 downto 16));\n"
)
if old_hdr_ts in text:
    text = text.replace(old_hdr_ts, new_hdr_ts)
elif "running_ts(15 downto 0)" not in text:
    raise SystemExit("update_preprocessed: pattern not found for header low-ts capture patch")

# 2) Fix page allocator timestamp handling:
#    - Do not advance frame_ts before writing the header (off-by-one, breaks N_SHD=128 bit11 phase).
#    - Re-sync running_ts to the frame boundary on SOP to avoid drift when a frame is shortened.
old_frame_ts = (
    "                                page_allocator.frame_ts                         <= unsigned(page_allocator.frame_ts) + to_unsigned(FRAME_DURATION_CYCLES,page_allocator.frame_ts'length); -- incr frame ts after seen one aligned sop tickets\n"
)
new_frame_ts = (
    "                                -- Re-align running timestamp to the frame boundary at SOP.\n"
    "                                -- This prevents accumulated subheader-count drift (e.g., a shortened first frame).\n"
    "                                page_allocator.running_ts                       <= page_allocator.frame_ts;\n"
)
if old_frame_ts in text:
    text = text.replace(old_frame_ts, new_frame_ts)
elif ("page_allocator.running_ts                       <= page_allocator.frame_ts;" not in text
      and "page_allocator.running_ts                       <= to_unsigned(" not in text):
    raise SystemExit("update_preprocessed: pattern not found for SOP running_ts resync patch")

# Advance frame_ts only after finishing writing the header/trailer for the frame.
frame_cnt_line = (
    "                                page_allocator.frame_cnt                <= page_allocator.frame_cnt + 1; -- incr the frame counter\n"
)
frame_ts_advance = (
    "                                page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length); -- advance to next frame start\n"
)
if frame_cnt_line in text:
    block = frame_cnt_line + frame_ts_advance
    if block not in text:
        text = text.replace(frame_cnt_line, block)
elif "page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length);" not in text:
    raise SystemExit("update_preprocessed: pattern not found for frame_ts advance (WRITE_HEAD exit)")

tail_page_line = (
    "                            page_allocator.page_start_addr          <= page_allocator.page_start_addr + HDR_SIZE + TRL_SIZE; -- incr the page start addr by HDR_SIZE (5) + TRL_SIZE (1), because we wrote header + last trailer\n"
)
tail_frame_ts_advance = (
    "                            page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length); -- advance to next frame start\n"
)
if tail_page_line in text:
    block = tail_page_line + tail_frame_ts_advance
    if block not in text:
        text = text.replace(tail_page_line, block)
elif "page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length);" not in text:
    raise SystemExit("update_preprocessed: pattern not found for frame_ts advance (WRITE_TAIL exit)")

path.write_text(text)
PY

# Generate a stable wrapper entity name so testbenches don't depend on the
# (auto-suffixed) Platform Designer entity name.
python - <<'PY'
from pathlib import Path
import re

src = Path("ordered_priority_queue.vhd").read_text(errors="ignore")
m = re.search(r"\bentity\s+(\w+)\s+is\b", src, flags=re.IGNORECASE)
if not m:
    raise SystemExit("update_preprocessed: failed to find entity name in ordered_priority_queue.vhd")
impl = m.group(1)

wrapper = f"""library ieee;
use ieee.std_logic_1164.all;

entity ordered_priority_queue is
    generic (
        DEBUG_LV               : natural := 1
    );
    port (
        asi_ingress_0_data            : in  std_logic_vector(35 downto 0);
        asi_ingress_0_valid           : in  std_logic_vector(0 downto 0);
        asi_ingress_0_channel         : in  std_logic_vector(1 downto 0);
        asi_ingress_0_startofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_0_endofpacket     : in  std_logic_vector(0 downto 0);
        asi_ingress_0_error           : in  std_logic_vector(2 downto 0);
        asi_ingress_1_data            : in  std_logic_vector(35 downto 0);
        asi_ingress_1_valid           : in  std_logic_vector(0 downto 0);
        asi_ingress_1_channel         : in  std_logic_vector(1 downto 0);
        asi_ingress_1_startofpacket   : in  std_logic_vector(0 downto 0);
        asi_ingress_1_endofpacket     : in  std_logic_vector(0 downto 0);
        asi_ingress_1_error           : in  std_logic_vector(2 downto 0);

        aso_egress_data               : out std_logic_vector(35 downto 0);
        aso_egress_valid              : out std_logic;
        aso_egress_ready              : in  std_logic;
        aso_egress_startofpacket      : out std_logic;
        aso_egress_endofpacket        : out std_logic;
        aso_egress_error              : out std_logic_vector(2 downto 0);

        d_clk                         : in  std_logic;
        d_reset                       : in  std_logic
    );
end entity ordered_priority_queue;

architecture rtl of ordered_priority_queue is
begin
    u_impl : entity work.{impl}
        generic map (
            DEBUG_LV               => DEBUG_LV
        )
        port map (
            asi_ingress_0_data          => asi_ingress_0_data,
            asi_ingress_0_valid         => asi_ingress_0_valid,
            asi_ingress_0_channel       => asi_ingress_0_channel,
            asi_ingress_0_startofpacket => asi_ingress_0_startofpacket,
            asi_ingress_0_endofpacket   => asi_ingress_0_endofpacket,
            asi_ingress_0_error         => asi_ingress_0_error,
            asi_ingress_1_data          => asi_ingress_1_data,
            asi_ingress_1_valid         => asi_ingress_1_valid,
            asi_ingress_1_channel       => asi_ingress_1_channel,
            asi_ingress_1_startofpacket => asi_ingress_1_startofpacket,
            asi_ingress_1_endofpacket   => asi_ingress_1_endofpacket,
            asi_ingress_1_error         => asi_ingress_1_error,

            aso_egress_data             => aso_egress_data,
            aso_egress_valid            => aso_egress_valid,
            aso_egress_ready            => aso_egress_ready,
            aso_egress_startofpacket    => aso_egress_startofpacket,
            aso_egress_endofpacket      => aso_egress_endofpacket,
            aso_egress_error            => aso_egress_error,

            d_clk                       => d_clk,
            d_reset                     => d_reset
        );
end architecture rtl;
"""

Path("ordered_priority_queue_wrapper.vhd").write_text(wrapper)
print(f"Generated ordered_priority_queue_wrapper.vhd for entity: {impl}")
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
# If neither pattern matches, assume the template already carries a custom
# alloc_page_flow update (e.g. for stalling/backpressure) and skip this patch.
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

use_anchor = "use ieee.std_logic_misc.and_reduce;\n"
if "use std.textio.all;" not in text:
    if use_anchor not in text:
        raise SystemExit("update_preprocessed: use clause anchor not found for textio")
    text = text.replace(
        use_anchor,
        use_anchor + "use std.textio.all;\nuse ieee.std_logic_textio.all;\n"
    )

debug_block = """
    -- ────────────────────────────────────────────────
    -- Sim-only debug: log page RAM traffic and overwrite risk
    -- Enabled when DEBUG_LV >= 2 (non-synthesizable).
    -- ────────────────────────────────────────────────
    gen_overwrite_debug : if (DEBUG_LV >= 2) generate
        -- synopsys translate_off
        file f_overwrite : text open write_mode is "opq_overwrite_debug.log";
    begin
        proc_overwrite_debug : process (i_clk)
            variable l : line;
            variable rd_tile_i : integer;
            variable wr_tile_i : integer;
            variable overwrite_risk : boolean;
        begin
            if rising_edge(i_clk) then
                if i_rst = '1' then
                    null;
                else
                    rd_tile_i := to_integer(ftable_presenter.rseg.tile_index);
                    wr_tile_i := to_integer(ftable_mapper_writing_tile_index);
                    overwrite_risk := (ftable_presenter_state /= IDLE) and (wr_tile_i = rd_tile_i);

                    if page_ram_we = '1' then
                        write(l, string'("WRITE t="));
                        write(l, now);
                        write(l, string'(" tile="));
                        write(l, integer(wr_tile_i));
                        write(l, string'(" addr="));
                        hwrite(l, page_ram_wr_addr);
                        write(l, string'(" data="));
                        hwrite(l, page_ram_wr_data);
                        if overwrite_risk then
                            write(l, string'(" OVERWRITE_RISK rd_ptr="));
                            hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(rd_tile_i)));
                            write(l, string'(" rd_cnt="));
                            write(l, integer(to_integer(ftable_presenter.pkt_rd_word_cnt)));
                            write(l, string'(" state="));
                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
                        end if;
                        writeline(f_overwrite, l);
                    end if;

                    if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '1') and (aso_egress_ready = '1') then
                        write(l, string'("READ  t="));
                        write(l, now);
                        write(l, string'(" tile="));
                        write(l, integer(rd_tile_i));
                        write(l, string'(" addr="));
                        hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(rd_tile_i)));
                        write(l, string'(" data="));
                        hwrite(l, page_ram_rd_data);
                        write(l, string'(" state="));
                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
                        writeline(f_overwrite, l);
                    end if;
                end if;
            end if;
        end process;
        -- synopsys translate_on
    end generate;
"""

if "gen_overwrite_debug" not in text:
    anchor = "\n    proc_avalon_streaming_egress_comb : process (all)\n"
    if anchor not in text:
        raise SystemExit("update_preprocessed: anchor not found for overwrite debug block")
    text = text.replace(anchor, "\n" + debug_block + anchor)

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
    # Option B debug template may already carry a different (fixed) implementation.
    pass
if old2 in text:
    text = text.replace(old2, new2)
elif new2 not in text:
    # Option B debug template may already carry a different (fixed) implementation.
    pass
if old3 in text:
    text = text.replace(old3, new3)
elif new3 not in text:
    # Option B debug template may already carry a different (fixed) implementation.
    pass
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
    alt_anchor = anchor.replace("    -- io mapping \n", "    -- io mapping\n")
    if (anchor not in text) and (alt_anchor in text):
        anchor = alt_anchor
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
        "    -- io mapping\n"
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
elif new in text:
    pass
else:
    # The .terp-generated RTL (and some external preprocessed variants) can have a mixed form:
    # - future uses the 1-tick slack comparison (new)
    # - past already has the +16 slack compare (new)
    # - but both are missing the "running_ts==0" baseline guard (new)
    #
    # Patch that form in-place by inserting the baseline guard in both future and past paths.
    baseline_guard = "page_allocator.running_ts = to_unsigned(0, page_allocator.running_ts'length)"
    if baseline_guard not in text:
        fut_anchor = (
            "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) > page_allocator.running_ts + to_unsigned(16, page_allocator.running_ts'length)) then -- shr ticket (allow 1 tick slack)\n"
        )
        fut_insert = (
            "            elsif (page_allocator.running_ts = to_unsigned(0, page_allocator.running_ts'length)) then -- initialize baseline, do not mask the first ticket\n"
            "                page_allocator_is_tk_future(i)              <= '0';\n"
        )
        if fut_anchor in text:
            text = text.replace(fut_anchor, fut_insert + fut_anchor)

        past_anchor = (
            "            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) + to_unsigned(16, page_allocator.running_ts'length) < page_allocator.running_ts) then -- shr ticket (allow 1 tick slack)\n"
        )
        past_insert = (
            "            elsif (page_allocator.running_ts = to_unsigned(0, page_allocator.running_ts'length)) then -- initialize baseline, do not skip the first ticket\n"
            "                page_allocator_is_tk_past(i)                <= '0';\n"
        )
        if past_anchor in text:
            text = text.replace(past_anchor, past_insert + past_anchor)

    if baseline_guard not in text:
        raise SystemExit("update_preprocessed: pattern not found for ticket timeliness guard")
path.write_text(text)
PY

python - <<'PY'
from pathlib import Path

path = Path("ordered_priority_queue.vhd")
text = path.read_text()

# Normalize trailing whitespace so exact-match patches remain stable across formatting cleanups.
def strip_trailing_ws(s: str) -> str:
    out = "\n".join(line.rstrip() for line in s.splitlines())
    return out + ("\n" if s.endswith("\n") else "")

text = strip_trailing_ws(text)

# Fix egress backpressure handling in FTABLE_PRESENTER:
# - Do not rollback page_ram_rptr for all tiles when ready deasserts.
# - Hold output/pointers stable on ready=0 once a valid word is at the egress.

old_ptr_update = (
    "                        -- incr rd ptr \n"
    "                        if (aso_egress_ready = '1') then \n"
    "                            if ftable_presenter.trailing_active(0) then -- ghost\n"
    "                                if (ftable_presenter.trailing_tile_index = i) then\n"
    "                                    ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1; \n"
    "                                end if;\n"
    "                            elsif (ftable_presenter.rseg.tile_index = i) then -- normal\n"
    "                                ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1;  \n"
    "                            end if; \n"
    "                        else \n"
    "                            ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) - to_unsigned(EGRESS_DELAY+1,PAGE_RAM_ADDR_WIDTH); -- rptr scrollback\n"
    "                        end if;\n"
)
old_ptr_update = strip_trailing_ws(old_ptr_update)
new_ptr_update = (
    "                        -- incr rd ptr \n"
    "                        -- During pipeline fill (valid has not reached the egress yet), ignore ready.\n"
    "                        -- Once valid is at the egress, only advance on ready=1.\n"
    "                        if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then \n"
    "                            if ftable_presenter.trailing_active(0) then -- ghost\n"
    "                                if (ftable_presenter.trailing_tile_index = i) then\n"
    "                                    ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1; \n"
    "                                end if;\n"
    "                            elsif (ftable_presenter.rseg.tile_index = i) then -- normal\n"
    "                                ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1;  \n"
    "                            end if; \n"
    "                        end if;\n"
)
new_ptr_update = strip_trailing_ws(new_ptr_update)
if old_ptr_update in text:
    text = text.replace(old_ptr_update, new_ptr_update)
elif new_ptr_update not in text:
    raise SystemExit("update_preprocessed: pattern not found for presenter rptr advance patch")

old_pipe_data = (
    "                    -- pipe through the data\n"
    "                    ftable_presenter.output_data                <= page_ram_rd_data;\n"
)
old_pipe_data = strip_trailing_ws(old_pipe_data)
new_pipe_data = (
    "                    -- pipe through the data\n"
    "                    -- During an egress stall, hold the breakpoint word stable.\n"
    "                    if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then\n"
    "                        ftable_presenter.output_data            <= page_ram_rd_data;\n"
    "                    end if;\n"
)
new_pipe_data = strip_trailing_ws(new_pipe_data)
if old_pipe_data in text:
    text = text.replace(old_pipe_data, new_pipe_data)
elif new_pipe_data not in text:
    raise SystemExit("update_preprocessed: pattern not found for presenter data hold patch")

# Gate packet-presenter actions on a valid word at the egress.
old_ready_cond = "                            if (aso_egress_ready = '1') then \n"
new_ready_cond = "                            if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '1' and aso_egress_ready = '1') then \n"
old_ready_cond = strip_trailing_ws(old_ready_cond)
new_ready_cond = strip_trailing_ws(new_ready_cond)
if old_ready_cond in text:
    text = text.replace(old_ready_cond, new_ready_cond)
elif new_ready_cond not in text:
    raise SystemExit("update_preprocessed: pattern not found for presenter ready gating patch")

old_present_stall = (
    "                            else -- corner case : ready deasserted during packet transmission \n"
    "                                ftable_presenter_state                      <= RESTART;\n"
    "                                -- ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) - to_unsigned(EGRESS_DELAY+1,PAGE_RAM_ADDR_WIDTH); -- rptr scrollback\n"
    "                                ftable_presenter.output_data_valid          <= (0 => '1', others => '0'); -- reset the pipeline\n"
    "                            end if;\n"
)
new_present_stall = (
    "                            else -- corner case : ready deasserted during packet transmission \n"
    "                                -- Restart: roll back the read pointer to the current output word and refill the pipeline.\n"
    "                                if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '1') then\n"
    "                                    ftable_presenter_state                      <= RESTART;\n"
    "                                    ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) - to_unsigned(EGRESS_DELAY+1,PAGE_RAM_ADDR_WIDTH); -- rptr scrollback\n"
    "                                    ftable_presenter.output_data_valid          <= (others => '0'); -- restart pipeline\n"
    "                                end if;\n"
    "                            end if;\n"
)
old_present_stall = strip_trailing_ws(old_present_stall)
new_present_stall = strip_trailing_ws(new_present_stall)
if old_present_stall in text:
    text = text.replace(old_present_stall, new_present_stall)
elif new_present_stall in text:
    pass
else:
    # Accept already-guarded RESTART logic emitted by the .terp template.
    if ("corner case : ready deasserted during packet transmission" in text
        and "ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) - to_unsigned(EGRESS_DELAY+1,PAGE_RAM_ADDR_WIDTH)" in text
        and "ftable_presenter.output_data_valid          <= (others => '0'); -- restart pipeline" in text):
        pass
    else:
        raise SystemExit("update_preprocessed: pattern not found for presenter stall guard patch")

# Hold the registered page RAM data and trailing-active pipeline during a stall (valid=1, ready=0),
# otherwise the synchronous RAM output will overwrite in-flight words and cause duplicates on resume.
old_page_tile_reg = "            page_tile_rd_data_reg           <= page_tile_rd_data;\n"
new_page_tile_reg = (
    "            -- Keep the page RAM data pipeline aligned with egress backpressure.\n"
    "            -- If a valid word is stalled at the egress (valid=1, ready=0), hold this stage too,\n"
    "            -- otherwise the registered RAM output would overwrite in-flight words and cause duplicates.\n"
    "            if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then\n"
    "                page_tile_rd_data_reg           <= page_tile_rd_data;\n"
    "            end if;\n"
)
if old_page_tile_reg in text:
    text = text.replace(old_page_tile_reg, new_page_tile_reg)
elif "page_tile_rd_data_reg           <= page_tile_rd_data;" not in text:
    raise SystemExit("update_preprocessed: pattern not found for page_tile_rd_data_reg hold patch")

old_trailing_pipe = (
    "            -- trailing active pipeline\n"
    "            for i in 0 to EGRESS_DELAY-1 loop\n"
    "                ftable_presenter.trailing_active(i+1)          <= ftable_presenter.trailing_active(i);\n"
    "            end loop;\n"
)
new_trailing_pipe = (
    "            -- trailing active pipeline (keep aligned with output pipeline under backpressure)\n"
    "            if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then\n"
    "                for i in 0 to EGRESS_DELAY-1 loop\n"
    "                    ftable_presenter.trailing_active(i+1)          <= ftable_presenter.trailing_active(i);\n"
    "                end loop;\n"
    "            end if;\n"
)
if old_trailing_pipe in text:
    text = text.replace(old_trailing_pipe, new_trailing_pipe)
elif "trailing active pipeline (keep aligned with output pipeline under backpressure)" not in text:
    raise SystemExit("update_preprocessed: pattern not found for trailing_active hold patch")

import re

# Replace the entire RESTART branch so it refills the page RAM pipeline and does not emit externally.
restart_re = re.compile(r"(\s*when\s+RESTART\s+=>.*?)(\s*when\s+WARPING\s+=>)", flags=re.DOTALL)
m = restart_re.search(text)
if not m:
    raise SystemExit("update_preprocessed: failed to locate RESTART state block")

restart_block = (
    "\n                when RESTART => -- refill the page RAM pipeline after a backpressure event\n"
    "                    -- Re-read starting at the stalled output word address (rptr already rolled back).\n"
    "                    -- Suppress external valid in this state (see egress comb) to avoid double-accept.\n"
    "                    for i in 0 to N_TILE-1 loop\n"
    "                        if (to_integer(ftable_presenter.rseg.tile_index) = i) then\n"
    "                            ftable_presenter.output_data_valid(0)       <= '1';\n"
    "                            for j in 0 to EGRESS_DELAY-1 loop\n"
    "                                ftable_presenter.output_data_valid(j+1) <= ftable_presenter.output_data_valid(j);\n"
    "                            end loop;\n"
    "                            ftable_presenter.output_data                <= page_ram_rd_data;\n"
    "                            if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then\n"
    "                                ftable_presenter.page_ram_rptr(i)       <= ftable_presenter.page_ram_rptr(i) + 1;\n"
    "                            end if;\n"
    "                            if (ftable_presenter.output_data_valid(EGRESS_DELAY-1) = '1') then\n"
    "                                ftable_presenter_state                  <= PRESENTING;\n"
    "                            end if;\n"
    "                        end if;\n"
    "                    end loop;\n"
)

text = text[: m.start(1)] + restart_block + text[m.end(1) :]

# Gate external `valid` by presenter state so RESTART cannot be accepted.
old_egress_valid = "        aso_egress_valid                    <= ftable_presenter.output_data_valid(EGRESS_DELAY);\n"
new_egress_valid = (
    "        if (ftable_presenter_state = PRESENTING) then\n"
    "            aso_egress_valid                <= ftable_presenter.output_data_valid(EGRESS_DELAY);\n"
    "        else\n"
    "            aso_egress_valid                <= '0';\n"
    "        end if;\n"
)
if old_egress_valid in text:
    text = text.replace(old_egress_valid, new_egress_valid)
elif "if (ftable_presenter_state = PRESENTING) then" not in text:
    raise SystemExit("update_preprocessed: pattern not found for egress valid gating patch")

path.write_text(text)
PY

# Final whitespace normalization (generated PD VHDL sometimes has trailing spaces).
python - <<'PY'
from pathlib import Path

def strip_trailing_ws(s: str) -> str:
    out = "\n".join(line.rstrip() for line in s.splitlines())
    return out + ("\n" if s.endswith("\n") else "")

for fname in ("ordered_priority_queue.vhd", "ordered_priority_queue_wrapper.vhd"):
    p = Path(fname)
    if not p.exists():
        continue
    s = p.read_text()
    s2 = strip_trailing_ws(s)
    if s2 != s:
        p.write_text(s2)
PY
if [[ -n "${latest_src}" ]]; then
  echo "Updated ${DST_FILE} from ${latest_src}"
else
  echo "Updated ${DST_FILE} from template: ${TERP_TEMPLATE}"
fi

-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_rd_debug_if
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - extracted from ordered_priority_queue.terp.vhd
-- Description:         Read-only Avalon-MM debug register interface exposing OPQ internal state for bring-up.
--                      Intended to be synthesizable and low-impact (no functional datapath feedback).
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

-- Read-only debug register interface (Avalon-MM style).
--
-- This block is intended to expose internal OPQ state for bring-up/debug without
-- impacting functional datapaths.
--
-- NOTE: Register map is a WIP until it is aligned with the OPQ document header.
entity opq_rd_debug_if is
  generic (
    AVS_ADDR_WIDTH     : positive := 8;  -- word address
    N_TILE             : positive := 5;
    N_WR_SEG           : positive := 4;
    TILE_FIFO_DEPTH    : positive := 512;
    TILE_PKT_CNT_WIDTH : positive := 10
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Avalon-MM slave (read-only).
    i_avs_address       : in  std_logic_vector(AVS_ADDR_WIDTH-1 downto 0);
    i_avs_read          : in  std_logic;
    o_avs_readdata      : out std_logic_vector(31 downto 0);
    o_avs_waitrequest   : out std_logic;
    o_avs_readdatavalid : out std_logic;

    -- Debug sources (from frame-table complex for now).
    i_wr_blocked_by_rd_lock : in std_logic;
    i_mapper_state          : in std_logic_vector(2 downto 0);
    i_presenter_state       : in std_logic_vector(2 downto 0);
    i_rseg_tile_index       : in unsigned(clog2(N_TILE)-1 downto 0);
    i_wseg_tile_index       : in unsigned_array_t(0 to N_WR_SEG-1)(clog2(N_TILE)-1 downto 0);
    i_tile_wptr             : in unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    i_tile_rptr             : in unsigned_array_t(0 to N_TILE-1)(clog2(TILE_FIFO_DEPTH)-1 downto 0);
    i_tile_pkt_wcnt         : in unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0);
    i_tile_pkt_rcnt         : in unsigned_array_t(0 to N_TILE-1)(TILE_PKT_CNT_WIDTH-1 downto 0)
  );
end entity opq_rd_debug_if;

architecture rtl of opq_rd_debug_if is
  constant TILE_FIFO_ADDR_W : natural := clog2(TILE_FIFO_DEPTH);
  constant TILE_ID_W        : natural := clog2(N_TILE);

  signal rd_valid_q : std_logic := '0';
  signal rd_data_q  : std_logic_vector(31 downto 0) := (others => '0');

  subtype slv32_t is std_logic_vector(31 downto 0);

  function u32(v : unsigned) return slv32_t is
  begin
    return std_logic_vector(resize(v, 32));
  end function;
begin
  o_avs_waitrequest   <= '0';
  o_avs_readdata      <= rd_data_q;
  o_avs_readdatavalid <= rd_valid_q;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            RD_DEBUG_IF.REG
  -- @brief           Read register decode with one-cycle readdatavalid pulse
  -- @input           i_avs_address, i_avs_read, debug sources
  -- @output          o_avs_readdata/o_avs_readdatavalid
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_rd : process (i_clk) is
    variable addr_i : natural;
    variable tile_i : natural;
    variable rdata_v : std_logic_vector(31 downto 0);
  begin
    if rising_edge(i_clk) then
      rd_valid_q <= '0';
      if i_avs_read = '1' then
        rd_valid_q <= '1';
      end if;

      if (i_avs_read = '1') then
        addr_i := to_integer(unsigned(i_avs_address));
        rdata_v := (others => '0');

        case addr_i is
          when 0 =>
            -- "OPQ0"
            rdata_v := x"4F505130";

          when 1 =>
            rdata_v(7 downto 0)   := std_logic_vector(to_unsigned(N_TILE, 8));
            rdata_v(15 downto 8)  := std_logic_vector(to_unsigned(N_WR_SEG, 8));
            rdata_v(23 downto 16) := std_logic_vector(to_unsigned(TILE_FIFO_ADDR_W, 8));
            rdata_v(31 downto 24) := std_logic_vector(to_unsigned(TILE_PKT_CNT_WIDTH, 8));

          when 2 =>
            rdata_v(0)           := i_wr_blocked_by_rd_lock;
            rdata_v(3 downto 1)  := i_mapper_state;
            rdata_v(6 downto 4)  := i_presenter_state;
            rdata_v(15 downto 8) := std_logic_vector(resize(i_rseg_tile_index, 8));

          when 3 =>
            rdata_v(TILE_ID_W-1 downto 0) := std_logic_vector(i_rseg_tile_index);

          when others =>
            -- WSEG tile indices: 0x04..0x(04+N_WR_SEG-1).
            if (addr_i >= 4) and (addr_i < 4 + N_WR_SEG) then
              rdata_v(TILE_ID_W-1 downto 0) := std_logic_vector(i_wseg_tile_index(addr_i - 4));

            -- Per-tile status window: base 0x10, stride 4 words.
            --   +0: wptr
            --   +1: rptr
            --   +2: pkt_wcnt
            --   +3: pkt_rcnt
            elsif (addr_i >= 16) and (addr_i < 16 + 4*N_TILE) then
              tile_i := (addr_i - 16) / 4;
              case (addr_i - 16) mod 4 is
                when 0 =>
                  rdata_v := u32(resize(i_tile_wptr(tile_i), 32));
                when 1 =>
                  rdata_v := u32(resize(i_tile_rptr(tile_i), 32));
                when 2 =>
                  rdata_v := u32(resize(i_tile_pkt_wcnt(tile_i), 32));
                when 3 =>
                  rdata_v := u32(resize(i_tile_pkt_rcnt(tile_i), 32));
                when others =>
                  null;
              end case;
            end if;
        end case;

        rd_data_q <= rdata_v;
      end if;

      if i_rst = '1' then
        rd_valid_q <= '0';
        rd_data_q  <= (others => '0');
      end if;
    end if;
  end process;
end architecture rtl;

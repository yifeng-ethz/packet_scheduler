-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_sync_ram
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - utility extracted from ordered_priority_queue.terp.vhd
-- Description:         Simple synchronous read/write RAM with write-first behavior on address collision.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity opq_sync_ram is
  generic (
    DATA_WIDTH : positive := 40;
    ADDR_WIDTH : positive := 9
  );
  port (
    data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    read_addr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    write_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    we         : in  std_logic;
    clk        : in  std_logic;
    q          : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity opq_sync_ram;

architecture rtl of opq_sync_ram is
  type ram_t is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram : ram_t := (others => (others => '0'));
  signal q_r : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
begin
  q <= q_r;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            SYNC_RAM.REG
  -- @brief           Single-clock synchronous RAM with collision-safe read-during-write behavior
  -- @input           we, read_addr, write_addr, data
  -- @output          q
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_ram : process (clk) is
    variable rd_i : natural;
    variable wr_i : natural;
  begin
    if rising_edge(clk) then
      rd_i := to_integer(unsigned(read_addr));
      wr_i := to_integer(unsigned(write_addr));

      if we = '1' then
        ram(wr_i) <= data;
      end if;

      if (we = '1') and (read_addr = write_addr) then
        q_r <= data;
      else
        q_r <= ram(rd_i);
      end if;
    end if;
  end process;
end architecture rtl;

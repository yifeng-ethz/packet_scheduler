-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_util_pkg
-- Author:              Yifeng Wang (original OPQ) / split utilities by Codex
-- Revision:            0.1 - extracted from ordered_priority_queue.terp.vhd
-- Description:         Common utility package for OPQ split RTL (clog2, min/max, and unconstrained arrays).
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package opq_util_pkg is
  -- Integer ceil(log2(x)) for x >= 1.
  function clog2(x : positive) return natural;

  function imax(a, b : natural) return natural;
  function imin(a, b : natural) return natural;

  -- True when x is a power-of-two (x = 1,2,4,...).
  function is_pow2(x : positive) return boolean;

  -- Unconstrained array helpers (VHDL-2008).
  type slv_array_t is array (natural range <>) of std_logic_vector;
  type unsigned_array_t is array (natural range <>) of unsigned;
end package opq_util_pkg;

package body opq_util_pkg is
  function clog2(x : positive) return natural is
    variable v : natural := x - 1;
    variable r : natural := 0;
  begin
    while v > 0 loop
      r := r + 1;
      v := v / 2;
    end loop;
    return r;
  end function;

  function imax(a, b : natural) return natural is
  begin
    if a > b then
      return a;
    end if;
    return b;
  end function;

  function imin(a, b : natural) return natural is
  begin
    if a < b then
      return a;
    end if;
    return b;
  end function;

  function is_pow2(x : positive) return boolean is
    variable v : natural := x;
  begin
    -- x is power-of-two if repeated divide-by-2 ends at 1 with no remainder.
    while (v mod 2) = 0 loop
      v := v / 2;
    end loop;
    return v = 1;
  end function;
end package body opq_util_pkg;

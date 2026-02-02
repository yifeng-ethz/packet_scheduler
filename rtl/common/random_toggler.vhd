-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             random_toggler
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            1.0 - file created - Dec 18, 2025
-- Description:         Random 1-bit toggler with adjustable rate via LFSR-based pseudo-random generator.
-- ------------------------------------------------------------------------------------------------------------

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

-- general
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;
--use ieee.math_real.max;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
-- altera-specific
library altera_mf;
use altera_mf.all;

entity random_toggler is
    generic (
        LFSR_WIDTH         : positive := 16;       -- default width for LFSR
        SEED               : std_logic_vector(15 downto 0) := x"ACE1"
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;       -- synchronous active-high reset
        en        : in  std_logic;       -- enable signal
        rate_div  : in  unsigned(15 downto 0);  -- rate divider: 0=fastest, else slows toggling
        toggle_prob_pow2 : in unsigned(15 downto 0); -- toggling probability per update (1/2^K)
        dout      : out std_logic
    );
end entity random_toggler;

architecture rtl of random_toggler is
    signal lfsr       : std_logic_vector(LFSR_WIDTH-1 downto 0);
    signal q          : std_logic := '0';
    signal rate_cnt   : unsigned(rate_div'range) := (others => '0');

    function and_reduce_prefix(v : std_logic_vector; k : natural) return std_logic is
        variable a : std_logic := '1';
        variable limit : natural := k;
        variable count : natural := 0;
    begin
        if limit > v'length then
            limit := v'length;
        end if;
        if limit = 0 then
            return '1';
        end if;
        for i in v'low to v'high loop
            if count < limit then
                a := a and v(i);
                count := count + 1;
            end if;
        end loop;
        return a;
    end function;

    function galois_next(s : std_logic_vector) return std_logic_vector is
        variable n      : std_logic_vector(s'range) := s;
        variable fb     : std_logic := s(0);
    begin
        n := fb & s(s'high downto 1);
        if fb = '1' then
            if s'length >= 16 then
                n(13) := n(13) xor '1';
                n(12) := n(12) xor '1';
                n(10) := n(10) xor '1';
            end if;
        end if;
        return n;
    end function;

begin

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            RANDOM TOGGLER
    -- @brief           LFSR-based pseudo-random 1-bit toggler with rate divider and 1/2^K probability selector.
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_toggle : process(clk)
        variable k_int : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lfsr     <= SEED;
                q        <= '1';
                rate_cnt <= (others => '0');

            elsif en = '1' then
                -- rate divider: advance LFSR only when counter expires
                if rate_cnt = 0 then
                    rate_cnt <= rate_div;  -- reload

                    -- advance PRNG
                    lfsr <= galois_next(lfsr);

                    -- random toggle condition
                    k_int := to_integer(toggle_prob_pow2);
                    if k_int = 0 then
                        if lfsr(0) = '1' then
                            q <= not q;
                        end if;
                    else
                        if and_reduce_prefix(lfsr, k_int) = '1' then
                            q <= not q;
                        end if;
                    end if;
                else
                    rate_cnt <= rate_cnt - 1;
                end if;
            else
                q <= '0';
            end if;
        end if;
    end process;

    dout <= q;

end architecture rtl;

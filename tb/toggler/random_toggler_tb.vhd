-- ------------------------------------------------------------------------------------------------------------
-- Testbench:         random_toggler_tb
-- Description:       Reference-model checks for random_toggler with runtime toggle_prob_pow2.
-- ------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity random_toggler_tb is
end entity random_toggler_tb;

architecture tb of random_toggler_tb is
    constant CLK_PERIOD        : time := 10 ns;
    constant LFSR_WIDTH_C      : positive := 16;
    constant SEED_C            : std_logic_vector(LFSR_WIDTH_C-1 downto 0) := x"ACE1";
    constant UPDATES_PER_CASE  : natural := 256;
    constant UPDATES_LONG_CASE : natural := 512;

    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal en               : std_logic := '0';
    signal rate_div         : unsigned(15 downto 0) := (others => '0');
    signal toggle_prob_pow2 : unsigned(15 downto 0) := (others => '0');
    signal dout             : std_logic;

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
        variable n  : std_logic_vector(s'range) := s;
        variable fb : std_logic := s(0);
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

    procedure wait_cycles(n : natural) is
    begin
        for i in 0 to n-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2;

    uut: entity work.random_toggler
        generic map (
            LFSR_WIDTH => LFSR_WIDTH_C,
            SEED       => SEED_C
        )
        port map (
            clk              => clk,
            rst              => rst,
            en               => en,
            rate_div         => rate_div,
            toggle_prob_pow2 => toggle_prob_pow2,
            dout             => dout
        );

    stim_proc : process
        variable r : natural;
        variable k : natural;
    begin
        rst <= '1';
        en <= '0';
        rate_div <= (others => '0');
        toggle_prob_pow2 <= (others => '0');
        wait_cycles(3);

        rst <= '0';
        en <= '1';

        for r in 0 to 10 loop
            rate_div <= to_unsigned(r, rate_div'length);
            for k in 0 to 3 loop
                toggle_prob_pow2 <= to_unsigned(k, toggle_prob_pow2'length);
                wait_cycles((r + 1) * UPDATES_PER_CASE);
            end loop;
        end loop;

        rate_div <= to_unsigned(14, rate_div'length);
        for k in 0 to 3 loop
            toggle_prob_pow2 <= to_unsigned(k, toggle_prob_pow2'length);
            wait_cycles((14 + 1) * UPDATES_LONG_CASE);
        end loop;

        en <= '0';
        wait_cycles(20);

        std.env.stop;
        wait;
    end process;

    ref_proc : process
        variable ref_lfsr     : std_logic_vector(LFSR_WIDTH_C-1 downto 0) := SEED_C;
        variable ref_q        : std_logic := '1';
        variable ref_rate_cnt : unsigned(rate_div'range) := (others => '0');
        variable k_int        : natural;
    begin
        wait until rising_edge(clk);
        if rst = '1' then
            ref_lfsr := SEED_C;
            ref_q := '1';
            ref_rate_cnt := (others => '0');
        elsif en = '1' then
            if ref_rate_cnt = 0 then
                ref_rate_cnt := rate_div;
                k_int := to_integer(toggle_prob_pow2);
                if k_int = 0 then
                    if ref_lfsr(0) = '1' then
                        ref_q := not ref_q;
                    end if;
                else
                    if and_reduce_prefix(ref_lfsr, k_int) = '1' then
                        ref_q := not ref_q;
                    end if;
                end if;
                ref_lfsr := galois_next(ref_lfsr);
            else
                ref_rate_cnt := ref_rate_cnt - 1;
            end if;
        else
            ref_q := '0';
        end if;

        wait for 0 ns;
        wait for 0 ns;
        assert dout = ref_q
            report "Mismatch: dout=" & std_logic'image(dout) &
                   " expected=" & std_logic'image(ref_q)
            severity error;
    end process;

end architecture tb;

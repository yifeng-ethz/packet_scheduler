-- ------------------------------------------------------------------------------------------------------------
-- Testbench:         ordered_priority_queue_tb
-- Description:       Basic ingress sequence (preamble + header + subheader + hits) and egress activity check.
-- ------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity ordered_priority_queue_tb is
end entity ordered_priority_queue_tb;

architecture tb of ordered_priority_queue_tb is
    constant CLK_PERIOD   : time := 4 ns; -- 250 MHz
    constant SUBHDR_COUNT : natural := 128;
    function imax(a, b : natural) return natural is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function;
    constant MIN_SOP_CYC  : natural := 4000; -- 16 us / 4 ns
    constant PKT_LEN_CYC  : natural := 1 + 4 + SUBHDR_COUNT + 1 + 1; -- preamble + header + subhdrs + extra hit + trailer
    constant PKT_GAP_CYC  : natural := imax(MIN_SOP_CYC, PKT_LEN_CYC); -- enforce min SOP spacing
    -- running_ts in the DUT advances one subheader tick per round (16 cycles -> lower 4 bits), so
    -- advance the header timestamp by a full epoch worth of subheaders.
    constant TS_STEP      : unsigned(47 downto 0) := to_unsigned(SUBHDR_COUNT * 16, 48);

    constant K285 : std_logic_vector(7 downto 0) := "10111100";
    constant K284 : std_logic_vector(7 downto 0) := "10011100";
    constant K237 : std_logic_vector(7 downto 0) := "11110111";

    signal d_clk   : std_logic := '0';
    signal d_reset : std_logic := '1';

    signal asi_ingress_0_data          : std_logic_vector(35 downto 0) := (others => '0');
    signal asi_ingress_0_valid         : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_0_channel       : std_logic_vector(1 downto 0) := (others => '0');
    signal asi_ingress_0_startofpacket : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_0_endofpacket   : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_0_error         : std_logic_vector(2 downto 0) := (others => '0');

    signal asi_ingress_1_data          : std_logic_vector(35 downto 0) := (others => '0');
    signal asi_ingress_1_valid         : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_1_channel       : std_logic_vector(1 downto 0) := (others => '0');
    signal asi_ingress_1_startofpacket : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_1_endofpacket   : std_logic_vector(0 downto 0) := (others => '0');
    signal asi_ingress_1_error         : std_logic_vector(2 downto 0) := (others => '0');

    signal aso_egress_data          : std_logic_vector(35 downto 0);
    signal aso_egress_valid         : std_logic;
    signal aso_egress_ready         : std_logic := '0';
    signal aso_egress_startofpacket : std_logic;
    signal aso_egress_endofpacket   : std_logic;
    signal aso_egress_error         : std_logic_vector(2 downto 0);

    signal egress_seen : std_logic := '0';
    signal sop_seen    : std_logic := '0';
    signal preamble_seen : std_logic := '0';
    signal cafebabe_seen : std_logic := '0';
    signal deadbeef_seen : std_logic := '0';
    signal hit_burst_checked : std_logic := '0';

    signal t_pkt1_sop : time := 0 ns;
    signal t_first_egress_sop : time := 0 ns;

    function make_preamble(dt_type : std_logic_vector(5 downto 0);
                           feb_id  : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable data : std_logic_vector(31 downto 0) := (others => '0');
    begin
        data(31 downto 26) := dt_type;
        data(23 downto 8)  := feb_id;
        data(7 downto 0)   := K285;
        return data;
    end function;

    function make_subheader(shd_ts : std_logic_vector(7 downto 0);
                            hit_cnt : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable data : std_logic_vector(31 downto 0) := (others => '0');
    begin
        data(31 downto 24) := shd_ts;
        data(15 downto 8)  := hit_cnt;
        data(7 downto 0)   := K237;
        return data;
    end function;

    function make_trailer return std_logic_vector is
        variable data : std_logic_vector(31 downto 0) := (others => '0');
    begin
        data(7 downto 0) := K284;
        return data;
    end function;

    procedure wait_cycles(n : natural) is
    begin
        for i in 0 to n-1 loop
            wait until rising_edge(d_clk);
        end loop;
    end procedure;

    procedure drive_dual_word(
        signal data0  : out std_logic_vector(35 downto 0);
        signal valid0 : out std_logic_vector(0 downto 0);
        signal sop0   : out std_logic_vector(0 downto 0);
        signal eop0   : out std_logic_vector(0 downto 0);
        signal err0   : out std_logic_vector(2 downto 0);
        signal data1  : out std_logic_vector(35 downto 0);
        signal valid1 : out std_logic_vector(0 downto 0);
        signal sop1   : out std_logic_vector(0 downto 0);
        signal eop1   : out std_logic_vector(0 downto 0);
        signal err1   : out std_logic_vector(2 downto 0);
        data32_0      : std_logic_vector(31 downto 0);
        datak_0       : std_logic_vector(3 downto 0);
        sop_0         : std_logic;
        eop_0         : std_logic;
        err_0         : std_logic_vector(2 downto 0);
        data32_1      : std_logic_vector(31 downto 0);
        datak_1       : std_logic_vector(3 downto 0);
        sop_1         : std_logic;
        eop_1         : std_logic;
        err_1         : std_logic_vector(2 downto 0)
    ) is
    begin
        data0    <= datak_0 & data32_0;
        valid0(0) <= '1';
        sop0(0)  <= sop_0;
        eop0(0)  <= eop_0;
        err0     <= err_0;

        data1    <= datak_1 & data32_1;
        valid1(0) <= '1';
        sop1(0)  <= sop_1;
        eop1(0)  <= eop_1;
        err1     <= err_1;

        wait until rising_edge(d_clk);

        data0    <= (others => '0');
        valid0(0) <= '0';
        sop0(0)  <= '0';
        eop0(0)  <= '0';
        err0     <= (others => '0');

        data1    <= (others => '0');
        valid1(0) <= '0';
        sop1(0)  <= '0';
        eop1(0)  <= '0';
        err1     <= (others => '0');
    end procedure;

    procedure drive_header(
        signal data0  : out std_logic_vector(35 downto 0);
        signal valid0 : out std_logic_vector(0 downto 0);
        signal sop0   : out std_logic_vector(0 downto 0);
        signal eop0   : out std_logic_vector(0 downto 0);
        signal err0   : out std_logic_vector(2 downto 0);
        signal data1  : out std_logic_vector(35 downto 0);
        signal valid1 : out std_logic_vector(0 downto 0);
        signal sop1   : out std_logic_vector(0 downto 0);
        signal eop1   : out std_logic_vector(0 downto 0);
        signal err1   : out std_logic_vector(2 downto 0);
        ts_base       : unsigned(47 downto 0);
        pkg_cnt0      : unsigned(15 downto 0);
        pkg_cnt1      : unsigned(15 downto 0);
        subh_cnt      : unsigned(15 downto 0);
        hit_cnt0      : unsigned(15 downto 0);
        hit_cnt1      : unsigned(15 downto 0)
    ) is
        variable word0 : std_logic_vector(31 downto 0);
        variable word1_lane0 : std_logic_vector(31 downto 0);
        variable word1_lane1 : std_logic_vector(31 downto 0);
        variable word2_lane0 : std_logic_vector(31 downto 0);
        variable word2_lane1 : std_logic_vector(31 downto 0);
        variable word3 : std_logic_vector(31 downto 0);
    begin
        word0 := std_logic_vector(ts_base(47 downto 16));
        word1_lane0 := std_logic_vector(ts_base(15 downto 0)) & std_logic_vector(pkg_cnt0);
        word1_lane1 := std_logic_vector(ts_base(15 downto 0)) & std_logic_vector(pkg_cnt1);
        word2_lane0 := std_logic_vector(subh_cnt) & std_logic_vector(hit_cnt0);
        word2_lane1 := std_logic_vector(subh_cnt) & std_logic_vector(hit_cnt1);
        word3 := (others => '0');

        drive_dual_word(data0, valid0, sop0, eop0, err0,
                        data1, valid1, sop1, eop1, err1,
                        word0, "0000", '0', '0', "000",
                        word0, "0000", '0', '0', "000");
        drive_dual_word(data0, valid0, sop0, eop0, err0,
                        data1, valid1, sop1, eop1, err1,
                        word1_lane0, "0000", '0', '0', "000",
                        word1_lane1, "0000", '0', '0', "000");
        drive_dual_word(data0, valid0, sop0, eop0, err0,
                        data1, valid1, sop1, eop1, err1,
                        word2_lane0, "0000", '0', '0', "000",
                        word2_lane1, "0000", '0', '0', "000");
        drive_dual_word(data0, valid0, sop0, eop0, err0,
                        data1, valid1, sop1, eop1, err1,
                        word3, "0000", '0', '1', "000",
                        word3, "0000", '0', '1', "000");
    end procedure;

    procedure drive_lane_word(
        signal data    : out std_logic_vector(35 downto 0);
        signal valid   : out std_logic_vector(0 downto 0);
        signal sop_sig : out std_logic_vector(0 downto 0);
        signal eop_sig : out std_logic_vector(0 downto 0);
        signal err_sig : out std_logic_vector(2 downto 0);
        data32         : std_logic_vector(31 downto 0);
        datak          : std_logic_vector(3 downto 0);
        sop_bit        : std_logic;
        eop_bit        : std_logic;
        err_bits       : std_logic_vector(2 downto 0)
    ) is
    begin
        data      <= datak & data32;
        valid(0)  <= '1';
        sop_sig(0) <= sop_bit;
        eop_sig(0) <= eop_bit;
        err_sig   <= err_bits;
        wait until rising_edge(d_clk);
        data      <= (others => '0');
        valid(0)  <= '0';
        sop_sig(0) <= '0';
        eop_sig(0) <= '0';
        err_sig   <= (others => '0');
    end procedure;

begin
    d_clk <= not d_clk after CLK_PERIOD / 2;

    dut : entity work.debug_queue_system_ordered_priority_queue_250722_624ymiy
        generic map (
            N_LANE => 2
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

    proc_monitor : process(d_clk)
        type hit_words_t is array (0 to 3) of std_logic_vector(31 downto 0);
        variable capturing_hits : boolean := false;
        variable hits_remaining : natural := 0;
        variable hit_idx : natural := 0;
        variable hit_words : hit_words_t := (others => (others => '0'));
        variable data32 : std_logic_vector(31 downto 0);
        variable datak  : std_logic_vector(3 downto 0);
    begin
        if rising_edge(d_clk) then
            if aso_egress_valid = '1' then
                egress_seen <= '1';
                if aso_egress_startofpacket = '1' then
                    sop_seen <= '1';
                    if t_first_egress_sop = 0 ns then
                        t_first_egress_sop <= now;
                    end if;
                end if;
                datak  := aso_egress_data(35 downto 32);
                data32 := aso_egress_data(31 downto 0);
                -- track specific content to catch missing headers/hits
                if datak = "0001" and data32(7 downto 0) = K285 then
                    preamble_seen <= '1';
                end if;
                if datak = "0000" then
                    if data32 = x"CAFEBABE" then
                        cafebabe_seen <= '1';
                    elsif data32 = x"DEADBEEF" then
                        deadbeef_seen <= '1';
                    end if;
                end if;

                if capturing_hits then
                    assert datak = "0000" report "Expected hit word after K237 subheader" severity error;
                    hit_words(hit_idx) := data32;
                    hit_idx := hit_idx + 1;
                    hits_remaining := hits_remaining - 1;
                    if hits_remaining = 0 then
                        capturing_hits := false;
                        assert hit_words(0) = x"DEADBEEF" report "Hit[0] mismatch after first hit subheader" severity error;
                        assert hit_words(1) = x"0BADBEEF" report "Hit[1] mismatch after first hit subheader" severity error;
                        assert hit_words(2) = x"CAFEBABE" report "Hit[2] mismatch after first hit subheader" severity error;
                        assert hit_words(3) = x"0BADCAFE" report "Hit[3] mismatch after first hit subheader" severity error;
                        hit_burst_checked <= '1';
                    end if;
                else
                    if datak = "0001" and data32(7 downto 0) = K237 and hit_burst_checked = '0' then
                        if unsigned(data32(23 downto 8)) /= 0 then
                            assert unsigned(data32(23 downto 8)) = 4 report "Unexpected hit_cnt on first hit subheader" severity error;
                            capturing_hits := true;
                            hits_remaining := 4;
                            hit_idx := 0;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    proc_stim : process
        variable preamble : std_logic_vector(31 downto 0);
        variable subhdr   : std_logic_vector(31 downto 0);
        variable idx      : natural;
        variable hit_cnt0    : std_logic_vector(7 downto 0);
        variable hit_cnt1    : std_logic_vector(7 downto 0);
        variable shd_ts      : std_logic_vector(7 downto 0);
        variable shd_ts_base : natural;
    begin
        d_reset <= '1';
        wait_cycles(4);
        d_reset <= '0';
        wait_cycles(4);
        aso_egress_ready <= '1'; -- keep egress ready throughout to allow presenter to drain as soon as data is available

        asi_ingress_0_channel <= "00";
        asi_ingress_1_channel <= "01";

        -- Packet 0: lane 0 and lane 1 share the same ts, both lanes have 1 hit on the first subheader.
        preamble := make_preamble("000001", x"0001");
        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        preamble, "0001", '1', '0', "000",
                        preamble, "0001", '1', '0', "000"); -- SOP asserted on both lanes for K285
        drive_header(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                     asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                     to_unsigned(0,48), to_unsigned(0,16), to_unsigned(0,16),
                     to_unsigned(SUBHDR_COUNT-1,16), to_unsigned(2,16), to_unsigned(2,16));

        -- epoch 0 subheaders start at ts = 1 (upstream behavior) and only emit 127 subheaders
        shd_ts_base := 1;
        for idx in 0 to SUBHDR_COUNT-2 loop
            shd_ts   := std_logic_vector(to_unsigned((shd_ts_base + idx) mod 256, 8));
            hit_cnt0 := x"00";
            hit_cnt1 := x"00";

            if idx = 0 then
                -- first subheader carries two hits per lane so block_length > 0
                hit_cnt0 := x"02";
                hit_cnt1 := x"02";
                drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                                asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                                make_subheader(shd_ts, hit_cnt0), "0001", '1', '0', "000",
                                make_subheader(shd_ts, hit_cnt1), "0001", '1', '0', "000");
                -- drive two hit words per lane, aligned across lanes so both parsers
                -- complete their WR_HITS phase in lockstep.
                drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                                asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                                x"DEADBEEF", "0000", '0', '0', "000",
                                x"CAFEBABE", "0000", '0', '0', "000");
                drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                                asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                                x"0BADBEEF", "0000", '0', '1', "000",
                                x"0BADCAFE", "0000", '0', '1', "000");
            else
                drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                                asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                                make_subheader(shd_ts, hit_cnt0), "0001", '1', '1', "000",
                                make_subheader(shd_ts, hit_cnt1), "0001", '1', '1', "000");
            end if;
        end loop;

        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        make_trailer, "0001", '0', '1', "000",
                        make_trailer, "0001", '0', '1', "000");

        -- Packet 1 after 16 us gap, same ts pattern.
        wait_cycles(PKT_GAP_CYC);

        t_pkt1_sop <= now;
        preamble := make_preamble("000001", x"0001");
        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        preamble, "0001", '1', '0', "000",
                        preamble, "0001", '1', '0', "000");
        drive_header(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                     asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                     TS_STEP, to_unsigned(1,16), to_unsigned(1,16),
                     to_unsigned(SUBHDR_COUNT,16), to_unsigned(0,16), to_unsigned(0,16));

        -- epoch 1 subheaders start at ts = SUBHDR_COUNT and continue forward
        shd_ts_base := SUBHDR_COUNT;
        for idx in 0 to SUBHDR_COUNT-1 loop
            shd_ts   := std_logic_vector(to_unsigned((shd_ts_base + idx) mod 256, 8));
            hit_cnt0 := x"00";
            hit_cnt1 := x"00";
            drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                            asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                            make_subheader(shd_ts, hit_cnt0), "0001", '1', '1', "000",
                            make_subheader(shd_ts, hit_cnt1), "0001", '1', '1', "000");
        end loop;

        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        make_trailer, "0001", '1', '1', "000",
                        make_trailer, "0001", '1', '1', "000");

        -- Packet 2 after another 16 us gap, used to flush epoch 1 results to egress.
        wait_cycles(PKT_GAP_CYC);

        preamble := make_preamble("000001", x"0001");
        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        preamble, "0001", '1', '0', "000",
                        preamble, "0001", '1', '0', "000");
        drive_header(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                     asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                     TS_STEP + TS_STEP, to_unsigned(2,16), to_unsigned(2,16),
                     to_unsigned(SUBHDR_COUNT,16), to_unsigned(0,16), to_unsigned(0,16));

        -- epoch 2 subheaders start at ts = 2*SUBHDR_COUNT
        shd_ts_base := SUBHDR_COUNT * 2;
        for idx in 0 to SUBHDR_COUNT-1 loop
            shd_ts   := std_logic_vector(to_unsigned((shd_ts_base + idx) mod 256, 8));
            hit_cnt0 := x"00";
            hit_cnt1 := x"00";
            drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                            asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                            make_subheader(shd_ts, hit_cnt0), "0001", '1', '1', "000",
                            make_subheader(shd_ts, hit_cnt1), "0001", '1', '1', "000");
        end loop;

        drive_dual_word(asi_ingress_0_data, asi_ingress_0_valid, asi_ingress_0_startofpacket, asi_ingress_0_endofpacket, asi_ingress_0_error,
                        asi_ingress_1_data, asi_ingress_1_valid, asi_ingress_1_startofpacket, asi_ingress_1_endofpacket, asi_ingress_1_error,
                        make_trailer, "0001", '1', '1', "000",
                        make_trailer, "0001", '1', '1', "000");

        wait_cycles(60000);
        assert egress_seen = '1' report "No egress activity observed" severity error;
        assert sop_seen = '1' report "No egress SOP observed" severity warning;
        assert preamble_seen = '1' report "No egress preamble (K285) observed" severity error;
        assert hit_burst_checked = '1' report "First hit subheader burst not validated" severity error;
        assert cafebabe_seen = '1' report "CAFEBABE hit not observed on egress" severity error;
        assert deadbeef_seen = '1' report "DEADBEEF hit not observed on egress" severity error;
        assert t_first_egress_sop >= t_pkt1_sop report "Egress SOP observed before packet 1 ingress SOP" severity error;

        std.env.stop;
        wait;
    end process;

end architecture tb;

-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_ingress_parser
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Parses per-lane ingress Avalon-ST words into lane FIFO hit data and ticket FIFO
--                      descriptors. Trims hits beyond N_HIT to avoid downstream overflow.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.opq_util_pkg.all;

-- Ingress parser (split from ordered_priority_queue):
--   - Detects K285/K237/K284 on the ingress stream
--   - Trims hits beyond N_HIT (drops the extra hit words)
--   - Writes hit words into per-lane lane-FIFO
--   - Writes a ticket (ts + lane offset + length + alert flags) when the hit block is complete
--
-- Notes:
--   - The lane FIFO stores hit words only (subheaders are reconstructed by the allocator).
--   - `o_lane_wr_addr` / `o_ticket_wr_addr` follow the monolithic convention: write_addr = wptr-1.
entity opq_ingress_parser is
  generic (
    N_LANE           : positive := 2;
    INGRESS_DATA_WIDTH  : positive := 32;
    INGRESS_DATAK_WIDTH : positive := 4;
    CHANNEL_WIDTH    : positive := 2;

    LANE_FIFO_DEPTH  : positive := 1024;
    LANE_FIFO_WIDTH  : positive := 40;

    TICKET_FIFO_DEPTH : positive := 256;

    HIT_SIZE         : positive := 1;
    N_HIT            : positive := 255;

    FRAME_SERIAL_SIZE    : positive := 16;
    FRAME_SUBH_CNT_SIZE  : positive := 16;
    FRAME_HIT_CNT_SIZE   : positive := 16;

    -- Must match the ticket width used by the top-level (opq_top).
    --
    -- NOTE: Quartus' VHDL front-end is picky about user-defined function calls
    --       in generic default expressions, so the default here is a safe
    --       constant and opq_top always overrides it.
    TICKET_FIFO_DATA_WIDTH : positive := 96
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    i_ingress_data          : in  slv_array_t(0 to N_LANE-1)(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0);
    i_ingress_valid         : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_channel       : in  slv_array_t(0 to N_LANE-1)(CHANNEL_WIDTH-1 downto 0);
    i_ingress_startofpacket : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_endofpacket   : in  std_logic_vector(N_LANE-1 downto 0);
    i_ingress_error         : in  slv_array_t(0 to N_LANE-1)(2 downto 0);

    -- Credit return paths (optional; can be tied low/zero for unit tests).
    i_lane_credit_update_valid   : in  std_logic_vector(N_LANE-1 downto 0);
    i_lane_credit_update         : in  unsigned_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH)-1 downto 0);
    i_ticket_credit_update_valid : in  std_logic_vector(N_LANE-1 downto 0);
    i_ticket_credit_update       : in  unsigned_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);

    -- Lane FIFO write port (hits only).
    o_lane_we      : out std_logic_vector(N_LANE-1 downto 0);
    o_lane_wptr    : out unsigned_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH)-1 downto 0);
    o_lane_wdata   : out slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);
    o_lane_wr_addr : out slv_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH)-1 downto 0);

    -- Ticket FIFO write port.
    o_ticket_we      : out std_logic_vector(N_LANE-1 downto 0);
    o_ticket_wptr    : out unsigned_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);
    o_ticket_wdata   : out slv_array_t(0 to N_LANE-1)(TICKET_FIFO_DATA_WIDTH-1 downto 0);
    o_ticket_wr_addr : out slv_array_t(0 to N_LANE-1)(clog2(TICKET_FIFO_DEPTH)-1 downto 0);

    -- Debug visibility.
    o_trim_drop_active : out std_logic_vector(N_LANE-1 downto 0)
  );
end entity opq_ingress_parser;

architecture rtl of opq_ingress_parser is
  constant K285 : std_logic_vector(7 downto 0) := x"BC";
  constant K284 : std_logic_vector(7 downto 0) := x"9C";
  constant K237 : std_logic_vector(7 downto 0) := x"F7";

  constant LANE_FIFO_ADDR_W   : natural := clog2(LANE_FIFO_DEPTH);
  constant TICKET_FIFO_ADDR_W : natural := clog2(TICKET_FIFO_DEPTH);
  constant MAX_PKT_LENGTH_BITS : natural := clog2(HIT_SIZE*N_HIT);
  constant N_HIT_SAT : natural := imin(N_HIT, 2**MAX_PKT_LENGTH_BITS - 1);
  constant LANE_FIFO_MAX_CREDIT  : natural := LANE_FIFO_DEPTH - 2;
  constant TICKET_FIFO_MAX_CREDIT : natural := TICKET_FIFO_DEPTH - 1;

  constant TICKET_TS_LO            : natural := 0;
  constant TICKET_TS_HI            : natural := 47;
  constant TICKET_LANE_RD_OFST_LO  : natural := 48;
  constant TICKET_LANE_RD_OFST_HI  : natural := 48 + LANE_FIFO_ADDR_W - 1;
  constant TICKET_BLOCK_LEN_LO     : natural := 48 + LANE_FIFO_ADDR_W;
  constant TICKET_BLOCK_LEN_HI     : natural := 48 + LANE_FIFO_ADDR_W + MAX_PKT_LENGTH_BITS - 1;
  constant TICKET_ALT_EOP_LOC      : natural := TICKET_FIFO_DATA_WIDTH - 2;
  constant TICKET_ALT_SOP_LOC      : natural := TICKET_FIFO_DATA_WIDTH - 1;

  constant TICKET_SERIAL_LO : natural := 0;
  constant TICKET_SERIAL_HI : natural := FRAME_SERIAL_SIZE-1;
  constant TICKET_N_SUBH_LO : natural := FRAME_SERIAL_SIZE;
  constant TICKET_N_SUBH_HI : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  constant TICKET_N_HIT_LO  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  constant TICKET_N_HIT_HI  : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;

  subtype lane_addr_t is unsigned(LANE_FIFO_ADDR_W-1 downto 0);
  subtype ticket_addr_t is unsigned(TICKET_FIFO_ADDR_W-1 downto 0);
  subtype hit_cnt_t is unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);

  type ingress_state_t is (IDLE, UPDATE_HEADER_TS, WR_HITS, MASK_PKT_EXTENDED, RESET);
  type ingress_states_t is array (0 to N_LANE-1) of ingress_state_t;
  signal st : ingress_states_t := (others => RESET);

  type ingress_reg_t is record
    lane_we     : std_logic;
    lane_wptr   : lane_addr_t;
    lane_wdata  : std_logic_vector(LANE_FIFO_WIDTH-1 downto 0);
    lane_credit : lane_addr_t;

    ticket_we     : std_logic;
    ticket_wptr   : ticket_addr_t;
    ticket_wdata  : std_logic_vector(TICKET_FIFO_DATA_WIDTH-1 downto 0);
    ticket_credit : ticket_addr_t;

    running_ts       : unsigned(47 downto 0);
    pending_ticket_ts : unsigned(47 downto 0);

    hdr_flow : natural range 0 to 3;
    pkg_cnt  : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
    running_shd_cnt : unsigned(FRAME_SUBH_CNT_SIZE-1 downto 0);
    hit_cnt  : unsigned(FRAME_HIT_CNT_SIZE-1 downto 0);

    shd_len_raw  : hit_cnt_t;
    shd_len      : hit_cnt_t;
    shd_rx_cnt   : hit_cnt_t;
    shd_trim_drop : std_logic;

    lane_start_addr : lane_addr_t;
    alert_sop : std_logic;
    alert_eop : std_logic;
  end record;

  constant REG_RESET : ingress_reg_t := (
    lane_we => '0',
    lane_wptr => (others => '0'),
    lane_wdata => (others => '0'),
    lane_credit => to_unsigned(LANE_FIFO_MAX_CREDIT, LANE_FIFO_ADDR_W),
    ticket_we => '0',
    ticket_wptr => (others => '0'),
    ticket_wdata => (others => '0'),
    ticket_credit => to_unsigned(TICKET_FIFO_MAX_CREDIT, TICKET_FIFO_ADDR_W),
    running_ts => (others => '0'),
    pending_ticket_ts => (others => '0'),
    hdr_flow => 0,
    pkg_cnt => (others => '0'),
    running_shd_cnt => (others => '0'),
    hit_cnt => (others => '0'),
    shd_len_raw => (others => '0'),
    shd_len => (others => '0'),
    shd_rx_cnt => (others => '0'),
    shd_trim_drop => '0',
    lane_start_addr => (others => '0'),
    alert_sop => '0',
    alert_eop => '0'
  );

  type ingress_regs_t is array (0 to N_LANE-1) of ingress_reg_t;
  signal r : ingress_regs_t := (others => REG_RESET);

  signal is_subheader : std_logic_vector(N_LANE-1 downto 0);
  signal is_preamble  : std_logic_vector(N_LANE-1 downto 0);
  signal is_trailer   : std_logic_vector(N_LANE-1 downto 0);
  signal hdr_err      : std_logic_vector(N_LANE-1 downto 0);
  signal shd_err      : std_logic_vector(N_LANE-1 downto 0);
  signal hit_err      : std_logic_vector(N_LANE-1 downto 0);
  signal subh_hit_cnt_raw : unsigned_array_t(0 to N_LANE-1)(7 downto 0);
  signal subh_hit_cnt_trim : unsigned_array_t(0 to N_LANE-1)(7 downto 0);
  signal subh_shd_ts  : slv_array_t(0 to N_LANE-1)(7 downto 0);
begin
  -- Lane FIFO is a ring buffer; pointer truncation assumes power-of-two depth.
  assert is_pow2(LANE_FIFO_DEPTH)
    report "OPQ: LANE_FIFO_DEPTH must be a power-of-two"
    severity failure;

  -- Decode ingress word types (byte_is_k + low byte).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            INGRESS_PARSER.DECODE
  -- @brief           Decode K285/K237/K284 word classes and extract per-subheader hit count + timestamp
  -- @input           i_ingress_data, i_ingress_error
  -- @output          is_subheader/is_preamble/is_trailer, subh_hit_cnt_raw/subh_hit_cnt_trim, subh_shd_ts
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_decode : process (all) is
  begin
    for i in 0 to N_LANE-1 loop
      if (i_ingress_data(i)(35 downto 32) = "0001") and (i_ingress_data(i)(7 downto 0) = K237) then
        is_subheader(i) <= '1';
      else
        is_subheader(i) <= '0';
      end if;

      if (i_ingress_data(i)(35 downto 32) = "0001") and (i_ingress_data(i)(7 downto 0) = K285) then
        is_preamble(i) <= '1';
      else
        is_preamble(i) <= '0';
      end if;

      if (i_ingress_data(i)(35 downto 32) = "0001") and (i_ingress_data(i)(7 downto 0) = K284) then
        is_trailer(i) <= '1';
      else
        is_trailer(i) <= '0';
      end if;

      hit_err(i) <= i_ingress_error(i)(0);
      shd_err(i) <= i_ingress_error(i)(1);
      hdr_err(i) <= i_ingress_error(i)(2);

      subh_hit_cnt_raw(i) <= unsigned(i_ingress_data(i)(15 downto 8));
      subh_shd_ts(i) <= i_ingress_data(i)(31 downto 24);
      if unsigned(i_ingress_data(i)(15 downto 8)) > to_unsigned(N_HIT_SAT, 8) then
        subh_hit_cnt_trim(i) <= to_unsigned(N_HIT_SAT, 8);
      else
        subh_hit_cnt_trim(i) <= unsigned(i_ingress_data(i)(15 downto 8));
      end if;
    end loop;
  end process;

  -- Outputs.
  gen_out : for i in 0 to N_LANE-1 generate
    o_lane_we(i)      <= r(i).lane_we;
    o_lane_wptr(i)    <= r(i).lane_wptr;
    o_lane_wdata(i)   <= r(i).lane_wdata;
    o_lane_wr_addr(i) <= std_logic_vector(r(i).lane_wptr - 1);

    o_ticket_we(i)      <= r(i).ticket_we;
    o_ticket_wptr(i)    <= r(i).ticket_wptr;
    o_ticket_wdata(i)   <= r(i).ticket_wdata;
    o_ticket_wr_addr(i) <= std_logic_vector(r(i).ticket_wptr - 1);

    o_trim_drop_active(i) <= r(i).shd_trim_drop;
  end generate;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            INGRESS_PARSER.REG
  -- @brief           Per-lane parse state machine: collect hits, emit tickets, and maintain running timestamps
  -- @input           i_ingress_valid/SOP/EOP, decode flags, credit returns
  -- @output          lane FIFO writes, ticket FIFO writes, o_trim_drop_active
  -- @description     Subheaders are SOP-delimited per OPQ framing; hit words follow until EOP (or until N_HIT).
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_ingress : process (i_clk) is
    variable ticket_v : std_logic_vector(TICKET_FIFO_DATA_WIDTH-1 downto 0);
    variable lane_v   : std_logic_vector(LANE_FIFO_WIDTH-1 downto 0);
    variable shd_len_raw_v : hit_cnt_t;
    variable shd_len_v : hit_cnt_t;
    variable is_last_keep : boolean;
    variable ts_v : unsigned(47 downto 0);
    variable lane_credit_v   : lane_addr_t;
    variable ticket_credit_v : ticket_addr_t;
    variable lane_credit_sum_v   : unsigned(LANE_FIFO_ADDR_W downto 0);
    variable ticket_credit_sum_v : unsigned(TICKET_FIFO_ADDR_W downto 0);
  begin
    if rising_edge(i_clk) then
      for i in 0 to N_LANE-1 loop
        -- defaults (one-cycle pulses)
        r(i).lane_we   <= '0';
        r(i).ticket_we <= '0';

        -- Credits (saturating, avoids overflow wrap).
        lane_credit_v := r(i).lane_credit;
        ticket_credit_v := r(i).ticket_credit;

        lane_credit_sum_v := resize(lane_credit_v, lane_credit_sum_v'length);
        if i_lane_credit_update_valid(i) = '1' then
          lane_credit_sum_v := lane_credit_sum_v + resize(i_lane_credit_update(i), lane_credit_sum_v'length);
        end if;
        if lane_credit_sum_v > to_unsigned(LANE_FIFO_MAX_CREDIT, lane_credit_sum_v'length) then
          lane_credit_v := to_unsigned(LANE_FIFO_MAX_CREDIT, lane_credit_v'length);
        else
          lane_credit_v := lane_credit_sum_v(lane_credit_v'range);
        end if;

        ticket_credit_sum_v := resize(ticket_credit_v, ticket_credit_sum_v'length);
        if i_ticket_credit_update_valid(i) = '1' then
          ticket_credit_sum_v := ticket_credit_sum_v + resize(i_ticket_credit_update(i), ticket_credit_sum_v'length);
        end if;
        if ticket_credit_sum_v > to_unsigned(TICKET_FIFO_MAX_CREDIT, ticket_credit_sum_v'length) then
          ticket_credit_v := to_unsigned(TICKET_FIFO_MAX_CREDIT, ticket_credit_v'length);
        else
          ticket_credit_v := ticket_credit_sum_v(ticket_credit_v'range);
        end if;

        case st(i) is
          when IDLE =>
            if (i_ingress_valid(i) = '1') then
              -- Subheader starts a hit-block.
              if (i_ingress_startofpacket(i) = '1') and (is_subheader(i) = '1') and (shd_err(i) = '0') then
                shd_len_raw_v := resize(subh_hit_cnt_raw(i), shd_len_raw_v'length);
                shd_len_v     := resize(subh_hit_cnt_trim(i), shd_len_v'length);

                r(i).shd_len_raw   <= shd_len_raw_v;
                r(i).shd_len       <= shd_len_v;
                r(i).shd_rx_cnt    <= (others => '0');
                if subh_hit_cnt_raw(i) /= subh_hit_cnt_trim(i) then
                  r(i).shd_trim_drop <= '1';
                else
                  r(i).shd_trim_drop <= '0';
                end if;
                r(i).lane_start_addr <= r(i).lane_wptr;

                -- Ticket timestamp: {running_ts[47:12], shd_ts[7:0], 4'b0}.
                ts_v := r(i).running_ts(47 downto 12) & unsigned(subh_shd_ts(i)) & to_unsigned(0, 4);
                r(i).pending_ticket_ts <= ts_v;
                r(i).running_ts(11 downto 4) <= unsigned(subh_shd_ts(i));
                r(i).running_ts(3 downto 0)  <= (others => '0');

                if shd_len_v = 0 then
                  -- Empty ticket: write immediately (no hit words will follow).
                  if ticket_credit_v /= 0 then
                    ticket_v := (others => '0');
                    ticket_v(TICKET_TS_HI downto TICKET_TS_LO) := std_logic_vector(ts_v);
                    ticket_v(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO) := std_logic_vector(r(i).lane_start_addr);
                    ticket_v(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO) := (others => '0');
                    ticket_v(TICKET_ALT_EOP_LOC) := r(i).alert_eop;
                    ticket_v(TICKET_ALT_SOP_LOC) := r(i).alert_sop;
                    r(i).ticket_wdata <= ticket_v;
                    r(i).ticket_we <= '1';
                    r(i).ticket_wptr <= r(i).ticket_wptr + 1;
                    ticket_credit_v := ticket_credit_v - 1;
                    r(i).alert_sop <= '0';
                    r(i).alert_eop <= '0';
                  else
                    st(i) <= MASK_PKT_EXTENDED;
                  end if;
                else
                  -- Do not start writing a hit block unless we can store the whole trimmed block and a ticket.
                  -- This matches the monolithic OPQ behavior (drop-on-overflow, no partial blocks).
                  if resize(shd_len_v, lane_credit_v'length) >= lane_credit_v then
                    st(i) <= MASK_PKT_EXTENDED;
                    r(i).shd_trim_drop <= '0';
                  elsif ticket_credit_v = 0 then
                    st(i) <= MASK_PKT_EXTENDED;
                    r(i).shd_trim_drop <= '0';
                  else
                    st(i) <= WR_HITS;
                  end if;
                end if;
              elsif (i_ingress_startofpacket(i) = '1') and (is_preamble(i) = '1') and (hdr_err(i) = '0') then
                -- Preamble: enter header parse and write SOP ticket at the end.
                r(i).alert_sop <= '1';
                r(i).hdr_flow <= 0;
                st(i) <= UPDATE_HEADER_TS;
              elsif (is_trailer(i) = '1') then
                -- Trailer marker: will be attached to the next SOP ticket.
                r(i).alert_eop <= '1';
              end if;
            end if;

          when WR_HITS =>
            if (i_ingress_valid(i) = '1') then
              -- Write trimmed hits only; drop the remainder until EOP.
              if (r(i).shd_rx_cnt < r(i).shd_len) then
                is_last_keep := (r(i).shd_rx_cnt = r(i).shd_len - 1);

                -- Assemble lane FIFO data (hit word).
                lane_v := (others => '0');
                lane_v(35 downto 0) := i_ingress_data(i);
                lane_v(37) := '0'; -- SOP delimiter unused for lane FIFO
                lane_v(38) := hit_err(i);
                lane_v(39) := '0';

                if is_last_keep then
                  -- Write ticket alongside the last kept hit (EOP delimiter in lane FIFO).
                  if ticket_credit_v /= 0 then
                    ticket_v := (others => '0');
                    ticket_v(TICKET_TS_HI downto TICKET_TS_LO) := std_logic_vector(r(i).pending_ticket_ts);
                    ticket_v(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO) := std_logic_vector(r(i).lane_start_addr);
                    ticket_v(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO) := std_logic_vector(r(i).shd_len);
                    ticket_v(TICKET_ALT_EOP_LOC) := r(i).alert_eop;
                    ticket_v(TICKET_ALT_SOP_LOC) := r(i).alert_sop;
                    r(i).ticket_wdata <= ticket_v;
                    r(i).ticket_we <= '1';
                    r(i).ticket_wptr <= r(i).ticket_wptr + 1;
                    ticket_credit_v := ticket_credit_v - 1;
                    r(i).alert_sop <= '0';
                    r(i).alert_eop <= '0';
                  else
                    st(i) <= MASK_PKT_EXTENDED;
                  end if;

                  lane_v(36) := '1';
                  r(i).lane_we <= '1';
                  r(i).lane_wdata <= lane_v;
                  r(i).lane_wptr <= r(i).lane_wptr + 1;
                  lane_credit_v := lane_credit_v - resize(r(i).shd_len, lane_credit_v'length);

                  if r(i).shd_trim_drop = '1' then
                    st(i) <= MASK_PKT_EXTENDED;
                  else
                    st(i) <= IDLE;
                  end if;
                else
                  lane_v(36) := '0';
                  r(i).lane_we <= '1';
                  r(i).lane_wdata <= lane_v;
                  r(i).lane_wptr <= r(i).lane_wptr + 1;
                  r(i).shd_rx_cnt <= r(i).shd_rx_cnt + 1;
                end if;
              else
                -- Either we've written enough hits, or we ran out of lane credit: drop until EOP.
                st(i) <= MASK_PKT_EXTENDED;
              end if;

              if (i_ingress_endofpacket(i) = '1') and (st(i) = MASK_PKT_EXTENDED) then
                st(i) <= IDLE;
                r(i).shd_trim_drop <= '0';
              end if;
            end if;

          when UPDATE_HEADER_TS =>
            if (i_ingress_valid(i) = '1') then
              case r(i).hdr_flow is
                when 0 =>
                  -- header word0: ts[47:16]
                  r(i).running_ts(47 downto 16) <= unsigned(i_ingress_data(i)(31 downto 0));
                  r(i).hdr_flow <= 1;
                when 1 =>
                  -- header word1: ts[15:0] + serial/pkg_cnt[15:0]
                  r(i).running_ts(15 downto 0) <= unsigned(i_ingress_data(i)(31 downto 16));
                  r(i).pkg_cnt <= unsigned(i_ingress_data(i)(15 downto 0));
                  r(i).hdr_flow <= 2;
                when 2 =>
                  -- debug word0: subheader_cnt + hit_cnt
                  r(i).running_shd_cnt <= unsigned(i_ingress_data(i)(31 downto 16));
                  r(i).hit_cnt <= unsigned(i_ingress_data(i)(15 downto 0));
                  r(i).hdr_flow <= 3;
                when 3 =>
                  -- debug word1: send_ts (ignored here), then write SOP ticket.
                  r(i).hdr_flow <= 0;

                  if ticket_credit_v /= 0 then
                    ticket_v := (others => '0');
                    ticket_v(TICKET_SERIAL_HI downto TICKET_SERIAL_LO) := std_logic_vector(r(i).pkg_cnt);
                    ticket_v(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO) := std_logic_vector(r(i).running_shd_cnt);
                    ticket_v(TICKET_N_HIT_HI downto TICKET_N_HIT_LO)   := std_logic_vector(r(i).hit_cnt);
                    ticket_v(TICKET_ALT_EOP_LOC) := r(i).alert_eop;
                    ticket_v(TICKET_ALT_SOP_LOC) := r(i).alert_sop;
                    r(i).ticket_wdata <= ticket_v;
                    r(i).ticket_we <= '1';
                    r(i).ticket_wptr <= r(i).ticket_wptr + 1;
                    ticket_credit_v := ticket_credit_v - 1;
                    r(i).alert_sop <= '0';
                    r(i).alert_eop <= '0';
                    st(i) <= IDLE;
                  else
                    st(i) <= MASK_PKT_EXTENDED;
                  end if;

                when others =>
                  r(i).hdr_flow <= 0;
              end case;

              if hdr_err(i) = '1' then
                st(i) <= MASK_PKT_EXTENDED;
              end if;
            end if;

          when MASK_PKT_EXTENDED =>
            if (i_ingress_valid(i) = '1') and (i_ingress_endofpacket(i) = '1') then
              st(i) <= IDLE;
              r(i).shd_trim_drop <= '0';
            end if;

          when RESET =>
            r(i) <= REG_RESET;
            st(i) <= IDLE;

          when others =>
            null;
        end case;

        -- Commit updated credits (skip while in RESET so REG_RESET remains authoritative).
        if st(i) /= RESET then
          r(i).lane_credit <= lane_credit_v;
          r(i).ticket_credit <= ticket_credit_v;
        end if;

        if i_rst = '1' then
          st(i) <= RESET;
        end if;
      end loop;
    end if;
  end process;
end architecture rtl;

-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_b2p_arbiter
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Deficit Round Robin (DRR) arbiter granting block movers access to the shared page RAM
--                      write port, with allocator override priority.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.or_reduce;

use work.opq_util_pkg.all;

entity opq_b2p_arbiter is
  generic (
    N_LANE              : positive := 2;
    LANE_FIFO_WIDTH     : positive := 40;
    PAGE_RAM_DEPTH      : positive := 65536;
    PAGE_RAM_DATA_WIDTH : positive := 40;
    -- `word_wr_cnt` width (typically ceil(log2(HIT_SIZE*N_HIT))).
    WORD_WR_CNT_WIDTH   : positive := 8;
    QUANTUM_PER_SUBFRAME : natural := 256;
    QUANTUM_WIDTH        : positive := 10
  );
  port (
    i_clk  : in  std_logic;
    i_rst  : in  std_logic;

    -- Block mover requests + address/data.
    i_bm_page_wreq     : in  std_logic_vector(N_LANE-1 downto 0);
    i_bm_page_wptr     : in  unsigned_array_t(0 to N_LANE-1)(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_bm_word_wr_cnt   : in  unsigned_array_t(0 to N_LANE-1)(WORD_WR_CNT_WIDTH-1 downto 0);
    i_bm_lane_rd_data  : in  slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);

    -- Allocator has priority on the single page RAM write port.
    i_alloc_page_we    : in  std_logic;
    i_alloc_page_waddr : in  std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    i_alloc_page_wdata : in  std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- Quantum update tick per lane (typically asserted once per subframe when that lane participates).
    i_quantum_update   : in  std_logic_vector(N_LANE-1 downto 0);

    -- Outputs.
    o_b2p_arb_gnt      : out std_logic_vector(N_LANE-1 downto 0);
    o_page_ram_we      : out std_logic;
    o_page_ram_wr_addr : out std_logic_vector(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_page_ram_wr_data : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0)
  );
end entity opq_b2p_arbiter;

architecture rtl of opq_b2p_arbiter is
  constant PAGE_RAM_ADDR_WIDTH : natural := clog2(PAGE_RAM_DEPTH);
  constant LANE_IDX_WIDTH      : natural := clog2(N_LANE);
  constant QUANTUM_MAX         : unsigned(QUANTUM_WIDTH-1 downto 0) := (others => '1');
  constant QUANTUM_PER_SUBFRAME_U : unsigned(QUANTUM_WIDTH-1 downto 0) := to_unsigned(QUANTUM_PER_SUBFRAME, QUANTUM_WIDTH);

  type arb_state_t is (IDLE, LOCKING, LOCKED, RESET);
  type arb_reg_t is record
    priority : std_logic_vector(N_LANE-1 downto 0);
    sel_mask : std_logic_vector(N_LANE-1 downto 0);
    quantum  : unsigned_array_t(0 to N_LANE-1)(QUANTUM_WIDTH-1 downto 0);
  end record;

  constant ARB_REG_RESET : arb_reg_t := (
    priority => (0 => '1', others => '0'),
    sel_mask => (others => '0'),
    quantum  => (others => QUANTUM_PER_SUBFRAME_U)
  );

  signal arb_state : arb_state_t := RESET;
  signal arb       : arb_reg_t   := ARB_REG_RESET;

  signal b2p_arb_req : std_logic_vector(N_LANE-1 downto 0);
  signal b2p_arb_gnt : std_logic_vector(N_LANE-1 downto 0);
  signal b2p_arb_req_raw : std_logic_vector(N_LANE-1 downto 0);
  signal b2p_arb_req_eff : std_logic_vector(N_LANE-1 downto 0);
  signal b2p_arb_req_use : std_logic_vector(N_LANE-1 downto 0);

  signal page_ram_we_comb      : std_logic;
  signal page_ram_wr_addr_comb : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
  signal page_ram_wr_data_comb : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

  signal quantum_update_amt : unsigned_array_t(0 to N_LANE-1)(QUANTUM_WIDTH-1 downto 0);
begin
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            B2P_ARBITER.REG
  -- @brief           DRR lock/priority state machine + per-lane quantum bookkeeping
  -- @input           i_bm_page_wreq, i_quantum_update, i_rst
  -- @output          o_page_ram_<we/wr_addr/wr_data> (registered), arb.sel_mask
  -- @description     Matches the monolithic OPQ behavior: block mover traffic is time-sliced by quantum,
  --                  but the allocator has absolute priority on the single page RAM write port.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_b2p_arbiter : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      -- Quantum update + consumption.
      for i in 0 to N_LANE-1 loop
        if (b2p_arb_gnt(i) = '1') and (b2p_arb_req(i) = '1') then
          if arb.quantum(i) > 0 then
            arb.quantum(i) <= arb.quantum(i) - 1;
          else
            arb.quantum(i) <= (others => '0');
          end if;
        end if;

        if (i_quantum_update(i) = '1') then
          arb.quantum(i) <= arb.quantum(i) + quantum_update_amt(i);
          if (b2p_arb_gnt(i) = '1') and (b2p_arb_req(i) = '1') then
            -- Concurrent consume; avoid underflow.
            if arb.quantum(i) > 0 then
              arb.quantum(i) <= arb.quantum(i) - 1 + quantum_update_amt(i);
            else
              if quantum_update_amt(i) > 0 then
                arb.quantum(i) <= quantum_update_amt(i) - 1;
              else
                arb.quantum(i) <= (others => '0');
              end if;
            end if;
          end if;
        end if;
      end loop;

      case arb_state is
        when IDLE =>
          if or_reduce(b2p_arb_req) = '1' then
            if or_reduce(b2p_arb_gnt) = '1' then
              arb.sel_mask <= b2p_arb_gnt;
              arb_state <= LOCKED;
            else
              arb_state <= LOCKING;
            end if;
          end if;

        when LOCKING =>
          if or_reduce(b2p_arb_gnt) = '1' then
            arb.sel_mask <= b2p_arb_gnt;
            arb_state <= LOCKED;
          end if;

        when LOCKED =>
          for i in 0 to N_LANE-1 loop
            -- Release on request deassert.
            if (arb.sel_mask(i) = '1') and (b2p_arb_req(i) = '0') then
              arb_state <= IDLE;
              arb.priority <= arb.sel_mask(N_LANE-2 downto 0) & arb.sel_mask(N_LANE-1);
            end if;

            -- Time-slice / DRR quantum timeout.
            if (arb.quantum(i) <= 1) then
              if (b2p_arb_gnt(i) = '1') and (b2p_arb_req(i) = '1') then
                arb_state <= IDLE;
                arb.priority <= arb.sel_mask(N_LANE-2 downto 0) & arb.sel_mask(N_LANE-1);
              end if;
            end if;
          end loop;

        when RESET =>
          arb <= ARB_REG_RESET;
          arb_state <= IDLE;

        when others =>
          null;
      end case;

      -- Latch the comb page RAM port into regs (aligns with downstream tiled RAM pipeline).
      o_page_ram_we      <= page_ram_we_comb;
      o_page_ram_wr_addr <= page_ram_wr_addr_comb;
      o_page_ram_wr_data <= page_ram_wr_data_comb;

      if i_rst = '1' then
        arb_state <= RESET;
      end if;
    end if;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            B2P_ARBITER.COMB
  -- @brief           Onehot grant generation + page RAM write mux + quantum update amount (saturating)
  -- @input           b2p_arb_req, arb.priority, arb_state, i_alloc_page_we, i_bm_*
  -- @output          b2p_arb_gnt, page_ram_*_comb, quantum_update_amt
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_b2p_arbiter_comb : process (all) is
    variable result0   : std_logic_vector(N_LANE*2-1 downto 0);
    variable result0p5 : std_logic_vector(N_LANE*2-1 downto 0);
    variable result1   : std_logic_vector(N_LANE*2-1 downto 0);
    variable result2   : std_logic_vector(N_LANE*2-1 downto 0);
    variable sel_code  : unsigned(LANE_IDX_WIDTH-1 downto 0);
    variable req_raw_v : std_logic_vector(N_LANE-1 downto 0);
    variable req_eff_v : std_logic_vector(N_LANE-1 downto 0);
    variable req_use_v : std_logic_vector(N_LANE-1 downto 0);
    variable pa_writing_v : std_logic;
  begin
    -- Default.
    b2p_arb_gnt <= (others => '0');

    pa_writing_v := i_alloc_page_we;
    req_raw_v := (others => '0');
    req_eff_v := (others => '0');
    req_use_v := (others => '0');

    -- Input requests:
    --   - Gate requests during allocator writes so a granted beat always corresponds to an actual page RAM write.
    --   - DRR eligibility: only consider lanes with non-zero quantum, unless all eligible lanes are empty.
    for i in 0 to N_LANE-1 loop
      req_raw_v(i) := i_bm_page_wreq(i) and not pa_writing_v;
      if arb.quantum(i) /= to_unsigned(0, arb.quantum(i)'length) then
        req_eff_v(i) := i_bm_page_wreq(i) and not pa_writing_v;
      else
        req_eff_v(i) := '0';
      end if;
    end loop;

    if or_reduce(req_eff_v) = '1' then
      req_use_v := req_eff_v;
    else
      -- Fallback for forward progress: if everyone is out of quantum, ignore quantum gating.
      req_use_v := req_raw_v;
    end if;

    -- Internal raw request visible to the state machine (mirrors monolithic).
    b2p_arb_req_raw <= req_raw_v;
    b2p_arb_req_eff <= req_eff_v;
    b2p_arb_req_use <= req_use_v;
    b2p_arb_req <= req_raw_v;

    -- Priority encoder borrowed from altera_merlin_std_arbitrator_core.sv.
    result0   := req_use_v & req_use_v;
    result0p5 := (not req_use_v) & (not req_use_v);
    result1   := std_logic_vector(unsigned(result0p5) + unsigned(arb.priority));
    result2   := result0 and result1;
    if (or_reduce(result2(N_LANE-1 downto 0)) = '0') then
      b2p_arb_gnt <= result2(N_LANE*2-1 downto N_LANE);
    else
      b2p_arb_gnt <= result2(N_LANE-1 downto 0);
    end if;

    if (arb_state = LOCKED) then
      b2p_arb_gnt <= arb.sel_mask;
    end if;

    -- Interrupt by page allocator: single write port to the page RAM.
    if (i_alloc_page_we = '1') then
      b2p_arb_gnt <= (others => '0');
    end if;

    -- Onehot -> binary (lane index).
    sel_code := (others => '0');
    for i in 0 to N_LANE-1 loop
      if b2p_arb_gnt(i) = '1' then
        sel_code := to_unsigned(i, sel_code'length);
      end if;
    end loop;

    -- Page RAM write mux.
    page_ram_we_comb      <= '0';
    page_ram_wr_addr_comb <= (others => '0');
    page_ram_wr_data_comb <= (others => '0');

    -- Priority 1: granted block mover.
    for i in 0 to N_LANE-1 loop
      if (sel_code = to_unsigned(i, sel_code'length)) and (or_reduce(b2p_arb_gnt) = '1') then
        if i_bm_page_wreq(i) = '1' then
          page_ram_we_comb      <= '1';
          page_ram_wr_addr_comb <= std_logic_vector(i_bm_page_wptr(i) + resize(i_bm_word_wr_cnt(i), i_bm_page_wptr(i)'length));
          page_ram_wr_data_comb <= i_bm_lane_rd_data(i)(PAGE_RAM_DATA_WIDTH-1 downto 0);
        end if;
      end if;
    end loop;

    -- Priority 0: allocator.
    if i_alloc_page_we = '1' then
      page_ram_we_comb      <= '1';
      page_ram_wr_addr_comb <= i_alloc_page_waddr;
      page_ram_wr_data_comb <= i_alloc_page_wdata;
    end if;

    -- Quantum update amount with saturation (+compensate if consuming).
    for i in 0 to N_LANE-1 loop
      if (QUANTUM_MAX - arb.quantum(i) >= QUANTUM_PER_SUBFRAME_U) then
        quantum_update_amt(i) <= QUANTUM_PER_SUBFRAME_U;
      else
        if (b2p_arb_gnt(i) = '1') and (b2p_arb_req(i) = '1') then
          quantum_update_amt(i) <= QUANTUM_MAX - arb.quantum(i) + 1;
        else
          quantum_update_amt(i) <= QUANTUM_MAX - arb.quantum(i);
        end if;
      end if;
    end loop;
  end process;

  o_b2p_arb_gnt <= b2p_arb_gnt;
end architecture rtl;

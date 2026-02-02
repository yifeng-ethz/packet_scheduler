-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             opq_block_mover
-- Author:              Yifeng Wang (original OPQ) / split+refactor by Codex
-- Revision:            0.1 - split from ordered_priority_queue.terp.vhd
-- Description:         Per-lane mover that DMA-copies hit blocks from lane FIFOs into the shared page RAM via
--                      the B2P arbiter, then returns lane FIFO credits.
-- ------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.and_reduce;

use work.opq_util_pkg.all;

entity opq_block_mover is
  generic (
    N_LANE          : positive := 2;
    LANE_FIFO_DEPTH : positive := 1024;
    LANE_FIFO_WIDTH : positive := 40;
    HANDLE_FIFO_DEPTH : positive := 64;
    PAGE_RAM_DEPTH  : positive := 65536;
    HIT_SIZE        : positive := 1;
    N_HIT           : positive := 255;
    FIFO_RAW_DELAY  : positive := 2;
    FIFO_RD_DELAY   : positive := 1
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Handle FIFO (written by page allocator, read by block mover)
    i_handle_fifos_rd_data : in  slv_array_t(0 to N_LANE-1)(clog2(PAGE_RAM_DEPTH)+clog2(LANE_FIFO_DEPTH)+clog2(HIT_SIZE*N_HIT)+1-1 downto 0);
    i_handle_wptr          : in  unsigned_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);
    i_handle_we            : in  std_logic_vector(N_LANE-1 downto 0);
    o_handle_fifos_rd_addr : out slv_array_t(0 to N_LANE-1)(clog2(HANDLE_FIFO_DEPTH)-1 downto 0);

    -- Lane FIFO (written by ingress parser, read by block mover)
    i_lane_fifos_rd_data   : in  slv_array_t(0 to N_LANE-1)(LANE_FIFO_WIDTH-1 downto 0);
    o_lane_fifos_rd_addr   : out slv_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH)-1 downto 0);

    -- Arbiter grant (one-cycle aligned with RAM pipeline in the original design)
    i_b2p_arb_gnt          : in  std_logic_vector(N_LANE-1 downto 0);

    -- To arbiter: request + write base + word count.
    o_page_wreq            : out std_logic_vector(N_LANE-1 downto 0);
    o_page_wptr            : out unsigned_array_t(0 to N_LANE-1)(clog2(PAGE_RAM_DEPTH)-1 downto 0);
    o_word_wr_cnt          : out unsigned_array_t(0 to N_LANE-1)(clog2(HIT_SIZE*N_HIT)-1 downto 0);

    -- Credit return to ingress parser.
    o_lane_credit_update_valid : out std_logic_vector(N_LANE-1 downto 0);
    o_lane_credit_update       : out unsigned_array_t(0 to N_LANE-1)(clog2(LANE_FIFO_DEPTH)-1 downto 0);

    -- Status.
    o_handle_pending        : out std_logic_vector(N_LANE-1 downto 0)
  );
end entity opq_block_mover;

architecture rtl of opq_block_mover is
  constant LANE_FIFO_ADDR_WIDTH  : natural := clog2(LANE_FIFO_DEPTH);
  constant HANDLE_FIFO_ADDR_WIDTH : natural := clog2(HANDLE_FIFO_DEPTH);
  constant PAGE_RAM_ADDR_WIDTH   : natural := clog2(PAGE_RAM_DEPTH);
  constant MAX_PKT_LENGTH        : natural := HIT_SIZE * N_HIT;
  constant MAX_PKT_LENGTH_BITS   : natural := clog2(MAX_PKT_LENGTH);

  constant LANE_FIFO_MAX_CREDIT  : natural := LANE_FIFO_DEPTH - 2;

  -- handle = {src[LANE_FIFO_ADDR_WIDTH-1:0], dst[PAGE_RAM_ADDR_WIDTH-1:0], blk_len[MAX_PKT_LENGTH_BITS-1:0]}
  constant HANDLE_LENGTH  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS;
  constant HANDLE_SRC_LO  : natural := 0;
  constant HANDLE_SRC_HI  : natural := LANE_FIFO_ADDR_WIDTH-1;
  constant HANDLE_DST_LO  : natural := LANE_FIFO_ADDR_WIDTH;
  constant HANDLE_DST_HI  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH-1;
  constant HANDLE_LEN_LO  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH;
  constant HANDLE_LEN_HI  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS-1;

  type handle_t is record
    src     : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
    dst     : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    blk_len : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
  end record;

  type block_mover_state_t is (IDLE, PREP, WRITE_BLK, ABORT_WRITE_BLK, RESET);
  type block_movers_state_t is array (0 to N_LANE-1) of block_mover_state_t;
  signal block_mover_state : block_movers_state_t := (others => RESET);

  type handle_rptr_d_t is array (1 to FIFO_RD_DELAY) of unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
  subtype pending_d_t is std_logic_vector(1 to FIFO_RAW_DELAY);

  type block_mover_reg_t is record
    handle        : handle_t;
    flag          : std_logic;
    handle_rptr   : unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
    handle_rptr_d : handle_rptr_d_t;
    page_wptr     : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    page_wreq     : std_logic;
    word_wr_cnt   : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
    lane_credit_update       : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
    lane_credit_update_valid : std_logic;
    reset_done               : std_logic;
  end record;

  constant HANDLE_RESET : handle_t := (src => (others => '0'), dst => (others => '0'), blk_len => (others => '0'));
  constant BLOCK_MOVER_REG_RESET : block_mover_reg_t := (
    handle => HANDLE_RESET,
    flag => '0',
    handle_rptr => (others => '0'),
    handle_rptr_d => (others => (others => '0')),
    page_wptr => (others => '0'),
    page_wreq => '0',
    word_wr_cnt => (others => '0'),
    lane_credit_update => (others => '0'),
    lane_credit_update_valid => '0',
    reset_done => '0'
  );

  type block_movers_t is array (0 to N_LANE-1) of block_mover_reg_t;
  signal block_mover : block_movers_t := (others => BLOCK_MOVER_REG_RESET);

  signal handle_fifo_is_pending_handle       : std_logic_vector(N_LANE-1 downto 0);
  signal handle_fifo_is_pending_handle_valid : std_logic_vector(N_LANE-1 downto 0);
  signal handle_fifo_is_q_valid              : std_logic_vector(N_LANE-1 downto 0);

  type pending_ds_t is array (0 to N_LANE-1) of pending_d_t;
  signal handle_fifo_is_pending_handle_d : pending_ds_t := (others => (others => '0'));

  type handle_fifo_if_rd_t is record
    handle : handle_t;
    flag   : std_logic;
  end record;
  type handle_fifos_if_rd_t is array (0 to N_LANE-1) of handle_fifo_if_rd_t;
  signal handle_fifo_if_rd : handle_fifos_if_rd_t;

  type lane_rptr_t is array (0 to N_LANE-1) of unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
  signal lane_rptr_next : lane_rptr_t;

  constant LANE_ADDR_ZERO : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0) := (others => '0');
  constant LANE_ADDR_ONE  : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0) := to_unsigned(1, LANE_FIFO_ADDR_WIDTH);
  constant LANE_FIFO_MAX_CREDIT_U : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0) := to_unsigned(LANE_FIFO_MAX_CREDIT, LANE_FIFO_ADDR_WIDTH);
begin
  -- Lane FIFO is a ring buffer; pointer truncation assumes power-of-two depth.
  assert is_pow2(LANE_FIFO_DEPTH)
    report "OPQ: LANE_FIFO_DEPTH must be a power-of-two"
    severity failure;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            BLOCK_MOVER.COMB
  -- @brief           Decode handle FIFO word and compute per-lane FIFO read pointers / pending flags
  -- @input           i_handle_fifos_rd_data, i_handle_wptr, i_handle_we, i_b2p_arb_gnt
  -- @output          o_lane_fifos_rd_addr, o_handle_fifos_rd_addr, handle_fifo_is_pending_handle_valid
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_block_mover_comb : process (all) is
  begin
    for i in 0 to N_LANE-1 loop
      -- pending handle if wptr != rptr (note: write_addr = wptr-1)
      if (i_handle_wptr(i) /= block_mover(i).handle_rptr) then
        handle_fifo_is_pending_handle(i) <= '1';
      else
        handle_fifo_is_pending_handle(i) <= '0';
      end if;

      -- read-during-write guard (wait for RAM pipeline)
      if (i_handle_we(i) = '1') and (i_handle_wptr(i) - 1 = block_mover(i).handle_rptr) then
        handle_fifo_is_pending_handle(i) <= '0';
      end if;

      if (and_reduce(handle_fifo_is_pending_handle_d(i)) = '1') and (handle_fifo_is_pending_handle(i) = '1') then
        handle_fifo_is_pending_handle_valid(i) <= '1';
      else
        handle_fifo_is_pending_handle_valid(i) <= '0';
      end if;

      if (block_mover(i).handle_rptr_d(FIFO_RD_DELAY) = block_mover(i).handle_rptr) then
        handle_fifo_is_q_valid(i) <= '1';
      else
        handle_fifo_is_q_valid(i) <= '0';
      end if;

      if i_b2p_arb_gnt(i) = '1' then
        lane_rptr_next(i) <= block_mover(i).handle.src
          + resize(block_mover(i).word_wr_cnt, LANE_FIFO_ADDR_WIDTH)
          + LANE_ADDR_ONE;
      else
        lane_rptr_next(i) <= block_mover(i).handle.src
          + resize(block_mover(i).word_wr_cnt, LANE_FIFO_ADDR_WIDTH)
          + LANE_ADDR_ZERO;
      end if;

      o_lane_fifos_rd_addr(i) <= std_logic_vector(lane_rptr_next(i));
      o_handle_fifos_rd_addr(i) <= std_logic_vector(block_mover(i).handle_rptr);

      handle_fifo_if_rd(i).handle.src <= unsigned(i_handle_fifos_rd_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO));
      handle_fifo_if_rd(i).handle.dst <= unsigned(i_handle_fifos_rd_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO));
      handle_fifo_if_rd(i).handle.blk_len <= unsigned(i_handle_fifos_rd_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO));
      handle_fifo_if_rd(i).flag <= i_handle_fifos_rd_data(i)(HANDLE_LENGTH);
    end loop;
  end process;

  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  -- @name            BLOCK_MOVER.REG
  -- @brief           Per-lane mover state machine emitting page write requests and returning credits
  -- @input           handle_fifo_is_pending_handle_valid, handle_fifo_if_rd, i_b2p_arb_gnt, i_rst
  -- @output          o_page_wreq/o_page_wptr/o_word_wr_cnt, o_lane_credit_update_*
  -- @description     On ABORT (flag=1), the handle is consumed and credits are returned without writing.
  -- ────────────────────────────────────────────────────────────────────────────────────────────────
  proc_block_mover : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      for i in 0 to N_LANE-1 loop
        block_mover(i).page_wreq <= '0';
        block_mover(i).lane_credit_update_valid <= '0';

        case block_mover_state(i) is
          when IDLE =>
            block_mover(i).word_wr_cnt <= (others => '0');
            if (handle_fifo_is_pending_handle_valid(i) = '1') and (handle_fifo_is_q_valid(i) = '1') then
              block_mover(i).handle <= handle_fifo_if_rd(i).handle;
              block_mover(i).flag   <= handle_fifo_if_rd(i).flag;
              if handle_fifo_if_rd(i).flag = '0' then
                block_mover_state(i) <= PREP;
              else
                block_mover_state(i) <= ABORT_WRITE_BLK;
              end if;
            end if;

          when PREP =>
            block_mover(i).page_wptr <= block_mover(i).handle.dst;
            block_mover(i).page_wreq <= '1';
            block_mover_state(i) <= WRITE_BLK;

          when WRITE_BLK =>
            block_mover(i).page_wreq <= '1';
            if (block_mover(i).page_wreq = '1') and (i_b2p_arb_gnt(i) = '1') then
              block_mover(i).word_wr_cnt <= block_mover(i).word_wr_cnt + 1;
              if (block_mover(i).word_wr_cnt + 1 = block_mover(i).handle.blk_len) then
                block_mover(i).lane_credit_update <= resize(block_mover(i).handle.blk_len, block_mover(i).lane_credit_update'length);
                block_mover(i).lane_credit_update_valid <= '1';
                block_mover(i).handle_rptr <= block_mover(i).handle_rptr + 1;
                block_mover(i).page_wreq <= '0';
                block_mover_state(i) <= IDLE;
              end if;
            end if;

          when ABORT_WRITE_BLK =>
            block_mover(i).handle_rptr <= block_mover(i).handle_rptr + 1;
            block_mover(i).lane_credit_update <= resize(block_mover(i).handle.blk_len, block_mover(i).lane_credit_update'length);
            block_mover(i).lane_credit_update_valid <= '1';
            block_mover_state(i) <= IDLE;

          when RESET =>
            if not block_mover(i).reset_done then
              block_mover(i).lane_credit_update <= LANE_FIFO_MAX_CREDIT_U;
              block_mover(i).lane_credit_update_valid <= '1';
              block_mover(i).reset_done <= '1';
            else
              if not i_rst then
                block_mover_state(i) <= IDLE;
              end if;
            end if;

          when others =>
            null;
        end case;

        -- delay chain (pending handle)
        for j in 1 to FIFO_RAW_DELAY loop
          if j = 1 then
            handle_fifo_is_pending_handle_d(i)(j) <= handle_fifo_is_pending_handle(i);
          else
            handle_fifo_is_pending_handle_d(i)(j) <= handle_fifo_is_pending_handle_d(i)(j-1);
          end if;
        end loop;

        -- delay chain (rptr)
        for j in 1 to FIFO_RD_DELAY loop
          if j = 1 then
            block_mover(i).handle_rptr_d(j) <= block_mover(i).handle_rptr;
          else
            block_mover(i).handle_rptr_d(j) <= block_mover(i).handle_rptr_d(j-1);
          end if;
        end loop;

        if i_rst = '1' then
          block_mover_state(i) <= RESET;
          if (block_mover_state(i) /= RESET) then
            block_mover(i) <= BLOCK_MOVER_REG_RESET;
            block_mover(i).reset_done <= '0';
          end if;
        end if;
      end loop;
    end if;
  end process;

  -- Outputs.
  gen_out : for i in 0 to N_LANE-1 generate
    o_page_wreq(i) <= block_mover(i).page_wreq;
    o_page_wptr(i) <= block_mover(i).page_wptr;
    o_word_wr_cnt(i) <= block_mover(i).word_wr_cnt;
    o_lane_credit_update_valid(i) <= block_mover(i).lane_credit_update_valid;
    o_lane_credit_update(i) <= block_mover(i).lane_credit_update;
    o_handle_pending(i) <= handle_fifo_is_pending_handle(i);
  end generate;
end architecture rtl;

-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             ordered_priority_queue
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            1.0
-- Date:                July 2, 2025 (file created)
-- Description:         Aggregate multiple ingress data flows into one single egress data flow
--
--                      - data structure is defined as:
--                          Name (abbr.)            : typical number * unit size (fixed)
--                          -------------------------------------------------------------
--                          header(hdr)             : 1              * 5 words
--                          256 subheader(shd)      : 256            * 1 word
--                          hit (hit)               : 255            * 1 word
--
--                          Example: {hdr | shd [hit] [hit] ... | shd | shd [hit] | shd [hit] [hit] } {hdr ...}
--                          Explain: always one hdr as packet start or framing boundary 
--                                   typical hdr is appended with 256 shd
--                                   appended to shd are hit
--                                   can be zero hit or infinite
--
--                      - Mode description:
--                          [Multiplexing] If ingress flows are timestamp-interleaved with packet id (referred to as "ts" below),
--                          e.g., flow 0 has ts = {0,3,7,...}; flow 1 has ts = {1,4,8,...}; ...,
--                          the egress will be a single flow with one hdr and shd sequenced and consistent ts = {0,1,2,3,4,...,256}. 
--                          Note that the hdr of all flow will be merged.
--                          [Merging] If ingress flows are sequenced and consistent,
--                          e.g., flow 0 has ts = {0,1,2,...}; flow 1 has ts {0,1,2,...}; ...,
--                          the egress format will same as [Multiplexing] mode, but shd will be merged for all flows, such that
--                          ts = {0,1,2,3,4,...,256} and hits appended to the correct shd.
--
--                      - architecture:
--                                                                                  ┌────────────────────────────────────┐                                                                   
--                                                                                  │                                    ├─┐                                                                 
--                                                                                  │       ┌─────────────────────┐      │ │                                                                 
--                                                                                  │       │ Descriptor          │      │ │                                                                 
--                                                                                  │       │  - ts[47:0]         │      │ │                                                                 
--                                                                                  │       │  - start addr [9:0] │      │ │                                                                 
--                                                                                  │       │  - length[9:0]      │      │ │                                                                 
--                                                                                  │       └─────────────────┬───┘      │ │                                                                 
--                                                                                  │                         │          │ │                              ┌────────────┐                     
--                                                                                  │         ─────────┬─┬─┬─┬┼┐         │ │                              │            │                     
--                                                                                  │                  │ │ │ │▼│         │ │                              │    Page    │                     
--                             ┌───────────┐                                   ┌──────────────►        │ │ │ │ │ ──────────────────────────//────────────►│            │                     
--                             │           ├┐                                  │    │                  │ │ │ │ │         │ │                              │  Allocator │                     
--                             │  Ingress  ││                                  │    │         ─────────┴─┴─┴─┴─┘         │ │                              │            │                     
-- ───────────────//──────────►│           ││                                  │    │                                    │ │                              └──────┬─────┘                     
--                             │   Parser  │├──────────┐     /│                │    │            Ticket FIFO             │ │                                     │                           
--                             │           ││          │    / │                │    │                                    │ │                                     │                           
--                             └┬──────────┘│          │   /  ├─────────//─────┘    │                                    │ │                                     │                           
--                              └───────────┘          │  │   │                     │            ┌───────────────┐       │ │                                     │                           
--                                          x2         └──┤   │                     │            │ Packet = {    │       │ │                                 │   ▼   │                       
--                                                        │   │                     │            │  - data[31:0] │       │ │                                 │       │                       
--                                                        \\  ├─────────//─────┐    │            │  - datak[3:0] │       │ │                                 │       │                       
--                                                         \\ │                │    │            │  - eop[0]     │       │ │                                 ├───────┤                       
--                                                          \\│                │    │            │  - sop[0]     │       │ │                                 ├───────┤ Handle FIFO           
--                                                            x2               │    │            │  - hit err[0] │       │ │                                 ├───────┤                       
--                                                                             │    │            │ } x 255       │       │ │                                 ├───────┤                       
--                                                                             │    │            └────────────┬──┘       │ │                                 └───────┘                       
--                                                                             │    │                         │          │ │                                     │                           
--                                                                             │    │         ───┬───┬─┬───┬──┼┐         │ │                                     │                           
--                                                                             │    │            │   │ │   │  ▼│         │ │                                     │                           
--                                                                             └──────────────►  │   │ │   │   │ ─────────────────────────//────────────┐        ▼                           
--                                                                                  │            │   │ │   │   │         │ │                            │  ┌───────────┐                     
--                                                                                  │         ───┴───┴─┴───┴───┘         │ │                            │  │           ├┐                    
--                                                                                  │                                    │ │                            │  │   Block   ││                    
--                                                                                  │             Lane FIFO              │ │                            └─►│           ││                    
--                                                                                  └┬───────────────────────────────────┘ │                               │   Mover   │├───────────────────┐
--                                                                                   └─────────────────────────────────────┘                               │           ││                   │
--                                                                                                                          x2                             └┬──────────┘│                   │
--                                                                                              Ingress Queue                                               └───────────┘                   │
--                                                                                                                                                                      x2                  │
--                                                                                                                                                                                          │
--                                  ┌────────────────────────────────────────────────────────────────────//─────────────────────────────────────────────────────────────────────────────────┘
--                                  │                                                                                                                                                        
--                                  │                                                                                                                                                        
--                                  │                                   ┌────────────────────────────────────────────────────────────────────────┐                                           
--                                  │                                   │                                                                        │                                           
--                                  │                                   │                                                                        │                                           
--                                  │                                   │ ┌───────────┐                                                          │                                           
--                                  │                                   │ ├───────────┤                      Free Space         ┌───────────┐    │                                           
--                                  │                                   │ │           │                           │    .        │           │    │                                           
--                                  │                                   │ │   Frame   │                           │    .        │   Frame   │    │                                           
--                                  │                                   │ │           │                           │    .        │           │    │                                           
--                                  │                                   │ │   Table   │                           │    .        │  Tracker  │    │                                           
--                                  │                                   │ │           │     ┌──────────────────┐  │    .        │           │    │                                           
--                                  │                                   │ └───────────┘     │                  │  │    .        └───────────┘    │                                           
--                                  │                                   │           .       │               ◄──┼──┘    .                         │                                           
--                                  │                                   │           .       ├──────────────────┤       .                         │                                           
--                                  │                                   │           .       │//////////////////│◄───── . RD PTR                  │                                           
--                                  │      ┌───────┐                    │           .       │//////////////////│       .                         │                                           
--                                  │      │       │                    │           .       ├──────────────────┤       . RD debug I/F            │                                           
--                                  └─────►│  ARB  ├───────────────────►│           .       │//////////////////│       .  - remaining packets    │                                           
--                                         │       │                    │           .       ├──────────────────┤       .  - fill-level           │                                           
--                                         └───────┘                    │           .       │..................│       .  - dropped hit count    │                                           
--                                                                      │    WR PTR . ─────►│..................│       .  - dropped shd count    │                                           
--                                                                      │           .       ├------------------┤       .  - dropped hdr count    │                                           
--                                                                      │           .       │                  │       .  - write hit count      │                                           
--                                                                      │           .       │                  │       .  - write shd count      │                                           
--                                                                      │           .       │                  │       .  - write hdr count      │                                           
--                                                                      │           .       │                  │       .                         │                                           
--                                                                      │           .       │                  │       .                         │                                           
--                                                                      │           .       └──────────────────┘       .                         │                                           
--                                                                      │           .                                  .                         │                                           
--                                                                      │                         Page RAM                                       │                                           
--                                                                      │                                                                        │                                           
--                                                                      │                                                                        │                                           
--                                                                      │                                                                        │                                           
--                                                                      └────────────────────────────────────────────────────────────────────────┘                                           
--                                                                                                                                                                                          
--                                                                                                     Egress Queue                                                                          
--
--
--
--    
--                      - note:
--                          Ingress Queue: 
--                              > [I/F]: AVST(x4) <- packetized_data
--                              > ticket FIFO can be filled and will block write to lane FIFO
--                              > by default, lane FIFO will be queue managed by arbiter who will drop head depending on function
--                                F(quantum, usedw, ts). drop head is one cycle.
--                              > if lane FIFO is full, the head packet will be queue managed by revoking the last packet was writing. 
--                                this is the last safe mechamism, and induces more delay and non-linear rate.
--                          ARB:
--                              > [I/F]: AVMM <- log_msg
--                              > [scheduling scheme]: ordered deficit round robin arbitor
--                              > dequeue from lane FIFO by first "peek" from ticket FIFO
--                              > priority is given by the following list: 
--                                  1) smallest ts
--                                  2) quantum larger than packet size
--                              > if critiria 1 is satisfied and 2 is not, this packet will be dropped
--                              > if both critiria are satisfied, this packet is read, otherwise skipped
--                              > once read is done, pop the ticket FIFO to ack the ingress queue
--                              > [preemptive overflow avoidance]: periodically clean up of high usedw and low quantum lane, and log it
--                              > [quantum returning]: TBD
--                          Egress Queue:
--                              > [I/F]: AVST -> packetized_data
--                                       AVMM <- rd_debug_msg
--                              > [overflow protection]: if write pointer reach the rd pointer, aligned to packet sop addr,
--                                current writing packet will be revoked/dropped
--                              > once read has finished the whole packet, the region for this space is released and useable 
--                                for write pointer

--                                            
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
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
-- altera-specific
library altera_mf;
use altera_mf.all;
-- get params from hls* macro
@@ set fifos_names_cap [string toupper $fifos_names]
@@ set sigType_list {data valid error startofpacket endofpacket channel}
@@ set errDisc_list {hit_err shd_err hdr_err}
@@ if {$egress_empty_width > 0} {
    lappend sigType_list empty
@@ }

entity ${output_name} is
    generic (
        -- IP basic
        N_LANE                  : natural := 4; -- number of ingress lanes, e.g., 4 for x4
        MODE                    : string := "MERGING"; -- {MULTIPLEXING MERGING} multiplexing: ingress flows ts are interleaved; merging: ingress flows ts are sequenced and consistent
        TRACK_HEADER            : boolean := true; -- Select whether to track the header of ingress flow as the reference timestamp for each subheader packet.
        -- ingress format
        INGRESS_DATA_WIDTH      : natural := 32; -- default = 32
        INGRESS_DATAK_WIDTH     : natural := 4; -- default = 4
        CHANNEL_WIDTH           : natural := 2; -- width of logical channel, e.g., 2 bits for 4 channels
        -- IP advance
        LANE_FIFO_DEPTH         : natural := 1024; -- size of each lane FIFO in unit of its data width. Affects the max delay skew between each lane supported and maximum waiting time for the <b>page allocator</b>
        LANE_FIFO_WIDTH         : natural := 40; -- data width of each lane FIFO in unit of bits, must be larger than total(39) = data(32)+datak(4)+eop(1)+sop(1)+err(1)
        TICKET_FIFO_DEPTH       : natural := 64; -- size of each ticket FIFO in unit of its data width, set accordingly to the expected latency / max delay it allows
        HANDLE_FIFO_DEPTH       : natural := 64; -- size of each handle FIFO in unit of its data width, set accordingly to the expected latency / max delay it allows, drop means blk mover too slow
        PAGE_RAM_DEPTH          : natural := 65536; -- size of the page RAM in unit of its WR data width, need to be larger than the full header packet, which is usually 8k max for each FEB flow
        PAGE_RAM_RD_WIDTH       : natural := 36; -- RD data width of the page RAM in unit of bits, write width = LANE_FIFO_WIDTH, read width can be larger to interface with PCIe DMA
        -- packet format 
        N_SHD                   : natural := 256; -- number of subheader, e.g., 256, more than 256 will be dropped
        N_HIT                   : natural := 255; -- number of hits per subheader, e.g., 255, more than 255 will be dropped
        HDR_SIZE                : natural := 5; -- size of header in words, e.g., 5 words
        SHD_SIZE                : natural := 1; -- size of subheader in words, e.g., 1 word
        HIT_SIZE                : natural := 1; -- size of hit in words, e.g., 1 word
        
        -- debug configuration
        DEBUG_LV               : natural := 1 -- debug level, e.g., 0 for no debug, 1 for basic debug
    );
    port (
        -- +----------------------------+
        -- | Ingress Queue Interface(s) |
        -- +----------------------------+
        @@ for {set i 0} {$i < $n_lane} {incr i} {
        asi_ingress_${i}_data            : in  std_logic_vector(INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1 downto 0); -- [35:32] : byte_is_k - "0001" = sub-header, "0000" = hit
        asi_ingress_${i}_valid           : in  std_logic_vector(0 downto 0); -- non-backlog, will drop packet inside if full
        asi_ingress_${i}_channel         : in  std_logic_vector(CHANNEL_WIDTH-1 downto 0); -- indicates the logical channel, fixed during run time
        asi_ingress_${i}_startofpacket   : in  std_logic_vector(0 downto 0); -- start of subheader or header
        asi_ingress_${i}_endofpacket     : in  std_logic_vector(0 downto 0); -- end of subheader (last hit) or header
        asi_ingress_${i}_error           : in  std_logic_vector(2 downto 0); -- errorDescriptor = {hit_err shd_err hdr_err}. will block the remaining data until eop and revoke the current packet
        @@ }

        -- +------------------------+
        -- | Egress Queue Interface |
        -- +------------------------+
        aso_egress_data             : out std_logic_vector(PAGE_RAM_RD_WIDTH-1 downto 0); -- [35:32] : byte_is_k - "0001" = sub-header, "0000" = hit
        aso_egress_valid            : out std_logic; -- supports backpressure
        aso_egress_ready            : in  std_logic; -- upstream can grant for whole packet or stop during read
        aso_egress_startofpacket    : out std_logic; -- start of subheader or header
        aso_egress_endofpacket      : out std_logic; -- end of subheader (last hit) or header
        aso_egress_error            : out std_logic_vector(2 downto 0); -- errorDescriptor = {hit_err shd_err hdr_err}. will block the remaining data until eop and revoke the current packet
        @@ if {$egress_empty_width > 0} {
        aso_egress_empty            : out std_logic_vector($egress_empty_width-1 downto 0); -- empty for number of symbols
        @@ } elseif {$egress_empty_width == 1} {
        aso_egress_empty            : out std_logic_vector(0 downto 0); -- empty for number of symbols
        @@ }

        -- +---------------------+
        -- | CLK / RST Interface |
        -- +---------------------+
        d_clk                    : in std_logic; -- data path clock
        d_reset                  : in std_logic -- data path reset
    );
end entity ${output_name};


architecture rtl of ${output_name} is 
    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  COMMON 
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- universal 8b10b
	constant K285					: std_logic_vector(7 downto 0) := "10111100"; -- 16#BC# -- byte 0 marks header begins
	constant K284					: std_logic_vector(7 downto 0) := "10011100"; -- 16#9C# -- byte 0 marks trailer ends
	constant K237					: std_logic_vector(7 downto 0) := "11110111"; -- 16#F7# -- byte 0 marks subheader begins

    -- direct io signals
    signal i_clk					: std_logic;
    signal i_rst					: std_logic;

    -- global settings 
    constant MAX_PKT_LENGTH         : natural := HIT_SIZE*N_HIT; -- default is 255, max length of packet to be allocated and in the lane FIFO as a whole, this does not include subheader as it will be in the ticket FIFO
    constant MAX_PKT_LENGTH_BITS    : natural := integer(ceil(log2(real(MAX_PKT_LENGTH)))); -- default is 8 bits
    constant FIFO_RDW_DELAY         : natural := 2; -- need to delay read for 2 cycles after write (2 for RDW="old data", 1 for RDW="new data")
    
    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  TICKET_FIFO 
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant TICKET_FIFO_DATA_WIDTH : natural := 48 + integer(ceil(log2(real(LANE_FIFO_DEPTH)))) + integer(ceil(log2(real(MAX_PKT_LENGTH)))); -- 48 for ts, 10 for start address, 8 for length, of that block associated with this ticket
    constant TICKET_FIFO_ADDR_WIDTH : natural := integer(ceil(log2(real(TICKET_FIFO_DEPTH)))); -- default is 6 bits
    constant TICKET_FIFO_MAX_CREDIT : natural := TICKET_FIFO_DEPTH-1; -- credit between page allocator (rx) and ingress parser (tx). must be <= TICKET_FIFO_DEPTH. the maximum number of outstanding ticket the ingress parser can issue. 

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  LANE_FIFO
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant LANE_FIFO_DATA_WIDTH	: natural := LANE_FIFO_WIDTH; -- 32 for data, 4 for byte_is_k, 2 for eop/sop, 1 for error (only hit err)
    constant LANE_FIFO_ADDR_WIDTH	: natural := integer(ceil(log2(real(LANE_FIFO_DEPTH)))); -- 1024 words, 10 bits address. at least need to be large enough to hold the whole packet
    constant LANE_FIFO_MAX_CREDIT   : natural := LANE_FIFO_DEPTH-2; -- credit between block mover (rx) and ingress parser (tx). must be <= LANE_FIFO_DEPTH. the maximum number of data bytes the ingress parser can store. 

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  HANDLE_FIFO
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant HANDLE_FIFO_DATA_WIDTH : natural := integer(ceil(log2(real(PAGE_RAM_DEPTH)))) + LANE_FIFO_ADDR_WIDTH + MAX_PKT_LENGTH_BITS + 1; -- 16 for page ram address, 10 for lane ram address, 8 for packet length. handle = {src, dst, length}, 1 for flag
    constant HANDLE_FIFO_ADDR_WIDTH : natural := integer(ceil(log2(real(HANDLE_FIFO_DEPTH)))); -- default is 6 bits
    constant HANDLE_FIFO_MAX_CREDIT : natural := HANDLE_FIFO_DEPTH-2; -- credit between block mover (rx) and page allocator. the maximum outstanding number of handle the page allocator can issue.

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  PAGE_RAM
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant PAGE_RAM_DATA_WIDTH    : natural := 40; -- TBD
    constant PAGE_RAM_ADDR_WIDTH    : natural := integer(ceil(log2(real(PAGE_RAM_DEPTH)))); -- 65536 words, 16 bits address. should be > LANE_FIFO_DEPTH*N_LANE. 

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  DATA STRUCT FORMAT 
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- handle = {src[9:0], dst[15:0], blk_len(length)[7:0]}
        -- bitmap
    constant HANDLE_LENGTH                  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS;
    constant HANDLE_SRC_LO                  : natural := 0;
    constant HANDLE_SRC_HI                  : natural := LANE_FIFO_ADDR_WIDTH-1;
    constant HANDLE_DST_LO                  : natural := LANE_FIFO_ADDR_WIDTH;
    constant HANDLE_DST_HI                  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH-1;
    constant HANDLE_LEN_LO                  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH;
    constant HANDLE_LEN_HI                  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS-1;
        -- declare
    type handle_t is record 
        src             : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        dst             : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        blk_len         : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);                        
    end record;

    constant HANDLE_REG_RESET       : handle_t := (
        src             => (others => '0'),
        dst             => (others => '0'),
        blk_len         => (others => '0')
    );
    
    -- ticket = {ts[47:0], start addr[9:0], length[9:0]}
    type ticket_t is record
        ticket_ts               : unsigned(47 downto 0);
        lane_fifo_rd_offset     : std_logic_vector(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        block_length            : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
    end record;
    constant TICKET_DEFAULT     : ticket_t := (
        ticket_ts               => (others => '0'),
        lane_fifo_rd_offset     => (others => '0'),
        block_length            => (others => '0')
    );

    -- lane = {data[31:0], datak[3:0], eop[0], sop[0], hit_err[0], reserved[0]}

    -- i/o
    @@ foreach sigType $sigType_list {
    type asi_ingress_${sigType}_t is array (0 to N_LANE-1) of std_logic_vector(asi_ingress_0_${sigType}'high downto 0);
    signal asi_ingress_${sigType}               : asi_ingress_${sigType}_t;
    @@ }


    
    @@ foreach errType $errDisc_list {
    --type ingress_parser_${errType}_t is array (0 to N_LANE-1) of std_logic;
    --signal ingress_parser_${errType}            : ingress_parser_${errType}_t;
    @@ }
    
    

    -- ────────────────────────────────────────────────
    -- hls generate : fifos comp
    -- ────────────────────────────────────────────────
    @@ for {set i 0} {$i < [llength $fifos_names]} {incr i} {
    @@ set name [lindex $fifos_names $i]
    @@ set name_cap [lindex $fifos_names_cap $i]
    -- $name template
    component $name
    generic (
        DATA_WIDTH      : natural := ${name_cap}_DATA_WIDTH;
        ADDR_WIDTH      : natural := ${name_cap}_ADDR_WIDTH
    );
	port (
		data		    : in  std_logic_vector(${name_cap}_DATA_WIDTH-1 downto 0);
		read_addr		: in  std_logic_vector(${name_cap}_ADDR_WIDTH-1 downto 0);
		write_addr		: in  std_logic_vector(${name_cap}_ADDR_WIDTH-1 downto 0);
		we		        : in  std_logic;
		clk		        : in  std_logic;
		q		        : out std_logic_vector(${name_cap}_DATA_WIDTH-1 downto 0)
	);
	end component;

    type ${name}s_data_t is array (0 to N_LANE-1) of std_logic_vector(${name_cap}_DATA_WIDTH-1 downto 0);
    type ${name}s_addr_t is array (0 to N_LANE-1) of std_logic_vector(${name_cap}_ADDR_WIDTH-1 downto 0);
    signal ${name}s_wr_data         : ${name}s_data_t;
    signal ${name}s_rd_data         : ${name}s_data_t;
    signal ${name}s_wr_addr         : ${name}s_addr_t;
    signal ${name}s_rd_addr         : ${name}s_addr_t;
    signal ${name}s_we              : std_logic_vector(N_LANE-1 downto 0);
    @@ }

    -- ────────────────────────────────────────────────
    -- page ram
    -- ────────────────────────────────────────────────
    component page_ram
    generic (
        DATA_WIDTH      : natural := PAGE_RAM_DATA_WIDTH;
        ADDR_WIDTH      : natural := PAGE_RAM_ADDR_WIDTH
    );
	port (
		data		    : in  std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
		read_addr		: in  std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
		write_addr		: in  std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
		we		        : in  std_logic;
		clk		        : in  std_logic;
		q		        : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0)
	);
	end component;
    signal page_ram_wr_data         : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal page_ram_rd_data         : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal page_ram_wr_addr         : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_ram_rd_addr         : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_ram_we              : std_logic; 

    -- ────────────────────────────────────────────────
    -- ingress parser
    -- ────────────────────────────────────────────────
    -- state signals
    subtype update_header_ts_flow_t is integer range 0 to 3;
    type update_header_tss_flow_t is array (0 to N_LANE-1) of update_header_ts_flow_t;
    signal update_header_ts_flow            : update_header_tss_flow_t;
    type ingress_parser_state_t is (IDLE, UPDATE_HEADER_TS, MASK_PKT_EXTENDED, MASK_PKT, WR_HITS, RESET);
    type ingress_parsers_state_t is array (0 to N_LANE-1) of ingress_parser_state_t;
    signal ingress_parser_state             : ingress_parsers_state_t;

    -- registers
    type ingress_parser_reg_t is record 
        -- lane
        lane_we                         : std_logic;
        lane_wptr                       : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        lane_wdata                      : std_logic_vector(LANE_FIFO_DATA_WIDTH-1 downto 0);
        lane_credit                     : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0); 
        -- ticket
        ticket_we                       : std_logic;
        ticket_wptr                     : unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);
        ticket_wdata                    : std_logic_vector(TICKET_FIFO_DATA_WIDTH-1 downto 0);
        ticket_credit                   : unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);
        -- register
        running_ts                      : unsigned(47 downto 0);
        shd_len                         : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
        dt_type                         : std_logic_vector(5 downto 0); -- 6 bits, unique for each subdetector 
        feb_id                          : std_logic_vector(15 downto 0); -- 16 bits, unique for feb under each subdetector. combined to get the flow id. 
        lane_start_addr                 : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0); -- start address of the lane FIFO for this packet, used to detect if the packet is with declared length
        pkg_cnt                         : std_logic_vector(15 downto 0); -- 16 bits, running package index
        running_shd_cnt                 : std_logic_vector(14 downto 0); -- 15 bits, running header index
        hit_cnt                         : unsigned(15 downto 0); -- 15 bits, number of hits under this header package
        send_ts                         : std_logic_vector(30 downto 0); -- 31 bits, timestamp of this package departing at the upstream port, used to calculate package header delay
        error_lane_wr_early_term        : std_logic; -- indicates if the lane write is early terminated due to error
    end record;
    constant INGRESS_PARSER_REG_RESET   : ingress_parser_reg_t := (
        lane_we         => '0',
        lane_wptr       => (others => '0'),
        lane_wdata      => (others => '0'),
        lane_credit     => to_unsigned(LANE_FIFO_MAX_CREDIT,LANE_FIFO_ADDR_WIDTH),
        ticket_we       => '0',
        ticket_wptr     => (others => '0'),
        ticket_wdata    => (others => '0'),
        ticket_credit   => to_unsigned(TICKET_FIFO_MAX_CREDIT,TICKET_FIFO_ADDR_WIDTH),
        running_ts      => (others => '0'),
        shd_len         => (others => '0'),
        dt_type         => (others => '0'),
        feb_id          => (others => '0'),
        lane_start_addr => (others => '0'),
        pkg_cnt         => (others => '0'),
        running_shd_cnt => (others => '0'),
        hit_cnt         => (others => '0'),
        send_ts         => (others => '0'),
        error_lane_wr_early_term => '0'
    );

    type ingress_parsers_reg_t is array (0 to N_LANE-1) of ingress_parser_reg_t;
    signal ingress_parser           : ingress_parsers_reg_t;

    -- combinational wires
    signal ingress_parser_is_subheader      : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a subheader
    signal ingress_parser_is_preamble       : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a preamble
    signal ingress_parser_is_trailer        : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a trailer
    signal ingress_parser_hit_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has hit error
    signal ingress_parser_shd_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has subheader error
    signal ingress_parser_hdr_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has header error
    type ingress_parser_if_subheader_hit_cnt_t is array (0 to N_LANE-1) of unsigned(MAX_PKT_LENGTH_BITS-1 downto 0); 
    signal ingress_parser_if_subheader_hit_cnt  : ingress_parser_if_subheader_hit_cnt_t; -- hit count of the subheader, 8 bits
    type ingress_parser_if_subheader_shd_ts_t is array (0 to N_LANE-1) of std_logic_vector(7 downto 0); 
    signal ingress_parser_if_subheader_shd_ts   : ingress_parser_if_subheader_shd_ts_t; -- subheader timestamp, 8 bits
    type ingress_parser_if_preamble_dt_type_t is array (0 to N_LANE-1) of std_logic_vector(5 downto 0);
    signal ingress_parser_if_preamble_dt_type   : ingress_parser_if_preamble_dt_type_t; -- preamble data type, 6 bits
    type ingress_parser_if_preamble_feb_id_t is array (0 to N_LANE-1) of std_logic_vector(15 downto 0);
    signal ingress_parser_if_preamble_feb_id    : ingress_parser_if_preamble_feb_id_t; -- preamble feb id, 16 bits
    type ingress_parser_if_write_ticket_data_t is array (0 to N_LANE-1) of std_logic_vector(48+LANE_FIFO_ADDR_WIDTH+MAX_PKT_LENGTH_BITS-1 downto 0); -- ticket = {ts[47:0], start addr[9:0], length[9:0]}
    signal ingress_parser_if_write_ticket_data  : ingress_parser_if_write_ticket_data_t;
    type ingress_parser_if_write_lane_data_t is array (0 to N_LANE-1) of std_logic_vector(LANE_FIFO_DATA_WIDTH-1 downto 0);
    signal ingress_parser_if_write_lane_data    : ingress_parser_if_write_lane_data_t;

    -- ────────────────────────────────────────────────
    -- page allocator
    -- ────────────────────────────────────────────────
    -- state signals
    type page_allocator_state_t is (IDLE, FETCH_TICKET, ALLOC_PAGE, WRITE_PAGE, RESET);
    signal page_allocator_state             : page_allocator_state_t;
    subtype alloc_page_flow_t is integer range 0 to N_LANE-1;

    -- registers
    type ticket_credit_update_t is array (0 to N_LANE-1) of unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);
    type handle_wflag_t is array (0 to N_LANE-1) of std_logic;
    type handle_wptr_t is array (0 to N_LANE-1) of unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
    type tickets_t is array (0 to N_LANE-1) of ticket_t;

    type page_allocator_reg_t is record 
        -- ticket
        ticket_rptr                         : unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);
        ticket_credit_update                : ticket_credit_update_t;
        ticket_credit_update_valid          : std_logic_vector(N_LANE-1 downto 0);
        -- handle
        handle_we                           : std_logic_vector(N_LANE-1 downto 0);
        handle_wflag                        : handle_wflag_t; -- default is 1 bits, flag = {skip_blk}
        handle_wptr                         : handle_wptr_t;
        -- page
        page_we                             : std_logic;
        page_wdata                          : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
        page_waddr                          : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        -- internal
        running_ts                          : unsigned(47 downto 0);
        lane_masked                         : std_logic_vector(N_LANE-1 downto 0);
        lane_skipped                        : std_logic_vector(N_LANE-1 downto 0);
        ticket                              : tickets_t;
        page_start_addr                     : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        page_length                         : unsigned(MAX_PKT_LENGTH_BITS+CHANNEL_WIDTH-1 downto 0); -- hint: max page length = N_LANE * max block length
        alloc_page_flow                     : alloc_page_flow_t; -- flow need to iterate all lanes
        reset_done                          : std_logic;
    end record;

    constant PAGE_ALLOCATOR_REG_RESET   : page_allocator_reg_t := (
        running_ts                  => (others => '0'),
        lane_masked                 => (others => '0'),
        lane_skipped                => (others => '0'),
        ticket                      => (others => TICKET_DEFAULT),
        ticket_rptr                 => (others => '0'),
        page_length                 => (others => '0'),
        alloc_page_flow             => 0,
        handle_we                   => (others => '0'),
        handle_wflag                => (others => '0'),
        handle_wptr                 => (others => (others => '0')),
        page_we                 => '0',
        page_wdata              => (others => '0'),
        page_waddr              => (others => '0'),
        ticket_credit_update        => (others => (others => '0')),
        ticket_credit_update_valid  => (others => '0'),
        page_start_addr             => (others => '0'),
        reset_done                  => '0'
    );

    signal page_allocator           : page_allocator_reg_t;

    type page_allocator_is_pending_ticket_d_t is array (1 to FIFO_RDW_DELAY) of std_logic_vector(N_LANE-1 downto 0);
    signal page_allocator_is_pending_ticket_d   : page_allocator_is_pending_ticket_d_t;

    -- combinational wires
    -- ticket
    type page_allocator_if_read_ticket_ticket_t is array (0 to N_LANE-1) of ticket_t;
    signal page_allocator_if_read_ticket_ticket : page_allocator_if_read_ticket_ticket_t;
    signal page_allocator_is_tk_future          : std_logic_vector(N_LANE-1 downto 0);
    signal page_allocator_is_tk_past            : std_logic_vector(N_LANE-1 downto 0);
    type page_allocator_if_alloc_blk_start_t is array (0 to N_LANE-1) of std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_allocator_if_alloc_blk_start    : page_allocator_if_alloc_blk_start_t;
    signal page_allocator_is_pending_ticket     : std_logic_vector(N_LANE-1 downto 0); -- asserted when rd/wr pointers mismatch 
    -- handle
    type page_allocator_if_write_handle_data_t is array (0 to N_LANE-1) of std_logic_vector(HANDLE_LENGTH-1 downto 0);
    signal page_allocator_if_write_handle_data  : page_allocator_if_write_handle_data_t;
    -- page
    signal page_allocator_if_write_page_data    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    
    -- ────────────────────────────────────────────────
    -- block mover
    -- ────────────────────────────────────────────────
    -- state signals
    type block_mover_state_t is (IDLE, PREP, WRITE_BLK, WRITE_BLK_FINISHING, ABORT_WRITE_BLK, RESET);
    type block_movers_state_t is array (0 to N_LANE-1) of block_mover_state_t;
    signal block_mover_state             : block_movers_state_t;

    -- registers
    type block_mover_t is record 
        word_wr_cnt                         : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
        handle                              : handle_t;
        flag                                : std_logic; -- flag = {skip_blk}
        handle_rptr                         : unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
        lane_rptr                           : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        page_wptr                           : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        page_wreq                           : std_logic;
        lane_credit_update                  : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        lane_credit_update_valid            : std_logic;
        reset_done                          : std_logic;
    end record;

    constant BLOCK_MOVER_REG_RESET      : block_mover_t := (
        word_wr_cnt             => (others => '0'),
        handle                  => HANDLE_REG_RESET,
        flag                    => '0',
        handle_rptr             => (others => '0'),
        lane_rptr               => (others => '0'),
        page_wptr               => (others => '0'),
        page_wreq               => '0',
        lane_credit_update      => (others => '0'),
        lane_credit_update_valid    => '0',
        reset_done              => '0'
    );

    type block_movers_t is array (0 to N_LANE-1) of block_mover_t;
    signal block_mover              : block_movers_t;

    type handle_fifo_is_pending_handle_d_t is array (1 to FIFO_RDW_DELAY) of std_logic_vector(N_LANE-1 downto 0);
    signal handle_fifo_is_pending_handle_d      : handle_fifo_is_pending_handle_d_t;

    -- combinational wires
    signal handle_fifo_is_pending_handle        : std_logic_vector(N_LANE-1 downto 0);
    type handle_fifo_if_rd_t is record
        handle              : handle_t;
        flag                : std_logic;
    end record;
    type handle_fifos_if_rd_t is array (0 to N_LANE-1) of handle_fifo_if_rd_t;
    signal handle_fifo_if_rd                    : handle_fifos_if_rd_t;
    signal lane_fifo_if_rd_eop                  : std_logic_vector(N_LANE-1 downto 0);
    type block_mover_if_write_page_data_t is array (0 to N_LANE-1) of std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal block_mover_if_write_page_data       : block_mover_if_write_page_data_t;

    -- ────────────────────────────────────────────────
    -- arbiter
    -- ────────────────────────────────────────────────
    -- state signal
    type arbiter_state_t is (IDLE, LOCKING, LOCKED, RESET);
    signal arbiter_state                : arbiter_state_t;

    -- registers
    type b2p_arb_t is record
        priority                        : std_logic_vector(N_LANE-1 downto 0);
    end record;

    constant B2P_ARB_REG_RESET          : b2p_arb_t := (
        priority                => (0 => '1', others => '0') -- note: need to put initial priority to first lane
    );

    signal b2p_arb              : b2p_arb_t;

    -- combinational wires
    signal b2p_arb_req                  : std_logic_vector(N_LANE-1 downto 0);
    signal b2p_arb_gnt                  : std_logic_vector(N_LANE-1 downto 0);
    signal b2p_arb_gnt_int              : std_logic_vector(N_LANE-1 downto 0);
    signal b2p_arb_unlock               : std_logic;
    

begin

    assert PAGE_RAM_ADDR_WIDTH = 16 report "PAGE RAM ADDR NON-DEFAULT (16 bits)" severity warning; 

    -- io mapping 
    i_clk           <= d_clk;
    i_rst           <= d_reset;

    -- ────────────────────────────────────────────────
    -- hls generate : fifos insts
    -- ────────────────────────────────────────────────
    @@ for {set i 0} {$i < [llength $fifos_names]} {incr i} {
    @@ set name [lindex $fifos_names $i]
    gen_${name} : for i in 0 to N_LANE-1 generate
        c_${name} : $name
        port map (
            data            => ${name}s_wr_data(i),       
            read_addr       => ${name}s_rd_addr(i), 
            write_addr      => ${name}s_wr_addr(i),      
            we              => ${name}s_we(i),     
            clk             => i_clk,    
            q               => ${name}s_rd_data(i)    
        );
    end generate;
    @@ }

    -- ────────────────────────────────────────────────
    -- page ram
    -- ────────────────────────────────────────────────
    c_page_ram : page_ram
        port map (
            data            => page_ram_wr_data,       
            read_addr       => page_ram_rd_addr, 
            write_addr      => page_ram_wr_addr,      
            we              => page_ram_we,     
            clk             => i_clk,    
            q               => page_ram_rd_data    
        );

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            INGRESS PARSER
    -- @brief           parse the ingress data, write data to lane FIFO, write ticket to ticket FIFO
    -- @input           asi_ingress_<data/valid/channel/startofpacket/endofpacket/error>
    -- @output          ingress_parser_<lane_we/lane_wptr/lane_wdata/lane_credit/ticket_we/ticket_wptr/ticket_wdata/ticket_credit/running_ts/shd_len/dt_type/feb_id/lane_start_addr>
    -- @description     use credit flow control between page allocator and block mover for future CDC upgrade
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_ingress_parser_comb : process (all)
    -- derive some comb signals:
    -- to check: _is_<subheader/preamble/trailer>
    -- iff valid: _if_<subheader/preamble/write_ticket/write_lane>
    -- conn: to ticket FIFO and lane FIFO
    begin
        -- mapping io to here
        @@ for {set i 0} {$i < $n_lane} {incr i} {
            @@ foreach sigType $sigType_list {
        asi_ingress_${sigType}(${i})                    <= asi_ingress_${i}_${sigType};
            @@ }
        @@ }

        for i in 0 to N_LANE -1 loop
            -- speical symbol check [subheader, preamble, trailer]
            if (asi_ingress_data(i)(7 downto 0) = K237 and asi_ingress_data(i)(35 downto 32) = "0001") then 
                ingress_parser_is_subheader(i)              <= '1';
            else 
                ingress_parser_is_subheader(i)              <= '0';
            end if;
            if (asi_ingress_data(i)(7 downto 0) = K285 and asi_ingress_data(i)(35 downto 32) = "0001") then 
                ingress_parser_is_preamble(i)               <= '1';
            else 
                ingress_parser_is_preamble(i)               <= '0';
            end if;
            if (asi_ingress_data(i)(7 downto 0) = K284 and asi_ingress_data(i)(35 downto 32) = "0001") then 
                ingress_parser_is_trailer(i)                <= '1';
            else 
                ingress_parser_is_trailer(i)                <= '0';
            end if;

            -- error signal, always valid but user must use with discretion
            ingress_parser_hit_err(i)                     <= asi_ingress_error(i)(0); 
            ingress_parser_shd_err(i)                     <= asi_ingress_error(i)(1);
            ingress_parser_hdr_err(i)                     <= asi_ingress_error(i)(2);

            -- if=conditional
            ingress_parser_if_subheader_hit_cnt(i)        <= unsigned(asi_ingress_data(i))(15 downto 8);
            ingress_parser_if_subheader_shd_ts(i)         <= asi_ingress_data(i)(31 downto 24);
            ingress_parser_if_preamble_dt_type(i)         <= asi_ingress_data(i)(31 downto 26);
            ingress_parser_if_preamble_feb_id(i)          <= asi_ingress_data(i)(23 downto 8);
            if (ingress_parser_state(i) = IDLE) then -- IDLE : use comb ts and subh_cnt from ingress data
                ingress_parser_if_write_ticket_data(i)(47 downto 0)                                                                         <= std_logic_vector(ingress_parser(i).running_ts)(47 downto 12) & ingress_parser_if_subheader_shd_ts(i) & "0000"; -- ts[47:0]
                ingress_parser_if_write_ticket_data(i)(48+LANE_FIFO_ADDR_WIDTH-1 downto 48)                                                 <= std_logic_vector(ingress_parser(i).lane_start_addr); -- start address of the lane FIFO
                ingress_parser_if_write_ticket_data(i)(48+LANE_FIFO_ADDR_WIDTH+MAX_PKT_LENGTH_BITS-1 downto 48+LANE_FIFO_ADDR_WIDTH)        <= std_logic_vector(ingress_parser_if_subheader_hit_cnt(i)); -- length of the subheader (8-bit)
            else -- WR_HIT : use registered ts and subh_cnt
                ingress_parser_if_write_ticket_data(i)(47 downto 0)                                                                         <= std_logic_vector(ingress_parser(i).running_ts)(47 downto 0); -- ts[47:0]
                ingress_parser_if_write_ticket_data(i)(48+LANE_FIFO_ADDR_WIDTH-1 downto 48)                                                 <= std_logic_vector(ingress_parser(i).lane_start_addr); -- start address of the lane FIFO
                ingress_parser_if_write_ticket_data(i)(48+LANE_FIFO_ADDR_WIDTH+MAX_PKT_LENGTH_BITS-1 downto 48+LANE_FIFO_ADDR_WIDTH)        <= std_logic_vector(ingress_parser(i).shd_len); -- length of the subheader (8-bit)
            end if;
            ingress_parser_if_write_lane_data(i)(35 downto 0)         <= asi_ingress_data(i); -- {data[31:0], byte_is_k[3:0]}
            if ingress_parser(i).ticket_we then -- eop delimiter, inform the block_mover you have reached the end of this block. note: should be used when we write last hit of this block along with the ticket
                ingress_parser_if_write_lane_data(i)(36)                    <= '1'; 
            else 
                ingress_parser_if_write_lane_data(i)(36)                    <= '0';
            end if;
            ingress_parser_if_write_lane_data(i)(37)                  <= '0'; -- sop delimiter, no use for lane FIFO, as subheader is parsed into ticket fifo
            ingress_parser_if_write_lane_data(i)(38)                  <= asi_ingress_error(i)(0); -- error descriptor: {"hit_err"}. hit error from upstream: TBD
            ingress_parser_if_write_lane_data(i)(39)                  <= '0'; -- reserved, set to '0' for now     
            
            -- conn.
            -- > ticket FIFO
            ticket_fifos_wr_data(i)         <= ingress_parser(i).ticket_wdata;
            ticket_fifos_wr_addr(i)         <= std_logic_vector(ingress_parser(i).ticket_wptr - 1); -- note: as we plus 1 for every time we write, e.g., need to start from -1 address
            ticket_fifos_we(i)              <= ingress_parser(i).ticket_we;
            -- > lane FIFO
            lane_fifos_wr_data(i)           <= ingress_parser(i).lane_wdata;
            lane_fifos_wr_addr(i)           <= std_logic_vector(ingress_parser(i).lane_wptr - 1); -- note: as we plus 1 for every time we write, e.g., need to start from -1 address
            lane_fifos_we(i)                <= ingress_parser(i).lane_we;
        end loop;
    end process;


    proc_ingress_parser : process (i_clk)
    -- ingress parser state machine, write to lane FIFO and ticket FIFO
    begin
        if rising_edge(i_clk) then 
            -- parallel parsers (x N_LANE)
            for i in 0 to N_LANE-1 loop
                -- default 
                ingress_parser(i).lane_we               <= '0'; -- write enable to lane FIFO
                ingress_parser(i).ticket_we             <= '0'; -- write enable to ticket FIFO

                -- update credit from block mover, overwritten if write side wants to consume 
                if block_mover(i).lane_credit_update_valid then 
                    ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit + block_mover(i).lane_credit_update;
                end if;

                if page_allocator.ticket_credit_update_valid(i) then
                    ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i); 
                end if;

                -- state machine of ingress parser (x N_LANE)
                case ingress_parser_state(i) is 
                    when IDLE =>
                        if asi_ingress_valid(i)(0) then 
                            -- trigger by new subheader coming in
                            if (ingress_parser_is_subheader(i) and not ingress_parser_shd_err(i)) then -- [subheader]
                                -- update subheader ts (8-bit) and add to into global ts (48-bit) 
                                -- write ticket to ticket FIFO
                                -- ticket = {ts, start addr, length}
                                -- errorDescriptor = {hit_err shd_err hdr_err}
                                ingress_parser(i).running_ts(11 downto 4)   <= unsigned(ingress_parser_if_subheader_shd_ts(i)); -- update subheader timestamp
                                ingress_parser(i).shd_len                   <= unsigned(ingress_parser_if_subheader_hit_cnt(i)); -- shd_hcnt (8-bit) from 0 to 255 hits + 1 (SHD_SIZE)
                                if (ingress_parser_if_subheader_hit_cnt(i) + 1 > ingress_parser(i).lane_credit) then -- pkg size > free words
                                    -- error : incoming packet too large for lane FIFO (lane FIFO low credit)
                                    ingress_parser_state(i)         <= MASK_PKT;
                                elsif (ingress_parser(i).ticket_credit = 0) then 
                                    -- error : ticket FIFO low credit
                                    ingress_parser_state(i)         <= MASK_PKT;
                                else
                                    if (unsigned(ingress_parser_if_subheader_hit_cnt(i)) /= 0) then 
                                        -- ok : but wait until subheader in lane FIFO, then write ticket FIFO
                                        ingress_parser_state(i)         <= WR_HITS;
                                    else
                                        -- ok : write ticket to ticket FIFO now
                                        ingress_parser(i).ticket_we     <= '1';
                                        ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                        ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                        if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket 
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1; 
                                        else
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                        end if;
                                        if block_mover(i).lane_credit_update_valid then -- update lane credit, substract the length to be written, allowing cocurrent updating
                                            ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i) + block_mover(i).lane_credit_update; 
                                        else 
                                            ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i);
                                        end if;
                                    end if;
                                end if;
                            elsif (asi_ingress_startofpacket(i)(0) and ingress_parser_is_preamble(i) and not ingress_parser_hdr_err(i)) then -- [preamble]
                                -- update header ts (48-bit)
                                ingress_parser(i).dt_type       <= ingress_parser_if_preamble_dt_type(i); -- 6 bits, dt_type : ...
                                ingress_parser(i).feb_id        <= ingress_parser_if_preamble_feb_id(i); 
                                update_header_ts_flow(i)        <= 0;
                                ingress_parser_state(i)         <= UPDATE_HEADER_TS; 
                            elsif ingress_parser_is_trailer(i) then -- [trailer]
                                -- write speical ticket for page allocator, to signal end of packet
                                
                            end if;

                            -- upstream error : subheader error
                            if ingress_parser_shd_err(i) then 
                                ingress_parser_state(i)        <= MASK_PKT; -- mask the subheader packet, i.e., do not write to lane FIFO until eop
                            end if;

                            -- up stream error : header error
                            if ingress_parser_hdr_err(i) then 
                                ingress_parser_state(i)        <= MASK_PKT_EXTENDED; -- mask the full packet, i.e., do not write to lane FIFO until trailer or new header is seen
                            end if;

                            -- early termination error from [hit] : set the wr lane ptr to the end of subheader position
                            if (ingress_parser(i).error_lane_wr_early_term) then 
                                ingress_parser(i).error_lane_wr_early_term          <= '0';
                                ingress_parser(i).lane_wptr                         <= ingress_parser(i).lane_start_addr + ingress_parser(i).shd_len; -- reset the write pointer to the end, as we have already consumed the credit
                            end if;
                        end if;

                    when UPDATE_HEADER_TS =>
                        if asi_ingress_valid(i)(0) then 
                            -- update header information (**48-bit running_ts**, 16-bit pkg_cnt, 15-bit running_shd_cnt, 31-bit send_ts, 16-bit hit_cnt)
                            case update_header_ts_flow(i) is 
                                when 0 => -- [data header 0]
                                    ingress_parser(i).running_ts(47 downto 16)      <= unsigned(asi_ingress_data(i)(31 downto 0));
                                    update_header_ts_flow(i)                        <= update_header_ts_flow(i) + 1; -- next state    
                                when 1 => -- [data header 1]
                                    ingress_parser(i).running_ts(15 downto 12)      <= unsigned(asi_ingress_data(i)(31 downto 28)); -- note: do not overwrite subheader ts bit field
                                    ingress_parser(i).pkg_cnt                       <= asi_ingress_data(i)(15 downto 0);
                                    update_header_ts_flow(i)                        <= update_header_ts_flow(i) + 1; -- next state
                                when 2 => -- [debug word 0]
                                    ingress_parser(i).running_shd_cnt               <= asi_ingress_data(i)(30 downto 16);
                                    ingress_parser(i).hit_cnt                       <= unsigned(asi_ingress_data(i)(15 downto 0));
                                    update_header_ts_flow(i)                        <= update_header_ts_flow(i) + 1; -- next state
                                when 3 => -- [debug word 1]
                                    ingress_parser(i).send_ts                       <= asi_ingress_data(i)(30 downto 0);
                                    update_header_ts_flow(i)                        <= 0; -- reset state, as return 0 (no error)
                                    ingress_parser_state(i)                         <= IDLE; -- go back to IDLE
                                when others =>
                                    null;
                            end case;

                            -- upstream error : header error
                            if ingress_parser_hdr_err(i) then 
                                -- header error, mask the full packet, i.e., do not write to lane FIFO until trailer or preamble
                                ingress_parser_state(i)        <= MASK_PKT_EXTENDED;
                            end if;
                        end if;

                    when MASK_PKT_EXTENDED => -- mask until end of the full packet
                        if ingress_parser_is_trailer(i) then -- [trailer]
                            -- unmask input flow
                            ingress_parser_state(i)        <= IDLE; -- go back to IDLE
                        end if; 

                        if ingress_parser_is_preamble(i) then -- encountered [preamble], missing trailer due to broken packet
                            -- update header ts (48-bit)
                            ingress_parser(i).dt_type       <= ingress_parser_if_preamble_dt_type(i); -- 6 bits, dt_type : ...
                            ingress_parser(i).feb_id        <= ingress_parser_if_preamble_feb_id(i); 
                            update_header_ts_flow(i)        <= 0;
                            ingress_parser_state(i)         <= UPDATE_HEADER_TS; 
                        end if;
                
                    when MASK_PKT => -- mask until end of this subheader packet 
                        if (asi_ingress_valid(i)(0) and asi_ingress_endofpacket(i)(0)) then -- packet eop
                            ingress_parser_state(i)        <= IDLE;
                        end if;

                        if asi_ingress_valid(i)(0) then 
                            -- trigger by new subheader coming in
                            if (ingress_parser_is_subheader(i) and not ingress_parser_shd_err(i)) then -- [subheader]
                                -- update subheader ts (8-bit) and add to into global ts (48-bit) 
                                -- write ticket to ticket FIFO
                                -- ticket = {ts, start addr, length}
                                -- errorDescriptor = {hit_err shd_err hdr_err}
                                ingress_parser(i).running_ts(11 downto 4)   <= unsigned(ingress_parser_if_subheader_shd_ts(i)); -- update subheader timestamp
                                ingress_parser(i).shd_len                   <= unsigned(ingress_parser_if_subheader_hit_cnt(i)); -- shd_hcnt (8-bit) from 0 to 255 hits + 1 (SHD_SIZE)
                                if (ingress_parser_if_subheader_hit_cnt(i) + 1 > ingress_parser(i).lane_credit) then -- pkg size > free words
                                    -- error : incoming packet too large for lane FIFO (lane FIFO low credit)
                                    ingress_parser_state(i)         <= MASK_PKT;
                                elsif (ingress_parser(i).ticket_credit = 0) then 
                                    -- error : ticket FIFO low credit
                                    ingress_parser_state(i)         <= MASK_PKT;
                                else
                                    if (unsigned(ingress_parser_if_subheader_hit_cnt(i)) /= 0) then 
                                        -- ok : but wait until subheader in lane FIFO, then write ticket FIFO
                                        ingress_parser_state(i)         <= WR_HITS;
                                    else
                                        -- ok : write ticket to ticket FIFO now
                                        ingress_parser(i).ticket_we     <= '1';
                                        ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                        ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                        if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket 
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1; 
                                        else
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                        end if;
                                        if block_mover(i).lane_credit_update_valid then -- update lane credit, substract the length to be written, allowing cocurrent updating
                                            ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i) + block_mover(i).lane_credit_update; 
                                        else 
                                            ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i);
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;

                    when WR_HITS => -- [hit(s)] 
                        -- ingress data -> lane FIFO (write hits to lane FIFO)
                        if (asi_ingress_valid(i)(0) and not ingress_parser_hit_err(i)) then -- hit w/o error
                            -- ok : write lane data 
                            ingress_parser(i).lane_wdata            <= ingress_parser_if_write_lane_data(i); -- see proc_assemble_write_lane_fifo
                            ingress_parser(i).lane_wptr             <= ingress_parser(i).lane_wptr + 1; -- increment write pointer as we will write to lane FIFO
                            ingress_parser(i).lane_we               <= '1'; -- write enable to lane FIFO
                        elsif ingress_parser_shd_err(i) then 
                            -- error : early eop seen, set the wr ptr to the expected length (next cycle)
                            ingress_parser(i).error_lane_wr_early_term      <= '1';
                        end if;

                        -- exit : ticket -> ticket FIFO (write ticekt when last hit)
                        if (asi_ingress_valid(i)(0) and not ingress_parser_hit_err(i)) then -- kick the end of subheader
                            if (ingress_parser(i).lane_start_addr + ingress_parser(i).shd_len = ingress_parser(i).lane_wptr + 1) then -- note: write ticket in the last cycle of WR_HITS
                                -- ok : write ticket to ticket FIFO now
                                ingress_parser(i).ticket_we     <= '1';
                                ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket 
                                    ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1; 
                                else
                                    ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                end if;
                                if block_mover(i).lane_credit_update_valid then -- update lane credit, substract the length to be written, allowing cocurrent updating
                                    ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i) + block_mover(i).lane_credit_update; 
                                else 
                                    ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i);
                                end if;
                                -- update the start addr
                                ingress_parser(i).lane_start_addr   <= ingress_parser(i).lane_wptr + 1; -- note: wptr is like a wrcnt (larger than waddr by 1). wptr-1 = waddr, record waddr
                                -- [EXIT] can move on immediately
                                ingress_parser_state(i)           <= IDLE; 
                            end if;
                        end if;

                        -- corner case (forbidden): if the in last cycle of WR_HITS, the next subheader is coming from ingress, write ticket (will be in IDLE)
                        -- if (asi_ingress_valid(i)(0) and not ingress_parser_hit_err(i)) then 
                        --     -- trigger by new subheader coming in
                        --     if (ingress_parser_is_subheader(i) and not ingress_parser_shd_err(i)) then -- [subheader]
                        --         -- update subheader ts (8-bit) and add to into global ts (48-bit) 
                        --         -- write ticket to ticket FIFO
                        --         -- ticket = {ts, start addr, length}
                        --         -- errorDescriptor = {hit_err shd_err hdr_err}
                        --         ingress_parser(i).running_ts(11 downto 4)   <= unsigned(ingress_parser_if_subheader_shd_ts(i)); -- update subheader timestamp
                        --         ingress_parser(i).shd_len                   <= unsigned(ingress_parser_if_subheader_hit_cnt(i)); -- shd_hcnt (8-bit) from 0 to 255 hits + 1 (SHD_SIZE)
                        --         if (ingress_parser_if_subheader_hit_cnt(i) + 1 > ingress_parser(i).lane_credit) then -- pkg size > free words
                        --             -- error : incoming packet too large for lane FIFO (lane FIFO low credit)
                        --             ingress_parser_state(i)         <= MASK_PKT;
                        --         elsif (ingress_parser(i).ticket_credit = 0) then 
                        --             -- error : ticket FIFO low credit
                        --             ingress_parser_state(i)         <= MASK_PKT;
                        --         else
                        --             if (unsigned(ingress_parser_if_subheader_hit_cnt(i)) /= 0) then 
                        --                 -- ok : but wait until subheader in lane FIFO, then write ticket FIFO
                        --                 ingress_parser_state(i)         <= WR_HITS;
                        --             else
                        --                 -- ok : write ticket to ticket FIFO now
                        --                 ingress_parser(i).ticket_we     <= '1';
                        --                 ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                        --                 ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                        --                 if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket 
                        --                     ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1; 
                        --                 else
                        --                     ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                        --                 end if;
                        --                 if block_mover(i).lane_credit_update_valid then -- update lane credit, substract the length to be written, allowing cocurrent updating
                        --                     ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i) + block_mover(i).lane_credit_update; 
                        --                 else 
                        --                     ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit - ingress_parser_if_subheader_hit_cnt(i);
                        --                 end if;
                        --             end if;
                        --         end if;
                        --     end if;
                        -- end if;

                    when RESET => 
                        -- reset all the register pack
                        ingress_parser(i)                  <= INGRESS_PARSER_REG_RESET;
                        if (ingress_parser(i).lane_credit = LANE_FIFO_MAX_CREDIT and ingress_parser(i).ticket_credit = TICKET_FIFO_MAX_CREDIT) then
                            -- wait until all block mover to send back credit, so it can write an empty FIFO
                            ingress_parser_state(i)            <= IDLE;
                        end if;

                    when others =>
                        null;
                end case;

                -- delay chain 
                for j in 1 to FIFO_RDW_DELAY loop
                    if j = 1 then 
                        page_allocator_is_pending_ticket_d(j)(i)       <= page_allocator_is_pending_ticket(i);
                    else 
                        page_allocator_is_pending_ticket_d(j)(i)       <= page_allocator_is_pending_ticket_d(j-1)(i);
                    end if;
                end loop;

                -- reset 
                if i_rst then 
                   ingress_parser_state(i)         <= RESET;         
                end if;
            end loop;
        end if;
    end process;



    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            PAGE ALLOCATOR
    -- @brief           allocate a page in the page RAM once all tickets are available
    -- @input           ticket_fifos_rd_data, page_allocator.running_ts
    -- @output          page_allocator_if_read_ticket_page_length, page_allocator_if_alloc_blk_start, ticket_wr_comb
    -- @description     process the read ticket FIFO data, assemble the page RAM write data and ticket write data
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_page_allocator_comb : process (all)
    begin
        for i in 0 to N_LANE-1 loop
            -- assemble handle
            if (i > 0) then 
                page_allocator_if_alloc_blk_start(i)         <= std_logic_vector(page_allocator.page_start_addr + page_allocator.ticket(i-1).block_length + i*SHD_SIZE); -- need to offset by subheader (1 word) 
            else 
                page_allocator_if_alloc_blk_start(i)         <= std_logic_vector(page_allocator.page_start_addr + i*SHD_SIZE);
            end if;
            page_allocator_if_write_handle_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO)         <= page_allocator.ticket(i).lane_fifo_rd_offset; -- source
            page_allocator_if_write_handle_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO)         <= page_allocator_if_alloc_blk_start(i); -- destination 
            page_allocator_if_write_handle_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO)         <= std_logic_vector(page_allocator.ticket(i).block_length); -- length

            if (ingress_parser(i).ticket_wptr /= page_allocator.ticket_rptr) then -- ex: wr ptr = 7, wr addr = 6. rd ptr = rd addr = 6, no ticket
                page_allocator_is_pending_ticket(i)   <= '1'; -- there is pending ticket to be read
            else 
                page_allocator_is_pending_ticket(i)   <= '0'; -- no pending ticket to be read
            end if;
        end loop;

        -- page RAM write data
        page_allocator_if_write_page_data(35 downto 32)     <= "0001"; -- byte_is_k[3:0] = "0001" for subheader
        page_allocator_if_write_page_data(31 downto 24)     <= std_logic_vector(page_allocator.running_ts(11 downto 4)); -- ts[11:4] of the subheader
        page_allocator_if_write_page_data(23 downto 8)      <= std_logic_vector(to_unsigned(to_integer(unsigned(std_logic_vector(page_allocator.page_length))),23-8+1)); -- hit cnt of this subheader
        page_allocator_if_write_page_data(7 downto 0)       <= K237; -- write subheader begin marker

        -- conn. 
        for i in 0 to N_LANE-1 loop
        -- > handle FIFO
            handle_fifos_we(i)                                      <= page_allocator.handle_we(i);
            handle_fifos_wr_data(i)(HANDLE_LENGTH downto 0)         <= page_allocator.handle_wflag(i) & page_allocator_if_write_handle_data(i); -- handle = {flag 1-bit, data}
            handle_fifos_wr_addr(i)                                 <= std_logic_vector(page_allocator.handle_wptr(i) - 1); -- note: we start from -1 ptr, so first write word will be in addr 0
        -- ticket FIFO >
            ticket_fifos_rd_addr(i)                                 <= std_logic_vector(page_allocator.ticket_rptr);  
            -- deassemble ticket
            page_allocator_if_read_ticket_ticket(i).ticket_ts                   <= unsigned(ticket_fifos_rd_data(i)(47 downto 0)); -- ts[47:0]
            page_allocator_if_read_ticket_ticket(i).lane_fifo_rd_offset         <= ticket_fifos_rd_data(i)(48+LANE_FIFO_ADDR_WIDTH-1 downto 48); -- start address of the lane RAM
            page_allocator_if_read_ticket_ticket(i).block_length                <= unsigned(ticket_fifos_rd_data(i)(48+MAX_PKT_LENGTH_BITS+LANE_FIFO_ADDR_WIDTH-1 downto 48+LANE_FIFO_ADDR_WIDTH)); -- length of the subheader (8-bit), excl subheader itself
            if (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) > page_allocator.running_ts) then 
                page_allocator_is_tk_future(i)              <= '1';
            else 
                page_allocator_is_tk_future(i)              <= '0';
            end if;
            if (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) < page_allocator.running_ts) then 
                page_allocator_is_tk_past(i)                <= '1';
            else 
                page_allocator_is_tk_past(i)                <= '0';
            end if;
        end loop;
        -- > page RAM
        -- controlled by ARB ...

    end process;


    gen_alloc_by_mode : if (MODE = "MERGING") generate -- mode = {MERGING MULTIPLEXING}
        proc_page_allocator : process (i_clk)
        -- @description     allocate a page in the page RAM once all tickets are available. ipc to block mover to start the routine.
        -- @note            can skip late ticket
        --                  return credit to write_ticket_fifo
        begin
            if rising_edge(i_clk) then 
                -- default
                for i in 0 to N_LANE-1 loop
                    page_allocator.ticket_credit_update_valid(i)    <= '0'; 
                    page_allocator.handle_we(i)                     <= '0';
                end loop;
                page_allocator.page_we                          <= '0';

                -- state machine of page allocator
                case page_allocator_state is 
                    when IDLE => 
                        -- standby state, wait for ticket FIFO to have pending tickets
                        if (and_reduce(page_allocator_is_pending_ticket_d(FIFO_RDW_DELAY)) = '1' and and_reduce(page_allocator_is_pending_ticket) = '1') then -- all lanes have packet, check both tail and head of the delay chain
                            page_allocator_state            <= FETCH_TICKET; -- fetch HOL ticket from ticket FIFO  
                        end if;

                    when FETCH_TICKET =>
                        -- fetch a ticket from ticket FIFO and derive its timeliness. since we only write ticket if the lane has fully written to lane, it guarantee block mover can start right away
                        -- default
                        page_allocator.lane_masked            <= (others => '0'); -- assume not to mask
                        page_allocator.lane_skipped           <= (others => '0'); -- assume not to skip

                        for i in 0 to N_LANE-1 loop
                            -- return 1 unit of credit to ingress parser (ack we read the ticket)
                            page_allocator.ticket_credit_update(i)          <= to_unsigned(1,TICKET_FIFO_ADDR_WIDTH); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                            page_allocator.ticket_credit_update_valid(i)    <= '1';

                            -- fetch (read) ticket from ticket FIFO
                            -- ticket = {ts[47:0], start addr[9:0], length[9:0]}
                            if page_allocator_is_tk_future(i) then
                                -- [exception] maybe a skip, as we read ticket with timestamp in the future : do not read this ticket yet, reserve for next round 
                                page_allocator.ticket_rptr                    <= page_allocator.ticket_rptr; -- ignore ticket for this round
                                page_allocator.lane_masked(i)                 <= '1'; -- mask this lane, do not allocate in the page and let the block mover to ignore it
                                page_allocator.ticket_credit_update_valid(i)  <= '0'; -- note: do not return ticket, otherwise credit overflow
                            elsif page_allocator_is_tk_past(i) then
                                -- [exception] maybe a glitch, as we read ticket with timestamp in the past : drop this ticket
                                page_allocator.ticket_rptr                    <= page_allocator.ticket_rptr + 1; -- drop ack, incr ticket read pointer by 1
                                page_allocator.lane_skipped(i)                <= '1'; -- skip this lane, do not allocate in the page and let the block mover to skip it
                            else 
                                page_allocator.ticket(i)                      <= page_allocator_if_read_ticket_ticket(i); -- latch the ticket from ticket FIFO
                                page_allocator.ticket_rptr                    <= page_allocator.ticket_rptr + 1; -- read ack, incr ticket read pointer by 1
                                -- latch page length (only contains the blocks belong to current page)
                                page_allocator.page_length                    <= page_allocator.page_length + unsigned(ticket_fifos_rd_data(i)(48+LANE_FIFO_ADDR_WIDTH+MAX_PKT_LENGTH_BITS-1 downto 48+LANE_FIFO_ADDR_WIDTH)); -- length of the subheader (8-bit)
                            end if;
                        end loop;

                        -- exit condition : if all lanes have been fetched
                        page_allocator_state                          <= ALLOC_PAGE; -- allocate a page in the page RAM
                        page_allocator.alloc_page_flow                <= 0; -- reset entry point, TODO: to speed up, find the leading 1 of unmask and unskip lane, and the next...

                    when ALLOC_PAGE => 
                        -- allocate a page in the page RAM
                        -- default
                        page_allocator.alloc_page_flow         <= page_allocator.alloc_page_flow + 1; -- increment flow 

                        -- flow : write to handle FIFO to start block mover
                        for i in 0 to N_LANE-1 loop
                            -- write handle = {dst, src, length} to block mover, in a sequence lane by lane (better timing), from ticket = {ts[47:0], start addr[9:0], length[9:0]}
                            if (page_allocator.alloc_page_flow = i) then    
                                if (page_allocator.ticket(i).block_length = 0) then 
                                    -- do not write : no data in lane
                                    page_allocator.handle_we(i)                 <= '0'; -- TODO: remove it
                                elsif page_allocator.lane_skipped(i) then
                                    -- past ticket : mover must skip this lane
                                    page_allocator.handle_we(i)                 <= '1'; -- write skip flag to block mover
                                    page_allocator.handle_wflag(i)              <= '1'; -- flag = {skip_blk}, drop this block and return credit through lane FIFO
                                    page_allocator.handle_wptr(i)               <= page_allocator.handle_wptr(i) + 1;
                                elsif page_allocator.lane_masked(i) then 
                                    -- future ticket : mover can continue with current task
                                    page_allocator.handle_we(i)                 <= '0'; -- TODO: remove it
                                else 
                                    -- write ok
                                    page_allocator.handle_we(i)                 <= '1'; -- write to the handle FIFO
                                    page_allocator.handle_wptr(i)               <= page_allocator.handle_wptr(i) + 1;
                                end if;
                            end if;

                            -- end of ALLOC_PAGE state
                            if (page_allocator.alloc_page_flow = N_LANE-1) then 
                                -- update current running timestamp
                                page_allocator.running_ts(47 downto 4)               <= page_allocator.running_ts(47 downto 4) + 1; -- for each round, we increase the tracking ts by one subheader time unit
                                -- prepare to write subheader to page RAM 
                                page_allocator.page_we                          <= '1';
                                page_allocator.page_wdata                       <= page_allocator_if_write_page_data;
                                page_allocator.page_waddr                       <= page_allocator_if_alloc_blk_start(0); -- page boundary address = subheader line = first line of this page
                            end if;
                        end loop; 
                                
                        -- exit condition : if all lanes have been allocated a block in the page
                        if (page_allocator.alloc_page_flow = N_LANE-1) then 
                            page_allocator_state                        <= WRITE_PAGE; -- write the page, i.e., subheader, to the page RAM
                            page_allocator.alloc_page_flow              <= 0; -- reset flow, return 0 as OK
                        end if;

                    when WRITE_PAGE =>
                        page_allocator.page_start_addr                  <= unsigned(page_allocator.page_waddr) + page_allocator.page_length + 1; -- update to next page length, note: only 1 cycle
                        page_allocator_state                            <= IDLE;
                        -- write happens here...
                        
                    when RESET => 
                        -- reset register pack and return credit to source
                        if not page_allocator.reset_done then -- 1 cycle to return the credit
                            -- except for credit, we need to return to the source, because the source can be in non-reset state
                            for i in 0 to N_LANE-1 loop
                                page_allocator.ticket_credit_update(i)          <= to_unsigned(TICKET_FIFO_MAX_CREDIT,page_allocator.ticket_credit_update(i)'length); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                                page_allocator.ticket_credit_update_valid(i)    <= '1';
                            end loop;
                            page_allocator.reset_done                       <= '1';
                        else 
                            if not i_rst then -- wait for reset to deassert
                                -- reset everything here, 1 cycle to reset all registers and return to IDLE
                                page_allocator_state                        <= IDLE;
                            end if;
                        end if;
                        
                    when others =>
                        null;
                end case;

                -- sync reset
                if i_rst then 
                    page_allocator_state            <= RESET;
                    if (page_allocator_state /= RESET) then -- only reset register pack once. reset_done should be high for the rest of the states
                        page_allocator                  <= PAGE_ALLOCATOR_REG_RESET; -- reset register pack
                        page_allocator.reset_done       <= '0';
                    end if;
                end if;
                
            end if;
        end process;
    end generate;



    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            BLOCK MOVER
    -- @brief           move the subheader from lane FIFO into page RAM according to the handle 
    -- @input           
    -- @output          
    -- @description     can skip late hits and retrieve next handle
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_block_mover_comb : process (all)
    begin
        for i in 0 to N_LANE-1 loop
            -- if pending handle
            if (page_allocator.handle_wptr(i) /= block_mover(i).handle_rptr) then -- note: wr_addr = wr_ptr - 1 = rd_addr. when not equal, meaning pending ticket
                handle_fifo_is_pending_handle(i)       <= '1';
            else 
                handle_fifo_is_pending_handle(i)       <= '0';
            end if;
            
            -- conn.
            -- lane FIFO > 
            lane_fifos_rd_addr(i)                                   <= std_logic_vector(block_mover(i).lane_rptr);
            block_mover_if_write_page_data(i)(35 downto 0)          <= lane_fifos_rd_data(i)(35 downto 0); -- TODO: check what is written by ingress parser
            lane_fifo_if_rd_eop(i)                                  <= lane_fifos_rd_data(i)(36); -- normal eop of subheader
            -- handle FIFO >
            handle_fifos_rd_addr(i)                                 <= std_logic_vector(block_mover(i).handle_rptr);
            -- deassemble handle
            handle_fifo_if_rd(i).handle.src        <= unsigned(handle_fifos_rd_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO));
            handle_fifo_if_rd(i).handle.dst        <= unsigned(handle_fifos_rd_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO));
            handle_fifo_if_rd(i).handle.blk_len    <= unsigned(handle_fifos_rd_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO));
            -- > page RAM
            -- controlled by ARB 
        end loop;
    end process;

    proc_block_mover : process (i_clk)
    -- read from handle FIFO : handle  =  {dst, src, blk_len(length)}
    begin
        if rising_edge(i_clk) then 
            -- block mover state machine (x N_LANE)
            for i in 0 to N_LANE-1 loop
                -- default
                block_mover(i).page_wreq                    <= '0';
                block_mover(i).lane_credit_update_valid     <= '0';

                case block_mover_state(i) is 
                    when IDLE =>
                        -- standby state, wait for ticket from page allocator to write to blk handle FIFO
                        -- reset 
                        block_mover(i).word_wr_cnt          <= (others => '0');
                        -- pop HOL handle, decide to start or not
                        if (handle_fifo_is_pending_handle_d(FIFO_RDW_DELAY)(i) = '1' and handle_fifo_is_pending_handle(i) = '1') then -- head (rdptr incr'd, maybe no new handle) and tail (wrptr incr'd, no data yet) of the pipe are valid
                            block_mover(i).handle               <= handle_fifo_if_rd(i).handle;
                            block_mover(i).flag                 <= handle_fifo_if_rd(i).flag;
                            if (handle_fifo_if_rd(i).flag = '0') then -- flag = {skip_blk}
                                -- start the block mover, read from lane FIFO and write to page RAM
                                block_mover_state(i)                <= PREP; -- go to preparing write page RAM state
                            else 
                                block_mover_state(i)                <= ABORT_WRITE_BLK; -- go to abort state
                            end if;
                        end if;

                    when PREP =>
                        -- preparation state, set the pointer, so data can be used the next cycle
                        -- handle (read from handle FIFO) =  {src, dst, blk_len(length)}
                        block_mover(i).lane_rptr          <= block_mover(i).handle.src; 
                        block_mover(i).page_wptr          <= block_mover(i).handle.dst; -- set the wptr = page RAM block starting address
                        block_mover(i).word_wr_cnt        <= to_unsigned(1,MAX_PKT_LENGTH_BITS); -- already set to 1
                        block_mover(i).page_wreq          <= '1'; 
                        block_mover_state(i)              <= WRITE_BLK;

                    when WRITE_BLK => 
                        -- moving state, move data from lane FIFO to page RAM according to handle
                        -- request and post data
                        block_mover(i).page_wreq      <= '1'; -- request to write

                        -- if granted, can be the same cycle
                        if b2p_arb_gnt(i) then -- last write ok
                            if (block_mover(i).word_wr_cnt < block_mover(i).handle.blk_len - 1) then -- normal write, until last word
                                block_mover(i).lane_rptr            <= block_mover(i).lane_rptr + 1; -- incr read pointer of lane FIFO
                                block_mover(i).word_wr_cnt          <= block_mover(i).word_wr_cnt + 1; -- update cnt
                            else
                                block_mover(i).word_wr_cnt          <= block_mover(i).word_wr_cnt + 1; -- update cnt
                                block_mover_state(i)                <= WRITE_BLK_FINISHING;
                            -- else -- [exit] nearly finished according to handle
                            --     if lane_fifo_if_rd_eop(i) then -- normal exit
                            --         block_mover_state(i)                <= WRITE_BLK_FINISHING;
                            --     else -- error exit
                            --         -- TODO: report, handle and log the error
                            --         block_mover_state(i)                <= WRITE_BLK_FINISHING; -- ABORT_WRITE_BLK;
                            --     end if;
                            end if;
                        end if;

                        -- [exception] hit too late
                        -- if (unsigned(block_mover(i).hit_ts) - gts_counter.running_ts > unsigned(csr.expected_latency)) then 
                        --     block_mover(i).page_wreq      <= '0';
                        --     block_mover_state(i)            <= ABORT_WRITE_BLK;
                        -- end if;

                    when WRITE_BLK_FINISHING => 
                        -- sending the last word
                        if (b2p_arb_gnt(i) = '1') then -- [exit] last word accepted
                            block_mover(i).lane_credit_update       <= to_unsigned(to_integer(block_mover(i).handle.blk_len),block_mover(i).lane_credit_update'length); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                            block_mover(i).lane_credit_update_valid <= '1';
                            block_mover_state(i)                    <= IDLE;
                            block_mover(i).word_wr_cnt              <= (others => '0'); -- reset write word counter
                            block_mover(i).handle_rptr              <= block_mover(i).handle_rptr + 1;
                        else -- spinning, last word not yet accepted
                            block_mover(i).page_wreq          <= '1'; -- only assert here iff
                        end if;

                    when ABORT_WRITE_BLK =>
                        -- abort the write block, due to late hits
                        block_mover(i).handle_rptr              <= block_mover(i).handle_rptr + 1;
                        block_mover(i).lane_credit_update       <= to_unsigned(to_integer(block_mover(i).handle.blk_len),block_mover(i).lane_credit_update'length); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                        block_mover(i).lane_credit_update_valid <= '1';
                        block_mover_state(i)                    <= IDLE;
                    
                    when RESET =>
                        if not block_mover(i).reset_done then -- 1 cycle to return the credit
                            -- except for credit, we need to return to the source, because the source can be in non-reset state
                            block_mover(i).lane_credit_update       <= to_unsigned(LANE_FIFO_MAX_CREDIT,block_mover(i).lane_credit_update'length); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                            block_mover(i).lane_credit_update_valid <= '1';
                            block_mover(i).reset_done               <= '1';
                        else 
                            if not i_rst then -- wait for reset to deassert
                                -- reset everything here, 1 cycle to reset all registers and return to IDLE
                                block_mover_state(i)                    <= IDLE;
                            end if;
                        end if;
                        
                    when others =>
                        null;
                end case;

                -- delay chain
                for j in 1 to FIFO_RDW_DELAY loop
                    if j = 1 then 
                        handle_fifo_is_pending_handle_d(j)(i)        <= handle_fifo_is_pending_handle(i);
                    else 
                        handle_fifo_is_pending_handle_d(j)(i)        <= handle_fifo_is_pending_handle_d(j-1)(i);
                    end if;
                end loop; 

                -- sync reset
                if i_rst then 
                    block_mover_state(i)            <= RESET;
                    if (block_mover_state(i) /= RESET) then -- reset register pack here. reset_done should be high for the rest of the states
                        block_mover(i)                  <= BLOCK_MOVER_REG_RESET;
                        block_mover(i).reset_done       <= '0';
                    end if;
                end if;
            end loop;
        end if;

    end process;

    -- use Frame table {FIN TS CNT | READON} to track the number of packets in the frame buffer
    -- write will write to the left column. read will write to the right column. once READON = '1' and next cycle FIN is still '1' (ack of lock). write may not overwrite or revoke this package. 
    -- if read side is valid, show the next leading packet.
    -- use RD Debug I/F to check the fill level.  

            
    
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            B2P_ARBITER 
    -- @brief           grant the write access from block movers into page ram
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_b2p_arbiter : process (i_clk)
    begin
        if rising_edge (i_clk) then 
            case arbiter_state is 
                when IDLE => 
                    -- any request to write to page ram from block mover
                    if or_reduce(b2p_arb_req) then 
                        if or_reduce(b2p_arb_gnt) then -- grant in the same cycle
                            b2p_arb.priority            <= b2p_arb_gnt(N_LANE-2 downto 0) & b2p_arb_gnt(N_LANE-1);
                            b2p_arb_gnt_int             <= b2p_arb_gnt;
                            arbiter_state               <= LOCKED;
                        else
                            arbiter_state               <= LOCKING;
                        end if;
                    end if;

                when LOCKING => 
                    -- latch the new priority, shift to left by 1 lane
                    if or_reduce(b2p_arb_gnt) then 
                        b2p_arb.priority            <= b2p_arb_gnt(N_LANE-2 downto 0) & b2p_arb_gnt(N_LANE-1);
                        b2p_arb_gnt_int             <= b2p_arb_gnt;
                        arbiter_state               <= LOCKED;
                    end if;

                when LOCKED => 
                    -- request from granted lane is de-asserted, release the lock
                    for i in 0 to N_LANE-1 loop
                        if (b2p_arb_gnt_int(i) = '1' and b2p_arb_req(i) = '0') then 
                            arbiter_state           <= IDLE;
                        end if;
                    end loop;
                    -- timeout
                        -- ...
                when RESET => 
                    b2p_arb                 <= B2P_ARB_REG_RESET;
                    arbiter_state           <= IDLE;

                when others => 
                    null;
            end case;

            if (i_rst = '1') then 
                arbiter_state            <= RESET;
            end if;
        end if;
    end process;

    proc_b2p_arbiter_comb : process (all)
        variable result0		: std_logic_vector(N_LANE*2-1 downto 0);
        variable result0p5		: std_logic_vector(N_LANE*2-1 downto 0);
        variable result1		: std_logic_vector(N_LANE*2-1 downto 0);
        variable result2		: std_logic_vector(N_LANE*2-1 downto 0);
        variable code			: std_logic_vector(CHANNEL_WIDTH-1 downto 0); -- find leading '1' position in binary
		variable count			: unsigned(CHANNEL_WIDTH downto 0); -- TODO: fix this! (fixed) 0 to 127, for msb, it is overflow, which means all '1's. 
        variable req            : std_logic; -- request from the current selected lane
    begin
        -- input of request
        for i in 0 to N_LANE-1 loop
            b2p_arb_req(i)     <= block_mover(i).page_wreq;
        end loop;
        
        -- derive which lane to grant
		-- +------------------------------------------------------------------------------------+
		-- | Concept borrowed from 'altera_merlin_std_arbitrator_core.sv`                       |
		-- |                                                                                    |
		-- | Example:                                                                           |
		-- |                                                                                    |
		-- | top_priority                        =        010000                                |
		-- | {request, request}                  = 001001 001001  (result0)                     |
		-- | {~request, ~request} + top_priority = 110111 000110  (result1)                     |
		-- | result of & operation               = 000001 000000  (result2)                     |
		-- | next_grant                          =        000001  (grant_comb)                  |
		-- +------------------------------------------------------------------------------------+
		result0		:= b2p_arb_req & b2p_arb_req;
		result0p5	:= not b2p_arb_req & not b2p_arb_req;
		result1		:= std_logic_vector(unsigned(result0p5) + unsigned(b2p_arb.priority));
		result2		:= result0 and result1;
		if (or_reduce(result2(N_LANE-1 downto 0)) = '0') then 
			b2p_arb_gnt		    <= result2(N_LANE*2-1 downto N_LANE);
		else
            b2p_arb_gnt		    <= result2(N_LANE-1 downto 0);
		end if;

        -- b2p_arb_gnt_int         <= b2p_arb_gnt; -- copy the signal to internal use

        -- interrupt by page allocator
        if (page_allocator_state = WRITE_PAGE) then 
            b2p_arb_gnt         <= (others => '0');
        end if;

        -- convert onehot gnt into binary
        gen_binary : for i in 0 to N_LANE-1 loop -- from lsb to msb, msb will overwrite lsb ones.  
            -- casecade mux many stages, compare if '1', sel and go to next stage
            -- input: stage index, (last stage counter+1) and last stage code and count 
            -- output: code, count
            if (b2p_arb_gnt(i) = '1') then 
                code 		:= std_logic_vector(to_unsigned(i, code'length));
                req         := b2p_arb_req(i);
                count 		:= count + 1;
            else
                code 		:= code;
                req         := req;
                count		:= count;
            end if;
		end loop;

        -- signal if unlocked
        -- b2p_arb_unlock      <= '0';
        -- for i in 0 to N_LANE-1 loop
        --     if (unsigned(code) = i and or_reduce(b2p_arb_gnt) = '1') then -- if granted this lane
        --         if (b2p_arb_req(i) = '0' and page_allocator_state /= WRITE_PAGE) then -- request from selected lane is de-asserted and caused not by allocator
        --             b2p_arb_unlock      <= '1';
        --         end if;
        --     end if;
        -- end loop;

        -- conn.
        -- > page RAM
        -- default
        page_ram_we                 <= '0';
        page_ram_wr_addr            <= (others => '0');
        page_ram_wr_data            <= (others => '0');
        -- priority 1 : granted block mover if selected
        for i in 0 to N_LANE-1 loop
            if (unsigned(code) = i and or_reduce(b2p_arb_gnt) = '1') then -- if granted this lane
                if block_mover(i).page_wreq then -- if request is been made
                    page_ram_we             <= '1';
                    page_ram_wr_addr        <= std_logic_vector(block_mover(i).page_wptr + block_mover(i).word_wr_cnt - 1); 
                    page_ram_wr_data        <= lane_fifos_rd_data(i);
                end if;
            end if;
        end loop;
        -- priority 0 : page allocator
        if (page_allocator_state = WRITE_PAGE) then 
            page_ram_we                 <= page_allocator.page_we;
            page_ram_wr_addr            <= page_allocator.page_waddr;
            page_ram_wr_data            <= page_allocator.page_wdata;
        end if;
    end process;


    -- Optional : 
    -- If the downstream IP can track the read pointer, the page ram should be expose to external with conduit. The read side is at the external IP's discretion.
    -- In that case, the frame table and frame tracker are not needed. 
    -- -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- -- @name            FRAME_TABLE
    -- -- @brief           record the write <=> {FIN TS CNT | READON} <=> read
    -- -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- proc_frame_table_pusher : process (i_clk)
    -- begin
    --     if rising_edge (i_clk) then 
            




    --     end if;


    -- end process;




    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            FRAME_TRACKER
    -- @brief           present frame to egress interface according the frame table
    -- ────────────────────────────────────────────────────────────────────────────────────────────────


    page_ram_rd_addr        <= (others => '0'); -- TODO: connect this to external or frame tracker
    aso_egress_data         <= page_ram_rd_data(35 downto 0);        
   

    


end architecture rtl;



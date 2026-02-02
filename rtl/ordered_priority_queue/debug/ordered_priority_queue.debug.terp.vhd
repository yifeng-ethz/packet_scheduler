-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             ordered_priority_queue
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            1.0 - file created - July 2, 2025
-- Revision:            2.0 - all modules before frame table fully verified - Dec 11, 2025
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
--                      https://asciiflow.com/#/share/eJztm0Fv2zYUgP8KoXNtb0mLZQF2SNEZDbBiqRtgB3sYVItzhCiyQclZiiBAEfTYgw9G5kOOOeaY05Bfk18ySZYtUSSlR4qSrSAPSiLJ5OP7Hh8p8lm5NFzzDBv7hjc8wdbUweQv0xvatvHKcMwvmASfXA6Mc0w8e%2BwOjP2dVwPjIvi7txeefQnv7O0GZz6%2B8IOLgYF0y9P8%2B9P8a43HTIPRg4GrQQstT%2FNrWLFbTRjVQujo11miFOidXKka%2BBq9w96Q2BN%2FTDglmoOBWsj3%2Bq9%2F2v%2FhT7ZEozA83yQ%2BMi2LoP7PIU4zMRzsjvyTJQFdoikYc6UJ4D51vkiUbj9wwWcgCPAMyn8UVA0I6LjM78e0qUAXXOdcrqW2vlwZHf883TzSHoEjHZkjLGwGFSLBYgOyRpB7Tt%2F8J3BF%2FKMwxoVHpwM0SU%2BU0NWiZRbAf3EtSLQgtVg5cJzx0AyXFGXADt0RwZ4XXYGmTw5Ybkc8CH4vFJCFl2sJkPXGUjaKSripoDTABdyH5T1zZ8GtDgrzI5N4mMSYt7B5pMOxnI9%2FbA9PsY%2B6h93f5fFpzQKRHMt0X8YXHV4bFfQn16asFALNeRGQDQgOZifZMoKHxqLYXqqVWlwgGhfiQRE1t2xT1DIz3chuWmcpRfW4IS0XOymla%2B%2Fc5bTBmV%2BPzGi0%2FoIu6QJQpNjDN485zZZZo0n2YLRhskzf7O%2F%2BSO34JIE4ylNSYsk5CERhUM7yaU%2F7u1tJu8QFz7QxER5P%2BvFeV4VI5No7oY0lNhAhoCyfVxXfe9O1HJx99JbbIKVmmRSECO3E9hEmpK8YjLV2Hc8AEdoVukA7b97Q5dAzQAOmZtarj0VKHwxc1AJ%2FAVsTOK9IclH%2FsxzemGBPds%2Bcs3e%2BqmRh6NYFUts4TBu9XOEpZGHoVgSiHUkmCRpmWri48TVYUdEBTLMkQbNc6dXktNhzxVGAJGMg3hyop9FqzK8%2BMOfsneyMCncBLO210a88ZVDeOuPhKcrL4NSB8pvpMqswBESZL8d%2FfhIjkWpwIPkGjccCEAzLEh%2FG52HmaumQwtRV3rCuwnFI9auucs6DOC51xfd1cLcSlwCF2WbQopICS1WuHG2VYf84xVMsWVc6tZWqudE%2BkxFe%2FzbIfJ4Aza%2F9HadqD%2BiK8ZkdC1hXw3YeG5AX89elntVwpA%2BZ9wJ1ulRb3MipekHIlNL3ZkgpU1aiGw6y4BfkU7sEY%2FRpYg5xSifYWZvFzqzfi7W2%2BaUBqVBWqoDpEvMMF9bjw2Tqbh4GVq8hPXNsfnYUe%2BaYhF8lky2CydYr8eifNaIH4ftIrtZ0SjCFCda6HQ%2FvNvdudOffbyt7HynD20gk24aknPK6y6hSNWwlNfReh5EweZX0YXwEVXrv0NFxT9WAlUghiecS7upKDjJTrEhdkUiCXWdv5bWtNTSDfrTw5%2BkIHXa6VeMys1qccz%2FovS1Fwybv4b3dQgSfmbZruyM0iV7M8qrBTyxizgQFaBAd01AL%2FW07TsvB59gRNlkkUrBSbyII%2B7DNSKYPLTKeTLAVvQszHE9dv1KsXIlb%2FaMXzY9txA1VMJB3Ym0JUGJdfPe2xUgm2Na9YpFthRAtyVbFWugfYvuYDqymQlDB1FQIKpiaBgFSVyQvEMJWEwjlL4UXGVVFTRZJtaA5st0AtET%2Fndc7%2BKBBFSt1AFSq6gVAqVWNqvQB1P%2BySm1H0VsxVTh0I1KT8b%2Bqv9%2BSIwPjyrj6H09bHRY%3D)
--                      https://asciiflow.com/#/share/eJztnE1v0zAYx7%2BKlWM0xl6g7XbmwIHTLnCohMKajWhdU9LsjWkSmjhy6KEa%2FRCcECfEp%2BknwUmTNnFsx3b81jV%2FRaU0sfOz%2FTTO86%2Bze2fkXfrOsTOOgjAK4ruPX678K9%2FZcYbenR%2FBHfd959qPJkE46jvHBzt95xb%2Be3TYge%2Fukk%2B6R%2FBd7N%2FG8D99B5C0mP1YzL7l25R4nAH1%2ByPivsXs8eRN8qqRp1Z04Fnaw7%2FS17lGqlrRsIFtffy8cCHtB30oVK06rg64fMWQtU1x1WI%2FbFKhok06PHfx8vC9PwE3wXAIbiJvXB0%2B2hekcADp2No62KvKduyWVG4KvMp%2F9iZgFMZgEntR7A8oGHu48%2B%2Bjxx7UNeWQ1JRX1SKvsU3puJimELV5o0KvfqbgKzbHVYv9sEmFijbp8NzF2YevPoR0aPH0e%2BOQIQgbsiUq9Jz9uPls%2BCd9zfKUTcB%2BhJPxBoVF%2BaqS5Sn2Yxe0HbBm8%2FYG2Gby9gbAJvP2BrFsYl58Trh1QBrzdvYbIf7byGmphjYFFy9eGiY46Sdpa5KAj2HKOr6IX3TWw7SLqBxrm5Pq5Q3J0l1sQ2xJv%2BG0E0zAWRidwvGY%2BDGIw3RY9p%2FXiPBH%2BbxUQ5tkixcvDVMSW3tJyA2CyakXDVbGFcCNe5LvGpF4km0s8RbNpkw7BVy42HzXiDixS%2FmuEXECY%2FJdI9qOvNWEWlhVagJr0MFohm3AwWgGbMzBaBbL2meRhrhP%2F6SRMEkU98T3BuBdeHoBTrzRuS%2BZiqBGXkuSE%2F38vr5aPP3VFBtqnReKvYDdN2U8yzTH2lb3ZZnrD2GIB6NzECXxvkz1sZGW%2FXBXTLZfJkJ9gVVZybm%2BcMxl6riVhnTdVUP2Cw3puvUNaeC%2BIDyIH5auSPGuw2AAwms%2FuomC2CcwWDwiaRztgE93YDIeBnESX8lHXXH3hWIxYPfNGc8yz%2BG31YGhRkJ9uJQKKLRnVCErnCGV%2FJ6tYUqXh6vVnpGJrcWekQms0Z7ZmtRbu1pYVWphUyk1k1RiKzGTVAIrNJNUxrKCOa%2FFXSnzvmQ6S6oW%2FaJekqKN26IyZzWt6%2Bavi1ax7I3J%2FkIv%2FdJNpEOqZVE7xEtbA%2BSOBlWI3UExJgSiKBNqHsF3XbdSIPsob0DPxTbgkNSAnlvbALJphPGMNmUE0nipmkU9NWbRmoC%2FLlrFsjcmAwu9tbDCBhIUk3tkGTKjobp8Y0ESwtMxxnHF3CMLsPncIwuARdwj49g8amFVqYWVIqozYzM21pmxGZjizNiLjZ25W1xpSpwZxJaRbDBoW4zD6d1w3FHz5zCcS3GQMxb8E8Z2MwExOR2sx2E6keCIdJadWJM7Y5LnvPsFhKwQ2cVm9BwRkJXouCj8Ecm6yEv2qm4JUb2yjVKovwCfMZTg6ctnLO%2F5NEaqLshRExeE7TgcfcHzYGwvExCTO8F6HOa7Rx8QGr%2FWJ4vQce8yPwGFq0SLJLgYeoEzieIafrJIHNvQk0XiwEafLLL5prSiFlaVWlhVMgfbaLGLSWyhxS4mgRssdjEZywKz5ObhLnOIGw%2FeX0Zh%2Blc2JIu0mkXgQa%2F8wYE93E6xexpN61jENhZPSNoPnmJLUIAyG4a8r64bCAZLj7EbkL8ass7M2ZpHcBBIp5Y4fjn4%2Fp5bBGe1VhLinlsETytiAX%2FrRV9hagrCM%2BDfxpF%2F6cPuh31vfY8nQUKkqgcXWewBlJkn5H113UA7NftVVblHwu7lcdeoSqiT06s6ePjprK4%2BxZJyI6PfI5GErc8jkQSs2yPpOw%2FOw39ET5RX)
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
--use ieee.math_real.max;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
use std.textio.all;
use ieee.std_logic_textio.all;
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
        N_LANE                  : natural := 2; -- number of ingress lanes, e.g., 4 for x4
        MODE                    : string := "MERGING"; -- {MULTIPLEXING MERGING} multiplexing: ingress flows ts are interleaved; merging: ingress flows ts are sequenced and consistent
        TRACK_HEADER            : boolean := true; -- Select whether to track the header of ingress flow as the reference timestamp for each subheader packet.
        -- ingress format
        INGRESS_DATA_WIDTH      : natural := 32; -- default = 32
        INGRESS_DATAK_WIDTH     : natural := 4; -- default = 4
        CHANNEL_WIDTH           : natural := 2; -- width of logical channel, e.g., 2 bits for 4 channels
        -- IP advance
        LANE_FIFO_DEPTH         : natural := 1024; -- size of each lane FIFO in unit of its data width. Affects the max delay skew between each lane supported and maximum waiting time for the <b>page allocator</b>
        LANE_FIFO_WIDTH         : natural := 40; -- data width of each lane FIFO in unit of bits, must be larger than total(39) = data(32)+datak(4)+eop(1)+sop(1)+err(1)
        TICKET_FIFO_DEPTH       : natural := 256; -- size of each ticket FIFO in unit of its data width, set accordingly to the expected latency / max delay it allows. If too many empty subframes, the credit can be consumed quickly. Should be larger than N_SHD to absorb the burst per frame.
        HANDLE_FIFO_DEPTH       : natural := 64; -- size of each handle FIFO in unit of its data width, set accordingly to the expected latency / max delay it allows. Drop means blk mover too slow
        PAGE_RAM_DEPTH          : natural := 65536; -- size of the page RAM in unit of its WR data width, need to be larger than the full header packet, which is usually 65k max for each FEB flow
        PAGE_RAM_RD_WIDTH       : natural := 36; -- RD data width of the page RAM in unit of bits, write width = LANE_FIFO_WIDTH, read width can be larger to interface with PCIe DMA
        -- packet format (packet = subheader packet; w/o sop/eop; frame = header packet, w/ sop/eop)
        N_SHD                   : natural := 128; -- number of subheader, e.g., 256, more than 256 will be dropped. each subframe is 16 cycles
        N_HIT                   : natural := 255; -- number of hits per subheader, e.g., 255, more than 255 will be dropped
        HDR_SIZE                : natural := 5; -- size of header in words, e.g., 5 words
        SHD_SIZE                : natural := 1; -- size of subheader in words, e.g., 1 word
        HIT_SIZE                : natural := 1; -- size of hit in words, e.g., 1 word
        TRL_SIZE                : natural := 1; -- size of trailer in words, e.g., 1 word
        FRAME_SERIAL_SIZE       : natural := 16; -- size of frame serial number in bits, e.g., 16 bits
        FRAME_SUBH_CNT_SIZE     : natural := 16; -- size of frame subheader count in bits, e.g., 16 bits
        FRAME_HIT_CNT_SIZE      : natural := 16; -- size of frame hit count in bits, e.g., 16 bits

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
    --                  FUNCTION
    -- ───────────────────────────────────────────────────────────────────────────────────────
    function max(a, b : integer) return integer is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function;

    function min(a, b : integer) return integer is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;

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
    constant MAX_PKT_LENGTH         : natural := HIT_SIZE * N_HIT; -- default is 255, max length of packet to be allocated and in the lane FIFO as a whole, this does not include subheader as it will be in the ticket FIFO
    constant MAX_PKT_LENGTH_BITS    : natural := integer(ceil(log2(real(MAX_PKT_LENGTH)))); -- default is 8 bits
    -- The subheader hit-count field on the wire is 8-bit, but internally we size lengths by
    -- MAX_PKT_LENGTH_BITS. Clamp the incoming value to the representable (and configured) limit
    -- so a lane declaring >N_HIT can be safely trimmed/dropped.
    constant N_HIT_SAT             : natural := min(integer(N_HIT), 2**MAX_PKT_LENGTH_BITS - 1);
    constant MIN_PKT_LENGTH         : natural := HDR_SIZE + SHD_SIZE*N_SHD + TRL_SIZE; -- assumption: no hit but all subheaders
    constant FIFO_RAW_DELAY         : natural := 2; -- Read-After-Write. note: need to delay read for 2 cycles after write (2 for RDW="old data", 1 for RDW="new data", YW: check this?)
    constant FIFO_RD_DELAY          : natural := 1; -- once the rptr is changed, typical q is delay by 1 cycle
    constant SUBFRAME_DURATION_CYCLES : natural := 16;
    constant FRAME_DURATION_CYCLES  : natural := N_SHD * SUBFRAME_DURATION_CYCLES; -- ex: 16 us frame (n_shr=128)
    constant EGRESS_DELAY           : natural := 3; -- 3 **additional cycles** of delay wait for address to set on the page ram complex and data to be valid, so address change |-> 4 cycles data valid

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  TICKET_FIFO
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant TICKET_FIFO_DATA_WIDTH : natural :=
    max(48 + integer(ceil(log2(real(LANE_FIFO_DEPTH)))) + integer(ceil(log2(real(MAX_PKT_LENGTH)))) + 2,
        FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2); -- 48 for ts, 10 for start address, 8 for length of that block associated with this ticket, 2 for frame boundary alert
                                                                           -- OR serial(16) + subh cnt(16) + hit cnt(16) + 2 for frame sop ticket
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
    --                  ARB
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant QUANTUM_PER_SUBFRAME   : unsigned(9 downto 0) := to_unsigned(256,10);
    constant QUANTUM_MAX            : unsigned(9 downto 0) := to_unsigned(2**10-1,10);

    -- FEB pkt, with N_LANE flows, input will be parsed into frames L3 (network layer), near egress we call frame again as pkt as they are ready for L4 (transport layer)
    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  FRAME TABLE
    -- ───────────────────────────────────────────────────────────────────────────────────────
    constant N_TILE                     : natural := 5; -- total number of tiles, only one will be read segment
    constant N_WR_SEG                   : natural := N_TILE - 1; -- other 4 are write segments
    constant TILE_ID_WIDTH              : natural := integer(ceil(log2(real(N_TILE))));
    constant MAX_NPKT_IN_ONE_PAGE       : real := real(PAGE_RAM_DEPTH) / real(MIN_PKT_LENGTH);
    constant TILE_PKT_CNT_WIDTH         : natural := integer(ceil(log2(MAX_NPKT_IN_ONE_PAGE)));

    -- ───────────────────────────────────────────────────────────────────────────────────────
    --                  DATA STRUCT FORMAT
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- handle = {src[9:0], dst[15:0], blk_len(length)[7:0]}
    -- bitmap
    constant HANDLE_LENGTH                  : natural := LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS; -- TODO: currently, missing one bit flag
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

    -- shr ticket = {alert_sop_eop[1:0] ... ts[47:0], start addr[9:0], length[9:0]}
    -- bitmap
    constant TICKET_LENGTH                  : natural := TICKET_FIFO_DATA_WIDTH;
    constant TICKET_TS_LO                   : natural := 0;
    constant TICKET_TS_HI                   : natural := 47;
    constant TICKET_LANE_RD_OFST_LO         : natural := 48;
    constant TICKET_LANE_RD_OFST_HI         : natural := 48+LANE_FIFO_ADDR_WIDTH - 1;
    constant TICKET_BLOCK_LEN_LO            : natural := 48+LANE_FIFO_ADDR_WIDTH;
    constant TICKET_BLOCK_LEN_HI            : natural := 48+LANE_FIFO_ADDR_WIDTH + MAX_PKT_LENGTH_BITS-1;
    -- sop ticket = {alert_sop_eop[1:0] ... serial[15:0], n_subh[15:0], n_hit[15:0]}
    -- bitmap
    constant TICKET_SERIAL_LO               : natural := 0;
    constant TICKET_SERIAL_HI               : natural := FRAME_SERIAL_SIZE-1;
    constant TICKET_N_SUBH_LO               : natural := FRAME_SERIAL_SIZE;
    constant TICKET_N_SUBH_HI               : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE-1;
    constant TICKET_N_HIT_LO                : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
    constant TICKET_N_HIT_HI                : natural := FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE-1;
    -- flags : fixed to the top bit
    constant TICKET_ALT_EOP_LOC             : natural := TICKET_LENGTH - 2; -- indicate eop (not used for now)
    constant TICKET_ALT_SOP_LOC             : natural := TICKET_LENGTH - 1; -- indicate sop (sop ticket for page allocator to pass info to ftable mapper)
    type ticket_t is record
        ticket_ts               : unsigned(47 downto 0);
        lane_fifo_rd_offset     : std_logic_vector(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        block_length            : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
        alert_eop               : std_logic;
        alert_sop               : std_logic;
    end record;
    constant TICKET_DEFAULT     : ticket_t := (
        ticket_ts               => (others => '0'),
        lane_fifo_rd_offset     => (others => '0'),
        block_length            => (others => '0'),
        alert_eop               => '0',
        alert_sop               => '0'

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
    -- component
    component page_ram
    generic (
        DATA_WIDTH      : natural := PAGE_RAM_DATA_WIDTH;
        ADDR_WIDTH      : natural := PAGE_RAM_ADDR_WIDTH
    );
    port (
        data            : in  std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
        read_addr       : in  std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        write_addr      : in  std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        we              : in  std_logic;
        clk             : in  std_logic;
        q               : out std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0)
    );
    end component;
    -- comb
    signal page_ram_we_comb         : std_logic;
    signal page_ram_wr_addr_comb    : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_ram_wr_data_comb    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    -- reg
    signal page_ram_we              : std_logic;
    signal page_ram_wr_addr         : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_ram_wr_data         : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal page_ram_rd_addr         : std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_ram_rd_data         : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);

    -- ────────────────────────────────────────────────
    -- page tile
    -- ────────────────────────────────────────────────
    -- reg
    type page_ram_data_t is array (0 to N_TILE-1) of std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    type page_ram_addr_t is array (0 to N_TILE-1) of std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_tile_wr_data        : page_ram_data_t;
    signal page_tile_rd_data        : page_ram_data_t;
    signal page_tile_rd_data_reg    : page_ram_data_t;
    signal page_tile_wr_addr        : page_ram_addr_t;
    signal page_tile_rd_addr        : page_ram_addr_t;
    signal page_tile_we             : std_logic_vector(N_TILE-1 downto 0);

    -- ────────────────────────────────────────────────
    -- tile fifo
    -- ────────────────────────────────────────────────
    constant TILE_FIFO_ADDR_WIDTH   : natural := 9; -- default to 512, no overflow is expected
    constant TILE_FIFO_DATA_WIDTH   : natural := 2*PAGE_RAM_ADDR_WIDTH; -- we store meta info = {length, start_address} into this tile fifo as data
    constant TILE_FIFO_DEPTH        : natural := TILE_FIFO_ADDR_WIDTH**2;
    component tile_fifo
    generic (
        DATA_WIDTH      : natural := TILE_FIFO_DATA_WIDTH;
        ADDR_WIDTH      : natural := TILE_FIFO_ADDR_WIDTH
    );
    port (
        data            : in  std_logic_vector(TILE_FIFO_DATA_WIDTH-1 downto 0);
        read_addr       : in  std_logic_vector(TILE_FIFO_ADDR_WIDTH-1 downto 0);
        write_addr      : in  std_logic_vector(TILE_FIFO_ADDR_WIDTH-1 downto 0);
        we              : in  std_logic;
        clk             : in  std_logic;
        q               : out std_logic_vector(TILE_FIFO_DATA_WIDTH-1 downto 0)
    );
    end component;
    type tile_fifos_data_t is array (0 to N_TILE-1) of std_logic_vector(TILE_FIFO_DATA_WIDTH-1 downto 0);
    type tile_fifos_addr_t is array (0 to N_TILE-1) of std_logic_vector(TILE_FIFO_ADDR_WIDTH-1 downto 0);
    signal tile_fifos_wr_data       : tile_fifos_data_t;
    signal tile_fifos_rd_data       : tile_fifos_data_t;
    signal tile_fifos_wr_addr       : tile_fifos_addr_t;
    signal tile_fifos_rd_addr       : tile_fifos_addr_t;
    signal tile_fifos_we            : std_logic_vector(N_TILE-1 downto 0);

    -- ────────────────────────────────────────────────
    -- ingress parser
    -- ────────────────────────────────────────────────
    -- state
    subtype update_header_ts_flow_t is integer range 0 to 3;
    type update_header_tss_flow_t is array (0 to N_LANE-1) of update_header_ts_flow_t;
    signal update_header_ts_flow            : update_header_tss_flow_t;
    type ingress_parser_state_t is (IDLE, UPDATE_HEADER_TS, MASK_PKT_EXTENDED, MASK_PKT, WR_HITS, RESET);
    type ingress_parsers_state_t is array (0 to N_LANE-1) of ingress_parser_state_t;
    signal ingress_parser_state             : ingress_parsers_state_t;

    -- register
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
        shd_len_raw                     : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0); -- raw hit count from subheader field
        shd_len                         : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
        shd_rx_cnt                      : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0); -- hit words consumed for this subheader
        shd_trim_drop                   : std_logic; -- when '1', drop hits beyond shd_len
        dt_type                         : std_logic_vector(5 downto 0); -- 6 bits, unique for each subdetector
        feb_id                          : std_logic_vector(15 downto 0); -- 16 bits, unique for feb under each subdetector. combined to get the flow id.
        lane_start_addr                 : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0); -- start address of the lane FIFO for this packet, used to detect if the packet is with declared length
        pkg_cnt                         : std_logic_vector(15 downto 0); -- 16 bits, running package index
        running_shd_cnt                 : std_logic_vector(15 downto 0); -- 16 bits, running header index
        hit_cnt                         : unsigned(15 downto 0); -- 15 bits, number of hits under this header package
        send_ts                         : std_logic_vector(30 downto 0); -- 31 bits, timestamp of this package departing at the upstream port, used to calculate package header delay
        alert_sop                       : std_logic;
        alert_eop                       : std_logic;
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
        shd_len_raw     => (others => '0'),
        shd_len         => (others => '0'),
        shd_rx_cnt      => (others => '0'),
        shd_trim_drop   => '0',
        dt_type         => (others => '0'),
        feb_id          => (others => '0'),
        lane_start_addr => (others => '0'),
        pkg_cnt         => (others => '0'),
        running_shd_cnt => (others => '0'),
        hit_cnt         => (others => '0'),
        send_ts         => (others => '0'),
        alert_sop       => '0',
        alert_eop       => '0',
        error_lane_wr_early_term => '0'
    );

    type ingress_parsers_reg_t is array (0 to N_LANE-1) of ingress_parser_reg_t;
    signal ingress_parser           : ingress_parsers_reg_t;

    -- combinational wire
    signal ingress_parser_is_subheader      : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a subheader
    signal ingress_parser_is_preamble       : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a preamble
    signal ingress_parser_is_trailer        : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data is a trailer
    signal ingress_parser_hit_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has hit error
    signal ingress_parser_shd_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has subheader error
    signal ingress_parser_hdr_err           : std_logic_vector(N_LANE-1 downto 0); -- indicates if the ingress data has header error
    type ingress_parser_if_subheader_hit_cnt_t is array (0 to N_LANE-1) of unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
    signal ingress_parser_if_subheader_hit_cnt  : ingress_parser_if_subheader_hit_cnt_t; -- hit count of the subheader, 8 bits
    signal ingress_parser_if_subheader_hit_cnt_raw  : ingress_parser_if_subheader_hit_cnt_t; -- raw hit count from subheader field (before clamp)
    type ingress_parser_if_subheader_shd_ts_t is array (0 to N_LANE-1) of std_logic_vector(7 downto 0);
    signal ingress_parser_if_subheader_shd_ts   : ingress_parser_if_subheader_shd_ts_t; -- subheader timestamp, 8 bits
    type ingress_parser_if_preamble_dt_type_t is array (0 to N_LANE-1) of std_logic_vector(5 downto 0);
    signal ingress_parser_if_preamble_dt_type   : ingress_parser_if_preamble_dt_type_t; -- preamble data type, 6 bits
    type ingress_parser_if_preamble_feb_id_t is array (0 to N_LANE-1) of std_logic_vector(15 downto 0);
    signal ingress_parser_if_preamble_feb_id    : ingress_parser_if_preamble_feb_id_t; -- preamble feb id, 16 bits
    type ingress_parser_if_write_ticket_data_t is array (0 to N_LANE-1) of std_logic_vector(TICKET_FIFO_DATA_WIDTH-1 downto 0); -- ticket = {ts[47:0], start addr[9:0], length[9:0], alert_sop_eop[1:0]}
    signal ingress_parser_if_write_ticket_data  : ingress_parser_if_write_ticket_data_t;
    type ingress_parser_if_write_lane_data_t is array (0 to N_LANE-1) of std_logic_vector(LANE_FIFO_DATA_WIDTH-1 downto 0);
    signal ingress_parser_if_write_lane_data    : ingress_parser_if_write_lane_data_t;

    -- ────────────────────────────────────────────────
    -- page allocator
    -- ────────────────────────────────────────────────
    -- constant
    constant MAX_SHR_CNT_BITS               : natural := integer(ceil(log2(real(N_SHD*N_LANE)))) + 1; -- note: Nth bit + 1 = bit length, count for all lanes summed
    constant MAX_HIT_CNT_BITS               : natural := min(integer(ceil(log2(real(N_SHD*N_HIT)))) + 1, 16); -- count for all lanes summed (limited to 16 bits)
    -- state
    type page_allocator_state_t is (IDLE, FETCH_TICKET, WRITE_HEAD, WRITE_TAIL, ALLOC_PAGE, WRITE_PAGE, RESET);
    signal page_allocator_state             : page_allocator_state_t;
    subtype alloc_page_flow_t is integer range 0 to N_LANE-1;
    subtype write_meta_flow_t is integer range 0 to 5;

    -- register
    type ticket_credit_update_t is array (0 to N_LANE-1) of unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);
    type handle_wflag_t is array (0 to N_LANE-1) of std_logic;
    type handle_wptr_t is array (0 to N_LANE-1) of unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
    type tickets_t is array (0 to N_LANE-1) of ticket_t;
    type ticket_rptr_t is array (0 to N_LANE-1) of unsigned(TICKET_FIFO_ADDR_WIDTH-1 downto 0);

    type page_allocator_reg_t is record
        -- ticket
        ticket_rptr                         : ticket_rptr_t;
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
        -- frame
        frame_start_addr                    : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        frame_start_addr_last               : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        frame_cnt                           : unsigned(35 downto 0); -- if no loss, equal to ts[47:12]
        frame_serial                        : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
        frame_serial_this                   : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
        frame_shr_cnt                       : unsigned(MAX_SHR_CNT_BITS-1 downto 0); -- max = N_SHR * N_LANE
        frame_shr_cnt_this                  : unsigned(MAX_SHR_CNT_BITS-1 downto 0);
        frame_hit_cnt                       : unsigned(MAX_HIT_CNT_BITS-1 downto 0); -- max = N_SHR * N_HIT
        frame_hit_cnt_this                  : unsigned(MAX_HIT_CNT_BITS-1 downto 0);
        frame_ts                            : unsigned(47 downto 0);
        -- When the allocator has to skip subheader time ticks (no timely tickets), the frame is incomplete.
        -- Mark it invalid so the mapper/tracker can drop it instead of presenting a broken packet.
        frame_invalid                       : std_logic;
        frame_invalid_last                  : std_logic;
        -- internal
        running_ts                          : unsigned(47 downto 0);
        lane_masked                         : std_logic_vector(N_LANE-1 downto 0);
        lane_skipped                        : std_logic_vector(N_LANE-1 downto 0);
        ticket                              : tickets_t;
        page_start_addr                     : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        page_length                         : unsigned(MAX_PKT_LENGTH_BITS+CHANNEL_WIDTH-1 downto 0); -- hint: max = N_LANE * max block length
        alloc_page_flow                     : alloc_page_flow_t; -- flow need to iterate all lanes
        write_meta_flow                     : write_meta_flow_t; -- flow to write header and trailer
        write_meta_flow_d1                  : write_meta_flow_t;
        write_trailer                       : std_logic;
        reset_done                          : std_logic;
    end record;

    constant PAGE_ALLOCATOR_REG_RESET   : page_allocator_reg_t := (
        -- ticket
        ticket_rptr                 => (others => (others => '0')),
        ticket_credit_update        => (others => (others => '0')),
        ticket_credit_update_valid  => (others => '0'),
        -- handle
        handle_we                   => (others => '0'),
        handle_wflag                => (others => '0'),
        handle_wptr                 => (others => (others => '0')),
        -- page
        page_we                     => '0',
        page_wdata                  => (others => '0'),
        page_waddr                  => (others => '0'),
        -- frame
        frame_start_addr            => (others => '0'),
        frame_start_addr_last       => (others => '0'),
        frame_cnt                   => (others => '0'),
        frame_serial                => (others => '0'),
        frame_serial_this           => (others => '0'),
        frame_shr_cnt               => (others => '0'),
        frame_shr_cnt_this          => (others => '0'),
        frame_hit_cnt               => (others => '0'),
        frame_hit_cnt_this          => (others => '0'),
        frame_ts                    => (others => '0'),
        frame_invalid               => '0',
        frame_invalid_last          => '0',
        -- internal
        running_ts                  => (others => '0'),
        lane_masked                 => (others => '0'),
        lane_skipped                => (others => '0'),
        ticket                      => (others => TICKET_DEFAULT),
        page_start_addr             => (others => '0'),
        page_length                 => (others => '0'),
        alloc_page_flow             => 0,
        write_meta_flow             => 0,
        write_meta_flow_d1          => 0,
        write_trailer               => '0',
        reset_done                  => '0'
    );

    signal page_allocator           : page_allocator_reg_t;

    type page_allocator_is_pending_ticket_d_t is array (0 to N_LANE-1) of std_logic_vector(FIFO_RAW_DELAY downto 1);
    signal page_allocator_is_pending_ticket_d   : page_allocator_is_pending_ticket_d_t;

    -- combinational wire
    -- ticket
    type page_allocator_if_read_ticket_ticket_t is array (0 to N_LANE-1) of ticket_t;
    signal page_allocator_if_read_ticket_ticket : page_allocator_if_read_ticket_ticket_t;
    type page_allocator_if_read_ticket_ticket_sop_t is record
        serial                                  : unsigned(FRAME_SERIAL_SIZE-1 downto 0);
        n_subh                                  : unsigned(MAX_SHR_CNT_BITS-1 downto 0);
        n_hit                                   : unsigned(MAX_HIT_CNT_BITS-1 downto 0);
    end record;
    signal page_allocator_if_read_ticket_ticket_sop     : page_allocator_if_read_ticket_ticket_sop_t;
    signal page_allocator_is_tk_sop             : std_logic_vector(N_LANE-1 downto 0);
    signal page_allocator_is_tk_future          : std_logic_vector(N_LANE-1 downto 0);
    signal page_allocator_is_tk_past            : std_logic_vector(N_LANE-1 downto 0);
    type page_allocator_if_alloc_blk_start_t is array (0 to N_LANE-1) of std_logic_vector(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal page_allocator_if_alloc_blk_start    : page_allocator_if_alloc_blk_start_t;
    signal page_allocator_is_pending_ticket     : std_logic_vector(N_LANE-1 downto 0); -- asserted when rd/wr pointers mismatch
    signal page_allocator_is_pending_ticket_lane    : std_logic_vector(N_LANE-1 downto 0);
    -- handle
    type page_allocator_if_write_handle_data_t is array (0 to N_LANE-1) of std_logic_vector(HANDLE_LENGTH-1 downto 0);
    signal page_allocator_if_write_handle_data  : page_allocator_if_write_handle_data_t;
    -- page
    signal page_allocator_if_write_page_shr_data    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal page_allocator_if_write_page_hdr_data    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal page_allocator_if_write_page_trl_data    : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);


    -- ────────────────────────────────────────────────
    -- block mover
    -- ────────────────────────────────────────────────
    -- state signals
    type block_mover_state_t is (IDLE, PREP, WRITE_BLK, ABORT_WRITE_BLK, RESET);
    type block_movers_state_t is array (0 to N_LANE-1) of block_mover_state_t;
    signal block_mover_state             : block_movers_state_t;

    -- types
    type handle_fifo_is_pending_handle_d_t is array (0 to N_LANE-1) of std_logic_vector(FIFO_RAW_DELAY downto 1);
    signal handle_fifo_is_pending_handle_d      : handle_fifo_is_pending_handle_d_t;

    type block_mover_handle_rptr_d_t is array (1 to FIFO_RD_DELAY) of unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
    constant BLOCK_MOVER_HANDLE_RPTR_D_RESET    : block_mover_handle_rptr_d_t := (
        others => (others => '0')
    );

    -- registers
    type block_mover_t is record
        word_wr_cnt                         : unsigned(MAX_PKT_LENGTH_BITS-1 downto 0);
        handle                              : handle_t;
        flag                                : std_logic; -- flag = {skip_blk}
        handle_rptr                         : unsigned(HANDLE_FIFO_ADDR_WIDTH-1 downto 0);
        handle_rptr_d                       : block_mover_handle_rptr_d_t;
        page_wptr                           : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        page_wreq                           : std_logic;
        lane_credit_update                  : unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
        lane_credit_update_valid            : std_logic;
        reset_done                          : std_logic;
    end record;

    constant BLOCK_MOVER_REG_RESET      : block_mover_t := (
        word_wr_cnt                 => (others => '0'),
        handle                      => HANDLE_REG_RESET,
        flag                        => '0',
        handle_rptr                 => (others => '0'),
        handle_rptr_d               => BLOCK_MOVER_HANDLE_RPTR_D_RESET,
        page_wptr                   => (others => '0'),
        page_wreq                   => '0',
        lane_credit_update          => (others => '0'),
        lane_credit_update_valid    => '0',
        reset_done                  => '0'
    );

    type block_movers_t is array (0 to N_LANE-1) of block_mover_t;
    signal block_mover              : block_movers_t;

    -- combinational wires
    signal handle_fifo_is_pending_handle        : std_logic_vector(N_LANE-1 downto 0);
    signal handle_fifo_is_pending_handle_valid  : std_logic_vector(N_LANE-1 downto 0);
    signal handle_fifo_is_q_valid               : std_logic_vector(N_LANE-1 downto 0);
    type handle_fifo_if_rd_t is record
        handle              : handle_t;
        flag                : std_logic;
    end record;
    type handle_fifos_if_rd_t is array (0 to N_LANE-1) of handle_fifo_if_rd_t;
    signal handle_fifo_if_rd                    : handle_fifos_if_rd_t;
    signal lane_fifo_if_rd_eop                  : std_logic_vector(N_LANE-1 downto 0);
    type block_mover_if_move_lane_rptr_t is array (0 to N_LANE-1) of unsigned(LANE_FIFO_ADDR_WIDTH-1 downto 0);
    signal block_mover_if_move_lane_rptr        : block_mover_if_move_lane_rptr_t;
    type block_mover_if_write_page_data_t is array (0 to N_LANE-1) of std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
    signal block_mover_if_write_page_data       : block_mover_if_write_page_data_t;

    -- ────────────────────────────────────────────────
    -- arbiter
    -- ────────────────────────────────────────────────
    -- state
    type arbiter_state_t is (IDLE, LOCKING, LOCKED, RESET);
    signal arbiter_state                : arbiter_state_t;

    -- type
    type b2p_arb_quantum_t is array (0 to N_LANE-1) of unsigned(9 downto 0);

    -- register
    type b2p_arb_t is record
        sel_mask                        : std_logic_vector(N_LANE-1 downto 0);
        priority                        : std_logic_vector(N_LANE-1 downto 0);
        quantum                         : b2p_arb_quantum_t;
    end record;

    constant B2P_ARB_REG_RESET          : b2p_arb_t := (
        sel_mask                => (others => '0'),
        priority                => (0 => '1', others => '0'), -- note: need to put initial priority to first lane
        quantum                 => (others => QUANTUM_PER_SUBFRAME)
    );

    signal b2p_arb              : b2p_arb_t;

    -- comb
    signal b2p_arb_req                          : std_logic_vector(N_LANE-1 downto 0);
    signal b2p_arb_gnt                          : std_logic_vector(N_LANE-1 downto 0);
    signal b2p_arb_quantum_update_if_updating   : b2p_arb_quantum_t;

    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- frame table mapper
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- state
    type ftable_mapper_state_t is (IDLE, PREP_UPDATE, UPDATE_FRAME_TABLE, MODIFY_FRAME_TABLE, RESET);
    signal ftable_mapper_state                  : ftable_mapper_state_t;

    -- type
    type wseg_t is record
        tile_index                      : unsigned(TILE_ID_WIDTH-1 downto 0);
    end record;
    type wsegs_t is array (0 to N_WR_SEG-1) of wseg_t;
    type wtile_pipe_t is array (0 to 1) of unsigned(TILE_ID_WIDTH-1 downto 0);
    type update_ftable_tindex_t is array (0 to 1) of unsigned(TILE_ID_WIDTH-1 downto 0);
    type update_ftable_meta_t is array (0 to 1) of std_logic_vector(2*PAGE_RAM_ADDR_WIDTH-1 downto 0);
    type update_ftable_trltl_t is array (0 to 1) of unsigned(TILE_ID_WIDTH-1 downto 0);
    type update_ftable_bdytl_t is array (0 to 1) of unsigned(TILE_ID_WIDTH-1 downto 0);
    type last_pkt_dbg_tile_index_t is array (0 to 2) of unsigned(TILE_ID_WIDTH-1 downto 0);
    type last_pkt_dbg_tile_index_pipe_t is array (0 to 1) of last_pkt_dbg_tile_index_t;

    type ftable_mapper_t is record
        new_frame_raw_addr              : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
        frame_shr_cnt                   : unsigned(MAX_SHR_CNT_BITS-1 downto 0);
        frame_hit_cnt                   : unsigned(MAX_HIT_CNT_BITS-1 downto 0);
        wseg                            : wsegs_t;
        wseg_last_tile_pipe             : wtile_pipe_t;
        leading_wseg                    : unsigned(TILE_ID_WIDTH-1 downto 0);
        update_ftable_valid             : std_logic_vector(1 downto 0);
        update_ftable_tindex            : update_ftable_tindex_t;
        update_ftable_meta_valid        : std_logic_vector(1 downto 0);
        update_ftable_meta              : update_ftable_meta_t;
        update_ftable_trltl_valid       : std_logic_vector(1 downto 0);
        update_ftable_trltl             : update_ftable_trltl_t;
        update_ftable_bdytl_valid       : std_logic_vector(1 downto 0);
        update_ftable_bdytl             : update_ftable_bdytl_t;
        update_ftable_hcmpl             : std_logic_vector(1 downto 0);
        flush_ftable_valid              : std_logic_vector(1 downto 0);
        mgmt_tiles_start                : std_logic;
        last_pkt_dbg_tile_index         : last_pkt_dbg_tile_index_pipe_t;
        -- A packet is only safe to present once all block-mover writes for that frame are complete.
        -- We snapshot the end handle pointers at the frame boundary (WRITE_TAIL flow=3) and delay
        -- tile_pkt_wcnt increment until each lane's handle_rptr catches up to the snapshot.
        pending_pkt_valid               : std_logic;
        pending_pkt_tindex              : unsigned(TILE_ID_WIDTH-1 downto 0);
        pending_pkt_meta                : std_logic_vector(2*PAGE_RAM_ADDR_WIDTH-1 downto 0);
        pending_pkt_drop                : std_logic;
        pending_pkt_handle_wptr         : handle_wptr_t;
    end record;

    -- reg
    constant WSEG_REG_RESET             : wseg_t := (
        tile_index                      => (others => '0')
    );
    -- Initialize the write segments away from the initial read segment (rseg=0).
    -- The model assumes "N_TILE-1 write segments + 1 read segment", so avoid starting with all
    -- write segments mapped onto tile 0 (which makes WR/RD share a tile immediately).
    constant FTABLE_MAPPER_REG_RESET    : ftable_mapper_t := (
        new_frame_raw_addr              => (others => '0'),
        frame_shr_cnt                   => (others => '0'),
        frame_hit_cnt                   => (others => '0'),
        wseg                            => (
            0 => (tile_index => to_unsigned(1 mod N_TILE, TILE_ID_WIDTH)),
            1 => (tile_index => to_unsigned(2 mod N_TILE, TILE_ID_WIDTH)),
            2 => (tile_index => to_unsigned(3 mod N_TILE, TILE_ID_WIDTH)),
            3 => (tile_index => to_unsigned(4 mod N_TILE, TILE_ID_WIDTH))
        ),
        wseg_last_tile_pipe             => (others => (others => '0')),
        leading_wseg                    => (others => '0'),
        update_ftable_valid             => (others => '0'),
        update_ftable_tindex            => (others => (others => '0')),
        update_ftable_meta_valid        => (others => '0'),
        update_ftable_meta              => (others => (others => '0')),
        update_ftable_trltl_valid       => (others => '0'),
        update_ftable_trltl             => (others => (others => '0')),
        update_ftable_bdytl_valid       => (others => '0'),
        update_ftable_bdytl             => (others => (others => '0')),
        update_ftable_hcmpl             => (others => '0'),
        flush_ftable_valid              => (others => '0'),
        mgmt_tiles_start                => '0',
        last_pkt_dbg_tile_index         => (others => (others => (others => '0'))),
        pending_pkt_valid               => '0',
        pending_pkt_tindex              => (others => '0'),
        pending_pkt_meta                => (others => '0'),
        pending_pkt_drop                => '0',
        pending_pkt_handle_wptr         => (others => (others => '0'))
    );
    signal ftable_mapper                : ftable_mapper_t;
    signal ftable_mapper_update_ftable_spill_reg    : std_logic;
    signal ftable_mapper_expand_wr_tile_index_reg   : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_update_ftable_fspan_reg    : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal ftable_mapper_leading_wr_tile_index_reg  : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_last_pkt_spilled           : std_logic;
    signal ftable_mapper_rd_tile_in_wr_seg          : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_expand_wr_tile_index_reg0  : natural range 0 to N_TILE-1;

    -- comb
    signal ftable_mapper_update_ftable_fspan        : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal ftable_mapper_update_ftable_spill        : std_logic;
    signal ftable_mapper_update_ftable_trail_span   : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal ftable_mapper_leading_wr_seg_index       : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_leading_wr_tile_index      : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_expand_wr_tile_index       : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_writing_tile_index         : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_mapper_expand_wr_tile_index_0     : natural range 0 to N_TILE-1;

    -- Guard: never write to a tile that is actively being read/presented.
    -- If this triggers, we sacrifice the write side by dropping the frame.
    signal ftable_wr_blocked_by_rd_lock             : std_logic;


    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- frame table tracker
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- state
    type ftable_tracker_state_t is (IDLE, RECORD_TILE, FLUSH_TILE, RESET);
    signal ftable_tracker_state                 : ftable_tracker_state_t;

    type tile_ptr_t is array (0 to N_TILE-1) of unsigned(TILE_FIFO_ADDR_WIDTH-1 downto 0);
    type tile_pkt_wcnt_t is array (0 to N_TILE-1) of unsigned(TILE_PKT_CNT_WIDTH-1 downto 0);

    -- type
    type ftable_tracker_t is record
        update_ftable_valid                     : std_logic_vector(1 downto 0);
        update_ftable_tindex                    : update_ftable_tindex_t;
        update_ftable_meta_valid                : std_logic_vector(1 downto 0);
        update_ftable_meta                      : update_ftable_meta_t;
        update_ftable_trltl_valid               : std_logic_vector(1 downto 0);
        update_ftable_trltl                     : update_ftable_trltl_t;
        update_ftable_bdytl_valid               : std_logic_vector(1 downto 0);
        update_ftable_bdytl                     : update_ftable_bdytl_t;
        update_ftable_hcmpl                     : std_logic_vector(1 downto 0);
        flush_ftable_valid                      : std_logic_vector(1 downto 0);
        tile_cmpl                               : std_logic_vector(N_TILE-1 downto 0);
        tile_we                                 : std_logic_vector(N_TILE-1 downto 0);
        tile_wptr                               : tile_ptr_t;
        tile_wdata                              : tile_fifos_data_t;
        tile_pkt_wcnt                           : tile_pkt_wcnt_t;
    end record;

    signal ftable_tracker                       : ftable_tracker_t;
    constant FTABLE_TRACKER_REG_RESET           : ftable_tracker_t := (
        update_ftable_valid                     => (others => '0'),
        update_ftable_tindex                    => (others => (others => '0')),
        update_ftable_meta_valid                => (others => '0'),
        update_ftable_meta                      => (others => (others => '0')),
        update_ftable_trltl_valid               => (others => '0'),
        update_ftable_trltl                     => (others => (others => '0')),
        update_ftable_bdytl_valid               => (others => '0'),
        update_ftable_bdytl                     => (others => (others => '0')),
        update_ftable_hcmpl                     => (others => '0'),
        flush_ftable_valid                      => (others => '0'),
        tile_cmpl                               => (others => '0'),
        tile_we                                 => (others => '0'),
        tile_wptr                               => (others => (others => '0')),
        tile_wdata                              => (others => (others => '0')),
        tile_pkt_wcnt                           => (others => (others => '0'))
    );

    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- tile regs
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- type
    type trail_tid_t is array (0 to N_TILE-1) of unsigned(TILE_ID_WIDTH downto 0); -- msb is valid
    type body_tid_t is array (0 to N_TILE-1) of unsigned(TILE_ID_WIDTH downto 0); -- msb is lock

    type tile_regs_t is record
        trail_tid                   : trail_tid_t;
        body_tid                    : body_tid_t;
        tile_cmpl                   : std_logic_vector(N_TILE-1 downto 0);
    end record;

    -- signal
    signal tile_regs                : tile_regs_t;
    constant TILE_REGS_REG_RESET    : tile_regs_t := (
        trail_tid                   => (others => (others => '0')),
        body_tid                    => (others => (others => '0')),
        tile_cmpl                   => (others => '0')
    );

    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- frame table presenter
    -- ───────────────────────────────────────────────────────────────────────────────────────
    -- state
    type ftable_presenter_state_t is (IDLE, WAIT_FOR_COMPLETE, VERIFY, PRESENTING, RESTART, WARPING, RESET);
    signal ftable_presenter_state                   : ftable_presenter_state_t;

    -- type
    type rseg_t is record
        tile_index                      : unsigned(TILE_ID_WIDTH-1 downto 0);
    end record;
    constant RSET_REG_RESET             : rseg_t := (
        tile_index                      => (others => '0')
    );

    type tile_rptr_t is array (0 to N_TILE-1) of unsigned(TILE_FIFO_ADDR_WIDTH-1 downto 0);
    type page_ram_rptr_t is array (0 to N_TILE-1) of unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    type tile_pkt_rcnt_t is array (0 to N_TILE-1) of unsigned(TILE_PKT_CNT_WIDTH-1 downto 0);

    type ftable_presenter_t is record
        rseg                            : rseg_t;
        tile_rptr                       : tile_rptr_t;
        page_ram_rptr                   : page_ram_rptr_t;
        output_data_valid               : std_logic_vector(EGRESS_DELAY downto 0);
        output_data                     : std_logic_vector(PAGE_RAM_DATA_WIDTH-1 downto 0);
        trailing_active                 : std_logic_vector(EGRESS_DELAY downto 0);
        void_trail_tid                  : std_logic;
        void_body_tid                   : std_logic;
        trailing_tile_index             : unsigned(TILE_ID_WIDTH-1 downto 0);
        tile_pkt_rcnt                   : tile_pkt_rcnt_t;
        crossing_trid                   : unsigned(TILE_ID_WIDTH-1 downto 0);
        crossing_trid_valid             : std_logic;
        pkt_rd_word_cnt                 : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    end record;

    constant FTABLE_PRESENTER_REG_RESET : ftable_presenter_t := (
        rseg                            => RSET_REG_RESET,
        tile_rptr                       => (others => (others => '0')),
        page_ram_rptr                   => (others => (others => '0')),
        output_data_valid               => (others => '0'),
        output_data                     => (others => '0'),
        trailing_active                 => (others => '0'),
        void_trail_tid                  => '0',
        void_body_tid                   => '0',
        trailing_tile_index             => (others => '0'),
        tile_pkt_rcnt                   => (others => (others => '0')),
        crossing_trid                   => (others => '0'),
        crossing_trid_valid             => '0',
        pkt_rd_word_cnt                 => (others => '0')
    );

    -- signal
    signal ftable_presenter             : ftable_presenter_t;

    -- comb
    signal ftable_presenter_is_new_pkt_head         : std_logic;
    signal ftable_presenter_is_new_pkt_complete     : std_logic;
    signal ftable_presenter_trail_tile_id           : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_presenter_is_rd_tile_in_range     : std_logic;
    signal ftable_presenter_output_is_trailer       : std_logic;
    signal ftable_presenter_leading_header_addr     : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal ftable_presenter_packet_length           : unsigned(PAGE_RAM_ADDR_WIDTH-1 downto 0);
    signal ftable_presenter_is_pkt_spilling         : std_logic;
    signal ftable_presenter_if_in_range_warp_wr_seg : unsigned(TILE_ID_WIDTH-1 downto 0);
    signal ftable_presenter_if_in_range_warp_rd_tile    : unsigned(TILE_ID_WIDTH-1 downto 0);



begin

    assert PAGE_RAM_ADDR_WIDTH = 16 report "PAGE RAM ADDR NON-DEFAULT (16 bits)" severity warning;
    assert integer(ceil(log2(real(N_SHD*N_HIT)))) + 1 <= 16 report "N Hits counter will likely to overflow, resulting in functional error" severity warning;

    -- io mapping
    i_clk           <= d_clk;
    i_rst           <= d_reset;

    -- ────────────────────────────────────────────────
    -- hls generate : fifos insts
    -- ────────────────────────────────────────────────
    @@ for {set i 0} {$i < [llength $fifos_names]} {incr i} {
    @@ set name [lindex $fifos_names $i]
    gen_${name}s : for i in 0 to N_LANE-1 generate
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
    -- page rams = page tile complex
    -- ────────────────────────────────────────────────
    gen_page_rams : for i in 0 to N_TILE-1 generate
        c_page_ram : page_ram
            port map (
                data            => page_tile_wr_data(i),
                read_addr       => page_tile_rd_addr(i),
                write_addr      => page_tile_wr_addr(i),
                we              => page_tile_we(i),
                clk             => i_clk,
                q               => page_tile_rd_data(i)
            );
    end generate;

    -- ────────────────────────────────────────────────
    -- tile fifos
    -- ────────────────────────────────────────────────
    gen_tile_fifos : for i in 0 to N_TILE-1 generate
        c_tile_fifo : tile_fifo
            generic map (
                ADDR_WIDTH      => TILE_FIFO_ADDR_WIDTH,
                DATA_WIDTH      => TILE_FIFO_DATA_WIDTH
            )
            port map (
                data            => tile_fifos_wr_data(i),
                read_addr       => tile_fifos_rd_addr(i),
                write_addr      => tile_fifos_wr_addr(i),
                we              => tile_fifos_we(i),
                clk             => i_clk,
                q               => tile_fifos_rd_data(i)
            );
    end generate;

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

            -- de-assemble frame info from header
            ingress_parser_if_subheader_hit_cnt_raw(i) <= resize(unsigned(asi_ingress_data(i)(15 downto 8)), ingress_parser_if_subheader_hit_cnt_raw(i)'length);
            if (to_integer(unsigned(asi_ingress_data(i)(15 downto 8))) > N_HIT_SAT) then
                ingress_parser_if_subheader_hit_cnt(i)    <= to_unsigned(N_HIT_SAT, ingress_parser_if_subheader_hit_cnt(i)'length);
            else
                ingress_parser_if_subheader_hit_cnt(i)    <= ingress_parser_if_subheader_hit_cnt_raw(i);
            end if;
            ingress_parser_if_subheader_shd_ts(i)         <= asi_ingress_data(i)(31 downto 24);
            ingress_parser_if_preamble_dt_type(i)         <= asi_ingress_data(i)(31 downto 26);
            ingress_parser_if_preamble_feb_id(i)          <= asi_ingress_data(i)(23 downto 8);

            -- assemble write ticket FIFO wdata
            -- shr ticket = {alert_sop_eop[1:0] ... ts[47:0], start addr[9:0], length[9:0]}
            if (ingress_parser_state(i) = IDLE) then -- IDLE : use comb ts and subh_cnt from ingress data
                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts(47 downto 12)) & ingress_parser_if_subheader_shd_ts(i) & "0000"; -- ts[47:0]
                ingress_parser_if_write_ticket_data(i)(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO)    <= std_logic_vector(ingress_parser(i).lane_start_addr); -- start address of the lane FIFO
                ingress_parser_if_write_ticket_data(i)(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO)          <= std_logic_vector(ingress_parser_if_subheader_hit_cnt(i)); -- length of the subheader (8-bit)
            else -- WR_HIT : use registered ts and subh_cnt
                ingress_parser_if_write_ticket_data(i)(TICKET_TS_HI downto TICKET_TS_LO)                        <= std_logic_vector(ingress_parser(i).running_ts(47 downto 0)); -- ts[47:0]
                ingress_parser_if_write_ticket_data(i)(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO)    <= std_logic_vector(ingress_parser(i).lane_start_addr); -- start address of the lane FIFO
                ingress_parser_if_write_ticket_data(i)(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO)          <= std_logic_vector(ingress_parser(i).shd_len); -- length of the subheader (8-bit)
            end if;

            -- sop ticket = {alert_sop_eop[1:0] ... frame_serial[15:0], subheader_cnt[15:0], hits_count[15:0]}
            if (ingress_parser_state(i) = UPDATE_HEADER_TS and update_header_ts_flow(i) = 3) then
                ingress_parser_if_write_ticket_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)                <= (ingress_parser(i).pkg_cnt);
                ingress_parser_if_write_ticket_data(i)(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO)                <= (ingress_parser(i).running_shd_cnt);
                ingress_parser_if_write_ticket_data(i)(TICKET_N_HIT_HI downto TICKET_N_HIT_LO)                  <= std_logic_vector(ingress_parser(i).hit_cnt);
            end if;
            ingress_parser_if_write_ticket_data(i)(TICKET_ALT_EOP_LOC)      <= ingress_parser(i).alert_eop;
            ingress_parser_if_write_ticket_data(i)(TICKET_ALT_SOP_LOC)      <= ingress_parser(i).alert_sop;

            -- assemble write lane FIFO wdata
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
            ticket_fifos_wr_addr(i)         <= std_logic_vector(ingress_parser(i).ticket_wptr - 1);
            ticket_fifos_we(i)              <= ingress_parser(i).ticket_we;
            -- > lane FIFO
            lane_fifos_wr_data(i)           <= ingress_parser(i).lane_wdata;
            lane_fifos_wr_addr(i)           <= std_logic_vector(ingress_parser(i).lane_wptr - 1);
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
                                ingress_parser(i).shd_len_raw               <= ingress_parser_if_subheader_hit_cnt_raw(i);
                                ingress_parser(i).shd_len                   <= ingress_parser_if_subheader_hit_cnt(i); -- hit count (kept) from 0 to N_HIT
                                ingress_parser(i).shd_rx_cnt                <= (others => '0');
                                if ingress_parser_if_subheader_hit_cnt_raw(i) > ingress_parser_if_subheader_hit_cnt(i) then
                                    ingress_parser(i).shd_trim_drop <= '1';
                                else
                                    ingress_parser(i).shd_trim_drop <= '0';
                                end if;
                                if (ingress_parser_if_subheader_hit_cnt(i) >= ingress_parser(i).lane_credit) then -- pkg size >= free words
                                    -- error : incoming packet too large for lane FIFO (lane FIFO low credit)
                                    ingress_parser_state(i)         <= MASK_PKT;
                                elsif (ingress_parser(i).ticket_credit = 0) then
                                    -- error : ticket FIFO low credit
                                    ingress_parser_state(i)         <= MASK_PKT;
                                else
                                    if (ingress_parser_if_subheader_hit_cnt_raw(i) = 0) then
                                        -- ok : write ticket to ticket FIFO now (empty subheader)
                                        ingress_parser(i).ticket_we     <= '1';
                                        ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                        ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                        -- ticket credit
                                        if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                                        else
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                        end if;
                                        -- no need to update lane credit as the length is zero
                                    else
                                        -- Need to consume raw hits (may be trimmed).
                                        if (ingress_parser_if_subheader_hit_cnt(i) = 0) then
                                            -- Trim-to-zero: write the empty ticket now, then drop all raw hits.
                                            ingress_parser(i).ticket_we     <= '1';
                                            ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1;
                                            ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i);
                                            if page_allocator.ticket_credit_update_valid(i) then
                                                ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                                            else
                                                ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                            end if;
                                        end if;
                                        ingress_parser_state(i)         <= WR_HITS;
                                    end if;
                                end if;
                            elsif (asi_ingress_startofpacket(i)(0) and ingress_parser_is_preamble(i) and not ingress_parser_hdr_err(i)) then -- [preamble]
                                -- mark the sop (send special ticket to page allocator to indicate the start of frame, so the page allocator increase page wptr by offset of count * HDR_SIZE)
                                ingress_parser(i).alert_sop     <= '1';
                                -- update header ts (48-bit)
                                ingress_parser(i).dt_type       <= ingress_parser_if_preamble_dt_type(i); -- 6 bits, dt_type : ...
                                ingress_parser(i).feb_id        <= ingress_parser_if_preamble_feb_id(i);
                                update_header_ts_flow(i)        <= 0;
                                ingress_parser_state(i)         <= UPDATE_HEADER_TS;
                            elsif ingress_parser_is_trailer(i) then -- [trailer]
                                -- write special ticket for page allocator, to signal end of frame, so the page allocator increase page wptr by offset of count * TRL_SIZE)
                                ingress_parser(i).alert_eop     <= '1';
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
                                    -- Capture the full low 16 timestamp bits from the header word so the SOP ticket can
                                    -- carry an accurate frame timestamp even in N_SHD=128 mode (bit11 toggles).
                                    ingress_parser(i).running_ts(15 downto 0)       <= unsigned(asi_ingress_data(i)(31 downto 16));
                                    ingress_parser(i).pkg_cnt                       <= asi_ingress_data(i)(15 downto 0);
                                    update_header_ts_flow(i)                        <= update_header_ts_flow(i) + 1; -- next state
                                when 2 => -- [debug word 0]
                                    ingress_parser(i).running_shd_cnt               <= asi_ingress_data(i)(31 downto 16);
                                    ingress_parser(i).hit_cnt                       <= unsigned(asi_ingress_data(i)(15 downto 0));
                                    update_header_ts_flow(i)                        <= update_header_ts_flow(i) + 1; -- next state
                                when 3 => -- [debug word 1]
                                    ingress_parser(i).send_ts                       <= asi_ingress_data(i)(30 downto 0);
                                    update_header_ts_flow(i)                        <= 0; -- reset state, as return 0 (no error)
                                    -- write header ticket
                                    if (ingress_parser(i).ticket_credit /= 0) then -- ok : enough credit
                                        ingress_parser(i).alert_sop                     <= '0'; -- sop ticket has been written (eop is optional asserted here)
                                        ingress_parser(i).ticket_we                     <= '1';
                                        -- ticket credit
                                        if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                                        else
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                        end if;
                                        ingress_parser(i).ticket_wptr                   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                        ingress_parser(i).ticket_wdata                  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                        ingress_parser_state(i)                         <= IDLE; -- go back to IDLE
                                    else
                                        ingress_parser_state(i)                         <= MASK_PKT_EXTENDED; -- need to mask full frame as we cannot write the sop ticket, the mapper cannot predict how much memory to allocate in the page ram
                                    end if;

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
                            ingress_parser(i).shd_trim_drop <= '0';
                        end if;

                        if asi_ingress_valid(i)(0) then
                            -- trigger by new subheader coming in
                            if (ingress_parser_is_subheader(i) and not ingress_parser_shd_err(i)) then -- [subheader]
                                -- update subheader ts (8-bit) and add to into global ts (48-bit)
                                -- write ticket to ticket FIFO
                                -- ticket = {ts, start addr, length}
                                -- errorDescriptor = {hit_err shd_err hdr_err}
                                ingress_parser(i).running_ts(11 downto 4)   <= unsigned(ingress_parser_if_subheader_shd_ts(i)); -- update subheader timestamp
                                ingress_parser(i).shd_trim_drop <= '0';
                                ingress_parser(i).shd_len                   <= ingress_parser_if_subheader_hit_cnt(i); -- shd_hcnt (8-bit) from 0 to 255 hits + 1 (SHD_SIZE)
                                if (ingress_parser_if_subheader_hit_cnt(i) >= ingress_parser(i).lane_credit) then -- pkg size >= free words
                                    -- error : incoming packet too large for lane FIFO (lane FIFO low credit)
                                    ingress_parser_state(i)         <= MASK_PKT;
                                elsif (ingress_parser(i).ticket_credit = 0) then
                                    -- error : ticket FIFO low credit
                                    ingress_parser_state(i)         <= MASK_PKT;
                                else
                                    if (ingress_parser_if_subheader_hit_cnt(i) /= 0) then
                                        -- ok : but wait until subheader in lane FIFO, then write ticket FIFO
                                        ingress_parser_state(i)         <= WR_HITS;
                                    else
                                        -- ok : write ticket to ticket FIFO now
                                        ingress_parser(i).ticket_we     <= '1';
                                        ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                                        ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                                        ingress_parser(i).alert_eop     <= '0'; -- deassert alert of eop to page allocator once is written in a ticket once
                                        -- ticket credit
                                        if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                                        else
                                            ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                        end if;
                                        -- no need to update lane credit as the length is zero
                                    end if;
                                end if;
                            elsif (asi_ingress_startofpacket(i)(0) and ingress_parser_is_preamble(i) and not ingress_parser_hdr_err(i)) then -- [preamble]
                                -- mark the sop (send special ticket to page allocator to indicate the start of frame, so the page allocator increase page wptr by offset of count * HDR_SIZE)
                                ingress_parser(i).alert_sop     <= '1';
                                -- update header ts (48-bit)
                                ingress_parser(i).dt_type       <= ingress_parser_if_preamble_dt_type(i); -- 6 bits, dt_type : ...
                                ingress_parser(i).feb_id        <= ingress_parser_if_preamble_feb_id(i);
                                update_header_ts_flow(i)        <= 0;
                                ingress_parser_state(i)         <= UPDATE_HEADER_TS;
                            elsif ingress_parser_is_trailer(i) then -- [trailer]
                                -- write special ticket for page allocator, to signal end of frame, so the page allocator increase page wptr by offset of count * TRL_SIZE)
                                ingress_parser(i).alert_eop     <= '1';
                            end if;

                        --     -- trigger by new subheader coming in
                        --     if (ingress_parser_is_subheader(i) and not ingress_parser_shd_err(i)) then -- [subheader]
                        --         -- update subheader ts (8-bit) and add to into global ts (48-bit)
                        --         -- write ticket to ticket FIFO
                        --         -- ticket = {ts, start addr, length}
                        --         -- errorDescriptor = {hit_err shd_err hdr_err}
                        --         ingress_parser(i).running_ts(11 downto 4)   <= unsigned(ingress_parser_if_subheader_shd_ts(i)); -- update subheader timestamp
                        --         ingress_parser(i).shd_len                   <= ingress_parser_if_subheader_hit_cnt(i); -- shd_hcnt (8-bit) from 0 to 255 hits + 1 (SHD_SIZE)
                        --         if (ingress_parser_if_subheader_hit_cnt(i) >= ingress_parser(i).lane_credit) then -- pkg size >= free words
                        --             -- error : continue to mask if packet larger than lane credit
                        --             ingress_parser_state(i)         <= MASK_PKT;
                        --         elsif (ingress_parser(i).ticket_credit = 0) then
                        --             -- error : ticket FIFO low credit
                        --             ingress_parser_state(i)         <= MASK_PKT;
                        --         else
                        --             if (ingress_parser_if_subheader_hit_cnt(i) /= 0) then
                        --                 -- ok : but wait until subheader in lane FIFO, then write ticket FIFO
                        --                 ingress_parser_state(i)         <= WR_HITS;
                        --             else
                        --                 -- ok : write ticket to ticket FIFO with empty ticket
                        --                 ingress_parser(i).ticket_we     <= '1';
                        --                 ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1; -- increment write pointer as we will write to ticet FIFO
                        --                 ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i); -- see proc_assemble_write_ticket_fifo
                        --                 ingress_parser(i).alert_sop     <= '0'; -- deassert alert of sop to page allocator once is written in a ticket once
                        --                 ingress_parser(i).alert_eop     <= '0'; -- deassert alert of eop to page allocator once is written in a ticket once
                        --                 -- ticekt credit
                        --                 if page_allocator.ticket_credit_update_valid(i) then -- update ticket credit, substract 1 ticket
                        --                     ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                        --                 else
                        --                     ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                        --                 end if;
                        --                 -- lane credit
                        --                 if block_mover(i).lane_credit_update_valid then -- update lane credit if called on rx side, we write lane nothing here
                        --                     ingress_parser(i).lane_credit   <= ingress_parser(i).lane_credit + block_mover(i).lane_credit_update;
                        --                 end if;
                        --             end if;
                        --         end if;
                        --     end if;
                        -- end if;
                        end if;

                    when WR_HITS => -- [hit(s)]
                        -- Consume hit words for this subheader. Keep at most `shd_len` hits and drop the rest
                        -- (still consuming the raw length `shd_len_raw` to stay aligned to the next subheader).
                        if (asi_ingress_valid(i)(0) and not ingress_parser_hit_err(i)) then -- hit w/o error
                            ingress_parser(i).shd_rx_cnt <= ingress_parser(i).shd_rx_cnt + 1;

                            if (ingress_parser(i).shd_rx_cnt < ingress_parser(i).shd_len) then
                                -- ok : write lane data (kept hits)
                                ingress_parser(i).lane_wdata <= ingress_parser_if_write_lane_data(i); -- see proc_assemble_write_lane_fifo
                                ingress_parser(i).lane_wptr  <= ingress_parser(i).lane_wptr + 1;
                                ingress_parser(i).lane_we    <= '1';
                            else
                                -- drop trimmed hits
                                ingress_parser(i).lane_we    <= '0';
                            end if;

                            -- Write ticket when the last *kept* hit is written (or already written for trim-to-zero).
                            if (ingress_parser(i).lane_start_addr + ingress_parser(i).shd_len = ingress_parser(i).lane_wptr + 1) then
                                ingress_parser(i).ticket_we     <= '1';
                                ingress_parser(i).ticket_wptr   <= ingress_parser(i).ticket_wptr + 1;
                                ingress_parser(i).ticket_wdata  <= ingress_parser_if_write_ticket_data(i);
                                if page_allocator.ticket_credit_update_valid(i) then
                                    ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit + page_allocator.ticket_credit_update(i) - 1;
                                else
                                    ingress_parser(i).ticket_credit <= ingress_parser(i).ticket_credit - 1;
                                end if;
                                if block_mover(i).lane_credit_update_valid then
                                    ingress_parser(i).lane_credit <= ingress_parser(i).lane_credit - ingress_parser(i).shd_len + block_mover(i).lane_credit_update;
                                else
                                    ingress_parser(i).lane_credit <= ingress_parser(i).lane_credit - ingress_parser(i).shd_len;
                                end if;
                                ingress_parser(i).lane_start_addr <= ingress_parser(i).lane_wptr + 1;
                            end if;

                            -- Exit once we've consumed all raw hits for this subheader.
                            if (ingress_parser(i).shd_rx_cnt + 1 >= ingress_parser(i).shd_len_raw) then
                                ingress_parser_state(i)         <= IDLE;
                                ingress_parser(i).shd_trim_drop <= '0';
                            end if;
                        elsif ingress_parser_shd_err(i) then
                            -- error : early eop seen, set the wr ptr to the expected length (next cycle)
                            ingress_parser(i).error_lane_wr_early_term <= '1';
                        end if;

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

                -- deassert eop flag once written
                for i in 0 to N_LANE-1 loop
                    if (ingress_parser(i).ticket_we = '1' and ingress_parser(i).alert_eop = '1') then
                        ingress_parser(i).alert_eop         <= '0';
                    end if;
                end loop;

                -- delay chain
                for j in 1 to FIFO_RAW_DELAY loop
                    if j = 1 then
                        page_allocator_is_pending_ticket_d(i)(j)       <= page_allocator_is_pending_ticket(i);
                    else
                        page_allocator_is_pending_ticket_d(i)(j)       <= page_allocator_is_pending_ticket_d(i)(j-1);
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
        variable total_subh             : unsigned(FRAME_SUBH_CNT_SIZE-1 downto 0);
        variable total_hit              : unsigned(FRAME_HIT_CNT_SIZE-1 downto 0);
    begin
        -- assemble write handle to handle FIFO
        for i in 0 to N_LANE-1 loop
            if (i > 0) then
                page_allocator_if_alloc_blk_start(i)         <= std_logic_vector(page_allocator.page_start_addr + page_allocator.ticket(i-1).block_length + SHD_SIZE); -- need to offset by subheader (1 word)
            else
                page_allocator_if_alloc_blk_start(i)         <= std_logic_vector(page_allocator.page_start_addr + SHD_SIZE);
            end if;
            page_allocator_if_write_handle_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO)         <= page_allocator.ticket(i).lane_fifo_rd_offset; -- source
            page_allocator_if_write_handle_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO)         <= page_allocator_if_alloc_blk_start(i); -- destination
            page_allocator_if_write_handle_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO)         <= std_logic_vector(page_allocator.ticket(i).block_length); -- length

            if (ingress_parser(i).ticket_wptr /= page_allocator.ticket_rptr(i)) then -- ex: wr ptr = 7, wr addr = 6. rd ptr = rd addr = 6, no ticket
                page_allocator_is_pending_ticket(i)   <= '1'; -- there is pending ticket to be read
            else
                page_allocator_is_pending_ticket(i)   <= '0'; -- no pending ticket to be read
            end if;
        end loop;

        -- assemble page RAM write data
        -- [subheader]
        page_allocator_if_write_page_shr_data                   <= (others => '0'); -- default
        page_allocator_if_write_page_shr_data(35 downto 32)     <= "0001"; -- byte_is_k[3:0] = "0001" for subheader
        page_allocator_if_write_page_shr_data(31 downto 24)     <= std_logic_vector(page_allocator.running_ts(11 downto 4)); -- ts[11:4] of the subheader
        page_allocator_if_write_page_shr_data(23 downto 8)      <= std_logic_vector(to_unsigned(to_integer(unsigned(std_logic_vector(page_allocator.page_length))),23-8+1)); -- hit cnt of this subheader
        page_allocator_if_write_page_shr_data(7 downto 0)       <= K237; -- write subheader begin marker
        -- [header]
        page_allocator_if_write_page_hdr_data                   <= (others => '0'); -- default
        case page_allocator.write_meta_flow is -- [0:2] in WRITE_HEAD (this frame), [3:4] in WRITE_TAIL (last frame)
            when 0 =>
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0001";
                page_allocator_if_write_page_hdr_data(31 downto 26)     <= ingress_parser(0).dt_type; -- should be static. TODO: refine to mask
                page_allocator_if_write_page_hdr_data(23 downto 8)      <= ingress_parser(0).feb_id; -- should be static. TODO: refine to mask
                page_allocator_if_write_page_hdr_data(7 downto 0)       <= K285;
            when 1 =>
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0000";
                page_allocator_if_write_page_hdr_data(31 downto 0)      <= std_logic_vector(page_allocator.frame_ts(47 downto 16)); -- ts[47:16]
            when 2 =>
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0000";
                page_allocator_if_write_page_hdr_data(31 downto 16)     <= std_logic_vector(page_allocator.frame_ts(15 downto 0)); -- ts[15:0], check ts[11:0] should be zero
                page_allocator_if_write_page_hdr_data(15 downto 0)      <= std_logic_vector(page_allocator.frame_serial_this(15 downto 0));
            when 3 =>
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0000";
                -- Declared subheader count is per merged frame (not summed across lanes).
                -- page_allocator.frame_shr_cnt counts accepted subheaders across all lanes, so divide by N_LANE.
                page_allocator_if_write_page_hdr_data(16+MAX_SHR_CNT_BITS-1 downto 16)      <= std_logic_vector(page_allocator.frame_shr_cnt / to_unsigned(N_LANE, page_allocator.frame_shr_cnt'length));
                page_allocator_if_write_page_hdr_data(MAX_HIT_CNT_BITS-1 downto 0)          <= std_logic_vector(page_allocator.frame_hit_cnt); -- 16 bits, sum of all lanes of decleared hits
            when 4 =>
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0000";
                page_allocator_if_write_page_hdr_data(30 downto 0)      <= std_logic_vector(ingress_parser(0).running_ts(30 downto 0)); -- TODO: change this to global timestamp counter (gts) once it is available
            when 5 =>
                page_allocator_if_write_page_hdr_data                   <= page_allocator_if_write_page_trl_data;
            when others => -- word 3 or 4 should be written when the whole frame is finished, including {subheader_cnt hit_cnt send_ts}
                page_allocator_if_write_page_hdr_data(35 downto 32)     <= "0000";
                page_allocator_if_write_page_hdr_data(31 downto 0)      <= (others => '0');
        end case;
        -- [trailer]
        page_allocator_if_write_page_trl_data                 <= (others => '0'); -- default (avoid X on unused upper bits)
        page_allocator_if_write_page_trl_data(35 downto 32)         <= "0001";
        page_allocator_if_write_page_trl_data(31 downto 8)          <= (others => '0'); -- TODO: change to the actual number of hits written by block mover and CRC-8 if needed
        page_allocator_if_write_page_trl_data(7 downto 0)           <= K284;


        -- deassemble ticket read from ticket FIFO
        total_subh          := (others => '0');
        total_hit           := (others => '0');
        for i in 0 to N_LANE-1 loop
            page_allocator_if_read_ticket_ticket(i).ticket_ts                   <= unsigned(ticket_fifos_rd_data(i)(TICKET_TS_HI downto TICKET_TS_LO)); -- ts[47:0]
            page_allocator_if_read_ticket_ticket(i).lane_fifo_rd_offset         <= ticket_fifos_rd_data(i)(TICKET_LANE_RD_OFST_HI downto TICKET_LANE_RD_OFST_LO); -- start address of the lane RAM
            page_allocator_if_read_ticket_ticket(i).block_length                <= unsigned(ticket_fifos_rd_data(i)(TICKET_BLOCK_LEN_HI downto TICKET_BLOCK_LEN_LO)); -- length of the subheader (8-bit), excl subheader itself
            page_allocator_if_read_ticket_ticket(i).alert_eop                   <= ticket_fifos_rd_data(i)(TICKET_ALT_EOP_LOC); -- alert eop, incr page wptr and dst 1
            page_allocator_if_read_ticket_ticket(i).alert_sop                   <= ticket_fifos_rd_data(i)(TICKET_ALT_SOP_LOC); -- alert sop, incr page wptr and dst 5
            total_subh      := total_subh + unsigned(ticket_fifos_rd_data(i)(TICKET_N_SUBH_HI downto TICKET_N_SUBH_LO));
            total_hit       := total_hit + unsigned(ticket_fifos_rd_data(i)(TICKET_N_HIT_HI downto TICKET_N_HIT_LO));
        end loop;
        page_allocator_if_read_ticket_ticket_sop.serial                     <= unsigned(ticket_fifos_rd_data(0)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)); -- serial number of the frame, TODO: check against mismatch
        page_allocator_if_read_ticket_ticket_sop.n_subh                     <= total_subh(MAX_SHR_CNT_BITS-1 downto 0); -- number of subheaders in frames of all lanes
        page_allocator_if_read_ticket_ticket_sop.n_hit                      <= total_hit(MAX_HIT_CNT_BITS-1 downto 0); -- number of hits in frames of all lanes

        -- derive sop
        page_allocator_is_tk_sop        <= (others => '0');
        for i in 0 to N_LANE-1 loop
            if ticket_fifos_rd_data(i)(TICKET_ALT_SOP_LOC) then
                page_allocator_is_tk_sop(i)        <= '1';
            end if;
        end loop;

        -- -- derive eop
        -- page_allocator_is_tk_eop        <= '0';
        -- for i in 0 to N_LANE-1 loop
        --     if page_allocator_if_read_ticket_ticket(i).alert_eop then
        --         page_allocator_is_tk_eop        <= '1';
        --     end if;
        -- end loop;

        -- derive timeliness of the showahead ticket
        for i in 0 to N_LANE-1 loop
            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket
                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) >= page_allocator.frame_serial + 1 then -- check serial number, TODO: handle the frame serial overflow case
                    page_allocator_is_tk_future(i)              <= '1'; -- "stall"
                else
                    page_allocator_is_tk_future(i)              <= '0'; -- ok : expected
                end if;
            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) > page_allocator.running_ts + to_unsigned(16, page_allocator.running_ts'length)) then -- shr ticket (allow 1 tick slack)
                page_allocator_is_tk_future(i)              <= '1';
            else
                page_allocator_is_tk_future(i)              <= '0';
            end if;

            if page_allocator_is_tk_sop(i) = '1' then -- sop ticket
                if unsigned(ticket_fifos_rd_data(i)(TICKET_SERIAL_HI downto TICKET_SERIAL_LO)) < page_allocator.frame_serial then -- check serial number
                    page_allocator_is_tk_past(i)                <= '1'; -- "drop"
                else
                    page_allocator_is_tk_past(i)                <= '0'; -- ok : expected
                end if;
            elsif (unsigned(ticket_fifos_rd_data(i)(47 downto 0)) + to_unsigned(16, page_allocator.running_ts'length) < page_allocator.running_ts) then -- shr ticket (allow 1 tick slack)
                page_allocator_is_tk_past(i)                <= '1';
            else
                page_allocator_is_tk_past(i)                <= '0';
            end if;
        end loop;

        -- derive the the pipeline is all set
        page_allocator_is_pending_ticket_lane       <= (others => '0');
        for i in 0 to N_LANE-1 loop
            page_allocator_is_pending_ticket_lane(i)    <= and_reduce(page_allocator_is_pending_ticket_d(i));
        end loop;

        -- conn.
        for i in 0 to N_LANE-1 loop
        -- > handle FIFO
            handle_fifos_we(i)                                      <= page_allocator.handle_we(i);
            handle_fifos_wr_data(i)(HANDLE_LENGTH downto 0)         <= page_allocator.handle_wflag(i) & page_allocator_if_write_handle_data(i); -- handle = {flag 1-bit, data}
            handle_fifos_wr_addr(i)                                 <= std_logic_vector(page_allocator.handle_wptr(i) - 1);
        -- ticket FIFO >
            ticket_fifos_rd_addr(i)                                 <= std_logic_vector(page_allocator.ticket_rptr(i));
        end loop;
        -- > page RAM
        -- controlled by ARB ...
    end process;


	    gen_alloc_by_mode : if (MODE = "MERGING") generate -- mode = {MERGING MULTIPLEXING}
	        proc_page_allocator : process (i_clk)
	            variable any_mover_busy : boolean;
	        -- @description     allocate a page in the page RAM once all tickets are available. ipc to block mover to start the routine with handle.
	        -- @note            can skip late ticket
	        --                  return credit to write_ticket_fifo
	        begin
            if rising_edge(i_clk) then
                -- default
                for i in 0 to N_LANE-1 loop
                    page_allocator.ticket_credit_update_valid(i)    <= '0';
                    page_allocator.handle_we(i)                     <= '0';
                    page_allocator.handle_wflag(i)                  <= '0';
                end loop;
                page_allocator.page_we                          <= '0';

                -- state machine of page allocator
                case page_allocator_state is
                    when IDLE =>
                        -- standby state, wait for ticket FIFO to have pending tickets
                        if (and_reduce(page_allocator_is_pending_ticket_lane) = '1' and and_reduce(page_allocator_is_pending_ticket) = '1') then -- all lanes have packet, check both tail and head of the delay chain
                            -- Frame-boundary safety: don't start a new frame header (SOP tickets) while
                            -- there are still outstanding block-mover handles from the previous frame.
                            -- Otherwise the mapper can advance the write-tile mapping while late hit writes
                            -- are still in flight, and those hits end up in the wrong tile (broken packets).
                            any_mover_busy := false;
                            for j in 0 to N_LANE-1 loop
                                if (block_mover_state(j) /= IDLE) then
                                    any_mover_busy := true;
                                end if;
                            end loop;

                            if (and_reduce(page_allocator_is_tk_sop) = '1') and ((or_reduce(handle_fifo_is_pending_handle) = '1') or any_mover_busy) then
                                -- stall in IDLE until movers drain
                            else
                                page_allocator_state                    <= FETCH_TICKET; -- fetch HOL ticket from ticket FIFO
                            end if;
                        end if;

                    when FETCH_TICKET =>
                        -- fetch a ticket from ticket FIFO and derive its timeliness. since we only write ticket if the lane has fully written to lane, it guarantees block mover can start right away
                        -- default
                        page_allocator.lane_masked              <= (others => '0'); -- assume not to mask
                        page_allocator.lane_skipped             <= (others => '0'); -- assume not to skip
                        page_allocator.page_length              <= (others => '0'); -- reset page length, to be calculated in ALLOC_PAGE

                        for i in 0 to N_LANE-1 loop -- do it in parallel
                            -- return 1 unit of credit to ingress parser (ack we read the ticket)
                            page_allocator.ticket_credit_update(i)          <= to_unsigned(1,TICKET_FIFO_ADDR_WIDTH); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                            page_allocator.ticket_credit_update_valid(i)    <= '1';

                            -- fetch (read) ticket from ticket FIFO
                            -- sop ticket = {alert_sop_eop[1:0] ... serial[15:0], n_subh[15:0], n_hit[15:0]}
                            if and_reduce(page_allocator_is_tk_sop) = '1' then -- all lanes have sop, otherwise proceed with lagging lanes
                                -- [sop ticket] update sum(frame shr cnt) and sum(hit cnt) and serial number
                                page_allocator.frame_shr_cnt_this               <= page_allocator_if_read_ticket_ticket_sop.n_subh; -- summed
                                page_allocator.frame_hit_cnt_this               <= page_allocator_if_read_ticket_ticket_sop.n_hit; -- summed
                                page_allocator.frame_serial_this                <= page_allocator_if_read_ticket_ticket_sop.serial; -- unified, note: we cannot allow all lanes to skip one frame, it will stuck
                                page_allocator.frame_serial                     <= page_allocator.frame_serial + 1; -- self-incr of tracking frame serial number
                                -- Snapshot whether the *previous* frame was declared invalid (allocator skipped ticks)
                                -- before clearing the flag for the new frame. This is needed because WRITE_TAIL
                                -- finalizes the previous frame after the new SOP has already been observed.
                                page_allocator.frame_invalid_last                <= page_allocator.frame_invalid;
                                page_allocator.frame_invalid                     <= '0';
                                page_allocator.ticket_rptr(i)                   <= page_allocator.ticket_rptr(i) + 1; -- read ack, incr ticket read pointer by 1
                            -- shr ticket = {alert_sop_eop[1:0] ... ts[47:0], start addr[9:0], length[9:0]}
                            elsif page_allocator_is_tk_future(i) then
                                -- [exception] maybe a skip, as we read ticket with timestamp in the future : "stall" do not read this ticket yet, reserve for next round
                                page_allocator.ticket_rptr(i)                   <= page_allocator.ticket_rptr(i); -- ignore ticket for this round
                                page_allocator.lane_masked(i)                   <= '1'; -- mask this lane, do not allocate in the page and let the block mover to ignore it
                                page_allocator.ticket_credit_update_valid(i)    <= '0'; -- note: do not return ticket, otherwise credit overflow
                            elsif page_allocator_is_tk_past(i) then
                                -- [exception] maybe a glitch, as we read ticket with timestamp in the past : "drop" this ticket
                                page_allocator.ticket_rptr(i)                   <= page_allocator.ticket_rptr(i) + 1; -- drop ack, incr ticket read pointer by 1
                                page_allocator.lane_skipped(i)                  <= '1'; -- skip this lane, do not allocate in the page and let the block mover to skip it
                            else
                                page_allocator.ticket(i)                        <= page_allocator_if_read_ticket_ticket(i); -- latch the ticket from ticket FIFO
                                page_allocator.ticket_rptr(i)                   <= page_allocator.ticket_rptr(i) + 1; -- read ack, incr ticket read pointer by 1
                            end if;
                        end loop;

                        -- exit condition 0 : if all lanes have been fetched, allocate page
                        page_allocator_state                          <= ALLOC_PAGE; -- allocate a page in the page RAM
                        page_allocator.alloc_page_flow                <= 0; -- reset entry point, TODO: to speed up, find the leading 1 of unmask and unskip lane, and the next...

                        -- exit condition 1 : if all lanes have sop (marks new frame packet, need to write 5 words of header), first write header (optional: write last trailer), then allocate page
                        for i in 0 to N_LANE-1 loop
                            if (and_reduce(page_allocator_is_tk_sop) = '1') then -- only generate once per frame
                                page_allocator.page_we                          <= '1'; -- write in the first cycle of WRITE_HEAD
                                if (page_allocator_if_read_ticket_ticket(i).alert_eop) then -- second+ frame of this run will be addressed to give space for the trailer of last frame
                                    page_allocator.page_waddr                       <= std_logic_vector(page_allocator.page_start_addr + to_unsigned(TRL_SIZE,page_allocator.page_start_addr'length)); -- set the top address of this frame in page RAM
                                    page_allocator.frame_start_addr                 <= page_allocator.page_start_addr + to_unsigned(TRL_SIZE,page_allocator.page_start_addr'length); -- remember the top address of this frame in page RAM
                                else -- first frame of this run will be addressed at 0
                                    page_allocator.page_waddr                       <= std_logic_vector(page_allocator.page_start_addr); -- first frame, not need to leave space for trailer
                                    page_allocator.frame_start_addr                 <= page_allocator.page_start_addr;
                                end if;
                                page_allocator.frame_start_addr_last            <= page_allocator.frame_start_addr; -- latch last frame starting address, need this to write debug info the last frame
                                -- Derive timestamps from packet serial to match the UVM time model:
                                --   - running_ts starts at pkg_cnt*FRAME_DURATION_CYCLES (sets ts8 phase for odd/even packets)
                                --   - frame_ts is the epoch base: ((pkg_cnt & ~1) + 1)*FRAME_DURATION_CYCLES (constant for pairs)
                                page_allocator.running_ts                       <= to_unsigned(
                                    to_integer(page_allocator_if_read_ticket_ticket_sop.serial) * FRAME_DURATION_CYCLES,
                                    page_allocator.running_ts'length
                                );
                                page_allocator.frame_ts                         <= to_unsigned(
                                    ((to_integer(page_allocator_if_read_ticket_ticket_sop.serial) / 2) * 2 + 1) * FRAME_DURATION_CYCLES,
                                    page_allocator.frame_ts'length
                                );
                                page_allocator.write_trailer                    <= page_allocator_if_read_ticket_ticket(i).alert_eop; -- it will be there fore the frame serial > 1, frame 0 has no trailer
                                page_allocator_state                            <= WRITE_HEAD;
                                page_allocator.write_meta_flow                  <= 0;
                            end if;
                        end loop;

                    when WRITE_HEAD =>
                        -- write the first 3 out of 5 words of header for current frame, flow = [0:2]
                        if page_allocator.write_meta_flow < 2 then
                            page_allocator.page_we                  <= '1'; -- write next word
                            page_allocator.page_waddr               <= std_logic_vector(page_allocator.frame_start_addr + page_allocator.write_meta_flow + 1); -- set the next addr
                        else
                            if page_allocator.write_trailer then -- [exit 1] write the trailer of last frame. derived from ticket.alert_eop
                                page_allocator.page_we                  <= '1'; -- write next word
                                page_allocator.page_waddr               <= std_logic_vector(page_allocator.frame_start_addr_last + page_allocator.write_meta_flow + 1); -- will be writing word 3
                                page_allocator_state                    <= WRITE_TAIL;
                            else -- [exit 0] allocate page for all lanes with tickets obtained, because this is the first frame of this run, no trailer needs to write
                                page_allocator.page_we                  <= '0'; -- stop write
                                page_allocator.page_start_addr          <= page_allocator.frame_start_addr + HDR_SIZE; -- incr the page start addr by HDR_SIZE (5) from this frame top, because we wrote header
                                page_allocator.frame_cnt                <= page_allocator.frame_cnt + 1; -- incr the frame counter
                                page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length); -- advance to next frame start
                                page_allocator_state                    <= IDLE; -- go back and get one shr ticket
                            end if;
                        end if;
                        -- incr flow
                        page_allocator.write_meta_flow          <= page_allocator.write_meta_flow + 1;

                    when WRITE_TAIL =>
                        -- write the last 2 out of 5 words of header and 1 word of trailer for last frame, flow = [3:5], then reset to 0
                        if page_allocator.write_meta_flow < 4 then
                            page_allocator.write_meta_flow          <= page_allocator.write_meta_flow + 1; -- incr flow
                            page_allocator.page_we                  <= '1'; -- write next word
                            page_allocator.page_waddr               <= std_logic_vector(page_allocator.frame_start_addr_last + page_allocator.write_meta_flow + 1); -- set the next addr
                        elsif page_allocator.write_meta_flow < 5 then
                            page_allocator.write_meta_flow          <= page_allocator.write_meta_flow + 1; -- incr flow
                            page_allocator.page_we                  <= '1'; -- write next word
                            page_allocator.page_waddr               <= std_logic_vector(page_allocator.frame_start_addr - 1); -- note: we used the latest ticket of frame N to derive the frame N-1 trailer address
                        else
                            -- [reset]
                            page_allocator.write_meta_flow          <= 0;
                            page_allocator.write_trailer            <= '0';
                            page_allocator.page_start_addr          <= page_allocator.page_start_addr + HDR_SIZE + TRL_SIZE; -- incr the page start addr by HDR_SIZE (5) + TRL_SIZE (1), because we wrote header + last trailer
                            page_allocator.frame_ts                 <= page_allocator.frame_ts + to_unsigned(FRAME_DURATION_CYCLES, page_allocator.frame_ts'length); -- advance to next frame start
                            page_allocator_state                    <= IDLE; -- go back and get one shr ticket
                            -- reset counters of last frame
                            page_allocator.frame_shr_cnt            <= (others => '0');
                            page_allocator.frame_hit_cnt            <= (others => '0');
                        end if;

	                    when ALLOC_PAGE =>
	                        -- allocate a page in the page RAM
	                        -- default
	                        page_allocator.alloc_page_flow         <= page_allocator.alloc_page_flow + 1; -- increment flow

	                        -- flow : write to handle FIFO to start block mover
	                        for i in 0 to N_LANE-1 loop -- do it in serial
	                            -- select this lane
	                            if (page_allocator.alloc_page_flow = i) then
	                                -- from the ticket keep track of subheader and hit counter in this frame
	                                if (page_allocator.lane_skipped(i) = '0' and page_allocator.lane_masked(i) = '0') then
	                                    page_allocator.frame_shr_cnt            <= page_allocator.frame_shr_cnt + 1; -- incr subheader count for this frame, iff the ticket was accepted (neither dropped nor halted)
	                                    page_allocator.frame_hit_cnt            <= page_allocator.frame_hit_cnt + page_allocator.ticket(i).block_length; -- incr hit count for this frame, iff the ticket was accepted (neither dropped nor halted)
	                                end if;

	                                -- write handle = {dst, src, length} to block mover, in a sequence lane by lane (better timing), from ticket = {ts[47:0], start addr[9:0], length[9:0]}
	                                if (page_allocator.ticket(i).block_length = 0) then -- do not write : no data in lane
	                                    page_allocator.handle_we(i)                 <= '0'; -- TODO: remove it
	                                elsif page_allocator.lane_skipped(i) then -- past ticket : mover must skip this lane
	                                    page_allocator.handle_we(i)                 <= '1'; -- write skip flag to block mover
	                                    page_allocator.handle_wflag(i)              <= '1'; -- flag = {skip_blk}, drop this block and return credit through lane FIFO
	                                    page_allocator.handle_wptr(i)               <= page_allocator.handle_wptr(i) + 1;
	                                elsif page_allocator.lane_masked(i) then -- future ticket : mover can continue with current task
	                                    page_allocator.handle_we(i)                 <= '0'; -- TODO: remove it
	                                else -- write ok
	                                    page_allocator.handle_we(i)                 <= '1'; -- write to the handle FIFO
	                                    page_allocator.handle_wptr(i)               <= page_allocator.handle_wptr(i) + 1;
	                                    -- calculate the page length (n_hits) as sum of block lengths
	                                    page_allocator.page_length                  <= page_allocator.page_length + page_allocator.ticket(i).block_length;
	                                end if;
	                            end if;
	                        end loop;

	                        -- [exit] : if all lanes have been allocated a block in the page
	                        if (page_allocator.alloc_page_flow = N_LANE-1) then
	                            if (and_reduce(page_allocator.lane_masked)) then -- no subheader from all lanes, we do not write this subheader of this frame
	                                page_allocator_state                        <= IDLE; -- all mask, all lane ahead, move ts forward, but do not write page ram
	                                page_allocator.running_ts(47 downto 4)      <= page_allocator.running_ts(47 downto 4) + 1; -- skip this subheader time tick
	                                page_allocator.frame_invalid                 <= '1'; -- record that this frame is incomplete; drop it at finalize
	                            else
	                                page_allocator_state                        <= WRITE_PAGE; -- write the page, i.e., subheader, to the page ram
	                                -- prepare to write subheader to page ram, write page data is in comb
	                                page_allocator.page_we                      <= '1';
	                                page_allocator.page_waddr                   <= std_logic_vector(page_allocator.page_start_addr); -- page boundary address = subheader line = first line of this page
	                            end if;
	                            page_allocator.alloc_page_flow              <= 0; -- reset flow, return 0 as OK
	                        end if;

                    when WRITE_PAGE =>
                        -- update current running timestamp
                        page_allocator.running_ts(47 downto 4)          <= page_allocator.running_ts(47 downto 4) + 1; -- for each round, we increase the tracking ts by one subheader time unit
                        page_allocator.page_start_addr                  <= unsigned(page_allocator.page_waddr) + page_allocator.page_length + to_unsigned(SHD_SIZE,page_allocator.page_start_addr'length); -- update to next page length, note: only 1 cycle, 1 word spacing for trailer
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

                -- Never allow the writer to touch a tile that is locked by the read/presenter.
                -- Sacrifice this frame (drop) rather than corrupting an in-flight egress packet.
                if (i_rst = '0') and (ftable_wr_blocked_by_rd_lock = '1') then
                    page_allocator.frame_invalid <= '1';
                end if;

                page_allocator.write_meta_flow_d1               <= page_allocator.write_meta_flow;

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
    -- @brief           given handle, DMA of data frame lane into page ram
    -- @input
    -- @output
    -- @description     can skip late hits and retrieve next handle
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_block_mover_comb : process (all)
    begin
        for i in 0 to N_LANE-1 loop
            -- if pending handle
            if (page_allocator.handle_wptr(i) /= block_mover(i).handle_rptr) then -- note: wr_addr = wr_ptr - 1 = rd_addr. when not equal, meaning pending ticket
                handle_fifo_is_pending_handle(i)        <= '1';
            else
                handle_fifo_is_pending_handle(i)        <= '0';
            end if;

            if (page_allocator.handle_we(i) = '1' and page_allocator.handle_wptr(i) - 1 = block_mover(i).handle_rptr) then -- read during write (wait 2 cycles)
                handle_fifo_is_pending_handle(i)        <= '0';
            end if;

            -- if pending handle valid, ready to read by incr rd_ptr (delayed pending_handle by FIFO_RAW_DELAY cycles)
            if (and_reduce(handle_fifo_is_pending_handle_d(i)) = '1' and handle_fifo_is_pending_handle(i) = '1') then
                handle_fifo_is_pending_handle_valid(i)  <= '1';
            else
                handle_fifo_is_pending_handle_valid(i)  <= '0';
            end if;

            -- if handle valid (in case rptr has changed, q will be delayed)
            if (block_mover(i).handle_rptr_d(FIFO_RD_DELAY) = block_mover(i).handle_rptr) then
                handle_fifo_is_q_valid(i)   <= '1';
            else
                handle_fifo_is_q_valid(i)   <= '0';
            end if;

            -- derive the pointer of read lane
            if b2p_arb_gnt(i) then
                block_mover_if_move_lane_rptr(i)        <= to_unsigned(to_integer(block_mover(i).handle.src) + to_integer(block_mover(i).word_wr_cnt) + 1,LANE_FIFO_ADDR_WIDTH);
            else
                block_mover_if_move_lane_rptr(i)        <= to_unsigned(to_integer(block_mover(i).handle.src) + to_integer(block_mover(i).word_wr_cnt),LANE_FIFO_ADDR_WIDTH);
            end if;

            -- conn.
            -- lane FIFO >
            lane_fifos_rd_addr(i)                                   <= std_logic_vector(block_mover_if_move_lane_rptr(i));
            block_mover_if_write_page_data(i)(35 downto 0)          <= lane_fifos_rd_data(i)(35 downto 0); -- TODO: check what is written by ingress parser
            lane_fifo_if_rd_eop(i)                                  <= lane_fifos_rd_data(i)(36); -- normal eop of subheader
            -- handle FIFO >
            handle_fifos_rd_addr(i)                                 <= std_logic_vector(block_mover(i).handle_rptr);
            -- deassemble handle
            handle_fifo_if_rd(i).handle.src        <= unsigned(handle_fifos_rd_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO));
            handle_fifo_if_rd(i).handle.dst        <= unsigned(handle_fifos_rd_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO));
            handle_fifo_if_rd(i).handle.blk_len    <= unsigned(handle_fifos_rd_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO));
            handle_fifo_if_rd(i).flag              <= handle_fifos_rd_data(i)(HANDLE_LENGTH);
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
                        if (handle_fifo_is_pending_handle_valid(i) = '1' and handle_fifo_is_q_valid(i) = '1') then -- discrepancy of wptr and rptr, sense the change of both pointers and delay the valid
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
                        block_mover(i).page_wptr          <= block_mover(i).handle.dst; -- set the wptr = page RAM block starting address
                        block_mover(i).page_wreq          <= '1';
                        block_mover_state(i)              <= WRITE_BLK;

                    when WRITE_BLK =>
                        -- moving state, move data from lane FIFO to page RAM according to handle
                        -- request and post data
                        block_mover(i).page_wreq      <= '1'; -- request to write

                        if (block_mover(i).page_wreq = '1' and b2p_arb_gnt(i) = '1') then
                            block_mover(i).word_wr_cnt          <= block_mover(i).word_wr_cnt + 1; -- advance word count
                            -- [exit] end of block reached now
                            if (block_mover(i).word_wr_cnt + 1 = block_mover(i).handle.blk_len) then -- stop at the last word
                                block_mover(i).lane_credit_update       <= to_unsigned(to_integer(block_mover(i).handle.blk_len),block_mover(i).lane_credit_update'length); -- return the credit to sink side (ingress_parser), as if whole blk is cleared
                                block_mover(i).lane_credit_update_valid <= '1';
                                block_mover(i).handle_rptr              <= block_mover(i).handle_rptr + 1;
                                block_mover(i).page_wreq                <= '0'; -- stop write as the last word has been grant in this cycle already
                                block_mover_state(i)                    <= IDLE;
                            end if;
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
                for j in 1 to FIFO_RAW_DELAY loop
                    if j = 1 then
                        handle_fifo_is_pending_handle_d(i)(j)        <= handle_fifo_is_pending_handle(i);
                    else
                        handle_fifo_is_pending_handle_d(i)(j)        <= handle_fifo_is_pending_handle_d(i)(j-1);
                    end if;
                end loop;

                for j in 1 to FIFO_RD_DELAY loop
                    if j = 1 then
                        block_mover(i).handle_rptr_d(j)          <= block_mover(i).handle_rptr;
                    else
                        block_mover(i).handle_rptr_d(j)          <= block_mover(i).handle_rptr_d(j-1);
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


    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            B2P_ARBITER
    -- @brief           grant the write access from block movers into page ram
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_b2p_arbiter : process (i_clk)
    begin
        if rising_edge (i_clk) then
            for i in 0 to N_LANE-1 loop
                -- update quantum : same amount of hits per subframe
                if (b2p_arb_gnt(i) = '1' and b2p_arb_req(i) = '1') then -- consuming
                    if (b2p_arb.quantum(i) > 0) then
                        b2p_arb.quantum(i)      <= b2p_arb.quantum(i) - 1;
                    else
                        b2p_arb.quantum(i)      <= (others => '0');
                    end if;
                end if;

                if (page_allocator_state = FETCH_TICKET and page_allocator_is_tk_future(i) = '0') then -- do not update if lane missing subframe, quantum is for each available subframe
                    b2p_arb.quantum(i)      <= b2p_arb.quantum(i) + b2p_arb_quantum_update_if_updating(i); -- + min(256,distance_to_full)
                    if (b2p_arb_gnt(i) = '1' and b2p_arb_req(i) = '1') then -- concurrent consuming
                        if (b2p_arb.quantum(i) > 0) then
                            b2p_arb.quantum(i)      <= b2p_arb.quantum(i) - 1 + b2p_arb_quantum_update_if_updating(i); -- we might deficit 1 when updating and consuming, check comb to see how we handle the case
                        else
                            if (b2p_arb_quantum_update_if_updating(i) > 0) then
                                b2p_arb.quantum(i)  <= b2p_arb_quantum_update_if_updating(i) - 1;
                            else
                                b2p_arb.quantum(i)  <= (others => '0');
                            end if;
                        end if;
                    end if;
                end if;
            end loop;

            case arbiter_state is -- note : only shift priority when release, so next cycle decision can be new
                when IDLE =>
                    -- any request to write to page ram from block mover
                    if or_reduce(b2p_arb_req) then
                        if or_reduce(b2p_arb_gnt) then -- grant in the same cycle
                            b2p_arb.sel_mask            <= b2p_arb_gnt;
                            arbiter_state               <= LOCKED;
                        else
                            arbiter_state               <= LOCKING;
                        end if;
                    end if;

                when LOCKING =>
                    if or_reduce(b2p_arb_gnt) then
                        b2p_arb.sel_mask            <= b2p_arb_gnt;
                        arbiter_state               <= LOCKED;
                    end if;

                when LOCKED =>
                    for i in 0 to N_LANE-1 loop
                        -- request from granted lane is de-asserted, release the lock
                        if (b2p_arb.sel_mask(i) = '1' and b2p_arb_req(i) = '0') then
                            arbiter_state               <= IDLE; -- [RELEASE - self]
                            b2p_arb.priority            <= b2p_arb.sel_mask(N_LANE-2 downto 0) & b2p_arb.sel_mask(N_LANE-1); -- derive the new priority, shift current selection to left by 1 lane
                        end if;
                        -- "timeout"
                        if (b2p_arb.quantum(i) <= 1) then
                            if (b2p_arb_gnt(i) = '1' and b2p_arb_req(i) = '1') then -- continue to consume, it is granted but quantum will be zero, release the lock
                                arbiter_state               <= IDLE; -- [RELEASE - force]
                                b2p_arb.priority            <= b2p_arb.sel_mask(N_LANE-2 downto 0) & b2p_arb.sel_mask(N_LANE-1);
                            end if;
                        end if;
                    end loop;
                    -- ...
                when RESET =>
                    b2p_arb                 <= B2P_ARB_REG_RESET;
                    arbiter_state           <= IDLE;

                when others =>
                    null;
            end case;

            -- conn.
            -- > page RAM
            -- latch the comb to reg
            page_ram_we                 <= page_ram_we_comb;
            page_ram_wr_addr            <= page_ram_wr_addr_comb;
            page_ram_wr_data            <= page_ram_wr_data_comb;

            if (i_rst = '1') then
                arbiter_state            <= RESET;
            end if;
        end if;
    end process;

	    proc_b2p_arbiter_comb : process (all)
	        variable result0        : std_logic_vector(N_LANE*2-1 downto 0);
	        variable result0p5      : std_logic_vector(N_LANE*2-1 downto 0);
	        variable result1        : std_logic_vector(N_LANE*2-1 downto 0);
	        variable result2        : std_logic_vector(N_LANE*2-1 downto 0);
	        variable req_raw        : std_logic_vector(N_LANE-1 downto 0);
	        variable req_eff        : std_logic_vector(N_LANE-1 downto 0);
	        variable req_use        : std_logic_vector(N_LANE-1 downto 0);
	        variable code           : std_logic_vector(CHANNEL_WIDTH-1 downto 0); -- find leading '1' position in binary
	        variable count          : unsigned(CHANNEL_WIDTH downto 0);
	        variable req            : std_logic; -- request from the current selected lane
	        variable pa_writing_v   : std_logic;
	    begin
	        -- default
	        code                    := (others => '0');
	        count                   := (others => '0');
	        req                     := '0';
	        req_raw                 := (others => '0');
	        req_eff                 := (others => '0');
	        req_use                 := (others => '0');
	        pa_writing_v            := '0';

	        if (page_allocator_state = WRITE_PAGE)
	           or (page_allocator_state = WRITE_HEAD)
	           or (page_allocator_state = WRITE_TAIL) then
	            pa_writing_v := '1';
	        end if;

	        -- input of request
	        for i in 0 to N_LANE-1 loop
	            -- IMPORTANT: the page allocator has priority on the page RAM port. When it is writing,
	            -- any concurrent block-mover "grant" would be dropped by the write mux, but the block mover
	            -- would still advance its counters (losing hit words). Gate requests during allocator writes
	            -- so a granted beat always corresponds to an actual page RAM write.
	            b2p_arb_req(i)     <= block_mover(i).page_wreq and not pa_writing_v;
	            req_raw(i)         := block_mover(i).page_wreq and not pa_writing_v;
	            -- DRR eligibility: only consider lanes with non-zero quantum, unless all eligible lanes are empty.
	            if (b2p_arb.quantum(i) /= to_unsigned(0, b2p_arb.quantum(i)'length)) then
	                req_eff(i)     := block_mover(i).page_wreq and not pa_writing_v;
	            else
	                req_eff(i)     := '0';
	            end if;
	        end loop;

        if or_reduce(req_eff) = '1' then
            req_use := req_eff;
        else
            -- Fallback for forward progress: if everyone is out of quantum, ignore quantum gating.
            req_use := req_raw;
        end if;

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
        result0		:= req_use & req_use;
        result0p5	:= not req_use & not req_use;
        result1		:= std_logic_vector(unsigned(result0p5) + unsigned(b2p_arb.priority));
        result2		:= result0 and result1;
        if (or_reduce(result2(N_LANE-1 downto 0)) = '0') then
            b2p_arb_gnt		    <= result2(N_LANE*2-1 downto N_LANE);
        else
            b2p_arb_gnt		    <= result2(N_LANE-1 downto 0);
        end if;

        if (arbiter_state = LOCKED) then -- you cannot freely hand over lock during a locked state, you must go back to idle with the new priority to decide who to grant next
            b2p_arb_gnt         <= b2p_arb.sel_mask;
        end if;

        -- Interrupt by page allocator: there is a single write port to the page RAM.
        -- If the allocator is scheduling a write this cycle (WRITE_PAGE / WRITE_HEAD / WRITE_TAIL),
        -- block movers must not see a grant, otherwise they can advance their counters even though
        -- the allocator will take the actual write.
        if (page_allocator.page_we = '1') then
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

        -- conn.
        -- > page RAM
        -- default
        page_ram_we_comb                 <= '0';
        page_ram_wr_addr_comb            <= (others => '0');
        page_ram_wr_data_comb            <= (others => '0');
        -- priority 1 : granted block mover if selected
        for i in 0 to N_LANE-1 loop
            if (unsigned(code) = i and or_reduce(b2p_arb_gnt) = '1') then -- if granted this lane
                if block_mover(i).page_wreq then -- if request is been made
                    page_ram_we_comb             <= '1';
                    page_ram_wr_addr_comb        <= std_logic_vector(block_mover(i).page_wptr + block_mover(i).word_wr_cnt);
                    page_ram_wr_data_comb        <= lane_fifos_rd_data(i);
                end if;
            end if;
        end loop;
        -- priority 0 : page allocator
        if (page_allocator_state = WRITE_PAGE) then
            page_ram_we_comb                 <= page_allocator.page_we;
            page_ram_wr_addr_comb            <= page_allocator.page_waddr;
            page_ram_wr_data_comb            <= page_allocator_if_write_page_shr_data;
        elsif (page_allocator_state = WRITE_HEAD or page_allocator_state = WRITE_TAIL) then
            page_ram_we_comb                 <= page_allocator.page_we;
            page_ram_wr_addr_comb            <= page_allocator.page_waddr;
            page_ram_wr_data_comb            <= page_allocator_if_write_page_hdr_data;
        end if;

        -- update quantum function
        for i in 0 to N_LANE-1 loop
            if (QUANTUM_MAX - b2p_arb.quantum(i) >= QUANTUM_PER_SUBFRAME) then -- no overflow : safe to update
                b2p_arb_quantum_update_if_updating(i)      <= QUANTUM_PER_SUBFRAME;
            else -- overflow : set to max
                if (b2p_arb_gnt(i) = '1' and b2p_arb_req(i) = '1') then -- if consuming at the same cycle : compensate for deficit 1
                    b2p_arb_quantum_update_if_updating(i)      <= QUANTUM_MAX - b2p_arb.quantum(i) + 1;
                else -- if not : update normally (set to max)
                    b2p_arb_quantum_update_if_updating(i)      <= QUANTUM_MAX - b2p_arb.quantum(i);
                end if;
            end if;
        end loop;
    end process;

    -- Optional :
    -- If the downstream IP can track the read pointer, the page ram should be expose to external with conduit. The read side is at the external IP's discretion.
    -- In that case, the frame table and frame tracker are not needed.
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            FTABLE_MAPPER
    -- @brief           map the allocator write access to (single) page ram to (multiple) page tile
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_frame_table_mapper : process (i_clk)
        variable next_wr_tile_i : natural range 0 to N_TILE-1;
        variable movers_done_v  : boolean;
    -- Map the input address to writers, i.e., allocator and mover, so they feel continous memeory but there data actually written to page ram with segmentation.
    -- Always write into N-1 segments, i.e., "active writing" and "shadow writing", the frame table presenter can void the shadow writing segment, while sacrifising its
    -- segment of "active reading".
    -- Presenter will show the ouput interface with the frame with lowest global timestamp in this frame table.
    -- The mapper shall use available region (segments of non-active reading) sequentially.
    -- wr : segment alpha and beta. alpha is current writing, beta is to be write if wrap-around. alpha and beta are mapped to individual tile number

    -- mapper - tracker - presenter
    begin
        if rising_edge (i_clk) then
            -- default
            ftable_mapper.update_ftable_valid               <= (others => '0');
            ftable_mapper.update_ftable_meta_valid          <= (others => '0');
            ftable_mapper.update_ftable_trltl_valid         <= (others => '0');
            ftable_mapper.update_ftable_bdytl_valid         <= (others => '0');
            ftable_mapper.flush_ftable_valid                <= (others => '0');
            ftable_mapper.update_ftable_hcmpl               <= (others => '0');

            case ftable_mapper_state is
                when IDLE => -- start by detecting allocator is writing a new head or finishing the last tail
                    if (page_allocator_state = WRITE_HEAD and page_allocator.write_meta_flow = 0) then -- latch the meta info of this frame
                        ftable_mapper.new_frame_raw_addr        <= page_allocator.frame_start_addr;
                        ftable_mapper.frame_shr_cnt             <= page_allocator.frame_shr_cnt_this / to_unsigned(N_LANE,page_allocator.frame_shr_cnt_this'length); -- declared sum of all subheaders at the ingress, it may be different from the aggregated ones
                        ftable_mapper.frame_hit_cnt             <= page_allocator.frame_hit_cnt_this;
                        ftable_mapper_state                     <= PREP_UPDATE;
                        ftable_mapper_expand_wr_tile_index_reg0 <= ftable_mapper_expand_wr_tile_index_0; -- [timing] (1/2) first calc based on wr seg
                    elsif (page_allocator_state = WRITE_TAIL and page_allocator.write_meta_flow = 3) then -- previous frame tail: finalize + mark packet ready (after movers drain)
                        -- Snapshot the previous frame meta now (page_allocator counters will be reset at the end of WRITE_TAIL).
                        ftable_mapper.pending_pkt_valid          <= '1';
                        ftable_mapper.pending_pkt_tindex         <= ftable_mapper.wseg_last_tile_pipe(1);
                        ftable_mapper.pending_pkt_meta           <= std_logic_vector(resize(
                                                                          page_allocator.frame_shr_cnt * to_unsigned(SHD_SIZE, page_allocator.frame_shr_cnt'length)
                                                                        + page_allocator.frame_hit_cnt * to_unsigned(HIT_SIZE, page_allocator.frame_hit_cnt'length)
                                                                        + HDR_SIZE + TRL_SIZE,
                                                                        PAGE_RAM_ADDR_WIDTH
                                                                      )) & std_logic_vector(page_allocator.frame_start_addr_last);
                        ftable_mapper.pending_pkt_drop           <= page_allocator.frame_invalid_last;
                        ftable_mapper.pending_pkt_handle_wptr    <= page_allocator.handle_wptr;
                        ftable_mapper_state                      <= MODIFY_FRAME_TABLE;
                    end if;

                when PREP_UPDATE => -- intermediate state between IDLE and UPDATE_FRAME_TABLE
                    if ftable_presenter_state /= WARPING then
                        ftable_mapper_state                     <= UPDATE_FRAME_TABLE;
                    end if;
                    ftable_mapper_update_ftable_spill_reg       <= ftable_mapper_update_ftable_spill; -- if current wr pkt will spill
                    ftable_mapper.leading_wseg                  <= ftable_mapper_leading_wr_seg_index; -- seg id (leading)
                    ftable_mapper_leading_wr_tile_index_reg     <= ftable_mapper_leading_wr_tile_index; -- tile id (leading)
                    ftable_mapper_expand_wr_tile_index_reg      <= ftable_mapper_expand_wr_tile_index; -- [timing] (2/2) second calc based on rd tile id (expanding)
                    ftable_mapper_update_ftable_fspan_reg       <= ftable_mapper_update_ftable_fspan; -- if spill, what is the span of its remainder in that tile it will go

	                when UPDATE_FRAME_TABLE => -- update tile fifos and manage the wr tiles
	                    if ftable_mapper_update_ftable_spill_reg then -- a) write will cross segment, generating spillover packet
                        -- write modification of wr tiles
                        if (ftable_mapper.leading_wseg < N_WR_SEG-1) then -- still space in the wr head : expand wr seg
                            for i in 0 to N_WR_SEG-1 loop
                                if (i > ftable_mapper.leading_wseg) then
                                    ftable_mapper.wseg(i).tile_index        <= ftable_mapper_expand_wr_tile_index_reg; -- expand the tiles of wr seg, rewrite the tile index of upper wr seg to new index
                                end if;
                            end loop;
                        else -- wr segs are fully expanded
                            if ftable_presenter.crossing_trid_valid then -- rd has locked two segments : shrink and scroll
                                for i in 0 to N_WR_SEG-3 loop -- 0 to 1
                                    ftable_mapper.wseg(i).tile_index            <= ftable_mapper.wseg(i+1).tile_index;
                                end loop;
                                for i in N_WR_SEG-2 to N_WR_SEG-1 loop -- 2 to 3
                                    ftable_mapper.wseg(i).tile_index            <= ftable_mapper.wseg(0).tile_index; -- last two seg will be repeat of wseg(0), some strange action as shrink-scroll
                                end loop;
                            else -- rd has not locked two segments : scroll
                                for i in 0 to N_WR_SEG-2 loop -- 0 to 2
                                    ftable_mapper.wseg(i).tile_index            <= ftable_mapper.wseg(i+1).tile_index;
                                end loop;
                                ftable_mapper.wseg(N_WR_SEG-1).tile_index       <= ftable_mapper_expand_wr_tile_index_reg; -- set the active tile to correct tile index
                            end if;
                        end if;

	                        -- note: there are two heads of mapper -> tracker
	                        -- write to tracker[tile_index] = {meta(header_addr,pkt_length), *where_is_trail}
	                        --         *tracker[tile_index] = {*where_is_head}
	                        -- * : only for spillover case
	                        ftable_mapper.update_ftable_valid           <= "11";
	                        ftable_mapper.update_ftable_tindex(0)       <= ftable_mapper_leading_wr_tile_index_reg; -- current tile id
	                        ftable_mapper.update_ftable_trltl_valid(0)  <= '1';
	                        ftable_mapper.update_ftable_trltl(0)        <= ftable_mapper_expand_wr_tile_index_reg; -- where is trail

                        ftable_mapper.update_ftable_tindex(1)       <= ftable_mapper_expand_wr_tile_index_reg; -- write to next tile
                        ftable_mapper.update_ftable_bdytl_valid(1)  <= '1';
                        ftable_mapper.update_ftable_bdytl(1)        <= ftable_mapper_leading_wr_tile_index_reg; -- link to head tile
                        ftable_mapper.flush_ftable_valid(1)         <= '1';

                        -- 3 debug header word will be written in the next pkt, but it can be scattered in different tiles as current pkt will spill
                        for i in 0 to 2 loop
                            if (i >= 0 and i <= 1) then -- debug word 3 and 4
                                if (ftable_mapper.new_frame_raw_addr + to_unsigned(3+i,PAGE_RAM_ADDR_WIDTH) > ftable_mapper.new_frame_raw_addr) then -- not overflow yet
                                    ftable_mapper.last_pkt_dbg_tile_index(0)(i)        <= ftable_mapper_leading_wr_tile_index_reg;
                                else -- overflow : tile id is the expanding one
                                    ftable_mapper.last_pkt_dbg_tile_index(0)(i)        <= ftable_mapper_expand_wr_tile_index_reg;
                                end if;
                            else -- trailer = debug word 5
                                ftable_mapper.last_pkt_dbg_tile_index(0)(i)        <= ftable_mapper_expand_wr_tile_index_reg; -- trailer will definitely go to next tile
	                            end if;
	                        end loop;
	                    else -- b) write frame will not cross segment, normal write
	                        -- Do not enqueue tile FIFO meta here. The exact frame span is only finalized when the
	                        -- next frame starts (trailer address becomes known). We enqueue the meta at
	                        -- MODIFY_FRAME_TABLE using the actual aggregated counters.

	                        -- 3 debug header word will be in the current tile due to pkt will not spill
	                        for i in 0 to 2 loop
	                            ftable_mapper.last_pkt_dbg_tile_index(0)(i)    <= ftable_mapper_leading_wr_tile_index_reg;
                        end loop;
                    end if;

                    ftable_mapper.wseg_last_tile_pipe(0)           <= ftable_mapper_leading_wr_tile_index_reg; -- record the tile of this pkt
                    ftable_mapper.wseg_last_tile_pipe(1)           <= ftable_mapper.wseg_last_tile_pipe(0);

                    ftable_mapper.last_pkt_dbg_tile_index(1)       <= ftable_mapper.last_pkt_dbg_tile_index(0);
                    ftable_mapper_state                            <= IDLE; -- write will be done in 1 cycle

                when MODIFY_FRAME_TABLE => -- finalize previous frame only when safe to present
                    -- Wait until:
                    --  1) page_allocator finished writing the tail words (hdr[3:4] + trailer), and
                    --  2) all block movers completed the handles belonging to that frame.
                    --
                    -- Otherwise the presenter can start reading a frame whose hit blocks are still
                    -- being written (stale/zero hits, broken subheader->hit association).
                    if (ftable_mapper.pending_pkt_valid = '1') then
                        movers_done_v := true;
                        for i in 0 to N_LANE-1 loop
                            if (block_mover(i).handle_rptr /= ftable_mapper.pending_pkt_handle_wptr(i)) then
                                movers_done_v := false;
                            end if;
                        end loop;

	                        if (page_allocator_state /= WRITE_TAIL) and movers_done_v then
	                            ftable_mapper_state                         <= IDLE;
	                            ftable_mapper.pending_pkt_valid             <= '0';
	                            ftable_mapper.pending_pkt_drop              <= '0';

	                            if (ftable_mapper.pending_pkt_drop = '1') then
	                                -- Drop the whole frame instead of presenting a broken packet.
	                                -- Flush the tile FIFO + spill regs so the presenter won't observe stale meta.
	                                ftable_mapper.flush_ftable_valid(0)      <= '1';
	                                ftable_mapper.update_ftable_tindex(0)    <= ftable_mapper.pending_pkt_tindex;
	                                ftable_mapper_last_pkt_spilled           <= '0';
	                            else
	                                -- Enqueue tile FIFO meta for the completed frame.
	                                ftable_mapper.update_ftable_valid           <= "01";
	                                ftable_mapper.update_ftable_tindex(0)       <= ftable_mapper.pending_pkt_tindex;
	                                ftable_mapper.update_ftable_meta_valid(0)   <= '1';
	                                ftable_mapper.update_ftable_meta(0)         <= ftable_mapper.pending_pkt_meta;
	                                ftable_mapper.update_ftable_hcmpl(0)        <= '1';

	                                -- record for next time we fill the debug word for this pkt, if this pkt has spilled
	                                if ftable_mapper_update_ftable_spill_reg then
	                                    ftable_mapper_last_pkt_spilled          <= '1';
	                                else
	                                    ftable_mapper_last_pkt_spilled          <= '0';
	                                end if;
	                            end if;

	                            -- If the read side is actively holding the current write tile (e.g. long egress stall),
	                            -- don't keep allocating *future* packets into that same tile. Advance the write window
                            -- (wseg) to the next available tile to avoid partial overwrites.
                            --
                            -- IMPORTANT: Do not change `ftable_mapper_leading_wr_tile_index_reg` here. That register
                            -- is used to map in-flight page RAM writes (block movers) for the *current* packet. Changing
                            -- it mid-packet can redirect late hit writes into a different tile than the tile FIFO meta,
                            -- producing missing/zero hits at egress.
                            if (ftable_presenter_state /= IDLE) and (ftable_presenter.rseg.tile_index = ftable_mapper_leading_wr_tile_index_reg) then
                                next_wr_tile_i := (to_integer(ftable_mapper_leading_wr_tile_index_reg) + 1) mod N_TILE;
                                -- Skip the locked read tile and (if applicable) the locked crossing tile.
                                if (next_wr_tile_i = to_integer(ftable_presenter.rseg.tile_index)) then
                                    next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                                end if;
                                if ftable_presenter.crossing_trid_valid then
                                    if (next_wr_tile_i = to_integer(ftable_presenter.crossing_trid)) then
                                        next_wr_tile_i := (next_wr_tile_i + 1) mod N_TILE;
                                    end if;
                                end if;

                                -- The next tile may still contain unread packets; we're about to overwrite it.
                                -- Flush its tile FIFO + regs so the presenter won't output stale headers.
                                ftable_mapper.flush_ftable_valid(1)    <= '1';
                                ftable_mapper.update_ftable_tindex(1)  <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);

                                for i in 0 to N_WR_SEG-2 loop
                                    ftable_mapper.wseg(i).tile_index <= ftable_mapper.wseg(i+1).tile_index;
                                end loop;
                                ftable_mapper.wseg(N_WR_SEG-1).tile_index <= to_unsigned(next_wr_tile_i, TILE_ID_WIDTH);
                            end if;
                        end if;
                    else
                        ftable_mapper_state <= IDLE;
                    end if;

                when RESET =>
                    ftable_mapper                           <= FTABLE_MAPPER_REG_RESET;
                    -- Keep the derived "current write tile" regs consistent with the reset wseg mapping.
                    -- Otherwise the first header word can be written to a different tile than the tile FIFO meta.
	                    ftable_mapper_leading_wr_tile_index_reg <= to_unsigned(N_TILE-1, TILE_ID_WIDTH); -- wseg(N_WR_SEG-1) at reset
	                    ftable_mapper_expand_wr_tile_index_reg  <= (others => '0');
	                    ftable_mapper_expand_wr_tile_index_reg0 <= 0;
	                    ftable_mapper_update_ftable_fspan_reg   <= (others => '0');
	                    ftable_mapper_update_ftable_spill_reg   <= '0';
	                    ftable_mapper_last_pkt_spilled          <= '0';
	                    ftable_mapper_state                     <= IDLE;

                when others =>
                    null;
            end case;

            -- read modification of wr tiles
            -- if (ftable_presenter_state = WARPING) then
            --     ftable_mapper.mgmt_tiles_start     <= '1';
            -- end if;

            if (ftable_presenter_state = WARPING) then -- rd only mod seg in warping, rd avoids wr, rd always after wr
                if ftable_presenter_is_rd_tile_in_range then -- rd in range : check if rd moved
                    if ftable_mapper_rd_tile_in_wr_seg > 0 then -- rd moved : wr shrink
                        for i in 0 to N_WR_SEG-2 loop
                            ftable_mapper.wseg(i).tile_index            <= ftable_mapper.wseg(i+1).tile_index; -- effective shrink one tile
                        end loop;
                    end if;
                else -- rd out of range : wr do nothing
                end if;
            end if;

            -- connections
            -- > page ram wr
            page_tile_we                    <= (others => '0');
            for i in 0 to N_TILE-1 loop
                if (ftable_mapper_writing_tile_index = i) then
                    page_tile_wr_addr(i)            <= page_ram_wr_addr;
                    page_tile_wr_data(i)            <= page_ram_wr_data;
                    if (ftable_wr_blocked_by_rd_lock = '1') then
                        page_tile_we(i)                 <= '0';
                    else
                        page_tile_we(i)                 <= page_ram_we;
                    end if;
                end if;
            end loop;
            -- ftable_mapper.writing_tile_index        <= ftable_mapper_writing_tile_index; -- latch the current leading tile index which will be the updated one

            if (i_rst = '1') then
                ftable_mapper_state             <= RESET;
            end if;

        end if;
    end process;

	    proc_frame_table_mapper_comb : process (all)
	        variable expected_new_wr_tile_index          : natural range 0 to N_TILE-1;
	        variable expected_new_wr_tile_index_rd       : natural range 0 to N_TILE-1;
	        variable leading_wr_seg_index_v              : natural range 0 to N_WR_SEG-1;
	        variable leading_wr_tile_index_v             : natural range 0 to N_TILE-1;
	    begin
        -- derive the if spill flag
        ftable_mapper_update_ftable_fspan <= resize(
            ftable_mapper.frame_shr_cnt * to_unsigned(SHD_SIZE, ftable_mapper.frame_shr_cnt'length)
          + ftable_mapper.frame_hit_cnt * to_unsigned(HIT_SIZE, ftable_mapper.frame_hit_cnt'length)
          + HDR_SIZE + TRL_SIZE,
          ftable_mapper_update_ftable_fspan'length
        ); -- write the max span of this frame
        if (to_integer(ftable_mapper.new_frame_raw_addr) + to_integer(ftable_mapper_update_ftable_fspan) > PAGE_RAM_DEPTH) then -- if the packet will be spill
            ftable_mapper_update_ftable_spill           <= '1';
        else
            ftable_mapper_update_ftable_spill           <= '0';
        end if;
        -- if spill, what is the remainder unusable part in the expanding tile
        ftable_mapper_update_ftable_trail_span      <= to_unsigned(to_integer(ftable_mapper.new_frame_raw_addr) + to_integer(ftable_mapper_update_ftable_fspan) - PAGE_RAM_DEPTH, ftable_mapper_update_ftable_trail_span'length);

	        -- Calculate the leading WR segment (head) deterministically.
	        -- We want the highest segment index where the tile changes, i.e. the newest/active tile.
	        leading_wr_seg_index_v := 0;
	        for i in 0 to N_WR_SEG-2 loop
	            if (ftable_mapper.wseg(i+1).tile_index /= ftable_mapper.wseg(i).tile_index) then
	                leading_wr_seg_index_v := i+1;
	            end if;
	        end loop;
	        ftable_mapper_leading_wr_seg_index          <= to_unsigned(leading_wr_seg_index_v, TILE_ID_WIDTH);

	        leading_wr_tile_index_v := to_integer(ftable_mapper.wseg(leading_wr_seg_index_v).tile_index);
	        ftable_mapper_leading_wr_tile_index         <= ftable_mapper.wseg(leading_wr_seg_index_v).tile_index;

	        -- calculate the tile index of expanding wr seg, taking into account of the read seg (current active and prelocked)
	        expected_new_wr_tile_index          := (leading_wr_tile_index_v + 1) mod N_TILE; -- new tile is (leading tile + 1)
	        ftable_mapper_expand_wr_tile_index_0        <= expected_new_wr_tile_index; -- [timing] do pipeline outside

        expected_new_wr_tile_index_rd               := ftable_mapper_expand_wr_tile_index_reg0; -- [timing] connect reg0 inside again
        if (ftable_mapper_expand_wr_tile_index_reg0 = ftable_presenter.rseg.tile_index) then -- if read seg lock, jump over one tile further
            expected_new_wr_tile_index_rd           := (ftable_mapper_expand_wr_tile_index_reg0 + 1) mod N_TILE;
        end if;
        ftable_mapper_expand_wr_tile_index   <= to_unsigned(expected_new_wr_tile_index_rd,TILE_ID_WIDTH);
        if (ftable_presenter.crossing_trid_valid) then -- if read shadow lock, jump over one tile further
            if expected_new_wr_tile_index_rd = ftable_presenter.crossing_trid then
                ftable_mapper_expand_wr_tile_index      <= to_unsigned((expected_new_wr_tile_index_rd + 1) mod N_TILE,TILE_ID_WIDTH);
            end if;
        end if;

        -- derive the wr seg index based on current rd tile index
        ftable_mapper_rd_tile_in_wr_seg         <= (others => '0');
        for i in N_WR_SEG-1 downto 0 loop
            if ftable_mapper.wseg(i).tile_index = ftable_presenter.rseg.tile_index then
                ftable_mapper_rd_tile_in_wr_seg        <= to_unsigned(i,TILE_ID_WIDTH);
            end if;
        end loop;

        -- connect wr heads to page ram complex (select which page ram)
        if ftable_mapper_update_ftable_spill_reg then -- current frame will spill over two tiles
            if (unsigned(page_ram_wr_addr) >= ftable_mapper.new_frame_raw_addr) then -- not overflow
                ftable_mapper_writing_tile_index                <= ftable_mapper_leading_wr_tile_index_reg;
            else -- overflowing
                ftable_mapper_writing_tile_index                <= ftable_mapper_expand_wr_tile_index_reg;
            end if;
            if (ftable_mapper_state = PREP_UPDATE) then -- glitch : the ftable_mapper_update_ftable_spill_reg is not updated (is for last pkt), so current pkt will be update after this cycle. because last pkt will spill, we should use the expanding anyways
                ftable_mapper_writing_tile_index                <= ftable_mapper_expand_wr_tile_index_reg;
            end if;
        else
            ftable_mapper_writing_tile_index                    <= ftable_mapper_leading_wr_tile_index_reg;
        end if;
        -- wr last pkt debug word, can scatter in different tiles
        -- IMPORTANT: gate this override to *page_allocator* meta writes only.
        -- `write_meta_flow_d1` can hold stale values while the allocator is idle; without gating,
        -- late block-mover hit writes can be redirected into the debug-word tiles (corrupt frames).
        if (page_allocator_state = WRITE_HEAD) or (page_allocator_state = WRITE_TAIL) then
            for i in 3 to 5 loop
                if (i = page_allocator.write_meta_flow_d1) then
                    ftable_mapper_writing_tile_index                <= ftable_mapper.last_pkt_dbg_tile_index(1)(i-3);
                end if;
            end loop;
        end if;
    end process;

    proc_ftable_wr_lock_guard_comb : process (all)
    begin
        ftable_wr_blocked_by_rd_lock <= '0';
        if (page_ram_we = '1') and ((ftable_presenter_state = PRESENTING) or (ftable_presenter_state = RESTART)) then
            if (ftable_mapper_writing_tile_index = ftable_presenter.rseg.tile_index) then
                ftable_wr_blocked_by_rd_lock <= '1';
            elsif (ftable_presenter.trailing_active(0) = '1')
               and (ftable_mapper_writing_tile_index = ftable_presenter.trailing_tile_index) then
                ftable_wr_blocked_by_rd_lock <= '1';
            end if;
        end if;
    end process;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            FTABLE_TRACKER
    -- @brief           track location of packets
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_frame_table_tracker : process (i_clk)
    -- tracks each tile's header starting address, remainder span, trail tile id
    -- write can push in new starting address, which is stored in a FIFO made out of DP-RAM
    -- write can modify the remainder span and trail tile id, which are stored in auxillary registers
    -- read can flush the tile by deleted all starting addresses, remainder span and trail tile id
    -- the valid of starting addresses is managed by read and write pointers
    -- the modify of the registers are managed by their valid bit
    begin
        if rising_edge (i_clk) then
            -- default
            ftable_tracker.tile_we                          <= (others => '0');

            -- 1) Command from mapper
            if (or_reduce(ftable_mapper.flush_ftable_valid) = '1') then -- priority 0 : flush the tile (delay 1 cycle, so we flush first before record)
                -- reset the tile write pointer to match the read pointer, effectively flush the tile fifo
                for a in 0 to 1 loop
                    for i in 0 to N_TILE-1 loop
                        if (to_integer(ftable_mapper.update_ftable_tindex(a)) = i) then -- tile address resolution of this head
                            if (ftable_mapper.flush_ftable_valid(a) = '1') then
                                tile_regs.trail_tid(i)              <= (others => '0');
                                tile_regs.body_tid(i)               <= (others => '0');
                                -- Drop any packets currently queued in this tile.
                                -- Align write/read pointers and packet counters so the presenter won't
                                -- observe stale meta (broken packets after overwrite).
                                ftable_tracker.tile_wptr(i)         <= ftable_presenter.tile_rptr(i);
                                ftable_tracker.tile_pkt_wcnt(i)     <= ftable_presenter.tile_pkt_rcnt(i);
                            end if;
                        end if;
                    end loop;
                end loop;
            end if;

            case ftable_tracker_state is
                when IDLE =>
                    if (or_reduce(ftable_mapper.update_ftable_valid) = '1') then -- update request valid (only valid for 1 cycle)
                        -- latch the command signals from mapper
                        ftable_tracker.update_ftable_valid          <= ftable_mapper.update_ftable_valid;
                        ftable_tracker.update_ftable_tindex         <= ftable_mapper.update_ftable_tindex;
                        ftable_tracker.update_ftable_meta_valid     <= ftable_mapper.update_ftable_meta_valid;
                        ftable_tracker.update_ftable_meta           <= ftable_mapper.update_ftable_meta;
                        ftable_tracker.update_ftable_trltl_valid    <= ftable_mapper.update_ftable_trltl_valid;
                        ftable_tracker.update_ftable_trltl          <= ftable_mapper.update_ftable_trltl;
                        ftable_tracker.update_ftable_bdytl_valid    <= ftable_mapper.update_ftable_bdytl_valid;
                        ftable_tracker.update_ftable_bdytl          <= ftable_mapper.update_ftable_bdytl;
                        ftable_tracker.update_ftable_hcmpl          <= ftable_mapper.update_ftable_hcmpl;
                        -- ftable_tracker.flush_ftable_valid           <= ftable_mapper.flush_ftable_valid;
                        ftable_tracker_state                        <= RECORD_TILE; -- priority 1 : record meta info into this tile
                    end if;

                    if (or_reduce(ftable_tracker.update_ftable_valid) = '1') then
                        ftable_tracker_state                        <= RECORD_TILE; -- priority 1 : record meta info into this tile (second entry)
                    end if;

                when RECORD_TILE => -- write the mapper meta data into the tile FIFO complex (delay 2 cycles)
                    for a in 0 to 1 loop
                        for i in 0 to N_TILE-1 loop
                            if (to_integer(ftable_tracker.update_ftable_tindex(a)) = i) then -- tile address resolution of this head
                                if ftable_tracker.update_ftable_meta_valid(a) then -- pkt header address in page ram
                                    ftable_tracker.tile_we(i)       <= '1';
                                    ftable_tracker.tile_wptr(i)     <= ftable_tracker.tile_wptr(i) + 1;
                                    ftable_tracker.tile_wdata(i)    <= ftable_tracker.update_ftable_meta(a);
                                end if;
                                if ftable_tracker.update_ftable_trltl_valid(a) then -- where to look for if the pkt has spilling to other tile
                                    tile_regs.trail_tid(i)          <= '1' & ftable_tracker.update_ftable_trltl(a); -- msb is not used
                                end if;
                                if ftable_tracker.update_ftable_bdytl_valid(a) then -- tile id of body of spilling pkt from other tile
                                    tile_regs.body_tid(i)(tile_regs.body_tid(i)'length-2 downto 0)     <= ftable_tracker.update_ftable_bdytl(a); -- unlocked (needs to be active by rd, notify wr to not overwrite this seg)
                                end if;
                                if ftable_tracker.update_ftable_hcmpl(a) then -- incr write pkt counter
                                    ftable_tracker.tile_pkt_wcnt(i) <= ftable_tracker.tile_pkt_wcnt(i) + 1;
                                end if;
                            end if;
                        end loop;
                    end loop;
                    -- after execution : deassert the command signals
                    ftable_tracker.update_ftable_valid              <= (others => '0');
                    ftable_tracker.update_ftable_meta_valid         <= (others => '0');
                    ftable_tracker.update_ftable_trltl_valid        <= (others => '0');
                    ftable_tracker.update_ftable_bdytl_valid        <= (others => '0');
                    ftable_tracker.update_ftable_hcmpl              <= (others => '0');
                    ftable_tracker_state                            <= IDLE;

                when RESET =>
                    ftable_tracker_state                        <= IDLE;
                    ftable_tracker                              <= FTABLE_TRACKER_REG_RESET;

                when others =>
                    null;
            end case;

            -- 2) Modify from presenter
            -- delete body pointer of current rd tile as we have crossing packet
            if (ftable_presenter.void_body_tid = '1') then
                for i in 0 to N_TILE-1 loop
                    if (to_integer(ftable_presenter.rseg.tile_index) = i) then
                        tile_regs.body_tid(i)(tile_regs.body_tid(i)'high)       <= '0'; -- void the valid bit of this reg
                    end if;
                end loop;
            end if;
            -- delete trail tile id of current rd tile as no pkt is available
            if (ftable_presenter.void_trail_tid = '1') then
                for i in 0 to N_TILE-1 loop
                    if (to_integer(ftable_presenter.rseg.tile_index) = i) then
                        tile_regs.trail_tid(i)(tile_regs.trail_tid(i)'high)                 <= '0'; -- void the valid bit of this reg
                    end if;
                end loop;
            end if;

            if (i_rst = '1') then
                ftable_tracker_state                <= RESET;
            end if;
        end if;
    end process;

    proc_frame_table_tracker_comb : process (all)
    begin
        -- connections
        -- tile fifos >
        for i in 0 to N_TILE-1 loop
            tile_fifos_wr_addr(i)                   <= std_logic_vector(ftable_tracker.tile_wptr(i) - 1);
            tile_fifos_we(i)                        <= ftable_tracker.tile_we(i);
            tile_fifos_wr_data(i)                   <= ftable_tracker.tile_wdata(i);
        end loop;
    end process;


    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            FTABLE_PRESENTER
    -- @brief           present available packet
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_frame_table_presenter : process (i_clk)
    -- present outside with valid signal, sticky until the full packet has been transmitted
    -- trace to the next tile if the packet is spillover
    -- once all packets in current tile are read, wrap to the tile containing to the tail of the write seg
    --
        variable any_tile_has_head : boolean;
    begin
        if rising_edge(i_clk) then
            -- default
            ftable_presenter.void_trail_tid             <= '0';
            ftable_presenter.void_body_tid              <= '0';
            ftable_presenter.output_data_valid          <= (others => '0');

            -- Determine whether there is any queued packet meta in any tile. This guards "empty warps"
            -- at reset/idle which can otherwise shrink the WR window before any packet exists.
            any_tile_has_head := false;
            for t in 0 to N_TILE-1 loop
                if (ftable_tracker.tile_wptr(t) /= ftable_presenter.tile_rptr(t)) then
                    any_tile_has_head := true;
                end if;
            end loop;

            case ftable_presenter_state is
                when IDLE =>
                    if ftable_presenter_is_new_pkt_head then -- rd slow : read pending pkt in rd tile
                        ftable_presenter_state                  <= WAIT_FOR_COMPLETE;
                    end if;
                    if ftable_presenter.rseg.tile_index = ftable_mapper_leading_wr_tile_index_reg then -- rd fast but not away : wait here for pkt
                        if ftable_presenter_is_new_pkt_head then
                            ftable_presenter_state                  <= WAIT_FOR_COMPLETE;
                        end if;
                    else -- wr fast and away : warp
                        if any_tile_has_head then
                            if (ftable_mapper_state = PREP_UPDATE or ftable_mapper_state = UPDATE_FRAME_TABLE or (page_allocator_state = WRITE_HEAD and page_allocator.write_meta_flow = 0)) then -- contention : freeze. wr is modifying the tiles, rd will freeze here
                                -- 3 cycles of stall, wr will modify the tiles here
                            else -- contention : ok
                                ftable_presenter_state                  <= WARPING;
                                -- free up current rd tile fifo
                                for i in 0 to N_TILE-1 loop
                                    if (to_integer(ftable_presenter.rseg.tile_index) = i) then -- select the current read tile
                                        ftable_presenter.tile_rptr(i)           <= ftable_tracker.tile_wptr(i); -- set the r to w ptr (flush fifo)
                                        ftable_presenter.tile_pkt_rcnt(i)       <= (others => '0'); -- fresh tile will read from 0
                                    end if;
                                end loop;
                                -- set new rd seg tile index
                                if ftable_presenter_is_rd_tile_in_range then -- in range : warp to next wr tile
                                    ftable_presenter.rseg.tile_index        <= ftable_presenter_if_in_range_warp_rd_tile;
                                else -- out of range : warp to tail of wr
                                    ftable_presenter.rseg.tile_index        <= ftable_mapper.wseg(0).tile_index;
                                end if;
                            end if;
                        end if;
                    end if;

	                when WAIT_FOR_COMPLETE => -- wait for packet to be completed
	                    if ftable_presenter_is_new_pkt_complete then
	                        -- Packet complete: start presenting. Write-side must avoid read-locked tiles
	                        -- (see ftable_wr_blocked_by_rd_lock + mapper policy); do not drop here.
	                        ftable_presenter_state                  <= PRESENTING;
	                        for i in 0 to N_TILE-1 loop
	                            -- set the read pointer to present the packet
	                            if (to_integer(ftable_presenter.rseg.tile_index) = i) then
	                                ftable_presenter.page_ram_rptr(i)       <= ftable_presenter_leading_header_addr;
	                            end if;
	                        end loop;
	                        ftable_presenter.pkt_rd_word_cnt        <= (others => '0');

	                        -- [crossing] : skip if bond is broken
	                        if ftable_presenter_is_pkt_spilling then -- verify if the bond is still valid
	                            for i in 0 to N_TILE-1 loop
	                                if (to_integer(ftable_presenter.rseg.tile_index) = i) then
	                                    ftable_presenter.crossing_trid  <= tile_regs.trail_tid(i)(tile_regs.trail_tid(i)'length-2 downto 0); -- latch the trail tile id
	                                end if;
	                            end loop;
	                            ftable_presenter_state              <= VERIFY;
	                        end if;
	                    end if;

                when VERIFY =>
                    for i in 0 to N_TILE-1 loop
                        if (to_integer(ftable_presenter.crossing_trid) = i) then
                            if (tile_regs.body_tid(i)(tile_regs.body_tid(i)'length-2 downto 0) = ftable_presenter.rseg.tile_index) then -- ok : link verified (body[trail id] = trail[body id])
                                ftable_presenter_state                      <= PRESENTING;
                                ftable_presenter.crossing_trid_valid        <= '1';
                            else -- broken : jump to tail of wr tile for reading of new pkt
                                ftable_presenter_state                      <= IDLE;
                                ftable_presenter.tile_pkt_rcnt(i)           <= ftable_presenter.tile_pkt_rcnt(i) + 1; -- skip this pkt
                                ftable_presenter.tile_rptr(i)               <= ftable_presenter.tile_rptr(i) + 1;
                            end if;
                        end if;
                    end loop;

                when PRESENTING => -- continue to allow read to consume the packet
                    ftable_presenter.output_data_valid(0)           <= '1'; -- preparing data...
                    -- counter of rd word
                    if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '1' and aso_egress_ready = '1') then
                        ftable_presenter.pkt_rd_word_cnt            <= ftable_presenter.pkt_rd_word_cnt + 1;
                    end if;
                    -- pipeline egress data valid bit
                    for i in 0 to EGRESS_DELAY-1 loop
                        ftable_presenter.output_data_valid(i+1)     <= ftable_presenter.output_data_valid(i);
                    end loop;
                    -- pipe through the data
                    -- During an egress stall, hold the breakpoint word stable.
                    if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then
                        ftable_presenter.output_data            <= page_ram_rd_data;
                    end if;

                    for i in 0 to N_TILE-1 loop
                        -- incr rd ptr
                        -- During pipeline fill (valid has not reached the egress yet), ignore ready.
                        -- Once valid is at the egress, only advance on ready=1.
                        if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then
                            if ftable_presenter.trailing_active(0) then -- ghost
                                if (ftable_presenter.trailing_tile_index = i) then
                                    ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1;
                                end if;
                            elsif (ftable_presenter.rseg.tile_index = i) then -- normal
                                ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) + 1;
                            end if;
                        end if;

                        -- read logic
                        if (ftable_presenter.rseg.tile_index = i) then
                            if (aso_egress_ready = '1') then
                                if ftable_presenter_output_is_trailer then -- [exit] : seen trailer, this packet has finished
                                    ftable_presenter_state                                  <= IDLE;
                                    ftable_presenter.output_data_valid                      <= (others => '0'); -- data stop now!
                                    if (ftable_presenter.trailing_active(0) = '1') then -- we have switched tile, deassert trail span of aux reg as read has finished
                                        ftable_presenter.trailing_active(0)         <= '0';
                                        ftable_presenter.void_body_tid              <= '1'; -- not necessary
                                        ftable_presenter.crossing_trid_valid        <= '0'; -- deassert the 2 rd seg flag
                                    end if;
                                    ftable_presenter.tile_pkt_rcnt(i)           <= ftable_presenter.tile_pkt_rcnt(i) + 1; -- incr rd counter
                                    ftable_presenter.tile_rptr(i)               <= ftable_presenter.tile_rptr(i) + 1; -- incr rd ptr
                                elsif ((to_integer(ftable_presenter.page_ram_rptr(i)) = PAGE_RAM_DEPTH-1) and ftable_presenter_is_pkt_spilling = '1') then -- warp to next tile
                                    ftable_presenter.trailing_active(0)         <= '1'; -- tracing the trail packet
                                    ftable_presenter.trailing_tile_index        <= ftable_presenter.crossing_trid; -- ftable_presenter_trail_tile_id; -- switch tile ghostly
                                    ftable_presenter.page_ram_rptr(i)           <= (others => '0'); -- this tile is finished, reset rd ptr
                                end if;
                            else -- corner case : ready deasserted during packet transmission
                                -- The internal page RAM pipeline cannot be fully frozen under backpressure
                                -- (the RAM has registered outputs), so restart by rolling back the read pointer
                                -- to the current output word and refilling the pipeline before resuming.
                                if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '1') then
                                    ftable_presenter_state                      <= RESTART;
                                    ftable_presenter.page_ram_rptr(i)           <= ftable_presenter.page_ram_rptr(i) - to_unsigned(EGRESS_DELAY+1,PAGE_RAM_ADDR_WIDTH); -- rptr scrollback
                                    ftable_presenter.output_data_valid          <= (others => '0'); -- restart pipeline
                                end if;
                            end if;
                        end if;
                    end loop;

                when RESTART => -- refill the page RAM pipeline after a backpressure event
                    -- Re-read starting at the stalled output word address (rptr already rolled back).
                    -- We don't assert `valid` externally in this state (see egress comb) to avoid double-accept.
                    for i in 0 to N_TILE-1 loop
                        if (to_integer(ftable_presenter.rseg.tile_index) = i) then
                            -- keep refilling until the word reaches the egress tap
                            ftable_presenter.output_data_valid(0)       <= '1';
                            for j in 0 to EGRESS_DELAY-1 loop
                                ftable_presenter.output_data_valid(j+1) <= ftable_presenter.output_data_valid(j);
                            end loop;
                            ftable_presenter.output_data            <= page_ram_rd_data;

                            if (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then
                                ftable_presenter.page_ram_rptr(i)       <= ftable_presenter.page_ram_rptr(i) + 1;
                            end if;
                            -- transition when the last shift will make the egress tap valid
                            if (ftable_presenter.output_data_valid(EGRESS_DELAY-1) = '1') then
                                ftable_presenter_state                  <= PRESENTING;
                            end if;
                        end if;
                    end loop;

                when WARPING => -- set to rd tile to the tail of wr tile TODO: remove this state, it might cause contention. the wr will use it, so better do it fast in IDLE
                    -- if ftable_presenter_is_rd_tile_in_range then -- in range : go to next wr tile (incr wr seg index)
                    --     ftable_presenter.rseg.tile_index        <= ftable_presenter_if_in_range_warp_rd_tile;
                    -- else -- out of range : set rd tile to the tail of wr tiles
                    --     ftable_presenter.rseg.tile_index        <= ftable_mapper.wseg(0).tile_index; --
                    -- end if;
                    ftable_presenter_state                  <= IDLE;

                when RESET =>
                    ftable_presenter_state                  <= IDLE;
                    ftable_presenter                        <= FTABLE_PRESENTER_REG_RESET;

                when others =>
                    null;
            end case;

            -- flushing tile fifo
            for a in 0 to 1 loop
                for i in 0 to N_TILE-1 loop
                    if (to_integer(ftable_tracker.update_ftable_tindex(a)) = i) then -- get which tile needs to be flushed, note: refactor this design!
                        if (ftable_tracker.flush_ftable_valid(a) = '1') then
                            ftable_presenter.tile_rptr(i)           <= ftable_tracker.tile_wptr(i); -- set r to w ptr, effectively empty the fifo
                            ftable_presenter.tile_pkt_rcnt(i)       <= (others => '0');
                        end if;
                    end if;
                end loop;
            end loop;

            -- tile fifo > [rd:data]
            -- (pointer: where the data is in the page ram, length: for detecting spilling)
            for i in 0 to N_TILE-1 loop
                if (to_integer(ftable_presenter.rseg.tile_index) = i) then -- select the current read tile
                    ftable_presenter_leading_header_addr            <= unsigned(tile_fifos_rd_data(i)(PAGE_RAM_ADDR_WIDTH-1 downto 0));
                    ftable_presenter_packet_length                  <= unsigned(tile_fifos_rd_data(i)(2*PAGE_RAM_ADDR_WIDTH-1 downto PAGE_RAM_ADDR_WIDTH));
                end if;
            end loop;

            -- page tile < [rd:addr]
            -- connect the read address to appropriate page ram of the complex given tile index
            -- page_tile_rd_addr                   <= (others => (others => '0')); -- default
            -- for i in 0 to N_TILE-1 loop
            --     if (to_integer(ftable_presenter.rseg.tile_index) = i) then -- normal
            --         page_tile_rd_addr(i)                <= page_ram_rd_addr; -- pipeline for timing
            --     end if;
            --     if ftable_presenter.trailing_active(0) then -- ghost
            --         if (to_integer(ftable_presenter.trailing_tile_index) = i) then
            --             page_tile_rd_addr(i)                <= page_ram_rd_addr;
            --         end if;
            --     end if;
            -- end loop;
            for i in 0 to N_TILE-1 loop
                page_tile_rd_addr(i)            <= std_logic_vector(ftable_presenter.page_ram_rptr(i));
            end loop;

            -- Keep the page RAM data pipeline aligned with egress backpressure.
            -- If a valid word is stalled at the egress (valid=1, ready=0), hold this stage too,
            -- otherwise the registered RAM output would overwrite in-flight words and cause duplicates.
            if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then
                page_tile_rd_data_reg           <= page_tile_rd_data;
            end if;

            -- trailing active pipeline (keep aligned with output pipeline under backpressure)
            if (aso_egress_ready = '1') or (ftable_presenter.output_data_valid(EGRESS_DELAY) = '0') then
                for i in 0 to EGRESS_DELAY-1 loop
                    ftable_presenter.trailing_active(i+1)          <= ftable_presenter.trailing_active(i);
                end loop;
            end if;

            if (i_rst = '1') then
                ftable_presenter_state                  <= RESET;
            end if;
        end if;
    end process;

    proc_frame_table_presenter_comb : process (all)
        variable rd_data_sel_idx        : integer range 0 to N_TILE-1 := 0;
    begin
        -- WR:
        -- pointer increase after head is in (we need placeholder)
        -- counter increase after tail is in

        -- RD:
        -- pointer and counter increase after the tail is out

        -- default
        ftable_presenter_is_new_pkt_head                <= '0';
        ftable_presenter_is_new_pkt_complete            <= '0';
        for i in 0 to N_TILE-1 loop
            if (to_integer(ftable_presenter.rseg.tile_index) = i) then -- select the current read tile
                if (ftable_tracker.tile_wptr(i) /= ftable_presenter.tile_rptr(i)) then -- there is a pkt in the tile
                    ftable_presenter_is_new_pkt_head        <= '1';
                end if;
                if (ftable_tracker.tile_pkt_wcnt(i) /= ftable_presenter.tile_pkt_rcnt(i)) then
                    ftable_presenter_is_new_pkt_complete    <= '1'; -- this packet has been completed
                end if;
            end if;
        end loop;

        -- derive if rd tile is in the wr tile range
        ftable_presenter_is_rd_tile_in_range        <= '0';
        for i in 0 to N_WR_SEG-1 loop
            if (ftable_mapper.wseg(i).tile_index = ftable_presenter.rseg.tile_index) then
                ftable_presenter_is_rd_tile_in_range    <= '1';
            end if;
        end loop;

        -- derive the next tile to jump to, pkt is spilling
        ftable_presenter_is_pkt_spilling            <= '0';
        if (to_integer(ftable_presenter_packet_length) + to_integer(ftable_presenter_leading_header_addr) >= PAGE_RAM_DEPTH) then -- no space
            ftable_presenter_is_pkt_spilling            <= '1';
        end if;

        -- derive output is trailer signal
        ftable_presenter_output_is_trailer           <= '0';
        if (ftable_presenter.output_data(35 downto 32) = "0001" and ftable_presenter.output_data(7 downto 0) = K284) then
            ftable_presenter_output_is_trailer           <= '1';
        elsif (ftable_presenter_packet_length = ftable_presenter.pkt_rd_word_cnt) then
            ftable_presenter_output_is_trailer           <= '1';
        end if;

        -- derive the what is the trail tile of current reading packet
        ftable_presenter_trail_tile_id      <= (others => '0');
        for i in 0 to N_TILE-1 loop
            if (to_integer(ftable_presenter.rseg.tile_index) = i) then -- select the current read tile
                ftable_presenter_trail_tile_id      <= tile_regs.trail_tid(i)(tile_regs.trail_tid(i)'length-2 downto 0); -- msb (valid) is trimmed
            end if;
        end loop;

        -- derive the warping tile given rd is within range
        ftable_presenter_if_in_range_warp_wr_seg      <= (others => '0');
        for i in N_WR_SEG-2 downto 0 loop
            if ftable_presenter.rseg.tile_index = ftable_mapper.wseg(i).tile_index then
                ftable_presenter_if_in_range_warp_wr_seg    <= to_unsigned(i+1,TILE_ID_WIDTH);
            end if;
        end loop;
        ftable_presenter_if_in_range_warp_rd_tile    <= (others => '0');
        for i in 0 to N_WR_SEG-1 loop
            if ftable_presenter_if_in_range_warp_wr_seg = i then
                ftable_presenter_if_in_range_warp_rd_tile       <= ftable_mapper.wseg(i).tile_index;
            end if;
        end loop;

        -- connection
        -- tile fifos < [rd:addr]
        -- track current frame is at each address of this page ram
        for i in 0 to N_TILE-1 loop
            tile_fifos_rd_addr(i)              <= std_logic_vector(ftable_presenter.tile_rptr(i));
        end loop;
        -- -- page ram < [rd:addr]
        -- -- connect read pointer to the page ram given tile index
        -- page_ram_rd_addr                    <= (others => '0');
        -- for i in 0 to N_TILE-1 loop
        --     if (to_integer(ftable_presenter.rseg.tile_index) = i) then
        --         page_ram_rd_addr                    <= std_logic_vector(ftable_presenter.page_ram_rptr(i));
        --     end if;
        --     if ftable_presenter.trailing_active(0) then -- ghost
        --         if (to_integer(ftable_presenter.trailing_tile_index) = i) then
        --             page_ram_rd_addr                <= std_logic_vector(ftable_presenter.page_ram_rptr(i));
        --         end if;
        --     end if;
        -- end loop;
        -- page tile > [rd:data]
        -- connect page ram complex with given index to the avst I/F
        -- page_ram_rd_data                    <= (others => '0'); -- default
        if ftable_presenter.trailing_active(EGRESS_DELAY) = '1' then
            rd_data_sel_idx                 := to_integer(ftable_presenter.trailing_tile_index);
        else
            rd_data_sel_idx                 := to_integer(ftable_presenter.rseg.tile_index);
        end if;
        page_ram_rd_data                    <= page_tile_rd_data_reg(rd_data_sel_idx);

        -- for i in 0 to N_TILE-1 loop
        --     if (to_integer(ftable_presenter.rseg.tile_index) = i) then
        --         page_ram_rd_data                    <= page_tile_rd_data_reg(i);
        --     end if;
        --     if ftable_presenter.trailing_active(EGRESS_DELAY) then -- ghost, note: we switch the data port with delay
        --         if (to_integer(ftable_presenter.trailing_tile_index) = i) then --
        --             page_ram_rd_data                    <= page_tile_rd_data_reg(i);
        --         end if;
        --     end if;
        -- end loop;

    end process;

    -- ────────────────────────────────────────────────
    -- Sim-only debug (DEBUG_LV >= 2):
    --   - Page RAM traffic + overwrite risk (opq_overwrite_debug.log)
    --   - Egress packet decode + state transitions (opq_pkt_debug.log)
    -- ────────────────────────────────────────────────
    gen_overwrite_debug : if (DEBUG_LV >= 2) generate
        -- synopsys translate_off
        file f_overwrite : text open write_mode is "opq_overwrite_debug.log";
        file f_pkt       : text open write_mode is "opq_pkt_debug.log";
    begin
			        proc_overwrite_debug : process (i_clk)
			            variable l : line;
			            variable rd_tile_i : integer;
			            variable roll_tile_i : integer;
			            variable wr_tile_i : integer;
			            variable prev_wr_tile_i : integer := -1;
			            variable prev_lead_tile_reg : unsigned(TILE_ID_WIDTH-1 downto 0) := (others => '0');
			            variable fl_tile_i : integer;
			            variable overwrite_risk : boolean;
			            variable wr_is_k : boolean;
			            variable wr_k : std_logic_vector(7 downto 0);
			            variable prev_tf_wptr : tile_ptr_t := (others => (others => '0'));
		            variable prev_tf_rptr : tile_rptr_t := (others => (others => '0'));
		            variable prev_pkt_wcnt : tile_pkt_wcnt_t := (others => (others => '0'));
		            variable prev_pkt_rcnt : tile_pkt_rcnt_t := (others => (others => '0'));
		            variable cyc : unsigned(63 downto 0) := (others => '0');
		        begin
			            if rising_edge(i_clk) then
			                if i_rst = '1' then
			                    cyc := (others => '0');
			                    prev_wr_tile_i := -1;
			                    prev_lead_tile_reg := (others => '0');
			                    prev_tf_wptr := (others => (others => '0'));
			                    prev_tf_rptr := (others => (others => '0'));
			                    prev_pkt_wcnt := (others => (others => '0'));
			                    prev_pkt_rcnt := (others => (others => '0'));
			                else
		                    cyc := cyc + 1;
	                    -- Select the effective read tile at the egress tap (normal vs. trailing spillover).
	                    if (ftable_presenter.trailing_active(EGRESS_DELAY) = '1') then
	                        rd_tile_i := to_integer(ftable_presenter.trailing_tile_index);
	                    else
	                        rd_tile_i := to_integer(ftable_presenter.rseg.tile_index);
	                    end if;
		                    roll_tile_i := to_integer(ftable_presenter.rseg.tile_index);
		                    wr_tile_i := to_integer(ftable_mapper_writing_tile_index);
		                    overwrite_risk := (ftable_presenter_state /= IDLE) and (wr_tile_i = rd_tile_i);

		                    -- Track write-tile mapping changes (this is where "wr jumps to tile 0" shows up).
		                    if (prev_wr_tile_i /= -1) and (wr_tile_i /= prev_wr_tile_i) then
		                        write(l, string'("WR_TILE t="));
		                        write(l, now);
		                        write(l, string'(" cyc=0x"));
		                        hwrite(l, std_logic_vector(cyc));
		                        write(l, string'(" old="));
		                        write(l, integer(prev_wr_tile_i));
		                        write(l, string'(" new="));
		                        write(l, integer(wr_tile_i));
		                        write(l, string'(" ft_st="));
		                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                        write(l, string'(" mapper="));
		                        write(l, ftable_mapper_state_t'image(ftable_mapper_state));
		                        write(l, string'(" rseg="));
		                        write(l, integer(to_integer(ftable_presenter.rseg.tile_index)));
		                        write(l, string'(" egress_tile="));
		                        write(l, integer(rd_tile_i));
		                        write(l, string'(" lead_tile_reg="));
		                        write(l, integer(to_integer(ftable_mapper_leading_wr_tile_index_reg)));
		                        write(l, string'(" exp_tile_reg="));
		                        write(l, integer(to_integer(ftable_mapper_expand_wr_tile_index_reg)));
		                        write(l, string'(" cross_v="));
		                        write(l, std_logic'image(ftable_presenter.crossing_trid_valid));
		                        write(l, string'(" cross_t="));
		                        write(l, integer(to_integer(ftable_presenter.crossing_trid)));
		                        write(l, string'(" risk="));
		                        if overwrite_risk then
		                            write(l, string'("1"));
		                        else
		                            write(l, string'("0"));
		                        end if;
		                        write(l, string'(" wseg={"));
		                        for s in 0 to N_WR_SEG-1 loop
		                            write(l, integer(to_integer(ftable_mapper.wseg(s).tile_index)));
		                            if (s < N_WR_SEG-1) then
		                                write(l, string'(","));
		                            end if;
		                        end loop;
		                        write(l, string'("}"));
		                        writeline(f_overwrite, l);
		                    end if;
		                    prev_wr_tile_i := wr_tile_i;

		                    -- Track leading write tile reg changes (should only advance at safe boundaries).
		                    if (ftable_mapper_leading_wr_tile_index_reg /= prev_lead_tile_reg) then
		                        write(l, string'("LEAD_TILE t="));
		                        write(l, now);
		                        write(l, string'(" cyc=0x"));
		                        hwrite(l, std_logic_vector(cyc));
		                        write(l, string'(" old="));
		                        write(l, integer(to_integer(prev_lead_tile_reg)));
		                        write(l, string'(" new="));
		                        write(l, integer(to_integer(ftable_mapper_leading_wr_tile_index_reg)));
		                        write(l, string'(" ft_st="));
		                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                        write(l, string'(" mapper="));
		                        write(l, ftable_mapper_state_t'image(ftable_mapper_state));
		                        write(l, string'(" rseg="));
		                        write(l, integer(to_integer(ftable_presenter.rseg.tile_index)));
		                        write(l, string'(" wseg={"));
		                        for s in 0 to N_WR_SEG-1 loop
		                            write(l, integer(to_integer(ftable_mapper.wseg(s).tile_index)));
		                            if (s < N_WR_SEG-1) then
		                                write(l, string'(","));
		                            end if;
		                        end loop;
		                        write(l, string'("}"));
		                        writeline(f_overwrite, l);
		                    end if;
		                    prev_lead_tile_reg := ftable_mapper_leading_wr_tile_index_reg;

		                    -- Tap actual tile RAM writes (post-mapper) around the last-hit address window.
		                    for t in 0 to N_TILE-1 loop
		                        if page_tile_we(t) = '1' then
	                            if (page_tile_wr_addr(t) = x"02F5") or (page_tile_wr_addr(t) = x"02F6") then
	                                write(l, string'("PTILE_WR t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" tile="));
	                                write(l, integer(t));
	                                write(l, string'(" addr="));
	                                hwrite(l, page_tile_wr_addr(t));
	                                write(l, string'(" data="));
	                                hwrite(l, page_tile_wr_data(t));
	                                write(l, string'(" pa_st="));
	                                write(l, page_allocator_state_t'image(page_allocator_state));
	                                write(l, string'(" mapper="));
	                                write(l, ftable_mapper_state_t'image(ftable_mapper_state));
	                                writeline(f_overwrite, l);
	                            end if;
	                        end if;
	                    end loop;

	                    -- Log tile FIFO meta writes (packet header address + length enqueue).
		                    for i in 0 to N_TILE-1 loop
		                        if tile_fifos_we(i) = '1' then
		                            write(l, string'("TFIFO_WR t="));
		                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" tile="));
	                            write(l, integer(i));
	                            write(l, string'(" wr_addr="));
	                            hwrite(l, tile_fifos_wr_addr(i));
	                            write(l, string'(" meta="));
	                            hwrite(l, tile_fifos_wr_data(i));
	                            write(l, string'(" hdr_addr="));
	                            hwrite(l, tile_fifos_wr_data(i)(PAGE_RAM_ADDR_WIDTH-1 downto 0));
		                            write(l, string'(" len="));
		                            hwrite(l, tile_fifos_wr_data(i)(2*PAGE_RAM_ADDR_WIDTH-1 downto PAGE_RAM_ADDR_WIDTH));
		                            write(l, string'(" ft_st="));
		                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                            write(l, string'(" mapper="));
		                            write(l, ftable_mapper_state_t'image(ftable_mapper_state));
		                            write(l, string'(" rseg="));
		                            write(l, integer(to_integer(ftable_presenter.rseg.tile_index)));
		                            write(l, string'(" lead_tile_reg="));
		                            write(l, integer(to_integer(ftable_mapper_leading_wr_tile_index_reg)));
		                            write(l, string'(" exp_tile_reg="));
		                            write(l, integer(to_integer(ftable_mapper_expand_wr_tile_index_reg)));
		                            write(l, string'(" cross_v="));
		                            write(l, std_logic'image(ftable_presenter.crossing_trid_valid));
		                            write(l, string'(" cross_t="));
		                            write(l, integer(to_integer(ftable_presenter.crossing_trid)));
		                            write(l, string'(" wseg={"));
		                            for s in 0 to N_WR_SEG-1 loop
		                                write(l, integer(to_integer(ftable_mapper.wseg(s).tile_index)));
		                                if (s < N_WR_SEG-1) then
		                                    write(l, string'(","));
		                                end if;
		                            end loop;
		                            write(l, string'("}"));
		                            write(l, string'(" tf_rptr="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(i)));
		                            write(l, string'(" tf_wptr="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(i)));
		                            write(l, string'(" pkt_rcnt="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_pkt_rcnt(i)));
		                            write(l, string'(" pkt_wcnt="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_pkt_wcnt(i)));
		                            write(l, string'(" trail_tid="));
		                            hwrite(l, std_logic_vector(tile_regs.trail_tid(i)));
		                            write(l, string'(" body_tid="));
		                            hwrite(l, std_logic_vector(tile_regs.body_tid(i)));
		                            writeline(f_overwrite, l);
		                        end if;
		                    end loop;

	                    -- Log flush events (overwrite/void of queued packets).
	                    for a in 0 to 1 loop
	                        if (ftable_mapper.flush_ftable_valid(a) = '1') then
	                            fl_tile_i := to_integer(ftable_mapper.update_ftable_tindex(a));
	                            write(l, string'("FLUSH t="));
	                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" tile="));
	                            write(l, integer(fl_tile_i));
	                            write(l, string'(" tf_rptr="));
	                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(fl_tile_i)));
	                            write(l, string'(" tf_wptr="));
	                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(fl_tile_i)));
	                            write(l, string'(" pkt_rcnt="));
	                            hwrite(l, std_logic_vector(ftable_presenter.tile_pkt_rcnt(fl_tile_i)));
	                            write(l, string'(" pkt_wcnt="));
	                            hwrite(l, std_logic_vector(ftable_tracker.tile_pkt_wcnt(fl_tile_i)));
	                            write(l, string'(" ft_st="));
	                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
	                            write(l, string'(" mapper="));
	                            write(l, ftable_mapper_state_t'image(ftable_mapper_state));
	                            writeline(f_overwrite, l);
	                        end if;
	                    end loop;

	                    -- Log handle FIFO writes (block movers' DMA descriptors).
	                    for i in 0 to N_LANE-1 loop
	                        if handle_fifos_we(i) = '1' then
	                            write(l, string'("HANDLE_WR t="));
	                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" lane="));
	                            write(l, integer(i));
	                            write(l, string'(" waddr="));
	                            hwrite(l, handle_fifos_wr_addr(i));
	                            write(l, string'(" flag="));
	                            write(l, std_logic'image(handle_fifos_wr_data(i)(HANDLE_LENGTH)));
	                            write(l, string'(" src="));
	                            hwrite(l, handle_fifos_wr_data(i)(HANDLE_SRC_HI downto HANDLE_SRC_LO));
	                            write(l, string'(" dst="));
	                            hwrite(l, handle_fifos_wr_data(i)(HANDLE_DST_HI downto HANDLE_DST_LO));
	                            write(l, string'(" len="));
	                            hwrite(l, handle_fifos_wr_data(i)(HANDLE_LEN_HI downto HANDLE_LEN_LO));
	                            write(l, string'(" ts=0x"));
	                            hwrite(l, std_logic_vector(page_allocator.ticket(i).ticket_ts));
	                            write(l, string'(" sop="));
	                            write(l, std_logic'image(page_allocator.ticket(i).alert_sop));
	                            write(l, string'(" eop="));
	                            write(l, std_logic'image(page_allocator.ticket(i).alert_eop));
	                            write(l, string'(" pa_st="));
	                            write(l, page_allocator_state_t'image(page_allocator_state));
	                            writeline(f_overwrite, l);
	                        end if;
	                    end loop;

	                    -- Track whether the block mover actually writes the "last-hit" handles seen in the repro:
	                    -- dst=0x02F5/0x02F6 (ts=0xFE0). If these writes never happen, the packet can be marked
	                    -- complete before DMA finishes, leading to zero hit words on egress.
	                    for i in 0 to N_LANE-1 loop
	                        if (block_mover_state(i) = PREP) then
	                            if (block_mover(i).handle.dst = to_unsigned(16#02F5#, PAGE_RAM_ADDR_WIDTH))
	                               or (block_mover(i).handle.dst = to_unsigned(16#02F6#, PAGE_RAM_ADDR_WIDTH)) then
	                                write(l, string'("BM_PREP t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" lane="));
	                                write(l, integer(i));
	                                write(l, string'(" src="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.src));
	                                write(l, string'(" dst="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.dst));
	                                write(l, string'(" len="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.blk_len));
	                                writeline(f_overwrite, l);
	                            end if;
	                        elsif (block_mover_state(i) = ABORT_WRITE_BLK) then
	                            if (block_mover(i).handle.dst = to_unsigned(16#02F5#, PAGE_RAM_ADDR_WIDTH))
	                               or (block_mover(i).handle.dst = to_unsigned(16#02F6#, PAGE_RAM_ADDR_WIDTH)) then
	                                write(l, string'("BM_ABORT t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" lane="));
	                                write(l, integer(i));
	                                write(l, string'(" src="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.src));
	                                write(l, string'(" dst="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.dst));
	                                write(l, string'(" len="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.blk_len));
	                                writeline(f_overwrite, l);
	                            end if;
	                        elsif (block_mover_state(i) = WRITE_BLK) and (b2p_arb_gnt(i) = '1') then
	                            if (block_mover(i).handle.dst = to_unsigned(16#02F5#, PAGE_RAM_ADDR_WIDTH))
	                               or (block_mover(i).handle.dst = to_unsigned(16#02F6#, PAGE_RAM_ADDR_WIDTH)) then
	                                write(l, string'("BM_WRITE t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" lane="));
	                                write(l, integer(i));
	                                write(l, string'(" wr_addr="));
	                                hwrite(l, std_logic_vector(block_mover(i).page_wptr + block_mover(i).word_wr_cnt));
	                                write(l, string'(" src="));
	                                hwrite(l, std_logic_vector(block_mover(i).handle.src));
	                                write(l, string'(" rd_addr="));
	                                hwrite(l, lane_fifos_rd_addr(i));
	                                write(l, string'(" data="));
	                                hwrite(l, lane_fifos_rd_data(i)(35 downto 0));
	                                writeline(f_overwrite, l);
	                            end if;
	                        end if;
	                    end loop;

	                    -- Log special marker writes (HDR/SHD/TRL) and any overwrite-risk writes.
	                    if page_ram_we = '1' then
	                        wr_is_k := (page_ram_wr_data(35 downto 32) = "0001");
	                        wr_k    := page_ram_wr_data(7 downto 0);

	                        -- Always log marker writes; additionally log writes into the currently read tile
	                        -- (OVERWRITE_RISK) and a narrow watch window around the last-hit addresses seen
	                        -- in our failing repro (0x02F5/0x02F6).
		                        if overwrite_risk
		                           or (ftable_wr_blocked_by_rd_lock = '1')
		                           or (wr_is_k and ((wr_k = K285) or (wr_k = K237) or (wr_k = K284)))
		                           or (page_ram_wr_addr = x"02F5")
		                           or (page_ram_wr_addr = x"02F6")
		                           -- Extra watch window for UVM "zero hit" repro around the 0x0618..0x0630 region.
		                           -- (Addresses are page RAM word indices within a tile.)
		                           or ((unsigned(page_ram_wr_addr) >= to_unsigned(16#0610#, PAGE_RAM_ADDR_WIDTH)) and
		                               (unsigned(page_ram_wr_addr) <= to_unsigned(16#0630#, PAGE_RAM_ADDR_WIDTH)))
		                           -- Watch around the first observed zero-hit read pointers (0x067E..0x0690).
		                           or ((unsigned(page_ram_wr_addr) >= to_unsigned(16#0670#, PAGE_RAM_ADDR_WIDTH)) and
		                               (unsigned(page_ram_wr_addr) <= to_unsigned(16#0690#, PAGE_RAM_ADDR_WIDTH))) then
		                            write(l, string'("WRITE t="));
		                            write(l, now);
		                            write(l, string'(" cyc=0x"));
		                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" tile="));
	                            write(l, integer(wr_tile_i));
	                            write(l, string'(" addr="));
	                            hwrite(l, page_ram_wr_addr);
                            write(l, string'(" data="));
                            hwrite(l, page_ram_wr_data);
		                            write(l, string'(" pa_st="));
		                            write(l, page_allocator_state_t'image(page_allocator_state));
		                            write(l, string'(" pa_flow="));
		                            write(l, integer(page_allocator.write_meta_flow));
		                            write(l, string'(" bm_st={"));
		                            for bi in 0 to N_LANE-1 loop
		                                write(l, block_mover_state_t'image(block_mover_state(bi)));
		                                if (bi < N_LANE-1) then
		                                    write(l, string'(","));
		                                end if;
		                            end loop;
		                            write(l, string'("} gnt="));
		                            hwrite(l, std_logic_vector(b2p_arb_gnt));
			                            write(l, string'(" ft_st="));
			                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                            if (ftable_wr_blocked_by_rd_lock = '1') then
		                                write(l, string'(" WR_BLOCKED=1"));
		                            end if;
		                            if (page_ram_wr_addr = x"02F5") or (page_ram_wr_addr = x"02F6") then
		                                write(l, string'(" WATCH_LAST_HIT=1"));
		                            end if;

			                            if overwrite_risk then
			                                write(l, string'(" OVERWRITE_RISK rd_tile="));
			                                write(l, integer(rd_tile_i));
		                                write(l, string'(" rseg_tile="));
		                                write(l, integer(roll_tile_i));
	                                write(l, string'(" rd_ptr="));
	                                hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(rd_tile_i)));
	                                write(l, string'(" rd_cnt="));
	                                write(l, integer(to_integer(ftable_presenter.pkt_rd_word_cnt)));
	                                write(l, string'(" tf_meta="));
	                                hwrite(l, tile_fifos_rd_data(roll_tile_i));
	                                write(l, string'(" hdr_addr="));
	                                hwrite(l, std_logic_vector(ftable_presenter_leading_header_addr));
	                                write(l, string'(" pkt_len="));
	                                hwrite(l, std_logic_vector(ftable_presenter_packet_length));
	                                write(l, string'(" rd_valid="));
	                                write(l, std_logic'image(aso_egress_valid));
		                                write(l, string'(" rd_ready="));
		                                write(l, std_logic'image(aso_egress_ready));
		                                write(l, string'(" mapper="));
		                                write(l, ftable_mapper_state_t'image(ftable_mapper_state));
		                                write(l, string'(" wseg={"));
		                                for s in 0 to N_WR_SEG-1 loop
		                                    write(l, integer(to_integer(ftable_mapper.wseg(s).tile_index)));
		                                    if (s < N_WR_SEG-1) then
		                                        write(l, string'(","));
		                                    end if;
		                                end loop;
		                                write(l, string'("}"));
		                                write(l, string'(" lead_seg_reg="));
		                                write(l, integer(to_integer(ftable_mapper.leading_wseg)));
		                                write(l, string'(" lead_seg_c="));
		                                write(l, integer(to_integer(ftable_mapper_leading_wr_seg_index)));
		                                write(l, string'(" lead_tile_reg="));
		                                write(l, integer(to_integer(ftable_mapper_leading_wr_tile_index_reg)));
		                                write(l, string'(" exp_tile_reg="));
		                                write(l, integer(to_integer(ftable_mapper_expand_wr_tile_index_reg)));
		                                write(l, string'(" cross_v="));
		                                write(l, std_logic'image(ftable_presenter.crossing_trid_valid));
		                                write(l, string'(" cross_t="));
		                                write(l, integer(to_integer(ftable_presenter.crossing_trid)));
		                            end if;
		                            writeline(f_overwrite, l);
                        end if;
                    end if;

	                    -- Log actual accepted egress words (valid && ready).
		                    if (aso_egress_valid = '1') and (aso_egress_ready = '1') then
		                        write(l, string'("EGRESS t="));
	                        write(l, now);
	                        write(l, string'(" cyc=0x"));
	                        hwrite(l, std_logic_vector(cyc));
	                        write(l, string'(" tile="));
	                        write(l, integer(rd_tile_i));
	                        write(l, string'(" rd_ptr="));
	                        hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(rd_tile_i)));
                        write(l, string'(" rd_cnt="));
                        write(l, integer(to_integer(ftable_presenter.pkt_rd_word_cnt)));
                        write(l, string'(" sop="));
                        write(l, std_logic'image(aso_egress_startofpacket));
                        write(l, string'(" eop="));
                        write(l, std_logic'image(aso_egress_endofpacket));
                        write(l, string'(" data="));
                        hwrite(l, aso_egress_data);
                        write(l, string'(" ft_st="));
                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                        writeline(f_overwrite, l);
		                    end if;

		                    -- Track tile FIFO pointer/counter changes (flush / enqueue / dequeue visibility).
		                    for t in 0 to N_TILE-1 loop
		                        if (ftable_tracker.tile_wptr(t) /= prev_tf_wptr(t)) then
		                            write(l, string'("TF_WPTR t="));
		                            write(l, now);
		                            write(l, string'(" cyc=0x"));
		                            hwrite(l, std_logic_vector(cyc));
		                            write(l, string'(" tile="));
		                            write(l, integer(t));
		                            write(l, string'(" old="));
		                            hwrite(l, std_logic_vector(prev_tf_wptr(t)));
		                            write(l, string'(" new="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(t)));
		                            write(l, string'(" tf_rptr="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(t)));
		                            writeline(f_overwrite, l);
		                        end if;
		                        if (ftable_presenter.tile_rptr(t) /= prev_tf_rptr(t)) then
		                            write(l, string'("TF_RPTR t="));
		                            write(l, now);
		                            write(l, string'(" cyc=0x"));
		                            hwrite(l, std_logic_vector(cyc));
		                            write(l, string'(" tile="));
		                            write(l, integer(t));
		                            write(l, string'(" old="));
		                            hwrite(l, std_logic_vector(prev_tf_rptr(t)));
		                            write(l, string'(" new="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(t)));
		                            write(l, string'(" tf_wptr="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(t)));
		                            writeline(f_overwrite, l);
		                        end if;
		                        if (ftable_tracker.tile_pkt_wcnt(t) /= prev_pkt_wcnt(t)) then
		                            write(l, string'("PKT_WCNT t="));
		                            write(l, now);
		                            write(l, string'(" cyc=0x"));
		                            hwrite(l, std_logic_vector(cyc));
		                            write(l, string'(" tile="));
		                            write(l, integer(t));
		                            write(l, string'(" old="));
		                            hwrite(l, std_logic_vector(prev_pkt_wcnt(t)));
		                            write(l, string'(" new="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_pkt_wcnt(t)));
		                            write(l, string'(" pkt_rcnt="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_pkt_rcnt(t)));
		                            write(l, string'(" tf_rptr="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(t)));
		                            write(l, string'(" tf_wptr="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(t)));
		                            write(l, string'(" ft_st="));
		                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                            writeline(f_overwrite, l);
		                        end if;
		                        if (ftable_presenter.tile_pkt_rcnt(t) /= prev_pkt_rcnt(t)) then
		                            write(l, string'("PKT_RCNT t="));
		                            write(l, now);
		                            write(l, string'(" cyc=0x"));
		                            hwrite(l, std_logic_vector(cyc));
		                            write(l, string'(" tile="));
		                            write(l, integer(t));
		                            write(l, string'(" old="));
		                            hwrite(l, std_logic_vector(prev_pkt_rcnt(t)));
		                            write(l, string'(" new="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_pkt_rcnt(t)));
		                            write(l, string'(" pkt_wcnt="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_pkt_wcnt(t)));
		                            write(l, string'(" tf_rptr="));
		                            hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(t)));
		                            write(l, string'(" tf_wptr="));
		                            hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(t)));
		                            write(l, string'(" ft_st="));
		                            write(l, ftable_presenter_state_t'image(ftable_presenter_state));
		                            writeline(f_overwrite, l);
		                        end if;
		                    end loop;
		                    prev_tf_wptr := ftable_tracker.tile_wptr;
		                    prev_tf_rptr := ftable_presenter.tile_rptr;
		                    prev_pkt_wcnt := ftable_tracker.tile_pkt_wcnt;
		                    prev_pkt_rcnt := ftable_presenter.tile_pkt_rcnt;
		                end if;
		            end if;
		        end process;

	        -- ────────────────────────────────────────────────
	        -- @name            PKT DEBUG DECODER
	        -- @brief           Sim-only mirror of the UVM egress decoder; emits per-frame traces and recent-word history.
	        -- ────────────────────────────────────────────────
	        proc_pkt_debug : process (i_clk)
            -- Mirror the UVM egress decoder in-VHDL so we can correlate broken frames to
            -- internal state/pointer transitions. This is sim-only.
            type state_t is (WAIT_SOF, IN_FRAME);

            constant HIST_DEPTH : integer := 32;
            type hist_word_t is array (0 to HIST_DEPTH-1) of std_logic_vector(aso_egress_data'range);
            type hist_tile_t is array (0 to HIST_DEPTH-1) of integer;
            type hist_cnt_t  is array (0 to HIST_DEPTH-1) of integer;

            variable l : line;
            variable st : state_t := WAIT_SOF;
            variable hdr_idx : integer := 0;
            variable hdr_hi32 : std_logic_vector(31 downto 0) := (others => '0');
            variable hdr_hi4  : std_logic_vector(3 downto 0)  := (others => '0');
            variable hdr_lo16 : std_logic_vector(15 downto 0) := (others => '0');
            variable pkg_cnt  : std_logic_vector(15 downto 0) := (others => '0');
            variable decl_subh16 : std_logic_vector(15 downto 0) := (others => '0');
            variable decl_hit16  : std_logic_vector(15 downto 0) := (others => '0');
            variable sub_ts8 : std_logic_vector(7 downto 0) := (others => '0');
            variable hits_left : integer := 0;
            variable frame_hits : integer := 0;
            variable frame_subh : integer := 0;
            variable frame_ts_hdr : std_logic_vector(47 downto 0) := (others => '0');

            variable prev_ft_st : ftable_presenter_state_t := RESET;
            variable prev_pa_st : page_allocator_state_t := RESET;
	            variable prev_mapper_st : ftable_mapper_state_t := RESET;

	            variable rd_tile_i : integer := 0;
	            variable roll_tile_i : integer := 0;
	            variable cyc : unsigned(63 downto 0) := (others => '0');

            variable hist_word : hist_word_t := (others => (others => '0'));
            variable hist_tile : hist_tile_t := (others => 0);
            variable hist_cnt  : hist_cnt_t  := (others => 0);
            variable hist_wptr : integer range 0 to HIST_DEPTH-1 := 0;

            variable hs_cnt : integer := 0;
            variable stall_active : boolean := false;
            variable stall_len : integer := 0;
            variable hit_ts48 : std_logic_vector(47 downto 0);
            variable kbyte : std_logic_vector(7 downto 0);
            variable is_k : boolean;
            variable dump_idx : integer;
        begin
	            if rising_edge(i_clk) then
	                if i_rst = '1' then
	                    cyc := (others => '0');
	                    st := WAIT_SOF;
	                    hdr_idx := 0;
	                    hits_left := 0;
	                    frame_hits := 0;
                    frame_subh := 0;
                    frame_ts_hdr := (others => '0');
                    prev_ft_st := RESET;
                    prev_pa_st := RESET;
                    prev_mapper_st := RESET;
                    hist_wptr := 0;
                    hs_cnt := 0;
	                    stall_active := false;
	                    stall_len := 0;
	                else
	                    cyc := cyc + 1;
	                    -- Tile selection at the egress tap.
	                    if (ftable_presenter.trailing_active(EGRESS_DELAY) = '1') then
	                        rd_tile_i := to_integer(ftable_presenter.trailing_tile_index);
	                    else
                        rd_tile_i := to_integer(ftable_presenter.rseg.tile_index);
                    end if;
                    -- Tile whose read pointer is rolled back on stall (see presenter RESTART logic).
                    roll_tile_i := to_integer(ftable_presenter.rseg.tile_index);

	                    -- State transition logging (presenter + allocator + mapper).
	                    if (ftable_presenter_state /= prev_ft_st) then
	                        write(l, string'("STATE t="));
	                        write(l, now);
	                        write(l, string'(" cyc=0x"));
	                        hwrite(l, std_logic_vector(cyc));
	                        write(l, string'(" ft="));
	                        write(l, ftable_presenter_state_t'image(prev_ft_st));
	                        write(l, string'("->"));
                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
                        write(l, string'(" tile="));
                        write(l, integer(rd_tile_i));
                        write(l, string'(" rptr="));
                        hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(rd_tile_i)));
                        write(l, string'(" rd_cnt="));
                        write(l, integer(to_integer(ftable_presenter.pkt_rd_word_cnt)));
	                        write(l, string'(" spill="));
	                        write(l, std_logic'image(ftable_presenter.trailing_active(EGRESS_DELAY)));
	                        writeline(f_pkt, l);

	                        -- Tile FIFO meta tap: print the meta entry (hdr addr + len) and pointers/counters
	                        -- for the currently selected read segment tile.
	                        write(l, string'("TFIFO_RD t="));
	                        write(l, now);
	                        write(l, string'(" cyc=0x"));
	                        hwrite(l, std_logic_vector(cyc));
	                        write(l, string'(" ft="));
	                        write(l, ftable_presenter_state_t'image(ftable_presenter_state));
	                        write(l, string'(" rseg_tile="));
	                        write(l, integer(roll_tile_i));
	                        write(l, string'(" egress_tile="));
	                        write(l, integer(rd_tile_i));
	                        write(l, string'(" tf_rptr="));
	                        hwrite(l, std_logic_vector(ftable_presenter.tile_rptr(roll_tile_i)));
	                        write(l, string'(" tf_wptr="));
	                        hwrite(l, std_logic_vector(ftable_tracker.tile_wptr(roll_tile_i)));
	                        write(l, string'(" tf_meta="));
	                        hwrite(l, tile_fifos_rd_data(roll_tile_i));
	                        write(l, string'(" hdr_addr="));
	                        hwrite(l, std_logic_vector(ftable_presenter_leading_header_addr));
	                        write(l, string'(" pkt_len="));
	                        hwrite(l, std_logic_vector(ftable_presenter_packet_length));
	                        write(l, string'(" pkt_rcnt="));
	                        hwrite(l, std_logic_vector(ftable_presenter.tile_pkt_rcnt(roll_tile_i)));
	                        write(l, string'(" pkt_wcnt="));
	                        hwrite(l, std_logic_vector(ftable_tracker.tile_pkt_wcnt(roll_tile_i)));
	                        writeline(f_pkt, l);

	                        -- If presenter goes IDLE while our decoder believes we're still inside a frame,
	                        -- that likely indicates a missing trailer or an early abort.
	                        if (ftable_presenter_state = IDLE) and (st = IN_FRAME) then
	                            write(l, string'("ERR  t="));
	                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" presenter_to_IDLE_while_IN_FRAME frame_ts=0x"));
	                            hwrite(l, frame_ts_hdr);
	                            write(l, string'(" pkg="));
                            hwrite(l, pkg_cnt);
                            write(l, string'(" seen_subh="));
                            write(l, integer(frame_subh));
                            write(l, string'(" seen_hit="));
                            write(l, integer(frame_hits));
                            writeline(f_pkt, l);
                        end if;

                        prev_ft_st := ftable_presenter_state;
                    end if;

                    -- Egress stall tracking (valid=1, ready=0).
	                    if (aso_egress_valid = '1') and (aso_egress_ready = '0') then
	                        if not stall_active then
	                            stall_active := true;
	                            stall_len := 1;
	                            write(l, string'("STALL t="));
	                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" begin tile="));
	                            write(l, integer(rd_tile_i));
	                            write(l, string'(" roll_tile="));
	                            write(l, integer(roll_tile_i));
	                            write(l, string'(" roll_rptr="));
	                            hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(roll_tile_i)));
	                            write(l, string'(" tf_meta="));
	                            hwrite(l, tile_fifos_rd_data(roll_tile_i));
	                            write(l, string'(" hdr_addr="));
	                            hwrite(l, std_logic_vector(ftable_presenter_leading_header_addr));
	                            write(l, string'(" pkt_len="));
	                            hwrite(l, std_logic_vector(ftable_presenter_packet_length));
	                            write(l, string'(" data="));
	                            hwrite(l, aso_egress_data);
	                            writeline(f_pkt, l);

                            if (ftable_presenter.page_ram_rptr(roll_tile_i) < to_unsigned(EGRESS_DELAY+1, PAGE_RAM_ADDR_WIDTH)) then
	                                write(l, string'("WARN t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" restart_rollback_underflow roll_tile="));
	                                write(l, integer(roll_tile_i));
	                                write(l, string'(" roll_rptr="));
                                hwrite(l, std_logic_vector(ftable_presenter.page_ram_rptr(roll_tile_i)));
                                write(l, string'(" back="));
                                write(l, integer(EGRESS_DELAY+1));
                                writeline(f_pkt, l);
                            end if;
                        else
                            stall_len := stall_len + 1;
                        end if;
	                    else
	                        if stall_active then
	                            write(l, string'("STALL t="));
	                            write(l, now);
	                            write(l, string'(" cyc=0x"));
	                            hwrite(l, std_logic_vector(cyc));
	                            write(l, string'(" end len="));
	                            write(l, integer(stall_len));
	                            writeline(f_pkt, l);
                            stall_active := false;
                            stall_len := 0;
                        end if;
                    end if;

	                    if (page_allocator_state /= prev_pa_st) then
	                        write(l, string'("STATE t="));
	                        write(l, now);
	                        write(l, string'(" cyc=0x"));
	                        hwrite(l, std_logic_vector(cyc));
	                        write(l, string'(" pa="));
	                        write(l, page_allocator_state_t'image(prev_pa_st));
	                        write(l, string'("->"));
                        write(l, page_allocator_state_t'image(page_allocator_state));
                        write(l, string'(" flow="));
                        write(l, integer(page_allocator.write_meta_flow));
                        writeline(f_pkt, l);
                        prev_pa_st := page_allocator_state;
                    end if;

		                    if (ftable_mapper_state /= prev_mapper_st) then
		                        write(l, string'("STATE t="));
		                        write(l, now);
		                        write(l, string'(" cyc=0x"));
		                        hwrite(l, std_logic_vector(cyc));
		                        write(l, string'(" mapper="));
		                        write(l, ftable_mapper_state_t'image(prev_mapper_st));
		                        write(l, string'("->"));
	                        write(l, ftable_mapper_state_t'image(ftable_mapper_state));
	                        write(l, string'(" rseg="));
	                        write(l, integer(to_integer(ftable_presenter.rseg.tile_index)));
	                        write(l, string'(" wseg={"));
	                        for s in 0 to N_WR_SEG-1 loop
	                            write(l, integer(to_integer(ftable_mapper.wseg(s).tile_index)));
	                            if (s < N_WR_SEG-1) then
	                                write(l, string'(","));
	                            end if;
	                        end loop;
	                        write(l, string'("}"));
	                        write(l, string'(" lead_seg_reg="));
	                        write(l, integer(to_integer(ftable_mapper.leading_wseg)));
	                        write(l, string'(" lead_seg_c="));
	                        write(l, integer(to_integer(ftable_mapper_leading_wr_seg_index)));
	                        write(l, string'(" lead_tile_reg="));
	                        write(l, integer(to_integer(ftable_mapper_leading_wr_tile_index_reg)));
	                        write(l, string'(" exp_tile_reg="));
	                        write(l, integer(to_integer(ftable_mapper_expand_wr_tile_index_reg)));
	                        writeline(f_pkt, l);
	                        prev_mapper_st := ftable_mapper_state;
	                    end if;

                    -- Egress decode on accepted words only.
                    if (aso_egress_valid = '1') and (aso_egress_ready = '1') then
                        hs_cnt := hs_cnt + 1;

                        hist_word(hist_wptr) := aso_egress_data;
                        hist_tile(hist_wptr) := rd_tile_i;
                        hist_cnt(hist_wptr)  := hs_cnt;
                        if (hist_wptr = HIST_DEPTH-1) then
                            hist_wptr := 0;
                        else
                            hist_wptr := hist_wptr + 1;
                        end if;

                        is_k  := (aso_egress_data(35 downto 32) = "0001");
                        kbyte := aso_egress_data(7 downto 0);

                        if (st = WAIT_SOF) then
                            if is_k and (kbyte = K285) then
                                st := IN_FRAME;
                                hdr_idx := 0;
                                hits_left := 0;
                                frame_hits := 0;
                                frame_subh := 0;
                                frame_ts_hdr := (others => '0');

	                                write(l, string'("SOF  t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" tile="));
	                                write(l, integer(rd_tile_i));
	                                write(l, string'(" preamble dt="));
                                hwrite(l, aso_egress_data(31 downto 26));
                                write(l, string'(" feb="));
                                hwrite(l, aso_egress_data(23 downto 8));
                                writeline(f_pkt, l);
                            else
	                                write(l, string'("WARN t="));
	                                write(l, now);
	                                write(l, string'(" cyc=0x"));
	                                hwrite(l, std_logic_vector(cyc));
	                                write(l, string'(" egress_before_preamble tile="));
	                                write(l, integer(rd_tile_i));
	                                write(l, string'(" data="));
                                hwrite(l, aso_egress_data);
                                writeline(f_pkt, l);
                            end if;
                        else
                            -- IN_FRAME
                            if (hdr_idx < (HDR_SIZE-1)) then
                                if (hdr_idx = 0) then
                                    hdr_hi32 := aso_egress_data(31 downto 0);
                                    hdr_idx := hdr_idx + 1;
                                elsif (hdr_idx = 1) then
                                    hdr_hi4  := aso_egress_data(31 downto 28);
                                    hdr_lo16 := aso_egress_data(31 downto 16);
                                    pkg_cnt  := aso_egress_data(15 downto 0);
                                    frame_ts_hdr := hdr_hi32 & hdr_lo16;
                                    hdr_idx := hdr_idx + 1;
                                elsif (hdr_idx = 2) then
                                    decl_subh16 := aso_egress_data(31 downto 16);
                                    decl_hit16  := aso_egress_data(15 downto 0);
                                    hdr_idx := hdr_idx + 1;

	                                    write(l, string'("HDR  t="));
	                                    write(l, now);
	                                    write(l, string'(" cyc=0x"));
	                                    hwrite(l, std_logic_vector(cyc));
	                                    write(l, string'(" frame_ts=0x"));
	                                    hwrite(l, frame_ts_hdr);
	                                    write(l, string'(" pkg="));
                                    hwrite(l, pkg_cnt);
                                    write(l, string'(" decl_subh="));
                                    hwrite(l, decl_subh16);
                                    write(l, string'(" decl_hit="));
                                    hwrite(l, decl_hit16);
                                    writeline(f_pkt, l);
                                else
                                    hdr_idx := hdr_idx + 1;
                                end if;

                                -- Any K-control word inside the header body is suspicious.
                                if is_k and ((kbyte = K237) or (kbyte = K284) or (kbyte = K285)) then
	                                    write(l, string'("ERR  t="));
	                                    write(l, now);
	                                    write(l, string'(" cyc=0x"));
	                                    hwrite(l, std_logic_vector(cyc));
	                                    write(l, string'(" Kword_inside_header idx="));
	                                    write(l, integer(hdr_idx));
	                                    write(l, string'(" data="));
                                    hwrite(l, aso_egress_data);
                                    writeline(f_pkt, l);
                                end if;
                            else
                                -- Body: subheaders / hits / trailer.
                                if is_k and (kbyte = K285) then
	                                    write(l, string'("ERR  t="));
	                                    write(l, now);
	                                    write(l, string'(" cyc=0x"));
	                                    hwrite(l, std_logic_vector(cyc));
	                                    write(l, string'(" preamble_inside_frame frame_ts=0x"));
	                                    hwrite(l, frame_ts_hdr);
	                                    write(l, string'(" pkg="));
                                    hwrite(l, pkg_cnt);
                                    writeline(f_pkt, l);

                                    for i in 0 to HIST_DEPTH-1 loop
                                        dump_idx := hist_wptr + i;
                                        if dump_idx >= HIST_DEPTH then
                                            dump_idx := dump_idx - HIST_DEPTH;
                                        end if;
	                                        write(l, string'("DUMP n="));
	                                        write(l, integer(hist_cnt(dump_idx)));
	                                        write(l, string'(" tile="));
	                                        write(l, integer(hist_tile(dump_idx)));
                                        write(l, string'(" data="));
                                        hwrite(l, hist_word(dump_idx));
                                        writeline(f_pkt, l);
                                    end loop;
                                elsif is_k and (kbyte = K237) then
                                    sub_ts8 := aso_egress_data(31 downto 24);
                                    hits_left := to_integer(unsigned(aso_egress_data(15 downto 8)));
                                    frame_subh := frame_subh + 1;

                                    write(l, string'("SHD  t="));
                                    write(l, now);
                                    write(l, string'(" frame_ts=0x"));
                                    hwrite(l, frame_ts_hdr);
                                    write(l, string'(" pkg="));
                                    hwrite(l, pkg_cnt);
                                    write(l, string'(" shd_idx="));
                                    write(l, integer(frame_subh));
                                    write(l, string'(" shd_ts8=0x"));
                                    hwrite(l, sub_ts8);
                                    write(l, string'(" hits="));
                                    write(l, integer(hits_left));
                                    writeline(f_pkt, l);
                                elsif is_k and (kbyte = K284) then
                                    write(l, string'("EOF  t="));
                                    write(l, now);
                                    write(l, string'(" frame_ts=0x"));
                                    hwrite(l, frame_ts_hdr);
                                    write(l, string'(" pkg="));
                                    hwrite(l, pkg_cnt);
                                    write(l, string'(" decl_subh="));
                                    hwrite(l, decl_subh16);
                                    write(l, string'(" seen_subh="));
                                    write(l, integer(frame_subh));
                                    write(l, string'(" decl_hit="));
                                    hwrite(l, decl_hit16);
                                    write(l, string'(" seen_hit="));
                                    write(l, integer(frame_hits));
                                    writeline(f_pkt, l);

                                    if (to_integer(unsigned(decl_subh16)) /= frame_subh) then
                                        write(l, string'("ERR  t="));
                                        write(l, now);
                                        write(l, string'(" frame_subheader_count_mismatch exp="));
                                        write(l, integer(to_integer(unsigned(decl_subh16))));
                                        write(l, string'(" got="));
                                        write(l, integer(frame_subh));
                                        writeline(f_pkt, l);
                                    end if;
                                    if (to_integer(unsigned(decl_hit16)) /= frame_hits) then
                                        write(l, string'("ERR  t="));
                                        write(l, now);
                                        write(l, string'(" frame_hit_count_mismatch exp="));
                                        write(l, integer(to_integer(unsigned(decl_hit16))));
                                        write(l, string'(" got="));
                                        write(l, integer(frame_hits));
                                        writeline(f_pkt, l);
                                    end if;

                                    if (hits_left /= 0) then
                                        write(l, string'("ERR  t="));
                                        write(l, now);
                                        write(l, string'(" trailer_before_consuming_hits_left="));
                                        write(l, integer(hits_left));
                                        writeline(f_pkt, l);
                                    end if;

                                    st := WAIT_SOF;
                                    hdr_idx := 0;
                                    hits_left := 0;
                                else
                                    -- Hit word (or malformed body word)
                                    if (hits_left = 0) then
                                        write(l, string'("ERR  t="));
                                        write(l, now);
                                        write(l, string'(" hit_outside_subheader frame_ts=0x"));
                                        hwrite(l, frame_ts_hdr);
                                        write(l, string'(" pkg="));
                                        hwrite(l, pkg_cnt);
                                        write(l, string'(" data="));
                                        hwrite(l, aso_egress_data);
                                        writeline(f_pkt, l);
                                    else
                                        hit_ts48 := hdr_hi32 & hdr_hi4 & sub_ts8 & aso_egress_data(31 downto 28);
                                        frame_hits := frame_hits + 1;
                                        hits_left := hits_left - 1;

                                        -- Only print the first few hits per frame at DEBUG_LV=2 to keep logs manageable.
                                        -- Always print suspicious "all-zero" hits so we can catch mis-association/corruption.
                                        if (DEBUG_LV >= 3) or (frame_hits <= 64) or (aso_egress_data(31 downto 0) = x"00000000") then
	                                        write(l, string'("HIT  t="));
	                                        write(l, now);
	                                        write(l, string'(" cyc=0x"));
	                                        hwrite(l, std_logic_vector(cyc));
	                                        write(l, string'(" ts=0x"));
	                                        hwrite(l, hit_ts48);
	                                        write(l, string'(" frame_ts=0x"));
                                            hwrite(l, frame_ts_hdr);
                                            write(l, string'(" pkg="));
                                            hwrite(l, pkg_cnt);
                                            write(l, string'(" data32=0x"));
                                            hwrite(l, aso_egress_data(31 downto 0));
                                            writeline(f_pkt, l);
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
        -- synopsys translate_on
    end generate;

    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    -- @name            AVST EGRESS
    -- @brief           Drive Avalon-ST egress controls (valid/sop/eop) from the presenter output stream.
    -- ────────────────────────────────────────────────────────────────────────────────────────────────
    proc_avalon_streaming_egress_comb : process (all)
    begin
        -- default
        aso_egress_startofpacket            <= '0';
        aso_egress_endofpacket              <= '0';
        aso_egress_error                    <= (others => '0');

        -- Only assert `valid` while actually presenting a packet. During internal restart/refill,
        -- suppress `valid` so the breakpoint word cannot be double-accepted.
        if (ftable_presenter_state = PRESENTING) then
            aso_egress_valid                <= ftable_presenter.output_data_valid(EGRESS_DELAY);
        else
            aso_egress_valid                <= '0';
        end if;
        aso_egress_data                     <= ftable_presenter.output_data(aso_egress_data'high downto 0);
        if (ftable_presenter.output_data(35 downto 32) = "0001" and ftable_presenter.output_data(7 downto 0) = K285) then
            aso_egress_startofpacket            <= '1';
        end if;
        if (ftable_presenter.output_data(35 downto 32) = "0001" and ftable_presenter.output_data(7 downto 0) = K284) then
            aso_egress_endofpacket            <= '1';
        end if;
    end process;

end architecture rtl;

-- https://asciiflow.com/#/share/eJztnE9v2zYYxr8Kod2ELEiaznZyG7DDCvRQZBi2g4FBtdlOiCO5sprEKwoMwY47%2BBCk%2FhA7DTsN%2BzT5JKP%2B2RJFUiRFilSsB0LrWBT1I%2Fla1PuY8icn8K6hc%2BEsIz%2BM%2FHj9y4eP8CN0jpyFt4YR2vFp6tzAaOWHwdS5eHE0de7Q%2F%2BdnI%2FRqnbwzOkevYngXoz%2BmDkj09PDn08Pvw%2FaMtg0oNJ0G%2BSDfA2tVhjMKTP8obISLt24Uq7Bo76Dyx5koR6K3v8qUFqDD%2F7C%2BfhsuVhd4Bd%2FOYv8GgjehH8QwKlfwKvCo%2B4h6482uYAx%2BDOao8E%2BXdfhKgcvv%2BOH5e0tqH6W8op7nPeHjf9R9P%2FNXk572gRLeW%2BHi1nzEeUUGprVw2Hq6bWuD3AuxYKuzEnHiMiU29n12Ke%2BQp1Fs4Oxq8BcWSBaIHcuW9fHzwkW0YrOsPu06rglYTwa4IVVLfLNNhZo25fDCh1eGD90F3%2FqLBbiNvCVh%2BFgfkFIBWtnGOvirynccVwQEIhGr84RU4BQv%2B6KpKWe0c72sH%2FINsSkjt94UNF%2F96q1AEMZgFXtRDOcNGMS29mFUdNz3bknVEt9sU6GmTTm88OH8w9ccQl3o6fHv3iEjED5kS1TqOftxi9nwn%2FTfPE%2FpA%2FZ95kllf%2FYBuHxVyfMU%2B7FLOgxYs3l7C2wzeXsLYJN5e4tYNjEvPifcJqAO83b%2BGyHx28hNpYYhBZc%2FvDJMaNJPkr0kA1%2BiRG95FX892g%2FTMaZqrPUn1Ssakqe7xIZYlH77K%2FAujGZoPFYwBnGYDsvp8xoR8SjfVmoYkmz5wyvDlMTWSRJyc38186J5xe6pDx3Kd41IPsk2lnjLZlOmnQIhXGK%2Ba0SC2JV814gEgQn5rhEdRt5qQgOsLrWBNehgtMM24GC0AzbmYLSL5c5nkZa4jKV0WiSLewm9OXgdzq7ApRe8h4qpKGrltSQ50Zc%2F9leLx387ig29zgvDXiDu23CeZVNgHar7kuX6CxTifvAeREm8Z6k%2BMdLyL%2B7KyfZuhS3RE1Cc60vHXK6RW2vI2N015LTUkLHb3JAW7gvGg%2Flh6ZIU7yb05yC8gdFt5MeQwmDxiKRxdATersFqufDjJL6St8by7gvDYiDu23KeZVvAH6oDw4yE5nCpHKDRntGFrHGG1PJ9dgdTujrcTu0Zldid2DMqgTu0Zw4m9e5cA6wuDbCptJpJOrG1mEk6gTWaSTpjWcOcN%2BDulHtfKp0lXYt%2BcS9J0yZsUZmzmvZ1i9fFqlj1xmV%2F4Zd%2B5SbSGdOyaBzizNYAT7vnuBnC7A6GMSERRblw8wi9Gru1A%2FK3igZMXGIDzmgNmLiNDaCbRgTPqC8jkMZL3Sya6DGL9gTidbEqVr1xGVj4rYUVNpCkuNwjy5A5DdXshQVJiEjHGMeVc48swBZzjywAlnGPjGOLaIDVpQFWiZjOjM3YRGfGZmCGM2MvNnHmHnCVKXFmMFtGscHQ2WIcQe9G4I5aPIcRXIqDnbHkn3C2mwuIy%2BngLUfoRIojMso6sSF3pvyinWTsYCtEjokZvUAE5EeMXBz%2BnGZdFEdO6m4JVZOqjVKqvwSfM1Tg2ctnLO%2F5NEbqLsh5GxeErxyJvuR5cLaXC4jLneAtR%2FjssQeExd%2Fpk0X4uI%2B5n4AiVdKJFLgY3QLnksU1%2FGSRPLahJ4vkgY0%2BWWTzTWlNA6wuDbC6ZA621WIXk9hSi11MArdY7GIyliVmyf7hZjnErYfuL6Mw%2FZUNxaKtZpF40Kt4cOCEtFPunqajdSxyG48npOwLT7klKECbDUPf19QNFINlwtkN2K%2BG7DNzvuZRHATaqRWOXwF%2BeuKWwXmtlYR44pbB04p4wL%2F3ot9QagrCdwDexRG8hqj7Ud9b3%2BNJkFCpmsFlFnsAbeYJfV9TN7BOzX9V1e6R8Ht5wjXqEu7kTOoOHnk6a6pPs5TcyHTvkSjC7s4jUQTctUcydT47n%2F8HSrA4ag%3D%3D)
--
-- Appendix A:
--     How Read During Write (RDW) creates bubble in typical memory system with malloc-style of linked-list?
--
--     Being the state-of-the-art solution for 1p1c high-performance queue, this structure generally allows read side to burst read for full length of the FIFO range
--     if the write speed is comparable near zero during read time. So, it is capable for epoll style interface between hardware write and software read, where
--     the interrupt or polling will invoke the software to read, whose read pattern is highly bursty (long stall and continue to read until empty).
--
--     However, when read and write has similar speed and concurrent, the performance of the data structure is highly inefficient. To see why, we draw the illustration below. One should
--     perticularly pay attention to the last two stages of the evolution. Due to read lock, the write will create memory bubbles. The bubble in return generates pitfalls for its overwrite
--     behavior, i.e., pkt-9 was overwrote by pkt-10 even if the memory system has empty spaces.
--
--     The conclusion is that the write and read will be non-blocking, the price to pay is highly fragmented packets, which locks to much region for read and unnecessarily overwrite for write.
--
--     What appears to outside is that write thread still feels infinite space, but the read thread feels space less than the memory size. The read traffic will be glitchy.
--
--
--     Principle:
--         1) RD pointer if not active is always set to the header of the packet with smallest index in the memory
--         2) RD pointer if active is always blocking WR pointer to access this region during read time                   -> this will create holes
--         3) WR pointer will jump the read locked region and void any subsequent packet in full (no broken packet)
--         4) No GC (garbage collection) for maximum system up-time
--
--     Assumption:
--         1) During WR, the packet length is always known prior to write its first byte
--         2) Packet length is variable but shorter than half of the whole memory                                         -> prevent deadlock
--
--     Result:
--         1) Fragmentation and space efficiency drop during read and write has strong time coincidence
--
--
--      ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
--      │                                                                                                                                                          │
--      │                                                                                                                  ┌───────┐                    ┌───────┐  │
--      │                                          │                         │                                             │.......│                    │#######│  │
--      │   Symbols:                Active Pointer │        Inactive Pointer │                             Packet Under WR │.......│    Packet Under RD │#######│  │
--      │                                          │                         │                                             │.......│                    │#######│  │
--      │                                          ▼                         X                                             └───────┘                    └───────┘  │
--      │                                                                                                                                                          │
--      └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

--                          ┌───┐
--                          │RD │
--                          └─┬─┘
--                            │
--                            │
--                           │X                                                                                                                                       │
--                           │┌───────────────────────────┐┌─────┐┌──────────────────┐┌──────────────────────────────────┐┌─────┐┌───────────────────┐┌────────────── │
-- WR will wrap              ││                           ││     ││                  ││                                  ││     ││                   ││.............. │
--                           ││              0            ││  1  ││        2         ││                 3                ││  4  ││          5        ││.......6*..... │
-- RD has not started        ││                           ││     ││                  ││                                  ││     ││                   ││.............. │
--                           │└───────────────────────────┘└─────┘└──────────────────┘└──────────────────────────────────┘└─────┘└───────────────────┘└────────────── │
--                           │                                                                                                                                      ▲ │
--                           │                                                                                                                                      │ │
--                                                                                                                                                                  │
--                                                                                                                                                                ┌─┴─┐
--                                                                                                                                                                │WR │
--                                                                                                                                                                └───┘


--                                                       ┌───┐
--                                                       │RD │
--                                                       └─┬─┘
--                                                         │
--                                                         │
--                           │                             X                                                                                                          │
--                           │ ────────────────┐           ┌─────┐┌──────────────────┐┌──────────────────────────────────┐┌─────┐┌───────────────────┐┌────────────── │
-- WR has wrapped pkt-6      │ ................│           │     ││                  ││                                  ││     ││                   ││.............. │
--                           │ .......6*.......│           │  1  ││        2         ││                 3                ││  4  ││          5        ││.......6*..... │
-- RD is forced set to pkt-1 │ ................│           │     ││                  ││                                  ││     ││                   ││.............. │
--                           │ ────────────────┘           └─────┘└──────────────────┘└──────────────────────────────────┘└─────┘└───────────────────┘└────────────── │
-- pkt-0 is discarded        │                 ▲                                                                                                                      │
--                           │                 │                                                                                                                      │
--                                             │
--                                           ┌─┴─┐
--                                           │WR │
--                                           └───┘




--                                                          ┌───┐
--                                                          │RD │
--                                                          └─┬─┘
--                                                            │
--                                                            ▼
--                                                      Read Lock Range
--                           │                             │◄───►│                                                                                                    │
--                           │ ────────────────┐ ┌──────── ┌─────┐ ────────────┐      ┌──────────────────────────────────┐┌─────┐┌───────────────────┐┌────────────── │
-- RD is locking read pkt-1  │                 │ │........ │#####│ ............│      │                                  ││     ││                   ││               │
--                           │        6*       │ │...7*... │##1##│ .....7*.....│      │                 3                ││  4  ││          5        ││       6*      │
-- WR will avoid overwrite   │                 │ │........ │#####│ ............│      │                                  ││     ││                   ││               │
-- pkt-1, by spliting pkt-7  │ ────────────────┘ └──────── └─────┘ ────────────┘      └──────────────────────────────────┘└─────┘└───────────────────┘└────────────── │
--                           │                                              ▲                                                                                         │
--                           │                                              │                                                                                         │
--                                                                          │
--                                                                        ┌─┴─┐
--                                                                        │WR │
--                                                                        └───┘





--                                                                                        ┌───┐
--                                                                                        │RD │
--                                                                                        └─┬─┘
--                                                                                          │
--                                                                                          │
--                                                                                          ▼    Read Lock Range
--                           │                                                        │◄────────────────────────────────►│                                            │
--                           │ ────────────────┐ ┌────────         ────────────┐ ┌─── ┌──────────────────────────────────┐ ───────────┐               ┌────────────── │
-- RD is locking read pkt-3  │                 │ │                             │ │... │##################################│ ...........│               │               │
--                           │        6*       │ │   7*                 7*     │ │.8* │#################3################│ ....8*.....│               │       6*      │
-- WR wil avoid overwrite    │                 │ │                             │ │... │##################################│ ...........│               │               │
-- pkt-3, by spliting pkt-8  │ ────────────────┘ └────────         ────────────┘ └─── └──────────────────────────────────┘ ───────────┘               └────────────── │
--                           │                                                                                                     ▲                                  │
--                           │                                                                                                     │                                  │
--                                                                                                                                 │
--                                                                                                                               ┌─┴─┐
--                                                                                                                               │WR │
--                                                                                                                               └───┘




--                                                                                                                                                        ┌───┐
--                                                                                                                                                        │RD │
--                                                                                                                                                        └─┬─┘
--                                                                                                                                                          │
--                                                                                                                                                          │
--                                                                                                                                                          ▼ Read Lock Range
--                           │ ───────────────►│                                                                                                      │◄───────────── │
--                           │ ────────────────┐ ────────────┐                   ┌───                                      ───────────┐ ┌──────────── ┌────────────── │
-- RD is locking read pkt-6  │ ################│ ............│                   │                                                    │ │............ │############## │
--                           │ #######6*#######│ .....9*.....│                   │ 8*                                          8*     │ │.....9*..... │#######6*##### │
-- WR will avoid overwrite   │ ################│ ............│                   │                                                    │ │............ │############## │
-- pkt-6, by spliting pkt-9  │ ────────────────┘ ────────────┘                   └───                                      ───────────┘ └──────────── └────────────── │
--                           │                            ▲                                                                                                           │
-- pkt-7 is discarded        │                            │                                                                                                           │
--                                                        │
--                                                      ┌─┴─┐
--                                                      │WR │
--                                                      └───┘





--                                                                                                                        ┌───┐
--                                                                                                                        │RD │
--                                                                                                                        └─┬─┘
--                                                                                                                          │
--                                                                                                                          │
-- pkt-9 was dropped                                                                                Read Lock Range         ▼
-- pkt-10                    │                                                   │◄──────────────────────────────────────────────────►│                               │
--                           │                                ┌───────────────── ┌───                                      ───────────┐ ────────┐                     │
-- RD is locking read pkt-8  │                                │................. │###                                      ###########│ ........│                     │
--                           │                                │.......10*....... │#8*                                      ####8*#####│ ...10*..│                     │
-- Harzard of extreme long   │                                │................. │###                                      ###########│ ........│                     │
-- lock                      │                                └───────────────── └───                                      ───────────┘ ────────┘                     │
--                           │                                         ▲                                                                                              │
-- WR will avoid overwrite   │                                         │                                                                                              │
-- pkt-8, by spliting pkt-10                                           │
--                                                                   ┌─┴─┐
--                                                                   │WR │
--                                                                   └───┘

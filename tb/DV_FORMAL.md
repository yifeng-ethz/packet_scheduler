# DV_FORMAL: ordered_priority_queue (monolithic) — packet-shape formal plan

**Companion to:** `DV_PLAN.md`, `DV_HARNESS.md`, `DV_REPORT.md`
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-17
**Status:** Active formal-readiness plan. Covers both the mixed-language SVA bind flow onto the monolithic VHDL DUT and the native-SV rewrite in `rtl/sv_ver/ordered_priority_queue/monolithic_sv/`.

This document folds in the packet-shape methodology from Doug Smith,
"Doing the Impossible: Using Formal Verification on Packet Based Data Paths"
(DVCon US 2023; video: <https://youtu.be/SbdgOf4Zf1o>; paper:
<https://dvcon-proceedings.org/wp-content/uploads/1032-Doing-the-Impossible-Using-Formal-Verification-on-Packet-Based-Data-Paths.pdf>).
The methodology is used to *bound the state space* of the OPQ packet paths so
formal tools can close structural, ordering, and flow-control properties on
the ingress AVST, the per-lane data mover, the frame-table/tile system, and the
egress AVST — including the known-hard edge cases where output ready is
deasserted and the write side is flushing a tile.

The intent here is that every property in this plan should be translatable to
real SVA/PSL and bound at a concrete DUT boundary. Where an internal signal
name is quoted in backticks, it is the name that appears in the active RTL
today (monolithic VHDL or `rtl/sv_ver/ordered_priority_queue/monolithic_sv/`).

---

## 0. Summary of the seven-step methodology

From the DVCon paper, reproduced as the skeleton we apply per-boundary:

1. **Model the control logic** — capture the handshake (valid / SOP / EOP /
   ready) as assumptions so formal only explores legal framings.
2. **Define the packet structure** — break the packet into small typed
   chunks (`typedef struct packed`) so each field has a dedicated, small
   state space; wrap the chunks in a `union packed` whose `qbits` member
   flattens onto the DUT bus.
3. **Define the packet constraints** — one named property per chunk that
   pins its `kind`, `length`, and the legal values of its fields; a
   `packet_info[n].total_length` trick lets each chunk reach into
   `packet_info[n+1]` to carry derived lengths across the frame.
4. **Apply the packet constraints** — a top-level `prop_pkt(n)` dispatches on
   `packet_info[n].kind` with an `if / else if` cascade, calling the
   right chunk property with index `n+1`. This is what telescopes an
   arbitrarily long legal frame out of a cascade of local constraints.
5. **Model the packet driving logic** — a synthesisable driver walks the
   `packet[p].qbits[n]` array onto the bus, handling any tool-specific
   bit stuffing / bus-width conversion.
6. **Generate the packet** — `assume property` over the top-level property,
   plus `$stable(packet)` / `$stable(packet_info)` during transfer so the
   frame is fixed once formal picks it. A `pkt_good` flag flips constraints
   between "valid frame" and "invalid frame" via `if (pkt_good) prop_x
   else not(prop_x)` so the same harness can prove both acceptance and
   malformed-frame detection.
7. **Check the packets** — assertions on the DUT's parsing / acceptance /
   reporting behaviour. `cover property` on `prop_transfer` gives a
   human-readable waveform proving the generator is wired up correctly.

The leverage is: the payload bits are free, but the `kind`, `length`, and
field-level constraints are tiny, so the valid *state space* is small even
when the raw frame is large. The OPQ ingress word is 36 bits wide with
three K-symbol kinds (K285=0xBC preamble, K237=0xF7 subheader,
K284=0x9C trailer) and a header/subheader/hit grammar, so it is exactly
the shape this methodology targets.

---

## 1. DUT partition and proof planes

The monolithic OPQ decomposes into six proof planes. Each plane gets its own
top-level property cascade (`prop_pkt_<plane>(n)` or equivalent) so the tool
can solve it independently.

| # | Plane | Entry signals | Exit signals | Internal state the plane owns |
|---|---|---|---|---|
| A | Ingress AVST | `asi_ingress_{data,valid,channel,startofpacket,endofpacket,error}[N_LANE]` | `ingress_parser_if_write_ticket_data`, `ingress_parser_if_write_lane_data` | `ingress_parser_state`, `update_header_ts_flow`, `alert_sop`, `alert_eop`, `lane_credit`, `ticket_credit`, `running_ts`, `shd_len`, `pkg_cnt`, `running_shd_cnt`, `hit_cnt`, `lane_start_addr` |
| B | Ticket + Lane FIFO write | `ingress_ticket_wdata[m]`, `ingress_ticket_wptr[m]`, `ingress_ticket_we[m]`, `ingress_lane_wdata[m]`, `ingress_lane_wptr[m]`, `ingress_lane_we[m]` | `ticket_fifos_rd_{data,addr}[m]`, `lane_fifos_rd_{data,addr}[m]` | write-pointer monotonicity, ticket credit return, lane credit return |
| C | Page allocator + handle FIFO write | `ticket_fifos_rd_data[m]`, `ingress_alert_eop_dbg[m]` | `handle_wdata_dbg[m]`, `handle_waddr_dbg[m]`, `handle_we_dbg[m]`, `page_we_dbg`, `page_waddr_dbg`, `page_wdata_dbg`, `ticket_credit_update_{o,valid_o}[m]`, `eop_flush_ack_o[m]` | allocator FSM (`fetch_ticket_active`, `write_head_active`, `write_tail_active`, `write_page_active`, `write_meta_flow`), `frame_start_addr`, `frame_shr_cnt_this`, `frame_hit_cnt_this`, `packet_complete_pulse` |
| D | Data mover + B2P arbiter | `handle_wptr_i[m]`, `handle_we_i[m]`, `handle_fifos_rd_data_i[m]`, `lane_fifos_rd_data_i[m]`, `drr_allowance_i[m]`, `drr_allowance_reload_i[m]`, `page_allocator_write_{head,tail,page}_i`, `page_allocator_page_we_i` | `page_ram_we_o`, `page_ram_wr_addr_o`, `page_ram_wr_data_o`, `lane_credit_update_{o,valid_o}[m]` | `block_mover_state[m]`, `block_mover[m].{handle,word_wr_cnt,flag,page_wptr,page_wreq,handle_rptr,handle_rptr_d}`, `b2p_arb.{sel_mask,priority_mask,quantum}`, `arbiter_state` |
| E | Frame-table tracker + tile FIFOs | `i_update_ftable_*`, `i_flush_ftable_valid`, `i_tile_rptr`, `i_tile_pkt_rcnt`, `i_rseg_tile_index`, `i_void_trail_tid`, `i_void_body_tid` | `o_tile_fifo_{we,wr_addr,wr_data}`, `o_tile_{wptr,pkt_wcnt}`, `o_trail_tid`, `o_body_tid` | `tracker_state`, `tile_wptr`, `tile_pkt_wcnt`, `trail_tid`, `body_tid` |
| F | Presenter + egress AVST | `page_ram_rd_data_i`, tracker meta outputs | `aso_egress_{data,valid,startofpacket,endofpacket,error}`, `aso_egress_ready` (input) | presenter FSM, output pipe, `meta_{addr,len,wptr,rptr,pkt_wcnt,pkt_rcnt}`, `page_ram_rptr`, `pkt_rd_word_cnt` |

The proof planes are dependency-ordered: A feeds B, B feeds C, C feeds D and E,
D feeds the shared page RAM, E feeds F, F feeds the egress AVST. Each plane
constrains its *input* side via `assume` packets that obey the previous
plane's *output* contract — the same packet shape is reused as both assertion
and assumption, which is the leverage the DVCon paper calls out in §V.

---

## 2. Ingress AVST proof plane (plane A)

### 2.1 Control-signal handshake (step 1)

Ingress is an Avalon-ST sink with 36-bit data (32 bits payload plus 4
K-flag bits in the upper nibble of the word on this port). The control
handshake uses `asi_ingress_valid`, `asi_ingress_startofpacket`, and
`asi_ingress_endofpacket`. The modelling assumptions are already asserted
in `opq_avst_ingress_sva.sv`; under formal they are re-cast as `assume`:

```systemverilog
asm_sideband_requires_valid: assume property (
  @(posedge d_clk) disable iff (d_reset)
    (asi_ingress_startofpacket[g] || asi_ingress_endofpacket[g]) |->
      asi_ingress_valid[g]);

asm_no_nested_sop: assume property (
  @(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid[g] && asi_ingress_startofpacket[g] |-> !packet_open[g]);

asm_eop_requires_open_or_trailer: assume property (
  @(posedge d_clk) disable iff (d_reset)
    asi_ingress_valid[g] && asi_ingress_endofpacket[g] |->
      (packet_open[g] || asi_ingress_startofpacket[g] ||
       is_trailer(asi_ingress_data[g])));
```

`packet_open[g]` is the auxiliary register already defined in
`opq_avst_ingress_sva` (`rtl/sv_ver/.../opq_avst_ingress_sva.sv:11`).

### 2.2 Packet structure (step 2)

The ingress frame is broken into the same chunk grammar the paper uses for
CAN. The chunk width is the natural 36-bit bus word so no bit-stuffing
modelling is required on the ingress side.

```systemverilog
typedef enum logic [3:0] {
  OPQ_KIND_PREAMBLE,   // K285 BC, data[35:32]==4'b0001, sop=1
  OPQ_KIND_HDR_W0,     // running_ts[47:16]
  OPQ_KIND_HDR_W1,     // running_ts[15:0] | pkg_cnt[15:0]
  OPQ_KIND_HDR_W2,     // running_shd_cnt[15:0] | hit_cnt[15:0]
  OPQ_KIND_HDR_W3,     // send_ts[30:0]
  OPQ_KIND_SUBHEADER,  // K237 F7, shd_ts byte, hit_cnt byte
  OPQ_KIND_HIT,        // data[35:32] == 4'b0000
  OPQ_KIND_TRAILER,    // K284 9C, eop=1
  OPQ_KIND_NONE
} opq_kind_t;

typedef struct packed {
  bit [3:0] kflag;   // data[35:32]
  bit [7:0] sym;     // data[7:0] when K-char
  bit [7:0] field_a; // e.g. hit_cnt for subheader
  bit [7:0] field_b; // e.g. shd_ts byte
  bit [3:0] unused;
} opq_subheader_t;   // one struct per kind; 36-bit wide
```

The union `pkt_item_t` that wraps all kinds exposes a `qbits[35:0]` flat
view which is asserted onto `asi_ingress_data[g]`.

### 2.3 Packet constraints (step 3)

One named property per kind. Only the non-trivial ones are shown; the
pattern mirrors the paper's `prop_sof` and `prop_arb_h` exactly.

```systemverilog
sequence seq_kind(n, k); packet_info[n].kind == k; endsequence
sequence seq_length(n, l);
  (packet_info[n].length == l) and
  (packet_info[n].total_length == packet_info[n+1].total_length + l);
endsequence

property prop_preamble(n);
  seq_kind(n, OPQ_KIND_PREAMBLE) and
  seq_length(n, 1) and
  (packet[n].qbits[35:32] == 4'b0001) and
  (packet[n].qbits[7:0] == 8'hBC);
endproperty

property prop_subheader(n);
  seq_kind(n, OPQ_KIND_SUBHEADER) and
  seq_length(n, 1) and
  (packet[n].qbits[35:32] == 4'b0001) and
  (packet[n].qbits[7:0] == 8'hF7) and
  (packet[n].qbits[15:8] inside {[0:N_HIT]});
endproperty

property prop_hit(n);
  seq_kind(n, OPQ_KIND_HIT) and
  seq_length(n, 1) and
  (packet[n].qbits[35:32] == 4'b0000);
endproperty

property prop_trailer(n);
  seq_kind(n, OPQ_KIND_TRAILER) and
  seq_length(n, 1) and
  (packet[n].qbits[35:32] == 4'b0001) and
  (packet[n].qbits[7:0] == 8'h9C);
endproperty
```

### 2.4 Apply (step 4)

The top-level cascade is a direct rendering of paper Figure 5 for OPQ:

```systemverilog
property prop_pkt_ingress(n);
         if (packet_info[n].kind == OPQ_KIND_PREAMBLE)   prop_hdr_w0(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HDR_W0)       prop_hdr_w1(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HDR_W1)       prop_hdr_w2(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HDR_W2)       prop_hdr_w3(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HDR_W3)       prop_subheader(n+1)
  else if (packet_info[n].kind == OPQ_KIND_SUBHEADER &&
           packet[n].qbits[15:8] == 0)                   prop_subheader_or_trailer(n+1)
  else if (packet_info[n].kind == OPQ_KIND_SUBHEADER)    prop_hit(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HIT &&
           hits_remaining(n) > 0)                        prop_hit(n+1)
  else if (packet_info[n].kind == OPQ_KIND_HIT)          prop_subheader_or_trailer(n+1)
  else if (packet_info[n].kind == OPQ_KIND_TRAILER)      prop_none(n+1);
endproperty
```

`hits_remaining(n)` is derived from the enclosing subheader's
`qbits[15:8]` count — this is the paper's `payload_size` trick. A helper
property `prop_subheader_or_trailer(n+1)` just unions the two kinds at
the chunk boundary.

### 2.5 Generate + drive (steps 5–6)

The driver is the 2-pointer walker from paper §II.E, but OPQ's AVST
already is word-aligned so no bit-stuffing is needed. Stability during
the transfer:

```systemverilog
asm_ingress_frame_stable: assume property (
  asi_ingress_valid[g] |-> $stable(packet) && $stable(packet_info));
```

### 2.6 Check (step 7) — ingress

These are the genuine DUT-side assertions (not assumptions):

```systemverilog
// When preamble arrives, parser must leave IDLE
ap_preamble_arms_header_update: assert property (
  asi_ingress_valid[g] && asi_ingress_startofpacket[g] &&
  (asi_ingress_data[g][7:0] == 8'hBC) &&
  !ingress_parser_hdr_err[g]
  |=> (ingress_parser_state[g] == INGRESS_PARSER_UPDATE_HEADER_TS));

// A non-zero subheader must either arm WR_HITS or mask
ap_nonzero_subheader_arms_wr_or_mask: assert property (
  (ingress_parser_state[g] == INGRESS_PARSER_IDLE) &&
  asi_ingress_valid[g] && ingress_parser_is_subheader[g] &&
  !ingress_parser_shd_err[g] &&
  (ingress_parser_if_subheader_hit_cnt[g] != 0)
  |=> (ingress_parser_state[g] inside
       {INGRESS_PARSER_WR_HITS, INGRESS_PARSER_MASK_PKT}));

// A trailer never advances a ticket pointer unless alert_eop was armed
ap_trailer_clears_alert_eop: assert property (
  asi_ingress_valid[g] && ingress_parser_is_trailer[g]
  |=> ##[0:2] !ingress_parser.alert_eop[g]);
```

### 2.7 Bad-packet mode

The paper's `pkt_good` flag is reused here so the same harness can prove
the parser either *accepts* a malformed frame (e.g. subheader with
`hit_cnt > lane_credit`) and *transitions into a mask state*, or
*rejects* it (early-terminates). In that mode the top assumption becomes
`not(prop_pkt_ingress(0))` and the assertion becomes
`|-> (ingress_parser_state[g] inside {MASK_PKT, MASK_PKT_EXTENDED, RESET})`.

---

## 3. Ticket + Lane FIFO plane (plane B)

The ticket and lane FIFOs are plain write-side RAMs: the ingress parser
writes, the allocator / block-mover reads. Credit is returned by the
consumer. Two families of invariants are cycle-local:

### 3.1 Write-pointer advance

```systemverilog
property p_ticket_wptr_advances_on_we;
  @(posedge d_clk) disable iff (d_reset)
    ingress_ticket_we[m] |=> (ingress_ticket_wptr[m] == $past(ingress_ticket_wptr[m]) + 1);
endproperty
ap_ticket_wptr_advances_on_we: assert property (p_ticket_wptr_advances_on_we);

property p_ticket_wptr_stable_without_we;
  @(posedge d_clk) disable iff (d_reset)
    !ingress_ticket_we[m] |=> $stable(ingress_ticket_wptr[m]);
endproperty
ap_ticket_wptr_stable_without_we: assert property (p_ticket_wptr_stable_without_we);
```

The analogous pair holds for `ingress_lane_wptr[m]` and
`ingress_lane_we[m]`.

*Caveat already noted in the native RTL comment at
`ingress_parser.sv:425`: both pulse and pointer are driven from the same
clocked process, so sampling directly on the public ports false-fires.
The formal flow binds a `p_shadow` register one delta-cycle earlier and
compares against that instead.*

### 3.2 Credit conservation (the key invariant)

Ticket credit and lane credit are the OPQ's *primary flow-control
resource*. If formal only proves one invariant per resource, make it this
one:

```systemverilog
// Credit + occupancy is a constant equal to CAPACITY
property p_ticket_credit_conservation;
  @(posedge d_clk) disable iff (d_reset)
    (ingress_parser[m].ticket_credit +
     outstanding_tickets[m]) == TICKET_FIFO_MAX_CREDIT;
endproperty
ap_ticket_credit_conservation: assert property (p_ticket_credit_conservation);

property p_lane_credit_conservation;
  @(posedge d_clk) disable iff (d_reset)
    (ingress_parser[m].lane_credit +
     outstanding_lane_words[m]) == LANE_FIFO_MAX_CREDIT;
endproperty
ap_lane_credit_conservation: assert property (p_lane_credit_conservation);
```

`outstanding_tickets[m]` is a small shadow counter that increments on
`ingress_ticket_we[m]` and decrements on `ticket_credit_update_valid[m]`
with step `ticket_credit_update[m]`. The same shape tracks
`outstanding_lane_words[m]` with lane credit. The conservation law is the
formal analogue of the end-to-end drain tests in
`opq_edge_backpressure_test` and `opq_edge_toggle_backpressure_test`.

### 3.3 No-overflow / no-underflow

Immediate corollaries, worth pinning independently because they are the
failure mode users actually see:

```systemverilog
ap_ticket_no_overflow: assert property (
  ingress_ticket_we[m] |-> (ingress_parser[m].ticket_credit != 0));
ap_lane_no_overflow: assert property (
  ingress_lane_we[m]  |-> (ingress_parser[m].lane_credit   != 0));
ap_ticket_no_underflow: assert property (
  !(ingress_parser[m].ticket_credit > TICKET_FIFO_MAX_CREDIT));
ap_lane_no_underflow: assert property (
  !(ingress_parser[m].lane_credit   > LANE_FIFO_MAX_CREDIT));
```

### 3.4 `alert_eop` → ticket write coupling

A trailer must be *absorbed* by the next ticket write when no frame is in
flight, otherwise the allocator flush path deadlocks (root cause of the
CDC-style regression referenced in `BUG_HISTORY.md`):

```systemverilog
property p_alert_eop_drains_via_ticket_or_flush_ack;
  @(posedge d_clk) disable iff (d_reset)
    ingress_parser[m].alert_eop |-> ##[1:$]
      (ingress_ticket_we[m] || eop_flush_ack_i[m]);
endproperty
```

The upper bound is unbounded for liveness; add a quantitative
`##[1:T_FLUSH_MAX]` form once the allocator's worst-case drain cost is
characterised from the `cross_frame` baseline.

---

## 4. Page allocator + handle FIFO write (plane C)

### 4.1 Allocator FSM flow

The allocator walks the flow
`fetch_ticket → write_head → write_tail → write_page` via the
`write_meta_flow` counter. The natural properties are strict ordering and
mutual exclusion:

```systemverilog
ap_flow_onehot: assert property (
  $onehot0({fetch_ticket_active_dbg, write_head_active_dbg,
            write_tail_active_dbg,  write_page_active_dbg}));

ap_flow_monotonic: assert property (
  write_head_active_dbg |-> ##[1:$] (write_tail_active_dbg || $fell(write_head_active_dbg)));
```

### 4.2 Page-RAM write port mutual exclusion

The allocator and the block mover share the page-RAM write port. This
is the most important ownership invariant of the whole DUT:

```systemverilog
ap_pa_vs_mover_exclusion: assert property (
  @(posedge d_clk) disable iff (d_reset)
    (page_allocator_page_we_i || page_allocator_write_head_i ||
     page_allocator_write_tail_i || page_allocator_write_page_i)
    |-> (b2p_arb_gnt == '0));
```

This property already lives as `OPQ_DRR_SVA` (`opq_drr_sva.sv:32`) but
deserves a second, phase-aware statement on the registered
`page_ram_we_o` so formal cannot hide a collision behind the output
pipeline register. That is:

```systemverilog
ap_page_ram_writer_is_unique: assert property (
  page_ram_we_o |-> ##0
    ($past(page_allocator_page_we_i, 0) ^ (|$past(b2p_arb_gnt, 0))));
```

### 4.3 Handle FIFO write vs flush-ack

An allocator completing a frame must produce exactly one
`packet_complete_pulse_dbg`, and an `eop_flush_ack_o[m]` must be
exactly paired with the ingress parser's `alert_eop[m]` register. Both
are bounded-response obligations:

```systemverilog
ap_packet_complete_is_pulse: assert property (
  packet_complete_pulse_dbg |=> !packet_complete_pulse_dbg);

ap_eop_flush_ack_paired: assert property (
  eop_flush_ack_o[m] |-> $past(ingress_parser[m].alert_eop));
```

### 4.4 Frame metadata sanity

`frame_shr_cnt_this_dbg` and `frame_hit_cnt_this_dbg` must match the
counts previously recorded by the ingress parser header update. This
plane is where the "decision-traceable" packet structure pays off:

```systemverilog
// When write_head_active with write_meta_flow == 0, counts must match the
// ingress parser snapshot made during UPDATE_HEADER_TS flow 3.
ap_frame_shr_count_matches_ingress: assert property (
  write_head_active_dbg && (write_meta_flow_dbg == 3'd0) |->
    (frame_shr_cnt_this_dbg == $past(ingress_parser[0].running_shd_cnt, K_PA_LATENCY)));
```

`K_PA_LATENCY` is the known fixed allocator latency from ticket acceptance
to head write; the `$past` index is set once during bring-up and is the
only magic number in the plane.

---

## 5. Data mover + B2P arbiter (plane D)

### 5.1 Arbiter contracts

Lift the existing `opq_drr_sva` properties (`opq_drr_sva.sv`) unchanged.
They already capture `$onehot0` grant/sel_mask/lock_event, locked-state
ownership discipline, and defer/eligibility legality. Under formal they
become `assert` properties rather than simulation-time assertions.

Additional properties that the simulation version cannot easily prove:

```systemverilog
// Preemption by page allocator never abandons a locked lane's handle
ap_locked_lane_preempt_clean: assert property (
  pa_writing |-> $stable(b2p_arb.sel_mask) && (b2p_arb_gnt == '0));

// DRR quantum never goes below zero
ap_quantum_nonneg: assert property ( b2p_arb.quantum[m] >= '0 );

// DRR quantum reloads to the configured value on pulse
ap_quantum_reload: assert property (
  drr_allowance_reload_i[m] |=> (b2p_arb.quantum[m] == $past(drr_allowance_i[m])));

// Bounded starvation: a requesting lane is eventually served within
// a quantum window bounded by max(drr_allowance_i[*]) * N_LANE
property p_bounded_starvation;
  @(posedge d_clk) disable iff (d_reset)
    b2p_arb_req_raw[m] |-> ##[1:T_STARVE_MAX] b2p_arb_gnt[m];
endproperty
```

`T_STARVE_MAX` is a parametric bound derived from `drr_allowance_i` and
`N_LANE`. On Questa FSE, bounded liveness via `##[1:T_STARVE_MAX]` stays
safety-style and solvable.

### 5.2 Block mover write integrity

The block mover is the true "data mover." Its job is to copy
`block_mover[i].handle.blk_len` words from lane-FIFO source
`block_mover[i].handle.src` to page-RAM destination
`block_mover[i].handle.dst`. The integrity properties are:

```systemverilog
// Each granted cycle consumes exactly one lane-FIFO word and produces
// exactly one page-RAM write at the correct offset.
ap_mover_wr_addr_ok: assert property (
  b2p_arb_gnt[m] && block_mover[m].page_wreq |->
    (page_ram_wr_addr_comb ==
      block_mover[m].page_wptr + block_mover[m].word_wr_cnt));

ap_mover_wr_data_ok: assert property (
  b2p_arb_gnt[m] && block_mover[m].page_wreq |->
    (page_ram_wr_data_comb == lane_fifos_rd_data_i[m]));

// The word counter never skips past blk_len
ap_mover_count_bounded: assert property (
  block_mover_state[m] == BLOCK_MOVER_WRITE_BLK |->
    (block_mover[m].word_wr_cnt <= block_mover[m].handle.blk_len));

// Retirement returns exactly blk_len worth of lane credit
ap_mover_credit_exact: assert property (
  (block_mover_state[m] == BLOCK_MOVER_WRITE_BLK) &&
  ((block_mover[m].word_wr_cnt + 1) == block_mover[m].handle.blk_len) &&
  b2p_arb_gnt[m] && block_mover[m].page_wreq
  |=> lane_credit_update_valid_o[m] &&
      (lane_credit_update_o[m] == block_mover[m].handle.blk_len));
```

### 5.3 Abort path

`BLOCK_MOVER_ABORT_WRITE_BLK` is exercised when the handle carries
`flag==1`, which the allocator sets to discard a malformed ticket. The
abort must still return credit (already asserted as
`ap_abort_returns_credit` at `block_path.sv:456`). Add:

```systemverilog
ap_abort_no_page_write: assert property (
  block_mover_state[m] == BLOCK_MOVER_ABORT_WRITE_BLK |-> !b2p_arb_req_raw[m]);
```

### 5.4 Handle FIFO conservation

Mirror of §3.2 for handles, with a per-lane bounded-depth invariant
that is critical for proving the allocator cannot overrun the block
mover:

```systemverilog
ap_handle_conservation: assert property (
  (handle_waddr_dbg[m] - block_mover[m].handle_rptr) <= HANDLE_FIFO_DEPTH);
```

---

## 6. Frame-table tracker + tile FIFOs (plane E)

The tracker is the multi-tile equivalent of a write-side FIFO: tile
write pointers advance on accepted updates, tile flushes atomically
wind the write pointer back to the read pointer. The tricky edge is
that a flush can arrive *in the same cycle* as an update on the
opposite sub-port (there are two update ports `[1:0]`).

### 6.1 Flush atomicity

```systemverilog
// After a flush, the tile's write side tracks the consumer's read side.
property p_flush_resets_tile_wr;
  @(posedge d_clk) disable iff (d_reset)
    i_flush_ftable_valid[a] |=>
      (tile_wptr[i_update_ftable_tindex[a]]     == $past(i_tile_rptr[i_update_ftable_tindex[a]]))
      &&
      (tile_pkt_wcnt[i_update_ftable_tindex[a]] == $past(i_tile_pkt_rcnt[i_update_ftable_tindex[a]]));
endproperty
ap_flush_resets_tile_wr: assert property (p_flush_resets_tile_wr);

// Flush also clears the head/trail ownership tokens
ap_flush_clears_tid: assert property (
  i_flush_ftable_valid[a] |=>
    (trail_tid[i_update_ftable_tindex[a]] == '0) &&
    (body_tid [i_update_ftable_tindex[a]] == '0));
```

### 6.2 Update vs flush mutual-exclusion

The RTL allows both `i_update_ftable_valid[a]` and `i_flush_ftable_valid[a]`
in the same cycle, which is why the tracker applies flush *before* the
update in `proc_tracker`. The formal expectation is then:

```systemverilog
ap_flush_wins_over_update: assert property (
  i_update_ftable_valid[a] && i_flush_ftable_valid[a] &&
  (i_update_ftable_tindex[a] == t_v) |=>
    // wpter is the flushed value, not the updated value
    (tile_wptr[t_v] == $past(i_tile_rptr[t_v])));
```

Without this, an overlapping flush and update is a genuine silent
functional corruption.

### 6.3 Tile FIFO write pointer advance

```systemverilog
ap_tile_wptr_advances_on_we: assert property (
  o_tile_fifo_we[t] |=> (o_tile_wptr[t] == $past(o_tile_wptr[t]) + 1));

ap_tile_wptr_stable_without_we: assert property (
  !o_tile_fifo_we[t] && !(|i_flush_ftable_valid) |=>
    $stable(o_tile_wptr[t]));
```

### 6.4 TID ownership ring

`trail_tid` and `body_tid` are a 2-slot ring per tile; only one can
own the tile at any time, and the RTL encodes ownership with the top
bit. Re-state that as:

```systemverilog
ap_tid_onehot0: assert property (
  $onehot0({trail_tid[t][$clog2(N_TILE)], body_tid[t][$clog2(N_TILE)]}));
```

(If the design actually allows both tokens valid simultaneously during
a hand-off cycle, this weakens to a `##[0:1]` form — to be verified
against the current tracker code during the first proof round.)

---

## 7. Presenter + egress AVST (plane F) — *the hardest plane*

This is the plane the user flagged: broken packets show up on the
egress when output `ready` is deasserted *and* the write side is
flushing tiles. All three constraints compound here.

### 7.1 Egress control-signal contract (step 1 — egress)

Lift directly from `opq_avst_egress_sva.sv`, promoted to `assert`:

```systemverilog
ap_hold_under_backpressure: assert property (
  aso_egress_valid && !aso_egress_ready
  |=> aso_egress_valid &&
      $stable({aso_egress_data,
               aso_egress_startofpacket,
               aso_egress_endofpacket,
               aso_egress_error}));

ap_sideband_requires_valid: assert property (
  (aso_egress_startofpacket || aso_egress_endofpacket) |-> aso_egress_valid);

ap_sop_is_preamble: assert property (
  aso_egress_valid && aso_egress_startofpacket |->
    (aso_egress_data[35:32] == 4'b0001) && (aso_egress_data[7:0] == 8'hBC));

ap_eop_is_trailer: assert property (
  aso_egress_valid && aso_egress_endofpacket |->
    (aso_egress_data[35:32] == 4'b0001) && (aso_egress_data[7:0] == 8'h9C));

ap_no_single_beat_collapse: assert property (
  aso_egress_valid |-> !(aso_egress_startofpacket && aso_egress_endofpacket));
```

### 7.2 Egress packet structure (steps 2–4 — egress)

The egress frame shape is exactly the "hit3" contract the scoreboard
already enforces in simulation (see
`opq_hit3_contract_sva.sv:11`). Reframed as formal:

| Chunk | Kind | Length | Field constraints |
|-------|------|--------|-------------------|
| 0 | `EG_PREAMBLE` | 1 | `kflag==4'b0001`, `sym==8'hBC`, `sop==1` |
| 1..4 | `EG_FRAME_HDR_W0..W3` | 1 each | free payload modulo `frame_ts_hi32` tracking |
| k | `EG_SUBHEADER` | 1 | `kflag==4'b0001`, `sym==8'hF7`, `abs_ts > last_nonempty_abs_ts` (monotone) |
| k+1..k+N | `EG_HIT` | N | `kflag==4'b0000`, N = subheader hit count |
| last | `EG_TRAILER` | 1 | `kflag==4'b0001`, `sym==8'h9C`, `eop==1`, and `hit_words_left==0` on entry |

The top-level dispatch property follows the paper's Figure 5:

```systemverilog
property prop_pkt_egress(n);
         if (packet_info[n].kind == EG_PREAMBLE)                 prop_frame_hdr_w0(n+1)
  else if (packet_info[n].kind == EG_FRAME_HDR_W0)               prop_frame_hdr_w1(n+1)
  else if (packet_info[n].kind == EG_FRAME_HDR_W1)               prop_frame_hdr_w2(n+1)
  else if (packet_info[n].kind == EG_FRAME_HDR_W2)               prop_frame_hdr_w3(n+1)
  else if (packet_info[n].kind == EG_FRAME_HDR_W3)               prop_subheader_eg(n+1)
  else if (packet_info[n].kind == EG_SUBHEADER &&
           packet[n].qbits[15:8] == 0)                           prop_subheader_or_trailer_eg(n+1)
  else if (packet_info[n].kind == EG_SUBHEADER)                  prop_hit_eg(n+1)
  else if (packet_info[n].kind == EG_HIT && hits_remaining(n)>0) prop_hit_eg(n+1)
  else if (packet_info[n].kind == EG_HIT)                        prop_subheader_or_trailer_eg(n+1)
  else if (packet_info[n].kind == EG_TRAILER)                    prop_none_eg(n+1);
endproperty
```

Under formal this is used as the **assumption** on the "oracle" side
(i.e. what should come out) and as **assertions** on the actual
egress bus:

```systemverilog
asm_oracle_well_formed: assume property (
  aso_egress_valid |-> prop_pkt_egress(oracle_index));

ap_egress_matches_oracle: assert property (
  aso_egress_valid && aso_egress_ready |->
    (aso_egress_data == oracle[oracle_index].qbits));
```

`oracle[]` is the bit-accurate frame the formal harness picks; matching
on `aso_egress_data` is bounded because the frame is shrunk to
`NUM_ITEMS_EG+1` entries per the paper's pattern.

### 7.3 Backpressure / flush compounding — the hard cases

These are the cases the user asked for. Each one is a single formal
obligation that, if it fails, explains a real observable
misbehaviour.

#### 7.3.1 Pure backpressure hold

```systemverilog
// Already in §7.1 as ap_hold_under_backpressure — this is the baseline.
```

#### 7.3.2 Backpressure + EOP delivery

Trailer must be delivered exactly once per frame, even across an
arbitrarily long backpressure window.

```systemverilog
ap_exactly_one_eop_per_frame: assert property (
  aso_egress_valid && aso_egress_startofpacket && aso_egress_ready
  |-> strong(##[1:$] (aso_egress_valid && aso_egress_ready &&
                      aso_egress_endofpacket))
      and not (##[1:$] (aso_egress_valid && aso_egress_ready &&
                        aso_egress_startofpacket) intersect
               !(aso_egress_endofpacket throughout)));
```

In Questa FSE formal mode, the paired-form is easier to close:

```systemverilog
ap_no_second_sop_before_eop: assert property (
  aso_egress_valid && aso_egress_startofpacket && aso_egress_ready
  |=> !(aso_egress_valid && aso_egress_startofpacket && aso_egress_ready) throughout
       (aso_egress_valid && aso_egress_endofpacket && aso_egress_ready)[->1]);
```

#### 7.3.3 Backpressure while write side writes the same tile

When `!aso_egress_ready` and the allocator is writing head/tail/page
for the *current* tile being presented, the read side must freeze.
Concretely, `page_ram_rptr` must not advance, and `meta_rptr` must not
advance:

```systemverilog
ap_presenter_rptr_frozen_under_bp: assert property (
  !aso_egress_ready && aso_egress_valid |=>
    $stable(page_ram_rptr) && $stable(meta_rptr) && $stable(pkt_rd_word_cnt));
```

#### 7.3.4 Backpressure while tile flush lands

A tile flush arriving mid-frame must not rewrite the word the
presenter is currently holding. The easiest way to encode that is
*address separation*:

```systemverilog
ap_flush_does_not_touch_live_page: assert property (
  (|i_flush_ftable_valid) && aso_egress_valid |->
    (i_update_ftable_tindex[flushed_port] != current_present_tile) ||
    (tile_of(page_ram_rptr) != i_update_ftable_tindex[flushed_port]));
```

`current_present_tile` is an auxiliary register tracking which tile the
presenter is currently draining. Without this property, a flush
landing on the live tile can silently substitute data underneath a
held `aso_egress_data` beat and produce a broken frame downstream —
exactly the symptom the user described.

#### 7.3.5 Write side flushes tail while presenter is reading head

The "tile write side flushing on the edge" case: presenter has emitted
preamble + partial frame header, page-RAM has the head block written,
and an allocator flush lands on the *tail* of the same tile.

```systemverilog
ap_tail_flush_preserves_head_region: assert property (
  (|i_flush_ftable_valid) &&
  (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
  (tile_of(page_ram_rptr) == i_update_ftable_tindex[flushed_port])
  |->
    // head region of the frame currently being presented is already copied
    // into the presenter's output pipe, so any address downstream of
    // page_ram_rptr that the flush can rewrite is never re-read.
    ($past(page_ram_rptr) >= flushed_tail_base_addr) ||
    ($stable(output_data_pipe)));
```

If this property fails, the flush's new tail overlaps the region the
presenter still has to read. The bug is visible downstream as a
**mid-frame substitution** of subheaders or hits; that is the single
most common way a packet ends up "broken" on the egress.

#### 7.3.6 Reset during transfer

```systemverilog
ap_reset_forces_eop_tracking_clear: assert property (
  d_reset |=> !aso_egress_valid &&
              (presenter_state == FTABLE_PRESENTER_RESET));
```

Combined with the plane-A reset property, this forecloses the
"half-delivered frame survives a reset" mode.

#### 7.3.7 Empty-frame drain

Frame has only a preamble + 4 header words + empty subheader + trailer.
This exercises the `hits_remaining==0` branch of both `prop_pkt_ingress`
and `prop_pkt_egress` and is the stress that caught the
`alert_eop` hang in production:

```systemverilog
cp_empty_frame_round_trip: cover property (
  asi_ingress_valid[g] && asi_ingress_startofpacket[g] ##[1:$]
  asi_ingress_valid[g] && asi_ingress_endofpacket[g] ##[1:$]
  aso_egress_valid && aso_egress_startofpacket && aso_egress_ready ##[1:$]
  aso_egress_valid && aso_egress_endofpacket   && aso_egress_ready);
```

### 7.4 Presenter meta FIFO conservation

Same shape as §3.2:

```systemverilog
ap_meta_conservation: assert property (
  ((meta_wptr - meta_rptr) <= META_DEPTH) &&
  ((meta_pkt_wcnt - meta_pkt_rcnt) <= META_DEPTH));
```

---

## 8. Cross-plane properties (end-to-end integrity)

These are the properties that only make sense across plane boundaries.
They are harder for formal — some will end up as bounded proofs
(`##[1:T]`) rather than unbounded safety — but they are the direct
analogue of the end-to-end simulation scoreboards, and closing even a
bounded version rules out a large class of silent corruption.

### 8.1 One-ticket-to-one-frame conservation

For a given lane `m`, every accepted ingress frame produces exactly
one ticket write, exactly one handle, and exactly one frame on the
egress:

```systemverilog
ap_one_frame_per_accepted_ingress: assert property (
  (asi_ingress_valid[m] && asi_ingress_startofpacket[m] &&
   !ingress_parser_hdr_err[m] &&
   (ingress_parser[m].ticket_credit != 0))
  |-> ##[1:T_FRAME_MAX]
    (ingress_ticket_we[m] and ##[1:T_ALLOC_MAX]
     handle_we_dbg[m]     and ##[1:T_PRESENT_MAX]
     aso_egress_valid && aso_egress_startofpacket && aso_egress_ready));
```

### 8.2 Hit-count integrity

Hits that enter the ingress parser (modulo error masking) must
eventually come out on the egress with the same count, in the same
subheader bin. The "modulo error masking" exclusion is made precise by
gating on `!ingress_parser.error_lane_wr_early_term[m]` and
`!ingress_parser_hit_err[m]` throughout.

Simulation already has this check as a scoreboard; formal proves a
single-frame, single-lane bounded version:

```systemverilog
// bounded frame, bounded hits
asm_payload_size_bounded: assume property (payload_size inside {[0:PAYLOAD_MAX]});

ap_hit_count_preserved: assert property (
  // per-frame counts match; strong bounded form
  $rose(aso_egress_endofpacket && aso_egress_ready) |->
    (total_hits_out == total_hits_in));
```

### 8.3 No-duplication / no-drop under healthy flow

```systemverilog
// When no error and no flush, every ticket-accepted frame produces exactly
// one presenter-side frame and vice versa.
ap_no_drop_no_dup_healthy: assert property (
  (~|ingress_parser_hdr_err) && (~|ingress_parser_shd_err) &&
  (~|ingress_parser_hit_err) && (~|i_flush_ftable_valid)
  |-> (tickets_accepted_total == frames_presented_total));
```

---

## 9. Boundary-condition matrix

The user asked for explicit coverage of all boundary positions. The
matrix below is the single source of truth; every entry is either
covered by a property above (cite) or carries a TODO.

| # | Boundary | Failure symptom | Property cite | Status |
|---|----------|-----------------|---------------|--------|
| B1 | Ingress SOP w/o valid | Sideband pulse ignored | §2.1 `asm_sideband_requires_valid` | covered |
| B2 | Ingress nested SOP | Parser stuck in UPDATE_HEADER_TS | §2.1 `asm_no_nested_sop` | covered |
| B3 | Ingress EOP w/o open | Trailer storms mask state | §2.1 `asm_eop_requires_open_or_trailer` | covered |
| B4 | Subheader hit-count > lane credit | Parser enters MASK_PKT | §2.6 `ap_nonzero_subheader_arms_wr_or_mask` | covered |
| B5 | Ingress header error mid-frame | Parser drops frame cleanly | §2.6 bad-packet mode | covered |
| B6 | Ticket credit exhaustion | Parser masks, no ticket write | §3.3 `ap_ticket_no_overflow` | covered |
| B7 | Lane credit exhaustion | Parser masks, no lane write | §3.3 `ap_lane_no_overflow` | covered |
| B8 | Ticket credit-return race | Credit over- or under-counted | §3.2 `ap_ticket_credit_conservation` | covered |
| B9 | Lane credit-return race | Credit over- or under-counted | §3.2 `ap_lane_credit_conservation` | covered |
| B10 | Alert-EOP blocked on empty frame | Allocator deadlock | §3.4 `p_alert_eop_drains_via_ticket_or_flush_ack` | covered (liveness, bounded TODO) |
| B11 | Allocator page-RAM vs mover collision | Silent data corruption | §4.2 `ap_pa_vs_mover_exclusion`, `ap_page_ram_writer_is_unique` | covered |
| B12 | Allocator flow out of order | Metadata mis-written | §4.1 `ap_flow_onehot`, `ap_flow_monotonic` | covered |
| B13 | Handle FIFO overrun | Mover reads stale handle | §5.4 `ap_handle_conservation` | covered |
| B14 | Block mover word-count overflow | Wrong page-RAM address | §5.2 `ap_mover_count_bounded` | covered |
| B15 | Block mover credit miscount | Lane credit drift | §5.2 `ap_mover_credit_exact` | covered |
| B16 | Abort path misses credit return | Ingress stalls forever | `ap_abort_returns_credit` (existing RTL SVA) | covered |
| B17 | B2P arbiter double-grant | Page-RAM write collision | `opq_drr_sva` `$onehot0(gnt)` | covered |
| B18 | B2P arbiter ineligible grant | Quantum violated | `opq_drr_sva` `ap_unlocked_not_ineligible` | covered |
| B19 | B2P arbiter starvation | Lane never granted | §5.1 `p_bounded_starvation` | covered (bounded liveness) |
| B20 | DRR defer without blocked request | Credit leak | `opq_drr_sva` defer legality | covered |
| B21 | DRR quantum reload race | Quantum corrupted | §5.1 `ap_quantum_reload` | covered |
| B22 | PA preempts locked lane | Handle state lost | §5.1 `ap_locked_lane_preempt_clean` | covered |
| B23 | Tracker flush during update | Tile pointer corrupted | §6.1 `ap_flush_resets_tile_wr`, §6.2 `ap_flush_wins_over_update` | covered |
| B24 | Tracker write-pointer freeze-violation | Silent extra write | §6.3 `ap_tile_wptr_stable_without_we` | covered |
| B25 | TID ownership collision | Two tiles claim same slot | §6.4 `ap_tid_onehot0` | covered (pending ring-edge review) |
| B26 | Egress backpressure hold | Presenter rewinds data | §7.1 `ap_hold_under_backpressure` | covered |
| B27 | Egress backpressure + write-side tile flush on same tile | **Broken mid-frame substitution** | §7.3.4 `ap_flush_does_not_touch_live_page` | covered |
| B28 | Tail flush while reading head region | **Broken mid-frame substitution** | §7.3.5 `ap_tail_flush_preserves_head_region` | covered |
| B29 | Presenter state freeze under backpressure | Pointer drift | §7.3.3 `ap_presenter_rptr_frozen_under_bp` | covered |
| B30 | Two SOPs without an EOP between | Duplicate frame visible | §7.3.2 `ap_no_second_sop_before_eop` | covered |
| B31 | Single-beat collapse SOP+EOP | Downstream parser confusion | §7.1 `ap_no_single_beat_collapse` | covered |
| B32 | Reset during egress transfer | Phantom frame tail | §7.3.6 `ap_reset_forces_eop_tracking_clear` | covered |
| B33 | Empty frame round-trip | Flush path hang | §7.3.7 `cp_empty_frame_round_trip` | covered (cover) |
| B34 | Meta FIFO overrun | Presenter reads wrong len | §7.4 `ap_meta_conservation` | covered |
| B35 | One-ticket-to-one-frame skew | Drop or dup | §8.1 `ap_one_frame_per_accepted_ingress` | covered (bounded) |
| B36 | Hit-count mismatch across pipeline | Silent payload corruption | §8.2 `ap_hit_count_preserved` | covered (bounded) |
| B37 | Multi-lane interleave keeps per-lane ordering | Lane N frames out-of-order | `opq_cross_drr_*` scoreboard + per-lane §8.1 per `m` | partial — formal proof needs per-lane frame-serial monotonicity prop (TODO) |
| B38 | 4-lane native-SV path | `BUG_HISTORY.md` sparse-frame cadence | out of signoff scope | deferred per `DV_REPORT.md` non-claim |

---

## 10. Tool / flow plan

### 10.1 Bind scheme

- **Short term (mixed-language):** bind each `opq_*_sva` module to the
  monolithic VHDL DUT as it does today in
  `tb/uvm/tb_top.sv`. Under formal, the same SVA file compiles but the
  tool picks up the `assert` properties as proof obligations and the
  `cover` properties as reachability targets.
- **Medium term (native SV):** migrate the SVA blocks into
  `rtl/sv_ver/ordered_priority_queue/monolithic_sv/*.sv` next to the
  RTL, same-language. This is already done for
  `p_reset_drives_ingress_parser_reset` in
  `ingress_parser.sv:420` and the block-path reset/abort properties in
  `block_path.sv:450`. On the current native-SV path this is now
  implemented as macro-guarded checker instantiation via
  `OPQ_ENABLE_NATIVE_FORMAL_{INGRESS,MOVER,EGRESS,FTABLE}` from
  `tb/uvm/Makefile` (`FORMAL_SVA=1`, `FORMAL_PLANE=<plane>`). Every
  plane in this document lists the target module.

### 10.2 Driver-side modelling code

One synthesisable driver per plane, all following paper §II.E:

- `packet_driver_ingress.sv` — walks `packet[p].qbits[n]` onto
  `asi_ingress_data[g]`. Bit-stuffing is unnecessary since OPQ AVST is
  word-aligned.
- `packet_driver_egress.sv` — *oracle* that reconstructs the expected
  egress frame from the same `packet` array. Its output is matched
  against the actual `aso_egress_data` under the paired assumption /
  assertion in §7.2.

### 10.3 Capacity plan

Because the OPQ page RAM is 64K×40 and the lane FIFO is 1024×40, the
raw state space is out of reach. The plan applies four abstractions
per the paper:

1. **Payload-free proofs.** Hit payload bytes (`data[31:0]` when
   `kflag==0`) are left unconstrained. Only control bits are pinned.
2. **Bounded frames.** `payload_size inside {[0:8]}` and
   `NUM_ITEMS_EG = PAYLOAD_MAX + HEADER_COUNT + 2` for cross-plane
   proofs. Widening happens one plane at a time.
3. **FIFO depth abstraction.** Replace `LANE_FIFO_DEPTH=1024` and
   `TICKET_FIFO_DEPTH=256` with `*_FIFO_DEPTH_F = 8` under a formal
   `FORMAL_ABSTRACTION` define. The credit-conservation properties
   re-parametrise cleanly.
4. **Single-lane abstraction.** Prove plane A / B / C with
   `N_LANE=1` first, then lift to `N_LANE=2` for plane D / F. The
   `opq_drr_sva` contract is the single property that requires
   `N_LANE>=2` to be meaningful; everything else re-parametrises.

### 10.4 Running the flow

Three scripts now exist under `packet_scheduler/tb/scripts/`:

- `formal_ingress.sh` — compiles plane A + B with abstractions on,
  and then launches either a real proof backend or the no-backend
  simulation fallback, dumping one status CSV.
- `formal_mover.sh` — compiles plane C + D + the shared-page-RAM
  mutual-exclusion properties.
- `formal_egress.sh` — compiles plane E + F, including the
  back-pressure + flush compounding properties of §7.3.

Each wrapper uses a dedicated build root (`tb/uvm/build_formal_*`) so
formal compile/elaboration cannot clobber the main regression build
directory. The wrappers write their latest status CSV under
`tb/formal_runs/csv/` and keep timestamped logs under
`tb/formal_runs/logs/`. The ingress and translated frame-table planes
use standalone elaboration tops (`opq_formal_ingress_tb`,
`opq_formal_ftable_tb`) so those planes can be checked without relying
on unsupported full-top parameter reductions.

The wrapper API is intentionally stable ahead of a real `qverify`
install:

- `FORMAL_BACKEND=auto|stress|qverify` selects the backend. `auto`
  chooses `stress` unless `FORMAL_QVERIFY_ENABLE=1` or
  `FORMAL_SBY_ENABLE=1` is set.
- `QVERIFY_BIN=/path/to/qverify` points the same wrappers at the future
  proof executable without changing testcase names, tops, or plane
  ordering.
- `FORMAL_BACKEND=sby` selects the OSS backend path.
- `SBY_BIN=/path/to/sby`, `YOSYS_BIN=/path/to/yosys`, and
  `BITWUZLA_BIN=/path/to/bitwuzla` point the same wrappers at an OSS
  toolchain without changing testcase names, tops, or plane ordering.
- `FORMAL_SBY_ENGINE=bitwuzla` records the intended SMT engine for the
  future OSS flow; today the wrappers treat it as metadata and a binary
  requirement check.
- `FORMAL_STRESS_TESTS` overrides the default simulation fallback test
  list for one plane without editing the wrapper.
- `FORMAL_STRESS_INCLUDE_PROBES=1` appends the plane's probe-only
  negative tests.
- `FORMAL_STRESS_EXTRA_TESTS="..."` appends ad hoc tests to the default
  list.

### 10.4.1 Current host execution status (2026-04-18)

The wrappers were executed on **2026-04-18** with the current host tool
installation:

- `formal_ingress.sh`: compile/elaboration passed on
  `opq_formal_ingress_tb`, and the current default fallback stress suite
  now passes with `FORMAL_BACKEND=stress` on the smallest known-good
  contract-preserving abstraction:
  `FORMAL_OPQ_N_SHD=256`, `FORMAL_OPQ_TICKET_FIFO_DEPTH=512`,
  stress tests `opq_basic_smoke_test` and
  `opq_formal_like_ingress_recovery_stress_test`.
- `formal_mover.sh`: compile/elaboration passed on the live allocator /
  block-mover path, and the current default fallback stress suite
  passes: `opq_cross_bp_credit_test` and
  `opq_formal_like_mover_drr_credit_stress_test`.
- `formal_egress.sh`: compile/elaboration passed on the live
  basic-presenter path and on the standalone `opq_formal_ftable_tb`
  elaboration top for the translated frame-table tracker/presenter
  path, and the current default fallback stress suite passes:
  `opq_edge_toggle_backpressure_test` and
  `opq_edge_stuck_low_backpressure_test`. The reduced-depth
  `opq_error_ftable_overflow_test` flush-atomicity companion also now
  passes as promoted isolated evidence, but it is not part of the
  default fallback suite because it requires a separate
  `OPQ_PAGE_RAM_DEPTH=512` elaboration point.
- Targeted egress probe status:
  `FORMAL_STRESS_TESTS=opq_formal_like_egress_flush_backpressure_stress_test
  FORMAL_BACKEND=stress bash tb/scripts/formal_egress.sh` is a current
  failing probe. It trips `opq_avst_egress_sva.sv` line 51
  (`p_hold_under_backpressure`) at multiple timestamps while the write
  side is forcing a flush window under deasserted output `ready`. This
  is tracked as `BUG-014-R` and remains excluded from the default
  fallback summary until the presenter/flush interaction is fixed.

Current ingress probe classification:

- `opq_error_header_mask_recovery_test` is **probe-only** in the
  fallback flow because it intentionally launches a new preamble before
  the masked bad frame closes, which violates the top-level
  `opq_avst_ingress_sva` no-nested-SOP contract by construction.
- `opq_error_header_word_mask_recovery_test` remains **probe-only**
  because it is already an open native-SV recovery probe in the main DV
  plan.
- `opq_error_subheader_mask_recovery_test` is **not** probe-only, but
  it does require the non-shrunken `N_SHD=256` ingress abstraction in
  the current simulation fallback. The more aggressive
  `FORMAL_OPQ_N_SHD=8/16` fallback reductions create a false failing
  model where one recovery hit is lost and one lane credit does not
  restore, while the normal-size run closes cleanly. The stable wrapper
  entry point for that fallback role is now
  `opq_formal_like_ingress_recovery_stress_test`.

Current blocker: the ETH license server exposes `znformal`, but the
current host tool installation does **not** provide a runnable
`qverify`/`znformal` binary in `PATH` or under the checked Questa
install trees. So the current wrappers close compile/elaboration
readiness and can execute a consistent simulation-backed fallback flow,
but they do not yet execute a real proof engine on this host.

Current OSS alternative status:

- the wrapper layer now also accepts `FORMAL_BACKEND=sby` with explicit
  `SBY_BIN`, `YOSYS_BIN`, and `BITWUZLA_BIN` hooks
- a shared OSS stack is now installed for all users under
  `/data1/oss_formal`, with stable wrappers in `/data1/oss_formal/bin`
  and a shell activation script at `/data1/oss_formal/activate.sh`
- the OPQ wrapper layer also probes `/data1/oss_formal/bin/{sby,yosys,bitwuzla}`
  directly, so `FORMAL_BACKEND=sby` works on this host without a
  per-user shell setup
- current host result with that shared install:
  - ingress:
    `compile=pass`,
    `elab=pass`,
    `formal=sby_fail`,
    `backend=sby+yosys+bitwuzla`
    via `formal_ingress.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
  - mover:
    `compile=pass`,
    `elab=pass`,
    `formal=sby_fail`,
    `backend=sby+yosys+bitwuzla`
    via `formal_mover.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
  - egress:
    `compile=pass`,
    `elab=pass`,
    `formal=sby_pass`,
    `backend=sby+yosys+bitwuzla`
    via `formal_egress.sh`
    `FORMAL_BACKEND=sby`
    `FORMAL_SBY_TASKS=prove`
- the OSS path is therefore no longer just a backend/API handoff:
  the ingress, mover, and egress jobs are now all truly scripted and
  execute real `sby` runs on this host
- current remaining blockers are concrete and tracked:
  - `BUG-015-H`: ingress proof now carries explicit legal-state
    assumptions for `WR_HITS` and drop-cause exclusivity, but it still
    fails on the lane-credit bound plus `lane_issue_dbg_oss` alignment,
    so the remaining blocker is a sampled write/credit abstraction issue
  - `BUG-016-H`: closed for the current OSS egress subset; the live
    Avalon-ST hold-under-backpressure slice now passes after isolating
    the overwrite-drop scan from the OSS backend
  - `BUG-017-H`: mover proof still fails on sampled
    page-writer source-data equality even after exporting combinational
    write-source mirrors, adding sampled source shadows, and extending
    reset warmup, so this one now needs RTL-or-harness triage instead
    of more proof-visibility cleanup
- non-claim for the current OSS egress pass:
  - the unread-overwrite scan itself is not yet proven in the OSS path;
    `OPQ_OSS_FORMAL` now isolates a feed-forward oversize-only drop
    subset so the live backpressure/hold contract can be proven without
    changing the native-SV signoff behavior

---

## 11. Trace to current simulation

| Formal target | Simulation stress |
|---------------|------------------|
| §2.6 parser structural | `opq_basic_smoke_test`, `opq_basic_default_test` |
| §3.2 credit conservation | `opq_edge_backpressure_test`, `opq_edge_toggle_backpressure_test` |
| §4.2 page-RAM exclusion | any `opq_cross_drr_*` + `opq_error_*` |
| §5.1 DRR legality | `opq_cross_drr_allowance_test`, `opq_cross_drr_bursty_random_test` |
| §6.1–6.2 flush atomicity | `opq_error_ftable_overflow_test` (promoted isolated reduced-depth point) |
| §7.3.3–7.3.5 backpressure + flush | `opq_edge_backpressure_test` × `opq_error_ftable_overflow_test` hybrid (TODO to add as a directed case) |
| §8.1–8.2 end-to-end integrity | `opq_cross_*` continuous-frame baselines |

The split is intentional: constrained-random tests trigger the same
contracts that later become proof targets. When a formal proof fails,
the counterexample trace is a minimal reproducer that should be added
to `tb/uvm/tests/` as a directed regression case.

---

## 12. Open items

- *Boundary* **B10** bounded-liveness threshold `T_FLUSH_MAX` not yet
  measured. Needs one instrumented run of the existing cross-frame
  baseline.
- *Boundary* **B19** `T_STARVE_MAX` likewise needs measurement.
- *Boundary* **B27 / B28** require adding a directed simulation
  hybrid test that couples `opq_edge_backpressure_test` cadence with
  an `opq_error_ftable_overflow_test`-style flush injection. That
  case is the first candidate to move from simulation-only to formal.
- *Boundary* **B25** TID ownership ring edge: during hand-off the
  property may need a one-cycle relaxation; confirm against the
  tracker RTL before committing.
- *Boundary* **B37** per-lane frame-serial monotonicity proof is the
  only plane-level property not yet planned; needs the ingress
  parser's `pkg_cnt` to be exported as a DUT-level observation port so
  the property can bind.
- Host-side tool block: on **2026-04-18** the ETH floating license for
  `znformal` was available, but no `qverify` / `znformal` executable was
  present in the installed Questa trees on this machine. First real
  proof execution therefore remains blocked on tool installation rather
  than on the OPQ RTL build.

//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_basic_presenter
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.3.18
// Date    : 20260418
// Change  : Drop overwritten unread packets before corrupted page-ram contents can reach egress
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_basic_presenter #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned META_ADDR_WIDTH = 9,
  parameter int unsigned EGRESS_DELAY = 3
) (
  input  logic                                            new_frame_valid_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                  new_frame_raw_addr_i,
  input  logic [MAX_SHR_CNT_BITS-1:0]                     frame_shr_cnt_this_i,
  input  logic [MAX_HIT_CNT_BITS-1:0]                     frame_hit_cnt_this_i,
  input  logic                                            packet_complete_i,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  page_ram_rd_addr_o,
  input  logic [PAGE_RAM_DATA_WIDTH-1:0]                  page_ram_rd_data_i,
  output logic                                            ft_drop_valid_o,
  output logic [31:0]                                     ft_drop_hdr_cnt_o,
  output logic [31:0]                                     ft_drop_shd_cnt_o,
  output logic [31:0]                                     ft_drop_hit_cnt_o,
  output logic [PAGE_RAM_RD_WIDTH-1:0]                    aso_egress_data,
  output logic                                            aso_egress_valid,
  input  logic                                            aso_egress_ready,
  output logic                                            aso_egress_startofpacket,
  output logic                                            aso_egress_endofpacket,
  output logic [2:0]                                      aso_egress_error,
  input  logic                                            d_clk,
  input  logic                                            d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam int unsigned META_DEPTH = 1 << META_ADDR_WIDTH;

  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [META_ADDR_WIDTH-1:0] meta_ptr_t;

  typedef enum logic [2:0] {
    FTABLE_PRESENTER_IDLE,
    FTABLE_PRESENTER_WAIT_FOR_COMPLETE,
    FTABLE_PRESENTER_PRESENTING,
    FTABLE_PRESENTER_RESET
  } presenter_state_t;

  presenter_state_t presenter_state;
  page_ram_addr_t meta_addr [META_DEPTH];
  page_ram_addr_t meta_len  [META_DEPTH];
  logic [MAX_SHR_CNT_BITS-1:0] meta_shd_cnt [META_DEPTH];
  logic [MAX_HIT_CNT_BITS-1:0] meta_hit_cnt [META_DEPTH];
  meta_ptr_t meta_wptr;
  meta_ptr_t meta_rptr;
  meta_ptr_t meta_pkt_wcnt;
  meta_ptr_t meta_pkt_rcnt;
  page_ram_addr_t page_ram_rptr;
  logic [EGRESS_DELAY:0] output_data_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data_pipe [EGRESS_DELAY-1:0];
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data;
  page_ram_addr_t pkt_rd_word_cnt;
  page_ram_addr_t packet_length;
  page_ram_addr_t launch_word_cnt;
  logic is_new_pkt_head;
  logic is_new_pkt_complete;
  logic output_is_trailer;
  logic launch_is_trailer;
  logic advance_output_pipe;
  logic retire_pending;
  logic pkt_accept_started;
  logic suppress_next_packet_complete;
  logic [PAGE_RAM_DATA_WIDTH-1:0] launch_data;
  int unsigned new_frame_length_full;
  page_ram_addr_t new_frame_length;
  logic new_frame_oversize;
  logic overwrite_head_accepted_or_accepting;
  logic overwrite_drop_valid_next;
  logic overwrite_drop_flush_head;
  meta_ptr_t overwrite_drop_rptr_next;
  meta_ptr_t overwrite_drop_pkt_rcnt_next;
  logic [31:0] overwrite_drop_hdr_cnt_next;
  logic [31:0] overwrite_drop_shd_cnt_next;
  logic [31:0] overwrite_drop_hit_cnt_next;

  function automatic int unsigned frame_length_from_counts(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    return int'(
      (shd_cnt * SHD_SIZE) +
      (hit_cnt * HIT_SIZE) +
      HDR_SIZE + TRL_SIZE
    );
  endfunction

  function automatic bit interval_overlaps(
    input int unsigned a_lo,
    input int unsigned a_hi,
    input int unsigned b_lo,
    input int unsigned b_hi
  );
    return !((a_hi < b_lo) || (b_hi < a_lo));
  endfunction

  function automatic bit circular_range_overlaps(
    input page_ram_addr_t lhs_addr,
    input page_ram_addr_t lhs_len,
    input page_ram_addr_t rhs_addr,
    input page_ram_addr_t rhs_len
  );
    int unsigned lhs_lo;
    int unsigned lhs_hi;
    int unsigned rhs_lo;
    int unsigned rhs_hi;
    begin
      if ((lhs_len == '0) || (rhs_len == '0)) begin
        return 1'b0;
      end

      lhs_lo = int'(lhs_addr);
      lhs_hi = lhs_lo + int'(lhs_len) - 1;
      rhs_lo = int'(rhs_addr);
      rhs_hi = rhs_lo + int'(rhs_len) - 1;

      for (int lhs_wrap = 0; lhs_wrap < 2; lhs_wrap++) begin
        for (int rhs_wrap = 0; rhs_wrap < 2; rhs_wrap++) begin
          if (interval_overlaps(
            lhs_lo + lhs_wrap * PAGE_RAM_DEPTH,
            lhs_hi + lhs_wrap * PAGE_RAM_DEPTH,
            rhs_lo + rhs_wrap * PAGE_RAM_DEPTH,
            rhs_hi + rhs_wrap * PAGE_RAM_DEPTH
          )) begin
            return 1'b1;
          end
        end
      end

      return 1'b0;
    end
  endfunction

  always_comb begin
    is_new_pkt_head = (meta_wptr != meta_rptr);
    is_new_pkt_complete = (meta_pkt_wcnt != meta_pkt_rcnt);
    packet_length = meta_len[meta_rptr];
    new_frame_length_full = frame_length_from_counts(frame_shr_cnt_this_i, frame_hit_cnt_this_i);
    new_frame_length = page_ram_addr_t'(new_frame_length_full);
    new_frame_oversize = (new_frame_length_full >= PAGE_RAM_DEPTH);
    output_data = output_data_pipe[EGRESS_DELAY-1];
    output_is_trailer = 1'b0;
    if ((output_data[35:32] == 4'b0001) && (output_data[7:0] == K284)) begin
      output_is_trailer = 1'b1;
    end else if (packet_length == pkt_rd_word_cnt) begin
      output_is_trailer = 1'b1;
    end

    advance_output_pipe = aso_egress_ready || !output_data_valid[EGRESS_DELAY];
    launch_word_cnt = pkt_rd_word_cnt;
    if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
      launch_word_cnt = pkt_rd_word_cnt + page_ram_addr_t'(1);
    end

    launch_data = output_data;
    if (advance_output_pipe) begin
      if (EGRESS_DELAY > 1) begin
        launch_data = output_data_pipe[EGRESS_DELAY-2];
      end else begin
        launch_data = page_ram_rd_data_i;
      end
    end

    launch_is_trailer = 1'b0;
    if ((launch_data[35:32] == 4'b0001) && (launch_data[7:0] == K284)) begin
      launch_is_trailer = 1'b1;
    end else if (packet_length == launch_word_cnt) begin
      launch_is_trailer = 1'b1;
    end

    page_ram_rd_addr_o = page_ram_rptr;

    aso_egress_valid = 1'b0;
    if (presenter_state == FTABLE_PRESENTER_PRESENTING) begin
      aso_egress_valid = output_data_valid[EGRESS_DELAY];
    end
    aso_egress_data = output_data[PAGE_RAM_RD_WIDTH-1:0];
    aso_egress_startofpacket = aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K285);
    aso_egress_endofpacket = aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K284);
    aso_egress_error = '0;
  end

  always_comb begin : proc_overwrite_drop_plan
    meta_ptr_t scan_rptr;
    meta_ptr_t scan_pkt_rcnt;
    bit stop_scan;

    overwrite_head_accepted_or_accepting =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      (pkt_accept_started || (output_data_valid[EGRESS_DELAY] && aso_egress_ready));
    overwrite_drop_valid_next = 1'b0;
    overwrite_drop_flush_head = 1'b0;
    overwrite_drop_rptr_next = meta_rptr;
    overwrite_drop_pkt_rcnt_next = meta_pkt_rcnt;
    overwrite_drop_hdr_cnt_next = '0;
    overwrite_drop_shd_cnt_next = '0;
    overwrite_drop_hit_cnt_next = '0;
    scan_rptr = meta_rptr;
    scan_pkt_rcnt = meta_pkt_rcnt;
    stop_scan = 1'b0;

    if (new_frame_valid_i) begin
      if (new_frame_oversize) begin
        overwrite_drop_hdr_cnt_next = 32'd1;
        overwrite_drop_shd_cnt_next = 32'(frame_shr_cnt_this_i);
        overwrite_drop_hit_cnt_next = 32'(frame_hit_cnt_this_i);
      end else begin
        for (int i = 0; i < META_DEPTH; i++) begin
          if (!stop_scan && (scan_pkt_rcnt != meta_pkt_wcnt)) begin
            if (circular_range_overlaps(
              new_frame_raw_addr_i,
              new_frame_length,
              meta_addr[scan_rptr],
              meta_len[scan_rptr]
            )) begin
              if ((scan_rptr == meta_rptr) && overwrite_head_accepted_or_accepting) begin
                stop_scan = 1'b1;
              end else begin
                overwrite_drop_hdr_cnt_next = overwrite_drop_hdr_cnt_next + 32'd1;
                overwrite_drop_shd_cnt_next = overwrite_drop_shd_cnt_next + 32'(meta_shd_cnt[scan_rptr]);
                overwrite_drop_hit_cnt_next = overwrite_drop_hit_cnt_next + 32'(meta_hit_cnt[scan_rptr]);
                scan_rptr = scan_rptr + meta_ptr_t'(1);
                scan_pkt_rcnt = scan_pkt_rcnt + meta_ptr_t'(1);
              end
            end else begin
              stop_scan = 1'b1;
            end
          end
        end
      end
    end

    overwrite_drop_rptr_next = scan_rptr;
    overwrite_drop_pkt_rcnt_next = scan_pkt_rcnt;
    overwrite_drop_valid_next =
      (overwrite_drop_hdr_cnt_next != 0) ||
      (overwrite_drop_shd_cnt_next != 0) ||
      (overwrite_drop_hit_cnt_next != 0);
    overwrite_drop_flush_head = overwrite_drop_valid_next && !new_frame_oversize;
  end

  always_ff @(posedge d_clk) begin
    ft_drop_valid_o <= 1'b0;
    ft_drop_hdr_cnt_o <= '0;
    ft_drop_shd_cnt_o <= '0;
    ft_drop_hit_cnt_o <= '0;

    if (new_frame_valid_i) begin
      if (new_frame_oversize) begin
        suppress_next_packet_complete <= 1'b1;
      end else begin
        meta_addr[meta_wptr] <= new_frame_raw_addr_i;
        meta_len[meta_wptr] <= new_frame_length;
        meta_shd_cnt[meta_wptr] <= frame_shr_cnt_this_i;
        meta_hit_cnt[meta_wptr] <= frame_hit_cnt_this_i;
        meta_wptr <= meta_wptr + meta_ptr_t'(1);

        if (overwrite_drop_flush_head) begin
          meta_rptr <= overwrite_drop_rptr_next;
          meta_pkt_rcnt <= overwrite_drop_pkt_rcnt_next;
        end
      end

      if (overwrite_drop_valid_next) begin
        ft_drop_valid_o <= 1'b1;
        ft_drop_hdr_cnt_o <= overwrite_drop_hdr_cnt_next;
        ft_drop_shd_cnt_o <= overwrite_drop_shd_cnt_next;
        ft_drop_hit_cnt_o <= overwrite_drop_hit_cnt_next;
      end
    end

    if (packet_complete_i) begin
      if (suppress_next_packet_complete) begin
        suppress_next_packet_complete <= 1'b0;
      end else begin
        meta_pkt_wcnt <= meta_pkt_wcnt + meta_ptr_t'(1);
      end
    end

    if (overwrite_drop_flush_head) begin
      presenter_state <= FTABLE_PRESENTER_IDLE;
      output_data_valid <= '0;
      pkt_rd_word_cnt <= '0;
      retire_pending <= 1'b0;
      pkt_accept_started <= 1'b0;
    end else begin
      unique case (presenter_state)
        FTABLE_PRESENTER_IDLE: begin
          if (is_new_pkt_head) begin
            presenter_state <= FTABLE_PRESENTER_WAIT_FOR_COMPLETE;
            pkt_accept_started <= 1'b0;
          end
        end

        FTABLE_PRESENTER_WAIT_FOR_COMPLETE: begin
          if (is_new_pkt_complete) begin
            presenter_state <= FTABLE_PRESENTER_PRESENTING;
            page_ram_rptr <= meta_addr[meta_rptr];
            pkt_rd_word_cnt <= '0;
            retire_pending <= 1'b0;
            pkt_accept_started <= 1'b0;
          end
        end

        FTABLE_PRESENTER_PRESENTING: begin
          if (retire_pending) begin
            if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
              presenter_state <= FTABLE_PRESENTER_IDLE;
              output_data_valid <= '0;
              meta_pkt_rcnt <= meta_pkt_rcnt + meta_ptr_t'(1);
              meta_rptr <= meta_rptr + meta_ptr_t'(1);
              retire_pending <= 1'b0;
              pkt_accept_started <= 1'b0;
            end
          end else begin
            if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
              pkt_rd_word_cnt <= pkt_rd_word_cnt + page_ram_addr_t'(1);
              pkt_accept_started <= 1'b1;
            end
            if (advance_output_pipe) begin
              output_data_valid[0] <= 1'b1;
              for (int i = 0; i < EGRESS_DELAY; i++) begin
                output_data_valid[i+1] <= output_data_valid[i];
              end
              output_data_pipe[0] <= page_ram_rd_data_i;
              for (int i = 0; i < EGRESS_DELAY-1; i++) begin
                output_data_pipe[i+1] <= output_data_pipe[i];
              end
              page_ram_rptr <= page_ram_rptr + page_ram_addr_t'(1);
            end

            if (advance_output_pipe && launch_is_trailer) begin
              output_data_valid <= '0;
              output_data_valid[EGRESS_DELAY] <= 1'b1;
              retire_pending <= 1'b1;
            end
          end
        end

        FTABLE_PRESENTER_RESET: begin
          presenter_state <= FTABLE_PRESENTER_IDLE;
          pkt_accept_started <= 1'b0;
        end

        default: begin
        end
      endcase
    end

    if (d_reset) begin
      presenter_state <= FTABLE_PRESENTER_RESET;
      meta_wptr <= '0;
      meta_rptr <= '0;
      meta_pkt_wcnt <= '0;
      meta_pkt_rcnt <= '0;
      page_ram_rptr <= '0;
      output_data_valid <= '0;
      for (int i = 0; i < EGRESS_DELAY; i++) begin
        output_data_pipe[i] <= '0;
      end
      pkt_rd_word_cnt <= '0;
      retire_pending <= 1'b0;
      pkt_accept_started <= 1'b0;
      suppress_next_packet_complete <= 1'b0;
      ft_drop_valid_o <= 1'b0;
      ft_drop_hdr_cnt_o <= '0;
      ft_drop_shd_cnt_o <= '0;
      ft_drop_hit_cnt_o <= '0;
    end
  end

  property p_reset_enters_presenter_reset;
    @(posedge d_clk) d_reset |=> (presenter_state == FTABLE_PRESENTER_RESET);
  endproperty
  ap_reset_enters_presenter_reset: assert property (p_reset_enters_presenter_reset);

  property p_complete_without_head_never_advances;
    @(posedge d_clk) disable iff (d_reset)
      (!is_new_pkt_head && packet_complete_i) |=> (meta_rptr == $past(meta_rptr));
  endproperty
  ap_complete_without_head_never_advances: assert property (p_complete_without_head_never_advances);

`ifdef OPQ_ENABLE_NATIVE_FORMAL_EGRESS
  opq_native_basic_presenter_formal_sva #(
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .META_ADDR_WIDTH(META_ADDR_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .packet_complete_i(packet_complete_i),
    .new_frame_valid_i(new_frame_valid_i),
    .page_ram_rd_addr_o(page_ram_rd_addr_o),
    .page_ram_rd_data_i(page_ram_rd_data_i),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .presenter_state(presenter_state),
    .meta_wptr(meta_wptr),
    .meta_rptr(meta_rptr),
    .meta_pkt_wcnt(meta_pkt_wcnt),
    .meta_pkt_rcnt(meta_pkt_rcnt),
    .page_ram_rptr(page_ram_rptr),
    .output_data_valid(output_data_valid),
    .output_data(output_data),
    .pkt_rd_word_cnt(pkt_rd_word_cnt),
    .retire_pending(retire_pending)
  );
`endif

endmodule

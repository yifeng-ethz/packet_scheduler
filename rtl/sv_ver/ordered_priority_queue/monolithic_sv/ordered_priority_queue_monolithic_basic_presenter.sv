//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_basic_presenter
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.3.11
// Date    : 20260417
// Change  : Hold the accepted egress beat stable under backpressure instead of rewinding the pipeline
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
  logic [PAGE_RAM_DATA_WIDTH-1:0] launch_data;

  always_comb begin
    is_new_pkt_head = (meta_wptr != meta_rptr);
    is_new_pkt_complete = (meta_pkt_wcnt != meta_pkt_rcnt);
    packet_length = meta_len[meta_rptr];
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

  always_ff @(posedge d_clk) begin
    if (new_frame_valid_i) begin
      meta_addr[meta_wptr] <= new_frame_raw_addr_i;
      meta_len[meta_wptr] <= page_ram_addr_t'(
        (frame_shr_cnt_this_i * SHD_SIZE) +
        (frame_hit_cnt_this_i * HIT_SIZE) +
        HDR_SIZE + TRL_SIZE
      );
      meta_wptr <= meta_wptr + meta_ptr_t'(1);
    end

    if (packet_complete_i) begin
      meta_pkt_wcnt <= meta_pkt_wcnt + meta_ptr_t'(1);
    end

    unique case (presenter_state)
      FTABLE_PRESENTER_IDLE: begin
        if (is_new_pkt_head) begin
          presenter_state <= FTABLE_PRESENTER_WAIT_FOR_COMPLETE;
        end
      end

      FTABLE_PRESENTER_WAIT_FOR_COMPLETE: begin
        if (is_new_pkt_complete) begin
          presenter_state <= FTABLE_PRESENTER_PRESENTING;
          page_ram_rptr <= meta_addr[meta_rptr];
          pkt_rd_word_cnt <= '0;
          retire_pending <= 1'b0;
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
          end
        end else begin
          if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
            pkt_rd_word_cnt <= pkt_rd_word_cnt + page_ram_addr_t'(1);
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
      end

      default: begin
      end
    endcase

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

endmodule

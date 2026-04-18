//------------------------------------------------------------------------------
// IP Name   : opq_oss_basic_presenter_formal_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.1 - OSS Yosys/SBY live basic-presenter proof harness
// Description:
//   Yosys/SymbiYosys-friendly harness for the native-SV basic presenter.
//   The primary proof target is the Avalon-ST hold contract under
//   backpressure, with a companion cover that reaches a stalled egress beat.
//------------------------------------------------------------------------------
module opq_oss_basic_presenter_formal_tb;
  localparam int unsigned N_LANE = 2;
  localparam int unsigned PAGE_RAM_DEPTH = 16;
  localparam int unsigned PAGE_RAM_RD_WIDTH = 36;
  localparam int unsigned PAGE_RAM_DATA_WIDTH = 40;
  localparam int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH);
  localparam int unsigned N_SHD = 4;
  localparam int unsigned N_HIT = 4;
  localparam int unsigned HDR_SIZE = 5;
  localparam int unsigned SHD_SIZE = 1;
  localparam int unsigned HIT_SIZE = 1;
  localparam int unsigned TRL_SIZE = 1;
  localparam int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1;
  localparam int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16;
  localparam int unsigned META_ADDR_WIDTH = 2;
  localparam int unsigned EGRESS_DELAY = 2;
  localparam int unsigned FRAME_LEN_WIDTH = PAGE_RAM_ADDR_WIDTH + 1;

  (* gclk *) reg gclk;
  reg f_past_valid = 1'b0;
  reg [1:0] f_reset_sr = 2'b11;

  wire d_reset = f_reset_sr[1];

  (* anyseq *) reg                                new_frame_valid_i;
  (* anyseq *) reg [PAGE_RAM_ADDR_WIDTH-1:0]      new_frame_raw_addr_i;
  (* anyseq *) reg [MAX_SHR_CNT_BITS-1:0]         frame_shr_cnt_this_i;
  (* anyseq *) reg [MAX_HIT_CNT_BITS-1:0]         frame_hit_cnt_this_i;
  (* anyseq *) reg                                packet_complete_i;
  (* anyseq *) reg [PAGE_RAM_DATA_WIDTH-1:0]      page_ram_rd_data_i;
  (* anyseq *) reg                                aso_egress_ready;

  wire [PAGE_RAM_ADDR_WIDTH-1:0]                  page_ram_rd_addr_o;
  wire                                            ft_drop_valid_o;
  wire [31:0]                                     ft_drop_hdr_cnt_o;
  wire [31:0]                                     ft_drop_shd_cnt_o;
  wire [31:0]                                     ft_drop_hit_cnt_o;
  wire [PAGE_RAM_RD_WIDTH-1:0]                    aso_egress_data;
  wire                                            aso_egress_valid;
  wire                                            aso_egress_startofpacket;
  wire                                            aso_egress_endofpacket;
  wire [2:0]                                      aso_egress_error;

  reg [META_ADDR_WIDTH:0]                         f_pending_completions;
  reg                                             f_seen_stall;
  reg                                             f_seen_drop;

  function automatic logic [FRAME_LEN_WIDTH-1:0] frame_length_from_counts(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    logic [FRAME_LEN_WIDTH-1:0] shd_ext;
    logic [FRAME_LEN_WIDTH-1:0] hit_ext;
    begin
      shd_ext = shd_cnt;
      hit_ext = hit_cnt;
      frame_length_from_counts = (shd_ext * SHD_SIZE) + (hit_ext * HIT_SIZE) + HDR_SIZE + TRL_SIZE;
    end
  endfunction

  wire new_frame_oversize =
    (frame_length_from_counts(frame_shr_cnt_this_i, frame_hit_cnt_this_i) >= PAGE_RAM_DEPTH);

  ordered_priority_queue_monolithic_basic_presenter #(
    .N_LANE(N_LANE),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .HDR_SIZE(HDR_SIZE),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .TRL_SIZE(TRL_SIZE),
    .MAX_SHR_CNT_BITS(MAX_SHR_CNT_BITS),
    .MAX_HIT_CNT_BITS(MAX_HIT_CNT_BITS),
    .META_ADDR_WIDTH(META_ADDR_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY)
  ) dut (
    .new_frame_valid_i(new_frame_valid_i),
    .new_frame_raw_addr_i(new_frame_raw_addr_i),
    .frame_shr_cnt_this_i(frame_shr_cnt_this_i),
    .frame_hit_cnt_this_i(frame_hit_cnt_this_i),
    .packet_complete_i(packet_complete_i),
    .page_ram_rd_addr_o(page_ram_rd_addr_o),
    .page_ram_rd_data_i(page_ram_rd_data_i),
    .ft_drop_valid_o(ft_drop_valid_o),
    .ft_drop_hdr_cnt_o(ft_drop_hdr_cnt_o),
    .ft_drop_shd_cnt_o(ft_drop_shd_cnt_o),
    .ft_drop_hit_cnt_o(ft_drop_hit_cnt_o),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(gclk),
    .d_reset(d_reset)
  );

  always @(posedge gclk) begin
    f_past_valid <= 1'b1;
    if (f_reset_sr != 2'b00) begin
      f_reset_sr <= {f_reset_sr[0], 1'b0};
    end

    if (d_reset) begin
      f_pending_completions <= '0;
      f_seen_stall <= 1'b0;
      f_seen_drop <= 1'b0;
    end else begin
      assume(!packet_complete_i ||
        (f_pending_completions != '0) ||
        (new_frame_valid_i && !new_frame_oversize));

      f_pending_completions <=
        f_pending_completions +
        ((new_frame_valid_i && !new_frame_oversize) ? {{META_ADDR_WIDTH{1'b0}}, 1'b1} : '0) -
        (packet_complete_i ? {{META_ADDR_WIDTH{1'b0}}, 1'b1} : '0);

      if (aso_egress_valid && !aso_egress_ready) begin
        f_seen_stall <= 1'b1;
      end
      if (ft_drop_valid_o) begin
        f_seen_drop <= 1'b1;
      end
    end

    if (f_past_valid && !$past(d_reset) && $past(aso_egress_valid && !aso_egress_ready)) begin
      assert(aso_egress_valid);
      assert(aso_egress_data == $past(aso_egress_data));
      assert(aso_egress_startofpacket == $past(aso_egress_startofpacket));
      assert(aso_egress_endofpacket == $past(aso_egress_endofpacket));
      assert(aso_egress_error == $past(aso_egress_error));
    end

    if (ft_drop_valid_o) begin
      assert((ft_drop_hdr_cnt_o != 32'd0) ||
        (ft_drop_shd_cnt_o != 32'd0) ||
        (ft_drop_hit_cnt_o != 32'd0));
    end

    cover(f_seen_stall);
    cover(f_seen_drop);
    cover(f_seen_stall && f_seen_drop);
  end
endmodule

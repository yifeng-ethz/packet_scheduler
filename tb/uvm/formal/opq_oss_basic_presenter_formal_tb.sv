//------------------------------------------------------------------------------
// IP Name   : opq_oss_basic_presenter_formal_tb
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - constrain legal page-RAM frame grammar and assert count-aware egress format
// Description:
//   Yosys/SymbiYosys-friendly harness for the native-SV basic presenter.
//   The environment constrains page-RAM reads to a legal frame grammar driven
//   by the queued frame counts, then asserts the accepted Avalon-ST output
//   follows the same header-count-aware packet contract.
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
  localparam int unsigned FRAME_HDR_AUX_WORDS = 4;
  localparam int unsigned FRAME_HDR_AUX_WORDS_WIDTH =
    (FRAME_HDR_AUX_WORDS <= 1) ? 1 : $clog2(FRAME_HDR_AUX_WORDS + 1);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  (* gclk *) reg gclk;
  reg f_past_valid = 1'b0;
  reg [1:0] f_reset_sr = 2'b11;
  reg [1:0] f_post_reset_sr = 2'b00;

  wire d_reset = f_reset_sr[1];

  (* anyseq *) reg                                new_frame_valid_i;
  (* anyseq *) reg [PAGE_RAM_ADDR_WIDTH-1:0]      new_frame_raw_addr_i;
  (* anyseq *) reg [MAX_SHR_CNT_BITS-1:0]         frame_shr_cnt_this_i;
  (* anyseq *) reg [MAX_HIT_CNT_BITS-1:0]         frame_hit_cnt_this_i;
  (* anyseq *) reg                                packet_complete_i;
  (* anyseq *) reg [PAGE_RAM_DATA_WIDTH-1:0]      page_ram_rd_data_i;
  (* anyseq *) reg                                aso_egress_ready;

  wire [MAX_SHR_CNT_BITS-1:0]                     packet_complete_shr_cnt_i = frame_shr_cnt_this_i;
  wire [MAX_HIT_CNT_BITS-1:0]                     packet_complete_hit_cnt_i = frame_hit_cnt_this_i;
  wire                                            payload_commit_idle_i = 1'b1;
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

  reg                                             f_seen_stall;
  reg                                             f_seen_drop;
  reg                                             f_seen_frame;
  reg                                             f_frame_queued;
  reg [PAGE_RAM_ADDR_WIDTH-1:0]                    f_active_frame_addr;
  reg [MAX_SHR_CNT_BITS-1:0]                      f_active_frame_shd_cnt;
  reg [MAX_HIT_CNT_BITS-1:0]                      f_active_frame_hit_cnt;

  reg                                             f_out_frame_open;
  reg [FRAME_HDR_AUX_WORDS_WIDTH-1:0]             f_out_hdr_aux_words_left;
  reg [15:0]                                      f_out_expected_frame_subhdr_cnt;
  reg [15:0]                                      f_out_expected_frame_hit_cnt;
  reg [15:0]                                      f_out_emitted_frame_subhdr_cnt;
  reg [15:0]                                      f_out_emitted_frame_hit_cnt;
  reg [7:0]                                       f_out_hit_words_left;

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

  function automatic logic pkt_is_preamble(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    pkt_is_preamble = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285);
  endfunction

  function automatic logic pkt_is_frame_trl(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    pkt_is_frame_trl = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284);
  endfunction

  function automatic logic pkt_is_subhdr(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    pkt_is_subhdr = (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237);
  endfunction

  function automatic logic pkt_is_hit(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    pkt_is_hit = (word_v[35:32] == 4'b0000);
  endfunction

  function automatic logic [15:0] decode_frame_subhdr_cnt(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    decode_frame_subhdr_cnt = 16'({1'b0, word_v[30:16]});
  endfunction

  function automatic logic [15:0] decode_frame_hit_cnt(input logic [PAGE_RAM_DATA_WIDTH-1:0] word_v);
    decode_frame_hit_cnt = 16'(word_v[15:0]);
  endfunction

  function automatic logic [FRAME_LEN_WIDTH-1:0] circular_distance(
    input logic [PAGE_RAM_ADDR_WIDTH-1:0] from_addr,
    input logic [PAGE_RAM_ADDR_WIDTH-1:0] to_addr
  );
    logic [FRAME_LEN_WIDTH-1:0] from_ext;
    logic [FRAME_LEN_WIDTH-1:0] to_ext;
    begin
      from_ext = from_addr;
      to_ext = to_addr;
      if (to_ext >= from_ext) begin
        circular_distance = to_ext - from_ext;
      end else begin
        circular_distance = FRAME_LEN_WIDTH'(PAGE_RAM_DEPTH) - from_ext + to_ext;
      end
    end
  endfunction

  function automatic logic [7:0] canonical_subheader_hit_cnt(
    input int unsigned subhdr_idx,
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    int signed remaining_hits_v;
    begin
      canonical_subheader_hit_cnt = 8'd0;
      if (subhdr_idx < shd_cnt) begin
        remaining_hits_v = int'(hit_cnt) - (subhdr_idx * int'(N_HIT));
        if (remaining_hits_v > 0) begin
          if (remaining_hits_v >= int'(N_HIT)) begin
            canonical_subheader_hit_cnt = 8'(N_HIT);
          end else begin
            canonical_subheader_hit_cnt = 8'(remaining_hits_v);
          end
        end
      end
    end
  endfunction

  function automatic logic [PAGE_RAM_DATA_WIDTH-1:0] canonical_frame_word(
    input logic [FRAME_LEN_WIDTH-1:0] word_idx,
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    logic [PAGE_RAM_DATA_WIDTH-1:0] word_v;
    logic [FRAME_LEN_WIDTH-1:0] cursor_v;
    logic [7:0] subhdr_hit_cnt_v;
    int unsigned subhdr_idx;
    int unsigned hit_idx;
    begin
      word_v = '0;
      case (word_idx)
        FRAME_LEN_WIDTH'(0): begin
          word_v[35:32] = 4'b0001;
          word_v[7:0] = K285;
        end
        FRAME_LEN_WIDTH'(1): begin
        end
        FRAME_LEN_WIDTH'(2): begin
          word_v[15:0] = 16'h0001;
        end
        FRAME_LEN_WIDTH'(3): begin
          word_v[30:16] = 15'(shd_cnt);
          word_v[15:0] = 16'(hit_cnt);
        end
        FRAME_LEN_WIDTH'(4): begin
        end
        default: begin
          if (word_idx == (frame_length_from_counts(shd_cnt, hit_cnt) - FRAME_LEN_WIDTH'(1))) begin
            word_v[35:32] = 4'b0001;
            word_v[7:0] = K284;
          end else begin
            cursor_v = FRAME_LEN_WIDTH'(HDR_SIZE);
            for (subhdr_idx = 0; subhdr_idx < (N_SHD * N_LANE); subhdr_idx = subhdr_idx + 1) begin
              if (subhdr_idx < shd_cnt) begin
                if (word_idx == cursor_v) begin
                  word_v[35:32] = 4'b0001;
                  word_v[31:24] = 8'(subhdr_idx);
                  word_v[15:8] = canonical_subheader_hit_cnt(subhdr_idx, shd_cnt, hit_cnt);
                  word_v[7:0] = K237;
                end
                cursor_v = cursor_v + FRAME_LEN_WIDTH'(1);
                subhdr_hit_cnt_v = canonical_subheader_hit_cnt(subhdr_idx, shd_cnt, hit_cnt);
                for (hit_idx = 0; hit_idx < N_HIT; hit_idx = hit_idx + 1) begin
                  if (hit_idx < subhdr_hit_cnt_v) begin
                    if (word_idx == cursor_v) begin
                      word_v[35:32] = 4'b0000;
                      word_v[31:0] = {24'd0, 8'(hit_idx)};
                    end
                    cursor_v = cursor_v + FRAME_LEN_WIDTH'(1);
                  end
                end
              end
            end
          end
        end
      endcase
      canonical_frame_word = word_v;
    end
  endfunction

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
    .packet_complete_shr_cnt_i(packet_complete_shr_cnt_i),
    .packet_complete_hit_cnt_i(packet_complete_hit_cnt_i),
    .payload_commit_idle_i(payload_commit_idle_i),
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
      f_post_reset_sr <= 2'b00;
      f_seen_stall <= 1'b0;
      f_seen_drop <= 1'b0;
      f_seen_frame <= 1'b0;
      f_frame_queued <= 1'b0;
      f_active_frame_addr <= '0;
      f_active_frame_shd_cnt <= '0;
      f_active_frame_hit_cnt <= '0;
      f_out_frame_open <= 1'b0;
      f_out_hdr_aux_words_left <= '0;
      f_out_expected_frame_subhdr_cnt <= '0;
      f_out_expected_frame_hit_cnt <= '0;
      f_out_emitted_frame_subhdr_cnt <= '0;
      f_out_emitted_frame_hit_cnt <= '0;
      f_out_hit_words_left <= '0;
      assume(!new_frame_valid_i);
      assume(!packet_complete_i);
    end else begin
      logic [FRAME_LEN_WIDTH-1:0] active_frame_len_v;
      logic [FRAME_LEN_WIDTH-1:0] active_rd_ofst_v;

      f_post_reset_sr <= {f_post_reset_sr[0], 1'b1};
      if (!(&f_post_reset_sr)) begin
        assume(!new_frame_valid_i);
        assume(!packet_complete_i);
      end else begin
        assume(packet_complete_i == (new_frame_valid_i && !new_frame_oversize));
        assume(!new_frame_valid_i || (frame_shr_cnt_this_i <= MAX_SHR_CNT_BITS'(N_SHD * N_LANE)));
        assume(!new_frame_valid_i || (frame_hit_cnt_this_i <= MAX_HIT_CNT_BITS'(N_SHD * N_HIT)));
        assume(!new_frame_valid_i || (frame_hit_cnt_this_i <= MAX_HIT_CNT_BITS'(frame_shr_cnt_this_i * N_HIT)));
        assume(!new_frame_valid_i || !f_frame_queued);
        assume(!f_frame_queued || (f_active_frame_shd_cnt <= MAX_SHR_CNT_BITS'(N_SHD * N_LANE)));
        assume(!f_frame_queued || (f_active_frame_hit_cnt <= MAX_HIT_CNT_BITS'(N_SHD * N_HIT)));
        assume(!f_frame_queued || (f_active_frame_hit_cnt <= MAX_HIT_CNT_BITS'(f_active_frame_shd_cnt * N_HIT)));
        // Keep the shadow monitor aligned to states that its own update logic can
        // actually reach, so induction cannot start from impossible mid-frame
        // helper-state combinations.
        assume(!f_out_frame_open || f_frame_queued);
        assume(f_out_hdr_aux_words_left <= FRAME_HDR_AUX_WORDS_WIDTH'(FRAME_HDR_AUX_WORDS));
        assume(!f_out_frame_open || (f_out_expected_frame_subhdr_cnt <= 16'(f_active_frame_shd_cnt)));
        assume(!f_out_frame_open || (f_out_expected_frame_hit_cnt <= 16'(f_active_frame_hit_cnt)));
        assume(!f_out_frame_open || (f_out_emitted_frame_subhdr_cnt <= f_out_expected_frame_subhdr_cnt));
        assume(!f_out_frame_open || (f_out_emitted_frame_hit_cnt <= f_out_expected_frame_hit_cnt));
        assume(f_out_frame_open || (f_out_hdr_aux_words_left == '0));
        assume(f_out_frame_open || (f_out_hit_words_left == '0));
        assume((f_out_hdr_aux_words_left == '0) ||
          (f_out_frame_open &&
            (f_out_hit_words_left == '0) &&
            (f_out_emitted_frame_subhdr_cnt == '0) &&
            (f_out_emitted_frame_hit_cnt == '0)));
        assume((f_out_hit_words_left == '0) ||
          (f_out_frame_open &&
            (f_out_hdr_aux_words_left == '0) &&
            (f_out_emitted_frame_subhdr_cnt != '0) &&
            (f_out_emitted_frame_subhdr_cnt <= f_out_expected_frame_subhdr_cnt) &&
            (f_out_emitted_frame_hit_cnt < f_out_expected_frame_hit_cnt)));
        assume((f_frame_queued || f_out_frame_open) || !aso_egress_ready);
        if (f_frame_queued) begin
          if (!f_out_frame_open) begin
            assume(!aso_egress_ready ||
              (aso_egress_startofpacket && !aso_egress_endofpacket && pkt_is_preamble(aso_egress_data)));
          end else if (f_out_hdr_aux_words_left != 0) begin
            if (f_out_hdr_aux_words_left == FRAME_HDR_AUX_WORDS_WIDTH'(2)) begin
              assume(!aso_egress_ready ||
                (!aso_egress_startofpacket &&
                  !aso_egress_endofpacket &&
                  !pkt_is_preamble(aso_egress_data) &&
                  !pkt_is_subhdr(aso_egress_data) &&
                  !pkt_is_frame_trl(aso_egress_data) &&
                  (aso_egress_data[31] == 1'b0) &&
                  (decode_frame_subhdr_cnt(aso_egress_data) == 16'(f_active_frame_shd_cnt)) &&
                  (decode_frame_hit_cnt(aso_egress_data) == 16'(f_active_frame_hit_cnt))));
            end else begin
              assume(!aso_egress_ready ||
                (!aso_egress_startofpacket &&
                  !aso_egress_endofpacket &&
                  !pkt_is_preamble(aso_egress_data) &&
                  !pkt_is_subhdr(aso_egress_data) &&
                  !pkt_is_frame_trl(aso_egress_data)));
            end
          end else if (f_out_hit_words_left != 0) begin
            assume(!aso_egress_ready ||
              (!aso_egress_startofpacket &&
                !aso_egress_endofpacket &&
                pkt_is_hit(aso_egress_data) &&
                (f_out_emitted_frame_hit_cnt < f_out_expected_frame_hit_cnt)));
          end else if (f_out_emitted_frame_subhdr_cnt < f_out_expected_frame_subhdr_cnt) begin
            assume(!aso_egress_ready ||
              (!aso_egress_startofpacket &&
                !aso_egress_endofpacket &&
                pkt_is_subhdr(aso_egress_data) &&
                (aso_egress_data[15:8] <= 8'(N_HIT))));
          end else begin
            assume(!aso_egress_ready ||
              (!aso_egress_startofpacket &&
                aso_egress_endofpacket &&
                (f_out_emitted_frame_hit_cnt == f_out_expected_frame_hit_cnt) &&
                pkt_is_frame_trl(aso_egress_data)));
          end
        end

        active_frame_len_v = frame_length_from_counts(f_active_frame_shd_cnt, f_active_frame_hit_cnt);
        active_rd_ofst_v = circular_distance(f_active_frame_addr, page_ram_rd_addr_o);
        if (f_frame_queued && (active_rd_ofst_v < active_frame_len_v)) begin
          assume(page_ram_rd_data_i ==
            canonical_frame_word(active_rd_ofst_v, f_active_frame_shd_cnt, f_active_frame_hit_cnt));
        end

        if (aso_egress_valid && !aso_egress_ready) begin
          f_seen_stall <= 1'b1;
        end
        if (ft_drop_valid_o) begin
          f_seen_drop <= 1'b1;
        end
        if (aso_egress_valid && aso_egress_ready && aso_egress_endofpacket) begin
          f_seen_frame <= 1'b1;
        end

        if (new_frame_valid_i && !new_frame_oversize) begin
          f_frame_queued <= 1'b1;
          f_active_frame_addr <= new_frame_raw_addr_i;
          f_active_frame_shd_cnt <= frame_shr_cnt_this_i;
          f_active_frame_hit_cnt <= frame_hit_cnt_this_i;
        end

        if (aso_egress_valid && aso_egress_ready) begin
          if (!f_out_frame_open) begin
            assert(f_frame_queued);
            assert(aso_egress_startofpacket);
            assert(!aso_egress_endofpacket);
            assert(pkt_is_preamble(aso_egress_data));

            f_out_frame_open <= 1'b1;
            f_out_hdr_aux_words_left <= FRAME_HDR_AUX_WORDS_WIDTH'(FRAME_HDR_AUX_WORDS);
            f_out_expected_frame_subhdr_cnt <= '0;
            f_out_expected_frame_hit_cnt <= '0;
            f_out_emitted_frame_subhdr_cnt <= '0;
            f_out_emitted_frame_hit_cnt <= '0;
            f_out_hit_words_left <= '0;
          end else if (f_out_hdr_aux_words_left != 0) begin
            assert(!aso_egress_startofpacket);
            assert(!aso_egress_endofpacket);
            assert(!pkt_is_preamble(aso_egress_data));
            assert(!pkt_is_subhdr(aso_egress_data));
            assert(!pkt_is_frame_trl(aso_egress_data));

            if (f_out_hdr_aux_words_left == FRAME_HDR_AUX_WORDS_WIDTH'(2)) begin
              assert(aso_egress_data[31] == 1'b0);
              assert(decode_frame_subhdr_cnt(aso_egress_data) == 16'(f_active_frame_shd_cnt));
              assert(decode_frame_hit_cnt(aso_egress_data) == 16'(f_active_frame_hit_cnt));
              f_out_expected_frame_subhdr_cnt <= decode_frame_subhdr_cnt(aso_egress_data);
              f_out_expected_frame_hit_cnt <= decode_frame_hit_cnt(aso_egress_data);
            end

            f_out_hdr_aux_words_left <= f_out_hdr_aux_words_left - FRAME_HDR_AUX_WORDS_WIDTH'(1);
          end else if (pkt_is_frame_trl(aso_egress_data)) begin
            assert(!aso_egress_startofpacket);
            assert(aso_egress_endofpacket);
            assert(f_out_hit_words_left == 0);
            assert(f_out_emitted_frame_subhdr_cnt == f_out_expected_frame_subhdr_cnt);
            assert(f_out_emitted_frame_hit_cnt == f_out_expected_frame_hit_cnt);

            f_out_frame_open <= 1'b0;
            f_out_hdr_aux_words_left <= '0;
            f_out_expected_frame_subhdr_cnt <= '0;
            f_out_expected_frame_hit_cnt <= '0;
            f_out_emitted_frame_subhdr_cnt <= '0;
            f_out_emitted_frame_hit_cnt <= '0;
            f_out_hit_words_left <= '0;
            f_frame_queued <= 1'b0;
          end else if (pkt_is_subhdr(aso_egress_data)) begin
            assert(!aso_egress_startofpacket);
            assert(!aso_egress_endofpacket);
            assert(f_out_hit_words_left == 0);
            assert(f_out_emitted_frame_subhdr_cnt < f_out_expected_frame_subhdr_cnt);
            assert(aso_egress_data[15:8] <= 8'(N_HIT));

            f_out_emitted_frame_subhdr_cnt <= f_out_emitted_frame_subhdr_cnt + 16'd1;
            f_out_hit_words_left <= aso_egress_data[15:8];
          end else begin
            assert(!aso_egress_startofpacket);
            assert(!aso_egress_endofpacket);
            assert(pkt_is_hit(aso_egress_data));
            assert(f_out_hit_words_left != 0);
            assert(f_out_emitted_frame_hit_cnt < f_out_expected_frame_hit_cnt);

            f_out_hit_words_left <= f_out_hit_words_left - 8'd1;
            f_out_emitted_frame_hit_cnt <= f_out_emitted_frame_hit_cnt + 16'd1;
          end
        end
      end
    end

    if (f_past_valid && (&f_post_reset_sr) && !$past(d_reset) && $past(aso_egress_valid && !aso_egress_ready)) begin
      assert(aso_egress_valid);
      assert(aso_egress_data == $past(aso_egress_data));
      assert(aso_egress_startofpacket == $past(aso_egress_startofpacket));
      assert(aso_egress_endofpacket == $past(aso_egress_endofpacket));
      assert(aso_egress_error == $past(aso_egress_error));
    end

    if (!d_reset && (&f_post_reset_sr)) begin
      if (aso_egress_valid) begin
        assert(!(aso_egress_startofpacket && aso_egress_endofpacket));
      end
      if (aso_egress_valid && aso_egress_startofpacket) begin
        assert(pkt_is_preamble(aso_egress_data));
      end
      if (aso_egress_valid && aso_egress_endofpacket) begin
        assert(pkt_is_frame_trl(aso_egress_data));
      end
      assert(aso_egress_error == 3'b000);
      assert(payload_commit_idle_i);
    end

    cover(f_seen_stall);
    cover(f_seen_drop);
    cover(f_seen_stall && f_seen_drop);
    cover(f_seen_frame);
  end
endmodule

//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_ingress_parser
// Version : 26.3.19
// Date    : 20260418
// Change  : Export credit-mask drop pulses and add an OSS-formal syntax bridge without changing the native-SV regression path
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_ingress_parser #(
  parameter int unsigned INGRESS_DATA_WIDTH = 32,
  parameter int unsigned INGRESS_DATAK_WIDTH = 4,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned LANE_FIFO_WIDTH = 40,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned FRAME_SERIAL_SIZE = 16,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A = 48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B,
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2
) (
  input  logic [INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data,
  input  logic                                              asi_ingress_valid,
  input  logic                                              asi_ingress_startofpacket,
  input  logic                                              asi_ingress_endofpacket,
  input  logic [2:0]                                        asi_ingress_error,
  input  logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_update,
  input  logic                                              lane_credit_update_valid,
  input  logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_update,
  input  logic                                              ticket_credit_update_valid,
  output logic [TICKET_FIFO_DATA_WIDTH-1:0]                 ticket_wdata,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_wptr,
  output logic                                              ticket_we,
  output logic [LANE_FIFO_WIDTH-1:0]                        lane_wdata,
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_wptr,
  output logic                                              lane_we,
  output logic [47:0]                                       running_ts_dbg,
  output logic [5:0]                                        dt_type_dbg,
  output logic [15:0]                                       feb_id_dbg,
`ifdef OPQ_OSS_FORMAL
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_dbg_oss,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_dbg_oss,
`endif
  output logic                                              credit_drop_valid_o,
  output logic                                              credit_drop_lane_o,
  output logic                                              credit_drop_ticket_o,
  output logic [15:0]                                       credit_drop_shd_cnt_o,
  output logic [15:0]                                       credit_drop_hit_cnt_o,
  output logic                                              alert_eop_state_o,
  input  logic                                              eop_flush_ack_i,
  input  logic                                              d_clk,
  input  logic                                              d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;

  localparam int unsigned TICKET_TS_LO = 0;
  localparam int unsigned TICKET_TS_HI = 47;
  localparam int unsigned TICKET_LANE_RD_OFST_LO = 48;
  localparam int unsigned TICKET_LANE_RD_OFST_HI = 48 + LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned TICKET_BLOCK_LEN_LO = 48 + LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned TICKET_BLOCK_LEN_HI = 48 + LANE_FIFO_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned TICKET_SERIAL_LO = 0;
  localparam int unsigned TICKET_SERIAL_HI = FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_N_SUBH_LO = FRAME_SERIAL_SIZE;
  localparam int unsigned TICKET_N_SUBH_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  localparam int unsigned TICKET_N_HIT_LO = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  localparam int unsigned TICKET_N_HIT_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;
  localparam int unsigned TICKET_ALT_EOP_LOC = TICKET_FIFO_DATA_WIDTH - 2;
  localparam int unsigned TICKET_ALT_SOP_LOC = TICKET_FIFO_DATA_WIDTH - 1;

  typedef logic [LANE_FIFO_ADDR_WIDTH-1:0] lane_fifo_addr_t;
  typedef logic [TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifo_addr_t;
  typedef logic [MAX_PKT_LENGTH_BITS-1:0] pkt_length_t;
  localparam lane_fifo_addr_t LANE_FIFO_ADDR_ONE_CONST = {{(LANE_FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam ticket_fifo_addr_t TICKET_FIFO_ADDR_ONE_CONST = {{(TICKET_FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam lane_fifo_addr_t LANE_FIFO_MAX_CREDIT_CONST = LANE_FIFO_MAX_CREDIT;
  localparam ticket_fifo_addr_t TICKET_FIFO_MAX_CREDIT_CONST = TICKET_FIFO_MAX_CREDIT;

  typedef enum logic [2:0] {
    INGRESS_PARSER_IDLE,
    INGRESS_PARSER_UPDATE_HEADER_TS,
    INGRESS_PARSER_MASK_PKT_EXTENDED,
    INGRESS_PARSER_MASK_PKT,
    INGRESS_PARSER_WR_HITS,
    INGRESS_PARSER_RESET
  } ingress_parser_state_t;

  typedef logic [1:0] update_header_ts_flow_t;

  typedef struct packed {
    logic                  lane_we;
    lane_fifo_addr_t       lane_wptr;
    logic [LANE_FIFO_WIDTH-1:0] lane_wdata;
    lane_fifo_addr_t       lane_credit;
    logic                  ticket_we;
    ticket_fifo_addr_t     ticket_wptr;
    logic [TICKET_FIFO_DATA_WIDTH-1:0] ticket_wdata;
    ticket_fifo_addr_t     ticket_credit;
    logic [47:0]           running_ts;
    pkt_length_t           shd_len;
    logic [5:0]            dt_type;
    logic [15:0]           feb_id;
    lane_fifo_addr_t       lane_start_addr;
    logic [15:0]           pkg_cnt;
    logic [15:0]           running_shd_cnt;
    logic [15:0]           hit_cnt;
    logic [30:0]           send_ts;
    logic                  alert_sop;
    logic                  alert_eop;
    logic                  error_lane_wr_early_term;
  } ingress_parser_reg_t;

  ingress_parser_state_t ingress_parser_state;
  update_header_ts_flow_t update_header_ts_flow;
  ingress_parser_reg_t ingress_parser;

  logic ingress_parser_is_subheader;
  logic ingress_parser_is_preamble;
  logic ingress_parser_is_trailer;
  logic ingress_parser_hit_err;
  logic ingress_parser_shd_err;
  logic ingress_parser_hdr_err;
  logic [MAX_PKT_LENGTH_BITS-1:0] ingress_parser_if_subheader_hit_cnt;
  logic [7:0] ingress_parser_if_subheader_shd_ts;
  logic [5:0] ingress_parser_if_preamble_dt_type;
  logic [15:0] ingress_parser_if_preamble_feb_id;
  logic [TICKET_FIFO_DATA_WIDTH-1:0] ingress_parser_if_write_ticket_data;
  logic [LANE_FIFO_WIDTH-1:0] ingress_parser_if_write_lane_data;

  always_comb begin : proc_ingress_parser_comb
    ingress_parser_is_subheader = (asi_ingress_data[7:0] == K237) && (asi_ingress_data[35:32] == 4'b0001);
    ingress_parser_is_preamble = (asi_ingress_data[7:0] == K285) && (asi_ingress_data[35:32] == 4'b0001);
    ingress_parser_is_trailer = (asi_ingress_data[7:0] == K284) && (asi_ingress_data[35:32] == 4'b0001);

    ingress_parser_hit_err = asi_ingress_error[0];
    ingress_parser_shd_err = asi_ingress_error[1];
    ingress_parser_hdr_err = asi_ingress_error[2];

    ingress_parser_if_subheader_hit_cnt = asi_ingress_data[15:8];
    ingress_parser_if_subheader_shd_ts = asi_ingress_data[31:24];
    ingress_parser_if_preamble_dt_type = asi_ingress_data[31:26];
    ingress_parser_if_preamble_feb_id = asi_ingress_data[23:8];

    ingress_parser_if_write_ticket_data = '0;
    if (ingress_parser_state == INGRESS_PARSER_IDLE) begin
      ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO] =
        {ingress_parser.running_ts[47:12], ingress_parser_if_subheader_shd_ts, 4'b0000};
      ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO] =
        ingress_parser.lane_start_addr;
      ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] =
        ingress_parser_if_subheader_hit_cnt;
    end else begin
      ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO] = ingress_parser.running_ts;
      ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO] =
        ingress_parser.lane_start_addr;
      ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] = ingress_parser.shd_len;
    end

    if ((ingress_parser_state == INGRESS_PARSER_UPDATE_HEADER_TS) && (update_header_ts_flow == 2'd3)) begin
      ingress_parser_if_write_ticket_data[TICKET_SERIAL_HI:TICKET_SERIAL_LO] = ingress_parser.pkg_cnt;
      ingress_parser_if_write_ticket_data[TICKET_N_SUBH_HI:TICKET_N_SUBH_LO] = ingress_parser.running_shd_cnt;
      ingress_parser_if_write_ticket_data[TICKET_N_HIT_HI:TICKET_N_HIT_LO] = ingress_parser.hit_cnt;
    end
    ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC] = ingress_parser.alert_eop;
    ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC] = ingress_parser.alert_sop;

    ingress_parser_if_write_lane_data = '0;
    ingress_parser_if_write_lane_data[35:0] = asi_ingress_data;
    ingress_parser_if_write_lane_data[36] = ingress_parser.ticket_we;
    ingress_parser_if_write_lane_data[38] = asi_ingress_error[0];

    ticket_wdata = ingress_parser.ticket_wdata;
    ticket_wptr = ingress_parser.ticket_wptr;
    ticket_we = ingress_parser.ticket_we;
    lane_wdata = ingress_parser.lane_wdata;
    lane_wptr = ingress_parser.lane_wptr;
    lane_we = ingress_parser.lane_we;
    running_ts_dbg = ingress_parser.running_ts;
    dt_type_dbg = ingress_parser.dt_type;
    feb_id_dbg = ingress_parser.feb_id;
`ifdef OPQ_OSS_FORMAL
    lane_credit_dbg_oss = ingress_parser.lane_credit;
    ticket_credit_dbg_oss = ingress_parser.ticket_credit;
`endif
    alert_eop_state_o = ingress_parser.alert_eop;
  end

  always_ff @(posedge d_clk) begin : proc_ingress_parser
    ingress_parser.lane_we <= 1'b0;
    ingress_parser.ticket_we <= 1'b0;
    credit_drop_valid_o <= 1'b0;
    credit_drop_lane_o <= 1'b0;
    credit_drop_ticket_o <= 1'b0;
    credit_drop_shd_cnt_o <= '0;
    credit_drop_hit_cnt_o <= '0;

    if (lane_credit_update_valid) begin
      ingress_parser.lane_credit <= ingress_parser.lane_credit + lane_credit_update;
    end
    if (ticket_credit_update_valid) begin
      ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update;
    end
    if (eop_flush_ack_i) begin
      ingress_parser.alert_eop <= 1'b0;
    end

    unique case (ingress_parser_state)
      INGRESS_PARSER_IDLE: begin
        if (asi_ingress_valid) begin
          if (ingress_parser_is_subheader && !ingress_parser_shd_err) begin
            ingress_parser.running_ts[11:4] <= ingress_parser_if_subheader_shd_ts;
            ingress_parser.shd_len <= ingress_parser_if_subheader_hit_cnt;
            if (int'(ingress_parser_if_subheader_hit_cnt) >= int'(ingress_parser.lane_credit)) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_lane_o <= 1'b1;
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= {8'd0, ingress_parser_if_subheader_hit_cnt};
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser.ticket_credit == '0) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_ticket_o <= 1'b1;
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= {8'd0, ingress_parser_if_subheader_hit_cnt};
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser_if_subheader_hit_cnt != '0) begin
              ingress_parser_state <= INGRESS_PARSER_WR_HITS;
            end else begin
              ingress_parser.ticket_we <= 1'b1;
              ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
              ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
              if (ticket_credit_update_valid) begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                  TICKET_FIFO_ADDR_ONE_CONST;
              end else begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
              end
            end
          end else if (asi_ingress_startofpacket && ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end else if (ingress_parser_is_trailer) begin
            ingress_parser.alert_eop <= 1'b1;
          end

          if (ingress_parser_shd_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
          end
          if (ingress_parser_hdr_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
          end
          if (ingress_parser.error_lane_wr_early_term) begin
            ingress_parser.error_lane_wr_early_term <= 1'b0;
            ingress_parser.lane_wptr <= ingress_parser.lane_start_addr + ingress_parser.shd_len;
          end
        end
      end

      INGRESS_PARSER_UPDATE_HEADER_TS: begin
        if (asi_ingress_valid) begin
          unique case (update_header_ts_flow)
            2'd0: begin
              ingress_parser.running_ts[47:16] <= asi_ingress_data[31:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd1: begin
              ingress_parser.running_ts[15:0] <= asi_ingress_data[31:16];
              ingress_parser.pkg_cnt <= asi_ingress_data[15:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd2: begin
              ingress_parser.running_shd_cnt <= asi_ingress_data[31:16];
              ingress_parser.hit_cnt <= asi_ingress_data[15:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd3: begin
              ingress_parser.send_ts <= asi_ingress_data[30:0];
              update_header_ts_flow <= '0;
              if (ingress_parser.ticket_credit != '0) begin
                ingress_parser.alert_sop <= 1'b0;
                ingress_parser.ticket_we <= 1'b1;
                if (ticket_credit_update_valid) begin
                  ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                    TICKET_FIFO_ADDR_ONE_CONST;
                end else begin
                  ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
                end
                ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
                ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
                ingress_parser_state <= INGRESS_PARSER_IDLE;
              end else begin
                ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
              end
            end
            default: begin
            end
          endcase

          if (ingress_parser_hdr_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
          end
        end
      end

      INGRESS_PARSER_MASK_PKT_EXTENDED: begin
        if (asi_ingress_valid) begin
          if (ingress_parser_is_trailer) begin
            ingress_parser_state <= INGRESS_PARSER_IDLE;
          end else if (ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end
        end
      end

      INGRESS_PARSER_MASK_PKT: begin
        if (asi_ingress_valid && asi_ingress_endofpacket) begin
          ingress_parser_state <= INGRESS_PARSER_IDLE;
        end

        if (asi_ingress_valid) begin
          if (ingress_parser_is_subheader && !ingress_parser_shd_err) begin
            ingress_parser.running_ts[11:4] <= ingress_parser_if_subheader_shd_ts;
            ingress_parser.shd_len <= ingress_parser_if_subheader_hit_cnt;
            if (int'(ingress_parser_if_subheader_hit_cnt) >= int'(ingress_parser.lane_credit)) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_lane_o <= 1'b1;
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= {8'd0, ingress_parser_if_subheader_hit_cnt};
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser.ticket_credit == '0) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_ticket_o <= 1'b1;
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= {8'd0, ingress_parser_if_subheader_hit_cnt};
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser_if_subheader_hit_cnt != '0) begin
              ingress_parser_state <= INGRESS_PARSER_WR_HITS;
            end else begin
              ingress_parser.ticket_we <= 1'b1;
              ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
              ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
              ingress_parser.alert_eop <= 1'b0;
              if (ticket_credit_update_valid) begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                  TICKET_FIFO_ADDR_ONE_CONST;
              end else begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
              end
            end
          end else if (asi_ingress_startofpacket && ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end else if (ingress_parser_is_trailer) begin
            ingress_parser.alert_eop <= 1'b1;
          end
        end
      end

      INGRESS_PARSER_WR_HITS: begin
        if (asi_ingress_valid && !ingress_parser_hit_err) begin
          ingress_parser.lane_wdata <= ingress_parser_if_write_lane_data;
          ingress_parser.lane_wptr <= ingress_parser.lane_wptr + LANE_FIFO_ADDR_ONE_CONST;
          ingress_parser.lane_we <= 1'b1;
        end else if (ingress_parser_shd_err) begin
          ingress_parser.error_lane_wr_early_term <= 1'b1;
        end

        if (asi_ingress_valid && !ingress_parser_hit_err) begin
          if ((ingress_parser.lane_start_addr + ingress_parser.shd_len) ==
              (ingress_parser.lane_wptr + LANE_FIFO_ADDR_ONE_CONST)) begin
            ingress_parser.ticket_we <= 1'b1;
            ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
            ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
            if (ticket_credit_update_valid) begin
              ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                TICKET_FIFO_ADDR_ONE_CONST;
            end else begin
              ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
            end
            if (lane_credit_update_valid) begin
              ingress_parser.lane_credit <= ingress_parser.lane_credit - ingress_parser.shd_len +
                lane_credit_update;
            end else begin
              ingress_parser.lane_credit <= ingress_parser.lane_credit - ingress_parser.shd_len;
            end
            ingress_parser.lane_start_addr <= ingress_parser.lane_wptr + LANE_FIFO_ADDR_ONE_CONST;
            ingress_parser_state <= INGRESS_PARSER_IDLE;
          end
        end
      end

      INGRESS_PARSER_RESET: begin
        ingress_parser <= '0;
        ingress_parser.lane_credit <= LANE_FIFO_MAX_CREDIT_CONST;
        ingress_parser.ticket_credit <= TICKET_FIFO_MAX_CREDIT_CONST;
        if ((ingress_parser.lane_credit == LANE_FIFO_MAX_CREDIT_CONST) &&
            (ingress_parser.ticket_credit == TICKET_FIFO_MAX_CREDIT_CONST)) begin
          ingress_parser_state <= INGRESS_PARSER_IDLE;
        end
      end

      default: begin
      end
    endcase

    if (ingress_parser.ticket_we && ingress_parser.alert_eop) begin
      ingress_parser.alert_eop <= 1'b0;
    end

    if (d_reset) begin
      ingress_parser <= '0;
      ingress_parser.lane_credit <= LANE_FIFO_MAX_CREDIT_CONST;
      ingress_parser.ticket_credit <= TICKET_FIFO_MAX_CREDIT_CONST;
      ingress_parser_state <= INGRESS_PARSER_RESET;
      update_header_ts_flow <= '0;
      credit_drop_valid_o <= 1'b0;
      credit_drop_lane_o <= 1'b0;
      credit_drop_ticket_o <= 1'b0;
      credit_drop_shd_cnt_o <= '0;
      credit_drop_hit_cnt_o <= '0;
    end
  end

`ifndef OPQ_OSS_FORMAL
  property p_reset_drives_ingress_parser_reset;
    @(posedge d_clk) d_reset |=> (ingress_parser_state == INGRESS_PARSER_RESET);
  endproperty
  ap_reset_drives_ingress_parser_reset: assert property (p_reset_drives_ingress_parser_reset);

  // TODO: pointer-advance assertions need a dedicated pre-update shadow register.
  // The exported write pulse and pointer are both driven from the same clocked process,
  // so a direct SVA on the public outputs samples the wrong phase and false-fires.

  property p_alert_eop_clears_after_ticket_write;
    @(posedge d_clk) disable iff (d_reset)
      (ticket_we && ingress_parser.alert_eop) |=> !ingress_parser.alert_eop;
  endproperty
  ap_alert_eop_clears_after_ticket_write: assert property (p_alert_eop_clears_after_ticket_write);
`endif

`ifdef OPQ_ENABLE_NATIVE_FORMAL_INGRESS
  opq_native_ingress_formal_sva #(
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .LANE_FIFO_ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH),
    .TICKET_FIFO_ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH),
    .TICKET_FIFO_DATA_WIDTH(TICKET_FIFO_DATA_WIDTH),
    .TICKET_ALT_EOP_LOC(TICKET_ALT_EOP_LOC),
    .TICKET_ALT_SOP_LOC(TICKET_ALT_SOP_LOC)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .asi_ingress_valid(asi_ingress_valid),
    .asi_ingress_startofpacket(asi_ingress_startofpacket),
    .asi_ingress_endofpacket(asi_ingress_endofpacket),
    .asi_ingress_data(asi_ingress_data),
    .asi_ingress_error(asi_ingress_error),
    .lane_credit_update(lane_credit_update),
    .lane_credit_update_valid(lane_credit_update_valid),
    .ticket_credit_update(ticket_credit_update),
    .ticket_credit_update_valid(ticket_credit_update_valid),
    .ticket_wdata(ticket_wdata),
    .ticket_wptr(ticket_wptr),
    .ticket_we(ticket_we),
    .lane_wptr(lane_wptr),
    .lane_we(lane_we),
    .lane_credit_dbg(ingress_parser.lane_credit),
    .ticket_credit_dbg(ingress_parser.ticket_credit),
    .alert_eop_dbg(ingress_parser.alert_eop),
    .eop_flush_ack_i(eop_flush_ack_i)
  );
`endif

endmodule

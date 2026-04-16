//------------------------------------------------------------------------------
// IP Name   : tb_int_egress_contract_sva
// Description:
//   Passive sideband contract checker for the OPQ egress stream. Unlike the
//   generic framed-stream checker used at C/D, OPQ derives SOP and EOP
//   explicitly from the emitted K28.5/K28.4 words. Check that those sidebands
//   stay aligned with the actual accepted beat content.
//------------------------------------------------------------------------------
module tb_int_egress_contract_sva #(
  parameter int MAX_ERROR_REPORTS = 16
) (
  input logic        clk,
  input logic        reset,
  input logic [35:0] data,
  input logic        valid,
  input logic        ready,
  input logic        sop,
  input logic        eop
);
  int unsigned contract_err_count;
  bit          contract_err_saturated;

  function automatic logic pkt_is_preamble(input logic [35:0] word);
    return (word[35:32] == 4'b0001) && (word[7:0] == 8'hBC);
  endfunction

  function automatic logic pkt_is_trailer(input logic [35:0] word);
    return (word[35:32] == 4'b0001) && (word[7:0] == 8'h9C);
  endfunction

  task automatic report_contract_error(input string msg);
    begin
      contract_err_count = contract_err_count + 1;
      if (contract_err_count <= MAX_ERROR_REPORTS) begin
        $error("[tb_int_egress_contract] %s", msg);
      end else if (!contract_err_saturated) begin
        contract_err_saturated = 1'b1;
        $error("[tb_int_egress_contract] report limit reached, suppressing further messages");
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (reset) begin
      contract_err_count     <= 0;
      contract_err_saturated <= 1'b0;
    end else if (valid && ready) begin
      if (sop && !pkt_is_preamble(data))
        report_contract_error("startofpacket asserted on a non-preamble egress beat");
      if (eop && !pkt_is_trailer(data))
        report_contract_error("endofpacket asserted on a non-trailer egress beat");
      if (pkt_is_preamble(data) && !sop)
        report_contract_error("preamble beat observed without startofpacket");
      if (pkt_is_trailer(data) && !eop)
        report_contract_error("trailer beat observed without endofpacket");
    end
  end

  final begin
    if (contract_err_count > MAX_ERROR_REPORTS) begin
      $display("[tb_int_egress_contract] suppressed %0d additional errors",
               contract_err_count - MAX_ERROR_REPORTS);
    end
  end
endmodule

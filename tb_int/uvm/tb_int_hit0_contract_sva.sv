//------------------------------------------------------------------------------
// IP Name   : tb_int_hit0_contract_sva
// Description:
//   Passive contract checker for the frame_rcv_ip hit_type0 stream.
//   In MODE_HALT=0 the producer explicitly allows recovery patterns such as
//   `sop ... sop eop` and `... eop sop eop`, so this checker only enforces
//   the sideband guarantees that are actually documented by the RTL:
//     - SOP/EOP are only meaningful on valid beats
//     - hit_error is only meaningful on valid beats
//   `crc_error` is sampled passively by the scoreboard but is not constrained
//   here because the live wrapper timing does not line up with a simple
//   "valid && eop" contract.
//------------------------------------------------------------------------------
module tb_int_hit0_contract_sva #(
  parameter int MAX_ERROR_REPORTS = 16
) (
  input logic clk,
  input logic reset,
  input logic valid,
  input logic hit_error,
  input logic crc_error,
  input logic sop,
  input logic eop
);
  int unsigned contract_err_count;
  bit          contract_err_saturated;

  task automatic report_contract_error(input string msg);
    begin
      contract_err_count = contract_err_count + 1;
      if (contract_err_count <= MAX_ERROR_REPORTS) begin
        $error("[tb_int_hit0_contract] %s", msg);
      end else if (!contract_err_saturated) begin
        contract_err_saturated = 1'b1;
        $error("[tb_int_hit0_contract] report limit reached, suppressing further messages");
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (reset) begin
      contract_err_count     <= 0;
      contract_err_saturated <= 1'b0;
    end else begin
      if (sop && !valid)
        report_contract_error("startofpacket asserted without a valid hit_type0 beat");
      if (eop && !valid)
        report_contract_error("endofpacket asserted without a valid hit_type0 beat");
      if (hit_error && !valid)
        report_contract_error("hit_error asserted without a valid hit_type0 beat");
    end
  end

  final begin
    if (contract_err_count > MAX_ERROR_REPORTS) begin
      $display("[tb_int_hit0_contract] suppressed %0d additional errors",
               contract_err_count - MAX_ERROR_REPORTS);
    end
  end
endmodule

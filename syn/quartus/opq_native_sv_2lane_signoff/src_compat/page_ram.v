module page_ram #(
  parameter DATA_WIDTH = 40,
  parameter ADDR_WIDTH = 16
) (
  input [(DATA_WIDTH-1):0] data,
  input [(ADDR_WIDTH-1):0] read_addr,
  input [(ADDR_WIDTH-1):0] write_addr,
  input we,
  input clk,
  output reg [(DATA_WIDTH-1):0] q
);
  (* ramstyle = "M20K, no_rw_check" *) reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

  always @(posedge clk) begin
    if (we)
      ram[write_addr] <= data;

    if (we && (read_addr == write_addr))
      q <= data;
    else
      q <= ram[read_addr];
  end
endmodule

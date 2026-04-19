module lane_fifo
#(parameter DATA_WIDTH=40, parameter ADDR_WIDTH=9)
(
	input [(DATA_WIDTH-1):0] data,
	input [(ADDR_WIDTH-1):0] read_addr, write_addr,
	input we, clk,
	output [(DATA_WIDTH-1):0] q
);

	localparam DEPTH = (1 << ADDR_WIDTH);

`ifdef SYNTHESIS
	wire [(DATA_WIDTH-1):0] ram_q;

	// Quartus 18.1 does not infer the deep lane FIFOs into block RAM reliably on
	// the standalone Arria 10 signoff path, so use an explicit simple dual-port
	// altsyncram for synthesis.
	altsyncram lane_fifo_ram (
		.address_a (write_addr),
		.address_b (read_addr),
		.clock0    (clk),
		.data_a    (data),
		.q_b       (ram_q),
		.wren_a    (we)
	);

	defparam
		lane_fifo_ram.address_reg_b = "CLOCK0",
		lane_fifo_ram.clock_enable_input_a = "BYPASS",
		lane_fifo_ram.clock_enable_input_b = "BYPASS",
		lane_fifo_ram.clock_enable_output_b = "BYPASS",
		lane_fifo_ram.indata_reg_b = "CLOCK0",
		lane_fifo_ram.intended_device_family = "Arria 10",
		lane_fifo_ram.lpm_type = "altsyncram",
		lane_fifo_ram.numwords_a = DEPTH,
		lane_fifo_ram.numwords_b = DEPTH,
		lane_fifo_ram.operation_mode = "DUAL_PORT",
		lane_fifo_ram.outdata_aclr_b = "NONE",
		lane_fifo_ram.outdata_reg_b = "UNREGISTERED",
		lane_fifo_ram.power_up_uninitialized = "FALSE",
		lane_fifo_ram.ram_block_type = "M20K",
		lane_fifo_ram.read_during_write_mode_mixed_ports = "OLD_DATA",
		lane_fifo_ram.width_a = DATA_WIDTH,
		lane_fifo_ram.width_b = DATA_WIDTH,
		lane_fifo_ram.width_byteena_a = 1,
		lane_fifo_ram.widthad_a = ADDR_WIDTH,
		lane_fifo_ram.widthad_b = ADDR_WIDTH;

	assign q = (we && (read_addr == write_addr)) ? data : ram_q;
`else
	reg [(DATA_WIDTH-1):0] q_reg;
	assign q = q_reg;

	// Match the standalone Arria 10 synthesis path to block RAM rather than
	// leaving the deep lane FIFOs in ALM logic.
	(* ramstyle = "M20K, no_rw_check" *) reg [DATA_WIDTH-1:0] ram[DEPTH-1:0];
`ifndef SYNTHESIS
	integer init_i;
	initial begin
		for (init_i = 0; init_i < DEPTH; init_i = init_i + 1)
			ram[init_i] = {DATA_WIDTH{1'b0}};
	end
`endif

	always @ (posedge clk)
	begin
		// Write
		if (we)
			ram[write_addr] <= data;

		// Read (bypass on same-address read/write).
		if (we && (read_addr == write_addr))
			q_reg <= data;
		else
			q_reg <= ram[read_addr];
	end
`endif

endmodule

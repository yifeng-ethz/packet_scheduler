// ---------------------------------------------------------------------------
// IP Name    : tb_int_if
// Author     : Yifeng Wang (yifenwan@phys.ethz.ch)
// Description:
//   Interfaces handed to UVM agents for packet_scheduler/tb_int. One
//   interface per role. Stage D/E taps live on the OPQ ingress/egress
//   interfaces declared here and are bound onto by stage_d / stage_e
//   monitors.
// ---------------------------------------------------------------------------

interface opq_ingress_if #(parameter int DATA_W = 36, parameter int CH_W = 2) (
    input logic clk,
    input logic rst
);
    logic [DATA_W-1:0] data;
    logic              valid;
    logic [CH_W-1:0]   channel;
    logic              startofpacket;
    logic              endofpacket;
    logic [2:0]        error;
endinterface

interface opq_egress_if #(parameter int DATA_W = 36) (
    input logic clk,
    input logic rst
);
    logic [DATA_W-1:0] data;
    logic              valid;
    logic              ready;
    logic              startofpacket;
    logic              endofpacket;
    logic [2:0]        error;
endinterface

interface hit_type2_if #(
    parameter int DATA_W = 36,
    parameter int CH_W   = 4,
    parameter int ERR_W  = 1
) (
    input logic clk,
    input logic rst
);
    logic [DATA_W-1:0] data;
    logic              valid;
    logic              ready;
    logic [CH_W-1:0]   channel;
    logic              startofpacket;
    logic              endofpacket;
    logic [ERR_W-1:0]  error;
endinterface

interface hit_type0_if #(
    parameter int DATA_W = 45,
    parameter int CH_W   = 4,
    parameter int ERR_W  = 3
) (
    input logic clk,
    input logic rst
);
    logic [DATA_W-1:0] data;
    logic              valid;
    logic [CH_W-1:0]   channel;
    logic              startofpacket;
    logic              endofpacket;
    logic [ERR_W-1:0]  error;
endinterface

interface hit_type1_if #(
    parameter int DATA_W = 39,
    parameter int CH_W   = 4
) (
    input logic clk,
    input logic rst
);
    logic [DATA_W-1:0] data;
    logic              valid;
    logic              ready;
    logic [CH_W-1:0]   channel;
    logic              startofpacket;
    logic              endofpacket;
    logic              empty;
    logic              error;
endinterface

interface run_control_if (
    input logic clk,
    input logic rst
);
    // run_state broadcast (9-bit one-hot, tb-side encoded)
    logic [8:0] run_state;
    // run_enable qualifier handed to the SWB ingress stub
    logic       run_enable;
    // PREP done aggregate from every datapath_stub. Driven by tb_int_top
    // (AND-reduce of every IP's asi_ctrl_ready across all 4 datapaths) so
    // the run_control_driver can wait for the slowest IP — ring_buffer_cam
    // takes ~131k cycles to flush its CAM/RAM in RUN_PREPARE — before
    // advancing to SYNC.
    logic       prep_done;
    // TERMINATING done aggregate, sourced from the same datapath-wide
    // asi_ctrl_ready reduction once every child IP has acknowledged drain
    // completion for the current run.
    logic       term_done;
    // FEB datapath quiet indicator, asserted when no datapath is still
    // driving the pre-gate FEB output stream. This keeps tb_int from
    // forcing IDLE in the middle of a late draining frame.
    logic       feb_quiet;
endinterface

interface opq_csr_if #(parameter int ADDR_W = 9) (
    input logic clk,
    input logic rst
);
    logic [ADDR_W-1:0] address;
    logic              read;
    logic              write;
    logic [31:0]       writedata;
    logic [31:0]       readdata;
    logic              readdatavalid;
    logic              waitrequest;
    logic              burstcount;
endinterface

interface emut_avmm_csr_if #(parameter int ADDR_W = 4) (
    input logic clk,
    input logic rst
);
    logic [ADDR_W-1:0] address;
    logic              read;
    logic              write;
    logic [31:0]       writedata;
    logic [31:0]       readdata;
    logic              waitrequest;

    modport drv (
        output address, read, write, writedata,
        input  readdata, waitrequest, clk, rst
    );

    modport mon (
        input address, read, write, writedata, readdata, waitrequest, clk, rst
    );
endinterface

// Stage A tap — one instance per datapath. Driven from tb_int_top with
// hierarchical references into hit_generator. `valid` is the 1-cycle pulse
// for the shared-L2 enqueue inside the emulator (the earliest durable point
// that can still reach the frame assembler); `payload` is the 48-bit raw
// L2-style hit word; {feb_id, datapath_id, mutrig_ch} are tied constants
// identifying which FEB.datapath.chip emitted the hit.
interface stage_a_if (
    input logic clk,
    input logic rst
);
    logic        valid;
    logic [47:0] payload;
    logic [1:0]  feb_id;
    logic        datapath_id;
    logic [2:0]  mutrig_ch;
endinterface

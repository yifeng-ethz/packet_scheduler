module tb_int_run_enable_contract_sva (
    input logic       clk,
    input logic       reset,
    input logic [8:0] run_state,
    input logic       run_enable
);

    localparam bit [8:0] RC_STATE_IDLE        = 9'b0_0000_0001;
    localparam bit [8:0] RC_STATE_SYNC        = 9'b0_0000_0100;
    localparam bit [8:0] RC_STATE_RUNNING     = 9'b0_0000_1000;
    localparam bit [8:0] RC_STATE_TERMINATING = 9'b0_0001_0000;

    property gate_only_in_active_states_p;
        @(posedge clk) disable iff (reset)
            run_enable |-> ((run_state == RC_STATE_RUNNING) ||
                            (run_state == RC_STATE_TERMINATING));
    endproperty

    property gate_low_during_sync_p;
        @(posedge clk) disable iff (reset)
            (run_state == RC_STATE_SYNC) |-> !run_enable;
    endproperty

    property gate_rises_on_running_p;
        @(posedge clk) disable iff (reset)
            $rose(run_enable) |-> (run_state == RC_STATE_RUNNING);
    endproperty

    property gate_falls_on_idle_p;
        @(posedge clk) disable iff (reset)
            $fell(run_enable) |-> (run_state == RC_STATE_IDLE);
    endproperty

    a_gate_only_in_active_states: assert property (gate_only_in_active_states_p)
        else $error("tb_int run-enable violation: SWB gate asserted outside RUNNING/TERMINATING");

    a_gate_low_during_sync: assert property (gate_low_during_sync_p)
        else $error("tb_int run-enable violation: SWB gate asserted during SYNC");

    a_gate_rises_on_running: assert property (gate_rises_on_running_p)
        else $error("tb_int run-enable violation: SWB gate rose outside RUNNING");

    a_gate_falls_on_idle: assert property (gate_falls_on_idle_p)
        else $error("tb_int run-enable violation: SWB gate fell outside IDLE");

endmodule

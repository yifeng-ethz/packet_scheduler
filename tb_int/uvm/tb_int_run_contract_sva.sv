module tb_int_run_contract_sva #(
    parameter bit ALLOW_TERMINATING = 1'b0
)(
    input logic       clk,
    input logic       reset,
    input logic [8:0] run_state,
    input logic       valid
);

    localparam bit [8:0] RC_STATE_RUNNING     = 9'b0_0000_1000;
    localparam bit [8:0] RC_STATE_TERMINATING = 9'b0_0001_0000;

    function automatic bit run_state_allowed(bit [8:0] s);
        if (s == RC_STATE_RUNNING)
            return 1'b1;
        if (ALLOW_TERMINATING && (s == RC_STATE_TERMINATING))
            return 1'b1;
        return 1'b0;
    endfunction

    property valid_only_in_allowed_state_p;
        @(posedge clk) disable iff (reset)
            valid |-> run_state_allowed(run_state);
    endproperty

    a_valid_only_in_allowed_state: assert property (valid_only_in_allowed_state_p)
        else $error("tb_int run-contract violation: valid observed outside the allowed run state");

endmodule

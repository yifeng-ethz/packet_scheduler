//------------------------------------------------------------------------------
// IP Name   : opq_drr_sva
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Revision  : 0.2 - align defer semantics to the sequential allowance-reload contract
// Description:
//   Scheduler-side SVA for the shared page-RAM DRR arbiter.
//------------------------------------------------------------------------------
module opq_drr_sva #(
  parameter int N_LANE = 2
) (
  input logic              clk,
  input logic              reset,
  input logic [N_LANE-1:0] req_raw,
  input logic [N_LANE-1:0] req_eligible,
  input logic [N_LANE-1:0] gnt,
  input logic [N_LANE-1:0] sel_mask,
  input logic [N_LANE-1:0] lock_event,
  input logic [N_LANE-1:0] defer_event,
  input logic              locked,
  input logic              pa_write
);

  assert property (@(posedge clk) disable iff (reset) $onehot0(gnt))
    else $error("OPQ_DRR_SVA grant is not onehot0");

  assert property (@(posedge clk) disable iff (reset) $onehot0(sel_mask))
    else $error("OPQ_DRR_SVA sel_mask is not onehot0");

  assert property (@(posedge clk) disable iff (reset) $onehot0(lock_event))
    else $error("OPQ_DRR_SVA lock_event is not onehot0");

  assert property (@(posedge clk) disable iff (reset) pa_write |-> (gnt == '0))
    else $error("OPQ_DRR_SVA page allocator write must suppress block-mover grants");

  assert property (@(posedge clk) disable iff (reset) locked |-> (sel_mask != '0))
    else $error("OPQ_DRR_SVA locked state without an owning lane");

  assert property (@(posedge clk) disable iff (reset)
    locked && !pa_write |-> (gnt == (sel_mask & req_raw)))
    else $error("OPQ_DRR_SVA locked arbiter changed owner or granted without an active owner request");

  assert property (@(posedge clk) disable iff (reset)
    !locked && (gnt != '0) |-> ((gnt & ~req_eligible) == '0))
    else $error("OPQ_DRR_SVA unlocked arbiter granted a non-eligible lane");

  assert property (@(posedge clk) disable iff (reset)
    !locked && !pa_write && (req_eligible == '0) |-> (gnt == '0))
    else $error("OPQ_DRR_SVA unlocked arbiter granted without any eligible request");

  assert property (@(posedge clk) disable iff (reset)
    (gnt != '0) |-> ((gnt & ~req_raw) == '0))
    else $error("OPQ_DRR_SVA arbiter granted a lane without a raw request");

  genvar lane;
  generate
    for (lane = 0; lane < N_LANE; lane++) begin : gen_lane
      assert property (@(posedge clk) disable iff (reset)
        defer_event[lane] |-> $past(req_raw[lane] && !req_eligible[lane]))
        else $error("OPQ_DRR_SVA defer event without blocked request on lane %0d", lane);

      assert property (@(posedge clk) disable iff (reset)
        defer_event[lane] |-> !($past(req_eligible[lane]) && !$past(pa_write)))
        else $error("OPQ_DRR_SVA defer event on lane %0d occurred even though the lane was already eligible in the previous cycle", lane);

      assert property (@(posedge clk) disable iff (reset)
        lock_event[lane] |-> ##[1:2] sel_mask[lane])
        else $error("OPQ_DRR_SVA lock event did not publish the same owner on lane %0d", lane);

      assert property (@(posedge clk) disable iff (reset)
        lock_event[lane] |-> ((req_raw[lane] && req_eligible[lane]) ||
                              $past(req_raw[lane] && req_eligible[lane])))
        else $error("OPQ_DRR_SVA lock event occurred without an eligible request on lane %0d", lane);

      cover property (@(posedge clk) disable iff (reset)
        req_raw[lane] && !req_eligible[lane] ##1 defer_event[lane]);

      cover property (@(posedge clk) disable iff (reset)
        req_raw[lane] && req_eligible[lane] ##1 lock_event[lane]);

      cover property (@(posedge clk) disable iff (reset)
        req_raw[lane] && !req_eligible[lane] ##1 defer_event[lane] ##[1:16]
        req_raw[lane] && req_eligible[lane] ##1 lock_event[lane]);
    end
  endgenerate

endmodule

# OPQ verification plan (split vs monolithic)

Scope: verify the *split* implementation (`packet_scheduler/rtl/ordered_priority_queue/split/`) is functionally compatible with the monolithic OPQ (`packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue*.terp.vhd`) and never produces **broken packets** under stress (especially overwrite / long `aso_egress_ready=0` cases).

This plan is meant to be executed with UVM, and it explicitly includes lane-count coverage (`N_LANE=2..16`) and skewed traffic patterns (lane imbalance + max-hit bursts).

## 1) Definitions / invariants

- **Marker words**
  - K28.5 (0xBC): preamble (frame start marker)
  - K23.7 (0xF7): subheader marker
  - K28.4 (0x9C): trailer (frame end marker)
- **Frame key**: `{frame_ts, pkg_cnt}` extracted from the header.
- **Broken packet**: any of:
  - egress frame missing K28.5 at SOP or missing K28.4 at EOP
  - egress frame with malformed structure (e.g., subheaders/hits not matching declared counts)
  - **mixed** frame content (hits from a different `{frame_ts,pkg_cnt}` appear within a frame)

## 2) Pass/fail criteria (what “correct” means)

### Must-pass (always required)
1. **No broken packets** on egress under any test.
2. **No “hits in wrong packet”**:
   - every emitted hit must map to an input hit,
   - with matching `{frame_ts, pkg_cnt, ts48}` reconstruction.
3. **Hit trimming correctness** (if enabled in stimulus and expected by the TB):
   - if a subheader declares more than `N_HIT`, the DUT must not leak trimmed hits into the next packet/frame.

### Allowed under stress (explicitly tolerated)
- **Whole-frame drops are acceptable** during overwrite/overflow/long-stall contention scenarios.
  - This is aligned with the architecture comments: sacrificing a frame is preferred to emitting a corrupted one.
  - The TB must still report **drop rate** and highlight the first few dropped keys for debugging.

### Split vs monolithic “compatibility” target
- For non-overflow / no-forced-contention tests: outputs should match (or at least be a strict subset in the presence of trimming).
- For forced-overflow tests: match is not strictly required, but:
  - both implementations must meet the must-pass invariants, and
  - any behavioral delta must be reported (drop rate, which keys drop, and whether overwrite events are correlated).

## 3) Test dimensions (orthogonal stress axes)

### A) Lane count & imbalance (primary new coverage)
Run all tests for:
- `N_LANE = 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16`

Per lane count, sweep lane imbalance patterns:
- **Balanced**: each lane generates the same hit distribution (aligned frames).
- **Skewed**: one “hot lane” generates high hits (near `N_HIT`) while others generate mostly zeros.
- **Sparse**: only 1 active lane, the rest idle (ensures lane-idle bookkeeping doesn’t break).
- **Phase-shifted**: different lanes start frames with deliberate SOP gaps (skew in ticket timing).

### B) Hits/subheaders geometry (corner cases)
For each lane pattern, vary:
- Hits per subheader: `{0, 1, 2, 8, 64, 255}`
- “Over-limit” declarations: `{256, 300}` (expect trimming to `N_HIT` if `EXPECT_TRIM_TO_N_HIT=1`)
- Subheader count per frame: small (`2/4/8`) and nominal (`128`), plus at least one stress point near limit (`255/256`) if supported by the generator.

### C) Egress backpressure (reproduce overwrite / stall sensitivity)
Use a matrix of `aso_egress_ready` patterns:
- Always ready (`ready=1`) baseline.
- Light random gaps (small `ready=0` probability) to perturb timing without inducing overflow.
- Bursty windows (random hi/lo windows).
- **Deterministic long stall mid-packet**:
  - `ready=0` for `{1k, 10k, 100k}` cycles
  - trigger after `{1, 4, 16}` accepted beats since SOP
  - single-shot and repeating (every packet)

### D) Overflow / overwrite forcing
To intentionally hit the known bug-class:
- Drive sustained ingress while holding egress `ready=0` long enough to force tile FIFO pressure.
- Use reduced-depth configurations (simulation-only knobs) to reach wrap/overwrite quickly:
  - small `TILE_FIFO_DEPTH`, small `PAGE_RAM_DEPTH`, and/or small `LANE_FIFO_DEPTH`
- Explicitly record when overwrite/drop happens and ensure it is always an entire frame.

## 4) Scoreboard requirements (minimum feature set)

The scoreboard needs to validate both **structure** and **content association**:
- Egress structure: SOP/EOP boundaries; K-marker placement.
- Frame key extraction: `{frame_ts, pkg_cnt}` monotonicity/consistency.
- Hit association:
  - output hit IDs must exist in the input set,
  - and must match expected `{frame_ts,pkg_cnt,ts48}`.
- Drop reporting (when allowed):
  - count dropped frame keys,
  - flag “partial frame” conditions as errors (output frame exists but missing expected hits/subheaders, unless explicitly marked as trimmed).

## 5) Method to compare split vs monolithic

For each test point:
1. Run monolithic with a fixed seed / fixed plusargs.
2. Run split with the same seed / plusargs.
3. Compare:
   - total egress frames/hits
   - total dropped frames (and the first N dropped keys)
   - first failing key (if any)
4. If mismatch:
   - keep both logs,
   - emit a short summary (“delta report”) for that test point.

## 6) Implementation notes (what we need in the code)

1. **TERP top wrapper**: generate split top with lane ports for `N_LANE=2..16`.
   - Template: `packet_scheduler/rtl/ordered_priority_queue/split/top/ordered_priority_queue_top.terp.vhd`
2. **UVM must be generalized to N lanes**:
   - existing `uvm_order_priority_queue` is 2-lane; refactor to array-based lanes and compile-time `N_LANE`.
3. **Regression runner**:
   - a script that sweeps `N_LANE=2..16` and the stress axes above, and prints progress.

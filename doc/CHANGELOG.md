# Changelog

## 26.2.0.0413

- **RTL / Packaging**: added a real Avalon-MM CSR slave to the monolithic OPQ. The packaged IP now exposes the common Mu3e `UID + META` identity header at CSR words `0x000/0x001`, a software `LANE_MASK` control register, a `CTRL` clear pulse, status/capability words, and a per-lane counter window.
- **RTL**: implemented per-lane runtime counters in the monolithic VHDL for header/subheader/hit write, read, and drop activity, plus live lane/ticket free-credit readback. The lane mask applies at packet boundaries: in-flight packets drain, then newly arriving packets on masked lanes are dropped and counted.
- **Synthesis Example**: updated `syn/opq_monolithic_4lane_merge` to the new catalog revision, fixed its local search path to discover the IP from `packet_scheduler/`, and regenerated the example `.qsys` / `.sopcinfo` / synthesis outputs with the exported `csr` interface.
- **Verification**: reran the active UVM basic smoke on the VHDL implementation after the CSR insertion. The shared scoreboard still closes with `expected=4 actual=4 missing=0 ghost=0`, so the observability/control add did not disturb the exercised data path.

## 26.1.0.0413

- **RTL**: promoted the native SystemVerilog rewrite to a versioned milestone. The exercised default/basic monolithic path is now native SV for the per-lane ingress parser, shared page allocator, handle-reader/block-mover/B2P arbiter, and the current single-page presenter. The `opq_basic_smoke_test` default case passes on `DUT_IMPL=native_sv` with the same observable behavior as the VHDL wrapper path.
- **RTL**: started the frame-table side of the rewrite in the preserved split architecture. New standalone SV blocks now exist for the frame-table tracker and frame-table presenter under `rtl/ordered_priority_queue/monolithic_sv/`. They are compile-clean staging blocks for the later top-level swap; the active monolithic shell still uses the basic presenter until the frame-table mapper and tiled top wiring are completed.
- **Verification Harness**: froze the current UVM contract around the real ingress packet format. The driver/monitor contract remains FEB-frame oriented, and the scoreboard checks hit integrity end to end: every hit observed at ingress must reappear at egress with the correct subheader slot and without ghost creation. The scoreboard timestamp key is the reconstructed 48-bit hit timestamp from frame header + subheader timing, and a UVM-only 64-bit `HIT_ID` side channel is carried in the harness for exact missing/ghost-hit tracking without changing synthesizable RTL.
- **Verification Harness**: `DUT_IMPL=vhdl` and `DUT_IMPL=native_sv` intentionally share the same sequencer, monitors, scoreboard, and SVA contract. The native-SV bring-up currently closes the basic smoke case with `expected=4 actual=4 missing=0 ghost=0`, while the placeholder edge/error/cross/prof buckets remain compile-clean entry points for the full DV-plan expansion.
- **Packaging**: established `packet_scheduler/VERSION` as the active monolithic OPQ rewrite release stamp and bumped the ordered-priority-queue catalog minor version from `26.0.0.0413` to `26.1.0.0413`.

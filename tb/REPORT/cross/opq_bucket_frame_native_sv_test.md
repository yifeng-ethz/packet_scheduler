# ✅ opq_bucket_frame_native_sv_test

**Kind:** `bucket_frame` &nbsp; **Build:** `after` &nbsp; **Sequence:** `run_promoted_default_build_matrix`

## Summary

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `39` |
| ℹ️ | effort | `high` |
| ℹ️ | txns | `738` |
| ✅ | functional_cross_pct | `76.72` |
| ✅ | counter_checks_failed | `0` |
| ✅ | unexpected_outputs | `0` |

## Execution Order

### bucket_frame

- bucket_order: `BASIC`, `EDGE`, `PROF`, `ERROR`, `CROSS`
- named_steps:
  `BASIC` -> `basic_seq` (basic smoke virtual sequence)
  `BASIC` -> `ts_seq` (timestamp boundary virtual sequence)
  `BASIC` -> `feb_seq` (FEB packet contract virtual sequence)
  `BASIC` -> `shd_seq` (subheader shape virtual sequence)
  `BASIC` -> `single_lane_seq` (single active lane 0 virtual sequence)
  `BASIC` -> `single_lane_lane1_seq` (single active lane 1 virtual sequence)
  `BASIC` -> `single_lane_dense_seq` (dense single-lane virtual sequence)
  `EDGE` -> `bp_seq_6_4_24` (periodic stall backpressure sweep high=6 low=4 repeat=24)
  `EDGE` -> `bp_seq_32_4_1` (always-ready backpressure sweep high=32 low=4 repeat=1)
  `EDGE` -> `bp_seq_32_8_12` (periodic stall backpressure sweep high=32 low=8 repeat=12)
  `EDGE` -> `bp_seq_4_12_24` (periodic stall backpressure sweep high=4 low=12 repeat=24)
  `EDGE` -> `bp_seq_1_2048_1` (always-stall backpressure sweep high=1 low=2048 repeat=1)
  `EDGE` -> `max_hits_seq` (max-hit virtual sequence)
  `EDGE` -> `bp_seq_1_1_24` (periodic stall backpressure sweep high=1 low=1 repeat=24)
  `EDGE` -> `bp_seq_1_1_96` (periodic stall backpressure sweep high=1 low=1 repeat=96)
  `EDGE` -> `max_hits_bp_seq` (max-hit virtual sequence under periodic stall)
  `PROF` -> `soak_seq` (baseline soak virtual sequence)
  `PROF` -> `stress_seq` (lane-skew stress virtual sequence)
  `PROF` -> `whole_frame_seq` (whole-frame skew virtual sequence)
  `PROF` -> `sparse_seq` (missing-empty-frame virtual sequence)
  `PROF` -> `long_soak_seq` (extended soak virtual sequence)
  `PROF` -> `heavy_skew_seq` (heavy lane-skew stress virtual sequence)
  `PROF` -> `deep_whole_frame_seq` (deep whole-frame skew virtual sequence)
  `PROF` -> `per_lane_half_frame_skew_seq` (4-lane per-lane skew sweep up to half-frame cadence)
  `PROF` -> `asym_sparse_seq` (asymmetric missing-empty-frame virtual sequence)
  `ERROR` -> `masked_drop_seq` (masked drop virtual sequence)
  `ERROR` -> `single_hit_masked_drop_seq` (single-hit masked drop virtual sequence)
  `ERROR` -> `burst_masked_drop_seq` (burst masked drop virtual sequence)
  `ERROR` -> `masked_recovery` (masked drop recovery virtual sequence)
  `ERROR` -> `hit_recovery_seq` (hit error recovery virtual sequence)
  `ERROR` -> `shd_recovery_seq` (subheader error recovery virtual sequence)
  `ERROR` -> `header_recovery_seq` (header error recovery virtual sequence)
  `ERROR` -> `header_word_recovery_seq` (header-word error recovery virtual sequence)
  `CROSS` -> `bp_credit_seq` (credit/backpressure cross sequence)
  `CROSS` -> `drr_allow_seq` (DRR allowance saturation sequence)
  `CROSS` -> `idle_lane_seq` (idle-lane DRR sequence)
  `CROSS` -> `zero_allow_seq` (zero-allowance DRR sequence)
  `CROSS` -> `drr_short_seq` (short-allowance DRR saturation sequence)
  `CROSS` -> `idle_lane_bp_case_seq` (idle-lane backpressure cross case)
- limitation: This native-SV frame baseline runs the promoted internal UVM sequence matrix from `opq_frame_signoff_tests.sv`, not the full canonical isolated case catalog.
- limitation: The isolated B/E/P/X case ledger remains the authoritative per-case closure view; this run is continuous-frame carry-over evidence.

## Code coverage

| metric | pct |
|---|---|
| stmt | 82.78 |
| branch | 80.82 |
| cond | 50.40 |
| expr | 78.67 |
| fsm_state | 100.00 |
| fsm_trans | 61.68 |
| toggle | 44.68 |

## Transaction growth curve

❓ no curve data available for this run.

## Checkpoint Ledgers

❓ no checkpoint ledger data recorded for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

# ❌ bucket_frame_native_sv

**Kind:** `bucket_frame` &nbsp; **Build:** `native_sv` &nbsp; **Bucket:** `-` &nbsp; **Sequence:** `OPQ_BUCKET_FRAME_NATIVE_SV`

## Summary

<!-- field legend:
  case_count              = number of plan cases composed into this run
  effort                  = practical (capped per case) or extensive (full planned stress)
  iter_cap, payload_cap   = practical-mode budget caps
  txns                    = total transactions driven through the DUT in this run
  functional_cross_pct    = functional coverage against DV_CROSS.md (percent)
  queued_overlap          = transactions enqueued before the previous drained
  counter_checks_failed   = scoreboard counter mismatches observed (0 is required for pass)
  unexpected_outputs      = outputs the scoreboard did not predict
-->

| status | field | value |
|:---:|---|---|
| ℹ️ | case_count | `24` |
| ℹ️ | effort | `practical` |
| ℹ️ | iter_cap | `None` |
| ℹ️ | payload_cap | `None` |
| ℹ️ | txns | `202` |
| ❌ | functional_cross_pct | `78.11` |
| ℹ️ | queued_overlap | `0` |
| ❌ | counter_checks_failed | `1` |
| ✅ | unexpected_outputs | `0` |

## Code coverage

<!-- merged code coverage produced by this single run (not ordered-merged into any bucket). -->

| metric | pct |
|---|---|
| stmt | 89.02 |
| branch | 80.12 |
| cond | 59.79 |
| expr | 81.82 |
| fsm_state | 91.43 |
| fsm_trans | 50.00 |
| toggle | 54.54 |

## Transaction growth curve

<!-- each row is one transaction step: which planned case fired, current functional-cross percent, -->
<!-- delta_bins = number of new cross bins hit at this step; reason = scoreboard checkpoint trigger. -->

❓ no curve data available for this run.

---
_Back to [dashboard](../../DV_REPORT.md)_

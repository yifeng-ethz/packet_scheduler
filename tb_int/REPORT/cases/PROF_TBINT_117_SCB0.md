# ✅ PROF_TBINT_117_SCB0

**Bucket:** `B7` &nbsp; **Method:** `R` &nbsp; **Build:** `longrun` &nbsp; **Effort:** `practical` &nbsp; **Result:** `pass`

## Intent

- **Scenario:** Short frame, cluster-domain family, burst emulator traffic, sparse load band. The emulator is the only pre-run programmed block; the FEB chain must stay lossless through stage D.
- **Primary checks:** No parser or contract errors at H0/B/C/D; lossless A->H0, H0->H1 for accepted hits, H1e->B, B->C, and C->D; deterministic replay for the fixed case seed. D->E is observational only in this matrix.
- **Contract anchor:** A->H0, H0->H1, H1e->B, B->C, C->D must close; D->E is telemetry only.

## Execution Evidence

<!-- fields (chief-architect legend)
  status                       = this case's overall health (legend: ✅ pass / ⚠️ partial / ❌ fail / ❓ pending)
  method                       = D = directed (1 txn); R = randomised (N txns)
  observed_txn                 = number of scoreboard-observed transactions driven by this case
  standalone_coverage          = code coverage measured from this case's own isolated UCDB
  isolated_cov_per_txn         = standalone_coverage averaged over observed_txn (useful for random cases)
  bucket_gain_by_case          = incremental code coverage this case added to the bucket's ordered merge
  bucket_merged_total_after    = the bucket's merged code coverage after this case was merged
  bucket_gain_per_txn          = bucket_gain_by_case averaged over observed_txn
-->

| status | field | value |
|:---:|---|---|
| ✅ | observed_txn | `80` |
| ℹ️ | implementation_mode | `tb_int_longrun_sanity_test + emulator CSR profile` |
| ℹ️ | log | [`uvm/logs/PROF_TBINT_117_SCB0_longrun_s1.log`](../../uvm/logs/PROF_TBINT_117_SCB0_longrun_s1.log) |
| ℹ️ | ucdb | [`uvm/cov_after/PROF_TBINT_117_SCB0_s1.ucdb`](../../uvm/cov_after/PROF_TBINT_117_SCB0_s1.ucdb) |
| ℹ️ | log.b_contract_err | `0` |
| ℹ️ | log.c_contract_err | `0` |
| ℹ️ | log.d_contract_err | `0` |
| ℹ️ | log.e_contract_err | `0` |
| ℹ️ | log.elapsed | `0:04:48` |
| ℹ️ | log.first_fail | `lane2:D->E` |
| ℹ️ | log.h0_contract_err | `0` |
| ℹ️ | log.largest_loss | `lane2:D->E` |
| ℹ️ | log.run_cycles | `8000` |
| ℹ️ | log.stage_a_hits | `80` |
| ℹ️ | log.stage_b_hits | `22` |
| ℹ️ | log.stage_c_hits | `22` |
| ℹ️ | log.stage_d_hits | `22` |
| ℹ️ | log.stage_e_hits | `19` |
| ℹ️ | log.stage_h0_hits | `80` |
| ℹ️ | log.stage_h1_hits | `80` |

## Coverage

<!-- code coverage vectors: stmt/branch/cond/expr/fsm_state/fsm_trans/toggle (percent) -->

| metric | standalone | isolated_per_txn | bucket_gain | bucket_merged_after | bucket_gain_per_txn |
|---|---|---|---|---|---|
| stmt | n/a | n/a | n/a | n/a | n/a |
| branch | n/a | n/a | n/a | n/a | n/a |
| cond | n/a | n/a | n/a | n/a | n/a |
| expr | n/a | n/a | n/a | n/a | n/a |
| fsm_state | n/a | n/a | n/a | n/a | n/a |
| fsm_trans | n/a | n/a | n/a | n/a | n/a |
| toggle | n/a | n/a | n/a | n/a | n/a |

## Transaction Growth (checkpoint UCDBs)

ℹ️ See [`../txn_growth/PROF_TBINT_117_SCB0.md`](../txn_growth/PROF_TBINT_117_SCB0.md) for the log-spaced coverage curve.

---
_Back to [bucket](../buckets/B7.md) &middot; [dashboard](../../DV_REPORT.md)_

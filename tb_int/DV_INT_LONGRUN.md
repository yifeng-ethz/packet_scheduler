# DV_INT Long-Run Workflow: FEB datapath sanity matrix

**Companion to:** `DV_INT_PLAN.md`, `DV_INT_HARNESS.md`  
**Scope:** `tb_int/` end-to-end FEB datapath sanity closure before OPQ debug  
**Date:** 2026-04-17  
**Target size:** 128 long runs, executed in 8 waves of 16 parallel jobs

**Implementation status:** implemented in `uvm/tb_int_pkg.sv` and `scripts/`; this document is the active matrix spec and execution log, not a future-tense bring-up plan.

---

## 0. Current execution status

- Harness support is implemented:
  - `tb_int_emut_cfg::describe_longrun()` in `uvm/tb_int_pkg.sv`
  - `tb_int_longrun_sanity_test` in `uvm/tb_int_pkg.sv`
  - wave launcher in `scripts/run_tb_int_longrun_wave.sh`
  - full-matrix launcher in `scripts/run_tb_int_longrun_matrix.sh`
- Execution artifacts live under `sim_runs/longrun/`.
- Latest refresh: `2026-04-17`, full `128/128` matrix complete with all eight wave summaries passing.
- Final execution set:
  - `wave_001`: `001-016` pass
  - `wave_017`: `017-032` pass
  - `wave_033`: `033-048` pass
  - `wave_049`: `049-064` pass after the cluster-domain source-lane silence fix
  - `wave_065`: `065-080` pass after the short-mode `A->H0` projection fix
  - `wave_081`: `081-096` pass
  - `wave_097`: `097-112` pass after the stochastic sparse-lane silence fix
  - `wave_113`: `113-128` pass
- Report closure:
  - `DV_REPORT.json`, `DV_REPORT.md`, `DV_COV.md`, and `REPORT/` are regenerated from the completed matrix evidence
  - `BUG_HISTORY.md` records the three harness bugs found during closure and their verified reruns

---

## 1. Goal

Use the live `tb_int/` chain

`emulator_mutrig -> frame_rcv_ip -> mts_processor -> ring_buffer_cam -> feb_frame_assembly -> swb_ingress_stub -> OPQ`

to run a **long-run sanity matrix** that:

- keeps the datapath timing-accurate end-to-end
- configures only the **emulator** by Avalon/MM at build / pre-run time
- exercises different hit-rate and occupancy shapes without reverting any IP boundary back to TLM
- proves the FEB datapath is clean enough to use FEB output as the debug reference for OPG / OPQ work

This plan is intentionally focused on **sanity and regression localization**, not full OPQ signoff.  
The main closure point is still the FEB-side chain through stage D.

---

## 2. Hard constraints

1. No run-time CSR retuning inside the active run window. Emulator CSR writes happen only after reset and before `RUN_PREPARE`.
2. All datapath traffic remains real RTL pin-wiggling. Monitors and SVA stay passive.
3. Each testcase must run in **1 s to 180 s wall-clock** after compile/elaboration reuse.
4. Regression execution uses **16 parallel runs** per wave.
5. One compile image is reused across the full matrix. Per-run variation comes from test config / plusargs / pre-run emulator CSR programming only.
6. Lossless signoff is judged at least through **stage D**. Stage E remains a separate OPQ closure problem.

---

## 3. Implemented harness support

The matrix support is implemented in-tree without changing datapath modeling.

1. `tb_int_emut_cfg` exists in `uvm/tb_int_pkg.sv` and carries one static pre-run profile per emulated lane.
2. `tb_int` already contains the build/pre-run Avalon/MM programming path for `emulator_mutrig` only.
3. `frame_rcv_ip`, `mts_processor`, `ring_buffer_cam`, and `feb_frame_assembly` remain on default CSR unless a later debug case proves otherwise.
4. `tb_int_longrun_sanity_test`:
   - loads one matrix profile by `+TB_INT_LONGRUN_CASE_ID=<1..128>`
   - programs emulator CSR after reset
   - runs the normal run-control sequence
   - logs the selected profile through `cfg.describe_longrun()`
5. Launchers under `tb_int/scripts/` now support both scopes:
   - `run_tb_int_longrun_wave.sh` for one 16-case wave
   - `run_tb_int_longrun_matrix.sh` for the full 128-case matrix with one compile image reused across all waves

No `.ipx` work and no Qsys regeneration are required for this workflow.

---

## 4. What gets programmed in the emulator

The long-run matrix uses only real emulator CSR knobs already present in tree:

- `CSR0 CONTROL`
  - `enable`
  - `hit_mode`
  - `short_mode`
- `CSR1 HIT_RATE`
  - `hit_rate`
  - `noise_rate`
- `CSR2 BURST_CFG`
  - `burst_size`
  - `burst_center_local`
  - `cluster_cross_asic`
  - `cluster_center_global`
  - `cluster_lane_index`
  - `cluster_lane_count`
- `CSR3 PRNG_SEED`
- `CSR4 TX_MODE`
  - `tx_mode`
  - `gen_idle`
  - `asic_id`

Long-run cases must use these as **static pre-run profile controls**.  
"Variable hit rate" in this plan means:

- different static rates across FEBs / datapaths / ASICs in one run
- frame-to-frame occupancy variation from Poisson / burst / mixed generation under a fixed profile
- optional cross-ASIC cluster slicing from `BURST_CFG`

It does **not** mean run-time CSR rewrites while the run is active.

---

## 5. 128-case matrix

The matrix is:

- **2 frame modes**
- **4 spatial profile families**
- **4 traffic patterns**
- **4 load bands**

Total: `2 x 4 x 4 x 4 = 128`

### 5.1 Frame modes

| Code | Meaning |
|------|---------|
| `L` | long frame mode |
| `S` | short frame mode |

### 5.2 Spatial profile families

| Code | Family | Intent |
|------|--------|--------|
| `U` | uniform | all datapaths / ASICs use the same configured rate profile |
| `F` | FEB-skew | FEB0 and FEB1 use different rate bands; catches board-side imbalance and lane starvation interactions |
| `H` | hotspot | one MuTRiG per datapath is hot, the other local instances are cool; catches per-link packing and scheduler unfairness |
| `C` | cluster-domain | neighbouring emulators share one cross-ASIC cluster domain; catches cluster slicing and correlated occupancy corners |

### 5.3 Traffic patterns

| Code | Emulator setting | Intent |
|------|------------------|--------|
| `P` | `hit_mode = POISSON` | baseline random occupancy |
| `B` | `hit_mode = BURST` | local or cross-ASIC clusters with deterministic centre bias |
| `N` | `hit_mode = NOISE` | dark-count-like random hits |
| `M` | `hit_mode = MIXED` | realistic mixed traffic with background plus clusters |

### 5.4 Load bands

These are **starting bands**. The current implemented default run-length ladder in `tb_int_longrun_sanity_test` is:

- `band0 -> 8000` run cycles
- `band1 -> 12000` run cycles
- `band2 -> 20000` run cycles
- `band3 -> 32000` run cycles

These values were chosen to keep the cached mixed-language `tb_int` runs inside the requested wall-clock envelope while still giving meaningful frame accumulation.

| Code | Relative load | Intended regime |
|------|---------------|-----------------|
| `0` | sparse | low occupancy, easy drain, baseline contract stability |
| `1` | nominal | representative stable-running occupancy |
| `2` | hot-safe | high but still expected lossless through FEB output |
| `3` | edge-safe | highest signoff load still expected lossless through FEB output |

If a profile is later found to exceed the FEB lossless envelope, it must be moved out of this 128-case matrix and into a separate controlled-overflow stress bucket rather than silently weakening the pass criteria.

---

## 6. Bucket layout

Each bucket has 16 cases: `4 traffic patterns x 4 load bands`.

| Bucket | Frame | Family | Cases |
|--------|-------|--------|-------|
| `B0` | `L` | `U` | `L/U/{P,B,N,M}/{0,1,2,3}` |
| `B1` | `L` | `F` | `L/F/{P,B,N,M}/{0,1,2,3}` |
| `B2` | `L` | `H` | `L/H/{P,B,N,M}/{0,1,2,3}` |
| `B3` | `L` | `C` | `L/C/{P,B,N,M}/{0,1,2,3}` |
| `B4` | `S` | `U` | `S/U/{P,B,N,M}/{0,1,2,3}` |
| `B5` | `S` | `F` | `S/F/{P,B,N,M}/{0,1,2,3}` |
| `B6` | `S` | `H` | `S/H/{P,B,N,M}/{0,1,2,3}` |
| `B7` | `S` | `C` | `S/C/{P,B,N,M}/{0,1,2,3}` |

### Naming rule

Use:

`PROF_TBINT_<id>_<frame><family><traffic><load>`

Examples:

- `PROF_TBINT_001_LUP0`
- `PROF_TBINT_016_LUM3`
- `PROF_TBINT_057_SHP0`
- `PROF_TBINT_128_SCM3`

The numeric ID is just the ordered matrix index. The compact suffix is the real profile key.

---

## 7. Per-family profile rules

### `U` Uniform

- same `hit_rate`, `noise_rate`, and `burst_size` on every emulator instance
- unique seeds per instance, but from one deterministic case seed root
- `cluster_cross_asic = 0`

### `F` FEB-skew

- FEB0 and FEB1 use different rate bands derived from the same case load
- keep within the lossless envelope at both ends
- use this family to expose idle-lane vs busy-lane arbitration issues

Suggested shape:

- FEB0 = one band lower than case load
- FEB1 = exact case load

### `H` Hotspot

- one ASIC per datapath uses the exact case load
- the other local ASICs use one or two lower bands
- hotspot ASIC rotates with case ID to cover lane placement

This family is intended to stress:

- burst packing concentration
- rb-cam slot imbalance
- feb frame assembly subheader packing under non-uniform arrival

### `C` Cluster-domain

- `cluster_cross_asic = 1`
- adjacent emulator lanes share the same cluster-domain seed root
- `cluster_lane_index` and `cluster_lane_count` are set per instance
- local burst centres are replaced by one `cluster_center_global`

This family is the main long-run check for:

- 8-lane shared cluster replay semantics
- cross-ASIC cluster slicing
- FEB correlation handling when neighbouring lanes become busy together

For `P` and `N` cases the cluster-domain controls may be inert; keep them programmed anyway so the same bucket wiring is used for all 16 cases.

---

## 8. Load-band calibration rule

The matrix should not hardcode final rates before one quick calibration sweep.

### Calibration step

Run one short calibration per frame mode:

- long mode: sweep `hit_rate` / `noise_rate` upward until the first repeated FEB-side non-lossless behavior appears
- short mode: repeat the same

Then lock:

- `band0` = comfortably below nominal
- `band1` = representative nominal
- `band2` = high but still lossless
- `band3` = just below the first persistent FEB-side loss point

The calibration itself is **not** part of the 128-case signoff set.

---

## 9. Run-time targets

Each testcase must land in this wall-clock window after compile reuse:

- minimum: `1 s`
- maximum: `180 s`

Recommended targets:

- `band0`: 5 s to 15 s
- `band1`: 10 s to 30 s
- `band2`: 20 s to 60 s
- `band3`: 60 s to 180 s

Use `TB_INT_PREPARE_CYCLES`, `TB_INT_END_CYCLES`, and the long-run-specific `TB_INT_LONGRUN_RUN_CYCLES` override to tune duration.  
Leave `TB_INT_RUN_CYCLES` for the non-matrix smoke/basic flows. Do not retune child-IP behavior to hit runtime; only tune run length and emulator load.

---

## 10. Parallel execution plan

Execute in **8 waves**, **16 cases per wave**.

Recommended scheduling:

- wave 0: `B0`
- wave 1: `B1`
- wave 2: `B2`
- wave 3: `B3`
- wave 4: `B4`
- wave 5: `B5`
- wave 6: `B6`
- wave 7: `B7`

Execution commands:

```bash
# one bucket / wave
bash scripts/run_tb_int_longrun_wave.sh 1 16

# full 128-case matrix
bash scripts/run_tb_int_longrun_matrix.sh
```

Rules:

1. Compile once for the full matrix.
2. Launch 16 `vsim` jobs against the same compile image.
3. Each job writes its own:
   - transcript
   - wave membership and status via the wave summary
   - optional wave/debug dump on failure only
4. Preserve case ordering inside each bucket so coverage deltas remain auditable later.

---

## 11. Pass criteria

### 11.1 Required for all 128 sanity cases

- no parser / contract errors at H0, B, C, D
- no ghost hits at H0, H1e, B, C, D
- synchronized run-control behavior across all datapaths
- no unexpected activity outside the allowed run window
- deterministic replay for a fixed case seed

### 11.2 Required for FEB sanity closure

For all 128 cases in this matrix:

- `A -> H0` lossless after the known emulator / parser contract is applied
- `H0 -> H1` lossless for accepted non-filtered hits
- `H1e -> B` lossless
- `B -> C` lossless
- `C -> D` lossless

If any case violates that, it is either:

- a real FEB-side datapath bug
- a wrong lossless load-band calibration
- a scoreboard / monitor contract bug

It must not be dismissed as "too long" or "too busy" inside this matrix.

### 11.3 Optional observation only

- `D -> E`

Stage E remains useful telemetry, but it is not the blocking criterion for this long-run FEB sanity plan until OPQ-side closure is resumed.

---

## 12. Evidence per testcase

Each case should emit one compact summary row containing at least:

- case ID and case seed
- frame mode / family / traffic / load code
- wall-clock runtime
- simulator run cycles
- per-stage totals: `A, H0, H1, H1e, B, C, D, E`
- per-boundary counts: `missing`, `ghost`, `contract_err`
- run-control timing summary
- first failing boundary, if any

If a case fails, also dump:

- first unmatched observations
- first contract violation
- selected internal drain/debug counters already present in `tb_int_top.sv`

---

## 13. Execution order

The implemented bring-up order remains the recommended execution/debug order:

1. `B0`: simplest long-frame / uniform profiles
2. `B4`: short-frame / uniform profiles
3. `B1/B5` and `B2/B6`: skewed and hotspot families
4. `B3/B7`: cluster-domain families last, because they are the most correlated and least forgiving

This keeps first-pass debug on the most interpretable long runs while preserving the final 128-case matrix order.

---

## 14. Explicit non-goals for this plan

- no run-time CSR modulation during active running
- no conversion of FEB boundaries back to transactions
- no OPQ performance signoff
- no deliberate overflow / drop-allowed matrix in the initial 128 cases

If controlled-overflow stress is wanted later, create a separate `DV_INT_STRESS_PLAN.md`.

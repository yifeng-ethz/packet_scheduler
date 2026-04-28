# DV_CROSS.md — ordered_priority_queue

**Companion to:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Canonical Run Range:** `CROSS-001-CROSS-129`
**Intent:** long-run cross-signoff regression that composes the direct catalog (B/E/P/X) into continuous-frame runs, promotes anchored direct patterns to seed-swept randomized soaks, and drives merged functional + code coverage on the monolithic `ordered_priority_queue_dut_sv` to closure. Preserves every `opq_cross_*_test` class currently living in `uvm/tests/` and pins each to a specific §6 row.

## 1) Purpose And Long-Run Philosophy

The direct catalog (`B001-B129`, `E001-E129`, `P001-P129`, `X001-X129`) proves each RTL contract on a clean DUT. Cross runs prove the contracts compose and survive time and noise on the packet_scheduler monolith. They exist to:

- exercise every direct case in a continuous frame without reset-per-case, so any case-boundary cleanup gap on the ticket FIFO, handle FIFO, lane FIFO, or basic presenter meta table is visible
- promote curated direct patterns (backpressure × credit, DRR × idle lane, bursty DRR, random-ready overflow, mixed-bucket random soak) to randomized seed-swept soaks so the same invariants are re-hit many cycles apart with different arrival phases
- hit the FSM / counter / arbitration corners that the direct cases only graze, until merged code coverage clears the targets in [DV_COV.md](DV_COV.md)
- seed explicit traps for every bug recorded in [BUG_HISTORY.md](BUG_HISTORY.md) so a regression cannot reintroduce the same class of defect silently

## 2) Direct → Random Promotion Ladder

Every cross run is one of five ladders. The ladder name is the first token in the scenario column of the catalog table in §6.

| ladder | how the stimulus is produced | what it proves beyond direct cases | typical txns per run |
|---|---|---|---|
| `bucket_frame` | direct cases in their declared order, no DUT restart | case boundaries leave no carry-over in ticket FIFO, page allocator, or scoreboard state | 10-50k |
| `all_buckets_frame` | BASIC → EDGE → PROF → ERROR in order, no restart | full-stack composition; LANE_MASK / soft-reset / error-recovery lifecycle handled once per bucket transition only | 50-200k |
| `anchored_hybrid` | one or more direct cases pinned with randomized inter-case gap, randomized DRR allowance, randomized LANE_MASK toggling | the anchor's invariants hold when surrounding traffic is random | 20-100k |
| `seed_sweep` | one random case (typically P0xx or a promoted opq_cross_* case) replayed with N orthogonal LCG seeds | per-case coverage bins union across seeds; seed axis is part of closure | 100k-1M per seed |
| `checkpoint_soak` | pure randomized traffic over 1M+ txn with log-spaced UCDB checkpoints | coverage growth curve; catches bins that only saturate deep into a run; exposes counter-truncation and long-horizon retirement regressions | 1M-10M |

Every `anchored_hybrid` and above saves one isolated UCDB plus a checkpoint UCDB per log-spaced milestone under [REPORT/txn_growth/](REPORT/txn_growth/). `bucket_frame` and `all_buckets_frame` save one merged UCDB under [REPORT/cross/](REPORT/cross/).

## 3) Randomization Axes

The composer draws from these axes. The axis table is the contract with the seed file; a cross run's metadata line must name every axis it varies.

| axis | values | notes |
|---|---|---|
| `seed` | 32-bit LCG seed | drives all other axes for the run; recorded in every case evidence page |
| `n_lane_build` | `default_p2_s256_t256_r65536`, `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=4096`, reduced-depth `2-lane/256/512`, reduced-depth `4-lane/128/512` | one row per non-default build; explicit elaboration metadata |
| `drr_allowance_profile` | default (256), zero-allowance, short-quantum, max-quantum (0x3FF), bursty DRR, mid-run reprogram | composes with every lane-skew shape |
| `lane_mask_profile` | all-clear, mask-lane-0, mask-lane-1, all-masked, mid-run toggle, recovery | lifts / drops at packet and frame boundaries |
| `ingress_gap_shape` | back-to-back, Poisson λ∈{0.3, 0.5, 0.7, 0.9}, burst (len∈[16,256], gap∈[0,256]), stuck-high | `λ≥0.9` probes legal overwrite on the presenter |
| `egress_ready_profile` | 100%, Bernoulli p∈{0.3, 0.5, 0.7, 0.9}, 1-cycle toggle, 2-cycle threshold hold, `EGRESS_DELAY=3` / `EGRESS_DELAY+1=4` boundary, 16/256/1024-cycle stall | exercises the skid buffer and `resident_backpressure_hold` |
| `ingress_error_injection` | none, `hit_err` 1%, `shd_err` 1%, `hdr_err` 1%, mixed 1%, burst 10% | typed per the X011-X037 location rules |
| `run_ctrl_injection` | none, soft-reset every 4k, LANE_MASK toggle every 2k, DRR reprogram every 1k, combined | composes with any `ingress_gap_shape` |
| `subheader_shape` | default (256 subheaders × mixed hits), max-subheader (`OPQ_N_SHD=256`), single-subheader, zero-hit-only, max-hit (`N_HIT=255`) | drives `cg_subheader.*` bins |
| `pkg_cnt` / `send_ts` / `dt_type` | fixed, monotonic sweep, random | drives ticket-field toggle coverage |

## 4) Closure Targets

Merged across all cross runs (union of per-run UCDBs), the closure bar is:

| metric | target | merge scope |
|---|---|---|
| stmt | `≥95%` | all CROSS merged with all isolated B/E/P/X runs |
| branch | `≥90%` | same |
| fsm_state | `≥95%` | per-FSM: `ingress_parser`, `block_mover`, `b2p_arbiter`, `basic_presenter`, `frame_table_tracker` (legacy tile) |
| fsm_trans | `≥90%` | same |
| toggle | `≥80%` | all RTL nets; key toggles are ticket fields, page-RAM address, `lane_credit_visible`, counter high bits |
| functional | `≥100%` bins saturated for: `cg_frame`, `cg_subheader.shd_ts` (wrap + no-wrap), `cg_subheader.hit_cnt` (low/mid/high/max), `cg_fifo_depth` (lane/ticket/handle near-full), `cg_bp` (always-ready, medium, stuck-low, toggle-short, toggle-long, burst-restart, max-hits-bp), `cg_drr` (onehot, defer, preempt-miss, zero/short/max allowance, reload), `cg_csr` (all 9-bit word-addressed offsets RD + RW), `cg_lane_mask` (masked-lane silent, unmask recovery), `cg_ft_drop` (hdr/shd/hit per-axis) | all CROSS merged |

Bins known to saturate slow (from DV_PROF §P017-P025 estimates): per-lane `drr_beat_cnt` deep-bin > 64k beats; whole-frame skew cadence × ingress-gap cross > 256k txn; counter high-bit toggles > 10M txn.

## 5) Bug-Spotting Plays (Why Each Family Is In The Plan)

Each cross family has at least one run whose direct purpose is to re-trip a previously-found bug if it regresses. Anchor cases are named so the composer can re-seed the trap even if the bug moves location.

| bug class | pattern the play reproduces | cross runs that anchor it |
|---|---|---|
| overwrite-pressure tail drop | sustained backpressure with legal ingress pre-drop, then late-frame overwrite at the presenter boundary | CROSS-033, CROSS-076, CROSS-081, CROSS-082 |
| random-ready two-step legal overflow | default-build random-ready shape check with heavy pre-drop pressure but legal accounting | CROSS-034, CROSS-084, CROSS-089 |
| overwrite-local must-drop witness | reduced-depth `2-lane/256/512 OPQ_PAGE_RAM_DEPTH=512` overwrite profile forcing `ft_drop_*` progress | CROSS-035, CROSS-078, CROSS-088 |
| DRR active-lane bursty retirement (`BUG-025-R`) | deterministic bursty DRR profile with frame_count=2 / frame_count=3 boundary anchors | CROSS-036, CROSS-037, CROSS-094 |
| hit3 contract (`opq_hit3_contract_sva`) mislocation | promoted direct hit3 lead-in and exact-sample-window repros with random surrounding traffic | CROSS-038, CROSS-111, CROSS-112 |
| masked-drop exact-sample-window | promoted direct `masked_drop_exact_102_117` profile reproduced under random surrounding traffic | CROSS-039, CROSS-113 |
| single-hit-masked-then-sparse regression | promoted direct `single_hit_masked_then_sparse` profile reproduced under random surrounding traffic | CROSS-040, CROSS-114 |
| sparse-single-lane DRR credit-restore | sparse-traffic single-lane run whose DRR credit must restore cleanly on idle intervals | CROSS-041, CROSS-115 |
| lane-FIFO integrity / block-mover abort (`BUG-018` historical) | forced integrity fault mid-body → `BLOCK_MOVER_WRITE_BLK → ABORT_WRITE_BLK → RESET` with `TICKET_ALT_EOP_LOC` | CROSS-042, CROSS-107 |
| DRR onehot / preempt-miss invariant | sustained multi-lane DRR with concurrent grant opportunities on both lanes | CROSS-043, CROSS-095 |
| ingress-error typed location contract | mixed `hit_err/shd_err/hdr_err` injection under random surrounding traffic | CROSS-044, CROSS-108 |
| 48-bit counter truncation through `FT_*` CSRs | sustained run until `wr_hdr/shd/hit` each cross 2^31; `STATUS` and `lane_credit_visible` must stay correct | CROSS-045, CROSS-121, CROSS-125 |

## 6) Canonical Cross Catalog

### 6.1 Bucket and all-bucket baselines (CROSS-001-006)

These are the reset-per-case-free direct regressions. Any case-boundary cleanup gap on the ticket FIFO / handle FIFO / page allocator / presenter meta table is caught here first.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-001 | `bucket_frame` | `B001-B129` in order, one DUT start | case-boundary cleanup for all BASIC CSR and ingress/egress invariants |
| CROSS-002 | `bucket_frame` | `E001-E129` in order | E010-E021 FIFO near-full composition; E022-E027 subheader/hit extrema chain; E073-E080 arbiter + block-mover corners |
| CROSS-003 | `bucket_frame` | `P001-P129` in order | all promoted random profile cases composed without restart |
| CROSS-004 | `bucket_frame` | `X001-X129` in order | typed ingress error, LANE_MASK lifecycle, reduced-depth overflow, and recovery composed in one run |
| CROSS-005 | `all_buckets_frame` | `BASIC → EDGE → PROF → ERROR` in order | full stack; bucket transitions handled by exactly one soft-reset each |
| CROSS-006 | `all_buckets_frame` | `BASIC → EDGE → PROF → ERROR` with B007, B127, E005, E022 repeated mid-frame | repeated single-lane-dense, zero-hit, and max-hit IDs stress the basic presenter meta table across bucket boundaries |

### 6.2 Promoted DRR / backpressure cases (CROSS-007-010)

Pins the live `opq_cross_*_test` classes that already ship as directed promoted cases. Each row preserves the test name in the scenario text so the composer and report generator keep the legacy alias.

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-007 | `anchored_hybrid` | `opq_cross_bp_credit_test` | backpressure × credit restoration on the healthy path, with randomized inter-window idle gap | `lane_credit_visible` returns to `LANE_FIFO_MAX_CREDIT=1022` between frames; catches credit freeze under bp |
| CROSS-008 | `anchored_hybrid` | `opq_cross_drr_allowance_test` | runtime per-lane DRR allowance programming with defer counters and service counts, with random idle-gap framing | `drr_allowance / drr_quantum / drr_grant_cnt / drr_beat_cnt / drr_defer_cnt` all track ground truth |
| CROSS-009 | `anchored_hybrid` | `opq_cross_drr_idle_lane_test` | DRR with one hit-idle peer lane that still emits empty frames | idle-lane cadence preserved; onehot DRR grant invariant holds |
| CROSS-010 | `anchored_hybrid` | `opq_cross_drr_zero_allowance_test` + `opq_cross_drr_short_allowance_test` | zero-allowance lane defers until reload then resumes service; short-quantum lane repeatedly reloads | defer counter advances by forced defers; reload path exercised; no stuck lane |

### 6.3 Arbitration and idle-lane backpressure anchors (CROSS-011-014)

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-011 | `anchored_hybrid` | `opq_cross_idle_lane_backpressure_test` | idle-lane cadence crossed with periodic egress stalls on the active lane | skid buffer + `resident_backpressure_hold` exercised while idle lane still emits empty frames |
| CROSS-012 | `anchored_hybrid` | `opq_cross_drr_bursty_frame2_boundary_test` | deterministic bursty DRR frame_count=2 boundary | refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=4096` rerun closes with `expected=484 actual=484 missing=0 ghost=0`; guards frame2-boundary regression |
| CROSS-013 | `anchored_hybrid` | `opq_cross_drr_bursty_frame3_repro_test` | reduced deterministic bursty DRR retirement anchor for `BUG-025-R` | `expected=714 actual=714 missing=0 ghost=0`; shortest historical closure check for the former active-lane retirement bug |
| CROSS-014 | `anchored_hybrid` | `opq_cross_drr_bursty_random_test` | constrained-random hot-lane / cold-lane DRR stress with periodic egress stalls | refreshed seed=1 `expected=990 actual=990 missing=0 ghost=0`; seeds 2..8 `expected=1864 actual=1864 missing=0 ghost=0`; per-lane `unexplained=0` |

### 6.4 Overwrite-pressure and overflow boundary anchors (CROSS-015-016)

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-015 | `anchored_hybrid` | `opq_cross_bp_predrop_boundary_test` | directed default-build backpressure boundary proof in the legal ingress pre-drop regime (`ft_drop_* = 0`) | hit and frame-table ledgers still close; catches overwrite-pressure tail drop regression in the legal pre-drop window |
| CROSS-016 | `anchored_hybrid` | `opq_cross_random_ready_overflow_step2_boundary_test` | named default-build two-step legal-overflow boundary in random-ready shape-check mode | final `wr_hdr/shd/hit=7/19/1607`, `rd_hdr/shd/hit=7/19/1607`, `ft_drop_hdr/shd/hit=0/0/0`, `accepted=1607 delivered=1607 unexplained=0`, `core_principles first_break=clean` |

### 6.5 Seed-swept random promotions (CROSS-017-030)

Each row replays one promoted random case (or P-bucket shape) with an orthogonal LCG seed. Seeds `0x0001..0x000E` align with the DV_PROF §P009-P020 seed reservations so merged UCDBs union correctly.

| case_id | ladder | anchor case | seed | scenario | bug / coverage target |
|---|---|---|---|---|---|
| CROSS-017 | `seed_sweep` | P001 `opq_prof_stress_test` | `0x0001` | short soak with repeated long frames, 200k txn equivalent | per-lane ledger closes; stmt / branch ≥90% on the healthy path |
| CROSS-018 | `seed_sweep` | P001 | `0x0002` | orthogonal seed | seed-axis contribution to toggle coverage |
| CROSS-019 | `seed_sweep` | P002 `opq_prof_lane_skew_test` | `0x0003` | sustained two-lane skew, 200k txn | `cg_frame.pre_gap` bins saturate under seed variation |
| CROSS-020 | `seed_sweep` | P002 | `0x0004` | orthogonal seed | multi-lane skew cross-seed UCDB merge |
| CROSS-021 | `seed_sweep` | P003 `opq_prof_whole_frame_skew_test` | `0x0005` | whole-frame skew cadence, 200k txn | alternating active / empty frame bin coverage |
| CROSS-022 | `seed_sweep` | P003 | `0x0006` | orthogonal seed | whole-frame cadence cross-seed merge |
| CROSS-023 | `seed_sweep` | P004 `opq_prof_missing_empty_frame_test` | `0x0007` | uneven per-lane frame-count stress, 200k txn | asymmetric `FT_WR_HDR` evidence |
| CROSS-024 | `seed_sweep` | P005 `opq_prof_long_soak_test` | `0x0008` | longer directed FEB whole-frame soak, 500k txn | deep-soak bin saturation |
| CROSS-025 | `seed_sweep` | P006 `opq_prof_heavy_lane_skew_test` | `0x0009` | deeper skew-gap envelope, 500k txn | heavy skew-gap bin coverage |
| CROSS-026 | `seed_sweep` | P007 `opq_prof_deep_whole_frame_skew_test` | `0x000A` | deeper residency + reduced subheader density, 500k txn | presenter meta table wrap evidence under deep whole-frame skew |
| CROSS-027 | `seed_sweep` | P008 `opq_prof_asymmetric_missing_empty_frame_test` | `0x000B` | explicit 2-lane asymmetric frame counts, 500k txn | cross-lane interleave bin saturation |
| CROSS-028 | `seed_sweep` | P018 long soak with 4k frames per lane | `0x000C` | extended soak with mixed subheader density | zero-defer invariant on the healthy path |
| CROSS-029 | `seed_sweep` | P021 sustained throughput | `0x000D` | 2-lane back-to-back zero-gap, 500k txn | arbiter continuous-grant coverage |
| CROSS-030 | `seed_sweep` | P044 burst ingress 32-beat | `0x000E` | burst ingress shape, 500k txn | burst-induced lane FIFO near-full bin |

### 6.6 Bug-seeded long soaks (CROSS-031-045)

Each row traps one bug family from §5. Surrounding traffic is randomized so the trap is hit many times per run, not just once.

| case_id | ladder | bug anchor | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-031 | `anchored_hybrid` | overwrite-pressure tail | `opq_cross_bp_predrop_boundary_test` shape + random idle gap, 500k txn | legal pre-drop window sustained; no `ft_drop_*` leak |
| CROSS-032 | `anchored_hybrid` | overwrite-pressure tail | `opq_cross_bp_credit_test` repeated every 10k cyc, 500k txn | credit restoration invariant; catches credit freeze under bp |
| CROSS-033 | `anchored_hybrid` | overwrite-pressure tail | sustained backpressure with mid-run LANE_MASK toggle, 500k txn | backpressure × mask interaction; catches drop attribution regression |
| CROSS-034 | `anchored_hybrid` | random-ready overflow | `opq_cross_random_ready_overflow_step2_boundary_test` repeated every 20k cyc, 500k txn | two-step legal overflow repeated; catches step transition regression |
| CROSS-035 | `anchored_hybrid` | overwrite-local must-drop | `opq_cross_bp_mustdrop_witness_test` on reduced-depth `2-lane/256/512 OPQ_PAGE_RAM_DEPTH=512` + random inter-burst gap, 500k txn | no-drop pre-phase keeps `ft_drop_delta hdr/shd/hit=0/0/0`; pressure phase advances `ft_drop_delta hdr/shd/hit=10/80/2400`; final ledger closes |
| CROSS-036 | `anchored_hybrid` | bursty DRR retirement | `opq_cross_drr_bursty_frame2_boundary_test` shape + random surrounding traffic, 500k txn | frame2-boundary retirement invariant at scale |
| CROSS-037 | `anchored_hybrid` | bursty DRR retirement | `opq_cross_drr_bursty_frame3_repro_test` shape + random surrounding traffic, 500k txn | frame3-boundary retirement invariant at scale; `BUG-025-R` guard |
| CROSS-038 | `anchored_hybrid` | hit3 contract | `opq_cross_hit3_lead_in_repro_test` shape + random surrounding traffic, 500k txn | hit3 lead-in reproducible regression trap |
| CROSS-039 | `anchored_hybrid` | masked-drop exact-window | `opq_cross_masked_drop_exact_102_117_repro_test` shape + random surrounding traffic, 500k txn | masked-drop exact-sample-window invariant |
| CROSS-040 | `anchored_hybrid` | single-hit-masked-then-sparse | `opq_cross_single_hit_masked_then_sparse_repro_test` shape + random surrounding traffic, 500k txn | single-hit masked then sparse ingress recovery invariant |
| CROSS-041 | `anchored_hybrid` | sparse DRR credit restore | `opq_cross_sparse_single_lane_drr_credit_restore_repro_test` shape + random idle gap, 500k txn | DRR credit restoration after sparse single-lane traffic |
| CROSS-042 | `anchored_hybrid` | block-mover abort | forced lane-FIFO integrity fault mid-body, random inter-frame, 500k txn | `ABORT_WRITE_BLK → RESET` reliably taken; `TICKET_ALT_EOP_LOC` set |
| CROSS-043 | `anchored_hybrid` | DRR onehot / preempt-miss | `opq_cross_drr_bursty_random_test` + random mid-run reprogram, 500k txn | onehot grant and no-preempt invariants hold on every frame |
| CROSS-044 | `anchored_hybrid` | ingress-error typed contract | random `hit_err/shd_err/hdr_err` injection at 1% on each, 500k txn | per-axis `drop_*` counters match injection shape |
| CROSS-045 | `checkpoint_soak` | counter truncation | sustained pool=2 at λ=0.9 for 10M txn to cross 2^31 in `FT_WR_HDR/SHD/HIT` | CSR counter monotonicity across the crossing; `STATUS` and `lane_credit_visible` still correct |

### 6.7 Build-variant soaks (CROSS-046-060)

One run per supported `OPQ_N_LANE × OPQ_N_SHD × OPQ_TICKET_FIFO_DEPTH × OPQ_PAGE_RAM_DEPTH` point.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-046 | `seed_sweep` | default `default_p2_s256_t256_r65536` build, `opq_cross_drr_allowance_test` shape, 200k txn | default build DRR coverage |
| CROSS-047 | `seed_sweep` | `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=4096` build, `opq_cross_drr_allowance_test` shape, 200k txn | 4-lane DRR fairness at this preset |
| CROSS-048 | `seed_sweep` | `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=4096`, `opq_cross_mixed_bucket_random_soak_test` shape | refreshed rerun closes `expected=14547 actual=14547 missing=0 ghost=0`; per-lane `unexplained=0` |
| CROSS-049 | `seed_sweep` | reduced-depth `2-lane/256/512 OPQ_PAGE_RAM_DEPTH=512` build, must-drop shape | `opq_cross_bp_mustdrop_witness_test` closure shape |
| CROSS-050 | `seed_sweep` | reduced-depth `4-lane/128/512 OPQ_PAGE_RAM_DEPTH=512` build, must-drop shape | preset-limited shape-check evidence |
| CROSS-051 | `seed_sweep` | default build, high-rate back-to-back traffic, 500k txn | default throughput ceiling |
| CROSS-052 | `seed_sweep` | `OPQ_N_LANE=4` build, lane-skew cadence, 500k txn | 4-lane whole-frame skew coverage |
| CROSS-053 | `seed_sweep` | `OPQ_N_LANE=4` build, missing-empty-frame shape, 500k txn | 4-lane asymmetric frame coverage |
| CROSS-054 | `seed_sweep` | default build, `+TB_CLK_PERIOD_NS=500`, 200k txn | slow-clock variant evidence |
| CROSS-055 | `seed_sweep` | default build, `+TB_CLK_PERIOD_NS=2000`, 200k txn | very slow-clock variant |
| CROSS-056 | `seed_sweep` | default build, `+OPQ_MIXED_SOAK_STEPS=32`, long chain | extended mixed-bucket soak evidence |
| CROSS-057 | `seed_sweep` | default build, `+OPQ_MIXED_SOAK_STEPS=64`, deeper chain | deeper mixed-bucket soak |
| CROSS-058 | `seed_sweep` | default build, `+DV_LONG_TXN_OVERRIDE=2`, reduced nightly | nightly regression mode |
| CROSS-059 | `seed_sweep` | default build, max-subheader `OPQ_N_SHD=256` frame-dominated traffic | `cg_subheader` max-width bin saturation |
| CROSS-060 | `seed_sweep` | default build, max-hit `N_HIT=255` subheader-dominated traffic, 500k txn | `cg_subheader.hit_cnt` max bin saturation |

### 6.8 Ingress-error / lane-mask injection soaks (CROSS-061-075)

Every run here includes typed `hit_err/shd_err/hdr_err` injection and / or LANE_MASK reprogramming. The error path and mask path must leave the DUT recoverable.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-061 | `seed_sweep` | X001 `opq_error_lane_mask_test` with random LANE_MASK toggles every 4k cyc, 200k txn | packet-boundary mask invariant at scale |
| CROSS-062 | `seed_sweep` | X002 `opq_error_lane_mask_single_hit_test` + random surrounding traffic, 200k txn | one-hit masked drop invariant |
| CROSS-063 | `seed_sweep` | X003 `opq_error_lane_mask_burst_test` + random surrounding traffic, 200k txn | burst masked drop invariant |
| CROSS-064 | `seed_sweep` | X004 `opq_error_lane_mask_recovery_test` + random inter-frame gap, 500k txn | post-unmask recovery across many gaps |
| CROSS-065 | `seed_sweep` | X005 `opq_error_hit_mask_recovery_test` + random surrounding traffic, 500k txn | `hit_err` typed contract at scale |
| CROSS-066 | `seed_sweep` | X006 `opq_error_subheader_mask_recovery_test` + random surrounding traffic, 500k txn | `shd_err` typed contract at scale |
| CROSS-067 | `seed_sweep` | X007 `opq_error_header_mask_recovery_test` + random surrounding traffic, 500k txn | `hdr_err` typed contract at scale |
| CROSS-068 | `seed_sweep` | X008 `opq_error_header_word_mask_recovery_test` + random surrounding traffic, 500k txn | header-word error → `MASK_PKT` path at scale |
| CROSS-069 | `seed_sweep` | X009 `opq_error_counter_clear_test` + random surrounding traffic, 500k txn | counter-clear invariants under random stress |
| CROSS-070 | `seed_sweep` | X010 `opq_error_ftable_overflow_test` shape-check at elaboration point with random inter-burst gap, 500k txn | reduced-depth overflow shape-check at scale |
| CROSS-071 | `seed_sweep` | mixed `hit_err` + `shd_err` injection at 1% each, random surrounding traffic, 500k txn | cross-error-type composition |
| CROSS-072 | `seed_sweep` | mixed `hit_err` + `hdr_err` injection at 1% each, 500k txn | `hit_err` vs `hdr_err` non-interference |
| CROSS-073 | `seed_sweep` | mixed `shd_err` + `hdr_err` injection at 1% each, 500k txn | `shd_err` vs `hdr_err` non-interference |
| CROSS-074 | `seed_sweep` | all three error types at 1% each + LANE_MASK toggles every 4k cyc, 500k txn | error × mask composition |
| CROSS-075 | `seed_sweep` | all three error types + LANE_MASK toggles + DRR reprogram every 1k cyc, 1M txn | error × mask × DRR composition |

### 6.9 Overwrite-pressure / drop soaks (CROSS-076-090)

These runs drive the overwrite-pressure and legal-overflow paths the hardest. Each has an explicit drop-axis target and a ledger-closure check.

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-076 | `seed_sweep` | `opq_cross_bp_predrop_boundary_test` | random inter-window gap, 500k txn | legal pre-drop window under random pacing |
| CROSS-077 | `seed_sweep` | `opq_cross_bp_predrop_boundary_test` | extended simtime + `+OPQ_MIXED_SOAK_STEPS=16`, 1M txn | extended pre-drop evidence |
| CROSS-078 | `seed_sweep` | `opq_cross_bp_mustdrop_witness_test` | reduced-depth `2-lane/256/512` at random inter-burst gap, 500k txn | must-drop ledger `wr_hdr/shd/hit=13/224/3135`, `rd_hdr/shd/hit=3/144/735`, `drop_hdr/shd/hit=10/80/2400`, `accepted=735 delivered=735 unexplained=0` |
| CROSS-079 | `seed_sweep` | `opq_cross_bp_mustdrop_witness_test` | refreshed `4-lane/128/512` + mid-run LANE_MASK toggle | must-drop on refreshed wider preset |
| CROSS-080 | `seed_sweep` | `opq_cross_random_ready_overflow_step2_boundary_test` | random inter-window gap, 500k txn | two-step legal overflow under random pacing |
| CROSS-081 | `seed_sweep` | `opq_cross_random_ready_overflow_seconds_soak_test` | default-build random-ready overflow / bp soak with ledger checkpoints | shape-check `ft_drop_hdr/shd/hit=0/0/0`, `wr_hdr/shd/hit=29/68/5545`, `rd_hdr/shd/hit=29/68/5545`, `accepted=5545 delivered=5545 unexplained=0`, `core_principles first_break=clean` |
| CROSS-082 | `seed_sweep` | sustained pool=2 at λ=0.9 with `resident_backpressure_hold` coverage, 1M txn | presenter hold engagement + overwrite-pressure invariants |
| CROSS-083 | `seed_sweep` | sustained pool=2 at λ=0.95 with max-hit subheaders, 1M txn | extreme-pressure invariants on max-hit frame |
| CROSS-084 | `seed_sweep` | sustained pool=2 at λ=1.0 with burst shape (256-beat bursts, 128-cycle gaps), 1M txn | burst-induced overwrite pressure |
| CROSS-085 | `seed_sweep` | `opq_cross_mixed_bucket_random_soak_test` | refreshed `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=4096` rerun | closes with `expected=14547 actual=14547 missing=0 ghost=0`; dedicated supplemental signoff run |
| CROSS-086 | `checkpoint_soak` | `opq_cross_mixed_bucket_seconds_soak_test` | extended probe with `+TB_CLK_PERIOD_NS=250` | crosses the old `mixed_sparse_191`, `mixed_soak_261`, `mixed_whole_skew_275/418/435` windows cleanly; exits `UVM_ERROR : 0` |
| CROSS-087 | `checkpoint_soak` | `opq_cross_mixed_bucket_long_simtime_soak_test` | `+TB_CLK_PERIOD_NS=1000000 +OPQ_MIXED_SOAK_STEPS=64` | finishes at ~`2194139500 us` (~36.6 min), `expected=5798 actual=5798 missing=0 ghost=0` |
| CROSS-088 | `checkpoint_soak` | must-drop + 10M txn cap | overwrite-pressure soak with `ft_drop_*` monotonicity check at log-spaced checkpoints | drop-axis growth curve captured |
| CROSS-089 | `checkpoint_soak` | two-step legal overflow + 10M txn cap | legal pre-drop sustained across deep soak | overflow-axis growth curve |
| CROSS-090 | `checkpoint_soak` | mixed-bucket 10M-txn reference soak | bucket-mix + overwrite-pressure × LANE_MASK × DRR compositions | primary growth-curve reference for the overwrite-pressure bucket |

### 6.10 DRR and backpressure soaks (CROSS-091-105)

One run per DRR and backpressure corner, promoted to long-soak with the coverage observer continuously sampling.

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-091 | `seed_sweep` | `opq_cross_drr_allowance_test` | random DRR allowance reprogram every 1k cyc, 500k txn | runtime allowance reprogramming regression guard |
| CROSS-092 | `seed_sweep` | `opq_cross_drr_idle_lane_test` | idle-lane cadence × periodic egress stall, 500k txn | idle-lane empty-frame cadence under random bp |
| CROSS-093 | `seed_sweep` | `opq_cross_drr_zero_allowance_test` | zero-allowance window followed by reload, random position, 500k txn | defer-then-resume invariant under random schedule |
| CROSS-094 | `seed_sweep` | `opq_cross_drr_short_allowance_test` | short-quantum reload × random surrounding traffic, 500k txn | repeated reload invariant |
| CROSS-095 | `seed_sweep` | `opq_cross_drr_bursty_random_test` | constrained-random bursty DRR × periodic egress stall, 1M txn | refreshed seeds `1..8` closure; `cg_drr` bursty bin saturation |
| CROSS-096 | `seed_sweep` | `opq_cross_idle_lane_backpressure_test` | idle-lane × active-lane bp with random bp profile, 500k txn | skid + `resident_backpressure_hold` × idle-lane interaction |
| CROSS-097 | `seed_sweep` | E001 `opq_edge_backpressure_test` | periodic stall + random subheader density, 500k txn | classic bp coverage |
| CROSS-098 | `seed_sweep` | E002 `opq_edge_always_ready_test` | ready-high baseline + random ingress shape, 500k txn | baseline reference |
| CROSS-099 | `seed_sweep` | E003 `opq_edge_ready_medium_profile_test` | medium-duty bp + random inter-window, 500k txn | medium bp coverage |
| CROSS-100 | `seed_sweep` | E004 `opq_edge_stuck_low_backpressure_test` | long stuck-low + random inter-window, 500k txn | long hold invariant |
| CROSS-101 | `seed_sweep` | E005 `opq_edge_max_hits_test` | max-hit frame + random bp, 500k txn | max-hit throughput invariant |
| CROSS-102 | `seed_sweep` | E006 `opq_edge_toggle_backpressure_test` | 1-cycle toggle + random ingress shape, 500k txn | toggle bp invariant |
| CROSS-103 | `seed_sweep` | E007 `opq_edge_burst_restart_profile_test` | short bursts + deep stretches, 500k txn | presenter restart invariant |
| CROSS-104 | `seed_sweep` | E008 `opq_edge_long_toggle_backpressure_test` | extended toggling + random surrounding traffic, 1M txn | long-toggle invariant |
| CROSS-105 | `seed_sweep` | E009 `opq_edge_max_hits_backpressure_test` | max-hit × bp + random inter-window, 1M txn | max-hit under bp invariant |

### 6.11 Hit3 and masked-drop repro regressions (CROSS-106-120)

Promotes the direct repro-tests into randomized long-soaks so the same invariants are re-hit at many phase offsets. Each row preserves the legacy repro test name so generator metadata keeps the alias.

| case_id | ladder | anchor test | scenario | bug / coverage target |
|---|---|---|---|---|
| CROSS-106 | `anchored_hybrid` | `opq_cross_hit3_exact_183_190_repro_test` | exact-sample-window at 183-190 + random surrounding traffic, 500 trials | hit3 exact-window reproducible regression trap |
| CROSS-107 | `anchored_hybrid` | block-mover abort at `TICKET_ALT_EOP_LOC` ∈ {first, mid, last}, random trial, 500 trials | abort paths exercised at all three locations |
| CROSS-108 | `anchored_hybrid` | mixed `hit_err/shd_err/hdr_err` at correct locations, random trial, 500 trials | typed-error contract exercised across the three locations |
| CROSS-109 | `anchored_hybrid` | LANE_MASK mid-frame vs packet-boundary, random trial, 500 trials | mask granularity invariant |
| CROSS-110 | `anchored_hybrid` | counter-clear during active `WR_HITS` vs `PRESENTING`, random trial, 500 trials | counter-clear scope invariant |
| CROSS-111 | `anchored_hybrid` | `opq_cross_hit3_lead_in_repro_test` + random surrounding traffic, 500 trials | hit3 lead-in invariant |
| CROSS-112 | `anchored_hybrid` | hit3 contract SVA `opq_hit3_contract_sva` under random pressure, 500 trials | SVA never fires under randomized stress |
| CROSS-113 | `anchored_hybrid` | `opq_cross_masked_drop_exact_102_117_repro_test` + random surrounding traffic, 500 trials | masked-drop exact-window invariant |
| CROSS-114 | `anchored_hybrid` | `opq_cross_single_hit_masked_then_sparse_repro_test` + random surrounding traffic, 500 trials | single-hit masked then sparse recovery invariant |
| CROSS-115 | `anchored_hybrid` | `opq_cross_sparse_single_lane_drr_credit_restore_repro_test` + random surrounding traffic, 500 trials | sparse single-lane DRR credit restoration invariant |
| CROSS-116 | `anchored_hybrid` | `opq_avst_ingress_sva` under random pressure, 500 trials | SVA never fires under randomized ingress |
| CROSS-117 | `anchored_hybrid` | `opq_avst_egress_sva` under random pressure, 500 trials | SVA never fires under randomized egress |
| CROSS-118 | `anchored_hybrid` | `opq_csr_sva` under random CSR access, 500 trials | SVA never fires under random CSR traffic |
| CROSS-119 | `anchored_hybrid` | `opq_drr_sva` under random DRR pressure, 500 trials | SVA never fires under random DRR traffic |
| CROSS-120 | `anchored_hybrid` | all 5 SVA families armed throughout mixed-bucket random soak, 1M txn | no SVA fires across long randomized signoff |

### 6.12 Checkpoint UCDB long soaks (CROSS-121-125)

Growth-curve runs. Each saves checkpoint UCDBs at log-spaced txn counts under `REPORT/txn_growth/`. Picked to union cross-axis bins fastest.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-121 | `checkpoint_soak` | default build pool=2 at λ=0.7, seed=`0x0001`, 10M txn, checkpoints at 1, 4, 16, 64, 256, 1k, 4k, 16k, 64k, 256k, 1M, 4M, 10M | primary growth curve; FSM + toggle closure driven here |
| CROSS-122 | `checkpoint_soak` | default build pool=2 at λ=0.9 with `EGRESS_DELAY=3 / +1` stall boundaries, seed=`0x0003`, 10M txn | bp bin coverage + overwrite-pressure cross |
| CROSS-123 | `checkpoint_soak` | default build pool=2 with LANE_MASK reprogram every 500k cyc, seed=`0x0006`, 10M txn | mask × counter coverage saturated |
| CROSS-124 | `checkpoint_soak` | default build pool=2 with DRR allowance reprogram every 500k cyc, seed=`0x0007`, 10M txn | DRR reprogramming × counter coverage |
| CROSS-125 | `checkpoint_soak` | default build pool=2 at 120% effective push rate, seed=`0x0020`, 10M txn, overwrite-focused | overwrite × counter truncation guard; `FT_WR_*` crosses 2^31 |

### 6.13 Closure signoff (CROSS-126-129)

Final merged-regression runs. Every axis is randomized; these are the one-shot runs that must all pass for the IP to sign off.

| case_id | ladder | scenario | bug / coverage target |
|---|---|---|---|
| CROSS-126 | `checkpoint_soak` | `all_buckets_frame` + randomized inter-case gaps + random LANE_MASK / DRR reprogram between buckets, 5M txn, seed=`0x1000` | full catalog composed under randomized timing |
| CROSS-127 | `checkpoint_soak` | same stimulus as CROSS-126 with seed=`0x2000` (orthogonal) | seed-independence of closure |
| CROSS-128 | `checkpoint_soak` | merge-reference of CROSS-017..030 + CROSS-061..090 + CROSS-121..125, 10M txn replay | merged UCDB must clear every target in §4 |
| CROSS-129 | `checkpoint_soak` | BUG-seeded composer using the full anchor list of §5, 10M txn, random trap selection per 50k cyc | one run that must trap every historical bug if any regresses |

## 7) Coverage Closure Rules

- Every cross run emits an isolated UCDB. `bucket_frame` / `all_buckets_frame` / `checkpoint_soak` runs emit merged UCDBs as well.
- `checkpoint_soak` runs emit one UCDB per checkpoint under `REPORT/txn_growth/<case_id>/ckpt_<n>.ucdb`. The checkpoint schedule is log-spaced and fixed per run (see catalog).
- The §4 closure targets are evaluated on the **merged UCDB** of the full isolated B/E/P/X catalog + all CROSS runs. Any single-run coverage is not closure.
- A CROSS run does not count toward closure until:
  - its scoreboard reports `expected == actual`, `missing == 0`, `ghost == 0`, and per-lane `unexplained == 0`
  - every `ft_drop_*` transition is accounted (either reconciled with `wr == rd + drop` at quiescence or explicitly tied to a must-drop / overwrite-local elaboration point)
  - every counter invariant in the anchor target column is verified
  - every SVA family (`opq_avst_ingress_sva`, `opq_avst_egress_sva`, `opq_csr_sva`, `opq_hit3_contract_sva`, `opq_drr_sva`) stays clean
  - its isolated UCDB is present and merged into the release UCDB

## 8) Bug-Regression Gate

The following runs must be green for a release-quality RTL revision:

- every bug-seeded soak in §6.6 (CROSS-031-045)
- every promoted `opq_cross_*_test` row in §6.2, §6.3, and §6.4 (CROSS-007..016)
- the overwrite-local must-drop witness rows in §6.9 (CROSS-078, CROSS-079)
- the refreshed mixed-bucket and long-simtime soak rows (CROSS-085, CROSS-086, CROSS-087)
- the full hit3 / masked-drop repro regressions in §6.11 (CROSS-106-120)
- the counter-truncation long-horizon runs (CROSS-045, CROSS-121, CROSS-125)
- the closure regressions CROSS-128 and CROSS-129

If any of those fail, the RTL is not releasable regardless of other coverage totals.

## 9) Signoff Gates

The IP is cross-signoff-complete when all of the following are true:

- every CROSS-001..129 has an evidence page under `REPORT/cross/` with a non-zero txn count and `unexplained=0`
- the merged UCDB clears every §4 target
- the §8 bug-regression gate is green on the current RTL revision
- the DV_REPORT.md dashboard (regenerated by `~/.codex/skills/dv-workflow/scripts/dv_report_gen.py`) shows zero `unimplemented_cases` across the cross table
- every SVA family is clean across all CROSS runs
- `DV_HARNESS.md` gaps are either closed or explicitly retired with written rationale

## 10) Regenerate

After editing this file, run the generator so `DV_REPORT.json` and `DV_REPORT.md` pick up the new scenarios:

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb .
```

The generator parses `DV_CROSS.md` for the catalog table. Keep the `CROSS-###` IDs contiguous from `001` to `129`; do not reuse numbers across rewrites.

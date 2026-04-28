# DV Coverage Summary — packet_scheduler ordered_priority_queue native_sv

This page is the coverage summary only. Per-case incremental coverage lives under
[`REPORT/cases/`](REPORT/cases/); per-bucket ordered-merge traces live under
[`REPORT/buckets/`](REPORT/buckets/). Isolated per-case coverage and continuous-frame
signoff-run coverage are tracked separately and must not be collapsed into one
number.

## Legend

✅ pass / closed &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `native_sv` |
| OPQ_N_LANE | `4` |
| OPQ_N_SHD | `128` |
| OPQ_TICKET_FIFO_DEPTH | `256` |
| OPQ_PAGE_RAM_DEPTH | `512`, `65536` |
| MODE | `MERGING` |
| probe_only_exclusions |  |

## Non-Claims

- cross scope: DV_CROSS supplemental long-run ladders are tracked separately from the canonical per-case isolated matrix in this refresh.

## Coverage Category Status

| metric | status | note |
|---|---|---|
| stmt | supported_with_target | supported in the Questa native-SV flow; tracked against the 95% workflow target |
| branch | supported_with_target | supported in the Questa native-SV flow; tracked against the 90% workflow target |
| fsm_state | supported_with_target | supported in the Questa native-SV flow; tracked against the 95% workflow target |
| fsm_trans | supported_with_target | supported in the Questa native-SV flow; tracked against the 90% workflow target |
| toggle | supported_with_target | supported in the Questa native-SV flow; tracked against the 80% workflow target |
| cond | supported_no_fixed_target | supported in the Questa native-SV flow and reported explicitly |
| expr | supported_no_fixed_target | supported in the Questa native-SV flow and reported explicitly |
| - | unsupported | none; no code-coverage category is silently omitted from this report |

## Coverage-Hole Disposition

| area | measured summary | disposition | evidence anchor | next action |
|---|---|---|---|---|
| ingress parser lane asymmetry | stmt=40.89, branch=22.64, cond=0.00, fsm_trans=4.17, toggle=6.85 (min across 4 instances) | justified_nonclaim: isolated merged coverage bottoms out at stmt=61.78, branch=47.17, fsm_trans=25.00, toggle=21.79 across the four lane-local parser instances; current-scope supplemental runs lift the parser family to stmt=93.56, branch=86.32, fsm_trans=70.83, toggle=61.22, so the residual deficit is the bounded 4-lane asymmetry / recovery axis rather than missing logs or broken UCDB plumbing | `DV_PLAN.md` 4-lane asymmetry notes; `DV_CROSS.md` CROSS-053 | Promote a dedicated 4-lane parser recovery / asymmetry sweep only if raw per-instance structural closure becomes a hard release gate. |
| page allocator reset / fast-close arcs | stmt=84.35, branch=72.01, cond=36.69, fsm_trans=54.55, toggle=19.88 (min across 1 instance) | justified_nonclaim: the allocator improves from stmt=84.35, branch=72.01, fsm_trans=54.55, toggle=19.88 to stmt=90.02, branch=82.59, fsm_trans=54.55, toggle=55.68 once maintained signoff runs are merged, and the remaining FSM misses are dominated by active-state -> RESET fanout plus the WRITE_HEAD -> WRITE_TAIL empty-frame fast-close path rather than unexplained hit loss | `DV_ERROR.md` X081-X086; `DV_FORMAL.md` B23/B32 | Add a true mid-state reset / zero-hit fast-close stress only if raw allocator transition closure is promoted from a bounded non-claim to a release gate. |
| presenter overwrite / must-drop scan | stmt=59.61, branch=62.88, cond=34.85, fsm_trans=50.00, toggle=15.60 (min across 1 instance) | justified_nonclaim: isolated presenter coverage remains low at stmt=59.61, branch=62.88, fsm_trans=50.00, toggle=15.60 because the overwrite-scan and must-drop logic is only forced by the named overflow witnesses; maintained signoff runs lift it to stmt=61.36, branch=72.73, fsm_trans=50.00, toggle=35.22 while hit-conservation screens stay clean, so the raw deficit maps to the explicit must-drop non-claim rather than a silent datapath failure | `DV_CROSS.md` CROSS-078/CROSS-079; `BUG_HISTORY.md` BUG-029-R/BUG-030-R | Keep `opq_cross_bp_mustdrop_witness_test` green and do not remove the non-claim until a default-build must-drop baseline is promoted into the published scope. |
| block path reset-only arcs | stmt=85.10, branch=74.75, cond=39.47, fsm_trans=37.50, toggle=29.46 (min across 1 instance) | justified_exclusion: statement coverage is already 85.10 and signoff runs lift block-path toggle to 85.78; the remaining uncovered FSM transitions are the three ARBITER_* -> RESET arcs only | `DV_FORMAL.md` B23/B32 reset / flush invariants | Leave this as a reset-only exclusion unless mid-state hard reset becomes part of the release contract. |
| wrapper-only toggle bookkeeping | stmt=78.45, branch=68.65, cond=42.11, toggle=13.47 (min across 3 instances) | justified_exclusion: top-level DUT and wrapper shells depress raw toggle through duplicated aggregation, probe, and bookkeeping nets without indicating missing testcase evidence in the core owner modules | `DV_REPORT.md` Signoff Runs; `doc/SIGNOFF.md` current-scope note | Do not spend testcase budget on wrapper toggles until owner-module functional gaps change. |

## Targets vs merged totals

<!-- merged_pct = merge across all evidenced promoted isolated-mode UCDBs across all signoff buckets. -->
<!-- Continuous-frame sequential-run coverage is reported separately in the signoff-run section below. -->

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | 73.06 | 95.0 |
| ⚠️ | branch | 61.81 | 90.0 |
| ℹ️ | cond | 31.03 | - |
| ℹ️ | expr | 56.67 | - |
| ⚠️ | fsm_state | 76.71 | 95.0 |
| ⚠️ | fsm_trans | 36.53 | 90.0 |
| ⚠️ | toggle | 18.58 | 80.0 |

## Per-bucket merged totals

_These are ordered isolated merged totals, not continuous-frame sequential-run totals._

| status | bucket | catalog_planned | promoted | evidenced | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---:|---:|---:|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](REPORT/buckets/BASIC.md) | 129 | 129 | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ⚠️ | [`EDGE`](REPORT/buckets/EDGE.md) | 129 | 129 | 1 | 72.60 | 60.33 | 26.28 | 48.67 | 76.71 | 36.53 | 17.75 |
| ⚠️ | [`PROF`](REPORT/buckets/PROF.md) | 129 | 129 | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ⚠️ | [`ERROR`](REPORT/buckets/ERROR.md) | 129 | 129 | 8 | 72.33 | 60.77 | 30.63 | 56.67 | 76.71 | 36.53 | 18.58 |

## Isolated execution order and traceability

| bucket | ordered case IDs | trace |
|---|---|---|
| BASIC | [`B001`](REPORT/cases/B001.md), [`B002`](REPORT/cases/B002.md), [`B003`](REPORT/cases/B003.md), [`B004`](REPORT/cases/B004.md), [`B005`](REPORT/cases/B005.md), [`B006`](REPORT/cases/B006.md), [`B007`](REPORT/cases/B007.md), [`B008`](REPORT/cases/B008.md), [`B009`](REPORT/cases/B009.md), [`B010`](REPORT/cases/B010.md), [`B011`](REPORT/cases/B011.md), [`B012`](REPORT/cases/B012.md), [`B013`](REPORT/cases/B013.md), [`B014`](REPORT/cases/B014.md), [`B015`](REPORT/cases/B015.md), [`B016`](REPORT/cases/B016.md), [`B017`](REPORT/cases/B017.md), [`B018`](REPORT/cases/B018.md), [`B019`](REPORT/cases/B019.md), [`B020`](REPORT/cases/B020.md), [`B021`](REPORT/cases/B021.md), [`B022`](REPORT/cases/B022.md), [`B023`](REPORT/cases/B023.md), [`B024`](REPORT/cases/B024.md), [`B025`](REPORT/cases/B025.md), [`B026`](REPORT/cases/B026.md), [`B027`](REPORT/cases/B027.md), [`B028`](REPORT/cases/B028.md), [`B029`](REPORT/cases/B029.md), [`B030`](REPORT/cases/B030.md), [`B031`](REPORT/cases/B031.md), [`B032`](REPORT/cases/B032.md), [`B033`](REPORT/cases/B033.md), [`B034`](REPORT/cases/B034.md), [`B035`](REPORT/cases/B035.md), [`B036`](REPORT/cases/B036.md), [`B037`](REPORT/cases/B037.md), [`B038`](REPORT/cases/B038.md), [`B039`](REPORT/cases/B039.md), [`B040`](REPORT/cases/B040.md), [`B041`](REPORT/cases/B041.md), [`B042`](REPORT/cases/B042.md), [`B043`](REPORT/cases/B043.md), [`B044`](REPORT/cases/B044.md), [`B045`](REPORT/cases/B045.md), [`B046`](REPORT/cases/B046.md), [`B047`](REPORT/cases/B047.md), [`B048`](REPORT/cases/B048.md), [`B049`](REPORT/cases/B049.md), [`B050`](REPORT/cases/B050.md), [`B051`](REPORT/cases/B051.md), [`B052`](REPORT/cases/B052.md), [`B053`](REPORT/cases/B053.md), [`B054`](REPORT/cases/B054.md), [`B055`](REPORT/cases/B055.md), [`B056`](REPORT/cases/B056.md), [`B057`](REPORT/cases/B057.md), [`B058`](REPORT/cases/B058.md), [`B059`](REPORT/cases/B059.md), [`B060`](REPORT/cases/B060.md), [`B061`](REPORT/cases/B061.md), [`B062`](REPORT/cases/B062.md), [`B063`](REPORT/cases/B063.md), [`B064`](REPORT/cases/B064.md), [`B065`](REPORT/cases/B065.md), [`B066`](REPORT/cases/B066.md), [`B067`](REPORT/cases/B067.md), [`B068`](REPORT/cases/B068.md), [`B069`](REPORT/cases/B069.md), [`B070`](REPORT/cases/B070.md), [`B071`](REPORT/cases/B071.md), [`B072`](REPORT/cases/B072.md), [`B073`](REPORT/cases/B073.md), [`B074`](REPORT/cases/B074.md), [`B075`](REPORT/cases/B075.md), [`B076`](REPORT/cases/B076.md), [`B077`](REPORT/cases/B077.md), [`B078`](REPORT/cases/B078.md), [`B079`](REPORT/cases/B079.md), [`B080`](REPORT/cases/B080.md), [`B081`](REPORT/cases/B081.md), [`B082`](REPORT/cases/B082.md), [`B083`](REPORT/cases/B083.md), [`B084`](REPORT/cases/B084.md), [`B085`](REPORT/cases/B085.md), [`B086`](REPORT/cases/B086.md), [`B087`](REPORT/cases/B087.md), [`B088`](REPORT/cases/B088.md), [`B089`](REPORT/cases/B089.md), [`B090`](REPORT/cases/B090.md), [`B091`](REPORT/cases/B091.md), [`B092`](REPORT/cases/B092.md), [`B093`](REPORT/cases/B093.md), [`B094`](REPORT/cases/B094.md), [`B095`](REPORT/cases/B095.md), [`B096`](REPORT/cases/B096.md), [`B097`](REPORT/cases/B097.md), [`B098`](REPORT/cases/B098.md), [`B099`](REPORT/cases/B099.md), [`B100`](REPORT/cases/B100.md), [`B101`](REPORT/cases/B101.md), [`B102`](REPORT/cases/B102.md), [`B103`](REPORT/cases/B103.md), [`B104`](REPORT/cases/B104.md), [`B105`](REPORT/cases/B105.md), [`B106`](REPORT/cases/B106.md), [`B107`](REPORT/cases/B107.md), [`B108`](REPORT/cases/B108.md), [`B109`](REPORT/cases/B109.md), [`B110`](REPORT/cases/B110.md), [`B111`](REPORT/cases/B111.md), [`B112`](REPORT/cases/B112.md), [`B113`](REPORT/cases/B113.md), [`B114`](REPORT/cases/B114.md), [`B115`](REPORT/cases/B115.md), [`B116`](REPORT/cases/B116.md), [`B117`](REPORT/cases/B117.md), [`B118`](REPORT/cases/B118.md), [`B119`](REPORT/cases/B119.md), [`B120`](REPORT/cases/B120.md), [`B121`](REPORT/cases/B121.md), [`B122`](REPORT/cases/B122.md), [`B123`](REPORT/cases/B123.md), [`B124`](REPORT/cases/B124.md), [`B125`](REPORT/cases/B125.md), [`B126`](REPORT/cases/B126.md), [`B127`](REPORT/cases/B127.md), [`B128`](REPORT/cases/B128.md), [`B129`](REPORT/cases/B129.md) | [`REPORT/buckets/BASIC.md`](REPORT/buckets/BASIC.md) |
| EDGE | [`E001`](REPORT/cases/E001.md), [`E002`](REPORT/cases/E002.md), [`E003`](REPORT/cases/E003.md), [`E004`](REPORT/cases/E004.md), [`E005`](REPORT/cases/E005.md), [`E006`](REPORT/cases/E006.md), [`E007`](REPORT/cases/E007.md), [`E008`](REPORT/cases/E008.md), [`E009`](REPORT/cases/E009.md), [`E010`](REPORT/cases/E010.md), [`E011`](REPORT/cases/E011.md), [`E012`](REPORT/cases/E012.md), [`E013`](REPORT/cases/E013.md), [`E014`](REPORT/cases/E014.md), [`E015`](REPORT/cases/E015.md), [`E016`](REPORT/cases/E016.md), [`E017`](REPORT/cases/E017.md), [`E018`](REPORT/cases/E018.md), [`E019`](REPORT/cases/E019.md), [`E020`](REPORT/cases/E020.md), [`E021`](REPORT/cases/E021.md), [`E022`](REPORT/cases/E022.md), [`E023`](REPORT/cases/E023.md), [`E024`](REPORT/cases/E024.md), [`E025`](REPORT/cases/E025.md), [`E026`](REPORT/cases/E026.md), [`E027`](REPORT/cases/E027.md), [`E028`](REPORT/cases/E028.md), [`E029`](REPORT/cases/E029.md), [`E030`](REPORT/cases/E030.md), [`E031`](REPORT/cases/E031.md), [`E032`](REPORT/cases/E032.md), [`E033`](REPORT/cases/E033.md), [`E034`](REPORT/cases/E034.md), [`E035`](REPORT/cases/E035.md), [`E036`](REPORT/cases/E036.md), [`E037`](REPORT/cases/E037.md), [`E038`](REPORT/cases/E038.md), [`E039`](REPORT/cases/E039.md), [`E040`](REPORT/cases/E040.md), [`E041`](REPORT/cases/E041.md), [`E042`](REPORT/cases/E042.md), [`E043`](REPORT/cases/E043.md), [`E044`](REPORT/cases/E044.md), [`E045`](REPORT/cases/E045.md), [`E046`](REPORT/cases/E046.md), [`E047`](REPORT/cases/E047.md), [`E048`](REPORT/cases/E048.md), [`E049`](REPORT/cases/E049.md), [`E050`](REPORT/cases/E050.md), [`E051`](REPORT/cases/E051.md), [`E052`](REPORT/cases/E052.md), [`E053`](REPORT/cases/E053.md), [`E054`](REPORT/cases/E054.md), [`E055`](REPORT/cases/E055.md), [`E056`](REPORT/cases/E056.md), [`E057`](REPORT/cases/E057.md), [`E058`](REPORT/cases/E058.md), [`E059`](REPORT/cases/E059.md), [`E060`](REPORT/cases/E060.md), [`E061`](REPORT/cases/E061.md), [`E062`](REPORT/cases/E062.md), [`E063`](REPORT/cases/E063.md), [`E064`](REPORT/cases/E064.md), [`E065`](REPORT/cases/E065.md), [`E066`](REPORT/cases/E066.md), [`E067`](REPORT/cases/E067.md), [`E068`](REPORT/cases/E068.md), [`E069`](REPORT/cases/E069.md), [`E070`](REPORT/cases/E070.md), [`E071`](REPORT/cases/E071.md), [`E072`](REPORT/cases/E072.md), [`E073`](REPORT/cases/E073.md), [`E074`](REPORT/cases/E074.md), [`E075`](REPORT/cases/E075.md), [`E076`](REPORT/cases/E076.md), [`E077`](REPORT/cases/E077.md), [`E078`](REPORT/cases/E078.md), [`E079`](REPORT/cases/E079.md), [`E080`](REPORT/cases/E080.md), [`E081`](REPORT/cases/E081.md), [`E082`](REPORT/cases/E082.md), [`E083`](REPORT/cases/E083.md), [`E084`](REPORT/cases/E084.md), [`E085`](REPORT/cases/E085.md), [`E086`](REPORT/cases/E086.md), [`E087`](REPORT/cases/E087.md), [`E088`](REPORT/cases/E088.md), [`E089`](REPORT/cases/E089.md), [`E090`](REPORT/cases/E090.md), [`E091`](REPORT/cases/E091.md), [`E092`](REPORT/cases/E092.md), [`E093`](REPORT/cases/E093.md), [`E094`](REPORT/cases/E094.md), [`E095`](REPORT/cases/E095.md), [`E096`](REPORT/cases/E096.md), [`E097`](REPORT/cases/E097.md), [`E098`](REPORT/cases/E098.md), [`E099`](REPORT/cases/E099.md), [`E100`](REPORT/cases/E100.md), [`E101`](REPORT/cases/E101.md), [`E102`](REPORT/cases/E102.md), [`E103`](REPORT/cases/E103.md), [`E104`](REPORT/cases/E104.md), [`E105`](REPORT/cases/E105.md), [`E106`](REPORT/cases/E106.md), [`E107`](REPORT/cases/E107.md), [`E108`](REPORT/cases/E108.md), [`E109`](REPORT/cases/E109.md), [`E110`](REPORT/cases/E110.md), [`E111`](REPORT/cases/E111.md), [`E112`](REPORT/cases/E112.md), [`E113`](REPORT/cases/E113.md), [`E114`](REPORT/cases/E114.md), [`E115`](REPORT/cases/E115.md), [`E116`](REPORT/cases/E116.md), [`E117`](REPORT/cases/E117.md), [`E118`](REPORT/cases/E118.md), [`E119`](REPORT/cases/E119.md), [`E120`](REPORT/cases/E120.md), [`E121`](REPORT/cases/E121.md), [`E122`](REPORT/cases/E122.md), [`E123`](REPORT/cases/E123.md), [`E124`](REPORT/cases/E124.md), [`E125`](REPORT/cases/E125.md), [`E126`](REPORT/cases/E126.md), [`E127`](REPORT/cases/E127.md), [`E128`](REPORT/cases/E128.md), [`E129`](REPORT/cases/E129.md) | [`REPORT/buckets/EDGE.md`](REPORT/buckets/EDGE.md) |
| PROF | [`P001`](REPORT/cases/P001.md), [`P002`](REPORT/cases/P002.md), [`P003`](REPORT/cases/P003.md), [`P004`](REPORT/cases/P004.md), [`P005`](REPORT/cases/P005.md), [`P006`](REPORT/cases/P006.md), [`P007`](REPORT/cases/P007.md), [`P008`](REPORT/cases/P008.md), [`P009`](REPORT/cases/P009.md), [`P010`](REPORT/cases/P010.md), [`P011`](REPORT/cases/P011.md), [`P012`](REPORT/cases/P012.md), [`P013`](REPORT/cases/P013.md), [`P014`](REPORT/cases/P014.md), [`P015`](REPORT/cases/P015.md), [`P016`](REPORT/cases/P016.md), [`P017`](REPORT/cases/P017.md), [`P018`](REPORT/cases/P018.md), [`P019`](REPORT/cases/P019.md), [`P020`](REPORT/cases/P020.md), [`P021`](REPORT/cases/P021.md), [`P022`](REPORT/cases/P022.md), [`P023`](REPORT/cases/P023.md), [`P024`](REPORT/cases/P024.md), [`P025`](REPORT/cases/P025.md), [`P026`](REPORT/cases/P026.md), [`P027`](REPORT/cases/P027.md), [`P028`](REPORT/cases/P028.md), [`P029`](REPORT/cases/P029.md), [`P030`](REPORT/cases/P030.md), [`P031`](REPORT/cases/P031.md), [`P032`](REPORT/cases/P032.md), [`P033`](REPORT/cases/P033.md), [`P034`](REPORT/cases/P034.md), [`P035`](REPORT/cases/P035.md), [`P036`](REPORT/cases/P036.md), [`P037`](REPORT/cases/P037.md), [`P038`](REPORT/cases/P038.md), [`P039`](REPORT/cases/P039.md), [`P040`](REPORT/cases/P040.md), [`P041`](REPORT/cases/P041.md), [`P042`](REPORT/cases/P042.md), [`P043`](REPORT/cases/P043.md), [`P044`](REPORT/cases/P044.md), [`P045`](REPORT/cases/P045.md), [`P046`](REPORT/cases/P046.md), [`P047`](REPORT/cases/P047.md), [`P048`](REPORT/cases/P048.md), [`P049`](REPORT/cases/P049.md), [`P050`](REPORT/cases/P050.md), [`P051`](REPORT/cases/P051.md), [`P052`](REPORT/cases/P052.md), [`P053`](REPORT/cases/P053.md), [`P054`](REPORT/cases/P054.md), [`P055`](REPORT/cases/P055.md), [`P056`](REPORT/cases/P056.md), [`P057`](REPORT/cases/P057.md), [`P058`](REPORT/cases/P058.md), [`P059`](REPORT/cases/P059.md), [`P060`](REPORT/cases/P060.md), [`P061`](REPORT/cases/P061.md), [`P062`](REPORT/cases/P062.md), [`P063`](REPORT/cases/P063.md), [`P064`](REPORT/cases/P064.md), [`P065`](REPORT/cases/P065.md), [`P066`](REPORT/cases/P066.md), [`P067`](REPORT/cases/P067.md), [`P068`](REPORT/cases/P068.md), [`P069`](REPORT/cases/P069.md), [`P070`](REPORT/cases/P070.md), [`P071`](REPORT/cases/P071.md), [`P072`](REPORT/cases/P072.md), [`P073`](REPORT/cases/P073.md), [`P074`](REPORT/cases/P074.md), [`P075`](REPORT/cases/P075.md), [`P076`](REPORT/cases/P076.md), [`P077`](REPORT/cases/P077.md), [`P078`](REPORT/cases/P078.md), [`P079`](REPORT/cases/P079.md), [`P080`](REPORT/cases/P080.md), [`P081`](REPORT/cases/P081.md), [`P082`](REPORT/cases/P082.md), [`P083`](REPORT/cases/P083.md), [`P084`](REPORT/cases/P084.md), [`P085`](REPORT/cases/P085.md), [`P086`](REPORT/cases/P086.md), [`P087`](REPORT/cases/P087.md), [`P088`](REPORT/cases/P088.md), [`P089`](REPORT/cases/P089.md), [`P090`](REPORT/cases/P090.md), [`P091`](REPORT/cases/P091.md), [`P092`](REPORT/cases/P092.md), [`P093`](REPORT/cases/P093.md), [`P094`](REPORT/cases/P094.md), [`P095`](REPORT/cases/P095.md), [`P096`](REPORT/cases/P096.md), [`P097`](REPORT/cases/P097.md), [`P098`](REPORT/cases/P098.md), [`P099`](REPORT/cases/P099.md), [`P100`](REPORT/cases/P100.md), [`P101`](REPORT/cases/P101.md), [`P102`](REPORT/cases/P102.md), [`P103`](REPORT/cases/P103.md), [`P104`](REPORT/cases/P104.md), [`P105`](REPORT/cases/P105.md), [`P106`](REPORT/cases/P106.md), [`P107`](REPORT/cases/P107.md), [`P108`](REPORT/cases/P108.md), [`P109`](REPORT/cases/P109.md), [`P110`](REPORT/cases/P110.md), [`P111`](REPORT/cases/P111.md), [`P112`](REPORT/cases/P112.md), [`P113`](REPORT/cases/P113.md), [`P114`](REPORT/cases/P114.md), [`P115`](REPORT/cases/P115.md), [`P116`](REPORT/cases/P116.md), [`P117`](REPORT/cases/P117.md), [`P118`](REPORT/cases/P118.md), [`P119`](REPORT/cases/P119.md), [`P120`](REPORT/cases/P120.md), [`P121`](REPORT/cases/P121.md), [`P122`](REPORT/cases/P122.md), [`P123`](REPORT/cases/P123.md), [`P124`](REPORT/cases/P124.md), [`P125`](REPORT/cases/P125.md), [`P126`](REPORT/cases/P126.md), [`P127`](REPORT/cases/P127.md), [`P128`](REPORT/cases/P128.md), [`P129`](REPORT/cases/P129.md) | [`REPORT/buckets/PROF.md`](REPORT/buckets/PROF.md) |
| ERROR | [`X001`](REPORT/cases/X001.md), [`X002`](REPORT/cases/X002.md), [`X003`](REPORT/cases/X003.md), [`X004`](REPORT/cases/X004.md), [`X005`](REPORT/cases/X005.md), [`X006`](REPORT/cases/X006.md), [`X007`](REPORT/cases/X007.md), [`X008`](REPORT/cases/X008.md), [`X009`](REPORT/cases/X009.md), [`X010`](REPORT/cases/X010.md), [`X011`](REPORT/cases/X011.md), [`X012`](REPORT/cases/X012.md), [`X013`](REPORT/cases/X013.md), [`X014`](REPORT/cases/X014.md), [`X015`](REPORT/cases/X015.md), [`X016`](REPORT/cases/X016.md), [`X017`](REPORT/cases/X017.md), [`X018`](REPORT/cases/X018.md), [`X019`](REPORT/cases/X019.md), [`X020`](REPORT/cases/X020.md), [`X021`](REPORT/cases/X021.md), [`X022`](REPORT/cases/X022.md), [`X023`](REPORT/cases/X023.md), [`X024`](REPORT/cases/X024.md), [`X025`](REPORT/cases/X025.md), [`X026`](REPORT/cases/X026.md), [`X027`](REPORT/cases/X027.md), [`X028`](REPORT/cases/X028.md), [`X029`](REPORT/cases/X029.md), [`X030`](REPORT/cases/X030.md), [`X031`](REPORT/cases/X031.md), [`X032`](REPORT/cases/X032.md), [`X033`](REPORT/cases/X033.md), [`X034`](REPORT/cases/X034.md), [`X035`](REPORT/cases/X035.md), [`X036`](REPORT/cases/X036.md), [`X037`](REPORT/cases/X037.md), [`X038`](REPORT/cases/X038.md), [`X039`](REPORT/cases/X039.md), [`X040`](REPORT/cases/X040.md), [`X041`](REPORT/cases/X041.md), [`X042`](REPORT/cases/X042.md), [`X043`](REPORT/cases/X043.md), [`X044`](REPORT/cases/X044.md), [`X045`](REPORT/cases/X045.md), [`X046`](REPORT/cases/X046.md), [`X047`](REPORT/cases/X047.md), [`X048`](REPORT/cases/X048.md), [`X049`](REPORT/cases/X049.md), [`X050`](REPORT/cases/X050.md), [`X051`](REPORT/cases/X051.md), [`X052`](REPORT/cases/X052.md), [`X053`](REPORT/cases/X053.md), [`X054`](REPORT/cases/X054.md), [`X055`](REPORT/cases/X055.md), [`X056`](REPORT/cases/X056.md), [`X057`](REPORT/cases/X057.md), [`X058`](REPORT/cases/X058.md), [`X059`](REPORT/cases/X059.md), [`X060`](REPORT/cases/X060.md), [`X061`](REPORT/cases/X061.md), [`X062`](REPORT/cases/X062.md), [`X063`](REPORT/cases/X063.md), [`X064`](REPORT/cases/X064.md), [`X065`](REPORT/cases/X065.md), [`X066`](REPORT/cases/X066.md), [`X067`](REPORT/cases/X067.md), [`X068`](REPORT/cases/X068.md), [`X069`](REPORT/cases/X069.md), [`X070`](REPORT/cases/X070.md), [`X071`](REPORT/cases/X071.md), [`X072`](REPORT/cases/X072.md), [`X073`](REPORT/cases/X073.md), [`X074`](REPORT/cases/X074.md), [`X075`](REPORT/cases/X075.md), [`X076`](REPORT/cases/X076.md), [`X077`](REPORT/cases/X077.md), [`X078`](REPORT/cases/X078.md), [`X079`](REPORT/cases/X079.md), [`X080`](REPORT/cases/X080.md), [`X081`](REPORT/cases/X081.md), [`X082`](REPORT/cases/X082.md), [`X083`](REPORT/cases/X083.md), [`X084`](REPORT/cases/X084.md), [`X085`](REPORT/cases/X085.md), [`X086`](REPORT/cases/X086.md), [`X087`](REPORT/cases/X087.md), [`X088`](REPORT/cases/X088.md), [`X089`](REPORT/cases/X089.md), [`X090`](REPORT/cases/X090.md), [`X091`](REPORT/cases/X091.md), [`X092`](REPORT/cases/X092.md), [`X093`](REPORT/cases/X093.md), [`X094`](REPORT/cases/X094.md), [`X095`](REPORT/cases/X095.md), [`X096`](REPORT/cases/X096.md), [`X097`](REPORT/cases/X097.md), [`X098`](REPORT/cases/X098.md), [`X099`](REPORT/cases/X099.md), [`X100`](REPORT/cases/X100.md), [`X101`](REPORT/cases/X101.md), [`X102`](REPORT/cases/X102.md), [`X103`](REPORT/cases/X103.md), [`X104`](REPORT/cases/X104.md), [`X105`](REPORT/cases/X105.md), [`X106`](REPORT/cases/X106.md), [`X107`](REPORT/cases/X107.md), [`X108`](REPORT/cases/X108.md), [`X109`](REPORT/cases/X109.md), [`X110`](REPORT/cases/X110.md), [`X111`](REPORT/cases/X111.md), [`X112`](REPORT/cases/X112.md), [`X113`](REPORT/cases/X113.md), [`X114`](REPORT/cases/X114.md), [`X115`](REPORT/cases/X115.md), [`X116`](REPORT/cases/X116.md), [`X117`](REPORT/cases/X117.md), [`X118`](REPORT/cases/X118.md), [`X119`](REPORT/cases/X119.md), [`X120`](REPORT/cases/X120.md), [`X121`](REPORT/cases/X121.md), [`X122`](REPORT/cases/X122.md), [`X123`](REPORT/cases/X123.md), [`X124`](REPORT/cases/X124.md), [`X125`](REPORT/cases/X125.md), [`X126`](REPORT/cases/X126.md), [`X127`](REPORT/cases/X127.md), [`X128`](REPORT/cases/X128.md), [`X129`](REPORT/cases/X129.md) | [`REPORT/buckets/ERROR.md`](REPORT/buckets/ERROR.md) |

## Signoff runs by build

_These rows are for continuous-frame sequential runs such as `bucket_frame` and
`all_buckets_frame`. They are separate from the isolated merged totals above._

| status | run_id | kind | build | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---:|---|---|---|---:|---:|
| ✅ | [`opq_bucket_frame_native_sv_test`](REPORT/cross/opq_bucket_frame_native_sv_test.md) | bucket_frame | after | 39 | 82.78 | 80.82 | 44.68 | 76.72 | 738 |
| ✅ | [`opq_all_buckets_frame_native_sv_test`](REPORT/cross/opq_all_buckets_frame_native_sv_test.md) | all_buckets_frame | after | 41 | 82.78 | 80.82 | 44.72 | 76.52 | 794 |
| ✅ | [`opq_cross_bp_predrop_boundary_test`](REPORT/cross/opq_cross_bp_predrop_boundary_test.md) | cross | after | 1 | 73.80 | 64.17 | 32.41 | 61.71 | 208 |
| ✅ | [`opq_cross_drr_bursty_frame2_boundary_test`](REPORT/cross/opq_cross_drr_bursty_frame2_boundary_test.md) | cross | after | 1 | 74.17 | 66.17 | 21.83 | 59.27 | 8 |
| ✅ | [`opq_cross_mixed_bucket_random_soak_test`](REPORT/cross/opq_cross_mixed_bucket_random_soak_test.md) | cross | after | 1 | 81.78 | 77.86 | 47.20 | 72.05 | 2038 |
| ✅ | [`opq_cross_random_ready_overflow_step2_boundary_test`](REPORT/cross/opq_cross_random_ready_overflow_step2_boundary_test.md) | cross | after | 1 | 79.74 | 72.19 | 35.15 | 63.48 | 20 |
| ⚠️ | [`opq_error_counter_clear_test`](REPORT/cross/opq_error_counter_clear_test.md) | cross | after | 1 | 44.19 | 28.42 | 3.27 | 38.24 | 4 |
| ✅ | [`opq_error_ftable_overflow_test`](REPORT/cross/opq_error_ftable_overflow_test.md) | cross | after | 1 | 72.60 | 60.33 | 17.75 | 60.78 | 64 |

## Fixed baseline execution order

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

### all_buckets_frame

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
  `PROF` -> `extra_prof_seq` (whole-frame skew tail after the promoted matrix)
  `ERROR` -> `extra_err_seq` (subheader error recovery tail after the promoted matrix)
- limitation: This native-SV frame baseline runs the promoted internal UVM sequence matrix from `opq_frame_signoff_tests.sv`, not the full canonical isolated case catalog.
- limitation: The isolated B/E/P/X case ledger remains the authoritative per-case closure view; this run is continuous-frame carry-over evidence.

_Regenerate with `python3 tb/scripts/dv_report_gen_local.py --tb tb`._

# ⚠️ Config Signoff — packet_scheduler ordered_priority_queue

**DUT:** `ordered_priority_queue` &nbsp; **Date:** `2026-04-23` &nbsp;
**Release:** `26.3.66.0423`

This page is the configuration-legality and evidence matrix for
[`../script/ordered_priority_queue_hw.tcl`](../script/ordered_priority_queue_hw.tcl).
The `_hw.tcl` now constrains only the honest packaged contract. Wider ingress
hit words and wider packed DMA egress beats are recorded here as staged axes,
but they are not exposed as legal packaged points until RTL, synthesis, and DV
close together. The GUI now also exposes a representative preset selector:
nine selectable entries total, namely eight named presets plus `CUSTOM`, with
all concrete named presets pinned to
`N_SHD=128` and the safe current `32+4` ingress / `36`-bit egress contract.

## Legend

`✅` pass / closed
`⚠️` bounded evidence / partial / non-claim
`❌` blocked by current RTL or harness
`❓` not yet run
`ℹ️` analytic or descriptive only

## Packet Contract

Current packaged release uses one `36`-bit symbol per beat:

- `symbol = {datak[3:0], data[31:0]}`
- `header = 1 preamble + 4 header payload words`
- `payload = sum over subheaders of {1 subheader word + hit words}`
- `trailer = 1 trailer word`

Formalized packet shape:

`frame = header(5 symbols) + Σ_i[subheader_i(1 symbol) + hits_i] + trailer(1 symbol)`

| segment | symbols | marker | current packaged layout |
|---|---:|---|---|
| Header preamble | `1` | `K285` / `0xBC` | `datak=0001`, `data[31:26]=dt_type`, `data[23:8]=feb_id`, `data[7:0]=0xBC` |
| Header payload | `4` | data | `frame_ts`, packet serial/count fields, `send_ts` |
| Subheader | `1` each | `K237` / `0xF7` | `datak=0001`, `data[31:24]=subheader_ts`, `data[15:8]=hit_cnt`, `data[7:0]=0xF7` |
| Hit | `1` each | data | `datak=0000`, `data[31:0]=hit word`; packaged point is `32`-bit hit word with `24` payload / non-timestamp bits |
| Trailer | `1` | `K284` / `0x9C` | `datak=0001`, `data[7:0]=0x9C` |

## Active Top-Level Parameters

| group | parameter | current `_hw.tcl` policy | editable | notes |
|---|---|---|---|---|
| Presets | `PRESET` | `{CUSTOM,2LANE_BASE,2LANE_DEEP,4LANE_BASE,4LANE_DEEP,8LANE_BASE,8LANE_DEEP,16LANE_BASE,16LANE_DEEP}` | yes | Representative `_hw.tcl` GUI preset selector with nine selectable entries total. All concrete named presets pin `N_SHD=128`, keep the safe `32+4` ingress / `36`-bit egress contract, and scale `N_LANE` plus `LANE_FIFO_DEPTH`. |
| Aggregation | `N_LANE` | `{2,4,8,16}` | yes | Packaged legal lane points. Current measured DV/SYN evidence is not symmetric across all four points. |
| Aggregation | `MODE` | `{MERGING}` | no | Fixed in packaged release. |
| Aggregation | `TRACK_HEADER` | `{true}` | no | Fixed in packaged release. |
| Ingress format | `INGRESS_DATA_WIDTH` | `{32}` | no | Requested `64/128`-bit expansion is staged, not packaged. |
| Ingress format | `INGRESS_DATAK_WIDTH` | `{4}` | no | Must stay `INGRESS_DATA_WIDTH/8`. |
| Ingress format | `CHANNEL_WIDTH` | auto from `N_LANE` | no | Compatibility floor of `2`; maps `{2,4,8,16} -> {2,2,3,4}`. |
| Storage | `LANE_FIFO_DEPTH` | legacy power-of-two list, default `1024` | yes | Existing depth policy kept. |
| Storage | `LANE_FIFO_WIDTH` | auto = ingress symbol + 4 control bits | no | Current packaged point is `40`. |
| Storage | `TICKET_FIFO_DEPTH` | auto from `N_SHD` | no | Smallest power-of-two strictly above `N_SHD`, minimum `256`. |
| Storage | `HANDLE_FIFO_DEPTH` | auto fixed `64` | no | Kept fixed in packaged release. |
| Storage | `PAGE_RAM_DEPTH` | `{8192,16384,32768,65536}` | yes | Existing depth list kept. |
| Storage | `PAGE_RAM_RD_WIDTH` | auto = base ingress symbol width | no | Current packaged point is `36`; wider DMA packing is staged. |
| Packet geometry | `N_SHD` | `{64,128,256,512}` | yes | New packaged sweep. |
| Packet geometry | `N_HIT` | `{255,511,1023,2047}` | yes | Legal generic points retained from prior package. |
| Packet geometry | `HDR_SIZE` | `1:16`, default `5` | yes | Current packet contract uses `5` header words. |
| Packet geometry | `SHD_SIZE` | `1:16`, default `1` | yes | Current packet contract uses `1` subheader word. |
| Packet geometry | `HIT_SIZE` | `1:16`, default `1` | yes | Current packet contract uses `1` hit word. |
| Packet geometry | `TRL_SIZE` | `1:16`, default `1` | yes | Current packet contract uses `1` trailer word. |
| Packet geometry | `FRAME_SERIAL_SIZE` | `1:32`, default `16` | yes | Existing generic retained. |
| Packet geometry | `FRAME_SUBH_CNT_SIZE` | `1:32`, default `16` | yes | Existing generic retained. |
| Packet geometry | `FRAME_HIT_CNT_SIZE` | `1:32`, default `16` | yes | Existing generic retained. |
| Debug | `DEBUG_LV` | `{0,1,2}` | yes | Existing debug policy retained. |
| Identity | `IP_UID` | fixed packaged default | no | HDL-backed Mu3e UID. |
| Identity | `VERSION_MAJOR` | fixed packaged default | no | `26`. |
| Identity | `VERSION_MINOR` | fixed packaged default | no | `3`. |
| Identity | `VERSION_PATCH` | fixed packaged CSR META default | no | `29`; retained interface stamp packed into CSR META page 0 and not equal to the repo release suffix. |
| Identity | `BUILD` | fixed packaged CSR META default | no | `0420`; retained 12-bit CSR build stamp. |
| Identity | `VERSION_DATE` | fixed packaged CSR META default | no | `20260421`; CSR META page-1 date from the current hidden package defaults. |
| Identity | `VERSION_GIT` | fixed packaged CSR META default | no | `0xACB54C7D`; retained 32-bit provenance stamp exposed through CSR META page 2. |
| Identity | `INSTANCE_ID` | integrator override | yes | Only identity field left GUI-editable. |

## Configuration Matrix

This page now keeps only representative preset combinations. The authoritative
full Cartesian-product tracker for the matrix space lives in
[`../tb/scripts/gen_config_signoff_matrix.py`](../tb/scripts/gen_config_signoff_matrix.py).

Current independent space size:

- `N_LANE`: `4` points
- `INGRESS_DATA_WIDTH` / `INGRESS_DATAK_WIDTH`: `3` points
- egress packing factor: `4` points
- `N_SHD`: `4` points
- `N_HIT`: `4` points
- full space: `4 x 3 x 4 x 4 x 4 = 768` tuples

Useful generator commands:

- `python ../tb/scripts/gen_config_signoff_matrix.py --format summary`
- `python ../tb/scripts/gen_config_signoff_matrix.py --format csv --output /tmp/opq_config_space.csv`
- `python ../tb/scripts/gen_config_signoff_matrix.py --format md --only-packaged`

For the live packaged `36`-bit symbol contract, the equal-load Poisson
lossless per-lane hit-word ceiling remains

`(1 / N_LANE) * λ / (λ + 1 + 6/N_SHD)` hit words / cycle / lane

The full-space generator still tracks the staged wider-ingress and packed-DMA
axes for planning. The `_hw.tcl` preset selector intentionally does not expose
those width-varying presets yet because the current monolithic RTL still has
fixed `36`/`40`-bit assumptions in the ingress parser and basic presenter path.

### Full-Space Closure Accounting

These counts are the current release snapshot from the generator script. They
describe representative package-space accounting and historical measured points;
they are not the same thing as the active generated standalone `tb/` dashboard,
which now credits only the canonical current-scope `4-lane/128/256/native_sv`
reruns.

| metric | count | note |
|---|---:|---|
| Total tuples | `768` | Full independent cross-product. |
| Packaged legal tuples | `64` | `32+4` ingress, `1x` egress packing, `N_LANE={2,4,8,16}`, `N_SHD={64,128,256,512}`, `N_HIT={255,511,1023,2047}`. |
| Staged future tuples | `704` | Wider ingress and/or packed DMA points not yet exposed in `_hw.tcl`. |
| DV closed tuples | `3` | `2-lane` packaged points at `N_SHD={128,256,512}`, `N_HIT=255`. |
| DV bounded tuples | `2` | `2-lane/N_SHD=64` and `4-lane/N_SHD=256`, both at `N_HIT=255`. |
| DV open legal tuples | `59` | Remaining packaged tuples not yet closed in DV. |
| DV blocked staged tuples | `704` | Wider ingress / packed DMA tuples remain blocked by current RTL and harness. |
| SYN closed tuples | `2` | `2-lane/N_SHD=256/N_HIT=255` and `4-lane/N_SHD=256/N_HIT=255`. |
| SYN open legal tuples | `62` | Remaining packaged tuples have no standalone Quartus closure yet. |
| SYN blocked staged tuples | `704` | Wider ingress / packed DMA tuples remain blocked. |

### Representative Preset Matrix

Each preset column below corresponds to one of the concrete named `_hw.tcl`
GUI presets. `CUSTOM` is not shown because it is manual rather than a fixed
tuple. All concrete presets intentionally keep the safe current width contract:
`32 data + 4 datak` ingress and `36`-bit `1x` egress. Closure of the wider
future width axes remains tracked only by the generator script.

| group | point / summary | `2LANE_BASE` | `2LANE_DEEP` | `4LANE_BASE` | `4LANE_DEEP` | `8LANE_BASE` | `8LANE_DEEP` | `16LANE_BASE` | `16LANE_DEEP` |
|---|---|---|---|---|---|---|---|---|---|
| Profile | intent | 2L representative base preset | 2L representative deep preset | 4L representative base preset | 4L representative deep preset | 8L representative base preset | 8L representative deep preset | 16L representative base preset | 16L representative deep preset |
| Lane count | `N_LANE=2` | `●` | `●` |  |  |  |  |  |  |
| Lane count | `N_LANE=4` |  |  | `●` | `●` |  |  |  |  |
| Lane count | `N_LANE=8` |  |  |  |  | `●` | `●` |  |  |
| Lane count | `N_LANE=16` |  |  |  |  |  |  | `●` | `●` |
| Ingress symbol | `36b = 32 data + 4 datak` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Egress packing | `1x base = 36b` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Subheader count | `N_SHD=128` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Hits per subheader | `N_HIT=255` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Fixed contract | `MODE=MERGING`, `TRACK_HEADER=true` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Fixed contract | `HDR_SIZE=5`, `SHD_SIZE=1`, `HIT_SIZE=1`, `TRL_SIZE=1` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Auto-derived | `CHANNEL_WIDTH` | `2` | `2` | `2` | `2` | `3` | `3` | `4` | `4` |
| Auto-derived | `LANE_FIFO_DEPTH` | `1024` | `2048` | `2048` | `4096` | `4096` | `8192` | `8192` | `16384` |
| Auto-derived | `LANE_FIFO_WIDTH` | `40` | `40` | `40` | `40` | `40` | `40` | `40` | `40` |
| Auto-derived | `TICKET_FIFO_DEPTH` | `256` | `256` | `256` | `256` | `256` | `256` | `256` | `256` |
| Auto-derived | `HANDLE_FIFO_DEPTH` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` |
| Auto-derived | `PAGE_RAM_RD_WIDTH` | `36` | `36` | `36` | `36` | `36` | `36` | `36` | `36` |
| Signoff | package | `✅` | `✅` | `✅` | `✅` | `✅` | `✅` | `✅` | `✅` |
| Signoff | DV | `✅` | `❓` | `❓` | `❓` | `❓` | `❓` | `❓` | `❓` |
| Signoff | SYN | `❓` | `❓` | `❓` | `❓` | `❓` | `❓` | `❓` | `❓` |
| Signoff | slow WNS / hold | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | ALMs | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | M20Ks | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | raw share / lane | `18 bits/cycle` | `18 bits/cycle` | `9 bits/cycle` | `9 bits/cycle` | `4.5 bits/cycle` | `4.5 bits/cycle` | `2.25 bits/cycle` | `2.25 bits/cycle` |
| Signoff | lossless throughput / lane | `0.5λ / (λ + 1 + 6/128)` | `0.5λ / (λ + 1 + 6/128)` | `0.25λ / (λ + 1 + 6/128)` | `0.25λ / (λ + 1 + 6/128)` | `0.125λ / (λ + 1 + 6/128)` | `0.125λ / (λ + 1 + 6/128)` | `0.0625λ / (λ + 1 + 6/128)` | `0.0625λ / (λ + 1 + 6/128)` |
| Signoff | summary | GUI representative preset; `N_SHD=128` promoted DV point | GUI representative preset; deeper FIFO, closure open | GUI representative preset; closure open | GUI representative preset; deeper FIFO, closure open | GUI representative preset; closure open | GUI representative preset; deeper FIFO, closure open | GUI representative preset; closure open | GUI representative preset; deeper FIFO, closure open |

## Evidence Notes

- The active generated standalone dashboard is now the canonical current-scope
  `OPQ_N_LANE=4 OPQ_N_SHD=128 OPQ_TICKET_FIFO_DEPTH=256 DUT_IMPL=native_sv`
  rerun slice, and it currently carries `9` evidenced promoted isolated rows,
  `507` unimplemented rows, `8/8` maintained signoff runs, and no signoff-run
  failures.
- That current standalone dashboard is still not full package-space signoff:
  later lane/width expansion remains future work, but the active 4-lane/128
  maintained signoff-run slice is no longer blocked on missing testcase
  implementation for those promoted runs. The remaining
  raw structural deltas are documented in `tb/DV_COV.md` as explicit
  coverage-hole dispositions rather than treated as hidden evidence gaps.
- Historical 2-lane closure, bounded `N_SHD=64`, and bounded 4-lane points
  remain useful planning evidence for the matrix, but they are not mixed into
  the active generated standalone dashboard unless rerun in the current scope.
- Additional bounded 2-lane `N_SHD=64` evidence was run locally on
  `2026-04-20` with
  `OPQ_N_SHD=64 OPQ_TICKET_FIFO_DEPTH=256 bash tb/scripts/run_uvm.sh opq_basic_smoke_test opq_basic_ts_boundary_test opq_edge_max_hits_test`
  and ended `pass=3 fail=0 total=3`.
- Additional bounded 4-lane smoke evidence was run locally on `2026-04-20`
  with
  `OPQ_N_LANE=4 OPQ_N_SHD=256 OPQ_TICKET_FIFO_DEPTH=512 bash tb/scripts/run_uvm.sh opq_basic_smoke_test`
  and ended `pass=1 fail=0 total=1`.
- New 2-lane standalone synthesis evidence is captured in
  [`../syn/quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.fit.summary`](../syn/quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.fit.summary)
  and
  [`../syn/quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.sta.summary`](../syn/quartus/opq_native_sv_2lane_signoff/output_files/opq_native_sv_2lane_signoff.sta.summary).
- Existing 4-lane standalone synthesis evidence remains in
  [`../syn/quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.fit.summary`](../syn/quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.fit.summary)
  and
  [`../syn/quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.sta.summary`](../syn/quartus/opq_native_sv_4lane_signoff/output_files/opq_native_sv_4lane_signoff.sta.summary).
- Both standalone synthesis points use virtual pins in a local harness, so the
  quoted slack/Fmax numbers are core-internal standalone signoff numbers rather
  than board I/O timing closure numbers; see [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md).

## Packaging Outcome

- `_hw.tcl` now constrains the live packaged contract instead of advertising
  unsupported width points.
- Requested future axes are preserved here as staged, visible non-claims:
  `INGRESS_DATA_WIDTH={64,128}`, matching `datak`, and DMA-packed
  `PAGE_RAM_RD_WIDTH={4x,8x,16x}` base widths with `empty`.
- The honest packaged release for `26.3.66.0423` is therefore:
  `N_LANE={2,4,8,16}`, `MODE=MERGING`, `TRACK_HEADER=true`,
  `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`,
  `N_SHD={64,128,256,512}`, `N_HIT={255,511,1023,2047}`,
  with `CHANNEL_WIDTH`, `LANE_FIFO_WIDTH`, `TICKET_FIFO_DEPTH`,
  `HANDLE_FIFO_DEPTH`, and `PAGE_RAM_RD_WIDTH` auto-derived.

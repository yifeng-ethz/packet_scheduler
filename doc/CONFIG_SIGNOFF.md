# ⚠️ Config Signoff — packet_scheduler ordered_priority_queue

**DUT:** `ordered_priority_queue` &nbsp; **Date:** `2026-04-20` &nbsp;
**Release:** `26.3.28.0420`

This page is the configuration-legality and evidence matrix for
[`../script/ordered_priority_queue_hw.tcl`](../script/ordered_priority_queue_hw.tcl).
The `_hw.tcl` now constrains only the honest packaged contract. Wider ingress
hit words and wider packed DMA egress beats are recorded here as staged axes,
but they are not exposed as legal packaged points until RTL, synthesis, and DV
close together.

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
| Identity | `VERSION_PATCH` | fixed packaged default | no | `28`. |
| Identity | `BUILD` | fixed packaged default | no | `0420`. |
| Identity | `VERSION_DATE` | fixed packaged default | no | `20260420`. |
| Identity | `VERSION_GIT` | fixed packaged default | no | `0xACA41A1D`. |
| Identity | `INSTANCE_ID` | integrator override | yes | Only identity field left GUI-editable. |

## Configuration Matrix

Commercial-style feature matrix: each feature column picks exactly one point
from each parameter group. `●` marks the selected point for that group. The
bottom rows then summarize the realized auto-derived values and the current
signoff state.

This is a canonical feature-space matrix rather than the full Cartesian
product. Each column represents one advertised feature point against the
baseline packaged contract, which keeps the table readable while still showing
all active legal or requested staged axes.

For equal-load Poisson traffic with `λ = E[hits/subheader]`, the current
single-symbol egress gives an approximate lossless per-lane hit-word ceiling of

`(1 / N_LANE) * λ / (λ + 1 + 6/N_SHD)` hit words / cycle / lane

The raw symbol-share ceiling before packet overhead is simply
`36 / N_LANE` bits / cycle / lane.

| group | point / summary | `F00` | `F01` | `F02` | `F03` | `F04` | `F05` | `F06` | `F07` | `F08` | `F09` | `F10` | `F11` | `F12` | `F13` | `F14` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Profile | intent | 2L `N_SHD=64` | 2L `N_SHD=128` | 2L `N_SHD=256` | 2L `N_SHD=512` | 4L `N_SHD=256` | 8L `N_SHD=256` | 16L `N_SHD=256` | 2L `64b` ingress | 2L `128b` ingress | 2L `4x` DMA pack | 2L `8x` DMA pack | 2L `16x` DMA pack | 2L `N_HIT=511` | 2L `N_HIT=1023` | 2L `N_HIT=2047` |
| Lane count | `N_LANE=2` | `●` | `●` | `●` | `●` |  |  |  | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Lane count | `N_LANE=4` |  |  |  |  | `●` |  |  |  |  |  |  |  |  |  |  |
| Lane count | `N_LANE=8` |  |  |  |  |  | `●` |  |  |  |  |  |  |  |  |  |
| Lane count | `N_LANE=16` |  |  |  |  |  |  | `●` |  |  |  |  |  |  |  |  |
| Ingress symbol | `36b = 32 data + 4 datak` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |  |  | `●` | `●` | `●` | `●` | `●` | `●` |
| Ingress symbol | `72b = 64 data + 8 datak` |  |  |  |  |  |  |  | `●` |  |  |  |  |  |  |  |
| Ingress symbol | `144b = 128 data + 16 datak` |  |  |  |  |  |  |  |  | `●` |  |  |  |  |  |  |
| Egress packing | `1x base = 36b` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |  |  |  | `●` | `●` | `●` |
| Egress packing | `4x base = 144b + empty[1:0]` |  |  |  |  |  |  |  |  |  | `●` |  |  |  |  |  |
| Egress packing | `8x base = 288b + empty[2:0]` |  |  |  |  |  |  |  |  |  |  | `●` |  |  |  |  |
| Egress packing | `16x base = 576b + empty[3:0]` |  |  |  |  |  |  |  |  |  |  |  | `●` |  |  |  |
| Subheader count | `N_SHD=64` | `●` |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Subheader count | `N_SHD=128` |  | `●` |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Subheader count | `N_SHD=256` |  |  | `●` |  | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Subheader count | `N_SHD=512` |  |  |  | `●` |  |  |  |  |  |  |  |  |  |  |  |
| Hits per subheader | `N_HIT=255` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |  |  |  |
| Hits per subheader | `N_HIT=511` |  |  |  |  |  |  |  |  |  |  |  |  | `●` |  |  |
| Hits per subheader | `N_HIT=1023` |  |  |  |  |  |  |  |  |  |  |  |  |  | `●` |  |
| Hits per subheader | `N_HIT=2047` |  |  |  |  |  |  |  |  |  |  |  |  |  |  | `●` |
| Fixed contract | `MODE=MERGING` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Fixed contract | `TRACK_HEADER=true` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Fixed contract | `HDR_SIZE=5`, `SHD_SIZE=1`, `HIT_SIZE=1`, `TRL_SIZE=1` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Fixed contract | `FRAME_SERIAL_SIZE=16`, `FRAME_SUBH_CNT_SIZE=16`, `FRAME_HIT_CNT_SIZE=16` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` | `●` |
| Auto-derived | `CHANNEL_WIDTH` | `2` | `2` | `2` | `2` | `2` | `3` | `4` | `2` | `2` | `2` | `2` | `2` | `2` | `2` | `2` |
| Auto-derived | `LANE_FIFO_WIDTH` | `40` | `40` | `40` | `40` | `40` | `40` | `40` | `76` | `148` | `40` | `40` | `40` | `40` | `40` | `40` |
| Auto-derived | `TICKET_FIFO_DEPTH` | `256` | `256` | `512` | `1024` | `512` | `512` | `512` | `512` | `512` | `512` | `512` | `512` | `512` | `512` | `512` |
| Auto-derived | `HANDLE_FIFO_DEPTH` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` | `64` |
| Auto-derived | `PAGE_RAM_RD_WIDTH` | `36` | `36` | `36` | `36` | `36` | `36` | `36` | `72` | `144` | `144` | `288` | `576` | `36` | `36` | `36` |
| Signoff | packaged legality | `✅` | `✅` | `✅` | `✅` | `✅` | `✅` | `✅` | `❌` | `❌` | `❌` | `❌` | `❌` | `✅` | `✅` | `✅` |
| Signoff | DV status | `⚠️` | `✅` | `✅` | `✅` | `⚠️` | `❓` | `❓` | `❌` | `❌` | `❌` | `❌` | `❌` | `❓` | `❓` | `❓` |
| Signoff | SYN status | `❓` | `❓` | `✅` | `❓` | `✅` | `❓` | `❓` | `❌` | `❌` | `❌` | `❌` | `❌` | `❓` | `❓` | `❓` |
| Signoff | slow WNS / hold | `-` | `-` | `+0.172 / +0.044 ns` | `-` | `+0.008 / +0.043 ns` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | ALMs | `-` | `-` | `3,235` | `-` | `5,297` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | M20Ks | `-` | `-` | `129` | `-` | `141` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` | `-` |
| Signoff | raw share / lane | `18` | `18` | `18` | `18` | `9` | `4.5` | `2.25` | `18` | `18` | `18` | `18` | `18` | `18` | `18` | `18` |
| Signoff | lossless throughput / lane | `0.5λ / (λ + 1 + 6/64)` | `0.5λ / (λ + 1 + 6/128)` | `0.5λ / (λ + 1 + 6/256)` | `0.5λ / (λ + 1 + 6/512)` | `0.25λ / (λ + 1 + 6/256)` | `0.125λ / (λ + 1 + 6/256)` | `0.0625λ / (λ + 1 + 6/256)` | open | open | open | open | open | open | open | open |
| Signoff | summary | bounded-only 2-lane trio pass | promoted 2-lane DV claim | closed 2-lane DV + SYN point | promoted 2-lane DV claim | bounded 4-lane DV + closed SYN point | legal lane point, open | legal lane point, open | requested wider ingress, blocked by current RTL | requested wider ingress, blocked by current RTL | requested packed DMA, blocked by current RTL | requested packed DMA, blocked by current RTL | requested packed DMA, blocked by current RTL | legal `N_HIT` point, open | legal `N_HIT` point, open | legal `N_HIT` point, open |

## Evidence Notes

- Active promoted 2-lane DV claim remains anchored in
  [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md) and
  [`../tb/DV_COV.md`](../tb/DV_COV.md):
  `OPQ_N_LANE=2`, `MODE=MERGING`, `OPQ_N_SHD={128,256,512}`.
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
- The honest packaged release for `26.3.28.0420` is therefore:
  `N_LANE={2,4,8,16}`, `MODE=MERGING`, `TRACK_HEADER=true`,
  `INGRESS_DATA_WIDTH=32`, `INGRESS_DATAK_WIDTH=4`,
  `N_SHD={64,128,256,512}`, `N_HIT={255,511,1023,2047}`,
  with `CHANNEL_WIDTH`, `LANE_FIFO_WIDTH`, `TICKET_FIFO_DEPTH`,
  `HANDLE_FIFO_DEPTH`, and `PAGE_RAM_RD_WIDTH` auto-derived.

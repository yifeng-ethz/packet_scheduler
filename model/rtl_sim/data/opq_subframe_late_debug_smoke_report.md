# OPQ Subframe LATE_DROP Debug

RTL trace is treated as golden. Buckets are `(frame, lane, subheader)` unless the component is aggregate-only.

- Runs parsed: 1
- Summary rows: 20
- Detail rows: 120

## Component Status

| Mode | Component | PASS | DEBUG | Mean aggregate delta | Max aggregate delta | Mean bucket delta | Max bucket delta |
|---|---:|---:|---:|---:|---:|---:|---:|
| forced_ingress | controlled_predrop_exact_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | frame_table_hit_aggregate | 0 | 1 | 0.144861 | 0.144861 | 0.144861 | 0.144861 |
| forced_ingress | ingress_accept_hits | 0 | 1 | 0.244061 | 0.244061 | 0.323457 | 0.323457 |
| forced_ingress | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.369642 | 0.369642 |
| forced_ingress | ingress_predrop_flag_hits | 0 | 1 | 4.1757 | 4.1757 | 5.53411 | 5.53411 |
| forced_ingress | late_drop_control_exact_hits | 0 | 1 | 0.217665 | 0.217665 | 1.60217 | 1.60217 |
| forced_ingress | late_drop_pa_action_hits | 0 | 1 | 0.219608 | 0.219608 | 1.60038 | 1.60038 |
| forced_ingress | pa_load_hits | 0 | 1 | 0.144861 | 0.144861 | 0.303409 | 0.303409 |
| forced_ingress | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | transaction_deliver_hits | 0 | 1 | 0.144861 | 0.144861 | 0.303409 | 0.303409 |
| normal | controlled_predrop_exact_hits | 0 | 1 | 0.189698 | 0.189698 | 0.942367 | 0.942367 |
| normal | frame_table_hit_aggregate | 0 | 1 | 0.026304 | 0.026304 | 0.026304 | 0.026304 |
| normal | ingress_accept_hits | 0 | 1 | 0.301446 | 0.301446 | 0.335894 | 0.335894 |
| normal | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.409228 | 0.409228 |
| normal | ingress_predrop_flag_hits | 0 | 1 | 5.15752 | 5.15752 | 5.74689 | 5.74689 |
| normal | late_drop_control_exact_hits | 0 | 1 | 0.00776329 | 0.00776329 | 1.73092 | 1.73092 |
| normal | late_drop_pa_action_hits | 0 | 1 | 0.0102279 | 0.0102279 | 1.72911 | 1.72911 |
| normal | pa_load_hits | 0 | 1 | 0.026304 | 0.026304 | 0.491513 | 0.491513 |
| normal | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| normal | transaction_deliver_hits | 0 | 1 | 0.026304 | 0.026304 | 0.48776 | 0.48776 |

## First Mismatches

- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_accept_hits`: first=f73 l1 shd108 rtl=95042 tlm=66392 agg_delta=0.30144568 bucket_delta=0.3358936
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_predrop_flag_hits`: first=f73 l1 shd108 rtl=5555 tlm=34205 agg_delta=5.1575158 bucket_delta=5.7468947
- `component_b000_rho0750_f0261_seed7101` `normal` `controlled_predrop_exact_hits`: first=f73 l1 shd108 rtl=28751 tlm=34205 agg_delta=0.18969775 bucket_delta=0.94236722
- `component_b000_rho0750_f0261_seed7101` `normal` `pa_load_hits`: first=f2 l0 shd20 rtl=58090 tlm=59618 agg_delta=0.026304011 bucket_delta=0.49151317
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_pa_action_hits`: first=f2 l0 shd20 rtl=6844 tlm=6774 agg_delta=0.010227937 bucket_delta=1.7291058
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_control_exact_hits`: first=f2 l0 shd20 rtl=6827 tlm=6774 agg_delta=0.0077632928 bucket_delta=1.7309213
- `component_b000_rho0750_f0261_seed7101` `normal` `transaction_deliver_hits`: first=f2 l-1 shd16 rtl=58090 tlm=59618 agg_delta=0.026304011 bucket_delta=0.48776037
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_decision_ticket`: first=f73 l1 shd108 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.40922833
- `component_b000_rho0750_f0261_seed7101` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=58090 tlm=59618 agg_delta=0.026304011 bucket_delta=0.026304011
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_accept_hits`: first=f97 l3 shd118 rtl=95042 tlm=71846 agg_delta=0.24406052 bucket_delta=0.323457
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f97 l3 shd118 rtl=5555 tlm=28751 agg_delta=4.1756976 bucket_delta=5.5341134
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `pa_load_hits`: first=f2 l0 shd20 rtl=58090 tlm=66505 agg_delta=0.14486142 bucket_delta=0.3034085
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f2 l0 shd20 rtl=6844 tlm=5341 agg_delta=0.21960842 bucket_delta=1.6003799
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f2 l0 shd20 rtl=6827 tlm=5341 agg_delta=0.21766515 bucket_delta=1.6021679
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f2 l-1 shd16 rtl=58090 tlm=66505 agg_delta=0.14486142 bucket_delta=0.3034085
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f97 l3 shd118 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.369642
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=58090 tlm=66505 agg_delta=0.14486142 bucket_delta=0.14486142

## Run Metadata

- `component_b000_rho0750_f0261_seed7101`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=539228 forced_events=573242

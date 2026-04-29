# OPQ Subframe LATE_DROP Debug

RTL trace is treated as golden. Buckets are `(frame, lane, subheader)` unless the component is aggregate-only.

- Runs parsed: 1
- Summary rows: 20
- Detail rows: 128

## Component Status

| Mode | Component | PASS | DEBUG | Mean aggregate delta | Max aggregate delta | Mean bucket delta | Max bucket delta |
|---|---:|---:|---:|---:|---:|---:|---:|
| forced_ingress | controlled_predrop_exact_hits | 0 | 1 | 0.13123 | 0.13123 | 0.13123 | 0.13123 |
| forced_ingress | frame_table_hit_aggregate | 0 | 1 | 0.118024 | 0.118024 | 0.118024 | 0.118024 |
| forced_ingress | ingress_accept_hits | 0 | 1 | 0.283759 | 0.283759 | 0.283759 | 0.283759 |
| forced_ingress | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.278017 | 0.278017 |
| forced_ingress | ingress_predrop_flag_hits | 0 | 1 | 4.85491 | 4.85491 | 4.85491 | 4.85491 |
| forced_ingress | late_drop_control_exact_hits | 0 | 1 | 0.541966 | 0.541966 | 0.648308 | 0.648308 |
| forced_ingress | late_drop_pa_action_hits | 0 | 1 | 0.543103 | 0.543103 | 0.645383 | 0.645383 |
| forced_ingress | pa_load_hits | 0 | 1 | 0.118024 | 0.118024 | 0.130418 | 0.130418 |
| forced_ingress | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | transaction_deliver_hits | 0 | 1 | 0.118024 | 0.118024 | 0.130418 | 0.130418 |
| normal | controlled_predrop_exact_hits | 0 | 1 | 0.331223 | 0.331223 | 1.03367 | 1.03367 |
| normal | frame_table_hit_aggregate | 1 | 0 | 0.00134274 | 0.00134274 | 0.00134274 | 0.00134274 |
| normal | ingress_accept_hits | 0 | 1 | 0.344258 | 0.344258 | 0.38584 | 0.38584 |
| normal | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.469708 | 0.469708 |
| normal | ingress_predrop_flag_hits | 0 | 1 | 5.89001 | 5.89001 | 6.60144 | 6.60144 |
| normal | late_drop_control_exact_hits | 0 | 1 | 0.391387 | 0.391387 | 1.38099 | 1.38099 |
| normal | late_drop_pa_action_hits | 0 | 1 | 0.392899 | 0.392899 | 1.38004 | 1.38004 |
| normal | pa_load_hits | 0 | 1 | 0.00134274 | 0.00134274 | 0.450232 | 0.450232 |
| normal | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| normal | transaction_deliver_hits | 0 | 1 | 0.00134274 | 0.00134274 | 0.446789 | 0.446789 |

## First Mismatches

- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_accept_hits`: first=f63 l1 shd120 rtl=95042 tlm=62323 agg_delta=0.34425833 bucket_delta=0.38583994
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_predrop_flag_hits`: first=f63 l1 shd120 rtl=5555 tlm=38274 agg_delta=5.890009 bucket_delta=6.6014401
- `component_b000_rho0750_f0261_seed7101` `normal` `controlled_predrop_exact_hits`: first=f63 l1 shd120 rtl=28751 tlm=38274 agg_delta=0.33122326 bucket_delta=1.0336684
- `component_b000_rho0750_f0261_seed7101` `normal` `pa_load_hits`: first=f63 l1 shd120 rtl=58090 tlm=58168 agg_delta=0.001342744 bucket_delta=0.4502324
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_pa_action_hits`: first=f96 l0 shd0 rtl=6844 tlm=4155 agg_delta=0.39289889 bucket_delta=1.3800409
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_control_exact_hits`: first=f96 l0 shd0 rtl=6827 tlm=4155 agg_delta=0.39138714 bucket_delta=1.3809873
- `component_b000_rho0750_f0261_seed7101` `normal` `transaction_deliver_hits`: first=f63 l-1 shd120 rtl=58090 tlm=58168 agg_delta=0.001342744 bucket_delta=0.44678946
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_decision_ticket`: first=f63 l1 shd120 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.46970785
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_accept_hits`: first=f97 l3 shd118 rtl=95042 tlm=68073 agg_delta=0.28375876 bucket_delta=0.28375876
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f97 l3 shd118 rtl=5555 tlm=32524 agg_delta=4.8549055 bucket_delta=4.8549055
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `controlled_predrop_exact_hits`: first=f166 l1 shd101 rtl=28751 tlm=32524 agg_delta=0.13123022 bucket_delta=0.13123022
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `pa_load_hits`: first=f170 l0 shd2 rtl=58090 tlm=64946 agg_delta=0.11802376 bucket_delta=0.13041832
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f168 l1 shd57 rtl=6844 tlm=3127 agg_delta=0.54310345 bucket_delta=0.64538282
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f137 l2 shd121 rtl=6827 tlm=3127 agg_delta=0.54196572 bucket_delta=0.64830819
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f170 l-1 shd0 rtl=58090 tlm=64946 agg_delta=0.11802376 bucket_delta=0.13041832
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f97 l3 shd118 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.27801724
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=58090 tlm=64946 agg_delta=0.11802376 bucket_delta=0.11802376

## Run Metadata

- `component_b000_rho0750_f0261_seed7101`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=547746 forced_events=580141

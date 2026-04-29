# OPQ Subframe LATE_DROP Debug

RTL trace is treated as golden. Buckets are `(frame, lane, subheader)` unless the component is aggregate-only.

- Runs parsed: 1
- Summary rows: 20
- Detail rows: 128

## Component Status

| Mode | Component | PASS | DEBUG | Mean aggregate delta | Max aggregate delta | Mean bucket delta | Max bucket delta |
|---|---:|---:|---:|---:|---:|---:|---:|
| forced_ingress | controlled_predrop_exact_hits | 0 | 1 | 0.13123 | 0.13123 | 0.13123 | 0.13123 |
| forced_ingress | frame_table_hit_aggregate | 0 | 1 | 0.0966087 | 0.0966087 | 0.0966087 | 0.0966087 |
| forced_ingress | ingress_accept_hits | 0 | 1 | 0.283759 | 0.283759 | 0.283759 | 0.283759 |
| forced_ingress | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.278017 | 0.278017 |
| forced_ingress | ingress_predrop_flag_hits | 0 | 1 | 4.85491 | 4.85491 | 4.85491 | 4.85491 |
| forced_ingress | late_drop_control_exact_hits | 0 | 1 | 0.359748 | 0.359748 | 0.727699 | 0.727699 |
| forced_ingress | late_drop_pa_action_hits | 0 | 1 | 0.361338 | 0.361338 | 0.723407 | 0.723407 |
| forced_ingress | pa_load_hits | 0 | 1 | 0.0966087 | 0.0966087 | 0.139611 | 0.139611 |
| forced_ingress | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | transaction_deliver_hits | 0 | 1 | 0.0966087 | 0.0966087 | 0.139611 | 0.139611 |
| normal | controlled_predrop_exact_hits | 0 | 1 | 0.28239 | 0.28239 | 0.95388 | 0.95388 |
| normal | frame_table_hit_aggregate | 1 | 0 | 0.00585299 | 0.00585299 | 0.00585299 | 0.00585299 |
| normal | ingress_accept_hits | 0 | 1 | 0.329486 | 0.329486 | 0.365049 | 0.365049 |
| normal | ingress_decision_ticket | 0 | 1 | 0 | 0 | 0.44202 | 0.44202 |
| normal | ingress_predrop_flag_hits | 0 | 1 | 5.63726 | 5.63726 | 6.24572 | 6.24572 |
| normal | late_drop_control_exact_hits | 0 | 1 | 0.22411 | 0.22411 | 1.52717 | 1.52717 |
| normal | late_drop_pa_action_hits | 0 | 1 | 0.226037 | 0.226037 | 1.52586 | 1.52586 |
| normal | pa_load_hits | 0 | 1 | 0.00585299 | 0.00585299 | 0.486521 | 0.486521 |
| normal | source_hits | 1 | 0 | 0 | 0 | 0 | 0 |
| normal | transaction_deliver_hits | 0 | 1 | 0.00585299 | 0.00585299 | 0.481976 | 0.481976 |

## First Mismatches

- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_accept_hits`: first=f63 l1 shd120 rtl=95042 tlm=63727 agg_delta=0.32948591 bucket_delta=0.36504914
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_predrop_flag_hits`: first=f63 l1 shd120 rtl=5555 tlm=36870 agg_delta=5.6372637 bucket_delta=6.2457246
- `component_b000_rho0750_f0261_seed7101` `normal` `controlled_predrop_exact_hits`: first=f63 l1 shd120 rtl=28751 tlm=36870 agg_delta=0.28239018 bucket_delta=0.95387987
- `component_b000_rho0750_f0261_seed7101` `normal` `pa_load_hits`: first=f63 l1 shd120 rtl=58090 tlm=58430 agg_delta=0.0058529867 bucket_delta=0.48652092
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_pa_action_hits`: first=f68 l0 shd1 rtl=6844 tlm=5297 agg_delta=0.22603741 bucket_delta=1.5258621
- `component_b000_rho0750_f0261_seed7101` `normal` `late_drop_control_exact_hits`: first=f68 l0 shd1 rtl=6827 tlm=5297 agg_delta=0.22411015 bucket_delta=1.5271715
- `component_b000_rho0750_f0261_seed7101` `normal` `transaction_deliver_hits`: first=f63 l-1 shd120 rtl=58090 tlm=58430 agg_delta=0.0058529867 bucket_delta=0.48197624
- `component_b000_rho0750_f0261_seed7101` `normal` `ingress_decision_ticket`: first=f63 l1 shd120 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.44201988
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_accept_hits`: first=f97 l3 shd118 rtl=95042 tlm=68073 agg_delta=0.28375876 bucket_delta=0.28375876
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f97 l3 shd118 rtl=5555 tlm=32524 agg_delta=4.8549055 bucket_delta=4.8549055
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `controlled_predrop_exact_hits`: first=f166 l1 shd101 rtl=28751 tlm=32524 agg_delta=0.13123022 bucket_delta=0.13123022
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `pa_load_hits`: first=f98 l1 shd0 rtl=58090 tlm=63702 agg_delta=0.096608711 bucket_delta=0.13961095
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f98 l1 shd0 rtl=6844 tlm=4371 agg_delta=0.3613384 bucket_delta=0.72340736
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f98 l1 shd0 rtl=6827 tlm=4371 agg_delta=0.35974806 bucket_delta=0.72769884
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f98 l-1 shd0 rtl=58090 tlm=63702 agg_delta=0.096608711 bucket_delta=0.13961095
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f97 l3 shd118 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.27801724
- `component_b000_rho0750_f0261_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=58090 tlm=63702 agg_delta=0.096608711 bucket_delta=0.096608711

## Run Metadata

- `component_b000_rho0750_f0261_seed7101`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=555030 forced_events=577863

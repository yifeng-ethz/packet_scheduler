# OPQ Subframe LATE_DROP Debug

RTL trace is treated as golden. Buckets are `(frame, lane, subheader)` unless the component is aggregate-only.

- Runs parsed: 12
- Summary rows: 240
- Detail rows: 1440

## Component Status

| Mode | Component | PASS | DEBUG | Mean aggregate delta | Max aggregate delta | Mean bucket delta | Max bucket delta |
|---|---:|---:|---:|---:|---:|---:|---:|
| forced_ingress | controlled_predrop_exact_hits | 12 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | frame_table_hit_aggregate | 0 | 12 | 0.189658 | 0.300198 | 0.189658 | 0.300198 |
| forced_ingress | ingress_accept_hits | 0 | 12 | 0.183774 | 0.283666 | 0.296984 | 0.349604 |
| forced_ingress | ingress_decision_ticket | 0 | 12 | 0 | 0 | 0.328881 | 0.406218 |
| forced_ingress | ingress_predrop_flag_hits | 0 | 12 | 2.8697 | 6.01632 | 4.11551 | 7.41238 |
| forced_ingress | late_drop_control_exact_hits | 0 | 12 | 0.65967 | 1 | 1.41316 | 2.29813 |
| forced_ingress | late_drop_pa_action_hits | 0 | 12 | 0.659081 | 1 | 1.41027 | 2.28582 |
| forced_ingress | pa_load_hits | 0 | 12 | 0.189658 | 0.300198 | 0.276021 | 0.303409 |
| forced_ingress | source_hits | 12 | 0 | 0 | 0 | 0 | 0 |
| forced_ingress | transaction_deliver_hits | 0 | 12 | 0.189658 | 0.300198 | 0.276018 | 0.303409 |
| normal | controlled_predrop_exact_hits | 0 | 12 | 0.193466 | 0.307488 | 1.02141 | 1.24744 |
| normal | frame_table_hit_aggregate | 0 | 12 | 0.088362 | 0.185625 | 0.088362 | 0.185625 |
| normal | ingress_accept_hits | 0 | 12 | 0.236771 | 0.341069 | 0.321056 | 0.359982 |
| normal | ingress_decision_ticket | 0 | 12 | 0 | 0 | 0.377384 | 0.442156 |
| normal | ingress_predrop_flag_hits | 0 | 12 | 3.58186 | 7.45364 | 4.36201 | 7.8141 |
| normal | late_drop_control_exact_hits | 0 | 12 | 0.471464 | 0.999001 | 1.64706 | 2.62946 |
| normal | late_drop_pa_action_hits | 0 | 12 | 0.470699 | 0.991542 | 1.64394 | 2.61592 |
| normal | pa_load_hits | 0 | 12 | 0.088362 | 0.185625 | 0.479213 | 0.511013 |
| normal | source_hits | 12 | 0 | 0 | 0 | 0 | 0 |
| normal | transaction_deliver_hits | 0 | 12 | 0.088362 | 0.185625 | 0.475918 | 0.5083 |

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
- `component_b000_rho0750_f0261_seed7102` `normal` `ingress_accept_hits`: first=f73 l1 shd83 rtl=93652 tlm=66597 agg_delta=0.28888865 bucket_delta=0.33918122
- `component_b000_rho0750_f0261_seed7102` `normal` `ingress_predrop_flag_hits`: first=f73 l1 shd83 rtl=6574 tlm=33629 agg_delta=4.1154548 bucket_delta=4.8319136
- `component_b000_rho0750_f0261_seed7102` `normal` `controlled_predrop_exact_hits`: first=f73 l1 shd83 rtl=29905 tlm=33629 agg_delta=0.12452767 bucket_delta=0.87965223
- `component_b000_rho0750_f0261_seed7102` `normal` `pa_load_hits`: first=f2 l0 shd9 rtl=56884 tlm=60058 agg_delta=0.055797764 bucket_delta=0.49743337
- `component_b000_rho0750_f0261_seed7102` `normal` `late_drop_pa_action_hits`: first=f2 l0 shd9 rtl=7157 tlm=6539 agg_delta=0.086349029 bucket_delta=1.6059802
- `component_b000_rho0750_f0261_seed7102` `normal` `late_drop_control_exact_hits`: first=f2 l0 shd9 rtl=7142 tlm=6539 agg_delta=0.084430132 bucket_delta=1.6072529
- `component_b000_rho0750_f0261_seed7102` `normal` `transaction_deliver_hits`: first=f2 l-1 shd9 rtl=56884 tlm=60058 agg_delta=0.055797764 bucket_delta=0.49367133
- `component_b000_rho0750_f0261_seed7102` `normal` `ingress_decision_ticket`: first=f73 l1 shd83 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.41234136
- `component_b000_rho0750_f0261_seed7102` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=56884 tlm=60058 agg_delta=0.055797764 bucket_delta=0.055797764
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `ingress_accept_hits`: first=f95 l3 shd122 rtl=93652 tlm=70321 agg_delta=0.24912442 bucket_delta=0.34821467
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `ingress_predrop_flag_hits`: first=f95 l3 shd122 rtl=6574 tlm=29905 agg_delta=3.5489808 bucket_delta=4.9606024
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `pa_load_hits`: first=f2 l0 shd9 rtl=56884 tlm=65486 agg_delta=0.15122003 bucket_delta=0.29783419
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `late_drop_pa_action_hits`: first=f2 l0 shd9 rtl=7157 tlm=4835 agg_delta=0.32443761 bucket_delta=1.491407
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `late_drop_control_exact_hits`: first=f2 l0 shd9 rtl=7142 tlm=4835 agg_delta=0.32301876 bucket_delta=1.4929992
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `transaction_deliver_hits`: first=f2 l-1 shd9 rtl=56884 tlm=65486 agg_delta=0.15122003 bucket_delta=0.29779903
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `ingress_decision_ticket`: first=f95 l3 shd122 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.40017361
- `component_b000_rho0750_f0261_seed7102` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=56884 tlm=65486 agg_delta=0.15122003 bucket_delta=0.15122003
- `component_b000_rho0750_f0261_seed7103` `normal` `ingress_accept_hits`: first=f75 l3 shd90 rtl=94625 tlm=66986 agg_delta=0.29208983 bucket_delta=0.33541876
- `component_b000_rho0750_f0261_seed7103` `normal` `ingress_predrop_flag_hits`: first=f75 l3 shd90 rtl=5687 tlm=33326 agg_delta=4.8600317 bucket_delta=5.5809742
- `component_b000_rho0750_f0261_seed7103` `normal` `controlled_predrop_exact_hits`: first=f75 l3 shd90 rtl=28546 tlm=33326 agg_delta=0.16744903 bucket_delta=0.92153016
- `component_b000_rho0750_f0261_seed7103` `normal` `pa_load_hits`: first=f0 l2 shd127 rtl=58523 tlm=59246 agg_delta=0.012354117 bucket_delta=0.49694992
- `component_b000_rho0750_f0261_seed7103` `normal` `late_drop_pa_action_hits`: first=f0 l2 shd127 rtl=6690 tlm=7740 agg_delta=0.15695067 bucket_delta=1.6729447
- `component_b000_rho0750_f0261_seed7103` `normal` `late_drop_control_exact_hits`: first=f0 l2 shd127 rtl=6672 tlm=7740 agg_delta=0.16007194 bucket_delta=1.6789568
- `component_b000_rho0750_f0261_seed7103` `normal` `transaction_deliver_hits`: first=f0 l-1 shd127 rtl=58523 tlm=59246 agg_delta=0.012354117 bucket_delta=0.49363498
- `component_b000_rho0750_f0261_seed7103` `normal` `ingress_decision_ticket`: first=f75 l3 shd90 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.40551664
- `component_b000_rho0750_f0261_seed7103` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=58523 tlm=59246 agg_delta=0.012354117 bucket_delta=0.012354117
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `ingress_accept_hits`: first=f95 l0 shd116 rtl=94625 tlm=71766 agg_delta=0.24157464 bucket_delta=0.32368824
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `ingress_predrop_flag_hits`: first=f95 l0 shd116 rtl=5687 tlm=28546 agg_delta=4.0195182 bucket_delta=5.3857922
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `pa_load_hits`: first=f0 l2 shd127 rtl=58523 tlm=66217 agg_delta=0.13146968 bucket_delta=0.29280796
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `late_drop_pa_action_hits`: first=f0 l2 shd127 rtl=6690 tlm=5549 agg_delta=0.17055306 bucket_delta=1.6177877
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `late_drop_control_exact_hits`: first=f0 l2 shd127 rtl=6672 tlm=5549 agg_delta=0.16831535 bucket_delta=1.6221523
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `transaction_deliver_hits`: first=f0 l-1 shd127 rtl=58523 tlm=66217 agg_delta=0.13146968 bucket_delta=0.29280796
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `ingress_decision_ticket`: first=f95 l0 shd116 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.37271013
- `component_b000_rho0750_f0261_seed7103` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=58523 tlm=66217 agg_delta=0.13146968 bucket_delta=0.13146968
- `component_b000_rho0800_f0245_seed7101` `normal` `ingress_accept_hits`: first=f70 l1 shd73 rtl=96397 tlm=63519 agg_delta=0.34106871 bucket_delta=0.35756299
- `component_b000_rho0800_f0245_seed7101` `normal` `ingress_predrop_flag_hits`: first=f70 l1 shd73 rtl=4411 tlm=37289 agg_delta=7.4536386 bucket_delta=7.8141011
- `component_b000_rho0800_f0245_seed7101` `normal` `controlled_predrop_exact_hits`: first=f70 l1 shd73 rtl=30949 tlm=37289 agg_delta=0.20485315 bucket_delta=0.8163107
- `component_b000_rho0800_f0245_seed7101` `normal` `pa_load_hits`: first=f0 l0 shd126 rtl=59675 tlm=54676 agg_delta=0.083770423 bucket_delta=0.41090909
- `component_b000_rho0800_f0245_seed7101` `normal` `late_drop_pa_action_hits`: first=f0 l0 shd126 rtl=4800 tlm=8843 agg_delta=0.84229167 bucket_delta=2.2464583
- `component_b000_rho0800_f0245_seed7101` `normal` `late_drop_control_exact_hits`: first=f0 l0 shd126 rtl=4796 tlm=8843 agg_delta=0.84382819 bucket_delta=2.2479149
- `component_b000_rho0800_f0245_seed7101` `normal` `transaction_deliver_hits`: first=f0 l-1 shd126 rtl=59675 tlm=54676 agg_delta=0.083770423 bucket_delta=0.40547968
- `component_b000_rho0800_f0245_seed7101` `normal` `ingress_decision_ticket`: first=f70 l1 shd73 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.44215561
- `component_b000_rho0800_f0245_seed7101` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=59675 tlm=54676 agg_delta=0.083770423 bucket_delta=0.083770423
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `ingress_accept_hits`: first=f90 l3 shd101 rtl=96397 tlm=69859 agg_delta=0.27529902 bucket_delta=0.33918068
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f90 l3 shd101 rtl=4411 tlm=30949 agg_delta=6.0163228 bucket_delta=7.4123781
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `pa_load_hits`: first=f0 l0 shd126 rtl=59675 tlm=63780 agg_delta=0.068789275 bucket_delta=0.25707583
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f0 l0 shd126 rtl=4800 tlm=6079 agg_delta=0.26645833 bucket_delta=2.0964583
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f0 l0 shd126 rtl=4796 tlm=6079 agg_delta=0.2675146 bucket_delta=2.0990409
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f0 l-1 shd126 rtl=59675 tlm=63780 agg_delta=0.068789275 bucket_delta=0.25707583
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f90 l3 shd101 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.3917889
- `component_b000_rho0800_f0245_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=59675 tlm=63780 agg_delta=0.068789275 bucket_delta=0.068789275
- `component_b000_rho0800_f0245_seed7102` `normal` `ingress_accept_hits`: first=f70 l1 shd23 rtl=95877 tlm=63643 agg_delta=0.33620159 bucket_delta=0.35998206
- `component_b000_rho0800_f0245_seed7102` `normal` `ingress_predrop_flag_hits`: first=f70 l1 shd23 rtl=4523 tlm=36757 agg_delta=7.1266858 bucket_delta=7.630776
- `component_b000_rho0800_f0245_seed7102` `normal` `controlled_predrop_exact_hits`: first=f70 l1 shd23 rtl=31720 tlm=36757 agg_delta=0.15879571 bucket_delta=0.79763556
- `component_b000_rho0800_f0245_seed7102` `normal` `pa_load_hits`: first=f0 l0 shd117 rtl=58758 tlm=55038 agg_delta=0.063310528 bucket_delta=0.44637326
- `component_b000_rho0800_f0245_seed7102` `normal` `late_drop_pa_action_hits`: first=f0 l0 shd117 rtl=5226 tlm=8605 agg_delta=0.64657482 bucket_delta=2.1215078
- `component_b000_rho0800_f0245_seed7102` `normal` `late_drop_control_exact_hits`: first=f0 l0 shd117 rtl=5204 tlm=8605 agg_delta=0.65353574 bucket_delta=2.1300922
- `component_b000_rho0800_f0245_seed7102` `normal` `transaction_deliver_hits`: first=f0 l-1 shd117 rtl=58758 tlm=55038 agg_delta=0.063310528 bucket_delta=0.44181218
- `component_b000_rho0800_f0245_seed7102` `normal` `ingress_decision_ticket`: first=f70 l1 shd23 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.43518814
- `component_b000_rho0800_f0245_seed7102` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=58758 tlm=55038 agg_delta=0.063310528 bucket_delta=0.063310528
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `ingress_accept_hits`: first=f90 l2 shd120 rtl=95877 tlm=68680 agg_delta=0.28366553 bucket_delta=0.34960418
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `ingress_predrop_flag_hits`: first=f90 l2 shd120 rtl=4523 tlm=31720 agg_delta=6.0130444 bucket_delta=7.4107893
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `pa_load_hits`: first=f0 l0 shd117 rtl=58758 tlm=61687 agg_delta=0.049848531 bucket_delta=0.24223085
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `late_drop_pa_action_hits`: first=f0 l0 shd117 rtl=5226 tlm=6993 agg_delta=0.33811711 bucket_delta=1.8314198
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `late_drop_control_exact_hits`: first=f0 l0 shd117 rtl=5204 tlm=6993 agg_delta=0.34377402 bucket_delta=1.8433897
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `transaction_deliver_hits`: first=f0 l-1 shd117 rtl=58758 tlm=61687 agg_delta=0.049848531 bucket_delta=0.24223085
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `ingress_decision_ticket`: first=f90 l2 shd120 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.40621811
- `component_b000_rho0800_f0245_seed7102` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=58758 tlm=61687 agg_delta=0.049848531 bucket_delta=0.049848531
- `component_b000_rho0800_f0245_seed7103` `normal` `ingress_accept_hits`: first=f71 l3 shd99 rtl=95972 tlm=64282 agg_delta=0.33020048 bucket_delta=0.35552036
- `component_b000_rho0800_f0245_seed7103` `normal` `ingress_predrop_flag_hits`: first=f71 l3 shd99 rtl=4449 tlm=36139 agg_delta=7.122949 bucket_delta=7.6691391
- `component_b000_rho0800_f0245_seed7103` `normal` `controlled_predrop_exact_hits`: first=f71 l3 shd99 rtl=30393 tlm=36139 agg_delta=0.18905669 bucket_delta=0.83907479
- `component_b000_rho0800_f0245_seed7103` `normal` `pa_load_hits`: first=f0 l2 shd123 rtl=60165 tlm=56276 agg_delta=0.06463891 bucket_delta=0.44030583
- `component_b000_rho0800_f0245_seed7103` `normal` `late_drop_pa_action_hits`: first=f0 l2 shd123 rtl=4020 tlm=8006 agg_delta=0.99154229 bucket_delta=2.6159204
- `component_b000_rho0800_f0245_seed7103` `normal` `late_drop_control_exact_hits`: first=f0 l2 shd123 rtl=4005 tlm=8006 agg_delta=0.99900125 bucket_delta=2.6294632
- `component_b000_rho0800_f0245_seed7103` `normal` `transaction_deliver_hits`: first=f0 l-1 shd123 rtl=60165 tlm=56276 agg_delta=0.06463891 bucket_delta=0.43561872
- `component_b000_rho0800_f0245_seed7103` `normal` `ingress_decision_ticket`: first=f71 l3 shd99 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.42345344
- `component_b000_rho0800_f0245_seed7103` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=60165 tlm=56276 agg_delta=0.06463891 bucket_delta=0.06463891
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `ingress_accept_hits`: first=f90 l0 shd85 rtl=95972 tlm=70028 agg_delta=0.27032885 bucket_delta=0.33605635
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `ingress_predrop_flag_hits`: first=f90 l0 shd85 rtl=4449 tlm=30393 agg_delta=5.8314228 bucket_delta=7.2492695
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `pa_load_hits`: first=f0 l2 shd123 rtl=60165 tlm=63637 agg_delta=0.05770797 bucket_delta=0.24688773
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `late_drop_pa_action_hits`: first=f0 l2 shd123 rtl=4020 tlm=6391 agg_delta=0.589801 bucket_delta=2.2858209
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `late_drop_control_exact_hits`: first=f0 l2 shd123 rtl=4005 tlm=6391 agg_delta=0.59575531 bucket_delta=2.2981273
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `transaction_deliver_hits`: first=f0 l-1 shd123 rtl=60165 tlm=63637 agg_delta=0.05770797 bucket_delta=0.24688773
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `ingress_decision_ticket`: first=f90 l0 shd85 accept rtl=125440 tlm=125440 agg_delta=0 bucket_delta=0.38858418
- `component_b000_rho0800_f0245_seed7103` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=60165 tlm=63637 agg_delta=0.05770797 bucket_delta=0.05770797
- `component_b403_rho0750_f0261_seed7101` `normal` `ingress_accept_hits`: first=f79 l3 shd125 rtl=89136 tlm=71726 agg_delta=0.19531951 bucket_delta=0.30349129
- `component_b403_rho0750_f0261_seed7101` `normal` `ingress_predrop_flag_hits`: first=f79 l3 shd125 rtl=10823 tlm=28233 agg_delta=1.6086113 bucket_delta=2.4994918
- `component_b403_rho0750_f0261_seed7101` `normal` `controlled_predrop_exact_hits`: first=f79 l3 shd125 rtl=23262 tlm=28233 agg_delta=0.21369616 bucket_delta=1.0962514
- `component_b403_rho0750_f0261_seed7101` `normal` `pa_load_hits`: first=f79 l3 shd125 rtl=59413 tlm=68268 agg_delta=0.14904146 bucket_delta=0.48199889
- `component_b403_rho0750_f0261_seed7101` `normal` `late_drop_pa_action_hits`: first=f133 l1 shd4 rtl=9263 tlm=3458 agg_delta=0.62668682 bucket_delta=1.1984238
- `component_b403_rho0750_f0261_seed7101` `normal` `late_drop_control_exact_hits`: first=f133 l1 shd4 rtl=9247 tlm=3458 agg_delta=0.62604088 bucket_delta=1.1996323
- `component_b403_rho0750_f0261_seed7101` `normal` `transaction_deliver_hits`: first=f79 l-1 shd125 rtl=59413 tlm=68268 agg_delta=0.14904146 bucket_delta=0.47836332
- `component_b403_rho0750_f0261_seed7101` `normal` `ingress_decision_ticket`: first=f79 l3 shd125 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.32986111
- `component_b403_rho0750_f0261_seed7101` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=59413 tlm=68268 agg_delta=0.14904146 bucket_delta=0.14904146
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `ingress_accept_hits`: first=f99 l3 shd63 rtl=89136 tlm=76697 agg_delta=0.1395508 bucket_delta=0.27969619
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f99 l3 shd63 rtl=10823 tlm=23262 agg_delta=1.1493117 bucket_delta=2.3035203
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `pa_load_hits`: first=f155 l0 shd117 rtl=59413 tlm=76697 agg_delta=0.29091276 bucket_delta=0.29091276
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f157 l0 shd12 rtl=9263 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f157 l0 shd12 rtl=9247 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f155 l-1 shd86 rtl=59413 tlm=76697 agg_delta=0.29091276 bucket_delta=0.29091276
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f99 l3 shd63 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.27051904
- `component_b403_rho0750_f0261_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=59413 tlm=76697 agg_delta=0.29091276 bucket_delta=0.29091276
- `component_b403_rho0750_f0261_seed7102` `normal` `ingress_accept_hits`: first=f72 l1 shd120 rtl=89285 tlm=70893 agg_delta=0.20599205 bucket_delta=0.31360251
- `component_b403_rho0750_f0261_seed7102` `normal` `ingress_predrop_flag_hits`: first=f72 l1 shd120 rtl=10680 tlm=29072 agg_delta=1.7220974 bucket_delta=2.6217228
- `component_b403_rho0750_f0261_seed7102` `normal` `controlled_predrop_exact_hits`: first=f72 l1 shd120 rtl=22235 tlm=29072 agg_delta=0.30748819 bucket_delta=1.2201034
- `component_b403_rho0750_f0261_seed7102` `normal` `pa_load_hits`: first=f72 l1 shd120 rtl=62214 tlm=66589 agg_delta=0.070321793 bucket_delta=0.46399524
- `component_b403_rho0750_f0261_seed7102` `normal` `late_drop_pa_action_hits`: first=f136 l0 shd3 rtl=7731 tlm=4304 agg_delta=0.4432803 bucket_delta=1.3352736
- `component_b403_rho0750_f0261_seed7102` `normal` `late_drop_control_exact_hits`: first=f136 l0 shd3 rtl=7715 tlm=4304 agg_delta=0.44212573 bucket_delta=1.3359689
- `component_b403_rho0750_f0261_seed7102` `normal` `transaction_deliver_hits`: first=f72 l-1 shd120 rtl=62214 tlm=66589 agg_delta=0.070321793 bucket_delta=0.46119844
- `component_b403_rho0750_f0261_seed7102` `normal` `ingress_decision_ticket`: first=f72 l1 shd120 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.35293942
- `component_b403_rho0750_f0261_seed7102` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=62214 tlm=66589 agg_delta=0.070321793 bucket_delta=0.070321793
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `ingress_accept_hits`: first=f101 l2 shd111 rtl=89285 tlm=77730 agg_delta=0.12941704 bucket_delta=0.26536372
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `ingress_predrop_flag_hits`: first=f101 l2 shd111 rtl=10680 tlm=22235 agg_delta=1.0819288 bucket_delta=2.2184457
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `pa_load_hits`: first=f156 l1 shd103 rtl=62214 tlm=77730 agg_delta=0.24939724 bucket_delta=0.24939724
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `late_drop_pa_action_hits`: first=f159 l0 shd2 rtl=7731 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `late_drop_control_exact_hits`: first=f159 l0 shd2 rtl=7715 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `transaction_deliver_hits`: first=f156 l-1 shd103 rtl=62214 tlm=77730 agg_delta=0.24939724 bucket_delta=0.24939724
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `ingress_decision_ticket`: first=f101 l2 shd111 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.26138949
- `component_b403_rho0750_f0261_seed7102` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=62214 tlm=77730 agg_delta=0.24939724 bucket_delta=0.24939724
- `component_b403_rho0750_f0261_seed7103` `normal` `ingress_accept_hits`: first=f76 l0 shd119 rtl=89060 tlm=74731 agg_delta=0.16089153 bucket_delta=0.29944981
- `component_b403_rho0750_f0261_seed7103` `normal` `ingress_predrop_flag_hits`: first=f76 l0 shd119 rtl=12203 tlm=26532 agg_delta=1.1742195 bucket_delta=2.1854462
- `component_b403_rho0750_f0261_seed7103` `normal` `controlled_predrop_exact_hits`: first=f76 l0 shd119 rtl=24439 tlm=26532 agg_delta=0.085641802 bucket_delta=1.0347805
- `component_b403_rho0750_f0261_seed7103` `normal` `pa_load_hits`: first=f76 l0 shd119 rtl=59701 tlm=70783 agg_delta=0.18562503 bucket_delta=0.51101322
- `component_b403_rho0750_f0261_seed7103` `normal` `late_drop_pa_action_hits`: first=f135 l0 shd3 rtl=9774 tlm=3948 agg_delta=0.59607121 bucket_delta=1.1778187
- `component_b403_rho0750_f0261_seed7103` `normal` `late_drop_control_exact_hits`: first=f135 l0 shd3 rtl=9756 tlm=3948 agg_delta=0.59532595 bucket_delta=1.1789668
- `component_b403_rho0750_f0261_seed7103` `normal` `transaction_deliver_hits`: first=f76 l-1 shd119 rtl=59701 tlm=70783 agg_delta=0.18562503 bucket_delta=0.50829969
- `component_b403_rho0750_f0261_seed7103` `normal` `ingress_decision_ticket`: first=f76 l0 shd119 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.35030532
- `component_b403_rho0750_f0261_seed7103` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=59701 tlm=70783 agg_delta=0.18562503 bucket_delta=0.18562503
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `ingress_accept_hits`: first=f99 l0 shd45 rtl=89060 tlm=76824 agg_delta=0.13739052 bucket_delta=0.29005165
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `ingress_predrop_flag_hits`: first=f99 l0 shd45 rtl=12203 tlm=24439 agg_delta=1.0027043 bucket_delta=2.1168565
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `pa_load_hits`: first=f152 l0 shd1 rtl=59701 tlm=76824 agg_delta=0.28681262 bucket_delta=0.28681262
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `late_drop_pa_action_hits`: first=f152 l0 shd1 rtl=9774 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `late_drop_control_exact_hits`: first=f152 l0 shd1 rtl=9756 tlm=0 agg_delta=1 bucket_delta=1
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `transaction_deliver_hits`: first=f152 l-1 shd0 rtl=59701 tlm=76824 agg_delta=0.28681262 bucket_delta=0.28681262
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `ingress_decision_ticket`: first=f99 l0 shd45 accept rtl=133632 tlm=133632 agg_delta=0 bucket_delta=0.29247486
- `component_b403_rho0750_f0261_seed7103` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=59701 tlm=76824 agg_delta=0.28681262 bucket_delta=0.28681262
- `component_b700_rho0700_f0280_seed7101` `normal` `ingress_accept_hits`: first=f81 l3 shd61 rtl=87721 tlm=76006 agg_delta=0.13354841 bucket_delta=0.26715382
- `component_b700_rho0700_f0280_seed7101` `normal` `ingress_predrop_flag_hits`: first=f81 l3 shd61 rtl=11951 tlm=23666 agg_delta=0.9802527 bucket_delta=1.9609238
- `component_b700_rho0700_f0280_seed7101` `normal` `controlled_predrop_exact_hits`: first=f81 l3 shd61 rtl=19392 tlm=23666 agg_delta=0.22040017 bucket_delta=1.2451526
- `component_b700_rho0700_f0280_seed7101` `normal` `pa_load_hits`: first=f81 l3 shd61 rtl=62319 tlm=70175 agg_delta=0.12606107 bucket_delta=0.50960381
- `component_b700_rho0700_f0280_seed7101` `normal` `late_drop_pa_action_hits`: first=f129 l1 shd14 rtl=10586 tlm=5831 agg_delta=0.44917816 bucket_delta=1.3507463
- `component_b700_rho0700_f0280_seed7101` `normal` `late_drop_control_exact_hits`: first=f129 l1 shd14 rtl=10569 tlm=5831 agg_delta=0.44829218 bucket_delta=1.3513104
- `component_b700_rho0700_f0280_seed7101` `normal` `transaction_deliver_hits`: first=f81 l-1 shd61 rtl=62319 tlm=70175 agg_delta=0.12606107 bucket_delta=0.50687591
- `component_b700_rho0700_f0280_seed7101` `normal` `ingress_decision_ticket`: first=f81 l3 shd61 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.31870815
- `component_b700_rho0700_f0280_seed7101` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=62319 tlm=70175 agg_delta=0.12606107 bucket_delta=0.12606107
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `ingress_accept_hits`: first=f101 l2 shd120 rtl=87721 tlm=80280 agg_delta=0.084825754 bucket_delta=0.22848577
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `ingress_predrop_flag_hits`: first=f101 l2 shd120 rtl=11951 tlm=19392 agg_delta=0.62262572 bucket_delta=1.6770982
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `pa_load_hits`: first=f163 l0 shd85 rtl=62319 tlm=80280 agg_delta=0.28821066 bucket_delta=0.28821066
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `late_drop_pa_action_hits`: first=f163 l1 shd57 rtl=10586 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `late_drop_control_exact_hits`: first=f163 l1 shd57 rtl=10569 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `transaction_deliver_hits`: first=f163 l-1 shd13 rtl=62319 tlm=80280 agg_delta=0.28821066 bucket_delta=0.28821066
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `ingress_decision_ticket`: first=f101 l2 shd120 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.2523019
- `component_b700_rho0700_f0280_seed7101` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=62319 tlm=80280 agg_delta=0.28821066 bucket_delta=0.28821066
- `component_b700_rho0700_f0280_seed7102` `normal` `ingress_accept_hits`: first=f77 l2 shd109 rtl=87498 tlm=75294 agg_delta=0.13947747 bucket_delta=0.30343551
- `component_b700_rho0700_f0280_seed7102` `normal` `ingress_predrop_flag_hits`: first=f77 l2 shd109 rtl=13400 tlm=25604 agg_delta=0.91074627 bucket_delta=1.9813433
- `component_b700_rho0700_f0280_seed7102` `normal` `controlled_predrop_exact_hits`: first=f77 l2 shd109 rtl=20441 tlm=25604 agg_delta=0.2525806 bucket_delta=1.2474439
- `component_b700_rho0700_f0280_seed7102` `normal` `pa_load_hits`: first=f77 l2 shd109 rtl=64034 tlm=69615 agg_delta=0.087156823 bucket_delta=0.49775119
- `component_b700_rho0700_f0280_seed7102` `normal` `late_drop_pa_action_hits`: first=f134 l0 shd9 rtl=9140 tlm=5679 agg_delta=0.37866521 bucket_delta=1.3561269
- `component_b700_rho0700_f0280_seed7102` `normal` `late_drop_control_exact_hits`: first=f134 l0 shd9 rtl=9123 tlm=5679 agg_delta=0.3775074 bucket_delta=1.3567905
- `component_b700_rho0700_f0280_seed7102` `normal` `transaction_deliver_hits`: first=f77 l-1 shd109 rtl=64034 tlm=69615 agg_delta=0.087156823 bucket_delta=0.49668926
- `component_b700_rho0700_f0280_seed7102` `normal` `ingress_decision_ticket`: first=f77 l2 shd109 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.33995536
- `component_b700_rho0700_f0280_seed7102` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=64034 tlm=69615 agg_delta=0.087156823 bucket_delta=0.087156823
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `ingress_accept_hits`: first=f100 l0 shd92 rtl=87498 tlm=80457 agg_delta=0.080470411 bucket_delta=0.23718256
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `ingress_predrop_flag_hits`: first=f100 l0 shd92 rtl=13400 tlm=20441 agg_delta=0.52544776 bucket_delta=1.5487313
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `pa_load_hits`: first=f165 l1 shd99 rtl=64034 tlm=80457 agg_delta=0.25647312 bucket_delta=0.25647312
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `late_drop_pa_action_hits`: first=f167 l0 shd11 rtl=9140 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `late_drop_control_exact_hits`: first=f167 l0 shd11 rtl=9123 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `transaction_deliver_hits`: first=f165 l-1 shd99 rtl=64034 tlm=80457 agg_delta=0.25647312 bucket_delta=0.25647312
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `ingress_decision_ticket`: first=f100 l0 shd92 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.27237723
- `component_b700_rho0700_f0280_seed7102` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=64034 tlm=80457 agg_delta=0.25647312 bucket_delta=0.25647312
- `component_b700_rho0700_f0280_seed7103` `normal` `ingress_accept_hits`: first=f84 l0 shd58 rtl=86891 tlm=76801 agg_delta=0.1161225 bucket_delta=0.28198548
- `component_b700_rho0700_f0280_seed7103` `normal` `ingress_predrop_flag_hits`: first=f84 l0 shd58 rtl=13452 tlm=23542 agg_delta=0.75007434 bucket_delta=1.8214392
- `component_b700_rho0700_f0280_seed7103` `normal` `controlled_predrop_exact_hits`: first=f84 l0 shd58 rtl=19498 tlm=23542 agg_delta=0.20740589 bucket_delta=1.2166376
- `component_b700_rho0700_f0280_seed7103` `normal` `pa_load_hits`: first=f84 l0 shd58 rtl=62179 tlm=70633 agg_delta=0.1359623 bucket_delta=0.50270992
- `component_b700_rho0700_f0280_seed7103` `normal` `late_drop_pa_action_hits`: first=f127 l0 shd2 rtl=10645 tlm=6168 agg_delta=0.42057304 bucket_delta=1.3169563
- `component_b700_rho0700_f0280_seed7103` `normal` `late_drop_control_exact_hits`: first=f127 l0 shd2 rtl=10628 tlm=6168 agg_delta=0.41964622 bucket_delta=1.3174633
- `component_b700_rho0700_f0280_seed7103` `normal` `transaction_deliver_hits`: first=f84 l-1 shd58 rtl=62179 tlm=70633 agg_delta=0.1359623 bucket_delta=0.5016163
- `component_b700_rho0700_f0280_seed7103` `normal` `ingress_decision_ticket`: first=f84 l0 shd58 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.30895647
- `component_b700_rho0700_f0280_seed7103` `normal` `frame_table_hit_aggregate`: first=aggregate rtl=62179 tlm=70633 agg_delta=0.1359623 bucket_delta=0.1359623
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `ingress_accept_hits`: first=f106 l2 shd103 rtl=86891 tlm=80845 agg_delta=0.06958143 bucket_delta=0.24283297
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `ingress_predrop_flag_hits`: first=f106 l2 shd103 rtl=13452 tlm=19498 agg_delta=0.4494499 bucket_delta=1.56854
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `pa_load_hits`: first=f159 l3 shd122 rtl=62179 tlm=80845 agg_delta=0.30019782 bucket_delta=0.30019782
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `late_drop_pa_action_hits`: first=f161 l0 shd11 rtl=10645 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `late_drop_control_exact_hits`: first=f161 l0 shd11 rtl=10628 tlm=0 agg_delta=1 bucket_delta=1
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `transaction_deliver_hits`: first=f159 l-1 shd122 rtl=62179 tlm=80845 agg_delta=0.30019782 bucket_delta=0.30019782
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `ingress_decision_ticket`: first=f106 l2 shd103 accept rtl=143360 tlm=143360 agg_delta=0 bucket_delta=0.26838728
- `component_b700_rho0700_f0280_seed7103` `forced_ingress` `frame_table_hit_aggregate`: first=aggregate rtl=62179 tlm=80845 agg_delta=0.30019782 bucket_delta=0.30019782

## Run Metadata

- `component_b000_rho0750_f0261_seed7101`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=539228 forced_events=573242
- `component_b000_rho0750_f0261_seed7102`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=540103 forced_events=569241
- `component_b000_rho0750_f0261_seed7103`: frames=261 rho_ppm=750000 burst_milli=0 seed=0x5c1f0001 normal_events=539991 forced_events=572744
- `component_b000_rho0800_f0245_seed7101`: frames=245 rho_ppm=800000 burst_milli=0 seed=0x5c1f0001 normal_events=490463 forced_events=531708
- `component_b000_rho0800_f0245_seed7102`: frames=245 rho_ppm=800000 burst_milli=0 seed=0x5c1f0001 normal_events=497639 forced_events=525181
- `component_b000_rho0800_f0245_seed7103`: frames=245 rho_ppm=800000 burst_milli=0 seed=0x5c1f0001 normal_events=501625 forced_events=531705
- `component_b403_rho0750_f0261_seed7101`: frames=261 rho_ppm=750000 burst_milli=403 seed=0x5c1f0001 normal_events=546407 forced_events=590426
- `component_b403_rho0750_f0261_seed7102`: frames=261 rho_ppm=750000 burst_milli=403 seed=0x5c1f0001 normal_events=542793 forced_events=591477
- `component_b403_rho0750_f0261_seed7103`: frames=261 rho_ppm=750000 burst_milli=403 seed=0x5c1f0001 normal_events=551509 forced_events=589648
- `component_b700_rho0700_f0280_seed7101`: frames=280 rho_ppm=700000 burst_milli=700 seed=0x5c1f0001 normal_events=578859 forced_events=631423
- `component_b700_rho0700_f0280_seed7102`: frames=280 rho_ppm=700000 burst_milli=700 seed=0x5c1f0001 normal_events=573003 forced_events=631230
- `component_b700_rho0700_f0280_seed7103`: frames=280 rho_ppm=700000 burst_milli=700 seed=0x5c1f0001 normal_events=576342 forced_events=631418

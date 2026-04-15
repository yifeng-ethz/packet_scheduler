lappend auto_path "$::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages"
package require -exact altera_terp 1.0
set template_file [file normalize {/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/rtl/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd}]
set template [read [open $template_file r]]
set params(n_lane) 4
set params(fifos_names) [list "ticket_fifo" "lane_fifo" "handle_fifo"]
set params(egress_empty_width) 0
set params(output_name) "ordered_priority_queue_dut4_impl"
set result [altera_terp $template params]
set out [open {/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/tb_int/rtl_gen_monolithic_4lane/ordered_priority_queue_dut4_impl.vhd} w]
puts $out $result
close $out

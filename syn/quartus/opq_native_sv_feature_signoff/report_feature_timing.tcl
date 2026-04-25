if {[llength $quartus(args)] > 0} {
  set project_name [lindex $quartus(args) 0]
  set revision_arg_idx [lsearch -exact $quartus(args) "-c"]

  if {$revision_arg_idx >= 0 && [llength $quartus(args)] > [expr {$revision_arg_idx + 1}]} {
    set revision_arg [lindex $quartus(args) [expr {$revision_arg_idx + 1}]]
    project_open $project_name -revision $revision_arg
  } else {
    project_open $project_name
  }

  create_timing_netlist
  read_sdc
  update_timing_netlist
}

set revision_name [get_current_revision]
set output_dir "output_files/${revision_name}"

file mkdir ${output_dir}

report_timing \
  -setup \
  -npaths 50 \
  -detail full_path \
  -from_clock clk \
  -to_clock clk \
  -file "${output_dir}/${revision_name}.setup_paths.rpt"

report_timing \
  -hold \
  -npaths 20 \
  -detail full_path \
  -from_clock clk \
  -to_clock clk \
  -file "${output_dir}/${revision_name}.hold_paths.rpt"

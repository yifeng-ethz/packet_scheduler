################################################
# ordered_priority_queue_v2 "Ordered Priority Queue (v2 split)" v26.1.0201
# Yifeng Wang 2025.07.16
################################################

################################################
# request TCL package from ACDS 16.1
################################################ 
package require qsys
# custom macro, for building .hdl.terp -> .hdl
# loc: $::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages/altera_terp.tcl
package require -exact altera_terp 1.0

# 25.0.0716 - file created
# 25.0.0722 - compilation successful, test ongoing
# 26.1.0201 - split RTL wrapper (ordered_priority_queue_top.terp.vhd) integration

################################################
# module ordered_priority_queue_v2
################################################ 
set_module_property NAME ordered_priority_queue_v2
set_module_property VERSION 26.1.0201
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "Mu3e Data Plane/Modules"
set_module_property AUTHOR "Yifeng Wang"
set_module_property ICON_PATH ../figures/mu3e_logo.png
set_module_property DISPLAY_NAME "Ordered Priority Queue (v2 split)"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property ELABORATION_CALLBACK my_elaborate


################################################ 
# parameters
################################################ 
# Reference for html codes used in this section
 # ----------------------------------------------
 # &lt = less than (<)
 # &gt = greater than (>)
 # <b></b> = bold text
 # <ul></ul> = defines an unordered list
 # <li></li> = bullet list
 # <br> = line break
add_parameter N_LANE NATURAL 
set_parameter_property N_LANE DEFAULT_VALUE 2
set_parameter_property N_LANE DISPLAY_NAME "Number of Ingress Lanes"
set_parameter_property N_LANE TYPE NATURAL
set_parameter_property N_LANE UNITS None
set_parameter_property N_LANE ALLOWED_RANGES 1:16
set_parameter_property N_LANE HDL_PARAMETER true
set dscpt \
"<html>
Select the number of ingress lanes for the ordered priority queue.<br>
All ingress flows will be aggregated into one single egress flow.<br>
</html>"
set_parameter_property N_LANE LONG_DESCRIPTION $dscpt
set_parameter_property N_LANE DESCRIPTION $dscpt

add_parameter MODE STRING 
set_parameter_property MODE DEFAULT_VALUE "Merging"
set_parameter_property MODE DISPLAY_NAME "Aggregation Mode"
set_parameter_property MODE UNITS None
set_parameter_property MODE ALLOWED_RANGES {MULTIPLEXING MERGING}
set_parameter_property MODE HDL_PARAMETER true
set dscpt \
"<html>
<ul>
    <li><b>Multiplexing</b>: ingress flows ts are interleaved. </li>
    <li><b>Merging</b>: ingress flows ts are sequenced and consistent. </li>
</ul>
</html>"
set_parameter_property MODE LONG_DESCRIPTION $dscpt
set_parameter_property MODE DESCRIPTION $dscpt

add_parameter TRACK_HEADER BOOLEAN 
set_parameter_property TRACK_HEADER DEFAULT_VALUE True
set_parameter_property TRACK_HEADER DISPLAY_NAME "Track Header"
set_parameter_property TRACK_HEADER UNITS None
set_parameter_property TRACK_HEADER ALLOWED_RANGES {"true:Yes" "false:No"}
set_parameter_property TRACK_HEADER DISPLAY_HINT "RADIO"
set_parameter_property TRACK_HEADER HDL_PARAMETER true
set dscpt \
"<html>
Select whether to track the header of ingress flow as the reference timestamp for subsequent subheader packet. <br>
<ul>
    <li><b>True</b>: the header is tracked, i.e., ingress flow must contain header to assign global timestamp for subsequent subheaders. </li>
    <li><b>False</b>: use subheader to infer the running timestamp in that flow. Maximum packet loss can not be longer than <b>256</b>, i.e., the number of subheaders in the header packets.</li>
</ul>
</html>"
set_parameter_property TRACK_HEADER LONG_DESCRIPTION $dscpt
set_parameter_property TRACK_HEADER DESCRIPTION $dscpt

add_parameter INGRESS_DATA_WIDTH NATURAL 
set_parameter_property INGRESS_DATA_WIDTH DEFAULT_VALUE 32
set_parameter_property INGRESS_DATA_WIDTH DISPLAY_NAME "Data Port Width (data)"
set_parameter_property INGRESS_DATA_WIDTH UNITS Bits
set_parameter_property INGRESS_DATA_WIDTH ALLOWED_RANGES 32:128
set_parameter_property INGRESS_DATA_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the width of each ingress interface data port (data).<br>
Default is <b>32</b> bits.<br>
</html>"
set_parameter_property INGRESS_DATA_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property INGRESS_DATA_WIDTH DESCRIPTION $dscpt

add_parameter INGRESS_DATAK_WIDTH NATURAL 
set_parameter_property INGRESS_DATAK_WIDTH DEFAULT_VALUE 4
set_parameter_property INGRESS_DATAK_WIDTH DISPLAY_NAME "Data Port Width (datak)"
set_parameter_property INGRESS_DATAK_WIDTH UNITS Bits
set_parameter_property INGRESS_DATAK_WIDTH ALLOWED_RANGES 1:16
set_parameter_property INGRESS_DATAK_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the width of each ingress interface data port (datak).<br>
Default is <b>4</b> bits, each bit represents the byte is '1'=control symbol or '0'=data symbol.<br>
</html>"
set_parameter_property INGRESS_DATAK_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property INGRESS_DATAK_WIDTH DESCRIPTION $dscpt

add_parameter CHANNEL_WIDTH NATURAL 
set_parameter_property CHANNEL_WIDTH DEFAULT_VALUE 2
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Channel Port Width"
set_parameter_property CHANNEL_WIDTH UNITS Bits
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES 0:4
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the width of logical channel, e.g., 2 bits for 4 channels<br>
Default is <b>2</b> bits, for 4 flow merging.<br>
You may set it to 0 to disable channel port.<br>
</html>"
set_parameter_property CHANNEL_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property CHANNEL_WIDTH DESCRIPTION $dscpt

add_parameter LANE_FIFO_DEPTH NATURAL 
set_parameter_property LANE_FIFO_DEPTH DEFAULT_VALUE 1024
set_parameter_property LANE_FIFO_DEPTH DISPLAY_NAME "Lane FIFO Depth"
set_parameter_property LANE_FIFO_DEPTH UNITS None
set_parameter_property LANE_FIFO_DEPTH ALLOWED_RANGES {16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536}
set_parameter_property LANE_FIFO_DEPTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of each lane FIFO in unit of its own data width. <br>
Lane FIFO is between <b>ingress parser</b> and <b>block mover</b>.<br>
Affects the max delay skew between each lane supported and maximum waiting time for the <b>page allocator</b>.<br>
Must be a <b>power of two</b> (ring-buffer address wrap).<br>
Using credit flow control. <br>
</html>"
set_parameter_property LANE_FIFO_DEPTH LONG_DESCRIPTION $dscpt
set_parameter_property LANE_FIFO_DEPTH DESCRIPTION $dscpt

add_parameter LANE_FIFO_WIDTH NATURAL 
set_parameter_property LANE_FIFO_WIDTH DEFAULT_VALUE 40
set_parameter_property LANE_FIFO_WIDTH DISPLAY_NAME "Lane FIFO Width"
set_parameter_property LANE_FIFO_WIDTH UNITS Bits
set_parameter_property LANE_FIFO_WIDTH ALLOWED_RANGES 39:80
set_parameter_property LANE_FIFO_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the data width of each lane FIFO. <br>
Data width of each lane FIFO in unit of bits, must be larger than total(39) = data(32)+datak(4)+eop(1)+sop(1)+err(1)<br>
</html>"
set_parameter_property LANE_FIFO_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property LANE_FIFO_WIDTH DESCRIPTION $dscpt

add_parameter TICKET_FIFO_DEPTH NATURAL 
set_parameter_property TICKET_FIFO_DEPTH DEFAULT_VALUE 256
set_parameter_property TICKET_FIFO_DEPTH DISPLAY_NAME "Ticket FIFO Depth"
set_parameter_property TICKET_FIFO_DEPTH UNITS None
set_parameter_property TICKET_FIFO_DEPTH ALLOWED_RANGES 2:256
set_parameter_property TICKET_FIFO_DEPTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of each ticket FIFO in unit of its data width. <br>
Ticket FIFO is between <b>ingress parser</b> and <b>page allocator</b>.<br>
Set accordingly to the expected latency and max delay skew it allows.<br>
If too many empty subframes, the credit can be consumed quickly. Should be larger than N_SHD to absorb the burst per frame. <br>
Using credit flow control. <br>
</html>"
set_parameter_property TICKET_FIFO_DEPTH LONG_DESCRIPTION $dscpt
set_parameter_property TICKET_FIFO_DEPTH DESCRIPTION $dscpt

add_parameter HANDLE_FIFO_DEPTH NATURAL 
set_parameter_property HANDLE_FIFO_DEPTH DEFAULT_VALUE 64
set_parameter_property HANDLE_FIFO_DEPTH DISPLAY_NAME "Handle FIFO Depth"
set_parameter_property HANDLE_FIFO_DEPTH UNITS None
set_parameter_property HANDLE_FIFO_DEPTH ALLOWED_RANGES 2:256
set_parameter_property HANDLE_FIFO_DEPTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of each handle FIFO in unit of its data width. <br>
Handle FIFO is between <b>page allocator</b> and <b>block mover</b>.<br>
Set accordingly to the expected latency and max delay skew it allows.<br>
Drop means blk mover is too slow. <br>
No credit flow control. <br>
</html>"
set_parameter_property HANDLE_FIFO_DEPTH LONG_DESCRIPTION $dscpt
set_parameter_property HANDLE_FIFO_DEPTH DESCRIPTION $dscpt

add_parameter PAGE_RAM_DEPTH NATURAL 
set_parameter_property PAGE_RAM_DEPTH DEFAULT_VALUE 65536
set_parameter_property PAGE_RAM_DEPTH DISPLAY_NAME "Page RAM Depth"
set_parameter_property PAGE_RAM_DEPTH UNITS None
set_parameter_property PAGE_RAM_DEPTH ALLOWED_RANGES {8192 16384 32768 65536}
set_parameter_property PAGE_RAM_DEPTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of the page RAM in unit of its WR data width. <br>
Handle FIFO is between <b>block mover</b> and <b>???</b>.<br>
This parameter needs to be larger than the full header packet, which is usually 8k by default.<br>
Using novel dynamic segmentation for read packet integrity and write up-to-date. <br>
If read side is too slow, read always returns the current reading packet, and the next packet will leap to the tail packet of the write thread. <br>
Write will not overwrite the current reading segment, but will overwrite the last writing segment.  <br>
So-called 3 segment. 2 for write to do ring-buffer write and 1 for read to continue current read.  <br>
This solves read/write contention and read most recent packet. <br>
</html>"
set_parameter_property PAGE_RAM_DEPTH LONG_DESCRIPTION $dscpt
set_parameter_property PAGE_RAM_DEPTH DESCRIPTION $dscpt

add_parameter PAGE_RAM_RD_WIDTH NATURAL 
set_parameter_property PAGE_RAM_RD_WIDTH DEFAULT_VALUE 36
set_parameter_property PAGE_RAM_RD_WIDTH DISPLAY_NAME "Page RAM RD Width"
set_parameter_property PAGE_RAM_RD_WIDTH UNITS Bits
set_parameter_property PAGE_RAM_RD_WIDTH ALLOWED_RANGES {36 72 108 144 180 216 252 288}
set_parameter_property PAGE_RAM_RD_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of the page RAM in unit of its WR data width. <br>
RD data width of the page RAM in unit of bits <br>
write width = LANE_FIFO_WIDTH, read width can be larger for interfacing with PCIe DMA or other high speed interface. <br>
</html>"
set_parameter_property PAGE_RAM_RD_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property PAGE_RAM_RD_WIDTH DESCRIPTION $dscpt

add_parameter N_SHD NATURAL 
set_parameter_property N_SHD DEFAULT_VALUE 256
set_parameter_property N_SHD DISPLAY_NAME "Number of Subheader Packets Between Header Packets"
set_parameter_property N_SHD UNITS None
set_parameter_property N_SHD ALLOWED_RANGES {128 256 512}
set_parameter_property N_SHD HDL_PARAMETER true
set dscpt \
"<html>
Enter the number of subheaders under one header packet, i.e., between two header packets. <br>
You can consider Subheader as a packet and header as a super-packet containing multiple subheader packets. <br>
This parameter defines how many subheader packets can be contained in one header packet. <br>
More subheaders will be regarded as new header in track header = off mode. <br>
Adjusting this parameter will require changing the code logic <br>
</html>"
set_parameter_property N_SHD LONG_DESCRIPTION $dscpt
set_parameter_property N_SHD DESCRIPTION $dscpt

add_parameter N_HIT NATURAL 
set_parameter_property N_HIT DEFAULT_VALUE 255
set_parameter_property N_HIT DISPLAY_NAME "Maximum Number of Hits in Subheader Packet"
set_parameter_property N_HIT UNITS None
set_parameter_property N_HIT ALLOWED_RANGES {255 511 1023 2047}
set_parameter_property N_HIT HDL_PARAMETER true
set dscpt \
"<html>
Enter the number of hits inside one subheader packet. <br>
Hits received above this parameter will be dropped by the <b>ingress parser</b> <br>
To support more hits, you may need to adjust the <b>hit_cnt</b> bitfield mask of the subheader.<br>
</html>"
set_parameter_property N_HIT LONG_DESCRIPTION $dscpt
set_parameter_property N_HIT DESCRIPTION $dscpt

add_parameter DEBUG_LV NATURAL 
set_parameter_property DEBUG_LV DEFAULT_VALUE 1
set_parameter_property DEBUG_LV DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG_LV TYPE NATURAL
set_parameter_property DEBUG_LV UNITS None
set_parameter_property DEBUG_LV ALLOWED_RANGES {0 1 2}
set_parameter_property DEBUG_LV HDL_PARAMETER true
set dscpt \
"<html>
Select the debug level of the IP (affects generation).<br>
<ul>
	<li><b>0</b> : off <br> </li>
	<li><b>1</b> : on, synthesizble <br> </li>
	<li><b>2</b> : on, non-synthesizble, simulation-only <br> </li>
</ul>
</html>"
set_parameter_property DEBUG_LV LONG_DESCRIPTION $dscpt
set_parameter_property DEBUG_LV DESCRIPTION $dscpt

add_parameter FRAME_SERIAL_SIZE NATURAL 
set_parameter_property FRAME_SERIAL_SIZE DEFAULT_VALUE 16
set_parameter_property FRAME_SERIAL_SIZE DISPLAY_NAME "Frame Serial Size"
set_parameter_property FRAME_SERIAL_SIZE UNITS Bits
set_parameter_property FRAME_SERIAL_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_SERIAL_SIZE HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of frame serial number in unit of bits. <br>
Refer to mu3e spec book for details. <br>
</html>"
set_parameter_property FRAME_SERIAL_SIZE LONG_DESCRIPTION $dscpt
set_parameter_property FRAME_SERIAL_SIZE DESCRIPTION $dscpt

add_parameter FRAME_SUBH_CNT_SIZE NATURAL 
set_parameter_property FRAME_SUBH_CNT_SIZE DEFAULT_VALUE 16
set_parameter_property FRAME_SUBH_CNT_SIZE DISPLAY_NAME "Frame Subheader Count Size"
set_parameter_property FRAME_SUBH_CNT_SIZE UNITS Bits
set_parameter_property FRAME_SUBH_CNT_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_SUBH_CNT_SIZE HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of frame subheader count in unit of bits. <br>
Refer to mu3e spec book for details. <br>
</html>"
set_parameter_property FRAME_SUBH_CNT_SIZE LONG_DESCRIPTION $dscpt
set_parameter_property FRAME_SUBH_CNT_SIZE DESCRIPTION $dscpt

add_parameter FRAME_HIT_CNT_SIZE NATURAL 
set_parameter_property FRAME_HIT_CNT_SIZE DEFAULT_VALUE 16
set_parameter_property FRAME_HIT_CNT_SIZE DISPLAY_NAME "Frame Hit Count Size"
set_parameter_property FRAME_HIT_CNT_SIZE UNITS Bits
set_parameter_property FRAME_HIT_CNT_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_HIT_CNT_SIZE HDL_PARAMETER true
set dscpt \
"<html>
Enter the size of frame hit count in unit of bits. <br>
Refer to mu3e spec book for details. <br>
</html>"
set_parameter_property FRAME_HIT_CNT_SIZE LONG_DESCRIPTION $dscpt
set_parameter_property FRAME_HIT_CNT_SIZE DESCRIPTION $dscpt

################################################ 
# display items
################################################ 
# --------------------------------------------------------------- 
add_display_item "" "IP Basic" GROUP ""
# ---------------------------------------------------------------
add_display_item  "IP Basic" N_LANE PARAMETER
add_display_item  "IP Basic" MODE PARAMETER
add_display_item  "IP Basic" TRACK_HEADER PARAMETER

# --------------------------------------------------------------- 
add_display_item "" "Ingress Format" GROUP ""
# ---------------------------------------------------------------
add_display_item  "Ingress Format" INGRESS_DATA_WIDTH PARAMETER
add_display_item  "Ingress Format" INGRESS_DATAK_WIDTH PARAMETER
add_display_item  "Ingress Format" CHANNEL_WIDTH PARAMETER

# --------------------------------------------------------------- 
add_display_item "" "IP Advance" GROUP ""
# ---------------------------------------------------------------
add_display_item  "IP Advance" LANE_FIFO_DEPTH PARAMETER
add_display_item  "IP Advance" LANE_FIFO_WIDTH PARAMETER
add_display_item  "IP Advance" TICKET_FIFO_DEPTH PARAMETER
add_display_item  "IP Advance" HANDLE_FIFO_DEPTH PARAMETER
add_display_item  "IP Advance" PAGE_RAM_DEPTH PARAMETER
add_display_item  "IP Advance" PAGE_RAM_RD_WIDTH PARAMETER

# --------------------------------------------------------------- 
add_display_item "" "Packet Format" GROUP ""
# ---------------------------------------------------------------
add_display_item  "Packet Format" N_SHD PARAMETER
add_display_item  "Packet Format" N_HIT PARAMETER
add_display_item  "Packet Format" FRAME_SERIAL_SIZE PARAMETER
add_display_item  "Packet Format" FRAME_SUBH_CNT_SIZE PARAMETER
add_display_item  "Packet Format" FRAME_HIT_CNT_SIZE PARAMETER

# --------------------------------------------------------------- 
add_display_item "" "Debug" GROUP ""
# ---------------------------------------------------------------
add_display_item  "Debug" DEBUG_LV PARAMETER

################################################
# ports
################################################ 

####################
# Egress Interface #
####################
add_interface egress avalon_streaming start
set_interface_property egress associatedClock clk_interface
set_interface_property egress associatedReset rst_interface
#set_interface_property egress dataBitsPerSymbol 36
set_interface_property egress errorDescriptor {hit_err shd_err hdr_err}
set_interface_property egress firstSymbolInHighOrderBits true
set_interface_property egress readyLatency 0
set_interface_property egress ENABLED true
set_interface_property egress EXPORT_OF ""
set_interface_property egress PORT_NAME_MAP ""
set_interface_property egress CMSIS_SVD_VARIABLES ""
set_interface_property egress SVD_ADDRESS_GROUP ""

add_interface_port egress aso_egress_startofpacket startofpacket Output 1
add_interface_port egress aso_egress_endofpacket endofpacket Output 1
add_interface_port egress aso_egress_valid valid Output 1
add_interface_port egress aso_egress_ready ready Input 1
add_interface_port egress aso_egress_error error Output 3
    


#############################
# Clock and reset interface #
#############################
add_interface clk_interface clock end 
set_interface_property clk_interface clockRate 0
add_interface_port clk_interface d_clk 		clk			Input 1

add_interface rst_interface reset end
set_interface_property rst_interface associatedClock clk_interface
set_interface_property rst_interface synchronousEdges BOTH
add_interface_port rst_interface d_reset	    reset		Input 1


################################################
# file sets
################################################ 
add_fileset synth   QUARTUS_SYNTH my_generate 

proc my_generate { output_name } {
    # checkout this //acds/rel/18.1std/ip/merlin/altera_merlin_router/altera_merlin_router_hw.tcl
    
    # Split RTL TERP wrapper (generates a drop-in Avalon-ST wrapper around `opq_top`).
    set template_file "rtl/ordered_priority_queue/split/top/ordered_priority_queue_top.terp.vhd"

    set template    [ read [ open $template_file r ] ]

    set if_data_in_width [expr [get_parameter_value INGRESS_DATA_WIDTH] + [get_parameter_value INGRESS_DATAK_WIDTH]] 
    set if_data_out_width [get_parameter_value PAGE_RAM_RD_WIDTH]
    set if_data_out_empty_width [expr int(ceil(log($if_data_out_width / $if_data_in_width)/log(2)))]
    set params(n_lane)              [get_parameter_value N_LANE]
    set params(egress_empty_width)  $if_data_out_empty_width

    set params(output_name) $output_name

    set result          [ altera_terp $template params ]

    send_message INFO "<b>generated file: (${output_name}.vhd)</b>"
    
    # Split RTL sources (VHDL only; inferred RAMs).
    add_fileset_file "opq_util_pkg.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/common/opq_util_pkg.vhd"
    add_fileset_file "opq_sync_ram.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/common/opq_sync_ram.vhd"
    add_fileset_file "opq_ingress_parser.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/ingress/opq_ingress_parser.vhd"
    add_fileset_file "opq_page_allocator.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/allocator/opq_page_allocator.vhd"
    add_fileset_file "opq_block_mover.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/mover/opq_block_mover.vhd"
    add_fileset_file "opq_b2p_arbiter.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/arbiter/opq_b2p_arbiter.vhd"
    add_fileset_file "opq_frame_table_mapper.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_mapper.vhd"
    add_fileset_file "opq_frame_table_tracker.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_tracker.vhd"
    add_fileset_file "opq_frame_table_presenter.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table_presenter.vhd"
    add_fileset_file "opq_frame_table.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/frame_table/opq_frame_table.vhd"
    add_fileset_file "opq_rd_debug_if.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/debug/opq_rd_debug_if.vhd"
    add_fileset_file "opq_top.vhd" VHDL PATH "./rtl/ordered_priority_queue/split/opq/top/opq_top.vhd"

    # Top level file (wrapper generated from TERP template).
    add_fileset_file ${output_name}.vhd VHDL TEXT $result TOP_LEVEL_FILE
}


################################################
# callbacks
################################################
proc my_elaborate {} {
	
	send_message INFO "performing elaboration"

    # -----
    # set parameter values
    


    # ------
    # build more ports 

    ############################## 
    # Ingress Interface x N_LANE #
    ##############################
    set if_data_in_width [expr [get_parameter_value INGRESS_DATA_WIDTH] + [get_parameter_value INGRESS_DATAK_WIDTH]] 

    for {set i 0 } {$i < [get_parameter_value N_LANE]} {incr i} {
        add_interface ingress_${i} avalon_streaming end
        set_interface_property ingress_${i} associatedClock clk_interface
        set_interface_property ingress_${i} associatedReset rst_interface
        set_interface_property ingress_${i} dataBitsPerSymbol $if_data_in_width
        set_interface_property ingress_${i} errorDescriptor {hit_err shd_err hdr_err}
        set_interface_property ingress_${i} firstSymbolInHighOrderBits true
        # Channel value range (Qsys uses this to decide adapter insertion); should match CHANNEL_WIDTH, not N_LANE.
        set_interface_property ingress_${i} maxChannel [expr (1 << [get_parameter_value CHANNEL_WIDTH]) - 1]
        set_interface_property ingress_${i} readyLatency 0
        set_interface_property ingress_${i} ENABLED true
        set_interface_property ingress_${i} EXPORT_OF ""
        set_interface_property ingress_${i} PORT_NAME_MAP ""
        set_interface_property ingress_${i} CMSIS_SVD_VARIABLES ""
        set_interface_property ingress_${i} SVD_ADDRESS_GROUP ""

        if {[get_parameter_value CHANNEL_WIDTH] > 0} {
            add_interface_port ingress_${i} asi_ingress_${i}_channel channel Input [get_parameter_value CHANNEL_WIDTH]
        } 

        add_interface_port ingress_${i} asi_ingress_${i}_startofpacket startofpacket Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_endofpacket endofpacket Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_data data Input $if_data_in_width
        add_interface_port ingress_${i} asi_ingress_${i}_valid valid Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_error error Input 3
    }

    # Egress Interface
    # -- re-set allowed range for user input
    set page_ram_rd_width_allowed_ranges_list [list]
    for {set i 1} {$i <= 8} {incr i} {
        lappend page_ram_rd_width_allowed_ranges_list [expr $if_data_in_width * $i]
    }
    set_parameter_property PAGE_RAM_RD_WIDTH ALLOWED_RANGES $page_ram_rd_width_allowed_ranges_list
    # -- add data port
    set if_data_out_width [get_parameter_value PAGE_RAM_RD_WIDTH]
    add_interface_port egress aso_egress_data data Output $if_data_out_width
    set_port_property aso_egress_data WIDTH_EXPR $if_data_out_width; # multiple of size of symbol
    # -- add empty port
    set if_data_out_n_symbols [expr $if_data_out_width / $if_data_in_width]
    set if_data_out_empty_width [expr int(ceil(log($if_data_out_width / $if_data_in_width)/log(2)))]
    if {$if_data_out_empty_width < 1} {
        send_message INFO "No empty port needed, as the output data width ($if_data_out_width) is same as the input data width ($if_data_in_width)."
    } else {
        add_interface_port egress aso_egress_empty empty Output 
        set_port_property aso_egress_empty WIDTH_EXPR $if_data_out_empty_width
        send_message INFO "empty port added. output data will represent ($if_data_out_n_symbols) symbols"
    }
    # -- re-set interface properties
    set_interface_property egress symbolsPerBeat $if_data_out_n_symbols; # number of symbols per beat
    set_interface_property egress dataBitsPerSymbol $if_data_in_width; # size of ingress width


    send_message INFO "elaboration <b>ok</b>"
}

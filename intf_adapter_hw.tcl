################################################
# intf_adapter "Interface Adapter" v25.0.0716
# Yifeng Wang 2025.07.16
################################################

################################################
# request TCL package from ACDS 16.1
################################################ 
package require qsys
# custom macro, for building .hdl.terp -> .hdl
# loc: $::env(QUARTUS_ROOTDIR)/../ip/altera/common/hw_tcl_packages/altera_terp.tcl
package require -exact altera_terp 1.0

# 25.0.0723 - file created 

################################################
# module intf_adapter
################################################ 
set_module_property NAME intf_adapter
set_module_property VERSION 25.0.0723
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "Mu3e Data Plane/Modules"
set_module_property AUTHOR "Yifeng Wang"
set_module_property ICON_PATH ../figures/mu3e_logo.png
set_module_property DISPLAY_NAME "Interface Adapter"
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
set_parameter_property N_LANE DISPLAY_NAME "Number of Lanes"
set_parameter_property N_LANE TYPE NATURAL
set_parameter_property N_LANE UNITS None
set_parameter_property N_LANE ALLOWED_RANGES 1:16
set_parameter_property N_LANE HDL_PARAMETER true
set dscpt \
"<html>
Select the number of ingress lanes for this adapter.<br>
Egress interface will be auto-set to the same number of lanes.<br>
</html>"
set_parameter_property N_LANE LONG_DESCRIPTION $dscpt
set_parameter_property N_LANE DESCRIPTION $dscpt

add_parameter INGRESS_FORMAT STRING 
set_parameter_property INGRESS_FORMAT DEFAULT_VALUE {Mu3e}
set_parameter_property INGRESS_FORMAT DISPLAY_NAME "Ingress Format"
set_parameter_property INGRESS_FORMAT UNITS None
set_parameter_property INGRESS_FORMAT ALLOWED_RANGES {"Mu3e" "Avalon" "AXI4"}
set_parameter_property INGRESS_FORMAT HDL_PARAMETER true
set dscpt \
"<html>
Select the ingress interface format.<br>
All ingress interfaces must have the same format.<br>
</html>"
set_parameter_property INGRESS_FORMAT LONG_DESCRIPTION $dscpt
set_parameter_property INGRESS_FORMAT DESCRIPTION $dscpt

add_parameter EGRESS_FORMAT STRING 
set_parameter_property EGRESS_FORMAT DEFAULT_VALUE {Avalon}
set_parameter_property EGRESS_FORMAT DISPLAY_NAME "Egress Format"
set_parameter_property EGRESS_FORMAT UNITS None
set_parameter_property EGRESS_FORMAT ALLOWED_RANGES {"Mu3e" "Avalon" "AXI4"}
set_parameter_property EGRESS_FORMAT HDL_PARAMETER true
set dscpt \
"<html>
Select the egress interface format.<br>
All egress interfaces must have the same format.<br>
</html>"
set_parameter_property EGRESS_FORMAT LONG_DESCRIPTION $dscpt
set_parameter_property EGRESS_FORMAT DESCRIPTION $dscpt

add_parameter MU3E_SIG_WIDTH NATURAL 
set_parameter_property MU3E_SIG_WIDTH DEFAULT_VALUE 39
set_parameter_property MU3E_SIG_WIDTH DISPLAY_NAME "Mu3e Signal Bundle Total Width"
set_parameter_property MU3E_SIG_WIDTH UNITS Bits
set_parameter_property MU3E_SIG_WIDTH ALLOWED_RANGES 1:80
set_parameter_property MU3E_SIG_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Set the total bit width of the signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_SIG_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_SIG_WIDTH DESCRIPTION $dscpt

add_parameter MU3E_USE_DATA BOOLEAN 
set_parameter_property MU3E_USE_DATA DEFAULT_VALUE True
set_parameter_property MU3E_USE_DATA DISPLAY_NAME "Use data"
set_parameter_property MU3E_USE_DATA UNITS None
set_parameter_property MU3E_USE_DATA ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_DATA HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>data</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_DATA LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_DATA DESCRIPTION $dscpt

add_parameter MU3E_USE_DATAK BOOLEAN 
set_parameter_property MU3E_USE_DATAK DEFAULT_VALUE True
set_parameter_property MU3E_USE_DATAK DISPLAY_NAME "Use datak"
set_parameter_property MU3E_USE_DATAK UNITS None
set_parameter_property MU3E_USE_DATAK ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_DATAK HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>datak</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_DATAK LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_DATAK DESCRIPTION $dscpt

add_parameter MU3E_USE_IDLE BOOLEAN 
set_parameter_property MU3E_USE_IDLE DEFAULT_VALUE True
set_parameter_property MU3E_USE_IDLE DISPLAY_NAME "Use idle"
set_parameter_property MU3E_USE_IDLE UNITS None
set_parameter_property MU3E_USE_IDLE ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_IDLE HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>idle</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_IDLE LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_IDLE DESCRIPTION $dscpt

add_parameter MU3E_USE_SOP BOOLEAN 
set_parameter_property MU3E_USE_SOP DEFAULT_VALUE True
set_parameter_property MU3E_USE_SOP DISPLAY_NAME "Use sop"
set_parameter_property MU3E_USE_SOP UNITS None
set_parameter_property MU3E_USE_SOP ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_SOP HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>sop</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_SOP LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_SOP DESCRIPTION $dscpt

add_parameter MU3E_USE_DTHR BOOLEAN 
set_parameter_property MU3E_USE_DTHR DEFAULT_VALUE False
set_parameter_property MU3E_USE_DTHR DISPLAY_NAME "Use dthr"
set_parameter_property MU3E_USE_DTHR UNITS None
set_parameter_property MU3E_USE_DTHR ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_DTHR HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>dthr</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_DTHR LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_DTHR DESCRIPTION $dscpt

add_parameter MU3E_USE_SBHDR BOOLEAN 
set_parameter_property MU3E_USE_SBHDR DEFAULT_VALUE False
set_parameter_property MU3E_USE_SBHDR DISPLAY_NAME "Use sbhdr"
set_parameter_property MU3E_USE_SBHDR UNITS None
set_parameter_property MU3E_USE_SBHDR ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_SBHDR HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>sbhdr</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_SBHDR LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_SBHDR DESCRIPTION $dscpt

add_parameter MU3E_USE_EOP BOOLEAN 
set_parameter_property MU3E_USE_EOP DEFAULT_VALUE True
set_parameter_property MU3E_USE_EOP DISPLAY_NAME "Use eop"
set_parameter_property MU3E_USE_EOP UNITS None
set_parameter_property MU3E_USE_EOP ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_EOP HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>eop</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_EOP LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_EOP DESCRIPTION $dscpt

add_parameter MU3E_USE_T0 BOOLEAN 
set_parameter_property MU3E_USE_T0 DEFAULT_VALUE False
set_parameter_property MU3E_USE_T0 DISPLAY_NAME "Use t0"
set_parameter_property MU3E_USE_T0 UNITS None
set_parameter_property MU3E_USE_T0 ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_T0 HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>t0</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_T0 LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_T0 DESCRIPTION $dscpt

add_parameter MU3E_USE_T1 BOOLEAN 
set_parameter_property MU3E_USE_T1 DEFAULT_VALUE False
set_parameter_property MU3E_USE_T1 DISPLAY_NAME "Use t1"
set_parameter_property MU3E_USE_T1 UNITS None
set_parameter_property MU3E_USE_T1 ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_T1 HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>t1</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_T1 LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_T1 DESCRIPTION $dscpt

add_parameter MU3E_USE_D0 BOOLEAN 
set_parameter_property MU3E_USE_D0 DEFAULT_VALUE False
set_parameter_property MU3E_USE_D0 DISPLAY_NAME "Use d0"
set_parameter_property MU3E_USE_D0 UNITS None
set_parameter_property MU3E_USE_D0 ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_D0 HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>d0</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_D0 LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_D0 DESCRIPTION $dscpt

add_parameter MU3E_USE_D1 BOOLEAN 
set_parameter_property MU3E_USE_D1 DEFAULT_VALUE False
set_parameter_property MU3E_USE_D1 DISPLAY_NAME "Use d1"
set_parameter_property MU3E_USE_D1 UNITS None
set_parameter_property MU3E_USE_D1 ALLOWED_RANGES {True False}
set_parameter_property MU3E_USE_D1 HDL_PARAMETER true
set dscpt \
"<html>
Set the to enable <b>d1</b> bit field signal bundle of Mu3e Signal according to vhdl type link_t.<br>
</html>"
set_parameter_property MU3E_USE_D1 LONG_DESCRIPTION $dscpt
set_parameter_property MU3E_USE_D1 DESCRIPTION $dscpt

add_parameter AVS_DATA_WIDTH NATURAL 
set_parameter_property AVS_DATA_WIDTH DEFAULT_VALUE 36
set_parameter_property AVS_DATA_WIDTH DISPLAY_NAME "Data Port Width"
set_parameter_property AVS_DATA_WIDTH UNITS Bits
set_parameter_property AVS_DATA_WIDTH ALLOWED_RANGES 1:1024
set_parameter_property AVS_DATA_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Set the width of data port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_DATA_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property AVS_DATA_WIDTH DESCRIPTION $dscpt

add_parameter AVS_CHANNEL_WIDTH NATURAL 
set_parameter_property AVS_CHANNEL_WIDTH DEFAULT_VALUE 2
set_parameter_property AVS_CHANNEL_WIDTH DISPLAY_NAME "Channel Port Width"
set_parameter_property AVS_CHANNEL_WIDTH UNITS Bits
set_parameter_property AVS_CHANNEL_WIDTH ALLOWED_RANGES 0:128
set_parameter_property AVS_CHANNEL_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Set the width of channel port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_CHANNEL_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property AVS_CHANNEL_WIDTH DESCRIPTION $dscpt

add_parameter AVS_ERROR_WIDTH NATURAL 
set_parameter_property AVS_ERROR_WIDTH DEFAULT_VALUE 3
set_parameter_property AVS_ERROR_WIDTH DISPLAY_NAME "Error Port Width"
set_parameter_property AVS_ERROR_WIDTH UNITS Bits
set_parameter_property AVS_ERROR_WIDTH ALLOWED_RANGES 0:128
set_parameter_property AVS_ERROR_WIDTH HDL_PARAMETER true
set dscpt \
"<html>
Set the width of error port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_ERROR_WIDTH LONG_DESCRIPTION $dscpt
set_parameter_property AVS_ERROR_WIDTH DESCRIPTION $dscpt

add_parameter AVS_USE_DATA BOOLEAN 
set_parameter_property AVS_USE_DATA DEFAULT_VALUE True
set_parameter_property AVS_USE_DATA DISPLAY_NAME "Use data"
set_parameter_property AVS_USE_DATA UNITS None
set_parameter_property AVS_USE_DATA ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_DATA HDL_PARAMETER true
set dscpt \
"<html>
Enable data port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_DATA LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_DATA DESCRIPTION $dscpt

add_parameter AVS_USE_VALID BOOLEAN 
set_parameter_property AVS_USE_VALID DEFAULT_VALUE True
set_parameter_property AVS_USE_VALID DISPLAY_NAME "Use valid"
set_parameter_property AVS_USE_VALID UNITS None
set_parameter_property AVS_USE_VALID ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_VALID HDL_PARAMETER true
set dscpt \
"<html>
Enable valid port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_VALID LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_VALID DESCRIPTION $dscpt

add_parameter AVS_USE_SOP BOOLEAN 
set_parameter_property AVS_USE_SOP DEFAULT_VALUE True
set_parameter_property AVS_USE_SOP DISPLAY_NAME "Use startofpacket"
set_parameter_property AVS_USE_SOP UNITS None
set_parameter_property AVS_USE_SOP ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_SOP HDL_PARAMETER true
set dscpt \
"<html>
Enable startofpacket port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_SOP LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_SOP DESCRIPTION $dscpt

add_parameter AVS_USE_EOP BOOLEAN 
set_parameter_property AVS_USE_EOP DEFAULT_VALUE True
set_parameter_property AVS_USE_EOP DISPLAY_NAME "Use endofpacket"
set_parameter_property AVS_USE_EOP UNITS None
set_parameter_property AVS_USE_EOP ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_EOP HDL_PARAMETER true
set dscpt \
"<html>
Enable endofpacket port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_EOP LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_EOP DESCRIPTION $dscpt

add_parameter AVS_USE_ERR BOOLEAN 
set_parameter_property AVS_USE_ERR DEFAULT_VALUE False
set_parameter_property AVS_USE_ERR DISPLAY_NAME "Use error"
set_parameter_property AVS_USE_ERR UNITS None
set_parameter_property AVS_USE_ERR ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_ERR HDL_PARAMETER true
set dscpt \
"<html>
Enable error port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_ERR LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_ERR DESCRIPTION $dscpt

add_parameter AVS_USE_CHANNEL BOOLEAN 
set_parameter_property AVS_USE_CHANNEL DEFAULT_VALUE False
set_parameter_property AVS_USE_CHANNEL DISPLAY_NAME "Use channel"
set_parameter_property AVS_USE_CHANNEL UNITS None
set_parameter_property AVS_USE_CHANNEL ALLOWED_RANGES {True False}
set_parameter_property AVS_USE_CHANNEL HDL_PARAMETER true
set dscpt \
"<html>
Enable channel port of the Avalon Streaming interface.<br>
</html>"
set_parameter_property AVS_USE_CHANNEL LONG_DESCRIPTION $dscpt
set_parameter_property AVS_USE_CHANNEL DESCRIPTION $dscpt

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


################################################
# ports
################################################ 

#---------------------+
# Clock and Reset I/F |
#---------------------+
add_interface data_clock_intf clock end 
set_interface_property data_clock_intf clockRate 0
add_interface_port data_clock_intf data_clk 		clk			Input 1

add_interface data_reset_intf reset end
set_interface_property data_reset_intf associatedClock data_clock_intf
set_interface_property data_reset_intf synchronousEdges BOTH
add_interface_port data_reset_intf data_reset	    reset		Input 1


################################################ 
# display items
################################################ 
set GUI_IP_NOTE0 \
"<html>
<b>You need to make sure the enabled signals are connect to the conduit interface as the below sequence. </b> <br>
</html>"
# ===============================================================
add_display_item "" "Base" GROUP tab
# ===============================================================
# --------------------------------------------------------------- 
add_display_item "Base" "IP Basic" GROUP ""
# ---------------------------------------------------------------
add_display_item  "IP Basic" N_LANE PARAMETER

# --------------------------------------------------------------- 
add_display_item "Base" "Interface Format" GROUP ""
# ---------------------------------------------------------------
add_display_item  "Interface Format" INGRESS_FORMAT PARAMETER
add_display_item  "Interface Format" EGRESS_FORMAT PARAMETER

# --------------------------------------------------------------- 
add_display_item "Base" "Debug Options" GROUP ""
# ---------------------------------------------------------------
add_display_item  "Debug Options" DEBUG_LV PARAMETER

# ===============================================================
add_display_item "" "Mu3e Signal Format" GROUP tab
# ===============================================================
add_display_item  "Mu3e Signal Format" MU3E_SIG_WIDTH PARAMETER
add_display_item  "Mu3e Signal Format" GUI_IP_NOTE0 TEXT $GUI_IP_NOTE0
add_display_item  "Mu3e Signal Format" MU3E_USE_DATA PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_DATAK PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_IDLE PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_SOP PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_DTHR PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_SBHDR PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_EOP PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_ERR PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_T0 PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_T1 PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_D0 PARAMETER
add_display_item  "Mu3e Signal Format" MU3E_USE_D1 PARAMETER

# ===============================================================
add_display_item "" "Avalon Streaming Format" GROUP tab
# ===============================================================
add_display_item  "Avalon Streaming Format" AVS_DATA_WIDTH PARAMETER
add_display_item  "Avalon Streaming Format" AVS_CHANNEL_WIDTH PARAMETER
add_display_item  "Avalon Streaming Format" AVS_ERROR_WIDTH PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_DATA PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_VALID PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_SOP PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_EOP PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_ERR PARAMETER
add_display_item  "Avalon Streaming Format" AVS_USE_CHANNEL PARAMETER



# --------------------------------------------------------------- 
#add_display_item "" "Debug" GROUP ""
# ---------------------------------------------------------------
#add_display_item  "Debug" DEBUG_LV PARAMETER

################################################
# file sets
################################################ 
add_fileset synth   QUARTUS_SYNTH my_generate 

proc my_generate { output_name } {
    # checkout this //acds/rel/18.1std/ip/merlin/altera_merlin_router/altera_merlin_router_hw.tcl
    
    set template_file "rtl/intf_adapter/intf_adapter.terp.vhd"

    set template    [ read [ open $template_file r ] ]

    set params(ingress_format) [get_parameter_value INGRESS_FORMAT]
    set params(egress_format)  [get_parameter_value EGRESS_FORMAT]
    set params(n_lane) [get_parameter_value N_LANE]
    set params(avs_use_data) [get_parameter_value AVS_USE_DATA]
    set params(avs_use_valid) [get_parameter_value AVS_USE_VALID]
    set params(avs_use_sop) [get_parameter_value AVS_USE_SOP]
    set params(avs_use_eop) [get_parameter_value AVS_USE_EOP]
    set params(avs_use_err) [get_parameter_value AVS_USE_ERR]
    set params(avs_use_channel) [get_parameter_value AVS_USE_CHANNEL]

    set params(output_name) $output_name

    set result          [ altera_terp $template params ]

    send_message INFO "<b>generated file: (${output_name}.vhd)</b>"
    
    # top level file 
    add_fileset_file ${output_name}.vhd VHDL TEXT $result TOP_LEVEL_FILE

    return -code ok
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
    #----------------------+
    # Ingress Interface(s) |
    #----------------------+
    for {set i 0 } {$i < [get_parameter_value N_LANE]} {incr i} {
        if {[string equal -nocase [get_parameter_value INGRESS_FORMAT] "Avalon"]} {
            add_interface ingress_${i} avalon_streaming end
            set_interface_property ingress_${i} associatedClock data_clock_intf
            set_interface_property ingress_${i} associatedReset data_reset_intf
            set_interface_property ingress_${i} dataBitsPerSymbol [get_parameter_value AVS_DATA_WIDTH]
            set_interface_property ingress_${i} errorDescriptor {}
            set_interface_property ingress_${i} firstSymbolInHighOrderBits true
            set_interface_property ingress_${i} maxChannel 0
            set_interface_property ingress_${i} readyLatency 0
            set_interface_property ingress_${i} ENABLED true
            set_interface_property ingress_${i} EXPORT_OF ""
            set_interface_property ingress_${i} PORT_NAME_MAP ""
            set_interface_property ingress_${i} CMSIS_SVD_VARIABLES ""
            set_interface_property ingress_${i} SVD_ADDRESS_GROUP ""

            if {[get_parameter_value AVS_USE_DATA]} {
                add_interface_port ingress_${i} asi_ingress_${i}_data data Input [get_parameter_value AVS_DATA_WIDTH]
            }
            if {[get_parameter_value AVS_USE_VALID]} {
                add_interface_port ingress_${i} asi_ingress_${i}_valid valid Input 1
            }
            if {[get_parameter_value AVS_USE_SOP]} {
                add_interface_port ingress_${i} asi_ingress_${i}_startofpacket startofpacket Input 1
            }
            if {[get_parameter_value AVS_USE_EOP]} {
                add_interface_port ingress_${i} asi_ingress_${i}_endofpacket endofpacket Input 1
            }
            if {[get_parameter_value AVS_USE_ERR]} {
                add_interface_port ingress_${i} asi_ingress_${i}_error error Input [get_parameter_value AVS_ERROR_WIDTH]
            }
            send_message INFO "ingress I/F ([expr $i+1]/[get_parameter_value N_LANE]) type: <b>Avalon Streaming</b>" 
        } elseif {[string equal -nocase [get_parameter_value INGRESS_FORMAT] "AXI4"]} {
            send_message ERROR "AXI4 ingress format is not supported yet"
        } else {
            add_interface ingress_${i} conduit end
            add_interface_port ingress_${i} cds_ingress_${i}_data data Input [get_parameter_value MU3E_SIG_WIDTH]
            set_interface_property ingress_${i} associatedClock data_clock_intf
            set_interface_property ingress_${i} associatedReset data_reset_intf
            send_message INFO "ingress I/F ([expr $i+1]/[get_parameter_value N_LANE]) type: <b>conduit (Mu3e)</b>" 
        }
    }
    #---------------------+
    # Egress Interface(s) |
    #---------------------+
    for {set i 0 } {$i < [get_parameter_value N_LANE]} {incr i} {
        if {[string equal -nocase [get_parameter_value EGRESS_FORMAT] "Avalon"]} {
            add_interface egress_${i} avalon_streaming start
            set_interface_property egress_${i} associatedClock data_clock_intf
            set_interface_property egress_${i} associatedReset data_reset_intf
            set_interface_property egress_${i} dataBitsPerSymbol [get_parameter_value AVS_DATA_WIDTH]
            set_interface_property egress_${i} errorDescriptor {}
            set_interface_property egress_${i} firstSymbolInHighOrderBits true
            set_interface_property egress_${i} maxChannel 0
            set_interface_property egress_${i} readyLatency 0
            set_interface_property egress_${i} ENABLED true
            set_interface_property egress_${i} EXPORT_OF ""
            set_interface_property egress_${i} PORT_NAME_MAP ""
            set_interface_property egress_${i} CMSIS_SVD_VARIABLES ""
            set_interface_property egress_${i} SVD_ADDRESS_GROUP ""

            if {[get_parameter_value AVS_USE_DATA]} {
                add_interface_port egress_${i} aso_egress_${i}_data data Output [get_parameter_value AVS_DATA_WIDTH]
            }
            if {[get_parameter_value AVS_USE_VALID]} {
                add_interface_port egress_${i} aso_egress_${i}_valid valid Output 1
            }
            if {[get_parameter_value AVS_USE_SOP]} {
                add_interface_port egress_${i} aso_egress_${i}_startofpacket startofpacket Output 1
            }
            if {[get_parameter_value AVS_USE_EOP]} {
                add_interface_port egress_${i} aso_egress_${i}_endofpacket endofpacket Output 1
            }
            if {[get_parameter_value AVS_USE_ERR]} {
                add_interface_port egress_${i} aso_egress_${i}_error error Output [get_parameter_value AVS_ERROR_WIDTH]
            }
            send_message INFO "egress I/F ([expr $i+1]/[get_parameter_value N_LANE]) type: <b>Avalon Streaming</b>" 
        } elseif {[string equal -nocase [get_parameter_value EGRESS_FORMAT] "AXI4"]} {
            send_message ERROR "AXI4 egress format is not supported yet"
        } else {
            add_interface egress_${i} conduit end
            add_interface_port egress_${i} cdm_egress_${i}_data data Output [get_parameter_value MU3E_SIG_WIDTH]
            set_interface_property egress_${i} associatedClock data_clock_intf 
            set_interface_property egress_${i} associatedReset data_reset_intf
            send_message INFO "egress I/F ([expr $i+1]/[get_parameter_value N_LANE]) type: <b>conduit (Mu3e)</b>" 
        }
    }


    send_message INFO "elaboration <b>ok</b>"
}

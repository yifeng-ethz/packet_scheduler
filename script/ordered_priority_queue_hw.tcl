#
# Author: Yifeng Wang (yifenwan@phys.ethz.ch)
#
package require -exact qsys 16.1
# altera_terp is shipped with ACDS under
# $QUARTUS_ROOTDIR/../ip/altera/common/hw_tcl_packages/altera_terp.tcl
package require -exact altera_terp 1.0

set_module_property NAME                             ordered_priority_queue
set_module_property DISPLAY_NAME                     "Ordered Priority Queue"
set_module_property VERSION                          26.4.4.0427
set_module_property DESCRIPTION                      "Ordered Priority Queue Mu3e IP Core"
set_module_property GROUP                            "Mu3e Data Plane/Modules"
set_module_property AUTHOR                           "Yifeng Wang (yifenwan@phys.ethz.ch)"
set_module_property ICON_PATH                        ../../firmware_builds/misc/logo/mu3e_logo.png
set_module_property INTERNAL                         false
set_module_property OPAQUE_ADDRESS_MAP               true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE     true
set_module_property EDITABLE                         true
set_module_property REPORT_TO_TALKBACK               false
set_module_property ALLOW_GREYBOX_GENERATION         false
set_module_property REPORT_HIERARCHY                 false
set_module_property ELABORATION_CALLBACK             elaborate
set_module_property VALIDATION_CALLBACK              validate

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

proc is_power_of_two {value} {
    if {$value < 1} {
        return 0
    }
    return [expr {($value & ($value - 1)) == 0}]
}

proc ceil_log2 {value} {
    if {$value <= 1} {
        return 0
    }

    set log2_v 0
    set threshold 1
    while {$threshold < $value} {
        set threshold [expr {$threshold << 1}]
        incr log2_v
    }
    return $log2_v
}

proc derive_channel_width {n_lane} {
    set width [ceil_log2 $n_lane]
    if {$width < 2} {
        set width 2
    }
    return $width
}

proc derive_lane_fifo_width {data_w datak_w} {
    # Lane FIFO stores the ingress symbol plus sop/eop/hit_err/reserved bits.
    return [expr {$data_w + $datak_w + 4}]
}

proc derive_ticket_fifo_depth {n_shd n_lane} {
    set target_lane [expr {$n_shd * 32}]
    set target_scan [expr {$n_shd * $n_lane * 2}]
    set target $target_lane
    if {$target_scan > $target} {
        set target $target_scan
    }
    set depth 256
    while {$depth < $target} {
        set depth [expr {$depth * 2}]
    }
    return $depth
}

proc derive_handle_fifo_depth {} {
    return 64
}

proc derive_page_ram_rd_width {data_w datak_w} {
    return [expr {$data_w + $datak_w}]
}

proc legal_page_ram_rd_widths {data_w datak_w} {
    set beat_w [expr {$data_w + $datak_w}]
    return [list $beat_w [expr {$beat_w * 2}] [expr {$beat_w * 4}] [expr {$beat_w * 8}]]
}

proc derive_empty_width {symbols_per_beat} {
    set empty_w [ceil_log2 $symbols_per_beat]
    if {$empty_w < 1} {
        set empty_w 1
    }
    return $empty_w
}

proc derive_hit_payload_width {data_w} {
    switch -- $data_w {
        32 { return 24 }
        64 { return 32 }
        default { return 0 }
    }
}

proc sync_auto_parameters {} {
    set n_lane      [get_parameter_value N_LANE]
    set data_w      [get_parameter_value INGRESS_DATA_WIDTH]
    set datak_w     [get_parameter_value INGRESS_DATAK_WIDTH]
    set n_shd       [get_parameter_value N_SHD]

    set_parameter_value CHANNEL_WIDTH     [derive_channel_width $n_lane]
    set_parameter_value LANE_FIFO_WIDTH   [derive_lane_fifo_width $data_w $datak_w]
    set_parameter_value TICKET_FIFO_DEPTH [derive_ticket_fifo_depth $n_shd $n_lane]
    set_parameter_value HANDLE_FIFO_DEPTH [derive_handle_fifo_depth]
}

proc opq_define_preset {name desc params} {
    variable OPQ_PRESETS
    variable OPQ_PRESET_DESC
    variable OPQ_PRESET_ORDER

    dict set OPQ_PRESETS $name $params
    dict set OPQ_PRESET_DESC $name $desc
    lappend OPQ_PRESET_ORDER $name
}

variable OPQ_PRESETS [dict create]
variable OPQ_PRESET_DESC [dict create]
variable OPQ_PRESET_ORDER [list]

opq_define_preset "2LANE_BASE" \
    "2-lane representative preset. N_SHD fixed to 128, base 36-bit symbol contract, balanced initial lane FIFO depth." \
    {
        N_LANE              2
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     1024
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "2LANE_DEEP" \
    "2-lane deeper-FIFO representative preset. Same 36-bit symbol contract, N_SHD fixed to 128, larger lane skew tolerance." \
    {
        N_LANE              2
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     2048
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "4LANE_BASE" \
    "4-lane representative preset. N_SHD fixed to 128, base 36-bit symbol contract, balanced initial lane FIFO depth." \
    {
        N_LANE              4
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     2048
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "4LANE_DEEP" \
    "4-lane deeper-FIFO representative preset. Same 36-bit symbol contract, N_SHD fixed to 128, larger lane skew tolerance." \
    {
        N_LANE              4
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     4096
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "8LANE_BASE" \
    "8-lane representative preset. N_SHD fixed to 128, base 36-bit symbol contract, balanced initial lane FIFO depth." \
    {
        N_LANE              8
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     4096
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "8LANE_DEEP" \
    "8-lane deeper-FIFO representative preset. Same 36-bit symbol contract, N_SHD fixed to 128, larger lane skew tolerance." \
    {
        N_LANE              8
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     8192
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "16LANE_BASE" \
    "16-lane representative preset. N_SHD fixed to 128, base 36-bit symbol contract, balanced initial lane FIFO depth." \
    {
        N_LANE              16
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     8192
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

opq_define_preset "16LANE_DEEP" \
    "16-lane deeper-FIFO representative preset. Same 36-bit symbol contract, N_SHD fixed to 128, larger lane skew tolerance." \
    {
        N_LANE              16
        MODE                MERGING
        TRACK_HEADER        true
        INGRESS_DATA_WIDTH  32
        INGRESS_DATAK_WIDTH 4
        LANE_FIFO_DEPTH     16384
        PAGE_RAM_DEPTH      65536
        N_SHD               128
        N_HIT               255
    }

proc opq_get_preset_names {} {
    variable OPQ_PRESET_ORDER
    return $OPQ_PRESET_ORDER
}

proc opq_apply_preset {preset_name} {
    variable OPQ_PRESETS

    if {$preset_name eq "CUSTOM"} {
        sync_auto_parameters
        return
    }

    if {![dict exists $OPQ_PRESETS $preset_name]} {
        send_message error "Unknown OPQ preset: $preset_name"
        return
    }

    set params [dict get $OPQ_PRESETS $preset_name]
    dict for {pname pval} $params {
        if {[catch {set_parameter_value $pname $pval} err]} {
            send_message warning "Preset $preset_name: failed to set $pname=$pval: $err"
        }
    }
    sync_auto_parameters
}

proc opq_apply_preset_if_needed {} {
    set preset [get_parameter_value PRESET]
    if {$preset eq ""} {
        set preset "CUSTOM"
    }
    opq_apply_preset $preset
}

proc opq_preset_summary_html {selected_preset} {
    variable OPQ_PRESETS
    variable OPQ_PRESET_DESC
    variable OPQ_PRESET_ORDER

    set html "<html><b>Representative preset selector</b><br/>"
    append html "Concrete presets intentionally pin <b>N_SHD=128</b> and the safe current <b>32 data + 4 datak</b> ingress contract. "
    append html "PAGE_RAM_RD_WIDTH remains selectable as 1x/2x/4x/8x OPQ symbols per egress beat for the active wide-egress DV closure.<br/><br/>"
    append html "<table border=\"1\" cellpadding=\"3\" width=\"100%\">"
    append html "<tr><th>Preset</th><th>N_LANE</th><th>LANE_FIFO_DEPTH</th><th>Ingress</th><th>Egress</th><th>Description</th></tr>"
    foreach name $OPQ_PRESET_ORDER {
        set params [dict get $OPQ_PRESETS $name]
        set n_lane [dict get $params N_LANE]
        set lane_fifo_depth [dict get $params LANE_FIFO_DEPTH]
        set desc [dict get $OPQ_PRESET_DESC $name]
        set preset_label $name
        if {$name eq $selected_preset} {
            set preset_label "<b>$name</b>"
        }
        append html "<tr><td>$preset_label</td><td>$n_lane</td><td>$lane_fifo_depth</td><td>32+4</td><td>36/72/144/288</td><td><small>$desc</small></td></tr>"
    }
    append html "</table><br/><b>CUSTOM</b> leaves the individual parameters editable; the named presets are representative starting points rather than a signoff claim on the full matrix space.</html>"
    return $html
}

# ────────────────────────────────────────────────────────────────────────────
# Identity constants — packaged 2026-04-24
# ────────────────────────────────────────────────────────────────────────────
# UID = ASCII "OPQM" (Ordered Priority Queue, Monolithic) = 0x4F50514D
set IP_UID_DEFAULT_CONST        1330663757
set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 4
set VERSION_PATCH_DEFAULT_CONST 4
set BUILD_DEFAULT_CONST         427
set VERSION_DATE_DEFAULT_CONST  20260427
# 32-bit packaged provenance stamp for this release family
set VERSION_GIT_DEFAULT_CONST   36303022
set INSTANCE_ID_DEFAULT_CONST   0
set OPQ_VERSION_STRING          [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]
set OPQ_GIT_HEX_STRING          [format "0x%08X" $VERSION_GIT_DEFAULT_CONST]

set OPQ_VERSIONING_HTML {<html><b>Common identity header</b><br/>CSR word <b>0x001</b> selects the META page on write and returns the selected payload on read.<br/><br/><b>Page 0</b>: VERSION word, encoded as YEAR[31:24], MINOR[23:16], PATCH[15:12], BUILD[11:0].<br/><b>Page 1</b>: VERSION_DATE (YYYYMMDD).<br/><b>Page 2</b>: VERSION_GIT (32-bit truncated git stamp).<br/><b>Page 3</b>: INSTANCE_ID.</html>}
set OPQ_CSR_WINDOW_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x000</td><td>UID</td><td>RO</td><td>Immutable Mu3e IP identifier. Default ASCII "OPQM".</td></tr>
<tr><td>0x001</td><td>META</td><td>RW/RO</td><td>Write page selector[1:0]. Read selected page: VERSION / DATE / GIT / INSTANCE_ID.</td></tr>
<tr><td>0x002</td><td>LANE_MASK</td><td>RW</td><td>Bit <i>i</i> = 1 masks lane <i>i</i> at packet boundaries. In-flight packets drain; new packets on masked lanes are dropped and counted.</td></tr>
<tr><td>0x003</td><td>CTRL</td><td>WO</td><td>Bit 0 = write-1 pulse to clear all software-visible counters.</td></tr>
<tr><td>0x004</td><td>STATUS</td><td>RO</td><td>Lane-mask summary, busy flags, and effective-mask state.</td></tr>
<tr><td>0x005</td><td>CAP</td><td>RO</td><td>Capability summary and per-lane counter-window geometry.</td></tr>
<tr><td>0x008..0x010</td><td>FT_* Counters</td><td>RO</td><td>Frame-table write/read/drop counters for headers, subheaders, and hits.</td></tr>
<tr><td>0x040 + lane*0x10 + 0..A</td><td>Lane Counters</td><td>RO</td><td>Per-lane write/read/drop counters plus live lane/ticket free-credit counters.</td></tr>
<tr><td>0x040 + lane*0x10 + B</td><td>DRR_ALLOWANCE</td><td>RW</td><td>Per-lane deficit-round-robin refill allowance in page words per participating subheader. Write also reseeds the live quantum.</td></tr>
<tr><td>0x040 + lane*0x10 + C..F</td><td>DRR Live / Stats</td><td>RO</td><td>Live DRR deficit budget plus per-lane block-grant / served-beat / defer-round counters.</td></tr>
</table></html>}
set OPQ_META_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[1:0]</b> write-only selector</td><td>PAGE_SEL</td><td>Selects which identity payload is returned on the next read: 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</td></tr>
<tr><td><b>[31:0]</b> read data</td><td>META_PAYLOAD</td><td>Selected identity payload returned by the read-side mux.</td></tr>
</table></html>}
set OPQ_CTRL_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[0]</b></td><td>CLEAR_COUNTERS</td><td>Write-1 pulse. Clears all per-lane and frame-table software-visible counters.</td></tr>
<tr><td><b>[31:1]</b></td><td>RESERVED</td><td>Ignored; write zero for forward compatibility.</td></tr>
</table></html>}
set OPQ_STATUS_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[N_LANE-1:0]</b></td><td>LANE_MASK_SHADOW</td><td>Software-programmed lane mask value.</td></tr>
<tr><td><b>[16]</b></td><td>ALLOC_BUSY</td><td>High when <code>page_allocator_state != IDLE</code>.</td></tr>
<tr><td><b>[17]</b></td><td>ARBITER_BUSY</td><td>High when the page-RAM write-port arbiter is not idle.</td></tr>
<tr><td><b>[18]</b></td><td>PRESENTER_BUSY</td><td>High when the frame-table presenter is not idle.</td></tr>
<tr><td><b>[19]</b></td><td>MASK_EFFECTIVE</td><td>High when any lane is currently blocked at the packet-boundary gate.</td></tr>
<tr><td><b>[23:20]</b></td><td>N_LANE</td><td>Packaged lane count of the instantiated core.</td></tr>
<tr><td><b>[31:24]</b></td><td>RESERVED</td><td>Reads zero.</td></tr>
</table></html>}
set OPQ_CAP_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[0]</b></td><td>UID_META_HEADER</td><td>Common Mu3e UID + META header is implemented.</td></tr>
<tr><td><b>[1]</b></td><td>LANE_MASK_CTRL</td><td>Software lane masking at packet boundaries is implemented.</td></tr>
<tr><td><b>[2]</b></td><td>PER_LANE_CNTRS</td><td>Per-lane write/read/drop and credit counters are implemented.</td></tr>
<tr><td><b>[3]</b></td><td>FT_CNTRS</td><td>Frame-table write/read/drop counters are implemented.</td></tr>
<tr><td><b>[4]</b></td><td>DRR_CTRL</td><td>Per-lane DRR allowance programming and live observability are implemented.</td></tr>
<tr><td><b>[7:5]</b></td><td>RESERVED</td><td>Reads zero.</td></tr>
<tr><td><b>[15:8]</b></td><td>LANE_REGION_STRIDE</td><td>Per-lane CSR region stride in words (default 0x10).</td></tr>
<tr><td><b>[23:16]</b></td><td>LANE_REGION_BASE</td><td>Base word address of the per-lane counter window (default 0x40).</td></tr>
<tr><td><b>[31:24]</b></td><td>N_LANE</td><td>Number of instantiated ingress lanes.</td></tr>
</table></html>}
set OPQ_FTABLE_COUNTERS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Name</th><th>Description</th></tr>
<tr><td>0x008</td><td>FT_WR_HDR</td><td>Headers committed into frame-table ownership.</td></tr>
<tr><td>0x009</td><td>FT_WR_SHD</td><td>Subheaders committed into frame-table ownership.</td></tr>
<tr><td>0x00A</td><td>FT_WR_HIT</td><td>Hits committed into frame-table ownership.</td></tr>
<tr><td>0x00B</td><td>FT_RD_HDR</td><td>Headers retired through the egress presenter.</td></tr>
<tr><td>0x00C</td><td>FT_RD_SHD</td><td>Subheaders retired through the egress presenter.</td></tr>
<tr><td>0x00D</td><td>FT_RD_HIT</td><td>Hits retired through the egress presenter.</td></tr>
<tr><td>0x00E</td><td>FT_DROP_HDR</td><td>Headers dropped by frame-table overwrite / overwrite recovery.</td></tr>
<tr><td>0x00F</td><td>FT_DROP_SHD</td><td>Subheaders dropped by frame-table overwrite / overwrite recovery.</td></tr>
<tr><td>0x010</td><td>FT_DROP_HIT</td><td>Hits dropped by frame-table overwrite / overwrite recovery.</td></tr>
</table></html>}
set OPQ_LANE_REGION_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Offset</th><th>Name</th><th>Description</th></tr>
<tr><td>+0</td><td>WR_HDR_CNT</td><td>Per-lane header tickets accepted from ingress parsing.</td></tr>
<tr><td>+1</td><td>WR_SHD_CNT</td><td>Per-lane subheader tickets accepted from ingress parsing.</td></tr>
<tr><td>+2</td><td>WR_HIT_CNT</td><td>Per-lane hit words written into the lane FIFO.</td></tr>
<tr><td>+3</td><td>RD_HDR_CNT</td><td>Per-lane header tickets consumed by the page allocator.</td></tr>
<tr><td>+4</td><td>RD_SHD_CNT</td><td>Per-lane subheaders accepted into the merged page stream.</td></tr>
<tr><td>+5</td><td>RD_HIT_CNT</td><td>Per-lane hits accepted into the merged page stream.</td></tr>
<tr><td>+6</td><td>DROP_HDR_CNT</td><td>Per-lane dropped headers before frame-table ownership.</td></tr>
<tr><td>+7</td><td>DROP_SHD_CNT</td><td>Per-lane dropped subheaders before frame-table ownership.</td></tr>
<tr><td>+8</td><td>DROP_HIT_CNT</td><td>Per-lane dropped hits before frame-table ownership.</td></tr>
<tr><td>+9</td><td>LANE_FREE_CREDIT</td><td>Current lane-FIFO free-credit counter for that lane.</td></tr>
<tr><td>+A</td><td>TICKET_FREE_CREDIT</td><td>Current ticket-FIFO free-credit counter for that lane.</td></tr>
<tr><td>+B</td><td>DRR_ALLOWANCE</td><td>Software-programmed DRR refill allowance for that lane. Lower values force more defer rounds before a whole block becomes eligible; write also reseeds the live budget.</td></tr>
<tr><td>+C</td><td>DRR_QUANTUM_LIVE</td><td>Current live DRR quantum / deficit budget for that lane.</td></tr>
<tr><td>+D</td><td>DRR_GRANT_CNT</td><td>Number of block-level arbiter lock windows granted to that lane.</td></tr>
<tr><td>+E</td><td>DRR_BEAT_CNT</td><td>Number of page-RAM data beats actually served from that lane by the block mover.</td></tr>
<tr><td>+F</td><td>DRR_DEFER_CNT</td><td>Number of defer rounds where that lane requested service but could not yet cover the whole block length.</td></tr>
</table></html>}

# ────────────────────────────────────────────────────────────────────────────
# Derived-value / GUI-text helper
# ────────────────────────────────────────────────────────────────────────────
proc compute_derived_values {} {
    opq_apply_preset_if_needed
    sync_auto_parameters

    set preset          [get_parameter_value PRESET]
    set n_lane          [get_parameter_value N_LANE]
    set mode            [get_parameter_value MODE]
    set track_header    [get_parameter_value TRACK_HEADER]
    set data_w          [get_parameter_value INGRESS_DATA_WIDTH]
    set datak_w         [get_parameter_value INGRESS_DATAK_WIDTH]
    set channel_w       [get_parameter_value CHANNEL_WIDTH]
    set lane_fifo_d     [get_parameter_value LANE_FIFO_DEPTH]
    set lane_fifo_w     [get_parameter_value LANE_FIFO_WIDTH]
    set ticket_fifo_d   [get_parameter_value TICKET_FIFO_DEPTH]
    set handle_fifo_d   [get_parameter_value HANDLE_FIFO_DEPTH]
    set page_ram_d      [get_parameter_value PAGE_RAM_DEPTH]
    set page_ram_rd_w   [get_parameter_value PAGE_RAM_RD_WIDTH]
    set n_shd           [get_parameter_value N_SHD]
    set n_hit           [get_parameter_value N_HIT]

    set ingress_beat_w  [expr {$data_w + $datak_w}]
    set hit_payload_w   [derive_hit_payload_width $data_w]
    set symbols_per_beat 1
    if {$ingress_beat_w > 0 && $page_ram_rd_w >= $ingress_beat_w} {
        set symbols_per_beat [expr {$page_ram_rd_w / $ingress_beat_w}]
    }
    set empty_w [derive_empty_width $symbols_per_beat]

    set lane_store_bits   [expr {$n_lane * $lane_fifo_d  * $lane_fifo_w}]
    set ticket_store_bits [expr {$n_lane * $ticket_fifo_d * 16}]
    set handle_store_bits [expr {$n_lane * $handle_fifo_d * 16}]
    set page_ram_bits     [expr {$page_ram_d * $lane_fifo_w}]
    set total_store_bits  [expr {$lane_store_bits + $ticket_store_bits + $handle_store_bits + $page_ram_bits}]

    set worst_case_hits_per_frame [expr {$n_shd * $n_hit}]

    set_parameter_value INGRESS_BEAT_WIDTH_DERIVED   $ingress_beat_w
    set_parameter_value EGRESS_SYMBOLS_PER_BEAT_DERIVED $symbols_per_beat
    set_parameter_value EGRESS_EMPTY_WIDTH_DERIVED   $empty_w

    catch {
        set_display_item_property sizing_html TEXT "<html><b>Derived storage and auto-sized knobs</b><br/>Ingress symbol: <b>${ingress_beat_w}</b> bits = data <b>${data_w}</b> + datak <b>${datak_w}</b><br/>CHANNEL_WIDTH auto = <b>${channel_w}</b> (compatibility floor of 2 bits, then grows with N_LANE)<br/>LANE_FIFO_WIDTH auto = <b>${lane_fifo_w}</b> bits = ingress symbol + sop/eop/hit_err/reserved<br/>TICKET_FIFO_DEPTH auto = <b>${ticket_fifo_d}</b> (smallest power-of-two at or above max(32 \u00d7 N_SHD, 2 \u00d7 N_SHD \u00d7 N_LANE), minimum 256)<br/>HANDLE_FIFO_DEPTH auto = <b>${handle_fifo_d}</b><br/>PAGE_RAM_RD_WIDTH selected = <b>${page_ram_rd_w}</b> bits = <b>${symbols_per_beat}</b> OPQ symbol(s) per egress beat<br/>EGRESS_EMPTY_WIDTH derived = <b>${empty_w}</b><br/>Hit payload model: current packaged point = <b>${data_w}</b>-bit hit word with <b>${hit_payload_w}</b>-bit non-timestamp payload<br/><br/><b>Derived storage</b><br/>Lane FIFO storage: <b>${lane_store_bits}</b> bits (${n_lane} \u00d7 ${lane_fifo_d} \u00d7 ${lane_fifo_w})<br/>Ticket FIFO storage: <b>${ticket_store_bits}</b> bits<br/>Handle FIFO storage: <b>${handle_store_bits}</b> bits<br/>Page RAM storage: <b>${page_ram_bits}</b> bits (${page_ram_d} \u00d7 ${lane_fifo_w})<br/>Total on-chip memory: <b>${total_store_bits}</b> bits</html>"
    }
    catch {
        set_display_item_property packet_html TEXT "<html><b>Packet format</b><br/>Current packaged release uses a <b>${ingress_beat_w}</b>-bit symbol: datak[${ingress_beat_w}-1:${data_w}] + data[${data_w}-1:0].<br/><table border=\"1\" cellpadding=\"3\" width=\"100%\"><tr><th>Segment</th><th>Words</th><th>Marker</th><th>Current layout</th></tr><tr><td>Header preamble</td><td>1</td><td><b>K285</b> / 0xBC</td><td>datak=<b>0001</b>, data[31:26]=dt_type, data[23:8]=feb_id, data[7:0]=K285</td></tr><tr><td>Header payload</td><td>4</td><td>data</td><td>word1=frame_ts[47:16], word2=frame_ts[15:0]|pkg_cnt, word3=subheader_cnt|hit_cnt, word4=send_ts[30:0]</td></tr><tr><td>Subheader</td><td>1 each</td><td><b>K237</b> / 0xF7</td><td>datak=<b>0001</b>, data[31:24]=subheader_ts, data[15:8]=hit_cnt, data[7:0]=K237</td></tr><tr><td>Hit</td><td>1 each</td><td>data</td><td>datak=<b>0000</b>, data[31:0]=hit word. Current packaged point: 32-bit hit word with 24-bit non-timestamp payload.</td></tr><tr><td>Trailer</td><td>1</td><td><b>K284</b> / 0x9C</td><td>datak=<b>0001</b>, data[7:0]=K284</td></tr></table><br/><b>Packet limits</b><br/>TRACK_HEADER is fixed to <b>${track_header}</b> in this release.<br/>Subheaders per header packet: <b>${n_shd}</b><br/>Max hits per subheader: <b>${n_hit}</b><br/>Max hits per header packet: <b>${worst_case_hits_per_frame}</b> (worst case before <i>ingress parser</i> drop)</html>"
    }
    catch {
        set_display_item_property throughput_html TEXT "<html><b>Expected throughput</b><br/>Aggregation mode: <b>${mode}</b><br/>Current packaged egress beat: <b>${page_ram_rd_w}</b> bits/cycle = <b>${symbols_per_beat}</b> OPQ ingress symbol(s) per egress beat<br/>Per-lane ingress budget: <b>${ingress_beat_w}</b> bits/cycle at the shared data-path clock<br/>Lossless equal-load share guideline: the selected egress pack ratio gives each lane roughly <b>${symbols_per_beat}/${n_lane}</b> of the sustained symbol budget before packet-overhead effects.<br/>Block-mover scheduling: shared page-RAM write port is serviced by an <b>ordered block-level DRR arbiter</b> with software-tunable per-lane refill allowance.<br/>Backpressure: ingress lanes are <i>non-backlog</i> (drop-on-full inside the lane/ticket FIFOs); egress honours <code>ready</code> and exports <code>empty</code> for packet-tail packing.</html>"
    }
    catch {
        set_display_item_property profile_html TEXT "<html><b>Catalog revision</b><br/>This release is packaged as <b>${::OPQ_VERSION_STRING}</b> (git <b>${::OPQ_GIT_HEX_STRING}</b>).<br/><br/><b>Packaged legal points</b><br/>N_LANE=<b>{2,4,8,16}</b>, MODE=<b>MERGING</b>, TRACK_HEADER=<b>true</b>, ingress=<b>32 data + 4 datak</b>, N_SHD=<b>{64,128,256,512}</b>, PAGE_RAM_RD_WIDTH=<b>{36,72,144,288}</b>. CHANNEL_WIDTH, LANE_FIFO_WIDTH, TICKET_FIFO_DEPTH, HANDLE_FIFO_DEPTH, EGRESS_SYMBOLS_PER_BEAT, and EGRESS_EMPTY_WIDTH are derived for the selected point.<br/><br/><b>Representative preset family</b><br/>The preset menu adds nine GUI options (<b>CUSTOM</b> plus eight named presets). All concrete named presets pin <b>N_SHD=128</b> and scale <b>N_LANE</b> plus <b>LANE_FIFO_DEPTH</b> as a starting point for later quantitative analysis.<br/><br/><b>Deferred preset axes</b><br/>64-bit / 128-bit hit words remain future work because the current monolithic ingress parser still uses the 32-bit hit-word contract.<br/><br/><b>Current instance</b><br/>PRESET=<b>${preset}</b>, MODE=<b>${mode}</b>, N_LANE=<b>${n_lane}</b>, N_SHD=<b>${n_shd}</b>, N_HIT=<b>${n_hit}</b>, CHANNEL_WIDTH=<b>${channel_w}</b>, PAGE_RAM_RD_WIDTH=<b>${page_ram_rd_w}</b>.<br/><br/><b>Runtime visibility</b><br/>The monolithic OPQ exposes a runtime <b>CSR Avalon-MM slave</b>. Software can read the common Mu3e <b>UID + META</b> header, inspect per-lane write/read/drop counters, inspect frame-table ownership counters, clear counter state, program a per-lane packet-boundary mask, and tune the per-lane <b>DRR allowance</b> used by the shared page-RAM arbiter.</html>"
    }
    catch {
        set_display_item_property preset_html TEXT [opq_preset_summary_html $preset]
    }
}

# ────────────────────────────────────────────────────────────────────────────
# Validation callback
# ────────────────────────────────────────────────────────────────────────────
proc validate {} {
    compute_derived_values

    set n_lane          [get_parameter_value N_LANE]
    set mode            [get_parameter_value MODE]
    set track_header    [get_parameter_value TRACK_HEADER]
    set data_w          [get_parameter_value INGRESS_DATA_WIDTH]
    set datak_w         [get_parameter_value INGRESS_DATAK_WIDTH]
    set channel_w       [get_parameter_value CHANNEL_WIDTH]
    set lane_fifo_d     [get_parameter_value LANE_FIFO_DEPTH]
    set lane_fifo_w     [get_parameter_value LANE_FIFO_WIDTH]
    set ticket_fifo_d   [get_parameter_value TICKET_FIFO_DEPTH]
    set handle_fifo_d   [get_parameter_value HANDLE_FIFO_DEPTH]
    set page_ram_d      [get_parameter_value PAGE_RAM_DEPTH]
    set page_ram_rd_w   [get_parameter_value PAGE_RAM_RD_WIDTH]
    set n_shd           [get_parameter_value N_SHD]
    set n_hit           [get_parameter_value N_HIT]
    set debug_lv        [get_parameter_value DEBUG_LV]

    set ingress_beat_w  [expr {$data_w + $datak_w}]
    set expected_channel_w   [derive_channel_width $n_lane]
    set expected_lane_fifo_w [derive_lane_fifo_width $data_w $datak_w]
    set expected_ticket_d    [derive_ticket_fifo_depth $n_shd $n_lane]
    set expected_handle_d    [derive_handle_fifo_depth]
    set legal_page_rd_ws     [legal_page_ram_rd_widths $data_w $datak_w]

    if {[lsearch -exact {2 4 8 16} $n_lane] < 0} {
        send_message error "N_LANE must be one of {2, 4, 8, 16} in the packaged release."
    }
    if {$mode ne "MERGING"} {
        send_message error "MODE is fixed to MERGING in the packaged release."
    }
    if {!$track_header} {
        send_message error "TRACK_HEADER is fixed to true in the packaged release."
    }
    if {$data_w != 32} {
        send_message error "INGRESS_DATA_WIDTH is constrained to 32 bits in the current packaged release; 64/128-bit hit-word expansion is staged future work."
    }
    if {$datak_w != 4} {
        send_message error "INGRESS_DATAK_WIDTH is constrained to 4 bits in the current packaged release."
    }
    if {$datak_w * 8 != $data_w} {
        send_message error "INGRESS_DATAK_WIDTH (${datak_w}) must match one K-flag bit per ingress data byte (${data_w}/8)."
    }
    if {$channel_w != $expected_channel_w} {
        send_message error "CHANNEL_WIDTH (${channel_w}) is auto-derived from N_LANE and must be ${expected_channel_w}."
    }
    if {![is_power_of_two $lane_fifo_d] || $lane_fifo_d < 16 || $lane_fifo_d > 65536} {
        send_message error "LANE_FIFO_DEPTH must be a power of two in 16..65536 (ring-buffer wrap)."
    }
    if {$lane_fifo_w != $expected_lane_fifo_w} {
        send_message error "LANE_FIFO_WIDTH (${lane_fifo_w}) is auto-derived from the ingress symbol and must be ${expected_lane_fifo_w}."
    }
    if {$ticket_fifo_d != $expected_ticket_d} {
        send_message error "TICKET_FIFO_DEPTH (${ticket_fifo_d}) is auto-derived from N_SHD and N_LANE and must be ${expected_ticket_d}."
    }
    if {$handle_fifo_d != $expected_handle_d} {
        send_message error "HANDLE_FIFO_DEPTH (${handle_fifo_d}) is auto-derived and must be ${expected_handle_d}."
    }
    if {![is_power_of_two $page_ram_d]} {
        send_message error "PAGE_RAM_DEPTH must be a power of two."
    }
    if {[lsearch -exact $legal_page_rd_ws $page_ram_rd_w] < 0} {
        send_message error "PAGE_RAM_RD_WIDTH (${page_ram_rd_w}) must select one of ${legal_page_rd_ws} for 1/2/4/8 OPQ symbols per egress beat."
    }
    if {[lsearch -exact {64 128 256 512} $n_shd] < 0} {
        send_message error "N_SHD must be one of {64, 128, 256, 512}."
    }
    if {$n_hit < 1} {
        send_message error "N_HIT must be at least 1."
    }
    if {$debug_lv < 0 || $debug_lv > 2} {
        send_message error "DEBUG_LV must stay in 0..2."
    }
    if {$channel_w < 2 || $channel_w > 4} {
        send_message error "CHANNEL_WIDTH must stay in 2..4 for the packaged lane points."
    }
}

# ────────────────────────────────────────────────────────────────────────────
# Elaboration callback — dynamic ingress fan-out + egress port sizing
# ────────────────────────────────────────────────────────────────────────────
proc elaborate {} {
    compute_derived_values

    set n_lane      [get_parameter_value N_LANE]
    set data_w      [get_parameter_value INGRESS_DATA_WIDTH]
    set datak_w     [get_parameter_value INGRESS_DATAK_WIDTH]
    set channel_w   [get_parameter_value CHANNEL_WIDTH]
    set ingress_beat_w [expr {$data_w + $datak_w}]

    set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES [list $channel_w]
    set_parameter_property LANE_FIFO_WIDTH ALLOWED_RANGES [list [get_parameter_value LANE_FIFO_WIDTH]]
    set_parameter_property TICKET_FIFO_DEPTH ALLOWED_RANGES [list [get_parameter_value TICKET_FIFO_DEPTH]]
    set_parameter_property HANDLE_FIFO_DEPTH ALLOWED_RANGES [list [get_parameter_value HANDLE_FIFO_DEPTH]]
    set_parameter_property PAGE_RAM_RD_WIDTH ALLOWED_RANGES [legal_page_ram_rd_widths $data_w $datak_w]

    set page_ram_rd_w    [get_parameter_value PAGE_RAM_RD_WIDTH]
    set symbols_per_beat [expr {$page_ram_rd_w / $ingress_beat_w}]
    set empty_w          [derive_empty_width $symbols_per_beat]

    # ---- Ingress sinks (one per lane) --------------------------------------
    for {set i 0} {$i < $n_lane} {incr i} {
        add_interface ingress_${i} avalon_streaming end
        set_interface_property ingress_${i} associatedClock clk_interface
        set_interface_property ingress_${i} associatedReset rst_interface
        set_interface_property ingress_${i} dataBitsPerSymbol $ingress_beat_w
        set_interface_property ingress_${i} errorDescriptor {hit_err shd_err hdr_err}
        set_interface_property ingress_${i} firstSymbolInHighOrderBits true
        set_interface_property ingress_${i} maxChannel [expr {$n_lane - 1}]
        set_interface_property ingress_${i} readyLatency 0
        set_interface_property ingress_${i} ENABLED true

        if {$channel_w > 0} {
            add_interface_port ingress_${i} asi_ingress_${i}_channel channel Input $channel_w
        }
        add_interface_port ingress_${i} asi_ingress_${i}_startofpacket startofpacket Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_endofpacket   endofpacket   Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_data          data          Input $ingress_beat_w
        add_interface_port ingress_${i} asi_ingress_${i}_valid         valid         Input 1
        add_interface_port ingress_${i} asi_ingress_${i}_error         error         Input 3
    }

    # ---- Egress source — dynamic data + optional empty ---------------------
    add_interface_port egress aso_egress_data data Output $page_ram_rd_w
    set_port_property aso_egress_data WIDTH_EXPR $page_ram_rd_w
    add_interface_port egress aso_egress_empty empty Output $empty_w
    set_port_property aso_egress_empty WIDTH_EXPR $empty_w
    set_interface_property egress symbolsPerBeat    $symbols_per_beat
    set_interface_property egress dataBitsPerSymbol $ingress_beat_w

    # Release identity is HDL-backed. Keep the packaged release stamp fixed in the
    # GUI, but allow INSTANCE_ID override per instantiated system.
    set_parameter_property IP_UID         ENABLED false
    set_parameter_property VERSION_MAJOR  ENABLED false
    set_parameter_property VERSION_MINOR  ENABLED false
    set_parameter_property VERSION_PATCH  ENABLED false
    set_parameter_property BUILD          ENABLED false
    set_parameter_property VERSION_DATE   ENABLED false
    set_parameter_property VERSION_GIT    ENABLED false
    set_parameter_property INSTANCE_ID    ENABLED true
    set_parameter_property INGRESS_DATA_WIDTH  ENABLED false
    set_parameter_property INGRESS_DATAK_WIDTH ENABLED false
    set_parameter_property MODE               ENABLED false
    set_parameter_property TRACK_HEADER       ENABLED false
    set_parameter_property CHANNEL_WIDTH      ENABLED false
    set_parameter_property LANE_FIFO_WIDTH    ENABLED false
    set_parameter_property TICKET_FIFO_DEPTH  ENABLED false
    set_parameter_property HANDLE_FIFO_DEPTH  ENABLED false
    set_parameter_property PAGE_RAM_RD_WIDTH  ENABLED true
}

# ────────────────────────────────────────────────────────────────────────────
# Fileset — terp-based generation of the monolithic core
# ────────────────────────────────────────────────────────────────────────────
add_fileset synth QUARTUS_SYNTH my_generate

proc my_generate {output_name} {
    set template_file "rtl/legacy/ordered_priority_queue/monolithic/ordered_priority_queue.terp.vhd"
    set template      [read [open $template_file r]]

    set data_w  [get_parameter_value INGRESS_DATA_WIDTH]
    set datak_w [get_parameter_value INGRESS_DATAK_WIDTH]
    set beat_w  [expr {$data_w + $datak_w}]
    set out_w   [get_parameter_value PAGE_RAM_RD_WIDTH]
    set empty_w [derive_empty_width [expr {$out_w / $beat_w}]]

    set params(n_lane)             [get_parameter_value N_LANE]
    set params(fifos_names)        [list "ticket_fifo" "lane_fifo" "handle_fifo"]
    set params(egress_empty_width) $empty_w
    set params(output_name)        $output_name

    set result [altera_terp $template params]

    send_message INFO "generated top-level file: ${output_name}.vhd"

    add_fileset_file ${output_name}.vhd VHDL TEXT $result TOP_LEVEL_FILE
    add_fileset_file "handle_fifo.v" VERILOG PATH "rtl/sv_ver/vendor/alt_ram/handle_fifo.v"
    add_fileset_file "lane_fifo.v"   VERILOG PATH "rtl/sv_ver/vendor/alt_ram/lane_fifo.v"
    add_fileset_file "ticket_fifo.v" VERILOG PATH "rtl/sv_ver/vendor/alt_ram/ticket_fifo.v"
    add_fileset_file "page_ram.v"    VERILOG PATH "rtl/sv_ver/vendor/alt_ram/page_ram.v"
    add_fileset_file "tile_fifo.v"   VERILOG PATH "rtl/sv_ver/vendor/alt_ram/tile_fifo.v"
}

# ────────────────────────────────────────────────────────────────────────────
# HDL parameters (mirror the entity generics of the monolithic core)
# ────────────────────────────────────────────────────────────────────────────
add_parameter PRESET STRING "2LANE_BASE"
set_parameter_property PRESET DISPLAY_NAME "Representative Preset"
set_parameter_property PRESET ALLOWED_RANGES [linsert [opq_get_preset_names] 0 CUSTOM]
set_parameter_property PRESET HDL_PARAMETER false
set_parameter_property PRESET DESCRIPTION "Representative preset selector for the `_hw.tcl` GUI. The named presets pin N_SHD=128 and scale N_LANE plus LANE_FIFO_DEPTH. CUSTOM leaves the individual parameters editable."

add_parameter N_LANE NATURAL 2
set_parameter_property N_LANE DISPLAY_NAME "Number of Ingress Lanes"
set_parameter_property N_LANE ALLOWED_RANGES {2 4 8 16}
set_parameter_property N_LANE HDL_PARAMETER true
set_parameter_property N_LANE DESCRIPTION "Number of ingress lanes aggregated into the single egress flow."

add_parameter MODE STRING "MERGING"
set_parameter_property MODE DISPLAY_NAME "Aggregation Mode"
set_parameter_property MODE ALLOWED_RANGES {MERGING}
set_parameter_property MODE HDL_PARAMETER true
set_parameter_property MODE DESCRIPTION "Packaged release is fixed to MERGING. MULTIPLEXING remains out of the current signoff scope."

add_parameter TRACK_HEADER BOOLEAN true
set_parameter_property TRACK_HEADER DISPLAY_NAME "Track Header"
set_parameter_property TRACK_HEADER DISPLAY_HINT "RADIO"
set_parameter_property TRACK_HEADER ALLOWED_RANGES {"true:Required"}
set_parameter_property TRACK_HEADER HDL_PARAMETER true
set_parameter_property TRACK_HEADER DESCRIPTION "Packaged release is fixed to true so the header timestamp anchors subsequent subheader packets."

add_parameter INGRESS_DATA_WIDTH NATURAL 32
set_parameter_property INGRESS_DATA_WIDTH DISPLAY_NAME "Ingress Data Width"
set_parameter_property INGRESS_DATA_WIDTH UNITS Bits
set_parameter_property INGRESS_DATA_WIDTH ALLOWED_RANGES {32}
set_parameter_property INGRESS_DATA_WIDTH HDL_PARAMETER true
set_parameter_property INGRESS_DATA_WIDTH DESCRIPTION "Current packaged release uses 32-bit hit words. Planned 64-bit / 128-bit hit-word expansion is documented but not exposed as a legal point yet."

add_parameter INGRESS_DATAK_WIDTH NATURAL 4
set_parameter_property INGRESS_DATAK_WIDTH DISPLAY_NAME "Ingress DataK Width"
set_parameter_property INGRESS_DATAK_WIDTH UNITS Bits
set_parameter_property INGRESS_DATAK_WIDTH ALLOWED_RANGES {4}
set_parameter_property INGRESS_DATAK_WIDTH HDL_PARAMETER true
set_parameter_property INGRESS_DATAK_WIDTH DESCRIPTION "One K-flag bit per ingress data byte. Current packaged release locks this to 4 bits for a 32-bit hit word."

add_parameter CHANNEL_WIDTH NATURAL 2
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Channel Width"
set_parameter_property CHANNEL_WIDTH UNITS Bits
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES {2 3 4}
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH DESCRIPTION "Auto-derived from N_LANE with a compatibility floor of 2 bits. Current legal lane points map to {2,2,3,4} bits for N_LANE={2,4,8,16}, so the packaged legal set is {2,3,4}."

add_parameter LANE_FIFO_DEPTH NATURAL 1024
set_parameter_property LANE_FIFO_DEPTH DISPLAY_NAME "Lane FIFO Depth"
set_parameter_property LANE_FIFO_DEPTH ALLOWED_RANGES {16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536}
set_parameter_property LANE_FIFO_DEPTH HDL_PARAMETER true
set_parameter_property LANE_FIFO_DEPTH DESCRIPTION "Per-lane FIFO depth between the ingress parser and the block mover. Sets max lane-to-lane skew tolerated and the page allocator wait budget. Must be a power of two (ring-buffer wrap). Credit-controlled."

add_parameter LANE_FIFO_WIDTH NATURAL 40
set_parameter_property LANE_FIFO_WIDTH DISPLAY_NAME "Lane FIFO Width"
set_parameter_property LANE_FIFO_WIDTH UNITS Bits
set_parameter_property LANE_FIFO_WIDTH ALLOWED_RANGES {40}
set_parameter_property LANE_FIFO_WIDTH HDL_PARAMETER true
set_parameter_property LANE_FIFO_WIDTH DESCRIPTION "Auto-derived from ingress symbol width plus sop/eop/hit_err/reserved bits. Current packaged base point is 40 bits = 32 data + 4 datak + 4 control bits. Future 64-bit hit-word support will require widening this auto-derived value together with the parser/presenter path."

add_parameter TICKET_FIFO_DEPTH NATURAL 256
set_parameter_property TICKET_FIFO_DEPTH DISPLAY_NAME "Ticket FIFO Depth"
set_parameter_property TICKET_FIFO_DEPTH ALLOWED_RANGES {256 512 1024 2048 4096 8192 16384}
set_parameter_property TICKET_FIFO_DEPTH HDL_PARAMETER true
set_parameter_property TICKET_FIFO_DEPTH DESCRIPTION "Auto-derived from N_SHD and N_LANE as the smallest power-of-two at or above max(32*N_SHD, 2*N_SHD*N_LANE), with a minimum of 256."

add_parameter HANDLE_FIFO_DEPTH NATURAL 64
set_parameter_property HANDLE_FIFO_DEPTH DISPLAY_NAME "Handle FIFO Depth"
set_parameter_property HANDLE_FIFO_DEPTH ALLOWED_RANGES {64}
set_parameter_property HANDLE_FIFO_DEPTH HDL_PARAMETER true
set_parameter_property HANDLE_FIFO_DEPTH DESCRIPTION "Auto-derived fixed handle depth for the packaged release. Current legal point is 64."

add_parameter PAGE_RAM_DEPTH NATURAL 65536
set_parameter_property PAGE_RAM_DEPTH DISPLAY_NAME "Page RAM Depth"
set_parameter_property PAGE_RAM_DEPTH ALLOWED_RANGES {8192 16384 32768 65536}
set_parameter_property PAGE_RAM_DEPTH HDL_PARAMETER true
set_parameter_property PAGE_RAM_DEPTH DESCRIPTION "Page RAM depth in units of lane-FIFO words. Must be larger than the full header packet. The 3-segment scheme reserves 2 for ring-buffer write and 1 for read continuation to resolve read/write contention while keeping the most recent packet available."

add_parameter PAGE_RAM_RD_WIDTH NATURAL 36
set_parameter_property PAGE_RAM_RD_WIDTH DISPLAY_NAME "Page RAM Read Width"
set_parameter_property PAGE_RAM_RD_WIDTH UNITS Bits
set_parameter_property PAGE_RAM_RD_WIDTH ALLOWED_RANGES {36 72 144 288}
set_parameter_property PAGE_RAM_RD_WIDTH HDL_PARAMETER true
set_parameter_property PAGE_RAM_RD_WIDTH DESCRIPTION "Selectable egress read/pack width for 1/2/4/8 OPQ symbols per Avalon-ST egress beat. Legal values for the 32d+4k ingress contract are 36, 72, 144, and 288 bits; EGRESS_EMPTY_WIDTH is derived from the selected pack ratio."

add_parameter N_SHD NATURAL 128
set_parameter_property N_SHD DISPLAY_NAME "Subheaders per Header Packet"
set_parameter_property N_SHD ALLOWED_RANGES {64 128 256 512}
set_parameter_property N_SHD HDL_PARAMETER true
set_parameter_property N_SHD DESCRIPTION "Number of subheader packets contained in one header packet. Packaged legal sweep is 64 / 128 / 256 / 512."

add_parameter N_HIT NATURAL 255
set_parameter_property N_HIT DISPLAY_NAME "Hits per Subheader Packet"
set_parameter_property N_HIT ALLOWED_RANGES {255 511 1023 2047}
set_parameter_property N_HIT HDL_PARAMETER true
set_parameter_property N_HIT DESCRIPTION "Maximum hits per subheader packet. Hits past this count are dropped by the ingress parser. Larger values require widening the subheader <b>hit_cnt</b> mask."

add_parameter HDR_SIZE NATURAL 5
set_parameter_property HDR_SIZE DISPLAY_NAME "Header Size"
set_parameter_property HDR_SIZE UNITS None
set_parameter_property HDR_SIZE ALLOWED_RANGES 1:16
set_parameter_property HDR_SIZE HDL_PARAMETER true
set_parameter_property HDR_SIZE DESCRIPTION "Header length in lane-FIFO words."

add_parameter SHD_SIZE NATURAL 1
set_parameter_property SHD_SIZE DISPLAY_NAME "Subheader Size"
set_parameter_property SHD_SIZE UNITS None
set_parameter_property SHD_SIZE ALLOWED_RANGES 1:16
set_parameter_property SHD_SIZE HDL_PARAMETER true
set_parameter_property SHD_SIZE DESCRIPTION "Subheader length in lane-FIFO words."

add_parameter HIT_SIZE NATURAL 1
set_parameter_property HIT_SIZE DISPLAY_NAME "Hit Size"
set_parameter_property HIT_SIZE UNITS None
set_parameter_property HIT_SIZE ALLOWED_RANGES 1:16
set_parameter_property HIT_SIZE HDL_PARAMETER true
set_parameter_property HIT_SIZE DESCRIPTION "Hit length in lane-FIFO words."

add_parameter TRL_SIZE NATURAL 1
set_parameter_property TRL_SIZE DISPLAY_NAME "Trailer Size"
set_parameter_property TRL_SIZE UNITS None
set_parameter_property TRL_SIZE ALLOWED_RANGES 1:16
set_parameter_property TRL_SIZE HDL_PARAMETER true
set_parameter_property TRL_SIZE DESCRIPTION "Trailer length in lane-FIFO words."

add_parameter FRAME_SERIAL_SIZE NATURAL 16
set_parameter_property FRAME_SERIAL_SIZE DISPLAY_NAME "Frame Serial Size"
set_parameter_property FRAME_SERIAL_SIZE UNITS Bits
set_parameter_property FRAME_SERIAL_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_SERIAL_SIZE HDL_PARAMETER true
set_parameter_property FRAME_SERIAL_SIZE DESCRIPTION "Width of the frame serial number field (see Mu3e spec book)."

add_parameter FRAME_SUBH_CNT_SIZE NATURAL 16
set_parameter_property FRAME_SUBH_CNT_SIZE DISPLAY_NAME "Frame Subheader Count Size"
set_parameter_property FRAME_SUBH_CNT_SIZE UNITS Bits
set_parameter_property FRAME_SUBH_CNT_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_SUBH_CNT_SIZE HDL_PARAMETER true
set_parameter_property FRAME_SUBH_CNT_SIZE DESCRIPTION "Width of the frame subheader-count field."

add_parameter FRAME_HIT_CNT_SIZE NATURAL 16
set_parameter_property FRAME_HIT_CNT_SIZE DISPLAY_NAME "Frame Hit Count Size"
set_parameter_property FRAME_HIT_CNT_SIZE UNITS Bits
set_parameter_property FRAME_HIT_CNT_SIZE ALLOWED_RANGES 1:32
set_parameter_property FRAME_HIT_CNT_SIZE HDL_PARAMETER true
set_parameter_property FRAME_HIT_CNT_SIZE DESCRIPTION "Width of the frame hit-count field."

add_parameter DEBUG_LV NATURAL 1
set_parameter_property DEBUG_LV DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG_LV ALLOWED_RANGES {0 1 2}
set_parameter_property DEBUG_LV HDL_PARAMETER true
set_parameter_property DEBUG_LV DESCRIPTION "0 = off, 1 = synthesizable debug, 2 = simulation-only debug."

# ────────────────────────────────────────────────────────────────────────────
# Identity parameters — common Mu3e UID + META header (HDL-backed)
# ────────────────────────────────────────────────────────────────────────────
add_parameter IP_UID NATURAL $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID ALLOWED_RANGES 0:2147483647
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DESCRIPTION {ASCII four-char Mu3e IP identifier. Exposed at CSR word 0x00.}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR DISPLAY_NAME "Version Major"
set_parameter_property VERSION_MAJOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MAJOR HDL_PARAMETER true

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR DISPLAY_NAME "Version Minor"
set_parameter_property VERSION_MINOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MINOR HDL_PARAMETER true

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH DISPLAY_NAME "Version Patch"
set_parameter_property VERSION_PATCH ALLOWED_RANGES 0:15
set_parameter_property VERSION_PATCH HDL_PARAMETER true

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD DISPLAY_NAME "Build Stamp"
set_parameter_property BUILD ALLOWED_RANGES 0:4095
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD DESCRIPTION {12-bit MMDD packaging stamp packed into META page 0 VERSION[11:0].}

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE DISPLAY_NAME "Version Date"
set_parameter_property VERSION_DATE ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE DESCRIPTION {YYYYMMDD packaging date exposed through META page 1.}

add_parameter VERSION_GIT NATURAL $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT DISPLAY_NAME "Git Stamp"
set_parameter_property VERSION_GIT ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT DESCRIPTION {Truncated submodule git hash exposed through META page 2.}

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID ALLOWED_RANGES 0:2147483647
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID DESCRIPTION {Per-instance integration identifier exposed through META page 3.}

# ────────────────────────────────────────────────────────────────────────────
# Derived (hidden) parameters
# ────────────────────────────────────────────────────────────────────────────
foreach derived_name {INGRESS_BEAT_WIDTH_DERIVED EGRESS_SYMBOLS_PER_BEAT_DERIVED EGRESS_EMPTY_WIDTH_DERIVED} {
    add_parameter $derived_name NATURAL 0
    set_parameter_property $derived_name HDL_PARAMETER false
    set_parameter_property $derived_name DERIVED true
    set_parameter_property $derived_name VISIBLE false
}

# ────────────────────────────────────────────────────────────────────────────
# GUI — 4-tab Mu3e layout
# ────────────────────────────────────────────────────────────────────────────
set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item "" $TAB_IDENTITY      GROUP tab
add_display_item "" $TAB_INTERFACES    GROUP tab
add_display_item "" $TAB_REGMAP        GROUP tab

# ---- Configuration ---------------------------------------------------------
add_display_item $TAB_CONFIGURATION "Overview"       GROUP
add_display_item $TAB_CONFIGURATION "Presets"        GROUP
add_display_item $TAB_CONFIGURATION "Aggregation"    GROUP
add_display_item $TAB_CONFIGURATION "Ingress Format" GROUP
add_display_item $TAB_CONFIGURATION "Sizing"         GROUP
add_display_item $TAB_CONFIGURATION "Packet Format"  GROUP
add_display_item $TAB_CONFIGURATION "Throughput"     GROUP
add_display_item $TAB_CONFIGURATION "Debug"          GROUP

add_html_text "Overview" overview_html {<html><b>Function</b><br/>Aggregates <i>N_LANE</i> ingress Avalon-ST flows (one per FEB) into a single timestamp-ordered egress flow. The monolithic core owns the full datapath: per-lane <b>ingress parser</b> \u2192 <b>lane FIFO</b> + <b>ticket FIFO</b> \u2192 <b>page allocator</b> \u2192 <b>block mover</b> \u2192 <b>ordered block-level DRR arbiter</b> \u2192 <b>page RAM</b> (3-segment dynamic) \u2192 packed egress.<br/><br/><b>Current packaged scope</b><br/>This release packages the 36-bit OPQ symbol contract: <b>32-bit data + 4-bit datak</b>, <b>MERGING</b> mode only, <b>TRACK_HEADER=true</b>, <b>N_LANE={2,4,8,16}</b>, <b>N_SHD={64,128,256,512}</b>, and egress packing at <b>1/2/4/8</b> OPQ symbols per beat. Wider hit words remain staged future work.<br/><br/><b>Clocking</b><br/>Single synchronous data-path domain (<code>d_clk</code> / <code>d_reset</code>) shared by all lanes and the egress path.<br/><br/><b>Flow control</b><br/>Ingress lanes are non-backlog (drop-on-full inside the lane/ticket FIFOs). The egress source honours Avalon-ST <code>ready</code>.</html>}

add_display_item "Presets" PRESET parameter
add_html_text "Presets" preset_html "<html><b>Representative preset selector</b><br/>Loading preset matrix...</html>"

add_display_item "Aggregation" N_LANE       parameter
add_display_item "Aggregation" MODE         parameter
add_display_item "Aggregation" TRACK_HEADER parameter

add_display_item "Ingress Format" INGRESS_DATA_WIDTH  parameter
add_display_item "Ingress Format" INGRESS_DATAK_WIDTH parameter
add_display_item "Ingress Format" CHANNEL_WIDTH       parameter

add_display_item "Sizing" LANE_FIFO_DEPTH   parameter
add_display_item "Sizing" LANE_FIFO_WIDTH   parameter
add_display_item "Sizing" TICKET_FIFO_DEPTH parameter
add_display_item "Sizing" HANDLE_FIFO_DEPTH parameter
add_display_item "Sizing" PAGE_RAM_DEPTH    parameter
add_display_item "Sizing" PAGE_RAM_RD_WIDTH parameter
add_html_text "Sizing" sizing_html "<html><b>Derived storage</b><br/>Updated by the validation callback.</html>"

add_display_item "Packet Format" N_SHD               parameter
add_display_item "Packet Format" N_HIT               parameter
add_display_item "Packet Format" HDR_SIZE            parameter
add_display_item "Packet Format" SHD_SIZE            parameter
add_display_item "Packet Format" HIT_SIZE            parameter
add_display_item "Packet Format" TRL_SIZE            parameter
add_display_item "Packet Format" FRAME_SERIAL_SIZE   parameter
add_display_item "Packet Format" FRAME_SUBH_CNT_SIZE parameter
add_display_item "Packet Format" FRAME_HIT_CNT_SIZE  parameter
add_html_text "Packet Format" packet_html "<html><b>Packet limits</b><br/>Updated by the validation callback.</html>"

add_html_text "Throughput" throughput_html "<html><b>Expected throughput</b><br/>Updated by the validation callback.</html>"

add_display_item "Debug" DEBUG_LV parameter

# ---- Identity --------------------------------------------------------------
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_display_item $TAB_IDENTITY "Versioning"        GROUP

add_html_text "Delivered Profile" profile_html "<html><b>Catalog revision</b><br/>Loading packaged profile text...</html>"

add_html_text "Versioning" versioning_html $OPQ_VERSIONING_HTML
add_display_item "Versioning" IP_UID        parameter
add_display_item "Versioning" VERSION_MAJOR parameter
add_display_item "Versioning" VERSION_MINOR parameter
add_display_item "Versioning" VERSION_PATCH parameter
add_display_item "Versioning" BUILD         parameter
add_display_item "Versioning" VERSION_DATE  parameter
add_display_item "Versioning" VERSION_GIT   parameter
add_display_item "Versioning" INSTANCE_ID   parameter

# ---- Interfaces ------------------------------------------------------------
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Ingress"       GROUP
add_display_item $TAB_INTERFACES "Egress"        GROUP
add_display_item $TAB_INTERFACES "CSR"           GROUP

add_html_text "Clock / Reset" clock_html "<html><b>clk_interface</b> / <b>rst_interface</b><br/>Single synchronous data-path domain. All ingress lanes and the egress source are associated with this clock/reset pair.</html>"

add_html_text "Ingress" ingress_html {<html><b>ingress_0 \u2026 ingress_<i>N_LANE-1</i></b> — Avalon-ST <i>sinks</i>, one per FEB lane. <i>Non-backlog</i>: no <code>ready</code> exported; full FIFOs drop the in-flight packet internally.<br/><br/><b>Current packaged symbol layout (36 bits)</b><br/><table border="1" cellpadding="3" width="100%"><tr><th>Bits</th><th>Field</th><th>Description</th></tr><tr><td>[35:32]</td><td>datak</td><td>8b/10b control-symbol flag per data byte. <code>0001</code> marks K-coded header/subheader/trailer words; <code>0000</code> marks hit words.</td></tr><tr><td>[31:0]</td><td>data</td><td>Header payload, subheader payload, or hit word.</td></tr></table><br/>Sidebands: <code>channel</code> (<i>CHANNEL_WIDTH</i> bits, auto-derived from <i>N_LANE</i>), <code>startofpacket</code>, <code>endofpacket</code>, <code>valid</code>, <code>error[2:0] = {hit_err, shd_err, hdr_err}</code>. An asserted <code>error</code> blocks the remainder of the packet until <code>eop</code> and revokes it.</html>}

add_html_text "Egress" egress_html {<html><b>egress</b> — Avalon-ST <i>source</i>.<br/><table border="1" cellpadding="3" width="100%"><tr><th>Port</th><th>Direction</th><th>Width</th><th>Description</th></tr><tr><td>data</td><td>out</td><td>PAGE_RAM_RD_WIDTH</td><td>Selected 36/72/144/288-bit pack width, equal to 1/2/4/8 OPQ symbols per egress beat.</td></tr><tr><td>empty</td><td>out</td><td>EGRESS_EMPTY_WIDTH_DERIVED</td><td>Avalon-ST packet-tail empty count for multi-symbol egress packing; width is at least 1 bit.</td></tr><tr><td>startofpacket / endofpacket</td><td>out</td><td>1</td><td>Packet framing.</td></tr><tr><td>valid / ready</td><td>out / in</td><td>1</td><td>Standard Avalon-ST handshake (backpressured).</td></tr><tr><td>error[2:0]</td><td>out</td><td>3</td><td>{hit_err, shd_err, hdr_err} — propagated from ingress parser.</td></tr></table></html>}

add_html_text "CSR" csr_html {<html><b>csr</b> — Avalon-MM <i>slave</i>, 32-bit data, 9-bit word address.<br/>Implements the common Mu3e UID + META identity header plus OPQ-specific runtime control and counters. <b>LANE_MASK</b> applies at packet boundaries: in-flight packets drain, then new packets on masked lanes are dropped and accounted. The per-lane region also exposes a <b>DRR allowance</b> register and live arbiter observability for scheduler tuning under real traffic.</html>}

# ---- Register Map ----------------------------------------------------------
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_window_html $OPQ_CSR_WINDOW_HTML
add_display_item $TAB_REGMAP "META Fields (0x001)" GROUP
add_html_text "META Fields (0x001)" meta_fields_html $OPQ_META_FIELDS_HTML
add_display_item $TAB_REGMAP "CTRL Fields (0x003)" GROUP
add_html_text "CTRL Fields (0x003)" ctrl_fields_html $OPQ_CTRL_FIELDS_HTML
add_display_item $TAB_REGMAP "STATUS Fields (0x004)" GROUP
add_html_text "STATUS Fields (0x004)" status_fields_html $OPQ_STATUS_FIELDS_HTML
add_display_item $TAB_REGMAP "CAP Fields (0x005)" GROUP
add_html_text "CAP Fields (0x005)" cap_fields_html $OPQ_CAP_FIELDS_HTML
add_display_item $TAB_REGMAP "Frame-Table Counters (0x008..0x010)" GROUP
add_html_text "Frame-Table Counters (0x008..0x010)" ftable_fields_html $OPQ_FTABLE_COUNTERS_HTML
    add_display_item $TAB_REGMAP "Lane Region (0x040 + lane*0x10)" GROUP
    add_html_text "Lane Region (0x040 + lane*0x10)" lane_region_html $OPQ_LANE_REGION_HTML

# ────────────────────────────────────────────────────────────────────────────
# Static interfaces — egress source + clock + reset
# (ingress sinks are added dynamically in the elaborate callback)
# ────────────────────────────────────────────────────────────────────────────
add_interface egress avalon_streaming start
set_interface_property egress associatedClock        clk_interface
set_interface_property egress associatedReset        rst_interface
set_interface_property egress errorDescriptor        {hit_err shd_err hdr_err}
set_interface_property egress firstSymbolInHighOrderBits true
set_interface_property egress readyLatency           0
set_interface_property egress ENABLED                true
add_interface_port egress aso_egress_startofpacket startofpacket Output 1
add_interface_port egress aso_egress_endofpacket   endofpacket   Output 1
add_interface_port egress aso_egress_valid         valid         Output 1
add_interface_port egress aso_egress_ready         ready         Input  1
add_interface_port egress aso_egress_error         error         Output 3

add_interface clk_interface clock end
set_interface_property clk_interface clockRate 0
set_interface_property clk_interface ENABLED   true
add_interface_port clk_interface d_clk clk Input 1

add_interface rst_interface reset end
set_interface_property rst_interface associatedClock  clk_interface
set_interface_property rst_interface synchronousEdges BOTH
set_interface_property rst_interface ENABLED          true
add_interface_port rst_interface d_reset reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clk_interface
set_interface_property csr associatedReset rst_interface
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr burstcountUnits WORDS
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 1
set_interface_property csr maximumPendingWriteTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input 9
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_readdatavalid readdatavalid Output 1
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
add_interface_port csr avs_csr_burstcount burstcount Input 1

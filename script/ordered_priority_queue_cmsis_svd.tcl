package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. .. dashboard_infra cmsis_svd lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::csr_offset {word_address} {
    return [format "0x%X" [expr {int($word_address) * 4}]]
}

proc ::mu3e::cmsis::spec::value_register {name word_address description access} {
    return [::mu3e::cmsis::svd::register $name \
        [::mu3e::cmsis::spec::csr_offset $word_address] \
        -description $description \
        -access $access \
        -resetValue 0x00000000 \
        -fields [list \
            [::mu3e::cmsis::svd::field value 0 32 \
                -description $description \
                -access $access]]]
}

proc ::mu3e::cmsis::spec::lane_counter_registers {} {
    set regs {}
    set lane_words [list \
        {WR_HDR_CNT "Headers accepted from ingress parsing." read-only 32} \
        {WR_SHD_CNT "Subheaders accepted from ingress parsing." read-only 32} \
        {WR_HIT_CNT "Hit words written into the lane FIFO." read-only 32} \
        {RD_HDR_CNT "Headers consumed by the page allocator." read-only 32} \
        {RD_SHD_CNT "Subheaders accepted into the merged page stream." read-only 32} \
        {RD_HIT_CNT "Hits accepted into the merged page stream." read-only 32} \
        {DROP_HDR_CNT "Headers dropped before frame-table ownership." read-only 32} \
        {DROP_SHD_CNT "Subheaders dropped before frame-table ownership." read-only 32} \
        {DROP_HIT_CNT "Hits dropped before frame-table ownership." read-only 32} \
        {LANE_FREE_CREDIT "Live lane-FIFO free-credit word." read-only 32} \
        {TICKET_FREE_CREDIT "Live ticket-FIFO free-credit word." read-only 32} \
        {DRR_ALLOWANCE "Software-programmed DRR refill allowance in page words." read-write 10} \
        {DRR_QUANTUM_LIVE "Live DRR deficit budget." read-only 10} \
        {DRR_GRANT_CNT "Block-level arbiter grant count." read-only 32} \
        {DRR_BEAT_CNT "Page-RAM data beats served from this lane." read-only 32} \
        {DRR_DEFER_CNT "Defer rounds while this lane requested service without enough budget." read-only 32}]

    for {set lane 0} {$lane < 16} {incr lane} {
        set lane_base [expr {0x040 + ($lane * 0x010)}]
        for {set idx 0} {$idx < [llength $lane_words]} {incr idx} {
            lassign [lindex $lane_words $idx] suffix desc access width
            set name [format "LANE%02d_%s" $lane $suffix]
            set full_desc [format "%s Valid when this lane index is below CAP.N_LANE; otherwise the RTL reads zero." $desc]
            set fields {}
            if {$width < 32} {
                lappend fields [::mu3e::cmsis::svd::field value 0 $width \
                    -description $desc \
                    -access $access]
                lappend fields [::mu3e::cmsis::svd::field reserved $width [expr {32 - $width}] \
                    -description "Reserved, read as zero." \
                    -access read-only]
            } else {
                lappend fields [::mu3e::cmsis::svd::field value 0 32 \
                    -description $desc \
                    -access $access]
            }
            lappend regs [::mu3e::cmsis::svd::register $name \
                [::mu3e::cmsis::spec::csr_offset [expr {$lane_base + $idx}]] \
                -description $full_desc \
                -access $access \
                -resetValue 0x00000000 \
                -fields $fields]
        }
    }

    return $regs
}

proc ::mu3e::cmsis::spec::handle_fifo_registers {} {
    set regs {}
    for {set lane 0} {$lane < 16} {incr lane} {
        lappend regs [::mu3e::cmsis::svd::register \
            [format "HANDLE_OVF_CNT_LANE%02d" $lane] \
            [::mu3e::cmsis::spec::csr_offset [expr {0x020 + $lane}]] \
            -description "Saturating count of handle FIFO overflow or overwrite-risk events for this lane. Any nonzero count is a configuration error for this run." \
            -access read-only \
            -resetValue 0x00000000 \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description "Saturating handle FIFO overflow event count." \
                    -access read-only]]]
    }

    for {set lane 0} {$lane < 16} {incr lane} {
        lappend regs [::mu3e::cmsis::svd::register \
            [format "HANDLE_OCC_MAX_LANE%02d" $lane] \
            [::mu3e::cmsis::spec::csr_offset [expr {0x030 + $lane}]] \
            -description "Maximum observed handle FIFO occupancy for this lane since reset or CTRL.CLEAR_COUNTERS." \
            -access read-only \
            -resetValue 0x00000000 \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description "Maximum observed handle FIFO occupancy." \
                    -access read-only]]]
    }

    return $regs
}

proc ::mu3e::cmsis::spec::build_device {} {
    set registers [list \
        [::mu3e::cmsis::svd::register UID 0x000 \
            -description {Software-visible IP identifier. Default ASCII "OPQM".} \
            -access read-only \
            -resetValue 0x4F50514D \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description {Compile-time or integration-time UID word. Default ASCII "OPQM".} \
                    -access read-only]]] \
        [::mu3e::cmsis::svd::register META 0x004 \
            -description {Read-multiplexed metadata word. Write [1:0] selects VERSION, DATE, GIT, or INSTANCE_ID; reads return the selected page payload.} \
            -access read-write \
            -fields [list \
                [::mu3e::cmsis::svd::field page_sel_or_payload 0 32 \
                    -description {Writes use [1:0] as the metadata page selector; reads return the selected 32-bit payload.} \
                    -access read-write]]] \
        [::mu3e::cmsis::svd::register LANE_MASK 0x008 \
            -description "Software lane mask applied at packet boundaries. Low CAP.N_LANE bits are implemented." \
            -access read-write \
            -resetValue 0x00000000 \
            -fields [list \
                [::mu3e::cmsis::svd::field lane_mask 0 16 \
                    -description "Bit i masks lane i after the in-flight packet drains." \
                    -access read-write] \
                [::mu3e::cmsis::svd::field reserved 16 16 \
                    -description "Reserved, read as zero." \
                    -access read-only]]] \
        [::mu3e::cmsis::svd::register CTRL 0x00C \
            -description "Write-only control pulses." \
            -access write-only \
            -resetValue 0x00000000 \
            -fields [list \
                [::mu3e::cmsis::svd::field clear_counters 0 1 \
                    -description "Write one to clear all software-visible counters and sticky handle FIFO overflow status." \
                    -access w1s] \
                [::mu3e::cmsis::svd::field reserved 1 31 \
                    -description "Reserved; write zero for forward compatibility." \
                    -access read-only]]] \
        [::mu3e::cmsis::svd::register STATUS 0x010 \
            -description "Lane-mask shadow, busy flags, effective-mask status, lane count, and handle FIFO overflow summary." \
            -access read-only \
            -fields [list \
                [::mu3e::cmsis::svd::field lane_mask_shadow 0 16 \
                    -description "Software-programmed lane mask shadow. Only low CAP.N_LANE bits are active." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field alloc_busy 16 1 \
                    -description "Page allocator is active." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field arbiter_busy 17 1 \
                    -description "Page-RAM write-port arbiter is active." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field presenter_busy 18 1 \
                    -description "Egress presenter has a valid beat pending or in flight." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field mask_effective 19 1 \
                    -description "At least one lane is currently blocked at the packet-boundary mask gate." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field n_lane 20 4 \
                    -description "Instantiated lane count." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field handle_ovf_any 24 1 \
                    -description "Sticky high after any handle FIFO overflow event." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field reserved 25 7 \
                    -description "Reserved, read as zero." \
                    -access read-only]]] \
        [::mu3e::cmsis::svd::register CAP 0x014 \
            -description "Capability summary and CSR lane-region geometry." \
            -access read-only \
            -fields [list \
                [::mu3e::cmsis::svd::field uid_meta_header 0 1 \
                    -description "Common Mu3e UID and META header is implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field lane_mask_ctrl 1 1 \
                    -description "Software lane masking is implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field per_lane_cntrs 2 1 \
                    -description "Per-lane counters are implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field ft_cntrs 3 1 \
                    -description "Frame-table counters are implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field drr_ctrl 4 1 \
                    -description "DRR allowance programming and observability are implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field handle_ovf_status 5 1 \
                    -description "Handle FIFO overflow status, counters, and max occupancy registers are implemented." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field reserved 6 2 \
                    -description "Reserved, read as zero." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field lane_region_stride_words 8 8 \
                    -description "Per-lane CSR region stride in 32-bit words. Current RTL returns 0x10." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field lane_region_base_word 16 8 \
                    -description "Base word address of the per-lane CSR region. Current RTL returns 0x40." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field n_lane 24 8 \
                    -description "Number of instantiated ingress lanes." \
                    -access read-only]]] \
        [::mu3e::cmsis::spec::value_register FT_WR_HDR 0x008 \
            "Headers committed into frame-table ownership." read-only] \
        [::mu3e::cmsis::spec::value_register FT_WR_SHD 0x009 \
            "Subheaders committed into frame-table ownership." read-only] \
        [::mu3e::cmsis::spec::value_register FT_WR_HIT 0x00A \
            "Hits committed into frame-table ownership." read-only] \
        [::mu3e::cmsis::spec::value_register FT_RD_HDR 0x00B \
            "Headers retired through the egress presenter." read-only] \
        [::mu3e::cmsis::spec::value_register FT_RD_SHD 0x00C \
            "Subheaders retired through the egress presenter." read-only] \
        [::mu3e::cmsis::spec::value_register FT_RD_HIT 0x00D \
            "Hits retired through the egress presenter." read-only] \
        [::mu3e::cmsis::spec::value_register FT_DROP_HDR 0x00E \
            "Headers dropped by frame-table overwrite or overwrite recovery." read-only] \
        [::mu3e::cmsis::spec::value_register FT_DROP_SHD 0x00F \
            "Subheaders dropped by frame-table overwrite or overwrite recovery." read-only] \
        [::mu3e::cmsis::spec::value_register FT_DROP_HIT 0x010 \
            "Hits dropped by frame-table overwrite or overwrite recovery." read-only] \
        [::mu3e::cmsis::svd::register HANDLE_OVF_STATUS 0x044 \
            -description "Sticky handle FIFO overflow summary. Any asserted bit marks invalid OPQ geometry or traffic provisioning; software must stop and reconfigure." \
            -access read-only \
            -resetValue 0x00000000 \
            -fields [list \
                [::mu3e::cmsis::svd::field lane_seen 0 16 \
                    -description "Bit i is sticky after lane i handle FIFO overflow." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field any 16 1 \
                    -description "Sticky OR of all lane handle FIFO overflow bits." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field reserved 17 14 \
                    -description "Reserved, read as zero." \
                    -access read-only] \
                [::mu3e::cmsis::svd::field config_error 31 1 \
                    -description "Alias of any. Treat asserted value as an invalid configuration for the current run." \
                    -access read-only]]]]

    foreach reg [::mu3e::cmsis::spec::handle_fifo_registers] {
        lappend registers $reg
    }
    foreach reg [::mu3e::cmsis::spec::lane_counter_registers] {
        lappend registers $reg
    }

    return [::mu3e::cmsis::svd::device MU3E_ORDERED_PRIORITY_QUEUE \
        -version 26.5.1.0509 \
        -description "CMSIS-SVD description of the ordered_priority_queue CSR aperture. BaseAddress is 0 because this file describes the relative CSR aperture of the IP; system integration supplies the live slave base address." \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral ORDERED_PRIORITY_QUEUE_CSR 0x0 \
                -description "Relative CSR aperture for the ordered priority queue. Register offsets are byte offsets matching the RTL word-addressed Avalon-MM map multiplied by four." \
                -groupName MU3E_DATA_PATH \
                -addressBlockSize 0x800 \
                -registers $registers]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir ordered_priority_queue.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}

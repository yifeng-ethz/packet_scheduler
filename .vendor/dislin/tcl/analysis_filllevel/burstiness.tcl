#
# @berief           Plot 2d histogram of burstiness (delta_timestamp vs delta_arrival)
#
#                   study:          burstiness and unsortness
#                   
#                   condition:      random
#                   condition2:     interval = 200
# 
proc llog10 {iarray} {
    set tmp_lin2log [list]
    foreach item $iarray {
        if {$item == 0} {
            lappend tmp_lin2log 0
        } else {
            lappend tmp_lin2log [expr log10($item)]
        }
    }
    return $tmp_lin2log
}

############################################################
# file initialization
############################################################
load [file join [pwd] ../dislin.so]

set ctit "delta_timestamp vs delta_arrival"
set nFile 1
set nData 256

set vx_real [list]
set vy_real [list]
set y_scale_factor 1

for {set i 0} {[expr $i < $nData]} {incr i} {
    # 0.1) read file 
    # test sample 
    #set fd0 [open "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/scan_records/ss_step-${i}.txt"]
    # real file <- folders: 
    set settingName "rdm-200"; # eoptions:"hdr-100_rate-2" "rdm-1000"
    set ioport "egress"; # options: "ingress" "egress"
    set folderName "burstiness_${ioport}/$settingName"; # to open
    #set folderName "burstiness/$settingName"
    set fd0 [open "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/records_auto/${folderName}/scan_step-${i}.txt"]
    set fileName "${ioport}_$settingName"; # to save as pdf
    set lines [split [read $fd0] "\n"]
    close $fd0;
    #puts [llength $lines]
    set i_line 0
    foreach line $lines {
        if {$i_line==0} {
            lappend vx_real $line
        # for this file process the y points
        } elseif {$i_line==1} {
            set line_tmp [list]
            # scale or log each y point
            foreach point $line {
                if {$point == 0} {
                    set point_tmp 0
                } else {
                    #set point_tmp [expr log10($point)]
                    set point_tmp [expr $point]
                }
                lappend line_tmp $point_tmp
            }
            lappend vy_real $line_tmp
            
        }
        incr i_line
    }
}


set x_nbins 256
set y_nbins 256


# shuffle the bin positions from 1d to 2d
# input: 1d, bin from 0 - 255
# output: 2d
# note: the scan is from +0 to 127 and from -0 to -127 in terms of timestamp delta. 
set z_2d_matrix [list]
for {set i 0} {$i < $x_nbins} {incr i} {
    for {set j 0} {$j < $y_nbins} {incr j} {
        if {$j < 128} {
            # index y to file: ex: 0 -> 255, 127 -> 128
            lappend y_2d_matrix [lindex [lindex $vy_real [expr 255-$j]] $i]
        } else {
            # index y to file: ex: 128 -> 0, 255 -> 127
            lappend y_2d_matrix [lindex [lindex $vy_real [expr $j-128]] $i]
        }
    }
}
#puts $y_2d_matrix

############################################################
# rebinning to coarse
############################################################
# 1) enable 
set new_bin [list]
set new_bin_sz 2
set x_nbins 128
set y_nbins 128
set z_2d_matrix_rebin [list]
for {set i 0} {$i < $x_nbins} {incr i} {
    for {set j 0} {$j < $y_nbins} {incr j} {
        set new_bin [list]
        for {set k 0} {$k < $new_bin_sz} {incr k} {
            lappend new_bin [lrange $y_2d_matrix [expr $k*256 + $j*$new_bin_sz + $i*$new_bin_sz*256] [expr $k*256 + [expr $j+1]*$new_bin_sz-1 + $i*$new_bin_sz*256] ]
        }
        #lappend z_2d_matrix_rebin $new_bin
        set sum [expr 0]
        foreach items $new_bin {
            foreach item $items {
                incr sum $item
            }
        }
        #puts [format "sum : %d" $sum]
        lappend z_2d_matrix_rebin $sum
    }
}
# 2) disable rebinning
# set z_2d_matrix_rebin $y_2d_matrix
# set x_nbins 256
# set y_nbins 256


############################################################
# log 10 (Y)
############################################################
set z_2d_matrix_rebin [llog10 $z_2d_matrix_rebin ]


############################################################
# get max value(Y)
############################################################
set max 0
foreach item $z_2d_matrix_rebin {
    if {$max < $item} {
        set max $item
    }
}
puts $max

############################################################
# create integrals
############################################################
# for Y
set int_y_nbins 256
set int_y [list]
for {set j 0} {$j < $int_y_nbins} {incr j} {
    if {$j < 128} {
        set values [lindex $vy_real [expr 255-$j]]
    } else {
        set values [lindex $vy_real [expr $j-128]]
    }
    set sum 0
    foreach value $values {
        set sum [expr $value+$sum]
    }
    lappend int_y $sum
    puts [format "y: %d | sum: %f" $j $sum]
}

# for X
set int_x_nbins 256
set int_x [list]
for {set j 0} {$j < $int_x_nbins} {incr j} {
    set segment [lrange $y_2d_matrix [expr $j*256] [expr ($j+1)*256]]
    
    set sum 0
    foreach value $segment {
        set sum [expr $value+$sum]
    }
    lappend int_x $sum
    #puts [format "x: %d | sum: %f" $j $sum]
}
#puts [llength $y_2d_matrix]

############################################################
# create 3d object of projection from integrals
############################################################
# for Y
set y_proj_yray [list]
set y_proj_xray [list]
set y_proj_zray [list]
for {set i 0} {$i < $int_y_nbins} {incr i} {
    lappend y_proj_yray [expr -256 + $i*2]
    lappend y_proj_xray [expr 0]
    lappend y_proj_rray [expr 0.005]
    if {$i>127} {
        lappend y_proj_wray [expr -128+$i+1]
    } else {
        lappend y_proj_wray [expr int(1.0*0xe63946/0xffffff * 256)]
    }
    
    set y_proj_zray [llog10 $int_y]
}

# for X
set x_proj_yray [list]
set x_proj_xray [list]
set x_proj_zray [list]
set x_proj_rray [list]
set x_proj_wray [list]
for {set i 0} {$i < $int_x_nbins} {incr i} {
    lappend x_proj_yray [expr 256]
    lappend x_proj_xray [expr $i*2]
    lappend x_proj_rray [expr 0.005]
    lappend x_proj_wray [expr $i+1]
    set x_proj_zray [llog10 $int_x]
}

# for boundary 
for {set i 0} {$i < $x_nbins} {incr i} {
    lappend zone_sort_xray [expr $i*4]
    lappend zone_sort_yray [expr 0]
    lappend zone_sort_zray [expr 0]
    lappend zone_sort_rray [expr 0.05]
    lappend zone_sort_icray [expr 1]
}
for {set i 0} {$i < $x_nbins} {incr i} {
    lappend zone_ontime_xray [expr $i*2]
    lappend zone_ontime_yray [expr $i*2]
    lappend zone_ontime_zray [expr 0]
    lappend zone_ontime_rray [expr 0.05]
    lappend zone_ontime_icray [expr 1]
}
 
############################################################
# zone line 
############################################################


############################################################
# config dislin 
############################################################
set subplot_y_length 1600
Dislin::scrmod revers
Dislin::setpag da4p
Dislin::metafl cons
Dislin::setfil "./plot/burstiness/${fileName}.pdf"
Dislin::disini 
Dislin::pagera 
Dislin::complx 
Dislin::intax  

Dislin::axslen 1600 $subplot_y_length
Dislin::titlin $ctit 3
set x_real [lindex $vx_real 1]
set y_real [lindex $vy_real 1]
# setup legend
set cbuf " "
Dislin::legini $cbuf $nFile 20
Dislin::legtit "$ioport" 
set color255 1
for {set i 1} {$i < $nFile+1} {incr i} {
    Dislin::leglin $cbuf "$settingName" $i
    Dislin::legpat -1 1 1 $color255 16 $i
    #incr color255 [expr 255/$nFile]
}


############################################################
# canvas boundaries
############################################################
set x_limit [expr 4*$x_nbins]
set x_tick [expr $x_limit / 8]
set y_limit [expr 4*[expr $y_nbins/2]]
set y_tick [expr $y_limit / 4]
set smear_factor 1

# construct the position for each bin column
set stepx [expr $x_limit/$x_nbins]
set stepy [expr 2*$y_limit/$y_nbins]
for {set i 0} {$i < $x_nbins} {incr i} {
    set x [expr $i * $stepx]
    for {set j 0} {$j < $y_nbins} {incr j} {
        set y  [expr -$y_limit + $j * $stepy]
        lappend yray $y
        lappend xray $x
        lappend zlvray [expr 10*($i*256+$j)]
    } 
}


############################################################
# (disabled) zero suppression of empty Z bin 
############################################################
for { set i 0 } { $i < [llength $z_2d_matrix_rebin] } { incr i } {
    lappend xwray 4
    lappend ywray 4.0
    lappend z1ray 0
    lappend icray 60
} 
set remove_indice [list]

for {set i 0} {$i < [llength $z_2d_matrix_rebin]} {incr i} {
    if {[lindex $z_2d_matrix_rebin $i] == 0} {
        lappend remove_indice $i
    }
}
#puts $remove_indice

for {set i 0} {$i < [llength $z_2d_matrix_rebin]} {incr i} {
    if {[lsearch -exact $remove_indice $i] != -1} {
        #puts [format "found %i" $i]
    } else {
        lappend xwray_zerosupp [lindex $xwray $i]
        lappend ywray_zerosupp [lindex $ywray $i]
        lappend z1ray_zerosupp [lindex $z1ray $i]
        lappend icray_zerosupp [lindex $icray $i]
        lappend xray_zerosupp [lindex $xray $i]
        lappend yray_zerosupp [lindex $yray $i]
        lappend z_2d_matrix_rebin_zerosupp [lindex $z_2d_matrix_rebin $i]
    }
}

# set xwray $xwray_zerosupp
# set ywray $ywray_zerosupp
# set z1ray $z1ray_zerosupp
# set icray $icray_zerosupp
# set xray $xray_zerosupp
# set yray $yray_zerosupp
# set z_2d_matrix_rebin $z_2d_matrix_rebin_zerosupp
#puts [llength $z_2d_matrix_rebin]



############################################################
# debug print
############################################################
# for {set i 0 } {$i < [llength $z_2d_matrix_rebin] } {incr i } {
#     puts [format "x: %f | y: %f | z: %f" [lindex $xray $i] [lindex $yray $i] [lindex $z_2d_matrix_rebin $i]]

# }

############################################################
# plot objects in canvas
############################################################
#Dislin::polcrv linear; #STEP; 
set color255 1
for {set i 1} {$i < $nFile+1} {incr i} {
    if {$i > 1} {
        Dislin::labels none X
    }
    # set axis
    Dislin::intax  
    Dislin::autres [expr 32*$x_nbins] [expr 32*$y_nbins]
    Dislin::ax3len 2200 2200 1400
    Dislin::axspos 000 2800
    
    # set 3d view point
    Dislin::view3d 3.5 -4 4.5 ABS
    Dislin::graf3d 0 $x_limit 0 $x_tick [expr -$y_limit] [expr $y_limit] [expr -$y_limit] $y_tick 0 [expr 10] 0 [expr 1]
    Dislin::grid3d 1 1 back

    #Dislin::graf 0 65536 0 128 0.0 $max_y 0.0 $tick_y
    
    #Dislin::polcrv spline

    #Dislin::shdmod smooth surface
    
    #Dislin::dash
    #Dislin::curve [lindex $vx_real [expr $i - 1]] [lindex $vy_real [expr $i - 1]] [llength [lindex $vx_real [expr $i - 1]]]
    
    

    # curve 3d
    Dislin::polcrv linear
    Dislin::setrgb [expr 0x21 / 255.0] [expr 0x34 / 255.0] [expr 0x68 / 255.0]
    Dislin::crvt3d $y_proj_xray $y_proj_yray $y_proj_zray $y_proj_rray $y_proj_wray $int_y_nbins
    Dislin::crvt3d $x_proj_xray $x_proj_yray $x_proj_zray $x_proj_rray $x_proj_wray $int_x_nbins
    
    Dislin::setrgb [expr 0x01 / 255.0] [expr 0x00 / 255.0] [expr 0xda / 255.0]
    Dislin::curv3d $zone_sort_xray $zone_sort_yray $zone_sort_zray  [llength $zone_sort_zray]
    Dislin::curv3d $zone_ontime_xray $zone_ontime_yray $zone_ontime_zray  [llength $zone_ontime_zray]
    #Dislin::surshd 
    #Dislin::surshd $xray $x_nbins $yray $y_nbins  $z_2d_matrix_rebin   

    # set color
    Dislin::setrgb [expr 0x9e / 255.0] [expr 0xca / 255.0] [expr 0xe1 / 255.0]
    # surface grid matrix 
    Dislin::polcrv linear
    Dislin::surmat $z_2d_matrix_rebin  [expr $x_nbins] [expr $y_nbins] $smear_factor $smear_factor
    #Dislin::shdmod poly contur
    #Dislin::conshd3d $xray 128 $yray 128 $z_2d_matrix_rebin $zlvray 3000
    #Dislin::bars3d $xray $yray $z1ray $z_2d_matrix_rebin $xwray $ywray $icray [llength $z_2d_matrix_rebin]
    Dislin::color fore
    #incr color255 [expr 255/$nFile]

    Dislin::height 50
    if {$i == $nFile} {
        # plot legend 
        Dislin::legend $cbuf 3
        Dislin::title 
    }
    Dislin::endgrf 
    
}

Dislin::disfin 







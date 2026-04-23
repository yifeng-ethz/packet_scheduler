#
# @berief           Plot histogram of filllevel (fillness PDF)
#
#                   study:          dependency on delay
#                   
#                   condition:      fixed header delay injection at 100 ns
#                   condition2:     cam index = 0
# 

# 0) init
load [file join [pwd] ../dislin.so]

set ctit "fill-level of CAM (fillness PDF) (Yaxis:log10)"
set nFile 9

set vx_real [list]
set vy_real [list]
set y_scale_factor 1

for {set i 1} {[expr $i < $nFile+1]} {incr i} {
    # 0.1) read file 
    set dly [expr 100*$i]
    set fd0 [open "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/records/filllevel_ringcam/cam-0_inj-hdr_rate-1_delay-${dly}.txt"]
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
                    set point_tmp [expr log10($point)]
                }
                lappend line_tmp $point_tmp
            }
            lappend vy_real $line_tmp
            
        }
        incr i_line
    }
}
#puts [llength $vx_real]



# 1) config 
set subplot_y_length 200
Dislin::scrmod revers
Dislin::setpag da4p
Dislin::metafl cons
Dislin::setfil "./plot/plot_filllevel_delay_cam-0.pdf"
Dislin::disini 
Dislin::pagera 
Dislin::complx 
#Dislin::ticks  1 x
Dislin::intax  
Dislin::axslen 1600 $subplot_y_length
Dislin::titlin $ctit 3


set x_real [lindex $vx_real 1]
set y_real [lindex $vy_real 1]

# 2) plot
# define range
# x_range x_tick y_range y_tick



# setup legend
set cbuf " "
Dislin::legini $cbuf $nFile 20
Dislin::legtit "condition"
set color255 1
for {set i 1} {$i < $nFile+1} {incr i} {
    set dly [expr $i*100]
    Dislin::leglin $cbuf "delay = ${dly}" $i
    Dislin::legpat -1 1 1 $color255 16 $i
    incr color255 [expr 255/$nFile]
}



# plot dot with lines
set max_y 10
set tick_y [expr $max_y / 4]
Dislin::polcrv FBARS; #STEP; 
set color255 1
for {set i 1} {$i < $nFile+1} {incr i} {
    if {$i > 1} {
        Dislin::labels none X
    }

    Dislin::axspos 300 [expr 2800-$subplot_y_length*[expr $i-1]]
    
    Dislin::graf 0 1024 0 128 0.0 $max_y 0.0 $tick_y
    Dislin::setclr $color255
    #Dislin::dash
    Dislin::curve [lindex $vx_real [expr $i - 1]] [lindex $vy_real [expr $i - 1]] [llength [lindex $vx_real [expr $i - 1]]]
    Dislin::color fore
    incr color255 [expr 255/$nFile]

    if {$i == $nFile} {
        # plot legend 
        Dislin::legend $cbuf 3
        Dislin::title 
    }
    Dislin::endgrf 
    
}

Dislin::disfin 
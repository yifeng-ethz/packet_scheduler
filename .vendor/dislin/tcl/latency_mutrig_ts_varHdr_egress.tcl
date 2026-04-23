#
# @berief           Plot histogram of ingress packet rank - internal counter of deque command generator (DCG) 
#                   mutrig timestamp - global timestamp
#                   (variable header delay injection)

# 0) init
load [file join [pwd] dislin.so]

set ctit "egress packet rank - local rank of DCG (packet latency)"

set vx_real [list]
set vy_real [list]

for {set i 1} {[expr $i <= 9]} {incr i} {
    # 0.1) read file 
    set dly [expr ${i}*100]
    set fd0 [open "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/records/egress_mask03_varHdrDelay/rate_1_delay_${dly}.txt"]
    set lines [split [read $fd0] "\n"]
    close $fd0;
    #puts [llength $lines]
    set i_line 0
    foreach line $lines {
        if {$i_line==0} {
            lappend vx_real $line
        } elseif {$i_line==1} {
            # scale y, because bin width was 4 (in latency_mutrig_ts.tcl), now is 8.
            set line_tmp [list]
            foreach point $line {
                lappend line_tmp [expr $point*0.5]
            }
            lappend vy_real $line_tmp
        }
        
        
        incr i_line
    }
}


#puts [llength $vx_real]



# 1) config 
Dislin::scrmod revers
Dislin::setpag da4p
Dislin::metafl cons
Dislin::setfil "plot_packet_latency_egress_varHdrDelay.pdf"
Dislin::disini 
Dislin::pagera 
Dislin::complx 
#Dislin::ticks  1 x
Dislin::intax  
Dislin::axslen 1600 200
Dislin::titlin $ctit 3




# 2) plot
# define range
# x_range x_tick y_range y_tick



# setup legend
set cbuf " "
Dislin::legini $cbuf 9 30
Dislin::legtit "condition"
set color255 1
for {set i 1} {$i <= 9} {incr i} {
    set delay_ns [expr $i*100]
    Dislin::leglin $cbuf "header delay \(ns\) = ${delay_ns}" $i
    Dislin::legpat -1 1 1 $color255 16 $i
    incr color255 25
}



# plot dot with lines
Dislin::polcrv FBARS; #STEP; 
set color255 1
for {set i 1} {$i <= 9} {incr i} {
    if {$i > 1} {
        Dislin::labels none X
    }

    Dislin::axspos 300 [expr 2800-200*[expr $i-1]]
    Dislin::graf 2000 4000 2000 200 0.0 1e6 0.0 2.5e5
    Dislin::setclr $color255
    #Dislin::dash
    Dislin::curve [lindex $vx_real [expr $i - 1]] [lindex $vy_real [expr $i - 1]] [llength [lindex $vx_real [expr $i - 1]]]
    Dislin::color fore
    incr color255 25

    if {$i == 9} {
        # plot legend 
        Dislin::legend $cbuf 3
        Dislin::title 
    }
    Dislin::endgrf 
    
}

Dislin::disfin 
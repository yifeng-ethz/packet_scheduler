#
# @berief           Plot histogram of ingress packet rank - internal counter of deque command generator (DCG) 
#                   mutrig timestamp - global timestamp
#                   (fixed header delay injection at 100 ns)

# 0) init
load [file join [pwd] dislin.so]

set ctit "ingress packet rank - local rank of DCG (packet latency)"

set vx_real [list]
set vy_real [list]

for {set i 1} {[expr $i < 9]} {incr i} {
    # 0.1) read file 
    set fd0 [open "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/records/ingress_mask03/hm${i}.txt"]
    set lines [split [read $fd0] "\n"]
    close $fd0;
    #puts [llength $lines]
    set i_line 0
    foreach line $lines {
        if {$i_line==0} {
            lappend vx_real $line
        } elseif {$i_line==1} {
            lappend vy_real $line
        }
        incr i_line
    }
}
#puts [llength $vx_real]



# 1) config 
Dislin::scrmod revers
Dislin::setpag da4p
Dislin::metafl pdf
Dislin::setfil "plot_packet_latency_ingress.pdf"
Dislin::disini 
Dislin::pagera 
Dislin::complx 
#Dislin::ticks  1 x
Dislin::intax  
Dislin::axslen 1600 300
Dislin::titlin $ctit 3


set x_real [lindex $vx_real 1]
set y_real [lindex $vy_real 1]

# 2) plot
# define range
# x_range x_tick y_range y_tick



# setup legend
set cbuf " "
Dislin::legini $cbuf 7 20
Dislin::legtit "condition"
set color255 1
for {set i 1} {$i < 8} {incr i} {
    set rate [expr $i]
    Dislin::leglin $cbuf "ingress rate = ${rate}" $i
    Dislin::legpat -1 1 1 $color255 16 $i
    incr color255 36
}



# plot dot with lines
Dislin::polcrv FBARS; #STEP; 
set color255 1
for {set i 1} {$i < 8} {incr i} {
    if {$i > 1} {
        Dislin::labels none X
    }

    Dislin::axspos 300 [expr 2800-300*[expr $i-1]]
    Dislin::graf 000 2000 0.0 200 0.0 1e6 0.0 2.5e5
    Dislin::setclr $color255
    #Dislin::dash
    Dislin::curve [lindex $vx_real [expr $i - 1]] [lindex $vy_real [expr $i - 1]] [llength [lindex $vx_real [expr $i - 1]]]
    Dislin::color fore
    incr color255 36

    if {$i == 7} {
        # plot legend 
        Dislin::legend $cbuf 3
        Dislin::title 
    }
    Dislin::endgrf 
    
}

Dislin::disfin 
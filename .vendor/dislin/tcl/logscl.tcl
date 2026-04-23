load dislin.so

set ctit "Logarithmic Scaling"
set clab [list LOG FLOAT ELOG]

Dislin::setpag da4p
Dislin::metafl cons

Dislin::disini 
Dislin::pagera 
Dislin::complx 
Dislin::axslen 1400 500

Dislin::name   X-axis X
Dislin::name   Y-axis Y
Dislin::axsscl LOG XY

Dislin::titlin $ctit 2

for { set i 0 } { $i < 3 } { incr i } {
    set nya [expr 2650 - $i * 800]
    Dislin::labdig -1 XY
    if {$i == 1} {
      Dislin::labdig 1 Y
      Dislin::name  " " X
    }

    Dislin::axspos 500 $nya
    set s "Labels: "
    Dislin::messag [append s [lindex $clab $i]] 600 [expr $nya - 400]
    Dislin::labels [lindex $clab $i] XY
    Dislin::graf   0 3 0 1 -1 2 -1 1
    if {$i == 2} {
      Dislin::height 50
      Dislin::title 
    } 
    Dislin::endgrf 
}
Dislin::disfin 



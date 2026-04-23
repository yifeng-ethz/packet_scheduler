load dislin.so

set ctit "Interpolation Methods"

set xray [list 0. 1. 3. 4.5 6. 8. 9. 11. 12. 12.5 13. 15. 16. 17. 19. 20.]
set yray [list 2. 4. 4.5 3. 1. 7. 2. 3. 5. 2. 2.5  2. 4. 6. 5.5 4.]
set cpol [list SPLINE STEM BARS STAIRS STEP LINEAR]

Dislin::setpag da4p
Dislin::metafl cons

Dislin::disini 
Dislin::pagera 
Dislin::complx 

Dislin::incmrk 1
Dislin::hsymbl 20
Dislin::titlin $ctit 1
Dislin::axslen 1500 350
Dislin::setgrf LINE LINE LINE LINE

set nya 2700
for { set i 0 } { $i < 6 } { incr i } {
    Dislin::axspos 350 [expr $nya - $i * 350]
    Dislin::polcrv [lindex $cpol $i]
    Dislin::marker 0
    Dislin::graf   0 20 0 5 0 10 0 5
    set nx [Dislin::nxposn 1.0]
    set ny [Dislin::nyposn 8.0]
    Dislin::messag [lindex $cpol $i] $nx $ny
    Dislin::curve  $xray $yray 16

    if {$i == 5} {
      Dislin::height 50
      Dislin::title 
    }

    Dislin::endgrf 
}
Dislin::disfin 



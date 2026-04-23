load dislin.so

set n 300
set m 10
set f [expr 3.1415927 / 180.]
set step [expr 360. / ($n - 1)]

for { set i 0 } { $i < $n } { incr i } {
    set a [expr ($i * $step) * $f]
    lappend y1 $a
    set a [expr 5 * $a]
    lappend x1 [expr sin ($a)]
}

for { set i 1 } { $i <= $m } { incr i } {
    lappend x2 $i
    lappend y2 $i
}

Dislin::setpag da4p
Dislin::metafl cons
Dislin::disini 
Dislin::complx 
Dislin::pagera 

Dislin::titlin "Polar Plots" 2
Dislin::ticks  3 Y
Dislin::axends NOENDS X
Dislin::labdig -1 Y
Dislin::axslen 1000 1000
Dislin::axsorg 1050 900

Dislin::grafp  1 0 0.2 0 30
Dislin::curve  $x1 $y1 $n
Dislin::htitle 50
Dislin::title  
Dislin::endgrf 

Dislin::labdig -1 X
Dislin::axsorg 1050 2250
Dislin::labtyp VERT Y
Dislin::grafp  10 0 2 0 30
Dislin::barwth -5
Dislin::polcrv FBARS
Dislin::curve  $x2 $y2 $m

Dislin::disfin 



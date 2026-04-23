load [file join [pwd] dislin.so]
#load dislin.so

set n 101
set pi 3.1415926
set f [expr $pi / 180]
set step [expr 360.0 / ($n - 1)]

for { set i 0 } { $i < $n } { incr i } {
    lappend xray [expr $i * $step]
    set x [expr $i * $step * $f]
    lappend y1ray [expr sin ($x)]
    lappend y2ray [expr cos ($x)]
}

Dislin::metafl cons
Dislin::scrmod revers
Dislin::disini

Dislin::complx
Dislin::pagera

Dislin::name X-axis  X
Dislin::name Y-axis  Y

Dislin::axspos 450 1800 
Dislin::axslen 2200 1200 

Dislin::labdig -1 X 
Dislin::ticks 10 XY 

Dislin::titlin "Demonstration of CURVE"  1
Dislin::titlin "SIN (X), COS (X)"  3

set ic [Dislin::intrgb 0.95 0.95 0.95]
Dislin::axsbgd $ic
Dislin::graf 0 360 0 90 -1 1 -1 0.5
Dislin::setrgb 0.7 0.7 0.7
Dislin::grid 1 1

Dislin::color fore
Dislin::height 50
Dislin::title

Dislin::color red
Dislin::curve $xray $y1ray $n
Dislin::color green
Dislin::curve $xray $y2ray $n
Dislin::disfin

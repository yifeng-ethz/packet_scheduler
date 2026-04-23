load dislin.so

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

Dislin::metafl xwin
Dislin::disini
Dislin::complx

Dislin::axspos 450 1800
Dislin::axslen 2200 1200

Dislin::name X-axis X
Dislin::name Y-axis Y

Dislin::labdig -1 X
Dislin::ticks  10 XY

Dislin::titlin "Demonstration of CURVE" 1
Dislin::titlin Legend 3
 
Dislin::graf 0 360 0 90 -1 1 -1 0.5
Dislin::title

Dislin::chncrv BOTH
Dislin::curve $xray $y1ray $n
Dislin::curve $xray $y2ray $n

set cbuf " "                   
Dislin::legini $cbuf 2 7 

set nx [Dislin::nxposn 190]
set ny [Dislin::nyposn 0.75]
Dislin::leglin $cbuf "sin (x)" 1
Dislin::leglin $cbuf "cos (x)" 2
Dislin::legpos $nx $ny
Dislin::legtit Legend
Dislin::legend $cbuf 3
Dislin::disfin



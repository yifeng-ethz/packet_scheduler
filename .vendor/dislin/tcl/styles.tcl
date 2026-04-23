load dislin.so

set ctit1 "Demonstration of CURVE"
set ctit2 "Line Styles"

set ctyp  [list "SOLID"   "DOT"    "DASH"  "CHNDSH" \
                "CHNDOT"  "DASHM"  "DOTL"  "DASHL"]
set x  [list 3.0  9.0]

Dislin::metafl cons
Dislin::setpag da4p

Dislin::disini
Dislin::pagera
Dislin::complx
Dislin::center

Dislin::chncrv BOTH
Dislin::name   X-axis X
Dislin::name   Y-axis Y

Dislin::titlin $ctit1 1
Dislin::titlin $ctit2 3

Dislin::graf   0 10 0 2 0 10 0 2
Dislin::title

for { set i 0 } { $i < 8 } { incr i } {
    set y [list [expr 8.5 - $i] [expr 8.5 - $i]]
    set nx [Dislin::nxposn 1.0]
    set ny [Dislin::nyposn [lindex $y 0]]
    Dislin::messag [lindex $ctyp $i] $nx [expr $ny - 20]
    Dislin::curve $x $y 2 
}
Dislin::disfin



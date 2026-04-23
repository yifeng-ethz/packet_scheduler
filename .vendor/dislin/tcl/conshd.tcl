load dislin.so

set ctit1 "Shaded Contour Plot"
set ctit2 "F(X,Y) = (X^2% - 1)^2% + (Y^2% - 1)^2%"

set n 50
set m 50
set stepx [expr 1.6 / ($n - 1)]
set stepy [expr 1.6 / ($m - 1)]

for { set i 0 } { $i < $n } { incr i } {
    lappend xray [expr $i * $stepx]
}

for { set i 0 } { $i < $m } { incr i } {
    lappend yray [expr $i * $stepy]
}

for { set i 0 } { $i < $n } { incr i } {
    set x [lindex $xray $i]
    set x [expr $x * $x - 1]
    set x [expr $x * $x]
    for { set j 0 } { $j < $m } { incr j } {
        set y [lindex $yray $j]
        set y [expr $y * $y - 1]
        set y [expr $y * $y]
        lappend zmat [expr $x + $y]
    }
}

Dislin::metafl cons
Dislin::setpag da4p

Dislin::disini
Dislin::pagera
Dislin::complx
Dislin::mixalf
Dislin::newmix

Dislin::titlin $ctit1 1
Dislin::titlin $ctit2 3

Dislin::name   X-axis X
Dislin::name   Y-axis Y

Dislin::axspos 450 2670
Dislin::shdmod poly contur
Dislin::graf   0 1.6 0 0.2 0 1.6 0 0.2

for { set i 0 } { $i < 12 } { incr i } {
    lappend zlev [expr 0.1 + (11 - $i) * 0.1]
}
Dislin::conshd $xray $n $yray $m $zmat $zlev 12

Dislin::height 50
Dislin::title
Dislin::disfin






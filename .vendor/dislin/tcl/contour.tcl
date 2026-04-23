load dislin.so

set ctit1 "Contour Plot"
set ctit2 "F(X,Y) = 2 * SIN(X) * SIN (Y)"

set n 50
set m 50

set fpi  [expr 3.1415927 / 180]
set stepx [expr 360. / ($n - 1)]
set stepy [expr 360. / ($m - 1)]

for { set i 0 } { $i < $n } { incr i } {
    lappend xray [expr $i * $stepx]
}

for { set i 0 } { $i < $m } { incr i } {
    lappend yray [expr $i * $stepy]
}

for { set i 0 } { $i < $n } { incr i } {
    set x [expr [lindex $xray $i] * $fpi]
    for { set j 0 } { $j < $m } { incr j } {
        set y [expr [lindex $yray $j] * $fpi]
        lappend zmat [expr 2 * sin ($x) * sin ($y)]
    }
}

Dislin::metafl cons
Dislin::setpag da4p
Dislin::disini
Dislin::pagera
Dislin::complx

Dislin::titlin $ctit1 1
Dislin::titlin $ctit2 3

Dislin::intax
Dislin::axspos 450 2650

Dislin::name  X-axis X
Dislin::name  Y-axis Y

Dislin::graf   0 360 0 90 0 360 0 90
Dislin::height 50
Dislin::title

Dislin::height 30
for { set i 0 } { $i < 9 } { incr i } {
    set zlev [expr -2. + $i * 0.5]
    if {$i == 4} {
       Dislin::labels NONE CONTUR
    } else {
       Dislin::labels FLOAT CONTUR
    }
    Dislin::setclr [expr ($i + 1) * 28]
    Dislin::contur $xray $n $yray $m $zmat $zlev
}
Dislin::disfin






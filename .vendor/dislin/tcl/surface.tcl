load dislin.so

set ctit1 "Surface Plot of the Function"
set ctit2 "F(X,Y) = 2 * SIN(X) * SIN (Y)"

set n 50
set m 50

set fpi  [expr 3.1415927 / 180]
set stepx [expr 360. / ($n - 1)]
set stepy [expr 360. / ($m - 1)]

for { set i 0 } { $i < $n } { incr i } {
    set x [expr $i * $stepx * $fpi]
    for { set j 0 } { $j < $m } { incr j } {
	set y  [expr $j * $stepy * $fpi]
        lappend zmat [expr 2 * sin ($x) * sin ($y)]
    }
}

Dislin::metafl cons
Dislin::setpag da4p
Dislin::disini
Dislin::pagera
Dislin::complx

Dislin::titlin $ctit1 2
Dislin::titlin $ctit2 4

Dislin::axspos 200 2600
Dislin::axslen 1800 1800

Dislin::name   X-axis X
Dislin::name   Y-axis Y
Dislin::name   Z-axis Z

Dislin::view3d -5 -5 4 ABS
Dislin::graf3d 0 360 0 90 0 360 0 90  -3 3 -3 1
Dislin::height 50
Dislin::title

Dislin::color green
Dislin::surmat $zmat $n $m 1 1
Dislin::disfin






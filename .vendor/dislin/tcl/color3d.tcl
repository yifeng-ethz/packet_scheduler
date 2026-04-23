load dislin.so

set ctit1 "3-D  Colour Plot of the Function"
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

Dislin::metafl xwin
Dislin::disini 
Dislin::pagera 
Dislin::complx 

Dislin::titlin $ctit1 1
Dislin::titlin $ctit2 3

Dislin::name X-axis X
Dislin::name Y-axis Y
Dislin::name Z-axis Z

Dislin::intax  
Dislin::autres $n $m
Dislin::axspos 300 1850
Dislin::ax3len 2200 1400 1400

Dislin::graf3 0 360 0 90 0 360 0 90 -2 2 -2 1
Dislin::crvmat $zmat $n $m 1 1
Dislin::height 50
Dislin::title  
Dislin::disfin 






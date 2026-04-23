#
# @berief           Bar Graphs / Tcl
#

load [file join [pwd] dislin.so]

set x  [list 1.0  2.0  3.0  4.0  5.0  6.0  7.0  8.0  9.0]
set y  [list 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0]
set y1 [list 1.0  1.5  2.5  1.3  2.0  1.2  0.7  1.4  1.1]
set y2 [list 2.0  2.7  3.5  2.1  3.2  1.9  2.0  2.3  1.8]
set y3 [list 4.0  3.5  4.5  3.7  4.0  2.9  3.0  3.2  2.6]

set nya 2700
set ctit "Bar Graphs (BARS)"

Dislin::scrmod revers
Dislin::setpag da4p
Dislin::metafl cons
Dislin::disini 
Dislin::pagera 
Dislin::complx 
Dislin::ticks  1 x
Dislin::intax  
Dislin::axslen 1600 700
Dislin::titlin $ctit 3

set cbuf " "
Dislin::legini $cbuf 3 8
Dislin::leglin $cbuf FIRST 1
Dislin::leglin $cbuf SECOND 2
Dislin::leglin $cbuf THIRD 3
Dislin::legtit " "
Dislin::shdpat 5

for { set i 0 } { $i < 3 } { incr i } {
    if {$i > 0} {
       Dislin::labels none X
    }
    Dislin::axspos 300 [expr $nya - $i * 800]
    Dislin::graf 0.0 10.0 0.0 1.0 0.0 5.0 0.0 1.0

    if {$i == 0} {
       Dislin::bargrp 3 0.15
       Dislin::color red
       Dislin::bars $x $y $y1 9
       Dislin::color green
       Dislin::bars $x $y $y2 9
       Dislin::color blue
       Dislin::bars $x $y $y3 9
       Dislin::color fore
       Dislin::reset bargrp
    } elseif {$i == 1} {
       Dislin::height 30
       Dislin::labels delta bars
       Dislin::labpos center bars
       Dislin::color red
       Dislin::bars $x $y $y1 9
       Dislin::color green
       Dislin::bars $x $y1 $y2 9
       Dislin::color blue
       Dislin::bars $x $y2 $y3 9
       Dislin::color fore
       Dislin::reset height 
    } elseif {$i == 2} {
       Dislin::labels second bars
       Dislin::labpos outside bars
       Dislin::color red
       Dislin::bars $x $y $y1 9
       Dislin::color  fore
    }

    if {$i != 2} {
       Dislin::legend $cbuf 7
    }
    
    if {$i == 2} {
       Dislin::height 50
       Dislin::title  
    }
  Dislin::endgrf 
}
Dislin::disfin 


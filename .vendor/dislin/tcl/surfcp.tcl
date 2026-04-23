load dislin.so

proc myfunc {x y iopt} {
  if {$iopt == 1} {
    set result [expr cos ($x) * (3 + cos ($y))]
  } elseif {$iopt == 2} {
    set result [expr sin ($x) * (3 + cos ($y))]
  } else {
    set result [expr sin ($y)]
  }
  return $result
}

set ctit1 "Surface Plot of the Parametric Function"
set ctit2 "COS(t)*(3+COS(u)), SIN(t)*(3+COS(u)), SIN(u)"
set pi 3.1415927

Dislin::scrmod revers
Dislin::metafl cons
Dislin::setpag da4p
Dislin::disini
Dislin::pagera
Dislin::complx

Dislin::titlin $ctit1 2
Dislin::titlin $ctit2 4

Dislin::axspos 200 2400
Dislin::axslen 1800 1800

Dislin::name  X-axis X
Dislin::name  Y-axis Y
Dislin::name  Z-axis Z
Dislin::intax

Dislin::vkytit -300
Dislin::zscale -1 1
Dislin::surmsh on

Dislin::graf3d -4 4 -4 1 -4 4 -4 1 -3  3  -3  1
Dislin::height 40
Dislin::title

set step [expr 2 * $pi / 30]
set pi2 [expr $pi + $pi]
Dislin::surfcp myfunc 0 $pi2 $step 0 $pi2 $step
Dislin::disfin


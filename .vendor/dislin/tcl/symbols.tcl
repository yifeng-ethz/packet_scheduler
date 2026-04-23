load dislin.so

set ctit Symbols

Dislin::setpag da4p
Dislin::metafl cons

Dislin::disini 
Dislin::pagera 
Dislin::complx 
Dislin::paghdr "H. Michels ("  ")" 2 0

Dislin::height 60
set nl [Dislin::nlmess $ctit]
Dislin::messag $ctit  [expr (2100 - $nl) / 2] 200

Dislin::height 50
Dislin::hsymbl 120

set ny 150

for { set i 0 } { $i < 24 } { incr i } {
  set nl [Dislin::nlnumb $i -1]
  set j [expr $i % 4]
  if {$j == 0} {
    set ny [expr $ny + 400]
    set nxp 550
  } else {
    set nxp [expr $nxp + 350]
  }

  Dislin::number $i -1 [expr $nxp - $nl/2] [expr $ny + 150]
  Dislin::symbol $i $nxp $ny
}
Dislin::disfin 


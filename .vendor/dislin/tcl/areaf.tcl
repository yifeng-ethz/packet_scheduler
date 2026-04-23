load dislin.so

set ctit "Shading Patterns (AREAF)"

Dislin::metafl cons
Dislin::disini
Dislin::setvlt small
Dislin::pagera
Dislin::complx

Dislin::height 50
set nl [Dislin::nlmess ($ctit)]
Dislin::messag $ctit [expr (2970 - $nl) / 2] 200

set nx0 335
set ny0 350

set iclr 0
for { set i 0 } { $i < 3 } { incr i } {
    set  ny [expr $ny0 + $i * 600]
    for { set j 0 } { $j < 6 } { incr j } {
	set nx  [expr $nx0 + $j * 400]
        set ii [expr $i * 6 + $j]
        Dislin::shdpat $ii
        set iclr [expr $iclr + 1]
        Dislin::setclr $iclr

        set ixp [list $nx [expr $nx + 300] [expr $nx + 300] $nx]
        set iyp [list $ny $ny [expr $ny + 400] [expr $ny + 400]]
        Dislin::areaf $ixp $iyp 4
        set nl [Dislin::nlnumb $ii -1]
        set nx [expr $nx + (300 - $nl) / 2]
        Dislin::color foreground
        Dislin::number $ii -1 $nx [expr $ny + 460] 
    }
}
Dislin::disfin


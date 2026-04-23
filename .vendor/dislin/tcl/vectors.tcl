load dislin.so

set ivec [list 0 1111 1311 1421 1531 1701 1911 \
            3111 3311 3421 3531 3703 4221 4302 \
            4413 4522 4701 5312 5502 5703]

set ctit Vectors

Dislin::metafl cons
Dislin::disini
Dislin::pagera
Dislin::complx

Dislin::height 60
set nl [Dislin::nlmess $ctit]
Dislin::messag $ctit [expr (2970 - $nl)/2] 200

Dislin::height 50
set nx 300
set ny 400

for { set i 0 } { $i < 20 } { incr i } {
    set nvec [lindex $ivec $i]
    if {$i == 10} {
	set nx [expr $nx + 2970 / 2]
        set ny 400
    }
    set nl [Dislin::nlnumb $nvec -1]
    Dislin::number $nvec -1 [expr $nx - $nl] [expr $ny - 25]
    Dislin::vector [expr $nx + 100] $ny [expr $nx + 1000] $ny $nvec
    set ny [expr $ny + 160]
}
Dislin::disfin


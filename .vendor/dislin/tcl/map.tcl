load dislin.so

set nproj 14
set cl1 [list "Cylindrical Equidistant" "Mercator" "Cylindrical Equal-Area" \
         "Hammer (Elliptical)" "Aitoff (Elliptical)" "Winkel (Elliptical)" \
	 "Sanson (Elliptical)" "Conical Equidistant" "Conical Equal-Area" \
	 "Conical Conformal" "Azimuthal Equidistant" "Azimuthal Equal-Area" \
         "Azimuthal Stereographic" "Azimuthal Orthgraphic"]

set cl2 [list CYLI MERC EQUA HAMM AITO WINK SANS  CONI  ALBE  CONF  AZIM  \
         LAMB STER  ORTH]

set id_lis 0
set id_draw 0

proc myplot {id} {
  global cl1 cl2 id_lis id_draw 
  set xa  -180
  set xe   180
  set xor -180
  set xstp  60 

  set ya   -90
  set ye    90
  set yor  -90
  set ystp  30 

  set isel [Dislin::gwglis $id_lis]
  Dislin::setxid $id_draw widget
  Dislin::metafl xwin
  Dislin::disini
  Dislin::erase
  Dislin::complx

  if {($isel >=4) && ($isel <= 7)} { 
    Dislin::noclip
  } elseif {$isel == 2} {
    set ya -85
    set ye 85
    set yor -60
  } elseif {($isel >= 8) && ($isel <= 10)} {
    set ya 0
    set ye 90
    set yor 0
  }

  Dislin::labdig -1 xy
  Dislin::name Longitude x
  Dislin::name Latitude  y
  set isel [expr $isel - 1]
  set citem [lindex $cl2 $isel]
  Dislin::projct $citem
  set citem [lindex $cl1 $isel]
  Dislin::titlin [append citem " Projection"] 3
  Dislin::htitle 50
  Dislin::grafmp $xa $xe $xor $xstp $ya $ye $yor $ystp
  Dislin::title
  Dislin::gridmp 1 1
  Dislin::color green
  Dislin::world
  Dislin::unit 0

  Dislin::disfin
}
 
set clis [lindex $cl1 0]

for { set i 1 } { $i < $nproj } { incr i } {
    set citem [lindex $cl1 $i]
    set clis [Dislin::itmcat $clis $citem]
}

Dislin::swgtit "DISLIN Map Plot"
set ip  [Dislin::wgini hori]
Dislin::swgwth -15
set ip1 [Dislin::wgbas $ip vert]
Dislin::swgwth -50
set ip2 [Dislin::wgbas $ip vert]

Dislin::swgdrw [expr 2100./2970.]
set id [Dislin::wglab $ip1 Projection:]
set id_lis [Dislin::wglis $ip1 $clis 1]

set id_but [Dislin::wgpbut $ip1 Plot]
Dislin::swgcbk $id_but myplot

set id_quit [Dislin::wgquit $ip1]
set id [Dislin::wglab $ip2 "DISLIN Draw Widget:"]
set id_draw [Dislin::wgdraw $ip2]
Dislin::wgfin

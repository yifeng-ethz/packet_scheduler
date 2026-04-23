load dislin.so

set cl1 "Item1|Item2|Item3|Item4|Item5"
set cfil " "

Dislin::swgtit "Widgets Example"
set ip [Dislin::wgini VERT]

set id [Dislin::wglab  $ip "File Widget:"]
set id_fil [Dislin::wgfil $ip "Open File" $cfil "*.c"]

set id [Dislin::wglab $ip "List Widget:"]
set id_lis [Dislin::wglis $ip $cl1 1]

set id [Dislin::wglab $ip "Button Widgets:"]
set id_but1 [Dislin::wgbut $ip "This is Button 1" 0] 
set id_but2 [Dislin::wgbut $ip "This is Button 2" 1]

set id [Dislin::wglab $ip "Scale Widget:"]
set id_scl [Dislin::wgscl $ip " " 0 10 5 1] 
Dislin::wgfin

set cfil [Dislin::gwgfil $id_fil]
set ilis [Dislin::gwglis $id_lis]
set ib1  [Dislin::gwgbut $id_but1]
set ib2  [Dislin::gwgbut $id_but2]
set xscl [Dislin::gwgscl $id_scl]

puts "File Widget   : $cfil"
puts "List Widget   : $ilis"
puts "Button Widgets: $ib1 $ib2"
puts "Scale Widget  : $xscl"

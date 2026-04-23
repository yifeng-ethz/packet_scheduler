#! /usr/bin/env ruby
require 'dislin'

Dislin.metafl('cons')
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.axspos(400, 1850)
Dislin.axslen(2400, 1400)

Dislin.name('Longitude', 'X')
Dislin.name('Latitude',  'Y')
Dislin.titlin('World Coastlines and Lakes', 3)

Dislin.labels('MAP', 'XY')
Dislin.labdig(-1, 'XY')
Dislin.grafmp(-180.0, 180.0, -180.0, 90.0, -90.0, 90.0, -90.0, 30.0)

Dislin.gridmp(1, 1)
Dislin.color('green')
Dislin.world()

Dislin.color('foreground')
Dislin.height(50)
Dislin.title()

Dislin.disfin()

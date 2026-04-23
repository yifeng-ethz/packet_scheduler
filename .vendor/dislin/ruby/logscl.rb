#! /usr/bin/env ruby
require 'dislin'

ctit = 'Logarithmic Scaling'
clab = ['LOG', 'FLOAT', 'ELOG']

Dislin.setpag('da4p')
Dislin.metafl('cons')

Dislin.disini()
Dislin.pagera()
Dislin.complx()
Dislin.axslen(1400, 500)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')
Dislin.axsscl('LOG', 'XY')

Dislin.titlin(ctit, 2)

for i in 0..2
  nya = 2650 - i * 800
  Dislin.labdig(-1, 'XY')
  if i == 1
    Dislin.labdig(1, 'Y')
    Dislin.name(' ', 'X')
  end

  Dislin.axspos(500, nya)
  Dislin.messag('Labels: ' + clab[i], 600, nya - 400)
  Dislin.labels(clab[i], 'XY')
  Dislin.graf(0.0, 3.0, 0.0, 1.0, -1.0, 2.0, -1.0, 1.0)
  if i == 2
    Dislin.height(50)
    Dislin.title()
  end

  Dislin.endgrf()
end

Dislin.disfin()



#! /usr/bin/env ruby
require 'dislin'

ctit1 = '3-D  Colour Plot of the Function'
ctit2 = 'F(X,Y) = 2 * SIN(X) * SIN (Y)'

n = 50
m = 50
zmat = Array.new(n*m)

fpi  = 3.1415927 / 180.0
stepx = 360.0 / (n - 1)
stepy = 360.0 / (m - 1)

for i in 0..n-1
  x = i * stepx
  for j in 0..m-1
    y = j * stepy
    zmat[i*m+j] = 2 * Math.sin(x * fpi) * Math.sin(y * fpi)
  end
end

Dislin.metafl('xwin')
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')
Dislin.name('Z-axis', 'Z')

Dislin.intax()
Dislin.autres(n, m)
Dislin.axspos(300, 1850)
Dislin.ax3len(2200, 1400, 1400)

Dislin.graf3(0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0,
                -2.0, 2.0, -2.0, 1.0)
Dislin.crvmat(zmat, n, m, 1, 1)
Dislin.height(50)
Dislin.title()
Dislin.disfin()






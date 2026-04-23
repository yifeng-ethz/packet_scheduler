#! /usr/bin/env ruby
require 'dislin'

ctit1 = 'Contour Plot'
ctit2 = 'F(X,Y) = 2 * SIN(X) * SIN(Y)'

n = 50
m = 50
xray = Array.new(n)
yray = Array.new(m)
zlev = Array.new(12)
zmat = Array.new(n * m)

fpi  = 3.1415927 / 180.0
stepx = 360.0 /(n - 1)
stepy = 360.0 /(m - 1)

for i in 0..n-1
  xray[i] = i * stepx
end

for i in 0..m-1
  yray[i] = i * stepy
end

for i in 0..n-1
  x = xray[i] * fpi
  for j in 0..m-1
    y = yray[j] * fpi
    zmat[i*m+j] = 2 * Math.sin(x) * Math.sin(y)
  end
end

Dislin.metafl('cons')
Dislin.setpag('da4p')
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.intax()
Dislin.axspos(450, 2650)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')

Dislin.graf(0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0)
Dislin.height(50)
Dislin.title()

Dislin.height(30)
for i in 0..8
  zlev = -2.0 + i * 0.5
  if i == 4
    Dislin.labels('NONE', 'CONTUR')
  else
    Dislin.labels('FLOAT', 'CONTUR')
  end

  Dislin.setclr((i+1) * 28)
  Dislin.contur(xray, n, yray, m, zmat, zlev)
end

Dislin.disfin()






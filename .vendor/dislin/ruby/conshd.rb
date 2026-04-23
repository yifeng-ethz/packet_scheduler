#! /usr/bin/env ruby
require 'dislin'

ctit1 = 'Shaded Contour Plot'
ctit2 = 'F(X,Y) =(X[2$ - 1)[2$ +(Y[2$ - 1)[2$'

n = 50
m = 50
xray = Array.new(n)
yray = Array.new(m)
zlev = Array.new(12)
zmat = Array.new(n * m)

stepx = 1.6 /(n - 1)
stepy = 1.6 /(m - 1)

for i in 0..n-1
  xray[i] = i * stepx
end

for i in 0..m-1
  yray[i] = i * stepy
end

for i in 0..n-1
  x = xray[i] * xray[i] - 1.0
  x = x * x
  for j in 0..m-1
    y = yray[j] * yray[j] - 1.0
    zmat[i*m+j] = x + y * y
  end
end

Dislin.metafl('cons')
Dislin.setpag('da4p')

Dislin.disini()
Dislin.pagera()
Dislin.complx()
Dislin.mixalf()

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')

Dislin.axspos(450, 2670)
Dislin.shdmod('poly', 'contur')
Dislin.graf(0.0, 1.6, 0.0, 0.2, 0.0, 1.6, 0.0, 0.2)

for i in 0..11
  zlev[11-i] = 0.1 + i * 0.1
end

Dislin.conshd(xray, n, yray, m, zmat, zlev, 12)

Dislin.height(50)
Dislin.title()

Dislin.disfin()






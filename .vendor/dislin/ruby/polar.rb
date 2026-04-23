#! /usr/bin/env ruby
require 'dislin'

n = 300
m = 10
pi = 3.1415926
f = pi / 180.0
step = 360.0 / (n - 1)

xray = Array.new(n)
x1 = Array.new(n)
y1 = Array.new(n)

x2 = Array.new(m)
y2 = Array.new(m)

for i  in 0..n-1
  a = (i * step) * f
  xray[i] = i * step
  x = xray[i] * f
  y1[i] = a
  x1[i] = Math.sin(5 * a)
end

for i  in 0..m-1
  x2[i] = i + 1
  y2[i] = i + 1
end

Dislin.setpag('da4p')
Dislin.scrmod('revers')
Dislin.metafl('cons')
Dislin.disini()
Dislin.complx()
Dislin.pagera()

Dislin.titlin('Polar Plots', 2)
Dislin.ticks(3, 'Y')
Dislin.axends('NOENDS', 'X')
Dislin.labdig(-1, 'Y')
Dislin.axslen(1000, 1000)
Dislin.axsorg(1050, 900)

ic = Dislin.intrgb(0.95,0.95,0.95)
Dislin.axsbgd(ic)
Dislin.grafp(1.0, 0.0, 0.2, 0.0, 30.0);
Dislin.color('blue')
Dislin.curve(x1, y1, n)
Dislin.color('fore')
Dislin.htitle(50)
Dislin.title()
Dislin.endgrf()

Dislin.labdig(-1, 'X')
Dislin.axsorg(1050, 2250)
Dislin.labtyp('VERT', 'Y')
Dislin.grafp(10.0, 0.0, 2.0, 0.0, 30.0)
Dislin.barwth(-5.0)
Dislin.polcrv('FBARS')
Dislin.color('blue')
Dislin.curve(x2, y2, m)

Dislin.disfin()

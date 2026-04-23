#! /usr/bin/env ruby
require 'dislin'

n = 101
pi = 3.1415926
f = pi / 180.0
step = 360.0 / (n - 1)

xray = Array.new(n)
y1ray = Array.new(n)
y2ray = Array.new(n)

for i  in 0..n-1
  xray[i] = i * step
  x = xray[i] * f
  y1ray[i] = Math.sin(x)
  y2ray[i] = Math.cos(x)
end


Dislin.metafl('xwin')
Dislin.scrmod('revers')
Dislin.disini()
Dislin.complx()
Dislin.pagera()

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')

Dislin.axspos(450, 1800)
Dislin.axslen(2200, 1200)

Dislin.labdig(-1, 'X')
Dislin.ticks(10, 'XY')

Dislin.titlin('Demonstration of CURVE', 1)
Dislin.titlin('SIN (X), COS (X)', 3)

ic = Dislin.intrgb(0.95, 0.95, 0.95)
Dislin.axsbgd(ic)
Dislin.graf(0.0, 360.0, 0.0, 90.0, -1.0, 1.0, -1.0, 0.5)
Dislin.setrgb(0.7, 0.7, 0.7)
Dislin.grid(1,1)

Dislin.color('fore')
Dislin.height(50)
Dislin.title()

Dislin.color('red')
Dislin.curve(xray, y1ray, n)
Dislin.color('green')
Dislin.curve(xray, y2ray, n)
Dislin.disfin()

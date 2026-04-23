#! /usr/bin/env ruby
require 'dislin'

n = 101
f = 3.1415926 / 180.0
step = 360.0 / (n - 1)

xray = Array.new(n)
y1ray = Array.new(n)
y2ray = Array.new(n)

for i in 0..n-1
  xray[i] = i * step
  x = xray[i] * f
  y1ray[i] = Math.sin(x)
  y2ray[i] = Math.cos(x)
end

Dislin.metafl('xwin')
Dislin.disini()
Dislin.complx()

Dislin.axspos(450, 1800)
Dislin.axslen(2200, 1200)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')

Dislin.labdig(-1, 'X')
Dislin.ticks(10, 'XY')

Dislin.titlin('Demonstration of CURVE', 1)
Dislin.titlin('Legend', 3)
 
Dislin.graf(0.0, 360.0, 0.0, 90.0, -1.0, 1.0, -1.0, 0.5)
Dislin.title()
Dislin.xaxgit()
Dislin.chncrv('BOTH')
Dislin.curve(xray, y1ray, n)
Dislin.curve(xray, y2ray, n)

cbuf = ' '                   
Dislin.legini(cbuf, 2, 7)     # cbuf is a dummy parameter for python
nx = Dislin.nxposn(190.0)
ny = Dislin.nyposn(0.75)
Dislin.leglin(cbuf, 'sin(x)', 1)
Dislin.leglin(cbuf, 'cos(x)', 2)
Dislin.legpos(nx, ny)
Dislin.legtit('Legend')
Dislin.legend(cbuf, 3)
Dislin.disfin()



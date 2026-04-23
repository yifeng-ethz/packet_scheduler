#! /usr/bin/env ruby
require 'dislin'

def myfunc(x, y, iopt)
  if iopt == 1
     xv = Math.cos(x)*(3+Math.cos(y))
  elsif iopt == 2
     xv = Math.sin(x)*(3+Math.cos(y))
  else
     xv = Math.sin(y)
  end

  return xv
end

ctit1 = "Surface Plot of the Parametric Function"
ctit2 = "[COS(t)*(3+COS(u)), SIN(t)*(3+COS(u)), SIN(u)]"

pi  = 3.1415927

Dislin.metafl('cons')
Dislin.setpag('da4p')
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.titlin(ctit1, 2)
Dislin.titlin(ctit2, 4)

Dislin.axspos(200, 2400)
Dislin.axslen(1800, 1800)

Dislin.name('X-axis', 'X')
Dislin.name('Y-axis', 'Y')
Dislin.name('Z-axis', 'Z')
Dislin.intax()

Dislin.vkytit(-300)
Dislin.zscale(-1.0,1.0)
Dislin.surmsh('on')

Dislin.graf3d(-4.0,4.0,-4.0,1.0,-4.0,4.0,-4.0,1.0,-3.0,3.0,-3.0,1.0)
Dislin.height(40)
Dislin.title()

step = 2 * pi / 30.0

Dislin.surfcp('myfunc', 0.0, 2*pi, step, 0.0, 2*pi, step)
Dislin.disfin()


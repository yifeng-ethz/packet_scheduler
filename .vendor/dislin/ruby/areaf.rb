#! /usr/bin/env ruby
require 'dislin'

ix  = [0, 300, 300,   0]
iy  = [0,   0, 400, 400]
ixp = [0, 0, 0, 0]
iyp = [0, 0, 0, 0]

Dislin.metafl('cons')
Dislin.disini()
Dislin.setvlt('small')
Dislin.pagera()
Dislin.complx()

Dislin.height(50)
ctit = "Shading patterns (AREAF)"
nl = Dislin.nlmess(ctit)
Dislin.messag(ctit, (2970 - nl)/2, 200)

nx0 = 335
ny0 = 350

iclr = 0
for i in 0..2
  ny = ny0 + i * 600

  for j in 0..5
    nx = nx0 + j * 400
    ii = i * 6 + j
    Dislin.shdpat(ii)
    iclr = iclr + 1
    iclr = iclr % 8
    if iclr == 0
      iclr = 8
    end 
    Dislin.setclr(iclr)
    for k in 0..3
      ixp[k] = ix[k] + nx
      iyp[k] = iy[k] + ny
    end

    Dislin.areaf(ixp, iyp, 4)
    nl = Dislin.nlnumb(ii, -1)
    nx = nx + (300 - nl) / 2
    Dislin.color('foreground')
    Dislin.number(ii, -1, nx, ny + 460) 
  end
end

Dislin.disfin()

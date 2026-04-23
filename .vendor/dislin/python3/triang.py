#! /usr/bin/env python3
import math
import dislin

ctit1 = 'Surface Plot of the Function'
ctit2 = 'F(X,Y) = 2 * SIN(X) * SIN (Y)'

npt = 100
n1  = 10003
n2  = 20001

xray = list (range (n1))
yray = list (range (n1))
zray = list (range (n1))
i1   = list (range (n2))
i2   = list (range (n2))
i3   = list (range (n2))

fpi  = 3.1415927 / 180.
step = 360. / (npt - 1)

n = 0
for i in range (0, npt):
  x = i * step
  for j in range (0, npt):
    y = j * step
    xray[n] = x;
    yray[n] = y;
    zray[n] = 2 * math.sin(x * fpi) * math.sin(y * fpi)
    n=n+1

ntri = dislin.triang (xray, yray, n, i1, i2, i3, 2 * n + 1)

dislin.scrmod ('revers')
dislin.setpag ('da4p')
dislin.metafl ('cons')
dislin.disini ()
dislin.pagera ()
dislin.complx ()

dislin.titlin (ctit1, 2)
dislin.titlin (ctit2, 4)

dislin.name   ('X-axis', 'X')
dislin.name   ('Y-axis', 'Y')
dislin.name   ('Z-axis', 'Z')

dislin.labdig (-1, 'XY')
dislin.graf3d (0., 360., 0., 90., 0., 360., 0., 90., -2., 2., -2., 0.5)
dislin.surtri (xray, yray, zray, n, i1, i2, i3, ntri)

dislin.disfin ()






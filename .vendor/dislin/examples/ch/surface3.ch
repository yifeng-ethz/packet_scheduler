#include <stdio.h>
#include <math.h>
#include "dislin.h"

double zmat[50][50], xray[50], yray[50], zlev[20];

main()
{ int n = 50 ,i, j, nlev = 20;
  double fpi=3.1415927/180., step, x, y;
  static char *ctit1 = "Shaded Surface / Contour Plot",
              *ctit2 = "F(X,Y) = 2*SIN(X)*SIN(Y)";

  step = 360./(n-1);
  for (i = 0; i < n; i++)
  { x = i*step;
    xray[i] = x;
    for (j = 0; j < n; j++)
    { y = j*step;
      yray[j] = y;
      zmat[i][j] = 2*sin(x*fpi)*sin(y*fpi);
    }
  }

  scrmod ("revers");
  setpag("da4p");
  metafl ("cons");
  disini();
  pagera();
  hwfont();
  axspos(200,2600);
  axslen(1800,1800);

  name("X-axis","x");
  name("Y-axis","y");
  name("Z-axis","z");

  titlin(ctit1,2);
  titlin(ctit2,4);

  graf3d(0.,360.,0.,90.,0.,360.,0.,90.,-2.,2.,-2.,1.);
  height(50);
  title();

  grfini (-1., -1., -1., 1., -1., -1., 1., 1., -1.);
  nograf ();
  graf (0., 360., 0., 90., 0., 360., 0., 90.);
  step = 4. / nlev;
  for (i = 0; i < nlev; i++)
    zlev[i] = (float) (-2.0 + i * step); 

  conshd (xray, n, yray, n, (float *) zmat, zlev, nlev);
  box2d ();
  reset ("nograf");
  grffin ();

  shdmod("smooth","surface"); 
  surshd(xray,n,yray,n,(float *) zmat);
  disfin();
}

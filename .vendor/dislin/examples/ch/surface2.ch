#include <stdio.h>
#include <math.h>
#include "dislin.h"

double zmat[50][50], xray[50], yray[50];

main()
{ int n = 50 ,i, j;
  double fpi=3.1415927/180., step, x, y;
  static char *ctit1 = "Shaded Surface Plot",
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

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
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

  view3d(-5.,-5.,4.,"abs");
  graf3d(0.,360.,0.,90.,0.,360.,0.,90.,-3.,3.,-3.,1.);
  height(50);
  title();

  shdmod("smooth","surface"); 
  surshd(xray,n,yray,n,(float *) zmat);
  disfin();
}

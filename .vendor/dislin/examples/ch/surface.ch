#include <stdio.h>
#include <math.h>
#include "dislin.h"

double zmat[50][50];

main()
{ int n = 50 ,i, j;
  double fpi=3.1415927/180., step, x, y;
  static char *ctit1 = "Surface Plot (SURMAT)",
              *ctit2 = "F(X,Y) = 2*SIN(X)*SIN(Y)";

  step = 360./(n-1);
  for (i = 0; i < n; i++)
  { x = i*step;
    for (j = 0; j < n; j++)
    { y = j*step;
      zmat[i][j] = 2*sin(x*fpi)*sin(y*fpi);
    }
  }

  scrmod("revers");
  metafl("xwin");
  setpag("da4p");
  disini();
  pagera();
  complx();
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

  color("green");
  surmat((double *) zmat,50,50,1,1);
  disfin();
}

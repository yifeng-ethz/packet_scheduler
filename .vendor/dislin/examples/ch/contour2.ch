#include <stdio.h>
#include <math.h>
#include "dislin.h"

double xray[50], yray[50], zmat[50][50];

main()
{ int n = 50, i, j;
  double step, x, y;
  double zlev[12];

  step = 1.6/(n-1);
  for (i = 0; i < n; i++)
  { x = 0.0+i*step;
    xray[i] = x;
    for (j = 0; j < n; j++)
    { y = 0.0+j*step;
      yray[j] = y;
      zmat[i][j] = (x*x-1.)*(x*x-1.) + (y*y-1.)*(y*y-1.);
    }
  }

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();

  mixalf();
  titlin("Shaded Contour Plot",1);
  titlin("F(X,Y) = (X[2$ - 1)[2$ + (Y[2$ - 1)[2$",3);
  name("X-axis","x");
  name("Y-axis","y");

  shdmod("poly", "contur");
  axspos(450,2670);
  graf(0.0,1.6,0.0,0.2,0.0,1.6,0.0,0.2);

  for (i = 1; i <= 12; i++)
    zlev[12-i] = 0.1+(i-1)*0.1;

  conshd(xray, n, yray, n, (float *) zmat,zlev,12);

  height(50);
  title();
  disfin();
}

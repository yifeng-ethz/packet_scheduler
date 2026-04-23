#include <stdio.h>
#include <math.h>
#include "dislin.h"

double xray[50], yray[50], zmat[50][50];

main()
{ int n = 50, i, j;
  double  fpi = 3.14159/180., step, x, y;
  double  zlev;

  step = 360./(n-1);

  for (i = 0; i < n; i++)
  { xray[i] = i*step;
    yray[i] = i*step;
  }

  for (i = 0; i < n; i++)
  { for (j = 0; j < n; j++)
    { x = xray[i]*fpi;
      y = yray[j]*fpi;    
      zmat[i][j] = 2*sin(x)*sin(y);
    }
  }

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  hwfont();
  pagera();

  titlin("Contour Plot",1);
  titlin("F(X,Y) = 2 * SIN(X) * SIN(Y)",3);

  name("X-axis","x");
  name("Y-axis","y");

  intax();
  axspos(450,2670);
  graf(0.,360.,0.,90.,0.,360.,0.,90.);

  height(30);
  for (i = 0; i < 9; i++)
  { zlev = -2.+i*0.5;
    setclr ((i+1) * 25);
    if (i == 4)
      labels("none","contur"); 
    else
      labels("float","contur");

    contur(xray,n,yray,n,(float *) zmat,zlev);
  }

  height(50);
  color("fore");
  title();

  disfin();
}

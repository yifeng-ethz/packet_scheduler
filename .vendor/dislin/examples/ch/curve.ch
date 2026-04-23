#include <stdio.h>
#include <math.h>
#include "dislin.h"

main()
{ int n = 100, i, ic;
  double fpi = 3.1415926/180., step, x;
  double xray[100], y1ray[100], y2ray[100];

  step = 360. / (n-1);

  for (i = 0; i < n; i++)
  { xray[i] = i * step;
    x = xray[i] * fpi;
    y1ray[i] = sin(x);
    y2ray[i] = cos(x);
  }

  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();
  axspos(450,1800);
  axslen(2200,1200);

  name("X-axis","x");
  name("Y-axis","y");

  labdig(-1,"x");
  ticks(9,"x");
  ticks(10,"y");

  titlin("Demonstration of CURVE",1);
  titlin("SIN(X), COS(X)",3);

  ic=intrgb(0.95,0.95,0.95);
  axsbgd(ic);

  graf(0.,360.,0.,90.,-1.,1.,-1.,0.5);
  setrgb(0.7,0.7,0.7);
  grid(1,1);

  color("fore");
  height(50);
  title();

  color("red");
  curve(xray,y1ray,n);
  color("green");
  curve(xray,y2ray,n);
  disfin();
}

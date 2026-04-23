#include <stdio.h>
#include "dislin.h"

main ()
{ int n = 100, i, nx, ny;
  double fpi = 3.1415926/180., step, x;
  double xray[100], y1ray[100], y2ray[100];
  char   cbuf[20];

  step = 360./(n-1);
  for (i=0; i<n; i++)
  { xray[i] = (float) (i * step);
    x=xray[i] * fpi;
    y1ray[i] = (float) sin(x);
    y2ray[i] = (float) cos(x);
  }

  scrmod("revers");
  metafl("xwin");
  disini();
  hwfont();
  pagera();

  axspos(450,1800);
  axslen(2200,1200);

  name("X-axis","x");
  name("Y-axis","y");
  labdig(-1,"x");
  ticks(10,"xy");

  titlin("Demonstration of Curve",1);
  titlin("Legend",3);

  graf(0.f, 360.f, 0.f, 90.f, -1.f, 1.f, -1.f, 0.5f);
  title();
  xaxgit();

  chncrv("both");
  curve(xray,y1ray,n);
  curve(xray,y2ray,n);

  legini(cbuf,2,7);
  nx = nxposn(190.f);
  ny = nyposn(0.75f);
  legpos(nx,ny);
  leglin(cbuf,"sin (x)",1);
  leglin(cbuf,"cos (x)",2);
  legtit("Legend");
  legend(cbuf,3);

  disfin();
}


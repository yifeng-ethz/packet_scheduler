#include <stdio.h>
#include "dislin.h"

main()
{ int nya = 2700, i, nx, ny, ic;
  static double
        x[] = {0.,1.,3.,4.5,6.,8.,9.,11.,12.,12.5,13.,15.,16.,17.,19.,20.},
        y[] = {2.,4.,4.5,3.,1.,7.,2.,3.,5.,2.,2.5,2.,4.,6.,5.5,4.};
  static char 
       *cpol[6] = {"SPLINE", "STEM", "BARS", "STAIRS", "STEP", "LINEAR"},
       *ctit    = "Interpolation Methods";

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  complx();
  pagera();
  incmrk(1);
  hsymbl(25);
  titlin(ctit,2);
  axslen(1500,350);
  setgrf("line","line","line","line");
  ic = intrgb (1.0,1.0,0.0);
  axsbgd (ic);

  for (i=0; i<6; i++)
  { axspos(350,nya-i*350);
    polcrv(cpol[i]);
    marker(16);

    graf(0.,20.,0.,5.,0.,10.,0.,5.);
    nx=nxposn(1.);
    ny=nyposn(8.);
    messag(cpol[i],nx,ny);
    color("red");
    curve(x,y,16);
    color("fore");

    if (i == 5)
    { height(50);
      title();
    }
    endgrf();
  }

  disfin();
}

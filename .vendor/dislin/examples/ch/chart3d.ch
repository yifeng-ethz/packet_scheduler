#include <stdio.h>
#include "dislin.h"

main()
{ char cbuf[80];
  double xray[5]  = {2.,4.,6.,8.,10.},
         y1ray[5] = {0.,0.,0.,0.,0.},
         y2ray[5] = {3.2,1.5,2.0,1.0,3.0};

  int ic1ray[5]  = {50,150,100,200,175},
      ic2ray[5]  = {50,150,100,200,175};

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();

  titlin("3-D Bar Graph / 3-D Pie Chart", 2);
  htitle(40);

  shdpat(16);
  axslen(1500,1000);
  axspos(300,1400);

  barwth(0.5);
  bartyp("3dvert");
  labels("second","bars");
  labpos("outside","bars");
  labclr(255,"bars");
  graf(0.,12.,0.,2.,0.,5.,0.,1.);
  title();
  color("red");
  bars(xray,y1ray,y2ray,5);
  endgrf();

  shdpat(16);
  labels("data","pie");
  labclr(255,"pie");
  chnpie("none");
  pieclr(ic1ray,ic2ray,5);
  pietyp("3d");
  axspos(300,2700);
  piegrf(cbuf,0,y2ray,5);       
  disfin();
}

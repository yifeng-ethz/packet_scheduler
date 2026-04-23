#include <stdio.h>
#include "dislin.h"

main()
{ int nya = 2700, i;
  static char   *ctit = "Bar Graphs (BARS)", cbuf[25];

  static double x[9]  = {1.,2.,3.,4.,5.,6.,7.,8.,9.},
                y[9]  = {0.,0.,0.,0.,0.,0.,0.,0.,0.},
                y1[9] = {1.,1.5,2.5,1.3,2.0,1.2,0.7,1.4,1.1},
                y2[9] = {2.,2.7,3.5,2.1,3.2,1.9,2.0,2.3,1.8},
                y3[9] = {4.,3.5,4.5,3.7,4.,2.9,3.0,3.2,2.6};

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();
  ticks(1,"x");
  intax();;
  axslen(1600,700);
  titlin(ctit,3);

  legini(cbuf,3,8);
  leglin(cbuf,"FIRST",1);
  leglin(cbuf,"SECOND",2);
  leglin(cbuf,"THIRD",3);
  legtit(" ");
  shdpat(5L);
  for (i = 1; i <= 3; i++)
  { if (i >  1) labels("none","x");
    axspos(300,nya-(i-1)*800);

    graf(0.,10.,0.,1.,0.,5.,0.,1.);

    if (i == 1)
    { bargrp(3,0.15);
      color("red");
      bars(x,y,y1,9);
      color("green");
      bars(x,y,y2,9);
      color("blue");
      bars(x,y,y3,9);
      color("fore");
      reset("bargrp");
    }
    else if (i == 2)
    { height(30);
      labels("delta","bars");
      labpos("center","bars");
      color("red");
      bars(x,y,y1,9);
      color("green");
      bars(x,y1,y2,9);
      color("blue");
      bars(x,y2,y3,9);
      color("fore");
      reset("height"); 
    }
    else if (i == 3)
    { labels("second","bars");
      labpos("outside","bars");
      color("red");
      bars(x,y,y1,9);
      color("fore");
    }

    if (i != 3) legend(cbuf,7);

    if (i == 3)
    { height(50);
      title();
    }

    endgrf();
  }

  disfin();
}

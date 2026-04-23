#include <stdio.h>
#include <math.h>
#include "dislin.h"

main()
{ int n = 300, m = 10, i, ic;
  double f = 3.1415926/180., step, a;
  double xray[300], yray[300], x2[10], y2[10];
  
  step = 360. / (n-1);

  for (i = 0; i < n; i++)
  { a = i * step * f;
    yray[i] = (float) a;
    xray[i] = (float) sin(5 * a);
  }

  for (i = 0; i < m; i++)
  { x2[i] = i + 1;
    y2[i] = i + 1;
  }

  setpag ("da4p");
  scrmod("revers");
  metafl("xwin");
  disini ();
  pagera ();
  hwfont ();
  axspos (450,1800);

  titlin ("Polar Plots", 2);
  ticks  (3, "Y");
  axends ("NOENDS", "X");
  labdig (-1, "Y");
  axslen (1000, 1000);
  axsorg (1050, 900);

  ic = intrgb (0.95, 0.95, 0.95);
  axsbgd (ic);
 
/* grafp replaces polar since polar is a internal routine of C99 */
  grafp  (1., 0., 0.2, 0., 30.);
  color  ("blue");
  curve  (xray, yray, n);
  color  ("fore");
  htitle (50);
  title  ();
  endgrf ();

  labdig (-1, "X");
  axsorg (1050, 2250);
  labtyp ("VERT", "Y");
  grafp  (10., 0., 2., 0., 30.);
  barwth (-5.);
  polcrv ("FBARS");
  color  ("blue");
  curve  (x2, y2, m);
             
  disfin();
}


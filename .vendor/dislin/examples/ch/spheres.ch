#include <stdio.h>
#include "dislin.h"

main()
{ int i, j1, j2, iret;
  double x[17] = {10., 20., 10., 20., 5., 15., 25., 5., 15., 25., 
                 5., 15., 25., 10., 20., 10., 20.};
  double y[17] = {10., 10., 20., 20., 5., 5., 5., 15., 15., 15.,
                 25., 25., 25., 10., 10., 20., 20.};
  double z[17] = {5., 5., 5., 5., 15., 15., 15., 15., 15., 15.,
                 15., 15., 15., 25., 25., 25., 25.};  

  int idx[]  = {1, 2, 1, 3, 3, 4, 2, 4, 5, 6, 6, 7, 8, 9, 9, 10,
                11, 12, 12, 13,  5, 8, 8, 11, 6, 9, 9, 12, 7, 10,
                10, 13,  14, 15, 16, 17, 14, 16, 15, 17,
                1, 5, 2, 7, 3, 11, 4, 13, 5, 14, 7, 15, 11, 16, 13, 17};

  setpag ("da4p");
  scrmod ("revers");
  metafl ("cons");
  disini ();
  pagera ();
  hwfont ();
  light ("on");
  matop3 (0.02, 0.02, 0.02, "specular");

  clip3d ("none");
  axspos (0, 2500);
  axslen (2100, 2100);

  htitle (50);
  titlin ("Spheres and Tubes", 4);

  name ("X-axis", "x");
  name ("Y-axis", "y");
  name ("Z-axis", "z");

  labdig (-1, "xyz");  
  labl3d ("hori");
  graf3d (0., 30., 0., 5., 0., 30., 0., 5., 0., 30., 0., 5.);
  title ();

  shdmod ("smooth", "surface");
  
  iret = zbfini();
  matop3 (1.0, 0.0, 0.0, "diffuse");
  for (i = 0; i < 17; i++)
    sphe3d (x[i], y[i], z[i], 2.0f, 50, 25);

  matop3 (0.0, 1.0, 0.0, "diffuse");
  for (i = 0; i < 56; i += 2)  
  { j1 = idx[i] - 1;
    j2 = idx[i+1] - 1;
    tube3d (x[j1], y[j1], z[j1], x[j2], y[j2], z[j2], 0.5, 5, 5); 
  }

  zbffin ();
  disfin ();
}

#include <stdio.h>
#include <math.h>
#include "dislin.h"

double zfun (double x, double y, int iopt)
{ double v;
  if (iopt == 1)
    v = cos (x) * (3. + cos (y));
  else if (iopt == 2)
    v = sin (x) * (3. + cos (y));
  else
    v = sin (y);

  return v;
}

main()
{ double p = 3.14159f, step;
  
   setpag ("da4p");
   metafl ("cons");
   scrmod ("revers");
   disini ();
   pagera ();
   hwfont ();
   axspos (200,2400);
   axslen (1800,1800);
   intax ();

   titlin ("Surface Plot of the Parametric Function",2);
   titlin ("[COS(t)+(3+COS(u)), SIN(t)*(3+COS(u)), SIN(u)]",4);

   name ("X-axis", "x");
   name ("Y-axis", "y");
   name ("Z-axis", "z");

   vkytit (-300);
   zscale (-1.0, 1.0);
   graf3d (-4.0, 4.0, -4.0, 1.0, -4.0, 4.0, -4.0, 1.0,
	       -3.0, 3.0, -3.0, 1.0);
   height (40);
   title ();

   surmsh ("on");
   step = 2 * 3.14159/30.;
   surfcp (zfun, 0.0, 2*p, step, 0.0, 2*p, step);
   disfin ();
}



#include <stdio.h>
#include "dislin.h"

main()
{ 

  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();

  frame(3);
  axspos(400,1850);
  axslen(2400,1400);

  name("Longitude","x");
  name("Latitude","y");
  titlin("World Coastlines and Lakes",3);

  labels("map","xy");
  grafmp(-180.,180.,-180.,90.,-90.,90.,-90.,30.);

  gridmp(1,1);
  color("green");
  world();
  color("fore");

  height(50);
  title();
  disfin();
}

#include <stdio.h>
#include "dislin.h"

main()
{ int nya = 2800, i;
  static char    *ctit = "Pie Charts (PIEGRF)", cbuf[41];
  static double xray[5] = {1.,2.5,2.,2.7,1.8};

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  hwfont();
  axslen(1600,1000);
  titlin(ctit,2);
  chnpie("both");

  legini(cbuf,5,8);
  leglin(cbuf,"FIRST",1);
  leglin(cbuf,"SECOND",2);
  leglin(cbuf,"THIRD",3);
  leglin(cbuf,"FOURTH",4);
  leglin(cbuf,"FIFTH",5);

  patcyc(1,7L);
  patcyc(2,4L);
  patcyc(3,13L);
  patcyc(4,3L);
  patcyc(5,5L);

  for (i = 0; i < 2; i++)
  { axspos(250,nya-i*1200);
    if (i == 1)
    { labels("data","pie");
      labpos("external","pie");
    }

    piegrf(cbuf,1,xray,5);

    if (i == 1)
    { height(50);
      title();
    }
    endgrf();
  }
  disfin();
}

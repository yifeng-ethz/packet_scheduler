#include <stdio.h>
#include "dislin.h"

main()
{ int nl, ny, i, nxp;
  static char ctit[] = "Symbols", cstr[3];

  setpag("da4p");
  scrmod("revers");
  metafl("xwin");
  disini();
  pagera();
  complx();

  height(60);
  nl = nlmess(ctit);
  messag(ctit,(2100-nl)/2,200);

  height(50);
  hsymbl(120);

  ny = 150;

  for (i = 0; i < 24; i++)
  { if ((i % 4) == 0) 
    { ny  += 400;
      nxp  = 550;
    }
    else
    { nxp += 350;
    }

    sprintf(cstr,"%d",i); 
    nl = nlmess(cstr)/2;
    messag(cstr,nxp-nl,ny+150);
    symbol(i,nxp,ny);
  }

  disfin();
}

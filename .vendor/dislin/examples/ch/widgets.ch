#include <stdio.h>
#include "dislin.h"

main ()
{ int ip, id, id_fil, id_lis, id_scl, id_but1, id_but2,
      ilis, ib1, ib2;
  double xscl; 
  char *cl1="Item1|Item2|Item3|Item4|Item5";
  char cfil[256];

  strcpy (cfil, " ");

  swgtit ("Widgets Example");
  ip = wgini  ("VERT");

  id = wglab  (ip, "File Widget:");
  id_fil = wgfil (ip, "Open File", cfil, "*.c");

  id = wglab  (ip, "List Widget:");
  id_lis = wglis (ip, cl1, 1);

  id = wglab  (ip, "Button Widgets:");
  id_but1 = wgbut (ip, "This is Button 1", 0); 
  id_but2 = wgbut (ip, "This is Button 2", 1);

  id = wglab  (ip, "Scale Widget:");
  id_scl = wgscl (ip, " ", 0., 10., 5., 1); 
  wgfin ();

  gwgfil (id_fil, cfil);
  ilis = gwglis (id_lis);
  ib1  = gwgbut (id_but1);
  ib2  = gwgbut (id_but2);
  xscl = gwgscl (id_scl);

  printf ("%s\n%d\n%d\n%d\n%f\n", cfil, ilis, ib1, ib2, xscl);
}
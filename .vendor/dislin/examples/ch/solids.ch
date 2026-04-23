#include <stdio.h>
#include "dislin.h"

main()
{ int iret;

  setpag ("da4p");
  scrmod ("revers");
  metafl ("cons");
  disini ();
  pagera ();
  hwfont ();
  light ("on");
  litop3(1,0.5,0.5,0.5,"ambient");

  clip3d ("none");
  axspos (0, 2500);
  axslen (2100, 2100);

  htitle (60);
  titlin ("Some Solids", 4);

  nograf ();
  graf3d (-5., 5., -5., 2., -5., 5., -5., 2., -5., 5., -5., 2.);
  title ();
 
  shdmod ("smooth", "surface"); 
  iret = zbfini();

  matop3 (1.0, 0.5, 0.0, "diffuse");
  tube3d (-3., -3., 8.0, 2., 3., 5.5, 1., 40, 20); 

  rot3d (-60., 0., 0.); 
  matop3 (1.0, 0.0, 1.0, "diffuse");
  setfce ("bottom");
  matop3 (1.0, 0.0, 0.0, "diffuse");
  cone3d (-3., -3., 3.5, 2., 3., 3., 40, 20);
  setfce ("top");

  rot3d (0., 0., 0.); 
  matop3 (0.0, 1.0, 1.0, "diffuse");
  plat3d (4., 4., 3., 3., "icos");

  rot3d (0., 0., 0.); 
  matop3 (1.0, 1.0, 0.0, "diffuse");
  sphe3d (0., 0., 0., 3., 40, 20);

  rot3d (0., 0., -20.); 
  matop3 (0.0, 0.0, 1.0, "diffuse");
  quad3d (-4., -4., -3., 3., 3., 3.);

  rot3d (0., 0., 30.); 
  matop3 (1.0, 0.3, 0.3, "diffuse");
  pyra3d (-2., -5., -10., 3., 5., 5., 4);

  rot3d (0., 0., 0.); 
  matop3 (1.0, 0.0, 0.0, "diffuse");
  torus3d (7., -3., -2., 1.5, 3.5, 1.5, 0., 360., 40, 20);
  rot3d (0., 90., 0.); 

  matop3 (0.0, 1.0, 0.0, "diffuse");
  torus3d (7., -5., -2., 1.5, 3.5, 1.5, 0., 360., 40, 20);
  zbffin ();
  disfin ();
}

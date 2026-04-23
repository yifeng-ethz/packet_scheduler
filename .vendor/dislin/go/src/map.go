package main

import "dislin"

var id_lis int = 0
var id_draw int = 0

var cl1 = [14]string{
       "Cylindrical Equidistant", 
       "Mercator",
       "Cylindrical Equal-Area",
       "Hammer (Elliptical)",
       "Aitoff (Elliptical)",
       "Winkel (Elliptical)",
       "Sanson (Elliptical)",
       "Conical Equidistant",
       "Conical Equal-Area",
       "Conical Conformal",
       "Azimuthal Equidistant",
       "Azimuthal Equal-Area",
       "Azimuthal Stereographic",
       "Azimuthal Orthgraphic"}

var cl2 = [14]string{
       "CYLI", "MERC", "EQUA", "HAMM", "AITO", "WINK",
       "SANS", "CONI", "ALBE", "CONF", "AZIM", "LAMB",
       "STER", "ORTH"}

func myplot (id int) {
  xa   := -180.0 
  xe   :=  180.0
  xor  := -180.0
  xstp :=   60.0

  ya   := -90.0 
  ye   :=  90.0
  yor  := -90.0
  ystp :=  30.0

  isel := dislin.Gwglis (id_lis)
  dislin.Setxid (id_draw, "widget")
  dislin.Metafl ("xwin")
  dislin.Disini ()
  dislin.Erase ()
  dislin.Complx ()

  if  isel >=4 && isel <= 7 { 
    dislin.Noclip ()
  } else if isel == 2 {
    ya = -85.0
    ye = 85.0
    yor = -60.0
  } else if  isel >= 8 && isel <= 10 {
    ya = 0.0
    ye = 90.0
    yor = 0.0
  }

  dislin.Labdig (-1, "xy")
  dislin.Name   ("Longitude", "x")
  dislin.Name   ("Latitude", "y")
  dislin.Projct (cl2[isel-1])
  dislin.Titlin (cl1[isel-1] + "Projection", 3)
  dislin.Htitle (50)
  dislin.Grafmp (xa, xe, xor, xstp, ya, ye, yor, ystp)
  dislin.Title  ()
  dislin.Gridmp (1, 1)
  dislin.Color ("green")
  dislin.World ()
  dislin.Errmod ("protocol", "off")
  dislin.Disfin ()
}

func main  () {
  nproj := 14
  clis  := cl1[0]

  for i:= 1; i < nproj; i++ {
    clis = dislin.Itmcat (clis, cl1[i])
  }

  dislin.Swgtit ("DISLIN Map Plot")
  ip  := dislin.Wgini ("hori")
  dislin.Swgwth (-15)
  ip1 := dislin.Wgbas (ip, "vert")
  dislin.Swgwth (-50)
  ip2 := dislin.Wgbas (ip, "vert")

  dislin.Swgdrw (2100.0/2970.0)
  dislin.Wglab (ip1, "Projection:")
  id_lis = dislin.Wglis (ip1, clis, 1)

  id_but := dislin.Wgpbut (ip1, "Plot")
  dislin.Swgcbk (id_but, myplot)

  dislin.Wgquit (ip1)

  dislin.Wglab (ip2, "DISLIN Draw Widget:")
  id_draw = dislin.Wgdraw (ip2)
  dislin.Wgfin ()
}





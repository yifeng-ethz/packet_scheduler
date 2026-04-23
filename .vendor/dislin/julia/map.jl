include("Dislin.jl")

id_lis = 0
id_draw = 0

cl1 =  ["Cylindrical Equidistant", 
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
       "Azimuthal Orthgraphic"]

cl2 = ["CYLI", "MERC", "EQUA", "HAMM", "AITO", "WINK",
       "SANS", "CONI", "ALBE", "CONF", "AZIM", "LAMB",
       "STER", "ORTH"]

function myplot(id)
  xa   = -180.0 
  xe   =  180.0
  xor  = -180.0
  xstp =   60.0

  ya   = -90.0 
  ye   =  90.0
  yor  = -90.0
  ystp =  30.0

  isel = Dislin.gwglis(id_lis)
  Dislin.setxid(id_draw, "widget")
  Dislin.metafl("xwin")
  Dislin.disini()
  Dislin.erase()
  Dislin.complx()

  if (isel >=4 && isel <= 7) 
    Dislin.noclip()
  elseif (isel == 2)
    ya = -85.0
    ye = 85.0
    yor = -60.0
  elseif (isel >= 8 && isel <= 10)
    ya = 0.0
    ye = 90.0
    yor = 0.0
  end

  Dislin.labdig(-1, "xy")
  Dislin.name("Longitude", "x")
  Dislin.name("Latitude", "y")
  Dislin.projct(cl2[isel])
  Dislin.titlin(cl1[isel] * "Projection", 3)
  Dislin.htitle(50)
  Dislin.grafmp(xa, xe, xor, xstp, ya, ye, yor, ystp)
  Dislin.title()
  Dislin.gridmp(1, 1)
  Dislin.color("green")
  Dislin.world()
  Dislin.unit(0)
  Dislin.disfin()
end

nproj = 14
clis = cl1[1]
for i = 2:nproj
  global clis = Dislin.itmcat(clis, cl1[i])
end

Dislin.swgtit("DISLIN Map Plot")
ip  = Dislin.wgini("hori")
Dislin.swgwth(-15)
ip1 = Dislin.wgbas(ip, "vert")
Dislin.swgwth(-50)
ip2 = Dislin.wgbas(ip, "vert")

Dislin.swgdrw(2100.0/2970.0)
id = Dislin.wglab(ip1, "Projection:")
id_lis = Dislin.wglis(ip1, clis, 1)

id_but = Dislin.wgpbut(ip1, "Plot")
Dislin.swgcbk(id_but, myplot)

id_quit = Dislin.wgquit(ip1)

id = Dislin.wglab(ip2, "DISLIN Draw Widget:")
id_draw = Dislin.wgdraw(ip2)
Dislin.wgfin()






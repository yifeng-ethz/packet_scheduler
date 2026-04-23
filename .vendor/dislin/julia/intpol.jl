include("Dislin.jl")

ctit = "Interpolation Methods"

xray = [0.0, 1.0, 3.0, 4.5, 6.0, 8.0, 9.0, 11.0, 12.0, 12.5, 
        13.0, 15.0, 16.0, 17.0, 19.0, 20.0]
yray = [2.0, 4.0, 4.5, 3.0, 1.0, 7.0, 2.0, 3.0, 5.0, 2.0, 2.5,
        2.0, 4.0, 6.0, 5.5, 4.0]
cpol = ["SPLINE", "STEM", "BARS", "STAIRS", "STEP", "LINEAR"]

Dislin.setpag("da4p")
Dislin.scrmod("revers")
Dislin.metafl("cons")

Dislin.disini()
Dislin.pagera()
Dislin.hwfont()

Dislin.incmrk(1)
Dislin.hsymbl(25)
Dislin.titlin(ctit, 1)
Dislin.axslen(1500, 350)
Dislin.setgrf("LINE", "LINE", "LINE", "LINE")

ic = Dislin.intrgb(1.0, 1.0, 0.0)
Dislin.axsbgd(ic)

nya = 2700
for i = 1:6
  Dislin.axspos(350, nya - (i - 1)  * 350)
  Dislin.polcrv(cpol[i])
  Dislin.marker(0)
  Dislin.graf(0.0, 20.0, 0.0, 5.0, 0.0, 10.0, 0.0, 5.0)
  nx = Dislin.nxposn(1.0)
  ny = Dislin.nyposn(8.0)
  Dislin.messag(cpol[i], nx, ny)
  Dislin.color("red")
  Dislin.curve(xray, yray, 16)
  Dislin.color("fore")

  if (i == 6)
    Dislin.height(50)
    Dislin.title()
  end

  Dislin.endgrf()
end

Dislin.disfin()



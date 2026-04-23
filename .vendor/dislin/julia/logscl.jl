include("Dislin.jl")

ctit = "Logarithmic Scaling"
clab = ["LOG", "FLOAT", "ELOG"]

Dislin.scrmod("revers")
Dislin.setpag("da4p")
Dislin.metafl("cons")

Dislin.disini()
Dislin.pagera()
Dislin.complx()
Dislin.axslen(1400, 500)

Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")
Dislin.axsscl("LOG", "XY")

Dislin.titlin(ctit, 2)

for i = 1:3
  nya = 2650 - (i - 1) * 800
  Dislin.labdig(-1, "XY")
  if (i == 2)
    Dislin.labdig(1, "Y")
    Dislin.name(" ", "X")
  end

  Dislin.axspos(500, nya)
  Dislin.messag("Labels: " * clab[i], 600, nya - 400)
  Dislin.labels(clab[i], "XY")
  Dislin.graf(0.0, 3.0, 0.0, 1.0, -1.0, 2.0, -1.0, 1.0)
  if (i == 3)
    Dislin.height(50)
    Dislin.title()
  end

  Dislin.endgrf()
end

Dislin.disfin()



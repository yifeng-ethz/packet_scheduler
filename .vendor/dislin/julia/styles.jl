include("Dislin.jl")

ctit1 = "Demonstration of CURVE"
ctit2 = "Line Styles"

ctyp = ["SOLID", "DOT", "DASH", "CHNDSH", 
        "CHNDOT", "DASHM", "DOTL", "DASHL"]
x = [3.0, 9.0]
y = [0.0, 0.0]

Dislin.metafl("cons")
Dislin.scrmod("revers")
Dislin.setpag("da4p")

Dislin.disini()
Dislin.pagera()
Dislin.complx()
Dislin.center()

Dislin.chncrv("BOTH")
Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.graf(0.0, 10.0, 0.0, 2.0, 0.0, 10.0, 0.0, 2.0)
Dislin.title()

for i = 1:8
  y[1] = 9.5 - i
  y[2] = 9.5 - i
  nx = Dislin.nxposn(1.0)
  ny = Dislin.nyposn(y[1])
  Dislin.messag(ctyp[i], nx, ny - 20)
  Dislin.curve(x, y, 2)
end

Dislin.disfin()



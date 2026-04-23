include("Dislin.jl")

n = 300
fpi = 3.1415926 / 180
stp = 360.0 / (n - 1)

xray  = Array{Float64}(undef, n)
y1ray = Array{Float64}(undef, n)
y2ray = Array{Float64}(undef, n)

for i = 1:n
  xray[i] = (i - 1) * stp
  x = xray[i] * fpi 
  y1ray[i] = sin(x)
  y2ray[i] = cos(x)
end

Dislin.scrmod("revers")
Dislin.metafl("xwin")
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.axspos(450, 1800)
Dislin.axslen(2200, 1200)

Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")
Dislin.labdig(-1, "X")
Dislin.ticks(10, "Y")
Dislin.ticks(9, "X")

Dislin.titlin("Demonstration of CURVE", 1)
Dislin.titlin("SIN(X), COS(X)", 3)

ic = Dislin.intrgb(0.95, 0.95, 0.95)
Dislin.axsbgd(ic)

Dislin.graf(0.0, 360.0, 0.0, 90.0, -1.0, 1.0, -1.0, 0.5)

Dislin.setrgb(0.7, 0.7, 0.7)
Dislin.grid(1, 1)

Dislin.color("fore")
Dislin.height(50)
Dislin.title()

Dislin.color("red")
Dislin.curve(xray, y1ray, n)
Dislin.color("green")
Dislin.curve(xray, y2ray, n)
Dislin.disfin()

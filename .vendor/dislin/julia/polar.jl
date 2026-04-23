include("Dislin.jl")

n = 300
m = 10
step = 360.0 / (n - 1)

xray  = Array{Float64}(undef, n)
x1  = Array{Float64}(undef, n)
y1  = Array{Float64}(undef, n)

x2  = Array{Float64}(undef, m)
y2  = Array{Float64}(undef, m)

for i = 1:n
  xray[i] = (i - 1) * step
  y1[i] = ((i - 1) * step) * 3.1415926 / 180.0
  x1[i] = sin(5 * y1[i])
end

for i = 1:m
  x2[i] = i
  y2[i] = i
end

Dislin.setpag("da4p")
Dislin.scrmod("revers")
Dislin.metafl("cons")
Dislin.disini()
Dislin.complx()
Dislin.pagera()

Dislin.titlin("Polar Plots", 2)
Dislin.ticks(3, "Y")
Dislin.axends("NOENDS", "X")
Dislin.labdig(-1, "Y")
Dislin.axslen(1000, 1000)
Dislin.axsorg(1050, 900)

ic = Dislin.intrgb(0.95,0.95,0.95)
Dislin.axsbgd(ic)
Dislin.grafp(1.0, 0.0, 0.2, 0.0, 30.0);
Dislin.color("blue")
Dislin.curve(x1, y1, n)
Dislin.color("fore")
Dislin.htitle(50)
Dislin.title()
Dislin.endgrf()

Dislin.labdig(-1, "X")
Dislin.axsorg(1050, 2250)
Dislin.labtyp("VERT", "Y")
Dislin.grafp(10.0, 0.0, 2.0, 0.0, 30.0)
Dislin.barwth(-5.0)
Dislin.polcrv("FBARS")
Dislin.color("blue")
Dislin.curve(x2, y2, m)

Dislin.disfin()

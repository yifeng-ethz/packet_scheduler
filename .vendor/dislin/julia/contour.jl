include("Dislin.jl")

ctit1 = "Contour Plot"
ctit2 = "F(X,Y) = 2 * SIN(X) * SIN(Y)"

n = 50
m = 50
xray = Array{Float64}(undef, n)
yray = Array{Float64}(undef, m)
zmat = Array{Float64}(undef, n, m)

fpi  = 3.1415927 / 180.0
stepx = 360.0 / (n - 1)
stepy = 360.0 / (m - 1)

for i = 1:n
  xray[i] = (i - 1) * stepx
end

for i = 1:m
  yray[i] = (i - 1) * stepy
end

for i = 1:n
  x = (i - 1) * stepx
  for j = 1:m
    y = (j - 1) * stepy
    zmat[i,j] = 2 * sin(x * fpi) * sin(y * fpi)
  end
end

Dislin.scrmod("revers")
Dislin.metafl("cons")
Dislin.setpag("da4p")
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.intax()
Dislin.axspos(450, 2650)

Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")

Dislin.graf(0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0)
Dislin.height(50)
Dislin.title()

Dislin.height(30)
for i = 1:9
  zlev = -2.0 + i * 0.5
  if (i == 5)
    Dislin.labels("NONE", "CONTUR")
  else
    Dislin.labels("FLOAT", "CONTUR")
  end

  Dislin.setclr(i * 28)
  Dislin.contur(xray, n, yray, m, zmat, zlev)
end

Dislin.disfin()

include("Dislin.jl")

ctit1 = "Shaded Contour Plot"
ctit2 = "F(X,Y) =(X[2\$ - 1)[2\$ +(Y[2\$ - 1)[2\$"

n = 50
m = 50
xray = Array{Float64}(undef, n)
yray = Array{Float64}(undef, m)
zlev = Array{Float64}(undef, 12)
zmat = Array{Float64}(undef, n, m)

stepx = 1.6 /(n - 1)
stepy = 1.6 /(m - 1)

for i = 1:n
  xray[i] = (i - 1) * stepx
end

for i = 1:m
  yray[i] = (i - 1) * stepy
end

for i = 1:n
  x = xray[i] * xray[i] - 1.0
  x = x * x
  for j = 1:m
    y = yray[j] * yray[j] - 1.0
    zmat[i,j] = x + y * y
  end
end

Dislin.scrmod("revers")
Dislin.metafl("cons")
Dislin.setpag("da4p")

Dislin.disini()
Dislin.pagera()
Dislin.complx()
Dislin.mixalf()

Dislin.titlin(ctit1, 1)
Dislin.titlin(ctit2, 3)

Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")

Dislin.axspos(450, 2670)
Dislin.shdmod("poly", "contur")
Dislin.graf(0.0, 1.6, 0.0, 0.2, 0.0, 1.6, 0.0, 0.2)

for i = 1:12
  zlev[13-i] = 0.1 + (i - 1) * 0.1
end

Dislin.conshd(xray, n, yray, m, zmat, zlev, 12)

Dislin.height(50)
Dislin.title()

Dislin.disfin()

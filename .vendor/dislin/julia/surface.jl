include("Dislin.jl")

ctit1 = "Surface Plot of the Function"
ctit2 = "F(X,Y) = 2 * SIN(X) * SIN(Y)"

n = 50
m = 50
zmat = Array{Float64}(undef, n, m)

fpi  = 3.1415927 / 180.0
stepx = 360.0 / (n - 1)
stepy = 360.0 / (m - 1)

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

Dislin.titlin(ctit1, 2)
Dislin.titlin(ctit2, 4)

Dislin.axspos(200, 2600)
Dislin.axslen(1800, 1800)

Dislin.name("X-axis", "X")
Dislin.name("Y-axis", "Y")
Dislin.name("Z-axis", "Z")

Dislin.view3d(-5.0, -5.0, 4.0, "ABS")
Dislin.graf3d(0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0,
                -3.0, 3.0, -3.0, 1.0)
Dislin.height(50)
Dislin.title()

Dislin.color("green")
Dislin.surmat(zmat, n, m, 1, 1)
Dislin.disfin()

include("Dislin.jl")

ix  = [0, 300, 300,   0]
iy  = [0,   0, 400, 400]

ixp  = Array{Int32}(undef, 4)
iyp  = Array{Int32}(undef, 4)

Dislin.scrmod("revers")
Dislin.metafl("cons")
Dislin.disini()
Dislin.setvlt("small")
Dislin.pagera()
Dislin.complx()

Dislin.height(50)
ctit = "Shading patterns (AREAF)"
n = Dislin.nlmess(ctit)
Dislin.messag(ctit, div(2970 - n, 2), 200)

nx0 = 335
ny0 = 350

for i = 0:2
  ny = ny0 + i * 600

  for j = 0:5
    nx = nx0 + j * 400
    ii = i * 6 + j
    x = i * 6.0 + j

    Dislin.shdpat(ii)
    iclr = i * 6 + j + 1
    iclr = iclr % 8
    if (iclr == 0)
      iclr = 8
    end 
    Dislin.setclr(iclr)
    for k = 1:4
      ixp[k] = ix[k] + nx
      iyp[k] = iy[k] + ny
    end

    Dislin.areaf(ixp, iyp, 4)
    nl = Dislin.nlnumb(x, -1)
    nx = nx + div(300 - nl, 2)
    Dislin.color("foreground")
    Dislin.number(x, -1, nx, ny + 460) 
  end
end

Dislin.disfin()

include("Dislin.jl")

ivec  = [0, 1111, 1311, 1421, 1531, 1701, 1911,
          3111, 3311, 3421, 3531, 3703, 4221, 4302,
          4413, 4522, 4701, 5312, 5502, 5703]

ctit = "Vectors"

Dislin.scrmod("revers")
Dislin.metafl("cons")
Dislin.disini()
Dislin.pagera()
Dislin.complx()

Dislin.height(60)
n = Dislin.nlmess(ctit)
Dislin.messag(ctit, div(2970 - n, 2), 200)

Dislin.height(50)
nx = 300
ny = 400

for i = 1:20
  if (i == 11)
    global nx = nx + div(2970, 2)
    global ny = 400
  end

  x = ivec[i] * 1.0
  nl = Dislin.nlnumb(x, -1)
  Dislin.number(x, -1, nx - nl, ny - 25)

  Dislin.vector(nx + 100, ny, nx + 1000, ny, ivec[i])
  global ny = ny + 160
end

Dislin.disfin()

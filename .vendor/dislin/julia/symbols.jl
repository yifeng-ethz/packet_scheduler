include("Dislin.jl")
ctit = "Symbols"

Dislin.setpag("da4p")
Dislin.metafl("cons")

Dislin.disini()
Dislin.pagera()
Dislin.hwfont()
Dislin.paghdr("H. Michels (", ")", 2, 0)

Dislin.height(60)
n = Dislin.nlmess(ctit)
Dislin.messag(ctit, div(2100 - n, 2), 200)

Dislin.height(50)
Dislin.hsymbl(120)

ny = 150
nxp = 0 

for j = 1:24
  i = j - 1
  x = j - 1.0
  if((i % 4) == 0)
    global ny  = ny + 400
    global nxp = 550
  else 
    global nxp = nxp + 350
  end
  nl = Dislin.nlnumb(x, -1)
  Dislin.number(x, -1, nxp - div(nl, 2), ny + 150)
  Dislin.symbol(i, nxp, ny)
end
Dislin.disfin()


package main

import "dislin"

func main () {
  var ctit = "Symbols"
  var nl, ny, nxp int

  dislin.Setpag ("da4p")
  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Complx ()
  dislin.Pagera ()

  dislin.Paghdr ("H. Michels   (", ")", 2, 0)

  dislin.Height (60)
  nl = dislin.Nlmess (ctit)
  dislin.Messag (ctit,  (2100 - nl) / 2, 200)

  dislin.Height (50)
  dislin.Hsymbl (120)

  ny = 150
  for i:=0; i < 22; i++ {
    if  (i % 4) == 0 {
      ny = ny + 400
      nxp = 550
    } else {
      nxp = nxp + 350
    }

    x := float64 (i)
    nl = dislin.Nlnumb (x, -1)
    dislin.Number (x, -1, nxp - nl/2, ny + 150)
    dislin.Symbol (i, nxp, ny)
  }
  dislin.Disfin ()
}

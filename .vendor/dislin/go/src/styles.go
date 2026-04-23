package main

import "dislin"

func main  () {
  ctit1 := "Demonstration of CURVE"
  ctit2 := "Line Styles"

  ctyp := [8]string{"SOLID", "DOT", "DASH", "CHNDSH", 
                    "CHNDOT", "DASHM", "DOTL", "DASHL"}
  x := [2]float64{3.0, 9.0}
  y := [2]float64{0.0, 0.0}

  dislin.Metafl ("cons")
  dislin.Setpag ("da4p")

  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()
  dislin.Center ()

  dislin.Chncrv ("BOTH")
  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")

  dislin.Titlin (ctit1, 1)
  dislin.Titlin (ctit2, 3)

  dislin.Graf   (0.0, 10.0, 0.0, 2.0, 0.0, 10.0, 0.0, 2.0)
  dislin.Title  ()

  for i := 0; i < 8; i++ {
    y[0] = 8.5 - float64 (i)
    y[1] = 8.5 - float64 (i)
    nx := dislin.Nxposn (1.0)
    ny := dislin.Nyposn (y[0])
    dislin.Messag (ctyp[i], nx, ny - 20)
    dislin.Curve (&x[0], &y[0], 2)
  }

  dislin.Disfin ()
}



package main

import "dislin"
import "math"
 
func main () {
  const n int = 50
  const m int = 50
  var zmat [n][m]float64

  ctit1 := "3-D  Colour Plot of the Function"
  ctit2 := "F(X,Y) = 2 * SIN(X) * SIN (Y)"

  fpi   := 3.1415927 / 180.0
  stepx := 360.0 / float64 (n - 1)
  stepy := 360.0 / float64 (m - 1)

  for i:= 0; i < n; i++ {
    x := float64 (i) * stepx
    for j:= 0; j < m; j++ {
      y := float64 (j) * stepy
      zmat[i][j] = 2 * math.Sin (x * fpi) * math.Sin (y * fpi)
    }
  }

  dislin.Metafl ("xwin")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Titlin (ctit1, 1)
  dislin.Titlin (ctit2, 3)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")
  dislin.Name   ("Z-axis", "Z")

  dislin.Intax  ()
  dislin.Autres (n, m)
  dislin.Axspos (300, 1850)
  dislin.Ax3len (2200, 1400, 1400)

  dislin.Graf3  (0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0,
                -2.0, 2.0, -2.0, 1.0)
  dislin.Crvmat (&zmat[0][0], n, m, 1, 1)
  dislin.Height (50)
  dislin.Title  ()
  dislin.Disfin ()
}





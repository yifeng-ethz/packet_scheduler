package main

import "dislin"
import "math"
 
func main () {
  const n int = 50
  const m int = 50
  var zmat [n][m]float64
  ctit1 := "Surface Plot of the Function"
  ctit2 := "F (X,Y) = 2 * SIN (X) * SIN (Y)"

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

  dislin.Metafl ("cons")
  dislin.Setpag ("da4p")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Titlin (ctit1, 2)
  dislin.Titlin (ctit2, 4)

  dislin.Axspos (200, 2600)
  dislin.Axslen (1800, 1800)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")
  dislin.Name   ("Z-axis", "Z")

  dislin.View3d (-5.0, -5.0, 4.0, "ABS")
  dislin.Graf3d (0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0,
                -3.0, 3.0, -3.0, 1.0)
  dislin.Height (50)
  dislin.Title  ()

  dislin.Color ("green")
  dislin.Surmat (&zmat[0][0], n, m, 1, 1)
  dislin.Disfin ()
}





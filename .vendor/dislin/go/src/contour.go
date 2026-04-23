package main

import "dislin"
import "math"
 
func main () {
  const n int = 50
  const m int = 50
  var xray [n] float64
  var yray [m] float64
  var zmat [n][m]float64

  ctit1 := "Contour Plot"
  ctit2 := "F(X,Y) = 2 * SIN(X) * SIN(Y)"

  fpi   := 3.1415927 / 180.0
  stepx := 360.0 / float64 (n - 1)
  stepy := 360.0 / float64 (m - 1)

  for i:= 0; i < n; i++ {
    xray[i] = float64 (i) * stepx
  }

  for i:= 0; i < m; i++ {
    yray[i] = float64 (i) * stepy
  }

  for i:= 0; i < n; i++ {
    x := xray[i] * fpi
    for j:= 0; j < m; j++ {
      y := yray[j] * fpi
      zmat[i][j] = 2 * math.Sin (x) * math.Sin (y)
    }
  }

  dislin.Metafl ("cons")
  dislin.Setpag ("da4p")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Titlin (ctit1, 1)
  dislin.Titlin (ctit2, 3)

  dislin.Intax  ()
  dislin.Axspos (450, 2650)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")

  dislin.Graf   (0.0, 360.0, 0.0, 90.0, 0.0, 360.0, 0.0, 90.0)
  dislin.Height (50)
  dislin.Title  ()

  dislin.Height (30)

  for i:= 0; i < 8; i++ {
    zlev := -2.0 + float64 (i) * 0.5
  
    if i == 4 {
      dislin.Labels ("NONE", "CONTUR")
    } else {
      dislin.Labels ("FLOAT", "CONTUR")
    }

    dislin.Setclr ( (i+1) * 28)
    dislin.Contur (&xray[0], n, &yray[0], m, &zmat[0][0], zlev)
  }
  dislin.Disfin ()
}





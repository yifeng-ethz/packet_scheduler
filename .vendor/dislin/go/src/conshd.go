package main

import "dislin"
 
func main () {
  const n int = 50
  const m int = 50
  var xray [n] float64
  var yray [m] float64
  var zmat [n][m]float64
  var zlev [12] float64

  ctit1 := "Shaded Contour Plot"
  ctit2 := "F(X,Y) =(X[2$ - 1)[2$ +(Y[2$ - 1)[2$"

  stepx := 1.6 / float64 (n - 1)
  stepy := 1.6 / float64 (m - 1)

  for i:= 0; i < n; i++ {
    xray[i] = float64 (i) * stepx
  }

  for i:= 0; i < m; i++ {
    yray[i] = float64 (i) * stepy
  }

  for i:= 0; i < n; i++ {
    x := xray[i] * xray[i] - 1.0
    x = x * x
    for j:= 0; j < m; j++ {
      y := yray[j] * yray[j] - 1.0
      zmat[i][j] = x + y * y
    }
  }

  dislin.Metafl ("cons")
  dislin.Setpag ("da4p")

  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()
  dislin.Mixalf ()

  dislin.Titlin (ctit1, 1)
  dislin.Titlin (ctit2, 3)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")

  dislin.Axspos (450, 2670)
  dislin.Shdmod ("poly", "contur")
  dislin.Graf   (0.0, 1.6, 0.0, 0.2, 0.0, 1.6, 0.0, 0.2)

  for i:= 0; i < 12; i++ {
    zlev[11-i] = 0.1 + float64 (i) * 0.1
  }

  dislin.Conshd (&xray[0], n, &yray[0], m, &zmat[0][0], &zlev[0], 12)

  dislin.Height (50)
  dislin.Title  ()
  dislin.Disfin ()
}





package main

import "dislin"
import "math"
 
func main () {
  const n int = 300
  const m int = 10
  var x1, y1  [n]float64
  var x2, y2  [m]float64

  pi := 3.1415926
  f := pi / 180.0
  step := 360.0 / float64 (n - 1)

  for i:= 0; i < n; i++ {
    a := (float64 (i) * step) * f
    y1[i] = a
    x1[i] = math.Sin (5 * a)
  }

  for i:= 0; i < m; i++ {
    x2[i] = float64 (i + 1)
    y2[i] = float64 (i + 1)
  }

  dislin.Setpag ("da4p")
  dislin.Scrmod ("revers")
  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Complx ()
  dislin.Pagera ()

  dislin.Titlin ("Polar Plots", 2)
  dislin.Ticks  (3, "Y")
  dislin.Axends ("NOENDS", "X")
  dislin.Labdig (-1, "Y")
  dislin.Axslen (1000, 1000)
  dislin.Axsorg (1050, 900)

  ic := dislin.Intrgb (0.95,0.95,0.95)
  dislin.Axsbgd (ic)
  dislin.Grafp  (1.0, 0.0, 0.2, 0.0, 30.0);
  dislin.Color  ("blue")
  dislin.Curve  (&x1[0], &y1[0], n)
  dislin.Color  ("fore")
  dislin.Htitle (50)
  dislin.Title  ()
  dislin.Endgrf ()

  dislin.Labdig (-1, "X")
  dislin.Axsorg (1050, 2250)
  dislin.Labtyp ("VERT", "Y")
  dislin.Grafp  (10.0, 0.0, 2.0, 0.0, 30.0)
  dislin.Barwth (-5.0)
  dislin.Polcrv ("FBARS")
  dislin.Color  ("blue")
  dislin.Curve  (&x2[0], &y2[0], m)

  dislin.Disfin ()
}

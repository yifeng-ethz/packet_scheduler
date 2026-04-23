package main

import "dislin"
import "math"
 
func main () {
  const n int = 100
  var step, fpi, x float64
  var xray, y1ray, y2ray  [n]float64

  step = 360.0 / float64 (n - 1)
  fpi  = 3.1415926 / 180.0
  for i:= 0; i < n; i++ {
     xray[i] = float64 (i) * step
     x = xray[i] * fpi
     y1ray[i] = math.Sin (x)
     y2ray[i] = math.Cos (x)
  }

  dislin.Metafl ("xwin")
  dislin.Scrmod ("reverse")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")
  dislin.Labdig (-1, "X")
  dislin.Ticks  (9, "X")
  dislin.Ticks  (10, "Y")

  dislin.Titlin ("Demonstration of CURVE", 1)
  dislin.Titlin ("SIN (X), COS (X)", 3)

  dislin.Axspos (450, 1800)
  dislin.Axslen (2200, 1200)

  ic := dislin.Intrgb (0.95, 0.95, 0.95)
  dislin.Axsbgd (ic)

  dislin.Graf   (0.0, 360.0, 0.0, 90.0, -1.0, 1.0, -1.0, 0.5)
  dislin.Setrgb (0.7, 0.7, 0.7)
  dislin.Grid   (1, 1)
  dislin.Color  ("fore")
  dislin.Height (50)
  dislin.Title  ()
 
  dislin.Color  ("red")
  dislin.Curve (&xray[0], &y1ray[0], n) 
  dislin.Color  ("green")
  dislin.Curve (&xray[0], &y2ray[0], n) 
  dislin.Disfin ()
}
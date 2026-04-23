package main

import "dislin"
import "math"
 
func main  () {
  const n int = 101
  var xray, y1ray, y2ray  [n]float64
  var cbuf [14]int8

  f := 3.1415926 / 180.0
  step := 360.0 /  float64 (n - 1)

  for i:= 0; i < n; i++ {
     xray[i] = float64 (i) * step
     x := xray[i] * f
     y1ray[i] = math.Sin (x)
     y2ray[i] = math.Cos (x)
  }

  dislin.Metafl ("xwin")
  dislin.Disini ()
  dislin.Complx ()

  dislin.Axspos (450, 1800)
  dislin.Axslen (2200, 1200)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")

  dislin.Labdig (-1, "X")
  dislin.Ticks  (10, "XY")

  dislin.Titlin ("Demonstration of CURVE", 1)
  dislin.Titlin ("Legend", 3)
 
  dislin.Graf   (0.0, 360.0, 0.0, 90.0, -1.0, 1.0, -1.0, 0.5)
  dislin.Title  ()
  dislin.Xaxgit ()
  dislin.Chncrv ("BOTH")
  dislin.Curve (&xray[0], &y1ray[0], n)
  dislin.Curve (&xray[0], &y2ray[0], n)

  dislin.Legini (&cbuf[0], 2, 7)   
  nx := dislin.Nxposn (190.0)
  ny := dislin.Nyposn (0.75)
  dislin.Leglin (&cbuf[0], "sin (x)", 1)
  dislin.Leglin (&cbuf[0], "cos (x)", 2)
  dislin.Legpos (nx, ny)
  dislin.Legtit ("Legend")
  dislin.Legend (&cbuf[0], 3)
  dislin.Disfin ()
}


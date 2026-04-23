package main

import "dislin"
import "math"

func myfunc (x float64, y float64, iopt int) float64 {
  var xv float64

  if iopt == 1 {
     xv = math.Cos (x) * (3 + math.Cos (y))
  } else if iopt == 2 {
     xv = math.Sin (x) * (3 + math.Cos (y))
  } else {
     xv = math.Sin (y)
  }
  return xv
}
 
func main () {

  ctit1 := "Surface Plot of the Parametric Function"
  ctit2 := "[COS(t)*(3+COS(u)), SIN(t)*(3+COS(u)), SIN(u)]"
  pi  := 3.1415927

  dislin.Metafl ("cons")
  dislin.Setpag ("da4p")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Titlin (ctit1, 2)
  dislin.Titlin (ctit2, 4)

  dislin.Axspos (200, 2400)
  dislin.Axslen (1800, 1800)

  dislin.Name   ("X-axis", "X")
  dislin.Name   ("Y-axis", "Y")
  dislin.Name   ("Z-axis", "Z")
  dislin.Intax  ()

  dislin.Vkytit (-300)
  dislin.Zscale (-1.0,1.0)
  dislin.Surmsh ("on")

  dislin.Graf3d (-4.0,4.0,-4.0,1.0,-4.0,4.0,-4.0,1.0,-3.0,3.0,-3.0,1.0)
  dislin.Height (40)
  dislin.Title  ()

  step := 2.0 * pi / 30.0
  dislin.Surfcp (myfunc, 0.0, 2.0 * pi, step, 0.0, 2.0 * pi, step)
  dislin.Disfin ()
}

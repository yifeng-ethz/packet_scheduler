package main

import "dislin"

func main  () {
  ctit := "Interpolation Methods"
  cpol := [6]string{"SPLINE", "STEM", "BARS", "STAIRS", "STEP", "LINEAR"}
  xray := [16]float64{0.0, 1.0, 3.0, 4.5, 6.0, 8.0, 9.0, 11.0, 12.0, 12.5, 
           13.0, 15.0, 16.0, 17.0, 19.0, 20.0}
  yray := [16]float64{2.0, 4.0, 4.5, 3.0, 1.0, 7.0, 2.0, 3.0, 5.0, 2.0, 2.5,
           2.0, 4.0, 6.0, 5.5, 4.0}

  dislin.Setpag ("da4p")
  dislin.Metafl ("cons")

  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Incmrk (1)
  dislin.Hsymbl (25)
  dislin.Titlin (ctit, 1)
  dislin.Axslen (1500, 350)
  dislin.Setgrf ("LINE", "LINE", "LINE", "LINE")

  nya := 2700
  for i:=0; i < 6; i++ {
    dislin.Axspos (350, nya - i * 350)
    dislin.Polcrv (cpol[i])
    dislin.Marker (0)
    dislin.Graf (0.0, 20.0, 0.0, 5.0, 0.0, 10.0, 0.0, 5.0)
    nx := dislin.Nxposn (1.0)
    ny := dislin.Nyposn (8.0)
    dislin.Messag (cpol[i], nx, ny)
    dislin.Curve (&xray[0], &yray[0], 16)

    if i == 5 {
      dislin.Height (50)
      dislin.Title ()
    }

    dislin.Endgrf ()
  }

  dislin.Disfin ()
}



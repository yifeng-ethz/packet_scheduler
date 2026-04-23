package main

import "dislin"

func main  () {
  ctit := "Logarithmic Scaling"
  clab :=[3]string{"LOG", "FLOAT", "ELOG"}

  dislin.Setpag ("da4p")
  dislin.Metafl ("cons")

  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()
  dislin.Axslen (1400, 500)

  dislin.Name ("X-axis", "X")
  dislin.Name ("Y-axis", "Y")
  dislin.Axsscl ("LOG", "XY")

  dislin.Titlin (ctit, 2)

  for i:= 0; i < 3; i++ {
    nya := 2650 - i * 800
    dislin.Labdig (-1, "XY")

    if i == 1 {
      dislin.Labdig (1, "Y")
      dislin.Name (" ", "X")
    }

    dislin.Axspos (500, nya)
    dislin.Messag ("Labels: " + clab[i], 600, nya - 400)
    dislin.Labels (clab[i], "XY")
    dislin.Graf   (0.0, 3.0, 0.0, 1.0, -1.0, 2.0, -1.0, 1.0)

    if i == 2 {
      dislin.Height (50)
      dislin.Title ()
    }

    dislin.Endgrf ()
  }

  dislin.Disfin ()
}



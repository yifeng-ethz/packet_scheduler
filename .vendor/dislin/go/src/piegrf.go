package main

import "dislin"

func main  () {
  var cbuf [14]int8
  xray  := [5]float64{1.0, 2.5, 2.0, 2.7, 1.8}

  ctit := "Pie Charts(PIEGRF)"

  dislin.Setpag ("da4p")
  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()
  dislin.Chnpie ("BOTH")

  dislin.Axslen (1600, 1000)
  dislin.Titlin (ctit, 2)

  dislin.Legini (&cbuf[0], 5, 8)
  dislin.Leglin (&cbuf[0], "FIRST",  1)
  dislin.Leglin (&cbuf[0], "SECOND", 2)
  dislin.Leglin (&cbuf[0], "THIRD",  3)
  dislin.Leglin (&cbuf[0], "FOURTH", 4)
  dislin.Leglin (&cbuf[0], "FIFTH",  5)

  dislin.Patcyc (1, 7)
  dislin.Patcyc (2, 4)
  dislin.Patcyc (3, 13)
  dislin.Patcyc (4, 3)
  dislin.Patcyc (5, 5)

  dislin.Axspos (250, 2800)
  dislin.Piegrf (&cbuf[0], 1, &xray[0], 5)
  dislin.Endgrf ()

  dislin.Axspos (250, 1600)
  dislin.Labels ("DATA", "PIE")
  dislin.Labpos ("EXTERNAL", "PIE")
  dislin.Piegrf (&cbuf[0], 1, &xray[0], 5)

  dislin.Height (50)
  dislin.Title  ()
  dislin.Disfin ()
}
package main

import "dislin"

func main  () {
  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Axspos (400, 1850)
  dislin.Axslen (2400, 1400)

  dislin.Name   ("Longitude", "X")
  dislin.Name   ("Latitude",  "Y")
  dislin.Titlin ("World Coastlines and Lakes", 3)

  dislin.Labels ("MAP", "XY")
  dislin.Labdig (-1, "XY")
  dislin.Grafmp (-180.0, 180.0, -180.0, 90.0, -90.0, 90.0, -90.0, 30.0)

  dislin.Gridmp (1, 1)
  dislin.Color ("green")
  dislin.World ()

  dislin.Color ("foreground")
  dislin.Height (50)
  dislin.Title ()

  dislin.Disfin ()
}
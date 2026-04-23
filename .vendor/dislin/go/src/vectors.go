package main

import "dislin"

func main  () {
  ivec := [20]int{0, 1111, 1311, 1421, 1531, 1701, 1911,
          3111, 3311, 3421, 3531, 3703, 4221, 4302,
          4413, 4522, 4701, 5312, 5502, 5703}
  ctit := "Vectors"

  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Height (60)
  nl := dislin.Nlmess (ctit)
  dislin.Messag (ctit,  (2970 - nl)/2, 200)

  dislin.Height (50)
  nx := 300
  ny := 400

  for i := 0; i < 20; i++ {
    if i == 10 {
      nx = nx + 2970 / 2
      ny = 400
    }

    nl = dislin.Nlnumb (float64 (ivec[i]), -1)
    dislin.Number (float64 (ivec[i]), -1, nx - nl, ny - 25)

    dislin.Vector (nx + 100, ny, nx + 1000, ny, ivec[i])
    ny = ny + 160
  }

  dislin.Disfin ()
}
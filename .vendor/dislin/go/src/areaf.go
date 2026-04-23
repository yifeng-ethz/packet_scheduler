package main

import "dislin"

func main  () {
  ix  := [4]int32{0, 300, 300,   0}
  iy  := [4]int32{0,   0, 400, 400}
  ixp := [4]int32{0, 0, 0, 0}
  iyp := [4]int32{0, 0, 0, 0}

  dislin.Metafl ("cons")
  dislin.Disini ()
  dislin.Setvlt ("small")
  dislin.Pagera ()
  dislin.Complx ()

  dislin.Height (50)
  ctit := "Shading patterns  (AREAF)"
  nl := dislin.Nlmess (ctit)
  dislin.Messag (ctit,  (2970 - nl)/2, 200)

  nx0 := 335
  ny0 := 350

  iclr := 0
  for i := 0; i < 3; i++ {
    ny := ny0 + i * 600

    for j := 0; j < 6; j++ {
      nx := nx0 + j * 400
      ii := i * 6 + j
      dislin.Shdpat (ii)
      iclr = iclr + 1
      iclr = iclr % 8
      if iclr == 0 {
        iclr = 8
      }
      dislin.Setclr (iclr)
      for k := 0; k < 4; k++ {
        ixp[k] = ix[k] + int32 (nx)
        iyp[k] = iy[k] + int32 (ny)
      }

      dislin.Areaf (&ixp[0], &iyp[0], 4)
      nl = dislin.Nlnumb (float64 (ii), -1)
      nx = nx +  (300 - nl) / 2
      dislin.Color ("foreground")
      dislin.Number (float64 (ii), -1, nx, ny + 460) 
    }
  }

  dislin.Disfin ()
}
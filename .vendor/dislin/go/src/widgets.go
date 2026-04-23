package main

import "dislin"
import "fmt"

func main  () {
  cl1  := "Item1|Item2|Item3|Item4|Item5"
  cfil := " "

  dislin.Swgtit ("Widgets Example")
  ip :=   dislin.Wgini ("VERT")

  dislin.Wglab (ip, "File Widget:")
  id_fil :=   dislin.Wgfil (ip, "Open File", cfil, "*.c")

  dislin.Wglab (ip, "List Widget:")
  id_lis :=   dislin.Wglis (ip, cl1, 1)
  
  dislin.Wglab (ip, "Button Widgets:")
  id_but1 :=   dislin.Wgbut (ip, "This is Button 1", 0) 
  id_but2 :=   dislin.Wgbut (ip, "This is Button 2", 1)

  dislin.Wglab (ip, "Scale Widget:")
  id_scl :=   dislin.Wgscl (ip, " ", 0.0, 10.0, 5.0, 1) 
  dislin.Wgfin ()


  cfil2 :=   dislin.Gwgfil (id_fil)
  ilis :=   dislin.Gwglis (id_lis)
  ib1  :=   dislin.Gwgbut (id_but1)
  ib2  :=   dislin.Gwgbut (id_but2)
  xscl :=   dislin.Gwgscl (id_scl)

  fmt.Printf ("%s\n", cfil2)
  fmt.Printf ("%d\n", ilis)
  fmt.Printf ("%d %d\n", ib1, ib2)
  fmt.Printf ("%f\n", xscl)
}
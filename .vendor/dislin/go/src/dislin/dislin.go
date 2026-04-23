/****************************************************************/
/**                        dislin.go                           **/
/**                                                            **/
/** Dislin interface for Go.                                   **/
/**                                                            **/
/** Date     : 15.03.2024                                      **/
/** Version  : 11.5.2, Unix, 64-bit                            **/
/** Author   : Helmut Michels                                  **/
/****************************************************************/

package dislin

/*
#cgo LDFLAGS: -L/usr/local/dislin -ldislin_d
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dislin_d.h"

void   cb_swgcbk (int id);
void   cb_swgcb2 (int id, int irow, int icol);
void   cb_swgcb3 (int id, int ival);
double cb_surfun (double x, double y);
double cb_surfcp (double x, double y, int iopt);
void   cb_wincbk (int id, int nx, int ny, int nw, int nh);
void   cb_setcbk (double *x, double *y);
void   cb_piecbk (int iseg, double xdat, double xper, int *nrad,
                  int *noff, double *angle, int *nvx, int *nvy,
                  int *idrw, int *iann);
typedef void   (*callback_fcn)(int);
typedef void   (*callback_fcn2)(int, int, int);
typedef void   (*callback_fcn3)(int, int);
typedef double (*callback_fcn4)(double, double);
typedef double (*callback_fcn5)(double, double, int);
typedef void   (*callback_fcn6)(int, int, int, int, int);
typedef void   (*callback_fcn7)(double *, double *);
typedef void   (*callback_fcn8)(int, double, double, int *, int *,
                double *, int *, int *, int *, int *);
*/
import "C" 
import "unsafe"

var cb_funcs  = make (map[int] func (int))  // hash tables for callbacks
var cb_funcs2 = make (map[int] func (int, int, int))
var cb_funcs3 = make (map[int] func (int, int))
var cb_funcs4 = make (map[int] func (float64, float64) float64)
var cb_funcs5 = make (map[int] func (float64, float64, int) float64)
var cb_funcs6 = make (map[int] func (int, int, int, int, int))
var cb_funcs7 = make (map[int] func (*float64, *float64))
var cb_funcs8 = make (map[int] func (int, float64, float64, *int32, 
                                     *int32, *float64, *int32, *int32,
                                     *int32, *int32))

//export cb_swgcbk_go
func cb_swgcbk_go (id int32) {
   cb_funcs[int (id)] (int (id))
}

//export cb_swgcb2_go
func cb_swgcb2_go (id int32, irow int32, icol int32) {
   cb_funcs2[int (id)] (int (id), int (irow), int (icol))
}

//export cb_swgcb3_go
func cb_swgcb3_go (id int32, ival int32) {
   cb_funcs3[int (id)] (int (id), int (ival))
}

//export cb_surfun_go
func cb_surfun_go (x float64, y float64) float64 {
   var z float64 
   z = cb_funcs4[1](x, y)
   return z
}

//export cb_surfcp_go
func cb_surfcp_go (x float64, y float64, iopt int32) float64 {
   var z float64 
   z = cb_funcs5[1](x, y, int (iopt))
   return z
}

//export cb_wincbk_go
func cb_wincbk_go (iwin int32, nx int32, ny int32, nw int32, nh int32) {
   cb_funcs6[1] (int (iwin), int (nx), int (ny), int (nw), int (nh))
}

//export cb_setcbk_go
func cb_setcbk_go (x *float64, y *float64) {
   cb_funcs7[1] (x, y)
}

//export cb_piecbk_go
func cb_piecbk_go (iseg int32, xdat float64, xper float64, nrad *int32,
                   noff *int32, angle *float64, nvx *int32, nvy *int32,
                   idrw *int32, iann *int32) {
   cb_funcs8[1] (int (iseg), xdat, xper, nrad, noff, angle, nvx, nvy,
                 idrw, iann)
}

func Abs3pt (x1 float64, x2 float64, x3 float64, 
             x4 *float64, x5 *float64) {
   var v4, v5 C.double
   C.abs3pt (C.double (x1), C.double (x2), C.double (x3), &v4, &v5)
   *x4 = float64 (v4);
   *x5 = float64 (v5);
}

func Addlab (s1 string, x1 float64, i1 int, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.addlab (c1, C.double (x1), C.int (i1), c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Angle (i1 int) {
   C.angle (C.int (i1))
}

func Arcell (i1 int, i2 int, i3 int, i4 int, x1 float64, x2 float64, 
             x3 float64) {
   C.arcell (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.double (x1),
             C.double (x2), C.double (x3))
}

func Areaf (nxray *int32, nyray *int32, n int) {
    C.areaf ((*C.int) (nxray), (*C.int) (nyray), C.int (n))
}

func Autres (i1 int, i2 int) {
   C.autres (C.int (i1), C.int (i2))
}

func Autres3d (i1 int, i2 int, i3 int) {
   C.autres3d (C.int (i1), C.int (i2), C.int (i3))
}

func Ax2grf () {
   C.ax2grf ()
}

func Ax3len (i1 int, i2 int, i3 int) {
   C.ax3len (C.int (i1), C.int (i2), C.int (i3))
}

func Axclrs (i1 int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.axclrs (C.int (i1), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Axends (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.axends (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Axgit () {
   C.axgit ()
}

func Axis3d (x1 float64, x2 float64, x3 float64) {
   C.axis3d (C.double (x1), C.double (x2), C.double (x3))
}

func Axsbgd (i1 int) {
   C.axsbgd (C.int (i1))
}

func Axsers () {
   C.axsers ()
}

func Axslen (i1 int, i2 int) {
   C.axslen (C.int (i1), C.int (i2))
}

func Axspos (i1 int, i2 int) {
   C.axspos (C.int (i1), C.int (i2))
}

func Axsorg (i1 int, i2 int) {
   C.axsorg (C.int (i1), C.int (i2))
}

func Axsscl (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.axsscl (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Axstyp (s1 string) {
   c1:= C.CString (s1)
   C.axstyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Barbor (i1 int) {
   C.barbor (C.int (i1))
}

func Barclr (i1 int, i2 int, i3 int) {
   C.barclr (C.int (i1), C.int (i2), C.int (i3))
}

func Bargrp (i1 int, x1 float64) {
   C.bargrp (C.int (i1), C.double (x1))
}

func Barmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.barmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Baropt (x1 float64, x2 float64) {
   C.baropt (C.double (x1), C.double (x2))
}

func Barpos (s1 string) {
   c1:= C.CString (s1)
   C.barpos (c1)
   C.free (unsafe.Pointer (c1))
}

func Bars (xray *float64, y1ray *float64, y2ray *float64, n int) {
    C.bars ((*C.double) (xray), (*C.double) (y1ray), (*C.double) (y2ray), 
              C.int (n))
}

func Bars3d (xray *float64, yray *float64, z1ray *float64, z2ray *float64, 
             xwray *float64, ywray *float64, icray *int32, n int) {
    C.bars3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (z1ray), 
              (*C.double) (z2ray), (*C.double) (xwray), (*C.double) (ywray), 
              (*C.int) (icray), C.int (n))
}

func Bartyp (s1 string) {
   c1:= C.CString (s1)
   C.bartyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Barwth (x1 float64) {
   C.barwth (C.double (x1))
}

func Basalf (s1 string) {
   c1:= C.CString (s1)
   C.basalf (c1)
   C.free (unsafe.Pointer (c1))
}

func Basdat (i1 int, i2 int, i3 int) {
   C.basdat (C.int (i1), C.int (i2), C.int (i3))
} 

func Bezier (xray *float64, yray *float64, nray int, x *float64, y *float64, 
              n int) {
    C.bezier ((*C.double) (xray), (*C.double) (yray), C.int (nray),
              (*C.double) (x), (*C.double) (y), C.int (n))
}

func Bitsi4 (i1 int, i2 int, i3 int, i4 int, i5 int) int {
   return int (C.bitsi4 (C.int (i1), C.int (i2), C.int (i3), C.int (i4), 
                         C.int (i5)))
} 

func Bmpfnt (s1 string) {
   c1:= C.CString (s1)
   C.bmpfnt (c1)
   C.free (unsafe.Pointer (c1))
}

func Bmpmod (i1 int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.bmpmod (C.int (i1), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Box2d () {
   C.box2d ()
}

func Box3d () {
   C.box3d ()
}

func Bufmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.bufmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Center () {
   C.center ()
}

func Cgmbgd (x1 float64, x2 float64, x3 float64) {
   C.cgmbgd (C.double (x1), C.double (x2), C.double (x3))
}

func Cgmpic (s1 string) {
   c1:= C.CString (s1)
   C.cgmpic (c1)
   C.free (unsafe.Pointer (c1))
}

func Cgmver (i1 int) {
   C.cgmver (C.int (i1))
}

func Chaang (x1 float64) {
   C.chaang (C.double (x1))
}

func Chacod (s1 string) {
   c1:= C.CString (s1)
   C.chacod (c1)
   C.free (unsafe.Pointer (c1))
}

func Chaspc (x1 float64) {
   C.chaspc (C.double (x1))
}

func Chawth (x1 float64) {
   C.chawth (C.double (x1))
}

func Chnatt () {
   C.chnatt ()
}

func Chncrv (s1 string) {
   c1:= C.CString (s1)
   C.chncrv (c1)
   C.free (unsafe.Pointer (c1))
}

func Chndot () {
   C.chndot ()
}

func Chndsh () {
   C.chndsh ()
}

func Chnbar (s1 string) {
   c1:= C.CString (s1)
   C.chnbar (c1)
   C.free (unsafe.Pointer (c1))
}

func Chnpie (s1 string) {
   c1:= C.CString (s1)
   C.chnpie (c1)
   C.free (unsafe.Pointer (c1))
}

func Circ3p (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64, x7 *float64, x8 *float64, x9 *float64) {
   var v7, v8, v9 C.double
   C.circ3p (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), &v7, &v8, &v9)
   *x7 = float64 (v7)
   *x8 = float64 (v8)
   *x9 = float64 (v9)
}

func Circle (i1 int, i2 int, i3 int) {
   C.circle (C.int (i1), C.int (i2), C.int (i3))
}

func Circsp (i1 int) {
   C.circsp (C.int (i1))
}

func Clip3d (s1 string) {
   c1:= C.CString (s1)
   C.clip3d (c1)
   C.free (unsafe.Pointer (c1))
}

func Closfl (i1 int) int {
   return int (C.closfl (C.int (i1)))
}

func Clpbor (s1 string) {
   c1:= C.CString (s1)
   C.clpbor (c1)
   C.free (unsafe.Pointer (c1))
}

func Clpmod (s1 string) {
   c1:= C.CString (s1)
   C.clpmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Clpwin (i1 int, i2 int, i3 int, i4 int) {
   C.clpwin (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Clrcyc (i1 int, i2 int) {
   C.clrcyc (C.int (i1), C.int (i2))
}

func Clrmod (s1 string) {
   c1:= C.CString (s1)
   C.clrmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Clswin (i1 int) {
   C.clswin (C.int (i1))
}

func Color (s1 string) {
   c1:= C.CString (s1)
   C.color (c1)
   C.free (unsafe.Pointer (c1))
}

func Colran (i1 int, i2 int) {
   C.colran (C.int (i1), C.int (i2))
}

func Colray (xray *float64, iray *int32, n int) {
    C.colray ((*C.double) (xray), (*C.int) (iray), C.int (n))
}

func Complx () {
   C.complx ()
}

func Conclr (nxray *int32, n int) {
    C.conclr ((*C.int) (nxray), C.int (n))
}

func Concrv (xray *float64, yray *float64, n int, x1 float64) {
    C.concrv ((*C.double) (xray), (*C.double) (yray), C.int (n), C.double (x1))
}

func Cone3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, 
             x6 float64, i1 int, i2 int) {
   C.cone3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
             C.double (x5), C.double (x6), C.int (i1), C.int (i2))
}

func Confll (xray *float64, yray *float64, zray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int,
             zlev *float64, nlev int) {
    C.confll ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray),
              C.int (n), (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
              C.int (ntri), (*C.double) (zlev), C.int (nlev))
}

func Congap (x1 float64) {
   C.congap (C.double (x1))
}

func Conlab (s1 string) {
   c1:= C.CString (s1)
   C.conlab (c1)
   C.free (unsafe.Pointer (c1))
}

func Conmat (zmat *float64, n int, m int, x1 float64) {
    C.conmat ((*C.double) (zmat), C.int (n), C.int (m), C.double (x1))
}

func Conmod (x1 float64, x2 float64) {
   C.conmod (C.double (x1), C.double (x2))
}

func Conn3d (x1 float64, x2 float64, x3 float64) {
   C.conn3d (C.double (x1), C.double (x2), C.double (x3))
}

func Connpt (x1 float64, x2 float64) {
   C.connpt (C.double (x1), C.double (x2))
}

func Conpts (xray *float64, n int, yray *float64, m int, zmat *float64,
             zlev float64, xpts *float64, ypts *float64, maxpts int,
             nray *int32, maxray int) int {
    var nlins C.int
    C.conpts ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat), C.double (zlev), (*C.double) (xpts),
              (*C.double) (ypts), C.int (maxpts), (*C.int) (nray),
              C.int (maxray), &nlins)
    return int (nlins)
}

func Conshd (xray *float64, n int, yray *float64, m int, zmat *float64,
             zlev *float64, nlev int) {
    C.conshd ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat), (*C.double) (zlev), C.int (nlev))
}

func Conshd2 (xmat *float64, ymat *float64, zmat *float64, n int, m int,
              zlev *float64, nlev int) {
    C.conshd2 ((*C.double) (xmat), (*C.double) (ymat), (*C.double) (zmat), 
               C.int (n), C.int (m), (*C.double) (zlev), C.int (nlev))
}

func Conshd3d (xray *float64, n int, yray *float64, m int, zmat *float64,
             zlev *float64, nlev int) {
    C.conshd3d ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat), (*C.double) (zlev), C.int (nlev))
}

func Contri (xray *float64, yray *float64, zray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int, 
             zlev float64) {
    C.contri ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray),
              C.int (n), (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
              C.int (ntri), C.double (zlev))
}

func Contur (xray *float64, n int, yray *float64, m int, zmat *float64,
             x1 float64) {
    C.contur ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat), C.double (x1))
}

func Contur2 (xmat *float64, ymat *float64, zmat *float64, n int, m int,
              x1 float64) {
    C.contur2 ((*C.double) (xmat), (*C.double) (ymat), (*C.double) (zmat), 
               C.int (n), C.int (m), C.double (x1))
}

func Cross () {
   C.cross ()
}

func Crvmat (xmat *float64, i1 int, i2 int, i3 int, i4 int) {
    C.crvmat ((*C.double) (xmat), C.int (i1), C.int (i2), C.int (i3), 
              C.int (i4))
}

func Crvqdr (xray *float64, yray *float64, zray *float64, n int) {
    C.crvqdr ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
                C.int (n))
}

func Crvt3d (xray *float64, yray *float64, zray *float64, rray *float64,
             icray *int32, n int) {
    C.crvt3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
              (*C.double) (rray), (*C.int) (icray),  C.int (n))
}

func Crvtri (xray *float64, yray *float64, zray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int) {
    C.crvtri ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), C.int (n), 
              (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray), C.int (ntri))
}

func Csrkey () int {
   return int (C.csrkey ())
}

func Csrlin (i1 *int, i2 *int, i3 *int, i4 *int) {
   var n1, n2, n3, n4 C.int
   C.csrlin (&n1, &n2, &n3, &n4)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
   *i4 = int (n4)
}

func Csrmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.csrmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Csrpol (nxray *int32, nyray *int32, nmax int, n *int, iret *int) {
    var n1, n2 C.int
    C.csrpol ((*C.int) (nxray), (*C.int) (nyray), C.int (nmax), &n1, &n2)
   *n    = int (n1)
   *iret = int (n2)
}

func Csrpos (i1 *int, i2 *int) int {
   var n1, n2  C.int
   n1 = C.int (*i1)
   n2 = C.int (*i2)
   iret := int (C.csrpos (&n1, &n2))
   *i1 = int (n1)
   *i2 = int (n2)
   return iret
}

func Csrpt1 (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.csrpt1 (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Csrpts (nxray *int32, nyray *int32, nmax int, n *int, iret *int) {
    var n1, n2 C.int
    C.csrpts ((*C.int) (nxray), (*C.int) (nyray), C.int (nmax), &n1, &n2)
   *n    = int (n1)
   *iret = int (n2)
}

func Csrmov (nxray *int32, nyray *int32, nmax int, n *int, iret *int) {
    var n1, n2 C.int
    C.csrmov ((*C.int) (nxray), (*C.int) (nyray), C.int (nmax), &n1, &n2)
   *n    = int (n1)
   *iret = int (n2)
}

func Csrrec (i1 *int, i2 *int, i3 *int, i4 *int) {
   var n1, n2, n3, n4 C.int
   C.csrrec (&n1, &n2, &n3, &n4)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
   *i4 = int (n4)
}

func Csrtyp (s1 string) {
   c1:= C.CString (s1)
   C.csrtyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Csruni (s1 string) {
   c1:= C.CString (s1)
   C.csruni (c1)
   C.free (unsafe.Pointer (c1))
}

func Curv3d (xray *float64, yray *float64, zray *float64, n int) {
    C.curv3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
                C.int (n))
}

func Curv4d (xray *float64, yray *float64, zray *float64, wray *float64, 
              n int) {
    C.curv4d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
               (*C.double) (wray), C.int (n))
}

func Curve (xray *float64, yray *float64, n int) {
    C.curve ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Curve3 (xray *float64, yray *float64, zray *float64, n int) {
    C.curve3 ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
               C.int (n))
}

func Curvmp (xray *float64, yray *float64, n int) {
    C.curvmp ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Curvx3 (xray *float64, y float64, zray *float64, n int) {
    C.curvx3 ((*C.double) (xray), C.double (y), (*C.double) (zray), C.int (n))
}

func Curvy3 (x float64, yray *float64, zray *float64, n int) {
    C.curvy3 (C.double (x), (*C.double) (yray), (*C.double) (zray), C.int (n))
}

func Cyli3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, i1 int, i2 int) {
   C.cyli3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), C.double (x5),
             C.int (i1), C.int (i2))
}

func Dash () {
   C.dash ()
}

func Dashl () {
   C.dashl ()
}

func Dashm () {
   C.dashm ()
}

func Dbffin () {
   C.dbffin ()
}

func Dbfini () int {
   return int (C.dbfini ())
}

func Dbfmod (s1 string) {
   c1:= C.CString (s1)
   C.dbfmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Delglb () {
   C.delglb ()
}

func Digits (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.digits (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Disalf () {
   C.disalf ()
}

func Disenv (s1 string) {
   c1:= C.CString (s1)
   C.disenv (c1)
   C.free (unsafe.Pointer (c1))
}

func Disfin () {
   C.disfin ()
}

func Disini () {
   C.disini ()
}

func Disk3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, i1 int, i2 int) {
   C.disk3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), C.double (x5),
             C.int (i1), C.int (i2))
}

func Doevnt () {
   C.doevnt ()
}

func Dot () {
   C.dot ()
}

func Dotl () {
   C.dotl ()
}

func Duplx () {
   C.duplx ()
}

func Dwgbut (s1 string, i1 int) int {
   c1:= C.CString (s1)
   iret := int (C.dwgbut (c1, C.int (i1)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Dwgerr () int {
   return int (C.dwgerr ())
}

func Dwgfil (s1 string, s2 string, s3 string) string {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   p := C.dwgfil (c1, c2, c3)
   s := C.GoString (p)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Dwglis (s1 string, s2 string, i1 int) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   iret := int (C.dwglis (c1, c2, C.int (i1)))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return iret
}

func Dwgmsg (s1 string) {
   c1:= C.CString (s1)
   C.dwgmsg (c1)
   C.free (unsafe.Pointer (c1))
}

func Dwgtxt (s1 string, s2 string) string {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   p := C.dwgtxt (c1, c2)
   s := C.GoString (p)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Ellips (i1 int, i2 int, i3 int, i4 int) {
   C.ellips (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Endgrf () {
   C.endgrf ()
}

func Erase () {
   C.erase ()
}

func Errbar (xray *float64, yray *float64, err1 *float64, err2 *float64, 
              n int) {
    C.errbar ((*C.double) (xray), (*C.double) (yray), (*C.double) (err1), 
              (*C.double) (err2), C.int (n))
}

func Errdev (s1 string) {
   c1:= C.CString (s1)
   C.errdev (c1)
   C.free (unsafe.Pointer (c1))
}

func Errfil (s1 string) {
   c1:= C.CString (s1)
   C.errfil (c1)
   C.free (unsafe.Pointer (c1))
}

func Errmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.errmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Eushft (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.eushft (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Expimg (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.expimg (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Expzlb (s1 string) {
   c1:= C.CString (s1)
   C.expzlb (c1)
   C.free (unsafe.Pointer (c1))
}

func Fbars (xray *float64, y1ray *float64, y2ray *float64, y3ray *float64, 
            y4ray *float64, n int) {
    C.fbars ((*C.double) (xray), (*C.double) (y1ray), (*C.double) (y2ray), 
             (*C.double) (y3ray), (*C.double) (y4ray), C.int (n))
}

func Fcha (x1 float64, i1 int) string {
   c1 := C.malloc (81)
   C.fcha (C.double (x1), C.int (i1), (*C.char) (c1))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Field (xray *float64, yray *float64, uray *float64, vray *float64,
            n int, ivec int) {
    C.field ((*C.double) (xray), (*C.double) (yray), (*C.double) (uray), 
             (*C.double) (vray), C.int (n), C.int (ivec))
}

func Field3d (x1ray *float64, y1ray *float64, z1ray *float64,
              x2ray *float64, y2ray *float64, z2ray *float64,
              n int, ivec int) {
    C.field3d ((*C.double) (x1ray), (*C.double) (y1ray), (*C.double) (z1ray), 
               (*C.double) (x2ray), (*C.double) (y2ray), (*C.double) (z2ray),
                 C.int (n), C.int (ivec))
}

func Filbox (i1 int, i2 int, i3 int, i4 int) {
   C.filbox (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Filclr (s1 string) {
   c1:= C.CString (s1)
   C.filclr (c1)
   C.free (unsafe.Pointer (c1))
}

func Filmod (s1 string) {
   c1:= C.CString (s1)
   C.filmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Filopt (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.filopt (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Filsiz (s1 string, i1 *int, i2 *int) int {
   var n1, n2 C.int
   c1:= C.CString (s1)
   iret := int (C.filsiz (c1, &n1, &n2))
   C.free (unsafe.Pointer (c1))
   *i1 = int (n1)
   *i2 = int (n2)
   return iret
}

func Filtyp (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.filtyp (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Filwin (i1 int, i2 int, i3 int, i4 int) {
   C.filwin (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Fitscls () {
   C.fitscls ()
}

func Fitsflt (s1 string) float64 {
   c1:= C.CString (s1)
   xret := float64 (C.fitsflt (c1))
   C.free (unsafe.Pointer (c1))
   return xret
}

func Fitshdu (i1 int) int {
   return int (C.fitshdu (C.int (i1)))
}

func Fitsimg (iray *byte, i1 int) int {
   return int (C.fitsimg ((*C.uchar) (iray), C.int (i1)))
}

func Fitsopn (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.fitsopn (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Fitsstr (s1 string, i1 int) string {
   c1:= C.CString (s1)
   c2 := C.malloc (C.ulong (i1 + 1))
   C.fitsstr (c1, (*C.char) (c2), C.int (i1))
   s2 := C.GoString ((*C.char) (c2))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return s2
}

func Fitstyp (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.fitstyp (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Fitsval (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.fitsval (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Fixspc (x1 float64) {
   C.fixspc (C.double (x1))
}

func Flab3d () {
   C.flab3d ()
}

func Flen (x1 float64, i1 int) int {
   return int (C.flen (C.double (x1), C.int (i1)))
}

func Frame (i1 int) {
   C.frame (C.int (i1))
}

func freeptr (p  []C.char) {                     // only local function
   C.freeptr (unsafe.Pointer (&p[0]))
}

func Frmbar (i1 int) {
   C.frmbar (C.int (i1))
}

func Frmclr (i1 int) {
   C.frmclr (C.int (i1))
}

func Frmess (i1 int) {
   C.frmess (C.int (i1))
}

func Gapcrv (x1 float64) {
   C.gapcrv (C.double (x1))
}

func Gapsiz (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.gapsiz (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Gaxpar (x1 float64, x2 float64, s1 string, s2 string, x3 *float64,
             x4 *float64, x5 *float64, x6 *float64, i1 *int) {
   var v1, v2, v3, v4 C.double
   var n1 C.int
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.gaxpar (C.double (x1), C.double (x2), c1, c2, &v1, &v2, &v3, &v4, &n1)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   *x3 = float64 (v1)
   *x4 = float64 (v2)
   *x5 = float64 (v3)
   *x6 = float64 (v4)
   *i1 = int (n1)
}

func Getalf () string {
   p := C.getalf ()
   s := C.GoString (p)
   C.freeptr (unsafe.Pointer (p))
   return s
}

func Getang () int {
   return int (C.getang ())
}

func Getbpp () int {
   return int (C.getbpp ())
}

func Getclp (i1 *int, i2 *int, i3 *int, i4 *int) {
   var n1, n2, n3, n4 C.int
   C.getclp (&n1, &n2, &n3, &n4)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
   *i4 = int (n4)
}

func Getclr () int {
   return int (C.getclr ())
}

func Getdig (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getdig (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getdsp () string {
   p := C.getdsp ()
   s := C.GoString (p)
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getfil () string {
   p := C.getfil ()
   s := C.GoString (p)
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getgrf (x1 *float64, x2 *float64, x3 *float64, x4 *float64, s1 string) {
   var v1, v2, v3, v4 C.double
   c1:= C.CString (s1)
   C.getgrf (&v1, &v2, &v3, &v4, c1)
   C.free (unsafe.Pointer (c1))
   *x1 = float64 (v1)
   *x2 = float64 (v2)
   *x3 = float64 (v3)
   *x4 = float64 (v4)
}

func Gethgt () int {
   return int (C.gethgt ())
}

func Gethnm () int {
   return int (C.gethnm ())
}

func Getico (x1 float64, x2 float64, x3 *float64, x4 *float64) {
   var v3, v4 C.double
   C.getico (C.double (x1), C.double (x2), &v3, &v4)
   *x3 = float64 (v3);
   *x4 = float64 (v4);
}
 
func Getind (i1 int, x1 *float64, x2 *float64, x3 *float64) {
   var v1, v2, v3 C.double
   C.getind (C.int (i1), &v1, &v2, &v3)
   *x1 = float64 (v1);
   *x2 = float64 (v2);
   *x3 = float64 (v3);
}
 
func Getlab (iax int) string {
   var s string
   c1 := C.malloc (9)
   c2 := C.malloc (9)
   c3 := C.malloc (9)
   C.getlab ((*C.char) (c1), (*C.char) (c2), (*C.char) (c3))
   if iax == 1 {
     s = C.GoString ((*C.char) (c1))
   } else if iax == 2 {
     s = C.GoString ((*C.char) (c2))
   } else {
     s = C.GoString ((*C.char) (c3))
   }
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   return s
}

func Getlen (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getlen (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getlev () int {
   return int (C.getlev ())
}

func Getlin () int {
   return int (C.getlin ())
}

func Getlit (x1 float64, x2 float64, x3 float64, x4 float64,
             x5 float64, x6 float64) int {
   return int (C.getlit (C.double (x1), C.double (x2), C.double (x3),
               C.double (x4), C.double (x5), C.double (x6)))
}

func Getmat (xray *float64, yray *float64, zray *float64, n int,
             zmat *float64, nx int, ny int, zval float64, imat *int32,
             wmat *float64) {
    C.getmat ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray),
              C.int (n), (*C.double) (zmat), C.int (nx), C.int (ny),
              C.double (zval), (*C.int) (imat), (*C.double) (wmat))
}

func Getmfl () string {
   p := C.getmfl ()
   s := C.GoString (p)
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getmix (s1 string) string {
   c1:= C.CString (s1)
   p := C.getmix (c1)
   s := C.GoString (p)
   C.free (unsafe.Pointer (c1))
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getor (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getor (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getpag (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getpag (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getpat () int {
   return int (C.getpat ())
}

func Getplv () int {
   return int (C.getplv ())
}

func Getpos (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getpos (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getran (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getran (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getrco (x1 float64, x2 float64, x3 *float64, x4 *float64) {
   var v3, v4 C.double
   C.getrco (C.double (x1), C.double (x2), &v3, &v4)
   *x3 = float64 (v3);
   *x4 = float64 (v4);
}

func Getres (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getres (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getrgb (x1 *float64, x2 *float64, x3 *float64) {
   var v1, v2, v3 C.double
   C.getrgb (&v1, &v2, &v3)
   *x1 = float64 (v1)
   *x2 = float64 (v2)
   *x3 = float64 (v3)
}

func Getscl (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getscl (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getscm (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getscm (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getscr (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getscr (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Getshf (s1 string) string {
   c1:= C.CString (s1)
   p := C.getshf (c1)
   s := C.GoString (p)
   C.free (unsafe.Pointer (c1))
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getsp1 (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getsp1 (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getsp2 (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getsp2 (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getsym (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.getsym (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Gettcl (i1 *int, i2 *int) {
   var n1, n2 C.int
   C.gettcl (&n1, &n2)
   *i1 = int (n1)
   *i2 = int (n2)
}

func Gettic (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.gettic (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Gettyp () int {
   return int (C.gettyp ())
}

func Getver () float64 {
   return float64 (C.getver ())
}

func Getvk (i1 *int, i2 *int, i3 *int) {
   var n1, n2, n3 C.int
   C.getvk (&n1, &n2, &n3)
   *i1 = int (n1)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Getvlt () string {
   p := C.getvlt ()
   s := C.GoString (p)
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Getwid () int {
   return int (C.getwid ())
}

func Getwin (i1 *int, i2 *int, i3 *int, i4 *int) {
   var n1, n2, n3, n4 C.int
   C.getwin (&n1, &n2, &n3, &n4)
   *i1 =  int (n1)
   *i2 =  int (n2)
   *i3 =  int (n3)
   *i4 =  int (n4)
}

func Getxid (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.getxid (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Gifmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.gifmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Gmxalf (s1 string, s2 string, s3 string) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   iret := int (C.gmxalf (c1, c2, c3))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   return iret
}

func Gothic () {
   C.gothic ()
}

func Grace (i1 int) {
   C.grace (C.int (i1))
}

func Graf (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64, x7 float64, x8 float64) {
   C.graf (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.double (x7), C.double (x8))
}

func Graf3 (x1 float64, x2 float64, x3 float64, x4 float64,
            x5 float64, x6 float64, x7 float64, x8 float64,
            x9 float64, x10 float64, x11 float64, x12 float64) {
   C.graf3 (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.double (x7), C.double (x8),
           C.double (x9), C.double (x10), C.double (x11), C.double (x12))
}

func Graf3d (x1 float64, x2 float64, x3 float64, x4 float64,
             x5 float64, x6 float64, x7 float64, x8 float64,
             x9 float64, x10 float64, x11 float64, x12 float64) {
   C.graf3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
             C.double (x5), C.double (x6), C.double (x7), C.double (x8),
             C.double (x9), C.double (x10), C.double (x11), C.double (x12))
}

func Grafmp (x1 float64, x2 float64, x3 float64, x4 float64,
             x5 float64, x6 float64, x7 float64, x8 float64) {
   C.grafmp (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
             C.double (x5), C.double (x6), C.double (x7), C.double (x8))
}

func Grafp (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64) {
   C.grafp (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.double (x5))
}

func Grafr (zre *float64, nre int, zimg *float64, nimg int) {
    C.grafr ((*C.double) (zre), C.int (nre), (*C.double) (zimg), C.int (nimg))
}

func Grdpol (i1 int, i2 int) {
   C.grdpol (C.int (i1), C.int (i2))
}

func Grffin () {
   C.grffin ()
}

func Grfimg (s1 string) {
   c1:= C.CString (s1)
   C.grfimg (c1)
   C.free (unsafe.Pointer (c1))
}

func Grfini (x1 float64, x2 float64, x3 float64, x4 float64,
            x5 float64, x6 float64, x7 float64, x8 float64,
            x9 float64) {
   C.grfini (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.double (x7), C.double (x8),
           C.double (x9))

}

func Grid (i1 int, i2 int) {
   C.grid (C.int (i1), C.int (i2))
}

func Grid3d (i1 int, i2 int, s1 string) {
   c1:= C.CString (s1)
   C.grid3d (C.int (i1), C.int (i2), c1)
   C.free (unsafe.Pointer (c1))
}

func Gridim (x1 float64, x2 float64, x3 float64, i1 int) {
   C.gridim (C.double (x1), C.double (x2), C.double (x3), C.int (i1))
}

func Gridmp (i1 int, i2 int) {
   C.gridmp (C.int (i1), C.int (i2))
}

func Gridre (x1 float64, x2 float64, x3 float64, i1 int) {
   C.gridre (C.double (x1), C.double (x2), C.double (x3), C.int (i1))
}

func Gwgatt (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.gwgatt (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Gwgbox (i1 int) int {
   return int (C.gwgbox (C.int (i1)))
}

func Gwgbut (i1 int) int {
   return int (C.gwgbut (C.int (i1)))
}

func Gwgfil (i1 int) string {
   c1 := C.malloc (257)
   C.gwgfil (C.int (i1), (*C.char) (c1))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Gwgflt (i1 int) float64 {
   return float64 (C.gwgflt (C.int (i1)))
}

func Gwggui () int {
   return int (C.gwggui ())
}

func Gwgint (i1 int) int {
   return int (C.gwgint (C.int (i1)))
}

func Gwglis (i1 int) int {
   return int (C.gwglis (C.int (i1)))
}

func Gwgscl (i1 int) float64 {
   return float64 (C.gwgscl (C.int (i1)))
}

func Gwgsiz (i1 int, i2 *int, i3 *int) {
   var n2, n3 C.int
   C.gwgsiz (C.int (i1), &n2, &n3)
   *i2 = int (n2)
   *i3 = int (n3)
}

func Gwgtbf (i1 int, i2 int, i3 int) float64 {
   return float64 (C.gwgtbf (C.int (i1), C.int (i2), C.int (i3)))
}

func Gwgtbi (i1 int, i2 int, i3 int) int {
   return int (C.gwgtbi (C.int (i1), C.int (i2), C.int (i3)))
}

func Gwgtbl (i1 int, xray *float64, i2 int, i3 int, s1 string) {
   c1:= C.CString (s1)
   C.gwgtbl (C.int (i1), (*C.double) (xray), C.int (i2), C.int (i3), c1)
   C.free (unsafe.Pointer (c1))
}

func Gwgtbs (i1 int, i2 int, i3 int) string {
   c1 := C.malloc (81)
   C.gwgtbs (C.int (i1), C.int (i2), C.int (i3), (*C.char) (c1))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Gwgtxt (i1 int) string {
   c1 := C.malloc (257)
   C.gwgtxt (C.int (i1), (*C.char) (c1))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Gwgxid (i1 int) int {
   return int (C.gwgxid (C.int (i1)))
}

func Height (i1 int) {
   C.height (C.int (i1))
}

func Helve () {
   C.helve ()
}

func Helves () {
   C.helves ()
}

func Helvet () {
   C.helvet ()
}

func Hidwin (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.hidwin (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Histog (xray *float64, n int, x *float64, y *float64) int {
    var iret C.int
    C.histog ((*C.double) (xray), C.int (n), (*C.double) (x), 
              (*C.double) (y), &iret)
    return int (iret)
}

func Hname (i1 int) {
   C.hname (C.int (i1))
}

func Hpgmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.hpgmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Hsvrgb (x1 float64, x2 float64, x3 float64, 
             x4 *float64, x5 *float64, x6 *float64) {
   var v4, v5, v6 C.double
   C.hsvrgb (C.double (x1), C.double (x2), C.double (x3), &v4, &v5, &v6)
   *x4 = float64 (v4);
   *x5 = float64 (v5);
   *x6 = float64 (v6);
}

func Hsym3d (x1 float64) {
   C.hsym3d (C.double (x1))
}

func Hsymbl (i1 int) {
   C.hsymbl (C.int (i1))
}

func Htitle (i1 int) {
   C.htitle (C.int (i1))
}

func Hwfont () {
   C.hwfont ()
}

func Hwmode (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.hwmode (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Hworig (i1 int, i2 int) {
   C.hworig (C.int (i1), C.int (i2))
}

func Hwpage (i1 int, i2 int) {
   C.hwpage (C.int (i1), C.int (i2))
}

func Hwscal (x1 float64) {
   C.hwscal (C.double (x1))
}

func Imgbox (i1 int, i2 int, i3 int, i4 int) {
   C.imgbox (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Imgclp (i1 int, i2 int, i3 int, i4 int) {
   C.imgclp (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Imgfin () {
   C.imgfin ()
}

func Imgfmt (s1 string) {
   c1:= C.CString (s1)
   C.imgfmt (c1)
   C.free (unsafe.Pointer (c1))
}

func Imgini () {
   C.imgini ()
}

func Imgmod (s1 string) {
   c1:= C.CString (s1)
   C.imgmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Imgsiz (i1 int, i2 int) {
   C.imgsiz (C.int (i1), C.int (i2))
}

func Imgtpr (i1 int) {
   C.imgtpr (C.int (i1))
}

func Inccrv (i1 int) {
   C.inccrv (C.int (i1))
}

func Incdat (i1 int, i2 int, i3 int) int {
   return int (C.incdat (C.int (i1), C.int (i2), C.int (i3)))
}

func Incfil (s1 string) {
   c1:= C.CString (s1)
   C.incfil (c1)
   C.free (unsafe.Pointer (c1))
}

func Incmrk (i1 int) {
   C.incmrk (C.int (i1))
}

func Indrgb (x1 float64, x2 float64, x3 float64) int {
   return int (C.indrgb (C.double (x1), C.double (x2), C.double (x3)))
}

func Intax () {
   C.intax ()
}

func Intcha (i1 int) string {
   c1 := C.malloc (81)
   C.intcha (C.int (i1), (*C.char) (c1))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Intlen (i1 int) int {
   return int (C.intlen (C.int (i1)))
}

func Intrgb (x1 float64, x2 float64, x3 float64) int {
   return int (C.intrgb (C.double (x1), C.double (x2), C.double (x3)))
}

func Intutf (iray *int32, n int) string {
   c1 := C.malloc (C.ulong (4 * n + 1))
   C.intutf ((*C.int) (iray), C.int (n), (*C.char) (c1), C.int (4 * n))
   s1 := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s1
}

func Isopts (xray *float64, nx int, yray *float64, ny int,
             zray *float64, nz int, wmat *float64, zlev float64, 
             xtri *float64, ytri *float64, ztri *float64, nmax int) int {
    var ntri C.int
    C.isopts ((*C.double) (xray), C.int (nx), (*C.double) (yray), C.int (ny),
              (*C.double) (zray), C.int (nz), (*C.double) (wmat),
              C.double (zlev), (*C.double) (xtri), (*C.double) (ytri),
              (*C.double) (ztri), C.int (nmax), &ntri)
    return int (ntri)
}

func Itmcat (s1 string, s2 string) string {
   var n1, n2 C.int
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   n1 = C.trmlen (c1)
   n2 = C.trmlen (c2)
   p := C.malloc (C.ulong (n1 + n2 + 2))
   C.strcpy ((*C.char) (p), c1)
   C.itmcat ((*C.char) (p), c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   s := C.GoString ((*C.char) (p))
   C.free (unsafe.Pointer (p))
   return s
}

func Itmcnt (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.itmcnt (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Itmncat (s1 string, nmx int, s2 string) string {
   var n1, n2 C.int
   c1:= C.CString (s1)
   n1 = C.trmlen (c1)
   c2:= C.CString (s2)
   n2 = C.trmlen (c2)
   p := C.malloc (C.ulong (n1 + n2 + 2))
   C.strcpy ((*C.char) (p), c1)
   C.itmncat ((*C.char) (p), C.int (nmx), c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   s := C.GoString ((*C.char) (p))
   C.free (unsafe.Pointer (p))
   return s
}

func Itmstr (s1 string, i1 int) string {
   c1:= C.CString (s1)
   p := C.itmstr (c1, C.int (i1))
   s := C.GoString (p)
   C.free (unsafe.Pointer (c1))
   C.freeptr (unsafe.Pointer (p))  
   return s
}

func Jusbar (s1 string) {
   c1:= C.CString (s1)
   C.jusbar (c1)
   C.free (unsafe.Pointer (c1))
}

func Labclr (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.labclr (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Labdig (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.labdig (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Labdis (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.labdis (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Labels (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.labels (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Labjus (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.labjus (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Labl3d (s1 string) {
   c1:= C.CString (s1)
   C.labl3d (c1)
   C.free (unsafe.Pointer (c1))
}

func Labmod (s1 string, s2 string, s3 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   C.labmod (c1, c2, c3)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
}

func Labpos (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.labpos (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Labtyp (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.labtyp (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Ldimg (s1 string, iray *uint16, nmax int, nc int) int {
   c1:= C.CString (s1)
   return int (C.ldimg (c1, (*C.ushort) (iray), C.int (nmax), C.int (nc)))
}

func Legbgd (i1 int) {
   C.legbgd (C.int (i1))
}

func Legclr () {
   C.legclr ()
}

func Legend (cbuf *int8, i1 int) {
   C.legend ((*C.char) (cbuf), C.int (i1))
}

func Legini (cbuf *int8, i1 int, i2 int) {
   C.legini ((*C.char) (cbuf), C.int (i1), C.int (i2))
}

func Leglin (cbuf *int8, s1 string, i1 int) {
   c1:= C.CString (s1)
   C.leglin ((*C.char) (cbuf), c1, C.int (i1))
   C.free (unsafe.Pointer (c1))
}

func Legopt (x1 float64, x2 float64, x3 float64) {
   C.legopt (C.double (x1), C.double (x2), C.double (x3))
}

func Legpat (i1 int, i2 int, i3 int, i4 int, i5 int, i6 int) {
   C.legpat (C.int (i1), C.int (i2), C.int (i3), 
             C.int (i4), C.long (i5), C.int (i6))
}

func Legpos (i1 int, i2 int) {
   C.legpos (C.int (i1), C.int (i2))
}

func Legsel (nxray *int32, n int) {
    C.legsel ((*C.int) (nxray), C.int (n))
}

func Legtbl (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.legtbl (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Legtit (s1 string) {
   c1:= C.CString (s1)
   C.legtit (c1)
   C.free (unsafe.Pointer (c1))
}

func Legtyp (s1 string) {
   c1:= C.CString (s1)
   C.legtyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Legval (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.legval (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Lfttit () {
   C.lfttit ()
}

func Licmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.licmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Licpts (xv *float64, yv *float64, nx int, ny int,
             itmat *int32, iwmat *int32, wmat *float64) {
    C.licpts ((*C.double) (xv), (*C.double) (yv), C.int (nx), C.int (ny),
              (*C.int) (itmat), (*C.int) (iwmat), (*C.double) (wmat))
}

func Light (s1 string) {
   c1:= C.CString (s1)
   C.light (c1)
   C.free (unsafe.Pointer (c1))
}

func Linclr (nxray *int32, n int) {
    C.linclr ((*C.int) (nxray), C.int (n))
}

func Lincyc (i1 int, i2 int) {
   C.lincyc (C.int (i1), C.int (i2))
}

func Line (i1 int, i2 int, i3 int, i4 int) {
   C.line (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Linesp (x1 float64) {
   C.linesp (C.double (x1))
}

func Linfit (xray *float64, yray *float64, n int,
             x1 *float64, x2 *float64, x3 *float64, s1 string) {
    var v1, v2, v3 C.double
    c1:= C.CString (s1)
    C.linfit ((*C.double) (xray), (*C.double) (yray), C.int (n),
              &v1, &v2, &v3, c1)
   C.free (unsafe.Pointer (c1))
   *x1 = float64 (v1)
   *x2 = float64 (v2)
   *x3 = float64 (v3)
}

func Linmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.linmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Lintyp (i1 int) {
   C.lintyp (C.int (i1))
}

func Linwid (i1 int) {
   C.linwid (C.int (i1))
}

func Litmod (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.litmod (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Litop3 (i1 int, x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.litop3 (C.int (i1), C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func Litopt (i1 int, x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.litopt (C.int (i1), C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Litpos (i1 int, x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.litpos (C.int (i1), C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func Lncap (s1 string) {
   c1:= C.CString (s1)
   C.lncap (c1)
   C.free (unsafe.Pointer (c1))
}

func Lnjoin (s1 string) {
   c1:= C.CString (s1)
   C.lnjoin (c1)
   C.free (unsafe.Pointer (c1))
}

func Lnmlt (x1 float64) {
   C.lnmlt (C.double (x1))
}

func Logtic (s1 string) {
   c1:= C.CString (s1)
   C.logtic (c1)
   C.free (unsafe.Pointer (c1))
}

func Mapbas (s1 string) {
   c1:= C.CString (s1)
   C.mapbas (c1)
   C.free (unsafe.Pointer (c1))
}

func Mapfil (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.mapfil (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Mapimg (s1 string, x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64) {
   c1:= C.CString (s1)
   C.mapimg (c1, C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6))
   C.free (unsafe.Pointer (c1))
}

func Maplab (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.maplab (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Maplev (s1 string) {
   c1:= C.CString (s1)
   C.maplev (c1)
   C.free (unsafe.Pointer (c1))
}

func Mapmod (s1 string) {
   c1:= C.CString (s1)
   C.mapmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Mappol (x1 float64, x2 float64) {
   C.mappol (C.double (x1), C.double (x2))
}

func Mapopt (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.mapopt (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Mapref (x1 float64, x2 float64) {
   C.mapref (C.double (x1), C.double (x2))
}

func Mapsph (x1 float64) {
   C.mapsph (C.double (x1))
}

func Marker (i1 int) {
   C.marker (C.int (i1))
}

func Matop3 (x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.matop3 (C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func Matopt (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.matopt (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Mdfmat (i1 int, i2 int, x1 float64) {
   C.mdfmat (C.int (i1), C.int (i2), C.double (x1))
}

func Messag (s1 string, i1 int, i2 int) {
   c1:= C.CString (s1)
   C.messag (c1, C.int (i1), C.int (i2))
   C.free (unsafe.Pointer (c1))
}

func Metafl (s1 string) {
   c1:= C.CString (s1)
   C.metafl (c1)
   C.free (unsafe.Pointer (c1))
}

func Mixalf () {
   C.mixalf ()
}

func Mixleg () {
   C.mixleg ()
}

func Mpaepl (i1 int) {
   C.mpaepl (C.int (i1))
}

func Mplang (x1 float64) {
   C.mplang (C.double (x1))
}

func Mplclr (i1 int, i2 int) {
   C.mplclr (C.int (i1), C.int (i2))
}

func Mplpos (i1 int, i2 int) {
   C.mplpos (C.int (i1), C.int (i2))
}

func Mplsiz (i1 int) {
   C.mplsiz (C.int (i1))
}

func Mpslogo (i1 int, i2 int, i3 int, s1 string) {
   c1:= C.CString (s1)
   C.mpslogo (C.int (i1), C.int (i2), C.int (i3), c1)
   C.free (unsafe.Pointer (c1))
}

func Mrkclr (i1 int) {
   C.mrkclr (C.int (i1))
}

func Msgbox (s1 string) {
   c1:= C.CString (s1)
   C.msgbox (c1)
   C.free (unsafe.Pointer (c1))
}

func Mshclr (i1 int) {
   C.mshclr (C.int (i1))
}

func Mshcrv (i1 int) {
   C.mshcrv (C.int (i1))
}

func Mylab (s1 string, i1 int, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.mylab (c1, C.int (i1), c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Myline (nxray *int32, n int) {
    C.myline ((*C.int) (nxray), C.int (n))
}

func Mypat (i1 int, i2 int, i3 int, i4 int) {
   C.mypat (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}


func Mysymb (xray *float64, yray *float64, n int, i1 int, i2 int) {
    C.mysymb ((*C.double) (xray), (*C.double) (yray), C.int (n), C.int (i1),
                C.int (i2))
}

func myvlt (xray *float64, yray *float64, zray *float64, n int) {
    C.myvlt ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
               C.int (n))
}

func Namdis (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.namdis (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Name (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.name (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Namjus (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.namjus (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Nancrv (s1 string) {
   c1:= C.CString (s1)
   C.nancrv (c1)
   C.free (unsafe.Pointer (c1))
}

func Neglog (x1 float64) {
   C.neglog (C.double (x1))
}

func Newmix () {
   C.newmix ()
}

func Newpag () {
   C.newpag ()
}

func Nlmess (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.nlmess (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Nlnumb (x1 float64, i1 int) int {
   return int (C.nlnumb (C.double (x1), C.int (i1)))
}

func Noarln () {
   C.noarln ()
}

func Nobar () {
   C.nobar ()
}

func Nobgd () {
   C.nobgd ()
}

func Nochek () {
   C.nochek ()
}

func Noclip () {
   C.noclip ()
}

func Nofill () {
   C.nofill ()
}

func Nograf () {
   C.nograf ()
}

func Nohide () {
   C.nohide ()
}

func Noline (s1 string) {
   c1:= C.CString (s1)
   C.noline (c1)
   C.free (unsafe.Pointer (c1))
}

func Number (x1 float64, i1 int, i2 int, i3 int) {
   C.number (C.double (x1), C.int (i1), C.int (i2), C.int (i3))
}

func Numfmt (s1 string) {
   c1:= C.CString (s1)
   C.numfmt (c1)
   C.free (unsafe.Pointer (c1))
}

func Numode (s1 string, s2 string, s3 string, s4 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   c4:= C.CString (s4)
   C.numode (c1, c2, c3, c4)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   C.free (unsafe.Pointer (c4))
}

func Nwkday (i1 int, i2 int, i3 int) int {
   return int (C.nwkday (C.int (i1), C.int (i2), C.int (i3)))
}

func Nxlegn (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.nxlegn (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Nxpixl (i1 int, i2 int) int {
   return int (C.nxpixl (C.int (i1), C.int (i2)))
}

func Nxposn (x1 float64) int {
   return int (C.nxposn (C.double (x1)))
}

func Nylegn (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.nylegn (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Nypixl (i1 int, i2 int) int {
   return int (C.nypixl (C.int (i1), C.int (i2)))
}

func Nyposn (x1 float64) int {
   return int (C.nyposn (C.double (x1)))
}

func Nzposn (x1 float64) int {
   return int (C.nzposn (C.double (x1)))
}

func Openfl (s1 string, i1 int, i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.openfl (c1, C.int (i1), C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Opnwin (i1 int) {
   C.opnwin (C.int (i1))
}

func Origin (i1 int, i2 int) {
   C.origin (C.int (i1), C.int (i2))
}

func Page (i1 int, i2 int) {
   C.page (C.int (i1), C.int (i2))
}

func Pagera () {
   C.pagera ()
}

func Pagfll (i1 int) {
   C.pagfll (C.int (i1))
}

func Paghdr (s1 string, s2 string, i1 int, i2 int) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.paghdr (c1, c2, C.int (i1), C.int (i2))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Pagmod (s1 string) {
   c1:= C.CString (s1)
   C.pagmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Pagorg (s1 string) {
   c1:= C.CString (s1)
   C.pagorg (c1)
   C.free (unsafe.Pointer (c1))
}

func Pagwin (i1 int, i2 int) {
   C.pagwin (C.int (i1), C.int (i2))
}

func Patcyc (i1 int, i2 int) {
   C.patcyc (C.int (i1), C.long (i2))
}

func Pdfbuf (cbuf *int8, i1 int) int {
   return int (C.pdfbuf ((*C.char) (cbuf), C.int (i1)))
}

func Pdfmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.pdfmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Pdfmrk (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.pdfmrk (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Penwid (x1 float64) {
   C.penwid (C.double (x1))
}

func Pie (i1 int, i2 int, i3 int, x1 float64, x2 float64) {
   C.pie (C.int (i1), C.int (i2), C.int (i3), C.double (x1), C.double (x2))
}

func Piebor (i1 int) {
   C.piebor (C.int (i1))
}

func Piecbk (cb func(int, float64, float64, *int32, *int32, *float64,
             *int32, *int32, *int32, *int32)) {
   cb_funcs8[1] = cb
   C.piecbk ((C.callback_fcn8) (unsafe.Pointer (C.cb_piecbk)))
} 

func Pieclr (nxray *int32, nyray *int32, n int) {
    C.pieclr ((*C.int) (nxray), (*C.int) (nyray), C.int (n))
}

func Pieexp () {
   C.pieexp ()
}

func Piegrf (cbuf *int8, nlin int, xray *float64, nseg int) {
   C.piegrf ((*C.char) (cbuf), C.int (nlin), (*C.double) (xray), C.int (nseg))
}

func Pielab (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.pielab (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Pieopt (x1 float64, x2 float64) {
   C.pieopt (C.double (x1), C.double (x2))
}

func Pierot (x1 float64) {
   C.pierot (C.double (x1))
}

func Pietyp (s1 string) {
   c1:= C.CString (s1)
   C.pietyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Pieval (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.pieval (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Pievec (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.pievec (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Pike3d (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64, x7 float64, i1 int, i2 int) {
   C.pike3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.double (x7), C.int (i1), C.int (i2))
}

func Plat3d (x1 float64, x2 float64, x3 float64, x4 float64, s1 string) {
   c1:= C.CString (s1)
   C.plat3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), c1)
   C.free (unsafe.Pointer (c1))
}

func Plyfin (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.plyfin (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Plyini (s1 string) {
   c1:= C.CString (s1)
   C.plyini (c1)
   C.free (unsafe.Pointer (c1))
}

func Pngmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.pngmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Point (i1 int, i2 int, i3 int, i4 int, i5 int) {
   C.point (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.int (i5))
}

func Polar (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64) {
   C.polar (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.double (x5))
}

func Polcrv (s1 string) {
   c1:= C.CString (s1)
   C.polcrv (c1)
   C.free (unsafe.Pointer (c1))
}

func Polclp (xray *float64, yray *float64, n int,
             xout *float64, yout *float64, nmax int,
             xv float64, s1 string) int {
   c1:= C.CString (s1)
   iret := C.polclp ((*C.double) (xray), (*C.double) (yray), C.int (n),
                     (*C.double) (xout), (*C.double) (yout), C.int (nmax),
                     C.double (xv), c1)
   C.free (unsafe.Pointer (c1))
   return int (iret)
}

func Polmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.polmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Pos2pt (x1 float64, x2 float64, x3 *float64, x4 *float64) {
   var v3, v4 C.double
   C.pos2pt (C.double (x1), C.double (x2), &v3, &v4)
   *x3 = float64 (v3);
   *x4 = float64 (v4);
}

func Pos3pt (x1 float64, x2 float64, x3 float64, 
             x4 *float64, x5 *float64, x6 *float64) {
   var v4, v5, v6 C.double
   C.pos3pt (C.double (x1), C.double (x2), C.double (x3), &v4, &v5, &v6)
   *x4 = float64 (v4);
   *x5 = float64 (v5);
   *x6 = float64 (v6);
}

func Posbar (s1 string) {
   c1:= C.CString (s1)
   C.posbar (c1)
   C.free (unsafe.Pointer (c1))
}

func Posifl (i1 int, i2 int) int {
   return int (C.posifl (C.int (i1), C.int (i2)))
}

func Proj3d (s1 string) {
   c1:= C.CString (s1)
   C.proj3d (c1)
   C.free (unsafe.Pointer (c1))
}

func Projct (s1 string) {
   c1:= C.CString (s1)
   C.projct (c1)
   C.free (unsafe.Pointer (c1))
}

func Psfont (s1 string) {
   c1:= C.CString (s1)
   C.psfont (c1)
   C.free (unsafe.Pointer (c1))
}

func Psmeta (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.psmeta (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Psmode (s1 string) {
   c1:= C.CString (s1)
   C.psmode (c1)
   C.free (unsafe.Pointer (c1))
}

func Pt2pos (x1 float64, x2 float64, x3 *float64, x4 *float64) {
   var v3, v4 C.double
   C.pt2pos (C.double (x1), C.double (x2), &v3, &v4)
   *x3 = float64 (v3);
   *x4 = float64 (v4);
}

func Pyra3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, 
             x6 float64, i1 int) {
   C.pyra3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
             C.double (x5), C.double (x6), C.int (i1))
}

func Qplbar (xray *float64, n int) {
    C.qplbar ((*C.double) (xray), C.int (n))
}

func Qplclr (xmat *float64, i1 int, i2 int) {
    C.qplclr ((*C.double) (xmat), C.int (i1), C.int (i2))
}

func Qplcon (xmat *float64, i1 int, i2 int, i3 int) {
    C.qplcon ((*C.double) (xmat), C.int (i1), C.int (i2), C.int (i3))
}

func Qplcrv (xray *float64, yray *float64, n int, s1 string) {
   c1:= C.CString (s1)
   C.qplcrv ((*C.double) (xray), (*C.double) (yray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Qplot (xray *float64, yray *float64, n int) {
    C.qplot ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Qplpie (xray *float64, n int) {
    C.qplpie ((*C.double) (xray), C.int (n))
}

func Qplsca (xray *float64, yray *float64, n int) {
    C.qplsca ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Qplscl (x1 float64, x2 float64, x3 float64, x4 float64, s1 string) {
   c1:= C.CString (s1)
   C.qplscl (C.double (x1), C.double (x2), C.double (x3), C.double (x4), c1)
   C.free (unsafe.Pointer (c1))
}

func Qplsur (xmat *float64, i1 int, i2 int) {
    C.qplsur ((*C.double) (xmat), C.int (i1), C.int (i2))
}

func Quad3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, 
             x6 float64) {
   C.quad3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
             C.double (x5), C.double (x6))
}

func Rbfpng (cbuf *int8, i1 int) int {
   return int (C.rbfpng ((*C.char) (cbuf), C.int (i1)))
}

func Rbmp (s1 string) {
   c1:= C.CString (s1)
   C.rbmp (c1)
   C.free (unsafe.Pointer (c1))
}

func Readfl (i1 int, iray *byte, i2 int) int {
   return int (C.readfl (C.int (i1), (*C.uchar) (iray), C.int (i2)))
}

func Reawgt () {
   C.reawgt ()
}

func Recfll (i1 int, i2 int, i3 int, i4 int, i5 int) {
   C.recfll (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.int (i5))
}

func Rectan (i1 int, i2 int, i3 int, i4 int) {
   C.rectan (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Rel3pt (x1 float64, x2 float64, x3 float64, 
             x4 *float64, x5 *float64) {
   var v4, v5 C.double
   C.rel3pt (C.double (x1), C.double (x2), C.double (x3), &v4, &v5)
   *x4 = float64 (v4);
   *x5 = float64 (v5);
}

func Resatt () {
   C.resatt ()
}

func Reset (s1 string) {
   c1:= C.CString (s1)
   C.reset (c1)
   C.free (unsafe.Pointer (c1))
}

func Revscr () {
   C.revscr ()
}

func Rgbhsv (x1 float64, x2 float64, x3 float64, 
             x4 *float64, x5 *float64, x6 *float64) {
   var v4, v5, v6 C.double
   C.rgbhsv (C.double (x1), C.double (x2), C.double (x3), &v4, &v5, &v6)
   *x4 = float64 (v4);
   *x5 = float64 (v5);
   *x6 = float64 (v6);
}

func Rgif (s1 string) {
   c1:= C.CString (s1)
   C.rgif (c1)
   C.free (unsafe.Pointer (c1))
}

func Rgtlab () {
   C.rgtlab ()
}

func Rimage (s1 string) {
   c1:= C.CString (s1)
   C.rimage (c1)
   C.free (unsafe.Pointer (c1))
}

func Rlarc (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64, x7 float64) {
   C.rlarc (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.double (x7))
}

func Rlarea (xray *float64, yray *float64, n int) {
    C.rlarea ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Rlcirc (x1 float64, x2 float64, x3 float64) {
   C.rlcirc (C.double (x1), C.double (x2), C.double (x3))
}

func Rlconn (x1 float64, x2 float64) {
   C.rlconn (C.double (x1), C.double (x2))
}

func Rlell (x1 float64, x2 float64, x3 float64, x4 float64) {
   C.rlell (C.double (x1), C.double (x2), C.double (x3), C.double (x4))
}

func Rline (x1 float64, x2 float64, x3 float64, x4 float64) {
   C.rline (C.double (x1), C.double (x2), C.double (x3), C.double (x4))
}

func Rlmess (s1 string, x1 float64, x2 float64) {
   c1:= C.CString (s1)
   C.rlmess (c1, C.double (x1), C.double (x2))
   C.free (unsafe.Pointer (c1))
}

func Rlnumb (x1 float64, i1 int, x2 float64, x3 float64) {
   C.rlnumb (C.double (x1), C.int (i1), C.double (x2), C.double (x3))
}

func Rlpie (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64) {
   C.rlpie (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.double (x5))
}

func Rlpoin (x1 float64, x2 float64, i1 int, i2 int, i3 int) {
   C.rlpoin (C.double (x1), C.double (x2), C.int (i1), C.int (i2),
             C.int (i3))
}

func Rlrec (x1 float64, x2 float64, x3 float64, x4 float64) {
   C.rlrec (C.double (x1), C.double (x2), C.double (x3), C.double (x4))
}

func Rlrnd (x1 float64, x2 float64, x3 float64, x4 float64, i1 int) {
   C.rlrnd (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1))
}

func Rlsec (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64,
            x6 float64, i1 int) {
   C.rlsec (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
            C.double (x5), C.double (x6), C.int (i1))
}

func Rlstrt (x1 float64, x2 float64) {
   C.rlstrt (C.double (x1), C.double (x2))
}

func Rlsymb (i1 int, x1 float64, x2 float64) {
   C.rlsymb (C.int (i1), C.double (x1), C.double (x2))
}

func Rlvec (x1 float64, x2 float64, x3 float64, x4 float64, i1 int) {
   C.rlvec (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
            C.int (i1))
}

func Rlwind (x1 float64, x2 float64, x3 float64, i1 int, x4 float64) {
   C.rlwind (C.double (x1), C.double (x2), C.double (x3), C.int (i1),
             C.double (x4)) 
}

func Rndrec (i1 int, i2 int, i3 int, i4 int, i5 int) {
   C.rndrec (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.int (i5))
}

func Rot3d (x1 float64, x2 float64, x3 float64) {
   C.rot3d (C.double (x1), C.double (x2), C.double (x3))
}

func Rpixel (i1 int, i2 int) int {
   var iret C.int
   C.rpixel (C.int (i1), C.int (i2), &iret)
   return int (iret)
}
 
func Rpixls (iray *byte, i1 int, i2 int, i3 int, i4 int) {
   C.rpixls ((*C.uchar) (iray), C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Rpng (s1 string) {
   c1:= C.CString (s1)
   C.rpng (c1)
   C.free (unsafe.Pointer (c1))
}

func Rppm (s1 string) {
   c1:= C.CString (s1)
   C.rppm (c1)
   C.free (unsafe.Pointer (c1))
}

func Rpxrow (iray *byte, i1 int, i2 int, i3 int) {
   C.rpxrow ((*C.uchar) (iray), C.int (i1), C.int (i2), C.int (i3))
}

func Rtiff (s1 string) {
   c1:= C.CString (s1)
   C.rtiff (c1)
   C.free (unsafe.Pointer (c1))
}

func Rvynam () {
   C.rvynam ()
}

func Scale (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.scale (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Sclfac (x1 float64) {
   C.sclfac (C.double (x1))
}

func Sclmod (s1 string) {
   c1:= C.CString (s1)
   C.sclmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Scrmod (s1 string) {
   c1:= C.CString (s1)
   C.scrmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Sector (i1 int, i2 int, i3 int, i4 int, x1 float64, x2 float64, i5 int) {
   C.sector (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.double (x1), 
             C.double (x2), C.int (i5))
}

func Selwin (i1 int) {
   C.selwin (C.int (i1))
}

func Sendbf () {
   C.sendbf ()
}

func Sendmb () {
   C.sendmb ()
}

func Sendok () {
   C.sendok ()
}

func Serif () {
   C.serif ()
}

func Setbas (x1 float64) {
   C.setbas (C.double (x1))
}

func Setcbk (cb func(*float64, *float64), s1 string) {
   cb_funcs7[1] = cb
   c1:= C.CString (s1)
   C.setcbk ((C.callback_fcn7) (unsafe.Pointer (C.cb_setcbk)), c1)
   C.free (unsafe.Pointer (c1))
} 

func Setclr (i1 int) {
   C.setclr (C.int (i1))
}

func Setcsr (s1 string) {
   c1:= C.CString (s1)
   C.setcsr (c1)
   C.free (unsafe.Pointer (c1))
}

func Setexp (x1 float64) {
   C.setexp (C.double (x1))
}

func Setfce (s1 string) {
   c1:= C.CString (s1)
   C.setfce (c1)
   C.free (unsafe.Pointer (c1))
}

func Setfil (s1 string) {
   c1:= C.CString (s1)
   C.setfil (c1)
   C.free (unsafe.Pointer (c1))
}

func Setgrf (s1 string, s2 string, s3 string, s4 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   c4:= C.CString (s4)
   C.setgrf (c1, c2, c3, c4)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   C.free (unsafe.Pointer (c4))
}

func Setind (i1 int, x1 float64, x2 float64, x3 float64) {
   C.setind (C.int (i1), C.double (x1), C.double (x2), C.double (x3))
}

func Setmix (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.setmix (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Setpag (s1 string) {
   c1:= C.CString (s1)
   C.setpag (c1)
   C.free (unsafe.Pointer (c1))
}

func Setres (i1 int, i2 int) {
   C.setres (C.int (i1), C.int (i2))
}

func Setres3d (x1 float64, x2 float64, x3 float64) {
   C.setres3d (C.double (x1), C.double (x2), C.double (x3))
}

func Setrgb (x1 float64, x2 float64, x3 float64) {
   C.setrgb (C.double (x1), C.double (x2), C.double (x3))
}

func Setscl (xray *float64, n int, s1 string) {
   c1:= C.CString (s1)
   C.setscl ((*C.double) (xray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Setvlt (s1 string) {
   c1:= C.CString (s1)
   C.setvlt (c1)
   C.free (unsafe.Pointer (c1))
}

func Setxid (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.setxid (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Shdafr (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdafr ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shdasi (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdasi ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shdaus (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdaus ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shdcha () {
   C.shdcha ()
}

func Shdcrv (x1ray *float64, y1ray *float64, n1 int, 
             x2ray *float64, y2ray *float64, n2 int) {
    C.shdcrv ((*C.double) (x1ray), (*C.double) (y1ray), C.int (n1),
              (*C.double) (x2ray), (*C.double) (y2ray), C.int (n2))
}

func Shdeur (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdeur ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shdfac (x1 float64) {
   C.shdfac (C.double (x1))
}

func Shdmap (s1 string) {
   c1:= C.CString (s1)
   C.shdmap (c1)
   C.free (unsafe.Pointer (c1))
}

func Shdmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.shdmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Shdnor (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdnor ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)),
             (*C.int) (icray), C.int (n))
}

func Shdpat (i1 int) {
   C.shdpat (C.long (i1))
}

func Shdsou (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdsou ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shdusa (inray *int32, ipray *int32, icray *int32, n int) {
   C.shdusa ((*C.int) (inray), (*C.long) (unsafe.Pointer (ipray)), 
             (*C.int) (icray), C.int (n))
}

func Shield (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.shield (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Shlcir (i1 int, i2 int, i3 int) {
   C.shlcir (C.int (i1), C.int (i2), C.int (i3))
}

func Shldel (i1 int) {
   C.shldel (C.int (i1))
}

func Shlell (i1 int, i2 int, i3 int, i4 int, x1 float64) {
   C.shlell (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.double (x1))
}

func Shlind () int {
   return int (C.shlind ())
}

func Shlpie (i1 int, i2 int, i3 int, x1 float64, x2 float64) {
   C.shlpie (C.int (i1), C.int (i2), C.int (i3), C.double (x1), C.double (x2))
}

func Shlpol (nxray *int32, nyray *int32, n int) {
    C.shlpol ((*C.int) (nxray), (*C.int) (nyray), C.int (n))
}

func Shlrct (i1 int, i2 int, i3 int, i4 int, x1 float64) {
   C.shlrct (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.double (x1))
}

func Shlrec (i1 int, i2 int, i3 int, i4 int) {
   C.shlrec (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Shlres (i1 int) {
   C.shlres (C.int (i1))
}

func Shlsur () {
   C.shlsur ()
}

func Shlvis (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.shlvis (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Simplx () {
   C.simplx ()
}

func Skipfl (i1 int, i2 int) int {
   return int (C.skipfl (C.int (i1), C.int (i2)))
}

func Smxalf (s1 string, s2 string, s3 string, i1 int) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   C.smxalf (c1, c2, c3, C.int (i1))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
}

func Solid () {
   C.solid ()
}

func Sortr1 (xray *float64, n int, s1 string) {
   c1:= C.CString (s1)
   C.sortr1 ((*C.double) (xray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Sortr2 (xray *float64, yray *float64, n int, s1 string) {
   c1:= C.CString (s1)
   C.sortr2 ((*C.double) (xray), (*C.double) (yray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Spcbar (i1 int) {
   C.spcbar (C.int (i1))
}

func Sphe3d (x1 float64, x2 float64, x3 float64, x4 float64, i1 int, i2 int) {
   C.sphe3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
             C.int (i1), C.int (i2))
}

func Spline (xray *float64, yray *float64, n int, 
             x *float64, y *float64) int {
    var iret C.int
    C.spline ((*C.double) (xray), (*C.double) (yray), C.int (n), 
              (*C.double) (x), (*C.double) (y), &iret)
    return int (iret)
}

func Splmod (i1 int, i2 int) {
   C.splmod (C.int (i1), C.int (i2))
}

func Stmmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.stmmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Stmopt (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.stmopt (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Stmpts (xmat *float64, ymat *float64, nx int, ny int,
             xp *float64, yp *float64, x0 float64, y0 float64, 
             xray *float64, yray *float64, nmax int) int {
    var nray C.int
    C.stmpts ((*C.double) (xmat), (*C.double) (ymat), C.int (nx), 
                C.int (ny), (*C.double) (xp), (*C.double) (yp), C.double (x0),
                C.double (y0), (*C.double) (xray), (*C.double) (yray), 
                C.int (nmax), &nray)
   return int (nray) 
}

func Stmtri (xv *float64, yv *float64, xp *float64, yp *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int, 
             xs *float64, ys *float64, nray int) {
    C.stmtri ((*C.double) (xv), (*C.double) (yv), 
              (*C.double) (xp), (*C.double) (yp), C.int (n),
              (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
              C.int (ntri), (*C.double) (xs), (*C.double) (ys), C.int (nray))
}

func Stmval (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.stmval (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Stream (xmat *float64, ymat *float64, nx int, ny int,
             xp *float64, yp *float64, 
             xs *float64, ys *float64, n int) {
    C.stream ((*C.double) (xmat), (*C.double) (ymat), C.int (nx), 
               C.int (ny), (*C.double) (xp), (*C.double) (yp), 
               (*C.double) (xs), (*C.double) (ys), C.int (n))
}

func Stream3d (xv *float64, yv *float64, zv *float64, nx int, ny int, nz int,
               xp *float64, yp *float64, zp *float64, 
               xs *float64, ys *float64, zs *float64, n int) {
    C.stream3d ((*C.double) (xv), (*C.double) (yv), (*C.double) (zv),
                C.int (nx), C.int (ny), C.int (nz), 
                (*C.double) (xp), (*C.double) (yp), (*C.double) (zp), 
                (*C.double) (xs), (*C.double) (ys), (*C.double) (zs),
                C.int (n))
}

func Strt3d (x1 float64, x2 float64, x3 float64) {
   C.strt3d (C.double (x1), C.double (x2), C.double (x3))
}

func Strtpt (x1 float64, x2 float64) {
   C.strtpt (C.double (x1), C.double (x2))
}

func Surclr (i1 int, i2 int) {
   C.surclr (C.int (i1), C.int (i2))
}

func Surfce (xray *float64, n int, yray *float64, m int, zmat *float64) {
    C.surfce ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat))
}

func Surfcp (zfun func(float64, float64, int) float64, 
             a1 float64, a2 float64, astp float64,
             b1 float64, b2 float64, bstp float64) {
   cb_funcs5[1] = zfun
   C.surfcp ((C.callback_fcn5) (unsafe.Pointer (C.cb_surfcp)), 
              C.double (a1), C.double (a2), C.double (astp),
              C.double (b1), C.double (b2), C.double (bstp))
} 

func Surfun (zfun func(float64, float64) float64, ixpts int, 
             xdel float64, iypts int, ydel float64) {
   cb_funcs4[1] = zfun
   C.surfun ((C.callback_fcn4) (unsafe.Pointer (C.cb_surfun)), C.int (ixpts),
              C.double (xdel), C.int (iypts), C.double (ydel))
} 

func Suriso (xray *float64, nx int, yray *float64, ny int, 
             zray *float64, nz int, wmat *float64, wlev float64) {
    C.suriso ((*C.double) (xray), C.int (nx), (*C.double) (yray), C.int (ny),
              (*C.double) (zray), C.int (nz), (*C.double) (wmat),
              C.double (wlev))
}

func Surmat (xmat *float64, i1 int, i2 int, i3 int, i4 int) {
    C.surmat ((*C.double) (xmat), C.int (i1), C.int (i2), C.int (i3), 
              C.int (i4))
}

func Surmsh (s1 string) {
   c1:= C.CString (s1)
   C.surmsh (c1)
   C.free (unsafe.Pointer (c1))
}

func Suropt (s1 string) {
   c1:= C.CString (s1)
   C.suropt (c1)
   C.free (unsafe.Pointer (c1))
}

func Surshc (xray *float64, n int, yray *float64, m int, zmat *float64,
             wmat *float64) {
    C.surshc ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat), (*C.double) (wmat))
}

func Surshd (xray *float64, n int, yray *float64, m int, zmat *float64) {
    C.surshd ((*C.double) (xray), C.int (n),(*C.double) (yray), C.int (m),
              (*C.double) (zmat))
}

func Sursze (x1 float64, x2 float64, x3 float64, x4 float64) {
   C.sursze (C.double (x1), C.double (x2), C.double (x3), C.double (x4))
}

func Surtri (xray *float64, yray *float64, zray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int) {
    C.surtri ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray),
              C.int (n), (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
              C.int (ntri))
}

func Survis (s1 string) {
   c1:= C.CString (s1)
   C.survis (c1)
   C.free (unsafe.Pointer (c1))
}

func Swapi2 (iray *int16, n int) {
    C.swapi2 ((*C.short) (iray), C.int (n))
}

func Swapi4 (iray *int32, n int) {
    C.swapi4 ((*C.int) (iray), C.int (n))
}

func Swgatt (i1 int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgatt (C.int (i1), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swgbgd (i1 int, x1 float64, x2 float64, x3 float64) {
   C.swgbgd (C.int (i1), C.double (x1), C.double (x2), C.double (x3))
}

func Swgbox (i1 int, i2 int) {
   C.swgbox (C.int (i1), C.int (i2))
}

func Swgbut (i1 int, i2 int) {
   C.swgbut (C.int (i1), C.int (i2))
}

func Swgcbk (id int, cb func(int)) {
   cb_funcs[id] = cb
   C.swgcbk (C.int (id), (C.callback_fcn) (unsafe.Pointer (C.cb_swgcbk)))
} 

func Swgcb2 (id int, cb func(int, int, int)) {
   cb_funcs2[id] = cb
   C.swgcb2 (C.int (id), (C.callback_fcn2) (unsafe.Pointer (C.cb_swgcb2)))
} 

func Swgcb3 (id int, cb func(int, int)) {
   cb_funcs3[id] = cb
   C.swgcb3 (C.int (id), (C.callback_fcn3) (unsafe.Pointer (C.cb_swgcb3)))
} 

func Swgclr (x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.swgclr (C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgdrw (x1 float64) {
   C.swgdrw (C.double (x1))
}

func Swgfgd (i1 int, x1 float64, x2 float64, x3 float64) {
   C.swgfgd (C.int (i1), C.double (x1), C.double (x2), C.double (x3))
}

func Swgfil (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.swgfil (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgflt (i1 int, x1 float64, i2 int) {
   C.swgflt (C.int (i1), C.double (x1), C.int (i2))
}

func Swgfnt (s1 string, i1 int) {
   c1:= C.CString (s1)
   C.swgfnt (c1, C.int (i1))
   C.free (unsafe.Pointer (c1))
}

func Swgfoc (i1 int) {
   C.swgfoc (C.int (i1))
}

func Swghlp (s1 string) {
   c1:= C.CString (s1)
   C.swghlp (c1)
   C.free (unsafe.Pointer (c1))
}

func Swgint (i1 int, i2 int) {
   C.swgint (C.int (i1), C.int (i2))
}

func Swgiop (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.swgiop (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgjus (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgjus (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swglis (i1 int, i2 int) {
   C.swglis (C.int (i1), C.int (i2))
}

func Swgmix (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgmix (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swgmrg (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.swgmrg (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgoff (i1 int, i2 int) {
   C.swgoff (C.int (i1), C.int (i2))
}

func Swgopt (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgopt (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swgpop (s1 string) {
   c1:= C.CString (s1)
   C.swgpop (c1)
   C.free (unsafe.Pointer (c1))
}

func Swgpos (i1 int, i2 int) {
   C.swgpos (C.int (i1), C.int (i2))
}

func Swgray (xray *float64, n int, s1 string) {
   c1:= C.CString (s1)
   C.swgray ((*C.double) (xray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgscl (i1 int, x1 float64) {
   C.swgscl (C.int (i1), C.double (x1))
}

func Swgsiz (i1 int, i2 int) {
   C.swgsiz (C.int (i1), C.int (i2))
}

func Swgspc (x1 float64, x2 float64) {
   C.swgspc (C.double (x1), C.double (x2))
}

func Swgstp (x1 float64) {
   C.swgstp (C.double (x1))
}

func Swgtbf (i1 int, x1 float64, i2 int, i3 int, i4 int, s1 string) {
   c1:= C.CString (s1)
   C.swgtbf (C.int (i1), C.double (x1), C.int (i2), C.int (i3), C.int (i4), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgtbi (i1 int, i2 int, i3 int, i4 int, s1 string) {
   c1:= C.CString (s1)
   C.swgtbi (C.int (i1), C.int (i2), C.int (i3), C.int (i4), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgtbl (i1 int, xray *float64, i2 int, i3 int, i4 int, s1 string) {
   c1:= C.CString (s1)
   C.swgtbl (C.int (i1), (*C.double) (xray), C.int (i2), C.int (i3), 
             C.int (i4), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgtbs (i1 int, s1 string, i2 int, i3 int, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgtbs (C.int (i1), c1, C.int (i2), C.int (i3), c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swgtit (s1 string) {
   c1:= C.CString (s1)
   C.swgtit (c1)
   C.free (unsafe.Pointer (c1))
}

func Swgtxt (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.swgtxt (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Swgtyp (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.swgtyp (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Swgval (i1 int, x1 float64) {
   C.swgval (C.int (i1), C.double (x1))
}

func Swgwin (i1 int, i2 int, i3 int, i4 int) {
   C.swgwin (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Swgwth (i1 int) {
   C.swgwth (C.int (i1))
}

func Symb3d (i1 int, x1 float64, x2 float64, x3 float64) {
   C.symb3d (C.int (i1), C.double (x1), C.double (x2), C.double (x3))
}

func Symbol (i1 int, i2 int, i3 int) {
   C.symbol (C.int (i1), C.int (i2), C.int (i3))
}

func Symfil (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.symfil (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Symrot (x1 float64) {
   C.symrot (C.double (x1))
}

func Tellfl (i1 int) int {
   return int (C.tellfl (C.int (i1)))
}

func Texmod (s1 string) {
   c1:= C.CString (s1)
   C.texmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Texopt (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.texopt (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Texval (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.texval (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Thkc3d (x1 float64) {
   C.thkc3d (C.double (x1))
}

func Thkcrv (i1 int) {
   C.thkcrv (C.int (i1))
}

func Thrfin () {
   C.thrfin ()
}

func Thrini (i1 int) {
   C.thrini (C.int (i1))
}

func Ticks (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.ticks (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Ticlen (i1 int, i2 int) {
   C.ticlen (C.int (i1), C.int (i2))
}

func Ticmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.ticmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Ticpos (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.ticpos (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Tifmod (i1 int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.tifmod (C.int (i1), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Tiforg (i1 int, i2 int) {
   C.tiforg (C.int (i1), C.int (i2))
}

func Tifwin (i1 int, i2 int, i3 int, i4 int) {
   C.tifwin (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Timopt () {
   C.timopt ()
}

func Titjus (s1 string) {
   c1:= C.CString (s1)
   C.titjus (c1)
   C.free (unsafe.Pointer (c1))
}

func Title () {
   C.title ()
}

func Titlin (s1 string, i1 int) {
   c1:= C.CString (s1)
   C.titlin (c1, C.int (i1))
   C.free (unsafe.Pointer (c1))
}

func Titpos (s1 string) {
   c1:= C.CString (s1)
   C.titpos (c1)
   C.free (unsafe.Pointer (c1))
}

func Torus3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, 
              x6 float64, x7 float64, x8 float64, i1 int, i2 int) {
   C.torus3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
              C.double (x5), C.double (x6), C.double (x7), C.double (x8),
              C.int (i1), C.int (i2))
}

func Tprfin () {
   C.tprfin ()
}

func Tprini () {
   C.tprini ()
}

func Tprmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.tprmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Tprval (x1 float64) {
   C.tprval (C.double (x1))
}

func Tr3axs (x1 float64, x2 float64, x3 float64, x4 float64) {
   C.tr3axs (C.double (x1), C.double (x2), C.double (x3), C.double (x4))
}

func Tr3res () {
   C.tr3res ()
}

func Tr3rot (x1 float64, x2 float64, x3 float64) {
   C.tr3rot (C.double (x1), C.double (x2), C.double (x3))
}

func Tr3scl (x1 float64, x2 float64, x3 float64) {
   C.tr3scl (C.double (x1), C.double (x2), C.double (x3))
}

func Tr3shf (x1 float64, x2 float64, x3 float64) {
   C.tr3shf (C.double (x1), C.double (x2), C.double (x3))
}

func Trfco1 (xray *float64, n int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.trfco1 ((*C.double) (xray), C.int (n), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Trfco2 (xray *float64, yray *float64, n int, s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.trfco2 ((*C.double) (xray), (*C.double) (yray), C.int (n), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Trfco3 (xray *float64, yray *float64, zray *float64, n int, s1 string, 
             s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.trfco3 ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
             C.int (n), c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Trfdat (i1 int, i2 *int, i3 *int, i4 *int) {
   var n1, n2, n3 C.int
   C.trfdat (C.int (i1), &n1, &n2, &n3)
   *i2 = int (n1)
   *i3 = int (n2)
   *i4 = int (n3)
}

func Trfmat (zmat *float64, nx int, ny int, zmat2 *float64, nx2 int, ny2 int) {
    C.trfmat ((*C.double) (zmat), C.int (nx), C.int (ny),
              (*C.double) (zmat2), C.int (nx2), C.int (ny2))
}

func Trfrel (xray *float64, yray *float64, n int) {
    C.trfrel ((*C.double) (xray), (*C.double) (yray), C.int (n))
}

func Trfres () {
   C.trfres ()
}

func Trfrot (x1 float64, i1 int, i2 int) {
   C.trfrot (C.double (x1), C.int (i1), C.int (i2))
}

func Trfscl (x1 float64, x2 float64) {
   C.trfscl (C.double (x1), C.double (x2))
}

func Trfshf (i1 int, i2 int) {
   C.trfshf (C.int (i1), C.int (i2))
}

func Tria3d (xray *float64, yray *float64, zray *float64) {
    C.tria3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray)) 
}

func Triang (xray *float64, yray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, nmax int) int {
    return int (C.triang ((*C.double) (xray), (*C.double) (yray), 
                C.int (n), (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
                C.int (nmax)))
}

func Triflc (xray *float64, yray *float64, iray *int32, n int) {
    C.triflc ((*C.double) (xray), (*C.double) (yray), (*C.int) (iray),
                C.int (n))
}

func Trifll (xray *float64, yray *float64) {
    C.trifll ((*C.double) (xray), (*C.double) (yray)) 
}

func Triplx () {
   C.triplx ()
}

func Tripts (xray *float64, yray *float64, zray *float64, n int,
             i1ray *int32, i2ray *int32, i3ray *int32, ntri int, 
             zlev float64, xpts *float64, ypts *float64, maxpts int,
             nptray *int32, maxray int) int {
    var nlins C.int
    C.tripts ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray),
              C.int (n), (*C.int) (i1ray), (*C.int) (i2ray), (*C.int) (i3ray),
              C.int (ntri), C.double (zlev), 
              (*C.double) (xpts), (*C.double) (ypts), C.int (maxpts),
              (*C.int) (nptray), C.int (maxray), &nlins)
    return int (nlins)
}

func Trmlen (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.trmlen (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Ttfont (s1 string) {
   c1:= C.CString (s1)
   C.ttfont (c1)
   C.free (unsafe.Pointer (c1))
}

func Tube3d (x1 float64, x2 float64, x3 float64, x4 float64, x5 float64, 
             x6 float64, x7 float64, i1 int, i2 int) {
   C.tube3d (C.double (x1), C.double (x2), C.double (x3), C.double (x4), 
             C.double (x5), C.double (x6), C.double (x7), 
             C.int (i1), C.int (i2))
}

func Txtbgd (i1 int) {
   C.txtbgd (C.int (i1))
}

func Txtjus (s1 string) {
   c1:= C.CString (s1)
   C.txtjus (c1)
   C.free (unsafe.Pointer (c1))
}

func Txture (itmat *int32, i1 int, i2 int) {
    C.txture ((*C.int) (itmat), C.int (i1), C.int (i2))
}

func Units (s1 string) {
   c1:= C.CString (s1)
   C.units (c1)
   C.free (unsafe.Pointer (c1))
}

func Upstr (s1 string) string {
   c1:= C.CString (s1)
   C.upstr (c1)
   s := C.GoString ((*C.char) (c1))
   C.free (unsafe.Pointer (c1))
   return s
}

func Utfint (s1 string, iray *int32, n int) int {
   var iret C.int
   c1:= C.CString (s1)
   iret = C.utfint (c1, (*C.int) (iray), C.int (n))
   return int (iret)
}

func Vang3d (x1 float64) {
   C.vang3d (C.double (x1))
}

func Vclp3d (x1 float64, x2 float64) {
   C.vclp3d (C.double (x1), C.double (x2))
}

func Vecclr (i1 int) {
   C.vecclr (C.int (i1))
}

func Vecf3d (xv *float64, yv *float64, zv *float64,
             xp *float64, yp *float64, zp *float64,
             n int, ivec int) {
    C.vecf3d ((*C.double) (xv), (*C.double) (yv), (*C.double) (zv), 
              (*C.double) (xp), (*C.double) (yp), (*C.double) (zp),
                C.int (n), C.int (ivec))
}

func Vecfld (xv *float64, yv *float64, xp *float64, yp *float64,
             n int, ivec int) {
    C.vecfld ((*C.double) (xv), (*C.double) (yv), (*C.double) (xp), 
              (*C.double) (yp), C.int (n), C.int (ivec))
}

func Vecmat (xmat *float64, ymat *float64, nx int, ny int,
             xp *float64, yp *float64, ivec int) {
    C.vecmat ((*C.double) (xmat), (*C.double) (ymat), C.int (nx),
              C.int (ny), (*C.double) (xp), (*C.double) (yp), C.int (ivec))
}

func Vecmat3d (xmat *float64, ymat *float64, zmat *float64, 
               nx int, ny int, nz int,
               xp *float64, yp *float64, zp *float64, ivec int) {
    C.vecmat3d ((*C.double) (xmat), (*C.double) (ymat), (*C.double) (zmat), 
                C.int (nx), C.int (ny), C.int (nz),
                (*C.double) (xp), (*C.double) (yp), (*C.double) (zp),
                C.int (ivec))
}

func Vecopt (x1 float64, s1 string) {
   c1:= C.CString (s1)
   C.vecopt (C.double (x1), c1)
   C.free (unsafe.Pointer (c1))
}

func Vector (i1 int, i2 int, i3 int, i4 int, i5 int) {
   C.vector (C.int (i1), C.int (i2), C.int (i3), C.int (i4), C.int (i5))
}

func Vectr3 (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64, i1 int) {
   C.vectr3 (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6), C.int (i1))
}

func Vfoc3d (x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.vfoc3d (C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func View3d (x1 float64, x2 float64, x3 float64, s1 string) {
   c1:= C.CString (s1)
   C.view3d (C.double (x1), C.double (x2), C.double (x3), c1)
   C.free (unsafe.Pointer (c1))
}

func Vkxbar (i1 int) {
   C.vkxbar (C.int (i1))
}

func Vkybar (i1 int) {
   C.vkybar (C.int (i1))
}

func Vkytit (i1 int) {
   C.vkytit (C.int (i1))
}

func Vltfil (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.vltfil (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func Vscl3d (x1 float64) {
   C.vscl3d (C.double (x1))
}

func Vtx3d (xray *float64, yray *float64, zray *float64, n int,
            s1 string) {
   c1:= C.CString (s1)
   C.vtx3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
              C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Vtxc3d (xray *float64, yray *float64, zray *float64, icray *int32,
             n int,  s1 string) {
   c1:= C.CString (s1)
   C.vtxc3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
             (*C.int) (icray), C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Vtxn3d (xray *float64, yray *float64, zray *float64, 
             xn *float64, yn *float64, zn *float64, 
             n int, s1 string) {
   c1:= C.CString (s1)
   C.vtxn3d ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
             (*C.double) (xn), (*C.double) (yn), (*C.double) (zn), 
               C.int (n), c1)
   C.free (unsafe.Pointer (c1))
}

func Vup3d (x1 float64) {
   C.vup3d (C.double (x1))
}

func Wgapp (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgapp (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgappb (i1 int, iray *byte, i2 int, i3 int) int {
   iret := int (C.wgappb (C.int (i1), (*C.uchar) (iray), C.int (i2), 
                         C.int (i3)))
   return iret
}

func Wgbas (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgbas (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgbox (i1 int, s1 string, i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgbox (C.int (i1), c1, C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgbut (i1 int, s1 string, i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgbut (C.int (i1), c1, C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgcmd (i1 int, s1 string, s2 string) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   iret := int (C.wgcmd (C.int (i1), c1, c2))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return iret
}

func Wgdlis (i1 int, s1 string, i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgdlis (C.int (i1), c1, C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgdraw (i1 int) int {
   return int (C.wgdraw (C.int (i1)))
}

func Wgfil (i1 int, s1 string, s2 string, s3 string) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   c3:= C.CString (s3)
   iret := int (C.wgfil (C.int (i1), c1, c2, c3))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   C.free (unsafe.Pointer (c3))
   return iret
}

func Wgfin () {
   C.wgfin ()
}

func Wgicon (i1 int, s1 string, i2 int, i3 int, s2 string) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   iret := int (C.wgicon (C.int (i1), c1, C.int (i2), C.int (i3), c2))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return iret
}

func Wgimg (i1 int, s1 string, iray *byte, i2 int, i3 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgimg (C.int (i1), c1, (*C.uchar) (iray), C.int (i2), 
                         C.int (i3)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgini (s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgini (c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wglab (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wglab (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wglis (i1 int, s1 string, i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.wglis (C.int (i1), c1, C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgltxt (i1 int, s1 string, s2 string, i2 int) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   iret := int (C.wgltxt (C.int (i1), c1, c2, C.int (i2)))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return iret
}

func Wgok (i1 int) int {
   return int (C.wgok (C.int (i1)))
}

func Wgpbar (i1 int, x1 float64, x2 float64, x3 float64) int {
   iret := int (C.wgpbar (C.int (i1), C.double (x1), C.double (x2), 
                          C.double (x3)))
   return iret
}

func Wgpbut (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgpbut (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgpicon (i1 int, s1 string, i2 int, i3 int, s2 string) int {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   iret := int (C.wgpicon (C.int (i1), c1, C.int (i2), C.int (i3), c2))
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
   return iret
}

func Wgpimg (i1 int, s1 string, iray *byte, i2 int, i3 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgpimg (C.int (i1), c1, (*C.uchar) (iray), C.int (i2), 
                          C.int (i3)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgpop (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgpop (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgpopb (i1 int, iray *byte, i2 int, i3 int) int {
   iret := int (C.wgpopb (C.int (i1), (*C.uchar) (iray), C.int (i2), 
                         C.int (i3)))
   return iret
}

func Wgquit (i1 int) int {
   return int (C.wgquit (C.int (i1)))
}

func Wgscl (i1 int, s1 string, x1 float64, x2 float64, x3 float64,
            i2 int) int {
   c1:= C.CString (s1)
   iret := int (C.wgscl (C.int (i1), c1, C.double (x1), C.double (x2),
                         C.double (x3), C.int (i2)))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Wgsep (i1 int) int {
   return int (C.wgsep (C.int (i1)))
}

func Wgstxt (i1 int, i2 int, i3 int) int {
   return int (C.wgstxt (C.int (i1), C.int (i2), C.int (i3)))
}

func Wgtbl (i1 int, i2 int, i3 int) int {
   return int (C.wgtbl (C.int (i1), C.int (i2), C.int (i3)))
}

func Wgtxt (i1 int, s1 string) int {
   c1:= C.CString (s1)
   iret := int (C.wgtxt (C.int (i1), c1))
   C.free (unsafe.Pointer (c1))
   return iret
}

func Widbar (i1 int) {
   C.widbar (C.int (i1))
}

func Wimage (s1 string) {
   c1:= C.CString (s1)
   C.wimage (c1)
   C.free (unsafe.Pointer (c1))
}
  
func Winapp (s1 string) {
   c1:= C.CString (s1)
   C.winapp (c1)
   C.free (unsafe.Pointer (c1))
}
  
func Wincbk (cb func(int, int, int, int, int), s1 string) {
   cb_funcs6[1] = cb
   c1:= C.CString (s1)
   C.wincbk ((C.callback_fcn6) (unsafe.Pointer (C.cb_wincbk)), c1)
   C.free (unsafe.Pointer (c1))
} 

func Windbr (x1 float64, i1 int, i2 int, i3 int, x2 float64) {
   C.windbr (C.double (x1), C.int (i1), C.int (i2), C.int (i3), 
             C.double (x2))
}

func Window (i1 int, i2 int, i3 int, i4 int) {
   C.window (C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Winfnt (s1 string) {
   c1:= C.CString (s1)
   C.winfnt (c1)
   C.free (unsafe.Pointer (c1))
}

func Winico (s1 string) {
   c1:= C.CString (s1)
   C.winico (c1)
   C.free (unsafe.Pointer (c1))
}

func Winid () int {
   return int (C.winid ())
}

func Winjus (s1 string) {
   c1:= C.CString (s1)
   C.winjus (c1)
   C.free (unsafe.Pointer (c1))
}

func Winkey (s1 string) {
   c1:= C.CString (s1)
   C.winkey (c1)
   C.free (unsafe.Pointer (c1))
}

func Winmod (s1 string) {
   c1:= C.CString (s1)
   C.winmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Winopt (i1 int, s1 string) {
   c1:= C.CString (s1)
   C.winopt (C.int (i1), c1)
   C.free (unsafe.Pointer (c1))
}

func Winsiz (i1 int, i2 int) {
   C.winsiz (C.int (i1), C.int (i2))
}

func Wintit (s1 string) {
   c1:= C.CString (s1)
   C.wintit (c1)
   C.free (unsafe.Pointer (c1))
}

func Wintyp (s1 string) {
   c1:= C.CString (s1)
   C.wintyp (c1)
   C.free (unsafe.Pointer (c1))
}

func Wmfmod (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.wmfmod (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func World () {
   C.world ()
}

func Wpixel (i1 int, i2 int, i3 int) {
   C.wpixel (C.int (i1), C.int (i2), C.int (i3))
}

func Wpixls (iray *byte, i1 int, i2 int, i3 int, i4 int) {
   C.wpixls ((*C.uchar) (iray), C.int (i1), C.int (i2), C.int (i3), C.int (i4))
}

func Wpxrow (iray *byte, i1 int, i2 int, i3 int) {
   C.wpxrow ((*C.uchar) (iray), C.int (i1), C.int (i2), C.int (i3))
}

func Writfl (i1 int, iray *byte, i2 int) int {
   return int (C.writfl (C.int (i1), (*C.uchar) (iray), C.int (i2)))
}

func Wtiff (s1 string) {
   c1:= C.CString (s1)
   C.wtiff (c1)
   C.free (unsafe.Pointer (c1))
}

func X11fnt (s1 string, s2 string) {
   c1:= C.CString (s1)
   c2:= C.CString (s2)
   C.x11fnt (c1, c2)
   C.free (unsafe.Pointer (c1))
   C.free (unsafe.Pointer (c2))
}

func X11mod (s1 string) {
   c1:= C.CString (s1)
   C.x11mod (c1)
   C.free (unsafe.Pointer (c1))
}

func x2dpos (x1 float64, x2 float64) float64 {
   return float64 (C.x2dpos (C.double (x1), C.double (x2)))
}

func X3dabs (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.x3dabs (C.double (x1), C.double (x2), C.double (x3)))
}

func X3dpos (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.x3dpos (C.double (x1), C.double (x2), C.double (x3)))
}

func X3drel (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.x3drel (C.double (x1), C.double (x2), C.double (x3)))
}

func Xaxgit () {
   C.xaxgit ()
}

func Xaxis (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int) {
   c1:= C.CString (s1)
   C.xaxis (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4))
   C.free (unsafe.Pointer (c1))
}

func Xaxlg (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int) {
   c1:= C.CString (s1)
   C.xaxlg (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4))
   C.free (unsafe.Pointer (c1))
}

func Xaxmap (x1 float64, x2 float64, x3 float64, x4 float64,
            s1 string, i1 int, i2 int) {
   c1:= C.CString (s1)
   C.xaxmap (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            c1, C.int (i1), C.int (i2))
   C.free (unsafe.Pointer (c1))
}

func Xcross () {
   C.xcross ()
}

func Xdraw (x1 float64, x2 float64) {
   C.xdraw (C.double (x1), C.double (x2))
}

func Xinvrs (i1 int) float64 {
   return float64 (C.xinvrs (C.int (i1)))
}

func Xmove (x1 float64, x2 float64) {
   C.xmove (C.double (x1), C.double (x2))
}

func Xposn (x1 float64) float64 {
   return float64 (C.xposn (C.double (x1)))
}

func Y2dpos (x1 float64, x2 float64) float64 {
   return float64 (C.y2dpos (C.double (x1), C.double (x2)))
}

func Y3dabs (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.y3dabs (C.double (x1), C.double (x2), C.double (x3)))
}

func Y3dpos (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.y3dpos (C.double (x1), C.double (x2), C.double (x3)))
}

func Y3drel (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.y3drel (C.double (x1), C.double (x2), C.double (x3)))
}

func Yaxgit () {
   C.yaxgit ()
}

func Yaxis (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int) {
   c1:= C.CString (s1)
   C.yaxis (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4))
   C.free (unsafe.Pointer (c1))
}

func Yaxlg (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int) {
   c1:= C.CString (s1)
   C.yaxlg (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4))
   C.free (unsafe.Pointer (c1))
}

func Yaxmap (x1 float64, x2 float64, x3 float64, x4 float64,
            s1 string, i1 int, i2 int) {
   c1:= C.CString (s1)
   C.yaxmap (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            c1, C.int (i1), C.int (i2))
   C.free (unsafe.Pointer (c1))
}

func Ycross () {
   C.ycross ()
}

func Yinvrs (i1 int) float64 {
   return float64 (C.yinvrs (C.int (i1)))
}

func Ypolar (x1 float64, x2 float64, x3 float64, x4 float64,
            s1 string, i1 int) {
   c1:= C.CString (s1)
   C.ypolar (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            c1, C.int (i1))
   C.free (unsafe.Pointer (c1))
}

func Yposn (x1 float64) float64 {
   return float64 (C.yposn (C.double (x1)))
}

func Z3dpos (x1 float64, x2 float64, x3 float64) float64 {
   return float64 (C.z3dpos (C.double (x1), C.double (x2), C.double (x3)))
}

func Zaxis (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int, i5 int) {
   c1:= C.CString (s1)
   C.zaxis (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4), C.int (i5))
   C.free (unsafe.Pointer (c1))
}

func Zaxlg (x1 float64, x2 float64, x3 float64, x4 float64, i1 int,
            s1 string, i2 int, i3 int, i4 int, i5 int) {
   c1:= C.CString (s1)
   C.zaxlg (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
            C.int (i1), c1, C.int (i2), C.int (i3), C.int (i4), C.int (i5))
   C.free (unsafe.Pointer (c1))
}

func Zbfers () {
   C.zbfers ()
}

func Zbffin () {
   C.zbffin ()
}

func Zbfini () int {
   return int (C.zbfini ())
}

func Zbflin (x1 float64, x2 float64, x3 float64, x4 float64,
           x5 float64, x6 float64) {
   C.zbflin (C.double (x1), C.double (x2), C.double (x3), C.double (x4),
           C.double (x5), C.double (x6))
}

func Zbfmod (s1 string) {
   c1:= C.CString (s1)
   C.zbfmod (c1)
   C.free (unsafe.Pointer (c1))
}

func Zbfres () {
   C.zbfres ()
}

func Zbfscl (x1 float64) {
   C.zbfscl (C.double (x1))
}

func Zbftri (xray *float64, yray *float64, zray *float64, icray *int32) {
    C.zbftri ((*C.double) (xray), (*C.double) (yray), (*C.double) (zray), 
              (*C.int) (icray))
}

func Zscale (x1 float64, x2 float64) {
   C.zscale (C.double (x1), C.double (x2))
}

/****************************************************************/
/**                         dislin.c                           **/
/**                                                            **/
/** Dislin interface for Ruby.                                 **/
/**                                                            **/
/** Date     : 15.03.2024                                      **/
/** Version  : 11.5.2 / Unix, Windows, 32- and 64-bit          **/
/****************************************************************/

#include <ruby.h>
#include <stdio.h>
#include <stdlib.h>
#include "dislin_d.h"

#define MAX_CB 200
static VALUE rb_Dislin;

static int ncbray = 0;
static int icbray[MAX_CB];
static char *rcbray[MAX_CB];
           
static char *clegbf = NULL;
static char *rbfunc = NULL, *rbwin = NULL, *rbpie = NULL, *rbprj = NULL;
static int nspline = 200;
static int imgopt = 0;

void dis_callbck2 (int ip);
void dis_callbck3 (int ip, int irow, int icol);
void dis_callbck4 (int ip, int ival);
double dis_funcbck (double x, double y, int iopt);
double dis_funcbck2 (double x, double y);
void dis_piecbk (int iseg, double xdat, double xper, int *nrad,
                 int *noff, double *angle, int *nvx, int *nvy, int *idrw, 
                 int *iann);
void dis_prjcbk (double *x, double *y);
void dis_wincbk (int id, int nx, int ny, int nw, int nh);

static int *int_array (VALUE arr, int n)
{ VALUE *r;
  int i, nr;
  int *p = NULL;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (int *) calloc (n, sizeof (int));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n; i++)
      p[i] = NUM2INT (r[i]);
  }

  return p;
}

static int *int_matrix (VALUE arr, int nx, int ny)
{ VALUE *r;
  int i, nr, n;
  int *p = NULL;

  n = nx * ny;
  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (int *) calloc (n, sizeof (int));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n; i++)
      p[i] = NUM2INT (r[i]);
  }

  return p;
}

static long *long_array (VALUE arr, int n)
{ VALUE *r;
  int i, nr;
  long *p = NULL;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (long *) calloc (n, sizeof (long));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n; i++)
      p[i] = (long) NUM2INT (r[i]);
  }

  return p;
}

static double *dbl_array (VALUE arr, int n)
{ VALUE *r;
  int i, nr;
  double *p = NULL;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (double *) calloc (n, sizeof (double));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n; i++)
      p[i] = NUM2DBL (r[i]);
  }

  return p;
}

static double *dbl_matrix (VALUE arr, int n, int m)
{ VALUE *r;
  int i, nr;
  double *p = NULL;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n * m) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (double *) calloc (n * m, sizeof (double));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n * m; i++)
      p[i] = NUM2DBL (r[i]);
  }

  return p;
}

static double *dbl_matrix3 (VALUE arr, int nx, int ny, int nz)
{ VALUE *r;
  int i, nr, n;
  double *p = NULL;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  n = nx * ny *nz;
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return NULL;
  }

  p = (double *) calloc (n, sizeof (double));
  if (p == NULL)
    rb_warn ("not enough memory!");
  else
  { r  = RARRAY_PTR (arr);
    for (i = 0; i < n; i++)
      p[i] = NUM2DBL (r[i]);
  }

  return p;
}

static  void copy_intarray (int *p, VALUE arr, int n)
{ VALUE *r;
  int i, nr;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return;
  }

  r  = RARRAY_PTR (arr);
  for (i = 0; i < n; i++)
    r[i] = INT2NUM (p[i]);

  return;
}

static  void copy_dblarray (double *p, VALUE arr, int n)
{ VALUE *r;
  int i, nr;

  Check_Type (arr, T_ARRAY);
  nr = RARRAY_LEN (arr);
  if (nr < n) 
  { rb_warn ("not enough elements in array!");
    return;
  }

  r  = RARRAY_PTR (arr);
  for (i = 0; i < n; i++)
    r[i] = rb_float_new (p[i]);

  return;
}

static VALUE rb_abs3pt (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ VALUE arr;
  double xp, yp;
  abs3pt (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_addlab (VALUE self, VALUE s1, VALUE x, VALUE i, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  addlab (StringValueCStr (s1), NUM2DBL (x), NUM2INT (i), 
          StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_angle (VALUE self, VALUE n)
{ angle (NUM2INT (n));
  return Qnil;
}

static VALUE rb_arcell (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                        VALUE x1, VALUE x2, VALUE x3)
{ arcell (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3),  NUM2INT (i4),
          NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_areaf (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  int *p1, *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = int_array (arr2, n);
  if (p1 != NULL && p2 != NULL) areaf (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_autres (VALUE self, VALUE i1, VALUE i2)
{ autres (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_autres3d (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ autres3d (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_ax2grf (VALUE self)
{ ax2grf ();
  return Qnil;
}

static VALUE rb_ax3len (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ ax3len (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_axclrs (VALUE self, VALUE n, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  axclrs (NUM2INT (n), StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_axends (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  axends (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_axgit (VALUE self)
{ axgit ();
  return Qnil;
}

static VALUE rb_axis3d (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ axis3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_axsbgd (VALUE self, VALUE n)
{ axsbgd (NUM2INT (n));
  return Qnil;
}

static VALUE rb_axsers (VALUE self)
{ axsers ();
  return Qnil;
}

static VALUE rb_axslen (VALUE self, VALUE i1, VALUE i2)
{ axslen (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_axsorg (VALUE self, VALUE i1, VALUE i2)
{ axsorg (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_axspos (VALUE self, VALUE i1, VALUE i2)
{ axspos (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_axsscl (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  axsscl (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_axstyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  axstyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_barbor (VALUE self, VALUE n)
{ barbor (NUM2INT (n));
  return Qnil;
}

static VALUE rb_barclr (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ barclr (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_bargrp (VALUE self, VALUE i, VALUE x)
{ bargrp (NUM2INT (i), NUM2DBL (x));
  return Qnil;
}

static VALUE rb_barmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  barmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_baropt (VALUE self, VALUE x1, VALUE x2)
{ baropt (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_barpos (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  barpos (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_bars (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) bars (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_bars3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE arr4, VALUE arr5, VALUE arr6, VALUE arr7, 
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3, *p4, *p5, *p6;
  int *p7;
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = dbl_array (arr5, n);
  p6 = dbl_array (arr6, n);
  p7 = int_array (arr7, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL &&
      p5 != NULL && p6 != NULL && p7 != NULL)
    bars3d (p1, p2, p3, p4, p5, p6, p7, n);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  return Qnil;
}

static VALUE rb_bartyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  bartyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_barwth (VALUE self, VALUE x)
{ barwth (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_basalf (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  basalf (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_basdat (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ basdat (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_bezier (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE arr3, VALUE arr4, VALUE n2)
{ int n, np;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  np = NUM2INT (n2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, np);
  p4 = dbl_array (arr4, np);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  {  bezier (p1, p2, n, p3, p4, np);
     copy_dblarray (p3, arr3, np);
     copy_dblarray (p4, arr4, np);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_bitsi2 (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                      VALUE i5)
{ int i;
  i = (int) bitsi2 (NUM2INT (i1), (short) NUM2INT (i2), NUM2INT (i3), 
                    (short) NUM2INT (i4), NUM2INT (i5));
  return INT2NUM (i);
}

static VALUE rb_bitsi4 (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                      VALUE i5)
{ int i;
  i = bitsi4 (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
            NUM2INT (i5));
  return INT2NUM (i);
}

static VALUE rb_bmpfnt(VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  bmpfnt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_bmpmod (VALUE self, VALUE n, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  bmpmod (NUM2INT (n), StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_box2d (VALUE self)
{ box2d ();
  return Qnil;
}

static VALUE rb_box3d (VALUE self)
{ box3d ();
  return Qnil;
}

static VALUE rb_bufmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  bufmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_center (VALUE self)
{ center ();
  return Qnil;
}

static VALUE rb_cgmbgd (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ cgmbgd (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_cgmpic (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  cgmpic (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_cgmver (VALUE self, VALUE n)
{ cgmver (NUM2INT (n));
  return Qnil;
}

static VALUE rb_chaang (VALUE self, VALUE x)
{ chaang (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_chacod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  chacod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_chaspc (VALUE self, VALUE x)
{ chaspc (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_chawth (VALUE self, VALUE x)
{ chawth (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_chnatt (VALUE self)
{ chnatt ();
  return Qnil;
}

static VALUE rb_chncrv (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  chncrv (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_chndot (VALUE self)
{ chndot ();
  return Qnil;
}

static VALUE rb_chndsh (VALUE self)
{ chndsh ();
  return Qnil;
}

static VALUE rb_chnbar (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  chnbar (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_chnpie (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  chnpie (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_circ3p (VALUE self, VALUE x1, VALUE x2, VALUE x3,
                        VALUE x4, VALUE x5, VALUE x6)
{ VALUE arr;
  double xm, ym, r ;
  circ3p (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), &xm, &ym, &r);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xm));
  rb_ary_push (arr, rb_float_new (ym));
  rb_ary_push (arr, rb_float_new (r));
  return arr;
}

static VALUE rb_circle (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ circle (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_circsp (VALUE self, VALUE n)
{ circsp (NUM2INT (n));
  return Qnil;
}

static VALUE rb_clip3d (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  clip3d (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_closfl (VALUE self, VALUE n)
{ int i;
  i = closfl (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_clpbor (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  clpbor (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_clpmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  clpmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_clpwin (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ clpwin (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_clrcyc (VALUE self, VALUE i1, VALUE i2)
{ clrcyc (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_clrmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  clrmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_clswin (VALUE self, VALUE n)
{ clswin (NUM2INT (n));
  return Qnil;
}

static VALUE rb_color (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  color (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_colran (VALUE self, VALUE i1, VALUE i2)
{ colran (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_colray (VALUE self, VALUE arr1, VALUE n1)
{ VALUE arr;
  int i, n, *p2;
  double *p1;

  n = NUM2INT (n1);
  p2 = (int *) calloc (n, sizeof (int));
  if (p2 == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  p1 = dbl_array (arr1, n);
  if (p1 != NULL) 
    colray (p1, p2, n);

  arr = rb_ary_new ();
  for (i = 0; i < n; i++)
    rb_ary_push (arr, INT2NUM (p2[i]));
  free (p1);
  free (p2);
  return arr;
}

static VALUE rb_complx (VALUE self)
{ complx ();
  return Qnil;
}

static VALUE rb_conclr (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  int *p1;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  if (p1 != NULL) conclr (p1, n);
  free (p1);
  return Qnil;
}

static VALUE rb_concrv (VALUE self, VALUE arr1, VALUE arr2, VALUE n1, VALUE x)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) concrv (p1, p2, n, NUM2DBL (x));
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_cone3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE i1, VALUE i2)
{ cone3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_confll (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1, VALUE arr4, VALUE arr5, VALUE arr6,
                        VALUE n2, VALUE arr7, VALUE n3)
{ int n, ntri, nlev, *p4, *p5, *p6;
  double *p1, *p2, *p3, *p7;

  n = NUM2INT (n1);
  ntri = NUM2INT (n2);
  nlev = NUM2INT (n3);

  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n); 
  p4 = int_array (arr4, ntri);
  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);
  p7 = dbl_array (arr7, nlev);
  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
    confll (p1, p2, p3, n, p4, p5, p6, ntri, p7, nlev);

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  return Qnil;
}

static VALUE rb_congap (VALUE self, VALUE x)
{ congap (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_conlab (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  conlab (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_conmat (VALUE self, VALUE arr1, VALUE i1, VALUE i2, VALUE x)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) conmat (p1, n, m, NUM2DBL (x));
  free (p1);
  return Qnil;
}

static VALUE rb_conmod (VALUE self, VALUE x1, VALUE x2)
{ conmod (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_conn3d (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ conn3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_connpt (VALUE self, VALUE x1, VALUE x2)
{ connpt (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_conpts (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE x, VALUE arr4, 
                        VALUE arr5, VALUE i3, VALUE arr6, VALUE i4)
{ int i, n, m, maxpts, maxray, *p6;
  double *p1, *p2, *p3, *p4, *p5;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  maxpts = NUM2INT (i3);
  maxray = NUM2INT (i4);

  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  p4 = dbl_array (arr4, maxpts);
  p5 = dbl_array (arr5, maxpts);
  p6 = int_array (arr6, maxray);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
  { conpts (p1, n, p2, m, p3, NUM2DBL (x), p4, p5, maxpts, p6, maxray, &i);
    copy_dblarray (p4, arr4, maxpts);
    copy_dblarray (p5, arr5, maxpts);
    copy_intarray (p6, arr6, maxray);
  }

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return INT2NUM (i);
}

static VALUE rb_conshd (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE arr4, VALUE i3)
{ int n, m, nlev;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  nlev = NUM2INT (i3);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  p4 = dbl_array (arr4, nlev);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd (p1, n, p2, m, p3, p4, nlev);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_conshd2 (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                         VALUE i1, VALUE i2, VALUE arr4, VALUE i3)
{ int n, m, nlev;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  nlev = NUM2INT (i3);
  p1 = dbl_matrix (arr1, n, m);
  p2 = dbl_matrix (arr2, n, m);
  p3 = dbl_matrix (arr3, n, m);
  p4 = dbl_array (arr4, nlev);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd2 (p1, p2, p3, n, m, p4, nlev);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_conshd3d (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE arr4, VALUE i3)
{ int n, m, nlev;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  nlev = NUM2INT (i3);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  p4 = dbl_array (arr4, nlev);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd3d (p1, n, p2, m, p3, p4, nlev);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_contri (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE i1, VALUE arr4, VALUE arr5, VALUE arr6,
                        VALUE i2, VALUE x)
{ int n, ntri;
  double *p1, *p2, *p3;
  int *p4, *p5, *p6;

  n = NUM2INT (i1);
  ntri = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = int_array (arr4, ntri);
  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
    contri (p1, p2, p3, n, p4, p5, p6, ntri, NUM2DBL (x));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_contur (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE x)
{ int n, m;
  double *p1, *p2, *p3;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    contur (p1, n, p2, m, p3, NUM2DBL (x));
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_contur2 (VALUE self, VALUE arr1, VALUE arr2, 
                         VALUE arr3, VALUE i1, VALUE i2, VALUE x)
{ int n, m;
  double *p1, *p2, *p3;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  p2 = dbl_matrix (arr2, n, m);
  p3 = dbl_matrix (arr3, n, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    contur2 (p1, p2, p3, n, m, NUM2DBL (x));
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_cross (VALUE self)
{ cross ();
  return Qnil;
}

static VALUE rb_crvmat (VALUE self, VALUE arr1, VALUE i1, VALUE i2, VALUE i3,
                        VALUE i4)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) crvmat (p1, n, m, NUM2INT (i3), NUM2INT (i4));
  free (p1);
  return Qnil;
}

static VALUE rb_crvqdr (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) crvqdr (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_crvt3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE arr4, VALUE arr5, VALUE n1)
{ int n, *p5;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = int_array (arr5, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL)
    crvt3d (p1, p2, p3, p4, p5, n);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  return Qnil;
}

static VALUE rb_crvtri (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1, VALUE arr4, VALUE arr5, VALUE arr6, VALUE n2)
{ int n, ntri, *p4, *p5, *p6;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  ntri = NUM2INT (n2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = int_array (arr4, ntri);
  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL)
    crvtri (p1, p2, p3, n, p4, p5, p6, ntri);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_csrkey (VALUE self)
{ int i;
  i = csrkey ();
  return INT2NUM (i);
}

static VALUE rb_csrlin (VALUE self)
{ VALUE arr;
  int i1, i2, i3, i4;

  csrlin (&i1, &i2, &i3, &i4);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  rb_ary_push (arr, INT2NUM (i4));
  return arr;
}

static VALUE rb_csrmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  csrmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_csrpos (VALUE self, VALUE n1, VALUE n2)
{ VALUE arr;
  int i1, i2, i3;

  i1 = NUM2INT (n1); 
  i2 = NUM2INT (n2); 
  i3 = csrpos (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_csrpt1 (VALUE self)
{ VALUE arr;
  int i1, i2;

  csrpt1 (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_csrpts (VALUE self, VALUE arr1, VALUE arr2, VALUE i1)
{ int nmax, n, iret, *p1, *p2;

  nmax = NUM2INT (i1);
  p1 = int_array (arr1, nmax);
  p2 = int_array (arr2, nmax);
  if (p1 != NULL && p2 != NULL)
  { csrpts (p1, p2, nmax, &n, &iret);
    copy_intarray (p1, arr1, n);
    copy_intarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return INT2NUM (n);
}

static VALUE rb_csrpol (VALUE self, VALUE arr1, VALUE arr2, VALUE i1)
{ int nmax, n, iret, *p1, *p2;

  nmax = NUM2INT (i1);
  p1 = int_array (arr1, nmax);
  p2 = int_array (arr2, nmax);
  if (p1 != NULL && p2 != NULL)
  { csrpol (p1, p2, nmax, &n, &iret);
    copy_intarray (p1, arr1, n);
    copy_intarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return INT2NUM (n);
}

static VALUE rb_csrmov (VALUE self, VALUE arr1, VALUE arr2, VALUE i1)
{ int nmax, n, iret, *p1, *p2;

  nmax = NUM2INT (i1);
  p1 = int_array (arr1, nmax);
  p2 = int_array (arr2, nmax);
  if (p1 != NULL && p2 != NULL)
  { csrmov (p1, p2, nmax, &n, &iret);
    copy_intarray (p1, arr1, n);
    copy_intarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return INT2NUM (n);
}

static VALUE rb_csrrec (VALUE self)
{ VALUE arr;
  int i1, i2, i3, i4;

  csrrec (&i1, &i2, &i3, &i4);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  rb_ary_push (arr, INT2NUM (i4));
  return arr;
}

static VALUE rb_csrtyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  csrtyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_csruni (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  csruni (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_curv3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) curv3d (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_curv4d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE arr4, VALUE n1)
{ int n;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL)
    curv4d (p1, p2, p3, p4, n);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_curve (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) curve (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_curve3 (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) curve3 (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_curvmp (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) curvmp (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_curvx3 (VALUE self, VALUE arr1, VALUE y, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) curvx3 (p1, NUM2DBL (y), p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_curvy3 (VALUE self, VALUE x, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) curvy3 (NUM2DBL (x), p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_cyli3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE i1, VALUE i2)
{ cyli3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_dash (VALUE self)
{ dash ();
  return Qnil;
}

static VALUE rb_dashl (VALUE self)
{ dashl ();
  return Qnil;
}

static VALUE rb_dashm (VALUE self)
{ dashm ();
  return Qnil;
}

static VALUE rb_dbffin (VALUE self)
{ dbffin ();
  return Qnil;
}

static VALUE rb_dbfini (VALUE self)
{ int i;
  i = dbfini ();
  return INT2NUM (i);
}

static VALUE rb_dbfmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  dbfmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_delglb (VALUE self)
{ delglb ();
  return Qnil;
}

static VALUE rb_digits (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  digits (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_disalf (VALUE self)
{ disalf ();
  return Qnil;
}

static VALUE rb_disenv (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  disenv (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_disfin (VALUE self)
{ disfin ();
  return Qnil;
}

static VALUE rb_disini (VALUE self)
{ disini ();
  nspline = 200;
  imgopt = 0;
  return Qnil;
}

static VALUE rb_disk3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE i1, VALUE i2)
{ disk3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_doevnt (VALUE self)
{ doevnt ();
  return Qnil;
}

static VALUE rb_dot (VALUE self)
{ dot ();
  return Qnil;
}

static VALUE rb_dotl (VALUE self)
{ dotl ();
  return Qnil;
}

static VALUE rb_duplx (VALUE self)
{ duplx ();
  return Qnil;
}

static VALUE rb_dwgbut (VALUE self, VALUE s1, VALUE i1)
{ int i;
  Check_Type (s1, T_STRING);
  i = dwgbut (StringValueCStr (s1), NUM2INT (i1));
  return INT2NUM (i);
}

static VALUE rb_dwgerr (VALUE self)
{ int i;
  i = dwgerr ();
  return INT2NUM (i);
}

static VALUE rb_dwgfil (VALUE self, VALUE s1, VALUE s2, VALUE s3)
{ VALUE str;
  char *p;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  p = dwgfil (StringValueCStr (s1), StringValueCStr (s2), 
              StringValueCStr (s3));
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_dwglis (VALUE self, VALUE s1, VALUE s2, VALUE i1)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  i = dwglis (StringValueCStr (s1), StringValueCStr (s2), NUM2INT (i1));
  return INT2NUM (i);
}

static VALUE rb_dwgmsg (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  dwgmsg (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_dwgtxt (VALUE self, VALUE s1, VALUE s2)
{ VALUE str;
  char *p;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  p = dwgtxt (StringValueCStr (s1), StringValueCStr (s2)); 
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_ellips (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ ellips (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_endgrf (VALUE self)
{ endgrf ();
  return Qnil;
}

static VALUE rb_erase (VALUE self)
{ erase ();
  return Qnil;
}

static VALUE rb_errbar (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                       VALUE arr4, VALUE n1)
{ int n;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    errbar (p1, p2, p3, p4, n);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_errdev (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  errdev (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_errfil (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  errfil (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_errmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  errmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_eushft (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  eushft (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_expimg (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  expimg (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_expzlb (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  expzlb (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_fbars (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                       VALUE arr4, VALUE arr5, VALUE n1)
{ int n;
  double *p1, *p2, *p3, *p4, *p5;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = dbl_array (arr5, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL) 
    fbars (p1, p2, p3, p4, p5, n);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  return Qnil;
}

static VALUE rb_fcha (VALUE self, VALUE x, VALUE i)
{ char s[41];
  fcha (NUM2DBL (x), NUM2INT (i), s);
  return rb_str_new2 (s);
}

static VALUE rb_field (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                       VALUE arr4, VALUE i1, VALUE i2)
{ int n;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    field (p1, p2, p3, p4, n, NUM2INT (i2));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_field3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                       VALUE arr4, VALUE arr5, VALUE arr6, VALUE i1, VALUE i2)
{ int n;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  n = NUM2INT (i1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = dbl_array (arr5, n);
  p6 = dbl_array (arr6, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
    field3d (p1, p2, p3, p4, p5, p6, n, NUM2INT (i2));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_filbox (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ filbox (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_filclr (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  filclr (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_filmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  filmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_filopt (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  filopt (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_filsiz (VALUE self, VALUE s)
{ VALUE arr;
  int i1, i2, i3;
  Check_Type (s, T_STRING);
  i3 = filsiz (StringValueCStr (s), &i1, &i2); 
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_filtyp (VALUE self, VALUE s)
{ int i1;
  Check_Type (s, T_STRING);
  i1 = filtyp (StringValueCStr (s)); 
  return INT2NUM (i1);
}

static VALUE rb_filwin (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ filwin (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_fitscls (VALUE self)
{ fitscls ();
  return Qnil;
}

static VALUE rb_fitsflt (VALUE self, VALUE s)
{ double x;
  Check_Type (s, T_STRING);
  x = fitsflt (StringValueCStr (s)); 
  return rb_float_new (x);
}

static VALUE rb_fitshdu (VALUE self, VALUE i)
{ int n;
  n = fitshdu (NUM2INT (i));
  return INT2NUM (n);
}

static VALUE rb_fitsimg (VALUE self)
{ VALUE str;
  char *p;
  int n;

  n = fitsimg (NULL, 0);

  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  n = fitsimg ((unsigned char *) p, n);
  str = rb_str_new (p, n);
  free (p);
  return str;
}

static VALUE rb_fitsopn (VALUE self, VALUE s)
{ int i1;
  Check_Type (s, T_STRING);
  i1 = fitsopn (StringValueCStr (s)); 
  return INT2NUM (i1);
}

static VALUE rb_fitsstr (VALUE self, VALUE s)
{ VALUE str;
  char p[257];

  Check_Type (s, T_STRING);
  fitsstr (StringValueCStr (s), p, 257); 
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_fitstyp (VALUE self, VALUE s)
{ int i1;
  Check_Type (s, T_STRING);
  i1 = fitstyp (StringValueCStr (s)); 
  return INT2NUM (i1);
}

static VALUE rb_fitsval (VALUE self, VALUE s)
{ int i1;
  Check_Type (s, T_STRING);
  i1 = fitsval (StringValueCStr (s)); 
  return INT2NUM (i1);
}

static VALUE rb_fixspc (VALUE self, VALUE x)
{ fixspc (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_flab3d (VALUE self)
{ flab3d ();
  return Qnil;
}

static VALUE rb_flen (VALUE self, VALUE x, VALUE i)
{ int nl;
  nl = flen (NUM2DBL (x), NUM2INT (i));
  return INT2NUM (nl);
}

static VALUE rb_frame (VALUE self, VALUE n)
{ frame (NUM2INT (n));
  return Qnil;
}

static VALUE rb_frmclr (VALUE self, VALUE n)
{ frmclr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_frmbar (VALUE self, VALUE n)
{ frmbar (NUM2INT (n));
  return Qnil;
}

static VALUE rb_frmess (VALUE self, VALUE n)
{ frmess (NUM2INT (n));
  return Qnil;
}

static VALUE rb_gapcrv (VALUE self, VALUE x)
{ gapcrv (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_gapsiz (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  gapsiz (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_gaxpar (VALUE self, VALUE v1, VALUE v2, VALUE s1, VALUE s2)
{ VALUE arr;
  int ndig;
  double x1, x2, x3, x4;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  gaxpar (NUM2DBL (v1), NUM2DBL (v2), StringValueCStr (s1), 
                   StringValueCStr (s2), &x1, &x2, &x3, &x4, &ndig);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (x1));
  rb_ary_push (arr, rb_float_new (x2));
  rb_ary_push (arr, rb_float_new (x3));
  rb_ary_push (arr, rb_float_new (x4));
  rb_ary_push (arr, INT2NUM (ndig));
  return arr;
}

static VALUE rb_getalf (VALUE self)
{ VALUE str;
  char *p;
  p = getalf ();
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getang (VALUE self)
{ int i;
  i = getang ();
  return INT2NUM (i);
}

static VALUE rb_getbpp (VALUE self)
{ int i;
  i = getbpp ();
  return INT2NUM (i);
}

static VALUE rb_getclp (VALUE self)
{ VALUE arr;
  int i1, i2, i3, i4;
  getclp (&i1, &i2, &i3, &i4);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  rb_ary_push (arr, INT2NUM (i4));
  return arr;
}

static VALUE rb_getclr (VALUE self)
{ int i;
  i = getclr ();
  return INT2NUM (i);
}

static VALUE rb_getdig (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getdig (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getdsp (VALUE self)
{ VALUE str;
  char *p;
  p = getdsp ();
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getfil (VALUE self)
{ VALUE str;
  char *p;
  p = getfil ();
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getgrf (VALUE self, VALUE s)
{ VALUE arr;
  double x1, x2, x3, x4;
  Check_Type (s, T_STRING);
  getgrf (&x1, &x2, &x3, &x4, StringValueCStr (s));
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (x1));
  rb_ary_push (arr, rb_float_new (x2));
  rb_ary_push (arr, rb_float_new (x3));
  rb_ary_push (arr, rb_float_new (x4));
  return arr;
}

static VALUE rb_gethgt (VALUE self)
{ int i;
  i = gethgt ();
  return INT2NUM (i);
}

static VALUE rb_gethnm (VALUE self)
{ int i;
  i = gethnm ();
  return INT2NUM (i);
}

static VALUE rb_getico (VALUE self, VALUE x1, VALUE x2)
{ VALUE arr;
  double xp, yp;
  getico (NUM2DBL (x1), NUM2DBL (x2), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_getind (VALUE self, VALUE i)
{ VALUE arr;
  double x1, x2, x3;
  getind (NUM2INT (i), &x1, &x2, &x3);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (x1));
  rb_ary_push (arr, rb_float_new (x2));
  rb_ary_push (arr, rb_float_new (x3));
  return arr;
}

static VALUE rb_getlab (VALUE self)
{ VALUE arr;
  char s1[9], s2[9], s3[9];
  getlab (s1, s2, s3);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_str_new2 (s1));
  rb_ary_push (arr, rb_str_new2 (s2));
  rb_ary_push (arr, rb_str_new2 (s3));
  return arr;
}

static VALUE rb_getlen (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getlen (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getlev (VALUE self)
{ int i;
  i = getlev ();
  return INT2NUM (i);
}

static VALUE rb_getlin (VALUE self)
{ int i;
  i = getlin ();
  return INT2NUM (i);
}

static VALUE rb_getlit (VALUE self, VALUE x1, VALUE x2, VALUE x3, 
                        VALUE x4, VALUE x5, VALUE x6)
{ int i;
  i = getlit (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), 
              NUM2DBL (x4), NUM2DBL (x5), NUM2DBL (x6));
  return INT2NUM (i);
}

static VALUE rb_getmat (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1, VALUE arr4, VALUE n2, VALUE n3,
                        VALUE x1)
{ int n, nx, ny, *p5;
  double *p1, *p2, *p3, *p4, *p6;

  n = NUM2INT (n1);
  nx = NUM2INT (n2);
  ny = NUM2INT (n3);

  p5 = (int *) calloc (nx * ny, sizeof (int));
  if (p5 == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  p6 = (double *) calloc (nx * ny, sizeof (double));
  if (p6 == NULL)
  { rb_warn ("not enough memory!");
    free (p5);
    return Qnil;
  }
  
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_matrix (arr4, nx, ny);

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  { getmat (p1, p2, p3, n, p4, nx, ny, NUM2DBL (x1), p5, p6);
    copy_dblarray (p4, arr4, nx * ny);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_getmfl (VALUE self)
{ VALUE str;
  char *p;
  p = getmfl ();
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getmix (VALUE self, VALUE s)
{ VALUE str;
  char *p;
  Check_Type (s, T_STRING);
  p = getmix (StringValueCStr (s));
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getor (VALUE self)
{ VALUE arr;
  int i1, i2;
  getor (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getpag (VALUE self)
{ VALUE arr;
  int i1, i2;
  getpag (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getpat (VALUE self)
{ int i;
  i = (int) getpat ();
  return INT2NUM (i);
}

static VALUE rb_getplv (VALUE self)
{ int i;
  i = getplv ();
  return INT2NUM (i);
}

static VALUE rb_getpos (VALUE self)
{ VALUE arr;
  int i1, i2;
  getpos (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getran (VALUE self)
{ VALUE arr;
  int i1, i2;
  getran (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getrco (VALUE self, VALUE x1, VALUE x2)
{ VALUE arr;
  double xp, yp;
  getrco (NUM2DBL (x1), NUM2DBL (x2), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_getres (VALUE self)
{ VALUE arr;
  int i1, i2;
  getres (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getrgb (VALUE self)
{ VALUE arr;
  double x1, x2, x3;
  getrgb (&x1, &x2, &x3);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (x1));
  rb_ary_push (arr, rb_float_new (x2));
  rb_ary_push (arr, rb_float_new (x3));
  return arr;
}

static VALUE rb_getscl (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getscl (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getscm (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getscm (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getscr (VALUE self)
{ VALUE arr;
  int i1, i2;
  getscr (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_getshf (VALUE self, VALUE s)
{ VALUE str;
  char *p;
  Check_Type (s, T_STRING);
  p = getshf (StringValueCStr (s));
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getsp1 (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getsp1 (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getsp2 (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getsp2 (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getsym (VALUE self)
{ VALUE arr;
  int i1, i2;
  getsym (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_gettcl (VALUE self)
{ VALUE arr;
  int i1, i2;
  gettcl (&i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_gettic (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  gettic (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_gettyp (VALUE self)
{ int i;
  i = gettyp ();
  return INT2NUM (i);
}

static VALUE rb_getuni (VALUE self)
{ FILE *fp;
  fp = getuni ();
  if (fp == NULL)
    return INT2NUM (0);
  else
    return INT2NUM (6);
}

static VALUE rb_getver (VALUE self)
{ double x;
  x = getver ();
  return rb_float_new (x);
}

static VALUE rb_getvk (VALUE self)
{ VALUE arr;
  int i1, i2, i3;
  getvk (&i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_getvlt (VALUE self)
{ VALUE str;
  char *p;
  p = getvlt ();
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_getwid (VALUE self)
{ int i;
  i = getwid ();
  return INT2NUM (i);
}

static VALUE rb_getwin (VALUE self)
{ VALUE arr;
  int i1, i2, i3, i4;
  getwin (&i1, &i2, &i3, &i4);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  rb_ary_push (arr, INT2NUM (i4));
  return arr;
}

static VALUE rb_getxid (VALUE self, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = getxid (StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_gifmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  gifmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_gmxalf (VALUE self, VALUE s)
{ VALUE arr;
  int n;
  char s1[2], s2[2];
  Check_Type (s, T_STRING);
  n = gmxalf (StringValueCStr (s), s1, s2);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_str_new2 (s1));
  rb_ary_push (arr, rb_str_new2 (s2));
  rb_ary_push (arr, NUM2INT (n));
  return arr;
}

static VALUE rb_gothic (VALUE self)
{ gothic ();
  return Qnil;
}

static VALUE rb_grace (VALUE self, VALUE n)
{ grace (NUM2INT (n));
  return Qnil;
}

static VALUE rb_graf (VALUE self, VALUE xa, VALUE xe, VALUE xor, VALUE xstp,
                      VALUE ya, VALUE ye, VALUE yor, VALUE ystp)
{ graf (NUM2DBL (xa), NUM2DBL (xe), NUM2DBL (xor), NUM2DBL (xstp),
        NUM2DBL (ya), NUM2DBL (ye), NUM2DBL (yor), NUM2DBL (ystp));
  return Qnil;
}

static VALUE rb_graf3 (VALUE self, VALUE xa, VALUE xe, VALUE xor, VALUE xstp,
		       VALUE ya, VALUE ye, VALUE yor, VALUE ystp,
                       VALUE za, VALUE ze, VALUE zor, VALUE zstp)
{ graf3 (NUM2DBL (xa), NUM2DBL (xe), NUM2DBL (xor), NUM2DBL (xstp),
         NUM2DBL (ya), NUM2DBL (ye), NUM2DBL (yor), NUM2DBL (ystp),
         NUM2DBL (za), NUM2DBL (ze), NUM2DBL (zor), NUM2DBL (zstp));
  return Qnil;
}

static VALUE rb_graf3d (VALUE self, VALUE xa, VALUE xe, VALUE xor, VALUE xstp,
		        VALUE ya, VALUE ye, VALUE yor, VALUE ystp,
                        VALUE za, VALUE ze, VALUE zor, VALUE zstp)
{ graf3d (NUM2DBL (xa), NUM2DBL (xe), NUM2DBL (xor), NUM2DBL (xstp),
          NUM2DBL (ya), NUM2DBL (ye), NUM2DBL (yor), NUM2DBL (ystp),
          NUM2DBL (za), NUM2DBL (ze), NUM2DBL (zor), NUM2DBL (zstp));
  return Qnil;
}

static VALUE rb_grafmp (VALUE self, VALUE xa, VALUE xe, VALUE xor, VALUE xstp,
                      VALUE ya, VALUE ye, VALUE yor, VALUE ystp)
{ grafmp (NUM2DBL (xa), NUM2DBL (xe), NUM2DBL (xor), NUM2DBL (xstp),
        NUM2DBL (ya), NUM2DBL (ye), NUM2DBL (yor), NUM2DBL (ystp));
  return Qnil;
}

static VALUE rb_grafp (VALUE self, VALUE xe, VALUE xorg, VALUE xstp,
                      VALUE yorg, VALUE ystp)
{ grafp (NUM2DBL (xe), NUM2DBL (xorg), NUM2DBL (xstp),
         NUM2DBL (yorg), NUM2DBL (ystp));
  return Qnil;
}

static VALUE rb_grafr (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, VALUE i2)
{ int n1, n2;
  double *p1, *p2;

  n1 = NUM2INT (i1);
  n2 = NUM2INT (i2);
  p1 = dbl_array (arr1, n1);
  p2 = dbl_array (arr2, n2);
  if (p1 != NULL && p2 != NULL) grafr (p1, n1, p2, n2);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_grdpol (VALUE self, VALUE i1, VALUE i2)
{ grdpol (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_grffin (VALUE self)
{ grffin ();
  return Qnil;
}

static VALUE rb_grfimg (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  grfimg (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_grfini (VALUE self, VALUE x1, VALUE x2, VALUE x3,
                        VALUE x4, VALUE x5, VALUE x6,
                        VALUE x7, VALUE x8, VALUE x9)
{ grfini (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3),
          NUM2DBL (x4), NUM2DBL (x5), NUM2DBL (x6),
          NUM2DBL (x7), NUM2DBL (x8), NUM2DBL (x9));
  return Qnil;
}

static VALUE rb_grid (VALUE self, VALUE i1, VALUE i2)
{ grid (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_grid3d (VALUE self, VALUE i1, VALUE i2, VALUE s)
{ Check_Type (s, T_STRING);
  grid3d (NUM2INT (i1), NUM2INT (i2), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_gridim (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE i1)
{ gridim (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_gridmp (VALUE self, VALUE i1, VALUE i2)
{ gridmp (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_gridre (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE i1)
{ gridre (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_gwgatt (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = gwgatt (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_gwgbox (VALUE self, VALUE n)
{ int i;
  i = gwgbox (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_gwgbut (VALUE self, VALUE n)
{ int i;
  i = gwgbut (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_gwgfil (VALUE self, VALUE i)
{ VALUE str;
  char p[257];
  gwgfil (NUM2INT (i), p);
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_gwgflt (VALUE self, VALUE i)
{ double x;
  x = gwgflt (NUM2INT (i));
  return rb_float_new (x);
}

static VALUE rb_gwggui (VALUE self)
{ int i;
  i = gwggui ();
  return INT2NUM (i);
}

static VALUE rb_gwgint (VALUE self, VALUE n)
{ int i;
  i = gwgint (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_gwglis (VALUE self, VALUE n)
{ int i;
  i = gwglis (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_gwgscl (VALUE self, VALUE i)
{ double x;
  x = gwgscl (NUM2INT (i));
  return rb_float_new (x);
}

static VALUE rb_gwgsiz (VALUE self, VALUE i)
{ VALUE arr;
  int i1, i2;
  gwgsiz (NUM2INT (i), &i1, &i2);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  return arr;
}

static VALUE rb_gwgtbf (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ double x;
  x = gwgtbf (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return rb_float_new (x);
}

static VALUE rb_gwgtbi (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ int i;
  i = gwgtbi (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return INT2NUM (i);
}

static VALUE rb_gwgtbl (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE s1)
{ VALUE arr;
  int i, n;
  double *p;
  
  n = NUM2INT (i2);
  Check_Type (s1, T_STRING);

  p = (double *) calloc (n, sizeof (double));
  if (p == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  gwgtbl (NUM2INT (i1), p, n, NUM2INT (i3), StringValueCStr (s1));
  arr = rb_ary_new ();
  for (i = 0; i < n; i++)
    rb_ary_push (arr, rb_float_new (p[i]));
  free (p);
  return arr;
}

static VALUE rb_gwgtbs (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ VALUE str;
  char p[257];
  gwgtbs (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), p);
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_gwgtxt (VALUE self, VALUE i)
{ VALUE str;
  char p[257];
  gwgtxt (NUM2INT (i), p);
  str = rb_str_new2 (p);
  return str;
}

static VALUE rb_gwgxid (VALUE self, VALUE n)
{ int i;
  i = gwgxid (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_height (VALUE self, VALUE n)
{ height (NUM2INT (n));
  return Qnil;
}

static VALUE rb_helve (VALUE self)
{ helve ();
  return Qnil;
}

static VALUE rb_helves (VALUE self)
{ helves ();
  return Qnil;
}

static VALUE rb_helvet (VALUE self)
{ helvet ();
  return Qnil;
}


static VALUE rb_hidwin (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  hidwin (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_histog (VALUE self, VALUE arr1, VALUE n1,
                        VALUE arr2, VALUE arr3)
{ int n, np;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  {  histog (p1, n, p2, p3, &np);
     copy_dblarray (p2, arr2, np);
     copy_dblarray (p3, arr3, np);
  }
  free (p1);
  free (p2);
  free (p3);
  return INT2NUM (np);
}

static VALUE rb_hname (VALUE self, VALUE n)
{ hname (NUM2INT (n));
  return Qnil;
}

static VALUE rb_hpgmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  hpgmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_hsvrgb (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ VALUE arr;
  double xr, xg, xb;
  hsvrgb (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), &xr, &xg, &xb);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xr));
  rb_ary_push (arr, rb_float_new (xg));
  rb_ary_push (arr, rb_float_new (xb));
  return arr;
}

static VALUE rb_hsym3d (VALUE self, VALUE x)
{ hsym3d (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_hsymbl (VALUE self, VALUE n)
{ hsymbl (NUM2INT (n));
  return Qnil;
}

static VALUE rb_htitle (VALUE self, VALUE n)
{ htitle (NUM2INT (n));
  return Qnil;
}

static VALUE rb_hwfont (VALUE self)
{ hwfont ();
  return Qnil;
}

static VALUE rb_hwmode (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  hwmode (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_hworig (VALUE self, VALUE i1, VALUE i2)
{ hworig (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_hwpage (VALUE self, VALUE i1, VALUE i2)
{ hwpage (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_hwscal (VALUE self, VALUE x)
{ hwscal (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_imgbox (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ imgbox (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_imgclp (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ imgclp (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_imgfin (VALUE self)
{ imgfin ();
  return Qnil;
}

static VALUE rb_imgfmt (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  imgfmt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_imgini (VALUE self)
{ imgini ();
  return Qnil;
}

static VALUE rb_imgmod (VALUE self, VALUE s1)
{ char *s;
  Check_Type (s1, T_STRING);
  s = StringValueCStr (s1);
  if ((s[0] == 'R' || s[0] == 'r') &&
      (s[1] == 'G' || s[1] == 'g') &&
      (s[2] == 'B' || s[2] == 'b'))
    imgopt = 1;
  else
    imgopt = 0;

  imgmod (s);
  return Qnil;
}

static VALUE rb_imgsiz (VALUE self, VALUE i1, VALUE i2)
{ imgsiz (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_imgtpr (VALUE self, VALUE n)
{ imgtpr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_inccrv (VALUE self, VALUE n)
{ inccrv (NUM2INT (n));
  return Qnil;
}

static VALUE rb_incdat (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ int i;
  i = incdat (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return INT2NUM (i);
}

static VALUE rb_incfil (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  incfil (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_incmrk (VALUE self, VALUE n)
{ incmrk (NUM2INT (n));
  return Qnil;
}

static VALUE rb_indrgb (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ int i;
  i = indrgb (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return INT2NUM (i);
}

static VALUE rb_intax (VALUE self)
{ intax ();
  return Qnil;
}

static VALUE rb_intcha (VALUE self, VALUE i1)
{ char p[81];

  intcha (NUM2INT (i1), p);
  return rb_str_new2 (p);
}

static VALUE rb_intlen (VALUE self, VALUE n)
{ int i;
  i = intlen (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_intrgb (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ int i;
  i = intrgb (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return INT2NUM (i);
}

static VALUE rb_intutf (VALUE self, VALUE arr1, VALUE i1)
{ VALUE str;
  int n;
  int *p1;
  char *p;

  n = NUM2INT (i1);
  p1 = int_array (arr1, n);
  p = (char *) malloc (n * 4 + 1);
  if (p == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  intutf (p1, n, p, n * 4);
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_isopts (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE i3, 
                        VALUE arr4, VALUE x, VALUE arr5, VALUE arr6, 
                        VALUE arr7, VALUE i4)
{ int nx, ny, nz, nmax, ntri;
  double *p1, *p2, *p3, *p4, *p5, *p6, *p7;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  nz = NUM2INT (i3);
  nmax = NUM2INT (i4);

  p1 = dbl_array (arr1, nx);
  p2 = dbl_array (arr2, ny);
  p3 = dbl_array (arr3, nz);
  p4 = dbl_matrix3 (arr4, nx, ny, nz);
  p5 = dbl_array (arr5, nmax);
  p6 = dbl_array (arr6, nmax);
  p7 = dbl_array (arr7, nmax);

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL &&
      p5 != NULL && p6 != NULL && p7 != NULL) 
  { isopts (p1, nx, p2, ny, p3, nz, p4, NUM2DBL (x), p5, p6, p7, nmax, &ntri);
    copy_dblarray (p5, arr5, ntri);
    copy_dblarray (p6, arr6, ntri);
    copy_dblarray (p7, arr7, ntri);
  }

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  return INT2NUM (ntri);
}

static VALUE rb_itmcat (VALUE self, VALUE s1, VALUE s2)
{ int n1, n2;
  char *p;
  VALUE str;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  n1 = trmlen (StringValueCStr (s1));
  n2 = trmlen (StringValueCStr (s2));
  p = (char *) malloc (n1 + n2 + 2);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }
 
  strcpy (p, StringValueCStr (s1));
  itmcat (p, StringValueCStr (s2));
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_itmncat (VALUE self, VALUE s1, VALUE i1, VALUE s2)
{ int n1, n2, n, nmx;
  char *p;
  VALUE str;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  n1 = trmlen (StringValueCStr (s1));
  n2 = trmlen (StringValueCStr (s2));
  n = n1 + n2 + 2;
  nmx = NUM2INT (i1);
  if (n > nmx) n = nmx;
  p = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }
 
  strcpy (p, StringValueCStr (s1));
  itmncat (p, nmx, StringValueCStr (s2));
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_itmcnt (VALUE self, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = itmcnt (StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_itmstr (VALUE self, VALUE s, VALUE i)
{ char *p;
  VALUE str;

  Check_Type (s, T_STRING);
  p = itmstr (StringValueCStr (s), NUM2INT (i));
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_jusbar (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  jusbar (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_labclr (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  labclr (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_labdig (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  labdig (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_labdis (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  labdis (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_labels (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  labels (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_labjus (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  labjus (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_labl3d (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  labl3d (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_labmod (VALUE self, VALUE s1, VALUE s2, VALUE s3)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  labmod (StringValueCStr (s1), StringValueCStr (s2), StringValueCStr (s3));
  return Qnil;
}

static VALUE rb_labpos (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  labpos (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_labtyp (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  labtyp (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_legbgd (VALUE self, VALUE n)
{ legbgd (NUM2INT (n));
  return Qnil;
}

static VALUE rb_legclr (VALUE self)
{ legclr ();
  return Qnil;
}

static VALUE rb_legend (VALUE self, VALUE s, VALUE i1)
{ legend (clegbf, NUM2INT (i1));
  return Qnil;
}

static VALUE rb_legini (VALUE self, VALUE s, VALUE i1, VALUE i2)
{ int nlin, nmaxln;

  nlin = NUM2INT (i1);
  nmaxln = NUM2INT (i2);
  if (clegbf != NULL) free (clegbf);
  clegbf = (char *) malloc (nlin * nmaxln + 1);
  if (clegbf == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }
  legini (clegbf, nlin, nmaxln);
  return Qnil;
}

static VALUE rb_leglin (VALUE self, VALUE s1, VALUE s2, VALUE i1)
{
  Check_Type (s2, T_STRING);
  leglin (clegbf, StringValueCStr (s2), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_legopt (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ legopt (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_legpat (VALUE self, VALUE i1, VALUE i2, VALUE i3, 
                        VALUE i4, VALUE i5, VALUE i6)
{ legpat (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
          (long) NUM2INT (i5), NUM2INT (i6));
  return Qnil;
}

static VALUE rb_legpos (VALUE self, VALUE i1, VALUE i2)
{ legpos (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_legsel (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  int *p1;

  n = NUM2INT (n1);
  if (n > 0) p1 = int_array (arr1, n);
  if (p1 != NULL || n < 1) legsel (p1, n);
  if (n > 0) free (p1);
  return Qnil;
}

static VALUE rb_legtbl (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  legtbl (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_legtit (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  legtit (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_legtyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  legtyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_legval (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  legval (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_lfttit (VALUE self)
{ lfttit ();
  return Qnil;
}

static VALUE rb_licmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  licmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_licpts (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE i2, VALUE arr3, VALUE arr4)
{ double *p1, *p2, *p4;
  int nx, ny, *p3, *p5; 

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);

  p5 = (int *) calloc ( nx * ny, sizeof (int));
  if (p5 == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  p1 = dbl_matrix (arr1, nx, ny);
  p2 = dbl_matrix (arr2, nx, ny);
  p3 = int_matrix (arr3, nx, ny);
  p4 = dbl_matrix (arr4, nx, ny);

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL)
  { licpts (p1, p2, nx, ny, p3, p5, p4);
    copy_dblarray (p4, arr4, nx * ny);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  return Qnil;
}

static VALUE rb_light (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  light (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_linclr (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  int *p1;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  if (p1 != NULL) linclr (p1, n);
  free (p1);
  return Qnil;
}

static VALUE rb_lincyc (VALUE self, VALUE i1, VALUE i2)
{ lincyc (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_line (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ line (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_linesp (VALUE self, VALUE x)
{ linesp (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_linfit (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE s1)
{ int n;
  double *p1, *p2;
  double a, b, r;
  VALUE arr;
  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) linfit (p1, p2, n, &a, &b, &r, 
         StringValueCStr (s1));
  free (p1);
  free (p2);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (a));
  rb_ary_push (arr, rb_float_new (b));
  rb_ary_push (arr, rb_float_new (r));
  return arr;
}

static VALUE rb_linmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  linmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_lintyp (VALUE self, VALUE n)
{ lintyp (NUM2INT (n));
  return Qnil;
}

static VALUE rb_linwid (VALUE self, VALUE n)
{ linwid (NUM2INT (n));
  return Qnil;
}

static VALUE rb_litmod (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  litmod (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_litop3 (VALUE self, VALUE i, VALUE x1, VALUE x2, VALUE x3,
                        VALUE s)
{ Check_Type (s, T_STRING);
  litop3 (NUM2INT (i), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3),
          StringValueCStr (s));
  return Qnil;
}

static VALUE rb_litopt (VALUE self, VALUE i, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  litopt (NUM2INT (i), NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_litpos (VALUE self, VALUE i, VALUE x1, VALUE x2, VALUE x3,
                        VALUE s)
{ Check_Type (s, T_STRING);
  litpos (NUM2INT (i), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3),
          StringValueCStr (s));
  return Qnil;
}

static VALUE rb_lncap (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  lncap (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_lnjoin (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  lnjoin (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_lnmlt (VALUE self, VALUE x)
{ lnmlt (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_logtic (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  logtic (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mapbas (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  mapbas (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mapfil (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  mapfil (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_mapimg (VALUE self, VALUE s, VALUE x1, VALUE x2, VALUE x3,
                        VALUE x4, VALUE x5, VALUE x6)
{ Check_Type (s, T_STRING);
  mapimg (StringValueCStr (s), NUM2INT (x1), NUM2DBL (x2), NUM2DBL (x3), 
          NUM2DBL (x4),  NUM2DBL (x5), NUM2DBL (x6));
  return Qnil;
}

static VALUE rb_maplab (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  maplab (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_maplev (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  maplev (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mapmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  mapmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mappol (VALUE self, VALUE x1, VALUE x2)
{ mappol (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_mapopt (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  mapopt (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_mapref (VALUE self, VALUE x1, VALUE x2)
{ mapref (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_mapsph (VALUE self, VALUE x)
{ 
  mapsph (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_marker (VALUE self, VALUE n)
{ marker (NUM2INT (n));
  return Qnil;
}

static VALUE rb_matop3 (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE s)
{ Check_Type (s, T_STRING);
  matop3 (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_matopt (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  matopt (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mdfmat (VALUE self, VALUE i1, VALUE i2, VALUE x)
{ mdfmat (NUM2INT (i1), NUM2INT (i2), NUM2DBL (x));
  return Qnil;
}

static VALUE rb_messag (VALUE self, VALUE s, VALUE nx, VALUE ny)
{ Check_Type (s, T_STRING);
  messag (StringValueCStr (s), NUM2INT (nx), NUM2INT (ny));
  return Qnil;
}

static VALUE rb_metafl (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  metafl (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mixalf (VALUE self)
{ mixalf ();
  return Qnil;
}

static VALUE rb_mixleg (VALUE self)
{ mixleg ();
  return Qnil;
}

static VALUE rb_mpaepl (VALUE self, VALUE n)
{ mpaepl (NUM2INT (n));
  return Qnil;
}

static VALUE rb_mplang (VALUE self, VALUE x)
{ mplang (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_mplclr (VALUE self, VALUE i1, VALUE i2)
{ mplclr (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_mplpos (VALUE self, VALUE i1, VALUE i2)
{ mplpos (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_mplsiz (VALUE self, VALUE n)
{ mplsiz (NUM2INT (n));
  return Qnil;
}

static VALUE rb_mpslogo (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE s)
{ Check_Type (s, T_STRING);
  mpslogo (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mrkclr (VALUE self, VALUE n)
{ mrkclr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_msgbox (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  msgbox (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_mshclr (VALUE self, VALUE n)
{ mshclr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_mshcrv (VALUE self, VALUE n)
{ mshcrv (NUM2INT (n));
  return Qnil;
}

static VALUE rb_mylab (VALUE self, VALUE s1, VALUE i, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  mylab (StringValueCStr (s1), NUM2INT (i), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_myline (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  int *p1;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  if (p1 != NULL) myline (p1, n);
  free (p1);
  return Qnil;
}

static VALUE rb_mypat (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ mypat (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_mysymb (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE i2, VALUE i3)
{ int n;
  double *p1, *p2;

  n = NUM2INT (i1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) 
    mysymb (p1, p2, n, NUM2INT (i2), NUM2INT (i3));
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_myvlt (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1)
{ int n;
  double *p1, *p2, *p3;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) myvlt (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_namdis (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  namdis (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_name (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  name (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_namjus (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  namjus (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_nancrv (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  sclmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_neglog (VALUE self, VALUE x)
{ neglog (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_newmix (VALUE self)
{ newmix ();
  return Qnil;
}

static VALUE rb_newpag (VALUE self)
{ newpag ();
  return Qnil;
}

static VALUE rb_nlmess (VALUE self, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = nlmess (StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_nlnumb (VALUE self, VALUE x, VALUE n)
{ int i;

  i = nlnumb (NUM2DBL (x), NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_noarln (VALUE self)
{ noarln ();
  return Qnil;
}

static VALUE rb_nobar (VALUE self)
{ nobar ();
  return Qnil;
}

static VALUE rb_nobgd (VALUE self)
{ nobgd ();
  return Qnil;
}

static VALUE rb_nochek (VALUE self)
{ nochek ();
  return Qnil;
}

static VALUE rb_noclip (VALUE self)
{ noclip ();
  return Qnil;
}

static VALUE rb_nofill (VALUE self)
{ nofill ();
  return Qnil;
}

static VALUE rb_nograf (VALUE self)
{ nograf ();
  return Qnil;
}

static VALUE rb_nohide (VALUE self)
{ nohide ();
  return Qnil;
}

static VALUE rb_noline (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  noline (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_number (VALUE self, VALUE x, VALUE i1, VALUE i2, VALUE i3)
{ number (NUM2DBL (x), NUM2INT (i1), NUM2INT (i2),  NUM2INT (i3));
  return Qnil;
}

static VALUE rb_numfmt (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  numfmt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_numode (VALUE self, VALUE s1, VALUE s2, VALUE s3, VALUE s4)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  Check_Type (s4, T_STRING);
  numode (StringValueCStr (s1), StringValueCStr (s2),
          StringValueCStr (s3), StringValueCStr (s4));
  return Qnil;
}

static VALUE rb_nwkday (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ int i;
  i = nwkday (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return INT2NUM (i);
}

static VALUE rb_nxlegn (VALUE self, VALUE s)
{ int i;
  i = nxlegn (clegbf);
  return INT2NUM (i);
}

static VALUE rb_nxpixl (VALUE self, VALUE i1, VALUE i2)
{ int i;
  i = nxpixl (NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_nxposn (VALUE self, VALUE x)
{ int i;
  i = nxposn (NUM2DBL (x));
  return INT2NUM (i);
}

static VALUE rb_nylegn (VALUE self, VALUE s)
{ int i;
  i = nylegn (clegbf);
  return INT2NUM (i);
}

static VALUE rb_nypixl (VALUE self, VALUE i1, VALUE i2)
{ int i;
  i = nypixl (NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_nyposn (VALUE self, VALUE x)
{ int i;
  i = nyposn (NUM2DBL (x));
  return INT2NUM (i);
}

static VALUE rb_nzposn (VALUE self, VALUE x)
{ int i;
  i = nzposn (NUM2DBL (x));
  return INT2NUM (i);
}

static VALUE rb_openfl (VALUE self, VALUE s, VALUE i1, VALUE i2)
{ int i;
  Check_Type (s, T_STRING);
  i = openfl (StringValueCStr (s), NUM2INT (i1), NUM2INT (i2)); 
  return INT2NUM (i);
}

static VALUE rb_opnwin (VALUE self, VALUE n)
{ opnwin (NUM2INT (n));
  return Qnil;
}

static VALUE rb_origin (VALUE self, VALUE i1, VALUE i2)
{ origin (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_page (VALUE self, VALUE i1, VALUE i2)
{ page (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_pagera (VALUE self)
{ pagera ();
  return Qnil;
}

static VALUE rb_pagfll (VALUE self, VALUE n)
{ pagfll (NUM2INT (n));
  return Qnil;
}

static VALUE rb_paghdr (VALUE self, VALUE s1, VALUE s2, VALUE i1, VALUE i2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  paghdr (StringValueCStr (s1), StringValueCStr (s2), 
          NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_pagmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  pagmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pagorg (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  pagorg (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pagwin (VALUE self, VALUE i1, VALUE i2)
{ pagwin (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_patcyc (VALUE self, VALUE i1, VALUE i2)
{ patcyc (NUM2INT (i1), (long) NUM2INT (i2));
  return Qnil;
}

static VALUE rb_pdfbuf (VALUE self)
{ VALUE str;
  char *p;
  int n;

  n = pdfbuf (NULL, 0);

  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  n = pdfbuf (p, n);
  str = rb_str_new (p, n);
  free (p);
  return str;
}

static VALUE rb_pdfmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  pdfmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_pdfmrk (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  pdfmrk (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_penwid (VALUE self, VALUE x)
{ penwid (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_pie (VALUE self, VALUE i1, VALUE i2, VALUE i3,
                     VALUE x1, VALUE x2)
{ pie (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), 
       NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_piebor (VALUE self, VALUE i)
{ piebor (NUM2INT (i));
  return Qnil;
}

static VALUE rb_piecbk (VALUE self, VALUE s1)
{ int n;
  char *p;
  
  Check_Type (s1, T_STRING);
  p = StringValueCStr (s1);
  n = strlen (p);

  if (rbpie != NULL) free (rbpie);
  rbpie = (char *) malloc (n + 1);
  if (rbpie == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rbpie, p);
  piecbk (dis_piecbk);
  return Qnil;
}

void dis_piecbk (int iseg, double xdat, double xper, int *nrad,
              int *noff, double *angle, int *nvx, int *nvy, int *idrw, 
              int *iann)
{ VALUE ret, *r;
  int n;
  ret = rb_funcall (Qnil, rb_intern (rbpie), 10, INT2NUM (iseg),  
              rb_float_new (xdat), rb_float_new (xper),
              INT2NUM (*nrad), INT2NUM (*noff), rb_float_new (*angle),
              INT2NUM (*nvx), INT2NUM (*nvy), INT2NUM (*idrw), 
              INT2NUM (*iann));

  Check_Type (ret, T_ARRAY);
  n = RARRAY_LEN (ret);
  if (n != 7) 
  { rb_warn ("wrong number of elements in array!");
    return;
  }

  r  = RARRAY_PTR (ret);
  *nrad  = NUM2INT (r[0]);
  *noff  = NUM2INT (r[1]);
  *angle = NUM2DBL (r[2]);
  *nvx   = NUM2INT (r[3]);
  *nvy   = NUM2INT (r[4]);
  *idrw  = NUM2INT (r[5]);
  *iann  = NUM2INT (r[6]);
  return;
}

static VALUE rb_pieclr (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  int *p1, *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = int_array (arr2, n);
  if (p1 != NULL && p2 != NULL) pieclr (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_pieexp (VALUE self)
{ pieexp ();
  return Qnil;
}

static VALUE rb_piegrf (VALUE self, VALUE s, VALUE i1, VALUE arr1, VALUE i2)
{ int n, nlin;
  double *p1;

  nlin = NUM2INT (i1);
  n = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL)
  { if (nlin == 0)
      piegrf (" ", nlin, p1, n);
    else 
      piegrf (clegbf, nlin, p1, n);
  }
  free (p1);
  return Qnil;
}

static VALUE rb_pielab (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  pielab (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_pieopt (VALUE self, VALUE x1, VALUE x2)
{ pieopt (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_pierot (VALUE self, VALUE x)
{ pierot (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_pietyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  pietyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pieval (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  pieval (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pievec (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  pievec (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pike3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE x7, VALUE i1, VALUE i2)
{ pike3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), NUM2DBL (x7), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_plat3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE s)
{ Check_Type (s, T_STRING);
  plat3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         StringValueCStr (s));
  return Qnil;
}

static VALUE rb_plyfin (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  plyfin (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_plyini (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  plyini (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pngmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  pngmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_point (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                       VALUE i5)
{ point (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4), NUM2INT (i5));
  return Qnil;
}

static VALUE rb_polar (VALUE self, VALUE xe, VALUE xorg, VALUE xstp,
                      VALUE yorg, VALUE ystp)
{ polar (NUM2DBL (xe), NUM2DBL (xorg), NUM2DBL (xstp),
         NUM2DBL (yorg), NUM2DBL (ystp));
  return Qnil;
}

static VALUE rb_polclp (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE arr3, VALUE arr4, VALUE i2, VALUE x1, VALUE s1)
{ int n, maxpts, i = 0;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (11);
  maxpts = NUM2INT (12);
  Check_Type (s1, T_STRING);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, maxpts);
  p4 = dbl_array (arr4, maxpts);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  { i = polclp (p1, p2, n, p3, p4, maxpts, NUM2DBL (x1), 
                StringValueCStr (s1));
    copy_dblarray (p3, arr3, i); 
    copy_dblarray (p4, arr4, i);
  } 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return INT2NUM (i);
}

static VALUE rb_polcrv (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  polcrv (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_polmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING); 
  Check_Type (s2, T_STRING);
  polmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_pos2pt (VALUE self, VALUE x1, VALUE x2)
{ VALUE arr;
  double xp, yp;
  pos2pt (NUM2DBL (x1), NUM2DBL (x2), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_pos3pt (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ VALUE arr;
  double xp, yp, zp;
  pos3pt (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), &xp, &yp, &zp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  rb_ary_push (arr, rb_float_new (zp));
  return arr;
}

static VALUE rb_posbar (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  posbar (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_posifl (VALUE self, VALUE i1, VALUE i2)
{ int i;
  i = posifl (NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_proj3d (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  proj3d (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_projct (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  projct (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_psfont (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  psfont (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_psmeta (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING); 
  Check_Type (s2, T_STRING);
  psmeta (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_psmode (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  psmode (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_pt2pos (VALUE self, VALUE x1, VALUE x2)
{ VALUE arr;
  double xp, yp;
  pt2pos (NUM2DBL (x1), NUM2DBL (x2), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_pyra3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE i1)
{ pyra3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_qplbar (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  double *p1;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) qplbar (p1, n);
  free (p1);
  return Qnil;
}


static VALUE rb_qplcon (VALUE self, VALUE arr1, VALUE i1, VALUE i2, VALUE i3)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) qplcon (p1, n, m, NUM2INT (i3));
  free (p1);
  return Qnil;
}

static VALUE rb_qplclr (VALUE self, VALUE arr1, VALUE i1, VALUE i2)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) qplclr (p1, n, m);
  free (p1);
  return Qnil;
}

static VALUE rb_qplcrv (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE s)
{ int n;
  double *p1, *p2;

  Check_Type (s, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) qplcrv (p1, p2, n, StringValueCStr (s));

  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_qplot (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) qplot (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_qplpie (VALUE self, VALUE arr1, VALUE n1)
{ int n;
  double *p1;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) qplpie (p1, n);
  free (p1);
  return Qnil;
}

static VALUE rb_qplsca (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) qplsca (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_qplscl (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE s)
{ Check_Type (s, T_STRING);
  qplscl (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          StringValueCStr (s));
  return Qnil;
}

static VALUE rb_qplsur (VALUE self, VALUE arr1, VALUE i1, VALUE i2)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) qplsur (p1, n, m);
  free (p1);
  return Qnil;
}

static VALUE rb_quad3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6)
{ quad3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6));
  return Qnil;
}

static VALUE rb_rbfpng (VALUE self)
{ VALUE str;
  char *p;
  int n;

  n = rbfpng (NULL, 0);

  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  n = rbfpng (p, n);
  str = rb_str_new (p, n);
  free (p);
  return str;
}

static VALUE rb_rbmp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rbmp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_readfl (VALUE self, VALUE i1, VALUE i2)
{ VALUE str;
  char *p;
  int n, nn;

  n = NUM2INT (i2);
  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  nn = readfl (NUM2INT (i1), (unsigned char *) p, NUM2INT (i2)); 
  str = rb_str_new (p, nn);
  free (p);
  return str;
}

static VALUE rb_reawgt (VALUE self)
{ reawgt ();
  return Qnil;
}

static VALUE rb_recfll (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                       VALUE i5)
{ recfll (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4), NUM2INT (i5));
  return Qnil;
}

static VALUE rb_rectan (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ rectan (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_rel3pt (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ VALUE arr;
  double xp, yp;
  rel3pt (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), &xp, &yp);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xp));
  rb_ary_push (arr, rb_float_new (yp));
  return arr;
}

static VALUE rb_resatt (VALUE self)
{ resatt ();
  return Qnil;
}

static VALUE rb_reset (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  reset (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_revscr (VALUE self)
{ revscr ();
  return Qnil;
}

static VALUE rb_rgbhsv (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ VALUE arr;
  double xh, xs, xv;
  rgbhsv (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), &xh, &xs, &xv);
  arr = rb_ary_new ();
  rb_ary_push (arr, rb_float_new (xh));
  rb_ary_push (arr, rb_float_new (xs));
  rb_ary_push (arr, rb_float_new (xv));
  return arr;
}

static VALUE rb_rgif (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rgif (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_rgtlab (VALUE self)
{ rgtlab ();
  return Qnil;
}

static VALUE rb_rimage (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rimage (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_rlarc (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE x7)
{ rlarc (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2DBL (x5), NUM2DBL (x6), NUM2DBL (x7));
  return Qnil;
}

static VALUE rb_rlarea (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) rlarea (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_rlcirc (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ rlcirc (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_rlconn (VALUE self, VALUE x1, VALUE x2)
{ rlconn (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_rlell (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4)
{ rlell (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4));
  return Qnil;
}

static VALUE rb_rline (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4)
{ rline (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4));
  return Qnil;
}

static VALUE rb_rlmess (VALUE self, VALUE s1, VALUE x1, VALUE x2)
{ Check_Type (s1, T_STRING);
  rlmess (StringValueCStr (s1), NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_rlnumb (VALUE self, VALUE x1, VALUE i1, VALUE x2, VALUE x3)
{ rlnumb (NUM2DBL (x1), NUM2INT (i1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_rlpie (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                       VALUE x5)
{ rlpie (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4), 
         NUM2DBL (x5));
  return Qnil;
}

static VALUE rb_rlpoin (VALUE self, VALUE x1, VALUE x2, VALUE i1, VALUE i2,
                       VALUE i3)
{ rlpoin (NUM2DBL (x1), NUM2DBL (x2), NUM2INT (i1), NUM2INT (i2), 
          NUM2INT (i3));
  return Qnil;
}

static VALUE rb_rlrec (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4)
{ rlrec (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4));
  return Qnil;
}

static VALUE rb_rlrnd (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                       VALUE i1)
{ rlrnd (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1));
  return Qnil;
}

static VALUE rb_rlsec (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                       VALUE x5, VALUE x6, VALUE i1)
{ rlsec (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4), 
         NUM2DBL (x5), NUM2DBL (x6), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_rlstrt (VALUE self, VALUE x1, VALUE x2)
{ rlstrt (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_rlsymb (VALUE self, VALUE i1, VALUE x1, VALUE x2)
{ rlsymb (NUM2INT (i1), NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_rlvec (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                       VALUE i1)
{ rlvec (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1));
  return Qnil;
}

static VALUE rb_rlwind (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE i1,
                       VALUE x4)
{ rlwind (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2INT (i1),
          NUM2DBL (x1));
  return Qnil;
}

static VALUE rb_rndrec (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                        VALUE i5)
{ rndrec (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
          NUM2INT (i5));
  return Qnil;
}

static VALUE rb_rot3d (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ rot3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_rpixel (VALUE self, VALUE i1, VALUE i2)
{ int i;
  rpixel (NUM2INT (i1), NUM2INT (i2), &i);
  return INT2NUM (i);
}

static VALUE rb_rpixls (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ VALUE str;
  char *p;
  int n;

  n = NUM2INT (i3) * NUM2INT (i4);
  if (imgopt == 1) n = n * 3;

  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  rpixls ((unsigned char *) p, NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), 
          NUM2INT (i4));
  str = rb_str_new (p, n);
  free (p);
  return str;
}

static VALUE rb_rpng (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rpng (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_rppm (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rppm (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_rpxrow (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ VALUE str;
  char *p;
  int n;

  n = NUM2INT (i3);
  if (imgopt == 1) n = n * 3;

  p  = (char *) malloc (n);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  rpxrow ((unsigned char *) p, NUM2INT (i1), NUM2INT (i2), NUM2INT (i3)); 
  str = rb_str_new (p, n);
  free (p);
  return str;
}

static VALUE rb_rtiff (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  rtiff (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_rvynam (VALUE self)
{ rvynam ();
  return Qnil;
}

static VALUE rb_scale (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  scale (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_sclfac (VALUE self, VALUE x)
{ sclfac (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_sclmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  sclmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_scrmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  scrmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_sector (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                        VALUE x1, VALUE x2, VALUE i5)
{ sector (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
          NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (i5));
  return Qnil;
}

static VALUE rb_selwin (VALUE self, VALUE n)
{ selwin (NUM2INT (n));
  return Qnil;
}

static VALUE rb_sendbf (VALUE self)
{ sendbf ();
  return Qnil;
}

static VALUE rb_sendmb (VALUE self)
{ sendmb ();
  return Qnil;
}

static VALUE rb_sendok (VALUE self)
{ sendok ();
  return Qnil;
}

static VALUE rb_serif (VALUE self)
{ serif ();
  return Qnil;
}

static VALUE rb_setbas (VALUE self, VALUE x)
{ setbas (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_setcbk (VALUE self, VALUE s1, VALUE s2)
{ int n;
  char *p;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);

  p = StringValueCStr (s1);
  n = strlen (p);

  if (rbprj != NULL) free (rbprj);
  rbprj = (char *) malloc (n + 1);
  if (rbprj == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rbprj, p);
  setcbk (dis_prjcbk, StringValueCStr (s2));
  return Qnil;
}

void dis_prjcbk (double *x1, double *x2)
{ VALUE ret, *r;
  int n;
  ret = rb_funcall (Qnil, rb_intern (rbprj), 2, rb_float_new (*x1),
                    rb_float_new (*x2));

  Check_Type (ret, T_ARRAY);
  n = RARRAY_LEN (ret);
  if (n != 2) 
  { rb_warn ("wrong number of elements in array!");
    return;
  }

  r  = RARRAY_PTR (ret);
  *x1 = NUM2DBL (r[0]);
  *x2 = NUM2DBL (r[1]);
  return;
}

static VALUE rb_setclr (VALUE self, VALUE n)
{ setclr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_setcsr (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  setcsr (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_setexp (VALUE self, VALUE x)
{ setexp (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_setfce (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  setfce (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_setfil (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  setfil (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_setgrf (VALUE self, VALUE s1, VALUE s2, VALUE s3, VALUE s4)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  Check_Type (s4, T_STRING);
  setgrf (StringValueCStr (s1), StringValueCStr (s2),
          StringValueCStr (s3), StringValueCStr (s4));
  return Qnil;
}

static VALUE rb_setind (VALUE self, VALUE i1, VALUE x1, VALUE x2, VALUE x3)
{ setind (NUM2INT (i1), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_setmix (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  setmix (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_setpag (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  setpag (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_setres (VALUE self, VALUE i1, VALUE i2)
{ setres (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_setres3d (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ setres3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_setrgb (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ setrgb (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_setscl (VALUE self, VALUE arr1, VALUE n1, VALUE s1)
{ int n;
  double *p1;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) setscl (p1, n, StringValueCStr (s1));
  free (p1);
  return Qnil;
}

static VALUE rb_setvlt (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  setvlt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_setxid (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  setxid (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_shdafr (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdafr (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdasi (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdasi (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdaus (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdaus (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdcha (VALUE self)
{ shdcha ();
  return Qnil;
}

static VALUE rb_shdcrv (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE arr3, VALUE arr4, VALUE n2)
{ int n, m;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  m = NUM2INT (n2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, m);
  p4 = dbl_array (arr4, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL)
    shdcrv (p1, p2, n, p3, p4, m);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_shdeur (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdeur (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdfac (VALUE self, VALUE x)
{ shdfac (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_shdmap (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  shdmap (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_shdmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  shdmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_shdnor (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdnor (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdpat (VALUE self, VALUE n)
{ shdpat ((long) NUM2INT (n));
  return Qnil;
}

static VALUE rb_shdsou (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdsou (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shdusa (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1)
{ int n;
  int *p1, *p3;
  long *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = long_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdusa (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_shield (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  shield (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_shlcir (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ shlcir (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_shldel (VALUE self, VALUE n)
{ shldel (NUM2INT (n));
  return Qnil;
}

static VALUE rb_shlell (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                        VALUE x1)
{ shlell (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
          NUM2DBL (x1));
  return Qnil;
}

static VALUE rb_shlind (VALUE self)
{ int i;
  i = shlind ();
  return INT2NUM (i);
}

static VALUE rb_shlpie (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE x1,
                        VALUE x2)
{ shlpie (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2DBL (x1),
          NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_shlpol (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  int *p1, *p2;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  p2 = int_array (arr2, n);
  if (p1 != NULL && p2 != NULL) shlpol (p1, p2, n);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_shlrct (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4,
                        VALUE x1)
{ shlrct (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4),
          NUM2DBL (x1));
  return Qnil;
}

static VALUE rb_shlrec (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ shlrec (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_shlres (VALUE self, VALUE n)
{ shlres (NUM2INT (n));
  return Qnil;
}

static VALUE rb_shlsur (VALUE self)
{ shlsur ();
  return Qnil;
}

static VALUE rb_shlvis (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  shlvis (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_simplx (VALUE self)
{ simplx ();
  return Qnil;
}

static VALUE rb_skipfl (VALUE self, VALUE i1, VALUE i2)
{ int i;
  i = skipfl (NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_smxalf (VALUE self, VALUE s1, VALUE s2, VALUE s3, VALUE i1)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  smxalf (StringValueCStr (s1), StringValueCStr (s2),
          StringValueCStr (s3), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_solid (VALUE self)
{ solid ();
  return Qnil;
}

static VALUE rb_sortr1 (VALUE self, VALUE arr1, VALUE n1, VALUE s1)
{ int n;
  double *p1;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) 
  { sortr1 (p1, n, StringValueCStr (s1));
    copy_dblarray (p1, arr1, n);
  }
  free (p1);
  return Qnil;
}

static VALUE rb_sortr2 (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE s1)
{ int n;
  double *p1, *p2;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) 
  { sortr2 (p1, p2, n, StringValueCStr (s1));
    copy_dblarray (p1, arr1, n);
    copy_dblarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_spcbar (VALUE self, VALUE n)
{ spcbar (NUM2INT (n));
  return Qnil;
}

static VALUE rb_sphe3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE i1, VALUE i2)
{ sphe3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_spline (VALUE self, VALUE arr1, VALUE arr2, VALUE n1,
                        VALUE arr3, VALUE arr4)
{ int n, nspl;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, nspline);
  p4 = dbl_array (arr4, nspline);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  { spline (p1, p2, n, p3, p4, &nspl);
    copy_dblarray (p3, arr3, nspl);
    copy_dblarray (p4, arr4, nspl);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return INT2NUM (nspl);
}

static VALUE rb_splmod (VALUE self, VALUE i1, VALUE i2)
{ int nspl;
  nspl = NUM2INT (i2);
  splmod (NUM2INT (i1), nspl);
  if (nspl >= 5) nspline = nspl;
  return Qnil;
}

static VALUE rb_stmmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  stmmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_stmopt (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  stmopt (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_stmpts (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE i2, VALUE arr3, VALUE arr4, VALUE x1,
                        VALUE x2, VALUE arr5, VALUE arr6, VALUE i3)
{ int nx, ny, n, nmax;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  nmax  = NUM2INT (i3);
  p1 = dbl_matrix (arr1, nx, ny);
  p2 = dbl_matrix (arr2, nx, ny);
  p3 = dbl_array (arr3, nx);
  p4 = dbl_array (arr4, ny);
  p5 = dbl_array (arr5, nmax);
  p6 = dbl_array (arr6, nmax);


  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
  { stmpts (p1, p2, nx, ny, p3, p4, NUM2DBL (x1), NUM2DBL (x2),
            p5, p6, nmax, &n);
    copy_dblarray (p5, arr5, n);
    copy_dblarray (p6, arr6, n);
  }

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return INT2NUM (n);
}

static VALUE rb_stmtri (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE arr4, VALUE i1, VALUE arr5, VALUE arr6, 
                        VALUE arr7, VALUE i2, VALUE arr8, VALUE arr9,
                        VALUE i3)
{ int n, ntri, nray, *p5, *p6, *p7;
  double *p1, *p2, *p3, *p4, *p8 = NULL, *p9 = NULL;

  n = NUM2INT (i1);
  ntri = NUM2INT (i2);
  nray  = NUM2INT (i3);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);

  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);
  p7 = int_array (arr7, ntri);

  if (nray > 0)
  { p8 = dbl_array (arr8, nray);
    p9 = dbl_array (arr9, nray);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL &&
      p6 != NULL && p7 != NULL && 
      (nray == 0 || (p8 != NULL && p9 != NULL))) 
    stmtri (p1, p2, p3, p4, n, p5, p6, p7, ntri, p8, p9, nray);

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
 
  if (nray > 0) 
  { free (p8);
    free (p9);
  }
  return Qnil;
}

static VALUE rb_stmval (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  stmval (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_stream (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE i2, VALUE arr3, VALUE arr4, VALUE arr5,
                        VALUE arr6, VALUE i3)
{ int nx, ny, n;
  double *p1, *p2, *p3, *p4, *p5 = NULL, *p6 = NULL;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  n  = NUM2INT (i3);
  p1 = dbl_matrix (arr1, nx, ny);
  p2 = dbl_matrix (arr2, nx, ny);
  p3 = dbl_array (arr3, nx);
  p4 = dbl_array (arr4, ny);

  if (n > 0)
  { p5 = dbl_array (arr5, n);
    p6 = dbl_array (arr6, n);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && 
      (n == 0 || (p5 != NULL && p6 != NULL))) 
    stream (p1, p2, nx, ny, p3, p4, p5, p6, n);

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (n > 0) 
  { free (p5);
    free (p6);
  }
  return Qnil;
}

static VALUE rb_stream3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE i1, VALUE i2, VALUE i3, 
                        VALUE arr4, VALUE arr5, VALUE arr6, VALUE arr7,
                        VALUE arr8, VALUE arr9, VALUE i4)
{ int nx, ny, nz, n;
  double *p1, *p2, *p3, *p4, *p5, *p6, *p7 = NULL, *p8 = NULL, *p9 = NULL;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  nz = NUM2INT (i3);
  n  = NUM2INT (i4);
  p1 = dbl_matrix3 (arr1, nx, ny, nz);
  p2 = dbl_matrix3 (arr2, nx, ny, nz);
  p3 = dbl_matrix3 (arr3, nx, ny, nz);
  p4 = dbl_array (arr4, nx);
  p5 = dbl_array (arr5, ny);
  p6 = dbl_array (arr6, ny);

  if (n > 0)
  { p7 = dbl_array (arr7, n);
    p8 = dbl_array (arr8, n);
    p9 = dbl_array (arr9, n);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL &&
      (n == 0 || (p7 != NULL && p8 != NULL && p9 != NULL))) 
    stream3d (p1, p2, p3, nx, ny, nz, p4, p5, p6, p7, p8, p9, n);

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (n > 0)
  { free (p7);
    free (p8);
    free (p9);
  }
  return Qnil;
}

static VALUE rb_strt3d (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ strt3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_strtpt (VALUE self, VALUE x1, VALUE x2)
{ strtpt (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_surclr (VALUE self, VALUE i1, VALUE i2)
{ surclr (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_surfce (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3)
{ int n, m;
  double *p1, *p2, *p3;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    surfce (p1, n, p2, m, p3);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_surfcp (VALUE self, VALUE func, VALUE x1, VALUE x2, VALUE x3,
                        VALUE x4, VALUE x5, VALUE x6)
{ char *p;
  int n;

  Check_Type (func, T_STRING);
  p = StringValueCStr (func);
  n = strlen (p);

  if (rbfunc != NULL) free (rbfunc);
  rbfunc = (char *) malloc (n + 1);
  if (rbfunc == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rbfunc, p);
  surfcp (dis_funcbck, NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3),
          NUM2DBL (x4), NUM2DBL (x5), NUM2DBL (x6));
  return Qnil;
}

double dis_funcbck (double x, double y, int iopt)
{ VALUE ret;

  ret = rb_funcall (Qnil, rb_intern (rbfunc), 3, rb_float_new (x),
                    rb_float_new (y), INT2NUM (iopt));
  return NUM2DBL (ret);
}

static VALUE rb_surfun (VALUE self, VALUE func, VALUE i1, VALUE x1, VALUE i2,
                        VALUE x2)
{ char *p;
  int n;

  Check_Type (func, T_STRING);
  p = StringValueCStr (func);
  n = strlen (p);

  if (rbfunc != NULL) free (rbfunc);
  rbfunc = (char *) malloc (n + 1);
  if (rbfunc == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rbfunc, p);
  surfun (dis_funcbck2, NUM2INT (i1), NUM2DBL (x1), NUM2INT (i2),
          NUM2DBL (x2));
  return Qnil;
}

double dis_funcbck2 (double x, double y)
{ VALUE ret;

  ret = rb_funcall (Qnil, rb_intern (rbfunc), 2, rb_float_new (x),
                    rb_float_new (y));
  return NUM2DBL (ret);
}


static VALUE rb_suriso (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE i3, VALUE arr4,
                        VALUE x1)
{ int nx, ny, nz;
  double *p1, *p2, *p3, *p4;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  nz = NUM2INT (i2);
  p1 = dbl_array (arr1, nx);
  p2 = dbl_array (arr2, ny);
  p3 = dbl_array (arr3, nz);
  p4 = dbl_matrix3 (arr4, nx, ny, nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    suriso (p1, nx, p2, ny, p3, nz, p4, NUM2DBL (x1));

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_surmat (VALUE self, VALUE arr1, VALUE i1, VALUE i2, VALUE i3,
                        VALUE i4)
{ int n, m;
  double *p1;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_matrix (arr1, n, m);
  if (p1 != NULL) surmat (p1, n, m, NUM2INT (i3), NUM2INT (i4));
  free (p1);
  return Qnil;
}

static VALUE rb_surmsh (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  surmsh (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_suropt (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  suropt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_surshc (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3, VALUE arr4)
{ int n, m;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  p4 = dbl_matrix (arr4, n, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    surshc (p1, n, p2, m, p3, p4);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_surshd (VALUE self, VALUE arr1, VALUE i1, VALUE arr2, 
                        VALUE i2, VALUE arr3)
{ int n, m;
  double *p1, *p2, *p3;

  n = NUM2INT (i1);
  m = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, m);
  p3 = dbl_matrix (arr3, n, m);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    surshd (p1, n, p2, m, p3);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_sursze (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4)
{ sursze (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4));
  return Qnil;
}

static VALUE rb_surtri (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE i1, VALUE arr4, VALUE arr5, VALUE arr6, 
                        VALUE i2)
{ int n, ntri, *p4, *p5, *p6;
  double *p1, *p2, *p3;

  n = NUM2INT (i1);
  ntri = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);

  p4 = int_array (arr4, ntri);
  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);

  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL)
    surtri (p1, p2, p3, n, p4, p5, p6, ntri);

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_survis (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  survis (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swapi4 (VALUE self, VALUE arr1, VALUE n1)
{ VALUE arr;
  int i, n, *p1;

  n = NUM2INT (n1);
  p1 = int_array (arr1, n);
  if (p1 != NULL) 
    swapi4 (p1, n);

  arr = rb_ary_new ();
  for (i = 0; i < n; i++)
    rb_ary_push (arr, INT2NUM (p1[i]));
  free (p1);
  return arr;
}

static VALUE rb_swgatt (VALUE self, VALUE i1, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  swgatt (NUM2INT (i1), StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swgbox (VALUE self, VALUE i1, VALUE i2)
{ swgbox (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgbut (VALUE self, VALUE i1, VALUE i2)
{ swgbut (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgcb2 (VALUE self, VALUE i, VALUE s)
{ int n;
  char *p;

  Check_Type (s, T_STRING);
  if (ncbray >= MAX_CB)
  { rb_warn ("too many callback routines!");
    return Qnil;
  }

  icbray[ncbray] = NUM2INT (i);
  p = StringValueCStr (s);
  n = strlen (p);
  rcbray[ncbray] = (char *) malloc (n + 1);
  if (rcbray[ncbray] == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rcbray[ncbray], p);
  ncbray++;

  swgcb2 (NUM2INT (i), dis_callbck3);
  return Qnil;
}

static VALUE rb_swgcb3 (VALUE self, VALUE i, VALUE s)
{ int n;
  char *p;

  Check_Type (s, T_STRING);
  if (ncbray >= MAX_CB)
  { rb_warn ("too many callback routines!");
    return Qnil;
  }

  icbray[ncbray] = NUM2INT (i);
  p = StringValueCStr (s);
  n = strlen (p);
  rcbray[ncbray] = (char *) malloc (n + 1);
  if (rcbray[ncbray] == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rcbray[ncbray], p);
  ncbray++;

  swgcb3 (NUM2INT (i), dis_callbck4);
  return Qnil;
}

void dis_callbck3 (int id, int irow, int icol)
{ int i;

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
    rb_funcall (Qnil, rb_intern (rcbray[i]), 3, INT2NUM (id),
                INT2NUM (irow), INT2NUM (icol));
  }
  return;
}

void dis_callbck4 (int id, int ival)
{ int i;

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
    rb_funcall (Qnil, rb_intern (rcbray[i]), 2, INT2NUM (id),
                INT2NUM (ival));
  }
  return;
}

static VALUE rb_swgcbk (VALUE self, VALUE i, VALUE s)
{ int n;
  char *p;

  Check_Type (s, T_STRING);
  if (ncbray >= MAX_CB)
  { rb_warn ("too many callback routines!");
    return Qnil;
  }

  icbray[ncbray] = NUM2INT (i);
  p = StringValueCStr (s);
  n = strlen (p);
  rcbray[ncbray] = (char *) malloc (n + 1);
  if (rcbray[ncbray] == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rcbray[ncbray], p);
  ncbray++;

  swgcbk (NUM2INT (i), dis_callbck2);
  return Qnil;
}

void dis_callbck2 (int id)
{ int i;

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
    rb_funcall (Qnil, rb_intern (rcbray[i]), 1, INT2NUM (id));
  }
  return;
}

static VALUE rb_swgclr (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE s)
{ Check_Type (s, T_STRING);
  swgclr (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgbgd (VALUE self, VALUE id, VALUE x1, VALUE x2, VALUE x3)
{ 
  swgbgd (NUM2INT (id), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_swgfgd (VALUE self, VALUE id, VALUE x1, VALUE x2, VALUE x3)
{ 
  swgfgd (NUM2INT (id), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_swgdrw (VALUE self, VALUE x)
{ swgdrw (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_swgfil (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  swgfil (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgflt (VALUE self, VALUE i1, VALUE x, VALUE i2)
{ swgflt (NUM2INT (i1), NUM2DBL (x), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgfnt (VALUE self, VALUE s, VALUE n)
{ Check_Type (s, T_STRING);
  swgfnt (StringValueCStr (s), NUM2INT (n));
  return Qnil;
}

static VALUE rb_swgfoc (VALUE self, VALUE n)
{ swgfoc (NUM2INT (n));
  return Qnil;
}

static VALUE rb_swghlp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  swghlp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgint (VALUE self, VALUE i1, VALUE i2)
{ swgint (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgiop (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  swgiop (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgjus (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  swgjus (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swglis (VALUE self, VALUE i1, VALUE i2)
{ swglis (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgmix (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  swgmix (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swgmrg (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  swgmrg (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgoff (VALUE self, VALUE i1, VALUE i2)
{ swgoff (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgopt (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  swgopt (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swgpop (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  swgpop (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgpos (VALUE self, VALUE i1, VALUE i2)
{ swgpos (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgray (VALUE self, VALUE arr1, VALUE n1, VALUE s1)
{ int n;
  double *p1;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) swgray (p1, n, StringValueCStr (s1));
  free (p1);
  return Qnil;
}

static VALUE rb_swgscl (VALUE self, VALUE i, VALUE x)
{ swgscl (NUM2INT (i), NUM2DBL (x));
  return Qnil;
}

static VALUE rb_swgsiz (VALUE self, VALUE i1, VALUE i2)
{ swgsiz (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_swgspc (VALUE self, VALUE x1, VALUE x2)
{ swgspc (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_swgstp (VALUE self, VALUE x)
{ swgstp (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_swgtbf (VALUE self, VALUE i1, VALUE x1, VALUE i2, VALUE i3,
                       VALUE i4, VALUE s)
{ Check_Type (s, T_STRING);
  swgtbf (NUM2INT (i1), NUM2DBL (x1), NUM2INT (i2), NUM2INT (i3),
          NUM2INT (i4), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgtbi (VALUE self, VALUE i1, VALUE i2, VALUE i3,
                       VALUE i4, VALUE s)
{ Check_Type (s, T_STRING);
  swgtbi (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3),
          NUM2INT (i4), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgtbl (VALUE self, VALUE i1, VALUE arr1, VALUE i2, VALUE i3,
                       VALUE i4, VALUE s)
{ int n;
  double *p1; 
 
  n = NUM2INT (i2);
  p1 = dbl_array (arr1, n);
  Check_Type (s, T_STRING);
  if (p1 != NULL)
    swgtbl (NUM2INT (i1), p1, n, NUM2INT (i3), NUM2INT (i4), 
            StringValueCStr (s));
  free (p1);
  return Qnil;
}

static VALUE rb_swgtbs (VALUE self, VALUE i1, VALUE s1, VALUE i2, VALUE i3,
                       VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s1, T_STRING);
  swgtbs (NUM2INT (i1), StringValueCStr (s1), NUM2INT (i2), NUM2INT (i3),
          StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swgtit (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  swgtit (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgtxt (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  swgtxt (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_swgtyp (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  swgtyp (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_swgval (VALUE self, VALUE i, VALUE x)
{ swgval (NUM2INT (i), NUM2DBL (x));
  return Qnil;
}

static VALUE rb_swgwin (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ swgwin (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_swgwth (VALUE self, VALUE i)
{ swgwth (NUM2INT (i));
  return Qnil;
}

static VALUE rb_symb3d (VALUE self, VALUE n, VALUE x1, VALUE x2, VALUE x3)
{ symb3d (NUM2INT (n), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_symbol (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ symbol (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_symfil (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  symfil (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_symrot (VALUE self, VALUE x)
{ symrot (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_tellfl (VALUE self, VALUE n)
{ int i;
  i = tellfl (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_texmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  texmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_texopt (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  texopt (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_texval (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  texval (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_thkc3d (VALUE self, VALUE x)
{ thkc3d (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_thkcrv (VALUE self, VALUE n)
{ thkcrv (NUM2INT (n));
  return Qnil;
}

static VALUE rb_thrfin (VALUE self)
{ thrfin ();
  return Qnil;
}

static VALUE rb_thrini (VALUE self, VALUE n)
{ thrini (NUM2INT (n));
  return Qnil;
}

static VALUE rb_ticks (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  ticks (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_ticlen (VALUE self, VALUE i1, VALUE i2)
{ ticlen (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_ticmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  ticmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_ticpos (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  ticpos (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_tifmod (VALUE self, VALUE n, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  tifmod (NUM2INT (n), StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_tiforg (VALUE self, VALUE i1, VALUE i2)
{ tiforg (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_tifwin (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ tifwin (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_timopt (VALUE self)
{ timopt ();
  return Qnil;
}

static VALUE rb_titjus (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  titjus (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_title (VALUE self)
{ title ();
  return Qnil;
}

static VALUE rb_titlin (VALUE self, VALUE s, VALUE n)
{ Check_Type (s, T_STRING);
  titlin (StringValueCStr (s), NUM2INT (n));
  return Qnil;
}

static VALUE rb_titpos (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  titpos (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_torus3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
			 VALUE x5, VALUE x6, VALUE x7, VALUE x8, 
                         VALUE i1, VALUE i2)
{ torus3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
           NUM2DBL (x5), NUM2DBL (x6), NUM2DBL (x7), NUM2DBL (x8),
           NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_tprfin (VALUE self)
{ tprfin ();
  return Qnil;
}

static VALUE rb_tprini (VALUE self)
{ tprini ();
  return Qnil;
}

static VALUE rb_tprmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  tprmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_tprval (VALUE self, VALUE x)
{ tprval (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_tr3axs (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4)
{ tr3axs (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4));
  return Qnil;
}

static VALUE rb_tr3res (VALUE self)
{ tr3res ();
  return Qnil;
}

static VALUE rb_tr3rot (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ tr3rot (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_tr3scl (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ tr3scl (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_tr3shf (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ tr3shf (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return Qnil;
}

static VALUE rb_trfco1 (VALUE self, VALUE arr1, VALUE n1, VALUE s1, VALUE s2)
{ int n;
  double *p1;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  if (p1 != NULL) 
  {  trfco1 (p1, n, StringValueCStr (s1), StringValueCStr (s2));
     copy_dblarray (p1, arr1, n);
  }
  free (p1);
  return Qnil;
}

static VALUE rb_trfco2 (VALUE self, VALUE arr1, VALUE arr2, VALUE n1, 
                        VALUE s1, VALUE s2)
{ int n;
  double *p1, *p2;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) 
  {  trfco2 (p1, p2, n, StringValueCStr (s1), StringValueCStr (s2));
     copy_dblarray (p1, arr1, n);
     copy_dblarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_trfco3 (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1, VALUE s1, VALUE s2)
{ int n;
  double *p1, *p2, *p3;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  {  trfco3 (p1, p2, p3, n, StringValueCStr (s1), StringValueCStr (s2));
     copy_dblarray (p1, arr1, n);
     copy_dblarray (p2, arr2, n);
     copy_dblarray (p3, arr3, n);
  }
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_trfdat (VALUE self, VALUE n)
{ VALUE arr;
  int i1, i2, i3;
  trfdat (NUM2INT (n), &i1, &i2, &i3);
  arr = rb_ary_new ();
  rb_ary_push (arr, INT2NUM (i1));
  rb_ary_push (arr, INT2NUM (i2));
  rb_ary_push (arr, INT2NUM (i3));
  return arr;
}

static VALUE rb_trfmat (VALUE self, VALUE arr1, VALUE i1, VALUE i2, VALUE i3, 
                        VALUE i4)
{ VALUE arr;
  int i, n, nx, ny;
  double *p1, *p2;
  
  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  n = NUM2INT (i3) * NUM2INT (i4);
  p2 = (double *) calloc (n, sizeof (double));
  if (p2 == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }
  p1 = dbl_matrix (arr1, nx, ny);
  if (p1 != NULL)
    trfmat (p1, nx, ny, p2, NUM2INT (i3), NUM2INT (i4));

  arr = rb_ary_new ();
  for (i = 0; i < n; i++)
    rb_ary_push (arr, rb_float_new (p2[i]));
  free (p2);
  return arr;
}

static VALUE rb_trfrel (VALUE self, VALUE arr1, VALUE arr2, VALUE n1)
{ int n;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) 
  {  trfrel (p1, p2, n);
     copy_dblarray (p1, arr1, n);
     copy_dblarray (p2, arr2, n);
  }
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_trfres (VALUE self)
{ trfres ();
  return Qnil;
}

static VALUE rb_trfrot (VALUE self, VALUE x, VALUE i1, VALUE i2)
{ trfrot (NUM2DBL (x), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_trfscl (VALUE self, VALUE x1, VALUE x2)
{ trfscl (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_trfshf (VALUE self, VALUE i1, VALUE i2)
{ trfshf (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_tria3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3)
{ int n;
  double *p1, *p2, *p3;

  n = 3;
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) tria3d (p1, p2, p3);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_triang (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE arr3, VALUE arr4, VALUE arr5, VALUE i2)
{ int n, nmax, ntri = 0, *p3, *p4, *p5;
  double *p1, *p2;

  n = NUM2INT (i1);
  nmax = NUM2INT (i2);
  p1 = dbl_array (arr1, n + 3);
  p2 = dbl_array (arr2, n + 3);
  p3 = int_array (arr3, nmax);
  p4 = int_array (arr4, nmax);
  p5 = int_array (arr5, nmax);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL) 
  { ntri = triang (p1, p2, n, p3, p4, p5, nmax);
    copy_intarray (p3, arr3, nmax);
    copy_intarray (p4, arr4, nmax);
    copy_intarray (p5, arr5, nmax);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  return INT2NUM (ntri);
}

static VALUE rb_triflc (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE n1)
{ int n, *p3;
  double *p1, *p2;

  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = int_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) triflc (p1, p2, p3, n);
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_trifll (VALUE self, VALUE arr1, VALUE arr2)
{ int n;
  double *p1, *p2;

  n = 3;
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  if (p1 != NULL && p2 != NULL) trifll (p1, p2);
  free (p1);
  free (p2);
  return Qnil;
}

static VALUE rb_triplx (VALUE self)
{ triplx ();
  return Qnil;
}

static VALUE rb_tripts (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE i1, VALUE arr4, VALUE arr5, VALUE arr6, 
                        VALUE i2, VALUE x1, VALUE arr7, VALUE arr8, VALUE i3,
                        VALUE arr9, VALUE i4)
{ int i, n, ntri, maxpts, maxray, *p4, *p5, *p6, *p9;
  double *p1, *p2, *p3, *p7, *p8;

  n = NUM2INT (i1);
  ntri = NUM2INT (i2);
  maxpts = NUM2INT (i3);
  maxray = NUM2INT (i4);

  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = int_array (arr4, ntri);
  p5 = int_array (arr5, ntri);
  p6 = int_array (arr6, ntri);
  p7 = dbl_array (arr7, maxpts);
  p8 = dbl_array (arr8, maxpts);
  p9 = int_array (arr9, maxray);

  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL && 
      p7 != NULL && p8 != NULL && p9 != NULL)
  { tripts (p1, p2, p3, n, p4, p5, p6, ntri, NUM2DBL (x1), 
            p7, p8,  maxpts, p9, maxray, &i);
    copy_dblarray (p7, arr7, maxpts);
    copy_dblarray (p8, arr8, maxpts);
    copy_intarray (p9, arr9, maxray);
  }

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  free (p8);
  free (p9);
  return INT2NUM (i);
}

static VALUE rb_trmlen (VALUE self, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = trmlen (StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_ttfont(VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  ttfont (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_tube3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE x7, VALUE i1, VALUE i2)
{ tube3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), NUM2DBL (x7), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_txtbgd (VALUE self, VALUE n)
{ txtbgd (NUM2INT (n));
  return Qnil;
}

static VALUE rb_txtjus (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  txtjus (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_txture (VALUE self, VALUE i1, VALUE i2)
{ VALUE arr;
  int i, n, nx, ny, *p;
  
  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  n = nx * ny;
  p = (int *) calloc (n, sizeof (int));
  if (p == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  txture (p, nx, ny);

  arr = rb_ary_new ();
  for (i = 0; i < n; i++)
    rb_ary_push (arr, INT2NUM (p[i]));
  free (p);
  return arr;
}

static VALUE rb_unit (VALUE self, VALUE i)
{ int n;
  n = NUM2INT (i);
  if (n == 0)
    unit (NULL);
  else
    unit ((void *) stdout);
  return Qnil;
}

static VALUE rb_units (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  units (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_upstr (VALUE self, VALUE s1)
{ VALUE str;
  char *p, *q;
  Check_Type (s1, T_STRING);

  q = StringValueCStr (s1);
  p = (char *) malloc (strlen (q) + 1);
  if (p == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }
  strcpy (p, q);
  upstr (p);
  str = rb_str_new2 (p);
  free (p);
  return str;
}

static VALUE rb_utfint (VALUE self, VALUE s)
{ VALUE arr;
  int i, nray, n;
  int *p;

  Check_Type (s, T_STRING);
  n = strlen (StringValueCStr (s));
  p = (int *) calloc (n, sizeof (int));
  if (p == NULL) 
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  nray = utfint (StringValueCStr (s), p, n);
  arr = rb_ary_new ();
  for (i = 0; i < nray; i++)
    rb_ary_push (arr, INT2NUM (p[i]));
  free (p);
  return arr;
}

static VALUE rb_vang3d (VALUE self, VALUE x)
{ vang3d (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_vclp3d (VALUE self, VALUE x1, VALUE x2)
{ vclp3d (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_vecclr (VALUE self, VALUE n)
{ vecclr (NUM2INT (n));
  return Qnil;
}

static VALUE rb_vecf3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE arr4, VALUE arr5, VALUE arr6, 
                        VALUE i1, VALUE i2)
{ int n;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  n = NUM2INT (i1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = dbl_array (arr5, n);
  p6 = dbl_array (arr6, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
    vecf3d (p1, p2, p3, p4, p5, p6, n, NUM2INT (i2));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_vecfld (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE arr4, VALUE i1, VALUE i2)
{ int n;
  double *p1, *p2, *p3, *p4;

  n = NUM2INT (i1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    vecfld (p1, p2, p3, p4, n, NUM2INT (i2));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_vecmat (VALUE self, VALUE arr1, VALUE arr2, VALUE i1,
                        VALUE i2, VALUE arr3, VALUE arr4, VALUE i3)
{ int nx, ny;
  double *p1, *p2, *p3, *p4;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  p1 = dbl_matrix (arr1, nx, ny);
  p2 = dbl_matrix (arr2, nx, ny);
  p3 = dbl_array (arr3, nx);
  p4 = dbl_array (arr4, ny);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    vecmat (p1, p2, nx, ny, p3, p4, NUM2INT (i3));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_vecmat3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3,
                        VALUE i1, VALUE i2, VALUE i3,
                        VALUE arr4, VALUE arr5, VALUE arr6, VALUE i4)
{ int nx, ny, nz;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  nx = NUM2INT (i1);
  ny = NUM2INT (i2);
  nz = NUM2INT (i3);
  p1 = dbl_matrix3 (arr1, nx, ny, nz);
  p2 = dbl_matrix3 (arr2, nx, ny, nz);
  p3 = dbl_matrix3 (arr3, nx, ny, nz);
  p4 = dbl_array (arr4, nx);
  p5 = dbl_array (arr5, ny);
  p6 = dbl_array (arr6, nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
    vecmat3d (p1, p2, p3, nx, ny, nz, p4, p5, p6, NUM2INT (i4));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_vecopt (VALUE self, VALUE x, VALUE s)
{ Check_Type (s, T_STRING);
  vecopt (NUM2DBL (x), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_vector (VALUE self, VALUE i1, VALUE i2, VALUE i3,
                        VALUE i4, VALUE i5)
{ vector (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4), 
          NUM2INT (i5));
  return Qnil;
}

static VALUE rb_vectr3 (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                        VALUE x5, VALUE x6, VALUE i1)
{ vectr3 (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_vfoc3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE s)
{ Check_Type (s, T_STRING);
  vfoc3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_view3d (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE s)
{ Check_Type (s, T_STRING);
  view3d (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_vkxbar (VALUE self, VALUE n)
{ vkxbar (NUM2INT (n));
  return Qnil;
}

static VALUE rb_vkybar (VALUE self, VALUE n)
{ vkybar (NUM2INT (n));
  return Qnil;
}

static VALUE rb_vkytit (VALUE self, VALUE n)
{ vkytit (NUM2INT (n));
  return Qnil;
}

static VALUE rb_vltfil (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  vltfil (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_vscl3d (VALUE self, VALUE x)
{ vscl3d (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_vtx3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE n1, VALUE s1)
{ int n;
  double *p1, *p2, *p3;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
     vtx3d (p1, p2, p3, n, StringValueCStr (s1));
  free (p1);
  free (p2);
  free (p3);
  return Qnil;
}

static VALUE rb_vtxc3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE arr4, VALUE n1, VALUE s1)
{ int n, *p4;
  double *p1, *p2, *p3;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = int_array (arr4, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
     vtxc3d (p1, p2, p3, p4, n, StringValueCStr (s1));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_vtxn3d (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE arr4, VALUE arr5, VALUE arr6, 
                        VALUE n1, VALUE s1)
{ int n;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  Check_Type (s1, T_STRING);
  n = NUM2INT (n1);
  p1 = dbl_array (arr1, n);
  p2 = dbl_array (arr2, n);
  p3 = dbl_array (arr3, n);
  p4 = dbl_array (arr4, n);
  p5 = dbl_array (arr5, n);
  p6 = dbl_array (arr6, n);
  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
     vtxn3d (p1, p2, p3, p4, p5, p6, n, StringValueCStr (s1));
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  return Qnil;
}

static VALUE rb_vup3d (VALUE self, VALUE x)
{ vup3d (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_wgapp (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgapp (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wgappb (VALUE self, VALUE n, VALUE s, VALUE i1, VALUE i2)
{ int i;
  char *p;
  p = StringValuePtr (s);
  i = wgappb (NUM2INT (n), (unsigned char *) p, NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgbas (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgbas (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wgbox (VALUE self, VALUE i1, VALUE s, VALUE i2)
{ int i;
  Check_Type (s, T_STRING);
  i = wgbox (NUM2INT (i1), StringValueCStr (s), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgbut (VALUE self, VALUE i1, VALUE s, VALUE i2)
{ int i;
  Check_Type (s, T_STRING);
  i = wgbut (NUM2INT (i1), StringValueCStr (s), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgcmd (VALUE self, VALUE n, VALUE s1, VALUE s2)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  i = wgcmd (NUM2INT (n), StringValueCStr (s1), StringValueCStr (s2));
  return INT2NUM (i);
}

static VALUE rb_wgdlis (VALUE self, VALUE i1, VALUE s, VALUE i2)
{ int i;
  Check_Type (s, T_STRING);
  i = wgdlis (NUM2INT (i1), StringValueCStr (s), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgdraw (VALUE self, VALUE n)
{ int i;
  i = wgdraw (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_wgfil (VALUE self, VALUE n, VALUE s1, VALUE s2, VALUE s3)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  Check_Type (s3, T_STRING);
  i = wgfil (NUM2INT (n), StringValueCStr (s1), StringValueCStr (s2),
             StringValueCStr (s3));
  return INT2NUM (i);
}

static VALUE rb_wgfin (VALUE self)
{ wgfin ();
  return Qnil;
}

static VALUE rb_wgicon (VALUE self, VALUE i1, VALUE s1, VALUE i2, VALUE i3,
                        VALUE s2)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  i = wgicon (NUM2INT (i1), StringValueCStr (s1), NUM2INT (i2), NUM2INT (i3),
              StringValueCStr (s2));
  return INT2NUM (i);
}

static VALUE rb_wgimg (VALUE self, VALUE n, VALUE s1, VALUE s2, VALUE i1, 
                       VALUE i2)
{ int i;
  char *p;
  Check_Type (s1, T_STRING);
  p = StringValuePtr (s2);
  i = wgimg (NUM2INT (n), StringValueCStr (s1), (unsigned char *) p, 
             NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgini (VALUE self, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgini (StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wglab (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wglab (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wglis (VALUE self, VALUE i1, VALUE s, VALUE i2)
{ int i;
  Check_Type (s, T_STRING);
  i = wglis (NUM2INT (i1), StringValueCStr (s), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgltxt (VALUE self, VALUE i1, VALUE s1, VALUE s2, VALUE i2)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  i = wgltxt (NUM2INT (i1), StringValueCStr (s1), StringValueCStr (s2),
              NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgok (VALUE self, VALUE n)
{ int i;
  i = wgok (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_wgpbar (VALUE self, VALUE n, VALUE x1, VALUE x2, VALUE x3)
{ int i;
  i = wgpbar (NUM2INT (n), NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return INT2NUM (i);
}

static VALUE rb_wgpbut (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgpbut (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wgpicon (VALUE self, VALUE i1, VALUE s1, VALUE i2, VALUE i3,
                        VALUE s2)
{ int i;
  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  i = wgpicon (NUM2INT (i1), StringValueCStr (s1), NUM2INT (i2), NUM2INT (i3),
              StringValueCStr (s2));
  return INT2NUM (i);
}

static VALUE rb_wgpimg (VALUE self, VALUE n, VALUE s1, VALUE s2, VALUE i1, 
                       VALUE i2)
{ int i;
  char *p;
  Check_Type (s1, T_STRING);
  p = StringValuePtr (s2);
  i = wgpimg (NUM2INT (n), StringValueCStr (s1), (unsigned char *) p, 
             NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgpop (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgpop (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_wgpopb (VALUE self, VALUE n, VALUE s, VALUE i1, VALUE i2)
{ int i;
  char *p;
  p = StringValuePtr (s);
  i = wgpopb (NUM2INT (n), (unsigned char *) p, NUM2INT (i1), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgquit (VALUE self, VALUE n)
{ int i;
  i = wgquit (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_wgscl (VALUE self, VALUE i1, VALUE s1, VALUE x1, VALUE x2, 
                       VALUE x3, VALUE i2)
{ int i;
  Check_Type (s1, T_STRING);
  i = wgscl (NUM2INT (i1), StringValueCStr (s1), NUM2DBL (x1), NUM2DBL (x2), 
             NUM2DBL (x3), NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wgsep (VALUE self, VALUE n)
{ int i;
  i = wgsep (NUM2INT (n));
  return INT2NUM (i);
}

static VALUE rb_wgstxt (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ int i;
  i = wgstxt (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return INT2NUM (i);
}

static VALUE rb_wgtbl (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ int i;
  i = wgtbl (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return INT2NUM (i);
}

static VALUE rb_wgtxt (VALUE self, VALUE n, VALUE s)
{ int i;
  Check_Type (s, T_STRING);
  i = wgtxt (NUM2INT (n), StringValueCStr (s));
  return INT2NUM (i);
}

static VALUE rb_widbar (VALUE self, VALUE n)
{ widbar (NUM2INT (n));
  return Qnil;
}

static VALUE rb_wimage (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  wimage (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winapp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winapp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_wincbk (VALUE self, VALUE s1, VALUE s2)
{ int n;
  char *p;

  Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);

  p = StringValueCStr (s1);
  n = strlen (p);

  if (rbwin != NULL) free (rbwin);
  rbwin = (char *) malloc (n + 1);
  if (rbwin == NULL)
  { rb_warn ("not enough memory!");
    return Qnil;
  }

  strcpy (rbwin, p);
  wincbk (dis_wincbk, StringValueCStr (s2));
  return Qnil;
}

void dis_wincbk (int id, int nx, int ny, int nw, int nh)
{
  rb_funcall (Qnil, rb_intern (rbwin), 5, INT2NUM (id), 
              INT2NUM (nx), INT2NUM (ny), INT2NUM (nw), INT2NUM (nh));
  return;
}

static VALUE rb_windbr (VALUE self, VALUE x1, VALUE i1, VALUE i2, VALUE i3,
                        VALUE x2)
{ windbr (NUM2DBL (x1), NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), 
          NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_window (VALUE self, VALUE i1, VALUE i2, VALUE i3, VALUE i4)
{ window (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), NUM2INT (i4));
  return Qnil;
}

static VALUE rb_winfnt (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winfnt (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winico (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winico (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winid (VALUE self)
{ int i;
  i = winid ();
  return INT2NUM (i);
}

static VALUE rb_winjus (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winjus (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winkey (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winkey (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  winmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winopt (VALUE self, VALUE n, VALUE s)
{ Check_Type (s, T_STRING);
  winopt (NUM2INT (n), StringValueCStr (s));
  return Qnil;
}

static VALUE rb_winsiz (VALUE self, VALUE i1, VALUE i2)
{ winsiz (NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_wintit (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  wintit (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_wintyp (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  wintyp (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_wmfmod (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  wmfmod (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_world (VALUE self)
{ world ();
  return Qnil;
}

static VALUE rb_wpixel (VALUE self, VALUE i1, VALUE i2, VALUE i3)
{ wpixel (NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_wpixls (VALUE self, VALUE s1, VALUE i1, VALUE i2, VALUE i3, 
                        VALUE i4)
{ char *p;
  p = StringValuePtr (s1);
  wpixls ((unsigned char *) p, NUM2INT (i1), NUM2INT (i2), NUM2INT (i3), 
          NUM2INT (i4));
  return Qnil;
}

static VALUE rb_wpxrow (VALUE self, VALUE s1, VALUE i1, VALUE i2, VALUE i3) 
{ char *p;
  p = StringValuePtr (s1);
  wpxrow ((unsigned char *) p, NUM2INT (i1), NUM2INT (i2), NUM2INT (i3));
  return Qnil;
}

static VALUE rb_writfl (VALUE self, VALUE i1, VALUE s1, VALUE i2) 
{ char *p;
  int i;
  p = StringValuePtr (s1);
  i = writfl (NUM2INT (i1), (unsigned char *) p, NUM2INT (i2));
  return INT2NUM (i);
}

static VALUE rb_wtiff (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  wtiff (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_x11fnt (VALUE self, VALUE s1, VALUE s2)
{ Check_Type (s1, T_STRING);
  Check_Type (s2, T_STRING);
  x11fnt (StringValueCStr (s1), StringValueCStr (s2));
  return Qnil;
}

static VALUE rb_x11mod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  x11mod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_x2dpos (VALUE self, VALUE x1, VALUE x2)
{ double x;
  x = x2dpos (NUM2DBL (x1), NUM2DBL (x2));
  return rb_float_new (x);
}

static VALUE rb_x3dabs (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = x3dabs (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_x3dpos (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = x3dpos (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_x3drel (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = x3drel (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_xaxgit (VALUE self)
{ xaxgit ();
  return Qnil;
}

static VALUE rb_xaxis (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4)
{ Check_Type (s, T_STRING);
  xaxis (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4));
  return Qnil;
}

static VALUE rb_xaxlg (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4)
{ Check_Type (s, T_STRING);
  xaxlg (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4));
  return Qnil;
}

static VALUE rb_xaxmap (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE s, VALUE i1, VALUE i2)
{ Check_Type (s, T_STRING);
  xaxmap (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         StringValueCStr (s), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_xcross (VALUE self)
{ xcross ();
  return Qnil;
}

static VALUE rb_xdraw (VALUE self, VALUE x1, VALUE x2)
{ xdraw (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_xinvrs (VALUE self, VALUE n)
{ double x;
  x = xinvrs (NUM2INT (n));
  return rb_float_new (x);
}

static VALUE rb_xmove (VALUE self, VALUE x1, VALUE x2)
{ xmove (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

static VALUE rb_xposn (VALUE self, VALUE x1)
{ double x;
  x = xposn (NUM2DBL (x1));
  return rb_float_new (x);
}

static VALUE rb_y2dpos (VALUE self, VALUE x1, VALUE x2)
{ double x;
  x = y2dpos (NUM2DBL (x1), NUM2DBL (x2));
  return rb_float_new (x);
}

static VALUE rb_y3dabs (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = y3dabs (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_y3dpos (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = y3dpos (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_y3drel (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = y3drel (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_yaxgit (VALUE self)
{ ycross ();
  return Qnil;
}

static VALUE rb_yaxis (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4)
{ Check_Type (s, T_STRING);
  yaxis (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4));
  return Qnil;
}

static VALUE rb_yaxlg (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4)
{ Check_Type (s, T_STRING);
  yaxlg (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4));
  return Qnil;
}

static VALUE rb_yaxmap (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE s, VALUE i1, VALUE i2)
{ Check_Type (s, T_STRING);
  yaxmap (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         StringValueCStr (s), NUM2INT (i1), NUM2INT (i2));
  return Qnil;
}

static VALUE rb_ycross (VALUE self)
{ ycross ();
  return Qnil;
}

static VALUE rb_yinvrs (VALUE self, VALUE n)
{ double x;
  x = yinvrs (NUM2INT (n));
  return rb_float_new (x);
}

static VALUE rb_ypolar (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
                      VALUE s, VALUE i1)
{ Check_Type (s, T_STRING);
  ypolar (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          StringValueCStr (s), NUM2INT (i1));
  return Qnil;
}

static VALUE rb_yposn (VALUE self, VALUE x1)
{ double x;
  x = yposn (NUM2DBL (x1));
  return rb_float_new (x);
}

static VALUE rb_z3dpos (VALUE self, VALUE x1, VALUE x2, VALUE x3)
{ double x;
  x = z3dpos (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3));
  return rb_float_new (x);
}

static VALUE rb_zaxis (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
		       VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4,
                       VALUE i5)
{ Check_Type (s, T_STRING);
  zaxis (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4), NUM2INT (i5));
  return Qnil;
}

static VALUE rb_zaxlg (VALUE self, VALUE x1, VALUE x2, VALUE x3, VALUE x4,
		       VALUE i1, VALUE s, VALUE i2, VALUE i3, VALUE i4,
                       VALUE i5)
{ Check_Type (s, T_STRING);
  zaxlg (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
         NUM2INT (i1), StringValueCStr (s), NUM2INT (i2), NUM2INT (i3),
         NUM2INT (i4), NUM2INT (i5));
  return Qnil;
}

static VALUE rb_zbfers (VALUE self)
{ zbfers ();
  return Qnil;
}

static VALUE rb_zbffin (VALUE self)
{ zbffin ();
  return Qnil;
}

static VALUE rb_zbfini (VALUE self)
{ int i;
  i = zbfini ();
  return INT2NUM (i);
}

static VALUE rb_zbflin (VALUE self, VALUE x1, VALUE x2, VALUE x3,
                        VALUE x4, VALUE x5, VALUE x6)
{ zbflin (NUM2DBL (x1), NUM2DBL (x2), NUM2DBL (x3), NUM2DBL (x4),
          NUM2DBL (x5), NUM2DBL (x6));
  return Qnil;
}

static VALUE rb_zbfmod (VALUE self, VALUE s)
{ Check_Type (s, T_STRING);
  zbfmod (StringValueCStr (s));
  return Qnil;
}

static VALUE rb_zbfres (VALUE self)
{ zbfres ();
  return Qnil;
}

static VALUE rb_zbfscl (VALUE self, VALUE x)
{ zbfscl (NUM2DBL (x));
  return Qnil;
}

static VALUE rb_zbftri (VALUE self, VALUE arr1, VALUE arr2, VALUE arr3, 
                        VALUE arr4)
{ int *p4; 
  double *p1, *p2, *p3;

  p1 = dbl_array (arr1, 3);
  p2 = dbl_array (arr2, 3);
  p3 = dbl_array (arr3, 3);
  p4 = int_array (arr4, 3);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    zbftri (p1, p2, p3, p4);
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  return Qnil;
}

static VALUE rb_zscale (VALUE self, VALUE x1, VALUE x2)
{ zscale (NUM2DBL (x1), NUM2DBL (x2));
  return Qnil;
}

void Init_dislin (VALUE self)
{ rb_Dislin = rb_define_module ("Dislin");

  rb_define_module_function (rb_Dislin, "abs3pt", rb_abs3pt, 3);
  rb_define_module_function (rb_Dislin, "addlab", rb_addlab, 4);
  rb_define_module_function (rb_Dislin, "angle",  rb_angle,  1);
  rb_define_module_function (rb_Dislin, "arcell", rb_arcell, 7);
  rb_define_module_function (rb_Dislin, "areaf",  rb_areaf,  3);
  rb_define_module_function (rb_Dislin, "autres", rb_autres, 2);
  rb_define_module_function (rb_Dislin, "autres3d", rb_autres3d, 3);
  rb_define_module_function (rb_Dislin, "ax2grf", rb_ax2grf, 0);
  rb_define_module_function (rb_Dislin, "ax3len", rb_ax3len, 3);
  rb_define_module_function (rb_Dislin, "axclrs", rb_axclrs, 3);
  rb_define_module_function (rb_Dislin, "axends", rb_axends, 2);
  rb_define_module_function (rb_Dislin, "axgit",  rb_axgit,  0);
  rb_define_module_function (rb_Dislin, "axis3d", rb_axis3d, 3);
  rb_define_module_function (rb_Dislin, "axsbgd", rb_axsbgd, 1);
  rb_define_module_function (rb_Dislin, "axsers", rb_axsers, 0);
  rb_define_module_function (rb_Dislin, "axslen", rb_axslen, 2);
  rb_define_module_function (rb_Dislin, "axsorg", rb_axsorg, 2);
  rb_define_module_function (rb_Dislin, "axspos", rb_axspos, 2);
  rb_define_module_function (rb_Dislin, "axsscl", rb_axsscl, 2);
  rb_define_module_function (rb_Dislin, "axstyp", rb_axstyp, 1);
  rb_define_module_function (rb_Dislin, "barbor", rb_barbor, 1);
  rb_define_module_function (rb_Dislin, "barclr", rb_barclr, 3);
  rb_define_module_function (rb_Dislin, "bargrp", rb_bargrp, 2);
  rb_define_module_function (rb_Dislin, "barmod", rb_barmod, 2);
  rb_define_module_function (rb_Dislin, "baropt", rb_baropt, 2);
  rb_define_module_function (rb_Dislin, "barpos", rb_barpos, 1);
  rb_define_module_function (rb_Dislin, "bars",   rb_bars,   4);
  rb_define_module_function (rb_Dislin, "bars3d", rb_bars3d, 8);
  rb_define_module_function (rb_Dislin, "bartyp", rb_bartyp, 1);
  rb_define_module_function (rb_Dislin, "barwth", rb_barwth, 1);
  rb_define_module_function (rb_Dislin, "basalf", rb_basalf, 1);
  rb_define_module_function (rb_Dislin, "basdat", rb_basdat, 3);
  rb_define_module_function (rb_Dislin, "bezier", rb_bezier, 6);
  rb_define_module_function (rb_Dislin, "bitsi2", rb_bitsi2, 5);
  rb_define_module_function (rb_Dislin, "bitsi4", rb_bitsi4, 5);
  rb_define_module_function (rb_Dislin, "bmpfnt", rb_bmpfnt, 1);
  rb_define_module_function (rb_Dislin, "bmpmod", rb_bmpmod, 3);
  rb_define_module_function (rb_Dislin, "box2d",  rb_box2d,  0);
  rb_define_module_function (rb_Dislin, "box3d",  rb_box3d,  0);
  rb_define_module_function (rb_Dislin, "bufmod", rb_bufmod, 2);
  rb_define_module_function (rb_Dislin, "center", rb_center, 0);
  rb_define_module_function (rb_Dislin, "cgmbgd", rb_cgmbgd, 3);
  rb_define_module_function (rb_Dislin, "cgmpic", rb_cgmpic, 1);
  rb_define_module_function (rb_Dislin, "cgmver", rb_cgmver, 1);
  rb_define_module_function (rb_Dislin, "chaang", rb_chaang, 1);
  rb_define_module_function (rb_Dislin, "chacod", rb_chacod, 1);
  rb_define_module_function (rb_Dislin, "chaspc", rb_chaspc, 1);
  rb_define_module_function (rb_Dislin, "chawth", rb_chawth, 1);
  rb_define_module_function (rb_Dislin, "chnatt", rb_chnatt, 0);
  rb_define_module_function (rb_Dislin, "chnbar", rb_chnbar, 1);
  rb_define_module_function (rb_Dislin, "chncrv", rb_chncrv, 1);
  rb_define_module_function (rb_Dislin, "chndot", rb_chndot, 0);
  rb_define_module_function (rb_Dislin, "chndsh", rb_chndsh, 0);
  rb_define_module_function (rb_Dislin, "chnpie", rb_chnpie, 1);
  rb_define_module_function (rb_Dislin, "circsp", rb_circsp, 1);
  rb_define_module_function (rb_Dislin, "circ3p", rb_circ3p, 6);
  rb_define_module_function (rb_Dislin, "circle", rb_circle, 2);
  rb_define_module_function (rb_Dislin, "clip3d", rb_clip3d, 1);
  rb_define_module_function (rb_Dislin, "closfl", rb_closfl, 1);
  rb_define_module_function (rb_Dislin, "clpbor", rb_clpbor, 1);
  rb_define_module_function (rb_Dislin, "clpmod", rb_clpmod, 1);
  rb_define_module_function (rb_Dislin, "clpwin", rb_clpwin, 4);
  rb_define_module_function (rb_Dislin, "clrcyc", rb_clrcyc, 2);
  rb_define_module_function (rb_Dislin, "clrmod", rb_clrmod, 1);
  rb_define_module_function (rb_Dislin, "clswin", rb_clswin, 1);
  rb_define_module_function (rb_Dislin, "color",  rb_color,  1);
  rb_define_module_function (rb_Dislin, "colran", rb_colran, 2);
  rb_define_module_function (rb_Dislin, "colray", rb_colray, 2);
  rb_define_module_function (rb_Dislin, "complx", rb_complx, 0);
  rb_define_module_function (rb_Dislin, "conclr", rb_conclr, 2);
  rb_define_module_function (rb_Dislin, "concrv", rb_concrv, 4);
  rb_define_module_function (rb_Dislin, "cone3d", rb_cone3d, 8);
  rb_define_module_function (rb_Dislin, "confll", rb_confll, 10);
  rb_define_module_function (rb_Dislin, "congap", rb_congap, 1);
  rb_define_module_function (rb_Dislin, "conlab", rb_conlab, 1);
  rb_define_module_function (rb_Dislin, "conmat", rb_conmat, 4);
  rb_define_module_function (rb_Dislin, "conmod", rb_conmod, 2);
  rb_define_module_function (rb_Dislin, "conn3d", rb_conn3d, 3);
  rb_define_module_function (rb_Dislin, "connpt", rb_connpt, 2);
  rb_define_module_function (rb_Dislin, "conpts", rb_conpts, 11);
  rb_define_module_function (rb_Dislin, "conshd", rb_conshd, 7);
  rb_define_module_function (rb_Dislin, "conshd2", rb_conshd2, 7);
  rb_define_module_function (rb_Dislin, "conshd3d", rb_conshd3d, 7);
  rb_define_module_function (rb_Dislin, "contri", rb_contri, 9);
  rb_define_module_function (rb_Dislin, "contur", rb_contur, 6);
  rb_define_module_function (rb_Dislin, "contur2", rb_contur2, 6);
  rb_define_module_function (rb_Dislin, "cross",  rb_cross,  0);
  rb_define_module_function (rb_Dislin, "crvmat", rb_crvmat, 5);
  rb_define_module_function (rb_Dislin, "crvqdr", rb_crvqdr, 4);
  rb_define_module_function (rb_Dislin, "crvt3d", rb_crvt3d, 6);
  rb_define_module_function (rb_Dislin, "crvtri", rb_crvtri, 8);
  rb_define_module_function (rb_Dislin, "csrkey", rb_csrkey, 0);
  rb_define_module_function (rb_Dislin, "csrlin", rb_csrlin, 0);
  rb_define_module_function (rb_Dislin, "csrmod", rb_csrmod, 2);
  rb_define_module_function (rb_Dislin, "csrmov", rb_csrmov, 3);
  rb_define_module_function (rb_Dislin, "csrpos", rb_csrpos, 2);
  rb_define_module_function (rb_Dislin, "csrpt1", rb_csrpt1, 0);
  rb_define_module_function (rb_Dislin, "csrpts", rb_csrpts, 3);
  rb_define_module_function (rb_Dislin, "csrpol", rb_csrpol, 3);
  rb_define_module_function (rb_Dislin, "csrrec", rb_csrrec, 0);
  rb_define_module_function (rb_Dislin, "csrtyp", rb_csrtyp, 1);
  rb_define_module_function (rb_Dislin, "csruni", rb_csruni, 1);
  rb_define_module_function (rb_Dislin, "curv3d", rb_curv3d, 4);
  rb_define_module_function (rb_Dislin, "curv4d", rb_curv4d, 5);
  rb_define_module_function (rb_Dislin, "curve",  rb_curve,  3);
  rb_define_module_function (rb_Dislin, "curve3", rb_curve3, 4);
  rb_define_module_function (rb_Dislin, "curvmp", rb_curvmp, 3);
  rb_define_module_function (rb_Dislin, "curvx3", rb_curvx3, 4);
  rb_define_module_function (rb_Dislin, "curvy3", rb_curvy3, 4);
  rb_define_module_function (rb_Dislin, "cyli3d", rb_cyli3d, 7);
  rb_define_module_function (rb_Dislin, "dash",   rb_dash,   0);
  rb_define_module_function (rb_Dislin, "dashl",  rb_dashl,  0);
  rb_define_module_function (rb_Dislin, "dashm",  rb_dashm,  0);
  rb_define_module_function (rb_Dislin, "dbffin", rb_dbffin, 0);
  rb_define_module_function (rb_Dislin, "dbfini", rb_dbfini, 0);
  rb_define_module_function (rb_Dislin, "dbfmod", rb_dbfmod, 1);
  rb_define_module_function (rb_Dislin, "delglb", rb_delglb, 0);
  rb_define_module_function (rb_Dislin, "digits", rb_digits, 2);
  rb_define_module_function (rb_Dislin, "disalf", rb_disalf, 0);
  rb_define_module_function (rb_Dislin, "disenv", rb_disenv, 1);
  rb_define_module_function (rb_Dislin, "disfin", rb_disfin, 0);
  rb_define_module_function (rb_Dislin, "disini", rb_disini, 0);
  rb_define_module_function (rb_Dislin, "disk3d", rb_disk3d, 7);
  rb_define_module_function (rb_Dislin, "doevnt", rb_doevnt, 0);
  rb_define_module_function (rb_Dislin, "dot",    rb_dot,    0);
  rb_define_module_function (rb_Dislin, "dotl",   rb_dotl,   0);
  rb_define_module_function (rb_Dislin, "duplx",  rb_duplx,  0);
  rb_define_module_function (rb_Dislin, "dwgbut", rb_dwgbut, 2);
  rb_define_module_function (rb_Dislin, "dwgerr", rb_dwgerr, 0);
  rb_define_module_function (rb_Dislin, "dwgfil", rb_dwgfil, 3);
  rb_define_module_function (rb_Dislin, "dwglis", rb_dwglis, 3);
  rb_define_module_function (rb_Dislin, "dwgmsg", rb_dwgmsg, 1);
  rb_define_module_function (rb_Dislin, "dwgtxt", rb_dwgtxt, 2);
  rb_define_module_function (rb_Dislin, "ellips", rb_ellips, 4);
  rb_define_module_function (rb_Dislin, "endgrf", rb_endgrf, 0);
  rb_define_module_function (rb_Dislin, "erase",  rb_erase,  0);
  rb_define_module_function (rb_Dislin, "errbar", rb_errbar, 5);
  rb_define_module_function (rb_Dislin, "errdev", rb_errdev, 1);
  rb_define_module_function (rb_Dislin, "errfil", rb_errfil, 1);
  rb_define_module_function (rb_Dislin, "errmod", rb_errmod, 2);
  rb_define_module_function (rb_Dislin, "expimg", rb_expimg, 2);
  rb_define_module_function (rb_Dislin, "eushft", rb_eushft, 2);
  rb_define_module_function (rb_Dislin, "fbars",  rb_fbars,  6);
  rb_define_module_function (rb_Dislin, "fcha",   rb_fcha,   2);
  rb_define_module_function (rb_Dislin, "field",  rb_field,  6);
  rb_define_module_function (rb_Dislin, "field3d", rb_field3d, 8);
  rb_define_module_function (rb_Dislin, "expzlb", rb_expzlb, 1);
  rb_define_module_function (rb_Dislin, "filbox", rb_filbox, 4);
  rb_define_module_function (rb_Dislin, "filclr", rb_filclr, 1);
  rb_define_module_function (rb_Dislin, "filmod", rb_filmod, 1);
  rb_define_module_function (rb_Dislin, "filopt", rb_filopt, 2);
  rb_define_module_function (rb_Dislin, "filsiz", rb_filsiz, 3);
  rb_define_module_function (rb_Dislin, "filtyp", rb_filtyp, 1);
  rb_define_module_function (rb_Dislin, "filwin", rb_filwin, 4);
  rb_define_module_function (rb_Dislin, "fitscls", rb_fitscls, 0);
  rb_define_module_function (rb_Dislin, "fitsflt", rb_fitsflt, 1);
  rb_define_module_function (rb_Dislin, "fitshdu", rb_fitshdu, 1);
  rb_define_module_function (rb_Dislin, "fitsimg", rb_fitsimg, 0);
  rb_define_module_function (rb_Dislin, "fitsopn", rb_fitsopn, 1);
  rb_define_module_function (rb_Dislin, "fitsstr", rb_fitsstr, 1);
  rb_define_module_function (rb_Dislin, "fitstyp", rb_fitstyp, 1);
  rb_define_module_function (rb_Dislin, "fitsval", rb_fitsval, 1);
  rb_define_module_function (rb_Dislin, "fixspc", rb_fixspc, 1);
  rb_define_module_function (rb_Dislin, "flab3d", rb_flab3d, 0);
  rb_define_module_function (rb_Dislin, "flen",   rb_flen,   2);
  rb_define_module_function (rb_Dislin, "frame",  rb_frame,  1);
  rb_define_module_function (rb_Dislin, "frmbar", rb_frmbar, 1);
  rb_define_module_function (rb_Dislin, "frmclr", rb_frmclr, 1);
  rb_define_module_function (rb_Dislin, "frmess", rb_frmess, 1);
  rb_define_module_function (rb_Dislin, "gapcrv", rb_gapcrv, 1);
  rb_define_module_function (rb_Dislin, "gapsiz", rb_gapsiz, 2);
  rb_define_module_function (rb_Dislin, "gaxpar", rb_gaxpar, 4);
  rb_define_module_function (rb_Dislin, "getalf", rb_getalf, 0);
  rb_define_module_function (rb_Dislin, "getang", rb_getang, 0);
  rb_define_module_function (rb_Dislin, "getbpp", rb_getbpp, 0);
  rb_define_module_function (rb_Dislin, "getclp", rb_getclp, 0);
  rb_define_module_function (rb_Dislin, "getclr", rb_getclr, 0);
  rb_define_module_function (rb_Dislin, "getdig", rb_getdig, 0);
  rb_define_module_function (rb_Dislin, "getdsp", rb_getdsp, 0);
  rb_define_module_function (rb_Dislin, "getfil", rb_getfil, 0);
  rb_define_module_function (rb_Dislin, "getgrf", rb_getgrf, 1);
  rb_define_module_function (rb_Dislin, "gethgt", rb_gethgt, 0);
  rb_define_module_function (rb_Dislin, "gethnm", rb_gethnm, 0);
  rb_define_module_function (rb_Dislin, "getind", rb_getind, 1);
  rb_define_module_function (rb_Dislin, "getico", rb_getico, 2);
  rb_define_module_function (rb_Dislin, "getlab", rb_getlab, 0);
  rb_define_module_function (rb_Dislin, "getlen", rb_getlen, 0);
  rb_define_module_function (rb_Dislin, "getlev", rb_getlev, 0);
  rb_define_module_function (rb_Dislin, "getlin", rb_getlin, 0);
  rb_define_module_function (rb_Dislin, "getlit", rb_getlit, 6);
  rb_define_module_function (rb_Dislin, "getmat", rb_getmat, 8);
  rb_define_module_function (rb_Dislin, "getmfl", rb_getmfl, 0);
  rb_define_module_function (rb_Dislin, "getmix", rb_getmix, 1);
  rb_define_module_function (rb_Dislin, "getor",  rb_getor,  0);
  rb_define_module_function (rb_Dislin, "getpag", rb_getpag, 0);
  rb_define_module_function (rb_Dislin, "getpat", rb_getpat, 0);
  rb_define_module_function (rb_Dislin, "getplv", rb_getplv, 0);
  rb_define_module_function (rb_Dislin, "getpos", rb_getpos, 0);
  rb_define_module_function (rb_Dislin, "getran", rb_getran, 0);
  rb_define_module_function (rb_Dislin, "getrco", rb_getrco, 2);
  rb_define_module_function (rb_Dislin, "getres", rb_getres, 0);
  rb_define_module_function (rb_Dislin, "getrgb", rb_getrgb, 0);
  rb_define_module_function (rb_Dislin, "getscl", rb_getscl, 0);
  rb_define_module_function (rb_Dislin, "getscm", rb_getscm, 0);
  rb_define_module_function (rb_Dislin, "getscr", rb_getscr, 0);
  rb_define_module_function (rb_Dislin, "getshf", rb_getshf, 1);
  rb_define_module_function (rb_Dislin, "getsp1", rb_getsp1, 0);
  rb_define_module_function (rb_Dislin, "getsp2", rb_getsp2, 0);
  rb_define_module_function (rb_Dislin, "getsym", rb_getsym, 0);
  rb_define_module_function (rb_Dislin, "gettcl", rb_gettcl, 0);
  rb_define_module_function (rb_Dislin, "gettic", rb_gettic, 0);
  rb_define_module_function (rb_Dislin, "gettyp", rb_gettyp, 0);
  rb_define_module_function (rb_Dislin, "getuni", rb_getuni, 0);
  rb_define_module_function (rb_Dislin, "getver", rb_getver, 0);
  rb_define_module_function (rb_Dislin, "getvk",  rb_getvk,  0);
  rb_define_module_function (rb_Dislin, "getwid", rb_getwid, 0);
  rb_define_module_function (rb_Dislin, "getvlt", rb_getvlt, 0);
  rb_define_module_function (rb_Dislin, "getwin", rb_getwin, 0);
  rb_define_module_function (rb_Dislin, "getxid", rb_getxid, 1);
  rb_define_module_function (rb_Dislin, "gifmod", rb_gifmod, 2);
  rb_define_module_function (rb_Dislin, "gmxalf", rb_gmxalf, 1);
  rb_define_module_function (rb_Dislin, "gothic", rb_gothic, 0);
  rb_define_module_function (rb_Dislin, "grace",  rb_grace,  1);
  rb_define_module_function (rb_Dislin, "graf",   rb_graf,   8);
  rb_define_module_function (rb_Dislin, "graf3",  rb_graf3,  12);
  rb_define_module_function (rb_Dislin, "graf3d", rb_graf3d, 12);
  rb_define_module_function (rb_Dislin, "grafmp", rb_grafmp, 8);
  rb_define_module_function (rb_Dislin, "grafp",  rb_grafp,  5);
  rb_define_module_function (rb_Dislin, "grafr",  rb_grafr,  4);
  rb_define_module_function (rb_Dislin, "grdpol", rb_grdpol, 2);
  rb_define_module_function (rb_Dislin, "grffin", rb_grffin, 0);
  rb_define_module_function (rb_Dislin, "grfimg", rb_grfimg, 1);
  rb_define_module_function (rb_Dislin, "grfini", rb_grfini, 9);
  rb_define_module_function (rb_Dislin, "grid",   rb_grid,   2);
  rb_define_module_function (rb_Dislin, "grid3d", rb_grid3d, 3);
  rb_define_module_function (rb_Dislin, "gridim", rb_gridim, 4);
  rb_define_module_function (rb_Dislin, "gridmp", rb_gridmp, 2);
  rb_define_module_function (rb_Dislin, "gridre", rb_gridre, 4);
  rb_define_module_function (rb_Dislin, "gwgatt", rb_gwgatt, 2);
  rb_define_module_function (rb_Dislin, "gwgbox", rb_gwgbox, 1);
  rb_define_module_function (rb_Dislin, "gwgbut", rb_gwgbut, 1);
  rb_define_module_function (rb_Dislin, "gwgfil", rb_gwgfil, 1);
  rb_define_module_function (rb_Dislin, "gwgflt", rb_gwgflt, 1);
  rb_define_module_function (rb_Dislin, "gwggui", rb_gwggui, 0);
  rb_define_module_function (rb_Dislin, "gwgint", rb_gwgint, 1);
  rb_define_module_function (rb_Dislin, "gwglis", rb_gwglis, 1);
  rb_define_module_function (rb_Dislin, "gwgscl", rb_gwgscl, 1);
  rb_define_module_function (rb_Dislin, "gwgsiz", rb_gwgsiz, 1);
  rb_define_module_function (rb_Dislin, "gwgtbf", rb_gwgtbf, 3);
  rb_define_module_function (rb_Dislin, "gwgtbi", rb_gwgtbi, 3);
  rb_define_module_function (rb_Dislin, "gwgtbl", rb_gwgtbl, 4);
  rb_define_module_function (rb_Dislin, "gwgtbs", rb_gwgtbs, 3);
  rb_define_module_function (rb_Dislin, "gwgtxt", rb_gwgtxt, 1);
  rb_define_module_function (rb_Dislin, "gwgxid", rb_gwgxid, 1);
  rb_define_module_function (rb_Dislin, "height", rb_height, 1);
  rb_define_module_function (rb_Dislin, "helve",  rb_helve,  0);
  rb_define_module_function (rb_Dislin, "helves", rb_helves, 0);
  rb_define_module_function (rb_Dislin, "helvet", rb_helvet, 0);
  rb_define_module_function (rb_Dislin, "hidwin", rb_hidwin, 2);
  rb_define_module_function (rb_Dislin, "histog", rb_histog, 4);
  rb_define_module_function (rb_Dislin, "hname",  rb_hname,  1);
  rb_define_module_function (rb_Dislin, "hpgmod", rb_hpgmod, 2);
  rb_define_module_function (rb_Dislin, "hsvrgb", rb_hsvrgb, 3);
  rb_define_module_function (rb_Dislin, "hsym3d", rb_hsym3d, 1);
  rb_define_module_function (rb_Dislin, "hsymbl", rb_hsymbl, 1);
  rb_define_module_function (rb_Dislin, "htitle", rb_htitle, 1);
  rb_define_module_function (rb_Dislin, "hwfont", rb_hwfont, 0);
  rb_define_module_function (rb_Dislin, "hwmode", rb_hwmode, 2);
  rb_define_module_function (rb_Dislin, "hworig", rb_hworig, 2);
  rb_define_module_function (rb_Dislin, "hwpage", rb_hwpage, 2);
  rb_define_module_function (rb_Dislin, "hwscal", rb_hwscal, 1);
  rb_define_module_function (rb_Dislin, "imgbox", rb_imgbox, 4);
  rb_define_module_function (rb_Dislin, "imgclp", rb_imgclp, 4);
  rb_define_module_function (rb_Dislin, "imgfin", rb_imgfin, 0);
  rb_define_module_function (rb_Dislin, "imgfmt", rb_imgfmt, 1);
  rb_define_module_function (rb_Dislin, "imgini", rb_imgini, 0);
  rb_define_module_function (rb_Dislin, "imgmod", rb_imgmod, 1);
  rb_define_module_function (rb_Dislin, "imgsiz", rb_imgsiz, 2);
  rb_define_module_function (rb_Dislin, "imgtpr", rb_imgtpr, 1);
  rb_define_module_function (rb_Dislin, "inccrv", rb_inccrv, 1);
  rb_define_module_function (rb_Dislin, "incdat", rb_incdat, 3);
  rb_define_module_function (rb_Dislin, "incfil", rb_incfil, 1);
  rb_define_module_function (rb_Dislin, "incmrk", rb_incmrk, 1);
  rb_define_module_function (rb_Dislin, "indrgb", rb_indrgb, 3);
  rb_define_module_function (rb_Dislin, "intax",  rb_intax,  0);
  rb_define_module_function (rb_Dislin, "intcha", rb_intcha, 1);
  rb_define_module_function (rb_Dislin, "intlen", rb_intlen, 1);
  rb_define_module_function (rb_Dislin, "intrgb", rb_intrgb, 3);
  rb_define_module_function (rb_Dislin, "intutf", rb_intutf, 2);
  rb_define_module_function (rb_Dislin, "isopts", rb_isopts, 12);
  rb_define_module_function (rb_Dislin, "itmcat", rb_itmcat, 2);
  rb_define_module_function (rb_Dislin, "itmcnt", rb_itmcnt, 1);
  rb_define_module_function (rb_Dislin, "itmncat", rb_itmncat, 3);
  rb_define_module_function (rb_Dislin, "itmstr", rb_itmstr, 2);
  rb_define_module_function (rb_Dislin, "jusbar", rb_jusbar, 1);
  rb_define_module_function (rb_Dislin, "labclr", rb_labclr, 2);
  rb_define_module_function (rb_Dislin, "labdig", rb_labdig, 2);
  rb_define_module_function (rb_Dislin, "labdis", rb_labdis, 2);
  rb_define_module_function (rb_Dislin, "labels", rb_labels, 2);
  rb_define_module_function (rb_Dislin, "labjus", rb_labjus, 2);
  rb_define_module_function (rb_Dislin, "labl3d", rb_labl3d, 1);
  rb_define_module_function (rb_Dislin, "labmod", rb_labmod, 3);
  rb_define_module_function (rb_Dislin, "labpos", rb_labpos, 2);
  rb_define_module_function (rb_Dislin, "labtyp", rb_labtyp, 2);
  rb_define_module_function (rb_Dislin, "legbgd", rb_legbgd, 1);
  rb_define_module_function (rb_Dislin, "legclr", rb_legclr, 0);
  rb_define_module_function (rb_Dislin, "legend", rb_legend, 2);
  rb_define_module_function (rb_Dislin, "legini", rb_legini, 3);
  rb_define_module_function (rb_Dislin, "leglin", rb_leglin, 3);
  rb_define_module_function (rb_Dislin, "legopt", rb_legopt, 3);
  rb_define_module_function (rb_Dislin, "legpat", rb_legpat, 6);
  rb_define_module_function (rb_Dislin, "legpos", rb_legpos, 2);
  rb_define_module_function (rb_Dislin, "legsel", rb_legsel, 2);
  rb_define_module_function (rb_Dislin, "legtit", rb_legtit, 1);
  rb_define_module_function (rb_Dislin, "legtbl", rb_legtbl, 2);
  rb_define_module_function (rb_Dislin, "legtyp", rb_legtyp, 1);
  rb_define_module_function (rb_Dislin, "legval", rb_legval, 2);
  rb_define_module_function (rb_Dislin, "lfttit", rb_lfttit, 0);
  rb_define_module_function (rb_Dislin, "licmod", rb_licmod, 2);
  rb_define_module_function (rb_Dislin, "licpts", rb_licpts, 6);
  rb_define_module_function (rb_Dislin, "light",  rb_light,  1);
  rb_define_module_function (rb_Dislin, "linclr", rb_linclr, 2);
  rb_define_module_function (rb_Dislin, "lincyc", rb_lincyc, 2);
  rb_define_module_function (rb_Dislin, "line",   rb_line,   4);
  rb_define_module_function (rb_Dislin, "linfit", rb_linfit, 4);
  rb_define_module_function (rb_Dislin, "linmod", rb_linmod, 2);
  rb_define_module_function (rb_Dislin, "linesp", rb_linesp, 1);
  rb_define_module_function (rb_Dislin, "lintyp", rb_lintyp, 1);
  rb_define_module_function (rb_Dislin, "linwid", rb_linwid, 1);
  rb_define_module_function (rb_Dislin, "litmod", rb_litmod, 2);
  rb_define_module_function (rb_Dislin, "litop3", rb_litop3, 5);
  rb_define_module_function (rb_Dislin, "litopt", rb_litopt, 3);
  rb_define_module_function (rb_Dislin, "litpos", rb_litpos, 5);
  rb_define_module_function (rb_Dislin, "lncap",  rb_lncap,  1);
  rb_define_module_function (rb_Dislin, "lnjoin", rb_lnjoin, 1);
  rb_define_module_function (rb_Dislin, "lnmlt",  rb_lnmlt,  1);
  rb_define_module_function (rb_Dislin, "logtic", rb_logtic, 1);
  rb_define_module_function (rb_Dislin, "mapbas", rb_mapbas, 1);
  rb_define_module_function (rb_Dislin, "mapfil", rb_mapfil, 2);
  rb_define_module_function (rb_Dislin, "mapimg", rb_mapimg, 7);
  rb_define_module_function (rb_Dislin, "maplab", rb_maplab, 2);
  rb_define_module_function (rb_Dislin, "maplev", rb_maplev, 1);
  rb_define_module_function (rb_Dislin, "mapmod", rb_mapmod, 1);
  rb_define_module_function (rb_Dislin, "mapopt", rb_mapopt, 2);
  rb_define_module_function (rb_Dislin, "mappol", rb_mappol, 2);
  rb_define_module_function (rb_Dislin, "mapref", rb_mapref, 2);
  rb_define_module_function (rb_Dislin, "mapsph", rb_mapsph, 1);
  rb_define_module_function (rb_Dislin, "marker", rb_marker, 1);
  rb_define_module_function (rb_Dislin, "mdfmat", rb_mdfmat, 3);
  rb_define_module_function (rb_Dislin, "messag", rb_messag, 3);
  rb_define_module_function (rb_Dislin, "matop3", rb_matop3, 4);
  rb_define_module_function (rb_Dislin, "matopt", rb_matopt, 2);
  rb_define_module_function (rb_Dislin, "metafl", rb_metafl, 1);
  rb_define_module_function (rb_Dislin, "mixalf", rb_mixalf, 0);
  rb_define_module_function (rb_Dislin, "mixleg", rb_mixleg, 0);
  rb_define_module_function (rb_Dislin, "mpaepl", rb_mpaepl, 1);
  rb_define_module_function (rb_Dislin, "mplang", rb_mplang, 1);
  rb_define_module_function (rb_Dislin, "mplclr", rb_mplclr, 2);
  rb_define_module_function (rb_Dislin, "mplpos", rb_mplpos, 2);
  rb_define_module_function (rb_Dislin, "mplsiz", rb_mplsiz, 1);
  rb_define_module_function (rb_Dislin, "mpslogo", rb_mpslogo, 4);
  rb_define_module_function (rb_Dislin, "mrkclr", rb_mrkclr, 1);
  rb_define_module_function (rb_Dislin, "msgbox", rb_msgbox, 1);
  rb_define_module_function (rb_Dislin, "mshclr", rb_mshclr, 1);
  rb_define_module_function (rb_Dislin, "mshcrv", rb_mshcrv, 1);
  rb_define_module_function (rb_Dislin, "mylab",  rb_mylab,  3);
  rb_define_module_function (rb_Dislin, "myline", rb_myline, 2);
  rb_define_module_function (rb_Dislin, "mypat",  rb_mypat,  4);
  rb_define_module_function (rb_Dislin, "mysymb", rb_mysymb, 5);
  rb_define_module_function (rb_Dislin, "myvlt",  rb_myvlt,  4);
  rb_define_module_function (rb_Dislin, "namdis", rb_namdis, 2);
  rb_define_module_function (rb_Dislin, "name",   rb_name,   2);
  rb_define_module_function (rb_Dislin, "namjus", rb_namjus, 2);
  rb_define_module_function (rb_Dislin, "neglog", rb_neglog, 1);
  rb_define_module_function (rb_Dislin, "newmix", rb_newmix, 0);
  rb_define_module_function (rb_Dislin, "newpag", rb_newpag, 0);
  rb_define_module_function (rb_Dislin, "nlmess", rb_nlmess, 1);
  rb_define_module_function (rb_Dislin, "nlnumb", rb_nlnumb, 2);
  rb_define_module_function (rb_Dislin, "noarln", rb_noarln, 0);
  rb_define_module_function (rb_Dislin, "nobar",  rb_nobar,  0);
  rb_define_module_function (rb_Dislin, "nobgd",  rb_nobgd,  0);
  rb_define_module_function (rb_Dislin, "nochek", rb_nochek, 0);
  rb_define_module_function (rb_Dislin, "noclip", rb_noclip, 0);
  rb_define_module_function (rb_Dislin, "nofill", rb_nofill, 0);
  rb_define_module_function (rb_Dislin, "nograf", rb_nograf, 0);
  rb_define_module_function (rb_Dislin, "nohide", rb_nohide, 0);
  rb_define_module_function (rb_Dislin, "noline", rb_noline, 0);
  rb_define_module_function (rb_Dislin, "number", rb_number, 4);
  rb_define_module_function (rb_Dislin, "numfmt", rb_numfmt, 1);
  rb_define_module_function (rb_Dislin, "numode", rb_numode, 4);
  rb_define_module_function (rb_Dislin, "nwkday", rb_nwkday, 3);
  rb_define_module_function (rb_Dislin, "nxlegn", rb_nxlegn, 1);
  rb_define_module_function (rb_Dislin, "nxpixl", rb_nxpixl, 2);
  rb_define_module_function (rb_Dislin, "nxposn", rb_nxposn, 1);
  rb_define_module_function (rb_Dislin, "nylegn", rb_nylegn, 1);
  rb_define_module_function (rb_Dislin, "nypixl", rb_nypixl, 2);
  rb_define_module_function (rb_Dislin, "nyposn", rb_nyposn, 1);
  rb_define_module_function (rb_Dislin, "nzposn", rb_nzposn, 1);
  rb_define_module_function (rb_Dislin, "openfl", rb_openfl, 3);
  rb_define_module_function (rb_Dislin, "opnwin", rb_opnwin, 1);
  rb_define_module_function (rb_Dislin, "origin", rb_origin, 2);
  rb_define_module_function (rb_Dislin, "page",   rb_page,   2);
  rb_define_module_function (rb_Dislin, "pagera", rb_pagera, 0);
  rb_define_module_function (rb_Dislin, "pagfll", rb_pagfll, 1);
  rb_define_module_function (rb_Dislin, "paghdr", rb_paghdr, 4);
  rb_define_module_function (rb_Dislin, "pagmod", rb_pagmod, 1);
  rb_define_module_function (rb_Dislin, "pagorg", rb_pagorg, 1);
  rb_define_module_function (rb_Dislin, "pagwin", rb_pagwin, 2);
  rb_define_module_function (rb_Dislin, "patcyc", rb_patcyc, 2);
  rb_define_module_function (rb_Dislin, "pdfbuf", rb_pdfbuf, 0);
  rb_define_module_function (rb_Dislin, "pdfmod", rb_pdfmod, 2);
  rb_define_module_function (rb_Dislin, "pdfmrk", rb_pdfmrk, 2);
  rb_define_module_function (rb_Dislin, "penwid", rb_penwid, 1);
  rb_define_module_function (rb_Dislin, "pie",    rb_pie,    5);
  rb_define_module_function (rb_Dislin, "piebor", rb_piebor, 1);
  rb_define_module_function (rb_Dislin, "piecbk", rb_piecbk, 1);
  rb_define_module_function (rb_Dislin, "pieclr", rb_pieclr, 3);
  rb_define_module_function (rb_Dislin, "pieexp", rb_pieexp, 0);
  rb_define_module_function (rb_Dislin, "piegrf", rb_piegrf, 4);
  rb_define_module_function (rb_Dislin, "pielab", rb_pielab, 2);
  rb_define_module_function (rb_Dislin, "pieopt", rb_pieopt, 2);
  rb_define_module_function (rb_Dislin, "pierot", rb_pierot, 1);
  rb_define_module_function (rb_Dislin, "pietyp", rb_pietyp, 1);
  rb_define_module_function (rb_Dislin, "pieval", rb_pieval, 2);
  rb_define_module_function (rb_Dislin, "pievec", rb_pievec, 2);
  rb_define_module_function (rb_Dislin, "pike3d", rb_pike3d, 9);
  rb_define_module_function (rb_Dislin, "plat3d", rb_plat3d, 5);
  rb_define_module_function (rb_Dislin, "pngmod", rb_pngmod, 2);
  rb_define_module_function (rb_Dislin, "plyfin", rb_plyfin, 2);
  rb_define_module_function (rb_Dislin, "plyini", rb_plyini, 1);
  rb_define_module_function (rb_Dislin, "point",  rb_point,  5);
  rb_define_module_function (rb_Dislin, "polar",  rb_polar,  5);
  rb_define_module_function (rb_Dislin, "polclp", rb_polclp, 8);
  rb_define_module_function (rb_Dislin, "polcrv", rb_polcrv, 1);
  rb_define_module_function (rb_Dislin, "polmod", rb_polmod, 2);
  rb_define_module_function (rb_Dislin, "pos2pt", rb_pos2pt, 2);
  rb_define_module_function (rb_Dislin, "pos3pt", rb_pos3pt, 3);
  rb_define_module_function (rb_Dislin, "posbar", rb_posbar, 1);
  rb_define_module_function (rb_Dislin, "posifl", rb_posifl, 2);
  rb_define_module_function (rb_Dislin, "proj3d", rb_proj3d, 1);
  rb_define_module_function (rb_Dislin, "projct", rb_projct, 1);
  rb_define_module_function (rb_Dislin, "psfont", rb_psfont, 1);
  rb_define_module_function (rb_Dislin, "psmeta", rb_psmeta, 2);
  rb_define_module_function (rb_Dislin, "psmode", rb_psmode, 1);
  rb_define_module_function (rb_Dislin, "pt2pos", rb_pt2pos, 2);
  rb_define_module_function (rb_Dislin, "pyra3d", rb_pyra3d, 7);
  rb_define_module_function (rb_Dislin, "qplbar", rb_qplbar, 2);
  rb_define_module_function (rb_Dislin, "qplclr", rb_qplclr, 3);
  rb_define_module_function (rb_Dislin, "qplcon", rb_qplcon, 4);
  rb_define_module_function (rb_Dislin, "qplcrv", rb_qplcrv, 4);
  rb_define_module_function (rb_Dislin, "qplot",  rb_qplot,  3);
  rb_define_module_function (rb_Dislin, "qplpie", rb_qplpie, 2);
  rb_define_module_function (rb_Dislin, "qplsca", rb_qplsca, 3);
  rb_define_module_function (rb_Dislin, "qplsur", rb_qplsur, 3);
  rb_define_module_function (rb_Dislin, "qplscl", rb_qplscl, 5);
  rb_define_module_function (rb_Dislin, "quad3d", rb_quad3d, 6);
  rb_define_module_function (rb_Dislin, "rbfpng", rb_rbfpng, 0);
  rb_define_module_function (rb_Dislin, "rbmp",   rb_rbmp,   1);
  rb_define_module_function (rb_Dislin, "readfl", rb_readfl, 2);
  rb_define_module_function (rb_Dislin, "reawgt", rb_reawgt, 0);
  rb_define_module_function (rb_Dislin, "recfll", rb_recfll, 5);
  rb_define_module_function (rb_Dislin, "rectan", rb_rectan, 4);
  rb_define_module_function (rb_Dislin, "rel3pt", rb_rel3pt, 3);
  rb_define_module_function (rb_Dislin, "resatt", rb_resatt, 0);
  rb_define_module_function (rb_Dislin, "reset",  rb_reset,  1);
  rb_define_module_function (rb_Dislin, "revscr", rb_revscr, 0);
  rb_define_module_function (rb_Dislin, "rgbhsv", rb_rgbhsv, 3);
  rb_define_module_function (rb_Dislin, "rgif",   rb_rgif,   1);
  rb_define_module_function (rb_Dislin, "rgtlab", rb_rgtlab, 0);
  rb_define_module_function (rb_Dislin, "rimage", rb_rimage, 1);
  rb_define_module_function (rb_Dislin, "rlarc",  rb_rlarc,  7);
  rb_define_module_function (rb_Dislin, "rlarea", rb_rlarea, 3);
  rb_define_module_function (rb_Dislin, "rlcirc", rb_rlcirc, 3);
  rb_define_module_function (rb_Dislin, "rlconn", rb_rlconn, 2);
  rb_define_module_function (rb_Dislin, "rlell",  rb_rlell,  4);
  rb_define_module_function (rb_Dislin, "rline",  rb_rline,  4);
  rb_define_module_function (rb_Dislin, "rlmess", rb_rlmess, 3);
  rb_define_module_function (rb_Dislin, "rlnumb", rb_rlnumb, 4);
  rb_define_module_function (rb_Dislin, "rlpie",  rb_rlpie,  5);
  rb_define_module_function (rb_Dislin, "rlpoin", rb_rlpoin, 5);
  rb_define_module_function (rb_Dislin, "rlrec",  rb_rlrec,  4);
  rb_define_module_function (rb_Dislin, "rlrnd",  rb_rlrnd,  5);
  rb_define_module_function (rb_Dislin, "rlsec",  rb_rlsec,  7);
  rb_define_module_function (rb_Dislin, "rlstrt", rb_rlstrt, 2);
  rb_define_module_function (rb_Dislin, "rlsymb", rb_rlsymb, 3);
  rb_define_module_function (rb_Dislin, "rlvec",  rb_rlvec,  5);
  rb_define_module_function (rb_Dislin, "rlwind", rb_rlwind, 5);
  rb_define_module_function (rb_Dislin, "rndrec", rb_rndrec, 5);
  rb_define_module_function (rb_Dislin, "rpixel", rb_rpixel, 2);
  rb_define_module_function (rb_Dislin, "rpixls", rb_rpixls, 4);
  rb_define_module_function (rb_Dislin, "rpng",   rb_rpng,   1);
  rb_define_module_function (rb_Dislin, "rot3d",  rb_rot3d,  3);
  rb_define_module_function (rb_Dislin, "rppm",   rb_rppm,   1);
  rb_define_module_function (rb_Dislin, "rpxrow", rb_rpxrow, 3);
  rb_define_module_function (rb_Dislin, "rtiff",  rb_rtiff,  1);
  rb_define_module_function (rb_Dislin, "rvynam", rb_rvynam, 0);
  rb_define_module_function (rb_Dislin, "scale",  rb_scale,  2);
  rb_define_module_function (rb_Dislin, "sclfac", rb_sclfac, 1);
  rb_define_module_function (rb_Dislin, "sclmod", rb_sclmod, 1);
  rb_define_module_function (rb_Dislin, "scrmod", rb_scrmod, 1);
  rb_define_module_function (rb_Dislin, "sector", rb_sector, 7);
  rb_define_module_function (rb_Dislin, "selwin", rb_selwin, 1);
  rb_define_module_function (rb_Dislin, "sendbf", rb_sendbf, 0);
  rb_define_module_function (rb_Dislin, "sendmb", rb_sendmb, 0);
  rb_define_module_function (rb_Dislin, "sendok", rb_sendok, 0);
  rb_define_module_function (rb_Dislin, "serif",  rb_serif,  0);
  rb_define_module_function (rb_Dislin, "setbas", rb_setbas, 1);
  rb_define_module_function (rb_Dislin, "setcbk", rb_setcbk, 2);
  rb_define_module_function (rb_Dislin, "setclr", rb_setclr, 1);
  rb_define_module_function (rb_Dislin, "setcsr", rb_setcsr, 1);
  rb_define_module_function (rb_Dislin, "setexp", rb_setexp, 1);
  rb_define_module_function (rb_Dislin, "setfce", rb_setfce, 1);
  rb_define_module_function (rb_Dislin, "setfil", rb_setfil, 1);
  rb_define_module_function (rb_Dislin, "setgrf", rb_setgrf, 4);
  rb_define_module_function (rb_Dislin, "setind", rb_setind, 4);
  rb_define_module_function (rb_Dislin, "setmix", rb_setmix, 2);
  rb_define_module_function (rb_Dislin, "setpag", rb_setpag, 1);
  rb_define_module_function (rb_Dislin, "setres", rb_setres, 2);
  rb_define_module_function (rb_Dislin, "setres3d", rb_setres3d, 3);
  rb_define_module_function (rb_Dislin, "setrgb", rb_setrgb, 3);
  rb_define_module_function (rb_Dislin, "setscl", rb_setscl, 3);
  rb_define_module_function (rb_Dislin, "setvlt", rb_setvlt, 1);
  rb_define_module_function (rb_Dislin, "setxid", rb_setxid, 2);
  rb_define_module_function (rb_Dislin, "shdafr", rb_shdafr, 4);
  rb_define_module_function (rb_Dislin, "shdasi", rb_shdasi, 4);
  rb_define_module_function (rb_Dislin, "shdaus", rb_shdaus, 4);
  rb_define_module_function (rb_Dislin, "shdcha", rb_shdcha, 0);
  rb_define_module_function (rb_Dislin, "shdcrv", rb_shdcrv, 6);
  rb_define_module_function (rb_Dislin, "shdeur", rb_shdeur, 4);
  rb_define_module_function (rb_Dislin, "shdfac", rb_shdfac, 1);
  rb_define_module_function (rb_Dislin, "shdmap", rb_shdmap, 1);
  rb_define_module_function (rb_Dislin, "shdmod", rb_shdmod, 2);
  rb_define_module_function (rb_Dislin, "shdpat", rb_shdpat, 1);
  rb_define_module_function (rb_Dislin, "shdnor", rb_shdnor, 4);
  rb_define_module_function (rb_Dislin, "shdsou", rb_shdsou, 4);
  rb_define_module_function (rb_Dislin, "shdusa", rb_shdusa, 4);
  rb_define_module_function (rb_Dislin, "shield", rb_shield, 2);
  rb_define_module_function (rb_Dislin, "shlcir", rb_shlcir, 3);
  rb_define_module_function (rb_Dislin, "shldel", rb_shldel, 1);
  rb_define_module_function (rb_Dislin, "shlell", rb_shlell, 5);
  rb_define_module_function (rb_Dislin, "shlind", rb_shlind, 0);
  rb_define_module_function (rb_Dislin, "shlpie", rb_shlpie, 5);
  rb_define_module_function (rb_Dislin, "shlpol", rb_shlpol, 3);
  rb_define_module_function (rb_Dislin, "shlrct", rb_shlrct, 5);
  rb_define_module_function (rb_Dislin, "shlrec", rb_shlrec, 4);
  rb_define_module_function (rb_Dislin, "shlres", rb_shlres, 1);
  rb_define_module_function (rb_Dislin, "shlsur", rb_shlsur, 0);
  rb_define_module_function (rb_Dislin, "shlvis", rb_shlvis, 2);
  rb_define_module_function (rb_Dislin, "simplx", rb_simplx, 0);
  rb_define_module_function (rb_Dislin, "skipfl", rb_skipfl, 2);
  rb_define_module_function (rb_Dislin, "smxalf", rb_smxalf, 4);
  rb_define_module_function (rb_Dislin, "solid",  rb_solid,  0);
  rb_define_module_function (rb_Dislin, "sortr1", rb_sortr1, 3);
  rb_define_module_function (rb_Dislin, "sortr2", rb_sortr2, 4);
  rb_define_module_function (rb_Dislin, "spcbar", rb_spcbar, 1);
  rb_define_module_function (rb_Dislin, "sphe3d", rb_sphe3d, 6);
  rb_define_module_function (rb_Dislin, "spline", rb_spline, 5);
  rb_define_module_function (rb_Dislin, "splmod", rb_splmod, 2);
  rb_define_module_function (rb_Dislin, "stmmod", rb_stmmod, 2);
  rb_define_module_function (rb_Dislin, "stmopt", rb_stmopt, 2);
  rb_define_module_function (rb_Dislin, "stmpts", rb_stmpts, 11);
  rb_define_module_function (rb_Dislin, "stmtri", rb_stmtri, 12);
  rb_define_module_function (rb_Dislin, "stmval", rb_stmval, 2);
  rb_define_module_function (rb_Dislin, "stream", rb_stream, 9);
  rb_define_module_function (rb_Dislin, "stream3d", rb_stream3d, 13);
  rb_define_module_function (rb_Dislin, "strt3d", rb_strt3d, 3);
  rb_define_module_function (rb_Dislin, "strtpt", rb_strtpt, 2);
  rb_define_module_function (rb_Dislin, "surclr", rb_surclr, 2);
  rb_define_module_function (rb_Dislin, "surfce", rb_surfce, 5);
  rb_define_module_function (rb_Dislin, "surfcp", rb_surfcp, 7);
  rb_define_module_function (rb_Dislin, "surfun", rb_surfun, 5);
  rb_define_module_function (rb_Dislin, "suriso", rb_suriso, 8);
  rb_define_module_function (rb_Dislin, "surmat", rb_surmat, 5);
  rb_define_module_function (rb_Dislin, "surmsh", rb_surmsh, 1);
  rb_define_module_function (rb_Dislin, "suropt", rb_suropt, 1);
  rb_define_module_function (rb_Dislin, "surshc", rb_surshc, 6);
  rb_define_module_function (rb_Dislin, "surshd", rb_surshd, 5);
  rb_define_module_function (rb_Dislin, "sursze", rb_sursze, 4);
  rb_define_module_function (rb_Dislin, "surtri", rb_surtri, 8);
  rb_define_module_function (rb_Dislin, "survis", rb_survis, 1);
  rb_define_module_function (rb_Dislin, "swapi4", rb_swapi4, 2);
  rb_define_module_function (rb_Dislin, "swgatt", rb_swgatt, 3);
  rb_define_module_function (rb_Dislin, "swgbgd", rb_swgbgd, 4);
  rb_define_module_function (rb_Dislin, "swgbox", rb_swgbox, 2);
  rb_define_module_function (rb_Dislin, "swgbut", rb_swgbut, 2);
  rb_define_module_function (rb_Dislin, "swgcb2", rb_swgcb2, 2);
  rb_define_module_function (rb_Dislin, "swgcb3", rb_swgcb3, 2);
  rb_define_module_function (rb_Dislin, "swgcbk", rb_swgcbk, 2);
  rb_define_module_function (rb_Dislin, "swgclr", rb_swgclr, 4);
  rb_define_module_function (rb_Dislin, "swgdrw", rb_swgdrw, 1);
  rb_define_module_function (rb_Dislin, "swgfgd", rb_swgfgd, 4);
  rb_define_module_function (rb_Dislin, "swgfil", rb_swgfil, 2);
  rb_define_module_function (rb_Dislin, "swgflt", rb_swgflt, 3);
  rb_define_module_function (rb_Dislin, "swgfnt", rb_swgfnt, 2);
  rb_define_module_function (rb_Dislin, "swgfoc", rb_swgfoc, 1);
  rb_define_module_function (rb_Dislin, "swghlp", rb_swghlp, 1);
  rb_define_module_function (rb_Dislin, "swgint", rb_swgint, 2);
  rb_define_module_function (rb_Dislin, "swgiop", rb_swgiop, 2);
  rb_define_module_function (rb_Dislin, "swgjus", rb_swgjus, 2);
  rb_define_module_function (rb_Dislin, "swglis", rb_swglis, 2);
  rb_define_module_function (rb_Dislin, "swgmix", rb_swgmix, 2);
  rb_define_module_function (rb_Dislin, "swgmrg", rb_swgmrg, 2);
  rb_define_module_function (rb_Dislin, "swgoff", rb_swgoff, 2);
  rb_define_module_function (rb_Dislin, "swgopt", rb_swgopt, 2);
  rb_define_module_function (rb_Dislin, "swgpop", rb_swgpop, 1);
  rb_define_module_function (rb_Dislin, "swgpos", rb_swgpos, 2);
  rb_define_module_function (rb_Dislin, "swgray", rb_swgray, 3);
  rb_define_module_function (rb_Dislin, "swgscl", rb_swgscl, 2);
  rb_define_module_function (rb_Dislin, "swgsiz", rb_swgsiz, 2);
  rb_define_module_function (rb_Dislin, "swgspc", rb_swgspc, 2);
  rb_define_module_function (rb_Dislin, "swgstp", rb_swgstp, 1);
  rb_define_module_function (rb_Dislin, "swgtbf", rb_swgtbf, 6);
  rb_define_module_function (rb_Dislin, "swgtbi", rb_swgtbi, 5);
  rb_define_module_function (rb_Dislin, "swgtbl", rb_swgtbl, 6);
  rb_define_module_function (rb_Dislin, "swgtbs", rb_swgtbs, 5);
  rb_define_module_function (rb_Dislin, "swgtit", rb_swgtit, 1);
  rb_define_module_function (rb_Dislin, "swgtxt", rb_swgtxt, 2);
  rb_define_module_function (rb_Dislin, "swgtyp", rb_swgtyp, 2);
  rb_define_module_function (rb_Dislin, "swgval", rb_swgval, 2);
  rb_define_module_function (rb_Dislin, "swgwin", rb_swgwin, 4);
  rb_define_module_function (rb_Dislin, "swgwth", rb_swgwth, 1);
  rb_define_module_function (rb_Dislin, "symb3d", rb_symb3d, 4);
  rb_define_module_function (rb_Dislin, "symbol", rb_symbol, 3);
  rb_define_module_function (rb_Dislin, "symfil", rb_symfil, 2);
  rb_define_module_function (rb_Dislin, "symrot", rb_symrot, 1);
  rb_define_module_function (rb_Dislin, "tellfl", rb_tellfl, 1);
  rb_define_module_function (rb_Dislin, "texmod", rb_texmod, 1);
  rb_define_module_function (rb_Dislin, "texopt", rb_texopt, 2);
  rb_define_module_function (rb_Dislin, "texval", rb_texval, 2);
  rb_define_module_function (rb_Dislin, "thkc3d", rb_thkc3d, 1);
  rb_define_module_function (rb_Dislin, "thkcrv", rb_thkcrv, 1);
  rb_define_module_function (rb_Dislin, "thrfin", rb_thrfin, 0);
  rb_define_module_function (rb_Dislin, "thrini", rb_thrini, 1);
  rb_define_module_function (rb_Dislin, "ticks",  rb_ticks,  2);
  rb_define_module_function (rb_Dislin, "ticlen", rb_ticlen, 2);
  rb_define_module_function (rb_Dislin, "ticmod", rb_ticmod, 2);
  rb_define_module_function (rb_Dislin, "ticpos", rb_ticpos, 2);
  rb_define_module_function (rb_Dislin, "tifmod", rb_tifmod, 3);
  rb_define_module_function (rb_Dislin, "tiforg", rb_tiforg, 2);
  rb_define_module_function (rb_Dislin, "tifwin", rb_tifwin, 4);
  rb_define_module_function (rb_Dislin, "timopt", rb_timopt, 0);
  rb_define_module_function (rb_Dislin, "titjus", rb_titjus, 1);
  rb_define_module_function (rb_Dislin, "title",  rb_title,  0);
  rb_define_module_function (rb_Dislin, "titlin", rb_titlin, 2);
  rb_define_module_function (rb_Dislin, "titpos", rb_titpos, 1);
  rb_define_module_function (rb_Dislin, "torus3d", rb_torus3d, 10);
  rb_define_module_function (rb_Dislin, "tprfin", rb_tprfin, 0);
  rb_define_module_function (rb_Dislin, "tprini", rb_tprini, 0);
  rb_define_module_function (rb_Dislin, "tprmod", rb_tprmod, 2);
  rb_define_module_function (rb_Dislin, "tprval", rb_tprval, 1);
  rb_define_module_function (rb_Dislin, "tr3res", rb_tr3res, 0);
  rb_define_module_function (rb_Dislin, "tr3axs", rb_tr3axs, 4);
  rb_define_module_function (rb_Dislin, "tr3rot", rb_tr3rot, 3);
  rb_define_module_function (rb_Dislin, "tr3scl", rb_tr3scl, 3);
  rb_define_module_function (rb_Dislin, "tr3shf", rb_tr3shf, 3);
  rb_define_module_function (rb_Dislin, "trfco1", rb_trfco1, 4);
  rb_define_module_function (rb_Dislin, "trfco2", rb_trfco2, 5);
  rb_define_module_function (rb_Dislin, "trfco3", rb_trfco3, 6);
  rb_define_module_function (rb_Dislin, "trfdat", rb_trfdat, 1);
  rb_define_module_function (rb_Dislin, "trfmat", rb_trfmat, 5);
  rb_define_module_function (rb_Dislin, "trfrel", rb_trfrel, 3);
  rb_define_module_function (rb_Dislin, "trfres", rb_trfres, 0);
  rb_define_module_function (rb_Dislin, "trfrot", rb_trfrot, 3);
  rb_define_module_function (rb_Dislin, "trfscl", rb_trfscl, 2);
  rb_define_module_function (rb_Dislin, "trfshf", rb_trfshf, 2);
  rb_define_module_function (rb_Dislin, "tria3d", rb_tria3d, 3);
  rb_define_module_function (rb_Dislin, "triang", rb_triang, 7);
  rb_define_module_function (rb_Dislin, "triflc", rb_triflc, 4);
  rb_define_module_function (rb_Dislin, "trifll", rb_trifll, 2);
  rb_define_module_function (rb_Dislin, "triplx", rb_triplx, 0);
  rb_define_module_function (rb_Dislin, "tripts", rb_tripts, 14);
  rb_define_module_function (rb_Dislin, "trmlen", rb_trmlen, 1);
  rb_define_module_function (rb_Dislin, "ttfont", rb_ttfont, 1);
  rb_define_module_function (rb_Dislin, "tube3d", rb_tube3d, 9);
  rb_define_module_function (rb_Dislin, "txtbgd", rb_txtbgd, 1);
  rb_define_module_function (rb_Dislin, "txtjus", rb_txtjus, 1);
  rb_define_module_function (rb_Dislin, "txture", rb_txture, 2);
  rb_define_module_function (rb_Dislin, "unit",   rb_unit,   1);
  rb_define_module_function (rb_Dislin, "units",  rb_units,  1);
  rb_define_module_function (rb_Dislin, "upstr",  rb_upstr,  1);
  rb_define_module_function (rb_Dislin, "utfint", rb_utfint, 1);
  rb_define_module_function (rb_Dislin, "vang3d", rb_vang3d, 1);
  rb_define_module_function (rb_Dislin, "vclp3d", rb_vclp3d, 2);
  rb_define_module_function (rb_Dislin, "vecclr", rb_vecclr, 1);
  rb_define_module_function (rb_Dislin, "vecf3d", rb_vecf3d, 8);
  rb_define_module_function (rb_Dislin, "vecfld", rb_vecfld, 6);
  rb_define_module_function (rb_Dislin, "vecmat", rb_vecmat, 7);
  rb_define_module_function (rb_Dislin, "vecmat3d", rb_vecmat3d, 10);
  rb_define_module_function (rb_Dislin, "vecopt", rb_vecopt, 2);
  rb_define_module_function (rb_Dislin, "vector", rb_vector, 5);
  rb_define_module_function (rb_Dislin, "vectr3", rb_vectr3, 7);
  rb_define_module_function (rb_Dislin, "vfoc3d", rb_vfoc3d, 4);
  rb_define_module_function (rb_Dislin, "view3d", rb_view3d, 4);
  rb_define_module_function (rb_Dislin, "vkxbar", rb_vkxbar, 1);
  rb_define_module_function (rb_Dislin, "vkybar", rb_vkybar, 1);
  rb_define_module_function (rb_Dislin, "vkytit", rb_vkytit, 1);
  rb_define_module_function (rb_Dislin, "vltfil", rb_vltfil, 2);
  rb_define_module_function (rb_Dislin, "vscl3d", rb_vscl3d, 1);
  rb_define_module_function (rb_Dislin, "vtx3d",  rb_vtx3d,  5);
  rb_define_module_function (rb_Dislin, "vtxc3d", rb_vtxc3d, 6);
  rb_define_module_function (rb_Dislin, "vtxn3d", rb_vtxn3d, 8);
  rb_define_module_function (rb_Dislin, "vup3d",  rb_vup3d,  1);
  rb_define_module_function (rb_Dislin, "wgapp",  rb_wgapp,  2);
  rb_define_module_function (rb_Dislin, "wgappb", rb_wgappb, 4);
  rb_define_module_function (rb_Dislin, "wgbas",  rb_wgbas,  2);
  rb_define_module_function (rb_Dislin, "wgbox",  rb_wgbox,  3);
  rb_define_module_function (rb_Dislin, "wgbut",  rb_wgbut,  3);
  rb_define_module_function (rb_Dislin, "wgcmd",  rb_wgcmd,  3);
  rb_define_module_function (rb_Dislin, "wgdlis", rb_wgdlis, 3);
  rb_define_module_function (rb_Dislin, "wgdraw", rb_wgdraw, 1);
  rb_define_module_function (rb_Dislin, "wgfil",  rb_wgfil,  4);
  rb_define_module_function (rb_Dislin, "wgfin",  rb_wgfin,  0);
  rb_define_module_function (rb_Dislin, "wgini",  rb_wgini,  1);
  rb_define_module_function (rb_Dislin, "wgicon", rb_wgicon, 5);
  rb_define_module_function (rb_Dislin, "wglab",  rb_wglab,  2);
  rb_define_module_function (rb_Dislin, "wglis",  rb_wglis,  3);
  rb_define_module_function (rb_Dislin, "wgltxt", rb_wgltxt, 4);
  rb_define_module_function (rb_Dislin, "wgok",   rb_wgok,   1);
  rb_define_module_function (rb_Dislin, "wgpbar", rb_wgpbar, 4);
  rb_define_module_function (rb_Dislin, "wgpbut", rb_wgpbut, 2);
  rb_define_module_function (rb_Dislin, "wgpicon", rb_wgpicon, 5);
  rb_define_module_function (rb_Dislin, "wgpop",  rb_wgpop,  2);
  rb_define_module_function (rb_Dislin, "wgpopb", rb_wgpopb, 4);
  rb_define_module_function (rb_Dislin, "wgquit", rb_wgquit, 1);
  rb_define_module_function (rb_Dislin, "wgscl",  rb_wgscl,  6);
  rb_define_module_function (rb_Dislin, "wgsep",  rb_wgsep,  1);
  rb_define_module_function (rb_Dislin, "wgstxt", rb_wgstxt, 3);
  rb_define_module_function (rb_Dislin, "wgtbl",  rb_wgtbl,  3);
  rb_define_module_function (rb_Dislin, "wgtxt",  rb_wgtxt,  2);
  rb_define_module_function (rb_Dislin, "widbar", rb_widbar, 1);
  rb_define_module_function (rb_Dislin, "wimage", rb_wimage, 1);
  rb_define_module_function (rb_Dislin, "winapp", rb_winapp, 1);
  rb_define_module_function (rb_Dislin, "wincbk", rb_wincbk, 2);
  rb_define_module_function (rb_Dislin, "windbr", rb_windbr, 5);
  rb_define_module_function (rb_Dislin, "window", rb_window, 4);
  rb_define_module_function (rb_Dislin, "winfnt", rb_winfnt, 1);
  rb_define_module_function (rb_Dislin, "winico", rb_winico, 1);
  rb_define_module_function (rb_Dislin, "winid",  rb_winid,  0);
  rb_define_module_function (rb_Dislin, "winjus", rb_winjus, 1);
  rb_define_module_function (rb_Dislin, "winkey", rb_winkey, 1);
  rb_define_module_function (rb_Dislin, "winmod", rb_winmod, 1);
  rb_define_module_function (rb_Dislin, "winopt", rb_winopt, 2);
  rb_define_module_function (rb_Dislin, "winsiz", rb_winsiz, 2);
  rb_define_module_function (rb_Dislin, "wintit", rb_wintit, 1);
  rb_define_module_function (rb_Dislin, "wintyp", rb_wintyp, 1);
  rb_define_module_function (rb_Dislin, "wmfmod", rb_wmfmod, 2);
  rb_define_module_function (rb_Dislin, "world",  rb_world,  0);
  rb_define_module_function (rb_Dislin, "wpixel", rb_wpixel, 3);
  rb_define_module_function (rb_Dislin, "wpixls", rb_wpixls, 5);
  rb_define_module_function (rb_Dislin, "wpxrow", rb_wpxrow, 4);
  rb_define_module_function (rb_Dislin, "writfl", rb_writfl, 3);
  rb_define_module_function (rb_Dislin, "wtiff",  rb_wtiff,  1);
  rb_define_module_function (rb_Dislin, "x11fnt", rb_x11fnt, 2);
  rb_define_module_function (rb_Dislin, "x11mod", rb_x11mod, 1);
  rb_define_module_function (rb_Dislin, "x2dpos", rb_x2dpos, 2);
  rb_define_module_function (rb_Dislin, "x3dabs", rb_x3dabs, 3);
  rb_define_module_function (rb_Dislin, "x3dpos", rb_x3dpos, 3);
  rb_define_module_function (rb_Dislin, "x3drel", rb_x3drel, 3);
  rb_define_module_function (rb_Dislin, "xaxgit", rb_xaxgit, 0);
  rb_define_module_function (rb_Dislin, "xaxis",  rb_xaxis,  9);
  rb_define_module_function (rb_Dislin, "xaxlg",  rb_xaxlg,  9);
  rb_define_module_function (rb_Dislin, "xaxmap", rb_xaxmap, 7);
  rb_define_module_function (rb_Dislin, "xcross", rb_xcross, 0);
  rb_define_module_function (rb_Dislin, "xdraw",  rb_xdraw,  2);
  rb_define_module_function (rb_Dislin, "xinvrs", rb_xinvrs, 1);
  rb_define_module_function (rb_Dislin, "xmove",  rb_xmove,  2);
  rb_define_module_function (rb_Dislin, "xposn",  rb_xposn,  1);
  rb_define_module_function (rb_Dislin, "y2dpos", rb_y2dpos, 2);
  rb_define_module_function (rb_Dislin, "y3dabs", rb_y3dabs, 3);
  rb_define_module_function (rb_Dislin, "y3dpos", rb_y3dpos, 3);
  rb_define_module_function (rb_Dislin, "y3drel", rb_y3drel, 3);
  rb_define_module_function (rb_Dislin, "yaxgit", rb_yaxgit, 0);
  rb_define_module_function (rb_Dislin, "yaxis",  rb_yaxis,  9);
  rb_define_module_function (rb_Dislin, "yaxlg",  rb_yaxlg,  9);
  rb_define_module_function (rb_Dislin, "yaxmap", rb_yaxmap, 7);
  rb_define_module_function (rb_Dislin, "ycross", rb_ycross, 0);
  rb_define_module_function (rb_Dislin, "yinvrs", rb_yinvrs, 1);
  rb_define_module_function (rb_Dislin, "yposn",  rb_yposn,  1);
  rb_define_module_function (rb_Dislin, "z3dpos", rb_z3dpos, 3);
  rb_define_module_function (rb_Dislin, "zaxis",  rb_zaxis, 10);
  rb_define_module_function (rb_Dislin, "zaxlg",  rb_zaxlg, 10);
  rb_define_module_function (rb_Dislin, "zbfers", rb_zbfers, 0);
  rb_define_module_function (rb_Dislin, "zbffin", rb_zbffin, 0);
  rb_define_module_function (rb_Dislin, "zbfini", rb_zbfini, 0);
  rb_define_module_function (rb_Dislin, "zbflin", rb_zbflin, 6);
  rb_define_module_function (rb_Dislin, "zbfmod", rb_zbfmod, 1);
  rb_define_module_function (rb_Dislin, "zbfres", rb_zbfres, 0);
  rb_define_module_function (rb_Dislin, "zbfscl", rb_zbfscl, 1);
  rb_define_module_function (rb_Dislin, "zbftri", rb_zbftri, 4);
  rb_define_module_function (rb_Dislin, "zscale", rb_zscale, 2);
}

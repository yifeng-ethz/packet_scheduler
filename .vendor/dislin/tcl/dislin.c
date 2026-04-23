#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tcl.h>
#include "dislin_d.h"

#define MAX_CB 200
static Tcl_Interp *tcl_interp, *pclwin, *pclpie, *pclprj; 

static int ncbray = 0;
static int icbray[MAX_CB];
static Tcl_Interp *pcbray[MAX_CB];
static char *tcbray[MAX_CB];
           
static char *clegbf = NULL;
static char *tclfunc = NULL, *tclwin = NULL, *tclpie = NULL, *tclprj = NULL;
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

static void tcl_warn (char *s)
{ fprintf (stderr, "%s", s);
}

static double *dbl_array (Tcl_Interp *interp, Tcl_Obj *list, int n)
{ int i, nr, iret;
  double *p = NULL;
  Tcl_Obj *element;

  if (Tcl_ListObjLength (interp, list, &nr) != TCL_OK) return NULL;

  if (nr < n) 
  { tcl_warn ("not enough elements in list!");
    return NULL;
  }

  p = (double *) calloc (n, sizeof (double));
  if (p == NULL)
    tcl_warn ("not enough memory!");
  else
  { for (i = 0; i < n; i++)
    { Tcl_ListObjIndex (interp, list, i, &element);
      iret = Tcl_GetDoubleFromObj (interp, element, &p[i]);
      if (iret != TCL_OK) return NULL;
    }
  }

  return p;
}

static double *dbl_matrix (Tcl_Interp *interp, Tcl_Obj *list, int i1, int i2 )
{ int i, nr, iret, n;
  double *p = NULL;
  Tcl_Obj *element;

  n = i1 * i2;
  if (Tcl_ListObjLength (interp, list, &nr) != TCL_OK) return NULL;

  if (nr < n) 
  { tcl_warn ("not enough elements in list!");
    return NULL;
  }

  p = (double *) calloc (n, sizeof (double));
  if (p == NULL)
    tcl_warn ("not enough memory!");
  else
  { for (i = 0; i < n; i++)
    { Tcl_ListObjIndex (interp, list, i, &element);
      iret = Tcl_GetDoubleFromObj (interp, element, &p[i]);
      if (iret != TCL_OK) return NULL;
    }
  }

  return p;
}

static int *int_array (Tcl_Interp *interp, Tcl_Obj *list, int n)
{ int i, nr, iret;
  int *p = NULL;
  Tcl_Obj *element;

  if (Tcl_ListObjLength (interp, list, &nr) != TCL_OK) return NULL;

  if (nr < n) 
  { tcl_warn ("not enough elements in list!");
    return NULL;
  }

  p = (int *) calloc (n, sizeof (int));
  if (p == NULL)
    tcl_warn ("not enough memory!");
  else
  { for (i = 0; i < n; i++)
    { Tcl_ListObjIndex (interp, list, i, &element);
      iret = Tcl_GetIntFromObj (interp, element, &p[i]);
      if (iret != TCL_OK) return NULL;
    }
  }

  return p;
}

static long *long_array (Tcl_Interp *interp, Tcl_Obj *list, int n)
{ int i, nr, iret, iv;
  long *p = NULL;
  Tcl_Obj *element;

  if (Tcl_ListObjLength (interp, list, &nr) != TCL_OK) return NULL;

  if (nr < n) 
  { tcl_warn ("not enough elements in list!");
    return NULL;
  }

  p = (long *) calloc (n, sizeof (long));
  if (p == NULL)
    tcl_warn ("not enough memory!");
  else
  { for (i = 0; i < n; i++)
    { Tcl_ListObjIndex (interp, list, i, &element);
      iret = Tcl_GetIntFromObj (interp, element, &iv);
      if (iret != TCL_OK) return NULL;
      p[i] = iv; 
    }
  }

  return p;
}

static  Tcl_Obj *copy_dblarray (Tcl_Interp *interp, double *p, int n)
{ int i;
  Tcl_Obj *list;

  list = Tcl_NewListObj (0, NULL);
  for (i = 0; i < n; i++)
      Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (p[i]));
  return list;
}

static  Tcl_Obj *copy_intarray (Tcl_Interp *interp, int *p, int n)
{ int i;
  Tcl_Obj *list;

  list = Tcl_NewListObj (0, NULL);
  for (i = 0; i < n; i++)
      Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (p[i]));
  return list;
}

static int abs3pt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5;
  Tcl_Obj *list;
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;

  abs3pt (x1, x2, x3, &x4, &x5);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x5));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int addlab_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str flt int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i1) != TCL_OK) return TCL_ERROR;
  addlab (Tcl_GetString (objv[1]), x1, i1, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int angle_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  angle (i1);
  return TCL_OK;
}

static int arcell_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double x1, x2, x3;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x3) != TCL_OK) return TCL_ERROR;
  arcell (i1, i2, i3, i4, x1, x2, x3);
  return TCL_OK;
}

static int areaf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = int_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    areaf (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int autres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  autres (i1, i2);
  return TCL_OK;
}

static int ax2grf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  ax2grf ();
  return TCL_OK;
}

static int ax3len_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  ax3len (i1, i2, i3);
  return TCL_OK;
}

static int axclrs_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  axclrs (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int axends_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  axends (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int axgit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  axgit ();
  return TCL_OK;
}

static int axis3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  axis3d (x1, x2, x3);
  return TCL_OK;
}

static int axsbgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  axsbgd (i1);
  return TCL_OK;
}

static int axsers_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  axsers ();
  return TCL_OK;
}

static int axslen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  axslen (i1, i2);
  return TCL_OK;
}

static int axsorg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  axsorg (i1, i2);
  return TCL_OK;
}

static int axspos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  axspos (i1, i2);
  return TCL_OK;
}

static int axsscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  axsscl (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int axstyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  axstyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int barbor_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  barbor (i1);
  return TCL_OK;
}

static int barclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  barclr (i1, i2, i3);
  return TCL_OK;
}

static int bargrp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  bargrp (i1, x1);
  return TCL_OK;
}

static int barmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  barmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int baropt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  baropt (x1, x2);
  return TCL_OK;
}

static int barpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  barpos (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int bars_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    bars (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int bars3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0, *p7;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[8], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = dbl_array (interp, objv[5], n);
  p6 = dbl_array (interp, objv[6], n);
  p7 = int_array (interp, objv[7], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL &&
      p5 != NULL && p6 != NULL && p7!= NULL) 
    bars3d (p1, p2, p3, p4, p5, p6, p7, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int bartyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  bartyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int barwth_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  barwth (x1);
  return TCL_OK;
}

static int basalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  basalf (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int basdat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  basdat (i1, i2, i3);
  return TCL_OK;
}

static int bezier_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, nn, ierr = 0;
  double *p1, *p2, *p3, *p4;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &nn) != TCL_OK) return TCL_ERROR;
  p3 = (double *) calloc (nn, sizeof (double));
  p4 = (double *) calloc (nn, sizeof (double));
  if (p3 == NULL || p4 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p3);
    free (p4);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { bezier (p1, p2, n, p3, p4, nn);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p3, nn);
    list2 = copy_dblarray (interp, p4, nn);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;

  return TCL_OK;
}

static int bitsi4_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5, iret;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  iret = bitsi4 (i1, i2, i3, i4, i5);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int bmpfnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  bmpfnt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int bmpmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  bmpmod (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int box2d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  box2d ();
  return TCL_OK;
}

static int box3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  box3d ();
  return TCL_OK;
}

static int bufmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  bufmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int center_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  center ();
  return TCL_OK;
}

static int cgmbgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  cgmbgd (x1, x2, x3);
  return TCL_OK;
}

static int cgmpic_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  cgmpic (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int cgmver_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  cgmver (i1);
  return TCL_OK;
}

static int chaang_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  chaang (x1);
  return TCL_OK;
}

static int chacod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  chacod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int chaspc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  chaspc (x1);
  return TCL_OK;
}

static int chawth_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  chawth (x1);
  return TCL_OK;
}

static int chnatt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  chnatt ();
  return TCL_OK;
}


static int chncrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  chncrv (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int chndot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  chndot ();
  return TCL_OK;
}

static int chndsh_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  chndsh ();
  return TCL_OK;
}

static int chnbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  chnbar (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int chnpie_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  chnpie (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int circ3p_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7, x8, x9;
  Tcl_Obj *list;
 
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  circ3p (x1, x2, x3, x4, x5, x6, &x7, &x8, &x9);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x7));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x8));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x9));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int circle_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  circle (i1, i2, i3);
  return TCL_OK;
}

static int circsp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  circsp (i1);
  return TCL_OK;
}

static int clip3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  clip3d (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int closfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = closfl (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int clpbor_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  clpbor (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int clpmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  clpmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int clpwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  clpwin (i1, i2, i3, i4);
  return TCL_OK;
}

static int clrcyc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  clrcyc (i1, i2);
  return TCL_OK;
}

static int clrmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  clrmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int clswin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  clswin (i1);
  return TCL_OK;
}

static int color_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "string");
    return TCL_ERROR;
  }
  
  color (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int colran_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  colran (i1, i2);
  return TCL_OK;
}

static int colray_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, i, *p2;
  double *p1;
  Tcl_Obj *list; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  p2 = (int *) calloc (n, sizeof (int));
  if (p2 == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { colray (p1, p2, n);
    list = Tcl_NewListObj (0, NULL);
    for (i = 0; i < n; i++)
      Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (p2[i]));

    Tcl_SetObjResult (interp, list);
    free (p1);
    free (p2);
  }
  else
  { free (p2);
    return TCL_ERROR;
  }

  return TCL_OK;
}

static int complx_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  complx ();
  return TCL_OK;
}

static int conclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  int *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  if (p1 != NULL) 
  { conclr (p1, n);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int concrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, x1;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x1) != TCL_OK) return TCL_ERROR;
  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    concrv (p1, p2, n, x1);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int cone3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  int i1, i2;
  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i2) != TCL_OK) return TCL_ERROR;
  cone3d (x1, x2, x3, x4, x5, x6, i1, i2);
  return TCL_OK;
}


static int confll_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, ierr = 0, *p4, *p5, *p6;
  double *p1, *p2, *p3, *p7, x1;

  if (objc != 11)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list int list list list int list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &i3) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[2], i1);
  p3 = dbl_array (interp, objv[3], i1);
  p4 = int_array (interp, objv[5], i2);
  p5 = int_array (interp, objv[6], i2);
  p6 = int_array (interp, objv[7], i2);
  p7 = dbl_array (interp, objv[9], i3);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL && p7 != NULL) 
    confll (p1, p2, p3, i1, p4, p5, p6, i2, p7, i3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int congap_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  congap (x1);
  return TCL_OK;
}

static int conlab_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  conlab (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int conmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  double x1;
  double *p1;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x1) != TCL_OK) return TCL_ERROR;
  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { conmat (p1, i1, i2, x1);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int conmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  conmod (x1, x2);
  return TCL_OK;
}

static int conn3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  conn3d (x1, x2, x3);
  return TCL_OK;
}

static int connpt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  connpt (x1, x2);
  return TCL_OK;
}

static int conpts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nlins, maxpts, maxray, np, i, ierr = 0, *p6;
  double *p1, *p2, *p3, *p4, *p5, x1;
  Tcl_Obj *list, *list1, *list2, *list3;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list int list int list flt int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &maxpts) != TCL_OK) 
     return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &maxray) != TCL_OK) 
     return TCL_ERROR;

  p4 = (double *) calloc (maxpts, sizeof (double));
  p5 = (double *) calloc (maxpts, sizeof (double));
  p6 = (int *) calloc (maxray, sizeof (int));
  if (p4 == NULL || p5 == NULL || p6 == NULL)
  { tcl_warn ("not enough memory!");
    free (p4);
    free (p5);
    free (p6);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], nx);
  p2 = dbl_array (interp, objv[3], ny);
  p3 = dbl_matrix (interp, objv[5], nx, ny);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  { conpts (p1, nx, p2, ny, p3, x1, p4, p5, maxpts, p6, maxray, &nlins);
    np = 0;
    for (i = 0; i < nlins; i++)
      np += p6[i];

    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p4, np);
    list2 = copy_dblarray (interp, p5, np);
    list3 = copy_intarray (interp, p6, nlins);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (nlins));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int conshd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i3) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  p4 = dbl_array (interp, objv[6], i3);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd (p1, i1, p2, i2, p3, p4, i3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int conshd2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int int list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i3) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], i1, i2);
  p2 = dbl_matrix (interp, objv[2], i1, i2);
  p3 = dbl_matrix (interp, objv[3], i1, i2);
  p4 = dbl_array (interp, objv[6], i3);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd2 (p1, p2, p3, i1, i2, p4, i3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int conshd3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i3) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  p4 = dbl_array (interp, objv[6], i3);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    conshd3d (p1, i1, p2, i2, p3, p4, i3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int contri_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0, *p4, *p5, *p6;
  double *p1, *p2, *p3, x1;

  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list int list list list int flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[9], &x1) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[2], i1);
  p3 = dbl_array (interp, objv[3], i1);
  p4 = int_array (interp, objv[5], i2);
  p5 = int_array (interp, objv[6], i2);
  p6 = int_array (interp, objv[7], i2);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
    contri (p1, p2, p3, i1, p4, p5, p6, i2, x1);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int contur_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0;
  double *p1, *p2, *p3, x1;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x1) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    contur (p1, i1, p2, i2, p3, x1);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int contur2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0;
  double *p1, *p2, *p3, x1;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int int flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x1) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], i1, i2);
  p2 = dbl_matrix (interp, objv[2], i1, i2);
  p3 = dbl_matrix (interp, objv[3], i1, i2);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    contur2 (p1, p2, p3, i1, i2, x1);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int cross_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  cross ();
  return TCL_OK;
}

static int crvmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double *p1;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { crvmat (p1, i1, i2, i3, i4);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int crvqdr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    crvqdr (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int crvt3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0, *p5;
  double *p1, *p2, *p3, *p4;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[6], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = int_array (interp, objv[5], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL) 
    crvt3d (p1, p2, p3, p4, p5, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int crvtri_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0, *p4, *p5, *p6;
  double *p1, *p2, *p3;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list int list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[2], i1);
  p3 = dbl_array (interp, objv[3], i1);
  p4 = int_array (interp, objv[5], i2);
  p5 = int_array (interp, objv[6], i2);
  p6 = int_array (interp, objv[7], i2);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p4 != NULL && p4 != NULL) 
    crvtri (p1, p2, p3, i1, p4, p5, p6, i2);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int csrkey_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = csrkey ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int csrlin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  csrlin (&i1, &i2, &i3, &i4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int csrmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  csrmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int csrpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i3 = csrpos (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int csrpt1_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  csrpt1 (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int csrpts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nmax, n, iret;
  int *p1, *p2;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &nmax) != TCL_OK) return TCL_ERROR;
  p1 = (int *) calloc (nmax, sizeof (int));
  p2 = (int *) calloc (nmax, sizeof (int));
  if (p1 == NULL || p2 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p1);
    free (p2);
    return TCL_ERROR;
  }

  csrpts (p1, p2, nmax, &n, &iret);
  list = Tcl_NewListObj (0, NULL);
  list1 = copy_intarray (interp, p1, n);
  list2 = copy_intarray (interp, p2, n);
  Tcl_ListObjAppendElement (interp, list, list1);
  Tcl_ListObjAppendElement (interp, list, list2);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (n));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (iret));
  Tcl_SetObjResult (interp, list);
  free (p1);
  free (p2);
  return TCL_OK;
}

static int csrpol_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nmax, n, iret;
  int *p1, *p2;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &nmax) != TCL_OK) return TCL_ERROR;
  p1 = (int *) calloc (nmax, sizeof (int));
  p2 = (int *) calloc (nmax, sizeof (int));
  if (p1 == NULL || p2 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p1);
    free (p2);
    return TCL_ERROR;
  }

  csrpol (p1, p2, nmax, &n, &iret);
  list = Tcl_NewListObj (0, NULL);
  list1 = copy_intarray (interp, p1, n);
  list2 = copy_intarray (interp, p2, n);
  Tcl_ListObjAppendElement (interp, list, list1);
  Tcl_ListObjAppendElement (interp, list, list2);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (n));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (iret));
  Tcl_SetObjResult (interp, list);
  free (p1);
  free (p2);
  return TCL_OK;
}

static int csrmov_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nmax, n, iret;
  int *p1, *p2;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &nmax) != TCL_OK) return TCL_ERROR;
  p1 = (int *) calloc (nmax, sizeof (int));
  p2 = (int *) calloc (nmax, sizeof (int));
  if (p1 == NULL || p2 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p1);
    free (p2);
    return TCL_ERROR;
  }

  csrmov (p1, p2, nmax, &n, &iret);
  list = Tcl_NewListObj (0, NULL);
  list1 = copy_intarray (interp, p1, n);
  list2 = copy_intarray (interp, p2, n);
  Tcl_ListObjAppendElement (interp, list, list1);
  Tcl_ListObjAppendElement (interp, list, list2);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (n));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (iret));
  Tcl_SetObjResult (interp, list);
  free (p1);
  free (p2);
  return TCL_OK;
}

static int csrrec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  csrrec (&i1, &i2, &i3, &i4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int csrtyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  csrtyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int csruni_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  csruni (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int curv3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    curv3d (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curv4d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    curv4d (p1, p2, p3, p4, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curve_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    curve (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curve3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    curve3 (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curvmp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    curvmp (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curvx3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, y;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list flt list int");
    return TCL_ERROR;
  }

  if (Tcl_GetDoubleFromObj (interp, objv[2], &y) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL) 
    curvx3 (p1, y, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int curvy3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, x;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetDoubleFromObj (interp, objv[1], &x) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[2], n);
  p2 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL) 
    curvy3 (x, p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int cyli3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5;
  int i1, i2;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  cyli3d (x1, x2, x3, x4, x5, i1, i2);
  return TCL_OK;
}

static int dash_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dash ();
  return TCL_OK;
}

static int dashl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dashl ();
  return TCL_OK;
}

static int dashm_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dashm ();
  return TCL_OK;
}

static int dbffin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dbffin ();
  return TCL_OK;
}

static int dbfini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = dbfini ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int dbfmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  dbfmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int delglb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  delglb ();
  return TCL_OK;
}

static int digits_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  digits (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int disalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  disalf ();
  return TCL_OK;
}

static int disenv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  disenv (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int disfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  disfin ();
  return TCL_OK;
}

static int disini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  disini ();
  nspline = 200;
  imgopt = 0;
  return TCL_OK;
}

static int disk3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5;
  int i1, i2;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  disk3d (x1, x2, x3, x4, x5, i1, i2);
  return TCL_OK;
}

static int doevnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  doevnt ();
  return TCL_OK;
}

static int dot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dot ();
  return TCL_OK;
}

static int dotl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  dotl ();
  return TCL_OK;
}

static int duplx_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  duplx ();
  return TCL_OK;
}

static int dwgbut_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  iret = dwgbut (Tcl_GetString (objv[1]), i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int dwgerr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = dwgerr ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int dwgfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str str");
    return TCL_ERROR;
  }
  p = dwgfil (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]),
              Tcl_GetString (objv[3]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int dwglis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[3], &i1) != TCL_OK) return TCL_ERROR;
  iret = dwglis (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]), i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int dwgmsg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  dwgmsg (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int dwgtxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  p = dwgtxt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int ellips_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  ellips (i1, i2, i3, i4);
  return TCL_OK;
}

static int endgrf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  endgrf ();
  return TCL_OK;
}

static int erase_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  erase ();
  return TCL_OK;
}

static int errbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    errbar (p1, p2, p3, p4, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int errdev_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  errdev (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int errfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  errfil (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int errmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  errmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int eushft_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  eushft (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int expimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  expimg (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int expzlb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  expzlb (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int fbars_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[6], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = dbl_array (interp, objv[5], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL) 
    fbars (p1, p2, p3, p4, p5, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int fcha_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char s[41];
  int i1;
  double x1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int");
    return TCL_ERROR;
  }

  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  fcha (x1, i1, s);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (s, -1));
  return TCL_OK;
}

static int field_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ivec, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &ivec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    field (p1, p2, p3, p4, n, ivec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int field3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ivec, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list list list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[7], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &ivec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = dbl_array (interp, objv[5], n);
  p6 = dbl_array (interp, objv[6], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
    field3d (p1, p2, p3, p4, p5, p6, n, ivec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int filbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  filbox (i1, i2, i3, i4);
  return TCL_OK;
}

static int filclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  filclr (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int filmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  filmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int filopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  filopt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int filsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  i3 = filsiz (Tcl_GetString (objv[1]), &i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int filtyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  i1 = filtyp (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i1));
  return TCL_OK;
}

static int filwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  filwin (i1, i2, i3, i4);
  return TCL_OK;
}

static int fitscls_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  fitscls ();
  return TCL_OK;
}

static int fitsflt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  x = fitsflt (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (x));
  return TCL_OK;
}

static int fitshdu_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = fitshdu (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int fitsimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int n;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }

  n = fitsimg (NULL, 0);
  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  n = fitsimg ((unsigned char *) p, n);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, n));
  return TCL_OK;
}

static int fitsopn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  i1 = fitsopn (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i1));
  return TCL_OK;
}

static int fitsstr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char p[257];
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  fitsstr (Tcl_GetString (objv[1]), p, 257);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int fitstyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  i1 = fitstyp (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i1));
  return TCL_OK;
}

static int fitsval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  i1 = fitsval (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i1));
  return TCL_OK;
}

static int fixspc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  fixspc (x1);
  return TCL_OK;
}

static int flab3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  flab3d ();
  return TCL_OK;
}

static int flen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  double x1; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  iret = flen (x1, i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int frame_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  frame (i1);
  return TCL_OK;
}

static int frmclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  frmclr (i1);
  return TCL_OK;
}

static int frmbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  frmbar (i1);
  return TCL_OK;
}

static int frmess_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  frmess (i1);
  return TCL_OK;
}

static int gapcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  gapcrv (x1);
  return TCL_OK;
}

static int gapsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  gapsiz (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int gaxpar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, v1, v2;
  int ndig;
  Tcl_Obj *list;
 
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt str str");
    return TCL_ERROR;
  }

  if (Tcl_GetDoubleFromObj (interp, objv[1], &v1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &v2) != TCL_OK) return TCL_ERROR;
  gaxpar (v1, v2, Tcl_GetString (objv[3]), Tcl_GetString (objv[4]), 
          &x1, &x2, &x3, &x4, &ndig);;
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (ndig));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  p = getalf ();
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getang_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getang ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getbpp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getbpp ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getclp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getclp (&i1, &i2, &i3, &i4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getclr ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getdig_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getdig (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getdsp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  p = getdsp ();
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  p = getfil ();
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getgrf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  getgrf (&x1, &x2, &x3, &x4, Tcl_GetString (objv[1]));
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gethgt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = gethgt ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int gethnm_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = gethnm ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getico_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  Tcl_Obj *list;
 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;

  getico (x1, x2, &x3, &x4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getind_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double x1, x2, x3;
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  getind (i1, &x1, &x2, &x3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getlab_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char s1[9], s2[9], s3[9];
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getlab (s1, s2, s3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewStringObj (s1, -1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewStringObj (s2, -1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewStringObj (s3, -1));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getlen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getlen (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getlev_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getlev ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getlin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getlin ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getlit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  double x1, x2, x3, x4, x5, x6;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  i = getlit (x1, x2, x3, x4, x5, x6);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, nx, ny, *p5, ierr = 0;
  double *p1, *p2, *p3, *p4, *p6, x1;
  Tcl_Obj *list;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list int list int int flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[8], &x1) != TCL_OK) return TCL_ERROR;

  p4 = (double *) calloc (nx * ny, sizeof (double));
  if (p4 == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  p5 = (int *) calloc (nx * ny, sizeof (int));
  if (p5 == NULL)
  { tcl_warn ("not enough memory!");
    free (p4);
    return TCL_ERROR;
  }

  p6 = (double *) calloc (nx * ny, sizeof (double));
  if (p6 == NULL)
  { tcl_warn ("not enough memory!");
    free (p4);
    free (p5);
    return TCL_ERROR;
  }
  
  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);

  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  { getmat (p1, p2, p3, n, p4, nx, ny, x1, p5, p6);
    list = copy_dblarray (interp, p4, nx * ny);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int getmfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  p = getmfl ();
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getmix_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  p = getmix (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getor_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getor (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getpag_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getpag (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getpat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = (int) getpat ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getplv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getplv ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getpos (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getran_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getran (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getrco_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  Tcl_Obj *list;
 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;

  getrco (x1, x2, &x3, &x4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getres (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getrgb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getrgb (&x1, &x2, &x3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getscl (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getscm_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getscm (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getscr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getscr (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getshf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  p = getshf (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getsp1_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getsp1 (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getsp2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getsp2 (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getsym_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getsym (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gettcl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  gettcl (&i1, &i2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gettic_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  gettic (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gettyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = gettyp ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getuni_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ FILE *fp;
  int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  fp = getuni ();
  if (fp == NULL)
    i = 0;
  else
    i = 6;  
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getver_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double xret; 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  xret = getver ();
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int getvk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getvk (&i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getvlt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  p = getvlt ();
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int getwid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = getwid ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int getwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  Tcl_Obj *list;
 
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  getwin (&i1, &i2, &i3, &i4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int getxid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = getxid (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gifmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  gifmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int gmxalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char s1[9], s2[9];
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  gmxalf (Tcl_GetString (objv[1]), s1, s2);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewStringObj (s1, -1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewStringObj (s2, -1));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gothic_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  gothic ();
  return TCL_OK;
}

static int grace_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  grace (i1);
  return TCL_OK;
}

static int graf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[8];
  int i;
 
  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 8; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  graf (x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7]);
  return TCL_OK;
}

static int graf3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[12];
  int i;
 
  if (objc != 13)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 12; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  graf3 (x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7],
         x[8], x[9], x[10], x[11]);
  return TCL_OK;
}

static int graf3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[12];
  int i;
 
  if (objc != 13)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 12; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  graf3d (x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7],
         x[8], x[9], x[10], x[11]);
  return TCL_OK;
}

static int grafmp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[8];
  int i;
 
  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 8; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  grafmp (x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7]);
  return TCL_OK;
}

static int grafp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[5];
  int i;
 
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 5; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  grafp (x[0], x[1], x[2], x[3], x[4]);
  return TCL_OK;
}

static int grafr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n1, n2, ierr = 0;
  double *p1, *p2;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &n2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n1);
  p2 = dbl_array (interp, objv[3], n2);
  if (p1 != NULL && p2 != NULL) 
    grafr (p1, n1, p2, n2);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int grdpol_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  grdpol (i1, i2);
  return TCL_OK;
}

static int grffin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  grffin ();
  return TCL_OK;
}

static int grfimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  grfimg (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int grfini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7, x8, x9;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f f");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x7) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[8], &x8) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[9], &x9) != TCL_OK) return TCL_ERROR;
  grfini (x1, x2, x3, x4, x5, x6, x7, x8, x9);
  return TCL_OK;
}

static int grid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  grid (i1, i2);
  return TCL_OK;
}

static int grid3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  grid3d (i1, i2, Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int gridim_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  gridim (x1, x2, x3, i1);
  return TCL_OK;
}

static int gridmp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  gridmp (i1, i2);
  return TCL_OK;
}

static int gridre_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  gridre (x1, x2, x3, i1);
  return TCL_OK;
}

static int gwgatt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwgatt (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwgbox (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgbut_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwgbut (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char p[257];
  int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  gwgfil (i1, p);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int gwgflt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double xret; 
  int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  xret = gwgflt (i1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int gwggui_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  iret = gwggui ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgint_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwgint (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwglis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwglis (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double xret; 
  int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  xret = gwgscl (i1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int gwgsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  gwgsiz (i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int gwgtbf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double xret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  xret = gwgtbf (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int gwgtbi_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  iret = gwgtbi (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int gwgtbl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double *p;
  Tcl_Obj *list;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  p = (double *) calloc (i2, sizeof (double));
  if (p == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  gwgtbl (i1, p, i2, i3, Tcl_GetString (objv[4]));
  list = copy_dblarray (interp, p, i2);
  Tcl_SetObjResult (interp, list);
  free (p);
  return TCL_OK;
}

static int gwgtbs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char p[257];
  int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  gwgtbs (i1, i2, i3, p);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int gwgtxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char p[257];
  int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  gwgtxt (i1, p);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  return TCL_OK;
}

static int gwgxid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = gwgxid (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int height_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  height (i1);
  return TCL_OK;
}

static int helve_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  helve ();
  return TCL_OK;
}

static int helves_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  helves ();
  return TCL_OK;
}

static int helvet_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  helvet ();
  return TCL_OK;
}

static int hidwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int string");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  hidwin (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int histog_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, np, ierr = 0;
  double *p1, *p2, *p3;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p2 = (double *) calloc (n, sizeof (double));
  p3 = (double *) calloc (n, sizeof (double));
  if (p2 == NULL || p3 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p2);
    free (p3);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { histog (p1, n, p2, p3, &np);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p2, np);
    list2 = copy_dblarray (interp, p3, np);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (np));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;

  return TCL_OK;
}

static int hname_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  hname (i1);
  return TCL_OK;
}

static int hpgmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  hpgmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int hsvrgb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  Tcl_Obj *list;
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  hsvrgb (x1, x2, x3, &x4, &x5, &x6);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x5));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x6));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int hsym3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  hsym3d (x1);
  return TCL_OK;
}

static int hsymbl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  hsymbl (i1);
  return TCL_OK;
}

static int htitle_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  htitle (i1);
  return TCL_OK;
}

static int hwfont_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  hwfont ();
  return TCL_OK;
}

static int hwmode_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  hwmode (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int hworig_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  hworig (i1, i2);
  return TCL_OK;
}

static int hwpage_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  hwpage (i1, i2);
  return TCL_OK;
}

static int hwscal_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  hwscal (x1);
  return TCL_OK;
}

static int imgbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  imgbox (i1, i2, i3, i4);
  return TCL_OK;
}

static int imgclp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  imgclp (i1, i2, i3, i4);
  return TCL_OK;
}

static int imgfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  imgfin ();
  return TCL_OK;
}

static int imgfmt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  imgfmt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int imgini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  imgini ();
  return TCL_OK;
}

static int imgmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *s;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  s = Tcl_GetString (objv[1]);
  if ((s[0] == 'R' || s[0] == 'r') &&
      (s[1] == 'G' || s[1] == 'g') &&
      (s[2] == 'B' || s[2] == 'b'))
    imgopt = 1;
  else
    imgopt = 0;
  imgmod (s);
  return TCL_OK;
}

static int imgsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  imgsiz (i1, i2);
  return TCL_OK;
}

static int imgtpr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  imgtpr (i1);
  return TCL_OK;
}

static int inccrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  inccrv (i1);
  return TCL_OK;
}

static int incdat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  iret = incdat (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int incfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  incfil (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int incmrk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  incmrk (i1);
  return TCL_OK;
}

static int indrgb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  iret = indrgb (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int intax_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  intax ();
  return TCL_OK;
}

static int intcha_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char s[41];
  int i1;

  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  intcha (i1, s);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (s, -1));
  return TCL_OK;
}

static int intlen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = intlen (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int intrgb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  double x1, x2, x3; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  iret = intrgb (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int intutf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, *p;
  char *s;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  p = int_array (interp, objv[1], n);
  s = (char *) malloc (n * 4 + 1);
  if (s == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  intutf (p, n, s, n * 4);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (s, -1));
  return TCL_OK;
}

static int isopts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nz, ntri, nmax, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6, *p7, x1;
  Tcl_Obj *list, *list1, *list2, *list3;

  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list int list int list int list flt int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nz) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &nmax) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[9], &x1) != TCL_OK) return TCL_ERROR;

  p5 = (double *) calloc (nmax, sizeof (double));
  p6 = (double *) calloc (nmax, sizeof (double));
  p7 = (double *) calloc (nmax, sizeof (double));
  if (p5 == NULL || p6 == NULL || p7 == NULL)
  { tcl_warn ("not enough memory!");
    free (p5);
    free (p6);
    free (p7);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], nx);
  p2 = dbl_array (interp, objv[3], ny);
  p3 = dbl_array (interp, objv[5], nz);
  p4 = dbl_array (interp, objv[7], nx *ny * nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  { isopts (p1, nx, p2, ny, p3, nz, p4, x1, p5, p6, p7, nmax, &ntri);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p5, ntri);
    list2 = copy_dblarray (interp, p6, ntri);
    list3 = copy_dblarray (interp, p7, ntri);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (ntri));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}


void  isopts (const double *xray, int nx, const double *yray, int ny, 
              const double *zray, int nz, const double *wmat, double wlev,
              double *xtri, double *ytri, double *ztri, int nmax, int *ntri);

static int itmcat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int n1, n2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }

  n1 = trmlen (Tcl_GetString (objv[1]));
  n2 = trmlen (Tcl_GetString (objv[2]));
  p = (char *) malloc (n1 + n2 + 2);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (p, Tcl_GetString (objv[1]));
  itmcat (p, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int itmncat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int n1, n2, n, nmx;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int str");
    return TCL_ERROR;
  }

  n1 = trmlen (Tcl_GetString (objv[1]));
  if (Tcl_GetIntFromObj (interp, objv[2], &nmx) != TCL_OK) return TCL_ERROR;
  n2 = trmlen (Tcl_GetString (objv[3]));
  n = n1 + n2 + 2;
  if (n > nmx) n = nmx;

  p = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (p, Tcl_GetString (objv[1]));
  itmncat (p, nmx, Tcl_GetString (objv[3]));
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int itmcnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = itmcnt (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int itmstr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int i1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  p = itmstr (Tcl_GetString (objv[1]), i1);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int jusbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  jusbar (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int labclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  labclr (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labdig_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  labdig (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labdis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  labdis (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labels_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  labels (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  labjus (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labl3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  labl3d (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int labmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str str");
    return TCL_ERROR;
  }
  labmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]),
          Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int labpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  labpos (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int labtyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  labtyp (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int legbgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  legbgd (i1);
  return TCL_OK;
}

static int legclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  legclr ();
  return TCL_OK;
}

static int legend_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  legend (clegbf, n);
  return TCL_OK;
}

static int legini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nlin, nmaxln;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &nlin) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &nmaxln) != TCL_OK) return TCL_ERROR;

  if (clegbf != NULL) free (clegbf);
  clegbf = (char *) malloc (nlin * nmaxln + 1);
  if (clegbf == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }
  legini (clegbf, nlin, nmaxln);
  return TCL_OK;
}

static int leglin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  leglin (clegbf, Tcl_GetString (objv[2]), n);
  return TCL_OK;
}

static int legopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  legopt (x1, x2, x3);
  return TCL_OK;
}

static int legpat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5, i6;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i6) != TCL_OK) return TCL_ERROR;
  legpat (i1, i2, i3, i4, (long) i5, i6);
  return TCL_OK;
}

static int legpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  legpos (i1, i2);
  return TCL_OK;
}

static int legsel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  int *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  if (n > 0) p1 = int_array (interp, objv[1], n);
  if (p1 != NULL || n < 1) 
  { legsel (p1, n);
    if (n > 0) free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int legtit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  legtit (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int legtyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  legtyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int legval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  legval (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int lfttit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  lfttit ();
  return TCL_OK;
}

static int licmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  licmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int licpts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, n, ierr = 0, *p3, *p4;
  double *p1, *p2, *p5;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int list");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;

  p4 = (int *) calloc ( nx * ny, sizeof (int));
  p5 = (double *) calloc ( nx * ny, sizeof (double));
  if (p4 == NULL || p5 == NULL)
  { tcl_warn ("not enough memory!");
    free (p4);
    free (p5); 
    return TCL_ERROR;
  }

  p1 = dbl_matrix (interp, objv[1], nx, ny);
  p2 = dbl_matrix (interp, objv[2], nx, ny);
  p3 = int_array (interp, objv[5], nx * ny);

  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  { licpts (p1, p2, nx, ny, p3, p4, p5);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p5, nx * ny);
    list2 = copy_intarray (interp, p4, nx * ny);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_SetObjResult (interp, list);
  }
  else 
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);

  if (ierr == 1)
    return TCL_ERROR;
  return TCL_OK;
}

static int light_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  light (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int linclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  int *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  if (p1 != NULL) 
  { linclr (p1, n);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int lincyc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  lincyc (i1, i2);
  return TCL_OK;
}

static int line_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  line (i1, i2, i3, i4);
  return TCL_OK;
}


static int linfit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, a = 0.0, b = 0.0, r = 0.0;
  Tcl_Obj *list;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    linfit (p1, p2, n, &a, &b, &r, Tcl_GetString (objv[4]));
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
  { list = Tcl_NewListObj (0, NULL);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (a));
    Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (b));
    Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (r));
    Tcl_SetObjResult (interp, list);
    return TCL_OK;
  }
}

static int linmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  linmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int linesp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  linesp (x1);
  return TCL_OK;
}

static int lintyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  lintyp (i1);
  return TCL_OK;
}

static int linwid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  linwid (i1);
  return TCL_OK;
}

static int litmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  litmod (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int litop3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  litop3 (i1, x1, x2, x3, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int litopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  litopt (i1, x1, Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int litpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  litpos (i1, x1, x2, x3, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int lncap_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  lncap (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int lnjoin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  lnjoin (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int lnmlt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  lnmlt (x1);
  return TCL_OK;
}

static int logtic_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  logtic (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mapbas_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  mapbas (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mapfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  mapfil (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int mapimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "str flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x6) != TCL_OK) return TCL_ERROR;
  mapimg (Tcl_GetString (objv[1]), x1, x2, x3, x4, x5, x6);
  return TCL_OK;
}

static int maplab_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  maplab (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int maplev_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  maplev (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mapmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  mapmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mappol_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  mappol (x1, x2);
  return TCL_OK;
}

static int mapopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  mapopt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int mapref_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  mapref (x1, x2);
  return TCL_OK;
}

static int mapsph_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  mapsph (x1);
  return TCL_OK;
}

static int marker_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  marker (i1);
  return TCL_OK;
}

static int matop3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  matop3 (x1, x2, x3, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int matopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  matopt (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int mdfmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  double x1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x1) != TCL_OK) return TCL_ERROR;
  mdfmat (i1, i2, x1);
  return TCL_OK;
}

static int messag_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "s i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  messag (Tcl_GetString (objv[1]), i1, i2);
  return TCL_OK;
}

static int metafl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  metafl (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mixalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  mixalf ();
  return TCL_OK;
}

static int mixleg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  mixleg ();
  return TCL_OK;
}

static int mpaepl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  mpaepl (i1);
  return TCL_OK;
}

static int mplang_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  mplang (x1);
  return TCL_OK;
}

static int mplclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  mplclr (i1, i2);
  return TCL_OK;
}

static int mplpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  mplpos (i1, i2);
  return TCL_OK;
}

static int mplsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  mplsiz (i1);
  return TCL_OK;
}

static int mpslogo_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  mpslogo (i1, i2, i3, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int mrkclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  mrkclr (i1);
  return TCL_OK;
}

static int msgbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  msgbox (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int mshclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  mshclr (i1);
  return TCL_OK;
}

static int mshcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  mshcrv (i1);
  return TCL_OK;
}

static int mylab_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  mylab (Tcl_GetString (objv[1]), i1, Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int myline_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  int *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  if (p1 != NULL) 
  { myline (p1, n);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int mypat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  mypat (i1, i2, i3, i4);
  return TCL_OK;
}

static int mysymb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, ierr = 0;
  double *p1, *p2;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i3) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[2], i1);
  if (p1 != NULL && p2 != NULL) 
    mysymb (p1, p2, i1, i2, i3);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int myvlt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    myvlt (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int namdis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  namdis (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int name_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  name (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int namjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  namjus (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int nancrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  nancrv (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int neglog_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  neglog (x1);
  return TCL_OK;
}

static int newmix_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  newmix ();
  return TCL_OK;
}

static int newpag_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  newpag ();
  return TCL_OK;
}

static int nlmess_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = nlmess (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nlnumb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  double x1; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  iret = nlnumb (x1, i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int noarln_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  noarln ();
  return TCL_OK;
}

static int nobar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nobar ();
  return TCL_OK;
}

static int nobgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nobgd ();
  return TCL_OK;
}

static int nochek_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nochek ();
  return TCL_OK;
}

static int noclip_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  noclip ();
  return TCL_OK;
}

static int nofill_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nofill ();
  return TCL_OK;
}

static int nograf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nograf ();
  return TCL_OK;
}

static int nohide_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  nohide ();
  return TCL_OK;
}

static int noline_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  noline (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int number_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double x1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  number (x1, i1, i2, i3);
  return TCL_OK;
}

static int numfmt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  numfmt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int numode_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str str str");
    return TCL_ERROR;
  }
  numode (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]),
          Tcl_GetString (objv[3]), Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int nwkday_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  iret = nwkday (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nxlegn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = nxlegn (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nxpixl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  iret = nxpixl (i1, i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nxposn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  double x1; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  iret = nxposn (x1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nylegn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = nylegn (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nypixl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  iret = nypixl (i1, i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nyposn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  double x1; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  iret = nyposn (x1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int nzposn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  double x1; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  iret = nzposn (x1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int openfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  iret = openfl (Tcl_GetString (objv[1]), i1, i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int opnwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  opnwin (i1);
  return TCL_OK;
}

static int origin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  origin (i1, i2);
  return TCL_OK;
}

static int page_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  page (i1, i2);
  return TCL_OK;
}

static int pagera_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  pagera ();
  return TCL_OK;
}

static int pagfll_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  pagfll (i1);
  return TCL_OK;
}

static int paghdr_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[3], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  paghdr (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]), i1, i2);
  return TCL_OK;
}

static int pagmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  pagmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int pagorg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  pagorg (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int pagwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  pagwin (i1, i2);
  return TCL_OK;
}

static int patcyc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  patcyc (i1, (long) i2);
  return TCL_OK;
}

static int pdfbuf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int n;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }

  n = pdfbuf (NULL, 0);

  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  n = pdfbuf (p, n);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, n));
  return TCL_OK;
}

static int pdfmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  pdfmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int pdfmrk_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  pdfmrk (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int penwid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  penwid (x1);
  return TCL_OK;
}

static int pie_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double x1, x2;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x2) != TCL_OK) return TCL_ERROR;
  pie (i1, i2, i3, x1, x2);
  return TCL_OK;
}

static int piebor_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  piebor (i1);
  return TCL_OK;
}

static int piecbk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;

  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  
  p = Tcl_GetString (objv[1]);
  tclpie = (char *) malloc (strlen (p) + 1);
  if (tclpie == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tclpie, p);
  pclpie = interp;
  piecbk (dis_piecbk);
  return TCL_OK;
}

void dis_piecbk (int iseg, double xdat, double xper, int *nrad,
              int *noff, double *angle, int *nvx, int *nvy, int *idrw, 
              int *iann)
{ int iret, n, iv;
  double xv;
  char cmd[257];
  Tcl_Obj *list, *element;

  sprintf (cmd, "%s %d %f %f %d %d %f %d %d %d %d", 
     tclpie, iseg, xdat, xper, *nrad, *noff, *angle, *nvx, *nvy, *idrw,
      *iann);
  iret = Tcl_Eval (pclpie, cmd);
  list = Tcl_GetObjResult (pclpie);

  if (Tcl_ListObjLength (pclpie, list, &n) != TCL_OK) return;
  if (n != 7) 
  { tcl_warn ("wrong number of elements in list!");
    return;
  }

  Tcl_ListObjIndex (pclpie, list, 0, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *nrad = iv;

  Tcl_ListObjIndex (pclpie, list, 1, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *noff = iv;

  Tcl_ListObjIndex (pclpie, list, 2, &element);
  if (Tcl_GetDoubleFromObj (pclpie, element, &xv) != TCL_OK) return;
  *angle = xv;

  Tcl_ListObjIndex (pclpie, list, 3, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *nvx = iv;

  Tcl_ListObjIndex (pclpie, list, 4, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *nvy = iv;

  Tcl_ListObjIndex (pclpie, list, 5, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *idrw = iv;

  Tcl_ListObjIndex (pclpie, list, 6, &element);
  if (Tcl_GetIntFromObj (pclpie, element, &iv) != TCL_OK) return;
  *iann = iv;
  return;
}

static int pieclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = int_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    pieclr (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int pieexp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  pieexp ();
  return TCL_OK;
}

static int piegrf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, nlin, ierr = 0;
  double *p1;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &nlin) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[3], n);
  if (p1 != NULL) 
  { if (nlin == 0)
      piegrf (" ", nlin, p1, n);
    else
      piegrf (clegbf, nlin, p1, n);
    free (p1);
  } 
  else
    return TCL_ERROR;
  return TCL_OK;
}

static int pielab_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  pielab (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int pieopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  pieopt (x1, x2);
  return TCL_OK;
}

static int pierot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  pierot (x1);
  return TCL_OK;
}

static int pietyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  pietyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int pieval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  pieval (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int pievec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  pievec (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int pike3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7;
  int i1, i2;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x7) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i2) != TCL_OK) return TCL_ERROR;
  pike3d (x1, x2, x3, x4, x5, x6, x7, i1, i2);
  return TCL_OK;
}

static int plat3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  plat3d (x1, x2, x3, x4, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int plyfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  plyfin (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int plyini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  plyini (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int pngmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  pngmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int point_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  point (i1, i2, i3, i4, i5);
  return TCL_OK;
}

static int polar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x[5];
  int i;
 
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f");
    return TCL_ERROR;
  }

  for (i = 0; i < 5; i++)
  { if (Tcl_GetDoubleFromObj (interp, objv[i + 1], &x[i]) != TCL_OK) 
      return TCL_ERROR;
  }
  grafp (x[0], x[1], x[2], x[3], x[4]);
  return TCL_OK;
}

static int polcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  polcrv (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int polclp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n, nmax, ierr = 0, nout;
  double *p1, *p2, *p3, *p4, x1;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int flt str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &nmax) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x1) != TCL_OK) return TCL_ERROR;

  p3 = (double *) calloc (nmax, sizeof (double));
  p4 = (double *) calloc (nmax, sizeof (double));
  if (p3 == NULL || p4 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p3);
    free (p4);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { nout = polclp (p1, p2, n, p3, p4, nmax, x1, Tcl_GetString (objv[6]));
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p3, nout);
    list2 = copy_dblarray (interp, p4, nout);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (nout));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int polmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  polmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int pos2pt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  Tcl_Obj *list;
 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;

  pos2pt (x1, x2, &x3, &x4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int pos3pt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  Tcl_Obj *list;
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;

  pos3pt (x1, x2, x3, &x4, &x5, &x6);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x5));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x6));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int posbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  posbar (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int posifl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  iret = posifl (i1, i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int proj3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  proj3d (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int projct_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  projct (Tcl_GetString (objv[1]));
  return TCL_OK;
}
 
static int psfont_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  psfont (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int psmode_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  psmode (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int pt2pos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  Tcl_Obj *list;
 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;

  pt2pos (x1, x2, &x3, &x4);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x3));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int pyra3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  int i1;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i1) != TCL_OK) return TCL_ERROR;
  pyra3d (x1, x2, x3, x4, x5, x6, i1);
  return TCL_OK;
}

static int qplbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  double *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { qplbar (p1, n);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int qplclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  double *p1;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { qplclr (p1, i1, i2);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int qplcon_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double *p1;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { qplcon (p1, i1, i2, i3);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int qplcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    qplcrv (p1, p2, n, Tcl_GetString (objv[4]));
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int qplot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    qplot (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int qplpie_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  double *p1;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { qplpie (p1, n);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int qplsca_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    qplsca (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int qplscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  qplscl (x1, x2, x3, x4, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int qplsur_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  double *p1;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { qplsur (p1, i1, i2);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int quad3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  quad3d (x1, x2, x3, x4, x5, x6);
  return TCL_OK;
}

static int rbfpng_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int n;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }

  n = rbfpng (NULL, 0);

  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  n = rbfpng (p, n);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, n));
  return TCL_OK;
}

static int rbmp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rbmp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int readfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int i1, n, nn;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  nn = readfl (i1, (unsigned char *) p, n);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, nn));
  return TCL_OK;
}

static int reawgt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  reawgt ();
  return TCL_OK;
}

static int recfll_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  recfll (i1, i2, i3, i4, i5);
  return TCL_OK;
}

static int rectan_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  rectan (i1, i2, i3, i4);
  return TCL_OK;
}

static int rel3pt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5;
  Tcl_Obj *list;
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;

  rel3pt (x1, x2, x3, &x4, &x5);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x5));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int resatt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  resatt ();
  return TCL_OK;
}

static int reset_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  reset (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int revscr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  revscr ();
  return TCL_OK;
}

static int rgbhsv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  Tcl_Obj *list;
 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  rgbhsv (x1, x2, x3, &x4, &x5, &x6);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x4));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x5));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewDoubleObj (x6));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int rgif_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rgif (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int rgtlab_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  rgtlab ();
  return TCL_OK;
}

static int rimage_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rimage (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int rlarc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x7) != TCL_OK) return TCL_ERROR;
  rlarc (x1, x2, x3, x4, x5, x6, x7);
  return TCL_OK;
}

static int rlarea_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    rlarea (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int rlcirc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  rlcirc (x1, x2, x3);
  return TCL_OK;
}

static int rlconn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  rlconn (x1, x2);
  return TCL_OK;
}

static int rlell_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  rlell (x1, x2, x3, x4);
  return TCL_OK;
}

static int rline_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  rline (x1, x2, x3, x4);
  return TCL_OK;
}

static int rlmess_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "str flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  rlmess (Tcl_GetString (objv[1]), x1, x2);
  return TCL_OK;
}

static int rlnumb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  rlnumb (x1, i1, x2, x3);
  return TCL_OK;
}

static int rlpie_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  rlpie (x1, x2, x3, x4, x5);
  return TCL_OK;
}

static int rlpoin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  int i1, i2, i3;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i3) != TCL_OK) return TCL_ERROR;
  rlpoin (x1, x2, i1, i2, i3);
  return TCL_OK;
}

static int rlrec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  rlrec (x1, x2, x3, x4);
  return TCL_OK;
}

static int rlrnd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  rlrnd (x1, x2, x3, x4, i1);
  return TCL_OK;
}

static int rlsec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  int i1;

  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i1) != TCL_OK) return TCL_ERROR;
  rlsec (x1, x2, x3, x4, x5, x6, i1);
  return TCL_OK;
}

static int rlstrt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  rlstrt (x1, x2);
  return TCL_OK;
}

static int rlsymb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  rlsymb (x1, x2, i1);
  return TCL_OK;
}

static int rlvec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  rlvec (x1, x2, x3, x4, i1);
  return TCL_OK;
}

static int rlwind_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x4) != TCL_OK) return TCL_ERROR;
  rlwind (x1, x2, x3, i1, x4);
  return TCL_OK;
}

static int rndrec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  rndrec (i1, i2, i3, i4, i5);
  return TCL_OK;
}

static int rot3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  rot3d (x1, x2, x3);
  return TCL_OK;
}

static int rpixel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  rpixel (i1, i2, &iret);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int rpixls_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int i1, i2, i3, i4, n;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;

  n = i3 * i4;
  if (imgopt == 1) n = n * 3;
  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  rpixls ((unsigned char *) p, i1, i2, i3, i4);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, n));
  return TCL_OK;
}

static int rpng_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rpng (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int rppm_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rppm (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int rpxrow_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;
  int i1, i2, i3,  n;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;

  n = i3;
  if (imgopt == 1) n = n * 3;
  p  = (char *) malloc (n);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  rpxrow ((unsigned char *) p, i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, n));
  return TCL_OK;
}

static int rtiff_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  rtiff (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int rvynam_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  rvynam ();
  return TCL_OK;
}

static int scale_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  scale (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int sclfac_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  sclfac (x1);
  return TCL_OK;
}

static int sclmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  sclmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int scrmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  scrmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int sector_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5;
  double x1, x2;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i5) != TCL_OK) return TCL_ERROR;
  sector (i1, i2, i3, i4, x1, x2, i5);
  return TCL_OK;
}

static int selwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  selwin (i1);
  return TCL_OK;
}

static int sendbf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  sendbf ();
  return TCL_OK;
}

static int sendmb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  sendmb ();
  return TCL_OK;
}

static int sendok_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  sendok ();
  return TCL_OK;
}

static int serif_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  serif ();
  return TCL_OK;
}

static int setbas_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  setbas (x1);
  return TCL_OK;
}

static int setcbk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  

  p = Tcl_GetString (objv[1]);
  tclprj = (char *) malloc (strlen (p) + 1);
  if (tclprj == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tclprj, p);
  pclprj = interp;
  setcbk (dis_prjcbk, Tcl_GetString (objv[2]));
  return TCL_OK;
}

void dis_prjcbk (double *x1, double *x2)
{ int iret;
  char cmd[257];
  Tcl_Obj *result;
  double *p;

  sprintf (cmd, "%s %f %f", tclprj, *x1, *x2);
  iret = Tcl_Eval (pclprj, cmd);
  result = Tcl_GetObjResult (pclprj);
  p = dbl_array (pclprj, result, 2);
  if (p != NULL)
  { *x1 = p[0];  
    *x2 = p[1];
    free (p);
  }
  return;
}

static int setclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  setclr (i1);
  return TCL_OK;
}

static int setcsr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  setcsr (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int setexp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  setexp (x1);
  return TCL_OK;
}

static int setfce_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  setfce (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int setfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  setfil (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int setgrf_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str str str");
    return TCL_ERROR;
  }
  setgrf (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]),
          Tcl_GetString (objv[3]), Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int setind_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  setind (i1, x1, x2, x3);
  return TCL_OK;
}

static int setmix_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  setmix (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int setpag_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  setpag (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int setres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  setres (i1, i2);
  return TCL_OK;
}

static int setrgb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  setrgb (x1, x2, x3);
  return TCL_OK;
}

static int setscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  double *p1;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { setscl (p1, n, Tcl_GetString (objv[3]));
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int setvlt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  setvlt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int setxid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  setxid (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int shdafr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdafr (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdasi_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdasi (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdaus_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdaus (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdcha_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  shdcha ();
  return TCL_OK;
}

static int shdcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n1, n2, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &n2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n1);
  p2 = dbl_array (interp, objv[2], n1);
  p3 = dbl_array (interp, objv[4], n2);
  p4 = dbl_array (interp, objv[5], n2);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    shdcrv (p1, p2, n1, p3, p4, n2);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdeur_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdeur (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdfac_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  shdfac (x1);
  return TCL_OK;
}

static int shdmap_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  shdmap (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int shdmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  shdmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int shdnor_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdnor (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdpat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  shdpat ((long) i1);
  return TCL_OK;
}

static int shdsou_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdsou (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shdusa_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p3;
  long *p2; 

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = long_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    shdusa (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shield_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  shield (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int shlcir_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  shlcir (i1, i2, i3);
  return TCL_OK;
}

static int shldel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  shldel (i1);
  return TCL_OK;
}

static int shlell_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double x1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x1) != TCL_OK) return TCL_ERROR;
  shlell (i1, i2, i3, i4, x1);
  return TCL_OK;
}

static int shlind_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = shlind ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int shlpie_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double x1, x2;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x2) != TCL_OK) return TCL_ERROR;
  shlpie (i1, i2, i3, x1, x2);
  return TCL_OK;
}

static int shlpol_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  int *p1, *p2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = int_array (interp, objv[1], n);
  p2 = int_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    shlpol (p1, p2, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int shlrct_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double x1;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x1) != TCL_OK) return TCL_ERROR;
  shlrct (i1, i2, i3, i4, x1);
  return TCL_OK;
}

static int shlrec_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  shlrec (i1, i2, i3, i4);
  return TCL_OK;
}

static int shlres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  shlres (i1);
  return TCL_OK;
}

static int shlsur_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  shlsur ();
  return TCL_OK;
}

static int shlvis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  shlvis (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int simplx_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  simplx ();
  return TCL_OK;
}

static int skipfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  iret = skipfl (i1, i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int smxalf_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  smxalf (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]),
          Tcl_GetString (objv[3]), i1);
  return TCL_OK;
}

static int solid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  solid ();
  return TCL_OK;
}

static int sortr1_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n;
  double *p1;
  Tcl_Obj *list;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { sortr1 (p1, n, Tcl_GetString (objv[3]));
    list = copy_dblarray (interp, p1, n);
    Tcl_SetObjResult (interp, list);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int sortr2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n, ierr = 0;
  double *p1, *p2;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { sortr2 (p1, p2, n, Tcl_GetString (objv[4]));
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p1, n);
    list2 = copy_dblarray (interp, p2, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int spcbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  spcbar (i1);
  return TCL_OK;
}

static int sphe3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i2) != TCL_OK) return TCL_ERROR;
  sphe3d (x1, x2, x3, x4, i1, i2);
  return TCL_OK;
}

static int spline_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, nspl, ierr = 0;
  double *p1, *p2, *p3, *p4;
  Tcl_Obj *list, *list1, *list2; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  p3 = (double *) calloc (nspline, sizeof (double));
  p4 = (double *) calloc (nspline, sizeof (double));
  if (p3 == NULL || p4 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p3);
    free (p4);
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { spline (p1, p2, n, p3, p4, &nspl);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p3, nspl);
    list2 = copy_dblarray (interp, p4, nspl);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (nspl));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;

  return TCL_OK;
}

static int splmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  splmod (i1, i2);
  if (i2 >= 5) nspline = i2;
  return TCL_OK;
}

static int stmmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  stmmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int stmopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  stmopt (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int stmpts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nmax, n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6, x0, y0;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list int int list list flt flt int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x0) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[8], &y0) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &nmax) != TCL_OK) return TCL_ERROR;

  p5 = (double *) calloc (nmax, sizeof (double));
  p6 = (double *) calloc (nmax, sizeof (double));
  if (p5 == NULL || p6 == NULL)
  { tcl_warn ("not enough memory!");
    free (p5);
    free (p6);
    return TCL_ERROR;
  }

  p1 = dbl_matrix (interp, objv[1], nx, ny);
  p2 = dbl_matrix (interp, objv[2], nx, ny);
  p3 = dbl_array (interp, objv[5], nx);
  p4 = dbl_array (interp, objv[6], ny);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
  { stmpts (p1, p2, nx, ny, p3, p4, x0, y0, p5, p6, nmax, &n);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p5, n);
    list2 = copy_dblarray (interp, p6, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (n));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int stmpts3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nz, nmax, n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6, *p7, *p8, *p9, x0, y0, z0;
  Tcl_Obj *list, *list1, *list2, *list3;

  if (objc != 14)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list int int int list list list flt flt flt int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nz) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[10], &x0) != TCL_OK) 
     return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[11], &y0) != TCL_OK) 
     return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[12], &z0) != TCL_OK) 
     return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[13], &nmax) != TCL_OK) return TCL_ERROR;

  p7 = (double *) calloc (nmax, sizeof (double));
  p8 = (double *) calloc (nmax, sizeof (double));
  p9 = (double *) calloc (nmax, sizeof (double));
  if (p7 == NULL || p8 == NULL || p9 == NULL)
  { tcl_warn ("not enough memory!");
    free (p7);
    free (p8);
    free (p9);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], nx *ny * nz);
  p2 = dbl_array (interp, objv[2], nx *ny * nz);
  p3 = dbl_array (interp, objv[3], nx *ny * nz);
  p4 = dbl_array (interp, objv[7], nx);
  p5 = dbl_array (interp, objv[8], ny);
  p6 = dbl_array (interp, objv[9], nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
  { stmpts3d (p1, p2, p3, nx, ny, nz, p4, p5, p6, x0, y0, z0, 
              p7, p8, p9, nmax, &n);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p7, n);
    list2 = copy_dblarray (interp, p8, n);
    list3 = copy_dblarray (interp, p9, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (n));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  free (p7);
  free (p8);
  free (p9);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

void  stmpts3d (const double *xv, const double *yv, const double *zv,
	      int nx, int ny, int nz, const double *xp, const double *yp, 
	      const double *zp, double x0, double y0, double z0, 
              double *xray, double *yray, double *zray, int nmax, int *nray);

static int stmtri_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ntri, nray, *p5, *p6, *p7, ierr = 0;
  double *p1, *p2, *p3, *p4, *p8 = NULL, *p9 = NULL;

  if (objc != 13)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list list int list list list int list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &ntri) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[12], &nray) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);

  p5 = int_array (interp, objv[6], ntri);
  p6 = int_array (interp, objv[7], ntri);
  p7 = int_array (interp, objv[8], ntri);

  if (nray > 0)
  { p8 = dbl_array (interp, objv[10], nray);
    p9 = dbl_array (interp, objv[11], nray);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && p5 != NULL &&
      p6 != NULL && p7 != NULL && 
      (nray == 0 || (p8 != NULL && p9 != NULL))) 
    stmtri (p1, p2, p3, p4, n, p5, p6, p7, ntri, p8, p9, nray);
  else
    ierr = 1;
 
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

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int stmval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  stmval (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int stream_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list int int list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], nx, ny);
  p2 = dbl_matrix (interp, objv[2], nx, ny);
  p3 = dbl_array (interp, objv[5], nx);
  p4 = dbl_array (interp, objv[6], ny);

  if (n > 0)
  { p5 = dbl_array (interp, objv[7], n);
    p6 = dbl_array (interp, objv[8], n);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL && 
      (n == 0 || (p5 != NULL && p6 != NULL))) 
    stream (p1, p2, nx, ny, p3, p4, p5, p6, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (n > 0) 
  { free (p5);
    free (p6);
  }
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int stream3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nz, n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6, *p7 = NULL, *p8 = NULL, *p9 = NULL;

  if (objc != 14)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list int int int list list list list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nz) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[13], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], nx * ny *nz);
  p2 = dbl_array (interp, objv[2], nx * ny *nz);
  p3 = dbl_array (interp, objv[3], nx * ny *nz);
  p4 = dbl_array (interp, objv[7], nx);
  p5 = dbl_array (interp, objv[8], ny);
  p6 = dbl_array (interp, objv[9], nz);

  if (n > 0)
  { p7 = dbl_array (interp, objv[10], n);
    p8 = dbl_array (interp, objv[11], n);
    p9 = dbl_array (interp, objv[12], n);
  }

  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL &&
      (n == 0 || (p7 != NULL && p8 != NULL && p9 != NULL))) 
    stream3d (p1, p2, p3, nx, ny, nz, p4, p5, p6, p7, p8, p9, n);
  else
    ierr = 1;

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

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int strt3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  strt3d (x1, x2, x3);
  return TCL_OK;
}

static int strtpt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  strtpt (x1, x2);
  return TCL_OK;
}

static int surclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  surclr (i1, i2);
  return TCL_OK;
}

static int surfce_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    surfce (p1, i1, p2, i2, p3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int surfcp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  char *p;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "str flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (tclfunc != NULL) free (tclfunc);
  p = Tcl_GetString (objv[1]);
  tclfunc = (char *) malloc (strlen (p) + 1);
  if (tclfunc == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tclfunc, p);
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x6) != TCL_OK) return TCL_ERROR;
  tcl_interp = interp;
  surfcp (dis_funcbck, x1, x2, x3, x4, x5, x6);
  return TCL_OK;
}

double dis_funcbck (double x, double y, int iopt)
{ int iret;
  Tcl_Obj *result;
  double xret = 0.;
  char cmd[257];
  sprintf (cmd, "%s %f %f %d", tclfunc, x, y, iopt);
  iret = Tcl_Eval (tcl_interp, cmd);
  result = Tcl_GetObjResult (tcl_interp);
  Tcl_GetDoubleFromObj (tcl_interp, result, &xret);
  return xret;
}

static int surfun_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  int i1, i2;
  char *p;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int flt int flt");
    return TCL_ERROR;
  }
  
  if (tclfunc != NULL) free (tclfunc);
  p = Tcl_GetString (objv[1]);
  tclfunc = (char *) malloc (strlen (p) + 1);
  if (tclfunc == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tclfunc, p);
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x2) != TCL_OK) return TCL_ERROR;
  tcl_interp = interp;
  surfun (dis_funcbck2, i1, x1, i2, x2);
  return TCL_OK;
}

double dis_funcbck2 (double x, double y)
{ int iret;
  Tcl_Obj *result;
  double xret = 0.;
  char cmd[257];
  sprintf (cmd, "%s %f %f", tclfunc, x, y);
  iret = Tcl_Eval (tcl_interp, cmd);
  result = Tcl_GetObjResult (tcl_interp);
  Tcl_GetDoubleFromObj (tcl_interp, result, &xret);
  return xret;
}

static int suriso_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nz, ierr = 0;
  double *p1, *p2, *p3, *p4, x1;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list int list int list int list flt");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nz) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[8], &x1) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], nx);
  p2 = dbl_array (interp, objv[3], ny);
  p3 = dbl_array (interp, objv[5], nz);
  p4 = dbl_array (interp, objv[7], nx * ny * nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    suriso (p1, nx, p2, ny, p3, nz, p4, x1);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int surmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double *p1;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], i1, i2);
  if (p1 != NULL) 
  { surmat (p1, i1, i2, i3, i4);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int surmsh_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  surmsh (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int suropt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  suropt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int surshc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list list");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  p4 = dbl_matrix (interp, objv[6], i1, i2);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    surshc (p1, i1, p2, i2, p3, p4);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int surshd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int list int list");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[3], i2);
  p3 = dbl_matrix (interp, objv[5], i1, i2);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    surshd (p1, i1, p2, i2, p3);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int sursze_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  sursze (x1, x2, x3, x4);
  return TCL_OK;
}

static int surtri_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, ierr = 0, *p4, *p5, *p6;
  double *p1, *p2, *p3;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
      "list list list int list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i2) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], i1);
  p2 = dbl_array (interp, objv[2], i1);
  p3 = dbl_array (interp, objv[3], i1);
  p4 = int_array (interp, objv[5], i2);
  p5 = int_array (interp, objv[6], i2);
  p6 = int_array (interp, objv[7], i2);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p4 != NULL && p4 != NULL) 
    surtri (p1, p2, p3, i1, p4, p5, p6, i2);
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int survis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  survis (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int swapi4_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, i, *p1;
  Tcl_Obj *list; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  p1 = int_array (interp, objv[1], n);
  if (p1 != NULL) 
  { swapi4 (p1, n);
    list = Tcl_NewListObj (0, NULL);
    for (i = 0; i < n; i++)
      Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (p1[i]));

    Tcl_SetObjResult (interp, list);
    free (p1);
  }
    return TCL_ERROR;

  return TCL_OK;
}

static int swgatt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  swgatt (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int swgbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgbox (i1, i2);
  return TCL_OK;
}

static int swgbut_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgbut (i1, i2);
  return TCL_OK;
}

static int swgcb2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (ncbray >= MAX_CB)
  { tcl_warn ("too many callback routines!");
    return TCL_ERROR;
  }

  icbray[ncbray] = i1; 
  p = Tcl_GetString (objv[2]);
  tcbray[ncbray] = (char *) malloc (strlen (p) + 1);
  if (tcbray[ncbray] == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tcbray[ncbray], p);
  pcbray[ncbray] = interp;
  ncbray++;
  swgcb2 (i1, dis_callbck3);
  return TCL_OK;
}

static int swgcb3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (ncbray >= MAX_CB)
  { tcl_warn ("too many callback routines!");
    return TCL_ERROR;
  }

  icbray[ncbray] = i1; 
  p = Tcl_GetString (objv[2]);
  tcbray[ncbray] = (char *) malloc (strlen (p) + 1);
  if (tcbray[ncbray] == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tcbray[ncbray], p);
  pcbray[ncbray] = interp;
  ncbray++;
  swgcb3 (i1, dis_callbck4);
  return TCL_OK;
}

void dis_callbck3 (int id, int irow, int icol)
{ int i, iret;
  char cmd[257];

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
      sprintf (cmd, "%s %d %d %d", tcbray[i], id, irow, icol);
    iret = Tcl_Eval (pcbray[i], cmd);
    return;
  }
  return;
}

void dis_callbck4 (int id, int ival)
{ int i, iret;
  char cmd[257];

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
      sprintf (cmd, "%s %d %d", tcbray[i], id, ival);
    iret = Tcl_Eval (pcbray[i], cmd);
    return;
  }
  return;
}

static int swgcbk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (ncbray >= MAX_CB)
  { tcl_warn ("too many callback routines!");
    return TCL_ERROR;
  }

  icbray[ncbray] = i1; 
  p = Tcl_GetString (objv[2]);
  tcbray[ncbray] = (char *) malloc (strlen (p) + 1);
  if (tcbray[ncbray] == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tcbray[ncbray], p);
  pcbray[ncbray] = interp;
  ncbray++;
  swgcbk (i1, dis_callbck2);
  return TCL_OK;
}

void dis_callbck2 (int id)
{ int i, iret;
  char cmd[257];

  for (i = ncbray - 1; i >= 0; i--)
  { if (id == icbray[i])
    sprintf (cmd, "%s %d", tcbray[i], id);
    iret = Tcl_Eval (pcbray[i], cmd);
    return;
  }
  return;
}

static int swgclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  swgclr (x1, x2, x3, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int swgbgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int id;
  double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &id) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  swgbgd (id, x1, x2, x3);
  return TCL_OK;
}

static int swgfgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int id;
  double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &id) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  swgfgd (id, x1, x2, x3);
  return TCL_OK;
}

static int swgdrw_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  swgdrw (x1);
  return TCL_OK;
}

static int swgfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  swgfil (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgflt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  int i1, i2;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgflt (i1, x1, i2);
  return TCL_OK;
}

static int swgfnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  swgfnt (Tcl_GetString (objv[1]), n);
  return TCL_OK;
}

static int swgfoc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  swgfoc (i1);
  return TCL_OK;
}

static int swghlp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  swghlp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int swgint_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgint (i1, i2);
  return TCL_OK;
}

static int swgiop_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  swgiop (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  swgjus (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swglis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swglis (i1, i2);
  return TCL_OK;
}

static int swgmix_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  swgmix (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgmrg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  swgmrg (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgoff_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgoff (i1, i2);
  return TCL_OK;
}

static int swgopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  swgopt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgpop_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  swgpop (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int swgpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgpos (i1, i2);
  return TCL_OK;
}

static int swgray_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  double *p1;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { swgray (p1, n, Tcl_GetString (objv[3]));
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int swgscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  swgscl (i1, x1);
  return TCL_OK;
}

static int swgsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  swgsiz (i1, i2);
  return TCL_OK;
}

static int swgspc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  swgspc (x1, x2);
  return TCL_OK;
}

static int swgstp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  swgstp (x1);
  return TCL_OK;
}

static int swgtbf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double x1;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt int int int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;
  swgtbf (i1, x1, i2, i3, i4, Tcl_GetString (objv[6]));
  return TCL_OK;
}

static int swgtbi_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  swgtbi (i1, i2, i3, i4, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int swgtbl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  double *p1;
 
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "int list int int int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[2], i2);
  if (p1 != NULL) 
  { swgtbl (i1, p1, i2, i3, i4, Tcl_GetString (objv[6]));
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int swgtbs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  swgtbs (i1, Tcl_GetString (objv[2]), i2, i3, Tcl_GetString (objv[5]));
  return TCL_OK;
}

static int swgtit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  swgtit (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int swgtxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  swgtxt (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgtyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  swgtyp (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int swgval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  swgval (i1, x1);
  return TCL_OK;
}

static int swgwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  swgwin (i1, i2, i3, i4);
  return TCL_OK;
}

static int swgwth_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  swgwth (i1);
  return TCL_OK;
}

static int symb3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  int i1;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  symb3d (i1, x1, x2, x3);
  return TCL_OK;
}

static int symbol_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  symbol (i1, i2, i3);
  return TCL_OK;
}

static int symfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  symfil (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int symrot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  symrot (x1);
  return TCL_OK;
}

static int tellfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = tellfl (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int texmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  texmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int texopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  texopt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int texval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  texval (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int thkc3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  thkc3d (x1);
  return TCL_OK;
}

static int thkcrv_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  thkcrv (i1);
  return TCL_OK;
}

static int thrfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  thrfin ();
  return TCL_OK;
}

static int thrini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  thrini (i1);
  return TCL_OK;
}

static int ticks_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int string");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  ticks (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int ticlen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  ticlen (i1, i2);
  return TCL_OK;
}

static int ticmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  ticmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int ticpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  ticpos (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int tifmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  tifmod (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]));
  return TCL_OK;
}

static int tiforg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  tiforg (i1, i2);
  return TCL_OK;
}

static int tifwin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  tifwin (i1, i2, i3, i4);
  return TCL_OK;
}

static int timopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  timopt ();
  return TCL_OK;
}

static int titjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  titjus (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int title_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  title ();
  return TCL_OK;
}

static int titlin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  titlin (Tcl_GetString (objv[1]), n);
  return TCL_OK;
}

static int titpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  titpos (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int torus3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7, x8;
  int i1, i2;
  if (objc != 11)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x7) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[8], &x8) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &i2) != TCL_OK) return TCL_ERROR;
  torus3d (x1, x2, x3, x4, x5, x6, x7, x8, i1, i2);
  return TCL_OK;
}

static int tprfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  tprfin ();
  return TCL_OK;
}

static int tprini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  tprini ();
  return TCL_OK;
}

static int tprmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  tprmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int tprval_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  tprval (x1);
  return TCL_OK;
}

static int tr3axs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  tr3axs (x1, x2, x3, x4);
  return TCL_OK;
}

static int tr3res_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  tr3res ();
  return TCL_OK;
}

static int tr3rot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  tr3rot (x1, x2, x3);
  return TCL_OK;
}

static int tr3scl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  tr3scl (x1, x2, x3);
  return TCL_OK;
}

static int tr3shf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  tr3shf (x1, x2, x3);
  return TCL_OK;
}

static int trfco1_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n;
  double *p1;
  Tcl_Obj *list;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int str str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  if (p1 != NULL) 
  { trfco1 (p1, n, Tcl_GetString (objv[3]), Tcl_GetString (objv[4]));
    list = copy_dblarray (interp, p1, n);
    Tcl_SetObjResult (interp, list);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int trfco2_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n, ierr = 0;
  double *p1, *p2;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int str str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { trfco2 (p1, p2, n, Tcl_GetString (objv[4]), Tcl_GetString (objv[5]));
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p1, n);
    list2 = copy_dblarray (interp, p2, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int trfco3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n, ierr = 0;
  double *p1, *p2, *p3;
  Tcl_Obj *list, *list1, *list2, *list3;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int str str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
  { trfco3 (p1, p2, p3, n, Tcl_GetString (objv[5]), Tcl_GetString (objv[6]));
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p1, n);
    list2 = copy_dblarray (interp, p2, n);
    list3 = copy_dblarray (interp, p3, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int trfdat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, i1, i2, i3;
  Tcl_Obj *list;
 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  trfdat (n, &i1, &i2, &i3);
  list = Tcl_NewListObj (0, NULL);
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i1));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i2));
  Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (i3));
  Tcl_SetObjResult (interp, list);
  return TCL_OK;
}

static int trfmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, n;
  double *p1, *p2;
  Tcl_Obj *list;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list int int int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;
  p1 = dbl_array (interp, objv[1], i1 * i2);
  n = i3 * i4;
  p2 = (double *) calloc (n, sizeof (double));
  if (p2 == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }
   
  if (p1 != NULL) 
  { trfmat (p1, i1, i2, p2, i3, i4);
    list = copy_dblarray (interp, p2, n);
    Tcl_SetObjResult (interp, list);
    free (p1);
  }
  else
    return TCL_ERROR;

  return TCL_OK;
}

static int trfrel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i, n, ierr = 0;
  double *p1, *p2;
  Tcl_Obj *list, *list1, *list2;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
  { trfrel (p1, p2, n);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p1, n);
    list2 = copy_dblarray (interp, p2, n);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;

  free (p1);
  free (p2);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int trfres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  trfres ();
  return TCL_OK;
}

static int trfrot_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  int i1, i2; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  trfrot (x1, i1, i2);
  return TCL_OK;
}

static int trfscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  trfscl (x1, x2);
  return TCL_OK;
}

static int trfshf_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  trfshf (i1, i2);
  return TCL_OK;
}

static int tria3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n = 3, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list");
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    tria3d (p1, p2, p3);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int triang_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nmax, n, ntri;
  int *p3, *p4, *p5;
  double *p1, *p2; 
  Tcl_Obj *list, *list1, *list2, *list3; 
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &nmax) != TCL_OK) return TCL_ERROR;
  p3 = (int *) calloc (nmax, sizeof (int));
  p4 = (int *) calloc (nmax, sizeof (int));
  p5 = (int *) calloc (nmax, sizeof (int));
  if (p3 == NULL || p4 == NULL || p5 == NULL) 
  { tcl_warn ("not enough memory!");
    free (p3);
    free (p4);
    free (p5);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n + 3);
  p2 = dbl_array (interp, objv[2], n + 3);
  if (p1 != NULL && p2 != NULL) 
  { ntri = triang (p1, p2, n, p3, p4, p5, nmax);
    list = Tcl_NewListObj (0, NULL);
    list1 = copy_intarray (interp, p3, ntri);
    list2 = copy_intarray (interp, p4, ntri);
    list3 = copy_intarray (interp, p5, ntri);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (ntri));
    Tcl_SetObjResult (interp, list);
  }
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  return TCL_OK;
}

static int triflc_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0, *p3;
  double *p1, *p2;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = int_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    triflc (p1, p2, p3, n);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int trifll_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n = 3, ierr = 0;
  double *p1, *p2;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list");
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  if (p1 != NULL && p2 != NULL) 
    trifll (p1, p2);
  else
    ierr = 1;

  free (p1);
  free (p2);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int triplx_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  triplx ();
  return TCL_OK;
}

static int tripts_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ntri, maxpts, maxcrv, ierr = 0, *p4, *p5, *p6, *p9, nlins, i, np;
  double *p1, *p2, *p3, *p7, *p8, x1;
  Tcl_Obj *list, *list1, *list2, *list3;

  if (objc != 12)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list int list list list int flt int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &ntri) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[9], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &maxpts) != TCL_OK) 
     return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[11], &maxcrv) != TCL_OK) 
     return TCL_ERROR;

  p7 = (double *) calloc (maxpts, sizeof (double));
  p8 = (double *) calloc (maxpts, sizeof (double));
  p9 = (int *) calloc (maxcrv, sizeof (int));
  if (p7 == NULL || p8 == NULL || p9 == NULL)
  { tcl_warn ("not enough memory!");
    free (p7);
    free (p8);
    free (p9);
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = int_array (interp, objv[5], ntri);
  p5 = int_array (interp, objv[6], ntri);
  p6 = int_array (interp, objv[7], ntri);

  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
  { tripts (p1, p2, p3, n, p4, p5, p6, ntri, x1, 
            p7, p8,  maxpts, p9, maxcrv, &nlins);
    np = 0;
    for (i = 0; i < nlins; i++)
      np += p9[i];

    list = Tcl_NewListObj (0, NULL);
    list1 = copy_dblarray (interp, p7, np);
    list2 = copy_dblarray (interp, p8, np);
    list3 = copy_intarray (interp, p9, nlins);
    Tcl_ListObjAppendElement (interp, list, list1);
    Tcl_ListObjAppendElement (interp, list, list2);
    Tcl_ListObjAppendElement (interp, list, list3);
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (nlins));
    Tcl_SetObjResult (interp, list);
  }
  else
    ierr = 1;
 
  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int trmlen_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = trmlen (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int ttfont_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  ttfont (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int tube3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6, x7;
  int i1, i2;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f f f f i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[7], &x7) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i2) != TCL_OK) return TCL_ERROR;
  tube3d (x1, x2, x3, x4, x5, x6, x7, i1, i2);
  return TCL_OK;
}

static int txtbgd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  txtbgd (i1);
  return TCL_OK;
}

static int txtjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  txtjus (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int txture_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, n;
  int *p1;
  Tcl_Obj *list;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  n = i1 * i2;
  p1 = (int *) calloc (n, sizeof (int));
  if (p1 == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }
   
  txture (p1, i1, i2);
  list = copy_intarray (interp, p1, n);
  Tcl_SetObjResult (interp, list);
  free (p1);
  return TCL_OK;
}

static int unit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (i1 == 0)
    unit (NULL);
  else
    unit ((void *) stdout);

  return TCL_OK;
}

static int units_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  units (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int upstr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p, *q;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  q = Tcl_GetString (objv[1]);
  p = (char *) malloc (strlen (q) + 1);
  if (p == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }
  strcpy (p, q);
  upstr (p);
  Tcl_SetObjResult (interp, Tcl_NewStringObj (p, -1));
  free (p);
  return TCL_OK;
}

static int utfint_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, i, nray, *p;
  Tcl_Obj *list; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  n = strlen (Tcl_GetString (objv[1]));
  p = (int *) calloc (n, sizeof (int));
  if (p == NULL) 
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  nray = utfint (Tcl_GetString (objv[1]), p, n);
  list = Tcl_NewListObj (0, NULL);
  for (i = 0; i < nray; i++)
    Tcl_ListObjAppendElement (interp, list, Tcl_NewIntObj (p[i]));

  Tcl_SetObjResult (interp, list);
  free (p);
  return TCL_OK;
}

static int vang3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  vang3d (x1);
  return TCL_OK;
}

static int vclp3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  vclp3d (x1, x2);
  return TCL_OK;
}

static int vecclr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  vecclr (i1);
  return TCL_OK;
}

static int vecf3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ivec, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list list list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[7], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &ivec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = dbl_array (interp, objv[5], n);
  p6 = dbl_array (interp, objv[6], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL &&
      p4 != NULL && p5 != NULL && p6 != NULL) 
    vecf3d (p1, p2, p3, p4, p5, p6, n, ivec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vecfld_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ivec, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, 
       "list list list list int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &ivec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    vecfld (p1, p2, p3, p4, n, ivec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vecmat_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nvec, ierr = 0;
  double *p1, *p2, *p3, *p4;

  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list int int list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[3], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &nvec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_matrix (interp, objv[1], nx, ny);
  p2 = dbl_matrix (interp, objv[2], nx, ny);
  p3 = dbl_array (interp, objv[5], nx);
  p4 = dbl_array (interp, objv[6], ny);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    vecmat (p1, p2, nx, ny, p3, p4, nvec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vecmat3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int nx, ny, nz, nvec, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 11)
  { Tcl_WrongNumArgs (interp, 1, objv, 
        "list list list int int int list list list int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &nx) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &ny) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &nz) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &nvec) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], nx * ny * nz);
  p2 = dbl_array (interp, objv[2], nx * ny * nz);
  p3 = dbl_array (interp, objv[3], nx * ny * nz);
  p4 = dbl_array (interp, objv[7], nx);
  p5 = dbl_array (interp, objv[8], ny);
  p6 = dbl_array (interp, objv[9], nz);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
    vecmat3d (p1, p2, p3, nx, ny, nz, p4, p5, p6, nvec);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);

  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}


static int vecopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  vecopt (x1, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int vector_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, i5;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i5) != TCL_OK) return TCL_ERROR;
  vector (i1, i2, i3, i4, i5);
  return TCL_OK;
}

static int vectr3_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  int i1;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i1) != TCL_OK) return TCL_ERROR;
  vectr3 (x1, x2, x3, x4, x5, x6, i1);
  return TCL_OK;
}

static int vfoc3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  vfoc3d (x1, x2, x3, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int view3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  view3d (x1, x2, x3, Tcl_GetString (objv[4]));
  return TCL_OK;
}

static int vkxbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  vkxbar (i1);
  return TCL_OK;
}

static int vkybar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  vkybar (i1);
  return TCL_OK;
}

static int vkytit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  vkytit (i1);
  return TCL_OK;
}

static int vltfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  vltfil (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int vscl3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  vscl3d (x1);
  return TCL_OK;
}

static int vtx3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3;

  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[4], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL) 
    vtx3d (p1, p2, p3, n, Tcl_GetString (objv[5]));
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vtxc3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0, *p4;
  double *p1, *p2, *p3;

  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[5], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = int_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    vtxc3d (p1, p2, p3, p4, n, Tcl_GetString (objv[6]));
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vtxn3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n, ierr = 0;
  double *p1, *p2, *p3, *p4, *p5, *p6;

  if (objc != 9)
  { Tcl_WrongNumArgs (interp, 1, objv, 
            "list list list list list list int str");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[7], &n) != TCL_OK) return TCL_ERROR;

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = dbl_array (interp, objv[4], n);
  p5 = dbl_array (interp, objv[5], n);
  p6 = dbl_array (interp, objv[6], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && 
      p4 != NULL && p5 != NULL && p6 != NULL) 
    vtxn3d (p1, p2, p3, p4, p5, p6, n, Tcl_GetString (objv[8]));
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  free (p5);
  free (p6);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int vup3d_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  vup3d (x1);
  return TCL_OK;
}

static int wgapp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgapp (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgappb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, nn, n, iret;
  char *p;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  p = Tcl_GetStringFromObj (objv[2], &nn);
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  n = i2 * i3 * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }

  iret = wgappb (i1, (unsigned char *) p, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgbas_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgbas (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgbox_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  iret = wgbox (i1, Tcl_GetString (objv[2]), i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgbut_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  iret = wgbut (i1, Tcl_GetString (objv[2]), i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgcmd_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgcmd (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgdlis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  iret = wgdlis (i1, Tcl_GetString (objv[2]), i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgdraw_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgdraw (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgfil_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgfil (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]),
                Tcl_GetString (objv[4]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgfin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  wgfin ();
  return TCL_OK;
}

static int wgicon_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  iret = wgicon (i1, Tcl_GetString (objv[2]), i2, i3, Tcl_GetString (objv[5]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, n, nn, iret;
  char *p;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  p = Tcl_GetStringFromObj (objv[3], &nn);
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i3) != TCL_OK) return TCL_ERROR;

  n = i2 * i3 * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }
  iret = wgimg (i1, Tcl_GetString (objv[2]), (unsigned char *) p, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  iret = wgini (Tcl_GetString (objv[1]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wglab_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wglab (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wglis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  iret = wglis (i1, Tcl_GetString (objv[2]), i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgltxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str str int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  iret = wgltxt (i1, Tcl_GetString (objv[2]), Tcl_GetString (objv[3]), i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgok_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgok (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  double x1, x2, x3; 
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x3) != TCL_OK) return TCL_ERROR;
  iret = wgpbar (i1, x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpbut_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgpbut (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpicon_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  iret = wgpicon (i1, Tcl_GetString (objv[2]), i2, i3, Tcl_GetString (objv[5]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpimg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, n, nn, iret;
  char *p;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  p = Tcl_GetStringFromObj (objv[3], &nn);
  if (Tcl_GetIntFromObj (interp, objv[4], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i3) != TCL_OK) return TCL_ERROR;

  n = i2 * i3 * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }
  iret = wgpimg (i1, Tcl_GetString (objv[2]), (unsigned char *) p, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpop_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgpop (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgpopb_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, nn, n, iret;
  char *p;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int int");
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  p = Tcl_GetStringFromObj (objv[2], &nn);
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  n = i2 * i3 * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }

  iret = wgpopb (i1, (unsigned char *) p, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgquit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgquit (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, iret;
  double x1, x2, x3; 
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str flt flt flt int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i2) != TCL_OK) return TCL_ERROR;
  iret = wgscl (i1, Tcl_GetString (objv[2]), x1, x2, x3, i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgsep_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgsep (i1);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgstxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  iret = wgstxt (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgtbl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, iret;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  iret = wgtbl (i1, i2, i3);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int wgtxt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, iret;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  iret = wgtxt (i1, Tcl_GetString (objv[2]));
  Tcl_SetObjResult (interp, Tcl_NewIntObj (iret));
  return TCL_OK;
}

static int widbar_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  widbar (i1);
  return TCL_OK;
}

static int wimage_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  wimage (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winapp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winapp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int wincbk_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ char *p;

  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  

  p = Tcl_GetString (objv[1]);
  tclwin = (char *) malloc (strlen (p) + 1);
  if (tclwin == NULL)
  { tcl_warn ("not enough memory!");
    return TCL_ERROR;
  }

  strcpy (tclwin, p);
  pclwin = interp;
  wincbk (dis_wincbk, Tcl_GetString (objv[2]));
  return TCL_OK;
}

void dis_wincbk (int id, int nx, int ny, int nw, int nh)
{ int iret;
  char cmd[257];

  sprintf (cmd, "%s %d %d %d %d %d", tclwin, id, nx, ny, nw, nh);
  iret = Tcl_Eval (pclwin, cmd);
  return;
}

static int windbr_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  double x1, x2;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt int int int flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x2) != TCL_OK) return TCL_ERROR;
  windbr (x1, i1, i2, i3, x2);
  return TCL_OK;
}

static int window_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i4) != TCL_OK) return TCL_ERROR;
  window (i1, i2, i3, i4);
  return TCL_OK;
}

static int winfnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winfnt (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winico_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winico (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winid_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = winid ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int winjus_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winjus (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winkey_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winkey (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  winmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int winopt_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &n) != TCL_OK) return TCL_ERROR;
  winopt (n, Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int winsiz_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  winsiz (i1, i2);
  return TCL_OK;
}

static int wintit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  wintit (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int wintyp_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  wintyp (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int wmfmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  wmfmod (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int world_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  world ();
  return TCL_OK;
}

static int wpixel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[2], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i3) != TCL_OK) return TCL_ERROR;
  wpixel (i1, i2, i3);
  return TCL_OK;
}

static int wpixls_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, i4, n, nn;
  char *p;
  if (objc != 6)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int int int int");
    return TCL_ERROR;
  }

  p = Tcl_GetStringFromObj (objv[1], &nn);
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i4) != TCL_OK) return TCL_ERROR;
  n = i3 * i4;
  if (imgopt == 1) n = n * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }

  wpixls ((unsigned char *) p, i1, i2, i3, i4);
  return TCL_OK;
}

static int wpxrow_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, i3, n, nn;
  char *p;
  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "str int int int");
    return TCL_ERROR;
  }

  p = Tcl_GetStringFromObj (objv[1], &nn);
  if (Tcl_GetIntFromObj (interp, objv[2], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[4], &i3) != TCL_OK) return TCL_ERROR;
  n = i3;
  if (imgopt == 1) n = n * 3;
  if (nn < n)
  { tcl_warn ("not enough pixels in string!");
    return TCL_ERROR;
  }

  wpxrow ((unsigned char *) p, i1, i2, i3);
  return TCL_OK;
}

static int writfl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1, i2, n, nn;
  char *p;
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "int str int");
    return TCL_ERROR;
  }

  p = Tcl_GetStringFromObj (objv[2], &nn);
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[3], &i2) != TCL_OK) return TCL_ERROR;
  if (nn < i2)
  { tcl_warn ("not enough characters in string!");
    return TCL_ERROR;
  }

  n = writfl (i1, (unsigned char *) p, i2);
  Tcl_SetObjResult (interp, Tcl_NewIntObj (n));
  return TCL_OK;
}

static int wtiff_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  wtiff (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int x11fnt_tcl (ClientData cdata, Tcl_Interp *interp, 
                     int objc, Tcl_Obj *const objv[])
{ if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "str str");
    return TCL_ERROR;
  }
  x11fnt (Tcl_GetString (objv[1]), Tcl_GetString (objv[2]));
  return TCL_OK;
}

static int x11mod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  x11mod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int x2dpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, xret; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  xret = x2dpos (x1, x2);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int x3dabs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = x3dabs (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int x3dpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = x3dpos (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int x3drel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = x3drel (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int xaxgit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  xaxgit ();
  return TCL_OK;
}

static int xaxis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int str int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  xaxis (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4);
  return TCL_OK;
}

static int xaxlg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int str int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  xaxlg (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4);
  return TCL_OK;
}

static int xaxmap_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt str int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  xaxmap (x1, x2, x3, x4, Tcl_GetString (objv[5]), i1, i2);
  return TCL_OK;
}

static int xcross_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  xcross ();
  return TCL_OK;
}

static int xdraw_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  xdraw (x1, x2);
  return TCL_OK;
}

static int xinvrs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double xret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  xret = xinvrs (i1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int xmove_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  xmove (x1, x2);
  return TCL_OK;
}

static int xposn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, xret; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  xret = xposn (x1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int y2dpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, xret; 
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  xret = y2dpos (x1, x2);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int y3dabs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = y3dabs (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int y3dpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = y3dpos (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int y3drel_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = y3drel (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int yaxgit_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  yaxgit ();
  return TCL_OK;
}

static int yaxis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int str int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  yaxis (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4);
  return TCL_OK;
}

static int yaxlg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4;
  if (objc != 10)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt int str int int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  yaxlg (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4);
  return TCL_OK;
}

static int yaxmap_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2;
  if (objc != 8)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt str int int");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[6], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  yaxmap (x1, x2, x3, x4, Tcl_GetString (objv[5]), i1, i2);
  return TCL_OK;
}

static int ycross_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  ycross ();
  return TCL_OK;
}

static int yinvrs_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i1;
  double xret;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj (interp, objv[1], &i1) != TCL_OK) return TCL_ERROR;
  xret = yinvrs (i1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int yposn_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, xret; 
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  xret = yposn (x1);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int z3dpos_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, xret; 
  if (objc != 4)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt");
    return TCL_ERROR;
  }
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  xret = z3dpos (x1, x2, x3);
  Tcl_SetObjResult (interp, Tcl_NewDoubleObj (xret));
  return TCL_OK;
}

static int zaxis_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4, i5;
  if (objc != 11)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f i s i i i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &i5) != TCL_OK) return TCL_ERROR;
  zaxis (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4, i5);
  return TCL_OK;
}

static int zaxlg_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4;
  int i1, i2, i3, i4, i5;
  if (objc != 11)
  { Tcl_WrongNumArgs (interp, 1, objv, "f f f f i s i i i i");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[5], &i1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[7], &i2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[8], &i3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[9], &i4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetIntFromObj (interp, objv[10], &i5) != TCL_OK) return TCL_ERROR;
  zaxlg (x1, x2, x3, x4, i1, Tcl_GetString (objv[6]), i2, i3, i4, i5);
  return TCL_OK;
}

static int zbfers_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  zbfers ();
  return TCL_OK;
}

static int zbffin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  zbffin ();
  return TCL_OK;
}

static int zbfini_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int i;
  if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  i = zbfini ();
  Tcl_SetObjResult (interp, Tcl_NewIntObj (i));
  return TCL_OK;
}

static int zbflin_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2, x3, x4, x5, x6;
  if (objc != 7)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt flt flt flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[3], &x3) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[4], &x4) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[5], &x5) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[6], &x6) != TCL_OK) return TCL_ERROR;
  zbflin (x1, x2, x3, x4, x5, x6);
  return TCL_OK;
}

static int zbfmod_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "str");
    return TCL_ERROR;
  }
  zbfmod (Tcl_GetString (objv[1]));
  return TCL_OK;
}

static int zbfres_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ if (objc != 1)
  { Tcl_WrongNumArgs (interp, 1, objv, "");
    return TCL_ERROR;
  }
  zbfres ();
  return TCL_OK;
}

static int zbfscl_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1;
  if (objc != 2)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  zbfscl (x1);
  return TCL_OK;
}

static int zbftri_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ int n = 3, ierr = 0, *p4;
  double *p1, *p2, *p3;

  if (objc != 5)
  { Tcl_WrongNumArgs (interp, 1, objv, "list list list list");
    return TCL_ERROR;
  }

  p1 = dbl_array (interp, objv[1], n);
  p2 = dbl_array (interp, objv[2], n);
  p3 = dbl_array (interp, objv[3], n);
  p4 = int_array (interp, objv[4], n);
  if (p1 != NULL && p2 != NULL && p3 != NULL && p4 != NULL) 
    zbftri (p1, p2, p3, p4);
  else
    ierr = 1;

  free (p1);
  free (p2);
  free (p3);
  free (p4);
  if (ierr == 1)
    return TCL_ERROR;
  else
    return TCL_OK;
}

static int zscale_tcl (ClientData cdata, Tcl_Interp *interp, 
                       int objc, Tcl_Obj *const objv[])
{ double x1, x2;
  if (objc != 3)
  { Tcl_WrongNumArgs (interp, 1, objv, "flt flt");
    return TCL_ERROR;
  }
  
  if (Tcl_GetDoubleFromObj (interp, objv[1], &x1) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj (interp, objv[2], &x2) != TCL_OK) return TCL_ERROR;
  zscale (x1, x2);
  return TCL_OK;
}

int DLLEXPORT Dislin_Init (Tcl_Interp *interp)
{
  if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL)
  { return TCL_ERROR;
  }
  Tcl_CreateObjCommand (interp, "Dislin::abs3pt", abs3pt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::addlab", addlab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::angle",  angle_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::arcell", arcell_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::areaf",  areaf_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::autres", autres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ax2grf", ax2grf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ax3len", ax3len_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axclrs", axclrs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axends", axends_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axgit",  axgit_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axis3d", axis3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axsbgd", axsbgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axslen", axsers_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axslen", axslen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axsorg", axsorg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axspos", axspos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axsscl", axsscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::axstyp", axstyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::barbor", barbor_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::barclr", barclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bargrp", bargrp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::barmod", barmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::baropt", baropt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::barpos", barpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bars",   bars_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bars3d", bars3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bartyp", bartyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::barwth", barwth_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::basalf", basalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::basdat", basdat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bezier", bezier_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bitsi4", bitsi4_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bmpfnt", bmpfnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bmpmod", bmpmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::box2d",  box2d_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::box3d",  box3d_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::bufmod", bufmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::center", center_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cgmbgd", cgmbgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cgmpic", cgmpic_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cgmver", cgmver_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chaang", chaang_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chacod", chacod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chaspc", chaspc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chawth", chawth_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chnatt", chnatt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chncrv", chncrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chndot", chndot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chndsh", chndsh_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chnbar", chnbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::chnpie", chnpie_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::circ3p", circ3p_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::circle", circle_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::circsp", circsp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clip3d", clip3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::closfl", closfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clpbor", clpbor_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clpmod", clpmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clpwin", clpwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clrcyc", clrcyc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clrmod", clrmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::clswin", clswin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::color",  color_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::colran", colran_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::colray", colray_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::complx", complx_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conclr", conclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::concrv", concrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cone3d", cone3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::confll", confll_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::congap", congap_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conlab", conlab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conmat", conmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conmod", conmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conn3d", conn3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::connpt", connpt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conpts", conpts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conshd", conshd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conshd2", conshd2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::conshd3d", conshd3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::contri", contri_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::contur", contur_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::contur2", contur2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cross",  cross_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::crvmat", crvmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::crvqdr", crvqdr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::crvt3d", crvt3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::crvtri", crvtri_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrkey", csrkey_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrlin", csrlin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrmod", csrmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrpos", csrpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrpt1", csrpt1_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrpol", csrpol_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrpts", csrpts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrmov", csrmov_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrrec", csrrec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csrtyp", csrtyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::csruni", csruni_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curv3d", curv3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curv4d", curv4d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curve",  curve_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curve3", curve3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curvmp", curvmp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curvx3", curvx3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::curvy3", curvy3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::cyli3d", cyli3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dash",   dash_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dashl",  dashl_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dashm",  dashm_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dbffin", dbffin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dbfini", dbfini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dbfmod", dbfmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::delglb", delglb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::digits", digits_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::disalf", disalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::disenv", disenv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::disfin", disfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::disini", disini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::disk3d", disk3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::doevnt", doevnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dot",    dot_tcl,    NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dotl",   dotl_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::duplx",  duplx_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dwgbut", dwgbut_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dwgerr", dwgerr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*dwgfil", *dwgfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dwglis", dwglis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::dwgmsg", dwgmsg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*dwgtxt", *dwgtxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ellips", ellips_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::endgrf", endgrf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::erase",  erase_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::errbar", errbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::errdev", errdev_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::errfil", errfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::errmod", errmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::eushft", eushft_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::expimg", expimg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::expzlb", expzlb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::fbars",  fbars_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::fcha",   fcha_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::field",  field_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::field3d", field3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filbox", filbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filclr", filclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filmod", filmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filopt", filopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filsiz", filsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filtyp", filtyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::filwin", filwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::fixspc", fixspc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::flab3d", flab3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::flen", flen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::frame", frame_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::frmbar", frmbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::frmclr", frmclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::frmess", frmess_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gapcrv", gapcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gapsiz", gapsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gaxpar", gaxpar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getalf", *getalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getang", getang_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getbpp", getbpp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getclp", getclp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getclr", getclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getdig", getdig_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getdsp", *getdsp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getfil", *getfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getgrf", getgrf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gethgt", gethgt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gethnm", gethnm_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getico", getico_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getind", getind_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getlab", getlab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getlen", getlen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getlev", getlev_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getlin", getlin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getlit", getlit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getmat", getmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getmfl", *getmfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getmix", *getmix_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getor", getor_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getpag", getpag_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getpat", getpat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getplv", getplv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getpos", getpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getran", getran_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getrco", getrco_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getres", getres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getrgb", getrgb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getscl", getscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getscm", getscm_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getscr", getscr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getshf", *getshf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getsp1", getsp1_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getsp2", getsp2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getsym", getsym_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gettcl", gettcl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gettic", gettic_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gettyp", gettyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getuni", *getuni_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getver", getver_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getvk",  getvk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*getvlt", *getvlt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getwid", getwid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getwin", getwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::getxid", getxid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gifmod", gifmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gmxalf", gmxalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gothic", gothic_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grace",  grace_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::graf",   graf_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::graf3",  graf3_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::graf3d", graf3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grafmp", grafmp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grafp",  grafp_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grafr",  grafr_tcl,  NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grdpol", grdpol_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grffin", grffin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grfimg", grfimg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grfini", grfini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grid",   grid_tcl,   NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::grid3d", grid3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gridim", gridim_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gridmp", gridmp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gridre", gridre_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgatt", gwgatt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgbox", gwgbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgbut", gwgbut_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgfil", gwgfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgflt", gwgflt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwggui", gwggui_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgint", gwgint_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwglis", gwglis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgscl", gwgscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgsiz", gwgsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgtbf", gwgtbf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgtbi", gwgtbi_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgtbl", gwgtbl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgtbs", gwgtbs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgtxt", gwgtxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::gwgxid", gwgxid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::height", height_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::helve",  helve_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::helves", helves_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::helvet", helvet_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hidwin", hidwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::histog", histog_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hname", hname_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hpgmod", hpgmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hsvrgb", hsvrgb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hsym3d", hsym3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hsymbl", hsymbl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::htitle", htitle_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hwfont", hwfont_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hwmode", hwmode_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hworig", hworig_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hwpage", hwpage_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::hwscal", hwscal_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgbox", imgbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgclp", imgclp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgfin", imgfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgfmt", imgfmt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgini", imgini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgmod", imgmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgsiz", imgsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::imgtpr", imgtpr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::inccrv", inccrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::incdat", incdat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::incfil", incfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::incmrk", incmrk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::indrgb", indrgb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::intax", intax_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::intcha", intcha_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::intlen", intlen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::intrgb", intrgb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::intutf", intutf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::isopts", isopts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::itmcat", itmcat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::itmncat", itmncat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::itmcnt", itmcnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::*itmstr", *itmstr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::jusbar", jusbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labclr", labclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labdig", labdig_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labdis", labdis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labels", labels_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labjus", labjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labl3d", labl3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labmod", labmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labpos", labpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::labtyp", labtyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legbgd", legbgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legclr", legclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legend", legend_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legini", legini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::leglin", leglin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legopt", legopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legpat", legpat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legpos", legpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legsel", legsel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legtit", legtit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legtyp", legtyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::legval", legval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lfttit", lfttit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::licmod", licmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::licpts", licpts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::light", light_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::linclr", linclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lincyc", lincyc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::line", line_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::linesp", linesp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::linfit", linfit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::linmod", linmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lintyp", lintyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::linwid", linwid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::litmod", litmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::litop3", litop3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::litopt", litopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::litpos", litpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lncap", lncap_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lnjoin", lnjoin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::lnmlt", lnmlt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::logtic", logtic_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapbas", mapbas_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapfil", mapfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapimg", mapimg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::maplab", maplab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::maplev", maplev_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapmod", mapmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mappol", mappol_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapopt", mapopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapref", mapref_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mapsph", mapsph_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::marker", marker_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::matop3", matop3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::matopt", matopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mdfmat", mdfmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::messag", messag_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::metafl", metafl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mixalf", mixalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mixleg", mixleg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mpaepl", mpaepl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mplang", mplang_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mplclr", mplclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mplpos", mplpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mplsiz", mplsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mpslogo", mpslogo_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mrkclr", mrkclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::msgbox", msgbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mshclr", mshclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mshcrv", mshcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mylab", mylab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::myline", myline_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mypat", mypat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::mysymb", mysymb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::myvlt", myvlt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::namdis", namdis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::name", name_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::namjus", namjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::neglog", neglog_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::newmix", newmix_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::newpag", newpag_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nlmess", nlmess_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nlnumb", nlnumb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::noarln", noarln_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nobar", nobar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nobgd", nobgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nochek", nochek_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::noclip", noclip_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nofill", nofill_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nograf", nograf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nohide", nohide_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::noline", noline_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::number", number_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::numfmt", numfmt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::numode", numode_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nwkday", nwkday_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nxlegn", nxlegn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nxpixl", nxpixl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nxposn", nxposn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nylegn", nylegn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nypixl", nypixl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nyposn", nyposn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::nzposn", nzposn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::openfl", openfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::opnwin", opnwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::origin", origin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::page", page_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pagera", pagera_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pagfll", pagfll_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::paghdr", paghdr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pagmod", pagmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pagorg", pagorg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pagwin", pagwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::patcyc", patcyc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pdfbuf", pdfbuf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pdfmod", pdfmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pdfmrk", pdfmrk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::penwid", penwid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pie", pie_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::piebor", piebor_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::piecbk", piecbk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pieclr", pieclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pieexp", pieexp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::piegrf", piegrf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pielab", pielab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pieopt", pieopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pierot", pierot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pietyp", pietyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pieval", pieval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pievec", pievec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pike3d", pike3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::plat3d", plat3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::plyfin", plyfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::plyini", plyini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pngmod", pngmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::point", point_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::polar", polar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::polcrv", polcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::polclp", polclp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::polmod", polmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pos2pt", pos2pt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pos3pt", pos3pt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::posbar", posbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::posifl", posifl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::proj3d", proj3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::projct", projct_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::psfont", psfont_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::psmode", psmode_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pt2pos", pt2pos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::pyra3d", pyra3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplbar", qplbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplclr", qplclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplcon", qplcon_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplcrv", qplcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplot", qplot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplpie", qplpie_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplsca", qplsca_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplscl", qplscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::qplsur", qplsur_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::quad3d", quad3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rbfpng", rbfpng_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rbmp", rbmp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::readfl", readfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::reawgt", reawgt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::recfll", recfll_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rectan", rectan_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rel3pt", rel3pt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::resatt", resatt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::reset", reset_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::revscr", revscr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rgbhsv", rgbhsv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rgif", rgif_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rgtlab", rgtlab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rimage", rimage_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlarc", rlarc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlarea", rlarea_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlcirc", rlcirc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlconn", rlconn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlell", rlell_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rline", rline_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlmess", rlmess_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlnumb", rlnumb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlpie", rlpie_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlpoin", rlpoin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlrec", rlrec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlrnd", rlrnd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlsec", rlsec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlstrt", rlstrt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlsymb", rlsymb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlvec", rlvec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rlwind", rlwind_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rndrec", rndrec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rot3d", rot3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rpixel", rpixel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rpixls", rpixls_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rpng", rpng_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rppm", rppm_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rpxrow", rpxrow_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rtiff", rtiff_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::rvynam", rvynam_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::scale", scale_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sclfac", sclfac_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sclmod", sclmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::scrmod", scrmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sector", sector_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::selwin", selwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sendbf", sendbf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sendmb", sendmb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sendok", sendok_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::serif", serif_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setbas", setbas_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setcbk", setcbk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setclr", setclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setcsr", setcsr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setexp", setexp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setfce", setfce_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setfil", setfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setgrf", setgrf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setind", setind_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setmix", setmix_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setpag", setpag_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setres", setres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setrgb", setrgb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setscl", setscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setvlt", setvlt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::setxid", setxid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdafr", shdafr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdasi", shdasi_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdaus", shdaus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdcha", shdcha_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdcrv", shdcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdeur", shdeur_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdfac", shdfac_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdmap", shdmap_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdmod", shdmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdnor", shdnor_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdpat", shdpat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdsou", shdsou_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shdusa", shdusa_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shield", shield_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlcir", shlcir_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shldel", shldel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlell", shlell_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlind", shlind_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlpie", shlpie_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlpol", shlpol_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlrct", shlrct_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlrec", shlrec_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlres", shlres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlsur", shlsur_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::shlvis", shlvis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::simplx", simplx_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::skipfl", skipfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::smxalf", smxalf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::solid", solid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sortr1", sortr1_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sortr2", sortr2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::spcbar", spcbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sphe3d", sphe3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::spline", spline_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::splmod", splmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmmod", stmmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmopt", stmopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmpts", stmpts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmpts3d", stmpts3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmtri", stmtri_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stmval", stmval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stream", stream_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::stream3d", stream3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::strt3d", strt3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::strtpt", strtpt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surclr", surclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surfce", surfce_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surfcp", surfcp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surfun", surfun_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::suriso", suriso_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surmat", surmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surmsh", surmsh_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::suropt", suropt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surshc", surshc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surshd", surshd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::sursze", sursze_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::surtri", surtri_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::survis", survis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swapi4", swapi4_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgatt", swgatt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgbgd", swgbgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgbox", swgbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgbut", swgbut_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgcb2", swgcb2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgcbk", swgcbk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgclr", swgclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgdrw", swgdrw_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgfgd", swgfgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgfil", swgfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgflt", swgflt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgfnt", swgfnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgfoc", swgfoc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swghlp", swghlp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgint", swgint_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgiop", swgiop_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgjus", swgjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swglis", swglis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgmix", swgmix_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgmrg", swgmrg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgoff", swgoff_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgopt", swgopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgpop", swgpop_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgpos", swgpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgray", swgray_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgscl", swgscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgsiz", swgsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgspc", swgspc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgstp", swgstp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtbf", swgtbf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtbi", swgtbi_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtbl", swgtbl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtbs", swgtbs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtit", swgtit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtxt", swgtxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgtyp", swgtyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgval", swgval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgwin", swgwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::swgwth", swgwth_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::symb3d", symb3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::symbol", symbol_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::symfil", symfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::symrot", symrot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tellfl", tellfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::texmod", texmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::texopt", texopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::texval", texval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::thkc3d", thkc3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::thkcrv", thkcrv_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::thrfin", thrfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::thrini", thrini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ticks", ticks_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ticlen", ticlen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ticmod", ticmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ticpos", ticpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tifmod", tifmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tiforg", tiforg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tifwin", tifwin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::timopt", timopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::titjus", titjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::title", title_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::titlin", titlin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::titpos", titpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::torus3d", torus3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tprfin", tprfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tprini", tprini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tprmod", tprmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tprval", tprval_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tr3axs", tr3axs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tr3res", tr3res_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tr3rot", tr3rot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tr3scl", tr3scl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tr3shf", tr3shf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfco1", trfco1_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfco2", trfco2_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfco3", trfco3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfdat", trfdat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfmat", trfmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfrel", trfrel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfres", trfres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfrot", trfrot_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfscl", trfscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trfshf", trfshf_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tria3d", tria3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::triang", triang_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::triflc", triflc_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trifll", trifll_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::triplx", triplx_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tripts", tripts_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::trmlen", trmlen_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ttfont", ttfont_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::tube3d", tube3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::txtbgd", txtbgd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::txtjus", txtjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::txture", txture_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::unit", unit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::units", units_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::upstr", upstr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::utfint", utfint_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vang3d", vang3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vclp3d", vclp3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecclr", vecclr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecf3d", vecf3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecfld", vecfld_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecmat", vecmat_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecmat3d", vecmat3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vecopt", vecopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vector", vector_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vectr3", vectr3_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vfoc3d", vfoc3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::view3d", view3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vkxbar", vkxbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vkybar", vkybar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vkytit", vkytit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vltfil", vltfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vscl3d", vscl3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vtx3d", vtx3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vtxc3d", vtxc3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vtxn3d", vtxn3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::vup3d", vup3d_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgapp", wgapp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgappb", wgappb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgbas", wgbas_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgbox", wgbox_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgbut", wgbut_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgcmd", wgcmd_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgdlis", wgdlis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgdraw", wgdraw_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgfil", wgfil_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgfin", wgfin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgicon", wgicon_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgini", wgini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wglab", wglab_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wglis", wglis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgltxt", wgltxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgok", wgok_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgpbar", wgpbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgpbut", wgpbut_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgpicon", wgpicon_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgpop", wgpop_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgpopb", wgpopb_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgquit", wgquit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgscl", wgscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgsep", wgsep_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgstxt", wgstxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgtbl", wgtbl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wgtxt", wgtxt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::widbar", widbar_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wimage", wimage_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winapp", winapp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wincbk", wincbk_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::windbr", windbr_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::window", window_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winfnt", winfnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winico", winico_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winid",  winid_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winjus", winjus_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winkey", winkey_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winmod", winmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winopt", winopt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::winsiz", winsiz_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wintit", wintit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wintyp", wintyp_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wmfmod", wmfmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::world", world_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wpixel", wpixel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wpixls", wpixls_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wpxrow", wpxrow_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::writfl", writfl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::wtiff", wtiff_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x11fnt", x11fnt_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x11mod", x11mod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x2dpos", x2dpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x3dabs", x3dabs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x3dpos", x3dpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::x3drel", x3drel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xaxgit", xaxgit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xaxis", xaxis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xaxlg", xaxlg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xaxmap", xaxmap_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xcross", xcross_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xdraw", xdraw_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xinvrs", xinvrs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xmove", xmove_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::xposn", xposn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::y2dpos", y2dpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::y3dabs", y3dabs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::y3dpos", y3dpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::y3drel", y3drel_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yaxgit", yaxgit_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yaxis", yaxis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yaxlg", yaxlg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yaxmap", yaxmap_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::ycross", ycross_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yinvrs", yinvrs_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::yposn", yposn_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::z3dpos", z3dpos_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zaxis", zaxis_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zaxlg", zaxlg_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbfers", zbfers_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbffin", zbffin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbfini", zbfini_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbflin", zbflin_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbfmod", zbfmod_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbfres", zbfres_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbfscl", zbfscl_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zbftri", zbftri_tcl, NULL, NULL);
  Tcl_CreateObjCommand (interp, "Dislin::zscale", zscale_tcl, NULL, NULL);

  return TCL_OK;
}


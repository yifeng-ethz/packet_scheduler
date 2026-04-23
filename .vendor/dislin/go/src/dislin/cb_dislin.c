#include <stdio.h>

extern void   cb_swgcbk_go (int id);
extern void   cb_swgcb2_go (int id, int irow, int icol);
extern void   cb_swgcb3_go (int id, int ival);
extern double cb_surfun_go (double x, double y);
extern double cb_surfcp_go (double x, double y, int iopt);
extern void   cb_wincbk_go (int id, int nx, int ny, int nw, int nh);
extern void   cb_setcbk_go (double *x, double *y);
extern void   cb_piecbk_go (int iseg, double xdat, double xper, int *nrad,
                            int *noff, double *angle, int *nvx, int *nvy,
                            int *idrw, int *iann);

void cb_swgcbk (int id)
{
  cb_swgcbk_go (id);
}

void cb_swgcb2 (int id, int irow, int icol)
{
  cb_swgcb2_go (id, irow, icol);
}

void cb_swgcb3 (int id, int ival)
{
  cb_swgcb3_go (id, ival);
}

double cb_surfun (double x, double y)
{
  return cb_surfun_go (x, y);
}

double cb_surfcp (double x, double y, int iopt)
{
  return cb_surfcp_go (x, y, iopt);
}

void cb_wincbk (int iwin, int nx, int ny, int nw, int nh)
{
  cb_wincbk_go (iwin, nx, ny, nw, nh);
}

void cb_setcbk (double *x, double *y)
{
  cb_setcbk_go (x, y);
}

void cb_piecbk (int iseg, double xdat, double xper, int *nrad, 
                int *noff, double *angle, int *nvx, int *nvy, int *idrw,
                int *iann)
{
  cb_piecbk_go (iseg, xdat, xper, nrad, noff, angle, nvx, nvy, idrw, iann);
}

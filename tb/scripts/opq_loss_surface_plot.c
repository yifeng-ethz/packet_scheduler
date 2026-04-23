#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
  float zmin;
  float zmax;
} opq_loss_grid_t;

static void trim_ascii(char *text) {
  size_t start = 0;
  size_t end = strlen(text);

  while (start < end && isspace((unsigned char) text[start])) {
    start++;
  }
  while (end > start && isspace((unsigned char) text[end - 1])) {
    end--;
  }
  if (start != 0) {
    memmove(text, text + start, end - start);
  }
  text[end - start] = '\0';
}

static int read_grid(const char *path, opq_loss_grid_t *grid) {
  FILE *handle = fopen(path, "r");
  int ix;
  int iy;

  if (handle == NULL) {
    fprintf(stderr, "Failed to open grid file %s\n", path);
    return 0;
  }

  if (fscanf(handle, "%d %d", &grid->nx, &grid->ny) != 2 ||
      grid->nx < 2 || grid->ny < 2) {
    fprintf(stderr, "Invalid grid header in %s\n", path);
    fclose(handle);
    return 0;
  }

  grid->x = (float *) calloc((size_t) grid->nx, sizeof(float));
  grid->y = (float *) calloc((size_t) grid->ny, sizeof(float));
  grid->z = (float *) calloc((size_t) grid->nx * (size_t) grid->ny, sizeof(float));
  if (grid->x == NULL || grid->y == NULL || grid->z == NULL) {
    fprintf(stderr, "Out of memory while allocating contour grid\n");
    fclose(handle);
    return 0;
  }

  for (ix = 0; ix < grid->nx; ix++) {
    if (fscanf(handle, "%f", &grid->x[ix]) != 1) {
      fprintf(stderr, "Failed to read x-axis value %d from %s\n", ix, path);
      fclose(handle);
      return 0;
    }
  }
  for (iy = 0; iy < grid->ny; iy++) {
    if (fscanf(handle, "%f", &grid->y[iy]) != 1) {
      fprintf(stderr, "Failed to read y-axis value %d from %s\n", iy, path);
      fclose(handle);
      return 0;
    }
  }

  grid->zmin = 0.0f;
  grid->zmax = 0.0f;
  for (ix = 0; ix < grid->nx; ix++) {
    for (iy = 0; iy < grid->ny; iy++) {
      float value;
      size_t offset = (size_t) ix * (size_t) grid->ny + (size_t) iy;

      if (fscanf(handle, "%f", &value) != 1) {
        fprintf(stderr, "Failed to read z-matrix value (%d, %d) from %s\n", ix, iy, path);
        fclose(handle);
        return 0;
      }
      grid->z[offset] = value;
      if (ix == 0 && iy == 0) {
        grid->zmin = value;
        grid->zmax = value;
      } else {
        if (value < grid->zmin) {
          grid->zmin = value;
        }
        if (value > grid->zmax) {
          grid->zmax = value;
        }
      }
    }
  }

  fclose(handle);
  return 1;
}

static void free_grid(opq_loss_grid_t *grid) {
  free(grid->x);
  free(grid->y);
  free(grid->z);
  grid->x = NULL;
  grid->y = NULL;
  grid->z = NULL;
}

static double nice_step(double span, int target_ticks) {
  double rough;
  double power_of_ten;
  double normalized;

  if (span <= 0.0) {
    return 1.0;
  }
  rough = span / (double) target_ticks;
  power_of_ten = pow(10.0, floor(log10(rough)));
  normalized = rough / power_of_ten;

  if (normalized <= 1.0) {
    return power_of_ten;
  }
  if (normalized <= 2.0) {
    return 2.0 * power_of_ten;
  }
  if (normalized <= 5.0) {
    return 5.0 * power_of_ten;
  }
  return 10.0 * power_of_ten;
}

static double align_up(double value, double step) {
  return ceil(value / step) * step;
}

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "PNG";
  }
  dot++;
  if (strcasecmp(dot, "svg") == 0) {
    return "SVG";
  }
  if (strcasecmp(dot, "pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static void render_plot(const opq_loss_grid_t *grid, const char *output_path) {
  int level_count = 12;
  float levels[12];
  float xmin = grid->x[0];
  float xmax = grid->x[grid->nx - 1];
  float ymin = grid->y[0];
  float ymax = grid->y[grid->ny - 1];
  float xpad = (float) fmax(0.10, (xmax - xmin) * 0.08);
  float ypad = (float) fmax(0.01, (ymax - ymin) * 0.10);
  float gxmin = xmin - xpad;
  float gxmax = xmax + xpad;
  float gymin = ymin - ypad;
  float gymax = ymax + ypad;
  float zmin = fminf(0.0f, grid->zmin);
  float zmax = grid->zmax;
  float zspan = zmax - zmin;
  double xstep = nice_step((double) (gxmax - gxmin), 8);
  double ystep = nice_step((double) (gymax - gymin), 7);
  double zstep = nice_step((double) fmaxf(zspan, 0.001f), 6);
  double xorigin = align_up(gxmin, xstep);
  double yorigin = align_up(gymin, ystep);
  double zorigin = align_up(zmin, zstep);
  int level_idx;

  if (zspan <= 0.0f) {
    zmax = zmin + 1.0e-3f;
    zspan = zmax - zmin;
  }
  for (level_idx = 0; level_idx < level_count; level_idx++) {
    levels[level_idx] = zmin + ((float) (level_idx + 1) * zspan / (float) level_count);
  }

  metafl(output_format_from_path(output_path));
  setfil(output_path);
  filmod("delete");
  setpag("da4l");
  scrmod("reverse");
  disini();
  pagera();
  complx();
  setvlt("temp");

  titlin("OPQ-Inspired Loss Surface", 1);
  titlin("x: B=(SCV-1)/(SCV+1),  y: offered rate / lane rho", 3);
  titlin("B=-1 periodic, B=0 Poisson, B=+1 bursty", 4);

  name("burstiness B", "x");
  name("rate / lane rho", "y");

  intax();
  labdig(2, "xy");
  labdig(3, "z");
  axspos(420, 1750);
  axslen(1950, 1100);
  graf(gxmin, gxmax, (float) xorigin, (float) xstep,
       gymin, gymax, (float) yorigin, (float) ystep);

  shdmod("poly", "contur");
  zscale(zmin, zmax);
  conshd(grid->x, grid->nx, grid->y, grid->ny, grid->z, levels, level_count);

  setrgb(0.20f, 0.20f, 0.20f);
  labels("none", "contur");
  for (level_idx = 1; level_idx < level_count; level_idx += 2) {
    contur(grid->x, grid->nx, grid->y, grid->ny, grid->z, levels[level_idx]);
  }

  color("fore");
  height(32);
  zaxis(zmin, zmax, (float) zorigin, (float) zstep, 1100, "loss probability", 1, 0, 2550, 1750);

  height(50);
  title();
  disfin();
}

int main(int argc, char **argv) {
  opq_loss_grid_t grid;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <loss_surface_grid.dat> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }

  memset(&grid, 0, sizeof(grid));
  if (!read_grid(argv[1], &grid)) {
    free_grid(&grid);
    return 1;
  }

  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_grid(&grid);
    return 1;
  }

  render_plot(&grid, output_path);
  free_grid(&grid);
  return 0;
}

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define LEVEL_COUNT 3
#define MAX_CONTOUR_POINTS 262144
#define MAX_CONTOUR_CURVES 8192

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
} loss_grid_t;

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

static int read_grid(const char *path, loss_grid_t *grid) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open grid %s\n", path);
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
    fprintf(stderr, "Out of memory while reading grid %s\n", path);
    fclose(handle);
    return 0;
  }

  for (int ix = 0; ix < grid->nx; ix++) {
    if (fscanf(handle, "%f", &grid->x[ix]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int iy = 0; iy < grid->ny; iy++) {
    if (fscanf(handle, "%f", &grid->y[iy]) != 1) {
      fclose(handle);
      return 0;
    }
    grid->y[iy] *= 100.0f;
  }
  for (int ix = 0; ix < grid->nx; ix++) {
    for (int iy = 0; iy < grid->ny; iy++) {
      float value;
      if (fscanf(handle, "%f", &value) != 1) {
        fclose(handle);
        return 0;
      }
      if (value < 1.0e-6f) {
        value = 1.0e-6f;
      }
      if (value > 1.0f) {
        value = 1.0f;
      }
      grid->z[(size_t) ix * (size_t) grid->ny + (size_t) iy] = log10f(value);
    }
  }

  fclose(handle);
  return 1;
}

static void free_grid(loss_grid_t *grid) {
  free(grid->x);
  free(grid->y);
  free(grid->z);
  grid->x = NULL;
  grid->y = NULL;
  grid->z = NULL;
}

static void set_impl_color(int impl_idx) {
  if (impl_idx == 0) {
    setrgb(0.10f, 0.30f, 0.78f);
  } else {
    setrgb(0.82f, 0.20f, 0.10f);
  }
}

static void set_level_style(int level_idx) {
  if (level_idx == 0) {
    dotl();
  } else if (level_idx == 1) {
    dashm();
  } else {
    solid();
  }
}

static void draw_single_contour(const loss_grid_t *grid, float level, int impl_idx, int level_idx) {
  float *xpts = (float *) calloc(MAX_CONTOUR_POINTS, sizeof(float));
  float *ypts = (float *) calloc(MAX_CONTOUR_POINTS, sizeof(float));
  int *nray = (int *) calloc(MAX_CONTOUR_CURVES, sizeof(int));
  int curve_count = 0;
  int offset = 0;

  if (xpts == NULL || ypts == NULL || nray == NULL) {
    free(xpts);
    free(ypts);
    free(nray);
    return;
  }

  conpts(grid->x, grid->nx, grid->y, grid->ny, grid->z, log10f(level),
         xpts, ypts, MAX_CONTOUR_POINTS, nray, MAX_CONTOUR_CURVES, &curve_count);

  set_impl_color(impl_idx);
  set_level_style(level_idx);
  linwid(7);
  for (int curve_idx = 0; curve_idx < curve_count; curve_idx++) {
    if (nray[curve_idx] >= 2) {
      curve(xpts + offset, ypts + offset, nray[curve_idx]);
    }
    offset += nray[curve_idx];
  }
  solid();
  linwid(1);

  free(xpts);
  free(ypts);
  free(nray);
}

static void draw_grid(float xmin, float xmax, float ymin, float ymax) {
  setrgb(0.80f, 0.80f, 0.80f);
  dotl();
  linwid(1);
  for (float x = -0.5f; x < xmax; x += 0.5f) {
    float xs[2] = {x, x};
    float ys[2] = {ymin, ymax};
    curve(xs, ys, 2);
  }
  for (float y = 5.0f; y < ymax; y += 5.0f) {
    float xs[2] = {xmin, xmax};
    float ys[2] = {y, y};
    curve(xs, ys, 2);
  }
  solid();
}

static void draw_legend(void) {
  float xs[2];
  float ys[2];

  simplx();
  height(18);
  color("fore");
  rlmess("implementation", -0.92f, 23.0f);
  linwid(7);
  xs[0] = -0.92f; xs[1] = -0.72f; ys[0] = 21.6f; ys[1] = 21.6f;
  set_impl_color(0); solid(); curve(xs, ys, 2);
  color("fore"); linwid(1); rlmess("OPQ", -0.66f, 22.1f);
  linwid(7);
  xs[0] = -0.92f; xs[1] = -0.72f; ys[0] = 20.3f; ys[1] = 20.3f;
  set_impl_color(1); solid(); curve(xs, ys, 2);
  color("fore"); linwid(1); rlmess("Time-Merger", -0.66f, 20.8f);

  height(18);
  rlmess("loss contour", 0.22f, 37.0f);
  linwid(7);
  xs[0] = 0.22f; xs[1] = 0.42f; ys[0] = 35.6f; ys[1] = 35.6f;
  color("fore"); dotl(); curve(xs, ys, 2);
  solid(); linwid(1); rlmess("1e-6", 0.48f, 36.1f);
  linwid(7);
  xs[0] = 0.22f; xs[1] = 0.42f; ys[0] = 34.3f; ys[1] = 34.3f;
  dashm(); curve(xs, ys, 2);
  solid(); linwid(1); rlmess("1 %", 0.48f, 34.8f);
  linwid(7);
  xs[0] = 0.22f; xs[1] = 0.42f; ys[0] = 33.0f; ys[1] = 33.0f;
  solid(); curve(xs, ys, 2);
  linwid(1); rlmess("5 %", 0.48f, 33.5f);
  complx();
}

static void render_plot(const loss_grid_t *opq_grid, const loss_grid_t *tm_grid, const char *output_path) {
  const float levels[LEVEL_COUNT] = {1.0e-6f, 1.0e-2f, 5.0e-2f};
  const char *output_format = output_format_from_path(output_path);
  float xmin = opq_grid->x[0];
  float xmax = opq_grid->x[opq_grid->nx - 1];
  float ymin = opq_grid->y[0];
  float ymax = opq_grid->y[opq_grid->ny - 1];

  metafl(output_format);
  setfil(output_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format, "PNG") == 0) {
    winsiz(2048, 1448);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();

  titlin("OPQ IP-Core vs Time-Merger Burst/Rate Loss Contour", 2);
  name("burstiness B", "x");
  name("rate / lane [%]", "y");
  intax();
  labdig(2, "x");
  labdig(0, "y");
  axspos(420, 1720);
  axslen(2050, 1100);
  graf(xmin, xmax, -1.0f, 0.5f, ymin, ymax, 5.0f, 5.0f);
  draw_grid(xmin, xmax, ymin, ymax);

  for (int level_idx = 0; level_idx < LEVEL_COUNT; level_idx++) {
    draw_single_contour(opq_grid, levels[level_idx], 0, level_idx);
    draw_single_contour(tm_grid, levels[level_idx], 1, level_idx);
  }

  draw_legend();
  height(44);
  title();
  color("fore");
  height(15);
  messag("x: B=(SCV-1)/(SCV+1), y: offered rate/lane; window zooms out to expose early time-merger loss", 420, 1918);
  messag("finite-buffer analytical proxy: OPQ capacity=255, Time-Merger tree capacity/service penalized", 420, 1960);
  disfin();
}

int main(int argc, char **argv) {
  loss_grid_t opq_grid;
  loss_grid_t tm_grid;
  char output_path[4096];

  if (argc != 4) {
    fprintf(stderr, "Usage: %s <opq.dat> <time_merger.dat> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }

  memset(&opq_grid, 0, sizeof(opq_grid));
  memset(&tm_grid, 0, sizeof(tm_grid));
  if (!read_grid(argv[1], &opq_grid) || !read_grid(argv[2], &tm_grid)) {
    free_grid(&opq_grid);
    free_grid(&tm_grid);
    return 1;
  }

  snprintf(output_path, sizeof(output_path), "%s", argv[3]);
  trim_ascii(output_path);
  render_plot(&opq_grid, &tm_grid, output_path);
  free_grid(&opq_grid);
  free_grid(&tm_grid);
  return 0;
}

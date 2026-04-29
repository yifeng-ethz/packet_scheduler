#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define RATIO_MAX_LOG 6.0f
#define RATIO_MIN_LOG 0.0f
#define MAX_CONTOUR_POINTS 262144
#define MAX_CONTOUR_CURVES 8192

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
} ratio_grid_t;

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

static int read_grid(const char *path, ratio_grid_t *grid) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open ratio grid %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d %d", &grid->nx, &grid->ny) != 2 ||
      grid->nx < 2 || grid->ny < 2) {
    fprintf(stderr, "Invalid ratio grid header in %s\n", path);
    fclose(handle);
    return 0;
  }

  grid->x = (float *) calloc((size_t) grid->nx, sizeof(float));
  grid->y = (float *) calloc((size_t) grid->ny, sizeof(float));
  grid->z = (float *) calloc((size_t) grid->nx * (size_t) grid->ny, sizeof(float));
  if (grid->x == NULL || grid->y == NULL || grid->z == NULL) {
    fprintf(stderr, "Out of memory while reading %s\n", path);
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
      if (value < 1.0f) {
        value = 1.0f;
      }
      if (value > 1.0e6f) {
        value = 1.0e6f;
      }
      grid->z[(size_t) ix * (size_t) grid->ny + (size_t) iy] = log10f(value);
    }
  }

  fclose(handle);
  return 1;
}

static void free_grid(ratio_grid_t *grid) {
  free(grid->x);
  free(grid->y);
  free(grid->z);
  grid->x = NULL;
  grid->y = NULL;
  grid->z = NULL;
}

static float clamp_unit(float value) {
  if (value < 0.0f) {
    return 0.0f;
  }
  if (value > 1.0f) {
    return 1.0f;
  }
  return value;
}

static void init_ratio_palette(void) {
  float red[256];
  float green[256];
  float blue[256];

  for (int idx = 0; idx < 256; idx++) {
    float t = (float) idx / 255.0f;

    if (idx == 0) {
      red[idx] = 1.0f;
      green[idx] = 1.0f;
      blue[idx] = 1.0f;
    } else {
      red[idx] = 1.00f - 0.96f * t;
      green[idx] = 0.98f - 0.94f * t;
      blue[idx] = 0.70f - 0.54f * t;
    }
  }
  myvlt(red, green, blue, 256);
}

static int ratio_color_index(float log_ratio) {
  float t = clamp_unit((log_ratio - RATIO_MIN_LOG) / (RATIO_MAX_LOG - RATIO_MIN_LOG));

  return 1 + (int) floorf((253.0f * t) + 0.5f);
}

static void draw_ratio_cells(const ratio_grid_t *grid) {
  for (int ix = 0; ix < grid->nx - 1; ix++) {
    float x0 = xposn(grid->x[ix]);
    float x1 = xposn(grid->x[ix + 1]);
    int nx0 = (int) floorf(fminf(x0, x1));
    int nx1 = (int) ceilf(fmaxf(x0, x1));

    for (int iy = 0; iy < grid->ny - 1; iy++) {
      float y0 = yposn(grid->y[iy]);
      float y1 = yposn(grid->y[iy + 1]);
      int ny0 = (int) floorf(fminf(y0, y1));
      int ny1 = (int) ceilf(fmaxf(y0, y1));
      float z00 = grid->z[(size_t) ix * (size_t) grid->ny + (size_t) iy];
      float z10 = grid->z[(size_t) (ix + 1) * (size_t) grid->ny + (size_t) iy];
      float z01 = grid->z[(size_t) ix * (size_t) grid->ny + (size_t) (iy + 1)];
      float z11 = grid->z[(size_t) (ix + 1) * (size_t) grid->ny + (size_t) (iy + 1)];
      float zmean = 0.25f * (z00 + z10 + z01 + z11);

      recfll(nx0, ny0, nx1 - nx0 + 1, ny1 - ny0 + 1, ratio_color_index(zmean));
    }
  }
}

static void draw_ratio_contour(const ratio_grid_t *grid, float level_log, int style_index) {
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

  conpts(grid->x, grid->nx, grid->y, grid->ny, grid->z, level_log,
         xpts, ypts, MAX_CONTOUR_POINTS, nray, MAX_CONTOUR_CURVES, &curve_count);

  setrgb(0.98f, 0.98f, 0.90f);
  linwid(7);
  if (style_index == 0) {
    dashm();
  } else {
    solid();
  }
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

static void draw_ratio_legend(float xmin, float ymax) {
  float xs[2];
  float ys[2];
  float x0 = xmin + 0.05f;
  float x1 = x0 + 0.16f;
  float text_x = x1 + 0.05f;
  float y0 = ymax - 4.0f;

  color("fore");
  simplx();
  height(17);
  rlmess("ratio contour", x0, y0 + 2.0f);
  linwid(7);
  xs[0] = x0; xs[1] = x1; ys[0] = y0; ys[1] = y0;
  setrgb(0.98f, 0.98f, 0.90f); dashm(); curve(xs, ys, 2);
  solid(); linwid(1); color("fore"); rlmess("1e3x", text_x, y0 + 0.6f);
  linwid(7);
  xs[0] = x0; xs[1] = x1; ys[0] = y0 - 2.8f; ys[1] = y0 - 2.8f;
  setrgb(0.98f, 0.98f, 0.90f); solid(); curve(xs, ys, 2);
  linwid(1); color("fore"); rlmess("1e6x", text_x, y0 - 2.2f);
  complx();
}

static void render_plot(const ratio_grid_t *ratio_grid, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  const char *plot_title = getenv("OPQ_RATIO_TITLE");
  const char *plot_note = getenv("OPQ_RATIO_NOTE");
  float xmin = ratio_grid->x[0];
  float xmax = ratio_grid->x[ratio_grid->nx - 1];
  float ymin = ratio_grid->y[0];
  float ymax = ratio_grid->y[ratio_grid->ny - 1];
  float xpad = 0.015f * fmaxf(fabsf(xmax - xmin), 1.0e-6f);
  float ypad = 0.015f * fmaxf(fabsf(ymax - ymin), 1.0e-6f);
  float gxmin = xmin - xpad;
  float gxmax = xmax + xpad;
  float gymin = fmaxf(0.0f, ymin - ypad);
  float gymax = ymax + ypad;
  const int zaxis_x = 2480;
  const int zaxis_y = 1750;
  const int zaxis_len = 1100;
  const int ztick_label_x = zaxis_x - 24;
  const int ztitle_x = zaxis_x + 146;

  metafl(output_format);
  setfil(output_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format, "PNG") == 0) {
    winsiz(4096, 2896);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  init_ratio_palette();

  if (plot_title == NULL || plot_title[0] == '\0') {
    plot_title = "OPQ vs Time-Merger Ready/Burst Loss Ratio";
  }
  titlin(plot_title, 2);
  name("burstiness B", "x");
  name("egress ready duty [%]", "y");
  intax();
  labdig(2, "x");
  labdig(0, "y");
  labels("none", "z");
  axspos(420, 1750);
  axslen(1950, 1100);
  graf(gxmin, gxmax, -0.2f, 0.2f, gymin, gymax, 50.0f, 10.0f);
  draw_ratio_cells(ratio_grid);
  setrgb(0.76f, 0.76f, 0.76f);
  grid(1, 1);
  draw_ratio_contour(ratio_grid, 3.0f, 0);
  draw_ratio_contour(ratio_grid, 6.0f, 1);
  draw_ratio_legend(gxmin, gymax);

  color("fore");
  height(32);
  zscale(RATIO_MIN_LOG, RATIO_MAX_LOG);
  zaxis(RATIO_MIN_LOG, RATIO_MAX_LOG, RATIO_MIN_LOG, 1.0f, zaxis_len,
        "", 1, 0, zaxis_x, zaxis_y);
  height(16);
  txtjus("RIGHT");
  messag("1e6x", ztick_label_x, (int) floorf(yposn(gymax) + 0.5f) - 8);
  messag("1e5x", ztick_label_x, (int) floorf(yposn(gymin + (5.0f / 6.0f) * (gymax - gymin)) + 0.5f) - 8);
  messag("1e4x", ztick_label_x, (int) floorf(yposn(gymin + (4.0f / 6.0f) * (gymax - gymin)) + 0.5f) - 8);
  messag("1e3x", ztick_label_x, (int) floorf(yposn(gymin + (3.0f / 6.0f) * (gymax - gymin)) + 0.5f) - 8);
  messag("100x", ztick_label_x, (int) floorf(yposn(gymin + (2.0f / 6.0f) * (gymax - gymin)) + 0.5f) - 8);
  messag("10x", ztick_label_x, (int) floorf(yposn(gymin + (1.0f / 6.0f) * (gymax - gymin)) + 0.5f) - 8);
  messag("1x", ztick_label_x, (int) floorf(yposn(gymin) + 0.5f) - 8);
  txtjus("CENT");
  height(30);
  angle(270);
  messag("time-merger loss / OPQ loss", ztitle_x,
         ((int) floorf(yposn(gymax) + 0.5f) + (int) floorf(yposn(gymin) + 0.5f)) / 2);
  angle(0);
  txtjus("LEFT");

  height(48);
  title();
  height(14);
  color("fore");
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "x: B=(CV-1)/(CV+1), y: egress ready duty; fill: clipped loss ratio 1x..1e6x";
  }
  messag(plot_note, 420, 1938);
  messag("contours: dashed 1e3x, solid 1e6x; darker cells indicate stronger OPQ advantage", 420, 1980);
  disfin();
}

int main(int argc, char **argv) {
  ratio_grid_t grid;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <ratio_grid.dat> <output.{png|svg|pdf}>\n", argv[0]);
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

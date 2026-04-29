#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

typedef struct {
  int count;
  float *rho;
  float *loss;
  float knee;
  float margin;
  float first_loss;
} tm_curve_t;

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

static int read_curve(const char *path, tm_curve_t *curve_data) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open time-merger boundary data %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d", &curve_data->count) != 1 || curve_data->count < 2) {
    fprintf(stderr, "Invalid boundary data header in %s\n", path);
    fclose(handle);
    return 0;
  }
  curve_data->rho = (float *) calloc((size_t) curve_data->count, sizeof(float));
  curve_data->loss = (float *) calloc((size_t) curve_data->count, sizeof(float));
  if (curve_data->rho == NULL || curve_data->loss == NULL) {
    fprintf(stderr, "Out of memory while reading %s\n", path);
    fclose(handle);
    return 0;
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->rho[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->loss[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  if (fscanf(handle, "%f %f %f", &curve_data->knee, &curve_data->margin, &curve_data->first_loss) != 3) {
    fprintf(stderr, "Missing knee/margin/first-loss values in %s\n", path);
    fclose(handle);
    return 0;
  }
  fclose(handle);
  return 1;
}

static void free_curve(tm_curve_t *curve_data) {
  free(curve_data->rho);
  free(curve_data->loss);
}

static void draw_real_box(float x0, float y0, float x1, float y1) {
  float x[5] = {x0, x1, x1, x0, x0};
  float y[5] = {y0, y0, y1, y1, y0};

  color("fore");
  linwid(1);
  solid();
  curve(x, y, 5);
}

static void draw_vline(float x, float y0, float y1, const char *style_name) {
  float xs[2] = {x, x};
  float ys[2] = {y0, y1};

  if (strcmp(style_name, "dash") == 0) {
    dash();
  } else if (strcmp(style_name, "dot") == 0) {
    dot();
  } else {
    solid();
  }
  curve(xs, ys, 2);
  solid();
}

static void draw_legend(void) {
  float xs[2];
  float ys[2];

  draw_real_box(0.207f, 0.365f, 0.270f, 0.442f);
  height(17);
  color("fore");
  rlmess("markers", 0.211f, 0.430f);

  linwid(7);
  xs[0] = 0.211f; xs[1] = 0.226f; ys[0] = 0.412f; ys[1] = 0.412f;
  setrgb(0.72f, 0.12f, 0.10f);
  solid();
  curve(xs, ys, 2);
  linwid(1);
  color("fore");
  rlmess("source loss", 0.230f, 0.405f);

  linwid(3);
  xs[0] = 0.211f; xs[1] = 0.226f; ys[0] = 0.392f; ys[1] = 0.392f;
  setrgb(0.10f, 0.25f, 0.72f);
  dash();
  curve(xs, ys, 2);
  solid();
  linwid(1);
  color("fore");
  rlmess("80% margin", 0.230f, 0.385f);

  linwid(3);
  xs[0] = 0.211f; xs[1] = 0.226f; ys[0] = 0.373f; ys[1] = 0.373f;
  color("fore");
  dot();
  curve(xs, ys, 2);
  solid();
  linwid(1);
  rlmess("ideal knee", 0.230f, 0.366f);
}

static void render_curve(const tm_curve_t *curve_data, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);

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
  titlin("Old Time-Merger First-Loss Boundary N_LANE=4", 2);
  name("rho: hit words / cycle / lane", "x");
  name("source loss probability", "y");
  labdig(2, "x");
  labdig(2, "y");
  axspos(420, 1750);
  axslen(2050, 1100);
  graf(0.10f, 0.30f, 0.10f, 0.05f, 0.0f, 0.45f, 0.0f, 0.05f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);

  linwid(9);
  setrgb(0.72f, 0.12f, 0.10f);
  solid();
  curve(curve_data->rho, curve_data->loss, curve_data->count);

  linwid(4);
  setrgb(0.10f, 0.25f, 0.72f);
  draw_vline(curve_data->margin, 0.0f, 0.45f, "dash");
  color("fore");
  draw_vline(curve_data->knee, 0.0f, 0.45f, "dot");
  setrgb(0.30f, 0.30f, 0.30f);
  draw_vline(curve_data->first_loss, 0.0f, 0.45f, "solid");
  draw_legend();

  height(48);
  color("fore");
  title();
  height(14);
  messag("source queue depth=1024 words; stage FIFO depth=128; hps=1; accepted hits equal delivered hits", 420, 1938);
  messag("first loss occurs below the ideal average knee because source queues fill under merger-tree backpressure", 420, 1980);
  disfin();
}

int main(int argc, char **argv) {
  tm_curve_t curve_data = {0};

  if (argc != 3) {
    fprintf(stderr, "usage: %s input.dat output.png\n", argv[0]);
    return 2;
  }
  if (!read_curve(argv[1], &curve_data)) {
    free_curve(&curve_data);
    return 1;
  }
  render_curve(&curve_data, argv[2]);
  free_curve(&curve_data);
  return 0;
}

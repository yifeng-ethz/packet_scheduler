#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

typedef struct {
  int count;
  float *rho_pct;
  float *rtl_loss;
  float *at_loss;
} boundary_curve_t;

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

static int read_curve(const char *path, boundary_curve_t *curve_data) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open boundary data %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d", &curve_data->count) != 1 || curve_data->count < 2) {
    fprintf(stderr, "Invalid boundary data header in %s\n", path);
    fclose(handle);
    return 0;
  }
  curve_data->rho_pct = (float *) calloc((size_t) curve_data->count, sizeof(float));
  curve_data->rtl_loss = (float *) calloc((size_t) curve_data->count, sizeof(float));
  curve_data->at_loss = (float *) calloc((size_t) curve_data->count, sizeof(float));
  if (curve_data->rho_pct == NULL || curve_data->rtl_loss == NULL || curve_data->at_loss == NULL) {
    fprintf(stderr, "Out of memory while reading %s\n", path);
    fclose(handle);
    return 0;
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->rho_pct[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->rtl_loss[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->at_loss[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  fclose(handle);
  return 1;
}

static void free_curve(boundary_curve_t *curve_data) {
  free(curve_data->rho_pct);
  free(curve_data->rtl_loss);
  free(curve_data->at_loss);
}

static void draw_real_box(float x0, float y0, float x1, float y1) {
  float x[5] = {x0, x1, x1, x0, x0};
  float y[5] = {y0, y0, y1, y1, y0};

  color("fore");
  linwid(1);
  solid();
  curve(x, y, 5);
}

static void draw_legend(void) {
  float xs[2];
  float ys[2];

  draw_real_box(11.5f, 0.435f, 29.0f, 0.585f);
  height(18);
  color("fore");
  rlmess("loss source", 12.2f, 0.565f);

  linwid(8);
  xs[0] = 12.3f; xs[1] = 17.0f; ys[0] = 0.525f; ys[1] = 0.525f;
  setrgb(0.74f, 0.16f, 0.12f);
  solid();
  curve(xs, ys, 2);
  linwid(1);
  color("fore");
  rlmess("RTL parsed drops", 18.0f, 0.515f);

  linwid(8);
  xs[0] = 12.3f; xs[1] = 17.0f; ys[0] = 0.475f; ys[1] = 0.475f;
  setrgb(0.10f, 0.30f, 0.78f);
  dashm();
  curve(xs, ys, 2);
  solid();
  linwid(1);
  color("fore");
  rlmess("Structural AT", 18.0f, 0.465f);
}

static void render_curve(const boundary_curve_t *curve_data, const char *output_path) {
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
  titlin("OPQ Structural AT vs RTL Boundary N_LANE=4, Egress=1x", 2);
  name("per-lane offered rate [%]", "x");
  name("loss probability", "y");
  intax();
  labdig(0, "x");
  labdig(2, "y");
  axspos(420, 1750);
  axslen(2050, 1100);
  graf(10.0f, 60.0f, 10.0f, 10.0f, 0.0f, 0.60f, 0.0f, 0.10f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);

  linwid(9);
  setrgb(0.74f, 0.16f, 0.12f);
  solid();
  curve(curve_data->rho_pct, curve_data->rtl_loss, curve_data->count);
  setrgb(0.10f, 0.30f, 0.78f);
  dashm();
  curve(curve_data->rho_pct, curve_data->at_loss, curve_data->count);
  solid();
  linwid(1);
  draw_legend();

  height(48);
  color("fore");
  title();
  height(14);
  messag("profile=3 timestamp source; zero inter-frame gap; independent lanes; B=0", 420, 1938);
  messag("legend order follows the central curve ordering near rho=35%; boxed because grid crosses the legend area", 420, 1980);
  disfin();
}

int main(int argc, char **argv) {
  boundary_curve_t curve_data = {0};

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

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define LOSS_LOG_MIN -12.0f
#define LOSS_LOG_MAX 0.0f

typedef struct {
  int count;
  float *rho_lane;
  float *opq_log_loss;
  float *tm_log_loss;
} loss_curve_t;

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

static float clamp_loss(float value) {
  if (value < 1.0e-12f) {
    return 1.0e-12f;
  }
  if (value > 1.0f) {
    return 1.0f;
  }
  return value;
}

static int read_curve(const char *path, loss_curve_t *curve_data) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open loss-curve file %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d", &curve_data->count) != 1 || curve_data->count < 2) {
    fprintf(stderr, "Invalid loss-curve header in %s\n", path);
    fclose(handle);
    return 0;
  }
  curve_data->rho_lane = (float *) calloc((size_t) curve_data->count, sizeof(float));
  curve_data->opq_log_loss = (float *) calloc((size_t) curve_data->count, sizeof(float));
  curve_data->tm_log_loss = (float *) calloc((size_t) curve_data->count, sizeof(float));
  if (curve_data->rho_lane == NULL ||
      curve_data->opq_log_loss == NULL ||
      curve_data->tm_log_loss == NULL) {
    fprintf(stderr, "Out of memory while reading %s\n", path);
    fclose(handle);
    return 0;
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    if (fscanf(handle, "%f", &curve_data->rho_lane[idx]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    float value;

    if (fscanf(handle, "%f", &value) != 1) {
      fclose(handle);
      return 0;
    }
    curve_data->opq_log_loss[idx] = log10f(clamp_loss(value));
  }
  for (int idx = 0; idx < curve_data->count; idx++) {
    float value;

    if (fscanf(handle, "%f", &value) != 1) {
      fclose(handle);
      return 0;
    }
    curve_data->tm_log_loss[idx] = log10f(clamp_loss(value));
  }
  fclose(handle);
  return 1;
}

static void free_curve(loss_curve_t *curve_data) {
  free(curve_data->rho_lane);
  free(curve_data->opq_log_loss);
  free(curve_data->tm_log_loss);
  curve_data->rho_lane = NULL;
  curve_data->opq_log_loss = NULL;
  curve_data->tm_log_loss = NULL;
}

static void draw_real_box(float x0, float y0, float x1, float y1) {
  float x[5] = {x0, x1, x1, x0, x0};
  float y[5] = {y0, y0, y1, y1, y0};

  setrgb(0.96f, 0.96f, 0.96f);
  shdpat(16);
  rlarea(x, y, 5);
  color("fore");
  linwid(1);
  solid();
  curve(x, y, 5);
}

static void draw_loss_legend(float xmin, float xmax) {
  float xs[2];
  float ys[2];
  float xspan = fmaxf(fabsf(xmax - xmin), 1.0e-6f);
  float x0 = xmax - 0.20f * xspan;
  float x1 = x0 + 0.080f * xspan;
  float text_gap = 0.012f * xspan;

  draw_real_box(x0 - 0.020f * xspan, -10.35f,
                xmax - 0.004f * xspan, -7.05f);

  height(16);
  color("fore");
  rlmess("implementation", x0, -7.60f);
  linwid(8);
  xs[0] = x0; xs[1] = x1; ys[0] = -8.45f; ys[1] = -8.45f;
  setrgb(0.82f, 0.20f, 0.10f); dashm(); curve(xs, ys, 2);
  color("fore"); linwid(1); rlmess("Time-Merger", x1 + text_gap, -8.25f);
  linwid(8);
  xs[0] = x0; xs[1] = x1; ys[0] = -9.55f; ys[1] = -9.55f;
  setrgb(0.10f, 0.30f, 0.78f); solid(); curve(xs, ys, 2);
  solid(); color("fore"); linwid(1); rlmess("OPQ", x1 + text_gap, -9.35f);
}

static void draw_log_loss_axis_labels(float xmin, float ymax_log, float ymin_log) {
  (void) xmin;
  (void) ymax_log;
  (void) ymin_log;
  txtjus("RIGHT");
  height(15);
  color("fore");
  for (int exp = 0; exp >= -12; exp -= 2) {
    char label[32];
    int y = (int) floorf(yposn((float) exp) + 0.5f) - 8;

    if (exp == 0) {
      snprintf(label, sizeof(label), "1");
    } else {
      snprintf(label, sizeof(label), "1e%d", exp);
    }
    messag(label, 384, y);
  }
  txtjus("LEFT");
}

static void render_curve(const loss_curve_t *curve_data, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  const char *plot_title = getenv("OPQ_LOSS_CURVE_TITLE");
  const char *plot_note = getenv("OPQ_LOSS_CURVE_NOTE");
  float xmin = curve_data->rho_lane[0];
  float xmax = curve_data->rho_lane[curve_data->count - 1];

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
  if (plot_title == NULL || plot_title[0] == '\0') {
    plot_title = "OPQ vs Time-Merger Loss Curve";
  }
  titlin(plot_title, 2);
  name("normalized throughput share / lane", "x");
  name("", "y");
  intax();
  labdig(2, "x");
  labels("none", "y");
  axspos(420, 1750);
  axslen(2050, 1100);
  graf(xmin, xmax, 0.0f, 0.2f, LOSS_LOG_MIN, LOSS_LOG_MAX, LOSS_LOG_MIN, 2.0f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);
  draw_log_loss_axis_labels(xmin, LOSS_LOG_MAX, LOSS_LOG_MIN);

  linwid(9);
  setrgb(0.10f, 0.30f, 0.78f);
  solid();
  curve(curve_data->rho_lane, curve_data->opq_log_loss, curve_data->count);
  setrgb(0.82f, 0.20f, 0.10f);
  dashm();
  curve(curve_data->rho_lane, curve_data->tm_log_loss, curve_data->count);
  solid();
  linwid(1);
  draw_loss_legend(xmin, xmax);

  height(48);
  color("fore");
  title();
  height(14);
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "analytical finite-buffer proxy; y-axis is logarithmic loss probability";
  }
  messag(plot_note, 420, 1938);
  messag("solid blue: OPQ; dashed red: time-merger; lower curve is lower modeled loss", 420, 1980);
  disfin();
}

int main(int argc, char **argv) {
  loss_curve_t curve_data;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <loss_curve.dat> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }
  memset(&curve_data, 0, sizeof(curve_data));
  if (!read_curve(argv[1], &curve_data)) {
    free_curve(&curve_data);
    return 1;
  }
  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_curve(&curve_data);
    return 1;
  }
  render_curve(&curve_data, output_path);
  free_curve(&curve_data);
  return 0;
}

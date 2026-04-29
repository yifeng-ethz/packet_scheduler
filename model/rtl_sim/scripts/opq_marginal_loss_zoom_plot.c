#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define LOSS_LOG_MIN -6.0f
#define LOSS_LOG_MAX -0.8f
#define MAX_GROUPS 8

typedef struct {
  float burstiness;
  int count;
  float *rho;
  float *rtl_log_loss;
  float *tlm_log_loss;
} loss_group_t;

typedef struct {
  int count;
  loss_group_t groups[MAX_GROUPS];
} zoom_data_t;

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
  if (value < 1.0e-6f) {
    return 1.0e-6f;
  }
  if (value > 1.0f) {
    return 1.0f;
  }
  return value;
}

static int alloc_group(loss_group_t *group) {
  group->rho = (float *) calloc((size_t) group->count, sizeof(float));
  group->rtl_log_loss = (float *) calloc((size_t) group->count, sizeof(float));
  group->tlm_log_loss = (float *) calloc((size_t) group->count, sizeof(float));
  return group->rho != NULL && group->rtl_log_loss != NULL && group->tlm_log_loss != NULL;
}

static int read_zoom_data(const char *path, zoom_data_t *data) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open marginal zoom data %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d", &data->count) != 1 || data->count < 1 || data->count > MAX_GROUPS) {
    fprintf(stderr, "Invalid marginal zoom group count in %s\n", path);
    fclose(handle);
    return 0;
  }
  for (int group_idx = 0; group_idx < data->count; group_idx++) {
    loss_group_t *group = &data->groups[group_idx];

    if (fscanf(handle, "%f %d", &group->burstiness, &group->count) != 2 || group->count < 2) {
      fprintf(stderr, "Invalid marginal zoom group header in %s\n", path);
      fclose(handle);
      return 0;
    }
    if (!alloc_group(group)) {
      fprintf(stderr, "Out of memory while reading %s\n", path);
      fclose(handle);
      return 0;
    }
    for (int idx = 0; idx < group->count; idx++) {
      if (fscanf(handle, "%f", &group->rho[idx]) != 1) {
        fclose(handle);
        return 0;
      }
    }
    for (int idx = 0; idx < group->count; idx++) {
      float value;

      if (fscanf(handle, "%f", &value) != 1) {
        fclose(handle);
        return 0;
      }
      group->rtl_log_loss[idx] = log10f(clamp_loss(value));
    }
    for (int idx = 0; idx < group->count; idx++) {
      float value;

      if (fscanf(handle, "%f", &value) != 1) {
        fclose(handle);
        return 0;
      }
      group->tlm_log_loss[idx] = log10f(clamp_loss(value));
    }
  }
  fclose(handle);
  return 1;
}

static void free_zoom_data(zoom_data_t *data) {
  for (int group_idx = 0; group_idx < data->count; group_idx++) {
    free(data->groups[group_idx].rho);
    free(data->groups[group_idx].rtl_log_loss);
    free(data->groups[group_idx].tlm_log_loss);
  }
}

static void set_group_color(int group_idx) {
  if (group_idx == 0) {
    setrgb(0.10f, 0.30f, 0.78f);
  } else if (group_idx == 1) {
    setrgb(0.05f, 0.50f, 0.28f);
  } else if (group_idx == 2) {
    setrgb(0.78f, 0.18f, 0.10f);
  } else {
    setrgb(0.35f, 0.25f, 0.55f);
  }
}

static void draw_real_box(float x0, float y0, float x1, float y1) {
  float x[5] = {x0, x1, x1, x0, x0};
  float y[5] = {y0, y0, y1, y1, y0};

  setrgb(0.965f, 0.965f, 0.965f);
  shdpat(16);
  rlarea(x, y, 5);
  color("fore");
  linwid(1);
  solid();
  curve(x, y, 5);
}

static void draw_log_axis_labels(void) {
  txtjus("RIGHT");
  height(15);
  color("fore");
  for (int exp = -1; exp >= -6; exp--) {
    char label[32];
    int y = (int) floorf(yposn((float) exp) + 0.5f) - 8;

    snprintf(label, sizeof(label), "1e%d", exp);
    messag(label, 382, y);
  }
  txtjus("LEFT");
}

static void draw_legend(const zoom_data_t *data) {
  float xs[2];
  float ys[2];
  float y = -1.13f;

  draw_real_box(0.615f, -1.62f, 0.825f, -0.92f);
  height(13);
  color("fore");
  rlmess("solid RTL / dash TLM", 0.625f, -1.00f);

  linwid(6);
  setrgb(0.12f, 0.12f, 0.12f);
  xs[0] = 0.625f; xs[1] = 0.660f; ys[0] = y; ys[1] = y;
  solid();
  curve(xs, ys, 2);
  xs[0] = 0.670f; xs[1] = 0.705f; ys[0] = y; ys[1] = y;
  dashm();
  curve(xs, ys, 2);
  solid();

  y -= 0.24f;
  color("fore");
  linwid(1);
  rlmess("B:", 0.625f, y - 0.04f);
  for (int group_idx = 0; group_idx < data->count; group_idx++) {
    char label[32];
    float x0 = 0.660f + 0.050f * (float) group_idx;
    float x1 = x0 + 0.018f;
    float sample_y = y;

    snprintf(label, sizeof(label), "%.3g", data->groups[group_idx].burstiness);
    linwid(7);
    set_group_color(group_idx);
    xs[0] = x0; xs[1] = x1; ys[0] = sample_y; ys[1] = sample_y;
    solid();
    curve(xs, ys, 2);
    linwid(1);
    color("fore");
    rlmess(label, x0 - 0.002f, sample_y - 0.17f);
  }
}

static void render_zoom(const zoom_data_t *data, const char *output_path) {
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
  titlin("OPQ RTL vs Structural TLM Marginal Loss Zoom", 2);
  name("per-lane offered rate rho", "x");
  name("", "y");
  intax();
  labdig(2, "x");
  labels("none", "y");
  axspos(420, 1750);
  axslen(2050, 1100);
  graf(0.60f, 1.00f, 0.60f, 0.05f, LOSS_LOG_MIN, LOSS_LOG_MAX, LOSS_LOG_MIN, 1.0f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);
  draw_log_axis_labels();

  for (int group_idx = 0; group_idx < data->count; group_idx++) {
    const loss_group_t *group = &data->groups[group_idx];

    linwid(8);
    set_group_color(group_idx);
    solid();
    curve(group->rho, group->rtl_log_loss, group->count);
    set_group_color(group_idx);
    dashm();
    curve(group->rho, group->tlm_log_loss, group->count);
    solid();
  }
  linwid(1);
  draw_legend(data);

  height(48);
  color("fore");
  title();
  height(14);
  messag("100-frame UVM knee zoom, N_LANE=4, egress=1x; y-axis clamps zero loss to 1e-6", 420, 1938);
  messag("loss tiers: RTL controlled drops only; TLM remains DEBUG where exact drop count differs", 420, 1980);
  disfin();
}

int main(int argc, char **argv) {
  zoom_data_t data;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <marginal_zoom.dat> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }
  memset(&data, 0, sizeof(data));
  if (!read_zoom_data(argv[1], &data)) {
    free_zoom_data(&data);
    return 1;
  }
  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_zoom_data(&data);
    return 1;
  }
  render_zoom(&data, output_path);
  free_zoom_data(&data);
  return 0;
}

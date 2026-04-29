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
#define MAX_SAMPLE_PINS 128

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
} loss_grid_t;

typedef struct {
  float burstiness;
  float rho_lane;
  float rtl_loss;
  float tlm_loss;
  char label[160];
} sample_pin_t;

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

static int parse_env_float(const char *name, float *value) {
  const char *text = getenv(name);
  char *end = NULL;
  double parsed;

  if (text == NULL || text[0] == '\0') {
    return 0;
  }
  parsed = strtod(text, &end);
  if (end == text) {
    return 0;
  }
  *value = (float) parsed;
  return 1;
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
  for (float x = xmin; x < xmax; x += 0.2f) {
    float xs[2] = {x, x};
    float ys[2] = {ymin, ymax};
    curve(xs, ys, 2);
  }
  for (float y = 0.2f; y < ymax; y += 0.2f) {
    float xs[2] = {xmin, xmax};
    float ys[2] = {y, y};
    curve(xs, ys, 2);
  }
  solid();
}

static void draw_legend(float xmin, float xmax, float ymin, float ymax) {
  float xs[2];
  float ys[2];
  float yspan = fmaxf(fabsf(ymax - ymin), 1.0e-6f);
  float row_gap = 0.070f * yspan;
  float header_gap = 0.050f * yspan;
  float label_raise = 0.018f * yspan;
  float box_pad = 0.035f * yspan;
  float impl_x0 = xmin + 0.05f;
  float impl_x1 = impl_x0 + 0.16f;
  float impl_text_x = impl_x1 + 0.05f;
  float impl_y0 = ymax - 0.10f * yspan;
  float level_x0 = xmax - 0.53f;
  float level_x1 = level_x0 + 0.16f;
  float level_text_x = level_x1 + 0.05f;
  float level_y0 = impl_y0;

  draw_real_box(impl_x0 - 0.035f, impl_y0 - row_gap - box_pad,
                impl_text_x + 0.34f, impl_y0 + header_gap + box_pad);
  draw_real_box(level_x0 - 0.035f, level_y0 - 2.0f * row_gap - box_pad,
                level_text_x + 0.25f, level_y0 + header_gap + box_pad);

  simplx();
  height(18);
  color("fore");
  rlmess("implementation", impl_x0, impl_y0 + header_gap);
  linwid(7);
  xs[0] = impl_x0; xs[1] = impl_x1; ys[0] = impl_y0; ys[1] = impl_y0;
  set_impl_color(0); solid(); curve(xs, ys, 2);
  color("fore"); linwid(1); rlmess("OPQ", impl_text_x, impl_y0 + label_raise);
  linwid(7);
  xs[0] = impl_x0; xs[1] = impl_x1; ys[0] = impl_y0 - row_gap; ys[1] = impl_y0 - row_gap;
  set_impl_color(1); solid(); curve(xs, ys, 2);
  color("fore"); linwid(1); rlmess("Time-Merger", impl_text_x, impl_y0 - row_gap + label_raise);

  height(18);
  rlmess("loss contour", level_x0, level_y0 + header_gap);
  linwid(7);
  xs[0] = level_x0; xs[1] = level_x1; ys[0] = level_y0; ys[1] = level_y0;
  color("fore"); solid(); curve(xs, ys, 2);
  linwid(1); rlmess("5 %", level_text_x, level_y0 + label_raise);
  linwid(7);
  xs[0] = level_x0; xs[1] = level_x1; ys[0] = level_y0 - row_gap; ys[1] = level_y0 - row_gap;
  dashm(); curve(xs, ys, 2);
  solid(); linwid(1); rlmess("1 %", level_text_x, level_y0 - row_gap + label_raise);
  linwid(7);
  xs[0] = level_x0; xs[1] = level_x1; ys[0] = level_y0 - 2.0f * row_gap; ys[1] = level_y0 - 2.0f * row_gap;
  dotl(); curve(xs, ys, 2);
  solid(); linwid(1); rlmess("1e-6", level_text_x, level_y0 - 2.0f * row_gap + label_raise);
  complx();
}

static void draw_sample_point_if_present(float gxmin, float gxmax, float gymin, float gymax) {
  const char *label = getenv("OPQ_SAMPLE_LABEL");
  float burstiness;
  float rho_lane;
  float rho_axis;
  float dx;
  float dy;
  int clipped_high = 0;
  int clipped_low = 0;
  char clipped_label[256];
  float xs[2];
  float ys[2];

  if (!parse_env_float("OPQ_SAMPLE_B", &burstiness) ||
      !parse_env_float("OPQ_SAMPLE_RHO_LANE", &rho_lane)) {
    return;
  }

  rho_axis = rho_lane;
  if (burstiness < gxmin || burstiness > gxmax) {
    return;
  }

  dx = 0.008f * fmaxf(fabsf(gxmax - gxmin), 1.0e-6f);
  dy = 0.008f * fmaxf(fabsf(gymax - gymin), 1.0e-6f);
  if (rho_axis > gymax) {
    rho_axis = gymax - (2.5f * dy);
    clipped_high = 1;
  } else if (rho_axis < gymin) {
    rho_axis = gymin + (2.5f * dy);
    clipped_low = 1;
  }

  linwid(5);
  setrgb(0.00f, 0.82f, 0.36f);
  xs[0] = burstiness - dx; xs[1] = burstiness + dx;
  ys[0] = rho_axis - dy; ys[1] = rho_axis + dy;
  curve(xs, ys, 2);
  xs[0] = burstiness - dx; xs[1] = burstiness + dx;
  ys[0] = rho_axis + dy; ys[1] = rho_axis - dy;
  curve(xs, ys, 2);
  linwid(1);

  if (label != NULL && label[0] != '\0') {
    if (clipped_high) {
      snprintf(clipped_label, sizeof(clipped_label), "%s (rho above axis)", label);
      label = clipped_label;
    } else if (clipped_low) {
      snprintf(clipped_label, sizeof(clipped_label), "%s (rho below axis)", label);
      label = clipped_label;
    }
    height(13);
    color("fore");
    txtjus("LEFT");
    rlmess(label, clipped_high ? (burstiness - dx) : (burstiness + (1.6f * dx)),
           clipped_high ? (rho_axis - (26.0f * dy)) :
           (clipped_low ? (rho_axis + (4.2f * dy)) : (rho_axis + (0.8f * dy))));
  }
}

static int read_sample_pins(sample_pin_t *pins, int max_pins) {
  const char *path = getenv("OPQ_SAMPLE_PINS_CSV");
  FILE *handle;
  char line[512];
  int count = 0;

  if (path == NULL || path[0] == '\0') {
    return 0;
  }
  handle = fopen(path, "r");
  if (handle == NULL) {
    fprintf(stderr, "Warning: failed to open sample-pin CSV %s\n", path);
    return 0;
  }
  while (fgets(line, sizeof(line), handle) != NULL && count < max_pins) {
    char run_tag[192];
    sample_pin_t pin;
    memset(&pin, 0, sizeof(pin));
    if (sscanf(line, "%191[^,],%f,%f,%f,%f,%159[^\n]",
               run_tag, &pin.burstiness, &pin.rho_lane,
               &pin.rtl_loss, &pin.tlm_loss, pin.label) != 6) {
      continue;
    }
    trim_ascii(pin.label);
    pins[count++] = pin;
  }
  fclose(handle);
  return count;
}

static void draw_sample_pins_if_present(float gxmin, float gxmax, float gymin, float gymax) {
  sample_pin_t pins[MAX_SAMPLE_PINS];
  int count = read_sample_pins(pins, MAX_SAMPLE_PINS);
  float dx = 0.008f * fmaxf(fabsf(gxmax - gxmin), 1.0e-6f);
  float dy = 0.010f * fmaxf(fabsf(gymax - gymin), 1.0e-6f);

  for (int idx = 0; idx < count; idx++) {
    float x = pins[idx].burstiness;
    float y = pins[idx].rho_lane;
    float xs[2];
    float ys[2];
    int group_row = 0;
    int group_count = 0;
    float xspan = fmaxf(fabsf(gxmax - gxmin), 1.0e-6f);
    float yspan = fmaxf(fabsf(gymax - gymin), 1.0e-6f);
    int label_left;
    float label_x;
    float label_y;

    if (x < gxmin || x > gxmax || y < gymin || y > gymax) {
      continue;
    }
    for (int prev = 0; prev < count; prev++) {
      if (fabsf(pins[prev].burstiness - x) < 1.0e-5f &&
          fabsf(pins[prev].rho_lane - y) < 1.0e-5f) {
        if (prev < idx) {
          group_row++;
        }
        group_count++;
      }
    }

    linwid(6);
    setrgb(0.00f, 0.62f, 0.28f);
    xs[0] = x - dx; xs[1] = x + dx;
    ys[0] = y - dy; ys[1] = y + dy;
    curve(xs, ys, 2);
    xs[0] = x - dx; xs[1] = x + dx;
    ys[0] = y + dy; ys[1] = y - dy;
    curve(xs, ys, 2);
    linwid(1);

    label_left = (x > gxmin + (0.35f * xspan));
    label_x = label_left ? x - (2.2f * dx) : x + (2.2f * dx);
    label_y = y +
      ((float) group_row - 0.5f * (float) (group_count - 1)) * (2.3f * dy) +
      ((y > gymin + (0.77f * yspan)) ? (2.2f * dy) : (-2.2f * dy));
    if (label_y > gymax - (1.5f * dy)) {
      label_y = gymax - (1.5f * dy);
    }
    if (label_y < gymin + (1.5f * dy)) {
      label_y = gymin + (1.5f * dy);
    }

    height(9);
    txtjus(label_left ? "RIGHT" : "LEFT");
    color("fore");
    rlmess(pins[idx].label, label_x, label_y);
  }
  txtjus("LEFT");
  color("fore");
}

static void render_plot(const loss_grid_t *opq_grid, const loss_grid_t *tm_grid, const char *output_path) {
  const float levels[LEVEL_COUNT] = {1.0e-6f, 1.0e-2f, 5.0e-2f};
  const char *output_format = output_format_from_path(output_path);
  const char *plot_title = getenv("OPQ_TM_CONTOUR_TITLE");
  const char *plot_note = getenv("OPQ_TM_CONTOUR_NOTE");
  float xmin = opq_grid->x[0];
  float xmax = opq_grid->x[opq_grid->nx - 1];
  float ymin = opq_grid->y[0];
  float ymax = opq_grid->y[opq_grid->ny - 1];
  float xpad = 0.015f * fmaxf(fabsf(xmax - xmin), 1.0e-6f);
  float ypad = 0.015f * fmaxf(fabsf(ymax - ymin), 1.0e-6f);
  float gxmin = xmin - xpad;
  float gxmax = xmax + xpad;
  float gymin = fmaxf(0.0f, ymin - ypad);
  float gymax = ymax + ypad;

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
    plot_title = "OPQ IP-Core vs Time-Merger Burst/Rate Loss Contour";
  }
  titlin(plot_title, 2);
  name("burstiness B", "x");
  name("rate / lane rho", "y");
  intax();
  labdig(2, "x");
  labdig(2, "y");
  axspos(420, 1720);
  axslen(2050, 1100);
  graf(gxmin, gxmax, -1.0f, 0.2f, gymin, gymax, 0.0f, 0.2f);
  draw_grid(xmin, xmax, ymin, ymax);

  for (int level_idx = 0; level_idx < LEVEL_COUNT; level_idx++) {
    draw_single_contour(opq_grid, levels[level_idx], 0, level_idx);
    draw_single_contour(tm_grid, levels[level_idx], 1, level_idx);
  }

  draw_sample_point_if_present(gxmin, gxmax, gymin, gymax);
  draw_sample_pins_if_present(gxmin, gxmax, gymin, gymax);
  draw_legend(gxmin, gxmax, gymin, gymax);
  height(44);
  title();
  color("fore");
  height(15);
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "x: B=(CV-1)/(CV+1), y: offered rate/lane; window zooms out to expose early time-merger loss";
  }
  messag(plot_note, 420, 1918);
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

#include <ctype.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define REF_LEVEL_COUNT 3
#define MIN_FINE_X_COUNT 181
#define MIN_FINE_Y_COUNT 141
#define CONTOUR_MAX_CURVES 2048
#define MAX_SAMPLE_PINS 128
#define PLOT_PI 3.14159265358979323846

typedef struct {
  float probability;
  const char *label;
  float preferred_x;
  float preferred_y;
} reference_contour_t;

typedef struct {
  int curve_index;
  int point_index;
  int point_offset;
  double angle_deg;
} contour_label_position_t;

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
  float zmin;
  float zmax;
} opq_loss_grid_t;

typedef struct {
  float burstiness;
  float rho_lane;
  float rtl_loss;
  float tlm_loss;
  char loss_tier[64];
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

static int split_csv_fields(char *line, char **fields, int max_fields) {
  int count = 0;
  char *cursor = line;

  while (count < max_fields && cursor != NULL) {
    char *comma = strchr(cursor, ',');
    if (comma != NULL) {
      *comma = '\0';
    }
    trim_ascii(cursor);
    fields[count++] = cursor;
    cursor = (comma == NULL) ? NULL : comma + 1;
  }
  return count;
}

static int parse_float_text(const char *text, float *value) {
  char *end = NULL;
  double parsed = strtod(text, &end);

  if (end == text) {
    return 0;
  }
  *value = (float) parsed;
  return 1;
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

static int max_int(int lhs, int rhs) {
  return lhs > rhs ? lhs : rhs;
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

static void init_loss_palette(void) {
  float red[256];
  float green[256];
  float blue[256];
  int idx;

  for (idx = 0; idx < 256; idx++) {
    float t = (float) idx / 255.0f;

    red[idx] = 0.98f - 0.84f * t;
    green[idx] = 0.98f - 0.86f * t;
    blue[idx] = 0.99f - 0.81f * t;
  }
  myvlt(red, green, blue, 256);
}

static float clamp_loss_floor(float value, float floor_value) {
  if (value < floor_value) {
    return floor_value;
  }
  if (value > 1.0f) {
    return 1.0f;
  }
  return value;
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

static void fill_linspace(float *values, int count, float start, float stop) {
  int idx;

  if (count <= 1) {
    if (count == 1) {
      values[0] = start;
    }
    return;
  }

  for (idx = 0; idx < count; idx++) {
    values[idx] = start + ((stop - start) * (float) idx / (float) (count - 1));
  }
}

static int loss_color_index(float log_loss, float log_min, float log_max) {
  float t = clamp_unit((log_loss - log_min) / (log_max - log_min));

  return 1 + (int) floorf((253.0f * t) + 0.5f);
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

static void draw_sample_point_if_present(
    float gxmin,
    float gxmax,
    float gymin,
    float gymax) {
  const char *label = getenv("OPQ_SAMPLE_LABEL");
  float burstiness;
  float rho_lane;
  float rho_axis;
  float dx;
  float dy;
  int clipped_high = 0;
  int clipped_low = 0;
  char clipped_label[256];
  float dot_x[13];
  float dot_y[13];

  if (!parse_env_float("OPQ_SAMPLE_B", &burstiness) ||
      !parse_env_float("OPQ_SAMPLE_RHO_LANE", &rho_lane)) {
    return;
  }

  rho_axis = rho_lane;
  if (burstiness < gxmin || burstiness > gxmax) {
    return;
  }

  dx = 0.012f * fmaxf(fabsf(gxmax - gxmin), 1.0e-6f);
  dy = 0.012f * fmaxf(fabsf(gymax - gymin), 1.0e-6f);
  if (rho_axis > gymax) {
    rho_axis = gymax - (2.5f * dy);
    clipped_high = 1;
  } else if (rho_axis < gymin) {
    rho_axis = gymin + (2.5f * dy);
    clipped_low = 1;
  }

  linwid(1);
  setrgb(0.00f, 0.82f, 0.36f);
  for (int dot_idx = 0; dot_idx < 13; dot_idx++) {
    float theta = (2.0f * (float) PLOT_PI * (float) dot_idx) / 12.0f;
    dot_x[dot_idx] = burstiness + (0.95f * dx * cosf(theta));
    dot_y[dot_idx] = rho_axis + (0.95f * dy * sinf(theta));
  }
  shdpat(16);
  rlarea(dot_x, dot_y, 13);
  curve(dot_x, dot_y, 13);
  linwid(1);

  if (label != NULL && label[0] != '\0') {
    if (clipped_high) {
      snprintf(clipped_label, sizeof(clipped_label), "%s (share above axis)", label);
      label = clipped_label;
    } else if (clipped_low) {
      snprintf(clipped_label, sizeof(clipped_label), "%s (share below axis)", label);
      label = clipped_label;
    }
    height(14);
    txtjus("LEFT");
    if (clipped_high) {
      setrgb(0.96f, 0.96f, 0.96f);
    } else {
      color("fore");
    }
    rlmess(label, burstiness + (1.6f * dx),
           clipped_high ? (rho_axis - (3.5f * dy)) :
           (clipped_low ? (rho_axis + (3.5f * dy)) : (rho_axis + (0.8f * dy))));
    color("fore");
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
    char *fields[8];
    int field_count;
    sample_pin_t pin;
    memset(&pin, 0, sizeof(pin));
    line[strcspn(line, "\r\n")] = '\0';
    field_count = split_csv_fields(line, fields, 8);
    if (field_count < 6 ||
        !parse_float_text(fields[1], &pin.burstiness) ||
        !parse_float_text(fields[2], &pin.rho_lane) ||
        !parse_float_text(fields[3], &pin.rtl_loss) ||
        !parse_float_text(fields[4], &pin.tlm_loss)) {
      continue;
    }
    if (field_count >= 7) {
      snprintf(pin.loss_tier, sizeof(pin.loss_tier), "%s", fields[5]);
      snprintf(pin.label, sizeof(pin.label), "%s", fields[6]);
    } else {
      pin.loss_tier[0] = '\0';
      snprintf(pin.label, sizeof(pin.label), "%s", fields[5]);
    }
    trim_ascii(pin.loss_tier);
    trim_ascii(pin.label);
    pins[count++] = pin;
  }
  fclose(handle);
  return count;
}

static void draw_persistent_knee_if_present(float gxmin, float gxmax, float gymin, float gymax) {
  const char *label = getenv("OPQ_PERSISTENT_KNEE_LABEL");
  float knee;
  float xs[2];
  float ys[2];
  float xspan = fmaxf(fabsf(gxmax - gxmin), 1.0e-6f);
  float yspan = fmaxf(fabsf(gymax - gymin), 1.0e-6f);
  char default_label[128];

  if (!parse_env_float("OPQ_PERSISTENT_KNEE_SHARE", &knee)) {
    return;
  }
  if (knee < gymin || knee > gymax) {
    return;
  }

  xs[0] = gxmin + (0.015f * xspan);
  xs[1] = gxmax - (0.015f * xspan);
  ys[0] = knee;
  ys[1] = knee;
  linwid(5);
  setrgb(0.66f, 0.16f, 0.10f);
  dashm();
  curve(xs, ys, 2);
  solid();
  linwid(1);

  if (label == NULL || label[0] == '\0') {
    snprintf(default_label, sizeof(default_label), "OPQ persistent knee %.3f", knee);
    label = default_label;
  }
  height(11);
  txtjus("LEFT");
  setrgb(0.66f, 0.16f, 0.10f);
  rlmess(label, gxmin + (0.030f * xspan), knee + (0.012f * yspan));
  color("fore");
}

static void draw_sample_pins_if_present(
    float gxmin,
    float gxmax,
    float gymin,
    float gymax) {
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
    int low_share_row = 0;
    int low_share_count = 0;
    int low_share_pin = 0;
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
    low_share_pin = (y < gymin + (0.10f * yspan));
    if (low_share_pin) {
      for (int other = 0; other < count; other++) {
        if (fabsf(pins[other].burstiness - x) < 1.0e-5f &&
            pins[other].rho_lane < gymin + (0.10f * yspan)) {
          if (other < idx) {
            low_share_row++;
          }
          low_share_count++;
        }
      }
    }

    linwid(6);
    setrgb(0.00f, 0.82f, 0.36f);
    xs[0] = x - dx; xs[1] = x + dx;
    ys[0] = y - dy; ys[1] = y + dy;
    curve(xs, ys, 2);
    xs[0] = x - dx; xs[1] = x + dx;
    ys[0] = y + dy; ys[1] = y - dy;
    curve(xs, ys, 2);
    linwid(1);

    label_left = (x > gxmin + (0.35f * xspan));
    label_x = label_left ? x - (2.2f * dx) : x + (2.2f * dx);
    if (low_share_pin) {
      float row_gap = 0.027f * yspan;
      float row_base = gymin + (0.055f * yspan);
      (void) low_share_count;
      label_y = row_base + (float) low_share_row * row_gap;
    } else {
      label_y = y +
        ((float) group_row - 0.5f * (float) (group_count - 1)) * (2.3f * dy) +
        ((y > gymin + (0.77f * yspan)) ? (2.2f * dy) : (-2.2f * dy));
    }
    if (label_y > gymax - (1.5f * dy)) {
      label_y = gymax - (1.5f * dy);
    }
    if (label_y < gymin + (0.065f * yspan)) {
      label_y = gymin + (0.065f * yspan);
    }

    height(9);
    txtjus(label_left ? "RIGHT" : "LEFT");
    if (y < gymin + (0.12f * yspan) ||
        0.5f * (pins[idx].rtl_loss + pins[idx].tlm_loss) < 0.004f) {
      setrgb(0.06f, 0.05f, 0.08f);
    } else {
      setrgb(0.96f, 0.96f, 0.96f);
    }
    rlmess(pins[idx].label, label_x, label_y);
  }
  txtjus("LEFT");
  color("fore");
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

static void draw_modeling_contract_box(float gxmin, float gymin, float gymax) {
  const char *anchor = getenv("OPQ_MODELING_BOX_ANCHOR");
  const char *evidence_mode = getenv("OPQ_EVIDENCE_MODE");
  float yspan = fmaxf(fabsf(gymax - gymin), 1.0e-6f);
  float line_gap = 0.040f * yspan;
  float top_pad = 0.040f * yspan;
  float box_height = 0.280f * yspan;
  float x0 = gxmin + 0.035f;
  float x1 = x0 + 0.74f;
  float y0 = gymin + 0.070f * yspan;
  float y1 = y0 + box_height;

  if (anchor != NULL && strcmp(anchor, "upper_left") == 0) {
    y1 = gymax - 0.050f * yspan;
    y0 = y1 - box_height;
  }

  draw_real_box(x0, y0, x1, y1);
  height(12);
  color("fore");
  if (evidence_mode != NULL && strcmp(evidence_mode, "opq_n4_e1") == 0) {
    rlmess("evidence gate: corrected OPQ N4/E1", x0 + 0.02f, y1 - top_pad);
    rlmess("RTL pins: UVM physical cadence, FIFO=8192", x0 + 0.02f, y1 - top_pad - line_gap);
    rlmess("TLM: structural FIFO/credit/allocator/DRR", x0 + 0.02f, y1 - top_pad - 2.0f * line_gap);
    rlmess("loss tier: controlled drop monitor", x0 + 0.02f, y1 - top_pad - 3.0f * line_gap);
    rlmess("pins: R/T/A = RTL/TLM/Analytical loss", x0 + 0.02f, y1 - top_pad - 4.0f * line_gap);
    rlmess("next: detached 128-point RTL scan", x0 + 0.02f, y1 - top_pad - 5.0f * line_gap);
  } else {
    rlmess("modeling gate", x0 + 0.02f, y1 - top_pad);
    rlmess("loss tiers: controlled / asserted / inferred", x0 + 0.02f, y1 - top_pad - line_gap);
    rlmess("checkpoints: per-subframe basic", x0 + 0.02f, y1 - top_pad - 2.0f * line_gap);
    rlmess("  -> knee-zoom subframe stats", x0 + 0.02f, y1 - top_pad - 3.0f * line_gap);
    rlmess("  -> high-performance collective soak", x0 + 0.02f, y1 - top_pad - 4.0f * line_gap);
    rlmess("gate: RTL pin/UVM tx bucket match", x0 + 0.02f, y1 - top_pad - 5.0f * line_gap);
  }
}

static void draw_loss_gradient_cells(
    const float *xplot,
    int nx,
    const float *yplot,
    int ny,
    const float *zplot,
    float log_min,
    float log_max) {
  int ix;
  int iy;

  for (ix = 0; ix < nx - 1; ix++) {
    float x0 = xposn(xplot[ix]);
    float x1 = xposn(xplot[ix + 1]);
    int nx0 = (int) floorf(fminf(x0, x1));
    int nx1 = (int) ceilf(fmaxf(x0, x1));

    for (iy = 0; iy < ny - 1; iy++) {
      float y0 = yposn(yplot[iy]);
      float y1 = yposn(yplot[iy + 1]);
      int ny0 = (int) floorf(fminf(y0, y1));
      int ny1 = (int) ceilf(fmaxf(y0, y1));
      float z00 = zplot[(size_t) ix * (size_t) ny + (size_t) iy];
      float z10 = zplot[(size_t) (ix + 1) * (size_t) ny + (size_t) iy];
      float z01 = zplot[(size_t) ix * (size_t) ny + (size_t) (iy + 1)];
      float z11 = zplot[(size_t) (ix + 1) * (size_t) ny + (size_t) (iy + 1)];
      float zmean = 0.25f * (z00 + z10 + z01 + z11);

      recfll(nx0, ny0, nx1 - nx0 + 1, ny1 - ny0 + 1,
             loss_color_index(zmean, log_min, log_max));
    }
  }
}

static void interpolate_regular_grid(
    const float *zin,
    int nx_in,
    int ny_in,
    float *zout,
    int nx_out,
    int ny_out) {
  int ix_out;
  int iy_out;

  for (ix_out = 0; ix_out < nx_out; ix_out++) {
    float x_index = (nx_in == 1) ? 0.0f :
        (float) ix_out * (float) (nx_in - 1) / (float) (nx_out - 1);
    int ix0 = (int) floorf(x_index);
    int ix1 = ix0 + 1;
    float tx = x_index - (float) ix0;

    if (ix1 >= nx_in) {
      ix1 = nx_in - 1;
      ix0 = ix1;
      tx = 0.0f;
    }

    for (iy_out = 0; iy_out < ny_out; iy_out++) {
      float y_index = (ny_in == 1) ? 0.0f :
          (float) iy_out * (float) (ny_in - 1) / (float) (ny_out - 1);
      int iy0 = (int) floorf(y_index);
      int iy1 = iy0 + 1;
      float ty = y_index - (float) iy0;
      float z00;
      float z10;
      float z01;
      float z11;
      float z0;
      float z1;

      if (iy1 >= ny_in) {
        iy1 = ny_in - 1;
        iy0 = iy1;
        ty = 0.0f;
      }

      z00 = zin[(size_t) ix0 * (size_t) ny_in + (size_t) iy0];
      z10 = zin[(size_t) ix1 * (size_t) ny_in + (size_t) iy0];
      z01 = zin[(size_t) ix0 * (size_t) ny_in + (size_t) iy1];
      z11 = zin[(size_t) ix1 * (size_t) ny_in + (size_t) iy1];
      z0 = z00 + ((z10 - z00) * tx);
      z1 = z01 + ((z11 - z01) * tx);
      zout[(size_t) ix_out * (size_t) ny_out + (size_t) iy_out] =
          z0 + ((z1 - z0) * ty);
    }
  }
}

static int smooth_log_grid(float *grid, int nx, int ny, int passes) {
  float *scratch = NULL;
  int pass;

  scratch = (float *) calloc((size_t) nx * (size_t) ny, sizeof(float));
  if (scratch == NULL) {
    fprintf(stderr, "Out of memory while allocating smoothing grid\n");
    return 0;
  }

  for (pass = 0; pass < passes; pass++) {
    int ix;
    int iy;

    for (ix = 0; ix < nx; ix++) {
      for (iy = 0; iy < ny; iy++) {
        float accum = 0.0f;
        float weight_sum = 0.0f;
        int dx;
        int dy;

        for (dx = -1; dx <= 1; dx++) {
          int sx = ix + dx;

          if (sx < 0 || sx >= nx) {
            continue;
          }
          for (dy = -1; dy <= 1; dy++) {
            int sy = iy + dy;
            float weight;

            if (sy < 0 || sy >= ny) {
              continue;
            }

            weight = (dx == 0 && dy == 0) ? 4.0f : ((dx == 0 || dy == 0) ? 2.0f : 1.0f);
            accum += grid[(size_t) sx * (size_t) ny + (size_t) sy] * weight;
            weight_sum += weight;
          }
        }

        scratch[(size_t) ix * (size_t) ny + (size_t) iy] = accum / weight_sum;
      }
    }

    memcpy(grid, scratch, (size_t) nx * (size_t) ny * sizeof(float));
  }

  free(scratch);
  return 1;
}

static double normalized_label_distance(
    float x,
    float y,
    float preferred_x,
    float preferred_y,
    float xmin,
    float xmax,
    float ymin,
    float ymax) {
  double xspan = fmax((double) fabsf(xmax - xmin), 1.0e-9);
  double yspan = fmax((double) fabsf(ymax - ymin), 1.0e-9);
  double dx = ((double) x - (double) preferred_x) / xspan;
  double dy = ((double) y - (double) preferred_y) / yspan;

  return (dx * dx) + (dy * dy);
}

static double contour_tangent_angle_degrees(
    const float *xpts,
    const float *ypts,
    int point_count,
    int point_index) {
  int prev = point_index - 2;
  int next = point_index + 2;
  double dx;
  double dy;
  double angle_deg;

  if (prev < 0) {
    prev = 0;
  }
  if (next >= point_count) {
    next = point_count - 1;
  }
  if (next == prev) {
    return 0.0;
  }

  dx = (double) xposn(xpts[next]) - (double) xposn(xpts[prev]);
  dy = (double) yposn(ypts[next]) - (double) yposn(ypts[prev]);
  angle_deg = atan2(-dy, dx) * 180.0 / PLOT_PI;

  while (angle_deg > 90.0) {
    angle_deg -= 180.0;
  }
  while (angle_deg < -90.0) {
    angle_deg += 180.0;
  }
  return angle_deg;
}

static double readable_label_angle(double angle_deg) {
  if (angle_deg > 60.0 || angle_deg < -60.0) {
    return 0.0;
  }
  return angle_deg;
}

static int label_fits_inside_axes(
    float x,
    float y,
    double angle_deg,
    int text_width,
    int text_height,
    float xmin,
    float xmax,
    float ymin,
    float ymax) {
  double label_angle_deg = readable_label_angle(angle_deg);
  double angle_rad = label_angle_deg * PLOT_PI / 180.0;
  double half_width =
      (fabs(cos(angle_rad)) * (double) text_width * 0.5) +
      (fabs(sin(angle_rad)) * (double) text_height * 0.5);
  double half_height =
      (fabs(sin(angle_rad)) * (double) text_width * 0.5) +
      (fabs(cos(angle_rad)) * (double) text_height * 0.5);
  double px = (double) xposn(x);
  double py = (double) yposn(y);
  double xlo = fmin((double) xposn(xmin), (double) xposn(xmax));
  double xhi = fmax((double) xposn(xmin), (double) xposn(xmax));
  double ylo = fmin((double) yposn(ymin), (double) yposn(ymax));
  double yhi = fmax((double) yposn(ymin), (double) yposn(ymax));
  const double margin = 12.0;

  return (px - half_width > xlo + margin) &&
         (px + half_width < xhi - margin) &&
         (py - half_height > ylo + margin) &&
         (py + half_height < yhi - margin);
}

static int label_crosses_grid_lines(
    float x,
    float y,
    double angle_deg,
    int text_width,
    int text_height,
    float xmin,
    float xmax,
    float ymin,
    float ymax,
    double xgrid_origin,
    double xgrid_step,
    double ygrid_origin,
    double ygrid_step) {
  double label_angle_deg = readable_label_angle(angle_deg);
  double angle_rad = label_angle_deg * PLOT_PI / 180.0;
  double half_width =
      (fabs(cos(angle_rad)) * (double) text_width * 0.5) +
      (fabs(sin(angle_rad)) * (double) text_height * 0.5);
  double half_height =
      (fabs(sin(angle_rad)) * (double) text_width * 0.5) +
      (fabs(cos(angle_rad)) * (double) text_height * 0.5);
  double px = (double) xposn(x);
  double py = (double) yposn(y) - ((double) text_height * 0.5);
  double clearance = 14.0;
  double x_min_data = fmin((double) xmin, (double) xmax);
  double x_max_data = fmax((double) xmin, (double) xmax);
  double y_min_data = fmin((double) ymin, (double) ymax);
  double y_max_data = fmax((double) ymin, (double) ymax);

  if (fabs(xgrid_step) > 1.0e-9) {
    double step = fabs(xgrid_step);
    double value =
        xgrid_origin + ceil((x_min_data - xgrid_origin) / step) * step;

    for (; value <= x_max_data + (step * 0.5); value += step) {
      double grid_px = (double) xposn((float) value);

      if ((grid_px > px - half_width - clearance) &&
          (grid_px < px + half_width + clearance)) {
        return 1;
      }
    }
  }

  if (fabs(ygrid_step) > 1.0e-9) {
    double step = fabs(ygrid_step);
    double value =
        ygrid_origin + ceil((y_min_data - ygrid_origin) / step) * step;

    for (; value <= y_max_data + (step * 0.5); value += step) {
      double grid_py = (double) yposn((float) value);

      if ((grid_py > py - half_height - clearance) &&
          (grid_py < py + half_height + clearance)) {
        return 1;
      }
    }
  }

  return 0;
}

static int select_contour_label_position(
    const float *xpts,
    const float *ypts,
    const int *nray,
    int curve_count,
    const reference_contour_t *ref,
    int text_width,
    int text_height,
    float xmin,
    float xmax,
    float ymin,
    float ymax,
    double xgrid_origin,
    double xgrid_step,
    double ygrid_origin,
    double ygrid_step,
    contour_label_position_t *position) {
  double best_score = DBL_MAX;
  double fallback_score = DBL_MAX;
  contour_label_position_t fallback;
  int offset = 0;
  int curve_index;

  memset(position, 0, sizeof(*position));
  memset(&fallback, 0, sizeof(fallback));

  for (curve_index = 0; curve_index < curve_count; curve_index++) {
    int point_count = nray[curve_index];
    int point_index;

    for (point_index = 1; point_index + 1 < point_count; point_index++) {
      float x = xpts[offset + point_index];
      float y = ypts[offset + point_index];
      double angle_deg =
          contour_tangent_angle_degrees(xpts + offset, ypts + offset, point_count, point_index);
      double score = normalized_label_distance(x, y, ref->preferred_x, ref->preferred_y,
                                               xmin, xmax, ymin, ymax);
      int crosses_grid = label_crosses_grid_lines(
          x, y, angle_deg, text_width, text_height, xmin, xmax, ymin, ymax,
          xgrid_origin, xgrid_step, ygrid_origin, ygrid_step);
      double fallback_candidate_score = score + (crosses_grid ? 100.0 : 0.0);

      if (fallback_candidate_score < fallback_score) {
        fallback_score = fallback_candidate_score;
        fallback.curve_index = curve_index;
        fallback.point_index = point_index;
        fallback.point_offset = offset;
        fallback.angle_deg = angle_deg;
      }

      if (point_count >= 6 &&
          label_fits_inside_axes(x, y, angle_deg, text_width, text_height,
                                 xmin, xmax, ymin, ymax) &&
          !crosses_grid &&
          score < best_score) {
        best_score = score;
        position->curve_index = curve_index;
        position->point_index = point_index;
        position->point_offset = offset;
        position->angle_deg = angle_deg;
      }
    }

    offset += point_count;
  }

  if (best_score < DBL_MAX) {
    return 1;
  }
  if (fallback_score < DBL_MAX) {
    *position = fallback;
    return 1;
  }
  return 0;
}

static void draw_curve_slice(const float *xpts, const float *ypts, int start, int stop) {
  if (stop - start >= 2) {
    curve(xpts + start, ypts + start, stop - start);
  }
}

static void draw_curve_with_label_gap(
    const float *xpts,
    const float *ypts,
    int point_count,
    int label_point_index,
    double gap_half_width) {
  double *distance = NULL;
  double label_distance;
  double gap_start;
  double gap_stop;
  int first_gap = point_count;
  int last_gap = -1;
  int point_index;

  if (point_count < 2) {
    return;
  }

  distance = (double *) calloc((size_t) point_count, sizeof(double));
  if (distance == NULL) {
    curve(xpts, ypts, point_count);
    return;
  }

  for (point_index = 1; point_index < point_count; point_index++) {
    double dx = (double) xposn(xpts[point_index]) - (double) xposn(xpts[point_index - 1]);
    double dy = (double) yposn(ypts[point_index]) - (double) yposn(ypts[point_index - 1]);

    distance[point_index] = distance[point_index - 1] + sqrt((dx * dx) + (dy * dy));
  }

  label_distance = distance[label_point_index];
  gap_start = fmax(0.0, label_distance - gap_half_width);
  gap_stop = fmin(distance[point_count - 1], label_distance + gap_half_width);

  for (point_index = 0; point_index < point_count; point_index++) {
    if (distance[point_index] >= gap_start && distance[point_index] <= gap_stop) {
      if (first_gap == point_count) {
        first_gap = point_index;
      }
      last_gap = point_index;
    }
  }

  if (first_gap == point_count) {
    curve(xpts, ypts, point_count);
  } else {
    draw_curve_slice(xpts, ypts, 0, first_gap);
    draw_curve_slice(xpts, ypts, last_gap + 1, point_count);
  }

  free(distance);
}

static void set_reference_line_style(int style_index) {
  if (style_index == 0) {
    dotl();
  } else if (style_index == 1) {
    dashm();
  } else {
    solid();
  }
}

static void draw_contour_text_label(
    const reference_contour_t *ref,
    float x,
    float y,
    double angle_deg,
    float log_min,
    float log_max) {
  float t = clamp_unit((log10f(ref->probability) - log_min) / (log_max - log_min));
  int x_center = (int) floorf(xposn(x) + 0.5f);
  int y_center = (int) floorf(yposn(y) + 0.5f);
  int text_height = 24;
  double label_angle_deg = readable_label_angle(angle_deg);

  if (t > 0.68f) {
    setrgb(0.96f, 0.96f, 0.96f);
  } else {
    setrgb(0.08f, 0.08f, 0.08f);
  }
  solid();
  linwid(1);
  txtbgd(-1);
  frmess(0);
  txtjus("CENT");
  simplx();
  height(22);
  angle((int) floor(label_angle_deg + ((label_angle_deg >= 0.0) ? 0.5 : -0.5)));
  messag(ref->label, x_center, y_center - (text_height / 2));
  angle(0);
  complx();
  txtjus("LEFT");
}

static int draw_reference_contour_with_label_gap(
    const float *xplot,
    int nx,
    const float *yplot,
    int ny,
    const float *zplot,
    const reference_contour_t *ref,
    int style_index,
    float log_min,
    float log_max,
    double xgrid_origin,
    double xgrid_step,
    double ygrid_origin,
    double ygrid_step) {
  int max_points = max_int(nx * ny * 4, 4096);
  float *xpts = NULL;
  float *ypts = NULL;
  int *nray = NULL;
  int curve_count = 0;
  int curve_index;
  int offset = 0;
  int text_width;
  const int text_height = 24;
  contour_label_position_t label_position;
  int have_label;

  xpts = (float *) calloc((size_t) max_points, sizeof(float));
  ypts = (float *) calloc((size_t) max_points, sizeof(float));
  nray = (int *) calloc((size_t) CONTOUR_MAX_CURVES, sizeof(int));
  if (xpts == NULL || ypts == NULL || nray == NULL) {
    fprintf(stderr, "Out of memory while allocating contour points\n");
    free(xpts);
    free(ypts);
    free(nray);
    return 0;
  }

  conpts(xplot, nx, yplot, ny, zplot, log10f(ref->probability),
         xpts, ypts, max_points, nray, CONTOUR_MAX_CURVES, &curve_count);

  height(text_height);
  text_width = nlmess(ref->label);
  have_label = select_contour_label_position(
      xpts, ypts, nray, curve_count, ref, text_width, text_height,
      xplot[0], xplot[nx - 1], yplot[0], yplot[ny - 1],
      xgrid_origin, xgrid_step, ygrid_origin, ygrid_step, &label_position);

  setrgb(0.08f, 0.08f, 0.08f);
  linwid(7);
  set_reference_line_style(style_index);

  for (curve_index = 0; curve_index < curve_count; curve_index++) {
    int point_count = nray[curve_index];

    if (have_label && curve_index == label_position.curve_index) {
      double gap_half_width = (double) text_width * 0.70 + 20.0;

      draw_curve_with_label_gap(xpts + offset, ypts + offset, point_count,
                                label_position.point_index, gap_half_width);
    } else if (point_count >= 2) {
      curve(xpts + offset, ypts + offset, point_count);
    }

    offset += point_count;
  }

  if (have_label) {
    int label_offset = label_position.point_offset + label_position.point_index;

    draw_contour_text_label(ref, xpts[label_offset], ypts[label_offset],
                            label_position.angle_deg, log_min, log_max);
  }

  free(xpts);
  free(ypts);
  free(nray);
  return have_label;
}

static void render_plot(const opq_loss_grid_t *loss_grid, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  const char *plot_title = getenv("OPQ_LOSS_SURFACE_TITLE");
  const char *plot_note = getenv("OPQ_LOSS_SURFACE_NOTE");
  reference_contour_t ref_contours[REF_LEVEL_COUNT];
  float *zplot = NULL;
  float *xfine = NULL;
  float *yfine = NULL;
  float *zfine = NULL;
  float xmin = loss_grid->x[0];
  float xmax = loss_grid->x[loss_grid->nx - 1];
  float ymin = loss_grid->y[0];
  float ymax = loss_grid->y[loss_grid->ny - 1];
  float xpad = 0.015f * fmaxf(fabsf(xmax - xmin), 1.0e-6f);
  float ypad = 0.015f * fmaxf(fabsf(ymax - ymin), 1.0e-6f);
  float gxmin = xmin - xpad;
  float gxmax = xmax + xpad;
  float gymin = fmaxf(0.0f, ymin - ypad);
  float gymax = ymax + ypad;
  float zmin = 1.0e-6f;
  double xstep = nice_step((double) (gxmax - gxmin), 8);
  double ystep = nice_step((double) (gymax - gymin), 7);
  double xorigin = align_up(gxmin, xstep);
  double yorigin = align_up(gymin, ystep);
  double zorigin = -6.0;
  double zstep = 1.0;
  const reference_contour_t base_ref_contours[REF_LEVEL_COUNT] = {
      {0.000001f, "1e-6", -0.82f, 0.988f},
      {0.010f, "1 %", -0.46f, 1.004f},
      {0.050f, "5 %", 0.92f, 0.974f}};
  int level_idx;
  size_t point_count = (size_t) loss_grid->nx * (size_t) loss_grid->ny;
  int fine_nx = max_int(loss_grid->nx, MIN_FINE_X_COUNT);
  int fine_ny = max_int(loss_grid->ny, MIN_FINE_Y_COUNT);
  size_t fine_point_count = (size_t) fine_nx * (size_t) fine_ny;
  size_t point_idx;
  float zlabel_span = gymax - gymin;
  float fine_zmin = 0.0f;
  float fine_zmax = 0.0f;
  const int zaxis_x = 2480;
  const int zaxis_y = 1750;
  const int zaxis_len = 1100;
  const int ztick_label_x = zaxis_x - 24;
  const int ztitle_x = zaxis_x + 146;
  int ztick_y_top;
  int ztick_y_bottom;

  zplot = (float *) calloc(point_count, sizeof(float));
  if (zplot == NULL) {
    fprintf(stderr, "Out of memory while allocating log-scaled contour grid\n");
    return;
  }
  xfine = (float *) calloc((size_t) fine_nx, sizeof(float));
  yfine = (float *) calloc((size_t) fine_ny, sizeof(float));
  zfine = (float *) calloc(fine_point_count, sizeof(float));
  if (xfine == NULL || yfine == NULL || zfine == NULL) {
    fprintf(stderr, "Out of memory while allocating interpolated contour grid\n");
    free(zplot);
    free(xfine);
    free(yfine);
    free(zfine);
    return;
  }
  for (level_idx = 0; level_idx < REF_LEVEL_COUNT; level_idx++) {
    ref_contours[level_idx] = base_ref_contours[level_idx];
  }
  for (point_idx = 0; point_idx < point_count; point_idx++) {
    zplot[point_idx] = log10f(clamp_loss_floor(loss_grid->z[point_idx], zmin));
  }
  if (!smooth_log_grid(zplot, loss_grid->nx, loss_grid->ny, 4)) {
    free(zplot);
    free(xfine);
    free(yfine);
    free(zfine);
    return;
  }
  fill_linspace(xfine, fine_nx, xmin, xmax);
  fill_linspace(yfine, fine_ny, ymin, ymax);
  interpolate_regular_grid(zplot, loss_grid->nx, loss_grid->ny, zfine, fine_nx, fine_ny);
  for (point_idx = 0; point_idx < fine_point_count; point_idx++) {
    if (point_idx == 0 || zfine[point_idx] < fine_zmin) {
      fine_zmin = zfine[point_idx];
    }
    if (point_idx == 0 || zfine[point_idx] > fine_zmax) {
      fine_zmax = zfine[point_idx];
    }
  }

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
  init_loss_palette();

  if (plot_title == NULL || plot_title[0] == '\0') {
    plot_title = "OPQ IP-Core Burst/Rate Loss Contour";
  }
  titlin(plot_title, 2);

  name("burstiness B", "x");
  name("normalized throughput share / lane", "y");

  intax();
  labdig(2, "x");
  labdig(2, "y");
  labels("none", "z");
  axspos(420, 1750);
  axslen(1950, 1100);
  graf(gxmin, gxmax, (float) xorigin, (float) xstep, gymin, gymax,
       (float) yorigin, (float) ystep);

  draw_loss_gradient_cells(xfine, fine_nx, yfine, fine_ny, zfine, (float) zorigin, 0.0f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);

  labels("none", "contur");
  for (level_idx = 0; level_idx < REF_LEVEL_COUNT; level_idx++) {
    float ref_log = log10f(ref_contours[level_idx].probability);

    if (ref_log <= fine_zmin || ref_log >= fine_zmax) {
      continue;
    }
    if (!draw_reference_contour_with_label_gap(
            xfine, fine_nx, yfine, fine_ny, zfine, &ref_contours[level_idx], level_idx,
            (float) zorigin, 0.0f, xorigin, xstep, yorigin, ystep)) {
      fprintf(stderr, "Warning: no label point found for contour %s\n",
              ref_contours[level_idx].label);
    }
  }
  linwid(1);
  solid();
  angle(0);

  draw_persistent_knee_if_present(gxmin, gxmax, gymin, gymax);

  color("fore");
  height(32);
  zscale((float) zorigin, 0.0f);
  zaxis((float) zorigin, 0.0f, (float) zorigin, (float) zstep, zaxis_len,
        "", 1, 0, zaxis_x, zaxis_y);
  ztick_y_top = (int) floorf(yposn(gymax) + 0.5f);
  ztick_y_bottom = (int) floorf(yposn(gymin) + 0.5f);
  height(16);
  txtjus("RIGHT");
  messag("1", ztick_label_x, ztick_y_top - 8);
  messag("1e-1", ztick_label_x,
         (int) floorf(yposn(gymax - (1.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-2", ztick_label_x,
         (int) floorf(yposn(gymax - (2.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-3", ztick_label_x,
         (int) floorf(yposn(gymax - (3.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-4", ztick_label_x,
         (int) floorf(yposn(gymax - (4.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-5", ztick_label_x,
         (int) floorf(yposn(gymax - (5.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-6", ztick_label_x, ztick_y_bottom - 8);
  txtjus("CENT");
  height(30);
  angle(270);
  messag("loss probability", ztitle_x, (ztick_y_top + ztick_y_bottom) / 2);
  angle(0);
  txtjus("LEFT");

  draw_sample_point_if_present(gxmin, gxmax, gymin, gymax);
  draw_sample_pins_if_present(gxmin, gxmax, gymin, gymax);
  draw_modeling_contract_box(gxmin, gymin, gymax);

  height(50);
  title();
  color("fore");
  height(14);
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "x: B=(CV-1)/(CV+1), y: normalized offered throughput share per lane";
  }
  messag(plot_note, 420, 1938);
  messag("loss tiers: controlled CSR/drop, asserted local hook, inferred E2E-after-drain", 420, 1980);
  messag("checkpoints: per-subframe basic -> knee-zoom stats -> high-performance collective soak", 420, 2022);
  messag("B=-1 periodic, B=0 Poisson, B=+1 bursty; inline labels: dot 1e-6, dash 1%, solid 5%", 420, 2064);
  disfin();
  free(zplot);
  free(xfine);
  free(yfine);
  free(zfine);
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

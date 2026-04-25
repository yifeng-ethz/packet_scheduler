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
  float gxmin = xmin;
  float gxmax = xmax;
  float gymin = ymin;
  float gymax = ymax;
  float gymin_pct = gymin * 100.0f;
  float gymax_pct = gymax * 100.0f;
  float zmin = 1.0e-6f;
  double xstep = nice_step((double) (gxmax - gxmin), 8);
  double ystep = nice_step((double) (gymax_pct - gymin_pct), 7);
  double xorigin = align_up(gxmin, xstep);
  double yorigin = align_up(gymin_pct, ystep);
  double zorigin = -6.0;
  double zstep = 1.0;
  const reference_contour_t base_ref_contours[REF_LEVEL_COUNT] = {
      {0.000001f, "1e-6", -0.82f, 98.8f},
      {0.010f, "1 %", -0.46f, 100.4f},
      {0.050f, "5 %", 0.92f, 97.4f}};
  int level_idx;
  size_t point_count = (size_t) loss_grid->nx * (size_t) loss_grid->ny;
  int fine_nx = max_int(loss_grid->nx, MIN_FINE_X_COUNT);
  int fine_ny = max_int(loss_grid->ny, MIN_FINE_Y_COUNT);
  size_t fine_point_count = (size_t) fine_nx * (size_t) fine_ny;
  size_t point_idx;
  float zlabel_span = gymax_pct - gymin_pct;
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
  fill_linspace(yfine, fine_ny, ymin * 100.0f, ymax * 100.0f);
  interpolate_regular_grid(zplot, loss_grid->nx, loss_grid->ny, zfine, fine_nx, fine_ny);

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
  init_loss_palette();

  if (plot_title == NULL || plot_title[0] == '\0') {
    plot_title = "OPQ IP-Core Burst/Rate Loss Contour";
  }
  titlin(plot_title, 2);

  name("burstiness B", "x");
  name("rate / lane [%]", "y");

  intax();
  labdig(2, "x");
  labdig(0, "y");
  labels("none", "z");
  axspos(420, 1750);
  axslen(1950, 1100);
  graf(gxmin, gxmax, (float) xorigin, (float) xstep, gymin_pct, gymax_pct,
       (float) yorigin, (float) ystep);

  draw_loss_gradient_cells(xfine, fine_nx, yfine, fine_ny, zfine, (float) zorigin, 0.0f);
  setrgb(0.82f, 0.82f, 0.82f);
  grid(1, 1);

  labels("none", "contur");
  for (level_idx = 0; level_idx < REF_LEVEL_COUNT; level_idx++) {
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

  color("fore");
  height(32);
  zscale((float) zorigin, 0.0f);
  zaxis((float) zorigin, 0.0f, (float) zorigin, (float) zstep, zaxis_len,
        "", 1, 0, zaxis_x, zaxis_y);
  ztick_y_top = (int) floorf(yposn(gymax_pct) + 0.5f);
  ztick_y_bottom = (int) floorf(yposn(gymin_pct) + 0.5f);
  height(16);
  txtjus("RIGHT");
  messag("1", ztick_label_x, ztick_y_top - 8);
  messag("1e-1", ztick_label_x,
         (int) floorf(yposn(gymax_pct - (1.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-2", ztick_label_x,
         (int) floorf(yposn(gymax_pct - (2.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-3", ztick_label_x,
         (int) floorf(yposn(gymax_pct - (3.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-4", ztick_label_x,
         (int) floorf(yposn(gymax_pct - (4.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-5", ztick_label_x,
         (int) floorf(yposn(gymax_pct - (5.0f / 6.0f) * zlabel_span) + 0.5f) - 8);
  messag("1e-6", ztick_label_x, ztick_y_bottom - 8);
  txtjus("CENT");
  height(30);
  angle(270);
  messag("loss probability", ztitle_x, (ztick_y_top + ztick_y_bottom) / 2);
  angle(0);
  txtjus("LEFT");

  height(50);
  title();
  color("fore");
  height(14);
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "x: B=(SCV-1)/(SCV+1), y: offered rate / lane shown in percent";
  }
  messag(plot_note, 420, 1938);
  messag("B=-1 periodic, B=0 Poisson, B=+1 bursty; fill: continuous log loss from 1e-6 to 1", 420, 1980);
  messag("inline loss-probability labels: dot 1e-6, dash 1%, solid 5%", 420, 2022);
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

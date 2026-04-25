#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_NSHD_SERIES 16

typedef struct {
  int n_shd;
  float skew_frames;
  float log10_opq_loss_rate;
  float log10_old_loss_rate;
  float log10_loss_ratio;
} comparison_point_t;

typedef struct {
  comparison_point_t *points;
  size_t count;
  size_t capacity;
} comparison_table_t;

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

static int append_point(comparison_table_t *table, comparison_point_t point) {
  if (table->count == table->capacity) {
    size_t next_capacity = (table->capacity == 0) ? 512 : table->capacity * 2;
    comparison_point_t *next_points =
        (comparison_point_t *) realloc(table->points, next_capacity * sizeof(*next_points));

    if (next_points == NULL) {
      fprintf(stderr, "Out of memory while growing comparison table\n");
      return 0;
    }
    table->points = next_points;
    table->capacity = next_capacity;
  }

  table->points[table->count++] = point;
  return 1;
}

static int read_comparison_csv(const char *path, comparison_table_t *table) {
  FILE *handle = fopen(path, "r");
  char line[2048];

  if (handle == NULL) {
    fprintf(stderr, "Failed to open comparison CSV %s\n", path);
    return 0;
  }

  if (fgets(line, sizeof(line), handle) == NULL) {
    fprintf(stderr, "Empty comparison CSV %s\n", path);
    fclose(handle);
    return 0;
  }

  while (fgets(line, sizeof(line), handle) != NULL) {
    comparison_point_t point;
    float skew_timestamp_ticks;
    float skew_ns;
    float aligned_poisson_mean;
    float offered_poisson_mean;
    float opq_loss_rate;
    float old_loss_rate;
    float loss_ratio;
    int opq_capacity;
    int old_tree_depth;
    int old_capacity;
    int parsed;

    trim_ascii(line);
    if (line[0] == '\0') {
      continue;
    }

    parsed = sscanf(
        line,
        "%d,%f,%f,%f,%f,%f,%d,%d,%d,%f,%f,%f,%f,%f,%f",
        &point.n_shd,
        &point.skew_frames,
        &skew_timestamp_ticks,
        &skew_ns,
        &aligned_poisson_mean,
        &offered_poisson_mean,
        &opq_capacity,
        &old_tree_depth,
        &old_capacity,
        &opq_loss_rate,
        &old_loss_rate,
        &loss_ratio,
        &point.log10_opq_loss_rate,
        &point.log10_old_loss_rate,
        &point.log10_loss_ratio);
    if (parsed != 15) {
      fprintf(stderr, "Malformed comparison CSV row: %s\n", line);
      fclose(handle);
      return 0;
    }

    if (!append_point(table, point)) {
      fclose(handle);
      return 0;
    }
  }

  fclose(handle);
  return table->count > 0;
}

static void free_comparison_table(comparison_table_t *table) {
  free(table->points);
  table->points = NULL;
  table->count = 0;
  table->capacity = 0;
}

static int collect_n_shd_values(const comparison_table_t *table, int *values, int max_values) {
  int count = 0;

  for (size_t point_idx = 0; point_idx < table->count; point_idx++) {
    int seen = 0;

    for (int value_idx = 0; value_idx < count; value_idx++) {
      if (values[value_idx] == table->points[point_idx].n_shd) {
        seen = 1;
        break;
      }
    }
    if (!seen && count < max_values) {
      values[count++] = table->points[point_idx].n_shd;
    }
  }

  for (int outer = 0; outer < count; outer++) {
    for (int inner = outer + 1; inner < count; inner++) {
      if (values[inner] < values[outer]) {
        int tmp = values[outer];

        values[outer] = values[inner];
        values[inner] = tmp;
      }
    }
  }
  return count;
}

static int count_points_for_n_shd(const comparison_table_t *table, int n_shd) {
  int count = 0;

  for (size_t point_idx = 0; point_idx < table->count; point_idx++) {
    if (table->points[point_idx].n_shd == n_shd) {
      count++;
    }
  }
  return count;
}

static int fill_series_for_n_shd(
    const comparison_table_t *table,
    int n_shd,
    int old_impl,
    float *x_values,
    float *y_values,
    int max_count) {
  int count = 0;

  for (size_t point_idx = 0; point_idx < table->count; point_idx++) {
    if (table->points[point_idx].n_shd == n_shd && count < max_count) {
      x_values[count] = table->points[point_idx].skew_frames;
      y_values[count] = old_impl ? table->points[point_idx].log10_old_loss_rate
                                 : table->points[point_idx].log10_opq_loss_rate;
      count++;
    }
  }

  for (int outer = 0; outer < count; outer++) {
    for (int inner = outer + 1; inner < count; inner++) {
      if (x_values[inner] < x_values[outer]) {
        float tmp_x = x_values[outer];
        float tmp_y = y_values[outer];

        x_values[outer] = x_values[inner];
        y_values[outer] = y_values[inner];
        x_values[inner] = tmp_x;
        y_values[inner] = tmp_y;
      }
    }
  }
  return count;
}

static void set_n_shd_color(int series_idx) {
  if (series_idx == 0) {
    /* N_SHD=64: shortest timestamp/frame wavelength, violet-blue. */
    setrgb(0.24f, 0.23f, 0.78f);
  } else if (series_idx == 1) {
    /* N_SHD=128: mid wavelength, green. */
    setrgb(0.05f, 0.56f, 0.35f);
  } else {
    /* N_SHD=256: longest timestamp/frame wavelength, red-orange. */
    setrgb(0.86f, 0.28f, 0.13f);
  }
}

static void draw_plot_grid(
    float x_min,
    float x_max,
    float x_step,
    float y_min,
    float y_max,
    float y_step) {
  color("fore");
  dotl();
  linwid(1);

  for (float x = x_min + x_step; x < x_max - 0.001f; x += x_step) {
    float x_values[2] = {x, x};
    float y_values[2] = {y_min, y_max};

    curve(x_values, y_values, 2);
  }

  for (float y = y_min + y_step; y < y_max - 0.001f; y += y_step) {
    float x_values[2] = {x_min, x_max};
    float y_values[2] = {y, y};

    curve(x_values, y_values, 2);
  }

  solid();
}

static void draw_manual_legend(const int *n_shd_values, int series_count) {
  char label[64];
  float x0 = 1.22f;
  float x1 = 1.39f;
  float x_text = 1.43f;
  float y_top = -7.15f;
  float y_step = 0.55f;

  color("fore");
  simplx();
  height(18);
  rlmess("solid: OPQ, dash: old time-merger", x0, -6.55f);
  linwid(5);

  for (int series_idx = 0; series_idx < series_count; series_idx++) {
    float y = y_top - ((float) series_idx * y_step);
    float x_values[2] = {x0, x1};
    float y_values[2] = {y, y};

    set_n_shd_color(series_idx);
    solid();
    curve(x_values, y_values, 2);
    dashm();
    y_values[0] = y - 0.18f;
    y_values[1] = y - 0.18f;
    curve(x_values, y_values, 2);

    color("fore");
    solid();
    linwid(1);
    snprintf(label, sizeof(label), "N_SHD=%d", n_shd_values[series_idx]);
    rlmess(label, x_text, y + 0.08f);
    linwid(5);
  }
  linwid(1);
  solid();
  complx();
}

static void render_plot(const comparison_table_t *table, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  int n_shd_values[MAX_NSHD_SERIES];
  int n_shd_count;

  n_shd_count = collect_n_shd_values(table, n_shd_values, MAX_NSHD_SERIES);

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

  titlin("OPQ IP-Core vs Time-Merger Loss Curve", 2);
  name("one-lane header skew [frames]", "x");
  name("log10 loss rate", "y");

  intax();
  labdig(1, "x");
  labdig(0, "y");
  axspos(420, 1650);
  axslen(2100, 1050);
  graf(0.0f, 2.0f, 0.0f, 0.5f, -12.0f, 0.0f, -12.0f, 2.0f);

  draw_plot_grid(0.0f, 2.0f, 0.5f, -12.0f, 0.0f, 2.0f);

  hsymbl(20);
  for (int series_idx = 0; series_idx < n_shd_count; series_idx++) {
    int point_count = count_points_for_n_shd(table, n_shd_values[series_idx]);
    float *x_values = NULL;
    float *y_values = NULL;

    if (point_count < 2) {
      continue;
    }

    x_values = (float *) calloc((size_t) point_count, sizeof(float));
    y_values = (float *) calloc((size_t) point_count, sizeof(float));
    if (x_values == NULL || y_values == NULL) {
      fprintf(stderr, "Out of memory while allocating comparison series\n");
      free(x_values);
      free(y_values);
      continue;
    }

    set_n_shd_color(series_idx);
    linwid(7);
    solid();
    point_count = fill_series_for_n_shd(
        table, n_shd_values[series_idx], 0, x_values, y_values, point_count);
    curve(x_values, y_values, point_count);

    point_count = fill_series_for_n_shd(
        table, n_shd_values[series_idx], 1, x_values, y_values, point_count);
    dashm();
    curve(x_values, y_values, point_count);

    free(x_values);
    free(y_values);
  }
  solid();
  linwid(1);

  draw_manual_legend(n_shd_values, n_shd_count);

  height(42);
  title();
  color("fore");
  height(17);
  messag("iid Poisson input; 3 lanes aligned, lane 3 delayed; lower curve is better", 420, 1908);
  messag("old model charges a 2-input tree join/service-credit penalty; analytical proxy, not pin-equivalent RTL evidence", 420, 1950);
  disfin();
}

int main(int argc, char **argv) {
  comparison_table_t table;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <old_vs_opq_loss_comparison.csv> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }

  memset(&table, 0, sizeof(table));
  if (!read_comparison_csv(argv[1], &table)) {
    free_comparison_table(&table);
    return 1;
  }

  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_comparison_table(&table);
    return 1;
  }

  render_plot(&table, output_path);
  free_comparison_table(&table);
  return 0;
}

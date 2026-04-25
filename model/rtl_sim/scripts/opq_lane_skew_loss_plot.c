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
  int ticket_fifo_depth;
  float skew_frames;
  float loss_rate_percent;
} lane_skew_point_t;

typedef struct {
  lane_skew_point_t *points;
  size_t count;
  size_t capacity;
} lane_skew_table_t;

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

static int append_point(lane_skew_table_t *table, lane_skew_point_t point) {
  if (table->count == table->capacity) {
    size_t next_capacity = (table->capacity == 0) ? 256 : table->capacity * 2;
    lane_skew_point_t *next_points =
        (lane_skew_point_t *) realloc(table->points, next_capacity * sizeof(*next_points));

    if (next_points == NULL) {
      fprintf(stderr, "Out of memory while growing lane-skew table\n");
      return 0;
    }
    table->points = next_points;
    table->capacity = next_capacity;
  }

  table->points[table->count++] = point;
  return 1;
}

static int read_lane_skew_csv(const char *path, lane_skew_table_t *table) {
  FILE *handle = fopen(path, "r");
  char line[1024];

  if (handle == NULL) {
    fprintf(stderr, "Failed to open lane-skew CSV %s\n", path);
    return 0;
  }

  if (fgets(line, sizeof(line), handle) == NULL) {
    fprintf(stderr, "Empty lane-skew CSV %s\n", path);
    fclose(handle);
    return 0;
  }

  while (fgets(line, sizeof(line), handle) != NULL) {
    lane_skew_point_t point;
    float skew_timestamp_ticks;
    float skew_ns;
    float aligned_poisson_mean;
    float offered_poisson_mean;
    float overflow_mean;
    float loss_rate;
    int parsed;

    trim_ascii(line);
    if (line[0] == '\0') {
      continue;
    }

    parsed = sscanf(
        line,
        "%d,%d,%f,%f,%f,%f,%f,%f,%f",
        &point.n_shd,
        &point.ticket_fifo_depth,
        &point.skew_frames,
        &skew_timestamp_ticks,
        &skew_ns,
        &aligned_poisson_mean,
        &offered_poisson_mean,
        &overflow_mean,
        &loss_rate);
    if (parsed != 9) {
      fprintf(stderr, "Malformed lane-skew CSV row: %s\n", line);
      fclose(handle);
      return 0;
    }

    point.loss_rate_percent = 100.0f * loss_rate;
    if (!append_point(table, point)) {
      fclose(handle);
      return 0;
    }
  }

  fclose(handle);
  return table->count > 0;
}

static void free_lane_skew_table(lane_skew_table_t *table) {
  free(table->points);
  table->points = NULL;
  table->count = 0;
  table->capacity = 0;
}

static int collect_n_shd_values(const lane_skew_table_t *table, int *values, int max_values) {
  int count = 0;
  size_t point_idx;

  for (point_idx = 0; point_idx < table->count; point_idx++) {
    int seen = 0;
    int value_idx;

    for (value_idx = 0; value_idx < count; value_idx++) {
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

static int count_points_for_n_shd(const lane_skew_table_t *table, int n_shd) {
  int count = 0;
  size_t point_idx;

  for (point_idx = 0; point_idx < table->count; point_idx++) {
    if (table->points[point_idx].n_shd == n_shd) {
      count++;
    }
  }
  return count;
}

static int fill_series_for_n_shd(
    const lane_skew_table_t *table,
    int n_shd,
    float *x_values,
    float *y_values,
    int max_count,
    int *ticket_fifo_depth) {
  int count = 0;
  size_t point_idx;

  *ticket_fifo_depth = 0;
  for (point_idx = 0; point_idx < table->count; point_idx++) {
    if (table->points[point_idx].n_shd == n_shd && count < max_count) {
      x_values[count] = table->points[point_idx].skew_frames;
      y_values[count] = table->points[point_idx].loss_rate_percent;
      *ticket_fifo_depth = table->points[point_idx].ticket_fifo_depth;
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

static float max_loss_percent(const lane_skew_table_t *table) {
  float max_value = 0.0f;
  size_t point_idx;

  for (point_idx = 0; point_idx < table->count; point_idx++) {
    if (table->points[point_idx].loss_rate_percent > max_value) {
      max_value = table->points[point_idx].loss_rate_percent;
    }
  }
  return max_value;
}

static void set_series_style(int series_idx) {
  if (series_idx == 0) {
    setrgb(0.10f, 0.35f, 0.65f);
    solid();
    marker(15);
  } else if (series_idx == 1) {
    setrgb(0.65f, 0.22f, 0.28f);
    dashm();
    marker(16);
  } else {
    setrgb(0.16f, 0.50f, 0.32f);
    dashl();
    marker(17);
  }
}

static void draw_plot_grid(
    float x_min,
    float x_max,
    float x_step,
    float y_min,
    float y_max,
    float y_step) {
  float x;
  float y;

  color("fore");
  dotl();
  linwid(1);

  for (x = x_min + x_step; x < x_max - 0.001f; x += x_step) {
    float x_values[2] = {x, x};
    float y_values[2] = {y_min, y_max};

    curve(x_values, y_values, 2);
  }

  for (y = y_min + y_step; y < y_max - 0.001f; y += y_step) {
    float x_values[2] = {x_min, x_max};
    float y_values[2] = {y, y};

    curve(x_values, y_values, 2);
  }

  solid();
}

static void draw_manual_legend(const int *n_shd_values, int series_count) {
  float y_top = 52.0f;
  float y_step = 3.0f;
  char label[64];

  color("fore");
  linwid(1);
  simplx();
  height(22);
  rlmess("iid Poisson input", 0.05f, y_top);
  linwid(5);
  hsymbl(24);
  for (int series_idx = 0; series_idx < series_count; series_idx++) {
    float x_values[2] = {0.05f, 0.15f};
    float y = y_top - ((float) (series_idx + 1) * y_step);
    float y_values[2] = {y, y};

    set_series_style(series_idx);
    incmrk(1);
    curve(x_values, y_values, 2);
    incmrk(0);
    solid();
    snprintf(label, sizeof(label), "N_SHD=%d", n_shd_values[series_idx]);
    color("fore");
    linwid(1);
    simplx();
    height(22);
    rlmess(label, 0.19f, y + 0.7f);
    linwid(5);
  }
  marker(-1);
  linwid(1);
  solid();
  complx();
}

static void render_plot(const lane_skew_table_t *table, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  int n_shd_values[MAX_NSHD_SERIES];
  int n_shd_count;
  float y_axis_max;
  int ticket_fifo_depth = (table->count > 0) ? table->points[0].ticket_fifo_depth : 0;
  char note[256];

  n_shd_count = collect_n_shd_values(table, n_shd_values, MAX_NSHD_SERIES);
  y_axis_max = fmaxf(5.0f, ceilf((max_loss_percent(table) + 2.5f) / 5.0f) * 5.0f);
  if (y_axis_max < 55.0f) {
    y_axis_max = 55.0f;
  }

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

  titlin("OPQ IP-Core Lane-Skew and Loss Curve", 2);
  name("one-lane header skew [frames]", "x");
  name("loss rate [%]", "y");

  intax();
  labdig(1, "x");
  labdig(0, "y");
  axspos(420, 1650);
  axslen(2100, 1050);
  graf(0.0f, 2.0f, 0.0f, 0.5f, 0.0f, y_axis_max, 0.0f, 10.0f);

  linwid(7);
  hsymbl(26);
  for (int series_idx = 0; series_idx < n_shd_count; series_idx++) {
    int point_count = count_points_for_n_shd(table, n_shd_values[series_idx]);
    float *x_values = NULL;
    float *y_values = NULL;
    int ticket_fifo_depth = 0;

    if (point_count < 2) {
      continue;
    }
    x_values = (float *) calloc((size_t) point_count, sizeof(float));
    y_values = (float *) calloc((size_t) point_count, sizeof(float));
    if (x_values == NULL || y_values == NULL) {
      fprintf(stderr, "Out of memory while allocating lane-skew series\n");
      free(x_values);
      free(y_values);
      continue;
    }

    point_count = fill_series_for_n_shd(
        table, n_shd_values[series_idx], x_values, y_values, point_count,
        &ticket_fifo_depth);
    (void) ticket_fifo_depth;
    set_series_style(series_idx);
    incmrk(10);
    curve(x_values, y_values, point_count);
    free(x_values);
    free(y_values);
  }
  incmrk(0);
  marker(-1);
  solid();
  linwid(1);

  draw_plot_grid(0.0f, 2.0f, 0.5f, 0.0f, y_axis_max, 10.0f);

  draw_manual_legend(n_shd_values, n_shd_count);

  height(42);
  title();
  color("fore");
  height(17);
  messag("3 lanes aligned, lane 3 delayed; FEB ts ticks = frames x N_SHD x 16 (0x800 at N_SHD=128)", 420, 1908);
  snprintf(note, sizeof(note),
           "iid Poisson input, rho=0.92; fixed ticket window=%d analytical proxy, not direct RTL loss evidence",
           ticket_fifo_depth);
  messag(note, 420, 1950);
  disfin();
}

int main(int argc, char **argv) {
  lane_skew_table_t table;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <lane_skew_loss.csv> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }

  memset(&table, 0, sizeof(table));
  if (!read_lane_skew_csv(argv[1], &table)) {
    free_lane_skew_table(&table);
    return 1;
  }

  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_lane_skew_table(&table);
    return 1;
  }

  render_plot(&table, output_path);
  free_lane_skew_table(&table);
  return 0;
}
